-- src/maps/biome_system.lua 

local BiomeSystem = {}
local PerlinNoise = require 'src.maps.perlin_noise'

-- Límites del mundo (200k x 200k)
BiomeSystem.WORLD_LIMIT = 200000

-- Tipos de biomas ordenados por rareza
BiomeSystem.BiomeType = {
    DEEP_SPACE = 1,           -- Espacio profundo (océano espacial - predominante)
    NEBULA_FIELD = 2,         -- Campo de Nebulosa (común)
    ASTEROID_BELT = 3,        -- Campo de Asteroides (poco común)
    GRAVITY_ANOMALY = 4,      -- Zona de Gravedad Anómala (raro)
    RADIOACTIVE_ZONE = 5,     -- Sistema Radiactivo (muy raro)
    ANCIENT_RUINS = 6         -- Zona de Civilización Antigua (extremadamente raro)
}

-- Configuración de parámetros espaciales
BiomeSystem.SpaceParameters = {
    -- Energía Espacial (temperatura)
    energy = {
        levels = {
            {min = -1.0, max = -0.45, name = "FROZEN"},
            {min = -0.45, max = -0.15, name = "COLD"},
            {min = -0.15, max = 0.2, name = "TEMPERATE"},
            {min = 0.2, max = 0.55, name = "WARM"},
            {min = 0.55, max = 1.0, name = "HOT"}
        }
    },
    
    -- Densidad de Materia
    density = {
        levels = {
            {min = -1.0, max = -0.35, name = "VOID"},
            {min = -0.35, max = -0.1, name = "SPARSE"},
            {min = -0.1, max = 0.1, name = "NORMAL"},
            {min = 0.1, max = 0.3, name = "DENSE"},
            {min = 0.3, max = 1.0, name = "ULTRA_DENSE"}
        }
    },
    
    -- Distancia desde Deep Space (continentalness)
    continentalness = {
        levels = {
            {min = -1.2, max = -1.05, name = "DEEP_OCEAN"},
            {min = -1.05, max = -0.455, name = "OCEAN"},
            {min = -0.455, max = -0.19, name = "COAST"},
            {min = -0.19, max = 0.03, name = "NEAR_INLAND"},
            {min = 0.03, max = 0.3, name = "MID_INLAND"},
            {min = 0.3, max = 1.0, name = "FAR_INLAND"}
        }
    },
    
    -- Turbulencia Espacial
    turbulence = {
        levels = {
            {min = -1.0, max = -0.78, name = "EXTREME"},
            {min = -0.78, max = -0.375, name = "HIGH"},
            {min = -0.375, max = -0.2225, name = "MEDIUM"},
            {min = -0.2225, max = 0.05, name = "LOW"},
            {min = 0.05, max = 0.45, name = "MINIMAL"},
            {min = 0.45, max = 1.0, name = "STABLE"}
        }
    },
    
    -- Anomalías
    weirdness = {
        levels = {
            {min = -1.0, max = -0.7, name = "VERY_WEIRD"},
            {min = -0.7, max = -0.26667, name = "WEIRD"},
            {min = -0.26667, max = 0.26667, name = "NORMAL"},
            {min = 0.26667, max = 0.7, name = "POSITIVE_WEIRD"},
            {min = 0.7, max = 1.0, name = "ULTRA_POSITIVE_WEIRD"}
        }
    }
}

