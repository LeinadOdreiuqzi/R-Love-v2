-- src/maps/systems/map_generator.lua
-- Sistema de generación de contenido del mapa

local MapGenerator = {}
local PerlinNoise = require 'src.maps.perlin_noise'
local BiomeSystem = require 'src.maps.biome_system'
local MapConfig = require 'src.maps.config.map_config'
local ColorHarmony = require 'src.utils.color_harmony'
local SeedSystem = require 'src.utils.seed_system'

MapGenerator.debugLogs = false

-- Estado de modo subnivel (sencillo y extensible)
MapGenerator.subLevelMode = { active = false, config = nil }

function MapGenerator.setSubLevelMode(active, config)
    MapGenerator.subLevelMode.active = not not active
    MapGenerator.subLevelMode.config = config
end

-- Generación mínima para chunks de subnivel (esqueleto)
function MapGenerator.generateSubLevelChunk(chunkX, chunkY, cfg, rng)
    -- Limitar generación a los límites del subnivel
    do
        local sizePixels = MapConfig.chunk.size * MapConfig.chunk.tileSize
        local spacing = MapConfig.chunk.spacing or 0
        local stride = sizePixels + spacing
        local ws = MapConfig.chunk.worldScale or 1
        local strideScaled = stride * ws
        local ex = (cfg and cfg.entry and cfg.entry.x) or 0
        local ey = (cfg and cfg.entry and cfg.entry.y) or 0
        local entryChunkX = math.floor(ex / strideScaled)
        local entryChunkY = math.floor(ey / strideScaled)
        local w = (cfg and cfg.size and cfg.size.width) or 8
        local h = (cfg and cfg.size and cfg.size.height) or 8
        local halfW = math.floor(w / 2)
        local halfH = math.floor(h / 2)
        local minX = entryChunkX - halfW
        local minY = entryChunkY - halfH
        local maxX = minX + w - 1
        local maxY = minY + h - 1
        if chunkX < minX or chunkX > maxX or chunkY < minY or chunkY > maxY then
            -- Fuera de límites: devolver chunk vacío ligero
            local c = { x = chunkX, y = chunkY, tiles = {}, objects = {stars = {}, nebulae = {}}, specialObjects = {} }
            local size = MapConfig.chunk.size
            for yy = 0, size - 1 do
                c.tiles[yy] = {}
                for xx = 0, size - 1 do c.tiles[yy][xx] = MapConfig.ObjectType.EMPTY end
            end
            c.biome = { type = BiomeSystem.BiomeType.DEEP_SPACE, name = "SubLevel-Empty" }
            return c
        end
    end

    local chunk = {
        x = chunkX,
        y = chunkY,
        tiles = {},
        objects = {stars = {}, nebulae = {}},
        specialObjects = {},
        biome = { type = BiomeSystem.BiomeType.ANCIENT_RUINS, name = "SubLevel" },
        bounds = (function()
            local sizePixels = MapConfig.chunk.size * MapConfig.chunk.tileSize
            local spacing = MapConfig.chunk.spacing or 0
            local stride = sizePixels + spacing
            local ws = MapConfig.chunk.worldScale or 1
            local left = chunkX * stride * ws
            local top = chunkY * stride * ws
            return {left = left, top = top, right = left + stride * ws, bottom = top + stride * ws}
        end)()
    }

    -- Inicializar vacío
    local size = MapConfig.chunk.size
    for y = 0, size - 1 do
        chunk.tiles[y] = {}
        for x = 0, size - 1 do
            chunk.tiles[y][x] = MapConfig.ObjectType.EMPTY
        end
    end

    -- Esqueleto: generar unas pocas estrellas para visualización
    local densities = MapConfig.density or { stars = 0.1 }
    MapGenerator.generateBalancedStars(chunk, chunkX, chunkY, densities, rng or SeedSystem.makeRNG(0))

    return chunk
end
-- Función de ruido multi-octava
function MapGenerator.multiOctaveNoise(x, y, octaves, persistence, scale)

    local value = 0
    local amplitude = 1
    local frequency = scale
    local maxValue = 0
    
    for i = 1, octaves do
        value = value + PerlinNoise.noise(x * frequency, y * frequency) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
    end
    
    return value / maxValue
end

-- Helpers para escalar densidad y aplicar caps
local function _densityScale()
    return (MapConfig.spawn and MapConfig.spawn.densityScale) or 1
end

local function _scaledCount(baseCount, cap)
    local n = math.floor((baseCount or 0) * _densityScale() + 0.5)
    if cap then n = math.min(n, cap) end
    return n
