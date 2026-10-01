-- src/maps/systems/renderers/background_star_renderer.lua
-- Submódulo para renderizado de capas de fondo espacial (Micro-estrellas y Estrellas pequeñas/intermedias)
-- Desacoplado de src/maps/systems/map_renderer.lua

local BackgroundStarRenderer = {}
local StarShader = require 'src.shaders.star_shader'

--[[
    Dibujo de microestrellas (fondo procedural económico en espacio de pantalla con parallax)
--]]
function BackgroundStarRenderer.drawMicroStars(mapRenderer, camera)
    local ms = mapRenderer._microStars
    if not ms or not ms.initialized then return 0 end

    local zoom = (camera and camera.zoom or 1.0)
    if zoom > (ms.config.showBelowZoom or 0.95) then
        return 0
    end

    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local pixels = screenW * screenH
    local desired = math.min(ms.config.maxCount, math.floor(pixels * (ms.config.densityPerPixel or 0.00012) + 0.5))

    local needsRebuild = ms.dirty or (not ms.batch) or (ms.batch and ms.batch:getCount() == 0)
        or (ms.lastW ~= screenW) or (ms.lastH ~= screenH) or (ms.lastCount ~= desired)

    if needsRebuild then
        if not ms.batch then
            ms.batch = love.graphics.newSpriteBatch(ms.img, ms.config.maxCount)
        else
            ms.batch:clear()
        end
        if not ms.batchGlow then
            ms.batchGlow = love.graphics.newSpriteBatch(ms.img, ms.config.maxCount)
        else
            ms.batchGlow:clear()
        end
        
        local m = 2147483647
        local seedBase = ((screenW * 73856093) + (screenH * 19349663) + ((ms.generationSeed or 0) * 2654435761)) % m
        if seedBase == 0 then seedBase = 12345 end
        local seed = seedBase
        local function lcg()
            seed = (1103515245 * seed + 12345) % m
            return seed / m
        end

        for i = 1, desired do
            local x = math.floor(lcg() * screenW + 0.5)
            local y = math.floor(lcg() * screenH + 0.5)
            local rs = lcg()
            local sizeMin = ms.config.sizeMin or 0.8
            local sizeMax = ms.config.sizeMax or 1.8
            local size = math.max(1.0, sizeMin + rs * (sizeMax - sizeMin))

            local iw, ih = ms.img:getWidth(), ms.img:getHeight()
            local s = size / math.max(1, iw)
            ms.batch:add(x, y, 0, s, s, 0, 0)
            
            local glowMul = 2.4
            local sg = s * glowMul
            ms.batchGlow:add(x, y, 0, sg, sg, 0, 0)
        end
        ms.lastW, ms.lastH, ms.lastCount = screenW, screenH, desired
        ms.dirty = nil
    end

    local aMin = ms.config.alphaMin or 0.35
    local aMax = ms.config.alphaMax or 0.8
    local z0 = 0.4
    local z1 = ms.config.showBelowZoom or 0.95
    local t = 0
    if z1 > z0 then t = math.max(0, math.min(1, (zoom - z0) / (z1 - z0))) end
    local alpha = aMax * (1 - t) + aMin * t

    local px, py = 0, 0
    local ps = ms.config.parallaxScale or 0.02
    if camera then
        px = - (camera.x or 0) * ps
        py = - (camera.y or 0) * ps
    end
    local ox = ((px % screenW) + screenW) % screenW
    local oy = ((py % screenH) + screenH) % screenH
    ox = math.floor(ox + 0.5)
    oy = math.floor(oy + 0.5)

    local r, g, b, a = love.graphics.getColor()
    love.graphics.push()
    love.graphics.origin()
    
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
    
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(ms.batch, ox, oy)
    love.graphics.draw(ms.batch, ox - screenW, oy)
    love.graphics.draw(ms.batch, ox, oy - screenH)
    love.graphics.draw(ms.batch, ox - screenW, oy - screenH)
    love.graphics.pop()
    love.graphics.setColor(r, g, b, a)

    return ms.lastCount or 0
end