-- CONFIGURACIÓN BALANCEADA para distribución natural (SIN RESTRICCIONES DE ALTURA)
BiomeSystem.biomeConfigs = {
    [BiomeSystem.BiomeType.DEEP_SPACE] = {
        name = "Deep Space",
        rarity = "Very Common",
        color = {0.05, 0.05, 0.15, 1},  -- Azul muy oscuro más visible
        spawnWeight = 0.40,  -- 40% del mapa - océano espacial
        
        conditions = {
            continentalness = {"DEEP_OCEAN", "OCEAN"},  -- Principalmente zonas oceánicas
            energy = nil,  -- Cualquier temperatura
            density = {"VOID", "SPARSE"},  -- Baja densidad
            turbulence = nil,  -- Cualquier turbulencia
            weirdness = nil,  -- Cualquier anomalía
            depthRange = {0.0, 1.0}  -- TODA altura válida
        },
        
        coherenceRadius = 8,
        biomeScale = 0.02,
        properties = {
            visibility = 1.0,
            mobility = 1.0,
            radiation = 0.0,
            gravity = 1.0
        }
    },
    
    [BiomeSystem.BiomeType.NEBULA_FIELD] = {
        name = "Nebula Field",
        rarity = "Common",
        color = {0.3, 0.15, 0.45, 1},  -- Púrpura más brillante
        spawnWeight = 0.25,  -- 25% del mapa
        
        conditions = {
            continentalness = {"COAST", "NEAR_INLAND"},
            energy = {"TEMPERATE", "WARM"},
            density = {"DENSE", "ULTRA_DENSE"},
            turbulence = nil,  -- Cualquier turbulencia
            weirdness = {"NORMAL"},
            depthRange = {0.0, 1.0}  -- TODA altura válida (cambiado de 0.2-0.8)
        },
        
        coherenceRadius = 6,
        biomeScale = 0.025,
        specialFeatures = {"dense_nebula", "nebula_storm"},
        properties = {
            visibility = 0.7,
            mobility = 0.8,
            radiation = 0.1,
            gravity = 0.9
        }
    },
    
    [BiomeSystem.BiomeType.ASTEROID_BELT] = {
        name = "Asteroid Belt",
        rarity = "Uncommon",
        color = {0.35, 0.25, 0.15, 1},  -- Marrón más claro
        spawnWeight = 0.25,  -- 20% del mapa
        
        conditions = {
            continentalness = {"NEAR_INLAND", "MID_INLAND"},
            energy = {"COLD", "TEMPERATE"},
            density = {"NORMAL", "DENSE"},
            turbulence = {"HIGH", "MEDIUM"},
            weirdness = nil,
            depthRange = {0.0, 1.0}  -- TODA altura válida
        },
        
        coherenceRadius = 5,
        biomeScale = 0.03,
        specialFeatures = {"mega_asteroid", "asteroid_cluster"},
        properties = {
            visibility = 0.9,
            mobility = 0.6,
            radiation = 0.0,
            gravity = 1.1
        }
    },
    
    [BiomeSystem.BiomeType.GRAVITY_ANOMALY] = {
        name = "Gravity Anomaly",
        rarity = "Rare",
        color = {0.5, 0.15, 0.5, 1},  -- Magenta más brillante
        spawnWeight = 0.10,  -- 8% del mapa
        
        conditions = {
            continentalness = {"MID_INLAND", "FAR_INLAND"},
            energy = {"HOT", "WARM"},
            density = nil,
            turbulence = {"EXTREME", "HIGH"},
            weirdness = {"WEIRD", "VERY_WEIRD"},
            depthRange = {0.0, 1.0}  -- TODA altura válida
        },
        
        coherenceRadius = 4,
        biomeScale = 0.04,
        specialFeatures = {"gravity_well", "space_distortion"},
        properties = {
            visibility = 0.8,
            mobility = 0.4,
            radiation = 0.2,
            gravity = 2.5
        }
    },
    
    [BiomeSystem.BiomeType.RADIOACTIVE_ZONE] = {
        name = "Radioactive Zone",
        rarity = "Very Rare",
        color = {0.15, 0.5, 0.15, 1},  -- Verde radiactivo más brillante
        spawnWeight = 0.10,  -- 5% del mapa
        
        conditions = {
            continentalness = {"FAR_INLAND"},
            energy = {"HOT"},
            density = {"ULTRA_DENSE"},
            turbulence = {"EXTREME"},
            weirdness = {"VERY_WEIRD", "ULTRA_POSITIVE_WEIRD"},
            depthRange = {0.0, 1.0}  -- TODA altura válida (cambiado de 0.0-0.3)
        },
        
        coherenceRadius = 3,
        biomeScale = 0.05,
        specialFeatures = {"radioactive_core", "mutated_flora"},
        properties = {
            visibility = 0.6,
            mobility = 0.3,
            radiation = 5.0,
            gravity = 1.0
        }
    },
    
    [BiomeSystem.BiomeType.ANCIENT_RUINS] = {
        name = "Ancient Ruins",
        rarity = "Extremely Rare", 
        color = {0.25, 0.25, 0.3, 1},  -- Gris azulado más visible
        spawnWeight = 0.10,  -- 2% del mapa
        
        conditions = {
            continentalness = {"FAR_INLAND"},
            energy = {"FROZEN", "HOT"},
            density = {"ULTRA_DENSE"},
            turbulence = {"STABLE", "MINIMAL"},
            weirdness = {"ULTRA_POSITIVE_WEIRD"},
            depthRange = {0.0, 1.0}  -- TODA altura válida (cambiado de 0.7-1.0)
        },
        
        coherenceRadius = 2,
        biomeScale = 0.06,
        specialFeatures = {"ancient_artifact", "alien_structure"},
        properties = {
            visibility = 0.5,
            mobility = 0.2,
            radiation = 0.5,
            gravity = 1.5
        }
    }
}

-- Cache y configuración
BiomeSystem.biomeCache = {}
BiomeSystem.parameterCache = {}
BiomeSystem.debugInfo = {
    lastPlayerBiome = nil,
    biomeChangeCount = 0
}
BiomeSystem.debugMode = false
BiomeSystem.seed = 12345
BiomeSystem.numericSeed = 12345