end

-- La densidad se interpola entre muestras compartidas por los chunks contiguos.
-- El relieve del cinturón se muestrea por tile en coordenadas globales.
function MapGenerator.generateBalancedAsteroids(chunk, chunkX, chunkY, densities, rng)
    local size = MapConfig.chunk.size
    local divisions = 8
    local field = {}
    for j = 0, divisions do
        field[j] = {}
        for i = 0, divisions do
            local cx, cy = chunkX + i / divisions, chunkY + j / divisions
            local blend = BiomeSystem.sampleBiomeBlend(cx, cy)
            local params = BiomeSystem.generateSpaceParameters(cx, cy, true)
            local mixed = BiomeSystem.modifyDensitiesBlended(MapConfig.density, blend, cx, cy, params)
            field[j][i] = math.min(0.12, mixed.asteroids)
        end
    end

    local O = MapConfig.ObjectType
    local cap = MapConfig.spawn.caps.asteroids_per_chunk_max
    local selected, candidates = {}, 0
    local capRng = SeedSystem.makeRNG(string.format("%d:%d:%d:rock-cap", BiomeSystem.numericSeed, chunkX, chunkY))
    for y = 0, size - 1 do
        local v = (y + 0.5) * divisions / size
        local j = math.floor(v)
        local top, bottom = field[j], field[j + 1]
        local fy = v - j
        for x = 0, size - 1 do
            local u = (x + 0.5) * divisions / size
            local i = math.floor(u)
            local fx = u - i
            local densityTop = top[i] + fx * (top[i + 1] - top[i])
            local densityBottom = bottom[i] + fx * (bottom[i + 1] - bottom[i])
            local density = densityTop + fy * (densityBottom - densityTop)
            local wx, wy = chunkX * size + x, chunkY * size + y
            local ridge = PerlinNoise.noise(wx * 0.035, wy * 0.035, 321)
            local clustering = math.max(0, 1 + 4 * ridge)
            if rng:random() < density * clustering then
                local roll = rng:random()
                local kind = roll < 0.15 and O.ASTEROID_LARGE
                    or roll < 0.55 and O.ASTEROID_MEDIUM or O.ASTEROID_SMALL
                -- Muestreo de reservorio: el límite nunca deja vacías las últimas filas.
                candidates = candidates + 1
                local slot = candidates <= cap and candidates or capRng:randomInt(1, candidates)
                if slot <= cap then
                    local old = selected[slot]
                    if old then chunk.tiles[math.floor(old / size)][old % size] = O.EMPTY end
                    selected[slot] = y * size + x
                    chunk.tiles[y][x] = kind
                end
            end
        end
    end
end

local function limitNebulaHalo(nebula, blend)
    local stride = (MapConfig.chunk.size * MapConfig.chunk.tileSize + MapConfig.chunk.spacing) * MapConfig.chunk.worldScale
    local footprint = MapConfig.biomeFootprint
    local radius = footprint.nebulaHaloRadius
    if nebula.biomeType == BiomeSystem.BiomeType.NEBULA_FIELD then
        -- Una nube central puede ocupar el campo entero; al borde sólo le queda el halo exterior.
        radius = radius + math.max(0, footprint.nebulaRadius - blend.nebulaDistance)
    end
    local maxSize = stride * radius
        * (nebula.parallax or 0.85) / MapConfig.nebulae.cullRadiusMultiplier
    nebula.size = math.min(nebula.size, maxSize)
end

