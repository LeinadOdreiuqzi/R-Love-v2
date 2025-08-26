-- src/maps/systems/map_renderer.lua
-- Sistema de renderizado tradicional mejorado

local MapRenderer = {}
local CoordinateSystem = require 'src.maps.coordinate_system'
local BiomeSystem = require 'src.maps.biome_system'
local MapConfig = require 'src.maps.config.map_config'
local StarShader = require 'src.shaders.star_shader'
local ShaderManager = require 'src.shaders.shader_manager'
local NebulaRenderer = require 'src.maps.systems.nebula_renderer'
local StarfieldInstanced = require 'src.shaders.starfield_instanced'

-- Variables de estado para optimización
MapRenderer.sinTable = {}
MapRenderer.cosTable = {}

-- Stride unificado (tamaño del chunk en píxeles + espaciado)
local SIZE_PIXELS = MapConfig.chunk.size * MapConfig.chunk.tileSize
local STRIDE = SIZE_PIXELS + (MapConfig.chunk.spacing or 0)

-- Inicializar tablas de optimización
function MapRenderer.init(worldSeed)
    for i = 0, 359 do
        local rad = math.rad(i)
        MapRenderer.sinTable[i] = math.sin(rad)
        MapRenderer.cosTable[i] = math.cos(rad)
    end
    -- Inicializar shader de estrellas
    if StarShader and StarShader.init then StarShader.init() end
    -- Inicializar ShaderManager para disponer de shaders e imágenes base
    if ShaderManager and ShaderManager.init then ShaderManager.init() end

    -- NUEVO: estado y assets para microestrellas
    -- Reiniciar completamente el estado para evitar cache inconsistente tras cambiar la seed
    MapRenderer._microStars = { initialized = false }
    local ms = MapRenderer._microStars
    ms.config = {
        -- Se muestra por debajo de este zoom (alejado). Si zoom > showBelowZoom => oculto.
        showBelowZoom = (MapConfig.stars and MapConfig.stars.microStars and MapConfig.stars.microStars.showBelowZoom) or 0.95,
        -- Densidad en estrellas por píxel de pantalla
        densityPerPixel = (MapConfig.stars and MapConfig.stars.microStars and MapConfig.stars.microStars.densityPerPixel) or 0.00012,
        -- Límite duro de microestrellas
        maxCount = (MapConfig.stars and MapConfig.stars.microStars and MapConfig.stars.microStars.maxCount) or 600,
        -- Rango de tamaño (en píxeles en pantalla)
        sizeMin = (MapConfig.stars and MapConfig.stars.microStars and MapConfig.stars.microStars.sizeMin) or 0.8,
        sizeMax = (MapConfig.stars and MapConfig.stars.microStars and MapConfig.stars.microStars.sizeMax) or 1.8,
        -- Alpha base para fade (aplicado globalmente)
        alphaMin = (MapConfig.stars and MapConfig.stars.microStars and MapConfig.stars.microStars.alphaMin) or 0.35,
        alphaMax = (MapConfig.stars and MapConfig.stars.microStars and MapConfig.stars.microStars.alphaMax) or 0.8,
        -- Parallax sutil para microestrellas
        parallaxScale = (MapConfig.stars and MapConfig.stars.microStars and MapConfig.stars.microStars.parallaxScale) or 0.02
    }
    -- Guardar seed de generación para microestrellas
    ms.generationSeed = tonumber(worldSeed) or 0

    -- Imagen base: círculo del ShaderManager o fallback a 1x1
    local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle") or nil
    if not img then
        local id = love.image.newImageData(1, 1)
        id:setPixel(0, 0, 1, 1, 1, 1)
        img = love.graphics.newImage(id)
    end
    -- Mantener el filtro del ShaderManager (suele ser linear). Si es fallback 1x1, usar linear para suavizar.
    if img and img.getWidth and img:getWidth() == 1 and img.getHeight and img:getHeight() == 1 then
        if img.setFilter then img:setFilter("linear", "linear") end
    end

    ms.img = img
    ms.batch = love.graphics.newSpriteBatch(ms.img, ms.config.maxCount)
    ms.initialized = true
    -- Marcar como sucio para reconstruir en el próximo draw
    ms.dirty = true
    ms.lastW, ms.lastH, ms.lastCount = nil, nil, nil
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

    -- Encontrar bioma más común y acumular color mezclado por chunks visibles
    local biomeCounts = {}
    local sumR, sumG, sumB, sumA, sumCount = 0, 0, 0, 0, 0
    -- Acumulador solo de no Deep Space (para asegurar visibilidad del fondo)
    local ndSumR, ndSumG, ndSumB, ndSumA, ndCount = 0, 0, 0, 0, 0

    for i = 1, #chunkInfo do
        local info = chunkInfo[i]
        local chunk = getChunkFunc(info.cx, info.cy)
        if chunk and chunk.biome then
            local biomeType = chunk.biome.type
            biomeCounts[biomeType] = (biomeCounts[biomeType] or 0) + 1

            -- Considerar color mezclado por chunk si existe biomeBlend
            if chunk.biomeBlend and BiomeSystem.getBackgroundColorBlended then
                local c = BiomeSystem.getBackgroundColorBlended(chunk.biomeBlend)
                if c then
                    sumR, sumG, sumB, sumA = sumR + (c[1] or 0), sumG + (c[2] or 0), sumB + (c[3] or 0), sumA + (c[4] or 1)
                    if biomeType ~= BiomeSystem.BiomeType.DEEP_SPACE then
                        ndSumR, ndSumG, ndSumB, ndSumA = ndSumR + (c[1] or 0), ndSumG + (c[2] or 0), ndSumB + (c[3] or 0), ndSumA + (c[4] or 1)
                        ndCount = ndCount + 1
                    end
                end
            else
                local c = BiomeSystem.getBackgroundColor(biomeType)
                if c then
                    sumR, sumG, sumB, sumA = sumR + (c[1] or 0), sumG + (c[2] or 0), sumB + (c[3] or 0), sumA + (c[4] or 1)
                    if biomeType ~= BiomeSystem.BiomeType.DEEP_SPACE then
                        ndSumR, ndSumG, ndSumB, ndSumA = ndSumR + (c[1] or 0), ndSumG + (c[2] or 0), ndSumB + (c[3] or 0), ndSumA + (c[4] or 1)
                        ndCount = ndCount + 1
                    end
                end
            end
            sumCount = sumCount + 1
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

    -- Dibujar fondo
    love.graphics.push()
    love.graphics.origin()

    -- Si hay biomas no Deep Space visibles, usar su promedio SIEMPRE (aunque Deep Space sea dominante)
    if ndCount > 0 then
        local backgroundColor = { ndSumR / ndCount, ndSumG / ndCount, ndSumB / ndCount, (ndSumA / ndCount) }
        local cr = backgroundColor[1] or 0
        local cg = backgroundColor[2] or 0
        local cb = backgroundColor[3] or 0
        local ca = backgroundColor[4] or 1
        love.graphics.setColor(cr, cg, cb, ca)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    else
        -- Solo Deep Space visible: usar velo sutil si es realmente dominante
        local totalChunks = math.max(1, sumCount)
        local deepSpaceRatio = (biomeCounts[BiomeSystem.BiomeType.DEEP_SPACE] or 0) / totalChunks

        if deepSpaceRatio > 0.7 then
            love.graphics.setColor(0.02, 0.02, 0.05, 0.3)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        end
    end

    love.graphics.pop()
    love.graphics.setColor(r, g, b, a)
    return (sumCount > 0) and sumCount or 0