-- Función para convertir semilla alfanumérica a numérica
function BiomeSystem.seedToNumeric(alphaSeed)
    if type(alphaSeed) == "number" then
        return alphaSeed
    end
    
    local numericValue = 0
    local seedStr = tostring(alphaSeed)
    
    for i = 1, #seedStr do
        local char = seedStr:sub(i, i)
        local charValue = 0
        
        if char:match("%d") then
            charValue = tonumber(char)
        else
            charValue = string.byte(char:upper()) - string.byte('A') + 10
        end
        
        numericValue = numericValue + charValue * (37 ^ (i - 1))
    end
    
    return math.abs(numericValue) % 2147483647
end

-- Inicialización del sistema
function BiomeSystem.init(seed)
    BiomeSystem.seed = seed or "A1B2C"
    BiomeSystem.numericSeed = BiomeSystem.seedToNumeric(seed)
    BiomeSystem.biomeCache = {}
    BiomeSystem.parameterCache = {}
    BiomeSystem.debugInfo = {
        lastPlayerBiome = nil,
        biomeChangeCount = 0
    }
    
    -- Inicializar Perlin con semilla numérica
    PerlinNoise.init(BiomeSystem.numericSeed)
    
    print("3D Biome System initialized with seed: " .. tostring(BiomeSystem.seed))
    print("Numeric seed: " .. BiomeSystem.numericSeed)
    print("Using improved 6-parameter generation with proper distribution")
    print("Height dimension affects object density, not biome visibility")
    print("All biomes can appear at any height for 2D top-down view")
end

-- Verificar límites del mundo
function BiomeSystem.isWithinWorldLimits(x, y)
    return math.abs(x) <= BiomeSystem.WORLD_LIMIT and math.abs(y) <= BiomeSystem.WORLD_LIMIT
end

-- Calcular altura falsa basada en posición (solo para variación visual)
function BiomeSystem.calculateFalseHeight(worldX, worldY)
    -- Usar múltiples octavas para altura más natural con escalas más grandes
    local scale1 = 0.00005  -- Escala muy grande para continentes (más grande)
    local scale2 = 0.0002   -- Escala media para regiones (más grande)
    local scale3 = 0.001    -- Escala pequeña para detalles (más grande)
    
    local height1 = PerlinNoise.noise(worldX * scale1, worldY * scale1, 0)
    local height2 = PerlinNoise.noise(worldX * scale2, worldY * scale2, 100)
    local height3 = PerlinNoise.noise(worldX * scale3, worldY * scale3, 200)
    
    -- Combinar con pesos decrecientes
    local combinedHeight = height1 * 0.5 + height2 * 0.3 + height3 * 0.2
    
    -- Normalizar a [0, 1]
    local normalized = (combinedHeight + 1) * 0.5
    
    -- Clamp para asegurar rango válido
    return math.max(0, math.min(1, normalized))
end

-- Hash determinista para chunk
function BiomeSystem.hashChunk(chunkX, chunkY)
    -- Crear un hash único y determinista para cada chunk
    local hash = ((chunkX * 73856093) + (chunkY * 19349663)) % 2147483647
    return (hash + BiomeSystem.numericSeed) % 2147483647
end

