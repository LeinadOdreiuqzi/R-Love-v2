-- src/maps/systems/map_generator.lua
-- Sistema de generación de contenido del mapa

local MapGenerator = {}
local PerlinNoise = require 'src.maps.perlin_noise'
local BiomeSystem = require 'src.maps.biome_system'
local MapConfig = require 'src.maps.config.map_config'
local ColorHarmony = require 'src.utils.color_harmony'
local SeedSystem = require 'src.utils.seed_system'

MapGenerator.debugLogs = false
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

-- Generación densa y navegacional para ASTEROID_BELT
function MapGenerator.generateAsteroidBeltField(chunk, chunkX, chunkY, densities, rng)
    local size = MapConfig.chunk.size
    local ts = MapConfig.chunk.tileSize
    
    -- Inicializar el chunk vacío
    for y = 0, size - 1 do
        chunk.tiles[y] = {}
        for x = 0, size - 1 do
            chunk.tiles[y][x] = MapConfig.ObjectType.EMPTY
        end
    end
    
    local baseDensity = math.max(0.3, densities.asteroids or MapConfig.density.asteroids)
    
    -- Parámetros de la red de asteroides
    local cellSize = 4
    local jitter = 0.6
    local minDistance = 2.0
    local maxDistance = 4.0
    
    -- Generar puntos de la red
    local points = {}
    local wx = chunkX * size
    local wy = chunkY * size
    
    for gy = -1, math.ceil(size/cellSize) + 1 do
        for gx = -1, math.ceil(size/cellSize) + 1 do
            local nx = (wx + gx * cellSize) * 0.1
            local ny = (wy + gy * cellSize) * 0.1
            local jx = (PerlinNoise.noise(nx, ny, 123) - 0.5) * cellSize * jitter
            local jy = (PerlinNoise.noise(nx + 100, ny + 100, 456) - 0.5) * cellSize * jitter
            
            local x = gx * cellSize + jx
            local y = gy * cellSize + jy
            
            if x >= -cellSize and x < size + cellSize and y >= -cellSize and y < size + cellSize then
                table.insert(points, {x = x, y = y, size = 0})
            end
        end
    end
    
    -- Determinar tamaños
    for i, point in ipairs(points) do
        local noise = (PerlinNoise.noise(
            (wx + point.x) * 0.07, 
            (wy + point.y) * 0.07, 
            789
        ) + 1) * 0.5
        
        if rng:random() > baseDensity then
            point.size = -1
        else
            if noise > 0.8 then
                point.size = 2
            elseif noise > 0.5 then
                point.size = 1
            else
                point.size = 0
            end
        end
    end
    
    -- Conexiones (sin RNG, solo distancia)
    local connections = {}
    for i = 1, #points do
        connections[i] = {}
        for j = i + 1, #points do
            local dx = points[i].x - points[j].x
            local dy = points[i].y - points[j].y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            if dist <= maxDistance and (points[i].size >= 0 or points[j].size >= 0) then
                connections[i][j] = true
                connections[j] = connections[j] or {}
                connections[j][i] = true
            end
        end
    end
    
    -- Rellenar asteroides
    local asteroidsPlaced = 0
    local minAsteroids = math.floor(size * size * baseDensity * 0.5)
    
    for i, point in ipairs(points) do
        local x, y = math.floor(point.x + 0.5), math.floor(point.y + 0.5)
        if x >= 0 and x < size and y >= 0 and y < size and point.size >= 0 then
            local asteroidType
            if point.size == 2 then
                asteroidType = MapConfig.ObjectType.ASTEROID_LARGE
            elseif point.size == 1 then
                asteroidType = MapConfig.ObjectType.ASTEROID_MEDIUM
            else
                asteroidType = MapConfig.ObjectType.ASTEROID_SMALL
            end
            
            if chunk.tiles[y][x] == MapConfig.ObjectType.EMPTY then
                chunk.tiles[y][x] = asteroidType
                asteroidsPlaced = asteroidsPlaced + 1
                
                if point.size == 2 and rng:random() > 0.5 then
                    for dy = -1, 1 do
                        for dx = -1, 1 do
                            if (dx ~= 0 or dy ~= 0) and 
                               x + dx >= 0 and x + dx < size and 
                               y + dy >= 0 and y + dy < size and
                               chunk.tiles[y + dy][x + dx] == MapConfig.ObjectType.EMPTY and
                               rng:random() > 0.6 then
                                
                                chunk.tiles[y + dy][x + dx] = MapConfig.ObjectType.ASTEROID_SMALL
                                asteroidsPlaced = asteroidsPlaced + 1
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Forzar mínimo
    if asteroidsPlaced < minAsteroids then
        local attempts = 0
        while asteroidsPlaced < minAsteroids and attempts < minAsteroids * 2 do
            local x = math.floor(rng:random() * size)
            local y = math.floor(rng:random() * size)
            
            if chunk.tiles[y][x] == MapConfig.ObjectType.EMPTY then
                local sizeRoll = rng:random()
                if sizeRoll > 0.9 then
                    chunk.tiles[y][x] = MapConfig.ObjectType.ASTEROID_LARGE
                elseif sizeRoll > 0.7 then
                    chunk.tiles[y][x] = MapConfig.ObjectType.ASTEROID_MEDIUM
                else
                    chunk.tiles[y][x] = MapConfig.ObjectType.ASTEROID_SMALL
                end
                asteroidsPlaced = asteroidsPlaced + 1
            end
            attempts = attempts + 1
        end
    end
    
    -- Cobertura mínima
    local marked = 0
    local candidates = {}
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            if chunk.tiles[y][x] ~= MapConfig.ObjectType.EMPTY then
                marked = marked + 1
            else
                local noise = (PerlinNoise.noise(
                    (wx + x) * 0.1, 
                    (wy + y) * 0.1, 
                    321
                ) + 1) * 0.5
                
                if noise > 0.6 then
                    table.insert(candidates, {x = x, y = y, d = noise})
                end
            end
        end
    end
    
    local minFill = math.floor(size * size * 0.25)
    if marked < minFill and #candidates > 0 then
        table.sort(candidates, function(a, b) return a.d > b.d end)
        local idx = 1
        while marked < minFill and idx <= #candidates do
            local c = candidates[idx]
            if chunk.tiles[c.y][c.x] == MapConfig.ObjectType.EMPTY then
                chunk.tiles[c.y][c.x] = MapConfig.ObjectType.ASTEROID_SMALL
                marked = marked + 1
            end
            idx = idx + 1
        end
    end
    
    -- Crear espacios abiertos grandes (optimizado con distancia²)
    if rng:random() < 0.12 then
        local centerX = math.floor(rng:random() * (size - 12) + 6)
        local centerY = math.floor(rng:random() * (size - 12) + 6)
        local radius = 3 + math.floor(rng:random() * 3)
        
        local O = MapConfig.ObjectType
        local radius2 = radius * radius
        for y = 0, size - 1 do
            local row = chunk.tiles[y]
            local dy = (y - centerY)
            local dy2 = dy * dy
            for x = 0, size - 1 do
                local dx = (x - centerX)
                local d2 = dx * dx + dy2
                if d2 <= radius2 and row[x] ~= O.ASTEROID_LARGE then
                    row[x] = O.EMPTY
                end
            end
        end
    end
    
    return chunk
