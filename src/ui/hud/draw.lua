local HUD = require('src.ui.hud.core')

-- Dibujar todo el HUD (idéntico al original)
function HUD.draw(inventoryOpen)
    local r, g, b, a = love.graphics.getColor()
    
    if hudState.showInfo then
        HUD.drawUnifiedInfoPanel()
    end
    
    if hudState.showBiomeInfo then
        HUD.drawBiomeInfoPanel()
    end
    
    if hudState.showSeedInput then
        HUD.drawSeedInput()
    end
    
    HUD.drawCurrentSeedInfo()
    
    if player and player.stats then
        if inventoryOpen then
            love.graphics.setColor(1, 1, 1, 0.7)
        end
        HUD.drawPlayerHUD()
        if inventoryOpen then
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
    
    if player and player.weaponSystem then
        if inventoryOpen then
            love.graphics.setColor(1, 1, 1, 0.7)
        end
        WeaponHUD:draw(player)
        if inventoryOpen then
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    if hudState.stationHint and hudState.stationHint.enabled then
        HUD.drawStationHint()
    end
    
    HUD.drawPhaseVisualFeedback()
    
    if hudState.showDebugMenu then
        HUD.drawDebugMenu()
    end
    
    love.graphics.setColor(r, g, b, a)
end

return HUD