-- Generar parámetros espaciales 3D mejorados
function BiomeSystem.generateSpaceParameters(chunkX, chunkY)
    local cacheKey = chunkX .. "," .. chunkY
    
    if BiomeSystem.parameterCache[cacheKey] then
        return BiomeSystem.parameterCache[cacheKey]
    end
    
    -- Coordenadas del mundo
    local worldX = chunkX * 48 * 32
    local worldY = chunkY * 48 * 32
    
    -- Verificar límites
    if not BiomeSystem.isWithinWorldLimits(worldX, worldY) then
        local params = {
            energy = -0.8,
            density = -0.9,
            continentalness = -1.1,
            turbulence = 0.3,
            weirdness = 0.0,
            depth = 0.5
        }
        BiomeSystem.parameterCache[cacheKey] = params
        return params
    end
    
    -- Calcular altura falsa (solo para variación visual)
    local falseHeight = BiomeSystem.calculateFalseHeight(worldX, worldY)
    
    -- ESCALAS AJUSTADAS para mejor distribución visible
    local energyScale = 0.0002     -- Más grande para regiones más amplias
    local densityScale = 0.0003    -- Más grande para regiones más amplias
    local contScale = 0.00015      -- Más grande para continentes más visibles
    local turbScale = 0.0004       -- Escala media
    local weirdScale = 0.00025     -- Escala media
    
    -- ENERGÍA ESPACIAL (temperatura)
    local energy = PerlinNoise.noise(worldX * energyScale, worldY * energyScale, 0)
    energy = energy + PerlinNoise.noise(worldX * energyScale * 3, worldY * energyScale * 3, 50) * 0.3
    
    -- DENSIDAD DE MATERIA
    local density = PerlinNoise.noise(worldX * densityScale + 1000, worldY * densityScale + 1000, 100)
    density = density + PerlinNoise.noise(worldX * densityScale * 2.5, worldY * densityScale * 2.5, 150) * 0.4
    
    -- CONTINENTALIDAD - Crear "islas" de biomas más grandes
    local cont1 = PerlinNoise.noise(worldX * contScale, worldY * contScale, 200)
    local cont2 = PerlinNoise.noise(worldX * contScale * 0.5, worldY * contScale * 0.5, 250)
    local cont3 = PerlinNoise.noise(worldX * contScale * 2, worldY * contScale * 2, 280) * 0.2
    local continentalness = cont1 * 0.6 + cont2 * 0.3 + cont3 * 0.1
    
    -- Amplificar para crear islas más definidas
    continentalness = continentalness * 1.8
    continentalness = math.max(-1.2, math.min(1, continentalness))
    
    -- TURBULENCIA ESPACIAL
    local turbulence = PerlinNoise.noise(worldX * turbScale + 2000, worldY * turbScale + 2000, 300)
    turbulence = turbulence + PerlinNoise.noise(worldX * turbScale * 2, worldY * turbScale * 2, 350) * 0.3
    
    -- ANOMALÍAS (weirdness)
    local weirdness = PerlinNoise.noise(worldX * weirdScale + 3000, worldY * weirdScale + 3000, 400)
    weirdness = weirdness + PerlinNoise.noise(worldX * weirdScale * 4, worldY * weirdScale * 4, 450) * 0.2
    
    -- La altura solo afecta sutilmente otros parámetros (no bloquea biomas)
    energy = energy - (falseHeight - 0.5) * 0.2  -- Efecto más suave
    density = density * (1.0 - math.abs(energy) * 0.15)  -- Efecto más suave
    
    local params = {
        energy = math.max(-1, math.min(1, energy)),
        density = math.max(-1, math.min(1, density)),
        continentalness = continentalness,
        turbulence = math.max(-1, math.min(1, turbulence)),
        weirdness = math.max(-1, math.min(1, weirdness)),
        depth = falseHeight  -- Solo para modificar densidades, no para bloquear
    }
    
    BiomeSystem.parameterCache[cacheKey] = params
    return params
end

-- Encontrar nivel de parámetro
function BiomeSystem.findParameterLevel(value, parameterType)
    local levels = BiomeSystem.SpaceParameters[parameterType].levels
    
    for _, level in ipairs(levels) do
        if value >= level.min and value <= level.max then
            return level.name
        end
    end
    
    return levels[1].name  -- Fallback
end

-- Verificar si los parámetros coinciden con las condiciones del bioma
function BiomeSystem.matchesBiomeConditions(params, conditions)
    -- La altura NO bloquea biomas en vista 2D cenital, edit: igual no se ve xd
    -- Solo se usa para modificar densidades en modifyDensities()
    
    -- Función auxiliar para verificar condición
    local function checkCondition(paramValue, paramType, allowedLevels)
        if not allowedLevels then return true end  -- nil significa cualquier valor
        
        local level = BiomeSystem.findParameterLevel(paramValue, paramType)
        for _, allowedLevel in ipairs(allowedLevels) do
            if level == allowedLevel then
                return true
            end
        end
        return false
    end
    
    -- Verificar cada condición (excepto altura que ya no bloquea)
    if not checkCondition(params.continentalness, "continentalness", conditions.continentalness) then
        return false
    end
    
    if not checkCondition(params.energy, "energy", conditions.energy) then
        return false
    end
    
    if not checkCondition(params.density, "density", conditions.density) then
        return false
    end
    
    if not checkCondition(params.turbulence, "turbulence", conditions.turbulence) then
        return false
    end
    
    if not checkCondition(params.weirdness, "weirdness", conditions.weirdness) then
        return false
    end
    
    return true
end