end

-- NUEVO: Continuidad en bordes del Asteroid Belt
-- Genera una "pluma" (feather) de asteroides medianos/grandes en chunks adyacentes
-- para evitar cortes cuadrados visibles en el límite del bioma.
function MapGenerator.applyAsteroidBeltFeather(chunk, chunkX, chunkY, densities, rng, strength)
    local size = MapConfig.chunk.size
    local O = MapConfig.ObjectType
    -- MEJORADO: densidad base más alta y escalada con strength
    local baseDensity = math.max(0.08, (densities.asteroids or MapConfig.density.asteroids) * 0.35)
    baseDensity = baseDensity * (0.5 + 0.5 * strength) -- escalar con strength

    local cellSize = 4
    local jitter = 0.6
    local wx = chunkX * size
    local wy = chunkY * size

    -- NUEVO: añadir distribución adicional más densa para mejor continuidad
    local extraDensity = strength * 0.15

    for gy = -1, math.ceil(size / cellSize) + 1 do
        for gx = -1, math.ceil(size / cellSize) + 1 do
            local nx = (wx + gx * cellSize) * 0.1
            local ny = (wy + gy * cellSize) * 0.1
            local jx = (PerlinNoise.noise(nx, ny, 123) - 0.5) * cellSize * jitter
            local jy = (PerlinNoise.noise(nx + 100, ny + 100, 456) - 0.5) * cellSize * jitter

            local x = gx * cellSize + jx
            local y = gy * cellSize + jy

            if x >= -cellSize and x < size + cellSize and y >= -cellSize and y < size + cellSize then
                -- Tamaño siguiendo el mismo campo del cinturón
                local ns = (PerlinNoise.noise((wx + x) * 0.07, (wy + y) * 0.07, 789) + 1) * 0.5
                local placeProb = baseDensity * math.max(0, math.min(1, strength or 0))
                
                -- NUEVO: probabilidad adicional para asteroides pequeños/medianos
                local extraProb = extraDensity * math.max(0, math.min(1, strength or 0))
                
                if rng:random() < (placeProb + extraProb) then
                    local tx = math.floor(x + 0.5)
                    local ty = math.floor(y + 0.5)
                    if tx >= 0 and tx < size and ty >= 0 and ty < size then
                        if chunk.tiles[ty][tx] == O.EMPTY then
                            -- MEJORADO: mejor distribución de tamaños con más variedad
                            if ns > 0.85 and strength > 0.6 then
                                chunk.tiles[ty][tx] = O.ASTEROID_LARGE
                            elseif ns > 0.45 then
                                chunk.tiles[ty][tx] = O.ASTEROID_MEDIUM
                            else
                                -- Más asteroides pequeños para llenar espacios
                                if rng:random() < (0.3 + 0.4 * strength) then
                                    chunk.tiles[ty][tx] = O.ASTEROID_SMALL
                                elseif rng:random() < 0.15 * strength then
                                    chunk.tiles[ty][tx] = O.ASTEROID_MEDIUM
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- NUEVO: añadir dispersión adicional para suavizar bordes
    if strength > 0.3 then
        local scatterCount = math.floor(size * size * 0.02 * strength)
        for i = 1, scatterCount do
            local x = rng:randomInt(0, size - 1)
            local y = rng:randomInt(0, size - 1)
            if chunk.tiles[y][x] == O.EMPTY then
                local globalX = chunkX * size + x
                local globalY = chunkY * size + y
                local noise = (PerlinNoise.noise(globalX * 0.05, globalY * 0.05, 999) + 1) * 0.5
                if noise > (0.6 - 0.2 * strength) then
                    if rng:random() < 0.7 then
                        chunk.tiles[y][x] = O.ASTEROID_SMALL
                    else
                        chunk.tiles[y][x] = O.ASTEROID_MEDIUM
                    end
                end
            end
        end
    end
