-- src/maps/systems/ancient_ruins_renderer.lua
-- Sistema de renderizado modular para el bioma Ancient Ruins

local AncientRuinsRenderer = {}

-- Dependencias
local MapConfig = require 'src.maps.config.map_config'
local ShaderManager = require 'src.shaders.shader_manager'

-- Configuración específica para ancient ruins
AncientRuinsRenderer.config = {
    -- Configuración de placeholders circulares (solo 1 por bioma)
    placeholders = {
        -- Tamaños de estaciones: grande (90% del bioma), mediano, pequeño
        sizes = {
            large = 0.4,    
            medium = 0.2,   
            small = 0.1    
        },
        -- Probabilidades de cada tamaño
        sizeWeights = {
            large = 0.4,    -- 40% probabilidad de estación grande
            medium = 0.35,  -- 35% probabilidad de estación mediana
            small = 0.25    -- 25% probabilidad de estación pequeña
        },
        -- Sistema de tipos base y estados de daño coherentes
        baseStationTypes = {
            ring_station = {
                name = "estacion_anillo",
                weight = 0.4,  -- 40% probabilidad de tipo anillo
                baseShape = "ring"
            },
            modular_station = {
                name = "estacion_modular",
                weight = 0.35,  -- 35% probabilidad de tipo modular
                baseShape = "modular"
            },
            elongated_ship = {
                name = "nave_alargada",
                weight = 0.25,  -- 25% probabilidad de tipo nave
                baseShape = "elongated"
            }
        },
        
        -- Estados de daño para cada tipo base
        damageStates = {
            operational = {
                name = "operacional",
                weight = 0.3,  -- 30% probabilidad de estar operacional
                suffix = "_operational"
            },
            damaged = {
                name = "parcialmente_destruida",
                weight = 0.45,  -- 45% probabilidad de estar dañada
                suffix = "_damaged"
            },
            ruins = {
                name = "ruinas_totales",
                weight = 0.25,  -- 25% probabilidad de ser ruinas
                suffix = "_ruins"
            }
        },
        
        -- Configuraciones específicas por tipo y estado
        stationConfigs = {
            -- Estaciones tipo anillo
            ring_operational = {
                shape = "ring_operational",
                color = {0.45, 0.5, 0.55, 1.0},  -- Metálico brillante
                glowColor = {0.7, 0.8, 0.9, 1.0},  -- Resplandor azul intenso
                alpha = 1.0,
                structuralIntegrity = 1.0
            },
            ring_damaged = {
                shape = "ring_damaged",
                color = {0.3, 0.35, 0.4, 1.0},  -- Gris metálico espacial dañado
                glowColor = {0.4, 0.5, 0.6, 1.0},  -- Resplandor azul frío reducido
                alpha = 1.0,
                structuralIntegrity = 0.6
            },
            ring_ruins = {
                shape = "ring_ruins",
                color = {0.15, 0.18, 0.22, 1.0},  -- Gris espacial muy oscuro
                glowColor = {0.2, 0.25, 0.35, 1.0},  -- Resplandor azul muy tenue
                alpha = 1.0,
                structuralIntegrity = 0.2
            },
            
            -- Estaciones modulares (tonos azul-verdosos industriales)
            modular_operational = {
                shape = "modular_operational",
                color = {0.3, 0.5, 0.45, 1.0},  -- Verde azulado industrial
                glowColor = {0.4, 0.8, 0.7, 1.0},  -- Resplandor verde-azul brillante
                alpha = 1.0,
                structuralIntegrity = 1.0
            },
            modular_damaged = {
                shape = "modular_damaged",
                color = {0.25, 0.35, 0.32, 1.0},  -- Verde azulado apagado
                glowColor = {0.3, 0.5, 0.45, 1.0},  -- Resplandor verde-azul tenue
                alpha = 1.0,
                structuralIntegrity = 0.5
            },
            modular_ruins = {
                shape = "modular_ruins",
                color = {0.15, 0.20, 0.18, 1.0},  -- Verde grisáceo muy oscuro
                glowColor = {0.2, 0.3, 0.25, 1.0},  -- Resplandor verde muy débil
                alpha = 1.0,
                structuralIntegrity = 0.15
            },
            
            -- Naves alargadas (tonos rojizo-naranjas militares)
            elongated_operational = {
                shape = "elongated_operational",
                color = {0.5, 0.35, 0.25, 1.0},  -- Bronce militar sólido
                glowColor = {0.8, 0.5, 0.3, 1.0},  -- Resplandor naranja cálido
                alpha = 1.0,
                structuralIntegrity = 1.0
            },
            elongated_damaged = {
                shape = "elongated_damaged",
                color = {0.42, 0.28, 0.20, 1.0},  -- Bronce oxidado dañado
                glowColor = {0.6, 0.35, 0.22, 1.0},  -- Resplandor naranja apagado
                alpha = 1.0,
                structuralIntegrity = 0.4
            },
            elongated_ruins = {
                shape = "elongated_ruins",
                color = {0.25, 0.15, 0.12, 1.0},  -- Óxido muy oscuro
                glowColor = {0.35, 0.20, 0.15, 1.0},  -- Resplandor rojizo muy tenue
                alpha = 1.0,
                structuralIntegrity = 0.1
            }
        }
    },
    
    -- Configuración de LOD mejorada con más niveles de detalle
    lod = {
        maxDistance = 16000,  -- Distancia máxima de renderizado aumentada
        lodThresholds = {2000, 5000, 10000, 14000},  -- Umbrales desplazados para mantener más detalle desde lejos
        -- Configuración de detalles por LOD
        details = {
            [0] = { -- LOD máximo (muy cerca)
                showMicroStructures = true,
                showLightingDetails = true,
                showVolumeEffects = true,
                segmentMultiplier = 1.5,
                extraElements = true,
                -- Parámetros visuales de shader
                specular = { intensity = 0.8, exponent = 32.0 },
                rimLight = { intensity = 0.35, width = 2.0 }
            },
            [1] = { -- LOD alto (cerca)
                showMicroStructures = true,
                showLightingDetails = true,
                showVolumeEffects = true,
                segmentMultiplier = 1.2,
                extraElements = false,
                -- Parámetros visuales de shader
                specular = { intensity = 0.6, exponent = 24.0 },
                rimLight = { intensity = 0.25, width = 2.2 }
            },
            [2] = { -- LOD medio (distancia media)
                showMicroStructures = false,
                showLightingDetails = true,
                showVolumeEffects = true,
                segmentMultiplier = 1.0,
                extraElements = false,
                -- Parámetros visuales de shader
                specular = { intensity = 0.4, exponent = 16.0 },
                rimLight = { intensity = 0.15, width = 2.5 }
            },
            [3] = { -- LOD bajo (lejos)
                showMicroStructures = false,
                showLightingDetails = false,
                showVolumeEffects = false,
                segmentMultiplier = 0.8,
                extraElements = false,
                -- Parámetros visuales de shader
                specular = { intensity = 0.2, exponent = 12.0 },
                rimLight = { intensity = 0.08, width = 3.0 }
            },
            [4] = { -- LOD mínimo (muy lejos)
                showMicroStructures = false,
                showLightingDetails = false,
                showVolumeEffects = false,
                segmentMultiplier = 0.85,
                extraElements = false,
                -- Parámetros visuales de shader
                specular = { intensity = 0.1, exponent = 8.0 },
                rimLight = { intensity = 0.05, width = 3.5 }
            }
        }
    }
}

