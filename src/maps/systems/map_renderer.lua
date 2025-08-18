-- src/maps/systems/map_renderer.lua
-- Sistema de renderizado tradicional mejorado

local MapRenderer = {}
local CoordinateSystem = require 'src.maps.coordinate_system'
local BiomeSystem = require 'src.maps.biome_system'
local MapConfig = require 'src.maps.config.map_config'
local StarShader = require 'src.shaders.star_shader'

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
end

-- Verificar si un objeto está visible (frustum culling optimizado)
function MapRenderer.isObjectVisible(x, y, size, camera)
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    local relX = x - camera.x
    local relY = y - camera.y
    local screenX = relX * camera.zoom + screenWidth / 2
    local screenY = relY * camera.zoom + screenHeight / 2
    local screenSize = size * camera.zoom
    
    local margin = screenSize + 20
    
    return screenX >= -margin and screenX <= screenWidth + margin and
           screenY >= -margin and screenY <= screenHeight + margin
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
    
    -- Dibujar fondo del bioma dominante
    local backgroundColor = BiomeSystem.getBackgroundColor(dominantBiome)
    love.graphics.setColor(backgroundColor)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setColor(r, g, b, a)
    return maxCount
end

-- Dibujar estrellas mejoradas
function MapRenderer.drawEnhancedStars(chunkInfo, camera, getChunkFunc, starConfig)
    local time = love.timer.getTime()
    local starsRendered = 0
    local maxStarsPerFrame = starConfig.maxStarsPerFrame or 5000
    -- Obtener la posición de la cámara en el espacio de juego
    local cameraX, cameraY = camera.x, camera.y
    local parallaxStrength = starConfig.parallaxStrength or 0.2
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
    local chunkSize = STRIDE * MapConfig.chunk.worldScale
    local startChunkX = math.floor(viewportLeft / chunkSize)
    local endChunkX = math.ceil(viewportRight / chunkSize)
    local startChunkY = math.floor(viewportTop / chunkSize)
    local endChunkY = math.ceil(viewportBottom / chunkSize)
    
    -- Recorrer solo los chunks visibles
    for chunkY = startChunkY, endChunkY do
        for chunkX = startChunkX, endChunkX do
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.objects and chunk.objects.stars then
                -- Coordenadas base del chunk en el mundo
                local chunkBaseX = chunkX * chunkSize
                local chunkBaseY = chunkY * chunkSize
                
                for _, star in ipairs(chunk.objects.stars) do
                    -- Calcular posición absoluta de la estrella en el mundo
                    local worldX = chunkBaseX + star.x * MapConfig.chunk.worldScale
                    local worldY = chunkBaseY + star.y * MapConfig.chunk.worldScale
                    
                    -- Aplicar efecto de paralaje basado en la profundidad
                    if parallaxStrength > 0 then
                        local depth = star.depth or 0.5
                        -- Ajustar el factor de profundidad para un efecto más suave
                        local depthFactor = (1.0 - depth) * 1.5
                        
                        -- Calcular la posición relativa al jugador
                        local relX = worldX - playerX
                        local relY = worldY - playerY
                        
                        -- Aplicar el efecto de paralaje basado en la profundidad
                        worldX = playerX + relX * (1 + depthFactor * parallaxStrength)
                        worldY = playerY + relY * (1 + depthFactor * parallaxStrength)
                    end
                    
                    -- Verificar si la estrella está dentro del área visible + margen
                    if worldX >= viewportLeft and worldX <= viewportRight and
                       worldY >= viewportTop and worldY <= viewportBottom then
                        
                        -- Convertir a coordenadas de pantalla
                        local screenX, screenY = camera:worldToScreen(worldX, worldY)
                        -- Ajustar el tamaño basado en la profundidad y zoom
                        local depth = star.depth or 0.5
                        local baseSize = math.max(0.5, star.size or 1)
                        -- Ajuste del tamaño según la profundidad (estrellas más lejanas más pequeñas)
                        local sizeMultiplier = 0.3 + depth * 0.7  -- 0.3 a 1.0 basado en profundidad
                        local starSize = baseSize * 2.0 * (camera.zoom or 1.0) * sizeMultiplier
                        
                        -- Verificar visibilidad en pantalla
                        if screenX + starSize >= -margin and screenX - starSize <= screenWidth + margin and
                           screenY + starSize >= -margin and screenY - starSize <= screenHeight + margin then
                            
                            -- Clampear dentro del margen extendido (para evitar NaN raros en shaders)
                            screenX = math.max(-margin, math.min(screenWidth + margin, screenX))
                            screenY = math.max(-margin, math.min(screenHeight + margin, screenY))
                            
                            visibleStars[star.type] = visibleStars[star.type] or {}
                            table.insert(visibleStars[star.type], {
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
    
    -- Renderizado por capas (de atrás hacia adelante para el orden de dibujado correcto)
    for layer = 1, 6 do
        if visibleStars[layer] then
            local layerStars = visibleStars[layer]
            local layerCount = #layerStars
            
            -- Ordenar estrellas por profundidad (más lejanas primero)
            table.sort(layerStars, function(a, b) 
                return (a.star.depth or 0.5) > (b.star.depth or 0.5)
            end)
            
            for i = 1, layerCount do
                if starsRendered >= maxStarsPerFrame then 
                    break 
                end
                
                local starInfo = layerStars[i]
                if starInfo then
                    -- Asegurar que las coordenadas sean válidas
                    if starInfo.screenX and starInfo.screenY then
                        MapRenderer.drawAdvancedStar(
                            starInfo.star,
                            starInfo.screenX,
                            starInfo.screenY,
                            time,
                            starConfig,
                            starInfo.camera or camera
                        )
                        starsRendered = starsRendered + 1
                    end
                end
            end
        end
    end
    
    return starsRendered, totalStars
end



-- Dibujar estrella individual con efectos avanzados
-- Ahora usa screenX y screenY que ya están en coordenadas de pantalla
function MapRenderer.drawAdvancedStar(star, screenX, screenY, time, starConfig, camera)
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
    local size = star.size * (camera and camera.zoom or 1.0)  -- Ajustar tamaño según el zoom

    -- Si hay efectos mejorados y shader disponible, usar GPU shader para estrellas
    if starConfig.enhancedEffects and StarShader and StarShader.getShader and StarShader.getShader() then
        -- Usar coordenadas de pantalla directamente
        local adjustedSize = size * 0.8  -- Ajuste de tamaño para el shader
        
        -- IMPORTANTE: dibujar en espacio de pantalla (sin la transformación de cámara)
        love.graphics.push()
        love.graphics.origin()
        StarShader.drawStar(screenX, screenY, adjustedSize, color, brightness, twinkleIntensity, starType)
        love.graphics.pop()
        
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
        local pulse = 0.8 + 0.4 * MapRenderer.sinTable[pulseIndex]
        
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
    
    for chunkY = chunkInfo.startY, chunkInfo.endY do
        for chunkX = chunkInfo.startX, chunkInfo.endX do
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.objects and chunk.objects.nebulae then
                local chunkBaseX = chunkX * STRIDE * MapConfig.chunk.worldScale
                local chunkBaseY = chunkY * STRIDE * MapConfig.chunk.worldScale
                
                for _, nebula in ipairs(chunk.objects.nebulae) do
                    local worldX = chunkBaseX + nebula.x * MapConfig.chunk.worldScale
                    local worldY = chunkBaseY + nebula.y * MapConfig.chunk.worldScale
                    
                    if MapRenderer.isObjectVisible(worldX, worldY, nebula.size * 2, camera) then
                        MapRenderer.drawNebula(nebula, worldX, worldY, time)
                        rendered = rendered + 1
                    end
                end
            end
        end
    end
    
    return rendered
end

-- Dibujar nebulosa individual
function MapRenderer.drawNebula(nebula, worldX, worldY, time)
    local r, g, b, a = love.graphics.getColor()
    
    local timeIndex = math.floor((time * 0.8 * 57.3) % 360)
    local pulse = 0.9 + 0.1 * MapRenderer.sinTable[timeIndex]
    local currentSize = nebula.size * pulse
    
    love.graphics.setColor(nebula.color[1], nebula.color[2], nebula.color[3], nebula.color[4] * nebula.intensity)
    
    if currentSize > 80 then
        love.graphics.circle("fill", worldX, worldY, currentSize, 16)
    else
        love.graphics.circle("fill", worldX, worldY, currentSize, 12)
    end
    
    love.graphics.setColor(r, g, b, a)
end

-- Dibujar asteroides
function MapRenderer.drawAsteroids(chunkInfo, camera, getChunkFunc)
    local rendered = 0
    
    for chunkY = chunkInfo.startY, chunkInfo.endY do
        for chunkX = chunkInfo.startX, chunkInfo.endX do
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.tiles then
                -- Base de tiles (sin espaciado) para índices enteros/semillas
                local chunkBaseTileX = chunkX * MapConfig.chunk.size
                local chunkBaseTileY = chunkY * MapConfig.chunk.size
                -- Base de mundo (con espaciado) para posiciones (en unidades de mundo)
                local chunkBaseWorldX = chunkX * STRIDE * MapConfig.chunk.worldScale
                local chunkBaseWorldY = chunkY * STRIDE * MapConfig.chunk.worldScale

                for y = 0, MapConfig.chunk.size - 1 do
                    for x = 0, MapConfig.chunk.size - 1 do
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
                                MapRenderer.drawAsteroidLOD(tileType, worldX, worldY, globalTileX, globalTileY, lod)
                                rendered = rendered + 1
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
function MapRenderer.drawAsteroidLOD(asteroidType, worldX, worldY, globalX, globalY, lod)
    local seed = globalX * 1000 + globalY
    math.randomseed(seed)
    
    local sizes = {8, 15, 25}
    local baseSize = sizes[asteroidType] * MapConfig.chunk.worldScale
    local colorIndex = (globalX + globalY) % #MapConfig.colors.asteroids + 1
    local color = MapConfig.colors.asteroids[colorIndex]
    
    local sizeVariation = 0.8 + math.random() * 0.4
    local finalSize = baseSize * sizeVariation
    
    local segments = lod >= 2 and 6 or (lod >= 1 and 8 or 12)
    
    if lod >= 2 then
        love.graphics.setColor(color[1], color[2], color[3], 0.8)
        love.graphics.circle("fill", worldX, worldY, finalSize, segments)
        return
    end
    
    if lod >= 1 then
        love.graphics.setColor(0.1, 0.1, 0.1, 0.3)
        love.graphics.circle("fill", worldX + 2, worldY + 2, finalSize + 1, segments)
        
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.circle("fill", worldX, worldY, finalSize, segments)
        return
    end
    
    -- LOD 0: Detalle completo
    love.graphics.setColor(0.1, 0.1, 0.1, 0.5)
    love.graphics.circle("fill", worldX + 2, worldY + 2, finalSize + 1, segments)
    
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.circle("fill", worldX, worldY, finalSize, segments)
    
    if asteroidType >= MapConfig.ObjectType.ASTEROID_MEDIUM then
        love.graphics.setColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, 1)
        
        local numDetails = math.min(math.random(2, 4), math.floor(finalSize / 5))
        
        for i = 1, numDetails do
            local angleIndex = math.floor((i / numDetails) * 360 + math.random() * 30) % 360 + 1
            local detailDistance = finalSize * 0.3 * math.random()
            local detailX = worldX + MapRenderer.cosTable[angleIndex] * detailDistance
            local detailY = worldY + MapRenderer.sinTable[angleIndex] * detailDistance
            local detailSize = finalSize * 0.2 * math.random()
            
            love.graphics.circle("fill", detailX, detailY, detailSize, 6)
        end
    end
    
    if asteroidType == MapConfig.ObjectType.ASTEROID_LARGE then
        love.graphics.setColor(color[1] * 1.3, color[2] * 1.3, color[3] * 1.3, 0.7)
        love.graphics.circle("fill", worldX - finalSize * 0.3, worldY - finalSize * 0.3, finalSize * 0.2, 6)
    end
end

-- Dibujar objetos especiales
function MapRenderer.drawSpecialObjects(chunkInfo, camera, getChunkFunc)
    local rendered = 0
    
    for chunkY = chunkInfo.startY, chunkInfo.endY do
        for chunkX = chunkInfo.startX, chunkInfo.endX do
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.specialObjects then
                local chunkBaseX = chunkX * STRIDE * MapConfig.chunk.worldScale
                local chunkBaseY = chunkY * STRIDE * MapConfig.chunk.worldScale
                
                for _, obj in ipairs(chunk.specialObjects) do
                    if obj.type == MapConfig.ObjectType.STATION or obj.type == MapConfig.ObjectType.WORMHOLE then
                        local worldX = chunkBaseX + obj.x * MapConfig.chunk.worldScale
                        local worldY = chunkBaseY + obj.y * MapConfig.chunk.worldScale
                        
                        if MapRenderer.isObjectVisible(worldX, worldY, obj.size * 2, camera) then
                            if obj.type == MapConfig.ObjectType.STATION then
                                MapRenderer.drawStation(obj, worldX, worldY)
                            elseif obj.type == MapConfig.ObjectType.WORMHOLE then
                                MapRenderer.drawWormhole(obj, worldX, worldY)
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

-- Dibujar estación
function MapRenderer.drawStation(station, worldX, worldY)
    love.graphics.push()
    love.graphics.translate(worldX, worldY)
    
    local rotation = station.rotation + love.timer.getTime() * 0.1
    love.graphics.rotate(rotation)
    
    local segments = station.size < 20 and 8 or (station.size > 40 and 16 or 12)
    
    love.graphics.setColor(0.1, 0.1, 0.1, 0.3)
    love.graphics.circle("fill", 2, 2, station.size * 1.1, segments)
    
    love.graphics.setColor(0.6, 0.6, 0.8, 1)
    love.graphics.circle("fill", 0, 0, station.size, segments)
    
    if station.size > 15 then
        love.graphics.setColor(0.3, 0.5, 0.8, 1)
        love.graphics.circle("line", 0, 0, station.size * 0.8, segments)
        love.graphics.circle("line", 0, 0, station.size * 0.6, segments)
    end
    
    love.graphics.setColor(0.2, 0.3, 0.7, 0.8)
    love.graphics.rectangle("fill", -station.size * 1.5, -station.size * 0.2, station.size * 0.4, station.size * 0.4)
    love.graphics.rectangle("fill", station.size * 1.1, -station.size * 0.2, station.size * 0.4, station.size * 0.4)
    
    if math.floor(love.timer.getTime()) % 2 == 0 then
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.circle("fill", station.size * 0.7, 0, 2, 4)
        love.graphics.circle("fill", -station.size * 0.7, 0, 2, 4)
    end
    
    love.graphics.pop()
end

-- Dibujar wormhole
function MapRenderer.drawWormhole(wormhole, worldX, worldY)
    local time = love.timer.getTime()
    
    local timeIndex = math.floor((time * 2 + wormhole.pulsePhase) * 57.29) % 360
    local pulse = 0.8 + 0.2 * MapRenderer.sinTable[timeIndex]
    local size = wormhole.size * pulse
    
    local segments = size < 20 and 8 or (size > 40 and 16 or 12)
    
    love.graphics.setColor(0.1, 0.1, 0.4, 0.8)
    love.graphics.circle("fill", worldX, worldY, size * 1.5, segments)
    
    love.graphics.setColor(0.3, 0.1, 0.8, 0.9)
    love.graphics.circle("fill", worldX, worldY, size, segments)
    
    love.graphics.setColor(0.6, 0.3, 1, 0.7)
    love.graphics.circle("fill", worldX, worldY, size * 0.6, segments)
    
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", worldX, worldY, size * 0.2, 8)
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
    
    local time = love.timer.getTime()
    local timeIndex2 = math.floor((time * 2 * 57.3) % 360) + 1
    local timeIndex3 = math.floor((time * 3 * 57.3) % 360) + 1
    
    if feature.type == "dense_nebula" then
        love.graphics.setColor(feature.color)
        love.graphics.circle("fill", screenX, screenY, renderSize, 24)
        
        local pulse = 0.8 + 0.2 * MapRenderer.sinTable[timeIndex2]
        love.graphics.setColor(feature.color[1], feature.color[2], feature.color[3], 
                              feature.color[4] * 0.3 * pulse)
        love.graphics.circle("fill", screenX, screenY, renderSize * 1.3, 16)
        
    elseif feature.type == "mega_asteroid" then
        love.graphics.setColor(feature.color)
        love.graphics.circle("fill", screenX, screenY, renderSize, 16)
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.circle("fill", screenX + 3, screenY + 3, renderSize, 16)
        
    elseif feature.type == "gravity_well" then
        if renderSize > 5 then
            love.graphics.setColor(feature.color)
            for i = 1, 3 do
                local radius = renderSize * i * 0.8
                local alpha = feature.color[4] / i
                love.graphics.setColor(feature.color[1], feature.color[2], feature.color[3], alpha)
                love.graphics.circle("line", screenX, screenY, radius, 16)
            end
        else
            love.graphics.setColor(feature.color)
            love.graphics.circle("fill", screenX, screenY, renderSize, 12)
        end
        
    elseif feature.type == "dead_star" then
        love.graphics.setColor(feature.color)
        love.graphics.circle("fill", screenX, screenY, renderSize, 12)
        
        local pulse = 0.5 + 0.5 * MapRenderer.sinTable[timeIndex3]
        love.graphics.setColor(1, 0.5, 0, 0.3 * pulse)
        love.graphics.circle("fill", screenX, screenY, renderSize * 3, 16)
        
    elseif feature.type == "ancient_station" then
        love.graphics.setColor(feature.color)
        love.graphics.push()
        love.graphics.translate(screenX, screenY)
        love.graphics.rotate(time * 0.2)
        
        love.graphics.rectangle("fill", -renderSize/2, -renderSize/2, renderSize, renderSize)
        
        if renderSize > 10 then
            love.graphics.setColor(0.5, 1, 0.8, 0.8)
            love.graphics.rectangle("line", -renderSize/3, -renderSize/3, renderSize/1.5, renderSize/1.5)
            
            if feature.properties and feature.properties.intact and MapRenderer.sinTable[timeIndex3 % 360] > 0 then
                love.graphics.setColor(0, 1, 0, 1)
                love.graphics.circle("fill", 0, 0, 3)
            end
        end
        
        love.graphics.pop()
    end
    
    love.graphics.setColor(r, g, b, a)
end

-- Initialize the renderer
MapRenderer.init()

return MapRenderer