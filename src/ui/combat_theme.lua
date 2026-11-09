local Theme = {
    colors = {active = {.25, .87, 1}, evolved = {.78, .53, 1}, recipe = {1, .73, .26},
        muted = {.57, .68, .76}, text = {.9, .96, 1}, danger = {1, .35, .38}}
}

function Theme.init()
    if Theme.font then return end
    Theme.font = love.graphics.newFont(12)
    Theme.small = love.graphics.newFont(10)
    Theme.title = love.graphics.newFont(14)
end

function Theme.panel(x, y, w, h, color, selected)
    local g = love.graphics
    color = color or Theme.colors.active
    g.setColor(.015, .035, .065, .84)
    g.rectangle('fill', x, y, w, h, 4)
    g.setColor(color[1], color[2], color[3], selected and .22 or .06)
    g.rectangle('fill', x, y, w, h, 4)
    g.setColor(color[1], color[2], color[3], selected and .85 or .3)
    g.setLineWidth(1)
    g.rectangle('line', x + .5, y + .5, w - 1, h - 1, 4)
    if selected then
        g.setColor(color[1], color[2], color[3], .12)
        g.rectangle('line', x - 2, y - 2, w + 4, h + 4, 5)
    end
end

function Theme.star(x, y, size)
    local points = {}
    for i = 0, 9 do
        local angle = -math.pi / 2 + i * math.pi / 5
        local radius = i % 2 == 0 and size or size * .45
        points[#points + 1], points[#points + 2] = x + math.cos(angle) * radius, y + math.sin(angle) * radius
    end
    love.graphics.polygon('fill', points)
end

function Theme.tooltip(player, data, mouseX, mouseY)
    Theme.init()
    local g = love.graphics
    local View = require 'src.ui.combat_presentation'
    local lines = View.tooltip(player, data)
    local width = math.min(350, g.getWidth() - 24)
    local sections = {{text = (data.name or data.id):gsub('★%s*', ''), kind = data.isEvolved and 'evolved' or 'text', font = Theme.title},
        {text = data.description or '', kind = 'muted', font = Theme.font}}
    for _, line in ipairs(lines) do sections[#sections + 1] = line end
    if data.value then
        sections[#sections + 1] = {text = 'Valor: ' .. data.value .. ' créditos'
            .. (data.weight and (' · Peso: ' .. data.weight) or ''), kind = 'muted'}
    end
    local height = 20
    for _, section in ipairs(sections) do
        section.text = section.text:gsub('★%s*', ''):gsub('→', '=>')
        section.font = section.font or Theme.small
        local _, wrapped = section.font:getWrap(section.text, width - 24)
        section.height = #wrapped * section.font:getHeight() + 8
        height = height + section.height
    end
    local scale = math.min(1, (g.getHeight() - 24) / height)
    local x = math.max(12, math.min(mouseX + 16, g.getWidth() - width * scale - 12))
    local y = math.max(12, math.min(mouseY + 16, g.getHeight() - height * scale - 12))
    g.push('all'); g.translate(x, y); g.scale(scale)
    Theme.panel(0, 0, width, height, Theme.colors.active, true)
    local top = 10
    for _, section in ipairs(sections) do
        g.setFont(section.font); g.setColor(Theme.colors[section.kind] or Theme.colors.text)
        if section.kind == 'evolved' then Theme.star(width - 9, top + 5, 4) end
        g.printf(section.text, 12, top, width - 24)
        top = top + section.height
    end
    g.pop()
    return {x = x, y = y, width = width * scale, height = height * scale}
end

return Theme
