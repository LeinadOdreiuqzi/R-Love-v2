-- src/maps/systems/map_generator.lua
-- Sistema de generación de contenido del mapa

local MapGenerator = {}
local PerlinNoise = require 'src.maps.perlin_noise'
local BiomeSystem = require 'src.maps.biome_system'
local MapConfig = require 'src.maps.config.map_config'
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

-- Generar asteroides balanceados
function MapGenerator.generateBalancedAsteroids(chunk, chunkX, chunkY, densities, rng)
    local asteroidDensity = densities.asteroids or MapConfig.density.asteroids
    if chunk.biome.type == BiomeSystem.BiomeType.ASTEROID_BELT then
        return MapGenerator.generateAsteroidBeltField(chunk, chunkX, chunkY, densities, rng)
    end
    
    local placed = 0
    local size = MapConfig.chunk.size
    local tiles = chunk.tiles
    local O = MapConfig.ObjectType
    local bt = chunk.biome.type

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
                combinedNoise = combinedNoise * 1.1
            elseif bt == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
                threshold = 0.4
            elseif bt == BiomeSystem.BiomeType.ANCIENT_RUINS then
                threshold = 0.45
            end
            
            if combinedNoise > threshold + 0.3 then
                row[x] = O.ASTEROID_LARGE
                placed = placed + 1
            elseif combinedNoise > threshold + 0.15 then
                row[x] = O.ASTEROID_MEDIUM
                placed = placed + 1
            elseif combinedNoise > threshold then
                row[x] = O.ASTEROID_SMALL
                placed = placed + 1
            end
            
            local randomFactor = rng:random()
            if randomFactor < asteroidDensity * 0.08 then
                if row[x] == O.EMPTY then
                    row[x] = O.ASTEROID_SMALL
                end
            end
        end
    end

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
                local roll = rng:random()
                if roll < 0.15 then
                    row[rx] = O.ASTEROID_LARGE
                elseif roll < 0.45 then
                    row[rx] = O.ASTEROID_MEDIUM
                else
                    row[rx] = O.ASTEROID_SMALL
                end
                toAdd = toAdd - 1
            end
        end
    end
end