-- Función para generar placeholders en un chunk
function AncientRuinsRenderer.generatePlaceholders(chunk, chunkX, chunkY, rng)
    local BiomeSystem = require 'src.maps.biome_system'
    
    -- Solo generar en bioma ancient_ruins
    if chunk.biome.type ~= BiomeSystem.BiomeType.ANCIENT_RUINS then
        return
    end
    
    -- Inicializar lista de placeholders del chunk si no existe
    if not chunk.ancientRuinsPlaceholders then
        chunk.ancientRuinsPlaceholders = {}
    end
    
    -- Solo generar 1 placeholder por bioma (usar chunk central como referencia)
    -- Verificar si ya existe un placeholder en este bioma
    if #chunk.ancientRuinsPlaceholders > 0 then
        return
    end
    
    local chunkSize = MapConfig.chunk.size
    local tileSize = MapConfig.chunk.tileSize
    local worldScale = MapConfig.chunk.worldScale or 1.0
    local spacing = MapConfig.chunk.spacing or 0
    local config = AncientRuinsRenderer.config.placeholders
    
    -- Calcular STRIDE respetando spacing y worldScale
    local STRIDE = (chunkSize * tileSize + spacing)
    local chunkWorldX = chunkX * STRIDE * worldScale
    local chunkWorldY = chunkY * STRIDE * worldScale
    
    -- Calcular el tamaño del bioma (aproximadamente el tamaño del chunk en mundo)
    local biomeSize = STRIDE * worldScale
    
    -- Determinar el tamaño de la estación basado en probabilidades
    local sizeType = AncientRuinsRenderer.selectStationSize(rng)
    local stationSize = biomeSize * config.sizes[sizeType]
    
    -- Seleccionar tipo base y estado de daño
    local baseType = AncientRuinsRenderer.selectBaseStationType(chunkX, chunkY)
    local damageState = AncientRuinsRenderer.selectDamageState(chunkX, chunkY)
    local complexType = baseType .. "_" .. damageState
    
    -- Posición central del chunk para la estación escalada correctamente por worldScale
    local localX = (chunkSize * tileSize) * 0.5 * worldScale
    local localY = (chunkSize * tileSize) * 0.5 * worldScale
    local worldX = chunkWorldX + localX
    local worldY = chunkWorldY + localY
    local seed = (chunkX * 1000 + chunkY)
    
    -- Pre-obtener efectos de daño cacheados
    local damageEffects = AncientRuinsRenderer.getDamageEffects(damageState, seed)

    -- Calcular ubicación y dimensiones de la Bahía de Atraque (Docking Bay)
    local dockAngle = (seed * 0.47) % (math.pi * 2)
    local dockDistRatio = 0.90
    if baseType == "modular" then
        dockDistRatio = 0.60
    elseif baseType == "elongated" then
        dockDistRatio = 0.75
    end
    local dockDist = stationSize * dockDistRatio
    local dockWorldX = worldX + math.cos(dockAngle) * dockDist
    local dockWorldY = worldY + math.sin(dockAngle) * dockDist
    local dockRadius = math.max(65, stationSize * 0.12)

    local dockingBay = {
        angle = dockAngle,
        distRatio = dockDistRatio,
        worldX = dockWorldX,
        worldY = dockWorldY,
        radius = dockRadius,
        width = math.max(48, stationSize * 0.10),
        height = math.max(32, stationSize * 0.06),
        name = "DOCK-01"
    }

    -- Precomputar campo de escombros orbitales (placas de blindaje a la deriva)
    local orbitalDebris = {}
    local debrisCount = (damageState == "ruins" and 10) or (damageState == "damaged" and 7) or 4
    for i = 1, debrisCount do
        local dAngle = (i / debrisCount) * 2 * math.pi + (seed % 19) * 0.22
        local dDistRatio = 1.15 + ((i * 7) % 5) * 0.06
        local dWidth = math.max(16, stationSize * (0.04 + (i % 3) * 0.02))
        local dHeight = math.max(8, stationSize * (0.02 + (i % 2) * 0.015))
        local rotSpeed = ((i % 2 == 0) and 1 or -1) * (0.03 + (i % 4) * 0.015)
        table.insert(orbitalDebris, {
            baseAngle = dAngle,
            distRatio = dDistRatio,
            width = dWidth,
            height = dHeight,
            baseRot = (i * 1.3),
            rotSpeed = rotSpeed
        })
    end
    
    -- Crear el placeholder para este bioma con dockingBay y orbitalDebris
    local placeholder = {
        type = "ancient_placeholder",
        stationSize = sizeType,  -- "large", "medium", o "small"
        complexType = complexType,  -- tipo de complejo espacial
        x = worldX,
        y = worldY,
        localX = localX,
        localY = localY,
        size = stationSize,
        rotation = rng:random() * math.pi * 2,
        pulsePhase = rng:random() * math.pi * 2,
        chunkX = chunkX,
        chunkY = chunkY,
        seed = seed,
        damageEffects = damageEffects,
        dockingBay = dockingBay,
        orbitalDebris = orbitalDebris
    }
    
    table.insert(chunk.ancientRuinsPlaceholders, placeholder)
end

-- Función auxiliar para seleccionar el tamaño de la estación
function AncientRuinsRenderer.selectStationSize(rng)
    local config = AncientRuinsRenderer.config.placeholders.sizeWeights
    local random = rng:random()
    
    if random < config.large then
        return "large"
    elseif random < config.large + config.medium then
        return "medium"
    else
        return "small"
    end
end

-- Función auxiliar para seleccionar el tipo base de estación
function AncientRuinsRenderer.selectBaseStationType(chunkX, chunkY)
    local config = AncientRuinsRenderer.config.placeholders.baseStationTypes
    
    -- Usar coordenadas del chunk para generar un valor determinístico
    local seed = math.abs(chunkX * 73 + chunkY * 41) % 1000
    local random = seed / 1000
    
    -- Orden determinístico de tipos para asegurar variedad
    local orderedTypes = {
        {"ring", config.ring_station},
        {"modular", config.modular_station},
        {"elongated", config.elongated_ship}
    }
    
    local cumulative = 0
    for _, typeData in ipairs(orderedTypes) do
        local baseType, typeConfig = typeData[1], typeData[2]
        cumulative = cumulative + typeConfig.weight
        if random < cumulative then
            return baseType
        end
    end
    
    return "ring"  -- fallback
end

-- Función auxiliar para seleccionar el estado de daño
function AncientRuinsRenderer.selectDamageState(chunkX, chunkY)
    local config = AncientRuinsRenderer.config.placeholders.damageStates
    
    -- Usar coordenadas diferentes para el estado de daño (más variación)
    local seed = math.abs(chunkX * 127 + chunkY * 83) % 1000
    local random = seed / 1000
    
    -- Orden determinístico de estados
    local orderedStates = {
        {"operational", config.operational},
        {"damaged", config.damaged},
        {"ruins", config.ruins}
    }
    
    local cumulative = 0
    for _, stateData in ipairs(orderedStates) do
        local damageState, stateConfig = stateData[1], stateData[2]
        cumulative = cumulative + stateConfig.weight
        if random < cumulative then
            return damageState
        end
    end
    
    return "damaged"  -- fallback
end

local damageEffectsCache = {}
local debrisPolygonsCache = {}
local debrisPolygonsCache12 = {}

local function getRuinsDebrisPolygons(seed)
    local s = seed or 0
    if debrisPolygonsCache[s] then return debrisPolygonsCache[s] end
    local list = {}
    for i = 1, 6 do
        local angle = (i / 6) * 2 * math.pi + s * 0.1
        local distance = 1.2 + (i % 3) * 0.2
        local fragX = math.cos(angle) * distance
        local fragY = math.sin(angle) * distance
        local fragSize = 0.05 + (i % 2) * 0.03
        table.insert(list, {
            fragX - fragSize,       fragY - fragSize * 0.5,
            fragX + fragSize * 0.7, fragY - fragSize * 0.3,
            fragX + fragSize * 0.5, fragY + fragSize,
            fragX - fragSize * 0.8, fragY + fragSize * 0.4
        })
    end
    debrisPolygonsCache[s] = list
    return list
end

local function getRuinsDebrisPolygons12(seed)
    local s = seed or 0
    if debrisPolygonsCache12[s] then return debrisPolygonsCache12[s] end
    local list = {}
    for i = 1, 12 do
        local angle = (i / 12) * 2 * math.pi + s * 0.3
        local distance = 0.8 + (i % 4) * 0.3
        local fragX = math.cos(angle) * distance
        local fragY = math.sin(angle) * distance
        local fragSize = 0.02 + (i % 3) * 0.015
        table.insert(list, {
            fragX - fragSize,       fragY - fragSize * 0.7,
            fragX + fragSize * 0.8, fragY - fragSize * 0.4,
            fragX + fragSize * 0.6, fragY + fragSize * 0.9,
            fragX - fragSize * 0.9, fragY + fragSize * 0.5
        })
    end
    debrisPolygonsCache12[s] = list
    return list