-- Determinar bioma basado en parámetros 3D
function BiomeSystem.getBiomeForChunk(chunkX, chunkY)
    local key = chunkX .. "," .. chunkY
    
    if BiomeSystem.biomeCache[key] then
        return BiomeSystem.biomeCache[key]
    end
    
    -- Generar parámetros espaciales
    local params = BiomeSystem.generateSpaceParameters(chunkX, chunkY)
    
    -- Sistema de puntuación para cada bioma
    local biomeScores = {}
    
    for biomeType, config in pairs(BiomeSystem.biomeConfigs) do
        if BiomeSystem.matchesBiomeConditions(params, config.conditions) then
            -- Calcular puntuación basada en qué tan bien coincide
            local score = config.spawnWeight
            
            -- Bonus por estar en el centro del rango de continentalidad
            if config.conditions.continentalness then
                local contLevel = BiomeSystem.findParameterLevel(params.continentalness, "continentalness")
                for _, allowedLevel in ipairs(config.conditions.continentalness) do
                    if contLevel == allowedLevel then
                        score = score * 1.2
                        break
                    end
                end
            end
            
            -- LA ALTURA AHORA MODIFICA LA PROBABILIDAD, NO BLOQUEA
            -- Bonus/penalización suave por altura óptima
            local depthRange = config.conditions.depthRange
            if depthRange and params.depth then
                local optimalDepth = (depthRange[1] + depthRange[2]) / 2
                local depthDistance = math.abs(params.depth - optimalDepth)
                -- Modificador suave: máximo 1.3x si está en altura perfecta, mínimo 0.7x si está lejos
                local depthModifier = 1.0 + (0.3 - depthDistance * 0.6)
                depthModifier = math.max(0.7, math.min(1.3, depthModifier))
                score = score * depthModifier
            end
            
            table.insert(biomeScores, {
                type = biomeType,
                score = score
            })
        end
    end
    
    -- Si no hay coincidencias, usar Deep Space
    if #biomeScores == 0 then
        BiomeSystem.biomeCache[key] = BiomeSystem.BiomeType.DEEP_SPACE
        return BiomeSystem.BiomeType.DEEP_SPACE
    end
    
    -- Usar hash determinista para selección
    local chunkHash = BiomeSystem.hashChunk(chunkX, chunkY)
    local randomValue = (chunkHash % 10000) / 10000.0
    
    -- Selección por ruleta ponderada
    local totalScore = 0
    for _, entry in ipairs(biomeScores) do
        totalScore = totalScore + entry.score
    end
    
    local targetValue = randomValue * totalScore
    local accumulator = 0
    
    for _, entry in ipairs(biomeScores) do
        accumulator = accumulator + entry.score
        if accumulator >= targetValue then
            BiomeSystem.biomeCache[key] = entry.type
            return entry.type
        end
    end
    
    -- Fallback
    BiomeSystem.biomeCache[key] = biomeScores[1].type
    return biomeScores[1].type
end

-- Sistema de coherencia espacial simplificado
function BiomeSystem.applyCoherence3D(chunkX, chunkY, proposedBiome, params)
    -- Reducir agresividad del sistema de coherencia
    local proposedConfig = BiomeSystem.biomeConfigs[proposedBiome]
    local coherenceRadius = proposedConfig.coherenceRadius or 1
    
    -- Solo aplicar coherencia para biomas raros
    if proposedConfig.spawnWeight > 0.1 then
        return proposedBiome
    end
    
    -- Contar biomas vecinos
    local neighborCounts = {}
    local totalNeighbors = 0
    
    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx == 0 and dy == 0 then goto continue end
            
            local neighborKey = (chunkX + dx) .. "," .. (chunkY + dy)
            local neighborBiome = BiomeSystem.biomeCache[neighborKey]
            
            if neighborBiome then
                neighborCounts[neighborBiome] = (neighborCounts[neighborBiome] or 0) + 1
                totalNeighbors = totalNeighbors + 1
            end
            
            ::continue::
        end
    end
    
    -- Si no hay suficientes vecinos, mantener propuesta
    if totalNeighbors < 4 then
        return proposedBiome
    end
    
    -- Solo cambiar si hay un bioma muy dominante alrededor
    for biome, count in pairs(neighborCounts) do
        if count >= 6 and biome ~= BiomeSystem.BiomeType.DEEP_SPACE then
            local dominantConfig = BiomeSystem.biomeConfigs[biome]
            if BiomeSystem.matchesBiomeConditions(params, dominantConfig.conditions) then
                return biome
            end
        end
    end
    
    return proposedBiome
end

function BiomeSystem.getBiomeConfig(biomeType)
    return BiomeSystem.biomeConfigs[biomeType] or BiomeSystem.biomeConfigs[BiomeSystem.BiomeType.DEEP_SPACE]
end

function BiomeSystem.getBiomeInfo(chunkX, chunkY)
    local biomeType = BiomeSystem.getBiomeForChunk(chunkX, chunkY)
    local config = BiomeSystem.getBiomeConfig(biomeType)
    local params = BiomeSystem.generateSpaceParameters(chunkX, chunkY)
    
    return {
        type = biomeType,
        name = config.name,
        config = config,
        coordinates = {x = chunkX, y = chunkY},
        parameters = params
    }
end

