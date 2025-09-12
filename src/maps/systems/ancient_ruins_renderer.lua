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
        -- Tipos de complejos espaciales
        complexTypes = {
            ring_station = {
                name = "estacion_anillo",
                weight = 0.15,  -- 15% probabilidad
                shape = "ring",
                color = {0.4, 0.45, 0.5, 1.0},  -- Color sólido metálico
                glowColor = {0.6, 0.7, 0.8, 1.0},  -- Resplandor azul sólido
                alpha = 1.0
            },
            modular_station = {
                name = "estacion_modular",
                weight = 0.2,   -- 20% probabilidad
                shape = "modular",
                color = {0.35, 0.4, 0.45, 1.0},  -- Color sólido gris azulado
                glowColor = {0.5, 0.6, 0.7, 1.0},  -- Resplandor sólido
                alpha = 1.0
            },
            elongated_ship = {
                name = "nave_alargada",
                weight = 0.25,  -- 25% probabilidad
                shape = "elongated",
                color = {0.3, 0.35, 0.4, 1.0},  -- Color sólido oscuro
                glowColor = {0.4, 0.5, 0.6, 1.0},  -- Resplandor sólido
                alpha = 1.0
            },
            partial = {
                name = "parcialmente_destruida",
                weight = 0.25,  -- 25% probabilidad
                shape = "damaged",
                color = {0.25, 0.25, 0.30, 1.0},  -- Color más visible y sólido
                glowColor = {0.4, 0.4, 0.5, 1.0},  -- Resplandor más intenso para visibilidad
                alpha = 1.0  -- Completamente opaco
            },
            ruins = {
                name = "ruinas_totales",
                weight = 0.15,  -- 15% probabilidad
                shape = "ruins",
                color = {0.12, 0.08, 0.08, 1.0},  -- Color mucho más oscuro para profundidad
                glowColor = {0.2, 0.12, 0.12, 1.0},  -- Resplandor muy tenue
                alpha = 1.0
            }
        }
    },
    
    -- Configuración de LOD mejorada con más niveles de detalle
    lod = {
        maxDistance = 8000,  -- Distancia máxima de renderizado aumentada
        lodThresholds = {800, 2000, 4000, 6000},  -- Más niveles de LOD para transiciones suaves
        -- Configuración de detalles por LOD
        details = {
            [0] = { -- LOD máximo (muy cerca)
                showMicroStructures = true,
                showLightingDetails = true,
                showVolumeEffects = true,
                segmentMultiplier = 1.5,
                extraElements = true
            },
            [1] = { -- LOD alto (cerca)
                showMicroStructures = true,
                showLightingDetails = true,
                showVolumeEffects = true,
                segmentMultiplier = 1.2,
                extraElements = false
            },
            [2] = { -- LOD medio (distancia media)
                showMicroStructures = false,
                showLightingDetails = true,
                showVolumeEffects = true,
                segmentMultiplier = 1.0,
                extraElements = false
            },
            [3] = { -- LOD bajo (lejos)
                showMicroStructures = false,
                showLightingDetails = false,
                showVolumeEffects = false,
                segmentMultiplier = 0.8,
                extraElements = false
            },
            [4] = { -- LOD mínimo (muy lejos)
                showMicroStructures = false,
                showLightingDetails = false,
                showVolumeEffects = false,
                segmentMultiplier = 0.6,
                extraElements = false
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
    local worldScale = MapConfig.chunk.worldScale
    local config = AncientRuinsRenderer.config.placeholders
    
    -- Calcular coordenadas base del chunk en el mundo
    local chunkWorldX = chunkX * chunkSize * tileSize * worldScale
    local chunkWorldY = chunkY * chunkSize * tileSize * worldScale
    
    -- Calcular el tamaño del bioma (aproximadamente el tamaño del chunk)
    local biomeSize = chunkSize * tileSize * worldScale
    
    -- Determinar el tamaño de la estación basado en probabilidades
    local sizeType = AncientRuinsRenderer.selectStationSize(rng)
    local stationSize = biomeSize * config.sizes[sizeType]
    
    -- Seleccionar tipo de complejo espacial
    local complexType = AncientRuinsRenderer.selectComplexType(chunkX, chunkY)
    
    -- Posición central del chunk para la estación
    local localX = (chunkSize * tileSize) * 0.5
    local localY = (chunkSize * tileSize) * 0.5
    local worldX = chunkWorldX + localX
    local worldY = chunkWorldY + localY
    
    -- Crear el único placeholder para este bioma
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
        -- Semilla determinista para efectos consistentes
        seed = (chunkX * 1000 + chunkY)
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

-- Función auxiliar para seleccionar el tipo de complejo espacial
function AncientRuinsRenderer.selectComplexType(chunkX, chunkY)
    local config = AncientRuinsRenderer.config.placeholders.complexTypes
    
    -- Usar coordenadas del chunk para generar un valor determinístico
    local seed = math.abs(chunkX * 73 + chunkY * 41) % 1000
    local random = seed / 1000
    
    -- Orden determinístico de tipos para asegurar variedad
    local orderedTypes = {
        {"ring_station", config.ring_station},
        {"modular_station", config.modular_station},
        {"elongated_ship", config.elongated_ship},
        {"partial", config.partial},
        {"ruins", config.ruins}
    }
    
    local cumulative = 0
    for _, typeData in ipairs(orderedTypes) do
        local complexType, typeConfig = typeData[1], typeData[2]
        cumulative = cumulative + typeConfig.weight
        if random < cumulative then
            return complexType
        end
    end
    
    return "ruins"  -- fallback
end

-- Función para renderizar placeholders de ancient ruins
function AncientRuinsRenderer.renderPlaceholders(chunkInfo, camera, getChunkFunc)
    local rendered = 0
    local config = AncientRuinsRenderer.config
    
    for chunkY = chunkInfo.startY, chunkInfo.endY do
        for chunkX = chunkInfo.startX, chunkInfo.endX do
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.ancientRuinsPlaceholders then
                for _, placeholder in ipairs(chunk.ancientRuinsPlaceholders) do
                    -- Verificar si el placeholder está visible
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

-- Verificar si un placeholder está visible en pantalla
function AncientRuinsRenderer.isPlaceholderVisible(placeholder, camera)
    local screenX, screenY = camera:worldToScreen(placeholder.x, placeholder.y)
    local screenSize = placeholder.size * (camera.zoom or 1)
    
    -- Margen para objetos parcialmente visibles
    local margin = screenSize + 50
    
    return screenX > -margin and screenX < love.graphics.getWidth() + margin and
           screenY > -margin and screenY < love.graphics.getHeight() + margin
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
    local dx = placeholder.x - camera.x
    local dy = placeholder.y - camera.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Simular orientación 3D basada en posición relativa
    local viewAngle = math.atan2(dy, dx)
    local distanceFactor = math.min(1.0, distance / 5000) -- Normalizar distancia
    
    -- Variaciones de escala para simular profundidad
    local depthScale = 1.0 + (math.sin(placeholder.seed * 0.1) * 0.15 * distanceFactor)
    local heightVariation = 1.0 + (math.cos(placeholder.seed * 0.07) * 0.2)
    
    -- Orientación aparente basada en ángulo de vista
    local apparentRotation = viewAngle * 0.1 + (placeholder.seed * 0.05)
    
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

-- Renderizar un placeholder individual
function AncientRuinsRenderer.renderPlaceholder(placeholder, camera, lod)
    local screenX, screenY = camera:worldToScreen(placeholder.x, placeholder.y)
    local screenSize = placeholder.size * (camera.zoom or 1)
    
    -- Saltear si es muy pequeño en pantalla (umbral reducido para mejor detalle)
    if screenSize < 1 then
        return
    end
    
    -- Obtener configuración del tipo de complejo espacial
    local complexConfig = AncientRuinsRenderer.config.placeholders.complexTypes[placeholder.complexType]
    if not complexConfig then
        complexConfig = AncientRuinsRenderer.config.placeholders.complexTypes.ruins -- fallback
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
    
    -- Rotación con perspectiva dinámica mejorada y efectos 3D
    local rotation = 0
    if complexConfig.shape == "ring" then
        rotation = (placeholder.seed * 0.1) % (math.pi * 2) + advanced3D.apparentRotation * 0.3
    elseif complexConfig.shape == "modular" then
        rotation = advanced3D.apparentRotation * 0.2  -- Rotación sutil para estructuras modulares
    elseif complexConfig.shape == "elongated" then
        rotation = (placeholder.seed * 0.05) % (math.pi * 2) + advanced3D.apparentRotation * 0.5
    elseif complexConfig.shape == "damaged" then
        -- Combinar rotación de perspectiva con efectos 3D
        rotation = perspectiveData.rotation + advanced3D.apparentRotation * 0.4
    elseif complexConfig.shape == "ruins" then
        -- Combinar rotación de perspectiva con efectos 3D
        rotation = perspectiveData.rotation + advanced3D.apparentRotation * 0.3
    else
        rotation = advanced3D.apparentRotation * 0.1
    end
    
    -- Calcular alpha basado en distancia para fade suave y tipo de complejo
    local alpha = AncientRuinsRenderer.calculateEdgeFade(screenX, screenY, finalSize, camera)
    alpha = alpha * complexConfig.alpha  -- Aplicar alpha del tipo de complejo
    
    love.graphics.push()
    love.graphics.origin()
    
    -- En el espacio no hay sombras proyectadas - solo iluminación direccional de estrellas
    -- Las estaciones espaciales no proyectan sombras porque no hay superficie ni atmósfera
    -- que permita la proyección de sombras como en un planeta
    if lod <= 2 and volumeEffects.shadow.alpha > 0.05 then
        -- Esta sección ahora está deshabilitada para mayor realismo espacial
        -- En su lugar, los efectos de iluminación direccional se manejan en applyVolumeEffects
    end
    
    -- Transformaciones de perspectiva ahora se aplican dentro de cada forma y en la ruta con shader
    
    -- Usar shader si está disponible (solo para estaciones funcionales)
    local shader = ShaderManager and ShaderManager.getShader and ShaderManager.getShader("circle") or nil
    local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle") or nil
    
    if shader and img and lod <= 3 and complexConfig.shape ~= "damaged" and complexConfig.shape ~= "ruins" then
        -- Renderizado con shader para mejor calidad
        love.graphics.setShader(shader)
        local iw, ih = img:getWidth(), img:getHeight()
        local scale = (finalSize * 2) / math.max(1, iw)
        
        -- Resplandor exterior (solo en LOD alto)
        if lod == 0 then
            love.graphics.setColor(complexConfig.glowColor[1], complexConfig.glowColor[2], complexConfig.glowColor[3], complexConfig.glowColor[4] * alpha)
            local glowScale = scale * 1.5
            love.graphics.draw(img, screenX, screenY, placeholder.rotation, glowScale, glowScale, iw * 0.5, ih * 0.5)
        end
        
        -- Cuerpo principal
         love.graphics.setColor(complexConfig.color[1], complexConfig.color[2], complexConfig.color[3], complexConfig.color[4] * alpha)
         love.graphics.draw(img, screenX, screenY, rotation, scale, scale, iw * 0.5, ih * 0.5)
        
        love.graphics.setShader()
    else
        -- Fallback sin shader con segmentos basados en LOD mejorado
        local lodConfig = AncientRuinsRenderer.config.lod.details[lod] or AncientRuinsRenderer.config.lod.details[4]
        local baseSegments = lod >= 4 and 8 or (lod >= 3 and 12 or (lod >= 2 and 16 or (lod >= 1 and 20 or 24)))
        local segments = math.floor(baseSegments * lodConfig.segmentMultiplier)
        
        -- Renderizar según el tipo de complejo espacial
        love.graphics.setColor(complexConfig.color[1], complexConfig.color[2], complexConfig.color[3], complexConfig.color[4] * alpha)
        
        AncientRuinsRenderer.renderComplexShape(complexConfig.shape, screenX, screenY, finalSize, segments, alpha, rotation, placeholder.seed, complexConfig.glowColor, lod, perspectiveData, volumeEffects, lodConfig)
    end
    
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
    if shape == "ring" then
        -- Estación tipo anillo (como en las imágenes de referencia)
        love.graphics.push()
        love.graphics.translate(screenX, screenY)
        love.graphics.rotate(rotation)
        love.graphics.scale(1.0, perspectiveData.scaleY)
        love.graphics.shear(perspectiveData.skewX, 0)
        
        -- Resplandor específico para anillo
        if glowColor and lod <= 2 then
            love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] * alpha)
            love.graphics.circle("fill", 0, 0, finalSize * 1.2, segments)
            love.graphics.setColor(love.graphics.getColor())
        end
        
        -- Capa de profundidad (fondo más oscuro)
        if volumeEffects.depth and lod <= 2 then
            local currentColor = {love.graphics.getColor()}
            love.graphics.setColor(currentColor[1] * 0.7, currentColor[2] * 0.7, currentColor[3] * 0.7, currentColor[4])
            love.graphics.circle("fill", volumeEffects.depth.layerOffset * 0.5, volumeEffects.depth.layerOffset * 0.5, finalSize * 1.02, segments)
            love.graphics.setColor(currentColor)
        end
        
        -- Anillo exterior principal
        love.graphics.circle("fill", 0, 0, finalSize, segments)
        
        -- Aplicar efectos de volumen (highlights)
        applyVolumeEffects(volumeEffects, finalSize, lod, lodConfig)
        
        -- Hueco interior con efectos de profundidad direccional
        local lighting = volumeEffects.lighting or {gradientAngle = 0, intensity = 1.0, contrastFactor = 1.0}
        local lightAngle = lighting.gradientAngle
        local lightDirX, lightDirY = math.cos(lightAngle), math.sin(lightAngle)
        local depthIntensity = lighting.intensity * 0.8
        
        -- Múltiples capas para crear efecto de profundidad realista
        for i = 1, 6 do
            local depthFactor = 0.55 - (i * 0.02)
            local depthAlpha = 1.0 - (i * 0.12)
            local shadowOffset = i * 0.015
            
            -- Color base de profundidad con variación según dirección de luz
            local depthR = 0.02 + (lightDirX * 0.03 * depthIntensity)
            local depthG = 0.01 + (lightDirY * 0.015 * depthIntensity)
            local depthB = 0.05 + (depthIntensity * 0.04)
            
            love.graphics.setColor(depthR, depthG, depthB, depthAlpha)
            love.graphics.circle("fill", 
                lightDirX * finalSize * shadowOffset, 
                lightDirY * finalSize * shadowOffset, 
                finalSize * depthFactor, 
                segments
            )
        end
        
        -- Restaurar color
        love.graphics.setColor(love.graphics.getColor())
        
        -- Anillo interior estructural con contraste mejorado
        local structuralIntensity = 0.7 + (lighting.contrastFactor * 0.3)
        local currentColor = {love.graphics.getColor()}
        love.graphics.setColor(
            currentColor[1] * structuralIntensity,
            currentColor[2] * structuralIntensity,
            currentColor[3] * structuralIntensity,
            currentColor[4]
        )
        love.graphics.setLineWidth(math.max(2, finalSize * 0.008))
        love.graphics.circle("line", 0, 0, finalSize * 0.7, segments)
        love.graphics.circle("line", 0, 0, finalSize * 0.85, segments)
        
        -- Anillos adicionales para mayor detalle estructural
        love.graphics.setLineWidth(math.max(1, finalSize * 0.004))
        love.graphics.circle("line", 0, 0, finalSize * 0.77, segments)
        love.graphics.setColor(currentColor)
        
        -- Estructuras radiales principales (rayos) con efectos direccionales
        local lighting = volumeEffects.lighting or {gradientAngle = 0, intensity = 1.0, contrastFactor = 1.0}
        local lightAngle = lighting.gradientAngle
        local lightDirX, lightDirY = math.cos(lightAngle), math.sin(lightAngle)
        
        for i = 1, 12 do
            local angle = (i / 12) * 2 * math.pi
            local rayDirX, rayDirY = math.cos(angle), math.sin(angle)
            local x1 = rayDirX * finalSize * 0.55
            local y1 = rayDirY * finalSize * 0.55
            local x2 = rayDirX * finalSize
            local y2 = rayDirY * finalSize
            
            -- Calcular intensidad basada en ángulo con la luz
            local dotProduct = rayDirX * lightDirX + rayDirY * lightDirY
            local rayIntensity = 0.6 + (dotProduct * 0.4 * lighting.intensity)
            local rayAlpha = 0.8 + (dotProduct * 0.2)
            
            local currentColor = {love.graphics.getColor()}
            love.graphics.setColor(
                currentColor[1] * rayIntensity,
                currentColor[2] * rayIntensity,
                currentColor[3] * rayIntensity,
                currentColor[4] * rayAlpha
            )
            
            love.graphics.setLineWidth(math.max(2, finalSize * 0.012 * rayIntensity))
            love.graphics.line(x1, y1, x2, y2)
            
            -- Sombra sutil del rayo en el lado opuesto
            if dotProduct < 0 then
                love.graphics.setColor(
                    currentColor[1] * 0.3,
                    currentColor[2] * 0.3,
                    currentColor[3] * 0.3,
                    currentColor[4] * 0.4
                )
                love.graphics.setLineWidth(math.max(1, finalSize * 0.006))
                love.graphics.line(
                    x1 + lightDirX * finalSize * 0.02,
                    y1 + lightDirY * finalSize * 0.02,
                    x2 + lightDirX * finalSize * 0.02,
                    y2 + lightDirY * finalSize * 0.02
                )
            end
            
            love.graphics.setColor(currentColor)
        end
        
        -- Módulos de acoplamiento con efectos de profundidad
        for i = 1, 4 do
            local angle = (i / 4) * 2 * math.pi
            local moduleDirX, moduleDirY = math.cos(angle), math.sin(angle)
            local x = moduleDirX * finalSize * 0.9
            local y = moduleDirY * finalSize * 0.9
            
            -- Calcular intensidad del módulo basada en iluminación
            local dotProduct = moduleDirX * lightDirX + moduleDirY * lightDirY
            local moduleIntensity = 0.7 + (dotProduct * 0.3 * lighting.intensity)
            
            local currentColor = {love.graphics.getColor()}
            
            -- Sombra del módulo
            love.graphics.setColor(
                currentColor[1] * 0.2,
                currentColor[2] * 0.2,
                currentColor[3] * 0.2,
                currentColor[4] * 0.6
            )
            love.graphics.rectangle("fill", 
                x - finalSize * 0.05 + lightDirX * finalSize * 0.01,
                y - finalSize * 0.03 + lightDirY * finalSize * 0.01,
                finalSize * 0.1, finalSize * 0.06
            )
            
            -- Módulo principal con iluminación
            love.graphics.setColor(
                currentColor[1] * moduleIntensity,
                currentColor[2] * moduleIntensity,
                currentColor[3] * moduleIntensity,
                currentColor[4]
            )
            love.graphics.rectangle("fill", 
                x - finalSize * 0.05, y - finalSize * 0.03, 
                finalSize * 0.1, finalSize * 0.06
            )
            
            -- Highlight en el lado iluminado
            if dotProduct > 0 then
                love.graphics.setColor(
                    math.min(1.0, currentColor[1] * (1.2 + moduleIntensity * 0.3)),
                    math.min(1.0, currentColor[2] * (1.2 + moduleIntensity * 0.3)),
                    math.min(1.0, currentColor[3] * (1.2 + moduleIntensity * 0.3)),
                    currentColor[4] * 0.8
                )
                love.graphics.rectangle("fill", 
                    x - finalSize * 0.05 - lightDirX * finalSize * 0.005,
                    y - finalSize * 0.03 - lightDirY * finalSize * 0.005,
                    finalSize * 0.02, finalSize * 0.06
                )
            end
            
            love.graphics.setColor(currentColor)
        end
        
        -- Antenas y estructuras externas con efectos direccionales
        for i = 1, 8 do
            local angle = (i / 8) * 2 * math.pi + math.pi/16
            local antennaDirX, antennaDirY = math.cos(angle), math.sin(angle)
            local x1 = antennaDirX * finalSize * 1.0
            local y1 = antennaDirY * finalSize * 1.0
            local x2 = antennaDirX * finalSize * 1.15
            local y2 = antennaDirY * finalSize * 1.15
            
            -- Calcular intensidad de la antena basada en iluminación
            local dotProduct = antennaDirX * lightDirX + antennaDirY * lightDirY
            local antennaIntensity = 0.5 + (dotProduct * 0.5 * lighting.intensity)
            local antennaAlpha = 0.7 + (dotProduct * 0.3)
            
            local currentColor = {love.graphics.getColor()}
            
            -- Sombra de la antena
            if dotProduct < 0.2 then
                love.graphics.setColor(
                    currentColor[1] * 0.3,
                    currentColor[2] * 0.3,
                    currentColor[3] * 0.3,
                    currentColor[4] * 0.5
                )
                love.graphics.setLineWidth(math.max(1, finalSize * 0.004))
                love.graphics.line(
                    x1 + lightDirX * finalSize * 0.01,
                    y1 + lightDirY * finalSize * 0.01,
                    x2 + lightDirX * finalSize * 0.01,
                    y2 + lightDirY * finalSize * 0.01
                )
            end
            
            -- Antena principal
            love.graphics.setColor(
                currentColor[1] * antennaIntensity,
                currentColor[2] * antennaIntensity,
                currentColor[3] * antennaIntensity,
                currentColor[4] * antennaAlpha
            )
            love.graphics.setLineWidth(math.max(1, finalSize * 0.005 * antennaIntensity))
            love.graphics.line(x1, y1, x2, y2)
            
            -- Punta de la antena con efecto de brillo
            local tipIntensity = antennaIntensity * (1.0 + dotProduct * 0.3)
            love.graphics.setColor(
                math.min(1.0, currentColor[1] * tipIntensity),
                math.min(1.0, currentColor[2] * tipIntensity),
                math.min(1.0, currentColor[3] * tipIntensity),
                currentColor[4] * antennaAlpha
            )
            love.graphics.circle("fill", x2, y2, finalSize * 0.025 * antennaIntensity, 8)
            
            -- Highlight en la punta si está iluminada
            if dotProduct > 0.3 then
                love.graphics.setColor(1.0, 0.95, 0.8, antennaAlpha * 0.8)
                love.graphics.circle("fill", 
                    x2 - lightDirX * finalSize * 0.01,
                    y2 - lightDirY * finalSize * 0.01,
                    finalSize * 0.015, 6
                )
            end
            
            love.graphics.setColor(currentColor)
        end
        
        -- Microestructuras detalladas solo en LOD alto
        if lodConfig.showMicroStructures then
            -- Paneles solares detallados en el anillo
            for i = 1, 16 do
                local angle = (i / 16) * 2 * math.pi
                local x = math.cos(angle) * finalSize * 0.75
                local y = math.sin(angle) * finalSize * 0.75
                love.graphics.rectangle("fill", x - finalSize * 0.03, y - finalSize * 0.015, finalSize * 0.06, finalSize * 0.03)
            end
            
            -- Ventanas de observación
            for i = 1, 12 do
                local angle = (i / 12) * 2 * math.pi + math.pi/24
                local x = math.cos(angle) * finalSize * 0.85
                local y = math.sin(angle) * finalSize * 0.85
                love.graphics.setColor(0.8, 0.9, 1.0, alpha * 0.95)
                love.graphics.circle("fill", x, y, finalSize * 0.015, 6)
                love.graphics.setColor(love.graphics.getColor())
            end
            
            -- Estructuras de comunicación
            for i = 1, 4 do
                local angle = (i / 4) * 2 * math.pi + math.pi/8
                local x = math.cos(angle) * finalSize * 0.95
                local y = math.sin(angle) * finalSize * 0.95
                love.graphics.rectangle("fill", x - finalSize * 0.01, y - finalSize * 0.04, finalSize * 0.02, finalSize * 0.08)
            end
        end
        
        love.graphics.pop()
        
    elseif shape == "modular" then
        -- Estación modular (como ISS en las imágenes)
        love.graphics.push()
        love.graphics.translate(screenX, screenY)
        love.graphics.rotate(rotation)
        love.graphics.scale(1.0, perspectiveData.scaleY)
        love.graphics.shear(perspectiveData.skewX, 0)
        
        -- Resplandor específico para estación modular
        if glowColor and lod <= 2 then
            love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] * alpha * 0.6)
            love.graphics.rectangle("fill", -finalSize * 1.3, -finalSize * 0.3, finalSize * 2.6, finalSize * 0.6)
            love.graphics.setColor(love.graphics.getColor())
        end
        
        -- Capa de profundidad para estructura modular
        if volumeEffects.depth and lod <= 2 then
            local currentColor = {love.graphics.getColor()}
            love.graphics.setColor(currentColor[1] * 0.6, currentColor[2] * 0.6, currentColor[3] * 0.6, currentColor[4])
            love.graphics.rectangle("fill", -finalSize * 0.42 + volumeEffects.depth.layerOffset * 0.3, -finalSize * 0.14 + volumeEffects.depth.layerOffset * 0.3, finalSize * 0.84, finalSize * 0.28)
            love.graphics.setColor(currentColor)
        end
        
        -- Estructura central principal (cilindro)
        love.graphics.rectangle("fill", -finalSize * 0.4, -finalSize * 0.12, finalSize * 0.8, finalSize * 0.24)
        
        -- Aplicar efectos de volumen (highlights en estructura central)
        if volumeEffects.lighting and lod <= 2 then
            love.graphics.setColor(1.0, 1.0, 1.0, volumeEffects.lighting.highlightColor[4])
            love.graphics.rectangle("fill", -finalSize * 0.35, -finalSize * 0.10, finalSize * 0.1, finalSize * 0.05)
            love.graphics.setColor(love.graphics.getColor())
        end
        
        -- Módulos de conexión
        love.graphics.rectangle("fill", -finalSize * 0.1, -finalSize * 0.25, finalSize * 0.2, finalSize * 0.13)
        love.graphics.rectangle("fill", -finalSize * 0.1, finalSize * 0.12, finalSize * 0.2, finalSize * 0.13)
        
        -- Paneles solares principales (más detallados)
        love.graphics.setLineWidth(1)
        -- Panel solar izquierdo
        love.graphics.rectangle("fill", -finalSize * 1.1, -finalSize * 0.08, finalSize * 0.5, finalSize * 0.16)
        for i = 1, 6 do
            local x = -finalSize * 1.1 + (i-1) * finalSize * 0.08
            love.graphics.line(x, -finalSize * 0.08, x, finalSize * 0.08)
        end
        for i = 1, 3 do
            local y = -finalSize * 0.08 + (i-1) * finalSize * 0.08
            love.graphics.line(-finalSize * 1.1, y, -finalSize * 0.6, y)
        end
        
        -- Panel solar derecho
        love.graphics.rectangle("fill", finalSize * 0.6, -finalSize * 0.08, finalSize * 0.5, finalSize * 0.16)
        for i = 1, 6 do
            local x = finalSize * 0.6 + (i-1) * finalSize * 0.08
            love.graphics.line(x, -finalSize * 0.08, x, finalSize * 0.08)
        end
        for i = 1, 3 do
            local y = -finalSize * 0.08 + (i-1) * finalSize * 0.08
            love.graphics.line(finalSize * 0.6, y, finalSize * 1.1, y)
        end
        
        -- Módulos habitacionales laterales
        love.graphics.circle("fill", -finalSize * 0.05, -finalSize * 0.45, finalSize * 0.15, 8)
        love.graphics.circle("fill", finalSize * 0.05, finalSize * 0.45, finalSize * 0.15, 8)
        
        -- Antenas y comunicaciones
        love.graphics.setLineWidth(2)
        love.graphics.line(0, -finalSize * 0.12, 0, -finalSize * 0.35)
        love.graphics.line(-finalSize * 0.1, -finalSize * 0.35, finalSize * 0.1, -finalSize * 0.35)
        love.graphics.circle("fill", 0, -finalSize * 0.35, finalSize * 0.03, 6)
        
        -- Brazos robóticos
        love.graphics.setLineWidth(3)
        love.graphics.line(finalSize * 0.4, 0, finalSize * 0.55, -finalSize * 0.2)
        love.graphics.line(finalSize * 0.55, -finalSize * 0.2, finalSize * 0.65, -finalSize * 0.15)
        love.graphics.circle("fill", finalSize * 0.65, -finalSize * 0.15, finalSize * 0.04, 6)
        
        -- Puertos de acoplamiento
        love.graphics.circle("line", -finalSize * 0.4, 0, finalSize * 0.06, 8)
        love.graphics.circle("line", finalSize * 0.4, 0, finalSize * 0.06, 8)
        
        -- Microestructuras detalladas solo en LOD alto
        if lodConfig.showMicroStructures then
            -- Ventanas de observación en módulo central
            for i = 1, 8 do
                local x = -finalSize * 0.35 + (i-1) * finalSize * 0.08
                love.graphics.setColor(0.7, 0.8, 1.0, alpha * 0.9)
                love.graphics.rectangle("fill", x, -finalSize * 0.05, finalSize * 0.03, finalSize * 0.04)
                love.graphics.setColor(love.graphics.getColor())
            end
            
            -- Detalles en paneles solares (celdas individuales)
            for i = 1, 4 do
                for j = 1, 2 do
                    local x = -finalSize * 1.05 + (i-1) * finalSize * 0.1
                    local y = -finalSize * 0.06 + (j-1) * finalSize * 0.06
                    love.graphics.setColor(0.3, 0.4, 0.8, alpha * 0.8)
                    love.graphics.rectangle("fill", x, y, finalSize * 0.04, finalSize * 0.03)
                    love.graphics.setColor(love.graphics.getColor())
                end
            end
            
            -- Luces de navegación
            love.graphics.setColor(1.0, 0.2, 0.2, alpha * 0.8)
            love.graphics.circle("fill", -finalSize * 0.4, 0, finalSize * 0.015, 6)
            love.graphics.setColor(0.2, 1.0, 0.2, alpha * 0.8)
            love.graphics.circle("fill", finalSize * 0.4, 0, finalSize * 0.015, 6)
            love.graphics.setColor(love.graphics.getColor())
            
            -- Sistemas de acoplamiento detallados
            for i = 1, 3 do
                local angle = (i / 3) * 2 * math.pi
                local x = math.cos(angle) * finalSize * 0.08
                local y = math.sin(angle) * finalSize * 0.08
                love.graphics.rectangle("fill", x - finalSize * 0.02, y - finalSize * 0.02, finalSize * 0.04, finalSize * 0.04)
            end
        end
        
        love.graphics.pop()
        
    elseif shape == "elongated" then
        -- Nave alargada (como las naves espaciales de las imágenes)
        love.graphics.push()
        love.graphics.translate(screenX, screenY)
        love.graphics.rotate(rotation)
        love.graphics.scale(1.0, perspectiveData.scaleY)
        love.graphics.shear(perspectiveData.skewX, 0)
        
        -- Resplandor específico para nave alargada
        if glowColor and lod <= 2 then
            love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] * alpha * 0.5)
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
        
    elseif shape == "damaged" then
        -- Estación parcialmente dañada (más realista) con perspectiva 2.5D
        love.graphics.push()
        love.graphics.translate(screenX, screenY)
        love.graphics.rotate(rotation)
        
        -- Aplicar transformaciones de perspectiva 2.5D
        love.graphics.scale(1.0, perspectiveData.scaleY)
        
        -- Aplicar inclinación (skew) para efecto 3D
        love.graphics.shear(perspectiveData.skewX, 0)
        
        -- Resplandor específico para estación dañada (más visible)
        if glowColor and lod <= 2 then
            love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] * alpha * 0.8)
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
        
        -- Fragmentos flotantes cerca
        for i = 1, 6 do
            local angle = (i / 6) * 2 * math.pi + seed * 0.1
            local distance = finalSize * (1.2 + (i % 3) * 0.2)
            local fragX = math.cos(angle) * distance
            local fragY = math.sin(angle) * distance
            local fragSize = finalSize * (0.05 + (i % 2) * 0.03)
            love.graphics.polygon("fill", 
                fragX - fragSize, fragY - fragSize * 0.5,
                fragX + fragSize * 0.7, fragY - fragSize * 0.3,
                fragX + fragSize * 0.5, fragY + fragSize,
                fragX - fragSize * 0.8, fragY + fragSize * 0.4
            )
        end
        
        -- Estructuras colgantes dañadas
        love.graphics.setLineWidth(2)
        love.graphics.line(finalSize * 0.6, -finalSize * 0.1, finalSize * 0.9, -finalSize * 0.3)
        love.graphics.line(-finalSize * 0.5, finalSize * 0.2, -finalSize * 0.8, finalSize * 0.5)
        
        love.graphics.pop()

    elseif shape == "ruins" then
        -- Ruinas más detalladas y realistas con perspectiva 2.5D mejorada
        love.graphics.push()
        love.graphics.translate(screenX, screenY)
        love.graphics.rotate(rotation)
        
        -- Resplandor específico para ruinas (más visible y fragmentado)
        if glowColor and lod <= 1 then
            love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] * alpha * 0.8)
            -- Múltiples resplandores pequeños en lugar de uno grande
            for i = 1, 5 do
                local angle = (i / 5) * 2 * math.pi + (seed or 0) * 0.1
                local distance = finalSize * (0.3 + (i % 3) * 0.2)
                local glowX = math.cos(angle) * distance
                local glowY = math.sin(angle) * distance
                local glowSize = finalSize * (0.4 + (i % 2) * 0.2)
                love.graphics.circle("fill", glowX, glowY, glowSize, math.max(8, math.floor(segments / 2)))
            end
            love.graphics.setColor(love.graphics.getColor())
        end
        
        -- Aplicar transformaciones de perspectiva 2.5D mejoradas
        love.graphics.scale(1.0, perspectiveData.scaleY)
        
        -- Aplicar inclinación (skew) para efecto 3D
        love.graphics.shear(perspectiveData.skewX, 0)
        
        -- Dirección de luz determinista basada en la semilla y color base actual
        local baseR, baseG, baseB, baseA = love.graphics.getColor()
        local lightAngle = ((seed or 0) * 12.9898) % (math.pi * 2)
        local lightDirX, lightDirY = math.cos(lightAngle), math.sin(lightAngle)
        local shadowBase = math.max(4, finalSize * 0.04)
        local shadowPasses = (lod and lod <= 1) and 3 or 2
        
        -- Funciones de textura procedural
        local function getLayerTexture(layer, x, y, size, partSeed)
            local texSeed = (partSeed or 0) + layer * 1000
            local noise1 = math.sin(x * 0.1 + texSeed) * math.cos(y * 0.1 + texSeed * 0.7)
            local noise2 = math.sin(x * 0.05 + texSeed * 1.3) * math.cos(y * 0.05 + texSeed * 2.1)
            
            if layer == 0 then -- Capa base: metal oxidado
                local rust = math.abs(noise1 * noise2) * 0.3
                return {r = 0.8 - rust, g = 0.6 - rust * 0.5, b = 0.4 - rust * 0.3, roughness = 0.8 + rust}
            elseif layer == 1 then -- Capa media: metal pulido con daños
                local damage = math.max(0, noise1 * 0.4)
                return {r = 0.9 - damage, g = 0.9 - damage, b = 0.95 - damage * 0.5, roughness = 0.3 + damage}
            else -- Capa alta: cristal/cerámica
                local clarity = math.abs(noise2) * 0.2
                return {r = 0.95 - clarity, g = 0.98 - clarity, b = 1.0 - clarity * 0.5, roughness = 0.1 + clarity}
            end
        end
        
        local function getNormalOffset(x, y, size, partSeed, intensity)
            local ns = (partSeed or 0) * 0.1
            local nx = math.sin(x * 0.2 + ns) * math.cos(y * 0.15 + ns * 1.4) * intensity
            local ny = math.cos(x * 0.15 + ns * 0.8) * math.sin(y * 0.2 + ns * 2.1) * intensity
            return nx, ny
        end
        
        -- Funciones de perspectiva dinámica eliminadas - ahora se usa perspectiva fija
        
        -- Sistema de profundidad visual optimizado para vista cenital
        local function calculateVisualDepth(layer, height, perspectiveFactor, distance)
            -- Calcular offset de profundidad con mayor contraste
            local depthOffset = layer * 2.5 + height * 0.8
            
            -- Factor de escala con mayor diferencia entre capas
            local depthScale = math.max(0.6, 1.0 - (depthOffset * 0.025 * perspectiveFactor))
            
            -- Offset de posición más pronunciado para mejor efecto 3D
            local maxOffset = 0.4
            local depthX = math.max(-maxOffset, math.min(maxOffset, depthOffset * math.sin(perspectiveFactor * math.pi * 0.3) * 0.3))
            local depthY = math.max(-maxOffset, math.min(maxOffset, depthOffset * math.cos(perspectiveFactor * math.pi * 0.3) * 0.25))
            
            -- Alpha con mayor contraste para profundidad
            local depthAlpha = math.max(0.8, 1.0 - (depthOffset * 0.08 * perspectiveFactor))
            
            -- Factor de desenfoque más pronunciado
            local blurFactor = math.min(0.25, depthOffset * 0.12 * perspectiveFactor)
            
            return {
                scale = depthScale,
                offsetX = depthX,
                offsetY = depthY,
                alpha = depthAlpha,
                blur = blurFactor
            }
        end
        
        -- Fragmentos realistas de estación destruida (con mayor variación de capas y alturas)
        local stationParts = {
            {type = "command", x = 0.3,  y = -0.4, size = 0.25, intact = 0.7, layer = 3, height = 5},  -- Más profundo
            {type = "power",   x = -0.5, y = 0.2,  size = 0.3,  intact = 0.4, layer = 2, height = 3},  -- Profundidad media
            {type = "hull",    x = 0.1,  y = 0.3,  size = 0.35, intact = 0.6, layer = 0, height = 1},  -- Superficie
            {type = "antenna", x = -0.3, y = -0.5, size = 0.15, intact = 0.8, layer = 4, height = 6},  -- Muy profundo
            {type = "lifesupport", x = 0.6,  y = 0.1, size = 0.2, intact = 0.3, layer = 2, height = 4},  -- Profundidad media-alta
            {type = "engine",  x = -0.2, y = 0.6,  size = 0.28, intact = 0.5, layer = 1, height = 2},  -- Cerca de superficie
            {type = "solar",   x = 0.4,  y = -0.2, size = 0.18, intact = 0.2, layer = 0, height = 1},  -- Superficie
            {type = "dock",    x = -0.4, y = -0.1, size = 0.22, intact = 0.6, layer = 3, height = 4}   -- Profundo
        }
        
        -- En el espacio no hay sombras proyectadas - solo efectos de iluminación direccional
        -- Las estaciones espaciales no proyectan sombras porque no hay superficie para proyectarlas
        -- En su lugar, usamos variaciones de iluminación direccional para crear profundidad visual
        
        -- Paso 2: dibujo por capas con sombreado direccional y profundidad visual
        for layer = 0, 4 do
            for i, part in ipairs(stationParts) do
                if part.layer == layer then
                    local partX = part.x * finalSize
                    local partY = part.y * finalSize
                    local partSize = finalSize * part.size
                    local damage = 1.0 - part.intact
                    local partSeed = (seed or 0) + i * 100
                    
                    -- Calcular profundidad visual para esta parte
                    local depthData = calculateVisualDepth(part.layer, part.height, perspectiveData.perspectiveFactor, finalSize)
                    
                    -- Aplicar transformaciones de profundidad
                    partX = partX + depthData.offsetX
                    partY = partY + depthData.offsetY
                    partSize = partSize * depthData.scale
                    
                    -- Obtener textura procedural para esta capa
                    local texture = getLayerTexture(layer, partX, partY, partSize, partSeed)
                    
                    -- Normal mapping simulado
                    local normalIntensity = partSize * 0.02 * texture.roughness
                    local normalX, normalY = getNormalOffset(partX, partY, partSize, partSeed, normalIntensity)
                    
                    -- Sombreado direccional mejorado con normal mapping
                    local nx, ny = partX + normalX, partY + normalY
                    local len = math.sqrt(nx * nx + ny * ny)
                    if len > 0 then nx, ny = nx / len, ny / len end
                    local ndotl = -(nx * lightDirX + ny * lightDirY)
                    local brightness = math.max(0.7, math.min(1.2, 0.85 + 0.25 * ndotl))
                    
                    -- Aplicar textura procedural al color base con alpha de profundidad
                    -- Factor de oscurecimiento por profundidad mejorado para mayor contraste 3D
                    local depthDarkening = 1.0 - (part.layer * 0.35 + part.height * 0.20)
                    depthDarkening = math.max(0.15, depthDarkening) -- Oscurecimiento más agresivo para capas profundas
                    
                    local finalR = (baseR * texture.r) * brightness * depthDarkening
                    local finalG = (baseG * texture.g) * brightness * depthDarkening
                    local finalB = (baseB * texture.b) * brightness * depthDarkening
                    local finalAlpha = baseA * depthData.alpha * alpha
                    love.graphics.setColor(finalR, finalG, finalB, finalAlpha)
                    
                    -- Renderizar cada tipo de parte de estación con texturas específicas
                    if part.type == "command" then
                        -- Sección de comando (hexágono dañado) con paneles
                        local points = {}
                        for j = 1, 6 do
                            local angle = (j / 6) * 2 * math.pi
                            local radius = partSize * (0.8 + damage * 0.4)
                            table.insert(points, partX + math.cos(angle) * radius)
                            table.insert(points, partY + math.sin(angle) * radius)
                        end
                        love.graphics.polygon("fill", points)
                        
                        -- Paneles de comando con micro-detalles
                        love.graphics.setColor(finalR * 1.1, finalG * 1.1, finalB * 1.1, baseA * 0.8)
                        for j = 1, 6 do
                            local angle = (j / 6) * 2 * math.pi
                            local px = partX + math.cos(angle) * partSize * 0.6
                            local py = partY + math.sin(angle) * partSize * 0.6
                            love.graphics.rectangle("fill", px - partSize * 0.08, py - partSize * 0.05, partSize * 0.16, partSize * 0.1)
                        end
                        
                        -- Borde de profundidad
                        love.graphics.setColor(finalR * 0.6, finalG * 0.6, finalB * 0.6, baseA)
                        love.graphics.setLineWidth(2)
                        love.graphics.polygon("line", points)
                        
                        -- Daño interno
                        if damage > 0.3 then
                            love.graphics.setColor(0, 0, 0, alpha)
                            love.graphics.circle("fill", partX + partSize * 0.2, partY, partSize * damage * 0.4, 8)
                        end
                        love.graphics.setColor(finalR, finalG, finalB, baseA)
                        
                    elseif part.type == "power" then
                        -- Módulo de energía (cilindro con daños) con superficie metálica
                        love.graphics.ellipse("fill", partX, partY, partSize, partSize * 0.6)
                        
                        -- Superficie metálica con reflejos
                        love.graphics.setColor(finalR * 1.3, finalG * 1.3, finalB * 1.3, baseA * 0.9)
                        love.graphics.ellipse("fill", partX - partSize * 0.2, partY - partSize * 0.1, partSize * 0.4, partSize * 0.2)
                        
                        -- Borde de profundidad
                        love.graphics.setColor(finalR * 0.5, finalG * 0.5, finalB * 0.5, baseA)
                        love.graphics.setLineWidth(3)
                        love.graphics.ellipse("line", partX, partY, partSize, partSize * 0.6)
                        
                        -- Grietas de energía con resplandor
                        love.graphics.setColor(0.3, 0.8, 1.0, alpha * 0.95)
                        love.graphics.setLineWidth(2)
                        for j = 1, 3 do
                            local startX = partX + (j - 2) * partSize * 0.3
                            love.graphics.line(startX, partY - partSize * 0.3, startX, partY + partSize * 0.3)
                        end
                        love.graphics.setColor(finalR, finalG, finalB, baseA)
                        
                    elseif part.type == "hull" then
                        -- Fragmento del casco principal (irregular) con placas de blindaje
                        local hullPoints = {
                            partX - partSize, partY - partSize * 0.5,
                            partX + partSize * 0.8, partY - partSize * 0.3,
                            partX + partSize, partY + partSize * 0.4,
                            partX - partSize * 0.6, partY + partSize * 0.6
                        }
                        love.graphics.polygon("fill", hullPoints)
                        
                        -- Placas de blindaje superpuestas
                        love.graphics.setColor(finalR * 0.9, finalG * 0.9, finalB * 0.9, baseA * 0.9)
                        love.graphics.polygon("fill",
                            partX - partSize * 0.7, partY - partSize * 0.3,
                            partX + partSize * 0.5, partY - partSize * 0.1,
                            partX + partSize * 0.6, partY + partSize * 0.2,
                            partX - partSize * 0.4, partY + partSize * 0.3
                        )
                        
                        -- Bordes de profundidad
                        love.graphics.setColor(finalR * 0.4, finalG * 0.4, finalB * 0.4, baseA)
                        love.graphics.setLineWidth(2)
                        love.graphics.polygon("line", hullPoints)
                        
                        -- Agujeros de impacto con bordes quemados
                        love.graphics.setColor(0.2, 0.1, 0.1, alpha)
                        love.graphics.circle("fill", partX - partSize * 0.3, partY, partSize * 0.25, 8)
                        love.graphics.setColor(0, 0, 0, alpha)
                        love.graphics.circle("fill", partX - partSize * 0.3, partY, partSize * 0.2, 8)
                        love.graphics.circle("fill", partX + partSize * 0.2, partY + partSize * 0.2, partSize * 0.15, 6)
                        love.graphics.setColor(finalR, finalG, finalB, baseA)
                        
                    elseif part.type == "antenna" then
                        -- Antena rota con estructura metálica
                        -- Base de la antena con textura metálica
                        love.graphics.circle("fill", partX, partY, partSize * 0.3, 8)
                        
                        -- Reflejo metálico en la base
                        love.graphics.setColor(finalR * 1.4, finalG * 1.4, finalB * 1.4, baseA * 0.7)
                        love.graphics.circle("fill", partX - partSize * 0.1, partY - partSize * 0.1, partSize * 0.15, 6)
                        
                        -- Estructura de antena con profundidad
                        love.graphics.setColor(finalR * 0.8, finalG * 0.8, finalB * 0.8, baseA)
                        love.graphics.setLineWidth(4)
                        love.graphics.line(partX, partY, partX + partSize * 0.8, partY - partSize * 1.2)
                        love.graphics.line(partX, partY, partX - partSize * 0.6, partY - partSize * 0.8)
                        
                        -- Cables y detalles
                        love.graphics.setColor(finalR * 0.6, finalG * 0.6, finalB * 0.6, baseA)
                        love.graphics.setLineWidth(2)
                        love.graphics.line(partX, partY, partX + partSize * 0.4, partY - partSize * 0.6)
                        love.graphics.setColor(finalR, finalG, finalB, baseA)
                        
                    elseif part.type == "lifesupport" then
                        -- Módulo de soporte vital (cubo dañado) con paneles
                        love.graphics.rectangle("fill", partX - partSize, partY - partSize, partSize * 2, partSize * 2)
                        
                        -- Paneles laterales con textura
                        love.graphics.setColor(finalR * 1.1, finalG * 1.1, finalB * 1.1, baseA * 0.95)
                        love.graphics.rectangle("fill", partX - partSize * 0.9, partY - partSize * 0.9, partSize * 0.3, partSize * 1.8)
                        love.graphics.rectangle("fill", partX + partSize * 0.6, partY - partSize * 0.9, partSize * 0.3, partSize * 1.8)
                        
                        -- Bordes de profundidad
                        love.graphics.setColor(finalR * 0.5, finalG * 0.5, finalB * 0.5, baseA)
                        love.graphics.setLineWidth(2)
                        love.graphics.rectangle("line", partX - partSize, partY - partSize, partSize * 2, partSize * 2)
                        
                        -- Ventilación rota con resplandor interno
                        love.graphics.setColor(0.8, 0.4, 0.2, alpha * 0.9)
                        for j = 1, 4 do
                            local vX = partX - partSize * 0.6 + (j - 1) * partSize * 0.4
                            love.graphics.rectangle("fill", vX, partY - partSize * 0.8, partSize * 0.1, partSize * 0.3)
                        end
                        love.graphics.setColor(0, 0, 0, alpha)
                        for j = 1, 4 do
                            local vX = partX - partSize * 0.6 + (j - 1) * partSize * 0.4
                            love.graphics.rectangle("fill", vX + partSize * 0.02, partY - partSize * 0.75, partSize * 0.06, partSize * 0.2)
                        end
                        love.graphics.setColor(finalR, finalG, finalB, baseA)
                        
                    elseif part.type == "engine" then
                        -- Motor dañado con estructura compleja
                        love.graphics.polygon("fill",
                            partX - partSize * 0.8, partY - partSize * 0.4,
                            partX + partSize * 0.8, partY - partSize * 0.4,
                            partX + partSize * 0.5, partY + partSize * 0.6,
                            partX - partSize * 0.5, partY + partSize * 0.6
                        )
                        
                        -- Anillo metálico exterior
                        love.graphics.setColor(finalR * 1.3, finalG * 1.3, finalB * 1.3, baseA * 0.8)
                        love.graphics.setLineWidth(4)
                        love.graphics.polygon("line",
                            partX - partSize * 0.8, partY - partSize * 0.4,
                            partX + partSize * 0.8, partY - partSize * 0.4,
                            partX + partSize * 0.5, partY + partSize * 0.6,
                            partX - partSize * 0.5, partY + partSize * 0.6
                        )
                        
                        -- Núcleo central con resplandor
                        love.graphics.setColor(finalR * 0.7, finalG * 0.7, finalB * 0.7, baseA)
                        love.graphics.ellipse("fill", partX, partY, partSize * 0.6, partSize * 0.4)
                        
                        -- Toberas dañadas con efectos de quemado
                        love.graphics.setColor(0.4, 0.2, 0.1, alpha * 0.95)
                        love.graphics.circle("fill", partX - partSize * 0.3, partY + partSize * 0.3, partSize * 0.2, 8)
                        love.graphics.circle("fill", partX + partSize * 0.3, partY + partSize * 0.3, partSize * 0.2, 8)
                        
                        -- Agujeros internos quemados
                        love.graphics.setColor(0.1, 0.05, 0.05, alpha)
                        love.graphics.circle("fill", partX - partSize * 0.3, partY + partSize * 0.3, partSize * 0.1, 6)
                        love.graphics.circle("fill", partX + partSize * 0.3, partY + partSize * 0.3, partSize * 0.1, 6)
                        
                        -- Conductos de combustible dañados
                        love.graphics.setColor(finalR * 0.5, finalG * 0.5, finalB * 0.5, baseA)
                        love.graphics.setLineWidth(2)
                        love.graphics.line(partX, partY - partSize * 0.2, partX - partSize * 0.3, partY + partSize * 0.3)
                        love.graphics.line(partX, partY - partSize * 0.2, partX + partSize * 0.3, partY + partSize * 0.3)
                        love.graphics.setColor(finalR, finalG, finalB, baseA)
                        
                    elseif part.type == "solar" then
                        -- Panel solar roto con estructura metálica
                        love.graphics.rectangle("fill", partX - partSize * 1.2, partY - partSize * 0.8, partSize * 2.4, partSize * 1.6)
                        
                        -- Marco metálico del panel
                        love.graphics.setColor(finalR * 1.2, finalG * 1.2, finalB * 1.2, baseA * 0.98)
                        love.graphics.setLineWidth(3)
                        love.graphics.rectangle("line", partX - partSize * 1.2, partY - partSize * 0.8, partSize * 2.4, partSize * 1.6)
                        
                        -- Celdas solares individuales
                        love.graphics.setColor(finalR * 0.3, finalG * 0.3, finalB * 0.8, baseA * 0.9)
                        for i = 0, 2 do
                            for j = 0, 1 do
                                local cellX = partX - partSize * 0.8 + i * partSize * 0.8
                                local cellY = partY - partSize * 0.4 + j * partSize * 0.8
                                love.graphics.rectangle("fill", cellX, cellY, partSize * 0.6, partSize * 0.6)
                            end
                        end
                        
                        -- Grietas en el panel con efecto de cristal
                        love.graphics.setColor(0.9, 0.9, 1.0, alpha * 0.95)
                        love.graphics.setLineWidth(3)
                        love.graphics.line(partX - partSize, partY - partSize * 0.5, partX + partSize * 0.8, partY + partSize * 0.3)
                        love.graphics.line(partX - partSize * 0.3, partY - partSize * 0.7, partX + partSize * 0.5, partY + partSize * 0.6)
                        
                        -- Grietas secundarias
                        love.graphics.setColor(0, 0, 0, alpha)
                        love.graphics.setLineWidth(1)
                        love.graphics.line(partX - partSize * 0.8, partY, partX + partSize * 0.2, partY + partSize * 0.4)
                        love.graphics.line(partX, partY - partSize * 0.6, partX + partSize * 0.6, partY)
                        love.graphics.setColor(finalR, finalG, finalB, baseA)
                        
                    elseif part.type == "dock" then
                        -- Puerto de acoplamiento con estructura compleja
                        -- Anillo exterior metálico
                        love.graphics.setColor(finalR * 1.1, finalG * 1.1, finalB * 1.1, baseA * 0.8)
                        love.graphics.setLineWidth(4)
                        love.graphics.circle("line", partX, partY, partSize * 1.8, 16)
                        
                        -- Núcleo central
                        love.graphics.setColor(finalR * 0.9, finalG * 0.9, finalB * 0.9, baseA)
                        love.graphics.circle("fill", partX, partY, partSize * 0.5, 8)
                        
                        -- Reflejo metálico en el núcleo
                        love.graphics.setColor(finalR * 1.4, finalG * 1.4, finalB * 1.4, baseA * 0.6)
                        love.graphics.circle("fill", partX - partSize * 0.2, partY - partSize * 0.2, partSize * 0.25, 6)
                        
                        -- Brazos de acoplamiento rotos con estructura
                        love.graphics.setColor(finalR * 0.8, finalG * 0.8, finalB * 0.8, baseA)
                        love.graphics.setLineWidth(3)
                        for j = 1, 4 do
                            local angle = (j - 1) * math.pi / 2
                            local armX = partX + math.cos(angle) * partSize * 1.5
                            local armY = partY + math.sin(angle) * partSize * 1.5
                            love.graphics.line(partX, partY, armX, armY)
                            
                            -- Conectores dañados
                            love.graphics.setColor(finalR * 0.6, finalG * 0.6, finalB * 0.6, baseA)
                            love.graphics.circle("fill", armX, armY, partSize * 0.4, 6)
                            
                            -- Agujeros en los conectores
                            love.graphics.setColor(0, 0, 0, alpha * 0.95)
                            love.graphics.circle("fill", armX, armY, partSize * 0.2, 6)
                            
                            -- Cables sueltos
                            love.graphics.setColor(finalR * 0.4, finalG * 0.4, finalB * 0.4, baseA * 0.9)
                            love.graphics.setLineWidth(1)
                            love.graphics.line(armX, armY, armX + partSize * 0.3, armY + partSize * 0.2)
                        end
                        love.graphics.setColor(finalR, finalG, finalB, baseA)
                    end
                    
                    -- Restaurar color base para siguiente pieza
                    love.graphics.setColor(baseR, baseG, baseB, baseA)
                end
            end
        end
        
        -- Pequeños fragmentos dispersos
        for i = 1, 12 do
            local angle = (i / 12) * 2 * math.pi + seed * 0.3
            local distance = finalSize * (0.7 + (i % 4) * 0.15)
            local fragX = math.cos(angle) * distance
            local fragY = math.sin(angle) * distance
            local fragSize = finalSize * (0.02 + (i % 3) * 0.01)
            love.graphics.circle("fill", fragX, fragY, fragSize, 4)
        end
        
        love.graphics.pop()
        
    else
        -- Forma por defecto (círculo) - solo para tipos no definidos
        -- Resplandor exterior para círculos básicos
        if glowColor and lod <= 2 then
            love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] * alpha)
            love.graphics.circle("fill", screenX, screenY, finalSize * 1.3, segments)
            love.graphics.setColor(love.graphics.getColor())
        end
        love.graphics.circle("fill", screenX, screenY, finalSize, segments)
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

return AncientRuinsRenderer