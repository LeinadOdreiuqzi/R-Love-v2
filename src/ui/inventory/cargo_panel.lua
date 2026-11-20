local Grid = require 'src.item_systems.cargo_grid'
local Theme = require 'src.ui.combat_theme'

local Panel = {padding = 4, header = 64, inset = 15}

function Panel.pitch(width, height, rows)
    return math.max(8, math.floor(math.min(52, (width - 88) / 8,
        (height - 154) / rows, (height - 236) / 6)))
end

-- Coordinates describe the first cell, in screen space, in both inventory views.
function Panel.rect(x, y, pitch, columns, anchor, w, h)
    return x + (anchor-1) % columns * pitch, y + math.floor((anchor-1) / columns) * pitch,
        (w or 1)*pitch - Panel.padding, (h or 1)*pitch - Panel.padding
end

function Panel.hit(x, y, pitch, columns, capacity, mx, my)
    local dx, dy = mx-x, my-y
    if dx < 0 or dy < 0 or dx >= columns*pitch-Panel.padding
        or dy >= math.ceil(capacity/columns)*pitch-Panel.padding then return end
    local cell = math.floor(dy/pitch)*columns + math.floor(dx/pitch) + 1
    if cell <= capacity then return cell end
end

function Panel.shipTitle(player)
    return player.shipConfig and player.shipConfig.name or player.inventory.shipType or 'Carga'
end

function Panel.draw(view, ui, style, player)
    local g, colors = love.graphics, style.colors
    local x, y, pitch, columns = view.x, view.y, view.pitch, view.columns
    local width = columns*pitch - Panel.padding + 2*Panel.inset
    local height = math.ceil(view.capacity/columns)*pitch - Panel.padding + Panel.header + 32
    local left, top = x-Panel.inset, y-Panel.header
    g.setColor(colors.panelBackground)
    g.rectangle('fill', left, top, width, height, 6, 6)
    g.setColor(colors.border[1], colors.border[2], colors.border[3], .4)
    g.rectangle('line', left, top, width, height, 6, 6)
    g.setColor(view.tint or colors.accent)
    g.setFont(style.titleFont)
    local scale = math.min(1, (width-2*Panel.inset)/math.max(1, style.titleFont:getWidth(view.title)))
    g.print(view.title, x, top+5, 0, scale, scale)
    local used = 0
    local mx, my = love.mouse.getPosition()
    local cell = Panel.hit(x,y,pitch,columns,view.capacity,mx,my)
    for i=1,view.capacity do
        local sx,sy,w,h = Panel.rect(x,y,pitch,columns,i)
        g.setColor(i == cell and colors.slotHover or colors.slotEmpty)
        g.rectangle('fill',sx,sy,w,h,6,6)
        g.setColor(colors.border[1],colors.border[2],colors.border[3],.3)
        g.rectangle('line',sx,sy,w,h,6,6)
    end
    for anchor, entry in pairs(view.items) do
        local w,h = Grid.dimensions(entry)
        used = used + w*h
        local sx,sy,sw,sh = Panel.rect(x,y,pitch,columns,anchor,w,h)
        if entry.hidden then
            Theme.panel(sx,sy,sw,sh,Theme.colors.muted)
            g.setFont(style.font)
            g.setColor(colors.textSecondary)
            g.printf('?',sx,sy+(sh-style.font:getHeight())/2,sw,'center')
            if entry.progress then g.rectangle('fill',sx+3,sy+sh-4,(sw-6)*entry.progress,2) end
        else
            local hovered = mx >= sx and my >= sy and mx < sx+sw and my < sy+sh
            Theme.panel(sx,sy,sw,sh,ui:getItemRarityColor(entry),hovered)
            local size = math.max(1,pitch-Panel.padding-8)
            ui:drawItem(sx+(sw-size)/2,sy+(sh-size)/2,size,entry,player)
        end
    end
    g.setFont(style.smallFont)
    g.setColor(colors.textSecondary)
    g.print((width >= 205 and '%d/%d celdas' or '%d/%d'):format(used,view.capacity),x,top+37)
    if view.hint then g.print(view.hint,x,top+height-22) end
end

return Panel