function BiomeSystem.modifyDensities(baseDensities, biomeType, chunkX, chunkY)
    local config = BiomeSystem.getBiomeConfig(biomeType)
    local modifiedDensities = {}
    
    local params = BiomeSystem.generateSpaceParameters(chunkX, chunkY)
    local energyMultiplier = 1.0 + params.energy * 0.3
    local densityMultiplier = 1.0 + params.density * 0.5
    local turbulenceMultiplier = 1.0 + math.abs(params.turbulence) * 0.2
    
    -- LA ALTURA AHORA AFECTA LA DENSIDAD DE OBJETOS, NO BLOQUEA BIOMAS
    local heightMultiplier = 1.0
    if params.depth < 0.2 then
        heightMultiplier = 0.8  -- Menos objetos en zonas muy bajas
    elseif params.depth > 0.8 then
        heightMultiplier = 1.2  -- Más objetos en zonas altas
    end
    
    local biomeDensities = {
        [BiomeSystem.BiomeType.DEEP_SPACE] = {
            asteroids = 0.01 * densityMultiplier * heightMultiplier,
            nebulae = 0.001 * energyMultiplier,
            stations = 0.0001,
            wormholes = 0.00005,
            stars = 0.30 * energyMultiplier,
            specialFeatures = 0.0002
        },
        
        [BiomeSystem.BiomeType.NEBULA_FIELD] = {
            asteroids = 0.02 * densityMultiplier,
            nebulae = 0.20 * energyMultiplier * densityMultiplier * heightMultiplier,  -- Altura afecta nebulosas
            stations = 0.0008,
            wormholes = 0.001 * turbulenceMultiplier,
            stars = 0.35 * energyMultiplier,
            specialFeatures = 0.015 * densityMultiplier
        },
        
        [BiomeSystem.BiomeType.ASTEROID_BELT] = {
            asteroids = 0.25 * densityMultiplier * turbulenceMultiplier * heightMultiplier,  -- Altura afecta asteroides
            nebulae = 0.001,
            stations = 0.003,
            wormholes = 0.0001,
            stars = 0.12,
            specialFeatures = 0.025 * turbulenceMultiplier
        },
        
        [BiomeSystem.BiomeType.GRAVITY_ANOMALY] = {
            asteroids = 0.03 * turbulenceMultiplier,
            nebulae = 0.005 * energyMultiplier,
            stations = 0.0002,
            wormholes = 0.002 * energyMultiplier * heightMultiplier,  -- Más wormholes en altura
            stars = 0.18 * energyMultiplier,
            specialFeatures = 0.08 * energyMultiplier
        },
        
        [BiomeSystem.BiomeType.RADIOACTIVE_ZONE] = {
            asteroids = 0.005,
            nebulae = 0.001,
            stations = 0.0001,
            wormholes = 0.0003,
            stars = 0.45 * energyMultiplier * (2.0 - heightMultiplier),  -- Más estrellas en zonas bajas
            specialFeatures = 0.12 * energyMultiplier
        },
        
        [BiomeSystem.BiomeType.ANCIENT_RUINS] = {
            asteroids = 0.003,
            nebulae = 0.002,
            stations = 0.008 * heightMultiplier,  -- Más estructuras en altura
            wormholes = 0.004,
            stars = 0.15,
            specialFeatures = 0.15 * heightMultiplier  -- Más ruinas en altura
        }
    }
    
    local densitySet = biomeDensities[biomeType]
    if densitySet then
        for key, baseDensity in pairs(baseDensities) do
            modifiedDensities[key] = densitySet[key] or baseDensity
        end
    else
        modifiedDensities = baseDensities
    end
    
    return modifiedDensities
end

function BiomeSystem.updatePlayerBiome(playerX, playerY)
    local Map = require 'src.maps.map'
    local chunkX, chunkY = Map.getChunkInfo(playerX, playerY)
    local currentBiome = BiomeSystem.getBiomeForChunk(chunkX, chunkY)
    
    if BiomeSystem.debugInfo.lastPlayerBiome ~= currentBiome then
        BiomeSystem.debugInfo.lastPlayerBiome = currentBiome
        BiomeSystem.debugInfo.biomeChangeCount = BiomeSystem.debugInfo.biomeChangeCount + 1
        
        local config = BiomeSystem.getBiomeConfig(currentBiome)
        local params = BiomeSystem.generateSpaceParameters(chunkX, chunkY)
        
        if _G.advancedStats and _G.advancedStats.enabled then
            print("=== BIOME CHANGE #" .. BiomeSystem.debugInfo.biomeChangeCount .. " ===")
            print("Entered: " .. config.name .. " (" .. config.rarity .. ")")
            print("Color: R=" .. string.format("%.2f", config.color[1]) .. 
                  ", G=" .. string.format("%.2f", config.color[2]) ..
                  ", B=" .. string.format("%.2f", config.color[3]))
            print("Parameters: E=" .. string.format("%.2f", params.energy) .. 
                  ", D=" .. string.format("%.2f", params.density) ..
                  ", C=" .. string.format("%.2f", params.continentalness))
            print("Height (visual modifier only): " .. string.format("%.2f", params.depth))
            
            -- Notificación especial para biomas raros
            if config.spawnWeight <= 0.05 then
                print("*** RARE BIOME FOUND! ***")
            end
        end
    end
    
    return currentBiome
