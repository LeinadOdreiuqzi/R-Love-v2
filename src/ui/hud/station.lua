local HUD = require('src.ui.hud.core')

-- Actualizar aviso de entrada a estación (placeholder cercano en Ancient Ruins)
function HUD.updateStationHint(dt)
    local cfg = hudState.stationHint
    if not cfg or not cfg.enabled then return end

    -- Dependencias mínimas
    if not (player and player.x and player.y and Map and BiomeSystem) then return end

    local now = love.timer.getTime()
    if now - cfg.lastScan < cfg.scanInterval then return end
    cfg.lastScan = now

    -- Reset por defecto (solo cuando escaneamos)
    cfg.show = false
    cfg.placeholder = nil
    cfg.distance = math.huge

    -- Verificar bioma actual (usar cache si existe)
    local isAncient = false
    if biomeCache.currentBiome then
        isAncient = (biomeCache.currentBiome == (BiomeSystem.BiomeType and BiomeSystem.BiomeType.ANCIENT_RUINS))
    else
        local ok, info = pcall(function()
            return BiomeSystem.getPlayerBiomeInfo(player.x, player.y)
        end)
        if ok and info then
            isAncient = (info.type == (BiomeSystem.BiomeType and BiomeSystem.BiomeType.ANCIENT_RUINS))
        end
    end
    if not isAncient then return end

    -- Determinar bounds visibles usando la misma API que main.lua
    local bounds
    local okBounds, err = pcall(function()
        bounds = Map.getVisibleChunkBounds(_G.camera, cfg.scanMargin)
    end)
    if not okBounds or not bounds then return end

    local closest, minDist
    for cy = bounds.startY, bounds.endY do
        for cx = bounds.startX, bounds.endX do
            local chunk = Map.getChunkNonBlocking and Map.getChunkNonBlocking(cx, cy) or nil
            if chunk and chunk.ancientRuinsPlaceholders then
                for _, ph in ipairs(chunk.ancientRuinsPlaceholders) do
                    local dx, dy = (ph.x or 0) - player.x, (ph.y or 0) - player.y
                    local dist = math.sqrt(dx*dx + dy*dy)
                    if not minDist or dist < minDist then
                        closest, minDist = ph, dist
                    end
                end
            end
        end
    end

    if closest and minDist then
        local factor = cfg.enterRadiusFactor or 1.25
        -- Usar helper centralizado para calcular el radio permitido (incluye daño + tipo base)
        local allowed = (HUD.computeEnterRadius and HUD.computeEnterRadius(closest, factor)) or math.huge
        
        if minDist <= allowed then
            cfg.show = true
            cfg.placeholder = closest
            cfg.distance = minDist

            -- Posición de pantalla para indicador
            if _G.camera and _G.camera.worldToScreen then
                local sx, sy = _G.camera:worldToScreen(closest.x or 0, closest.y or 0)
                cfg.screenX, cfg.screenY = sx, sy
            else
                cfg.screenX, cfg.screenY = love.graphics.getWidth() * 0.5, love.graphics.getHeight() * 0.5
            end
        end
    end
end

-- Nuevo helper: calcula el radio dinámico de entrada para una estación
function HUD.computeEnterRadius(placeholder, factorOverride)
    local cfg = hudState and hudState.stationHint or {}
    local factor = factorOverride or (cfg and cfg.enterRadiusFactor) or 1.25
    if not placeholder or not placeholder.size or placeholder.size <= 0 then
        return math.huge
    end

    local baseMultiplier = 1.0
    local damageMultiplier = 1.0

    if placeholder.complexType then
        local base, state = tostring(placeholder.complexType):match("([^_]+)_([^_]+)")
        -- Ajuste por tipo base
        if base == "ring" then
            baseMultiplier = 1.0
        elseif base == "modular" then
            baseMultiplier = 0.95
        elseif base == "elongated" then
            baseMultiplier = 1.1
        end
        -- Ajuste por estado de daño
        if state == "damaged" then
            damageMultiplier = 0.9
        elseif state == "ruins" then
            damageMultiplier = 0.7
        else
            damageMultiplier = 1.0
        end
    end

    return placeholder.size * factor * damageMultiplier * baseMultiplier
