local HUD = require('src.ui.hud.core')

-- Dibuja un blasón de escudo geométrico estilo Enter the Gungeon (Armor/Shield Crest)
local function drawShieldCrest(x, y, size, fillRatio, activeColor)
    local g = love.graphics
    local w, h = size, size * 1.12
    local cx = x + w * 0.5
    local pts = {
        x + 1, y + 2,
        cx, y,
        x + w - 1, y + 2,
        x + w - 1, y + h * 0.55,
        cx, y + h,
        x + 1, y + h * 0.55
    }
    -- Fondo oscuro del blasón
    g.setColor(0.05, 0.10, 0.16, 0.90)
    g.polygon("fill", pts)

    -- Relleno energético proporcional
    if fillRatio > 0 then
        g.setColor(activeColor[1], activeColor[2], activeColor[3], 0.30 + 0.65 * fillRatio)
        if fillRatio >= 0.99 then
            g.polygon("fill", pts)
        else
            local sx, sy = g.transformPoint(x, y + h * (1 - fillRatio))
            local ex, ey = g.transformPoint(x + w, y + h)
            g.push('all')
            g.intersectScissor(math.floor(sx), math.floor(sy), math.max(1, math.ceil(ex - sx)), math.max(1, math.ceil(ey - sy)))
            g.polygon("fill", pts)
            g.pop()
        end
        -- Brillo especular superior
        g.setColor(0.85, 0.97, 1.0, 0.55 * fillRatio)
        g.line(x + 3, y + 3, cx, y + 2)
    end

    -- Contorno nítido
    g.setLineWidth(1.2)
    if fillRatio > 0 then
        g.setColor(activeColor[1], activeColor[2], activeColor[3], 0.95)
    else
        g.setColor(0.28, 0.38, 0.48, 0.65)
    end
    g.polygon("line", pts)
    g.setLineWidth(1)
end

local HEART_COUNT, HEART_SPACING = 5, 19
local SHIELD_COUNT, SHIELD_SPACING = 4, 15

function HUD.drawPlayerHUD()
    if not HUD.player or not HUD.player.stats then return end

    local g = love.graphics
    local stats = HUD.player.stats
    local panelX, panelH = 16, 46
    local panelY = g.getHeight() - 16 - panelH
    local startX, topY = panelX + 6, panelY + 5
    local shieldStartX = startX + HEART_COUNT * HEART_SPACING + 12
    local shieldEndX = shieldStartX + (SHIELD_COUNT - 1) * SHIELD_SPACING + 12
    local panelW = shieldEndX - panelX + 8
    local now = love.timer.getTime()
    local hullHit = now - (stats.health.lastImpactTime or -math.huge) < .22
    local shieldHit = now - (stats.shield.lastImpactTime or -math.huge) < .22
    local hullPct = stats:getHealthPercentage()
    local shieldPct = stats:getShieldPercentage()

    g.push('all')
    if HUD.hudState.tinyFont then g.setFont(HUD.hudState.tinyFont) end
    g.setColor(0.015, 0.03, 0.055, 0.75)
    g.rectangle("fill", panelX, panelY, panelW, panelH, 5, 5)
    g.setColor(0.22, 0.50, 0.68, 0.36)
    g.rectangle("line", panelX, panelY, panelW, panelH, 5, 5)

    HUD.drawHearts(startX, topY, hullPct, hullHit)

    local shieldColor = shieldHit and {.72, .97, 1}
        or stats.shield.isRegenerating and {.36, 1, .88} or {.25, .85, 1}
    for i = 1, SHIELD_COUNT do
        local fill = math.max(0, math.min(1, shieldPct / 100 * SHIELD_COUNT - i + 1))
        drawShieldCrest(shieldStartX + (i - 1) * SHIELD_SPACING, topY, 12, fill, shieldColor)
    end
    if shieldHit or stats.shield.isRegenerating then
        g.setColor(shieldColor)
        g.line(shieldStartX, topY + 17, shieldEndX, topY + 17)
    end

    -- 3. Fila inferior compacta: Micro-barra de Combustible o Indicador EVA
    local subY = topY + 23
    if not HUD.player.isInEVA then
        local fuelPct = stats:getFuelPercentage()
        g.setColor(0.75, 0.82, 0.90, 0.85)
        g.print("COMB.", startX, subY)
        HUD.drawBar(startX + 33, subY + 2, 72, 7, fuelPct, {1.0, 0.78, 0.22, 0.95}, {0.12, 0.14, 0.18, 0.85}, false)

        g.setColor(0.55, 0.66, 0.76, 0.72)
        g.printf("S+E: EVA", startX, subY, shieldEndX - startX, "right")
    else
        if HUD.hudState.smallFont then g.setFont(HUD.hudState.smallFont) end
        g.setColor(1.0, 0.58, 0.18, 0.95)
        g.print("EVA", startX, subY - 1)
        local distance = 0
        if HUD.player.evaPlayer and HUD.player.x and HUD.player.y then
            local dx = HUD.player.evaPlayer.x - HUD.player.x
            local dy = HUD.player.evaPlayer.y - HUD.player.y
            distance = math.sqrt(dx * dx + dy * dy)
        end
        if HUD.hudState.tinyFont then g.setFont(HUD.hudState.tinyFont) end
        g.setColor(0.80, 0.88, 0.95, 0.90)
        g.print(string.format("Nave a %.0fu · [E] Entrar", distance), startX + 34, subY + 1)
    end

    g.pop()
