local Theme = require 'src.ui.combat_theme'

local Panel = {}
local panelHeight = 246

local function bounds()
    local width, height = love.graphics.getDimensions()
    local w = math.min(550, width - 24)
    return math.floor((width - w) / 2), math.max(8, math.floor((height - panelHeight) / 2)), w
end

local function backButton(x, y, w)
    return x + w - 105, y + 7, 93, 22
end

local function inside(mx, my, x, y, w, h)
    return mx >= x and mx < x + w and my >= y and my < y + h
end

local function damageRange(low, high)
    if low == high then return string.format('%.1f', low) end
    return string.format('%.1f–%.1f', low, high)
end

function Panel.draw(player)
    Theme.init()
    local g, colors = love.graphics, Theme.colors
    local x, y, w = bounds()
    local mx, my = love.mouse.getPosition()
    local config, stats = player.shipConfig, player.stats
    local resistance = math.min(100, math.max(0, (player.resistances or {}).collision or 0))
    local info = player.weaponSystem and player.weaponSystem:getCurrentWeaponInfo()
    local rows = {
        {'Casco máximo', config.maxHealth, stats.health.maxHealth, 'Corazón Auxiliar'},
        {'Escudo máximo', config.maxShield, stats.shield.maxShield, 'Capacidad del chasis'},
        {'Combustible máximo', config.maxFuel, stats.fuel.maxFuel, 'Capacidad del chasis'},
        {'Defensa ante choques', '0%', string.format('%g%%', resistance), 'Blindaje Reactivo'},
        {'Daño de referencia', info and damageRange(info.baseDamageMin, info.baseDamageMax) or '—',
            info and damageRange(info.damageMin, info.damageMax) or '—', 'Arma y equipo'},
        {'Cadencia (disp/s)', info and string.format('%.2f', info.baseFireRate) or '—',
            info and string.format('%.2f', info.fireRate) or '—', 'Arma y equipo'},
        {'Suerte', '—', '—', 'Sin efecto'}
    }
    local baseX, effectiveX, sourceX = x + w * .33, x + w * .53, x + w * .72

    g.push('all')
    Theme.panel(x, y, w, panelHeight, colors.active)
    g.setFont(Theme.title)
    g.setColor(colors.text)
    g.print('Estadísticas · ' .. config.name, x + 12, y + 10)
    g.setFont(Theme.small)
    local bx, by, bw, bh = backButton(x, y, w)
    Theme.panel(bx, by, bw, bh, colors.active, inside(mx, my, bx, by, bw, bh))
    g.setColor(colors.active)
    g.printf('Volver a carga', bx, by + 4, bw, 'center')

    g.setColor(colors.muted)
    g.print('Base', baseX, y + 38)
    g.print('Actual', effectiveX, y + 38)
    g.print('Fuente o mejora', sourceX, y + 38)
    for index, row in ipairs(rows) do
        local rowY = y + 52 + (index - 1) * 22
        g.setColor(.08, .17, .24, index % 2 == 0 and .52 or .24)
        g.rectangle('fill', x + 8, rowY, w - 16, 21, 3)
        g.setColor(colors.text)
        g.print(row[1], x + 12, rowY + 4)
        g.print(tostring(row[2]), baseX, rowY + 4)
        g.setColor(row[2] ~= row[3] and colors.active or colors.text)
        g.print(tostring(row[3]), effectiveX, rowY + 4)
        g.setColor(colors.muted)
        g.printf(row[4], sourceX, rowY + 4, x + w - 10 - sourceX)
    end

    if player.getCruiseStats then
        local speed, accel = player:getCruiseStats()
        g.setColor(colors.muted)
        g.print(string.format('Vel. máxima %.1f · Aceleración %.1f', speed, accel), x + 12, y + 215)
    end
    g.pop()
end

function Panel.isBackButton(mx, my)
    return inside(mx, my, backButton(bounds()))
end

return Panel
