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

function isOnScreen(screenX, screenY, radiusPx, margin)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    -- Margen mucho más generoso para nebulosas grandes
    local m = margin or 200
    local dynamicMargin = math.max(m, radiusPx * 1.5)  -- 150% del radio como margen para nebulosas grandes
    -- Para nebulosas muy grandes (>1000px), ser aún más permisivo
    if radiusPx > 1000 then
        dynamicMargin = radiusPx * 2.0  -- 200% del radio para nebulosas enormes
    end
    return (screenX + radiusPx + dynamicMargin) >= 0 and (screenX - radiusPx - dynamicMargin) <= w
       and (screenY + radiusPx + dynamicMargin) >= 0 and (screenY - radiusPx - dynamicMargin) <= h
end

function NebulaRenderer.update(dt)
    -- Actualizar tiempo en el shader de nebulosas
    if NebulasShaders and NebulasShaders.updateTime then
        NebulasShaders.updateTime(love.timer.getTime())
    end
end

function NebulaRenderer.drawNebulae(chunkInfo, camera, getChunkFunc)
    -- DEBUG: Logging desactivado
    -- if not NebulaRenderer._drawCallLogged then
    --     NebulaRenderer._drawCallLogged = true
    --     print("NebulaRenderer.drawNebulae called - function is active")
    -- end
    
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
                    
                    -- DEBUG: Logging desactivado para reducir spam
                    -- if zoom > 0.8 and i == 1 then
                    --     print(string.format("Nebula debug: zoom=%.2f, worldPos=(%.1f,%.1f), screenPos=(%.1f,%.1f), size=%.1f, radiusPx=%.1f, parallax=%.2f", 
                    --         zoom, wx, wy, screenX, screenY, n.size or 140, radiusPx, par))
                    -- end
                    
                    -- NUEVO: Sistema basado en intersección con pantalla en lugar de distancia al centro
                    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
                    
                    -- Calcular bounds de la nebulosa en pantalla
                    local nebulaLeft = screenX - radiusPx
                    local nebulaRight = screenX + radiusPx
                    local nebulaTop = screenY - radiusPx
                    local nebulaBottom = screenY + radiusPx
                    
                    -- Usar función isOnScreen con margen dinámico más generoso
                    local isVisible = isOnScreen(screenX, screenY, radiusPx, nil)
                    
                    -- REMOVIDO: Sistema de fade-out - las nebulosas ahora mantienen visibilidad completa
                    
                    -- Renderizar si la nebulosa está visible en pantalla
                    if isVisible then
                        love.graphics.push()
                        love.graphics.origin()

                        -- Color base con alpha aumentado para mayor visibilidad
                        local br, bg, bb, ba = (n.color and n.color[1] or 1), (n.color and n.color[2] or 1), (n.color and n.color[3] or 1), (n.color and n.color[4] or 1)
                        ba = ba * 1.25  -- Alpha aumentado para mayor visibilidad, sin fade-out
                        
                        -- Armonización con nebulosas cercanas para coherencia visual
                        local harmonyFactor = 1.0
                        local neighborInfluence = 0.0
                        for j = 1, #chunk.objects.nebulae do
                            if j ~= i then
                                local neighbor = chunk.objects.nebulae[j]
                                local dist = math.sqrt((n.x - neighbor.x)^2 + (n.y - neighbor.y)^2)
                                if dist < 300 then  -- Nebulosas cercanas
                                    local influence = math.max(0, 1.0 - dist / 300)
                                    neighborInfluence = neighborInfluence + influence * 0.15
                                end
                            end
                        end
                        harmonyFactor = math.max(0.7, math.min(1.3, 1.0 + neighborInfluence))
                        
                        -- Variación armónica mejorada según parallax y vecindad
                        local h, s, v = rgb2hsv(br, bg, bb)
                        local hueShift = (par - 0.5) * 0.12 * harmonyFactor         -- ±0.06 modulado
                        local satAdj   = (0.90 + 0.20 * par) * harmonyFactor        -- [0.90, 1.10] modulado
                        local valAdj   = (0.95 + 0.10 * (1.0 - par)) * harmonyFactor  -- [0.95, 1.05] modulado
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
                            -- Niebla oscura intensificada para mayor contraste
                        local baseIntensity = n.intensity or 0.6
                        local fogAlpha = math.max(0.0, math.min(1.0, 0.12 + 0.25 * baseIntensity * (0.8 + 0.2 * par)))
                        
                        if fogAlpha > 0.01 then
                            local prevBlend, prevAlpha = love.graphics.getBlendMode()
                            love.graphics.setBlendMode("alpha", "alphamultiply")
                            
                            -- Niebla oscura principal con tinte armonizado
                            local fogTint = 0.08 + 0.04 * par  -- Tinte más pronunciado
                            local harmonyFactor = 0.85 + 0.15 * math.sin(timeNow * 0.3 + (n.seed or 0) * 0.1)
                            love.graphics.setColor(fogTint * harmonyFactor, fogTint * 0.75 * harmonyFactor, fogTint * 0.55 * harmonyFactor, fogAlpha)
                            local fogScale = scale * 1.18  -- Mayor cobertura para mejor integración
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