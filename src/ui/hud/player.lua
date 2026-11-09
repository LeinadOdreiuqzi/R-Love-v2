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
            g.setScissor( math.floor(sx), math.floor(sy), math.max(1, math.ceil(ex - sx)), math.max(1, math.ceil(ey - sy)) )
            g.polygon("fill", pts)
            g.setScissor()
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

-- HUD del jugador estilo Enter the Gungeon (Esquina superior izquierda: Corazones + Blasón de Escudo + Micro-barra de Combustible)
function HUD.drawPlayerHUD()
    if not HUD.player or not HUD.player.stats then return end

    local g = love.graphics
    local r, gr, b, a = g.getColor()
    local isInEVA = HUD.player.isInEVA or false

    local startX = 18
    local topY = 16
    local maxHearts = (HUD.player.stats.health and HUD.player.stats.health.maxHearts) or 3
    local heartSpacing = 22

    -- Placa translúcida sutil de respaldo para lectura limpia sobre nebulosas brillantes
    local shieldPipCount = 4
    local totalTopWidth = maxHearts * heartSpacing + 14 + shieldPipCount * 17 + 34
    g.setColor(0.015, 0.03, 0.055, 0.62)
    g.rectangle("fill", startX - 6, topY - 5, totalTopWidth, 48, 5, 5)
    g.setColor(0.22, 0.50, 0.68, 0.28)
    g.rectangle("line", startX - 6, topY - 5, totalTopWidth, 48, 5, 5)

    -- 1. Corazones de vida (arriba a la izquierda, estilo Gungeon)
    HUD.drawHearts(startX, topY)

    -- 2. Escudo junto a los corazones (Blasones segmentados estilo Armor de Enter the Gungeon)
    local shieldPct = math.max(0, math.min(100, HUD.player.stats:getShieldPercentage() or 0))
    local shieldStartX = startX + maxHearts * heartSpacing + 8
    local shieldColor = {0.25, 0.85, 1.0, 1.0}

    for i = 1, shieldPipCount do
        local segMin = (i - 1) * (100 / shieldPipCount)
        local segSpan = 100 / shieldPipCount
        local segFill = math.max(0, math.min(1, (shieldPct - segMin) / segSpan))
        drawShieldCrest(shieldStartX + (i - 1) * 16, topY, 12, segFill, shieldColor)
    end

    if HUD.hudState.tinyFont then g.setFont(HUD.hudState.tinyFont) end
    g.setColor(shieldPct > 0 and {0.65, 0.92, 1.0, 0.95} or {0.45, 0.55, 0.65, 0.75})
    g.print(string.format("%.0f%%", shieldPct), shieldStartX + shieldPipCount * 16 + 3, topY + 3)

    -- 3. Fila inferior compacta: Micro-barra de Combustible o Indicador EVA
    local subY = topY + 23
    if not isInEVA then
        local fuelPct = math.max(0, math.min(100, HUD.player.stats:getFuelPercentage() or 0))
        if HUD.hudState.tinyFont then g.setFont(HUD.hudState.tinyFont) end
        g.setColor(0.75, 0.82, 0.90, 0.85)
        g.print("FUEL", startX, subY)
        HUD.drawBar(startX + 32, subY + 2, 108, 7, fuelPct, {1.0, 0.78, 0.22, 0.95}, {0.12, 0.14, 0.18, 0.85}, false)

        g.setColor(0.55, 0.66, 0.76, 0.72)
        g.print("S+E: EVA", startX + 148, subY)
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

    g.setColor(r, gr, b, a)
end

-- Dibujar corazones de vida con acabado estilo Enter the Gungeon
function HUD.drawHearts(x, y)
    if not HUD.player or not HUD.player.stats or not HUD.player.stats.health then return end

    local heartSize = 16
    local heartSpacing = 22
    local maxHearts = HUD.player.stats.health.maxHearts or 3
    local curHearts = HUD.player.stats.health.currentHearts or 0
    local halves = HUD.player.stats.health.heartHalves or 0

    for i = 1, maxHearts do
        local heartX = x + (i - 1) * heartSpacing

        -- Sombra / base oscura del contenedor de corazón
        love.graphics.setColor(0.14, 0.04, 0.06, 0.85)
        HUD.drawHeart(heartX, y, heartSize, true)

        if i <= curHearts then
            love.graphics.setColor(0.96, 0.18, 0.24, 1)
            HUD.drawHeart(heartX, y, heartSize, true)
            -- Brillo especular estilo Gungeon
            love.graphics.setColor(1, 0.75, 0.78, 0.75)
            love.graphics.circle("fill", heartX + 4, y + 4, 1.6)
        elseif i == curHearts + 1 and halves > 0 then
            love.graphics.setColor(0.96, 0.18, 0.24, 1)
            HUD.drawHeart(heartX, y, heartSize, false)
            love.graphics.setColor(1, 0.75, 0.78, 0.75)
            love.graphics.circle("fill", heartX + 4, y + 4, 1.6)
        else
            love.graphics.setColor(0.38, 0.14, 0.18, 0.8)
            HUD.drawHeartOutline(heartX, y, heartSize)
        end
    end
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

function HUD.drawHeart(x, y, size, full)
    local g = love.graphics
    local pts = heartVertices(x, y, size)
    if full then
        g.polygon("fill", pts)
        g.setColor(0.55, 0.08, 0.12, 0.85)
        g.polygon("line", pts)
    else
        local sx, sy = g.transformPoint(x, y)
        local mx, my = g.transformPoint(x + size * 0.5, y + size)
        g.setScissor(math.floor(sx), math.floor(sy), math.max(1, math.ceil(mx - sx)), math.max(1, math.ceil(my - sy)))
        g.polygon("fill", pts)
        g.setScissor()
        g.setColor(0.45, 0.14, 0.18, 0.85)
        g.polygon("line", pts)
    end
end

function HUD.drawHeartOutline(x, y, size)
    love.graphics.polygon("line", heartVertices(x, y, size))
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