function MapGenerator.generateBalancedNebulae(chunk, chunkX, chunkY, densities, rng)
    local nebulaObjects = {}
    
    local BT = BiomeSystem.BiomeType
    local numNebulae = 14

    for i = 1, numNebulae do
        local x = rng:randomInt(0, MapConfig.chunk.size - 1)
        local y = rng:randomInt(0, MapConfig.chunk.size - 1)
        local ensureField = i == numNebulae and #nebulaObjects == 0 and chunk.biome.type == BT.NEBULA_FIELD
        if ensureField then
            x = math.floor(MapConfig.chunk.size / 2)
            y = x
        end
        local globalX = chunkX * MapConfig.chunk.size + x
        local globalY = chunkY * MapConfig.chunk.size + y
        
        local nebulaChance = MapGenerator.multiOctaveNoise(globalX, globalY, 3, 0.5, 0.035)
        local blend = BiomeSystem.sampleBiomeBlend(globalX / MapConfig.chunk.size, globalY / MapConfig.chunk.size)
        local localBiome = blend.biomeA
        local w = blend.weights
        local threshold = 0.18 + 0.10 * w[BT.DEEP_SPACE] - 0.18 * w[BT.NEBULA_FIELD]
            - 0.08 * w[BT.RADIOACTIVE_ZONE] - 0.03 * w[BT.GRAVITY_ANOMALY]
        local params = BiomeSystem.generateSpaceParameters(globalX / MapConfig.chunk.size, globalY / MapConfig.chunk.size, true)
        local mixed = BiomeSystem.modifyDensitiesBlended(MapConfig.density, blend, chunkX, chunkY, params)
        -- Tasas del generador anterior a la fase 3, interpoladas según el bioma local.
        local base = math.max(1, math.floor(mixed.nebulae * 0.8))
        local ordinary = math.min(6, 2 * base)
        local attempts = ordinary + (math.min(14, 8 * base) - ordinary) * w[BT.NEBULA_FIELD]
            + (math.min(14, 3 * base) - ordinary) * w[BT.RADIOACTIVE_ZONE]
            + (math.min(4, 2 * base) - ordinary) * w[BT.DEEP_SPACE]
        local chance = 0.85 * w[BT.NEBULA_FIELD] + 0.41 * w[BT.RADIOACTIVE_ZONE]
        local shouldGenerate = ensureField or (rng:random() < attempts / numNebulae
            and (nebulaChance > threshold or rng:random() < chance))
        if shouldGenerate then
            -- Elegir categoría de tamaño con pesos ajustados por bioma
            local tiers = (MapConfig.nebulae and MapConfig.nebulae.sizeTiers) or {
                small    = { min = 80,  max = 220,  weight = 0.58 },
                medium   = { min = 220, max = 420,  weight = 0.32 },
                large    = { min = 420, max = 720,  weight = 0.09 },
                gigantic = { min = 720, max = 1200, weight = 0.01 }
            }

            -- Copia de pesos por defecto
            local wSmall, wMedium, wLarge, wGigantic = tiers.small.weight, tiers.medium.weight, tiers.large.weight, tiers.gigantic.weight
            -- Ajustes por bioma
            if localBiome == BiomeSystem.BiomeType.NEBULA_FIELD then
                -- Más probabilidad de nebulosas grandes/“gigantescas”
                wSmall, wMedium, wLarge, wGigantic = 0.40, 0.38, 0.18, 0.04
            elseif localBiome == BiomeSystem.BiomeType.DEEP_SPACE then
                -- Mayoría pequeñas/medianas
                wSmall, wMedium, wLarge, wGigantic = 0.75, 0.22, 0.03, 0.00
            elseif localBiome == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
                wSmall, wMedium, wLarge, wGigantic = 0.55, 0.32, 0.11, 0.02
            elseif localBiome == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
                wSmall, wMedium, wLarge, wGigantic = 0.50, 0.35, 0.13, 0.02
            end

            -- Normalizar pesos
            do
                local sum = wSmall + wMedium + wLarge + wGigantic
                if sum <= 0 then sum = 1 end
                wSmall, wMedium, wLarge, wGigantic = wSmall/sum, wMedium/sum, wLarge/sum, wGigantic/sum
            end

            -- Selección ponderada
            local r = rng:random()
            local tierName, tdef
            if r < wSmall then
                tierName, tdef = "small", tiers.small
            elseif r < wSmall + wMedium then
                tierName, tdef = "medium", tiers.medium
            elseif r < wSmall + wMedium + wLarge then
                tierName, tdef = "large", tiers.large
            else
                tierName, tdef = "gigantic", tiers.gigantic
            end
            local baseScale = (MapConfig.nebulae and MapConfig.nebulae.baseSizeScale) or 1.25
            local sizeBasePx = rng:randomInt(tdef.min, tdef.max)
            local finalSize = sizeBasePx * MapConfig.chunk.worldScale * baseScale

            -- CORRECCIÓN: Generar seed primero para evitar error lógico
            local nebulaSeed = rng:randomRange(0.0, 10000.0)
            
            local nebula = {
                type = MapConfig.ObjectType.NEBULA,
                x = x * MapConfig.chunk.tileSize,
                y = y * MapConfig.chunk.tileSize,
                -- Tamaño según tier (reemplaza al tamaño fijo anterior)
                size = finalSize,
                sizeTier = tierName,
                -- SECCIÓN DE DETERMINACIÓN DE COLOR DE NEBULOSAS:
                -- Esta sección utiliza el sistema de armonía cromática para generar
                -- colores vibrantes y coherentes basados en:
                -- 1. El tipo de bioma del chunk
                -- 2. Una semilla específica para la nebulosa
                -- 3. Paletas astronómicas predefinidas o armonías procedurales
                color = (function()
                    local ok, nebColor = pcall(ColorHarmony.generateNebulaColor, rng, localBiome, math.floor(nebulaSeed))
                    if ok and type(nebColor) == "table" then
                        return nebColor
                    end
                    return {0.8, 0.6, 0.2, 0.35}
                end)(),
                intensity = rng:randomRange(0.30, 0.70),
                biomeType = localBiome,
                globalX = globalX,
                globalY = globalY
            }

            -- Color y propiedades de energía (Forma A: Mono-Tono / Forma B: Bi-Tonal)
            nebula.coreColor = (nebula.color and nebula.color.core) or nebula.color
            nebula.colorMode = (nebula.color and nebula.color.mode) or "A"
            nebula.harmony = (nebula.color and nebula.color.harmony) or "cosmic"
            nebula.energyStyle = (nebula.color and nebula.color.energyStyle) or "Standard"
            nebula.sparkleStrength = (nebula.color and nebula.color.sparkle) or 0.0

            -- Parámetros morfológicos y de orientación aleatoria libre
            nebula.rotation     = rng:randomRange(0, math.pi * 2)
            nebula.aspectRatio  = rng:randomRange(0.72, 1.38)
            nebula.irregularity = rng:randomRange(0.22, 0.52)

            -- Selección morfológica ponderada según el bioma cósmico:
            -- 0: Difusa, 1: Anular (Ring/Burbuja), 2: Bipolar (Alas/Reloj de arena), 3: Filamentosa
            local morphRoll = rng:random()
            if localBiome == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
                nebula.morphology = (morphRoll < 0.40 and 3) or (morphRoll < 0.70 and 2) or 0
            elseif localBiome == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
                nebula.morphology = (morphRoll < 0.45 and 1) or (morphRoll < 0.75 and 2) or 0
            elseif localBiome == BiomeSystem.BiomeType.DEEP_SPACE then
                nebula.morphology = (morphRoll < 0.35 and 3) or 0
            else
                nebula.morphology = (morphRoll < 0.22 and 1) or (morphRoll < 0.42 and 2) or (morphRoll < 0.62 and 3) or 0
            end

            -- Parámetros aleatorios para el shader de domain warping + parallax
            nebula.seed       = nebulaSeed
            nebula.noiseScale = rng:randomRange(1.6, 3.6)
            nebula.warpAmp    = rng:randomRange(0.35, 1.00)
            nebula.warpFreq   = rng:randomRange(0.7,  2.0)
            nebula.softness   = rng:randomRange(0.18, 0.40)

            -- Parallax por-nebulosa: más grande => más “cerca” (parallax mayor)
            local sizeFactor = math.min(1.0, (nebula.size / (MapConfig.nebulae.parallaxSizeThreshold * MapConfig.chunk.worldScale)))
            nebula.parallax  = math.min(0.95, MapConfig.nebulae.minParallax + sizeFactor * (MapConfig.nebulae.maxSizeMinParallax - MapConfig.nebulae.minParallax) + rng:randomRange(0, 0.10))

            -- Brillo base por-nebulosa (usado por el renderer)
            nebula.brightness = rng:randomRange(1.10, 1.22)

            -- Modulaciones físicas y energéticas según el bioma (Opción A)
            local bType = localBiome
            if bType == BiomeSystem.BiomeType.NEBULA_FIELD then
                nebula.size = nebula.size * rng:randomRange(1.30, MapConfig.nebulae.fieldSizeMultiplierMax)
                nebula.intensity = nebula.intensity * rng:randomRange(1.20, 1.70)
                nebula.warpAmp    = (nebula.warpAmp or 0.5) * rng:randomRange(1.10, 1.40)
                nebula.noiseScale = (nebula.noiseScale or 2.5) * rng:randomRange(1.05, 1.25)
                nebula.brightness = rng:randomRange(1.30, 1.45)
            elseif bType == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
                nebula.size = nebula.size * rng:randomRange(0.85, 1.35)
                nebula.intensity = nebula.intensity * rng:randomRange(1.25, 1.65)
                nebula.warpAmp = (nebula.warpAmp or 0.5) * rng:randomRange(1.20, 1.45)
                nebula.softness = math.max(0.15, (nebula.softness or 0.25) - 0.06)
                nebula.brightness = rng:randomRange(1.25, 1.42)
                nebula.sparkleStrength = math.max(nebula.sparkleStrength or 0.0, rng:randomRange(0.25, 0.50))
            elseif bType == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
                nebula.size = nebula.size * rng:randomRange(0.90, 1.40)
                nebula.intensity = nebula.intensity * rng:randomRange(1.15, 1.50)
                nebula.warpAmp = (nebula.warpAmp or 0.5) * rng:randomRange(1.30, 1.60)
                nebula.warpFreq = (nebula.warpFreq or 1.0) * rng:randomRange(0.70, 0.90)
                nebula.softness = math.max(0.14, (nebula.softness or 0.25) - 0.08)
            elseif bType == BiomeSystem.BiomeType.ANCIENT_RUINS then
                nebula.sparkleStrength = math.max(nebula.sparkleStrength or 0.0, rng:randomRange(0.15, 0.35))
                nebula.brightness = rng:randomRange(1.20, 1.35)
            elseif bType == BiomeSystem.BiomeType.DEEP_SPACE then
                nebula.softness = math.min(0.48, (nebula.softness or 0.25) + 0.08)
                nebula.brightness = rng:randomRange(1.05, 1.18)
            end

            limitNebulaHalo(nebula, blend)
            table.insert(nebulaObjects, nebula)
        end
    end

    chunk.objects.nebulae = nebulaObjects