end

-- Dibujar estrellas con efectos mejorados
function MapRenderer.drawEnhancedStars(chunkInfo, camera, getChunkFunc, starConfig)
    local time = love.timer.getTime()
    local starsRendered = 0
    -- Limitar por configuración (sin tope duro adicional)
    local maxStarsPerFrame = starConfig.maxStarsPerFrame or 5000
    -- Obtener la posición de la cámara en el espacio de juego
    local cameraX, cameraY = camera.x, camera.y
    local parallaxStrength = starConfig.parallaxStrength or 0.2
    -- Config profunda (3 capas) - usar la clave correcta 'deepLayers'
    local deepLayers = (starConfig and starConfig.deepLayers) or {
        { threshold = 0.90,  parallaxScale = 0.60, sizeScale = 0.55 },
        { threshold = 0.945, parallaxScale = 0.35, sizeScale = 0.40 },
        { threshold = 0.980, parallaxScale = 0.15, sizeScale = 0.30 }
    }
    -- NUEVO: escala global de tamaño para todas las estrellas
    local globalSizeScale = (starConfig and starConfig.sizeScaleGlobal) or 1.0
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
    -- Precalcular proyección en pantalla de nebulosas visibles para atenuar estrellas detrás
    local function clamp(x, a, b) return (x < a) and a or ((x > b) and b or x) end
    local nebulaCircles = {}
    do
        local zoom = camera and camera.zoom or 1
        -- Reutilizamos STRIDE y worldScale como en NebulaRenderer
        for cy = startChunkY, endChunkY do
            for cx = startChunkX, endChunkX do
                local chunk = getChunkFunc(cx, cy)
                if chunk and chunk.objects and chunk.objects.nebulae and #chunk.objects.nebulae > 0 then
                    local baseWorldX = cx * STRIDE * MapConfig.chunk.worldScale
                    local baseWorldY = cy * STRIDE * MapConfig.chunk.worldScale
                    for i = 1, #chunk.objects.nebulae do
                        local n = chunk.objects.nebulae[i]
                        local wx = baseWorldX + n.x * MapConfig.chunk.worldScale
                        local wy = baseWorldY + n.y * MapConfig.chunk.worldScale
                        local par = clamp(n.parallax or 0.85, 0.0, 1.0)
                        -- worldToScreenParallax inline
                        local px = camera.x + (wx - camera.x) * par
                        local py = camera.y + (wy - camera.y) * par
                        local sx, sy = camera:worldToScreen(px, py)
                        local radiusPx = (n.size or 140) * zoom
                        nebulaCircles[#nebulaCircles + 1] = {
                            sx = sx, sy = sy, radius = radiusPx, parallax = par,
                            intensity = n.intensity or 0.6
                        }
                    end
                end
            end
        end
    end
    -- Calcula factor de atenuación [0.35..1] según proximidad y si la estrella está “detrás”
    local function computeNebulaDimmingFactor(starScreenX, starScreenY, starDepth)
        if #nebulaCircles == 0 then return 1.0 end
        -- Aproximación de parallax de estrella (profundidad -> menos parallax cuanto más “detrás”)
        local depth = clamp(starDepth or 0.5, 0.0, 1.0)
        local starPar = 0.60 + (1.0 - depth) * 0.40  -- ~[0.60..1.0]
        local best = 0.0
        for i = 1, #nebulaCircles do
            local n = nebulaCircles[i]
            -- Detrás si la estrella tiene parallax menor que la nebulosa (con margen)
            if starPar < (n.parallax - 0.01) then
                local dx = starScreenX - n.sx
                local dy = starScreenY - n.sy
                local dist = math.sqrt(dx * dx + dy * dy)
                local norm = dist / (n.radius * 1.12)  -- leve colchón
                if norm <= 1.25 then
                    local coverage = math.max(0.0, 1.0 - norm) -- 1 en centro, 0 fuera
                    local parallaxDelta = clamp((n.parallax - starPar) / 0.5, 0.0, 1.0)
                    -- Ponderar por delta de parallax (más detrás => más atenuación)
                    local influence = coverage * parallaxDelta
                    if influence > best then best = influence end
                end
            end
        end
        if best <= 0.0 then return 1.0 end
        -- Atenuar hasta 75% según influencia, con un mínimo del 35% de brillo
        local dim = 1.0 - best * 0.75
        return clamp(dim, 0.35, 1.0)
    end
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
                        if deepLayers[3] and star.depth >= deepLayers[3].threshold then
                            layerId = -3
                            localParallaxStrength = parallaxStrength * (deepLayers[3].parallaxScale or 0.15)
                            sizeScaleExtra = deepLayers[3].sizeScale or 0.30
                        elseif deepLayers[2] and star.depth >= deepLayers[2].threshold then
                            layerId = -2
                            localParallaxStrength = parallaxStrength * (deepLayers[2].parallaxScale or 0.35)
                            sizeScaleExtra = deepLayers[2].sizeScale or 0.40
                        elseif deepLayers[1] and star.depth >= deepLayers[1].threshold then
                            layerId = -1
                            localParallaxStrength = parallaxStrength * (deepLayers[1].parallaxScale or 0.60)
                            sizeScaleExtra = deepLayers[1].sizeScale or 0.55
                        end
                    end

                    -- Aplicar efecto de paralaje
                    if parallaxStrength > 0 then
                        local depth = star.depth or 0.5
                        local depthFactor = (1.0 - depth) * 1.5
                        local relX = worldX - playerX
                        local relY = worldY - playerY
                        worldX = playerX + relX * (1 + depthFactor * localParallaxStrength)
                        worldY = playerY + relY * (1 + depthFactor * localParallaxStrength)
                    end

                    if worldX >= viewportLeft and worldX <= viewportRight and
                       worldY >= viewportTop and worldY <= viewportBottom then
                        local screenX, screenY = camera:worldToScreen(worldX, worldY)
                        local depth = star.depth or 0.5
                        local baseSize = math.max(0.5, star.size or 1)
                        local sizeMultiplier = 0.3 + (1.0 - depth) * 0.7
                        local starSize = baseSize * 2.0 * (camera.zoom or 1.0) * sizeMultiplier * (sizeScaleExtra or 1.0) * (globalSizeScale or 1.0)

                        if screenX + starSize >= -margin and screenX - starSize <= screenWidth + margin and
                           screenY + starSize >= -margin and screenY - starSize <= screenHeight + margin then
                            screenX = math.max(-margin, math.min(screenWidth + margin, screenX))
                            screenY = math.max(-margin, math.min(screenHeight + margin, screenY))

                            if sizeScaleExtra ~= 1.0 then
                                star._sizeScaleExtra = sizeScaleExtra
                            else
                                star._sizeScaleExtra = nil
                            end
                            
                            -- A: evitar table.insert, usar asignación indexada
                            local list = visibleStars[layerId]
                            if not list then
                                list = visibleStars[layerId] or {}
                                visibleStars[layerId] = list
                            end
                            local idx = #list + 1
                            list[idx] = {
                                star = star,
                                screenX = screenX,
                                screenY = screenY,
                                camera = camera,
                                dim = computeNebulaDimmingFactor(screenX, screenY, depth)
                            }
                        end
                    end
                end
            end
        end
    end

    -- Preparar espacio de pantalla y batching (una sola vez) y activar shader
    -- Preparar espacio de pantalla y batching (una sola vez)
    love.graphics.push()
    love.graphics.origin()
    local usingStarShader = (starConfig.enhancedEffects and StarShader and StarShader.getShader and StarShader.getShader())
    if usingStarShader and StarShader.begin then
        StarShader.begin()
    end

    -- Helper: cuantización de color (B: bins de color)
    local function quantizeColor(r, g, b, a)
        local levels = 16
        local rq = math.floor(math.max(0, math.min(1, r)) * (levels - 1) + 0.5)
        local gq = math.floor(math.max(0, math.min(1, g)) * (levels - 1) + 0.5)
        local bq = math.floor(math.max(0, math.min(1, b)) * (levels - 1) + 0.5)
        local aq = math.floor(math.max(0, math.min(1, a or 1)) * (levels - 1) + 0.5)
        return rq .. "|" .. gq .. "|" .. bq .. "|" .. aq
    end

    -- Helper: dibujar una capa agrupando por tipo (y por color cuando no hay shader)
    local function drawLayerGroupedByType(layerStars)
        -- Ordenar por profundidad para mantener estética
        table.sort(layerStars, function(a, b)
            return (a.star.depth or 0.5) > (b.star.depth or 0.5)
        end)

        -- A: pooling de agrupación por tipo
        local starsByType = MapRenderer._tmpStarsByType or {}
        MapRenderer._tmpStarsByType = starsByType
        -- limpiar listas previas reusables
        for t, lst in pairs(starsByType) do
            if type(lst) == "table" then
                for i = 1, #lst do lst[i] = nil end
            end
            -- mantener la clave para reutilizar capacidad
        end

        -- Agrupar por tipo evitando table.insert
        for i = 1, #layerStars do
            local info = layerStars[i]
            local t = info.star.type or 1
            local list = starsByType[t]
            if not list then
                list = {}
                starsByType[t] = list
            end
            local idx = #list + 1
            list[idx] = info
        end

        -- Iterar tipos en orden determinista
        local typeKeys = {}
        for t, _ in pairs(starsByType) do
            typeKeys[#typeKeys + 1] = t
        end
        table.sort(typeKeys)

        for _, t in ipairs(typeKeys) do
            local list = starsByType[t]
            if list and #list > 0 then
                if usingStarShader and StarShader.setType then
                    StarShader.setType(t)
                end

                if usingStarShader then
                    -- Ruta con shader (como antes)
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
                            starInfo.star._sizeScaleExtra,        -- sizeScaleExtra
                            true,
                            starInfo.dim or 1.0 -- uniformsPreset: ya fijados por tipo
                        )
                        starsRendered = starsRendered + 1
                    end
                else
                    -- B: Ruta sin shader: agrupar por color bin y minimizar setColor
                    if t == 4 then
                        -- Tipo complejo: mantener ruta por estrella para preservar estética
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
                                true
                            )
                            starsRendered = starsRendered + 1
                        end
                    else
                        -- Tipos simples: dos fases (glow y cuerpo principal), agrupando por color bin
                        local binsGlow = MapRenderer._tmpColorBinsGlow or {}
                        MapRenderer._tmpColorBinsGlow = binsGlow
                        for k, arr in pairs(binsGlow) do
                            if type(arr) == "table" then
                                for i2 = 1, #arr do arr[i2] = nil end
                            end
                            binsGlow[k] = nil
                        end

                        local binsMain = MapRenderer._tmpColorBinsMain or {}
                        MapRenderer._tmpColorBinsMain = binsMain
                        for k, arr in pairs(binsMain) do
                            if type(arr) == "table" then
                                for i2 = 1, #arr do arr[i2] = nil end
                            end
                            binsMain[k] = nil
                        end

                        -- Construir bins
                        for i = 1, #list do
                            local info = list[i]
                            local star = info.star
                            local color = star.color or { 1, 1, 1, 1 } or { 1, 1, 1, 1 }
                            local dim = info.dim or 1.0
                            local brightness = (star.brightness or 1) * dim
                            local depth = star.depth or 0.5
                            local baseSize = math.max(0.5, star.size or 1)
                            local mult = 0.3 + (1.0 - depth) * 0.7
                            local z = (camera.zoom or 1.0)
                            local sizeScale = (star._sizeScaleExtra or 1.0)
                            local size = baseSize * 2.0 * z * mult * sizeScale * dim

                            -- Glow (solo si aplica: en tipo 1 y otros básicos cuando brightness alto)
                            if t == 1 and brightness > 0.7 then
                                local gr = color[1] * brightness * 0.3
                                local gg = color[2] * brightness * 0.3
                                local gb = color[3] * brightness * 0.3
                                local ga = 0.2
                                local keyG = quantizeColor(gr, gg, gb, ga)
                                local arr = binsGlow[keyG]
                                if not arr then
                                    arr = {}
                                    binsGlow[keyG] = arr
                                end
                                local idxG = #arr + 1
                                arr[idxG] = { x = info.screenX, y = info.screenY, radius = size * 2, segs = 8 }
                            elseif t ~= 1 then
                                -- Tipos básicos (no 4, no 1): siempre dibujan un halo
                                local gr = color[1] * brightness * 0.3
                                local gg = color[2] * brightness * 0.3
                                local gb = color[3] * brightness * 0.3
                                local ga = 0.3
                                local keyG = quantizeColor(gr, gg, gb, ga)
                                local arr = binsGlow[keyG]
                                if not arr then
                                    arr = {}
                                    binsGlow[keyG] = arr
                                end
                                local idxG = #arr + 1
                                arr[idxG] = { x = info.screenX, y = info.screenY, radius = size * 2, segs = 12 }
                            end

                            -- Cuerpo principal
                            local mr = color[1] * brightness
                            local mg = color[2] * brightness
                            local mb = color[3] * brightness
                            local ma = (color[4] or 1.0)
                            local keyM = quantizeColor(mr, mg, mb, ma)
                            local arrM = binsMain[keyM]
                            if not arrM then
                                arrM = {}
                                binsMain[keyM] = arrM
                            end
                            local idxM = #arrM + 1
                            arrM[idxM] = { x = info.screenX, y = info.screenY, radius = size, segs = 6 }
                        end

                        -- Dibujar glows por bin (no incrementa starsRendered)
                        for key, arr in pairs(binsGlow) do
                            if #arr > 0 then
                                -- Restaurar color desde la clave si se desea, pero basta con fijar color una vez (ya cuantizado)
                                local rStr, gStr, bStr, aStr = key:match("^(%d+)|(%d+)|(%d+)|(%d+)$")
                                local levels = 16
                                local r = (tonumber(rStr) or 0) / (levels - 1)
                                local g = (tonumber(gStr) or 0) / (levels - 1)
                                local b = (tonumber(bStr) or 0) / (levels - 1)
                                local a = (tonumber(aStr) or 0) / (levels - 1)
                                love.graphics.setColor(r, g, b, a)
                                for i = 1, #arr do
                                    local it = arr[i]
                                    love.graphics.circle("fill", it.x, it.y, it.radius, it.segs)
                                end
                            end
                        end

                        -- Dibujar cuerpo principal por bin (incrementa starsRendered)
                        for key, arr in pairs(binsMain) do
                            if #arr > 0 then
                                if starsRendered >= maxStarsPerFrame then return end
                                local rStr, gStr, bStr, aStr = key:match("^(%d+)|(%d+)|(%d+)|(%d+)$")
                                local levels = 16
                                local r = (tonumber(rStr) or 0) / (levels - 1)
                                local g = (tonumber(gStr) or 0) / (levels - 1)
                                local b = (tonumber(bStr) or 0) / (levels - 1)
                                local a = (tonumber(aStr) or 0) / (levels - 1)
                                love.graphics.setColor(r, g, b, a)
                                for i = 1, #arr do
                                    if starsRendered >= maxStarsPerFrame then break end
                                    local it = arr[i]
                                    love.graphics.circle("fill", it.x, it.y, it.radius, it.segs)
                                    starsRendered = starsRendered + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Dibujar capas profundas primero
    for _, layer in ipairs({-3, -2, -1}) do
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
function MapRenderer.drawAdvancedStar(star, screenX, screenY, time, starConfig, camera, inScreenSpace, sizeScaleExtra, uniformsPreset, nebulaDim)
    -- Evitar asignaciones innecesarias y reducir cambios de estado
    local starType = star.type or 1

    -- Calcular parpadeo individual (compartido para shader y fallback)
    local twinklePhase = time * (star.twinkleSpeed or 1) + (star.twinkle or 0)
    local angleIndex = math.floor(twinklePhase * 57.29) % 360
    local twinkleIntensity = 0.6 + 0.4 * MapRenderer.sinTable[angleIndex]
    local brightness = (star.brightness or 1)

    -- NUEVO: aplicar factor de atenuación por nebulosa
    nebulaDim = nebulaDim or 1.0
    brightness = brightness * nebulaDim
    twinkleIntensity = twinkleIntensity * nebulaDim

    local color = star.color
    local localSizeScale = sizeScaleExtra or 1.0
    local zoom = (camera and camera.zoom or 1.0)
    -- NUEVO: factor global para todas las estrellas
    local globalSizeScale = (starConfig and starConfig.sizeScaleGlobal) or 1.0
    local size = (star.size * localSizeScale) * zoom * globalSizeScale

    -- NUEVO: usar StarfieldInstanced por índice si hay buffer y el star tiene índice
    if starConfig and starConfig.useInstancedShader and StarfieldInstanced and StarfieldInstanced.getShader and StarfieldInstanced.getShader() then
        local screenRadius = size
        if StarfieldInstanced.setGlobals then
            StarfieldInstanced.setGlobals({
                time = love.timer.getTime(),
                twinkleEnabled = (MapConfig.stars and MapConfig.stars.twinkleEnabled) or true,
                enhancedEffects = (MapConfig.stars and MapConfig.stars.enhancedEffects) or true
            })
        end
        -- Preferir buffer + índice si está disponible
        if StarfieldInstanced.hasStarData and StarfieldInstanced.hasStarData() and star._sfIndex ~= nil then
            -- s ~ 4 * radio_en_pantalla; la escala global se aplica en StarfieldInstanced
            local s = math.max(2, (screenRadius or 8) * 4.0)
            StarfieldInstanced.drawStarQuad(star._sfIndex, screenX, screenY, s)
            return
        end
        -- Fallback: uniforms por estrella (override)
        if StarfieldInstanced.drawStarWithUniforms then
            StarfieldInstanced.drawStarWithUniforms(screenX, screenY, screenRadius, star, starConfig)
            return
        end
    end

    -- Ruta con shader: no cambiar color ni shader aquí, solo dibujar y salir
    if starConfig.enhancedEffects and StarShader and StarShader.getShader then
        local starShader = StarShader.getShader and StarShader.getShader() or nil
        if starShader then
            local adjustedSize = size * 0.8

            if not inScreenSpace then
                love.graphics.push()
                love.graphics.origin()
            end

            local currentShader = love.graphics.getShader and love.graphics.getShader() or nil
            local shaderActive = (currentShader == starShader)

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

            -- No hubo cambios de color; no es necesario restaurar
            return
        end
    end

    -- A partir de aquí, rutas sin shader: cambiar color implica guardar/restaurar
    local r, g, b, a = love.graphics.getColor()

    if not starConfig.enhancedEffects then
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        love.graphics.circle("fill", screenX, screenY, star.size * (camera and camera.zoom or 1.0) * globalSizeScale, 6)
        love.graphics.setColor(r, g, b, a)
        return
    end

    -- Renderizado por tipo de estrella (fallback sin shader)
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
    -- Nueva ruta: delega al sistema de nebulosas GPU (NebulaRenderer)
    if NebulaRenderer then
        -- Avanzar el tiempo del shader una vez por frame
        if type(NebulaRenderer.update) == "function" then
            pcall(NebulaRenderer.update, love.timer.getDelta())
        end
        if type(NebulaRenderer.drawNebulae) == "function" then
            local ok, count = pcall(NebulaRenderer.drawNebulae, chunkInfo, camera, getChunkFunc)
            if ok and type(count) == "number" then
                return count
            end
        end
    end

    -- Fallback: si por alguna razón no está disponible, evita romper la ejecución
    return 0
