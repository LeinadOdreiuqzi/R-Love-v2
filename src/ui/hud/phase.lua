local HUD = require('src.ui.hud.core')

-- Feedback visual del sistema de fases (idéntico al original)
function HUD.drawPhaseVisualFeedback()
    local phaseInfo = nil
    pcall(function()
        local PhaseSystem = require 'src.gameplay.phase_system'
        if PhaseSystem and PhaseSystem.getHUDInfo then
            phaseInfo = PhaseSystem.getHUDInfo()
        end
    end)
    
    if not phaseInfo then return end
    
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local t = love.timer.getTime()
    
    if phaseInfo.status == "Near boundary" or phaseInfo.status == "At boundary" then
        local pulseSpeed = phaseInfo.status == "At boundary" and 6 or 3
        local pulse = 0.3 + 0.7 * math.abs(math.sin(t * pulseSpeed))
        
        local r, g, b = 1, 1, 0.3
        if phaseInfo.status == "At boundary" then
            r, g, b = 1, 0.3, 0.3
        end
        
        local borderWidth = 8
        love.graphics.setColor(r, g, b, pulse * 0.6)
        love.graphics.rectangle("fill", 0, 0, w, borderWidth)
        love.graphics.rectangle("fill", 0, h - borderWidth, w, borderWidth)
        love.graphics.rectangle("fill", 0, 0, borderWidth, h)
        love.graphics.rectangle("fill", w - borderWidth, 0, borderWidth, h)
        
        local warningText = phaseInfo.status == "At boundary" and "PHASE BOUNDARY REACHED!" or "APPROACHING PHASE BOUNDARY"
        local font = hudState.font or love.graphics.getFont()
        local textWidth = font:getWidth(warningText)
        local textHeight = font:getHeight()
        
        local msgPadding = 20
        local msgX = (w - textWidth) * 0.5 - msgPadding
        local msgY = 40
        local msgW = textWidth + msgPadding * 2
        local msgH = textHeight + msgPadding
        
        love.graphics.setColor(0, 0, 0, pulse * 0.8)
        love.graphics.rectangle("fill", msgX, msgY, msgW, msgH, 8, 8)
        love.graphics.setColor(r, g, b, pulse)
        love.graphics.rectangle("line", msgX, msgY, msgW, msgH, 8, 8)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.setFont(font)
        love.graphics.print(warningText, msgX + msgPadding, msgY + msgPadding * 0.5)
        
        if phaseInfo.distanceToBoundary then
            local distText = "Distance: " .. phaseInfo.distanceToBoundary
            local distWidth = font:getWidth(distText)
            love.graphics.setColor(1, 1, 1, pulse * 0.9)
            love.graphics.print(distText, (w - distWidth) * 0.5, msgY + msgH + 5)
        end
    end
    
    if phaseInfo.showUnlockPrompt then
        local pulse = 0.4 + 0.6 * math.abs(math.sin(t * 2))
        
        local unlockText = "PRESS E TO UNLOCK FULL MAP!"
        local subText = "Final phase boundary reached"
        local font = hudState.font or love.graphics.getFont()
        local smallFont = hudState.smallFont or font
        
        local mainWidth = font:getWidth(unlockText)
        local subWidth = smallFont:getWidth(subText)
        local maxWidth = math.max(mainWidth, subWidth)
        
        local msgPadding = 30
        local msgX = (w - maxWidth) * 0.5 - msgPadding
        local msgY = h * 0.33
        local msgW = maxWidth + msgPadding * 2
        local msgH = font:getHeight() + smallFont:getHeight() + msgPadding * 1.5
        
        love.graphics.setColor(0, 0.2, 0.4, pulse * 0.9)
        love.graphics.rectangle("fill", msgX, msgY, msgW, msgH, 12, 12)
        love.graphics.setColor(0.2, 0.8, 1, pulse)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", msgX, msgY, msgW, msgH, 12, 12)
        love.graphics.setLineWidth(1)
        
        love.graphics.setColor(0.8, 1, 1, 1)
        love.graphics.setFont(font)
        love.graphics.print(unlockText, (w - mainWidth) * 0.5, msgY + msgPadding * 0.5)
        
        love.graphics.setColor(0.6, 0.9, 1, 0.8)
        love.graphics.setFont(smallFont)
        love.graphics.print(subText, (w - subWidth) * 0.5, msgY + font:getHeight() + msgPadding * 0.8)
        
        for i = 1, 8 do
            local angle = (t * 2 + i * math.pi / 4) % (math.pi * 2)
            local radius = 60 + 20 * math.sin(t * 3 + i)
            local px = w * 0.5 + math.cos(angle) * radius
            local py = msgY + msgH * 0.5 + math.sin(angle) * radius * 0.5
            
            love.graphics.setColor(0.4, 0.8, 1, pulse * 0.7)
            love.graphics.circle("fill", px, py, 3)
        end
    end
    
    if phaseInfo.mapFullyUnlocked then
        local fadeTime = 3.0
        local alpha = math.max(0, 1 - (t % 10) / fadeTime)
        
        if alpha > 0 then
            local celebrationText = "MAP FULLY UNLOCKED!"
            local subText = "Infinite exploration enabled"
            local font = hudState.font or love.graphics.getFont()
            local smallFont = hudState.smallFont or font
            
            local mainWidth = font:getWidth(celebrationText)
            local subWidth = smallFont:getWidth(subText)
            
            love.graphics.setColor(0.2, 1, 0.2, alpha * 0.9)
            love.graphics.setFont(font)
            love.graphics.print(celebrationText, (w - mainWidth) * 0.5, 18)
            
            love.graphics.setColor(0.6, 1, 0.6, alpha * 0.7)
            love.graphics.setFont(smallFont)
            love.graphics.print(subText, (w - subWidth) * 0.5, 18 + font:getHeight() + 4)
        end
    end
    
    if phaseInfo.recentExpansion then
        local progress = 1 - (phaseInfo.expansionTimer / 3.0)
        local pulse = 0.5 + 0.5 * math.sin(t * 4)
        local alpha = math.max(0, 1 - progress * 0.7)
        
        local expansionText = "PHASE " .. phaseInfo.lastExpandedPhase .. " UNLOCKED!"
        local subText = "New area available for exploration"
        local font = hudState.font or love.graphics.getFont()
        local smallFont = hudState.smallFont or font
        
        local mainWidth = font:getWidth(expansionText)
        local subWidth = smallFont:getWidth(subText)
        
        local msgX = (w - mainWidth) * 0.5
        local msgY = h * 0.53
        
        love.graphics.setColor(0.2, 0.8, 1, alpha)
        love.graphics.setFont(font)
        love.graphics.print(expansionText, msgX, msgY)
        
        love.graphics.setColor(0.6, 0.9, 1, alpha * 0.8)
        love.graphics.setFont(smallFont)
        love.graphics.print(subText, (w - subWidth) * 0.5, msgY + font:getHeight() + 5)
        
        for i = 1, 6 do
            local angle = (t * 2 + i * math.pi / 3) % (math.pi * 2)
            local radius = 50 + 15 * math.sin(t * 3 + i)
            local px = w * 0.5 + math.cos(angle) * radius
            local py = msgY + math.sin(angle) * radius * 0.5
            
            love.graphics.setColor(0.4, 0.8, 1, alpha * 0.6)
            love.graphics.circle("fill", px, py, 2 + pulse)
        end
    end
end

return HUD