end

-- Generar objetos especiales balanceados
function MapGenerator.generateBalancedSpecialObjects(chunk, chunkX, chunkY, densities, rng)
    chunk.specialObjects = {}
    
    local stationDensity = densities.stations or MapConfig.density.stations
    local wormholeDensity = densities.wormholes or MapConfig.density.wormholes

    -- NUEVO: modulación por blend A/B del chunk para probabilidad adicional suave
    local BT = BiomeSystem.BiomeType
    local wRu, wGa, wNeb, wDeep = 0, 0, 0, 0
    do
        local b = chunk.biomeBlend
        if b and b.biomeA and b.biomeB then
            local t = math.max(0, math.min(1, b.blend or 0))
            local wA, wB = 1 - t, t
            wRu   = ((b.biomeA == BT.ANCIENT_RUINS)   and wA or 0) + ((b.biomeB == BT.ANCIENT_RUINS)   and wB or 0)
            wGa   = ((b.biomeA == BT.GRAVITY_ANOMALY)  and wA or 0) + ((b.biomeB == BT.GRAVITY_ANOMALY)  and wB or 0)
            wNeb  = ((b.biomeA == BT.NEBULA_FIELD)     and wA or 0) + ((b.biomeB == BT.NEBULA_FIELD)     and wB or 0)
            wDeep = ((b.biomeA == BT.DEEP_SPACE)       and wA or 0) + ((b.biomeB == BT.DEEP_SPACE)       and wB or 0)
        end
    end

    -- NUEVO: presencia en el centro del chunk (suficiente para objetos raros)
    local weights = chunk.biomeBlend.weights
    local presenceRu = weights[BT.ANCIENT_RUINS]
    local presenceGa = weights[BT.GRAVITY_ANOMALY]
    local presenceDeep = weights[BT.DEEP_SPACE]

    local addProbStation  = math.max(0, math.min(0.10, 0.20 * wRu + 0.05 * wGa + 0.05 * wNeb - 0.05 * wDeep))
    local addProbWormhole = math.max(0, math.min(0.20, 0.30 * wGa + 0.10 * wRu + 0.05 * wNeb - 0.05 * wDeep))

    -- NUEVO: sumar componente por presencia (formación de islas grandes multi-chunk)
    addProbStation  = math.max(0, math.min(0.25, addProbStation  + 0.25 * presenceRu  + 0.10 * presenceGa - 0.10 * presenceDeep))
    addProbWormhole = math.max(0, math.min(0.35, addProbWormhole + 0.35 * presenceGa  + 0.10 * presenceRu - 0.10 * presenceDeep))

    -- Estaciones
    local stationNoise = MapGenerator.multiOctaveNoise(chunkX, chunkY, 2, 0.5, 0.01)
    if stationNoise < stationDensity or (addProbStation > 0 and rng:random() < addProbStation) then
        local station = {
            type = MapConfig.ObjectType.STATION,
            x = rng:randomInt(0, MapConfig.chunk.size - 1) * MapConfig.chunk.tileSize,
            y = rng:randomInt(0, MapConfig.chunk.size - 1) * MapConfig.chunk.tileSize,
            size = rng:randomInt(18, 40) * MapConfig.chunk.worldScale,
            rotation = rng:random() * math.pi * 2,
            active = true,
            biomeType = chunk.biome.type
        }
        table.insert(chunk.specialObjects, station)
    end
    
    -- Wormholes
    local wormholeNoise = MapGenerator.multiOctaveNoise(chunkX + 0.5, chunkY + 0.5, 2, 0.5, 0.01)
    if wormholeNoise < wormholeDensity or (addProbWormhole > 0 and rng:random() < addProbWormhole) then
        local wormhole = {
            type = MapConfig.ObjectType.WORMHOLE,
            x = rng:randomInt(0, MapConfig.chunk.size - 1) * MapConfig.chunk.tileSize,
            y = rng:randomInt(0, MapConfig.chunk.size - 1) * MapConfig.chunk.tileSize,
            size = rng:randomInt(15, 25) * MapConfig.chunk.worldScale,
            pulsePhase = rng:random() * math.pi * 2,
            active = true,
            biomeType = chunk.biome.type
        }
        table.insert(chunk.specialObjects, wormhole)
    end

    -- Fallback en Gravity Anomaly: ahora ponderado por su peso en el blend
    if chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
        local hasWormhole = false
        for _, obj in ipairs(chunk.specialObjects) do
            if obj.type == MapConfig.ObjectType.WORMHOLE then
                hasWormhole = true
                break
            end
        end
        local extraChance = 0.25 + 0.50 * wGa  -- más chance si el blend favorece Gravity
        if not hasWormhole and rng:random() < math.min(0.8, extraChance) then
            local wormhole = {
                type = MapConfig.ObjectType.WORMHOLE,
                x = rng:randomInt(0, MapConfig.chunk.size - 1) * MapConfig.chunk.tileSize,
                y = rng:randomInt(0, MapConfig.chunk.size - 1) * MapConfig.chunk.tileSize,
                size = rng:randomInt(16, 28) * MapConfig.chunk.worldScale,
                pulsePhase = rng:random() * math.pi * 2,
                active = true,
                biomeType = chunk.biome.type
            }
            table.insert(chunk.specialObjects, wormhole)
        end
    end

    -- Entradas de Subnivel (deterministas y parte de la seed principal)
    -- Nota: se generan como objetos especiales ligeros para que queden registradas en el mapa.
    -- Su ejecución seguirá siendo aislada al entrar en la SubLevelScene.
    do
        -- Probabilidad base muy baja, modulada suavemente por presencia de ruinas
        local baseChance = 0.015
        local addProbEntrance = math.max(0, math.min(0.12, baseChance + 0.20 * presenceRu + 0.05 * wRu))
        local entranceNoise = MapGenerator.multiOctaveNoise(chunkX * 1.31, chunkY * 1.73, 2, 0.5, 0.01)
        if entranceNoise < baseChance or (addProbEntrance > 0 and rng:random() < addProbEntrance) then
            -- Posicionar preferentemente cerca del centro del chunk (estable y visible)
            local cx = math.floor(MapConfig.chunk.size * 0.5) * MapConfig.chunk.tileSize
            local cy = math.floor(MapConfig.chunk.size * 0.5) * MapConfig.chunk.tileSize
            local entrance = {
                -- Usar el enum de MapConfig para que el renderer lo detecte correctamente
                type = MapConfig.ObjectType.SUBLEVEL_ENTRANCE,
                x = cx,
                y = cy,
                size = 22 * (MapConfig.chunk.worldScale or 1),
                active = true,
                biomeType = chunk.biome and chunk.biome.type or nil,
                -- Metadatos deterministas mínimos para reconstruir el cfg después
                entranceType = "GENERIC",
                cx = chunkX,
                cy = chunkY,
                -- Clave determinista basada en coordenadas del chunk (se combinará con la seed padre al entrar)
                entranceKey = tostring(chunkX) .. ":" .. tostring(chunkY)
            }
            table.insert(chunk.specialObjects, entrance)
        end
    end