--[[
    Renderiza una capa individual de estrellas intermedias
--]]
function BackgroundStarRenderer.drawSmallStarsLayer(mapRenderer, ss, camera)
    local zoom = camera and camera.zoom or 1.0
    
    local showBelow = ss.config.showBelowZoom or 0.9
    local showAbove = ss.config.showAboveZoom or 0.0
    
    if zoom > showBelow or zoom < showAbove then
        return 0
    end
    
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local pixels = screenW * screenH
    local desired = math.min(ss.config.maxCount, math.floor(pixels * (ss.config.densityPerPixel or 0.00010) + 0.5))

    local needsRebuild = ss.dirty or (not ss.batch) or (ss.batch and ss.batch:getCount() == 0)
        or (ss.lastW ~= screenW) or (ss.lastH ~= screenH) or (ss.lastCount ~= desired)

    if needsRebuild then
        if not ss.batch then
            ss.batch = love.graphics.newSpriteBatch(ss.img, ss.config.maxCount)
        else
            ss.batch:clear()
        end
        
        local m = 2147483647
        local offset = (ss == mapRenderer._smallStars1) and 1000 or 2000
        local seedBase = ((screenW * 73856093) + (screenH * 19349663) + ((ss.generationSeed or 0) * 2654435761) + offset) % m
        if seedBase == 0 then seedBase = 12345 end
        local seed = seedBase
        local function lcg()
            seed = (1103515245 * seed + 12345) % m
            return seed / m
        end

        for i = 1, desired do
            local x = math.floor(lcg() * screenW + 0.5)
            local y = math.floor(lcg() * screenH + 0.5)
            local rs = lcg()
            
            local sizeMin = ss.config.sizeMin or 1.0
            local sizeMax = ss.config.sizeMax or 1.8
            local size = sizeMin + rs * (sizeMax - sizeMin)

            local iw, ih = ss.img:getWidth(), ss.img:getHeight()
            local s = size / math.max(1, iw)
            ss.batch:add(x, y, 0, s, s, 0, 0)
        end
        ss.lastW, ss.lastH, ss.lastCount = screenW, screenH, desired
        ss.dirty = nil
    end

    local aMin = ss.config.alphaMin or 0.3
    local aMax = ss.config.alphaMax or 0.6
    
    local fadeStart = showAbove + (showBelow - showAbove) * 0.1
    local fadeEnd = showBelow - (showBelow - showAbove) * 0.1
    
    local alpha = aMax
    if zoom < fadeStart then
        local t = math.max(0, math.min(1, (zoom - showAbove) / (fadeStart - showAbove)))
        alpha = aMin + (aMax - aMin) * t
    elseif zoom > fadeEnd then
        local t = math.max(0, math.min(1, (showBelow - zoom) / (showBelow - fadeEnd)))
        alpha = aMin + (aMax - aMin) * t
    end

    local px, py = 0, 0
    local ps = ss.config.parallaxScale or 0.012
    if camera then
        px = - (camera.x or 0) * ps
        py = - (camera.y or 0) * ps
    end
    local ox = ((px % screenW) + screenW) % screenW
    local oy = ((py % screenH) + screenH) % screenH
    ox = math.floor(ox + 0.5)
    oy = math.floor(oy + 0.5)

    local r, g, b, a = love.graphics.getColor()
    love.graphics.push()
    love.graphics.origin()
    
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(ss.batch, ox, oy)
    love.graphics.draw(ss.batch, ox - screenW, oy)
    love.graphics.draw(ss.batch, ox, oy - screenH)
    love.graphics.draw(ss.batch, ox - screenW, oy - screenH)
    
    love.graphics.pop()
    love.graphics.setColor(r, g, b, a)

    return ss.lastCount or 0
end

--[[
    Dibujo de capa 1 de estrellas intermedias (tipo 2)
--]]
function BackgroundStarRenderer.drawSmallStars1(mapRenderer, camera)
    local ss = mapRenderer._smallStars1
    if not ss or not ss.initialized then return 0 end

    local zoom = (camera and camera.zoom or 1.0)
    if zoom > (ss.config.showBelowZoom or 2.0) then
        return 0
    end

    if ss.config.useShaders and StarShader and StarShader.begin then
        StarShader.begin()
        StarShader.setType(2)
    end
    
    local count = BackgroundStarRenderer.drawSmallStarsLayer(mapRenderer, ss, camera)
    
    if ss.config.useShaders and StarShader and StarShader.finish then
        StarShader.finish()
    end
    
    return count
end

--[[
    Dibujo de capa 2 de estrellas intermedias (tipo 3)
--]]
function BackgroundStarRenderer.drawSmallStars2(mapRenderer, camera)
    local ss = mapRenderer._smallStars2
    if not ss or not ss.initialized then return 0 end

    local zoom = (camera and camera.zoom or 1.0)
    if zoom > (ss.config.showBelowZoom or 1.8) then
        return 0
    end

    if ss.config.useShaders and StarShader and StarShader.begin then
        StarShader.begin()
        StarShader.setType(3)
    end
    
    local count = BackgroundStarRenderer.drawSmallStarsLayer(mapRenderer, ss, camera)
    
    if ss.config.useShaders and StarShader and StarShader.finish then
        StarShader.finish()
    end
    
    return count
end

--[[
    Función combinada optimizada para dibujar ambas capas intermedias
--]]
function BackgroundStarRenderer.drawSmallStars(mapRenderer, camera)
    local ss1 = mapRenderer._smallStars1
    local ss2 = mapRenderer._smallStars2
    
    if not ss1 or not ss1.initialized or not ss2 or not ss2.initialized then
        return 0
    end
    
    local zoom = camera and camera.zoom or 1.0
    
    local layer1Visible = zoom <= (ss1.config.showBelowZoom or 2.0) and zoom >= (ss1.config.showAboveZoom or 0.2)
    local layer2Visible = zoom <= (ss2.config.showBelowZoom or 1.8) and zoom >= (ss2.config.showAboveZoom or 0.3)
    
    if not layer1Visible and not layer2Visible then
        return 0
    end
    
    if (layer1Visible or layer2Visible) and ss1.config.useShaders and StarShader and StarShader.begin then
        StarShader.begin()
    end
    
    local count1, count2 = 0, 0
    
    if layer1Visible then
        if StarShader and StarShader.setType then
            StarShader.setType(2)
        end
        count1 = BackgroundStarRenderer.drawSmallStarsLayer(mapRenderer, ss1, camera)
    end
    
    if layer2Visible then
        if StarShader and StarShader.setType then
            StarShader.setType(3)
        end
        count2 = BackgroundStarRenderer.drawSmallStarsLayer(mapRenderer, ss2, camera)
    end
    
    if (layer1Visible or layer2Visible) and ss1.config.useShaders and StarShader and StarShader.finish then
        StarShader.finish()
    end
    
    return count1 + count2
end

return BackgroundStarRenderer
