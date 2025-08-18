-- src/maps/systems/map_generator.lua
-- Sistema de generación de contenido del mapa

local MapGenerator = {}
local PerlinNoise = require 'src.maps.perlin_noise'
local BiomeSystem = require 'src.maps.biome_system'
local MapConfig = require 'src.maps.config.map_config'

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
    local cellSize = 4  -- Reduced cell size for more dense coverage
    local jitter = 0.6  -- Reduced jitter for more regular patterns
    local minDistance = 2.0  -- Reduced minimum distance between asteroids
    local maxDistance = 4.0  -- Reduced maximum connection distance
    
    -- Generar puntos de la red usando ruido para asegurar consistencia entre chunks
    local points = {}
    local wx = chunkX * size
    local wy = chunkY * size
    
    -- Crear una cuadrícula de puntos con jitter
    for gy = -1, math.ceil(size/cellSize) + 1 do
        for gx = -1, math.ceil(size/cellSize) + 1 do
            -- Usar ruido para el jitter consistente
            local nx = (wx + gx * cellSize) * 0.1
            local ny = (wy + gy * cellSize) * 0.1
            local jx = (PerlinNoise.noise(nx, ny, 123) - 0.5) * cellSize * jitter
            local jy = (PerlinNoise.noise(nx + 100, ny + 100, 456) - 0.5) * cellSize * jitter
            
            local x = gx * cellSize + jx
            local y = gy * cellSize + jy
            
            -- Mantener puntos dentro del chunk con margen
            if x >= -cellSize and x < size + cellSize and y >= -cellSize and y < size + cellSize then
                table.insert(points, {x = x, y = y, size = 0})
            end
        end
    end
    
    -- Determinar el tamaño de cada asteroide basado en la densidad local
    for i, point in ipairs(points) do
        -- Usar ruido para tamaño consistente con offset basado en la posición del punto
        local noise = (PerlinNoise.noise(
            (wx + point.x) * 0.07, 
            (wy + point.y) * 0.07, 
            789
        ) + 1) * 0.5  -- Normalizar a 0..1
        
        -- Ajustar por densidad global primero
        if deterministicRandom() > baseDensity then
            point.size = -1  -- Punto vacío (espacio abierto)
        else
            -- Asignar tamaño basado en el ruido, con distribución más sesgada hacia tamaños pequeños
            if noise > 0.8 then
                point.size = 2  -- Grande (20% de probabilidad)
            elseif noise > 0.5 then
                point.size = 1  -- Mediano (30% de probabilidad)
            else
                point.size = 0  -- Pequeño (50% de probabilidad)
            end
        end
    end
    
    -- Conectar puntos cercanos para formar una red
    local connections = {}
    for i = 1, #points do
        connections[i] = {}
        for j = i + 1, #points do
            local dx = points[i].x - points[j].x
            local dy = points[i].y - points[j].y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            if dist <= maxDistance and (points[i].size >= 0 or points[j].size >= 0) then
                -- Conectar solo si al menos uno de los puntos es un asteroide
                connections[i][j] = true
                connections[j] = connections[j] or {}
                connections[j][i] = true
            end
        end
    end
    
    -- Rellenar los asteroides en el chunk
    local asteroidsPlaced = 0
    local minAsteroids = math.floor(size * size * baseDensity * 0.5)
    
    for i, point in ipairs(points) do
        local x, y = math.floor(point.x + 0.5), math.floor(point.y + 0.5)
        
        -- Solo dibujar puntos dentro del chunk
        if x >= 0 and x < size and y >= 0 and y < size and point.size >= 0 then
            -- Determinar el tipo de asteroide basado en el tamaño
            local asteroidType
            if point.size == 2 then
                asteroidType = MapConfig.ObjectType.ASTEROID_LARGE
            elseif point.size == 1 then
                asteroidType = MapConfig.ObjectType.ASTEROID_MEDIUM
            else
                asteroidType = MapConfig.ObjectType.ASTEROID_SMALL
            end
            
            -- Colocar el asteroide solo si la celda está vacía
            if chunk.tiles[y][x] == MapConfig.ObjectType.EMPTY then
                chunk.tiles[y][x] = asteroidType
                asteroidsPlaced = asteroidsPlaced + 1
                
                -- Para asteroides grandes, agregar algunos pequeños alrededor
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
    
    -- Asegurar un mínimo de asteroides en el chunk
    if asteroidsPlaced < minAsteroids then
        local attempts = 0
        while asteroidsPlaced < minAsteroids and attempts < minAsteroids * 2 do
            local x = math.floor(deterministicRandom() * size)
            local y = math.floor(deterministicRandom() * size)
            
            if chunk.tiles[y][x] == MapConfig.ObjectType.EMPTY then
                -- Usar una distribución más probable de asteroides pequeños
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
    
    -- Asegurar que haya suficientes asteroides (al menos 25% de cobertura)
    local marked = 0
    local candidates = {}
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            if chunk.tiles[y][x] ~= MapConfig.ObjectType.EMPTY then
                marked = marked + 1
            else
                -- Usar ruido para determinar qué celdas vacías podrían convertirse en asteroides
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
    
    -- Asegurar un mínimo de cobertura (25%)
    local minFill = math.floor(size * size * 0.25)
    if marked < minFill and #candidates > 0 then
        -- Ordenar candidatos por valor de ruido descendente
        table.sort(candidates, function(a, b) return a.d > b.d end)
        
        -- Añadir asteroides pequeños hasta alcanzar el mínimo
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
    
    -- Crear algunos espacios abiertos más grandes (10-15% de probabilidad por chunk)
    if deterministicRandom() < 0.12 then
        local openSpaceX = math.floor(deterministicRandom() * (size - 12) + 6)
        local openSpaceY = math.floor(deterministicRandom() * (size - 12) + 6)
        local radius = 3 + math.floor(deterministicRandom() * 3)
        
        for dy = -radius, radius do
            for dx = -radius, radius do
                local x, y = openSpaceX + dx, openSpaceY + dy
                if x >= 0 and x < size and y >= 0 and y < size then
                    local dist = math.sqrt(dx*dx + dy*dy)
                    if dist <= radius and chunk.tiles[y][x] ~= MapConfig.ObjectType.ASTEROID_LARGE then
                        chunk.tiles[y][x] = MapConfig.ObjectType.EMPTY
                    end
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
    for y = 0, MapConfig.chunk.size - 1 do
        for x = 0, MapConfig.chunk.size - 1 do
            local globalX = chunkX * MapConfig.chunk.size + x
            local globalY = chunkY * MapConfig.chunk.size + y
            
            local noiseMain = MapGenerator.multiOctaveNoise(globalX, globalY, 4, 0.5, 0.025)
            local noiseDetail = MapGenerator.multiOctaveNoise(globalX, globalY, 2, 0.3, 0.12)
            local combinedNoise = (noiseMain * 0.7 + noiseDetail * 0.3)
            
            local threshold = 0.20
            if chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
                threshold = 0.25
                combinedNoise = combinedNoise * 0.9
            elseif chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
                threshold = 0.35
            elseif chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
                threshold = 0.18
                combinedNoise = combinedNoise * 1.1
            elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
                threshold = 0.4
            elseif chunk.biome.type == BiomeSystem.BiomeType.ANCIENT_RUINS then
                threshold = 0.45
            end
            
            if combinedNoise > threshold + 0.3 then
                chunk.tiles[y][x] = MapConfig.ObjectType.ASTEROID_LARGE
                placed = placed + 1
            elseif combinedNoise > threshold + 0.15 then
                chunk.tiles[y][x] = MapConfig.ObjectType.ASTEROID_MEDIUM
                placed = placed + 1
            elseif combinedNoise > threshold then
                chunk.tiles[y][x] = MapConfig.ObjectType.ASTEROID_SMALL
                placed = placed + 1
            end
            
            local randomFactor = math.random()
            if randomFactor < asteroidDensity * 0.08 then
                if chunk.tiles[y][x] == MapConfig.ObjectType.EMPTY then
                    chunk.tiles[y][x] = MapConfig.ObjectType.ASTEROID_SMALL
                end
            end
        end
    end

    -- Garantizar presencia mínima de asteroides según bioma (evitar chunks vacíos)
    local size = MapConfig.chunk.size
    local totalTiles = size * size
    local minRatioByBiome = {
        [BiomeSystem.BiomeType.DEEP_SPACE] = 0.005,
        [BiomeSystem.BiomeType.NEBULA_FIELD] = 0.02,
        [BiomeSystem.BiomeType.ASTEROID_BELT] = 0.0, -- ya manejado por generador dedicado
        [BiomeSystem.BiomeType.GRAVITY_ANOMALY] = 0.015,
        [BiomeSystem.BiomeType.RADIOACTIVE_ZONE] = 0.01,
        [BiomeSystem.BiomeType.ANCIENT_RUINS] = 0.008
    }
    local minNeeded = math.floor(totalTiles * (minRatioByBiome[chunk.biome.type] or 0.01))
    if placed < minNeeded then
        local toAdd = minNeeded - placed
        local attempts = 0
        while toAdd > 0 and attempts < totalTiles * 2 do
            attempts = attempts + 1
            local rx = math.random(0, size - 1)
            local ry = math.random(0, size - 1)
            if chunk.tiles[ry][rx] == MapConfig.ObjectType.EMPTY then
                local roll = math.random()
                if roll < 0.15 then
                    chunk.tiles[ry][rx] = MapConfig.ObjectType.ASTEROID_LARGE
                elseif roll < 0.45 then
                    chunk.tiles[ry][rx] = MapConfig.ObjectType.ASTEROID_MEDIUM
                else
                    chunk.tiles[ry][rx] = MapConfig.ObjectType.ASTEROID_SMALL
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
    local maxNebulae = 6
    
    local numNebulae
    if chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
        numNebulae = math.min(3, baseNumNebulae)
    elseif chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
        numNebulae = math.min(maxNebulae, baseNumNebulae * 4)
    elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
        numNebulae = math.min(maxNebulae, baseNumNebulae * 2)
    elseif chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
        numNebulae = math.min(4, baseNumNebulae * 1.5)
    else
        numNebulae = math.min(4, baseNumNebulae)
    end
    
    for i = 1, numNebulae do
        local x = math.random(0, MapConfig.chunk.size - 1)
        local y = math.random(0, MapConfig.chunk.size - 1)
        local globalX = chunkX * MapConfig.chunk.size + x
        local globalY = chunkY * MapConfig.chunk.size + y
        
        local nebulaChance = MapGenerator.multiOctaveNoise(globalX, globalY, 3, 0.5, 0.035)
        local threshold = 0.25
        
        if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
            threshold = 0.05
        elseif chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
            threshold = 0.35
        elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
            threshold = 0.15
        elseif chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
            threshold = 0.20
        end
        
        local shouldGenerate = false
        if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
            shouldGenerate = (nebulaChance > threshold) or (math.random() < 0.4)
        elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
            shouldGenerate = (nebulaChance > threshold) or (math.random() < 0.25)
        else
            shouldGenerate = nebulaChance > threshold
        end
        
        if shouldGenerate then
            local nebula = {
                type = MapConfig.ObjectType.NEBULA,
                x = x * MapConfig.chunk.tileSize,
                y = y * MapConfig.chunk.tileSize,
                size = math.random(60, 160) * MapConfig.chunk.worldScale,
                color = MapConfig.colors.nebulae[math.random(1, #MapConfig.colors.nebulae)],
                intensity = math.random(25, 60) / 100,
                biomeType = chunk.biome.type,
                globalX = globalX,
                globalY = globalY
            }
            
            if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
                nebula.size = nebula.size * math.random(120, 180) / 100
                nebula.intensity = nebula.intensity * math.random(110, 150) / 100
            elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
                nebula.size = nebula.size * math.random(80, 130) / 100
                nebula.intensity = nebula.intensity * math.random(120, 160) / 100
                nebula.color = {0.8, 0.6, 0.2, 0.5}
            end
            
            table.insert(nebulaObjects, nebula)
        end
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
    
    -- Aumentar la densidad base para evitar espacios vacíos
    local numStars = baseNumStars * 2.0
    if chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
        numStars = baseNumStars * 3.0
    elseif chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
        numStars = baseNumStars * 2.2
    elseif chunk.biome.type == BiomeSystem.BiomeType.ASTEROID_BELT then
        numStars = baseNumStars * 1.8
    elseif chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
        numStars = baseNumStars * 2.5
    end
    
    -- Distribución uniforme dividiendo el chunk en sectores
    local sectorsPerSide = 6
    local sectorSize = MapConfig.chunk.size * MapConfig.chunk.tileSize / sectorsPerSide
    local starsPerSector = math.ceil(numStars / (sectorsPerSide * sectorsPerSide))
    
    -- Generar estrellas por sector
    for sectorY = 0, sectorsPerSide - 1 do
        for sectorX = 0, sectorsPerSide - 1 do
            local sectorStars = starsPerSector
            if math.random() < 0.3 then
                sectorStars = sectorStars + math.random(1, 3)
            end
            
            for i = 1, sectorStars do
                local x = sectorX * sectorSize + math.random(sectorSize * 0.1, sectorSize * 0.9)
                local y = sectorY * sectorSize + math.random(sectorSize * 0.1, sectorSize * 0.9)
                
                -- Determinar tipo de estrella
                local starTypeRoll = math.random(1, 100)
                local starType
                
                if starTypeRoll <= 30 then
                    starType = 1
                elseif starTypeRoll <= 50 then
                    starType = 2
                elseif starTypeRoll <= 65 then
                    starType = 3
                elseif starTypeRoll <= 80 then
                    starType = 4
                elseif starTypeRoll <= 92 then
                    starType = 5
                else
                    starType = 6
                end
                
                -- Ajuste para biomas específicos
                if chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE and math.random() < 0.25 then
                    starType = math.min(6, starType + 1)
                end
                
                local starConfigs = {
                    [1] = {size = math.random(1, 2), depth = math.random(0.85, 0.95)},
                    [2] = {size = math.random(2, 3), depth = math.random(0.7, 0.85)},
                    [3] = {size = math.random(3, 4), depth = math.random(0.5, 0.7)},
                    [4] = {size = math.random(3, 5), depth = math.random(0.3, 0.5)},
                    [5] = {size = math.random(4, 6), depth = math.random(0.15, 0.3)},
                    [6] = {size = math.random(5, 8), depth = math.random(0.05, 0.15)}
                }
                
                local config = starConfigs[starType]
                local star = {
                    x = x,
                    y = y,
                    size = config.size,
                    type = starType,
                    color = MapConfig.colors.stars[math.random(1, #MapConfig.colors.stars)],
                    twinkle = math.random() * math.pi * 2,
                    twinkleSpeed = math.random(0.5, 3.0),
                    depth = config.depth,
                    brightness = math.random(0.8, 1.2),
                    pulsePhase = math.random() * math.pi * 2,
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
    
    -- Generar contenido usando densidades modificadas por bioma
    local modifiedDensities = BiomeSystem.modifyDensities(MapConfig.density, biomeInfo.type, chunkX, chunkY)
    
    MapGenerator.generateBalancedAsteroids(chunk, chunkX, chunkY, modifiedDensities)
    MapGenerator.generateBalancedNebulae(chunk, chunkX, chunkY, modifiedDensities)
    MapGenerator.generateBalancedSpecialObjects(chunk, chunkX, chunkY, modifiedDensities)
    MapGenerator.generateBalancedStars(chunk, chunkX, chunkY, modifiedDensities)
    
    BiomeSystem.generateSpecialFeatures(chunk, chunkX, chunkY, biomeInfo.type)
    
    return chunk
end

return MapGenerator