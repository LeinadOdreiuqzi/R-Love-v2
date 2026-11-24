-- src/maps/systems/nebula_renderer.lua
local NebulaRenderer = {}

local MapConfig = require 'src.maps.config.map_config'
local ShaderManager = require 'src.shaders.shader_manager'
local NebulasShaders = require 'src.shaders.nebulas_shaders'
local Volume = require 'src.shaders.nebula_volume'
local Material = require 'src.maps.nebula_material'
local Color = require 'src.utils.color_harmony'

local SIZE_PIXELS = MapConfig.chunk.size * MapConfig.chunk.tileSize
local STRIDE = SIZE_PIXELS + (MapConfig.chunk.spacing or 0)

local items, visibleList = {}, {}
local cfg = {coreColor = {1,1,1}}
local white = {1,1,1}

local function backToFront(a, b)
    if a.par == b.par then return a.order < b.order end
    return a.par < b.par
end

local function tint(color, fallback, shift, saturation, value)
    local h, s, v = Color.rgb2hsv(color[1] or fallback[1] or 1, color[2] or fallback[2] or 1, color[3] or fallback[3] or 1)
    return Color.hsv2rgb((h+shift)%1, math.min(1,s*saturation), math.min(1,v*value))
end

local function classicTints(item)
    local n, par = item.n, item.par
    local outer = n.color or white
    local core = n.coreColor or outer.core or outer
    local influence = 1
    for j, neighbor in ipairs(item.chunk.objects.nebulae) do
        if j ~= item.idx then
            local distance = math.sqrt((n.x-neighbor.x)^2 + (n.y-neighbor.y)^2)
            influence = influence + .15 * math.max(0, 1-distance/300)
        end
    end
    influence = math.min(1.3, influence)
    local shift = (par-.5)*.12*influence
    local saturation = (.90+.20*par)*influence
    local value = (.95+.10*(1-par))*influence
    cfg.coreColor[1],cfg.coreColor[2],cfg.coreColor[3] = tint(core, outer, shift, saturation, value)
    return tint(outer, white, shift, saturation, value)
end

local function worldToScreenParallax(camera, wx, wy, parallax)
    parallax = math.max(0.0, math.min(1.0, parallax or 1.0))
    local px = camera.x + (wx - camera.x) * parallax
    local py = camera.y + (wy - camera.y) * parallax
    return camera:worldToScreen(px, py)
end

local function isOnScreen(x, y, radius, nebula, volume, width, height)
    local rx, ry
    if volume then
        -- Máxima extensión de la misma máscara radial que usa el shader, después del giro.
        local aspect, angle = nebula.aspectRatio or 1, nebula.rotation or 0
        local c, s = math.cos(angle), math.sin(angle)
        local bound = radius * (1 + .25 * math.min(.75, nebula.irregularity or .35))
        rx = bound * math.sqrt((aspect*c)^2 + (s/aspect)^2) + 1
        ry = bound * math.sqrt((aspect*s)^2 + (c/aspect)^2) + 1
    else
        rx = radius * MapConfig.nebulae.cullRadiusMultiplier + MapConfig.nebulae.cullPaddingPx
        ry = rx
    end
    return x+rx >= 0 and x-rx <= width and y+ry >= 0 and y-ry <= height
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
    local effectiveRadius = radiusPx * MapConfig.nebulae.cullRadiusMultiplier
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
    local width, height = love.graphics.getDimensions()
    local target = love.graphics.getCanvas()
    if target then width, height = target:getDimensions() end

    -- Pool para recolección de nebulosas visibles (evita GC allocations)
    local volume = MapConfig.nebulae.volumetric
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
                    if isOnScreen(screenX, screenY, radiusPx, n, volume, width, height) then
                        local fadeAlpha = volume and 1 or calculateNebulaAlpha(screenX, screenY, radiusPx)
                        if fadeAlpha > 0.01 then
                            visibleCount = visibleCount + 1
                            local item = items[visibleCount]
                            if not item then
                                item = {}
                                items[visibleCount] = item
                            end
                            visibleList[visibleCount] = item
                            item.order = visibleCount
                            item.worldX, item.worldY = wx, wy
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
    love.graphics.push("all")
    love.graphics.origin()
    local oldBlend, oldAlphaMode = love.graphics.getBlendMode()

    -- =========================================================================
    -- PASO 1: CUERPOS DE NEBULOSAS (Shader activo + Blend Additive)
    -- =========================================================================
    if volume then
        table.sort(visibleList, backToFront)
        Volume.begin(shader)
    else
        love.graphics.setBlendMode("add","alphamultiply")
    end
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
        local ba = (n.color and n.color[4] or 1) * 1.25 * fadeAlpha
        local cr, cg, cb = 1, 1, 1
        if volume then
            n.emissionRegion = n.emissionRegion or Material.atWorld(item.worldX, item.worldY)
            local balance = Material.cloudBalance(n.emissionRegion, item.worldX, item.worldY, n)
            Volume.setCloud(shader, n.emissionRegion, item.worldX, item.worldY, n, balance)
        else
            cr, cg, cb = classicTints(item)
        end
        cfg.seed = n.seed or 0
        cfg.noiseScale = n.noiseScale or 2.5
        cfg.warpAmp = n.warpAmp or 0.65
        cfg.warpFreq = n.warpFreq or 1.25
        cfg.softness = n.softness or 0.28
        cfg.intensity = n.intensity or 0.6
        cfg.brightness = OptimizedRenderer.calculateNebulaBrightness(n, timeNow)
        cfg.parallax = par
        cfg.sparkleStrength = n.sparkleStrength or 0.0
        cfg.morphology = n.morphology or 0.0
        cfg.irregularity = n.irregularity or 0.35
        cfg.speed = n.speed or 1.0

        -- Configurar uniforms vectoriales para esta nebulosa (Fase 4: 4 llamadas en lugar de 13)
        NebulasShaders.configureForNebula(cfg)

        local scale = radiusPx * scaleFactor
        local rot = n.rotation or 0.0
        local aspect = n.aspectRatio or 1.0
        local scaleX = scale * aspect
        local scaleY = scale / aspect

        love.graphics.setColor(cr, cg, cb, ba)
        love.graphics.draw(img, screenX, screenY, rot, scaleX, scaleY, halfIw, halfIh)
    end

    if volume then Volume.finish(shader) end
    NebulasShaders.unsetShader()

    love.graphics.setColor(1,1,1,1)

    -- Limpiar referencias pesadas del pool para permitir GC de chunks descargados
    for idx = 1, visibleCount do
        visibleList[idx].n = nil
        visibleList[idx].chunk = nil
        visibleList[idx] = nil
    end

    love.graphics.setBlendMode(oldBlend or "alpha", oldAlphaMode)
    love.graphics.pop()

    return visibleCount
end

return NebulaRenderer