end

-- Dibujar nebulosa individual
function MapRenderer.drawNebula(nebula, worldX, worldY, time, camera)
    local r, g, b, a = love.graphics.getColor()
    
    local timeIndex = math.floor((time * 0.8 * 57.3) % 360)
    -- Pulso más sutil en el fallback
    local pulse = 1.0 + 0.03 * MapRenderer.sinTable[timeIndex]
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
                            
                            -- Tamaños base y escala desde configuración
                            local baseSizes = (MapConfig.asteroids and MapConfig.asteroids.baseSizes) or {8, 15, 25}
                            local sizeScale = (MapConfig.asteroids and MapConfig.asteroids.sizeScale) or 1.0
                            local size = baseSizes[tileType] * sizeScale * MapConfig.chunk.worldScale * 1.3
                            
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

    -- Tamaño base y escala desde configuración
    local baseSizes = (MapConfig.asteroids and MapConfig.asteroids.baseSizes) or {8, 15, 25}
    local sizeScale = (MapConfig.asteroids and MapConfig.asteroids.sizeScale) or 1.0
    local baseSize = baseSizes[asteroidType] * sizeScale * MapConfig.chunk.worldScale
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
        -- NEW: deterministic shape parameters per asteroid instance
        local function next01Local(st)
            st = (st * 1664525 + 1013904223) % 4294967296
            return st, (st / 4294967296)
        end
        local rSx; local rSy; local rAmp; local rFreq; local rRot
        state, rSx = next01Local(state)
        state, rSy = next01Local(state)
        state, rAmp = next01Local(state)
        state, rFreq = next01Local(state)
        state, rRot = next01Local(state)

        local squashMin, squashMax = 0.8, 1.3
        local squashX = squashMin + (squashMax - squashMin) * rSx
        local squashY = squashMin + (squashMax - squashMin) * rSy

        local ampBase = (asteroidType == MapConfig.ObjectType.ASTEROID_LARGE) and 0.16 or 0.10
        local freqBase = (asteroidType == MapConfig.ObjectType.ASTEROID_LARGE) and 16.0 or 12.0
        local noiseAmp = ampBase * (0.7 + 0.6 * rAmp)
        local noiseFreq = freqBase * (0.7 + 0.6 * rFreq)
        local rotation = (rRot * 2.0 - 1.0) * math.pi
        local seedUniform = (globalX * 0.123 + globalY * 0.789 + asteroidType * 1.37) % 1.0

        pcall(function()
            shader:send("u_squashX", squashX)
            shader:send("u_squashY", squashY)
            shader:send("u_noiseAmp", noiseAmp)
            shader:send("u_noiseFreq", noiseFreq)
            shader:send("u_rotation", rotation)
            shader:send("u_seed", seedUniform)
        end)

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

    -- Intentar usar shader dedicado de wormhole
    local wormholeShader = ShaderManager and ShaderManager.getShader and ShaderManager.getShader("wormhole") or nil
    if (not wormholeShader) and ShaderManager and ShaderManager.init then
        -- Asegurar inicialización (idempotente)
        if not ShaderManager.state or not ShaderManager.state.initialized then
            ShaderManager.init()
        end
        wormholeShader = ShaderManager.getShader and ShaderManager.getShader("wormhole") or nil
        if not wormholeShader then
            print("⚠ Wormhole shader no disponible tras init; usando fallback")
        end
    end

    if wormholeShader then
        love.graphics.setShader(wormholeShader)

        wormholeShader:send("u_time", time)
        wormholeShader:send("u_intensity", 1.8)

        wormholeShader:send("u_color", {0.2, 0.6, 1.0})
        wormholeShader:send("u_pulsePhase", wormhole.pulsePhase or 0)
        
        -- Parallax
        wormholeShader:send("u_playerPos", {camera.x or 0, camera.y or 0})
        wormholeShader:send("u_wormholePos", {worldX, worldY})
        wormholeShader:send("u_parallaxStrength", 0.15)
        wormholeShader:send("u_cameraZoom", camera and camera.zoom or 1.0)

        local img = ShaderManager.getBaseImage("circle")
        if img then
            love.graphics.setColor(1, 1, 1, 0.95 * alpha)
            local scale = (sizePx * 2) / img:getWidth()
            love.graphics.draw(img, screenX, screenY, 0, scale, scale, img:getWidth()/2, img:getHeight()/2)
        end

        love.graphics.setShader()
    else
        -- Fallback sin shaders (círculos simples)
        love.graphics.setColor(0.1, 0.1, 0.4, 0.8 * alpha)
        love.graphics.circle("fill", screenX, screenY, sizePx * 1.5, segments)

        love.graphics.setColor(0.3, 0.1, 0.8, 0.9 * alpha)
        love.graphics.circle("fill", screenX, screenY, sizePx, segments)

        love.graphics.setColor(0.6, 0.3, 1.0, 0.7 * alpha)
        love.graphics.circle("fill", screenX, screenY, sizePx * 0.6, segments)

        love.graphics.setColor(1, 1, 1, 0.9 * alpha)
        love.graphics.circle("fill", screenX, screenY, sizePx * 0.2, 8)
    end

    love.graphics.pop()
    love.graphics.setColor(r, g, b, a)
