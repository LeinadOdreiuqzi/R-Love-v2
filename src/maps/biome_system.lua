-- src/maps/biome_system.lua 

local BiomeSystem = {}
local PerlinNoise = require 'src.maps.perlin_noise'
local MapConfig = require 'src.maps.config.map_config'
local CoordinateSystem = require 'src.maps.coordinate_system'

-- Unified stride for chunk world positioning (scaled by worldScale to keep noise sampling consistent in screen pixels)
local STRIDE = ((MapConfig.chunk.size * MapConfig.chunk.tileSize) + MapConfig.chunk.spacing) * (MapConfig.chunk.worldScale or 1)

-- Límites del mundo - usar CoordinateSystem para consistencia
BiomeSystem.WORLD_LIMIT = (CoordinateSystem.config.sectorSize or 1000000) * 100

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
        color = {0, 0, 0, 0},  -- Azul muy oscuro más visible
        spawnWeight = 0.38,  -- 38% del mapa - océano espacial
        
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
        spawnWeight = 0.24,  -- 24% del mapa
        
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
        color = {0.7, 0.7, 0.7, 1.0},
        rarity = "common",
        spawnWeight = 0.12,  -- Reduced from 0.20 to make it less common
        
        conditions = {
            continentalness = {"MID_INLAND", "FAR_INLAND"},  -- More specific continentalness
            energy = {"COLD", "TEMPERATE"},  -- More specific energy range
            density = {"DENSE", "ULTRA_DENSE"},  -- Higher density required
            turbulence = {"LOW", "MEDIUM"},  -- More stable areas
            weirdness = {"NORMAL", "POSITIVE_WEIRD"},  -- More specific weirdness
            depthRange = {0.2, 0.8}  -- Avoid extreme depths
        },
        
        coherenceRadius = 8,  -- bajado (antes 18) para evitar placas rectangulares grandes
        biomeScale = 0.07,     -- puedes ajustar para controlar la granularidad
        specialFeatures = {"mega_asteroid", "asteroid_cluster"},
        properties = {
            visibility = 0.85,  -- Ligeramente más bajo para mayor densidad
        }
    },
    
    [BiomeSystem.BiomeType.GRAVITY_ANOMALY] = {
        name = "Gravity Anomaly",
        rarity = "Rare",
        color = {0.5, 0.15, 0.5, 1},  -- Magenta más brillante
        spawnWeight = 0.08,  -- 8% del mapa
        
        conditions = {
            continentalness = {"MID_INLAND", "FAR_INLAND"},
            energy = {"HOT", "WARM"},
            density = nil,
            turbulence = {"MEDIUM", "HIGH", "EXTREME"},
            weirdness = {"WEIRD", "VERY_WEIRD", "POSITIVE_WEIRD"},
            depthRange = {0.0, 1.0}  -- TODA altura válida
        },
        
        coherenceRadius = 4,
        biomeScale = 0.04,
        specialFeatures = {"gravity_well", "space_distortion"},
        properties = {
            visibility = 0.8,
            mobility = 0.4,
            radiation = 0.2,
            gravity = 2.5,
            -- NUEVO: Propiedades para el shader de anomalía gravitatoria
            anomalyStrength = 2.0,    -- Fuerza de la distorsión
            anomalyRadius = 800.0,    -- Radio de influencia
            distortionIntensity = 1.5, -- Intensidad de la distorsión
            chromaticAberration = 0.02 -- Aberración cromática
        }
    },
    
    [BiomeSystem.BiomeType.RADIOACTIVE_ZONE] = {
        name = "Radioactive Zone",
        rarity = "Very Rare",
        color = {0.15, 0.5, 0.15, 1},  -- Verde radiactivo más brillante
        spawnWeight = 0.09,  -- antes 0.07
        
        conditions = {
            -- Relajar ligeramente para que aparezca sin perder tema
            continentalness = {"MID_INLAND", "FAR_INLAND"},
            energy = {"WARM", "HOT"},
            density = {"DENSE", "ULTRA_DENSE"},
            turbulence = {"MEDIUM", "HIGH", "EXTREME"},
            weirdness = {"WEIRD", "VERY_WEIRD", "POSITIVE_WEIRD", "ULTRA_POSITIVE_WEIRD"},
            depthRange = {0.0, 1.0}
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
        spawnWeight = 0.05,  -- antes 0.03
        
        conditions = {
            -- Aumentar chances manteniendo identidad de bioma
            continentalness = {"MID_INLAND", "FAR_INLAND"},
            energy = {"COLD", "TEMPERATE", "HOT"},
            density = {"DENSE", "ULTRA_DENSE"},
            turbulence = {"LOW", "MINIMAL", "STABLE", "MEDIUM"},
            weirdness = {"POSITIVE_WEIRD", "ULTRA_POSITIVE_WEIRD"},
            depthRange = {0.0, 1.0}
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

-- Perfíl de depuración basado en seeds de F2
BiomeSystem.debugPresetProfile = nil

-- Mapeo de seeds de HUD (F2) a perfiles de depuración
-- Nota: Se activa SOLO si la seed coincide exactamente con estos códigos
function BiomeSystem.setPresetProfileBySeed(seed)
    local s = tostring(seed or ""):upper()
    local T = BiomeSystem.BiomeType
    local profiles = {
        ["A5N9E3B7U1"] = {
            name = "Dense Nebula",
            preferBiome = T.NEBULA_FIELD,
            preferBiomeBoost = 8.0,
            reduceOthers = 0.25,
            enforceMajority = true,
            forceChance = 0.90,
            enforceScoreBoost = 100.0,
            enforceScoreReduce = 0.25,
            globalMul = { nebulae = 8.0, stars = 1.0, asteroids = 0.2, wormholes = 1.2, specialFeatures = 1.2 }
        },
        ["S2P4A6C8E0"] = {
            name = "Open Void",
            preferBiome = T.DEEP_SPACE,
            preferBiomeBoost = 6.0,
            reduceOthers = 0.30,
            enforceMajority = true,
            forceChance = 0.90,
            enforceScoreBoost = 80.0,
            enforceScoreReduce = 0.30,
            globalMul = { nebulae = 0.05, stars = 0.30, asteroids = 0.20, specialFeatures = 0.30, wormholes = 0.5 }
        },
        ["R3O7C9K2S6"] = {
            name = "Asteroid Fields",
            preferBiome = T.ASTEROID_BELT,
            preferBiomeBoost = 8.0,
            reduceOthers = 0.25,
            enforceMajority = true,
            forceChance = 0.90,
            enforceScoreBoost = 100.0,
            enforceScoreReduce = 0.25,
            globalMul = { asteroids = 8.0, nebulae = 0.10, stars = 0.8, specialFeatures = 1.5 }
        },
        ["M1Y8S4T6I3"] = {
            name = "Ancient Mysteries",
            preferBiome = T.ANCIENT_RUINS,
            preferBiomeBoost = 6.0,
            reduceOthers = 0.40,
            enforceMajority = true,
            forceChance = 0.88,
            enforceScoreBoost = 70.0,
            enforceScoreReduce = 0.40,
            globalMul = { specialFeatures = 8.0, stations = 3.0, stars = 0.9, nebulae = 1.1 }
        },
        ["H2A5Z9R3D7"] = {
            name = "Radiation Storm",
            preferBiome = T.RADIOACTIVE_ZONE,
            preferBiomeBoost = 6.0,
            reduceOthers = 0.40,
            enforceMajority = true,
            forceChance = 0.88,
            enforceScoreBoost = 70.0,
            enforceScoreReduce = 0.40,
            globalMul = { stars = 3.0, wormholes = 2.5, nebulae = 0.8, specialFeatures = 1.3 }
        },
        ["C4R8Y1S5T9"] = {
            name = "Crystal Caverns",
            preferBiome = T.ASTEROID_BELT,
            preferBiomeBoost = 5.5,
            reduceOthers = 0.40,
            enforceMajority = true,
            forceChance = 0.88,
            enforceScoreBoost = 60.0,
            enforceScoreReduce = 0.40,
            globalMul = { asteroids = 3.5, specialFeatures = 4.0, nebulae = 1.2, stars = 1.0 }
        },
        ["Q3U6A7N2T4"] = {
            name = "Quantum Rifts",
            preferBiome = T.GRAVITY_ANOMALY,
            preferBiomeBoost = 7.0,
            reduceOthers = 0.35,
            enforceMajority = true,
            forceChance = 0.90,
            enforceScoreBoost = 90.0,
            enforceScoreReduce = 0.35,
            globalMul = { wormholes = 8.0, stars = 1.0, nebulae = 1.2, specialFeatures = 1.5 }
        },
        ["L6O1S4T9W3"] = {
            name = "Lost Worlds",
            preferBiome = T.ANCIENT_RUINS,
            preferBiomeBoost = 6.0,
            reduceOthers = 0.35,
            enforceMajority = true,
            forceChance = 0.88,
            enforceScoreBoost = 70.0,
            enforceScoreReduce = 0.35,
            globalMul = { specialFeatures = 6.0, stations = 2.5, nebulae = 1.1, stars = 0.9 }
        },
        ["E2X8P5L7O9"] = {
            name = "Deep Explorer",
            preferBiome = T.DEEP_SPACE,
            preferBiomeBoost = 5.5,
            reduceOthers = 0.35,
            enforceMajority = true,
            forceChance = 0.88,
            enforceScoreBoost = 60.0,
            enforceScoreReduce = 0.35,
            globalMul = { stars = 1.5, asteroids = 0.5, nebulae = 0.4, specialFeatures = 0.8 }
        }
    }
    BiomeSystem.debugPresetProfile = profiles[s] or nil
    if BiomeSystem.debugMode then
        if BiomeSystem.debugPresetProfile then
            print("[BiomeSystem] Debug preset active: " .. BiomeSystem.debugPresetProfile.name)
        else
            print("[BiomeSystem] Debug preset: none")
        end
    end
end

function BiomeSystem.clearCache()
    BiomeSystem.biomeCache = {}
    BiomeSystem.parameterCache = {}
    print("[BiomeSystem] cache cleared")
end

-- Helpers internos para invalidación automática del caché cuando cambian parámetros orgánicos
function BiomeSystem._computeOCSignature()
    local oc = BiomeSystem.organicCoherence or {}
    return table.concat({
        tostring(oc.sizeChunks),
        tostring(oc.jitter),
        tostring(oc.sigmaFactor),
        tostring(oc.strength)
    }, "|")
end

function BiomeSystem._maybeInvalidateOnOCChange()
    local sig = BiomeSystem._computeOCSignature()
    if BiomeSystem._ocSignature ~= sig then
        -- Solo los biomas dependen de organicCoherence; los parámetros espaciales no
        BiomeSystem.biomeCache = {}
        BiomeSystem._ocSignature = sig
        if BiomeSystem.debugMode then
            print("[BiomeSystem] organicCoherence changed -> biome cache invalidated")
        end
    end
end

-- NUEVO: invalidación del caché de parámetros espaciales cuando cambia STRIDE/worldScale
function BiomeSystem._computeSamplingSignature()
    local c = MapConfig and MapConfig.chunk or {}
    return table.concat({
        tostring(c.size),
        tostring(c.tileSize),
        tostring(c.spacing),
        tostring(c.worldScale)
    }, "|")
end

function BiomeSystem._maybeInvalidateOnSamplingChange()
    local sig = BiomeSystem._computeSamplingSignature()
    if BiomeSystem._samplingSignature ~= sig then
        BiomeSystem.parameterCache = {}
        BiomeSystem._samplingSignature = sig
        if BiomeSystem.debugMode then
            print("[BiomeSystem] sampling scale changed -> parameter cache invalidated")
        end
    end
end

-- Configuración global del sistema de biomas
BiomeSystem.macro = BiomeSystem.macro or {
    scale = 0.04,
    strength = 1.35,
    offStrength = 0.90
}

-- NUEVO: parámetros de coherencia orgánica (regiones tipo “células” con centros jitter)
-- Forzar asignación campo-por-campo para permitir hot-reload y evitar que 'or' bloquee cambios
BiomeSystem.organicCoherence = BiomeSystem.organicCoherence or {}
BiomeSystem.organicCoherence.sizeChunks = 32    -- tamaño base de cada región en chunks (más grande que antes para parches mayores)
BiomeSystem.organicCoherence.jitter = 0.15      -- jitter relativo dentro de cada región (0..0.5)
BiomeSystem.organicCoherence.sigmaFactor = 1.2  -- suavizado de la “campana” de influencia (bordes más graduales)
BiomeSystem.organicCoherence.strength = 1.5     -- probabilidad de que la región reemplace al propuesto

-- NUEVO: estructura “cañones/grietas” que favorecen biomas lineales a través de múltiples chunks
BiomeSystem.structural = BiomeSystem.structural or {
    canyon = {
        enabled = false,    -- desactivar para evitar líneas densas y favorecer “islas” cohesivas
        scale = 0.035,      -- escala espacial del patrón de cañón (menor = estructuras más largas)
        warp = 12.0,        -- intensidad del domain-warp para curvas orgánicas
        width = 0.22,       -- grosor relativo de la línea (0..1), valores bajos = líneas finas
        strength = 2.5,     -- intensidad del sesgo a biomas preferidos en la línea
        -- peso por bioma dentro de las franjas de cañón (1.0 = fuerte, 0 = sin sesgo)
        prefer = {
            ASTEROID_BELT   = 1.0,
            GRAVITY_ANOMALY = 0.9,
            NEBULA_FIELD    = 0.6
        },
        -- penalización para Deep Space dentro de líneas (evita cortar las grietas)
        penalizeDeepSpace = 0.9
    }
}

-- Helpers internos para coherencia orgánica
local function _rand01_from_cell(cellX, cellY, salt)
    -- Usa hash determinista existente para derivar un float [0,1)
    local h = BiomeSystem.hashChunk(cellX * 7349 + salt * 1597, cellY * 9151 + salt * 31337)
    return (h % 10000) / 10000.0
end

function BiomeSystem._getJitteredCenterForCell(cellX, cellY)
    local oc = BiomeSystem.organicCoherence
    local size = oc.sizeChunks
    local baseX = cellX * size + size / 2
    local baseY = cellY * size + size / 2
    local j = oc.jitter
    local jx = ((_rand01_from_cell(cellX, cellY, 17) * 2) - 1) * j * size
    local jy = ((_rand01_from_cell(cellX, cellY, 23) * 2) - 1) * j * size
    return baseX + jx, baseY + jy
end

local function _scoreBiomeAtParams(bType, cfg, params)
    if not BiomeSystem.matchesBiomeConditions(params, cfg.conditions) then
        return nil
    end
    local score = cfg.spawnWeight

    if cfg.conditions.continentalness then
        local contLevel = BiomeSystem.findParameterLevel(params.continentalness, "continentalness")
        for _, allowedLevel in ipairs(cfg.conditions.continentalness) do
            if contLevel == allowedLevel then
                score = score * 1.2
                break
            end
        end
    end

    local depthRange = cfg.conditions.depthRange
    if depthRange and params.depth then
        local optimalDepth = (depthRange[1] + depthRange[2]) / 2
        local depthDistance = math.abs(params.depth - optimalDepth)
        local depthModifier = 1.0 + (0.3 - depthDistance * 0.6)
        depthModifier = math.max(0.7, math.min(1.3, depthModifier))
        score = score * depthModifier
    end

    return score
end

function BiomeSystem._getRegionalPreferredBiome(cellX, cellY)
    -- Evalúa biomas en el centro jitterizado de la celda para elegir un preferido “regional”
    local cx, cy = BiomeSystem._getJitteredCenterForCell(cellX, cellY)
    local params = BiomeSystem.generateSpaceParameters(cx, cy)
    local bestType, bestScore = nil, -1

    for bType, cfg in pairs(BiomeSystem.biomeConfigs) do
        local s = _scoreBiomeAtParams(bType, cfg, params)
        if s and s > bestScore then
            bestScore = s
            bestType = bType
        end
    end

    return bestType or BiomeSystem.BiomeType.DEEP_SPACE
end

function BiomeSystem._getOrganicInfluence(chunkX, chunkY)
    -- Encuentra el sitio más cercano entre la celda y vecinas; calcula peso gaussiano e infiere bioma regional preferido
    local oc = BiomeSystem.organicCoherence
    local size = oc.sizeChunks
    local cellX = math.floor(chunkX / size)
    local cellY = math.floor(chunkY / size)

    local bestD2 = math.huge
    local bestCellX, bestCellY = cellX, cellY
    local bestCenterX, bestCenterY = nil, nil

    for dx = -1, 1 do
        for dy = -1, 1 do
            local cx = cellX + dx
            local cy = cellY + dy
            local sx, sy = BiomeSystem._getJitteredCenterForCell(cx, cy)
            local dxu = (chunkX - sx)
            local dyu = (chunkY - sy)
            local d2 = dxu * dxu + dyu * dyu
            if d2 < bestD2 then
                bestD2 = d2
                bestCellX, bestCellY = cx, cy
                bestCenterX, bestCenterY = sx, sy
            end
        end
    end

    local sigma = size * oc.sigmaFactor
    local weight = 0.0
    if sigma > 0 then
        weight = math.exp(-bestD2 / (2 * sigma * sigma))
    end

    local preferred = BiomeSystem._getRegionalPreferredBiome(bestCellX, bestCellY)
    return preferred, weight, bestCenterX, bestCenterY
end

-- Determina el bioma preferido de la región a escala macro (por chunk)
function BiomeSystem.getMacroPreferredBiome(chunkX, chunkY)
    -- Preferencia macro continua: evita tamaños discretos y permite variabilidad orgánica
    local s = BiomeSystem.macro.scale
    local n = PerlinNoise.noise(chunkX * s, chunkY * s, 999)
    -- Rebalanceo: la zona central (más frecuente en Perlin) ahora cae más a menudo en biomas antes sub-representados
    if n <= -0.50 then
        return BiomeSystem.BiomeType.DEEP_SPACE
    elseif n <= -0.20 then
        return BiomeSystem.BiomeType.NEBULA_FIELD
    elseif n <= 0.15 then
        return BiomeSystem.BiomeType.GRAVITY_ANOMALY
    elseif n <= 0.50 then
        return BiomeSystem.BiomeType.RADIOACTIVE_ZONE
    elseif n <= 0.80 then
        return BiomeSystem.BiomeType.ASTEROID_BELT
    else
        return BiomeSystem.BiomeType.ANCIENT_RUINS
    end
end

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
    
    -- Activar perfil de depuración según seed (si aplica)
    BiomeSystem.setPresetProfileBySeed(BiomeSystem.seed)
    
    -- Inicializar Perlin con semilla numérica
    PerlinNoise.init(BiomeSystem.numericSeed)
    
    print("3D Biome System initialized with seed: " .. tostring(BiomeSystem.seed))
    print("Numeric seed: " .. BiomeSystem.numericSeed)
    print("Using improved 6-parameter generation with proper distribution")
    print("Height dimension affects object density, not biome visibility")
    print("All biomes can appear at any height for 2D top-down view")
    BiomeSystem._ocSignature = BiomeSystem._computeOCSignature()  -- registrar firma inicial para invalidación automática
    BiomeSystem._samplingSignature = BiomeSystem._computeSamplingSignature() -- NUEVO: firma de muestreo inicial
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
    BiomeSystem._maybeInvalidateOnSamplingChange()
    local cacheKey = chunkX .. "," .. chunkY
    
    if BiomeSystem.parameterCache[cacheKey] then
        return BiomeSystem.parameterCache[cacheKey]
    end
    
    -- Coordenadas del mundo
    local worldX = chunkX * STRIDE
    local worldY = chunkY * STRIDE
    
    -- YA NO cortamos por límites para evitar pérdida de biomas a grandes distancias
    -- (antes había un early return si no se cumplía isWithinWorldLimits(worldX, worldY))
    
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
    -- Ligeramente más extremos para favorecer biomas raros
    turbulence = math.max(-1, math.min(1, turbulence * 1.35))
    
    -- ANOMALÍAS (weirdness)
    local weirdness = PerlinNoise.noise(worldX * weirdScale + 3000, worldY * weirdScale + 3000, 400)
    weirdness = weirdness + PerlinNoise.noise(worldX * weirdScale * 4, worldY * weirdScale * 4, 450) * 0.2
    -- Ligeramente más extremos para favorecer biomas raros
    weirdness = math.max(-1, math.min(1, weirdness * 1.35))
    
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

-- Muestreador continuo de presencia de bioma en espacio de chunks (cx, cy pueden ser flotantes)
function BiomeSystem.sampleBiomePresence(biomeType, cx, cy)
    -- Usa la misma lógica de puntuación que getBiomeForChunk pero sin caché y con coordenadas continuas.
    local params = BiomeSystem.generateSpaceParameters(cx, cy)
    local biomeScores = {}
    local BT = BiomeSystem.BiomeType

    for bType, config in pairs(BiomeSystem.biomeConfigs) do
        if BiomeSystem.matchesBiomeConditions(params, config.conditions) then
            local score = config.spawnWeight

            if config.conditions.continentalness then
                local contLevel = BiomeSystem.findParameterLevel(params.continentalness, "continentalness")
                for _, allowedLevel in ipairs(config.conditions.continentalness) do
                    if contLevel == allowedLevel then
                        score = score * 1.2
                        break
                    end
                end
            end

            local depthRange = config.conditions.depthRange
            if depthRange and params.depth then
                local optimalDepth = (depthRange[1] + depthRange[2]) / 2
                local depthDistance = math.abs(params.depth - optimalDepth)
                local depthModifier = 1.0 + (0.3 - depthDistance * 0.6)
                depthModifier = math.max(0.7, math.min(1.3, depthModifier))
                score = score * depthModifier
            end

            table.insert(biomeScores, { type = bType, score = score })
        end
    end

    if #biomeScores == 0 then
        return (biomeType == BT.DEEP_SPACE) and 1.0 or 0.0
    end

    -- Sesgo macro (usa enteros cercanos para coherencia regional)
    local macroPreferred = BiomeSystem.getMacroPreferredBiome(math.floor(cx + 0.5), math.floor(cy + 0.5))
    for _, entry in ipairs(biomeScores) do
        if entry.type == macroPreferred then
            entry.score = entry.score * BiomeSystem.macro.strength
        else
            entry.score = entry.score * BiomeSystem.macro.offStrength
        end
    end

    -- Sesgo de preset de depuración (si está activo)
    do
        local profile = BiomeSystem.debugPresetProfile
        if profile and profile.preferBiome then
            local boost = profile.preferBiomeBoost or 1.0
            local reduce = profile.reduceOthers or 1.0
            for _, entry in ipairs(biomeScores) do
                if entry.type == profile.preferBiome then
                    entry.score = entry.score * boost
                else
                    entry.score = entry.score * reduce
                end
            end
        end
    end

    -- Sesgo por cañones/grietas (mismo patrón que en getBiomeForChunk)
    do
        local st = BiomeSystem.structural and BiomeSystem.structural.canyon
        if st and st.enabled then
            local function canyonMask01(xp, yp)
                local s = st.scale
                local wx = PerlinNoise.noise(xp * s * 0.7, yp * s * 0.7, 910) * st.warp
                local wy = PerlinNoise.noise(xp * s * 0.7 + 17, yp * s * 0.7 + 17, 911) * st.warp
                local xw = xp + wx
                local yw = yp + wy
                local base = PerlinNoise.noise(xw * s, yw * s, 777)
                local ridge = 1 - math.abs(base)
                local width = math.max(0.01, math.min(1.0, (BiomeSystem.structural.canyon.width or 0.22)))
                ridge = math.max(0, ridge - (1 - width)) / width
                ridge = math.max(0, math.min(1, ridge))
                return ridge
            end
            local mask = canyonMask01(cx, cy)
            if mask > 0 then
                for _, entry in ipairs(biomeScores) do
                    if entry.type == BT.DEEP_SPACE then
                        entry.score = entry.score * (1.0 - st.penalizeDeepSpace * mask)
                    end
                    local keyName = nil
                    if entry.type == BT.ASTEROID_BELT then
                        keyName = "ASTEROID_BELT"
                    elseif entry.type == BT.GRAVITY_ANOMALY then
                        keyName = "GRAVITY_ANOMALY"
                    elseif entry.type == BT.NEBULA_FIELD then
                        keyName = "NEBULA_FIELD"
                    end
                    local prefWeights = st.prefer or {}
                    local w = (keyName and prefWeights[keyName]) or 0
                    if w > 0 then
                        local k = 1.0 + st.strength * w * mask
                        entry.score = entry.score * k
                    end
                end
            end
        end
    end

    local total = 0
    local typeScore = 0
    for _, e in ipairs(biomeScores) do
        total = total + e.score
        if e.type == biomeType then
            typeScore = e.score
        end
    end

    if total <= 0 then return 0 end
    return typeScore / total
end

-- Determinar bioma basado en parámetros 3D
function BiomeSystem.getBiomeForChunk(chunkX, chunkY)
    BiomeSystem._maybeInvalidateOnOCChange()
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
    
    -- Aplicar sesgo macro-regional para formar parches grandes (4–15 chunks)
    local macroPreferred = BiomeSystem.getMacroPreferredBiome(chunkX, chunkY)
    for i, entry in ipairs(biomeScores) do
        if entry.type == macroPreferred then
            entry.score = entry.score * BiomeSystem.macro.strength
        else
            entry.score = entry.score * BiomeSystem.macro.offStrength
        end
    end

    -- NUEVO: aplicar sesgo del preset de F2 (si está activo) antes de la selección
    do
        local profile = BiomeSystem.debugPresetProfile
        if profile and profile.preferBiome then
            local boost = profile.preferBiomeBoost or 1.0
            local reduce = profile.reduceOthers or 1.0
            for _, entry in ipairs(biomeScores) do
                if entry.type == profile.preferBiome then
                    entry.score = entry.score * boost
                else
                    entry.score = entry.score * reduce
                end
            end
        end
    end

    -- NUEVO: Si el preset exige mayoría, forzar este chunk al bioma preferido con alta probabilidad
    do
        local profile = BiomeSystem.debugPresetProfile
        if profile and profile.preferBiome and profile.enforceMajority then
            local chance = profile.forceChance or 0.85
            if randomValue < chance then
                local params2 = BiomeSystem.generateSpaceParameters(chunkX, chunkY)
                local coherentType = BiomeSystem.applyCoherence3D(chunkX, chunkY, profile.preferBiome, params2)
                BiomeSystem.biomeCache[key] = coherentType
                return coherentType
            end
        end
    end

    -- NUEVO: Máscara de “cañones/grietas” para formas lineales a través de múltiples chunks
    local function canyonMask01(cx, cy)
        local st = BiomeSystem.structural and BiomeSystem.structural.canyon
        if not (st and st.enabled) then return 0.0 end
        local s = st.scale
        -- domain-warp para curvar líneas
        local wx = PerlinNoise.noise(cx * s * 0.7, cy * s * 0.7, 910) * st.warp
        local wy = PerlinNoise.noise(cx * s * 0.7 + 17, cy * s * 0.7 + 17, 911) * st.warp
        local xw = cx + wx
        local yw = cy + wy
        local base = PerlinNoise.noise(xw * s, yw * s, 777)
        local ridge = 1 - math.abs(base)
        local width = math.max(0.01, math.min(1.0, (BiomeSystem.structural.canyon.width or 0.22)))
        ridge = math.max(0, ridge - (1 - width)) / width
        ridge = math.max(0, math.min(1, ridge))
        return ridge
    end

    -- Aplicar sesgo de cañón a las puntuaciones (favorece biomas estructurales a lo largo de la línea)
    do
        local st = BiomeSystem.structural and BiomeSystem.structural.canyon
        if st and st.enabled then
            local mask = canyonMask01(chunkX, chunkY)
            if mask > 0 then
                for _, entry in ipairs(biomeScores) do
                    -- penaliza Deep Space dentro de la grieta
                    if entry.type == BiomeSystem.BiomeType.DEEP_SPACE then
                        entry.score = entry.score * (1.0 - st.penalizeDeepSpace * mask)
                    end
                    -- boost a biomas preferidos dentro de la grieta
                    local prefWeights = st.prefer or {}
                    local keyName = nil
                    if entry.type == BiomeSystem.BiomeType.ASTEROID_BELT then
                        keyName = "ASTEROID_BELT"
                    elseif entry.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
                        keyName = "GRAVITY_ANOMALY"
                    elseif entry.type == BiomeSystem.BiomeType.NEBULA_FIELD then
                        keyName = "NEBULA_FIELD"
                    end
                    local w = (keyName and prefWeights[keyName]) or 0
                    if w > 0 then
                        local k = 1.0 + st.strength * w * mask
                        entry.score = entry.score * k
                    end
                end
            end
        end
    end

    -- Selección por ruleta ponderada
    local totalScore = 0
    for _, entry in ipairs(biomeScores) do
        totalScore = totalScore + entry.score
    end
    
    local targetValue = randomValue * totalScore
    local accumulator = 0
    
    local selectedType = biomeScores[1].type
    for _, entry in ipairs(biomeScores) do
        accumulator = accumulator + entry.score
        if accumulator >= targetValue then
            selectedType = entry.type
            break
        end
    end

    -- Forzar bioma preferido por preset (si está activo) con alta probabilidad
    do
        local profile = BiomeSystem.debugPresetProfile
        if profile and profile.enforceMajority and profile.preferBiome then
            local forceChance = profile.forceChance or 0.9
            if randomValue < forceChance then
                selectedType = profile.preferBiome
            end
        end
    end

    -- Aplicar coherencia espacial con vecinos ya generados para unir parches
    local params = BiomeSystem.generateSpaceParameters(chunkX, chunkY)
    local coherentType = BiomeSystem.applyCoherence3D(chunkX, chunkY, selectedType, params)

    BiomeSystem.biomeCache[key] = coherentType
    return coherentType
end

-- Sistema de coherencia espacial con cohesión orgánica y suavizado local
function BiomeSystem.applyCoherence3D(chunkX, chunkY, proposedBiome, params)
    -- Respeta el preset si está forzado y coincide con lo propuesto
    do
        local profile = BiomeSystem.debugPresetProfile
        if profile and profile.enforceMajority and profile.preferBiome and proposedBiome == profile.preferBiome then
            return proposedBiome
        end
    end

    -- Coherencia orgánica basada en regiones jitterizadas (sitios tipo Voronoi)
    local regionalPreferred, influence = BiomeSystem._getOrganicInfluence(chunkX, chunkY)

    -- Si la región prefiere el mismo bioma, no hay nada que hacer
    if regionalPreferred == proposedBiome then
        return proposedBiome
    end

    -- No dejamos que Deep Space absorba demasiado: reduce su capacidad de “robar” el chunk
    local oc = BiomeSystem.organicCoherence
    local threshold = influence * oc.strength
    if regionalPreferred == BiomeSystem.BiomeType.DEEP_SPACE then
        threshold = threshold * 0.6
    end

    -- Solo podemos cambiar a un bioma que cumpla condiciones en este chunk
    local cfg = BiomeSystem.getBiomeConfig(regionalPreferred)
    if not BiomeSystem.matchesBiomeConditions(params, cfg.conditions) then
        return proposedBiome
    end

    -- Decisión determinista por chunk usando hash
    local rv = (BiomeSystem.hashChunk(chunkX * 101 + 7, chunkY * 137 + 11) % 10000) / 10000.0
    if rv < threshold then
        return regionalPreferred
    end

    -- Fallback determinista: coherencia regional sin depender del caché y con vecindad circular + sesgo de cañón
    local proposedConfig = BiomeSystem.biomeConfigs[proposedBiome]
    local coherenceRadius = math.max(1, proposedConfig.coherenceRadius or 1)

    -- Función local para máscara de cañón (igual a la usada en getBiomeForChunk)
    local function canyonMask01(cx, cy)
        local st = BiomeSystem.structural and BiomeSystem.structural.canyon
        if not (st and st.enabled) then return 0.0 end
        local s = st.scale
        local wx = PerlinNoise.noise(cx * s * 0.7, cy * s * 0.7, 910) * st.warp
        local wy = PerlinNoise.noise(cx * s * 0.7 + 17, cy * s * 0.7 + 17, 911) * st.warp
        local xw = cx + wx
        local yw = cy + wy
        local base = PerlinNoise.noise(xw * s, yw * s, 777)
        local ridge = 1 - math.abs(base)
        local width = math.max(0.01, math.min(1.0, (BiomeSystem.structural.canyon.width or 0.22)))
        ridge = math.max(0, ridge - (1 - width)) / width
        ridge = math.max(0, math.min(1, ridge))
        return ridge
    end

    -- Contar bioma regional preferido en disco de radio R
    local counts = {}
    local totalWeight = 0.0
    local st = BiomeSystem.structural and BiomeSystem.structural.canyon
    local preferWeights = st and st.prefer or {}
    local penalizeDeep = st and (st.penalizeDeepSpace or 0.0) or 0.0

    for dx = -coherenceRadius, coherenceRadius do
        for dy = -coherenceRadius, coherenceRadius do
            if not (dx == 0 and dy == 0) then
                local d2 = dx*dx + dy*dy
                if d2 <= coherenceRadius * coherenceRadius then
                    local nx, ny = chunkX + dx, chunkY + dy
                    -- Bioma regional preferido del vecino (determinista, no depende de caché)
                    local neighborPreferred = BiomeSystem._getRegionalPreferredBiome(math.floor(nx / oc.sizeChunks), math.floor(ny / oc.sizeChunks))

                    -- Peso por distancia (más cerca = mayor peso)
                    local dist = math.sqrt(d2)
                    local w = 1.0 - (dist / coherenceRadius)
                    w = math.max(0.05, w)

                    -- Sesgo por cañón en la muestra vecina
                    local mask = canyonMask01(nx, ny)
                    if mask > 0 then
                        if neighborPreferred == BiomeSystem.BiomeType.DEEP_SPACE then
                            w = w * (1.0 - penalizeDeep * mask)
                        else
                            local keyName = nil
                            if neighborPreferred == BiomeSystem.BiomeType.ASTEROID_BELT then keyName = "ASTEROID_BELT"
                            elseif neighborPreferred == BiomeSystem.BiomeType.GRAVITY_ANOMALY then keyName = "GRAVITY_ANOMALY"
                            elseif neighborPreferred == BiomeSystem.BiomeType.NEBULA_FIELD then keyName = "NEBULA_FIELD" end
                            local pw = (keyName and preferWeights[keyName]) or 0
                            if pw > 0 then
                                w = w * (1.0 + (st.strength or 1.0) * pw * mask)
                            end
                        end
                    end

                    counts[neighborPreferred] = (counts[neighborPreferred] or 0.0) + w
                    totalWeight = totalWeight + w
                end
            end
        end
    end

    if totalWeight <= 0 then
        return proposedBiome
    end

    -- Encontrar dominante (evitar Deep Space si hay otra opción suficientemente fuerte)
    local dominantBiome, maxW = nil, -1
    for b, w in pairs(counts) do
        if w > maxW then
            maxW = w
            dominantBiome = b
        end
    end

    local fraction = maxW / totalWeight
    local neighborThreshold = 0.45 -- reducido de 0.58 a 0.45 para mayor cohesión

    if dominantBiome and dominantBiome ~= BiomeSystem.BiomeType.DEEP_SPACE and fraction >= neighborThreshold then
        local dominantConfig = BiomeSystem.biomeConfigs[dominantBiome]
        if BiomeSystem.matchesBiomeConditions(params, dominantConfig.conditions) then
            return dominantBiome
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
    
    -- Calcular top-2 candidatos para mezcla (mismo pipeline de puntuación que getBiomeForChunk)
    local biomeScores = {}
    for bType, bCfg in pairs(BiomeSystem.biomeConfigs) do
        if BiomeSystem.matchesBiomeConditions(params, bCfg.conditions) then
            local score = bCfg.spawnWeight

            if bCfg.conditions.continentalness then
                local contLevel = BiomeSystem.findParameterLevel(params.continentalness, "continentalness")
                for _, allowedLevel in ipairs(bCfg.conditions.continentalness) do
                    if contLevel == allowedLevel then
                        score = score * 1.2
                        break
                    end
                end
            end

            local depthRange = bCfg.conditions.depthRange
            if depthRange and params.depth then
                local optimalDepth = (depthRange[1] + depthRange[2]) / 2
                local depthDistance = math.abs(params.depth - optimalDepth)
                local depthModifier = 1.0 + (0.3 - depthDistance * 0.6)
                depthModifier = math.max(0.7, math.min(1.3, depthModifier))
                score = score * depthModifier
            end

            table.insert(biomeScores, { type = bType, score = score })
        end
    end

    if #biomeScores == 0 then
        biomeScores = { { type = BiomeSystem.BiomeType.DEEP_SPACE, score = 1.0 } }
    else
        local macroPreferred = BiomeSystem.getMacroPreferredBiome(chunkX, chunkY)
        for _, entry in ipairs(biomeScores) do
            if entry.type == macroPreferred then
                entry.score = entry.score * BiomeSystem.macro.strength
            else
                entry.score = entry.score * BiomeSystem.macro.offStrength
            end
        end
    end

    -- NUEVO: aplicar también el sesgo del preset aquí para que la mezcla A/B refleje el preset
    do
        local profile = BiomeSystem.debugPresetProfile
        if profile and profile.preferBiome then
            local boost = profile.preferBiomeBoost or 1.0
            local reduce = profile.reduceOthers or 1.0
            for _, entry in ipairs(biomeScores) do
                if entry.type == profile.preferBiome then
                    entry.score = entry.score * boost
                else
                    entry.score = entry.score * reduce
                end
            end

            -- Extra: si se exige mayoría, hacer que el preferido gane casi siempre en la mezcla
            if profile.enforceMajority then
                local sb = profile.enforceScoreBoost or 100.0
                local sr = profile.enforceScoreReduce or 0.25
                for _, entry in ipairs(biomeScores) do
                    if entry.type == profile.preferBiome then
                        entry.score = entry.score * sb
                    else
                        entry.score = entry.score * sr
                    end
                end
            end
        end
    end

    -- NUEVO: sesgo por cañones/grietas para que la mezcla A/B también forme líneas orgánicas
    do
        local st = BiomeSystem.structural and BiomeSystem.structural.canyon
        if st and st.enabled then
            local function canyonMask01(cx, cy)
                local s = st.scale
                local wx = PerlinNoise.noise(cx * s * 0.7, cy * s * 0.7, 910) * st.warp
                local wy = PerlinNoise.noise(cx * s * 0.7 + 17, cy * s * 0.7 + 17, 911) * st.warp
                local xw = cx + wx
                local yw = cy + wy
                local base = PerlinNoise.noise(xw * s, yw * s, 777)
                local ridge = 1 - math.abs(base)
                local width = math.max(0.01, math.min(1.0, (BiomeSystem.structural.canyon.width or 0.22)))
                ridge = math.max(0, ridge - (1 - width)) / width
                ridge = math.max(0, math.min(1, ridge))
                return ridge
            end
            local mask = canyonMask01(chunkX, chunkY)
            if mask > 0 then
                for _, entry in ipairs(biomeScores) do
                    if entry.type == BiomeSystem.BiomeType.DEEP_SPACE then
                        entry.score = entry.score * (1.0 - st.penalizeDeepSpace * mask)
                    end
                    local prefWeights = st.prefer or {}
                    local keyName = nil
                    if entry.type == BiomeSystem.BiomeType.ASTEROID_BELT then
                        keyName = "ASTEROID_BELT"
                    elseif entry.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
                        keyName = "GRAVITY_ANOMALY"
                    elseif entry.type == BiomeSystem.BiomeType.NEBULA_FIELD then
                        keyName = "NEBULA_FIELD"
                    end
                    local w = (keyName and prefWeights[keyName]) or 0
                    if w > 0 then
                        local k = 1.0 + st.strength * w * mask
                        entry.score = entry.score * k
                    end
                end
            end
        end
    end

    table.sort(biomeScores, function(a, b) return a.score > b.score end)
    local topA = biomeScores[1]
    local topB = topA
    for _, entry in ipairs(biomeScores) do
        if entry.type ~= biomeType then
            topB = entry
            break
        end
    end

    local function scoreOf(typeId)
        for _, e in ipairs(biomeScores) do
            if e.type == typeId then return e.score end
        end
        return 0
    end

    local scoreA = scoreOf(biomeType)
    local scoreB = (topB and topB.score) or 0
    local denom = scoreA + scoreB
    local blendValue = (denom > 0) and (scoreB / denom) or 0

    return {
        type = biomeType,
        name = config.name,
        config = config,
        coordinates = {x = chunkX, y = chunkY},
        parameters = params,
        blend = {
            biomeA = biomeType,
            biomeB = topB and topB.type or biomeType,
            blend = blendValue
        }
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

    -- Aplicar perfil de depuración por preset (si la seed coincide con un preset de F2)
    local profile = BiomeSystem.debugPresetProfile
    if profile then
        -- Multiplicadores globales por tipo de objeto
        local gm = profile.globalMul or {}
        if gm.asteroids then modifiedDensities.asteroids = (modifiedDensities.asteroids or 0) * gm.asteroids end
        if gm.nebulae then modifiedDensities.nebulae = (modifiedDensities.nebulae or 0) * gm.nebulae end
        if gm.stars then modifiedDensities.stars = (modifiedDensities.stars or 0) * gm.stars end
        if gm.stations then modifiedDensities.stations = (modifiedDensities.stations or 0) * gm.stations end
        if gm.wormholes then modifiedDensities.wormholes = (modifiedDensities.wormholes or 0) * gm.wormholes end
        if gm.specialFeatures then modifiedDensities.specialFeatures = (modifiedDensities.specialFeatures or 0) * gm.specialFeatures end

        -- Favorecer bioma preferido y penalizar el resto (si corresponde)
        if profile.preferBiome then
            if biomeType == profile.preferBiome then
                local boost = profile.preferBiomeBoost or 1.0
                for k, v in pairs(modifiedDensities) do
                    modifiedDensities[k] = v * boost
                end
            else
                local reduce = profile.reduceOthers or 1.0
                for k, v in pairs(modifiedDensities) do
                    modifiedDensities[k] = v * reduce
                end
            end
        end
    end
    
    return modifiedDensities
end

-- Mezcla de densidades por bioma usando biomeBlend = { biomeA, biomeB, blend }
function BiomeSystem.modifyDensitiesBlended(baseDensities, biomeBlend, chunkX, chunkY)
    local A = biomeBlend and biomeBlend.biomeA
    local B = biomeBlend and biomeBlend.biomeB
    local t = biomeBlend and biomeBlend.blend or 0
    t = math.max(0, math.min(1, t))

    if not A or not B or A == B or t == 0 then
        return BiomeSystem.modifyDensities(baseDensities, A or B or BiomeSystem.BiomeType.DEEP_SPACE, chunkX, chunkY)
    end

    local dA = BiomeSystem.modifyDensities(baseDensities, A, chunkX, chunkY)
    local dB = BiomeSystem.modifyDensities(baseDensities, B, chunkX, chunkY)

    local mixed = {}
    for k, base in pairs(baseDensities) do
        local va = dA[k] or base
        local vb = dB[k] or base
        mixed[k] = va * (1 - t) + vb * t
    end
    return mixed
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
    
    local maxChunk = math.floor(BiomeSystem.WORLD_LIMIT / STRIDE)
    
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

-- NUEVO: specialFeatures con mezcla A/B
function BiomeSystem.generateSpecialFeaturesBlended(chunk, chunkX, chunkY, blend)
    if not blend or not blend.biomeA or not blend.biomeB then
        -- Fallback: mantener comportamiento previo
        return BiomeSystem.generateSpecialFeatures(chunk, chunkX, chunkY, (blend and blend.biomeA) or BiomeSystem.BiomeType.DEEP_SPACE)
    end

    local biomeA = blend.biomeA
    local biomeB = blend.biomeB
    local t = math.max(0, math.min(1, blend.blend or 0))

    local configA = BiomeSystem.getBiomeConfig(biomeA)
    local configB = BiomeSystem.getBiomeConfig(biomeB)

    local featsA = configA.specialFeatures or {}
    local featsB = configB.specialFeatures or {}

    if (#featsA == 0) and (#featsB == 0) then return end

    local params = BiomeSystem.generateSpaceParameters(chunkX, chunkY)

    local energyBonus = params.energy > 0.5 and 1.5 or 1.0
    local weirdnessBonus = math.abs(params.weirdness) > 0.5 and 2.0 or 1.0
    local depthBonus = (params.depth < 0.2 or params.depth > 0.8) and 1.3 or 1.0

    local totalBonus = energyBonus * weirdnessBonus * depthBonus

    -- Hashes deterministas separados para A y B para evitar correlación
    local hashA = BiomeSystem.hashChunk(chunkX + 1000, chunkY + 1000)
    local hashB = BiomeSystem.hashChunk(chunkX + 2000, chunkY + 2000)

    local baseChance = 0.01
    local chanceA = baseChance * (1 - t) * totalBonus
    local chanceB = baseChance * t * totalBonus

    -- Generar desde A
    for i, featureType in ipairs(featsA) do
        local fr = ((hashA + i * 12345) % 10000) / 10000.0
        if fr < chanceA then
            BiomeSystem.addSpecialFeature(chunk, featureType, chunkX, chunkY, params)
        end
    end

    -- Generar desde B
    for i, featureType in ipairs(featsB) do
        local fr = ((hashB + i * 54321) % 10000) / 10000.0
        if fr < chanceB then
            BiomeSystem.addSpecialFeature(chunk, featureType, chunkX, chunkY, params)
        end
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
    local cs = MapConfig.chunk.size
    local ts = MapConfig.chunk.tileSize

    -- Ocupa todo el rango [0, cs-1] sin márgenes fijos
    local randX = featureHash % cs
    local randY = math.floor(featureHash / cs) % cs
    
    local feature = {
        type = featureType,
        x = randX * ts,
        y = randY * ts,
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

-- NUEVO: color de fondo mezclado por chunk según su blend A/B
function BiomeSystem.getBackgroundColorBlended(blend)
    if not blend or not blend.biomeA or not blend.biomeB then
        return BiomeSystem.getBackgroundColor((blend and (blend.biomeA or blend.biomeB)) or BiomeSystem.BiomeType.DEEP_SPACE)
    end
    local cA = BiomeSystem.getBackgroundColor(blend.biomeA) or {1, 1, 1, 1}
    local cB = BiomeSystem.getBackgroundColor(blend.biomeB) or {1, 1, 1, 1}
    local t = math.max(0, math.min(1, blend.blend or 0))
    local r = cA[1] * (1 - t) + cB[1] * t
    local g = cA[2] * (1 - t) + cB[2] * t
    local b = cA[3] * (1 - t) + cB[3] * t
    local a = (cA[4] or 1) * (1 - t) + (cB[4] or 1) * t
    return { r, g, b, a }
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

    -- Usar la misma malla que el sistema de generación/render (stride escalado)
    local strideScaled = (Map.stride or (((Map.chunkSize or 0) * (Map.tileSize or 0)) + (Map.spacing or 0))) * (Map.worldScale or 1)

    if strideScaled <= 0 then
        -- Fallback seguro si faltan datos en Map
        local cs = (MapConfig.chunk.size * MapConfig.chunk.tileSize) + (MapConfig.chunk.spacing or 0)
        strideScaled = cs * (MapConfig.chunk.worldScale or 1)
    end

    if not BiomeSystem.isWithinWorldLimits(x, y) then
        return {{
            type = BiomeSystem.BiomeType.DEEP_SPACE,
            name = "Deep Space",
            distance = 0,
            config = BiomeSystem.getBiomeConfig(BiomeSystem.BiomeType.DEEP_SPACE)
        }}
    end

    -- Calcular el chunk de partida usando la misma función que usa todo el mapa
    local startChunkX, startChunkY = Map.getChunkInfo(x, y)

    -- Radio en chunks coherente con strideScaled
    local chunkRadius = math.ceil(radius / strideScaled)

    local foundBiomes = {}
    local minDistances = {}

    for dx = -chunkRadius, chunkRadius do
        for dy = -chunkRadius, chunkRadius do
            local chunkX = startChunkX + dx
            local chunkY = startChunkY + dy

            -- Bounds del chunk en coordenadas de mundo usando strideScaled
            local chunkLeft = chunkX * strideScaled
            local chunkTop = chunkY * strideScaled
            local chunkRight = chunkLeft + strideScaled
            local chunkBottom = chunkTop + strideScaled

            local dxMin = 0
            if x < chunkLeft then
                dxMin = chunkLeft - x
            elseif x > chunkRight then
                dxMin = x - chunkRight
            end

            local dyMin = 0
            if y < chunkTop then
                dyMin = chunkTop - y
            elseif y > chunkBottom then
                dyMin = y - chunkBottom
            end

            local distance = math.sqrt(dxMin * dxMin + dyMin * dyMin)

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