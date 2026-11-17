local Loot = require 'src.gameplay.loot'
local Items = require 'src.item_systems.item_system'
local Theme = require 'src.ui.combat_theme'

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
    for index = 1, Loot.getBoxCount(self.run, target.id) do
        local box = {
            room = target.id, index = index, x = target.x, y = target.y,
            originX = target.x, originY = target.y,
            endX = target.x + offsets[index], endY = target.y - 120,
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
    for _, box in ipairs(self.boxes) do
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
    elseif not target.id then
        self.keyCollected = self:collectKey(target)
    elseif Loot.getRoomRarity(self.run, target.id) then
        self.message = 'Sala abierta. Acércate a una de sus cajas.'
    elseif Loot.unlockRoom(self.run, target.id, self.player.inventory, target.rarity or target.id) then
        self:spawnBoxes(target)
        self.message = 'Sala abierta. Cajas liberadas: ' .. Loot.getBoxCount(self.run, target.id)
    else
        self.message = 'Necesitas una llave en la carga.'
    end
    return true
end

local function layout()
    local sw, sh = love.graphics.getDimensions()
    local w, h = math.min(520, sw - 24), 202
    return math.floor((sw - w) / 2), math.max(38, math.floor((sh - h) / 2)), w, h
end

local function slotAt(x, y, width, index)
    local gap = 8
    local w = math.floor((width - 32 - gap * 2) / 3)
    return x + 16 + ((index - 1) % 3) * (w + gap),
        y + 57 + math.floor((index - 1) / 3) * 50, w, 43
end

local function inside(mx, my, x, y, w, h)
    return mx >= x and mx < x + w and my >= y and my < y + h
end

function Inspection:mousepressed(mx, my, button)
    if button ~= 1 or not self.inspecting then return end
    local x, y, w = layout()
    if inside(mx, my, x + w - 82, y + 10, 66, 23) then
        self.inspecting, self.message = nil, ''
        return
    end
    local box = self.inspecting
    local _, revealed = Loot.getBox(self.run, box.room, box.index)
    for index = 1, revealed do
        if inside(mx, my, slotAt(x, y, w, index)) then self:take(index); return end
    end
end

function Inspection:draw()
    local g = love.graphics
    g.push('all')
    for _, target in ipairs(self.targets) do
        if target.drawWorld then
            target.drawWorld(target)
        else
            local x, y = target.x, target.y
            local opened = target.id and Loot.getRoomRarity(self.run, target.id)
            local w = target.id and 148 or 116
            Theme.panel(x - w / 2, y - 42, w, 60, target.color, not not opened)
            g.setColor(target.color)
            g.printf(target.name, x - w / 2, y - 33, w, 'center')
            if target.id then
                g.printf(opened and 'Abierto' or 'Sellado', x - w / 2, y - 13, w, 'center')
            end
        end
    end
    for _, box in ipairs(self.boxes) do
        local remaining = Loot.getBox(self.run, box.room, box.index)
        Theme.panel(box.x - 26, box.y - 17, 52, 34, box.color, box == self.inspecting)
        g.setColor(#remaining > 0 and box.color or Theme.colors.muted)
        g.printf(#remaining > 0 and ('Caja ' .. box.index) or 'Vacía', box.x - 28, box.y - 6, 56, 'center')
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
        local action = target and ('[E] ' .. target.name) or 'Acércate a una sala o caja'
        g.printf(action .. (self.debugHint or ''), x + 8, 50, w - 16, 'center')
        g.setColor(Theme.colors.text)
        g.printf(self.message, x + 8, 75, w - 16, 'center')
        g.pop()
        return
    end

    local x, y, w, h = layout()
    local items, revealed = Loot.getBox(self.run, box.room, box.index)
    local mx, my = love.mouse.getPosition()
    g.setColor(.01, .02, .035, .36)
    g.rectangle('fill', 0, 0, g.getDimensions())
    Theme.panel(x, y, w, h, box.color, true)
    g.setFont(Theme.title)
    g.setColor(box.color)
    g.print(box.name, x + 16, y + 12)
    Theme.panel(x + w - 82, y + 10, 66, 23, box.color, inside(mx, my, x + w - 82, y + 10, 66, 23))
    g.setFont(Theme.small)
    g.setColor(Theme.colors.text)
    g.printf('Cerrar', x + w - 82, y + 15, 66, 'center')
    local status = #items == 0 and (box.drawWorld and 'Pecio vacío' or 'Caja vacía')
        or revealed == #items and 'Registro completo · Clic para recoger'
        or 'Buscando objetos…'
    g.setColor(Theme.colors.muted)
    g.print(status, x + 16, y + 38)
    local hovered
    for index = 1, #items do
        local sx, sy, sw, sh = slotAt(x, y, w, index)
        local visible = index <= revealed
        local hover = visible and inside(mx, my, sx, sy, sw, sh)
        local item = visible and Items:getItem(items[index])
        local rarity = item and item.rarity
        local color = type(rarity) == 'table' and rarity.color or Theme.colors.muted
        Theme.panel(sx, sy, sw, sh, color, hover)
        if visible then
            g.setColor(Theme.colors.text)
            g.printf(item.name, sx + 5, sy + 4, sw - 10, 'center')
            if type(rarity) == 'table' then
                g.setColor(color)
                g.printf(rarity.name, sx + 5, sy + sh - 12, sw - 10, 'center')
            end
            if hover then hovered = item end
        else
            g.setColor(Theme.colors.muted)
            g.printf('?', sx, sy + 12, sw, 'center')
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
    if hovered then Theme.tooltip(self.player, hovered, mx, my) end
end

return Inspection
