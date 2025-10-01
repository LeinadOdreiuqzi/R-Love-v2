local HUD = require('src.ui.hud.core')

-- Input de semilla alfanumérica (COMPLETAMENTE NUEVO)
function HUD.drawSeedInput()
    local panelWidth = 500
    local panelHeight = 400
    local x = (love.graphics.getWidth() - panelWidth) / 2
    local y = (love.graphics.getHeight() - panelHeight) / 2
    
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    love.graphics.setColor(0.5, 0.7, 0.9, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(hudState.font)
    love.graphics.print("NEW ENHANCED GALAXY SEED", x + 20, y + 20)
    
    love.graphics.setFont(hudState.smallFont)
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.print("Alphanumeric Seeds: 5 letters + 5 digits mixed (e.g., A5B9C2D7E1)", x + 20, y + 45)
    love.graphics.print("36^10 = 3.6 trillion possible galaxies!", x + 20, y + 60)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Quick Select (Arrow Keys + Enter):", x + 20, y + 85)
    
    for i, preset in ipairs(presetSeeds) do
        local color = (i == currentPresetIndex) and {1, 1, 0.3, 1} or {0.8, 0.8, 0.8, 1}
        local prefix = (i == currentPresetIndex) and "> " or "  "
        love.graphics.setColor(color)
        love.graphics.print(prefix .. preset.name .. " (" .. preset.seed .. ")", x + 30, y + 100 + i * 15)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Custom Seed (10 characters: 5 letters + 5 digits):", x + 20, y + 280)
    
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", x + 20, y + 300, 460, 25)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.rectangle("line", x + 20, y + 300, 460, 25)
    
    love.graphics.setColor(1, 1, 1, 1)
    local displayText = hudState.seedInputText:upper()
    love.graphics.print(displayText, x + 25, y + 305)
    
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then
        local textWidth = hudState.font:getWidth(displayText)
        love.graphics.line(x + 25 + textWidth, y + 305, x + 25 + textWidth, y + 320)
    end
    
    local isValid = SeedSystem.validate(displayText)
    local validColor = isValid and {0.6, 1, 0.6, 1} or {1, 0.6, 0.6, 1}
    local validText = isValid and "✓ Valid Format" or "✗ Need 5 letters + 5 digits"
    love.graphics.setColor(validColor)
    love.graphics.print(validText, x + 25, y + 330)
    
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print(#displayText .. "/10 characters", x + 300, y + 330)
    
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print("Letters A-Z and digits 0-9 only • Enter to confirm • Escape to cancel", x + 20, y + 355)
    
    love.graphics.setColor(0.6, 0.8, 1, 1)
    love.graphics.print("Examples: A5B2C9D1E7, X3Y8Z2K6M4, F9R1T5G3H8", x + 20, y + 375)
end

function HUD.drawCurrentSeedInfo()
    if not gameState then return end
    
    local currentSeed = gameState.currentSeed or "UNKNOWN00"
    local text = "Seed: " .. currentSeed
    local textWidth = hudState.smallFont:getWidth(text)
    local x = love.graphics.getWidth() - textWidth - 15
    local y = love.graphics.getHeight() - 45
    
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", x - 8, y - 3, textWidth + 16, 42)
    love.graphics.setColor(0.3, 0.5, 0.7, 0.8)
    love.graphics.rectangle("line", x - 8, y - 3, textWidth + 16, 42)
    love.graphics.setColor(0.7, 1, 0.7, 1)
    love.graphics.setFont(hudState.smallFont)
    love.graphics.print(text, x, y)
    
    local isValid = SeedSystem.validate(currentSeed)
    local validColor = isValid and {0.6, 1, 0.6, 1} or {1, 0.8, 0.4, 1}
    local validText = isValid and "Alpha" or "Legacy"
    love.graphics.setColor(validColor)
    love.graphics.setFont(hudState.tinyFont)
    love.graphics.print("Type: " .. validText, x, y + 15)
end

function HUD.handleSeedInput(key)
    if key == "escape" then
        hudState.showSeedInput = false
        hudState.seedInputText = ""
    elseif key == "return" or key == "enter" then
        if hudState.seedInputText ~= "" then
            local normalizedSeed = SeedSystem.normalize(hudState.seedInputText)
            if SeedSystem.validate(normalizedSeed) then
                hudState.showSeedInput = false
                hudState.seedInputText = ""
                return normalizedSeed, "custom"
            else
                hudState.showSeedInput = false
                hudState.seedInputText = ""
                return normalizedSeed, "normalized"
            end
        else
            local selectedPreset = presetSeeds[currentPresetIndex]
            local selectedSeed = selectedPreset.seed
            if selectedPreset.name == "Random" then
                selectedSeed = SeedSystem.generate()
                selectedPreset.seed = selectedSeed
            end
            hudState.showSeedInput = false
            hudState.seedInputText = ""
            return selectedSeed, "preset"
        end
    elseif key == "backspace" then
        hudState.seedInputText = string.sub(hudState.seedInputText, 1, -2)
    elseif key == "up" then
        currentPresetIndex = math.max(1, currentPresetIndex - 1)
    elseif key == "down" then
        currentPresetIndex = math.min(#presetSeeds, currentPresetIndex + 1)
    end
    return nil, nil
end

function HUD.textinput(text)
    if hudState.showSeedInput then
        local upperText = text:upper()
        if upperText:match("[A-Z0-9]") and #hudState.seedInputText < 10 then
            hudState.seedInputText = hudState.seedInputText .. upperText
        end
    end
end

function HUD.showSeedInput()
    hudState.showSeedInput = true
    hudState.seedInputText = ""
    presetSeeds[1].seed = SeedSystem.generate()
end

function HUD.hideSeedInput()
    hudState.showSeedInput = false
    hudState.seedInputText = ""
end

return HUD