end

-- Función para obtener efectos de daño según el estado (con cache de coordenadas y factores)
function AncientRuinsRenderer.getDamageEffects(damageState, seed)
    local cacheKey = tostring(damageState) .. "_" .. tostring(seed or 0)
    if damageEffectsCache[cacheKey] then
        return damageEffectsCache[cacheKey]
    end

    local effects = {
        alphaMultiplier = 1.0,
        sizeMultiplier = 1.0,
        fragmentCount = 0,
        glowReduction = 1.0,
        structuralIntegrity = 1.0,
        fragments = {}
    }
    
    if damageState == "operational" then
        effects.alphaMultiplier = 1.0
        effects.sizeMultiplier = 1.0
        effects.glowReduction = 1.0
        effects.structuralIntegrity = 1.0
    elseif damageState == "damaged" then
        effects.alphaMultiplier = 0.8
        effects.sizeMultiplier = 0.9
        effects.fragmentCount = 3 + ((seed or 0) % 3)
        effects.glowReduction = 0.6
        effects.structuralIntegrity = 0.7
    elseif damageState == "ruins" then
        effects.alphaMultiplier = 0.5
        effects.sizeMultiplier = 0.7
        effects.fragmentCount = 8 + ((seed or 0) % 5)
        effects.glowReduction = 0.3
        effects.structuralIntegrity = 0.3
    end
    
    -- Pre-calcular offsets trigonométricos para evitar trigonometría por cuadro
    for i = 1, effects.fragmentCount do
        local angle = (i / effects.fragmentCount) * 2 * math.pi + (seed or 0) * 0.3
        local distRatio = 0.6 + (i % 4) * 0.2
        local sizeRatio = 0.02 + (i % 3) * 0.015
        local alphaRatio = (0.7 + (i % 3) * 0.1)
        table.insert(effects.fragments, {
            cosOffset = math.cos(angle) * distRatio,
            sinOffset = math.sin(angle) * distRatio,
            sizeRatio = sizeRatio,
            alphaRatio = alphaRatio
        })
    end

    damageEffectsCache[cacheKey] = effects
    return effects
end

-- Función para renderizar fragmentos de daño (optimizada: sin cálculos trigonométricos repetidos)
function AncientRuinsRenderer.renderDamageFragments(screenX, screenY, size, damageEffects, alpha, seed)
    if not damageEffects or not damageEffects.fragments or #damageEffects.fragments == 0 then
        return
    end
    
    love.graphics.push()
    love.graphics.translate(screenX, screenY)
    
    local baseR, baseG, baseB, baseA = love.graphics.getColor()
    local colorR = baseR * 0.8
    local colorG = baseG * 0.8
    local colorB = baseB * 0.8
    local baseAlpha = alpha * damageEffects.alphaMultiplier
    
    for _, frag in ipairs(damageEffects.fragments) do
        local fragX = frag.cosOffset * size
        local fragY = frag.sinOffset * size
        local fragSize = frag.sizeRatio * size
        local fragAlpha = baseAlpha * frag.alphaRatio
        
        love.graphics.setColor(colorR, colorG, colorB, fragAlpha)
        love.graphics.circle("fill", fragX, fragY, fragSize, math.max(4, math.floor(fragSize * 2)))
    end
    
    love.graphics.setColor(baseR, baseG, baseB, baseA)
    love.graphics.pop()
end

-- Función para renderizar placeholders de ancient ruins con culling extendido
function AncientRuinsRenderer.renderPlaceholders(chunkInfo, camera, getChunkFunc)
    local rendered = 0
    local config = AncientRuinsRenderer.config
    
    -- Margen ampliado de chunks: las megaestaciones y ruinas tienen radios de hasta 2000+ px,
    -- pudiendo abarcar hasta 2 chunks fuera de su chunk de origen.
    local marginChunks = 2
    local startY = (chunkInfo.startY or 0) - marginChunks
    local endY = (chunkInfo.endY or 0) + marginChunks
    local startX = (chunkInfo.startX or 0) - marginChunks
    local endX = (chunkInfo.endX or 0) + marginChunks

    for chunkY = startY, endY do
        for chunkX = startX, endX do
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.ancientRuinsPlaceholders then
                for _, placeholder in ipairs(chunk.ancientRuinsPlaceholders) do
                    -- Verificar si el placeholder está visible (con margen holgado)
                    if AncientRuinsRenderer.isPlaceholderVisible(placeholder, camera) then
                        local lod = AncientRuinsRenderer.calculateLOD(placeholder, camera)
                        AncientRuinsRenderer.renderPlaceholder(placeholder, camera, lod)
                        rendered = rendered + 1
                    end
                end
            end
        end
    end
    
    return rendered
end

-- Verificar si un placeholder está visible en pantalla (margen ampliado para megaestructuras)
function AncientRuinsRenderer.isPlaceholderVisible(placeholder, camera)
    local screenX, screenY = camera:worldToScreen(placeholder.x, placeholder.y)
    local zoom = camera.zoom or 1
    local screenSize = placeholder.size * zoom
    
    -- Margen holgado para megaestructuras:
    -- Módulos, anillos, escombros y resplandores exteriores se extienden
    -- hasta 2.0x el tamaño nominal más un margen de pantalla.
    local margin = screenSize * 2.0 + 250
    
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    
    return screenX > -margin and screenX < screenW + margin and
           screenY > -margin and screenY < screenH + margin
end

-- Calcular nivel de LOD basado en distancia
function AncientRuinsRenderer.calculateLOD(placeholder, camera)
    local dx = placeholder.x - camera.x
    local dy = placeholder.y - camera.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    local thresholds = AncientRuinsRenderer.config.lod.lodThresholds
    
    if distance > thresholds[4] then
        return 4  -- LOD mínimo
    elseif distance > thresholds[3] then
        return 3  -- LOD bajo
    elseif distance > thresholds[2] then
        return 2  -- LOD medio
    elseif distance > thresholds[1] then
        return 1  -- LOD alto
    else
        return 0  -- LOD máximo
    end
end

-- Función para calcular variaciones de perspectiva 3D avanzadas
local function calculateAdvanced3DEffects(placeholder, camera, perspectiveData)
    local camX = (camera and camera.x) or 0
    local camY = (camera and camera.y) or 0
    local dx = placeholder.x - camX
    local dy = placeholder.y - camY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Simular orientación 3D basada en posición relativa
    local viewAngle = math.atan2(dy, dx)
    local distanceFactor = math.min(1.0, distance / 5000) -- Normalizar distancia
    
    -- Variaciones de escala para simular profundidad
    local depthScale = 1.0 + (math.sin(placeholder.seed * 0.1) * 0.15 * distanceFactor)
    local heightVariation = 1.0 + (math.cos(placeholder.seed * 0.07) * 0.2)
    
    -- Rotación aparente fija basada solo en la seed (sin depender del ángulo de vista)
    local apparentRotation = (placeholder.seed * 0.05)
    
    return {
        depthScale = depthScale,
        heightVariation = heightVariation,
        apparentRotation = apparentRotation,
        distanceFactor = distanceFactor,
        viewAngle = viewAngle
    }
end

