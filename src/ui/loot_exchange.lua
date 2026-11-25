local MenuCamera = require 'src.ui.menu_camera'
local MenuTheme = require 'src.ui.menu_theme'
local Grid = require 'src.item_systems.cargo_grid'
local Loot = require 'src.gameplay.loot'
local Theme = require 'src.ui.combat_theme'

local CargoPanel = require 'src.ui.inventory.cargo_panel'
local InventoryUI = require 'src.ui.inventory_ui'

local Exchange = {}
local columns = Grid.columns

local function layout(ui)
    local target = ui.inspecting
    local box = ui.run.lootRooms[target.room][target.index]
    local inv = ui.player.inventory
    local width, height = love.graphics.getDimensions()
    local rows = math.ceil(math.max(box.capacity, inv.maxSlots) / columns)
    local margin = math.max(8,math.min(48,math.floor(width*.035)))
    local available = width-2*margin-6*CargoPanel.inset-2*CargoPanel.gap
    local gearPitch = math.max(8,math.floor(math.min(84,available/11,(height-224)/6)))
    local pitch = math.max(8,math.floor(math.min(84,(available-3*gearPitch)/8,(height-150)/rows)))
    local cargoWidth = CargoPanel.width(columns,pitch)
    local gearWidth = CargoPanel.width(3,gearPitch)
    local groupWidth = cargoWidth*2+gearWidth+2*CargoPanel.gap
    local groupX = math.floor((width-groupWidth)/2)
    local left = groupX+CargoPanel.inset
    local right = left+cargoWidth+CargoPanel.gap
    local gearX = groupX+2*(cargoWidth+CargoPanel.gap)
    InventoryUI:layoutLootEquipment(ui.player,gearX,gearPitch)
    local top = math.max(CargoPanel.header+8,math.floor((height-rows*pitch)/2))
    local iconSize = math.max(1,CargoPanel.pitch(width,height,rows)-CargoPanel.padding-8)
    return {box=box,inv=inv,pitch=pitch,top=top,left=left,right=right,iconSize=iconSize}
end

local function rect(l, side, anchor, w, h)
    local left = side == 'box' and l.left or l.right
    return CargoPanel.rect(left,l.top,l.pitch,columns,anchor,w,h)
end

local function hit(l, x, y)
    for _, side in ipairs({'box', 'ship'}) do
        local left = side == 'box' and l.left or l.right
        local cell = CargoPanel.hit(left,l.top,l.pitch,columns,side == 'box' and l.box.capacity or l.inv.maxSlots,x,y)
        if cell then return side,cell end
    end
    local slot = InventoryUI:getEVASlotAt(x,y,l.inv:getCompartment('eva'))
    if slot then return 'eva', slot end
    slot = InventoryUI:getWeaponSlotAt(x,y,l.inv:getCompartment('weapons'))
    if slot then return 'weapons', slot end
    slot = InventoryUI:getPassiveSlotAt(x,y,l.inv:getCompartment('passives'))
    if slot then return 'passives', slot end
end

local function itemAt(l, side, cell)
    if side == 'ship' then
        local anchor = l.inv:cargoAnchor(cell)
        local item = l.inv.items[anchor]
        if item then return anchor, anchor, item, item.rotated end
    elseif side == 'box' then
        local anchor = Loot.boxCells(l.box)[cell]
        for i = 1, l.box.revealed do
            local p = l.box.placements[i]
            if p.anchor == anchor then return i, anchor, Loot.boxEntry(l.box, i), p.rotated end
        end
    elseif side then
        local entry = l.inv:getCompartment(side).items[cell]
        if entry then return cell,cell,entry,entry.rotated end
    end
end

local function take(ui, l, index, anchor, rotated)
    local t = ui.inspecting
    return Loot.takeFromBox(ui.run, t.room, t.index, index, l.inv, anchor, rotated)
end

local function feedback(ui, ok)
    ui.message = ok and '' or 'No cabe. El objeto sigue en su sitio.'
end

