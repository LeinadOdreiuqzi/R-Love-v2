-- src/maps/systems/map_renderer.lua
-- Sistema de renderizado tradicional mejorado

local MapRenderer = {}
local CoordinateSystem = require 'src.maps.coordinate_system'
local BiomeSystem = require 'src.maps.biome_system'
local MapConfig = require 'src.maps.config.map_config'
local StarShader = require 'src.shaders.star_shader'
local ShaderManager = require 'src.shaders.shader_manager'

-- Variables de estado para optimización
MapRenderer.sinTable = {}
MapRenderer.cosTable = {}

-- Stride unificado (tamaño del chunk en píxeles + espaciado)
local SIZE_PIXELS = MapConfig.chunk.size * MapConfig.chunk.tileSize
local STRIDE = SIZE_PIXELS + (MapConfig.chunk.spacing or 0)

-- Inicializar tablas de optimización
function MapRenderer.init()
    for i = 0, 359 do
        local rad = math.rad(i)
        MapRenderer.sinTable[i] = math.sin(rad)
        MapRenderer.cosTable[i] = math.cos(rad)
    end
    -- Inicializar shader de estrellas
    if StarShader and StarShader.init then StarShader.init() end
    -- Inicializar ShaderManager para disponer de shaders e imágenes base
    if ShaderManager and ShaderManager.init then ShaderManager.init() end
end
-- Calcular alpha de fade para objetos cerca del borde de pantalla
function MapRenderer.calculateEdgeFade(screenX, screenY, size, camera)
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local fadeMargin = math.max((size or 0) * (camera and camera.zoom or 1) + 60, 100)
    
    -- Distancia al borde más cercano
    local edgeDistX = math.min(screenX + fadeMargin, screenWidth + fadeMargin - screenX)
    local edgeDistY = math.min(screenY + fadeMargin, screenHeight + fadeMargin - screenY)
    local edgeDist = math.min(edgeDistX, edgeDistY)
    
    -- Fade suave en los últimos píxeles
    if edgeDist < fadeMargin then
        return math.max(0.1, edgeDist / fadeMargin)
    end
    return 1.0
end

-- Verificar si un objeto está visible (frustum culling en world-space con margen fijo de 700 px)
function MapRenderer.isObjectVisible(x, y, size, camera)
    -- Si no hay cámara válida, no cullar (mejor dibujar que desaparecer)
    if not camera or type(camera.screenToWorld) ~= "function" then
        return true
    end

    local screenW, screenH = love.graphics.getDimensions()

    -- Convertir el viewport a coordenadas del mundo
    local wl, wt = camera:screenToWorld(0, 0)
    local wr, wb = camera:screenToWorld(screenW, screenH)

    -- Ordenar límites y aplicar margen fijo de 700px en espacio de pantalla
    local left   = math.min(wl, wr)
    local right  = math.max(wl, wr)
    local top    = math.min(wt, wb)
    local bottom = math.max(wt, wb)

    -- Margen fijo (700 px) convertido a unidades del mundo
    local marginWorld = 700 / (camera.zoom or 1)

    left   = left   - marginWorld
    right  = right  + marginWorld
    top    = top    - marginWorld
    bottom = bottom + marginWorld

    return x >= left and x <= right and y >= top and y <= bottom
end

-- Calcular nivel de detalle básico
function MapRenderer.calculateLOD(x, y, camera)
    local screenX, screenY = camera:worldToScreen(x, y)
    local centerX = love.graphics.getWidth() / 2
    local centerY = love.graphics.getHeight() / 2
    
    local distance = math.sqrt((screenX - centerX)^2 + (screenY - centerY)^2)
    local maxDistance = math.sqrt(centerX^2 + centerY^2)
    
    if distance < maxDistance * 0.3 then
        return 0
    elseif distance < maxDistance * 0.7 then
        return 1
    else
        return 2
    end
end

-- Dibujar fondo según bioma dominante
function MapRenderer.drawBiomeBackground(chunkInfo, getChunkFunc)
    local r, g, b, a = love.graphics.getColor()
    
    -- Encontrar bioma más común en chunks visibles
    local biomeCounts = {}
    for chunkY = chunkInfo.startY, chunkInfo.endY do
        for chunkX = chunkInfo.startX, chunkInfo.endX do
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.biome then
                local biomeType = chunk.biome.type
                biomeCounts[biomeType] = (biomeCounts[biomeType] or 0) + 1
            end
        end
    end
    
    -- Encontrar bioma dominante
    local dominantBiome = BiomeSystem.BiomeType.DEEP_SPACE
    local maxCount = 0
    for biomeType, count in pairs(biomeCounts) do
        if count > maxCount then
            maxCount = count
            dominantBiome = biomeType
        end
    end
    
    -- Dibujar fondo del bioma dominante - SOLAMENTE SI NO ES DEEP SPACE O ES MUY DOMINANTE
    love.graphics.push()
    love.graphics.origin()
    
    if dominantBiome ~= BiomeSystem.BiomeType.DEEP_SPACE then
        -- Bioma no-Deep Space: usar color completo pero con alpha reducida
        local backgroundColor = BiomeSystem.getBackgroundColor(dominantBiome)
        love.graphics.setColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], 0.15)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    else
        -- Deep Space: usar gradiente muy sutil en lugar de negro sólido
        local totalChunks = (chunkInfo.endX - chunkInfo.startX + 1) * (chunkInfo.endY - chunkInfo.startY + 1)
        local deepSpaceRatio = maxCount / totalChunks
        
        if deepSpaceRatio > 0.7 then
            -- Solo si Deep Space es REALMENTE dominante (>70%), dibujar gradiente muy sutil
            love.graphics.setColor(0.02, 0.02, 0.05, 0.3)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        end
        -- Si Deep Space no es muy dominante, no dibujar fondo (dejar transparente)
    end
    
    love.graphics.pop()
    love.graphics.setColor(r, g, b, a)
    return maxCount