end

function BiomeSystem.getPlayerBiomeInfo(playerX, playerY)
    local Map = require 'src.maps.map'
    local chunkX, chunkY = Map.getChunkInfo(playerX, playerY)
    local biomeInfo = BiomeSystem.getBiomeInfo(chunkX, chunkY)
    
    return {
        type = biomeInfo.type,
        name = biomeInfo.name,
        rarity = biomeInfo.config.rarity,
        config = biomeInfo.config,
        coordinates = {
            chunk = {x = chunkX, y = chunkY},
            world = {x = playerX, y = playerY}
        },
        parameters = biomeInfo.parameters
    }
end

-- Función de debug para verificar distribución
function BiomeSystem.debugDistribution(sampleSize)
    sampleSize = sampleSize or 2000
    local counts = {}
    local heightStats = {total = 0, count = 0}
    
    for biomeType, _ in pairs(BiomeSystem.biomeConfigs) do
        counts[biomeType] = 0
    end
    
    local maxChunk = math.floor(BiomeSystem.WORLD_LIMIT / (48 * 32))
    
    for i = 1, sampleSize do
        local x = math.random(-maxChunk, maxChunk)
        local y = math.random(-maxChunk, maxChunk)
        local biome = BiomeSystem.getBiomeForChunk(x, y)
        local params = BiomeSystem.generateSpaceParameters(x, y)
        
        counts[biome] = counts[biome] + 1
        heightStats.total = heightStats.total + params.depth
        heightStats.count = heightStats.count + 1
    end
    
    print("=== BIOME DISTRIBUTION TEST (Sample: " .. sampleSize .. ") ===")
    print("NOTE: Height affects object density only, not biome visibility")
    print("")
    
    local totalPercentage = 0
    for biomeType, count in pairs(counts) do
        local config = BiomeSystem.getBiomeConfig(biomeType)
        local actualPercentage = (count / sampleSize) * 100
        local expectedPercentage = config.spawnWeight * 100
        totalPercentage = totalPercentage + actualPercentage
        
        local colorStr = string.format("Color(%.1f,%.1f,%.1f)", 
                                      config.color[1], config.color[2], config.color[3])
        
        print(string.format("%s: %.1f%% (target: %.1f%%) - %s", 
              config.name, actualPercentage, expectedPercentage, colorStr))
    end
    
    print("")
    print("Average height (visual modifier): " .. string.format("%.3f", heightStats.total / heightStats.count))
    print("Total coverage: " .. string.format("%.1f%%", totalPercentage))
    
    -- Verificar balance
    local deepSpacePercent = (counts[BiomeSystem.BiomeType.DEEP_SPACE] / sampleSize) * 100
    if deepSpacePercent >= 35 and deepSpacePercent <= 45 then
        print("✓ Deep Space acts as proper spatial ocean separator")
    else
        print("! Deep Space distribution needs adjustment: " .. string.format("%.1f%%", deepSpacePercent))
    end
end

function BiomeSystem.generateSpecialFeatures(chunk, chunkX, chunkY, biomeType)
    local config = BiomeSystem.getBiomeConfig(biomeType)
    local specialFeatures = config.specialFeatures or {}
    
    if #specialFeatures == 0 then return end
    
    local params = BiomeSystem.generateSpaceParameters(chunkX, chunkY)
    
    local energyBonus = params.energy > 0.5 and 1.5 or 1.0
    local weirdnessBonus = math.abs(params.weirdness) > 0.5 and 2.0 or 1.0
    local depthBonus = (params.depth < 0.2 or params.depth > 0.8) and 1.3 or 1.0
    
    local totalBonus = energyBonus * weirdnessBonus * depthBonus
    
    -- Usar hash determinista para features
    local featureHash = BiomeSystem.hashChunk(chunkX + 1000, chunkY + 1000)
    
    for i, featureType in ipairs(specialFeatures) do
        local featureRand = ((featureHash + i * 12345) % 10000) / 10000.0
        local baseChance = 0.01
        local adjustedChance = baseChance * totalBonus
        
        if featureRand < adjustedChance then
            BiomeSystem.addSpecialFeature(chunk, featureType, chunkX, chunkY, params)
        end
    end
end

