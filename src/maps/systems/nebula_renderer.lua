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

local function isOnScreen(screenX, screenY, radiusPx, margin)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local m = margin or 200
    return (screenX + radiusPx + m) >= 0 and (screenX - radiusPx - m) <= w
       and (screenY + radiusPx + m) >= 0 and (screenY - radiusPx - m) <= h
end

function NebulaRenderer.update(dt)
    -- Actualizar tiempo en el shader de nebulosas
    if NebulasShaders and NebulasShaders.updateTime then
        NebulasShaders.updateTime(love.timer.getTime())
    end
end

function NebulaRenderer.drawNebulae(chunkInfo, camera, getChunkFunc)
    -- Usar el nuevo sistema de shaders de nebulosas
    local shader = NebulasShaders and NebulasShaders.getShader and NebulasShaders.getShader() or nil
    local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle") or nil
    -- DEBUG: imprimir una sola vez el tamaño del círculo y existencia de shader
    if not NebulaRenderer._debugOnce then
        NebulaRenderer._debugOnce = true
        local iw, ih = 0, 0
        if img and img.getWidth then iw, ih = img:getWidth(), img:getHeight() end
        print(("NebulaRenderer: shader=%s, circle=%dx%d"):format(shader and "OK" or "nil", iw, ih))
    end
    if not shader or not img then return 0 end

    local rendered = 0
    local zoom = camera and camera.zoom or 1
    local oldBlend, oldAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")

    local timeNow = love.timer.getTime()

    -- DEBUG: imprimir una sola vez el tamaño del círculo y existencia de shader
    if not NebulaRenderer._debugOnce then
        NebulaRenderer._debugOnce = true
        local iw, ih = img:getWidth(), img:getHeight()
        print(("NebulaRenderer: shader=%s, circle=%dx%d"):format(shader and "OK" or "nil", iw, ih))
    end
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

                    if isOnScreen(screenX, screenY, radiusPx, 250) then
                        love.graphics.push()
                        love.graphics.origin()

                        -- Color base con alpha aumentado para mayor visibilidad
                        local br, bg, bb, ba = (n.color and n.color[1] or 1), (n.color and n.color[2] or 1), (n.color and n.color[3] or 1), (n.color and n.color[4] or 1)
                        ba = ba * 1.25  -- Aumentar opacidad base
                        -- Variación armónica según parallax: matiz análogo y ligera variación de saturación/valor
                        local h, s, v = rgb2hsv(br, bg, bb)
                        local hueShift = (par - 0.5) * 0.12         -- ±0.06
                        local satAdj   = 0.90 + 0.20 * par          -- [0.90, 1.10]
                        local valAdj   = 0.95 + 0.10 * (1.0 - par)  -- [0.95, 1.05] más suave en fondo
                        h = (h + hueShift) % 1.0
                        s = math.max(0.0, math.min(1.0, s * satAdj))
                        v = math.max(0.0, math.min(1.0, v * valAdj))
                        local cr, cg, cb = hsv2rgb(h, s, v)

                        -- UNIFICADO: Usar función centralizada de brillo
                        local OptimizedRenderer = require 'src.maps.optimized_renderer'
                        local brightness = OptimizedRenderer.calculateNebulaBrightness(n, timeNow)

                        -- Configurar uniforms usando el nuevo sistema
                        love.graphics.setColor(cr, cg, cb, ba)
                        if NebulasShaders and NebulasShaders.configureForNebula then
                            NebulasShaders.configureForNebula({
                                seed = (n.seed or 0) * 0.001,
                                noiseScale = n.noiseScale or 2.5,
                                warpAmp = n.warpAmp or 0.65,
                                warpFreq = n.warpFreq or 1.25,
                                softness = n.softness or 0.28,
                                brightness = brightness,
                                parallax = par,
                                sparkleStrength = 0.0  -- Destellos desactivados
                            })
                        end
                        NebulasShaders.setShader()
                        local iw, ih = img:getWidth(), img:getHeight()
                        local scale = (radiusPx * 2) / math.max(1, iw)
                        love.graphics.draw(img, screenX, screenY, 0, scale, scale, iw * 0.5, ih * 0.5)
                        NebulasShaders.unsetShader()

                        -- NUEVO: superponer niebla suave (fog-of-war) para contraste mejorado
                        do
                            -- Niebla oscura sutil para realzar contraste con colores procedurales
                            local baseIntensity = n.intensity or 0.6
                            local fogAlpha = math.max(0.0, math.min(1.0, 0.08 + 0.18 * baseIntensity * (0.75 + 0.25 * par)))
                            
                            if fogAlpha > 0.01 then
                                local prevBlend, prevAlpha = love.graphics.getBlendMode()
                                love.graphics.setBlendMode("alpha", "alphamultiply")
                                
                                -- Niebla oscura principal con tinte sutil
                                local fogTint = 0.05 + 0.03 * par  -- Ligero tinte según parallax
                                love.graphics.setColor(fogTint, fogTint * 0.8, fogTint * 0.6, fogAlpha)
                                local fogScale = scale * 1.12  -- Ligeramente más grande para mejor cobertura
                                love.graphics.draw(img, screenX, screenY, 0, fogScale, fogScale, iw * 0.5, ih * 0.5)
                                
                                love.graphics.setBlendMode(prevBlend or "add", prevAlpha)
                            end
                        end

                        love.graphics.pop()
                        rendered = rendered + 1
                    end
                end
            end
        end
    end

    love.graphics.setBlendMode(oldBlend or "alpha", oldAlphaMode)
    return rendered
end

return NebulaRenderer