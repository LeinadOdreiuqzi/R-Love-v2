-- src/maps/systems/nebula_renderer.lua
local NebulaRenderer = {}

local MapConfig = require 'src.maps.config.map_config'
local ShaderManager = require 'src.shaders.shader_manager'
local NebulasShaders = require 'src.shaders.nebulas_shaders'
local BiomeSystem = require 'src.maps.biome_system'

local SIZE_PIXELS = MapConfig.chunk.size * MapConfig.chunk.tileSize
local STRIDE = SIZE_PIXELS + (MapConfig.chunk.spacing or 0)

-- Utilidades color: RGB<->HSV (valores en [0,1])
local function rgb2hsv(r, g, b)
    local maxc = math.max(r, g, b)
    local minc = math.min(r, g, b)
    local v = maxc
    local d = maxc - minc
    local s = (maxc == 0) and 0 or d / maxc
    if d == 0 then return 0, 0, v end
    local h
    if maxc == r then
        h = ((g - b) / d) % 6
    elseif maxc == g then
        h = (b - r) / d + 2
    else
        h = (r - g) / d + 4
    end
    h = h / 6
    if h < 0 then h = h + 1 end
    return h, s, v
end

local function hsv2rgb(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local m = i % 6
    if m == 0 then return v, t, p
    elseif m == 1 then return q, v, p
    elseif m == 2 then return p, v, t
    elseif m == 3 then return p, q, v
    elseif m == 4 then return t, p, v
    else return v, p, q end
end

local function worldToScreenParallax(camera, wx, wy, parallax)
    parallax = math.max(0.0, math.min(1.0, parallax or 1.0))
    local px = camera.x + (wx - camera.x) * parallax
    local py = camera.y + (wy - camera.y) * parallax
    return camera:worldToScreen(px, py)
end

local function isOnScreen(screenX, screenY, radiusPx)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    -- El radio visual efectivo incluye el radio base, la capa de niebla (1.18x),
    -- deformación por warp del shader (~8%) y un margen de seguridad de 50px
    local effectiveRadius = (radiusPx or 140) * 1.25 + 50
    return (screenX + effectiveRadius >= 0) and (screenX - effectiveRadius <= w)
       and (screenY + effectiveRadius >= 0) and (screenY - effectiveRadius <= h)
end

-- Calcular factor de alpha para fade-in gradual de nebulas grandes en el borde del viewport
local function calculateNebulaAlpha(screenX, screenY, radiusPx)
    -- Nebulosas pequeñas y medianas no necesitan fade artificial (el shader ya posee bordes suaves)
    if not radiusPx or radiusPx <= 250 then
        return 1.0
    end

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    -- Distancia euclidiana mínima desde el centro de la nebulosa al rectángulo de la pantalla
    local dx = 0
    if screenX < 0 then
        dx = -screenX
    elseif screenX > w then
        dx = screenX - w
    end

    local dy = 0
    if screenY < 0 then
        dy = -screenY
    elseif screenY > h then
        dy = screenY - h
    end

    -- Si el centro está dentro de la pantalla, visibilidad completa
    if dx == 0 and dy == 0 then
        return 1.0
    end

    local distOutside = math.sqrt(dx * dx + dy * dy)
    local effectiveRadius = radiusPx * 1.25
    local distToCutoff = effectiveRadius - distOutside

    -- Fuera del alcance visual
    if distToCutoff <= 0 then
        return 0.0
    end

    -- Margen de transición gradual hacia el borde
    local fadeRange = math.min(radiusPx * 0.4, 250)
    if distToCutoff >= fadeRange then
        return 1.0
    end

    local t = distToCutoff / fadeRange
    return t * t * (3.0 - 2.0 * t)  -- Smoothstep
end

function NebulaRenderer.update(dt)
    -- Actualizar tiempo en el shader de nebulosas
    if NebulasShaders and NebulasShaders.updateTime then
        NebulasShaders.updateTime(love.timer.getTime())
    end
end

function NebulaRenderer.drawNebulae(chunkInfo, camera, getChunkFunc)
    -- Usar el sistema de shaders de nebulosas
    local shader = NebulasShaders and NebulasShaders.getShader and NebulasShaders.getShader() or nil
    local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle") or nil
    
    if not NebulaRenderer._debugOnce then
        NebulaRenderer._debugOnce = true
        local iw, ih = 0, 0
        if img and img.getWidth then iw, ih = img:getWidth(), img:getHeight() end
        print(("NebulaRenderer: shader=%s, circle=%dx%d"):format(shader and "OK" or "nil", iw, ih))
    end
    if not shader or not img then return 0 end

    local zoom = camera and camera.zoom or 1
    local timeNow = love.timer.getTime()

    -- Pool para recolección de nebulosas visibles (evita GC allocations)
    NebulaRenderer._visibleList = NebulaRenderer._visibleList or {}
    local visibleList = NebulaRenderer._visibleList
    local visibleCount = 0

    for chunkY = chunkInfo.startY, chunkInfo.endY do
        for chunkX = chunkInfo.startX, chunkInfo.endX do
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.objects and chunk.objects.nebulae and #chunk.objects.nebulae > 0 then
                local baseWorldX = chunkX * STRIDE * MapConfig.chunk.worldScale
                local baseWorldY = chunkY * STRIDE * MapConfig.chunk.worldScale

                for i = 1, #chunk.objects.nebulae do
                    local n = chunk.objects.nebulae[i]
                    local wx = baseWorldX + n.x * MapConfig.chunk.worldScale
                    local wy = baseWorldY + n.y * MapConfig.chunk.worldScale

                    local par = math.max(0.0, math.min(1.0, n.parallax or 0.85))
                    local screenX, screenY = worldToScreenParallax(camera, wx, wy, par)
                    local radiusPx = (n.size or 140) * zoom

                    -- Culling matemático exacto con margen físico
                    if isOnScreen(screenX, screenY, radiusPx) then
                        local fadeAlpha = calculateNebulaAlpha(screenX, screenY, radiusPx)
                        if fadeAlpha > 0.01 then
                            visibleCount = visibleCount + 1
                            local item = visibleList[visibleCount]
                            if not item then
                                item = {}
                                visibleList[visibleCount] = item
                            end
                            item.n = n
                            item.screenX = screenX
                            item.screenY = screenY
                            item.radiusPx = radiusPx
                            item.fadeAlpha = fadeAlpha
                            item.par = par
                            item.chunk = chunk
                            item.idx = i
                        end
                    end
                end
            end
        end
    end

    if visibleCount == 0 then
        return 0
    end

    local iw, ih = img:getWidth(), img:getHeight()
    local scaleFactor = 2.0 / math.max(1, iw)
    local halfIw, halfIh = iw * 0.5, ih * 0.5

    -- Preparar transformaciones una sola vez para todo el lote
    love.graphics.push()
    love.graphics.origin()
    local oldBlend, oldAlphaMode = love.graphics.getBlendMode()

    -- =========================================================================
    -- PASO 1: CUERPOS DE NEBULOSAS (Shader activo + Blend Additive)
    -- =========================================================================
    love.graphics.setBlendMode("add", "alphamultiply")
    NebulasShaders.setShader()

    local OptimizedRenderer = require 'src.maps.optimized_renderer'

    for idx = 1, visibleCount do
        local item = visibleList[idx]
        local n = item.n
        local par = item.par
        local fadeAlpha = item.fadeAlpha
        local screenX = item.screenX
        local screenY = item.screenY
        local radiusPx = item.radiusPx
        local chunk = item.chunk
        local i = item.idx

        -- Color base con alpha aumentado y fade-in gradual
        local br = (n.color and n.color[1] or 1)
        local bg = (n.color and n.color[2] or 1)
        local bb = (n.color and n.color[3] or 1)
        local ba = (n.color and n.color[4] or 1) * 1.25 * fadeAlpha

        -- Armonización con nebulosas cercanas del mismo chunk
        local neighborInfluence = 0.0
        for j = 1, #chunk.objects.nebulae do
            if j ~= i then
                local neighbor = chunk.objects.nebulae[j]
                local dist = math.sqrt((n.x - neighbor.x)^2 + (n.y - neighbor.y)^2)
                if dist < 300 then
                    local influence = math.max(0, 1.0 - dist / 300)
                    neighborInfluence = neighborInfluence + influence * 0.15
                end
            end
        end
        local harmonyFactor = math.max(0.7, math.min(1.3, 1.0 + neighborInfluence))

        -- Variación armónica según parallax y vecindad
        local h, s, v = rgb2hsv(br, bg, bb)
        local hueShift = (par - 0.5) * 0.12 * harmonyFactor
        local satAdj   = (0.90 + 0.20 * par) * harmonyFactor
        local valAdj   = (0.95 + 0.10 * (1.0 - par)) * harmonyFactor
        h = (h + hueShift) % 1.0
        s = math.max(0.0, math.min(1.0, s * satAdj))
        v = math.max(0.0, math.min(1.0, v * valAdj))
        local cr, cg, cb = hsv2rgb(h, s, v)

        local brightness = OptimizedRenderer.calculateNebulaBrightness(n, timeNow)

        -- Configurar uniforms para esta nebulosa
        NebulasShaders.configureForNebula({
            seed = (n.seed or 0) * 0.001,
            noiseScale = n.noiseScale or 2.5,
            warpAmp = n.warpAmp or 0.05,
            warpFreq = n.warpFreq or 0.20,
            softness = n.softness or 0.70,
            brightness = brightness,
            parallax = par,
            sparkleStrength = 0.0
        })

        local scale = radiusPx * scaleFactor
        item.scale = scale

        love.graphics.setColor(cr, cg, cb, ba)
        love.graphics.draw(img, screenX, screenY, 0, scale, scale, halfIw, halfIh)
    end

    NebulasShaders.unsetShader()

    -- =========================================================================
    -- PASO 2: CAPAS DE NIEBLA SUAVE (FOG-OF-WAR) (Sin shader + Blend Alpha)
    -- =========================================================================
    love.graphics.setBlendMode("alpha", "alphamultiply")

    for idx = 1, visibleCount do
        local item = visibleList[idx]
        local n = item.n
        local par = item.par
        local screenX = item.screenX
        local screenY = item.screenY
        local fadeAlpha = item.fadeAlpha
        local scale = item.scale or (item.radiusPx * scaleFactor)

        local baseIntensity = n.intensity or 0.6
        local fogAlpha = math.max(0.0, math.min(1.0, 0.12 + 0.25 * baseIntensity * (0.8 + 0.2 * par))) * fadeAlpha

        if fogAlpha > 0.01 then
            local fogTint = 0.08 + 0.04 * par
            local harmonyFactor = 0.85 + 0.15 * math.sin(timeNow * 0.3 + (n.seed or 0) * 0.1)
            love.graphics.setColor(fogTint * harmonyFactor, fogTint * 0.75 * harmonyFactor, fogTint * 0.55 * harmonyFactor, fogAlpha)
            local fogScale = scale * 1.18
            love.graphics.draw(img, screenX, screenY, 0, fogScale, fogScale, halfIw, halfIh)
        end
    end

    -- Limpiar referencias pesadas del pool para permitir GC de chunks descargados
    for idx = 1, visibleCount do
        visibleList[idx].n = nil
        visibleList[idx].chunk = nil
    end

    love.graphics.setBlendMode(oldBlend or "alpha", oldAlphaMode)
    love.graphics.pop()

    return visibleCount
end

return NebulaRenderer