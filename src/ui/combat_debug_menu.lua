local Items = require 'src.item_systems.item_system'
local utf8 = require 'utf8'
local Menu = {opened = false, tab = 'weapons', query = '', offset = 0, slot = 2, message = ''}
local tabs = {{'weapons', 'Armas'}, {'passives', 'Pasivas'}, {'abilities', 'Habilidades'}, {'ships', 'Naves'}}

function Menu.open(player)
    if not player or not player.inventory then return end
    Menu.player, Menu.opened = player, true
    Menu.query, Menu.offset, Menu.message = '', 0, ''
    Menu.searchFocused, Menu.focusIndex, Menu.buttons = true, nil, {}
end

function Menu.close()
    Menu.opened, Menu.player = false, nil
    Menu.dragging, Menu.pressed, Menu.buttons = nil, nil, {}
end

function Menu.items()
    local rows = {}
    if Menu.tab == 'ships' then
        for id, config in pairs(require('src.entities.naves').getShipTypes()) do
            if id ~= 'DREADNOUGHT' and (config.name .. ' ' .. id):lower():find(Menu.query:lower(), 1, true) then
                rows[#rows + 1] = {id = id, name = config.name,
                    description = string.format('Velocidad %d · Casco %d · Escudo %d · Combustible %d',
                        config.maxSpeed, config.maxHealth, config.maxShield, config.maxFuel)}
            end
        end
        table.sort(rows, function(a, b) return a.name < b.name end)
        return rows
    end
    for _, item in pairs(Items.items) do
        if (Menu.tab == 'weapons' and item.equipType == 'weapon')
            or (Menu.tab == 'passives' and item.category == 'passive') then
            local text = ((item.name or '') .. ' ' .. item.id):lower()
            if text:find(Menu.query:lower(), 1, true) then rows[#rows + 1] = item end
        end
    end
    table.sort(rows, function(a, b) return a.id < b.id end)
    return rows
end

function Menu.give(item, equip)
    local player = Menu.player
    local inventory = player.inventory
    local previousEvent = player.lastSynergyEvent
    local success
    if not equip then
        success = inventory:addItemToCompartment('ship', item, 1)
    elseif item.category == 'passive' then
        success = inventory:addItemToCompartment('passives', item, 1)
    elseif player.weaponSystem then
        success = player.weaponSystem:equipWeapon(item, Menu.slot)
        if success then player.weaponSystem:switchToSlot(Menu.slot) end
    end
    Menu.message = success and ('Añadido · ' .. item.name) or 'Sin espacio o slot incompatible.'
    if success and player.lastSynergyEvent ~= previousEvent then
        Menu.message = Menu.message .. ' · Fusión · ' .. player.lastSynergyEvent.resultName:gsub('★', '[EVO]')
    end
    return success
end

local function layout()
    local w, h = love.graphics.getDimensions()
    local scale = math.min(1, w / 1020, h / 720)
    return (w - 980 * scale) / 2, (h - 680 * scale) / 2, scale
end

local function localPoint(x, y)
    local left, top, scale = layout()
    return (x - left) / scale, (y - top) / scale
end

local function contains(rect, x, y)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function scrollTo(offset)
    Menu.offset = math.max(0, math.min(math.max(0, #Menu.items() - 10), math.floor(offset + .5)))
    Menu.pressed, Menu.focusIndex = nil, nil
end

function Menu.keypressed(key)
    if key == 'escape' then
        Menu.close()
    elseif key == 'tab' then
        Menu.searchFocused = false
        local direction = love.keyboard.isDown('lshift', 'rshift') and -1 or 1
        Menu.focusIndex = ((Menu.focusIndex or 0) + direction - 1) % math.max(1, #Menu.buttons) + 1
    elseif (key == 'return' or key == 'space') and not Menu.searchFocused then
        local hit = Menu.buttons[Menu.focusIndex or 0]
        if hit and not hit.disabled then hit.action() end
    elseif key == 'pageup' then
        scrollTo(Menu.offset - 10)
    elseif key == 'pagedown' then
        scrollTo(Menu.offset + 10)
    elseif key == 'home' and not Menu.searchFocused then
        scrollTo(0)
    elseif key == 'end' and not Menu.searchFocused then
        scrollTo(#Menu.items())
    elseif key == 'backspace' and Menu.searchFocused then
        local index = utf8.offset(Menu.query, -1)
        if index then Menu.query = Menu.query:sub(1, index - 1) end
        Menu.offset = 0
    end
end

function Menu.textinput(text)
    if not Menu.searchFocused then return end
    Menu.query = Menu.query .. text
    Menu.offset = 0
end

function Menu.wheelmoved(_, y)
    scrollTo(Menu.offset - y * 3)
end

function Menu.mousepressed(x, y, button)
    if button ~= 1 then return end
    x, y = localPoint(x, y)
    Menu.searchFocused = x >= 24 and x <= 660 and y >= 125 and y <= 157
    Menu.focusIndex, Menu.pressed = nil, nil
    local bar = Menu.scrollbar
    if bar and contains(bar, x, y) and bar.maximum > 0 then
        if y >= bar.thumbY and y <= bar.thumbY + bar.thumbH then
            Menu.dragging = y - bar.thumbY
        else
            scrollTo(Menu.offset + (y < bar.thumbY and -10 or 10))
        end
        return
    end
    for i, hit in ipairs(Menu.buttons or {}) do
        if not hit.disabled and contains(hit, x, y) then
            Menu.pressed = i
            return
        end
    end
end

function Menu.mousemoved(x, y)
    if not Menu.dragging or not Menu.scrollbar then return end
    x, y = localPoint(x, y)
    local bar = Menu.scrollbar
    scrollTo((y - bar.y - Menu.dragging) / math.max(1, bar.h - bar.thumbH) * bar.maximum)
end

function Menu.mousereleased(x, y, button)
    if button ~= 1 then return end
    x, y = localPoint(x, y)
    local hit = Menu.buttons[Menu.pressed or 0]
    Menu.pressed, Menu.dragging = nil, nil
    if hit and not hit.disabled and contains(hit, x, y) then hit.action() end
end

function Menu.changeShip(id)
    if Menu.player:debugChangeShipType(id) then
        Menu.message = 'Chasis activo · ' .. Menu.player.shipName
        return true
    end
    Menu.message = 'Vuelve a la nave para cambiar de chasis.'
    return false
end

function Menu.draw()
    if not Menu.opened then return end
    local g = love.graphics
    Menu.font = Menu.font or g.newFont(16)
    Menu.small = Menu.small or g.newFont(12)
    local x, y, scale = layout()
    g.push('all')
    g.origin()
    g.setShader()
    g.setScissor()
    g.setColor(0, 0, 0, .8)
    g.rectangle('fill', 0, 0, g.getDimensions())
    g.translate(x, y)
    g.scale(scale)
    g.setFont(Menu.font)
    g.setColor(.04, .065, .10, 1)
    g.rectangle('fill', 0, 0, 980, 680, 12)
    g.setColor(.85, .95, 1)
    g.print('LABORATORIO DE COMBATE', 24, 20)
    g.setFont(Menu.small)
    g.print('Partida pausada · Esc para cerrar · Rueda para recorrer el catálogo', 24, 48)
    local mouseX, mouseY = localPoint(love.mouse.getPosition())
    Menu.buttons = {}
    local tooltip
    local function button(label, bx, by, bw, action, selected, disabled)
        local index = #Menu.buttons + 1
        local hover = contains({x = bx, y = by, w = bw, h = 32}, mouseX, mouseY)
        local highlight = not disabled and (hover or Menu.focusIndex == index)
        local boost = highlight and .12 or 0
        if Menu.pressed == index and hover then boost = .2 end
        g.setColor((selected and .12 or .09) + boost, (selected and .32 or .15) + boost,
            (selected and .45 or .22) + boost, disabled and .4 or 1)
        g.rectangle('fill', bx, by, bw, 32, 5)
        if highlight then
            g.setColor(.3, .8, 1)
            g.rectangle('line', bx, by, bw, 32, 5)
        end
        g.setColor(.9, .96, 1, disabled and .35 or 1)
        g.printf(label, bx, by + 8, bw, 'center')
        Menu.buttons[#Menu.buttons + 1] = {x = bx, y = by, w = bw, h = 32, action = action, disabled = disabled}
    end
    button('Cerrar', 860, 20, 96, Menu.close)
    for i, tab in ipairs(tabs) do
        button(tab[2], 24 + (i - 1) * 140, 82, 130, function()
            Menu.tab, Menu.offset, Menu.query = tab[1], 0, ''
            Menu.focusIndex, Menu.dragging, Menu.scrollbar = nil, nil, nil
        end, Menu.tab == tab[1])
    end
    local player = Menu.player
    button(player.debugDisableSynergies and 'Sinergias OFF' or 'Sinergias ON', 700, 82, 256, function()
        player.debugDisableSynergies = not player.debugDisableSynergies
        player.inventory:evaluateSynergies()
        Menu.message = 'Activar sinergias puede consumir ingredientes y crear evoluciones.'
    end, not player.debugDisableSynergies)
    g.setColor(.02, .04, .07)
    g.rectangle('fill', 24, 125, 636, 32, 5)
    g.setColor(Menu.searchFocused and .3 or .2, .55, .7)
    g.rectangle('line', 24, 125, 636, 32, 5)
    g.setScissor(x + 30 * scale, y + 125 * scale, 620 * scale, 32 * scale)
    g.setColor(.8, .9, 1)
    g.print('Buscar · ' .. Menu.query .. (Menu.searchFocused and '_' or ''), 32, 132)
    g.setScissor()
    Menu.scrollbar = nil
    if Menu.tab == 'abilities' then
        local ability = player.abilitySystem
        g.setFont(Menu.font)
        g.print('Q · Phase Dash — desplazamiento táctico', 24, 195)
        g.print('R · Matrix Overload — campo de daño y control', 24, 295)
        g.setFont(Menu.small)
        g.print('Q: 6 s de recarga · R: radio 180 / duración 5 s / recarga 25 s', 24, 390)
        g.print('Las pasivas equipadas modifican estas habilidades. Cierra el menú para avanzar el tiempo.', 24, 420)
        if ability then
            button('Probar Q', 24, 235, 180, function()
                local ok = ability:triggerTactical()
                Menu.message = ok and 'Phase Dash activado' or 'Q no disponible'
            end)
            button('Probar R', 24, 335, 180, function()
                local ok = ability:triggerUltimate()
                Menu.message = ok and 'Matrix Overload activado' or 'R no disponible'
            end)
            button('Reiniciar recargas', 24, 470, 240, function()
                ability.q, ability.r = 0, 0
                Menu.message = 'Recargas Q/R reiniciadas para debug'
            end)
            g.print(string.format('Recarga Q: %.1f s · R: %.1f s', ability.q, ability.r), 24, 525)
        end
    else
        if Menu.tab == 'weapons' then
            button('<', 700, 125, 32, function() Menu.slot = (Menu.slot - 2) % 9 + 1 end)
            g.setColor(.8, .9, 1)
            g.printf('Slot de arma · ' .. Menu.slot, 736, 133, 180, 'center')
            button('>', 924, 125, 32, function() Menu.slot = Menu.slot % 9 + 1 end)
        end
        g.setColor(.65, .75, .85)
        local help = 'Equipar reemplaza el slot elegido · Hover sobre un ítem para ver su descripción'
        if Menu.tab == 'ships' then help = 'Cambiar chasis conserva equipo y carga · Ajusta velocidad, hardpoints y capacidades'
        elseif Menu.tab == 'passives' then help = 'Equipar usa el primer slot pasivo libre · Hover para consultar los efectos' end
        g.print(help, 24, 170)
        local rows = Menu.items()
        Menu.offset = math.min(Menu.offset, math.max(0, #rows - 10))
        for i = 1, 10 do
            local item = rows[Menu.offset + i]
            if item then
                local ry = 200 + (i - 1) * 39
                if contains({x = 24, y = ry - 2, w = 930, h = 38}, mouseX, mouseY) then
                    g.setColor(.09, .17, .24, .75)
                    g.rectangle('fill', 20, ry - 2, 938, 38, 4)
                    if mouseX < 690 then tooltip = item.description end
                end
                g.setColor(.85, .92, 1)
                g.print(item.name:gsub('★', '[EVO]'), 24, ry)
                g.setColor(.5, .65, .75)
                g.print(item.id, 24, ry + 17)
                if Menu.tab == 'ships' then
                    local active = player.shipType == item.id
                    button(active and 'Activa' or 'Cambiar chasis', 760, ry, 190,
                        function() Menu.changeShip(item.id) end, active, active or player.isInEVA)
                else
                    button('A bodega', 700, ry, 120, function() Menu.give(item, false) end)
                    button('Equipar', 836, ry, 114, function() Menu.give(item, true) end)
                end
            end
        end
        local maximum = math.max(0, #rows - 10)
        local thumbH = math.max(32, 390 * math.min(1, 10 / math.max(1, #rows)))
        local thumbY = 200 + (390 - thumbH) * Menu.offset / math.max(1, maximum)
        Menu.scrollbar = {x = 961, y = 200, w = 12, h = 390, maximum = maximum,
            thumbY = thumbY, thumbH = thumbH}
        g.setColor(.025, .04, .065)
        g.rectangle('fill', 961, 200, 12, 390, 5)
        local barHover = contains(Menu.scrollbar, mouseX, mouseY)
        g.setColor(.2, barHover and .7 or .45, .65, maximum > 0 and 1 or .25)
        g.rectangle('fill', 962, thumbY, 10, thumbH, 5)
        if #rows == 0 then
            g.setColor(.65, .75, .85)
            g.print('Sin resultados. Modifica o borra la búsqueda.', 24, 220)
        end
        button('Anterior', 700, 600, 120, function() scrollTo(Menu.offset - 10) end, false, Menu.offset == 0)
        button('Siguiente', 836, 600, 114, function() scrollTo(Menu.offset + 10) end, false, Menu.offset >= maximum)
        g.setColor(.6, .75, .85)
        g.print(string.format('%d resultados · %d–%d', #rows, math.min(#rows, Menu.offset + 1), math.min(#rows, Menu.offset + 10)), 24, 605)
    end
    g.setColor(.6, 1, .8)
    g.printf(Menu.message, 24, 640, 932)
    if tooltip and not Menu.dragging then
        local _, lines = Menu.small:getWrap(tooltip, 360)
        local height = #lines * Menu.small:getHeight() + 20
        local tx, ty = math.min(590, mouseX + 16), math.max(10, math.min(670 - height, mouseY + 20))
        g.setColor(.025, .045, .07, .98)
        g.rectangle('fill', tx, ty, 380, height, 6)
        g.setColor(.35, .65, .8)
        g.rectangle('line', tx, ty, 380, height, 6)
        g.setColor(.9, .95, 1)
        g.printf(tooltip, tx + 10, ty + 10, 360)
    end
    g.pop()
end

return Menu
