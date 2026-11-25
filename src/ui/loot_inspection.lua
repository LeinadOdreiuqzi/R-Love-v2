local MenuCamera = require 'src.ui.menu_camera'
local Loot = require 'src.gameplay.loot'
local Items = require 'src.item_systems.item_system'
local Theme = require 'src.ui.combat_theme'
local Grid = require 'src.item_systems.cargo_grid'

local Art = require 'src.rendering.loot_art'

local Exchange = require 'src.ui.loot_exchange'

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
    if distanceSquared(self.player, box) > 110^2 then self.inspecting, self.drag = nil, nil; return end
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
            self.inspecting, self.drag = nil, nil
            self.message = ''
            return true
        end
        if key == 'r' then Exchange.rotate(self) end
        return key ~= 'f11' and key ~= 'p'
    end
    if key ~= 'e' then return false end
    local target = self:nearby()
    if not target then
        return false
    elseif target.room then
        Loot.getBox(self.run, target.room, target.index)
        MenuCamera.open('loot')
        self.inspecting, self.message, self.drag = target, '', nil
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

function Inspection:mousepressed(x, y, button)
    if self.inspecting then Exchange.press(self, x, y, button) end
end

function Inspection:mousereleased(x, y, button)
    if self.inspecting then Exchange.release(self, x, y, button) end
end

function Inspection:draw()
    local g = love.graphics
    g.push('all')
    for _, target in ipairs(self.targets) do
        if target.drawWorld then
            target.drawWorld(target)
        elseif target.id then
            local opened = self.run.lootRooms[target.id] ~= nil
            Art.draw('capsule',target.x,target.y,target.unsealing or (opened and 1 or 0),
                opened,target.rarity or target.id,target.roll,1.4)
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

    Exchange.draw(self)
    g.pop()
end

return Inspection