end
-- Función para aplicar efectos de anomalía gravitatoria
function MapRenderer.applyGravityAnomalyEffect(chunk, camera)
    -- Pipeline en blanco: no aplicar efecto ni activar shader
    return false
end

-- NUEVO: Función para aplicar efectos de anomalía gravitacional a múltiples chunks
function MapRenderer.applyGravityAnomalyEffectMultiple(chunkInfo, camera, getChunkFunc)
    local BiomeSystem = require 'src.maps.biome_system'
    local anomalyChunks = {}
    
    -- Encontrar todos los chunks con anomalía gravitacional
    for chunkY = chunkInfo.startY, chunkInfo.endY do
        for chunkX = chunkInfo.startX, chunkInfo.endX do
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.biome and chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
                table.insert(anomalyChunks, chunk)
            end
        end
    end
    
    -- Pipeline en blanco: no inicializar ni aplicar shader aunque existan anomalías
    return false
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

-- NUEVO: Dibujo de microestrellas (fondo procedural barato en pantalla)
function MapRenderer.drawMicroStars(camera)
    local ms = MapRenderer._microStars
    if not ms or not ms.initialized then return 0 end

    local zoom = (camera and camera.zoom or 1.0)
    -- Culling por zoom (mostrar solo alejado)
    if zoom > (ms.config.showBelowZoom or 0.95) then
        return 0
    end

    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local pixels = screenW * screenH
    local desired = math.min(ms.config.maxCount, math.floor(pixels * (ms.config.densityPerPixel or 0.00012) + 0.5))

    -- Reconstruir si cambia resolución/densidad o si el batch está vacío o marcado como sucio (p.ej. tras cambiar seed)
    local needsRebuild = ms.dirty or (not ms.batch) or (ms.batch and ms.batch:getCount() == 0)
        or (ms.lastW ~= screenW) or (ms.lastH ~= screenH) or (ms.lastCount ~= desired)

    if needsRebuild then
        if not ms.batch then
            ms.batch = love.graphics.newSpriteBatch(ms.img, ms.config.maxCount)
        else
            ms.batch:clear()
        end
        -- Preparar/limpiar batch de halo
        if not ms.batchGlow then
            ms.batchGlow = love.graphics.newSpriteBatch(ms.img, ms.config.maxCount)
        else
            ms.batchGlow:clear()
        end
        -- RNG determinista por generación (seed del mundo) + resolución
        local m = 2147483647
        local seedBase = ((screenW * 73856093) + (screenH * 19349663) + ((ms.generationSeed or 0) * 2654435761)) % m
        if seedBase == 0 then seedBase = 12345 end
        local seed = seedBase
        local function lcg()
            seed = (1103515245 * seed + 12345) % m
            return seed / m
        end

        for i = 1, desired do
            -- Posiciones enteras (pixel snapping)
            local x = math.floor(lcg() * screenW + 0.5)
            local y = math.floor(lcg() * screenH + 0.5)
            local rs = lcg()
            -- Tamaño mínimo 1px para evitar parpadeo
            local sizeMin = ms.config.sizeMin or 0.8
            local sizeMax = ms.config.sizeMax or 1.8
            local size = math.max(1.0, sizeMin + rs * (sizeMax - sizeMin))

            local iw, ih = ms.img:getWidth(), ms.img:getHeight()
            local s = size / math.max(1, iw)
            -- Origen 0,0 para evitar subpíxel
            ms.batch:add(x, y, 0, s, s, 0, 0)
            -- NUEVO: halo/blur más grande y tenue
            local glowMul = 2.4
            local sg = s * glowMul
            ms.batchGlow:add(x, y, 0, sg, sg, 0, 0)
        end
        ms.lastW, ms.lastH, ms.lastCount = screenW, screenH, desired
        ms.dirty = nil
    end

    -- Alpha global con fade por zoom (posiciones no cambian)
    local aMin = ms.config.alphaMin or 0.35
    local aMax = ms.config.alphaMax or 0.8
    local z0 = 0.4
    local z1 = ms.config.showBelowZoom or 0.95
    local t = 0
    if z1 > z0 then t = math.max(0, math.min(1, (zoom - z0) / (z1 - z0))) end
    local alpha = aMax * (1 - t) + aMin * t

    -- Parallax sutil (sin depender del zoom), con wrapping y snapping a píxel
    local px, py = 0, 0
    local ps = ms.config.parallaxScale or 0.02
    if camera then
        px = - (camera.x or 0) * ps
        py = - (camera.y or 0) * ps
    end
    local ox = ((px % screenW) + screenW) % screenW
    local oy = ((py % screenH) + screenH) % screenH
    -- Snap a entero para evitar parpadeo por subpíxel
    ox = math.floor(ox + 0.5)
    oy = math.floor(oy + 0.5)

    local r, g, b, a = love.graphics.getColor()
    love.graphics.push()
    love.graphics.origin()
    -- NUEVO: dibujar halo/blur primero con blending aditivo suave
    local oldBlend, oldAlpha = love.graphics.getBlendMode()
    if ms.batchGlow then
        love.graphics.setBlendMode("add", "alphamultiply")
        love.graphics.setColor(1, 1, 1, alpha * 0.35)
        love.graphics.draw(ms.batchGlow, ox, oy)
        love.graphics.draw(ms.batchGlow, ox - screenW, oy)
        love.graphics.draw(ms.batchGlow, ox, oy - screenH)
        love.graphics.draw(ms.batchGlow, ox - screenW, oy - screenH)
        love.graphics.setBlendMode(oldBlend or "alpha", oldAlpha)
    end
    -- Núcleo de microestrellas
    love.graphics.setColor(1, 1, 1, alpha)
    -- Dibujo con tiling para evitar cortes al envolver
    love.graphics.draw(ms.batch, ox, oy)
    love.graphics.draw(ms.batch, ox - screenW, oy)
    love.graphics.draw(ms.batch, ox, oy - screenH)
    love.graphics.draw(ms.batch, ox - screenW, oy - screenH)
    love.graphics.pop()
    love.graphics.setColor(r, g, b, a)

    return ms.lastCount or 0
end

-- Initialize the renderer
MapRenderer.init()

return MapRenderer