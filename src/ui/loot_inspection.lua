local Loot = require 'src.gameplay.loot'
local Items = require 'src.item_systems.item_system'
local Theme = require 'src.ui.combat_theme'
local Grid = require 'src.item_systems.cargo_grid'

local Art = require 'src.rendering.loot_art'

local Inspection = {}
Inspection.__index = Inspection

function Inspection.new(player, run, targets)
    return setmetatable({player = player, run = run, targets = targets, boxes = {}, message = ''}, Inspection)
end

function Inspection:collectKey()
    local added = self.player.inventory:addItemToCompartment('ship', Items:getItem(Loot.roomKeyId), 1)
    self.message = added and 'Llave añadida a la carga.' or 'Carga llena.'
    return added
end

local offsets = {-108, -36, 36, 108}
local searchTime = .48

function Inspection:spawnBoxes(target, settled)
    local room = self.run.lootRooms[target.id]
    -- Older saves ejected from the fixed site centre.
    local x = room.releaseX or target.anchorX or target.x
    local y = room.releaseY or target.anchorY or target.y
    for index = 1, Loot.getBoxCount(self.run, target.id) do
        local items,revealed,capacity = Loot.getBox(self.run,target.id,index)
        local box = {
            room = target.id, index = index, x = x, y = y, capacity = capacity,
            opening = (room[index].opened or revealed > 0 or #items == 0) and 1 or 0,
            originX = x, originY = y,
            endX = x + offsets[index], endY = y - 120,
            color = target.color, name = 'Caja ' .. index .. ' · ' .. target.name,
            age = settled and .65 or 0, search = 0
        }
        if settled then box.x, box.y = box.endX, box.endY end
        self.boxes[#self.boxes + 1] = box
    end
end

local function distanceSquared(player, target)
    return (player.x - target.x)^2 + (player.y - target.y)^2
end

function Inspection:nearby()
    local choice, distance = nil, 90^2
    for _, target in ipairs(self.targets) do
        local d = distanceSquared(self.player, target)
        if d < distance then choice, distance = target, d end
    end
    for _, box in ipairs(self.boxes) do
        local d = distanceSquared(self.player, box)
        if box.age >= .65 and d < distance then choice, distance = box, d end
    end
    return choice
end

function Inspection:update(dt)
    for _,target in ipairs(self.targets) do
        if target.id and not target.drawWorld then
            target.anchorX = target.anchorX or target.x
            target.anchorY = target.anchorY or target.y
            local phase = love.timer.getTime()*.14 + target.anchorX*.011 + target.anchorY*.019
            target.x = target.anchorX + 12*math.sin(phase)
            target.y = target.anchorY + 7*math.cos(phase*.8)
            target.roll = .065*math.sin(phase*.7)
            if target.unsealing then target.unsealing = math.min(1,target.unsealing+dt/.35) end
        end
    end
    for _, box in ipairs(self.boxes) do
        if self.run.lootRooms[box.room][box.index].opened then
            box.opening = math.min(1,box.opening+dt/.42)
        end
        if box.age < .65 then
            box.age = math.min(.65, box.age + dt)
            local t = 1 - (1 - box.age / .65)^3
            box.x = box.originX + (box.endX - box.originX) * t
            box.y = box.originY + (box.endY - box.originY) * t
        end
    end
    local box = self.inspecting
    if not box then return end
    if distanceSquared(self.player, box) > 110^2 then self.inspecting = nil; return end
    local items, revealed = Loot.getBox(self.run, box.room, box.index)
    if revealed < #items then
        box.search = box.search + dt
        while box.search >= searchTime and revealed < #items do
            box.search = box.search - searchTime
            Loot.revealNext(self.run, box.room, box.index)
            revealed = revealed + 1
        end
    end
end

function Inspection:take(index)
    local box = self.inspecting
    local items, revealed = Loot.getBox(self.run, box.room, box.index)
    if index > revealed or not items[index] then return end
    if Loot.takeFromBox(self.run, box.room, box.index, index, self.player.inventory) then
        self.message = 'Recogiste ' .. Items:getItem(items[index]).name .. '.'
    else
        self.message = 'Carga llena. El objeto sigue en la caja.'
    end
end

function Inspection:keypressed(key)
    if require('src.ui.inventory_ui'):isOpen() then return false end
    if self.inspecting then
        if key == 'e' or key == 'escape' or key == 'tab' then
            self.inspecting = nil
            self.message = ''
            return key ~= 'tab'
        end
        if key == 'return' or key == 'kpenter' then self:take(1); return true end
        return false
    end
    if key ~= 'e' then return false end
    local target = self:nearby()
    if not target then
        return false
    elseif target.room then
        self.inspecting, self.message = target, ''
        if not target.drawWorld then self.run.lootRooms[target.room][target.index].opened = true end
    elseif not target.id then
        self.keyCollected = self:collectKey(target)
    elseif Loot.getRoomRarity(self.run, target.id) then
        self.message = 'Cápsula abierta. Acércate a una de sus cajas.'
    elseif Loot.unlockRoom(self.run, target.id, self.player.inventory, target.rarity or target.id) then
        local room = self.run.lootRooms[target.id]
        room.releaseX,room.releaseY = target.x,target.y
        target.unsealing = 0
        self:spawnBoxes(target)
        self.message = 'Cápsula abierta. Cajas liberadas: ' .. Loot.getBoxCount(self.run, target.id)
    else
        self.message = 'Necesitas una llave en la carga.'
    end
    return true
end

local function layout(capacity)
    local sw, sh = love.graphics.getDimensions()
    local w, h = math.min(460, sw - 24), 202
    local cell
    if capacity then
        local rows = capacity / Grid.columns
        cell = math.floor(math.min(62, (w - 36) / Grid.columns - 4, (sh - 132) / rows - 4))
        h = rows * (cell + 4) + 93
    end
    return math.floor((sw - w) / 2), math.max(14, math.floor((sh - h) / 2)), w, h, cell
end

local function slotAt(x, y, width, index, id, placement, cell)
    if cell then
        local anchor = placement and placement.anchor or index
        local pitch = cell + 4
        local w, h = 1, 1
        if id then w, h = Grid.dimensions(Items:getItem(id) or {id = id}, placement.rotated) end
        return x + math.floor((width - Grid.columns * pitch + 4) / 2) + (anchor - 1) % Grid.columns * pitch,
            y + 60 + math.floor((anchor - 1) / Grid.columns) * pitch, w * pitch - 4, h * pitch - 4
    end
    local gap = 8
    local w = math.floor((width - 32 - gap * 2) / 3)
    return x + 16 + ((index - 1) % 3) * (w + gap),
        y + 57 + math.floor((index - 1) / 3) * 50, w, 43
end

local function inside(mx, my, x, y, w, h)
    return mx >= x and mx < x + w and my >= y and my < y + h
end

local function drawItemName(name, x, y, w, h)
    local scale = w < 65 and .85 or 1
    local width = (w - 8) / scale
    local _, lines = Theme.small:getWrap(name, width)
    local lineCount = math.min(#lines, h >= 48 and 3 or h >= 31 and 2 or 1)
    local g = love.graphics
    for index = 1, lineCount do
        local label = lines[index]
        if index == lineCount and index < #lines then label = '…' end
        g.printf(label, x + 4, y + 4 + (index - 1) * Theme.small:getHeight() * scale, width, 'center', 0, scale)
    end
end

function Inspection:mousepressed(mx, my, button)
    if button ~= 1 or not self.inspecting then return end
    local box = self.inspecting
    local items, revealed, capacity, placements = Loot.getBox(self.run, box.room, box.index)
    local x, y, w, _, cell = layout(capacity)
    if inside(mx, my, x + w - 82, y + 10, 66, 23) then
        self.inspecting, self.message = nil, ''
        return
    end
    for index = 1, revealed do
        if inside(mx, my, slotAt(x, y, w, index, items[index], placements and placements[index], cell)) then
            self:take(index)
            return
        end
    end
end

function Inspection:draw()
    local g = love.graphics
    g.push('all')
    for _, target in ipairs(self.targets) do
        if target.drawWorld then
            target.drawWorld(target)
        elseif target.id then
            local opened = Loot.getRoomRarity(self.run,target.id)
            Art.draw('capsule',target.x,target.y,target.unsealing or (opened and 1 or 0),
                false,target.rarity or target.id,target.roll,1.4)
        else
            Theme.panel(target.x-58,target.y-42,116,60,target.color)
            g.setColor(target.color)
            g.printf(target.name,target.x-58,target.y-33,116,'center')
        end
    end
    for _,box in ipairs(self.boxes) do
        local empty = #self.run.lootRooms[box.room][box.index]==0
        Art.draw(box.capacity or 16,box.x,box.y,box.opening,empty)
    end
    g.pop()
end

function Inspection:drawHUD()
    local g = love.graphics
    Theme.init()
    g.push('all')
    g.setFont(Theme.font)
    local box = self.inspecting
    if not box then
        local target = self:nearby()
        local w = math.min(500, g.getWidth() - 24)
        local x = (g.getWidth() - w) / 2
        Theme.panel(x, 42, w, 61)
        g.setColor(Theme.colors.active)
        local action = target and ('[E] ' .. target.name) or 'Acércate a una cápsula o caja'
        g.printf(action .. (self.debugHint or ''), x + 8, 50, w - 16, 'center')
        g.setColor(Theme.colors.text)
        g.printf(self.message, x + 8, 75, w - 16, 'center')
        g.pop()
        return
    end

    local items, revealed, capacity, placements = Loot.getBox(self.run, box.room, box.index)
    local x, y, w, h, cell = layout(capacity)
    local mx, my = love.mouse.getPosition()
    g.setColor(.01, .02, .035, .36)
    g.rectangle('fill', 0, 0, g.getDimensions())
    Theme.panel(x, y, w, h, box.color, true)
    g.setFont(Theme.title)
    g.setColor(box.color)
    local titleX=x+16
    if not box.drawWorld then
        Art.draw(box.capacity or 16,x+31,y+26,box.opening,#items==0,nil,0,.76)
        titleX=x+57
    end
    g.setColor(box.color)
    g.print(box.name, titleX, y + 12)
    Theme.panel(x + w - 82, y + 10, 66, 23, box.color, inside(mx, my, x + w - 82, y + 10, 66, 23))
    g.setFont(Theme.small)
    g.setColor(Theme.colors.text)
    g.printf('Cerrar', x + w - 82, y + 15, 66, 'center')
    local status = #items == 0 and (box.drawWorld and 'Pecio vacío' or 'Caja vacía')
        or revealed == #items and 'Registro completo · Clic para recoger'
        or 'Buscando objetos…'
    g.setColor(Theme.colors.muted)
    g.print(status, x + 16, y + 38)
    if capacity then
        g.printf(('%d celdas'):format(capacity), x + w - 106, y + 38, 90, 'right')
        for index = 1, capacity do
            local sx, sy, sw, sh = slotAt(x, y, w, index, nil, nil, cell)
            g.setColor(.09, .11, .16, .8)
            g.rectangle('fill', sx, sy, sw, sh, 4, 4)
            g.setColor(.31, .39, .52, .32)
            g.rectangle('line', sx, sy, sw, sh, 4, 4)
        end
    end
    local hovered, hoveredShape
    for index = 1, #items do
        local sx, sy, sw, sh = slotAt(x, y, w, index, items[index], placements and placements[index], cell)
        local visible = index <= revealed
        local hover = visible and inside(mx, my, sx, sy, sw, sh)
        local item = visible and (Items:getItem(items[index]) or {name = items[index]})
        local rarity = item and item.rarity
        local color = type(rarity) == 'table' and rarity.color or Theme.colors.muted
        Theme.panel(sx, sy, sw, sh, color, hover)
        if visible then
            g.setColor(Theme.colors.text)
            drawItemName(item.name, sx, sy, sw, sh)
            if type(rarity) == 'table' and sh >= 54 then
                g.setColor(color)
                g.printf(rarity.name, sx + 5, sy + sh - 12, sw - 10, 'center')
            end
            if hover then
                hovered = item
                local wide, tall = Grid.dimensions(item, placements and placements[index].rotated)
                hoveredShape = ('Carga · %d×%d'):format(wide, tall)
            end
        else
            g.setColor(Theme.colors.muted)
            g.printf('?', sx, sy + math.floor((sh - 14) / 2), sw, 'center')
            if index == revealed + 1 then
                g.setColor(box.color)
                g.rectangle('fill', sx + 4, sy + sh - 6, (sw - 8) * math.min(1, box.search / searchTime), 2)
            end
        end
    end
    g.setColor(Theme.colors.text)
    local footer = self.message ~= '' and self.message or 'Esc · Cerrar   Enter · Recoger primero   Tab · Carga'
    g.printf(footer, x + 12, y + h - 25, w - 24, 'center')
    g.pop()
    if hovered then Theme.tooltip(self.player, hovered, mx, my, hoveredShape) end
end

return Inspection