-- Función para calcular efectos de volumen aparente con iluminación espacial realista
local function calculateVolumeEffects(placeholder, screenX, screenY, screenSize, perspectiveData)
    -- Calcular dirección de iluminación estelar basada en posición para consistencia
    -- En el espacio, la luz viene de estrellas lejanas, no hay sombras proyectadas
    local lightAngle = ((placeholder.x * 0.001 + placeholder.y * 0.001 + placeholder.seed * 0.1) % (math.pi * 2))
    local lightDirX, lightDirY = math.cos(lightAngle), math.sin(lightAngle)
    
    -- Intensidad de iluminación estelar variable
    local lightIntensity = 0.6 + 0.4 * math.sin(lightAngle * 1.5)
    
    local volumeEffects = {
        -- Sin sombras proyectadas - en el espacio no hay superficie para proyectar sombras
        shadow = {
            offsetX = 0,
            offsetY = 0,
            blur = 0,
            alpha = 0, -- Eliminamos completamente las sombras proyectadas
            direction = {lightDirX, lightDirY}
        },
        -- Iluminación direccional estelar realista
        lighting = {
            highlightColor = {1.0, 0.95 + 0.05 * lightIntensity, 0.9 + 0.1 * lightIntensity, 0.3 * perspectiveData.perspectiveFactor * lightIntensity},
            shadowColor = {0.05, 0.02, 0.08, 0.4 * perspectiveData.perspectiveFactor}, -- Lado no iluminado más oscuro
            gradientAngle = lightAngle,
            intensity = lightIntensity,
            contrastFactor = 2.0 + 0.8 * lightIntensity -- Mayor contraste en el espacio
        },
        -- Efectos de profundidad espacial mejorados
        depth = {
            layerOffset = screenSize * 0.08 * perspectiveData.perspectiveFactor, -- Reducido para mayor realismo
            layerAlpha = 0.9,
            edgeDarkening = 0.6 * perspectiveData.perspectiveFactor, -- Más pronunciado en el espacio
            depthContrast = 1.8 + 0.4 * lightIntensity -- Mayor contraste de profundidad
        }
    }
    return volumeEffects
end

