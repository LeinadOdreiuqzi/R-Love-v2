local HUD = require('src.ui.hud.core')

-- Actualizar aviso de entrada a estación (placeholder cercano en Ancient Ruins)
function HUD.updateStationHint(dt)
    local cfg = HUD.hudState.stationHint
    if not cfg or not cfg.enabled then return end

    -- Dependencias mínimas
    if not (HUD.player and HUD.player.x and HUD.player.y and HUD.Map and HUD.BiomeSystem) then return end

    local now = love.timer.getTime()
    if now - cfg.lastScan < cfg.scanInterval then return end
    cfg.lastScan = now

    -- Reset por defecto (solo cuando escaneamos)
    cfg.show = false
    cfg.placeholder = nil
    cfg.distance = math.huge

    -- Verificar bioma actual (usar cache si existe)
    local isAncient = false
    if HUD.biomeCache.currentBiome then
        isAncient = (HUD.biomeCache.currentBiome == (HUD.BiomeSystem.BiomeType and HUD.BiomeSystem.BiomeType.ANCIENT_RUINS))
    else
        local ok, info = pcall(function()
            return HUD.BiomeSystem.getPlayerBiomeInfo(HUD.player.x, HUD.player.y)
        end)
        if ok and info then
            isAncient = (info.type == (HUD.BiomeSystem.BiomeType and HUD.BiomeSystem.BiomeType.ANCIENT_RUINS))
        end
    end
    if not isAncient then return end

    -- Determinar bounds visibles usando la misma API que main.lua
    local bounds
    local World = require 'src.core.world'
    local okBounds, err = pcall(function()
        local camera = World.get('camera')
        bounds = HUD.Map.getVisibleChunkBounds(camera, cfg.scanMargin)
    end)
    if not okBounds or not bounds then return end

    local closest, minDist
    for cy = bounds.startY, bounds.endY do
        for cx = bounds.startX, bounds.endX do
            local chunk = HUD.Map.getChunkNonBlocking and HUD.Map.getChunkNonBlocking(cx, cy) or nil
            if chunk and chunk.ancientRuinsPlaceholders then
                for _, ph in ipairs(chunk.ancientRuinsPlaceholders) do
                    local targetX = (ph.dockingBay and ph.dockingBay.worldX) or (ph.x or 0)
                    local targetY = (ph.dockingBay and ph.dockingBay.worldY) or (ph.y or 0)
                    local dx, dy = targetX - HUD.player.x, targetY - HUD.player.y
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
        -- Usar helper centralizado para calcular el radio permitido (incluye daño + tipo base + dockingBay)
        local allowed = (HUD.computeEnterRadius and HUD.computeEnterRadius(closest, factor)) or math.huge
        
        if minDist <= allowed then
            cfg.show = true
            cfg.placeholder = closest
            cfg.distance = minDist

            -- Posición de pantalla para indicador centrada en la bahía de atraque
            local camera = World.get('camera')
            if camera and camera.worldToScreen then
                local targetX = (closest.dockingBay and closest.dockingBay.worldX) or (closest.x or 0)
                local targetY = (closest.dockingBay and closest.dockingBay.worldY) or (closest.y or 0)
                local sx, sy = camera:worldToScreen(targetX, targetY)
                cfg.screenX, cfg.screenY = sx, sy
            else
                cfg.screenX, cfg.screenY = love.graphics.getWidth() * 0.5, love.graphics.getHeight() * 0.5
            end
        end
    end
end

-- Helper: calcula el radio dinámico de entrada para una estación (basado en dockingBay)
function HUD.computeEnterRadius(placeholder, factorOverride)
    local cfg = HUD.hudState and HUD.hudState.stationHint or {}
    local factor = factorOverride or (cfg and cfg.enterRadiusFactor) or 1.25
    if not placeholder or not placeholder.size or placeholder.size <= 0 then
        return math.huge
    end

    local damageMultiplier = 1.0
    if placeholder.complexType then
        local _, state = tostring(placeholder.complexType):match("([^_]+)_([^_]+)")
        if state == "damaged" then
            damageMultiplier = 0.95
        elseif state == "ruins" then
            damageMultiplier = 0.85
        end
    end

    -- Si existe bahía de atraque dedicada, el radio se acopla al perímetro de atraque
    if placeholder.dockingBay then
        local dockRadius = placeholder.dockingBay.radius or 65
        return (dockRadius + 90) * factor * damageMultiplier
    end

    local baseMultiplier = 1.0
    if placeholder.complexType then
        local base = tostring(placeholder.complexType):match("([^_]+)_")
        if base == "ring" then baseMultiplier = 1.0
        elseif base == "modular" then baseMultiplier = 0.95
        elseif base == "elongated" then baseMultiplier = 1.1 end
    end

    return placeholder.size * factor * damageMultiplier * baseMultiplier