function BiomeSystem.addSpecialFeature(chunk, featureType, chunkX, chunkY, params)
    local featureHash = BiomeSystem.hashChunk(chunkX + 2000, chunkY + 2000)
    local randX = (featureHash % 38) + 5
    local randY = ((featureHash / 38) % 38) + 5
    
    local feature = {
        type = featureType,
        x = randX * 32,
        y = randY * 32,
        size = 20 + (featureHash % 40),
        properties = {},
        active = true,
        parameters = params
    }
    
    -- Configuración específica por tipo
    if featureType == "dense_nebula" then
        feature.color = {0.8, 0.3, 0.8, 0.6 + params.density * 0.2}
        feature.size = 80 + (featureHash % 70)
    elseif featureType == "mega_asteroid" then
        feature.size = 40 + (featureHash % 40)
        feature.color = {0.5, 0.4, 0.3, 1}
    elseif featureType == "gravity_well" then
        feature.color = {0.4, 0.2, 0.8, 0.4}
        feature.size = 30 + (featureHash % 20)
    end
    
    chunk.specialObjects = chunk.specialObjects or {}
    table.insert(chunk.specialObjects, feature)
end

function BiomeSystem.getBackgroundColor(biomeType)
    local config = BiomeSystem.getBiomeConfig(biomeType)
    return config.color
end

function BiomeSystem.getProperty(biomeType, property)
    local config = BiomeSystem.getBiomeConfig(biomeType)
    return config.properties and config.properties[property] or 1.0
end

function BiomeSystem.regenerate(newSeed)
    BiomeSystem.init(newSeed)
    print("Biome System regenerated with improved distribution")
    print("All biomes visible at any height - 2D top-down compatible")
    print("Height now only affects object density for visual variety")
end

function BiomeSystem.getAdvancedStats()
    local stats = {
        totalChunksGenerated = 0,
        biomeDistribution = {},
        rarityDistribution = {},
        seed = BiomeSystem.seed,
        numericSeed = BiomeSystem.numericSeed,
        worldLimits = BiomeSystem.WORLD_LIMIT
    }
    
    for biomeType, config in pairs(BiomeSystem.biomeConfigs) do
        stats.biomeDistribution[config.name] = 0
        stats.rarityDistribution[config.rarity] = 0
    end
    
    for _, biomeType in pairs(BiomeSystem.biomeCache) do
        local config = BiomeSystem.getBiomeConfig(biomeType)
        stats.biomeDistribution[config.name] = stats.biomeDistribution[config.name] + 1
        stats.rarityDistribution[config.rarity] = stats.rarityDistribution[config.rarity] + 1
        stats.totalChunksGenerated = stats.totalChunksGenerated + 1
    end
    
    return stats
end

function BiomeSystem.findNearbyBiomes(x, y, radius)
    radius = radius or 10000
    local Map = require 'src.maps.map'
    local chunkSize = Map.chunkSize * Map.tileSize
    
    if not BiomeSystem.isWithinWorldLimits(x, y) then
        return {{
            type = BiomeSystem.BiomeType.DEEP_SPACE,
            name = "Deep Space",
            distance = 0,
            config = BiomeSystem.getBiomeConfig(BiomeSystem.BiomeType.DEEP_SPACE)
        }}
    end
    
    local chunkRadius = math.ceil(radius / chunkSize)
    local startChunkX, startChunkY = math.floor(x / chunkSize), math.floor(y / chunkSize)
    
    local foundBiomes = {}
    local minDistances = {}
    
    for dx = -chunkRadius, chunkRadius do
        for dy = -chunkRadius, chunkRadius do
            local chunkX = startChunkX + dx
            local chunkY = startChunkY + dy
            
            local worldX = (chunkX + 0.5) * chunkSize
            local worldY = (chunkY + 0.5) * chunkSize
            local distance = math.sqrt((worldX - x)^2 + (worldY - y)^2)
            
            if distance <= radius then
                local biomeInfo = BiomeSystem.getBiomeInfo(chunkX, chunkY)
                if biomeInfo and biomeInfo.type then
                    local biomeType = biomeInfo.type
                    
                    if not minDistances[biomeType] or distance < minDistances[biomeType] then
                        minDistances[biomeType] = distance
                        foundBiomes[biomeType] = {
                            type = biomeType,
                            name = biomeInfo.name,
                            distance = distance,
                            config = biomeInfo.config,
                            chunkX = chunkX,
                            chunkY = chunkY,
                            parameters = biomeInfo.parameters
                        }
                    end
                end
            end
        end
    end
    
    local result = {}
    for _, biome in pairs(foundBiomes) do
        table.insert(result, biome)
    end
    
    table.sort(result, function(a, b) 
        return a.distance < b.distance
    end)
    
    return result
end

return BiomeSystem