-- Generar nebulosas balanceadas
function MapGenerator.generateBalancedNebulae(chunk, chunkX, chunkY, densities, rng)
    local nebulaObjects = {}
    local nebulaDensity = densities.nebulae or MapConfig.density.nebulae
    
    local baseNumNebulae = math.max(1, math.floor(nebulaDensity * 0.8))
    local maxNebulae = 8

    local numNebulae
    if chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
        numNebulae = math.min(4, baseNumNebulae * 2)
    elseif chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
        numNebulae = math.min(maxNebulae, math.max(baseNumNebulae * 5, 4))
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

        local shouldGenerate = false
        if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
            shouldGenerate = (nebulaChance > threshold) or (rng:random() < 0.55)
        elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
            shouldGenerate = (nebulaChance > threshold) or (rng:random() < 0.35)
        else
            shouldGenerate = nebulaChance > threshold
        end

        if shouldGenerate then
            local nebula = {
                type = MapConfig.ObjectType.NEBULA,
                x = x * MapConfig.chunk.tileSize,
                y = y * MapConfig.chunk.tileSize,
                size = rng:randomInt(80, 220) * MapConfig.chunk.worldScale,
                color = MapConfig.colors.nebulae[rng:randomInt(1, #MapConfig.colors.nebulae)],
                intensity = rng:randomRange(0.30, 0.70),
                biomeType = chunk.biome.type,
                globalX = globalX,
                globalY = globalY
            }
            if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
                nebula.size = nebula.size * rng:randomRange(1.30, 1.90)
                nebula.intensity = nebula.intensity * rng:randomRange(1.20, 1.70)
            elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
                nebula.size = nebula.size * rng:randomRange(0.80, 1.30)
                nebula.intensity = nebula.intensity * rng:randomRange(1.20, 1.60)
                nebula.color = {0.8, 0.6, 0.2, 0.5}
            end
            table.insert(nebulaObjects, nebula)
        end
    end

    if (chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD) and (#nebulaObjects == 0) then
        local cx = math.floor(MapConfig.chunk.size * 0.5) * MapConfig.chunk.tileSize
        local cy = math.floor(MapConfig.chunk.size * 0.5) * MapConfig.chunk.tileSize
        table.insert(nebulaObjects, {
            type = MapConfig.ObjectType.NEBULA,
            x = cx, y = cy,
            size = rng:randomInt(120, 220) * MapConfig.chunk.worldScale,
            color = MapConfig.colors.nebulae[rng:randomInt(1, #MapConfig.colors.nebulae)],
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

    local stationNoise = MapGenerator.multiOctaveNoise(chunkX, chunkY, 2, 0.5, 0.01)
    if stationNoise < stationDensity then
        local station = {
            type = MapConfig.ObjectType.STATION,
            x = rng:randomInt(10, MapConfig.chunk.size - 10) * MapConfig.chunk.tileSize,
            y = rng:randomInt(10, MapConfig.chunk.size - 10) * MapConfig.chunk.tileSize,
            size = rng:randomInt(18, 40) * MapConfig.chunk.worldScale,
            rotation = rng:random() * math.pi * 2,
            active = true,
            biomeType = chunk.biome.type
        }
        table.insert(chunk.specialObjects, station)
    end
    
    local wormholeNoise = MapGenerator.multiOctaveNoise(chunkX + 0.5, chunkY + 0.5, 2, 0.5, 0.01)
    if wormholeNoise < wormholeDensity then
        local wormhole = {
            type = MapConfig.ObjectType.WORMHOLE,
            x = rng:randomInt(8, MapConfig.chunk.size - 8) * MapConfig.chunk.tileSize,
            y = rng:randomInt(8, MapConfig.chunk.size - 8) * MapConfig.chunk.tileSize,
            size = rng:randomInt(15, 25) * MapConfig.chunk.worldScale,
            pulsePhase = rng:random() * math.pi * 2,
            active = true,
            biomeType = chunk.biome.type
        }
        table.insert(chunk.specialObjects, wormhole)
    end

    if chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
        local hasWormhole = false
        for _, obj in ipairs(chunk.specialObjects) do
            if obj.type == MapConfig.ObjectType.WORMHOLE then
                hasWormhole = true
                break
            end
        end
        if not hasWormhole and rng:random() < 0.25 then
            local wormhole = {
                type = MapConfig.ObjectType.WORMHOLE,
                x = rng:randomInt(8, MapConfig.chunk.size - 8) * MapConfig.chunk.tileSize,
                y = rng:randomInt(8, MapConfig.chunk.size - 8) * MapConfig.chunk.tileSize,
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
    
    local numStars = baseNumStars * 1.3
    if chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
        numStars = baseNumStars * 2.0
    elseif chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
        numStars = baseNumStars * 1.5
    elseif chunk.biome.type == BiomeSystem.BiomeType.ASTEROID_BELT then
        numStars = baseNumStars * 1.2
    elseif chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
        numStars = baseNumStars * 1.8
    end
    
    local sectorsPerSide = 5
    local sectorSize = MapConfig.chunk.size * MapConfig.chunk.tileSize / sectorsPerSide
    local starsPerSector = math.ceil(numStars / (sectorsPerSide * sectorsPerSide))
    
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
                local x = sectorX * sectorSize + rng:randomRange(sectorSize * 0.1, sectorSize * 0.9)
                local y = sectorY * sectorSize + rng:randomRange(sectorSize * 0.1, sectorSize * 0.9)
                
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
    local modified = BiomeSystem.modifyDensities(MapConfig.density, biomeInfo.type, chunkX, chunkY)

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
    BiomeSystem.generateSpecialFeatures(chunk, chunkX, chunkY, biomeInfo.type)

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