function Exchange.press(ui, x, y, button)
    if button ~= 1 then return end
    local l = layout(ui)
    if x >= l.right + columns*l.pitch - 58 and x <= l.right + columns*l.pitch
        and y >= l.top - 34 and y <= l.top - 10 then
        ui.inspecting, ui.drag, ui.message = nil, nil, ''
        return
    end
    local side, cell = hit(l, x, y)
    local index, anchor, entry, rotated = itemAt(l, side, cell)
    if not entry then return end
    ui.message = ''
    if love.keyboard.isDown('lshift') then
        if side == 'box' then feedback(ui, take(ui, l, index))
        else feedback(ui, Loot.storeInBox(l.box, l.inv, index,nil,nil,side)) end
        return
    end
    if side == 'weapons' and index == 1 then return end
    local fromGrid = side == 'box' or side == 'ship'
    local size = fromGrid and CargoPanel.iconSize(l.pitch,l.iconSize) or InventoryUI:equipmentIconSize()
    ui.drag = {size=size,side = side, index = index, entry = entry, rotated = rotated, box = l.box,
        dx = (cell - anchor) % columns, dy = math.floor((cell - anchor) / columns),
        startX = x, startY = y}
end

function Exchange.rotate(ui)
    local d = ui.drag
    if d and Grid.canRotate(d.entry) then
        local _, h = Grid.dimensions(d.entry, d.rotated)
        d.dx, d.dy = h - 1 - d.dy, d.dx
        d.rotated = not d.rotated
    end
end

local function landing(l, d, side, cell)
    if not side or d.box ~= l.box then return end
    if d.side == 'ship' and l.inv.items[d.index] ~= d.entry then return end
    if side == 'ship' and d.side == 'ship' and (d.rotated == true) == (d.entry.rotated == true) then
        local move = l.inv:previewCargoMove(d.index, cell, nil, d.dx, d.dy)
        return move and move.target, move and move.rotated, move
    end
    local w, h = Grid.dimensions(d.entry, d.rotated)
    local cap = side == 'ship' and l.inv.maxSlots or l.box.capacity
    local col = math.max(0, math.min(columns - w, (cell - 1) % columns - d.dx))
    local row = math.max(0, math.min(cap / columns - h, math.floor((cell - 1) / columns) - d.dy))
    local anchor = row * columns + col + 1
    local cells
    if side == 'ship' then
        cells = Grid.occupancy(l.inv.items, d.side == side and d.index or nil)
        local stack = l.inv.items[cells[cell]]
        local data = d.entry.data or d.entry
        if d.side == 'box' and data.stackable and stack and stack.data.id == data.id
            and (stack.quantity or 1) + (d.entry.quantity or 1) <= (data.maxStack or 99) then
            return cells[cell], d.rotated
        end
    else
        cells = Loot.boxCells(l.box, d.side == side and d.index or nil)
    end
    if Grid.fits(cells, cap, anchor, d.entry, d.rotated) then return anchor, d.rotated end
end

function Exchange.release(ui, x, y, button)
    local d = ui.drag
    if button ~= 1 or not d then return end
    ui.drag = nil
    if math.abs(x-d.startX) + math.abs(y-d.startY) < 3 then return end
    local l = layout(ui)
    local side, cell = hit(l, x, y)
    if not side then return end
    local toGear = side ~= 'box' and side ~= 'ship'
    local fromGear = d.side ~= 'box' and d.side ~= 'ship'
    if toGear or fromGear then
        local ok
        if d.side == 'box' then
            local target = ui.inspecting
            ok = Loot.takeFromBox(ui.run,target.room,target.index,d.index,l.inv,cell,nil,side)
        elseif side == 'box' then
            local anchor,rotated = landing(l,d,side,cell)
            ok = anchor and Loot.storeInBox(l.box,l.inv,d.index,anchor,rotated,d.side)
        elseif side ~= d.side and not (side == 'weapons' and cell == 1) then
            ok = l.inv:transferItemBetweenCompartments(d.side,d.index,side,cell)
        end
        ui.message = ok and '' or 'No se puede colocar en esa ranura.'
        return
    end
    local anchor, rotated, move = landing(l, d, side, cell)
    if not anchor then feedback(ui, false); return end
    local ok
    if side == 'box' and d.side == 'ship' then
        ok = Loot.storeInBox(l.box, l.inv, d.index, anchor, rotated)
    elseif side == 'ship' and d.side == 'box' then
        ok = take(ui, l, d.index, anchor, rotated)
    elseif side == 'ship' then
        if move then ok = l.inv:moveItemWithinCompartment('ship', d.index, cell, nil, d.dx, d.dy)
        else ok = l.inv:moveItemWithinCompartment('ship', d.index, anchor, rotated) end
    else
        local place = l.box.placements[d.index]
        place.anchor, place.rotated = anchor, rotated
        ok = true
    end
    feedback(ui, ok)