end

-- Dibujar estrellas con efectos mejorados
function MapRenderer.drawEnhancedStars(chunkInfo, camera, getChunkFunc, starConfig)
    local time = love.timer.getTime()
    local starsRendered = 0
    -- Limita a 3000 sin tocar config global
    local maxStarsPerFrame = math.min(starConfig.maxStarsPerFrame or 5000, 3000)
    -- Obtener la posición de la cámara en el espacio de juego
    local cameraX, cameraY = camera.x, camera.y
    local parallaxStrength = starConfig.parallaxStrength or 0.2
    -- Config profunda (2 capas) - usar la clave correcta 'deepLayers'
    local deepLayers = (starConfig and starConfig.deepLayers) or {
        { threshold = 0.90,  parallaxScale = 0.35, sizeScale = 0.55 },
        { threshold = 0.945, parallaxScale = 0.15, sizeScale = 0.40 }
    }
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local margin = 1000 -- Margen más grande para precarga suave
    local visibleStars = {}
    local totalStars = 0
    
    -- Asegurar que la cámara tenga dimensiones actualizadas
    if not camera.screenWidth or not camera.screenHeight then
        camera:updateScreenDimensions()
    end
    
    -- Obtener la posición del jugador para el efecto de paralaje
    local playerX, playerY = cameraX, cameraY
    
    -- Calcular el área visible en coordenadas del mundo
    local camLeft, camTop = camera:screenToWorld(0, 0)
    local camRight, camBottom = camera:screenToWorld(screenWidth, screenHeight)
    
    -- Expandir el área visible con el margen
    local viewportLeft = camLeft - margin / camera.zoom
    local viewportTop = camTop - margin / camera.zoom
    local viewportRight = camRight + margin / camera.zoom
    local viewportBottom = camBottom + margin / camera.zoom
    
    -- Calcular chunks visibles basados en la vista
    -- Usar los bounds/unidades unificadas
    local chunkSize = STRIDE * MapConfig.chunk.worldScale
    local viewportLeft = chunkInfo.worldLeft
    local viewportTop = chunkInfo.worldTop
    local viewportRight = chunkInfo.worldRight
    local viewportBottom = chunkInfo.worldBottom

    local startChunkX = chunkInfo.startX
    local endChunkX = chunkInfo.endX
    local startChunkY = chunkInfo.startY
    local endChunkY = chunkInfo.endY

    -- Recorrer solo los chunks visibles (idéntico a otros renderers)
    for chunkY = startChunkY, endChunkY do
        for chunkX = startChunkX, endChunkX do
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.objects and chunk.objects.stars then
                local chunkBaseX = chunkX * chunkSize
                local chunkBaseY = chunkY * chunkSize

                for _, star in ipairs(chunk.objects.stars) do
                    local worldX = chunkBaseX + star.x * MapConfig.chunk.worldScale
                    local worldY = chunkBaseY + star.y * MapConfig.chunk.worldScale

                    -- Determinar capa y escalados según profundidad
                    local layerId = star.type or 1
                    local localParallaxStrength = parallaxStrength
                    local sizeScaleExtra = 1.0

                    if star.depth then
                        -- Capa más profunda (deep2)
                        if deepLayers[2] and star.depth >= deepLayers[2].threshold then
                            layerId = -2
                            localParallaxStrength = parallaxStrength * (deepLayers[2].parallaxScale or 0.35)
                            sizeScaleExtra = deepLayers[2].sizeScale or 0.40
                        -- Capa profunda 1 (deep1)
                        elseif deepLayers[1] and star.depth >= deepLayers[1].threshold then
                            layerId = -1
                            localParallaxStrength = parallaxStrength * (deepLayers[1].parallaxScale or 0.60)
                            sizeScaleExtra = deepLayers[1].sizeScale or 0.55
                        end
                    end

                    -- Aplicar efecto de paralaje con la fuerza local (más lenta para capas profundas)
                    if parallaxStrength > 0 then
                        local depth = star.depth or 0.5
                        local depthFactor = (1.0 - depth) * 1.5
                        local relX = worldX - playerX
                        local relY = worldY - playerY
                        worldX = playerX + relX * (1 + depthFactor * localParallaxStrength)
                        worldY = playerY + relY * (1 + depthFactor * localParallaxStrength)
                    end

                    -- Verificar si la estrella está dentro del área visible + margen
                    if worldX >= viewportLeft and worldX <= viewportRight and
                       worldY >= viewportTop and worldY <= viewportBottom then
                        local screenX, screenY = camera:worldToScreen(worldX, worldY)
                        local depth = star.depth or 0.5
                        local baseSize = math.max(0.5, star.size or 1)
                        -- Invertir: estrellas más lejanas (depth alto) más pequeñas
                        local sizeMultiplier = 0.3 + (1.0 - depth) * 0.7
                        -- Reducir tamaño extra para capas profundas
                        local starSize = baseSize * 2.0 * (camera.zoom or 1.0) * sizeMultiplier * (sizeScaleExtra or 1.0)

                        if screenX + starSize >= -margin and screenX - starSize <= screenWidth + margin and
                           screenY + starSize >= -margin and screenY - starSize <= screenHeight + margin then
                            screenX = math.max(-margin, math.min(screenWidth + margin, screenX))
                            screenY = math.max(-margin, math.min(screenHeight + margin, screenY))

                            -- Guardar el factor para aplicarlo en el render real
                            if sizeScaleExtra ~= 1.0 then
                                star._sizeScaleExtra = sizeScaleExtra
                            else
                                star._sizeScaleExtra = nil
                            end
                            
                            visibleStars[layerId] = visibleStars[layerId] or {}
                            table.insert(visibleStars[layerId], {
                                star = star,
                                screenX = screenX,
                                screenY = screenY,
                                camera = camera
                            })
                        end
                    end
                end
            end
        end
    end

    -- Preparar espacio de pantalla y batching (una sola vez)
    love.graphics.push()
    love.graphics.origin()
    local usingStarShader = (starConfig.enhancedEffects and StarShader and StarShader.getShader and StarShader.getShader())
    if usingStarShader and StarShader.begin then
        StarShader.begin()
    end

    -- Helper: dibujar una capa agrupando por tipo
    local function drawLayerGroupedByType(layerStars)
        -- Ordenar por profundidad para mantener estética
        table.sort(layerStars, function(a, b)
            return (a.star.depth or 0.5) > (b.star.depth or 0.5)
        end)
        -- Agrupar por tipo
        local starsByType = {}
        for i = 1, #layerStars do
            local info = layerStars[i]
            local t = info.star.type or 1
            local list = starsByType[t]
            if not list then
                list = {}
                starsByType[t] = list
            end
            list[#list + 1] = info
        end
        -- Iterar tipos en orden determinista
        local typeKeys = {}
        for t, _ in pairs(starsByType) do
            typeKeys[#typeKeys + 1] = t
        end
        table.sort(typeKeys)

        for _, t in ipairs(typeKeys) do
            local list = starsByType[t]
            if usingStarShader and StarShader.setType then
                StarShader.setType(t)
            end
            for i = 1, #list do
                if starsRendered >= maxStarsPerFrame then return end
                local starInfo = list[i]
                MapRenderer.drawAdvancedStar(
                    starInfo.star,
                    starInfo.screenX,
                    starInfo.screenY,
                    time,
                    starConfig,
                    starInfo.camera or camera,
                    true,                                 -- inScreenSpace
                    starInfo.star._sizeScaleExtra,       -- sizeScaleExtra
                    true                                  -- uniformsPreset: ya fijados por tipo
                )
                starsRendered = starsRendered + 1
            end
        end
    end

    -- Dibujar capas profundas primero
    for _, layer in ipairs({-2, -1}) do
        if visibleStars[layer] then
            drawLayerGroupedByType(visibleStars[layer])
        end
    end

    -- Capas existentes (1..6)
    for layer = 1, 6 do
        if visibleStars[layer] then
            drawLayerGroupedByType(visibleStars[layer])
            if starsRendered >= maxStarsPerFrame then break end
        end
    end

    if usingStarShader and StarShader.finish then
        StarShader.finish()
    end
    love.graphics.pop()

    return starsRendered, totalStars
end



-- Dibujar estrella individual con efectos avanzados
-- Ahora usa screenX y screenY que ya están en coordenadas de pantalla
function MapRenderer.drawAdvancedStar(star, screenX, screenY, time, starConfig, camera, inScreenSpace, sizeScaleExtra, uniformsPreset)
    local r, g, b, a = love.graphics.getColor()
    
    if not starConfig.enhancedEffects then
        love.graphics.setColor(star.color[1], star.color[2], star.color[3], star.color[4])
        love.graphics.circle("fill", screenX, screenY, star.size * (camera and camera.zoom or 1.0), 6)
        love.graphics.setColor(r, g, b, a)
        return
    end
    
    local starType = star.type or 1
    
    -- Calcular parpadeo individual
    local twinklePhase = time * (star.twinkleSpeed or 1) + (star.twinkle or 0)
    local angleIndex = math.floor(twinklePhase * 57.29) % 360
    local twinkleIntensity = 0.6 + 0.4 * MapRenderer.sinTable[angleIndex]
    local brightness = (star.brightness or 1)
    
    local color = star.color
    local sizeScaleExtra = sizeScaleExtra or 1.0
    local size = (star.size * sizeScaleExtra) * (camera and camera.zoom or 1.0)

    -- Si hay efectos mejorados y shader disponible, usar GPU shader para estrellas
    if starConfig.enhancedEffects and StarShader and StarShader.getShader and StarShader.getShader() then
        local adjustedSize = size * 0.8

        if not inScreenSpace then
            love.graphics.push()
            love.graphics.origin()
        end

        local shaderActive = (love.graphics.getShader and (love.graphics.getShader() == StarShader.getShader()))
        if shaderActive then
            if uniformsPreset and StarShader.drawStarBatchedNoUniforms then
                StarShader.drawStarBatchedNoUniforms(screenX, screenY, adjustedSize, color, brightness, twinkleIntensity, starType)
            elseif StarShader.drawStarWithUniformsNoSet then
                StarShader.drawStarWithUniformsNoSet(screenX, screenY, adjustedSize, color, brightness, twinkleIntensity, starType)
            elseif StarShader.drawStarBatched then
                StarShader.drawStarBatched(screenX, screenY, adjustedSize, color, brightness, twinkleIntensity, starType)
            end
        else
            if StarShader.drawStarBatched then
                StarShader.drawStarBatched(screenX, screenY, adjustedSize, color, brightness, twinkleIntensity, starType)
            end
        end

        if not inScreenSpace then
            love.graphics.pop()
        end

        love.graphics.setColor(r, g, b, a)
        return
    end
    
    -- Renderizado por tipo de estrella (usando coordenadas de pantalla)
    if starType == 1 then
        if brightness > 0.7 then
            love.graphics.setColor(color[1] * brightness * 0.3, color[2] * brightness * 0.3, color[3] * brightness * 0.3, 0.2)
            love.graphics.circle("fill", screenX, screenY, size * 2, 8)
        end
        love.graphics.setColor(color[1] * brightness, color[2] * brightness, color[3] * brightness, color[4])
        love.graphics.circle("fill", screenX, screenY, size, 6)
        
    elseif starType == 4 then
        local pulseIndex = math.floor((time * 6 + (star.pulsePhase or 0)) * 57.29) % 360
        local pulse = 0.8 + 0.2 * MapRenderer.sinTable[pulseIndex]
        
        love.graphics.setColor(color[1] * brightness * 0.7, color[2] * brightness * 0.7, color[3] * brightness * 0.7, 0.3)
        love.graphics.circle("fill", screenX, screenY, size * 3 * pulse, 12)
        love.graphics.circle("fill", screenX, screenY, size * 0.8, 12)
        
        love.graphics.setColor(1, 1, 1, brightness * 0.9)
        love.graphics.circle("fill", screenX, screenY, size * 0.3, 6)
    else
        -- Tipos básicos
        love.graphics.setColor(color[1] * brightness * 0.3, color[2] * brightness * 0.3, color[3] * brightness * 0.3, 0.3)
        love.graphics.circle("fill", screenX, screenY, size * 2, 12)
        
        love.graphics.setColor(color[1] * brightness, color[2] * brightness, color[3] * brightness, color[4])
        love.graphics.circle("fill", screenX, screenY, size, 8)
    end
    
    love.graphics.setColor(r, g, b, a)
end

-- Dibujar nebulosas
function MapRenderer.drawNebulae(chunkInfo, camera, getChunkFunc)
    local time = love.timer.getTime()
    local rendered = 0
    local maxNebulaePerFrame = (MapConfig.performance and MapConfig.performance.maxNebulaePerFrame) or 1200
    
    for chunkY = chunkInfo.startY, chunkInfo.endY do
        for chunkX = chunkInfo.startX, chunkInfo.endX do
            if rendered >= maxNebulaePerFrame then return rendered end
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.objects and chunk.objects.nebulae then
                local chunkBaseX = chunkX * STRIDE * MapConfig.chunk.worldScale
                local chunkBaseY = chunkY * STRIDE * MapConfig.chunk.worldScale
                
                for _, nebula in ipairs(chunk.objects.nebulae) do
                    if rendered >= maxNebulaePerFrame then return rendered end
                    local worldX = chunkBaseX + nebula.x * MapConfig.chunk.worldScale
                    local worldY = chunkBaseY + nebula.y * MapConfig.chunk.worldScale
                    
                    if MapRenderer.isObjectVisible(worldX, worldY, nebula.size * 2, camera) then
                        MapRenderer.drawNebula(nebula, worldX, worldY, time, camera)
                        rendered = rendered + 1
                    end
                end
            end
        end
    end
    
    return rendered
end

-- Dibujar nebulosa individual
function MapRenderer.drawNebula(nebula, worldX, worldY, time, camera)
    local r, g, b, a = love.graphics.getColor()
    
    local timeIndex = math.floor((time * 0.8 * 57.3) % 360)
    local pulse = 0.9 + 0.1 * MapRenderer.sinTable[timeIndex]
    local currentSize = nebula.size * pulse
    
    -- Convertir a coordenadas de pantalla y aplicar fade
    local screenX, screenY = camera:worldToScreen(worldX, worldY)
    local alpha = MapRenderer.calculateEdgeFade(screenX, screenY, currentSize, camera)
    love.graphics.setColor(nebula.color[1], nebula.color[2], nebula.color[3], (nebula.color[4] or 1) * (nebula.intensity or 1) * alpha)
    
    love.graphics.push()
    love.graphics.origin()
    
    local radiusPx = currentSize * (camera.zoom or 1)
    local shader = ShaderManager and ShaderManager.getShader and ShaderManager.getShader("nebula") or nil
    local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle") or nil
    if shader and img then
        love.graphics.setShader(shader)
        local iw, ih = img:getWidth(), img:getHeight()
        local scale = (radiusPx * 2) / math.max(1, iw)
        love.graphics.draw(img, screenX, screenY, 0, scale, scale, iw * 0.5, ih * 0.5)
        love.graphics.setShader()
    else
        if radiusPx > 80 then
            love.graphics.circle("fill", screenX, screenY, radiusPx, 16)
        else
            love.graphics.circle("fill", screenX, screenY, radiusPx, 12)
        end
    end
    
    love.graphics.pop()
    love.graphics.setColor(r, g, b, a)
end

-- Dibujar asteroides
function MapRenderer.drawAsteroids(chunkInfo, camera, getChunkFunc)
    local rendered = 0
    -- Cap duro de asteroides por frame (puedes ajustar)
    local maxAsteroidsPerFrame = (MapConfig.performance and MapConfig.performance.maxAsteroidsPerFrame) or 3000

    for chunkY = chunkInfo.startY, chunkInfo.endY do
        for chunkX = chunkInfo.startX, chunkInfo.endX do
            if rendered >= maxAsteroidsPerFrame then return rendered end
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.tiles then
                local chunkBaseTileX = chunkX * MapConfig.chunk.size
                local chunkBaseTileY = chunkY * MapConfig.chunk.size
                local chunkBaseWorldX = chunkX * STRIDE * MapConfig.chunk.worldScale
                local chunkBaseWorldY = chunkY * STRIDE * MapConfig.chunk.worldScale

                for y = 0, MapConfig.chunk.size - 1 do
                    if rendered >= maxAsteroidsPerFrame then return rendered end
                    for x = 0, MapConfig.chunk.size - 1 do
                        if rendered >= maxAsteroidsPerFrame then return rendered end
                        local tileType = chunk.tiles[y][x]
                        if tileType >= MapConfig.ObjectType.ASTEROID_SMALL and tileType <= MapConfig.ObjectType.ASTEROID_LARGE then
                            local globalTileX = chunkBaseTileX + x
                            local globalTileY = chunkBaseTileY + y
                            local worldX = chunkBaseWorldX + x * MapConfig.chunk.tileSize * MapConfig.chunk.worldScale
                            local worldY = chunkBaseWorldY + y * MapConfig.chunk.tileSize * MapConfig.chunk.worldScale
                            
                            local sizes = {8, 15, 25}
                            local size = sizes[tileType] * MapConfig.chunk.worldScale * 1.5
                            
                            if MapRenderer.isObjectVisible(worldX, worldY, size, camera) then
                                local lod = MapRenderer.calculateLOD(worldX, worldY, camera)
                                MapRenderer.drawAsteroidLOD(tileType, worldX, worldY, globalTileX, globalTileY, lod, camera)
                                rendered = rendered + 1
                                if rendered >= maxAsteroidsPerFrame then return rendered end
                            end
                        end
                    end
                end
            end
        end
    end
    return rendered
end

-- Dibujar asteroide con LOD
function MapRenderer.drawAsteroidLOD(asteroidType, worldX, worldY, globalX, globalY, lod, camera)
    -- RNG determinista local (LCG)
    local function lcg(state) return (state * 1664525 + 1013904223) % 4294967296 end
    local function next01(state)
        state = lcg(state)
        return state, (state / 4294967296)
    end
    -- Semilla determinista por tile y tipo
    local state = (globalX * 1103515245 + globalY * 12345 + asteroidType * 2654435761) % 4294967296

    local sizes = {8, 15, 25}
    local baseSize = sizes[asteroidType] * MapConfig.chunk.worldScale
    local colorIndex = (globalX + globalY) % #MapConfig.colors.asteroids + 1
    local color = MapConfig.colors.asteroids[colorIndex]
    
    -- Variación de tamaño determinista
    state, r1 = next01(state)
    local sizeVariation = 0.8 + r1 * 0.4
    local finalSize = baseSize * sizeVariation

    -- Convertir a pantalla una sola vez y calcular fade
    local sx, sy = camera:worldToScreen(worldX, worldY)
    local alpha = MapRenderer.calculateEdgeFade(sx, sy, finalSize, camera)
    local segments = lod >= 2 and 6 or (lod >= 1 and 8 or 12)
    local pxSize = finalSize * (camera.zoom or 1)
    
    love.graphics.push()
    love.graphics.origin()

    local shader = ShaderManager and ShaderManager.getShader and ShaderManager.getShader("asteroid") or nil
    local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle") or nil
    if shader and img then
        love.graphics.setShader(shader)
        local iw, ih = img:getWidth(), img:getHeight()
        local scale = (pxSize * 2) / math.max(1, iw)
        
        if lod >= 2 then
            love.graphics.setColor(color[1], color[2], color[3], 0.8 * alpha)
            love.graphics.draw(img, sx, sy, 0, scale, scale, iw * 0.5, ih * 0.5)
            love.graphics.setShader()
            love.graphics.pop()
            return
        end
        
        if lod >= 1 then
            love.graphics.setColor(0.1, 0.1, 0.1, 0.3 * alpha)
            love.graphics.draw(img, sx + 2, sy + 2, 0, (pxSize + 1) * 2 / iw, (pxSize + 1) * 2 / ih, iw * 0.5, ih * 0.5)
            love.graphics.setColor(color[1], color[2], color[3], 1 * alpha)
            love.graphics.draw(img, sx, sy, 0, scale, scale, iw * 0.5, ih * 0.5)
            love.graphics.setShader()
            love.graphics.pop()
            return
        end
        
        -- LOD 0: detalle + highlights
        love.graphics.setColor(0.1, 0.1, 0.1, 0.5 * alpha)
        love.graphics.draw(img, sx + 2, sy + 2, 0, (pxSize + 1) * 2 / iw, (pxSize + 1) * 2 / ih, iw * 0.5, ih * 0.5)
        love.graphics.setColor(color[1], color[2], color[3], 1 * alpha)
        love.graphics.draw(img, sx, sy, 0, scale, scale, iw * 0.5, ih * 0.5)
        
        if asteroidType >= MapConfig.ObjectType.ASTEROID_MEDIUM then
            love.graphics.setColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, 1 * alpha)
            state, r2 = next01(state)
            local numDetails = math.min(2 + math.floor(r2 * 3), math.floor(pxSize / 5))
            for i = 1, numDetails do
                state, rA = next01(state)
                state, rB = next01(state)
                state, rC = next01(state)
                local angle = (i / numDetails) * 2 * math.pi + rA * 0.5
                local detailDistancePx = (finalSize * 0.3 * rB) * (camera.zoom or 1)
                local detailX = sx + math.cos(angle) * detailDistancePx
                local detailY = sy + math.sin(angle) * detailDistancePx
                local detailSizePx = (finalSize * 0.2 * rC) * (camera.zoom or 1)
                love.graphics.draw(img, detailX, detailY, 0, (detailSizePx * 2) / iw, (detailSizePx * 2) / ih, iw * 0.5, ih * 0.5)
            end
        end
        
        if asteroidType == MapConfig.ObjectType.ASTEROID_LARGE then
            love.graphics.setColor(color[1] * 1.3, color[2] * 1.3, color[3] * 1.3, 0.7 * alpha)
            love.graphics.draw(img, sx - pxSize * 0.3, sy - pxSize * 0.3, 0, (pxSize * 0.4 * 2) / iw, (pxSize * 0.4 * 2) / ih, iw * 0.5, ih * 0.5)
        end
        
        love.graphics.setShader()
    else
        -- Fallback sin shader (círculos como antes)
        if lod >= 2 then
            love.graphics.setColor(color[1], color[2], color[3], 0.8 * alpha)
            love.graphics.circle("fill", sx, sy, pxSize, segments)
            love.graphics.pop()
            return
        end
        if lod >= 1 then
            love.graphics.setColor(0.1, 0.1, 0.1, 0.3 * alpha)
            love.graphics.circle("fill", sx + 2, sy + 2, pxSize + 1, segments)
            love.graphics.setColor(color[1], color[2], color[3], 1 * alpha)
            love.graphics.circle("fill", sx, sy, pxSize, segments)
            love.graphics.pop()
            return
        end
        love.graphics.setColor(0.1, 0.1, 0.1, 0.5 * alpha)
        love.graphics.circle("fill", sx + 2, sy + 2, pxSize + 1, segments)
        love.graphics.setColor(color[1], color[2], color[3], 1 * alpha)
        love.graphics.circle("fill", sx, sy, pxSize, segments)
    end

    love.graphics.pop()
end

-- Dibujar objetos especiales
function MapRenderer.drawSpecialObjects(chunkInfo, camera, getChunkFunc)
    local rendered = 0
    local maxSpecialPerFrame = (MapConfig.performance and MapConfig.performance.maxSpecialPerFrame) or 800

    local startX = chunkInfo.startX - 1
    local endX   = chunkInfo.endX + 1
    local startY = chunkInfo.startY - 1
    local endY   = chunkInfo.endY + 1

    for chunkY = startY, endY do
        for chunkX = startX, endX do
            if rendered >= maxSpecialPerFrame then return rendered end
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.specialObjects then
                local chunkBaseX = chunkX * STRIDE * MapConfig.chunk.worldScale
                local chunkBaseY = chunkY * STRIDE * MapConfig.chunk.worldScale
                for _, obj in ipairs(chunk.specialObjects) do
                    if rendered >= maxSpecialPerFrame then return rendered end
                    if obj.type == MapConfig.ObjectType.STATION or obj.type == MapConfig.ObjectType.WORMHOLE then
                        local worldX = chunkBaseX + obj.x * MapConfig.chunk.worldScale
                        local worldY = chunkBaseY + obj.y * MapConfig.chunk.worldScale
                        if MapRenderer.isObjectVisible(worldX, worldY, obj.size * 2, camera) then
                            if obj.type == MapConfig.ObjectType.STATION then
                                MapRenderer.drawStation(obj, worldX, worldY, camera)
                            elseif obj.type == MapConfig.ObjectType.WORMHOLE then
                                -- FIX: pasar el objeto correcto
                                MapRenderer.drawWormhole(obj, worldX, worldY, camera)
                            end
                            rendered = rendered + 1
                        end
                    end
                end
            end
        end
    end
    return rendered
end

-- Dibujar estación (en coordenadas de pantalla con fade)
function MapRenderer.drawStation(station, worldX, worldY, camera)
    if not station then return end  -- Guardia defensiva como en wormhole

    local r, g, b, a = love.graphics.getColor()
    local screenX, screenY = camera:worldToScreen(worldX, worldY)
    local renderSize = station.size * camera.zoom
    if renderSize < 6 then renderSize = 6 end
    local alpha = MapRenderer.calculateEdgeFade(screenX, screenY, station.size, camera)
    
    love.graphics.push()
    love.graphics.origin()
    love.graphics.translate(screenX, screenY)
    
    local rotation = station.rotation + love.timer.getTime() * 0.1
    love.graphics.rotate(rotation)
    
    -- Forzar el estilo anterior (vectorial) y NO usar shader ni imagen base
    local segments = station.size < 20 and 8 or (station.size > 40 and 16 or 12)
    love.graphics.setColor(0.1, 0.1, 0.1, 0.3 * alpha)
    love.graphics.circle("fill", 2, 2, renderSize * 1.1, segments)
    love.graphics.setColor(0.6, 0.6, 0.8, 1 * alpha)
    love.graphics.circle("fill", 0, 0, renderSize, segments)
    if renderSize > 15 then
        love.graphics.setColor(0.3, 0.5, 0.8, 1 * alpha)
        love.graphics.circle("line", 0, 0, renderSize * 0.8, segments)
        love.graphics.circle("line", 0, 0, renderSize * 0.6, segments)
    end
    love.graphics.setColor(0.2, 0.3, 0.7, 0.8 * alpha)
    love.graphics.rectangle("fill", -renderSize * 1.5, -renderSize * 0.2, renderSize * 0.4, renderSize * 0.4)
    love.graphics.rectangle("fill",  renderSize * 1.1, -renderSize * 0.2, renderSize * 0.4, renderSize * 0.4)
    if math.floor(love.timer.getTime()) % 2 == 0 then
        love.graphics.setColor(0, 1, 0, 1 * alpha)
        love.graphics.circle("fill", renderSize * 0.7, 0, 2, 4)
        love.graphics.circle("fill", -renderSize * 0.7, 0, 2, 4)
    end
    
    love.graphics.pop()
    love.graphics.setColor(r, g, b, a)
end

-- Dibujar wormhole (en coordenadas de pantalla con fade)
function MapRenderer.drawWormhole(wormhole, worldX, worldY, camera)
    if not wormhole then return end
    local r, g, b, a = love.graphics.getColor()
    local time = love.timer.getTime()
    local timeIndex = math.floor((time * 2 + wormhole.pulsePhase) * 57.29) % 360
    local pulse = 0.8 + 0.2 * MapRenderer.sinTable[timeIndex]
    local sizePx = wormhole.size * pulse * camera.zoom
    if sizePx < 6 then sizePx = 6 end

    local screenX, screenY = camera:worldToScreen(worldX, worldY)
    local alpha = MapRenderer.calculateEdgeFade(screenX, screenY, wormhole.size * pulse, camera)
    local segments = sizePx < 20 and 8 or (sizePx > 40 and 16 or 12)
    
    love.graphics.push()
    love.graphics.origin()
    
    local shader = ShaderManager and ShaderManager.getShader and ShaderManager.getShader("nebula") or nil
    local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle") or nil
    if shader and img then
        love.graphics.setShader(shader)
        -- Capa externa (aura)
        love.graphics.setColor(0.1, 0.1, 0.4, 0.8 * alpha)
        local iw, ih = img:getWidth(), img:getHeight()
        local scaleOuter = (sizePx * 1.6 * 2) / math.max(1, iw)
        love.graphics.draw(img, screenX, screenY, 0, scaleOuter, scaleOuter, iw * 0.5, ih * 0.5)

        -- Anillo principal
        love.graphics.setColor(0.3, 0.1, 0.8, 0.9 * alpha)
        local scaleMain = (sizePx * 1.0 * 2) / iw
        love.graphics.draw(img, screenX, screenY, 0, scaleMain, scaleMain, iw * 0.5, ih * 0.5)

        -- Núcleo
        love.graphics.setColor(0.6, 0.3, 1.0, 0.7 * alpha)
        local scaleInner = (sizePx * 0.6 * 2) / iw
        love.graphics.draw(img, screenX, screenY, 0, scaleInner, scaleInner, iw * 0.5, ih * 0.5)

        -- Centro brillante
        love.graphics.setColor(1, 1, 1, 0.9 * alpha)
        local scaleCenter = (sizePx * 0.2 * 2) / iw
        love.graphics.draw(img, screenX, screenY, 0, scaleCenter, scaleCenter, iw * 0.5, ih * 0.5)

        love.graphics.setShader()
    else
        -- Fallback sin shader (círculos)
        local segments = sizePx < 20 and 8 or (sizePx > 40 and 16 or 12)
        love.graphics.setColor(0.1, 0.1, 0.4, 0.8 * alpha)
        love.graphics.circle("fill", screenX, screenY, sizePx * 1.5, segments)

        love.graphics.setColor(0.3, 0.1, 0.8, 0.9 * alpha)
        love.graphics.circle("fill", screenX, screenY, sizePx, segments)

        love.graphics.setColor(0.6, 0.3, 1, 0.7 * alpha)
        love.graphics.circle("fill", screenX, screenY, sizePx * 0.6, segments)

        love.graphics.setColor(1, 1, 1, 0.9 * alpha)
        love.graphics.circle("fill", screenX, screenY, sizePx * 0.2, 8)
    end

    love.graphics.pop()
    love.graphics.setColor(r, g, b, a)
end

-- Dibujar características de biomas
function MapRenderer.drawBiomeFeatures(chunkInfo, camera, getChunkFunc)
    local rendered = 0
    
    for chunkY = chunkInfo.startY, chunkInfo.endY do
        for chunkX = chunkInfo.startX, chunkInfo.endX do
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.specialObjects then
                local chunkBaseX = chunkX * STRIDE * MapConfig.chunk.worldScale
                local chunkBaseY = chunkY * STRIDE * MapConfig.chunk.worldScale
                
                for _, feature in ipairs(chunk.specialObjects) do
                    if feature.type and type(feature.type) == "string" then
                        local worldX = chunkBaseX + feature.x * MapConfig.chunk.worldScale
                        local worldY = chunkBaseY + feature.y * MapConfig.chunk.worldScale
                        
                        if MapRenderer.isObjectVisible(worldX, worldY, feature.size * 2, camera) then
                            MapRenderer.drawBiomeFeature(feature, worldX, worldY, camera)
                            rendered = rendered + 1
                        end
                    end
                end
            end
        end
    end
    
    return rendered
end

-- Dibujar característica de bioma individual
function MapRenderer.drawBiomeFeature(feature, worldX, worldY, camera)
    local r, g, b, a = love.graphics.getColor()
    
    local screenX, screenY = camera:worldToScreen(worldX, worldY)
    local renderSize = feature.size * camera.zoom
    local alpha = MapRenderer.calculateEdgeFade(screenX, screenY, feature.size, camera)
    
    local time = love.timer.getTime()
    local timeIndex2 = math.floor((time * 2 * 57.3) % 360) + 1
    local timeIndex3 = math.floor((time * 3 * 57.3) % 360) + 1
    
    love.graphics.push()
    love.graphics.origin()
    
    if feature.type == "dense_nebula" then
        local shader = ShaderManager and ShaderManager.getShader and ShaderManager.getShader("nebula") or nil
        local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle") or nil
        if shader and img then
            love.graphics.setShader(shader)
            local iw, ih = img:getWidth(), img:getHeight()
            -- Capa base
            love.graphics.setColor(feature.color[1], feature.color[2], feature.color[3], (feature.color[4] or 1) * alpha)
            local baseScale = (renderSize * 2) / math.max(1, iw)
            love.graphics.draw(img, screenX, screenY, 0, baseScale, baseScale, iw * 0.5, ih * 0.5)
            -- Halo pulsante
            local pulse = 0.8 + 0.2 * MapRenderer.sinTable[timeIndex2 % 360]
            love.graphics.setColor(feature.color[1], feature.color[2], feature.color[3], (feature.color[4] or 1) * 0.35 * pulse * alpha)
            local haloScale = (renderSize * 1.3 * 2) / iw
            love.graphics.draw(img, screenX, screenY, 0, haloScale, haloScale, iw * 0.5, ih * 0.5)
            love.graphics.setShader()
        else
            -- Fallback previo
            love.graphics.setColor(feature.color[1], feature.color[2], feature.color[3], (feature.color[4] or 1) * alpha)
            love.graphics.circle("fill", screenX, screenY, renderSize, 24)
            local pulse = 0.8 + 0.2 * MapRenderer.sinTable[timeIndex2]
            love.graphics.setColor(feature.color[1], feature.color[2], feature.color[3], (feature.color[4] or 1) * 0.3 * pulse * alpha)
            love.graphics.circle("fill", screenX, screenY, renderSize * 1.3, 16)
        end

    elseif feature.type == "mega_asteroid" then
        local shader = ShaderManager and ShaderManager.getShader and ShaderManager.getShader("asteroid") or nil
        local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle") or nil
        if shader and img then
            love.graphics.setShader(shader)
            local iw, ih = img:getWidth(), img:getHeight()
            -- Sombra
            love.graphics.setColor(0, 0, 0, 0.3 * alpha)
            love.graphics.draw(img, screenX + 3, screenY + 3, 0, (renderSize * 2) / iw, (renderSize * 2) / ih, iw * 0.5, ih * 0.5)
            -- Cuerpo
            love.graphics.setColor(feature.color[1], feature.color[2], feature.color[3], (feature.color[4] or 1) * alpha)
            love.graphics.draw(img, screenX, screenY, 0, (renderSize * 2) / iw, (renderSize * 2) / ih, iw * 0.5, ih * 0.5)
            love.graphics.setShader()
        else
            -- Fallback previo
            love.graphics.setColor(feature.color[1], feature.color[2], feature.color[3], (feature.color[4] or 1) * alpha)
            love.graphics.circle("fill", screenX, screenY, renderSize, 16)
            love.graphics.setColor(0, 0, 0, 0.3 * alpha)
            love.graphics.circle("fill", screenX + 3, screenY + 3, renderSize, 16)
        end

    elseif feature.type == "gravity_well" then
        -- Mantener primitivas (efecto de anillos)
        if renderSize > 5 then
            for i = 1, 3 do
                local radius = renderSize * i * 0.8
                local alphaAdjusted = (feature.color[4] or 1) / i * alpha
                love.graphics.setColor(feature.color[1], feature.color[2], feature.color[3], alphaAdjusted)
                love.graphics.circle("line", screenX, screenY, radius, 16)
            end
        else
            love.graphics.setColor(feature.color[1], feature.color[2], feature.color[3], (feature.color[4] or 1) * alpha)
            love.graphics.circle("fill", screenX, screenY, renderSize, 12)
        end

    elseif feature.type == "dead_star" then
        -- Mantener implementación previa con primitivas
        love.graphics.setColor(feature.color[1], feature.color[2], feature.color[3], (feature.color[4] or 1) * alpha)
        love.graphics.circle("fill", screenX, screenY, renderSize, 12)
        local pulse = 0.5 + 0.5 * MapRenderer.sinTable[timeIndex3]
        love.graphics.setColor(1, 0.5, 0, 0.3 * pulse * alpha)
        love.graphics.circle("fill", screenX, screenY, renderSize * 3, 16)

    elseif feature.type == "ancient_station" then
        local shader = ShaderManager and ShaderManager.getShader and ShaderManager.getShader("station") or nil
        local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("white") or nil
        if shader and img then
            love.graphics.push()
            love.graphics.translate(screenX, screenY)
            love.graphics.rotate(time * 0.2)
            love.graphics.setShader(shader)
            love.graphics.setColor(feature.color[1], feature.color[2], feature.color[3], (feature.color[4] or 1) * alpha)
            local iw, ih = img:getWidth(), img:getHeight()
            local scale = (renderSize * 2) / math.max(1, iw)
            love.graphics.draw(img, 0, 0, 0, scale, scale, iw * 0.5, ih * 0.5)
            love.graphics.setShader()
            love.graphics.pop()

            -- Indicador opcional (intacto)
            if renderSize > 10 and feature.properties and feature.properties.intact and MapRenderer.sinTable[timeIndex3 % 360] > 0 then
                love.graphics.setColor(0, 1, 0, 1 * alpha)
                love.graphics.circle("fill", screenX, screenY, 3)
            end
        else
            -- Fallback previo
            love.graphics.setColor(feature.color[1], feature.color[2], feature.color[3], (feature.color[4] or 1) * alpha)
            love.graphics.push()
            love.graphics.translate(screenX, screenY)
            love.graphics.rotate(time * 0.2)
            love.graphics.rectangle("fill", -renderSize/2, -renderSize/2, renderSize, renderSize)
            if renderSize > 10 then
                love.graphics.setColor(0.5, 1, 0.8, 0.8 * alpha)
                love.graphics.rectangle("line", -renderSize/3, -renderSize/3, renderSize/1.5, renderSize/1.5)
                if feature.properties and feature.properties.intact and MapRenderer.sinTable[timeIndex3 % 360] > 0 then
                    love.graphics.setColor(0, 1, 0, 1 * alpha)
                    love.graphics.circle("fill", 0, 0, 3)
                end
            end
            love.graphics.pop()
        end
    end
    
    love.graphics.pop()
    love.graphics.setColor(r, g, b, a)
end

-- Initialize the renderer
MapRenderer.init()

return MapRenderer