local HUD = require('src.ui.hud.core')

-- HUD del jugador (barras de vida, escudo, combustible) - CON SOPORTE EVA
function HUD.drawPlayerHUD()
    if not HUD.player then return end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    local hudY = screenHeight - 80
    local heartStartX = 20
    local barWidth = 200
    local barHeight = 12
    
    local r, g, b, a = love.graphics.getColor()
    local isInEVA = HUD.player.isInEVA or false
    
    HUD.drawHearts(heartStartX, hudY - 30)
    
    if isInEVA then
        love.graphics.setColor(1, 0.5, 0, 1)
        love.graphics.setFont(HUD.hudState.font)
        love.graphics.print("EVA MODE", heartStartX, hudY - 50)
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.setFont(HUD.hudState.tinyFont)
        love.graphics.print("Press E near ship to enter", heartStartX, hudY - 35)
    else
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.setFont(HUD.hudState.tinyFont)
        love.graphics.print("Hold S+E to exit ship", heartStartX, hudY - 35)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(HUD.hudState.smallFont)
    love.graphics.print("SHIELD", heartStartX, hudY)
    HUD.drawBar(heartStartX + 60, hudY + 2, barWidth, barHeight, 
                 HUD.player.stats:getShieldPercentage(), {0.2, 0.6, 1, 1}, {0.1, 0.3, 0.5, 0.8})
    
    if not isInEVA then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("FUEL", heartStartX, hudY + 20)
        HUD.drawBar(heartStartX + 60, hudY + 22, barWidth, barHeight, 
                     HUD.player.stats:getFuelPercentage(), {1, 0.8, 0.2, 1}, {0.5, 0.4, 0.1, 0.8})
    else
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("DISTANCE TO SHIP", heartStartX, hudY + 20)
        local distance = 0
        if HUD.player.evaPlayer and HUD.player.x and HUD.player.y then
            local dx = HUD.player.evaPlayer.x - HUD.player.x
            local dy = HUD.player.evaPlayer.y - HUD.player.y
            distance = math.sqrt(dx * dx + dy * dy)
        end
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print(string.format("%.1f units", distance), heartStartX + 60, hudY + 22)
    end
    
    love.graphics.setColor(r, g, b, a)
end

-- Dibujar corazones de vida - SIN CAMBIOS
function HUD.drawHearts(x, y)
    if not HUD.player or not HUD.player.stats or not HUD.player.stats.health then return end

    local heartSize = 16
    local heartSpacing = 20
    
    for i = 1, HUD.player.stats.health.maxHearts do
        local heartX = x + (i - 1) * heartSpacing
        
        if i <= HUD.player.stats.health.currentHearts then
            love.graphics.setColor(1, 0.2, 0.2, 1)
            HUD.drawHeart(heartX, y, heartSize, true)
        elseif i == HUD.player.stats.health.currentHearts + 1 and HUD.player.stats.health.heartHalves > 0 then
            love.graphics.setColor(1, 0.2, 0.2, 1)
            HUD.drawHeart(heartX, y, heartSize, false)
        else
            love.graphics.setColor(0.3, 0.1, 0.1, 1)
            HUD.drawHeartOutline(heartX, y, heartSize)
        end
    end
end

function HUD.drawHeart(x, y, size, full)
    local halfSize = size / 2
    
    if full then
        love.graphics.circle("fill", x + halfSize * 0.5, y + halfSize * 0.5, halfSize * 0.5)
        love.graphics.circle("fill", x + halfSize * 1.5, y + halfSize * 0.5, halfSize * 0.5)
        love.graphics.polygon("fill", 
            x, y + halfSize,
            x + halfSize, y + size,
            x + size, y + halfSize
        )
    else
        love.graphics.circle("fill", x + halfSize * 0.5, y + halfSize * 0.5, halfSize * 0.5)
        love.graphics.polygon("fill", 
            x, y + halfSize,
            x + halfSize, y + size,
            x + halfSize, y + halfSize
        )
        love.graphics.setColor(0.3, 0.1, 0.1, 1)
        love.graphics.circle("line", x + halfSize * 1.5, y + halfSize * 0.5, halfSize * 0.5)
        love.graphics.polygon("line", 
            x + halfSize, y + halfSize,
            x + size, y + halfSize,
            x + halfSize, y + size
        )
    end
end

function HUD.drawHeartOutline(x, y, size)
    local halfSize = size / 2
    love.graphics.circle("line", x + halfSize * 0.5, y + halfSize * 0.5, halfSize * 0.5)
    love.graphics.circle("line", x + halfSize * 1.5, y + halfSize * 0.5, halfSize * 0.5)
    love.graphics.polygon("line", 
        x, y + halfSize,
        x + halfSize, y + size,
        x + size, y + halfSize
    )
end

function HUD.drawBar(x, y, width, height, percentage, color, backgroundColor)
    love.graphics.setColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, width, height)
    if (percentage or 0) > 0 then
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        local fillWidth = (width - 2) * (percentage / 100)
        love.graphics.rectangle("fill", x + 1, y + 1, fillWidth, height - 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
    local text = string.format("%.0f%%", percentage or 0)
    local textWidth = HUD.hudState.smallFont:getWidth(text)
    love.graphics.setFont(HUD.hudState.smallFont)
    love.graphics.print(text, x + width/2 - textWidth/2, y - 1)
end

return HUD