end

-- Generar asteroides balanceados
function MapGenerator.generateBalancedAsteroids(chunk, chunkX, chunkY, densities, rng)
    local asteroidDensity = densities.asteroids or MapConfig.density.asteroids

    -- Peso del cinturón desde la mezcla A/B del chunk
    local beltWeight = 0
    if chunk.biomeBlend then
        local b = chunk.biomeBlend
        local BT = BiomeSystem.BiomeType
        if b.biomeA == BT.ASTEROID_BELT then
            beltWeight = 1 - (b.blend or 0)
        elseif b.biomeB == BT.ASTEROID_BELT then
            beltWeight = (b.blend or 0)
        end
    end

    -- Activar generación densa del cinturón cuando aplica
    if chunk.biome.type == BiomeSystem.BiomeType.ASTEROID_BELT or beltWeight >= 0.5 then
        return MapGenerator.generateAsteroidBeltField(chunk, chunkX, chunkY, densities, rng)
    end

    -- Generación estándar original
    local placed = 0
    local size = MapConfig.chunk.size
    local tiles = chunk.tiles
    local O = MapConfig.ObjectType
    local bt = chunk.biome.type

    -- NUEVO: configuración de sesgos/pesos (con override para Deep Space)
    local astCfg = MapConfig.asteroids or {}
    local steps = astCfg.sizeNoiseSteps or { large = 0.18, medium = 0.08 }
    local largeBias = astCfg.largeBias or 0.0
    local mediumBias = astCfg.mediumBias or 0.0
    local weights = astCfg.sizeWeights or { small = 0.30, medium = 0.45, large = 0.25 }
    if bt == BiomeSystem.BiomeType.DEEP_SPACE and astCfg.deepSpace then
        if astCfg.deepSpace.largeBias ~= nil then largeBias = astCfg.deepSpace.largeBias end
        if astCfg.deepSpace.sizeWeights ~= nil then weights = astCfg.deepSpace.sizeWeights end
    end

    local function chooseWeightedAsteroid(rng)
        local wSmall = weights.small or 0.0
        local wMedium = weights.medium or 0.0
        local wLarge = weights.large or 0.0
        local total = wSmall + wMedium + wLarge
        if total <= 0 then return O.ASTEROID_SMALL end
        local r = rng:random() * total
        if r <= wSmall then
            return O.ASTEROID_SMALL
        elseif r <= (wSmall + wMedium) then
            return O.ASTEROID_MEDIUM
        else
            return O.ASTEROID_LARGE
        end
    end

    for y = 0, size - 1 do
        local row = tiles[y]
        local globalY = chunkY * size + y
        for x = 0, size - 1 do
            local globalX = chunkX * size + x

            local noiseMain  = MapGenerator.multiOctaveNoise(globalX, globalY, 3, 0.5, 0.025)
            local noiseDetail = MapGenerator.multiOctaveNoise(globalX, globalY, 1, 0.3, 0.12)
            local combinedNoise = (noiseMain * 0.7 + noiseDetail * 0.3)
            
            local threshold = 0.20
            if bt == BiomeSystem.BiomeType.DEEP_SPACE then
                threshold = 0.25
                combinedNoise = combinedNoise * 0.9
            elseif bt == BiomeSystem.BiomeType.NEBULA_FIELD then
                threshold = 0.35
            elseif bt == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
                threshold = 0.18
            end

            -- Asignación de tamaños (orden descendente)
            if combinedNoise > (threshold + 0.18) then
                row[x] = O.ASTEROID_LARGE
                placed = placed + 1
            elseif combinedNoise > (threshold + 0.08) then
                row[x] = O.ASTEROID_MEDIUM
                placed = placed + 1
            elseif combinedNoise > threshold then
                row[x] = O.ASTEROID_SMALL
                placed = placed + 1
            end
            
            -- Asignación de tamaños con sesgo por pasos (steps) y bias
            local largeStep = (steps.large or 0.18) - (largeBias or 0.0)
            local mediumStep = (steps.medium or 0.08) - (mediumBias or 0.0)
            if combinedNoise > (threshold + largeStep) then
                row[x] = O.ASTEROID_LARGE
                placed = placed + 1
            elseif combinedNoise > (threshold + mediumStep) then
                row[x] = O.ASTEROID_MEDIUM
                placed = placed + 1
            elseif combinedNoise > threshold then
                row[x] = O.ASTEROID_SMALL
                placed = placed + 1
            end
            
            -- Relleno aleatorio leve: desactivado en Deep Space, ponderado en el resto
            if bt ~= BiomeSystem.BiomeType.DEEP_SPACE then
                local randomFactor = rng:random()
                if randomFactor < asteroidDensity * 0.08 then
                    if row[x] == O.EMPTY then
                        row[x] = chooseWeightedAsteroid(rng)
                    end
                end
            end
        end
    end

    -- Cobertura mínima por bioma (sin cambios)
    local totalTiles = size * size
    local minRatioByBiome = {
        [BiomeSystem.BiomeType.DEEP_SPACE] = 0.005,
        [BiomeSystem.BiomeType.NEBULA_FIELD] = 0.02,
        [BiomeSystem.BiomeType.ASTEROID_BELT] = 0.0,
        [BiomeSystem.BiomeType.GRAVITY_ANOMALY] = 0.015,
        [BiomeSystem.BiomeType.RADIOACTIVE_ZONE] = 0.01,
        [BiomeSystem.BiomeType.ANCIENT_RUINS] = 0.008
    }
    local minNeeded = math.floor(totalTiles * (minRatioByBiome[bt] or 0.01))
    if placed < minNeeded then
        local toAdd = minNeeded - placed
        local attempts = 0
        while toAdd > 0 and attempts < totalTiles * 2 do
            attempts = attempts + 1
            local rx = rng:randomInt(0, size - 1)
            local ry = rng:randomInt(0, size - 1)
            local row = tiles[ry]
            if row[rx] == O.EMPTY then
                -- NUEVO: usar pesos
                row[rx] = chooseWeightedAsteroid(rng)
                toAdd = toAdd - 1
            end
        end
    end

    -- NUEVO: Feather de transición hacia el ASTEROID_BELT para evitar bordes cuadrados
    do
        local bt = chunk.biome.type
        if beltWeight > 0 and bt ~= BiomeSystem.BiomeType.ASTEROID_BELT then
            -- Fuerza en función de la presencia del cinturón en la mezcla (más cerca, más fuerte)
            -- MEJORADO: transición más suave y extendida
            local baseStrength = math.max(0.0, math.min(1.0, beltWeight * 1.2))
            local strength = baseStrength
            
            -- Aplicar curva suave para transición más gradual
            strength = strength * strength * (3.0 - 2.0 * strength) -- smoothstep
            
            -- Extender el rango de influencia para Deep Space
            if bt == BiomeSystem.BiomeType.DEEP_SPACE then
                strength = math.max(strength, beltWeight * 0.6) -- mínimo 60% del peso
            end
            
            if strength > 0.05 then -- umbral más bajo para activar
                MapGenerator.applyAsteroidBeltFeather(chunk, chunkX, chunkY, densities, rng, strength)
            end
        end
    end

    -- NUEVO: Ajuste de densidad y filtro de clústeres SOLO para Deep Space (con sensibilidad al borde del cinturón)
    if bt == BiomeSystem.BiomeType.DEEP_SPACE then
        local minClusterSizeBase = (MapConfig.asteroids and MapConfig.asteroids.deepSpaceClusterMinSize) or 12
        -- MEJORADO: reducción más agresiva cerca del borde del cinturón para preservar la continuidad visual
        local edgeFactor = 1.0
        if beltWeight > 0 then
            -- Reducir significativamente el tamaño mínimo de clúster cerca del cinturón
            local t = math.min(0.7, beltWeight) / 0.7 -- extender el rango de influencia
            edgeFactor = 1.0 - 0.7 * t -- reducir hasta 70% del tamaño mínimo
        end
        local minClusterSize = math.max(3, math.floor(minClusterSizeBase * edgeFactor + 0.5))
        
        -- Prep visited
        local visited = {}
        for y = 0, size - 1 do visited[y] = {} end

        local function isAst(x, y)
            local v = tiles[y][x]
            return v == O.ASTEROID_SMALL or v == O.ASTEROID_MEDIUM or v == O.ASTEROID_LARGE
        end

        local neigh = {
            {-1,-1},{0,-1},{1,-1},
            {-1, 0},        {1, 0},
            {-1, 1},{0, 1},{1, 1},
        }

        local function bfs(sx, sy)
            local q = {{x = sx, y = sy}}
            visited[sy][sx] = true
            local cluster = {{x = sx, y = sy}}
            local count = 1
            local hasMedOrLarge = (tiles[sy][sx] == O.ASTEROID_MEDIUM) or (tiles[sy][sx] == O.ASTEROID_LARGE)

            local qi = 1
            while q[qi] do
                local n = q[qi]; qi = qi + 1
                for i = 1, #neigh do
                    local dx, dy = neigh[i][1], neigh[i][2]
                    local nx, ny = n.x + dx, n.y + dy
                    if nx >= 0 and nx < size and ny >= 0 and ny < size then
                        if not visited[ny][nx] and isAst(nx, ny) then
                            visited[ny][nx] = true
                            table.insert(cluster, {x = nx, y = ny})
                            table.insert(q, {x = nx, y = ny})
                            count = count + 1
                            local v = tiles[ny][nx]
                            if v == O.ASTEROID_MEDIUM or v == O.ASTEROID_LARGE then
                                hasMedOrLarge = true
                            end
                        end
                    end
                end
            end

            return cluster, count, hasMedOrLarge
        end

        for y = 0, size - 1 do
            for x = 0, size - 1 do
                if not visited[y][x] and isAst(x, y) then
                    local cluster, count, hasMedOrLarge = bfs(x, y)
                    -- Mantener sólo clústeres suficientemente grandes Y que contengan medium o large
                    if (count < minClusterSize) or (not hasMedOrLarge) then
                        for i = 1, #cluster do
                            local p = cluster[i]
                            tiles[p.y][p.x] = O.EMPTY
                        end
                    end
                end
            end
        end
    end