end

-- Generar estrellas balanceadas
function MapGenerator.generateBalancedStars(chunk, chunkX, chunkY, densities, rng)
    local stars = {}
    local starDensity = densities.stars or MapConfig.density.stars
    local BT = BiomeSystem.BiomeType
    local factorByBiome = {1.8, 1.5, 1.2, 1.3, 2.0, 1.3}
    local capStars = MapConfig.spawn.caps.stars_per_chunk_max
    local sectorsPerSide = 5
    local sectorSize = MapConfig.chunk.size * MapConfig.chunk.tileSize / sectorsPerSide
    local colors = MapConfig.colors.stars
    local colorCount = #colors
    local starConfigs = {
        [1] = {minS = 1, maxS = 2,  minD = 0.85, maxD = 0.95},
        [2] = {minS = 2, maxS = 3,  minD = 0.70, maxD = 0.85},
        [3] = {minS = 3, maxS = 4,  minD = 0.50, maxD = 0.70},
        [4] = {minS = 3, maxS = 5,  minD = 0.30, maxD = 0.50},
        [5] = {minS = 4, maxS = 6,  minD = 0.15, maxD = 0.30},
        [6] = {minS = 5, maxS = 8,  minD = 0.05, maxD = 0.15}
    }
    
    for sectorY = 0, sectorsPerSide - 1 do
        for sectorX = 0, sectorsPerSide - 1 do
            local localBiome = chunk.biome.type
            local density, factor = starDensity, factorByBiome[localBiome] or 1.3
            if chunk.biomeBlend then
                local cx = chunkX + (sectorX + 0.5) / sectorsPerSide
                local cy = chunkY + (sectorY + 0.5) / sectorsPerSide
                local blend = BiomeSystem.sampleBiomeBlend(cx, cy)
                local params = BiomeSystem.generateSpaceParameters(cx, cy, true)
                density = BiomeSystem.modifyDensitiesBlended(MapConfig.density, blend, cx, cy, params).stars
                localBiome, factor = blend.biomeA, 0
                for t, weight in ipairs(blend.weights) do factor = factor + weight * factorByBiome[t] end
            end
            local expected = math.floor(MapConfig.chunk.size^2 * density * 0.2) * factor
            local desired = _scaledCount(math.floor(expected + 0.5), capStars)
            local sectorStars = math.ceil(desired / (sectorsPerSide * sectorsPerSide))
            if rng:random() < 0.3 then
                sectorStars = sectorStars + rng:randomInt(1, 3)
            end
            
            for i = 1, sectorStars do
                -- Antes: usábamos 0.1..0.9 del sector, dejando un margen vacío en el borde del chunk
                -- Ahora: rango completo 0..1 del sector para continuidad entre chunks
                local x = sectorX * sectorSize + rng:randomRange(0, sectorSize)
                local y = sectorY * sectorSize + rng:randomRange(0, sectorSize)
                
                local roll = rng:randomInt(1, 100)
                local starType =
                      (roll <= 30) and 1
                   or (roll <= 50) and 2
                   or (roll <= 65) and 3
                   or (roll <= 80) and 4
                   or (roll <= 92) and 5
                   or 6
                
                if localBiome == BiomeSystem.BiomeType.DEEP_SPACE and rng:random() < 0.25 then
                    starType = math.min(6, starType + 1)
                end
                
                local cfg = starConfigs[starType]
                local size = rng:randomRange(cfg.minS, cfg.maxS)
                local depth = cfg.minD + rng:random() * (cfg.maxD - cfg.minD)
                
                local rpick = rng:random()
                local brightness
                if rpick < 0.15 then
                    brightness = 1.3 + rng:random() * 0.5
                elseif rpick < 0.55 then
                    brightness = 0.9 + rng:random() * 0.3
                else
                    brightness = 0.7 + rng:random() * 0.2
                end
                if starType == 4 then brightness = brightness * 1.15 end
                brightness = math.min(brightness, 2.0)
                
                local star = {
                    x = x + (rng:random() - 0.5) * 0.4,
                    y = y + (rng:random() - 0.5) * 0.4,
                    size = size,
                    type = starType,
                    color = colors[rng:randomInt(1, colorCount)],
                    twinkle = rng:random() * math.pi * 2,
                    twinkleSpeed = rng:randomRange(0.5, 3.0),
                    depth = depth,
                    brightness = brightness,
                    pulsePhase = rng:random() * math.pi * 2,
                    biomeType = localBiome
                }
                table.insert(stars, star)
            end
        end
    end
    
    chunk.objects.stars = stars