end

-- Getter público del factor de radio de entrada usado por el HUD
function HUD.getEnterRadiusFactor()
    if HUD.hudState and HUD.hudState.stationHint and HUD.hudState.stationHint.enterRadiusFactor then
        return HUD.hudState.stationHint.enterRadiusFactor
    end
    return 1.25
end

-- Dibujar aviso/indicador de estación con información de tipo y estado
function HUD.drawStationHint()
    local cfg = HUD.hudState.stationHint
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

    local mainFont = HUD.hudState.font or love.graphics.getFont()
    local smallFont = HUD.hudState.smallFont or mainFont
    
    local dockName = (placeholder.dockingBay and placeholder.dockingBay.name) or "DOCK-01"
    local prompt = "[E] ATRAQUE EN " .. dockName
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

-- Actualizar aviso de abordaje de nave (cuando el jugador está en EVA cerca de una nave)
function HUD.updateBoardingHint(dt)
    local cfg = HUD.hudState.boardingHint
    if not cfg or not cfg.enabled then return end

    local now = love.timer.getTime()
    if now - (cfg.lastScan or 0) < (cfg.scanInterval or 0.1) then return end
    cfg.lastScan = now

    cfg.show = false
    cfg.ship = nil
    cfg.distance = math.huge

    if not HUD.player or not HUD.player.isInEVA or not HUD.player.evaPlayer then
        return
    end

    local canEnter, targetShip = HUD.player.evaPlayer:canEnterShip()
    if canEnter and targetShip then
        cfg.show = true
        cfg.ship = targetShip
        local dx = HUD.player.evaPlayer.x - targetShip.x
        local dy = HUD.player.evaPlayer.y - targetShip.y
        cfg.distance = math.sqrt(dx * dx + dy * dy)
    end
end

-- Dibujar aviso de abordaje de nave en pantalla
function HUD.drawBoardingHint()
    local cfg = HUD.hudState.boardingHint
    if not cfg or not cfg.show or not cfg.ship then return end

    local ship = cfg.ship
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local t = love.timer.getTime()
    local pulse = 0.7 + 0.3 * math.sin(t * 6)

    local mainFont = HUD.hudState.font or love.graphics.getFont()
    local smallFont = HUD.hudState.smallFont or mainFont

    local shipType = ship.shipType or "EXPLORER"
    local shipName = ship.shipName or ("Nave #" .. (ship.shipId or 1))

    -- Colores temáticos según la clase de nave a abordar
    local themeColor = {0.2, 0.8, 1.0}
    if shipType == "FIGHTER" then
        themeColor = {1.0, 0.35, 0.2}
    elseif shipType == "CARGO" then
        themeColor = {0.95, 0.75, 0.15}
    end

    local prompt = "[E] ABORDAR " .. shipName:upper()
    local healthPct = (ship.stats and ship.stats.health) and math.floor(ship.stats.health.currentHealth) or 100
    local subText = string.format("Clase: %s | Casco: %d%% | Combustible: %d",
        shipType, healthPct, (ship.stats and ship.stats.fuel) and math.floor(ship.stats.fuel.currentFuel) or 0)

    love.graphics.setFont(mainFont)
    local promptW = mainFont:getWidth(prompt)
    local promptH = mainFont:getHeight()

    love.graphics.setFont(smallFont)
    local subW = smallFont:getWidth(subText)
    local subH = smallFont:getHeight()

    local maxW = math.max(promptW, subW)
    local totalH = promptH + subH + 12

    local px = (w - maxW) * 0.5
    local py = h - totalH - 45

    -- Fondo translúcido con esquinas redondeadas
    love.graphics.setColor(0.04, 0.06, 0.10, 0.85)
    love.graphics.rectangle("fill", px - 20, py - 8, maxW + 40, totalH + 16, 6, 6)

    -- Borde pulsante temático
    love.graphics.setColor(themeColor[1], themeColor[2], themeColor[3], 0.85 * pulse)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px - 20, py - 8, maxW + 40, totalH + 16, 6, 6)
    love.graphics.setLineWidth(1)

    -- Texto principal
    love.graphics.setFont(mainFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(prompt, px + (maxW - promptW) * 0.5, py)

    -- Subtexto de estadísticas
    love.graphics.setFont(smallFont)
    love.graphics.setColor(themeColor[1], themeColor[2], themeColor[3], 0.95)
    love.graphics.print(subText, px + (maxW - subW) * 0.5, py + promptH + 4)
end

return HUD