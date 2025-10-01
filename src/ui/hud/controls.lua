local HUD = require('src.ui.hud.core')

function HUD.toggleInfo()
    hudState.showInfo = not hudState.showInfo
end

function HUD.toggleBiomeInfo()
    hudState.showBiomeInfo = not hudState.showBiomeInfo
    local status = hudState.showBiomeInfo and "ON" or "OFF"
    print("Biome info panel: " .. status)
end

function HUD.toggleDebugMenu()
    hudState.showDebugMenu = not hudState.showDebugMenu
    local status = hudState.showDebugMenu and "ON" or "OFF"
    print("Debug menu: " .. status)
end

function HUD.isSeedInputVisible()
    return hudState.showSeedInput
end

function HUD.isInfoVisible()
    return hudState.showInfo
end

function HUD.isBiomeInfoVisible()
    return hudState.showBiomeInfo
end

function HUD.drawDebugMenu()
    if love.keyboard.isDown("lshift") then
        print("[HUD DEBUG] Estado al renderizar:")
        print("  runState:", runState and "EXISTE" or "NIL")
        print("  gameDirector:", gameDirector and "EXISTE" or "NIL")
        if runState then
            print("  runState.currentSector:", runState.currentSector)
            print("  runState.distanceTraveled:", runState.distanceTraveled)
        end
        if gameDirector then
            print("  gameDirector.playerBoosting:", gameDirector.playerBoosting)
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
    love.graphics.setFont(hudState.font or love.graphics.getFont())
    love.graphics.print("DEBUG MENU (F5)", panelX + 10, panelY + 10)
    
    local yOffset = panelY + 40
    love.graphics.setFont(hudState.smallFont or love.graphics.getFont())
    love.graphics.setColor(0.8, 1, 0.8, 1)
    love.graphics.print("=== RUN STATE ===", panelX + 10, yOffset)
    
    yOffset = yOffset + 20
    love.graphics.setColor(1, 1, 1, 1)
    
    if runState then
        love.graphics.print("Current Sector: " .. (runState.sector or "N/A"), panelX + 10, yOffset)
        yOffset = yOffset + 15
        love.graphics.print("Phase: " .. (runState.phase or "N/A"), panelX + 10, yOffset)
        yOffset = yOffset + 15
        love.graphics.print("Distance: " .. string.format("%.1f", runState.meta.distanceTravelled or 0), panelX + 10, yOffset)
        yOffset = yOffset + 15
        love.graphics.print("Boosts Used: " .. (runState.meta.boostsUsed or 0), panelX + 10, yOffset)
        yOffset = yOffset + 15
        love.graphics.print("Time: " .. string.format("%.1fs", runState.time or 0), panelX + 10, yOffset)
        yOffset = yOffset + 15
        love.graphics.print("Debug Mode: " .. (runState.debug and "ON" or "OFF"), panelX + 10, yOffset)
    else
        love.graphics.print("RunState not available", panelX + 10, yOffset)
    end
    
    yOffset = yOffset + 30
    love.graphics.setColor(1, 0.8, 0.8, 1)
    love.graphics.print("=== GAME DIRECTOR ===", panelX + 10, yOffset)
    
    yOffset = yOffset + 20
    love.graphics.setColor(1, 1, 1, 1)
    
    if gameDirector then
        love.graphics.print("Player Boosting: " .. (gameDirector.playerActions.isBoosting and "YES" or "NO"), panelX + 10, yOffset)
        yOffset = yOffset + 15
        love.graphics.print("Player in Station: " .. (gameDirector.playerActions.isInStation and "YES" or "NO"), panelX + 10, yOffset)
        yOffset = yOffset + 15
        love.graphics.print("Debug Mode: " .. (gameDirector.debug and "ON" or "OFF"), panelX + 10, yOffset)
    else
        love.graphics.print("GameDirector not available", panelX + 10, yOffset)
    end
    
    yOffset = yOffset + 30
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.setFont(hudState.tinyFont or hudState.smallFont or love.graphics.getFont())
    love.graphics.print("Press F5 to toggle this menu", panelX + 10, yOffset)
end

return HUD