-- Renderizar campo de escombros orbitales y placas de blindaje a la deriva
function AncientRuinsRenderer.renderOrbitalDebrisField(placeholder, screenX, screenY, finalSize, camera, alpha, time, lod)
    local debris = placeholder.orbitalDebris
    if not debris or #debris == 0 or (lod and lod > 3) then return end

    local baseColor = {0.28, 0.33, 0.40, alpha * 0.85}
    if placeholder.complexType and placeholder.complexType:find("ruins") then
        baseColor = {0.20, 0.22, 0.26, alpha * 0.75}
    end

    love.graphics.push("all")
    love.graphics.translate(screenX, screenY)

    local is25D = placeholder.complexType and (placeholder.complexType:find("ring") or placeholder.complexType:find("modular"))
    local yFlatten = is25D and 0.62 or 1.0

    for _, deb in ipairs(debris) do
        local curAngle = deb.baseAngle + time * (deb.rotSpeed or 0.02)
        local dist = finalSize * (deb.distRatio or 1.2)
        local dx = math.cos(curAngle) * dist
        local dy = math.sin(curAngle) * dist * yFlatten
        local rot = (deb.baseRot or 0) + time * (deb.rotSpeed or 0.02) * 1.5

        local dw = math.max(6, finalSize * 0.035 * (deb.width / (placeholder.size * 0.05 or 1)))
        local dh = math.max(3, finalSize * 0.018 * (deb.height / (placeholder.size * 0.025 or 1)))

        love.graphics.push()
        love.graphics.translate(dx, dy)
        love.graphics.rotate(rot)

        -- Placa de blindaje trapezoidal facetada (Fragmento de megaestructura)
        local dPts = {
            -dw * 0.50, -dh * 0.40,
             dw * 0.42, -dh * 0.50,
             dw * 0.50,  dh * 0.38,
            -dw * 0.36,  dh * 0.50
        }
        love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4])
        love.graphics.polygon("fill", dPts)

        -- Borde de aleación de titanio con brillo de bisel
        love.graphics.setColor(baseColor[1] * 1.5, baseColor[2] * 1.5, baseColor[3] * 1.5, baseColor[4] * 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", dPts)

        love.graphics.pop()
    end

    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

-- Renderizar bahía de atraque con balizas estroboscópicas secuenciales de aproximación
function AncientRuinsRenderer.renderDockingBay(placeholder, screenX, screenY, finalSize, camera, alpha, time, damageState, lod)
    local dock = placeholder.dockingBay
    if not dock then return end

    local is25D = placeholder.complexType and (placeholder.complexType:find("ring") or placeholder.complexType:find("modular"))
    local yFlatten = is25D and 0.62 or 1.0

    local dockAngle = dock.angle or 0
    local dockDist = finalSize * (dock.distRatio or 0.88)
    local dx = math.cos(dockAngle) * dockDist
    local dy = math.sin(dockAngle) * dockDist * yFlatten
    local bayScreenX = screenX + dx
    local bayScreenY = screenY + dy

    local bayW = math.max(32, finalSize * 0.12)
    local bayH = math.max(20, finalSize * 0.07)

    love.graphics.push("all")
    love.graphics.translate(bayScreenX, bayScreenY)
    love.graphics.rotate(dockAngle)

    -- Colores de la bahía según el estado
    local dockColor = {0.25, 0.35, 0.45, alpha}
    local beaconColor = {0.2, 0.85, 1.0, alpha}
    local airlockColor = {0.15, 0.22, 0.30, alpha}
    
    if damageState == "damaged" then
        dockColor = {0.35, 0.30, 0.22, alpha}
        beaconColor = {1.0, 0.70, 0.2, alpha}
        airlockColor = {0.25, 0.18, 0.12, alpha}
    elseif damageState == "ruins" then
        dockColor = {0.22, 0.15, 0.15, alpha}
        beaconColor = {1.0, 0.25, 0.2, alpha}
        airlockColor = {0.12, 0.08, 0.08, alpha}
    end

    -- 1. Base y estructura del hangar en U
    love.graphics.setColor(dockColor[1], dockColor[2], dockColor[3], dockColor[4])
    love.graphics.setLineWidth(math.max(2, finalSize * 0.008))
    -- Base de la esclusa
    love.graphics.rectangle("fill", -bayW * 0.4, -bayH * 0.5, bayW * 0.8, bayH, 3, 3)
    -- Brazos metálicos de atraque exterior que reciben a la nave
    love.graphics.line(-bayW * 0.45, -bayH * 0.7, bayW * 0.35, -bayH * 0.7)
    love.graphics.line(-bayW * 0.45, bayH * 0.7, bayW * 0.35, bayH * 0.7)

    -- 2. Compuerta presurizada (Airlock Gate)
    love.graphics.setColor(airlockColor[1], airlockColor[2], airlockColor[3], airlockColor[4])
    love.graphics.circle("fill", -bayW * 0.1, 0, bayH * 0.44, 8)
    -- Sello hermético octogonal
    love.graphics.setColor(dockColor[1] * 1.5, dockColor[2] * 1.5, dockColor[3] * 1.5, alpha * 0.9)
    love.graphics.circle("line", -bayW * 0.1, 0, bayH * 0.44, 8)

    -- 3. Balizas estroboscópicas direccionales secuenciales (Landing Strobe Lights)
    local beaconCount = 4
    for i = 1, beaconCount do
        local progress = (i - 1) / (beaconCount - 1)
        local bx = -bayW * 0.3 + progress * (bayW * 0.65)
        
        -- Secuencia estroboscópica: la luz viaja desde el exterior hacia la compuerta
        local phase = (time * 4.0 - (beaconCount - i) * 0.6) % 3.0
        local strobe = math.max(0.15, 1.0 - phase)
        if damageState == "ruins" then
            strobe = strobe * (math.sin(time * 25 + i * 7) > 0 and 1 or 0.25)
        end

        local curA = beaconColor[4] * strobe
        local bRadius = math.max(2, finalSize * 0.007)

        -- Resplandor difuso
        love.graphics.setColor(beaconColor[1], beaconColor[2], beaconColor[3], curA * 0.45)
        love.graphics.circle("fill", bx, -bayH * 0.7, bRadius * 2.2, 6)
        love.graphics.circle("fill", bx, bayH * 0.7, bRadius * 2.2, 6)

        -- Núcleo incandescente de la baliza
        love.graphics.setColor(1, 1, 1, curA * 0.95)
        love.graphics.circle("fill", bx, -bayH * 0.7, bRadius, 6)
        love.graphics.circle("fill", bx, bayH * 0.7, bRadius, 6)
    end

    -- 4. Indicador de compuerta central (sello magnético)
    local gatePulse = 0.5 + 0.5 * math.sin(time * 5.0)
    love.graphics.setColor(beaconColor[1], beaconColor[2], beaconColor[3], beaconColor[4] * (0.4 + 0.6 * gatePulse))
    love.graphics.circle("fill", -bayW * 0.1, 0, math.max(2, bayH * 0.18), 6)

    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

-- Renderizar un placeholder individual
function AncientRuinsRenderer.renderPlaceholder(placeholder, camera, lod)
    local numLod = type(lod) == "number" and lod or (lod == "high" and 1 or (lod == "medium" and 2 or (lod == "low" and 3 or 0)))
    local lod = numLod
    local screenX, screenY = camera:worldToScreen(placeholder.x, placeholder.y)
    local screenSize = placeholder.size * (camera.zoom or 1)
    
    -- Saltear si es muy pequeño en pantalla (umbral reducido para mejor detalle)
    if screenSize < 1 then
        return
    end
    
    -- Obtener configuración del tipo de complejo espacial
    local complexConfig = AncientRuinsRenderer.config.placeholders.stationConfigs[placeholder.complexType]
    if not complexConfig then
        complexConfig = AncientRuinsRenderer.config.placeholders.stationConfigs.ring_station_damaged -- fallback
    end
    
    -- Calcular perspectiva fija por tipo (siempre aplicada) basada en la estructura y la seed
    local function calculateFixedPerspectiveForType(shape, structureX, structureY, seed)
        local baseAngle = (structureX * 0.001 + structureY * 0.001 + seed * 0.1) % (math.pi * 2)
        -- Intensidad determinística por seed con mínimo visible
        local n = love.math.noise(seed * 0.13, seed * 0.27)
        local minEffect = 0.5 -- aumentar mínimo para asegurar visibilidad
        local effectStrength = minEffect + (1.0 - minEffect) * n
        -- Multiplicador por tipo de estación (coinciden con shapes definidos y alias comunes)
        local typeIntensity = {
            -- shapes usados en el renderer
            ring = 0.75,
            modular = 0.7,
            elongated = 0.85,
            partial = 0.6,
            ruins = 1.0,
            damaged = 1.0,
            -- alias/variantes posibles
            ring_station = 0.75,
            modular_station = 0.7,
            elongated_ship = 0.85
        }
        local intensity = (typeIntensity[shape] or 0.7) * effectStrength
        -- Limitar intensidades para evitar extremos
        if intensity > 1.0 then intensity = 1.0 end
        if intensity < 0.3 then intensity = 0.3 end
        
        local angleJitter = (love.math.noise(seed * 0.31, seed * 0.47) - 0.5) * 0.4
        local finalAngle = baseAngle + angleJitter
        
        local scaleY = 1.0 - 0.25 * intensity -- más compresión vertical
        local skewX = math.sin(finalAngle) * 0.18 * intensity -- más inclinación visible
        local structureRotation = 0.0
        
        return {
            scaleY = scaleY,
            skewX = skewX,
            rotation = structureRotation,
            perspectiveFactor = intensity
        }
    end
    
    local perspectiveData = calculateFixedPerspectiveForType(complexConfig.shape, placeholder.x, placeholder.y, placeholder.seed)
    
    -- Calcular efectos 3D avanzados
    local advanced3D = calculateAdvanced3DEffects(placeholder, camera, perspectiveData)
    
    -- Aplicar variaciones de escala 3D al tamaño final
    local enhanced3DSize = screenSize * advanced3D.depthScale
    
    -- Calcular efectos de volumen aparente
    local volumeEffects = calculateVolumeEffects(placeholder, screenX, screenY, enhanced3DSize, perspectiveData)
    
    local time = love.timer.getTime()
    
    -- Tamaño final con efectos 3D aplicados
    local finalSize = enhanced3DSize
    
    -- Separar tipo base y estado de daño
    local baseType, damageState = complexConfig.shape:match("([^_]+)_(.+)")
    if not baseType then
        baseType = complexConfig.shape
        damageState = "operational"
    end
    
    -- Rotación con perspectiva dinámica mejorada y efectos 3D
    local rotation = 0
    if baseType == "ring" then
        rotation = (placeholder.seed * 0.1) % (math.pi * 2) + advanced3D.apparentRotation * 0.3
    elseif baseType == "modular" then
        rotation = advanced3D.apparentRotation * 0.2  -- Rotación sutil para estructuras modulares
    elseif baseType == "elongated" then
        rotation = (placeholder.seed * 0.05) % (math.pi * 2) + advanced3D.apparentRotation * 0.5
    else
        rotation = advanced3D.apparentRotation * 0.1
    end
    
    -- Calcular alpha basado en distancia para fade suave y tipo de complejo
    local alpha = AncientRuinsRenderer.calculateEdgeFade(screenX, screenY, finalSize, camera)
    alpha = alpha * complexConfig.alpha  -- Aplicar alpha del tipo de complejo
    
    love.graphics.push("all")
    love.graphics.origin()
    
    -- En el espacio no hay sombras proyectadas - solo iluminación direccional de estrellas
    -- Las estaciones espaciales no proyectan sombras porque no hay superficie ni atmósfera
    -- que permita la proyección de sombras como en un planeta
    if lod <= 2 and volumeEffects.shadow.alpha > 0.05 then
        -- Esta sección ahora está deshabilitada para mayor realismo espacial
        -- En su lugar, los efectos de iluminación direccional se manejan en applyVolumeEffects
    end
    
    -- Transformaciones de perspectiva ahora se aplican dentro de cada forma y en la ruta con shader
    
    -- Renderizadores especializados 2.5D con parallax de subniveles (Megaestructuras Brutalistas Sci-Fi)
    if baseType == "ring" then
        local StationRingRenderer = require 'src.maps.systems.renderers.station_ring_renderer'
        StationRingRenderer.render(placeholder, camera, screenX, screenY, finalSize, alpha, rotation, damageState, lod)
    elseif baseType == "modular" then
        local StationModularRenderer = require 'src.maps.systems.renderers.station_modular_renderer'
        StationModularRenderer.render(placeholder, camera, screenX, screenY, finalSize, alpha, rotation, damageState, lod)
    else
        -- Usar shader si está disponible (solo para estaciones funcionales modulares/alargadas)
        local shader = ShaderManager and ShaderManager.getShader and ShaderManager.getShader("station") or nil
        local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle") or nil
        
        if shader and img and lod <= 3 and complexConfig.shape ~= "damaged" and complexConfig.shape ~= "ruins" then
            -- Renderizado con shader para mejor calidad
            ShaderManager.setShader(shader)
            local iw, ih = img:getWidth(), img:getHeight()
            local scale = (finalSize * 2) / math.max(1, iw)

            -- Usar StationShaders module para envío de uniforms optimizado por LOD
            local StationShaders = require 'src.shaders.station_shaders'
            local lightAngle = (volumeEffects and volumeEffects.lighting and volumeEffects.lighting.gradientAngle) or 0
            local lightDir = {math.cos(lightAngle), math.sin(lightAngle)}
            local shapeType = (baseType == "modular") and 1 or 2
            local damageFactor = 1.0 - (complexConfig.structuralIntegrity or 1.0)
            
            -- Enviar uniforms usando el módulo especializado
            StationShaders.sendUniforms({
                time = time,
                lod = lod,
                rotation = rotation,
                damage = damageFactor,
                lightDir = lightDir,
                shapeType = shapeType,
                seed = placeholder.seed or 0,
                size = finalSize
            })
            
            -- Resplandor exterior (LOD 0-2 y LOD 4 para mantener visibilidad a distancia)
            if lod <= 2 or lod == 4 then
                local glowIntensity = (lod == 4) and 0.7 or 1.0  -- Reducir intensidad en LOD 4
                love.graphics.setColor(complexConfig.glowColor[1], complexConfig.glowColor[2], complexConfig.glowColor[3], complexConfig.glowColor[4] * alpha * glowIntensity)
                local glowScale = scale * 1.5
                love.graphics.draw(img, screenX, screenY, placeholder.rotation, glowScale, glowScale, iw * 0.5, ih * 0.5)
            end
            
            -- Cuerpo principal
             love.graphics.setColor(complexConfig.color[1], complexConfig.color[2], complexConfig.color[3], complexConfig.color[4] * alpha)
             love.graphics.draw(img, screenX, screenY, rotation, scale, scale, iw * 0.5, ih * 0.5)
            
            ShaderManager.unsetShader()
        else
            -- Fallback sin shader con segmentos basados en LOD mejorado
            local lodConfig = AncientRuinsRenderer.config.lod.details[lod] or AncientRuinsRenderer.config.lod.details[4]
            local baseSegments = lod >= 4 and 8 or (lod >= 3 and 12 or (lod >= 2 and 16 or (lod >= 1 and 20 or 24)))
            local segments = math.floor(baseSegments * lodConfig.segmentMultiplier)
            
            -- Renderizar según el tipo de complejo espacial
            love.graphics.setColor(complexConfig.color[1], complexConfig.color[2], complexConfig.color[3], complexConfig.color[4] * alpha)
            
            AncientRuinsRenderer.renderComplexShape(complexConfig.shape, screenX, screenY, finalSize, segments, alpha, rotation, placeholder.seed, complexConfig.glowColor, lod, perspectiveData, volumeEffects, lodConfig)
        end
    end
    
    -- Renderizar campo de escombros orbitales alrededor del casco
    AncientRuinsRenderer.renderOrbitalDebrisField(placeholder, screenX, screenY, finalSize, camera, alpha, time, lod)

    -- Renderizar bahía de atraque con balizas estroboscópicas secuenciales
    AncientRuinsRenderer.renderDockingBay(placeholder, screenX, screenY, finalSize, camera, alpha, time, damageState, lod)
    
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

-- Función auxiliar para aplicar efectos de volumen a una forma con iluminación direccional
local function applyVolumeEffects(volumeEffects, finalSize, lod, lodConfig)
    if not volumeEffects or lod > 2 then return end
    
    local lighting = volumeEffects.lighting
    local depth = volumeEffects.depth
    
    -- Aplicar gradiente de iluminación direccional
    if lighting.highlightColor[4] > 0.05 then
        local lightAngle = lighting.gradientAngle
        local lightDirX, lightDirY = math.cos(lightAngle), math.sin(lightAngle)
        local intensity = lighting.intensity or 1.0
        local contrast = lighting.contrastFactor or 1.0
        
        -- Highlight direccional con múltiples capas
        for i = 1, 4 do
            local factor = 1.0 - (i * 0.2)
            local highlightAlpha = lighting.highlightColor[4] * factor * intensity
            local offsetX = -lightDirX * finalSize * 0.3 * factor
            local offsetY = -lightDirY * finalSize * 0.3 * factor
            
            love.graphics.setColor(
                lighting.highlightColor[1] * contrast,
                lighting.highlightColor[2] * contrast,
                lighting.highlightColor[3] * contrast,
                highlightAlpha
            )
            love.graphics.circle("fill", offsetX, offsetY, finalSize * 0.15 * factor, 8)
        end
        
        -- Sombras direccionales en el lado opuesto
        for i = 1, 3 do
            local factor = 1.0 - (i * 0.25)
            local shadowAlpha = lighting.shadowColor[4] * factor
            local offsetX = lightDirX * finalSize * 0.4 * factor
            local offsetY = lightDirY * finalSize * 0.4 * factor
            
            love.graphics.setColor(
                lighting.shadowColor[1],
                lighting.shadowColor[2],
                lighting.shadowColor[3],
                shadowAlpha
            )
            love.graphics.ellipse("fill", offsetX, offsetY, finalSize * 0.8 * factor, finalSize * 0.4 * factor)
        end
    end
    
    -- Efectos de iluminación avanzados solo en LOD alto
    if lodConfig and lodConfig.showLightingDetails and lod <= 1 then
        local lightAngle = lighting.gradientAngle
        local lightDirX, lightDirY = math.cos(lightAngle), math.sin(lightAngle)
        local intensity = lighting.intensity or 1.0
        
        -- Reflejo especular direccional
        local specularX = -lightDirX * finalSize * 0.2
        local specularY = -lightDirY * finalSize * 0.2
        love.graphics.setColor(1.0, 0.95 + 0.05 * intensity, 0.9 + 0.1 * intensity, 0.9 * intensity)
        love.graphics.circle("fill", specularX, specularY, finalSize * 0.1, 8)
        
        -- Oscurecimiento direccional del lado no iluminado (sin sombra proyectada)
        local darkSideX = lightDirX * finalSize * 0.1
        local darkSideY = lightDirY * finalSize * 0.1
        love.graphics.setColor(0.02, 0.01, 0.05, 0.4)
        love.graphics.circle("fill", darkSideX, darkSideY, finalSize * 0.3, 12)
        
        -- Resplandor ambiental con variación de color
        love.graphics.setColor(
            0.7 + 0.1 * intensity,
            0.8 + 0.1 * intensity,
            0.9 + 0.1 * intensity,
            0.3 * intensity
        )
        love.graphics.circle("fill", 0, 0, finalSize * 1.3, 20)
        
        love.graphics.setColor(love.graphics.getColor())
    end
end

-- Función para renderizar diferentes formas de complejos espaciales
function AncientRuinsRenderer.renderComplexShape(shape, screenX, screenY, finalSize, segments, alpha, rotation, seed, glowColor, lod, perspectiveData, volumeEffects, lodConfig)
    perspectiveData = perspectiveData or {scaleY = 1.0, skewX = 0.0, rotation = 0.0, perspectiveFactor = 1.0}
    volumeEffects = volumeEffects or {}
    lodConfig = lodConfig or AncientRuinsRenderer.config.lod.details[4] -- fallback a LOD mínimo
    
    -- Separar tipo base y estado de daño
    local baseType, damageState = shape:match("([^_]+)_(.+)")
    if not baseType then
        baseType = shape
        damageState = "operational"
    end
    
    if baseType == "ring" then
        local StationRingRenderer = require 'src.maps.systems.renderers.station_ring_renderer'
        local dummyPlaceholder = { seed = seed, x = screenX, y = screenY }
        StationRingRenderer.render(dummyPlaceholder, nil, screenX, screenY, finalSize, alpha, rotation, damageState, lod)
    elseif baseType == "modular" then
        local StationModularRenderer = require 'src.maps.systems.renderers.station_modular_renderer'
        local dummyPlaceholder = { seed = seed, x = screenX, y = screenY, rotation = rotation }
        StationModularRenderer.render(dummyPlaceholder, nil, screenX, screenY, finalSize, alpha, rotation, damageState, lod)
    elseif baseType == "elongated" then
        -- Nave alargada (como las naves espaciales de las imágenes)
        love.graphics.push()
        love.graphics.translate(screenX, screenY)
        love.graphics.rotate(rotation)
        love.graphics.scale(1.0, perspectiveData.scaleY)
        love.graphics.shear(perspectiveData.skewX, 0)
        
        -- Resplandor específico para nave alargada (LOD 0-2 y LOD 4)
        if glowColor and (lod <= 2 or lod == 4) then
            local baseIntensity = (lod == 4) and 0.35 or 0.5
            love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] * alpha * baseIntensity)
            love.graphics.ellipse("fill", 0, 0, finalSize * 1.8, finalSize * 0.6)
            love.graphics.setColor(love.graphics.getColor())
        end
        
        -- Casco principal alargado (más detallado)
        love.graphics.ellipse("fill", 0, 0, finalSize * 1.4, finalSize * 0.35)
        
        -- Sección de comando frontal (más compleja)
        love.graphics.ellipse("fill", finalSize * 0.9, 0, finalSize * 0.3, finalSize * 0.25)
        love.graphics.circle("fill", finalSize * 1.05, 0, finalSize * 0.12, segments)
        
        -- Torre de comando
        love.graphics.rectangle("fill", finalSize * 0.7, -finalSize * 0.08, finalSize * 0.2, finalSize * 0.16)
        love.graphics.circle("fill", finalSize * 0.8, 0, finalSize * 0.06, 8)
        
        -- Motores principales (más grandes y detallados)
        love.graphics.circle("fill", -finalSize * 1.1, -finalSize * 0.18, finalSize * 0.15, segments)
        love.graphics.circle("fill", -finalSize * 1.1, finalSize * 0.18, finalSize * 0.15, segments)
        love.graphics.circle("fill", -finalSize * 1.2, 0, finalSize * 0.12, segments)
        
        -- Toberas de los motores
        love.graphics.setColor(0.3, 0.3, 0.3, alpha)
        love.graphics.circle("fill", -finalSize * 1.1, -finalSize * 0.18, finalSize * 0.08, segments)
        love.graphics.circle("fill", -finalSize * 1.1, finalSize * 0.18, finalSize * 0.08, segments)
        love.graphics.circle("fill", -finalSize * 1.2, 0, finalSize * 0.06, segments)
        love.graphics.setColor(love.graphics.getColor())
        
        -- Estructuras laterales (alas/estabilizadores)
        love.graphics.polygon("fill", 
            -finalSize * 0.3, -finalSize * 0.7,
            finalSize * 0.2, -finalSize * 0.45,
            finalSize * 0.4, -finalSize * 0.35,
            -finalSize * 0.1, -finalSize * 0.55
        )
        love.graphics.polygon("fill", 
            -finalSize * 0.3, finalSize * 0.7,
            finalSize * 0.2, finalSize * 0.45,
            finalSize * 0.4, finalSize * 0.35,
            -finalSize * 0.1, finalSize * 0.55
        )
        
        -- Detalles estructurales del casco
        love.graphics.setLineWidth(2)
        love.graphics.line(-finalSize * 0.6, -finalSize * 0.15, finalSize * 0.6, -finalSize * 0.15)
        love.graphics.line(-finalSize * 0.6, finalSize * 0.15, finalSize * 0.6, finalSize * 0.15)
        love.graphics.line(-finalSize * 0.3, -finalSize * 0.25, -finalSize * 0.3, finalSize * 0.25)
        love.graphics.line(finalSize * 0.3, -finalSize * 0.25, finalSize * 0.3, finalSize * 0.25)
        
        -- Antenas y sensores
        love.graphics.setLineWidth(1)
        for i = 1, 4 do
            local x = -finalSize * 0.4 + (i-1) * finalSize * 0.3
            love.graphics.line(x, -finalSize * 0.35, x, -finalSize * 0.45)
            love.graphics.circle("fill", x, -finalSize * 0.45, finalSize * 0.02, 6)
        end
        
        -- Luces de navegación
        love.graphics.setColor(0.8, 0.2, 0.2, alpha)
        love.graphics.circle("fill", -finalSize * 0.6, -finalSize * 0.7, finalSize * 0.03, 6)
        love.graphics.setColor(0.2, 0.8, 0.2, alpha)
        love.graphics.circle("fill", -finalSize * 0.6, finalSize * 0.7, finalSize * 0.03, 6)
        love.graphics.setColor(love.graphics.getColor())
        
        love.graphics.pop()
        
    elseif baseType == "modular_station" then
        -- Alias para compatibilidad
        baseType = "modular"
    elseif baseType == "elongated_ship" then
        -- Alias para compatibilidad
        baseType = "elongated"
    elseif baseType == "ring_station" then
        -- Alias para compatibilidad
        baseType = "ring"
    end
    
    -- Aplicar efectos de daño según el estado
    local damageEffects = AncientRuinsRenderer.getDamageEffects(damageState, seed)
    
    -- Modificar alpha y otros parámetros según el daño
    alpha = alpha * damageEffects.alphaMultiplier
    finalSize = finalSize * damageEffects.sizeMultiplier
    
    -- Renderizar diseños específicos para ruinas totales
    if damageState == "ruins" then
        -- Obtener configuración de color para ruinas
        local stationConfig = AncientRuinsRenderer.config.placeholders.stationConfigs[baseType .. "_ruins"]
        local color = stationConfig and stationConfig.color or {0.25, 0.3, 0.35, 1.0}
        
        love.graphics.push()
        love.graphics.translate(screenX, screenY)
        love.graphics.rotate(rotation)
        love.graphics.scale(1.0, perspectiveData.scaleY)
        love.graphics.shear(perspectiveData.skewX, 0)
        
        -- Establecer colores específicos para ruinas (grises fríos y azules apagados)
        love.graphics.setColor(color[1], color[2], color[3], color[4] * alpha)
        
        -- Resplandor muy tenue para ruinas (LOD 0-2 y LOD 4)
        if glowColor and (lod <= 2 or lod == 4) then
            local baseIntensity = (lod == 4) and 0.2 or 0.3
            love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] * alpha * baseIntensity)
            if baseType == "ring" then
                love.graphics.circle("fill", 0, 0, finalSize * 1.1, segments)
            elseif baseType == "modular" then
                love.graphics.rectangle("fill", -finalSize * 1.2, -finalSize * 0.25, finalSize * 2.4, finalSize * 0.5)
            elseif baseType == "elongated" then
                love.graphics.ellipse("fill", 0, 0, finalSize * 1.6, finalSize * 0.5)
            end
            love.graphics.setColor(love.graphics.getColor())
        end
        
        if baseType == "ring" then
            -- Anillo en ruinas: solo fragmentos del anillo original
            -- Fragmentos principales del anillo
            for i = 1, 8 do
                local startAngle = (i / 8) * 2 * math.pi + (seed * 0.1)
                local endAngle = startAngle + (math.pi / 6) + (seed % 3) * 0.2
                local innerRadius = finalSize * 0.6
                local outerRadius = finalSize * 0.9
                
                -- Crear arco fragmentado
                local points = {}
                local arcSegments = 8
                for j = 0, arcSegments do
                    local angle = startAngle + (endAngle - startAngle) * (j / arcSegments)
                    table.insert(points, math.cos(angle) * innerRadius)
                    table.insert(points, math.sin(angle) * innerRadius)
                end
                for j = arcSegments, 0, -1 do
                    local angle = startAngle + (endAngle - startAngle) * (j / arcSegments)
                    table.insert(points, math.cos(angle) * outerRadius)
                    table.insert(points, math.sin(angle) * outerRadius)
                end
                
                if #points >= 6 then
                    love.graphics.polygon("fill", points)
                end
            end
            
            -- Estructuras centrales colapsadas
            love.graphics.polygon("fill", 
                -finalSize * 0.3, -finalSize * 0.1,
                finalSize * 0.2, -finalSize * 0.15,
                finalSize * 0.1, finalSize * 0.1,
                -finalSize * 0.2, finalSize * 0.05
            )
            
        elseif baseType == "modular" then
            -- Estación modular en ruinas: módulos dispersos y estructura central dañada
            -- Estructura central parcialmente destruida
            love.graphics.polygon("fill", 
                -finalSize * 0.3, -finalSize * 0.08,
                finalSize * 0.1, -finalSize * 0.12,
                finalSize * 0.2, finalSize * 0.06,
                -finalSize * 0.4, finalSize * 0.1
            )
            
            -- Módulos flotantes dispersos
            love.graphics.rectangle("fill", -finalSize * 0.8, -finalSize * 0.2, finalSize * 0.15, finalSize * 0.1)
            love.graphics.rectangle("fill", finalSize * 0.5, finalSize * 0.15, finalSize * 0.12, finalSize * 0.08)
            love.graphics.circle("fill", -finalSize * 0.2, finalSize * 0.3, finalSize * 0.08, 6)
            
            -- Paneles solares destruidos (solo fragmentos)
            love.graphics.polygon("fill", 
                -finalSize * 1.0, -finalSize * 0.05,
                -finalSize * 0.7, -finalSize * 0.02,
                -finalSize * 0.8, finalSize * 0.03,
                -finalSize * 0.9, finalSize * 0.01
            )
            love.graphics.polygon("fill", 
                finalSize * 0.6, -finalSize * 0.04,
                finalSize * 0.9, -finalSize * 0.06,
                finalSize * 0.8, finalSize * 0.02
            )
            
        elseif baseType == "elongated" then
            -- Nave alargada en ruinas: casco partido y secciones dispersas
            -- Sección frontal separada
            love.graphics.ellipse("fill", finalSize * 0.7, -finalSize * 0.1, finalSize * 0.25, finalSize * 0.15)
            
            -- Casco principal partido
            love.graphics.polygon("fill", 
                -finalSize * 0.5, -finalSize * 0.15,
                finalSize * 0.3, -finalSize * 0.18,
                finalSize * 0.2, finalSize * 0.12,
                -finalSize * 0.6, finalSize * 0.1
            )
            
            -- Motores desprendidos
            love.graphics.circle("fill", -finalSize * 1.3, -finalSize * 0.3, finalSize * 0.1, segments)
            love.graphics.circle("fill", -finalSize * 1.1, finalSize * 0.4, finalSize * 0.08, segments)
            
            -- Alas/estabilizadores rotos
            love.graphics.polygon("fill", 
                -finalSize * 0.2, -finalSize * 0.5,
                finalSize * 0.1, -finalSize * 0.3,
                -finalSize * 0.1, -finalSize * 0.4
            )
            love.graphics.polygon("fill", 
                -finalSize * 0.1, finalSize * 0.6,
                finalSize * 0.2, finalSize * 0.3,
                finalSize * 0.0, finalSize * 0.4
            )
        end
        
        -- Cables y estructuras colgantes para todas las ruinas
        love.graphics.setLineWidth(math.max(1, finalSize * 0.003))
        for i = 1, 5 do
            local startAngle = (i / 5) * 2 * math.pi + seed * 0.2
            local startX = math.cos(startAngle) * finalSize * 0.4
            local startY = math.sin(startAngle) * finalSize * 0.4
            local endX = startX + (seed % 3 - 1) * finalSize * 0.3
            local endY = startY + (seed % 4 - 2) * finalSize * 0.2
            love.graphics.line(startX, startY, endX, endY)
        end
        
        -- Fragmentos de escombros adicionales (cacheados)
        local debris12 = getRuinsDebrisPolygons12(seed)
        for _, poly in ipairs(debris12) do
            love.graphics.polygon("fill",
                poly[1] * finalSize, poly[2] * finalSize,
                poly[3] * finalSize, poly[4] * finalSize,
                poly[5] * finalSize, poly[6] * finalSize,
                poly[7] * finalSize, poly[8] * finalSize
            )
        end
        
        love.graphics.pop()
        
    -- Renderizar según el tipo base (sin los tipos damaged/ruins separados)
    elseif false then
        -- Placeholder para mantener estructura
        love.graphics.push()
        love.graphics.translate(screenX, screenY)
        love.graphics.rotate(rotation)
        
        -- Aplicar transformaciones de perspectiva 2.5D
        love.graphics.scale(1.0, perspectiveData.scaleY)
        
        -- Aplicar inclinación (skew) para efecto 3D
        love.graphics.shear(perspectiveData.skewX, 0)
        
        -- Resplandor específico para estación dañada (más visible, LOD 0-2 y LOD 4)
        if glowColor and (lod <= 2 or lod == 4) then
            local baseIntensity = (lod == 4) and 0.55 or 0.8
            love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] * alpha * baseIntensity)
            love.graphics.circle("fill", 0, 0, finalSize * 1.1, segments)
            love.graphics.setColor(love.graphics.getColor())
        end
        
        -- Estructura principal dañada
        love.graphics.circle("fill", 0, 0, finalSize, segments)
        
        -- Daños estructurales (agujeros irregulares)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle("fill", finalSize * 0.3, -finalSize * 0.2, finalSize * 0.25, segments)
        love.graphics.circle("fill", -finalSize * 0.4, finalSize * 0.1, finalSize * 0.18, segments)
        love.graphics.circle("fill", finalSize * 0.1, finalSize * 0.4, finalSize * 0.15, segments)
        
        -- Restaurar color
        love.graphics.setColor(love.graphics.getColor())
        
        -- Fragmentos flotantes cerca (cacheados)
        local debris6 = getRuinsDebrisPolygons(seed)
        for _, poly in ipairs(debris6) do
            love.graphics.polygon("fill", 
                poly[1] * finalSize, poly[2] * finalSize,
                poly[3] * finalSize, poly[4] * finalSize,
                poly[5] * finalSize, poly[6] * finalSize,
                poly[7] * finalSize, poly[8] * finalSize
            )
        end
        
        -- Estructuras colgantes dañadas
        love.graphics.setLineWidth(2)
        love.graphics.line(finalSize * 0.6, -finalSize * 0.1, finalSize * 0.9, -finalSize * 0.3)
        love.graphics.line(-finalSize * 0.5, finalSize * 0.2, -finalSize * 0.8, finalSize * 0.5)
        
        love.graphics.pop()

    end
    
    -- Aplicar efectos de fragmentos para estados de daño
    if damageState == "damaged" or damageState == "ruins" then
        AncientRuinsRenderer.renderDamageFragments(screenX, screenY, finalSize, damageEffects, alpha, seed)
    end