end

-- Getter público del factor de radio de entrada usado por el HUD
function HUD.getEnterRadiusFactor()
    if hudState and hudState.stationHint and hudState.stationHint.enterRadiusFactor then
        return hudState.stationHint.enterRadiusFactor
    end
    return 1.25
end

-- Dibujar aviso/indicador de estación con información de tipo y estado
function HUD.drawStationHint()
    local cfg = hudState.stationHint
    if not cfg or not cfg.show or not cfg.placeholder then return end

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local placeholder = cfg.placeholder

    local t = love.timer.getTime()
    local pulse = 0.5 + 0.5 * math.sin(t * 4)

    local stationType = "Unknown"
    local stationState = "Unknown"
    local typeColor = {0.7, 0.7, 0.7}
    local stateColor = {0.7, 0.7, 0.7}
    
    if placeholder.complexType then
        local base, state = tostring(placeholder.complexType):match("([^_]+)_([^_]+)")
        if base and state then
            if base == "ring" then
                stationType = "Ring Station"
                typeColor = {0.3, 0.8, 1.0}
            elseif base == "modular" then
                stationType = "Modular Station"
                typeColor = {0.8, 0.6, 1.0}
            elseif base == "elongated" then
                stationType = "Elongated Station"
                typeColor = {1.0, 0.7, 0.3}
            end
            
            if state == "operational" then
                stationState = "Operational"
                stateColor = {0.3, 1.0, 0.3}
            elseif state == "damaged" then
                stationState = "Damaged"
                stateColor = {1.0, 0.8, 0.2}
            elseif state == "ruins" then
                stationState = "Ruins"
                stateColor = {1.0, 0.4, 0.2}
            end
        end
    end

    local mainFont = hudState.font or love.graphics.getFont()
    local smallFont = hudState.smallFont or mainFont
    
    local prompt = "Presiona E para entrar"
    local typeText = "Tipo: " .. stationType
    local stateText = "Estado: " .. stationState
    
    love.graphics.setFont(mainFont)
    local promptWidth = mainFont:getWidth(prompt)
    local promptHeight = mainFont:getHeight()
    
    love.graphics.setFont(smallFont)
    local typeWidth = smallFont:getWidth(typeText)
    local stateWidth = smallFont:getWidth(stateText)
    local infoHeight = smallFont:getHeight()
    
    local maxWidth = math.max(promptWidth, typeWidth, stateWidth)
    local totalHeight = promptHeight + infoHeight * 2 + 16
    
    local px = (w - maxWidth) * 0.5
    local py = h - totalHeight - 30
    
    love.graphics.setColor(0, 0, 0, 0.7 * (0.6 + 0.4 * pulse))
    love.graphics.rectangle("fill", px - 16, py - 8, maxWidth + 32, totalHeight + 16, 8, 8)
    
    love.graphics.setColor(0.2, 0.8, 1.0, 1)
    love.graphics.rectangle("line", px - 16, py - 8, maxWidth + 32, totalHeight + 16, 8, 8)
    
    love.graphics.setFont(mainFont)
    love.graphics.setColor(0.85, 1.0, 1.0, 1)
    love.graphics.print(prompt, px + (maxWidth - promptWidth) * 0.5, py)
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], 0.9)
    love.graphics.print(typeText, px + (maxWidth - typeWidth) * 0.5, py + promptHeight + 4)
    
    love.graphics.setColor(stateColor[1], stateColor[2], stateColor[3], 0.9)
    love.graphics.print(stateText, px + (maxWidth - stateWidth) * 0.5, py + promptHeight + infoHeight + 8)
end

return HUD