end

local function heartVertices(x, y, size)
    local w, h = size, size * 0.95
    return {
        x + w * 0.50, y + h * 0.24,
        x + w * 0.68, y + h * 0.04,
        x + w * 0.90, y + h * 0.08,
        x + w * 1.00, y + h * 0.30,
        x + w * 0.94, y + h * 0.54,
        x + w * 0.50, y + h * 0.98,
        x + w * 0.06, y + h * 0.54,
        x + w * 0.00, y + h * 0.30,
        x + w * 0.10, y + h * 0.08,
        x + w * 0.32, y + h * 0.04
    }
end

function HUD.drawHearts(x, y, percentage, hit)
    local g = love.graphics
    local size = 15
    for i = 1, HEART_COUNT do
        local heartX = x + (i - 1) * HEART_SPACING
        local points = heartVertices(heartX, y, size)
        local fill = math.max(0, math.min(1, percentage / 100 * HEART_COUNT - i + 1))

        g.setColor(.17, .05, .08, .95)
        g.polygon("fill", points)
        if fill > 0 then
            g.setColor(hit and {1, .57, .62} or {.96, .20, .31})
            if fill < 1 then
                local sx, sy = g.transformPoint(heartX, y)
                local ex, ey = g.transformPoint(heartX + size * fill, y + size)
                g.push('all')
                g.intersectScissor(math.floor(sx), math.floor(sy),
                    math.max(1, math.floor(ex) - math.floor(sx)), math.ceil(ey) - math.floor(sy))
                g.polygon("fill", points)
                g.pop()
            else
                g.polygon("fill", points)
            end
        end
        g.setColor(hit and {.95, .55, .57, .95} or {.65, .24, .30, .9})
        g.polygon("line", points)
    end
end

function HUD.drawBar(x, y, width, height, percentage, color, backgroundColor, showLabel)
    love.graphics.setColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
    love.graphics.rectangle("fill", x, y, width, height, 2, 2)
    love.graphics.setColor(0.35, 0.52, 0.68, 0.45)
    love.graphics.rectangle("line", x, y, width, height, 2, 2)
    if (percentage or 0) > 0 then
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        local fillWidth = math.max(0, (width - 2) * (math.min(100, percentage) / 100))
        love.graphics.rectangle("fill", x + 1, y + 1, fillWidth, height - 2, 2, 2)
    end
    if showLabel ~= false and height >= 10 and HUD.hudState.smallFont then
        love.graphics.setColor(1, 1, 1, 1)
        local text = string.format("%.0f%%", percentage or 0)
        local textWidth = HUD.hudState.smallFont:getWidth(text)
        love.graphics.setFont(HUD.hudState.smallFont)
        love.graphics.print(text, x + width/2 - textWidth/2, y - 1)
    end
end

return HUD