end

-- Calcular fade en los bordes de la pantalla (optimizado para reducir translucidez)
function AncientRuinsRenderer.calculateEdgeFade(screenX, screenY, size, camera)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local fadeDistance = math.max(size * 0.5, 20)  -- Distancia de fade reducida significativamente
    
    local fadeX = 1.0
    local fadeY = 1.0
    
    -- Fade horizontal más suave y menos agresivo
    if screenX < fadeDistance then
        fadeX = math.max(0.7, screenX / fadeDistance)  -- Mínimo 70% de opacidad
    elseif screenX > screenWidth - fadeDistance then
        fadeX = math.max(0.7, (screenWidth - screenX) / fadeDistance)
    end
    
    -- Fade vertical más suave y menos agresivo
    if screenY < fadeDistance then
        fadeY = math.max(0.7, screenY / fadeDistance)  -- Mínimo 70% de opacidad
    elseif screenY > screenHeight - fadeDistance then
        fadeY = math.max(0.7, (screenHeight - screenY) / fadeDistance)
    end
    
    return math.max(0.7, math.min(1, fadeX * fadeY))  -- Garantizar mínimo 70% de opacidad
end

-- Configurar parámetros visuales por LOD en StationShaders
function AncientRuinsRenderer.configureShaderParameters()
    local StationShaders = require 'src.shaders.station_shaders'
    
    -- Sincronizar configuración LOD con StationShaders
    for lod = 0, 4 do
        local lodConfig = AncientRuinsRenderer.config.lod.details[lod]
        if lodConfig and lodConfig.specular and lodConfig.rimLight then
            StationShaders.setLODConfig(lod, lodConfig.specular, lodConfig.rimLight)
        end
    end
    
    print("✓ AncientRuinsRenderer: Parámetros visuales sincronizados con StationShaders")
end

-- Obtener configuración visual actual por LOD
function AncientRuinsRenderer.getVisualConfig(lod)
    local lodConfig = AncientRuinsRenderer.config.lod.details[lod] or AncientRuinsRenderer.config.lod.details[4]
    return {
        specular = lodConfig.specular or { intensity = 0.1, exponent = 8.0 },
        rimLight = lodConfig.rimLight or { intensity = 0.05, width = 3.5 }
    }
end

-- Actualizar parámetros visuales específicos por LOD
function AncientRuinsRenderer.setVisualConfig(lod, specular, rimLight)
    if lod >= 0 and lod <= 4 then
        local lodConfig = AncientRuinsRenderer.config.lod.details[lod]
        if lodConfig then
            if specular then lodConfig.specular = specular end
            if rimLight then lodConfig.rimLight = rimLight end
            
            -- Sincronizar con StationShaders
            local StationShaders = require 'src.shaders.station_shaders'
            StationShaders.setLODConfig(lod, lodConfig.specular, lodConfig.rimLight)
        end
    end
end

-- Inicializar configuración de shaders (llamar al inicio)
function AncientRuinsRenderer.initShaderConfig()
    AncientRuinsRenderer.configureShaderParameters()
end

return AncientRuinsRenderer