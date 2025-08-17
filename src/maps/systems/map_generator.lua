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

-- Generar asteroides balanceados
function MapGenerator.generateBalancedAsteroids(chunk, chunkX, chunkY, densities)
    local asteroidDensity = densities.asteroids or MapConfig.density.asteroids
    
    for y = 0, MapConfig.chunk.size - 1 do
        for x = 0, MapConfig.chunk.size - 1 do
            local globalX = chunkX * MapConfig.chunk.size + x
            local globalY = chunkY * MapConfig.chunk.size + y
            
            local noiseMain = MapGenerator.multiOctaveNoise(globalX, globalY, 4, 0.5, 0.025)
            local noiseDetail = MapGenerator.multiOctaveNoise(globalX, globalY, 2, 0.3, 0.12)
            local combinedNoise = (noiseMain * 0.7 + noiseDetail * 0.3)
            
            local threshold = 0.20
            if chunk.biome.type == BiomeSystem.BiomeType.ASTEROID_BELT then
                threshold = 0.12
                combinedNoise = combinedNoise * 1.3
            elseif chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
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
            elseif combinedNoise > threshold + 0.15 then
                chunk.tiles[y][x] = MapConfig.ObjectType.ASTEROID_MEDIUM
            elseif combinedNoise > threshold then
                chunk.tiles[y][x] = MapConfig.ObjectType.ASTEROID_SMALL
            end
            
            local randomFactor = math.random()
            if randomFactor < asteroidDensity * 0.08 then
                if chunk.tiles[y][x] == MapConfig.ObjectType.EMPTY then
                    chunk.tiles[y][x] = MapConfig.ObjectType.ASTEROID_SMALL
                end
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