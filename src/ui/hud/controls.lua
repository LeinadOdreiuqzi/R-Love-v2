local HUD = require('src.ui.hud.core')

function HUD.toggleInfo()
    HUD.hudState.showInfo = not HUD.hudState.showInfo
end

function HUD.toggleBiomeInfo()
    HUD.hudState.showBiomeInfo = not HUD.hudState.showBiomeInfo
    local status = HUD.hudState.showBiomeInfo and "ON" or "OFF"
    print("Biome info panel: " .. status)
end

function HUD.toggleDebugMenu()
    HUD.hudState.showDebugMenu = not HUD.hudState.showDebugMenu
    local status = HUD.hudState.showDebugMenu and "ON" or "OFF"
    print("Debug menu: " .. status)
end

function HUD.isSeedInputVisible()
    return HUD.hudState.showSeedInput
end

function HUD.isInfoVisible()
    return HUD.hudState.showInfo
end

function HUD.isBiomeInfoVisible()
    return HUD.hudState.showBiomeInfo
end

function HUD.drawDebugMenu()
    if love.keyboard.isDown("lshift") then
        print("[HUD DEBUG] Estado al renderizar:")
        print("  runState:", HUD.runState and "EXISTE" or "NIL")
        print("  gameDirector:", HUD.gameDirector and "EXISTE" or "NIL")
        if HUD.runState then
            print("  runState.currentSector:", HUD.runState.currentSector)
            print("  runState.distanceTraveled:", HUD.runState.distanceTraveled)
        end
        if HUD.gameDirector then
            print("  gameDirector.playerBoosting:", HUD.gameDirector.playerBoosting)
        end
    end
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    local panelWidth = 400
    local panelHeight = 300
    local panelX = screenWidth - panelWidth - 20
    local panelY = 20
    
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight)
    love.graphics.setColor(0.3, 0.7, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(HUD.hudState.font or love.graphics.getFont())
    love.graphics.print("DEBUG MENU (F5)", panelX + 10, panelY + 10)
    
    local yOffset = panelY + 40
    love.graphics.setFont(HUD.hudState.smallFont or love.graphics.getFont())
    love.graphics.setColor(0.8, 1, 0.8, 1)
    love.graphics.print("=== RUN STATE ===", panelX + 10, yOffset)
    
    yOffset = yOffset + 20
    love.graphics.setColor(1, 1, 1, 1)
    
    if HUD.runState then
        love.graphics.print("Current Sector: " .. (HUD.runState.sector or "N/A"), panelX + 10, yOffset)
        yOffset = yOffset + 15
        love.graphics.print("Phase: " .. (HUD.runState.phase or "N/A"), panelX + 10, yOffset)
        yOffset = yOffset + 15
        love.graphics.print("Distance: " .. string.format("%.1f", HUD.runState.meta.distanceTravelled or 0), panelX + 10, yOffset)
        yOffset = yOffset + 15
        love.graphics.print("Boosts Used: " .. (HUD.runState.meta.boostsUsed or 0), panelX + 10, yOffset)
        yOffset = yOffset + 15
        love.graphics.print("Time: " .. string.format("%.1fs", HUD.runState.time or 0), panelX + 10, yOffset)
        yOffset = yOffset + 15
        love.graphics.print("Debug Mode: " .. (HUD.runState.debug and "ON" or "OFF"), panelX + 10, yOffset)
    else
        love.graphics.print("RunState not available", panelX + 10, yOffset)
    end
    
    yOffset = yOffset + 30
    love.graphics.setColor(1, 0.8, 0.8, 1)
    love.graphics.print("=== GAME DIRECTOR ===", panelX + 10, yOffset)
    
    yOffset = yOffset + 20
    love.graphics.setColor(1, 1, 1, 1)
    
    if HUD.gameDirector then
        love.graphics.print("Player Boosting: " .. (HUD.gameDirector.playerActions.isBoosting and "YES" or "NO"), panelX + 10, yOffset)
        yOffset = yOffset + 15
        love.graphics.print("Player in Station: " .. (HUD.gameDirector.playerActions.isInStation and "YES" or "NO"), panelX + 10, yOffset)
        yOffset = yOffset + 15
        love.graphics.print("Debug Mode: " .. (HUD.gameDirector.debug and "ON" or "OFF"), panelX + 10, yOffset)
    else
        love.graphics.print("GameDirector not available", panelX + 10, yOffset)
    end
    
    yOffset = yOffset + 30
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.setFont(HUD.hudState.tinyFont or HUD.hudState.smallFont or love.graphics.getFont())
    love.graphics.print("Press F5 to toggle this menu", panelX + 10, yOffset)
end

return HUD