end

-- Generar nebulosas balanceadas
function MapGenerator.generateBalancedNebulae(chunk, chunkX, chunkY, densities, rng)
    local nebulaObjects = {}
    local nebulaDensity = densities.nebulae or MapConfig.density.nebulae
    
    local baseNumNebulae = math.max(1, math.floor(nebulaDensity * 0.8))
    local maxNebulae = 14

    local numNebulae
    if chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
        numNebulae = math.min(4, baseNumNebulae * 2)
    elseif chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
        -- Aumentar notablemente la cantidad en NEBULA_FIELD
        numNebulae = math.min(maxNebulae, math.max(baseNumNebulae * 8, 7))
    elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
        numNebulae = math.min(maxNebulae, math.max(baseNumNebulae * 3, 2))
    elseif chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
        numNebulae = math.min(6, math.max(baseNumNebulae * 2, 2))
    else
        numNebulae = math.min(6, math.max(baseNumNebulae * 2, 1))
    end

    for i = 1, numNebulae do
        local x = rng:randomInt(0, MapConfig.chunk.size - 1)
        local y = rng:randomInt(0, MapConfig.chunk.size - 1)
        local globalX = chunkX * MapConfig.chunk.size + x
        local globalY = chunkY * MapConfig.chunk.size + y
        
        local nebulaChance = MapGenerator.multiOctaveNoise(globalX, globalY, 3, 0.5, 0.035)
        local threshold = 0.18

        if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
            threshold = 0.0
        elseif chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
            threshold = 0.28
        elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
            threshold = 0.10
        elseif chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
            threshold = 0.15
        end

        -- NUEVO: modulación por blend A/B del chunk
        local addProb = 0
        do
            local BT = BiomeSystem.BiomeType
            local offsets = {
                [BT.DEEP_SPACE]       =  0.08,  -- menos nebulosas
                [BT.NEBULA_FIELD]     = -0.12,  -- más nebulosas
                [BT.RADIOACTIVE_ZONE] = -0.04,  -- más nebulosas
                [BT.GRAVITY_ANOMALY]  = -0.02,  -- un poco más
                [BT.ASTEROID_BELT]    =  0.06,  -- menos nebulosas
                [BT.ANCIENT_RUINS]    =  0.00
            }
            local b = chunk.biomeBlend
            if b and b.biomeA and b.biomeB then
                local t = math.max(0, math.min(1, b.blend or 0))
                local wA, wB = 1 - t, t
                local bt = chunk.biome.type
                local currOffset = offsets[bt] or 0
                local blendOffset = (offsets[b.biomeA] or 0) * wA + (offsets[b.biomeB] or 0) * wB
                threshold = math.max(0.0, math.min(0.5, threshold + (blendOffset - currOffset)))

                -- Probabilidad extra suave para “rellenar” en transición
                local wNeb = ((b.biomeA == BT.NEBULA_FIELD) and wA or 0) + ((b.biomeB == BT.NEBULA_FIELD) and wB or 0)
                local wRad = ((b.biomeA == BT.RADIOACTIVE_ZONE) and wA or 0) + ((b.biomeB == BT.RADIOACTIVE_ZONE) and wB or 0)
                local wDeep= ((b.biomeA == BT.DEEP_SPACE) and wA or 0) + ((b.biomeB == BT.DEEP_SPACE) and wB or 0)
                addProb = math.max(0, wNeb * 0.25 + wRad * 0.10 - wDeep * 0.10)
            end
        end

        -- NUEVO: presencia continua del bioma NEBULA_FIELD en el punto candidato
        local u = globalX / MapConfig.chunk.size
        local v = globalY / MapConfig.chunk.size
        local presenceNeb = BiomeSystem.sampleBiomePresence(BiomeSystem.BiomeType.NEBULA_FIELD, u, v)

        -- Baja el umbral en zonas de alta presencia (islas grandes de nebulosas)
        threshold = math.max(0.0, threshold - presenceNeb * 0.12)

        -- NUEVO: probabilidad adicional suave basada en presencia
        local addProbPresence = math.min(0.35, presenceNeb * 0.30)

        local shouldGenerate = false
        if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
            local p = math.max(0, math.min(0.85, 0.55 + addProb + addProbPresence))
            shouldGenerate = (nebulaChance > threshold) or (rng:random() < p)
        elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
            local p = math.max(0, math.min(0.70, 0.35 + addProb * 0.6 + addProbPresence * 0.6))
            shouldGenerate = (nebulaChance > threshold) or (rng:random() < p)
        else
            -- Dar una pequeña oportunidad adicional en transición
            local p = math.max(0, math.min(0.25, addProb * 0.3))
            shouldGenerate = (nebulaChance > threshold) or (p > 0 and rng:random() < p)
        end

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
            if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
                -- Más probabilidad de nebulosas grandes/“gigantescas”
                wSmall, wMedium, wLarge, wGigantic = 0.40, 0.38, 0.18, 0.04
            elseif chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
                -- Mayoría pequeñas/medianas
                wSmall, wMedium, wLarge, wGigantic = 0.75, 0.22, 0.03, 0.00
            elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
                wSmall, wMedium, wLarge, wGigantic = 0.55, 0.32, 0.11, 0.02
            elseif chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
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
                    local ok, nebColor = pcall(ColorHarmony.generateNebulaColor, rng, chunk.biome.type, math.floor(nebulaSeed))
                    if ok and type(nebColor) == "table" then
                        return nebColor
                    end
                    return {0.8, 0.6, 0.2, 0.35}
                end)(),
                intensity = rng:randomRange(0.30, 0.70),
                biomeType = chunk.biome.type,
                globalX = globalX,
                globalY = globalY
            }

            -- NUEVO: parámetros aleatorios para el shader de domain warping + parallax
            nebula.seed       = nebulaSeed
            nebula.noiseScale = rng:randomRange(1.6, 3.6)
            nebula.warpAmp    = rng:randomRange(0.35, 1.00)
            nebula.warpFreq   = rng:randomRange(0.7,  2.0)
            nebula.softness   = rng:randomRange(0.18, 0.40)

            -- Parallax por-nebulosa: más grande => más “cerca” (parallax mayor)
            local sizeFactor = math.min(1.0, (nebula.size / (220.0 * MapConfig.chunk.worldScale)))
            nebula.parallax  = math.min(0.95, 0.55 + sizeFactor * 0.35 + rng:randomRange(-0.05, 0.05))

            -- Brillo por-nebulosa (usado por el renderer): más alto en NEBULA_FIELD
            nebula.brightness = rng:randomRange(1.10, 1.20)

            if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
                nebula.size = nebula.size * rng:randomRange(1.30, 1.90)
                nebula.intensity = nebula.intensity * rng:randomRange(1.20, 1.70)
                -- Nebulosas más “tortuosas” en campos densos
                nebula.warpAmp    = (nebula.warpAmp or rng:randomRange(0.35, 1.00)) * rng:randomRange(1.10, 1.40)
                nebula.noiseScale = (nebula.noiseScale or rng:randomRange(1.6, 3.6)) * rng:randomRange(1.05, 1.25)
                -- subir brillo en NEBULA_FIELD
                nebula.brightness = rng:randomRange(1.30, 1.45)
            elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
                nebula.size = nebula.size * rng:randomRange(0.80, 1.30)
                nebula.intensity = nebula.intensity * rng:randomRange(1.20, 1.60)
                -- En zonas radioactivas preferimos verdes/ámbar intensos
                local ok, c = pcall(ColorHarmony.generateHarmonicPalette, rng, "analogous", {0.2, 0.9, 0.2}, 1)
                if ok and type(c) == "table" and c[1] then
                    nebula.color = c[1]
                else
                    nebula.color = {0.8, 0.6, 0.2, 0.5}
                end
                -- Un poco más finas
                nebula.softness = math.max(0.15, (nebula.softness or rng:randomRange(0.18, 0.40)) - 0.05)
            end

            table.insert(nebulaObjects, nebula)
        end
    end

    if (chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD) and (#nebulaObjects == 0) then
        local cx = math.floor(MapConfig.chunk.size * 0.5) * MapConfig.chunk.tileSize
        local cy = math.floor(MapConfig.chunk.size * 0.5) * MapConfig.chunk.tileSize
        local baseScale = (MapConfig.nebulae and MapConfig.nebulae.baseSizeScale) or 1.25
        table.insert(nebulaObjects, {
            type = MapConfig.ObjectType.NEBULA,
            x = cx, y = cy,
            size = rng:randomInt(120, 220) * MapConfig.chunk.worldScale * baseScale,
            -- Color armónico para el fallback central en NEBULA_FIELD
            color = (function()
                local ok, palette = pcall(ColorHarmony.generateRandomCoherentPalette, rng, 1)
                if ok and type(palette) == "table" and palette[1] then
                    return palette[1]
                end
                return {0.6, 0.4, 0.9, 0.35}
            end)(),
            intensity = rng:randomRange(0.25, 0.55),
            biomeType = chunk.biome.type,
            globalX = chunkX * MapConfig.chunk.size + math.floor(MapConfig.chunk.size * 0.5),
            globalY = chunkY * MapConfig.chunk.size + math.floor(MapConfig.chunk.size * 0.5)
        })
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
    local uMid = chunkX + 0.5
    local vMid = chunkY + 0.5
    local presenceRu  = BiomeSystem.sampleBiomePresence(BiomeSystem.BiomeType.ANCIENT_RUINS,   uMid, vMid)
    local presenceGa  = BiomeSystem.sampleBiomePresence(BiomeSystem.BiomeType.GRAVITY_ANOMALY, uMid, vMid)
    local presenceNeb = BiomeSystem.sampleBiomePresence(BiomeSystem.BiomeType.NEBULA_FIELD,    uMid, vMid)
    local presenceDeep= BiomeSystem.sampleBiomePresence(BiomeSystem.BiomeType.DEEP_SPACE,      uMid, vMid)

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
end

-- Generar estrellas balanceadas
function MapGenerator.generateBalancedStars(chunk, chunkX, chunkY, densities, rng)
    local stars = {}
    local starDensity = densities.stars or MapConfig.density.stars
    local baseNumStars = math.floor(MapConfig.chunk.size * MapConfig.chunk.size * starDensity * 0.2)
    
    -- Modulación por bioma y mezcla A/B
    local BT = BiomeSystem.BiomeType
    local factorByBiome = {
        [BT.RADIOACTIVE_ZONE] = 2.0,
        [BT.NEBULA_FIELD]     = 1.5,
        [BT.ASTEROID_BELT]    = 1.2,
        [BT.DEEP_SPACE]       = 1.8
    }
    local defaultFactor = 1.3
    local currFactor = factorByBiome[chunk.biome.type] or defaultFactor
    local numStarsFactor = currFactor

    local b = chunk.biomeBlend
    if b and b.biomeA and b.biomeB then
        local t = math.max(0, math.min(1, b.blend or 0))
        local wA, wB = 1 - t, t
        local fA = factorByBiome[b.biomeA] or defaultFactor
        local fB = factorByBiome[b.biomeB] or defaultFactor
        numStarsFactor = fA * wA + fB * wB
    end

    local numStars = baseNumStars * numStarsFactor

    -- NUEVO: escalar por worldScale^2 y aplicar cap por chunk
    local capStars = MapConfig.spawn and MapConfig.spawn.caps and MapConfig.spawn.caps.stars_per_chunk_max
    local desiredStars = _scaledCount(math.floor(numStars + 0.5), capStars)
    if desiredStars <= 0 then
        chunk.objects.stars = {}
        return
    end

    local sectorsPerSide = 5
    local sectorSize = MapConfig.chunk.size * MapConfig.chunk.tileSize / sectorsPerSide
    local starsPerSector = math.ceil(desiredStars / (sectorsPerSide * sectorsPerSide))
    
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
            local sectorStars = starsPerSector
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
                
                if chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE and rng:random() < 0.25 then
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
                    biomeType = chunk.biome.type
                }
                table.insert(stars, star)
            end
        end
    end
    
    chunk.objects.stars = stars
end

-- Generar chunk completo
function MapGenerator.generateChunk(chunkX, chunkY)
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

        local b = biomeInfo.blend or {}
        chunk.biomeBlend = {
            biomeA = b.biomeA or biomeInfo.type,
            biomeB = b.biomeB or biomeInfo.type,
            blend = math.max(0, math.min(1, b.blend or 0))
        }
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
    local modified = BiomeSystem.modifyDensitiesBlended(MapConfig.density, chunk.biomeBlend, chunkX, chunkY)
    
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
