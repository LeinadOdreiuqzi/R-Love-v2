local HUD = require('src.ui.hud.core')

-- Panel de información de biomas optimizado (idéntico al original)
function HUD.drawBiomeInfoPanel()
    if not player or not BiomeSystem then return end
    
    local currentTime = love.timer.getTime()
    local scanInterval = hudState.performance.reducedUpdateMode and 2.0 or 1.0
    
    if not HUD.lastBiomeScan or currentTime - HUD.lastBiomeScan > scanInterval then
        HUD.nearbyBiomes = BiomeSystem.findNearbyBiomes(player.x, player.y, 10000)
        HUD.lastBiomeScan = currentTime
        
        if hudState.performance.enableCaching then
            hudState.renderCache.cachedBiomeInfo = HUD.nearbyBiomes
        end
    end
    
    local panelWidth = 300
    local panelHeight = 200
    local x = love.graphics.getWidth() - panelWidth - 10
    local y = 10
    
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    
    love.graphics.setColor(0.2, 0.6, 0.8, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    love.graphics.setColor(0.6, 0.9, 1, 1)
    love.graphics.setFont(hudState.font)
    love.graphics.print("BIOME SCANNER", x + 10, y + 8)
    
    love.graphics.setColor(0.7, 0.8, 1, 0.8)
    love.graphics.setFont(hudState.tinyFont)
    love.graphics.print("10km Radius", x + panelWidth - 60, y + 12)
    
    love.graphics.setColor(0.2, 0.6, 0.8, 0.8)
    love.graphics.line(x + 10, y + 28, x + panelWidth - 10, y + 28)
    
    local biomeInfo = biomeCache.currentBiomeInfo
    
    if biomeCache.debugInfo and not biomeInfo then
        love.graphics.setColor(1, 0.8, 0.2, 1)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("DEBUG INFO:", x + 10, y + 35)
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.setFont(hudState.tinyFont)
        local debugY = y + 50
        
        love.graphics.print("Player exists: " .. tostring(biomeCache.debugInfo.playerExists), x + 15, debugY)
        debugY = debugY + 12
        love.graphics.print("Player coords: " .. tostring(biomeCache.debugInfo.playerHasCoords), x + 15, debugY)
        debugY = debugY + 12
        love.graphics.print("BiomeSystem: " .. tostring(biomeCache.debugInfo.biomeSystemExists), x + 15, debugY)
        debugY = debugY + 12
        love.graphics.print("getPlayerBiomeInfo: " .. tostring(biomeCache.debugInfo.getPlayerBiomeInfoExists), x + 15, debugY)
        debugY = debugY + 12
        
        if biomeCache.debugInfo.playerCoords then
            love.graphics.print(string.format("Coords: (%.1f, %.1f)", 
                biomeCache.debugInfo.playerCoords.x, biomeCache.debugInfo.playerCoords.y), x + 15, debugY)
            debugY = debugY + 12
        end
        
        if biomeCache.lastError then
            love.graphics.setColor(1, 0.5, 0.5, 1)
            love.graphics.print("Error: " .. biomeCache.lastError, x + 15, debugY)
        end
    end
    
    if biomeInfo then
        local infoY = y + 35
        local lineHeight = 12
        
        local biomeColor = biomeInfo.config.color or {0.5, 0.5, 0.5, 1}
        love.graphics.setColor(biomeColor[1] + 0.3, biomeColor[2] + 0.3, biomeColor[3] + 0.3, 1)
        love.graphics.setFont(hudState.font)
        love.graphics.print("▶ " .. (biomeInfo.name or "Unknown"), x + 10, infoY)
        infoY = infoY + lineHeight + 2
        
        local rarityColors = {
            ["Very Common"] = {0.7, 0.7, 0.7, 1},
            ["Common"] = {0.8, 0.8, 0.8, 1},
            ["Uncommon"] = {0.6, 0.9, 0.6, 1},
            ["Rare"] = {0.6, 0.6, 1, 1},
            ["Very Rare"] = {0.9, 0.6, 1, 1},
            ["Legendary"] = {1, 0.8, 0.2, 1}
        }
        
        local rarityColor = rarityColors[biomeInfo.rarity] or {1, 1, 1, 1}
        love.graphics.setColor(rarityColor)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("Rarity: " .. (biomeInfo.rarity or "Unknown"), x + 15, infoY)
        infoY = infoY + lineHeight
        
        if biomeInfo.config and biomeInfo.config.properties then
            love.graphics.setColor(0.9, 0.9, 1, 1)
            love.graphics.print("PROPERTIES", x + 10, infoY)
            infoY = infoY + lineHeight + 2
            
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.setFont(hudState.tinyFont)
            
            local props = biomeInfo.config.properties
            love.graphics.print("Visibility: " .. string.format("%.1f", props.visibility or 1), x + 15, infoY)
            infoY = infoY + 10
            love.graphics.print("Mobility: " .. string.format("%.1f", props.mobility or 1), x + 15, infoY)
            infoY = infoY + 10
            love.graphics.print("Radiation: " .. string.format("%.1f", props.radiation or 0), x + 15, infoY)
            infoY = infoY + 10
            love.graphics.print("Gravity: " .. string.format("%.1f", props.gravity or 1), x + 15, infoY)
        end
        
        love.graphics.setColor(0.9, 1, 0.9, 1)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("LOCATION", x + 10, y + panelHeight - 30)
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.setFont(hudState.tinyFont)
        if biomeInfo.coordinates and biomeInfo.coordinates.chunk then
            love.graphics.print("Chunk: (" .. biomeInfo.coordinates.chunk.x .. ", " .. biomeInfo.coordinates.chunk.y .. ")", x + 15, y + panelHeight - 15)
        end
        
        local listY = infoY + 5
        local maxListHeight = y + panelHeight - listY - 30
        local maxVisibleItems = math.floor(maxListHeight / 12)
        
        love.graphics.setColor(0.6, 0.9, 1, 1)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("NEARBY BIOMES:", x + 10, listY)
        listY = listY + 15
        
        love.graphics.setFont(hudState.tinyFont)
        
        local itemsToShow = math.min(#HUD.nearbyBiomes, maxVisibleItems)
        for i = 1, itemsToShow do
            local biome = HUD.nearbyBiomes[i]
            local distance = math.floor(biome.distance / 100) * 100
            
            local stringKey = biome.name .. "_" .. distance
            local displayText = hudState.stringPool[stringKey]
            if not displayText then
                displayText = string.format("%s (%d m)", biome.name, distance)
                if #hudState.stringPool < hudState.performance.maxStringPoolSize then
                    hudState.stringPool[stringKey] = displayText
                end
            end
            
            local alpha = 1.0
            if distance > 8000 then
                alpha = 0.3 + 0.7 * (1 - math.min(1, (distance - 8000) / 2000))
            end
            
            love.graphics.setColor(0.8, 0.9, 1, alpha)
            love.graphics.print(displayText, x + 15, listY)
            listY = listY + 12
        end
        
        if biomeInfo.coordinates and biomeInfo.coordinates.chunk then
            love.graphics.setColor(0.6, 0.8, 0.6, 0.7)
            love.graphics.setFont(hudState.tinyFont)
            love.graphics.print(string.format("Chunk: (%d, %d)", 
                biomeInfo.coordinates.chunk.x, 
                biomeInfo.coordinates.chunk.y), 
                x + 10, y + panelHeight - 15)
        end
    else
        love.graphics.setColor(1, 0.5, 0.5, 1)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("Biome scanner offline", x + 10, y + 40)
        
        if HUD.nearbyBiomes then
            love.graphics.setColor(0.8, 0.4, 0.4, 1)
            love.graphics.setFont(hudState.tinyFont)
            love.graphics.print("Last known biomes:", x + 10, y + 60)
            
            for i = 1, math.min(#HUD.nearbyBiomes, 3) do
                local biome = HUD.nearbyBiomes[i]
                local distance = math.floor(biome.distance / 100) * 100
                love.graphics.print(string.format("%s (%d m)", biome.name, distance), 
                                  x + 20, y + 75 + (i-1)*12)
            end
        end
    end
end

return HUD