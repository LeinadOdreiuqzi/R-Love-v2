local HUD = require('src.ui.hud.core')

-- Dibujar todo el HUD (idéntico al original)
function HUD.draw(inventoryOpen)
    local r, g, b, a = love.graphics.getColor()
    
    -- Asegurar estado de color neutro para el HUD (evita heredar fugas de proyectiles o efectos)
    love.graphics.setColor(1, 1, 1, 1)
    
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
    
    if HUD.player and HUD.player.weaponSystem then
        if inventoryOpen then
            love.graphics.setColor(1, 1, 1, 0.7)
        end
        local WeaponHUD = require 'src.ui.weapon_hud'
        WeaponHUD:draw(HUD.player)
        if inventoryOpen then
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    if HUD.hudState.stationHint and HUD.hudState.stationHint.enabled then
        HUD.drawStationHint()
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