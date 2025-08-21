-- src/maps/systems/map_generator.lua
-- Sistema de generación de contenido del mapa

local MapGenerator = {}
local PerlinNoise = require 'src.maps.perlin_noise'
local BiomeSystem = require 'src.maps.biome_system'
local MapConfig = require 'src.maps.config.map_config'

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
function MapGenerator.generateAsteroidBeltField(chunk, chunkX, chunkY, densities)
    local size = MapConfig.chunk.size
    local ts = MapConfig.chunk.tileSize
    
    -- Inicializar el chunk vacío
    for y = 0, size - 1 do
        chunk.tiles[y] = {}
        for x = 0, size - 1 do
            chunk.tiles[y][x] = MapConfig.ObjectType.EMPTY
        end
    end
    
    -- Ensure we have a minimum density for asteroid belts
    local baseDensity = math.max(0.3, densities.asteroids or MapConfig.density.asteroids)
    
    -- Generate a deterministic seed based on chunk position
    local seed = chunkX * 1619 + chunkY * 31337
    local function deterministicRandom()
        seed = (seed * 1664525 + 1013904223) % 2^32
        return seed / 2^32
    end
    
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
        
        if deterministicRandom() > baseDensity then
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
    
    -- Conexiones
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
                
                if point.size == 2 and deterministicRandom() > 0.5 then
                    for dy = -1, 1 do
                        for dx = -1, 1 do
                            if (dx ~= 0 or dy ~= 0) and 
                               x + dx >= 0 and x + dx < size and 
                               y + dy >= 0 and y + dy < size and
                               chunk.tiles[y + dy][x + dx] == MapConfig.ObjectType.EMPTY and
                               deterministicRandom() > 0.6 then
                                
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
            local x = math.floor(deterministicRandom() * size)
            local y = math.floor(deterministicRandom() * size)
            
            if chunk.tiles[y][x] == MapConfig.ObjectType.EMPTY then
                local sizeRoll = deterministicRandom()
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
    if deterministicRandom() < 0.12 then
        local centerX = math.floor(deterministicRandom() * (size - 12) + 6)
        local centerY = math.floor(deterministicRandom() * (size - 12) + 6)
        local radius = 3 + math.floor(deterministicRandom() * 3)
        
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
function MapGenerator.generateBalancedAsteroids(chunk, chunkX, chunkY, densities)
    local asteroidDensity = densities.asteroids or MapConfig.density.asteroids
    -- Rama específica: si es ASTEROID_BELT usar el generador denso con corredores
    if chunk.biome.type == BiomeSystem.BiomeType.ASTEROID_BELT then
        return MapGenerator.generateAsteroidBeltField(chunk, chunkX, chunkY, densities)
    end
    
    local placed = 0
    local size = MapConfig.chunk.size
    local tiles = chunk.tiles
    local O = MapConfig.ObjectType
    local rnd = math.random
    local bt = chunk.biome.type

    for y = 0, size - 1 do
        local row = tiles[y]
        local globalY = chunkY * size + y
        for x = 0, size - 1 do
            local globalX = chunkX * size + x

            -- Menos octavas: 4->3 y 2->1 para reducir coste por celda
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
            
            local randomFactor = rnd()
            if randomFactor < asteroidDensity * 0.08 then
                if row[x] == O.EMPTY then
                    row[x] = O.ASTEROID_SMALL
                end
            end
        end
    end

    -- Garantizar presencia mínima (igual lógica, con PRNG local y filas cacheadas)
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
            local rx = rnd(0, size - 1)
            local ry = rnd(0, size - 1)
            local row = tiles[ry]
            if row[rx] == O.EMPTY then
                local roll = rnd()
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
function MapGenerator.generateBalancedNebulae(chunk, chunkX, chunkY, densities)
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
        local x = math.random(0, MapConfig.chunk.size - 1)
        local y = math.random(0, MapConfig.chunk.size - 1)
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
            shouldGenerate = (nebulaChance > threshold) or (math.random() < 0.55)
        elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
            shouldGenerate = (nebulaChance > threshold) or (math.random() < 0.35)
        else
            shouldGenerate = nebulaChance > threshold
        end

        if shouldGenerate then
            local nebula = {
                type = MapConfig.ObjectType.NEBULA,
                x = x * MapConfig.chunk.tileSize,
                y = y * MapConfig.chunk.tileSize,
                size = math.random(80, 220) * MapConfig.chunk.worldScale,
                color = MapConfig.colors.nebulae[math.random(1, #MapConfig.colors.nebulae)],
                intensity = math.random(30, 70) / 100,
                biomeType = chunk.biome.type,
                globalX = globalX,
                globalY = globalY
            }
            if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
                nebula.size = nebula.size * math.random(130, 190) / 100
                nebula.intensity = nebula.intensity * math.random(120, 170) / 100
            elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
                nebula.size = nebula.size * math.random(80, 130) / 100
                nebula.intensity = nebula.intensity * math.random(120, 160) / 100
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
            size = math.random(120, 220) * MapConfig.chunk.worldScale,
            color = MapConfig.colors.nebulae[math.random(1, #MapConfig.colors.nebulae)],
            intensity = math.random(25, 55) / 100,
            biomeType = chunk.biome.type,
            globalX = chunkX * MapConfig.chunk.size + math.floor(MapConfig.chunk.size * 0.5),
            globalY = chunkY * MapConfig.chunk.size + math.floor(MapConfig.chunk.size * 0.5)
        })
    end

    chunk.objects.nebulae = nebulaObjects
end

-- Generar objetos especiales balanceados
function MapGenerator.generateBalancedSpecialObjects(chunk, chunkX, chunkY, densities)
    chunk.specialObjects = {}
    
    local stationDensity = densities.stations or MapConfig.density.stations
    local wormholeDensity = densities.wormholes or MapConfig.density.wormholes

    -- Use Perlin noise for station generation
    local stationNoise = MapGenerator.multiOctaveNoise(chunkX, chunkY, 2, 0.5, 0.01)
    if stationNoise < stationDensity then
        local station = {
            type = MapConfig.ObjectType.STATION,
            x = math.random(10, MapConfig.chunk.size - 10) * MapConfig.chunk.tileSize,
            y = math.random(10, MapConfig.chunk.size - 10) * MapConfig.chunk.tileSize,
            size = math.random(18, 40) * MapConfig.chunk.worldScale,
            rotation = math.random() * math.pi * 2,
            active = true,
            biomeType = chunk.biome.type
        }
        table.insert(chunk.specialObjects, station)
    end
    
    -- Use Perlin noise for wormhole generation
    local wormholeNoise = MapGenerator.multiOctaveNoise(chunkX + 0.5, chunkY + 0.5, 2, 0.5, 0.01) -- Offset to differentiate from station noise
    if wormholeNoise < wormholeDensity then
        local wormhole = {
            type = MapConfig.ObjectType.WORMHOLE,
            x = math.random(8, MapConfig.chunk.size - 8) * MapConfig.chunk.tileSize,
            y = math.random(8, MapConfig.chunk.size - 8) * MapConfig.chunk.tileSize,
            size = math.random(15, 25) * MapConfig.chunk.worldScale,
            pulsePhase = math.random() * math.pi * 2,
            active = true,
            biomeType = chunk.biome.type
        }
        table.insert(chunk.specialObjects, wormhole)
    end

    -- Fallback: asegurar al menos 1 wormhole ocasional en Gravity Anomaly si no se generó por ruido
    if chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
        local hasWormhole = false
        for _, obj in ipairs(chunk.specialObjects) do
            if obj.type == MapConfig.ObjectType.WORMHOLE then
                hasWormhole = true
                break
            end
        end
        if not hasWormhole and math.random() < 0.25 then
            local wormhole = {
                type = MapConfig.ObjectType.WORMHOLE,
                x = math.random(8, MapConfig.chunk.size - 8) * MapConfig.chunk.tileSize,
                y = math.random(8, MapConfig.chunk.size - 8) * MapConfig.chunk.tileSize,
                size = math.random(16, 28) * MapConfig.chunk.worldScale,
                pulsePhase = math.random() * math.pi * 2,
                active = true,
                biomeType = chunk.biome.type
            }
            table.insert(chunk.specialObjects, wormhole)
        end
    end
end

-- Generar estrellas balanceadas
function MapGenerator.generateBalancedStars(chunk, chunkX, chunkY, densities)
    local stars = {}
    local starDensity = densities.stars or MapConfig.density.stars
    local baseNumStars = math.floor(MapConfig.chunk.size * MapConfig.chunk.size * starDensity * 0.2)
    
    -- Reducir multiplicadores (menos objetos y menos CPU por chunk)
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
    
    -- Menos sectores para reducir trabajo
    local sectorsPerSide = 5
    local sectorSize = MapConfig.chunk.size * MapConfig.chunk.tileSize / sectorsPerSide
    local starsPerSector = math.ceil(numStars / (sectorsPerSide * sectorsPerSide))
    
    -- Tablas y PRNG locales
    local rnd = math.random
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
            if rnd() < 0.3 then
                sectorStars = sectorStars + rnd(1, 3)
            end
            
            for i = 1, sectorStars do
                local x = sectorX * sectorSize + rnd(sectorSize * 0.1, sectorSize * 0.9)
                local y = sectorY * sectorSize + rnd(sectorSize * 0.1, sectorSize * 0.9)
                
                -- Determinar tipo de estrella
                local roll = rnd(1, 100)
                local starType =
                      (roll <= 30) and 1
                   or (roll <= 50) and 2
                   or (roll <= 65) and 3
                   or (roll <= 80) and 4
                   or (roll <= 92) and 5
                   or 6
                
                if chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE and rnd() < 0.25 then
                    starType = math.min(6, starType + 1)
                end
                
                local cfg = starConfigs[starType]
                local size = rnd(cfg.minS, cfg.maxS)
                local depth = cfg.minD + rnd() * (cfg.maxD - cfg.minD)
                
                local rpick = rnd()
                local brightness
                if rpick < 0.15 then
                    brightness = 1.3 + rnd() * 0.5
                elseif rpick < 0.55 then
                    brightness = 0.9 + rnd() * 0.3
                else
                    brightness = 0.7 + rnd() * 0.2
                end
                if starType == 4 then brightness = brightness * 1.15 end
                brightness = math.min(brightness, 2.0)
                
                local star = {
                    x = x + (rnd() - 0.5) * 0.4,
                    y = y + (rnd() - 0.5) * 0.4,
                    size = size,
                    type = starType,
                    color = colors[rnd(1, colorCount)],
                    twinkle = rnd() * math.pi * 2,
                    twinkleSpeed = rnd(0.5, 3.0),
                    depth = depth,
                    brightness = brightness,
                    pulsePhase = rnd() * math.pi * 2,
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
    
    -- Inicializar tiles
    for y = 0, MapConfig.chunk.size - 1 do
        chunk.tiles[y] = {}
        for x = 0, MapConfig.chunk.size - 1 do
            chunk.tiles[y][x] = MapConfig.ObjectType.EMPTY
        end
    end

    if MapGenerator.debugLogs then
        local t0 = love.timer.getTime()
        MapGenerator.generateBalancedAsteroids(chunk, chunkX, chunkY, BiomeSystem.modifyDensities(MapConfig.density, biomeInfo.type, chunkX, chunkY))
        local t1 = love.timer.getTime()
        MapGenerator.generateBalancedNebulae(chunk, chunkX, chunkY, BiomeSystem.modifyDensities(MapConfig.density, biomeInfo.type, chunkX, chunkY))
        local t2 = love.timer.getTime()
        MapGenerator.generateBalancedSpecialObjects(chunk, chunkX, chunkY, BiomeSystem.modifyDensities(MapConfig.density, biomeInfo.type, chunkX, chunkY))
        local t3 = love.timer.getTime()
        MapGenerator.generateBalancedStars(chunk, chunkX, chunkY, BiomeSystem.modifyDensities(MapConfig.density, biomeInfo.type, chunkX, chunkY))
        local t4 = love.timer.getTime()
        print(string.format("[GenProfile] Chunk (%d,%d): Ast=%.2fms, Neb=%.2fms, Spec=%.2fms, Stars=%.2fms",
            chunkX, chunkY, (t1-t0)*1000, (t2-t1)*1000, (t3-t2)*1000, (t4-t3)*1000))
    else
        local modified = BiomeSystem.modifyDensities(MapConfig.density, biomeInfo.type, chunkX, chunkY)
        MapGenerator.generateBalancedAsteroids(chunk, chunkX, chunkY, modified)
        MapGenerator.generateBalancedNebulae(chunk, chunkX, chunkY, modified)
        MapGenerator.generateBalancedSpecialObjects(chunk, chunkX, chunkY, modified)
        MapGenerator.generateBalancedStars(chunk, chunkX, chunkY, modified)
    end
    
    -- IMPORTANTE: Asegurar que las características especiales de bioma SIEMPRE se generen
    BiomeSystem.generateSpecialFeatures(chunk, chunkX, chunkY, biomeInfo.type)
    
    -- Debug para verificar generación
    if #chunk.specialObjects > 0 then
        -- dentro de MapGenerator.generateChunk, donde actualmente se imprime el resumen
        -- print del resumen de chunk
        if MapGenerator.debugLogs then
            print(string.format("Chunk (%d,%d) - Biome: %s, SpecialObjects: %d",
                chunkX, chunkY, chunk.biome and chunk.biome.name or "Unknown", #chunk.specialObjects))
        end
    end
    
    return chunk
end

return MapGenerator
