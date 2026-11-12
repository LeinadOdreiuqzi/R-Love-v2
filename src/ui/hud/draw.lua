local HUD = require('src.ui.hud.core')

function HUD.drawDefeat(cause)
    local g = love.graphics
    local Theme = require 'src.ui.combat_theme'
    Theme.init()
    local w, h = g.getDimensions()
    local panelW = math.min(380, w - 24)
    local x, y = (w - panelW) / 2, (h - 110) / 2
    g.push('all')
    g.origin()
    g.setColor(.015, .025, .045, .84)
    g.rectangle('fill', 0, 0, w, h)
    Theme.panel(x, y, panelW, 110, Theme.colors.danger)
    g.setFont(Theme.title)
    g.setColor(Theme.colors.danger)
    g.printf('Nave destruida', x + 12, y + 14, panelW - 24, 'center')
    g.setFont(Theme.font)
    g.setColor(Theme.colors.text)
    g.printf(cause, x + 12, y + 39, panelW - 24, 'center')
    g.setColor(Theme.colors.active)
    g.printf('[Enter] Nueva salida con la misma semilla', x + 12, y + 76, panelW - 24, 'center')
    g.pop()
end

-- Dibuja pulsos diegéticos de horizonte en el borde de la pantalla cuando hay encuentros,
-- flotas nodrizas o choques de escuadrones ocurriendo fuera de cámara (950px - 2350px).
function HUD.drawHorizonSignals()
    local player = HUD.player
    if not player then return end
    local Naves = package.loaded['src.entities.naves']
    if not Naves or not Naves.getAllShips then return end

    local activeEnt = (player.getActiveEntity and player:getActiveEntity()) or player
    local px, py = activeEnt.x or player.x or 0, activeEnt.y or player.y or 0
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local cx, cy = sw * 0.5, sh * 0.5
    local margin = 38
    local rx = cx - margin
    local ry = cy - margin
    local t = love.timer and love.timer.getTime and love.timer.getTime() or 0

    local ships = Naves.getAllShips()
    local bins = {}

    for i = 1, #ships do
        local s = ships[i]
        if s and s ~= player and not s.isPiloted and not s.isDestroyed and s.isAI and s.aiController and s.aiController.active then
            local dx = (s.x or 0) - px
            local dy = (s.y or 0) - py
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist >= 920 and dist <= 2350 then
                local angle = math.atan2(dy, dx)
                local binKey = math.floor((angle + math.pi) / 0.30)
                local b = bins[binKey]
                local ai = s.aiController
                local isCombat = (ai.state == "COMBAT")
                local isMothership = (s.shipConfig and s.shipConfig.isMothership) or false
                if not b then
                    bins[binKey] = {
                        angle = angle,
                        minDist = dist,
                        count = 1,
                        isCombat = isCombat,
                        isMothership = isMothership,
                        color = (ai.config and ai.config.beaconColor) or {0.35, 0.85, 1.0}
                    }
                else
                    b.count = b.count + 1
                    if dist < b.minDist then
                        b.minDist = dist
                        b.angle = angle
                    end
                    if isCombat then b.isCombat = true end
                    if isMothership then
                        b.isMothership = true
                        b.color = (ai.config and ai.config.beaconColor) or b.color
                    end
                end
            end
        end
    end

    for _, b in pairs(bins) do
        local proximity = 1.0 - math.max(0, math.min(1, (b.minDist - 920) / (2350 - 920)))
        local freq = b.isCombat and 11.0 or (b.isMothership and 5.0 or 3.2)
        local pulse = 0.45 + 0.55 * math.abs(math.sin(t * freq + b.angle))
        local alpha = (0.28 + 0.52 * proximity) * pulse

        local cosA, sinA = math.cos(b.angle), math.sin(b.angle)
        local ix = cx + cosA * rx
        local iy = cy + sinA * ry

        love.graphics.push()
        love.graphics.translate(ix, iy)
        love.graphics.rotate(b.angle)

        local col = b.isCombat and {1.0, 0.28, 0.35} or b.color
        love.graphics.setColor(col[1], col[2], col[3], alpha)

        -- Chevron direccional de sensor
        local sz = (b.isMothership or b.count >= 4) and 9.5 or 6.5
        love.graphics.setLineWidth(b.isMothership and 2.5 or 1.8)
        love.graphics.line(-sz, -sz * 0.85, 0, 0, -sz, sz * 0.85)

        -- Si es una flota grande o combate múltiple, dibujar segundo chevron concéntrico
        if b.count >= 3 or b.isMothership then
            love.graphics.setColor(col[1], col[2], col[3], alpha * 0.75)
            love.graphics.line(-sz * 1.65, -sz * 0.65, -sz * 0.85, 0, -sz * 1.65, sz * 0.65)
        end

        love.graphics.setLineWidth(1)
        love.graphics.pop()
    end
end

-- Dibujar todo el HUD (idéntico al original)
function HUD.draw(inventoryOpen)
    local r, g, b, a = love.graphics.getColor()
    
    -- Asegurar estado de color neutro para el HUD (evita heredar fugas de proyectiles o efectos)
    love.graphics.setColor(1, 1, 1, 1)

    if HUD.hudState.phaseVisualsEnabled then
        HUD.drawHorizonSignals()
    end
    
    if HUD.hudState.showInfo then
        HUD.drawUnifiedInfoPanel()
    end
    
    if HUD.hudState.showBiomeInfo then
        HUD.drawBiomeInfoPanel()
    end
    
    if HUD.hudState.showSeedInput then
        HUD.drawSeedInput()
    end
    
    HUD.drawCurrentSeedInfo()
    
    if HUD.player and HUD.player.stats then
        if inventoryOpen then
            love.graphics.setColor(1, 1, 1, 0.7)
        end
        HUD.drawPlayerHUD()
        if inventoryOpen then
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
    
    if not inventoryOpen and HUD.player and HUD.player.weaponSystem then
        local WeaponHUD = require 'src.ui.weapon_hud'
        WeaponHUD:draw(HUD.player, inventoryOpen)
    end

    if HUD.hudState.stationHint and HUD.hudState.stationHint.enabled then
        HUD.drawStationHint()
    end
    
    if HUD.hudState.boardingHint and HUD.hudState.boardingHint.enabled and HUD.drawBoardingHint then
        HUD.drawBoardingHint()
    end
    
    if HUD.hudState.phaseVisualsEnabled then
        HUD.drawPhaseVisualFeedback()
    end
    
    if HUD.hudState.showDebugMenu then
        HUD.drawDebugMenu()
    end
    
    love.graphics.setColor(r, g, b, a)
end

return HUD