end

local function drawContents(ui)
    local g, l = love.graphics, layout(ui)
    local mx, my = love.mouse.getPosition()
    local side, cell = hit(l, mx, my)
    local target = ui.inspecting
    local boxItems = {}
    for i, place in ipairs(l.box.placements) do
        local entry = Loot.boxEntry(l.box,i) or {id=l.box[i]}
        boxItems[place.anchor] = {data=entry.data or entry, quantity=entry.quantity, rotated=place.rotated,
            hidden=i>l.box.revealed, progress=i==l.box.revealed+1 and math.min(1,target.search/.48)}
    end
    InventoryUI:drawCargoPanel({x=l.left,y=l.top,pitch=l.pitch,iconSize=l.iconSize,columns=columns,capacity=l.box.capacity,
        items=boxItems,title=target.name,tint=target.color,
        hint=l.box.revealed<#l.box and 'Buscando objetos...' or #l.box==0 and 'Vacío' or nil},ui.player)
    InventoryUI:drawCargoPanel({x=l.right,y=l.top,pitch=l.pitch,iconSize=l.iconSize,columns=columns,capacity=l.inv.maxSlots,
        items=l.inv.items,title=CargoPanel.shipTitle(ui.player)},ui.player)
    InventoryUI:drawLootEquipment(ui.player)
    local closeX = l.right+columns*l.pitch-58
    MenuTheme.mark(closeX,l.top-34,58,24,MenuTheme.sage)
    g.setFont(Theme.small)
    g.setColor(Theme.colors.text)
    g.printf('Cerrar',closeX,l.top-29,58,'center')
    local hint = 'Arrastra para mover   ·   Shift izq. + clic para transferir   ·   Esc para cerrar'
    if ui.drag then
        local d = ui.drag
        local onGrid = side == "ship" or side == "box"
        local anchor, rotated
        if onGrid then anchor, rotated = landing(l,d,side,cell) end
        if onGrid then
            g.setColor(anchor and .25 or 1,anchor and .9 or .48,.55,1)
            g.setLineWidth(2)
            local w,h = Grid.dimensions(d.entry,rotated)
            g.rectangle('line',rect(l,side,anchor or cell,anchor and w or 1,anchor and h or 1))
        end
        local icon = d.entry.data and d.entry or {data=d.entry}
        local x,y = mx-d.size/2,my-d.size/2
        MenuCamera.itemEcho('loot',icon.data,x,y,d.size)
        InventoryUI:drawItem(x,y,d.size,icon,ui.player)
        hint = not side and 'Suelta fuera para cancelar' or (anchor or not onGrid) and 'Suelta para colocar' or 'No cabe aquí'
        if Grid.canRotate(d.entry) then hint = hint .. '   ·   R para girar' end
    else
        MenuCamera.itemEcho('loot')
    end
    g.setFont(Theme.small)
    g.setColor(Theme.colors.text)
    local hintWidth = l.right+columns*l.pitch-l.left
    local hintY = l.top+math.ceil(math.max(l.box.capacity,l.inv.maxSlots)/columns)*l.pitch+34
    g.printf(ui.message ~= '' and ui.message or hint,l.left,hintY,hintWidth,'center')
    if side and not ui.drag then
        local _, _, entry, rotated = itemAt(l,side,cell)
        if entry then
            local w,h = Grid.dimensions(entry,rotated)
            Theme.tooltip(ui.player,entry.data or entry,mx,my,('Carga · %d×%d'):format(w,h))
        end
    end
end

function Exchange.draw(ui)
    MenuCamera.draw('loot',drawContents,ui)
end

return Exchange