end

-- Generar chunk completo
function MapGenerator.generateChunk(chunkX, chunkY)
    -- Despachar a modo subnivel si está activo
    if MapGenerator.subLevelMode and MapGenerator.subLevelMode.active then
        local cfg = MapGenerator.subLevelMode.config or {}
        local rng = SeedSystem.makeRNG(cfg.numericSeed or 0)
        return MapGenerator.generateSubLevelChunk(chunkX, chunkY, cfg, rng)
    end
    local chunk = {
        x = chunkX,
        y = chunkY,
        tiles = {},
        objects = {stars = {}, nebulae = {}},
        specialObjects = {},
        bounds = (function()
            local sizePixels = MapConfig.chunk.size * MapConfig.chunk.tileSize
            local spacing = MapConfig.chunk.spacing or 0
            local stride = sizePixels + spacing
            local left = chunkX * stride
            local top = chunkY * stride
            return {
                left = left,
                top = top,
                right = left + stride,
                bottom = top + stride
            }
        end)()
    }
    
    -- Determinar bioma
    local biomeInfo = BiomeSystem.getBiomeInfo(chunkX, chunkY)
    chunk.biome = biomeInfo

    -- Guardar campos ambientales normalizados y mezcla de biomas
    do
        local p = biomeInfo.parameters or {}
        local temp = ((p.energy or 0) + 1) * 0.5
        local moist = ((p.density or 0) + 1) * 0.5
        local elev = (p.depth ~= nil) and p.depth or 0.5
        chunk.env = { temp = temp, moist = moist, elev = elev }

        chunk.biomeBlend = biomeInfo.blend
    end

    -- Crear RNG determinista por chunk
    local baseSeed = BiomeSystem.numericSeed or 0
    local rngSeed = string.format("%d:%d:%d", baseSeed, chunkX, chunkY)
    local rng = SeedSystem.makeRNG(rngSeed)

    -- Inicializar tiles
    for y = 0, MapConfig.chunk.size - 1 do
        chunk.tiles[y] = {}
        for x = 0, MapConfig.chunk.size - 1 do
            chunk.tiles[y][x] = MapConfig.ObjectType.EMPTY
        end
    end

    -- Densidades modificadas por bioma (una sola vez para consistencia)
    -- local modified = BiomeSystem.modifyDensities(MapConfig.density, biomeInfo.type, chunkX, chunkY)
    local modified = BiomeSystem.modifyDensitiesBlended(MapConfig.density, chunk.biomeBlend, chunkX, chunkY, biomeInfo.parameters)
    
    if MapGenerator.debugLogs then
        local t0 = love.timer.getTime()
        MapGenerator.generateBalancedAsteroids(chunk, chunkX, chunkY, modified, rng)
        local t1 = love.timer.getTime()
        MapGenerator.generateBalancedNebulae(chunk, chunkX, chunkY, modified, rng)
        local t2 = love.timer.getTime()
        MapGenerator.generateBalancedSpecialObjects(chunk, chunkX, chunkY, modified, rng)
        local t3 = love.timer.getTime()
        MapGenerator.generateBalancedStars(chunk, chunkX, chunkY, modified, rng)
        local t4 = love.timer.getTime()
        print(string.format("[GenProfile] Chunk (%d,%d): Ast=%.2fms, Neb=%.2fms, Spec=%.2fms, Stars=%.2fms",
            chunkX, chunkY, (t1-t0)*1000, (t2-t1)*1000, (t3-t2)*1000, (t4-t3)*1000))
    else
        MapGenerator.generateBalancedAsteroids(chunk, chunkX, chunkY, modified, rng)
        MapGenerator.generateBalancedNebulae(chunk, chunkX, chunkY, modified, rng)
        MapGenerator.generateBalancedSpecialObjects(chunk, chunkX, chunkY, modified, rng)
        MapGenerator.generateBalancedStars(chunk, chunkX, chunkY, modified, rng)
    end

    -- IMPORTANTE: Asegurar que las características especiales de bioma SIEMPRE se generen
    -- BiomeSystem.generateSpecialFeatures(chunk, chunkX, chunkY, biomeInfo.type)
    BiomeSystem.generateSpecialFeaturesBlended(chunk, chunkX, chunkY, chunk.biomeBlend)

    -- Generar anomalías gravitacionales para el bioma gravity_anomaly
    local GravityAnomaly = require 'src.shaders.gravity_anomaly'
    GravityAnomaly.generateAnomalies(chunk, chunkX, chunkY, chunk.biome.type, rng)
    
    -- Generar placeholders para el bioma ancient_ruins
    local AncientRuinsRenderer = require 'src.maps.systems.ancient_ruins_renderer'
    AncientRuinsRenderer.generatePlaceholders(chunk, chunkX, chunkY, rng)

    -- Debug para verificar generación
    if #chunk.specialObjects > 0 then
        if MapGenerator.debugLogs then
            print(string.format("Chunk (%d,%d) - Biome: %s, SpecialObjects: %d",
                chunkX, chunkY, chunk.biome and chunk.biome.name or "Unknown", #chunk.specialObjects))
        end
    end

    return chunk
end

return MapGenerator