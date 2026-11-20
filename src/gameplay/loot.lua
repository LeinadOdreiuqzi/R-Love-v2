local Items = require 'src.item_systems.item_system'
local Seed = require 'src.utils.seed_system'
local Grid = require 'src.item_systems.cargo_grid'

local Loot = {roomKeyId = 'salvage_room_key'}

-- Pesos propios de R-Love. Orden de rareza: común a legendaria.
local profiles = {
    enemy = {1, 1, {76, 19, 4, .9, .1}, 1},
    reinforced = {4, 4, {60, 27, 10, 2.5, .5}, 1},
    small = {8, 8, {76, 19, 4, .9, .1}, 1},
    standard = {22, 22, {44, 36, 15, 4, 1}, 2},
    elite = {12, 13, {35, 36, 20, 7, 2}, 1},
    capital = {20, 20, {25, 33, 28, 11, 3}, 1},
    convoyWreck = {14, 14, {28, 35, 27, 8, 2}},
    roomCommon = {8, 8, {52, 32, 12, 3.5, .5}},
    roomRare = {12, 12, {32, 38, 22, 7, 1}},
    roomExceptional = {16, 16, {20, 30, 34, 13, 3}}
}

local roomProfiles = {
    common = {profile = 'roomCommon', capacity = 8, minBoxes = 2, extraBoxChance = .25, itemWeights = {30, 50, 20}},
    rare = {profile = 'roomRare', capacity = 16, minBoxes = 2, extraBoxChance = .75, itemWeights = {10, 30, 45, 15}},
    exceptional = {profile = 'roomExceptional', capacity = 32, minBoxes = 3, extraBoxChance = .12, itemWeights = {5, 20, 40, 27, 8}}
}

local enemyDropChance = {enemy = 35, reinforced = 60, elite = 80, capital = 100}

function Loot.enemyProfile(ship)
    local config = ship.shipConfig or {}
    if config.isMothership then return 'capital' end
    if ship.shipType == 'GUNSHIP' or ship.shipType == 'SENTINEL' then return 'reinforced' end
    return 'enemy'
end

-- Cada entrada pertenece a una rareza de botín. Las evoluciones se obtienen por receta.
local pools = {
    {{'plasma_rifle', 'kinetic_assault_rifle'}, {'energy_shotgun', 'industrial_rip_saw'},
        {'gauss_railgun'}, {'gravitic_wave_projector'}, {'void_needle_dart'}},
    {{'enhanced_thrusters'}, {'inertial_gyro', 'rapid_fire_system'},
        {'reactive_armor_plating', 'salvage_magnet_array'}, {'afterburner_injector'}, {'cataclysm_core'}},
    {{'repair_kit', 'salvaged_fuel'}, {'energy_stim'}, {'medical_nanobots'}}
}

function Loot.applyCatalogRarities()
    local tiers = {Items.RARITY.COMMON, Items.RARITY.UNCOMMON, Items.RARITY.RARE,
        Items.RARITY.EPIC, Items.RARITY.LEGENDARY}
    for _, category in ipairs(pools) do
        for tier, ids in ipairs(category) do
            for _, id in ipairs(ids) do
                local item = assert(Items:getItem(id), 'Botín sin registrar: ' .. id)
                item.rarity = tiers[tier]
            end
        end
    end
end

local function choose(rng, weights)
    local total = 0
    for _, weight in ipairs(weights) do total = total + weight end
    local roll = rng:random() * total
    for index, weight in ipairs(weights) do
        if roll < weight then return index end
        roll = roll - weight
    end
end

local function pickItem(profile, rng, category, maxTier)
    local pool = pools[category]
    if not pool then return nil end
    local tier = choose(rng, {unpack(profile[3], 1, math.min(maxTier or #pool, #pool))})
    local ids = pool[tier]
    return ids[1 + math.floor(rng:random() * #ids)], tier
end

function Loot.roll(profileId, rng, count)
    local profile = assert(profiles[profileId], 'Perfil de botín desconocido')
    local result = {}
    local categories = {profile[1], profile[2], 100 - profile[1] - profile[2]}
    for i = 1, count or profile[4] or 1 do
        result[i] = pickItem(profile, rng, choose(rng, categories))
    end
    return result
end

function Loot.enemyDrop(profileId, rng, playerKill)
    local chance = assert(enemyDropChance[profileId], 'Perfil de botín enemigo desconocido')
    local profile = profiles[profileId]
    if playerKill then
        local category = choose(rng, {profile[1], profile[2],
            chance - profile[1] - profile[2], 100 - chance})
        return (pickItem(profile, rng, category))
    end
    -- Ambient skirmishes can leave supplies. The ship's actual cargo is recovered separately.
    if rng:random() * 100 < chance * .5 then
        return (pickItem(profile, rng, 3))
    end
end

local function packBox(items, capacity, preserve)
    local box = {capacity = capacity, placements = {}, revealed = items.revealed or 0, gridVersion = Grid.version}
    local cells, order, placements = {}, {}, {}
    for index, id in ipairs(items) do
        local item = Items:getItem(id) or {id = id}
        local w, h = Grid.dimensions(item)
        order[index] = {index = index, data = item, area = w * h}
    end
    if preserve then
        local packed = Grid.pack(capacity, order)
        if not packed then return nil end
        for anchor, entry in pairs(packed) do
            placements[entry.item.index] = {anchor = anchor, rotated = entry.rotated}
        end
    else
        table.sort(order, function(a, b)
            if a.area == b.area then return a.index < b.index end
            return a.area > b.area
        end)
        for _, entry in ipairs(order) do
            local anchor, rotated = Grid.find(cells, capacity, entry)
            if anchor then
                placements[entry.index] = {anchor = anchor, rotated = rotated}
                Grid.claim(cells, anchor, entry, rotated)
            end
        end
    end
    for index, id in ipairs(items) do
        if placements[index] then
            box[#box + 1] = id
            box.placements[#box] = placements[index]
        end
    end
    return box
end

function Loot.registerConvoyWreck(run, convoyId, x, y, rotation, size)
    local id = convoyId .. ':wreck'
    if run.lootRooms[id] then return id end
    local rng = love.math.newRandomGenerator(Seed.toNumeric(tostring(run.seed) .. ':' .. id))
    local profile = profiles.convoyWreck
    local cargo, maxTier = {revealed = 0}, 5
    local count = 3 + choose(rng, {40, 45, 15})
    for index = 1, count do
        local category = choose(rng, {profile[1], profile[2], 100 - profile[1] - profile[2]})
        local item, tier = pickItem(profile, rng, category, maxTier)
        cargo[index] = item
        if tier >= 4 then maxTier = 3 end
    end
    run.lootRooms[id] = {packBox(cargo, 24), convoyWreck = {x = x, y = y, rotation = rotation, size = size}}
    return id
end

function Loot.registerFrontierWreck(run, x, y, rotation)
    local id = 'frontier:1:wreck'
    if run.lootRooms[id] then return id end
    local rng = love.math.newRandomGenerator(Seed.toNumeric(tostring(run.seed)..':'..id))
    local cargo = Loot.roll('roomRare', rng, 4)
    local rareCargo = Loot.roll('roomExceptional', rng, 2)
    for _, item in ipairs(rareCargo) do cargo[#cargo+1] = item end
    run.lootRooms[id] = {packBox(cargo,32),frontierWreck={x=x,y=y,rotation=rotation}}
    return id
end

function Loot.unlockRoom(run, roomId, inventory, rarity)
    local config = roomProfiles[rarity or 'common']
    if not config then return false end
    local rooms = run.lootRooms
    if rooms[roomId] then return true end
    local cargo = inventory:getCompartment('ship')
    for slot = 1, cargo.maxSlots do
        local entry = cargo.items[slot]
        if entry and entry.data.id == Loot.roomKeyId then
            local seed = Seed.toNumeric(('%s:loot-room:%s'):format(run.seed, roomId))
            local rng = love.math.newRandomGenerator(seed)
            local boxes = {}
            local count = config.minBoxes
            if rng:random() < config.extraBoxChance then count = count + 1 end
            for index = 1, count do
                local size = choose(rng, config.itemWeights) + 1
                boxes[index] = packBox(Loot.roll(config.profile, rng, size), config.capacity)
            end
            boxes.rarity = rarity or 'common'
            local quantity = (entry.quantity or 1) - 1
            if quantity == 0 then
                inventory:removeItemFromCompartment('ship', slot)
            else
                entry.quantity, entry.data.quantity = quantity, quantity
            end
            rooms[roomId] = boxes
            return true
        end
    end
    return false
end

function Loot.getRoomRarity(run, roomId)
    local room = run.lootRooms[roomId]
    -- Las salas generadas antes de introducir rarezas usaban los pesos de la rara.
    return room and (room.rarity or 'rare')
end

function Loot.getBoxCount(run, roomId)
    local room = run.lootRooms[roomId]
    return room and #room or 0
end

function Loot.getBox(run, roomId, boxIndex)
    local room = run.lootRooms[roomId]
    local box = room and room[boxIndex]
    if not box then return end
    if box.gridVersion ~= Grid.version or not box.placements then
        local config = roomProfiles[room.rarity or 'rare'] or roomProfiles.rare
        local capacity = box.capacity or (room.convoyWreck and 24 or config.capacity)
        local migrated
        for size = capacity, 32, 8 do
            local packed = packBox(box, size, true)
            if packed then
                box, room[boxIndex] = packed, packed
                migrated = true
                break
            end
        end
        if not migrated then
            -- Oversized legacy boxes keep every item, even if they need extra rows.
            local cells = {}
            box.capacity, box.placements, box.gridVersion = 32, {}, Grid.version
            for i, id in ipairs(box) do
                local data = Items:getItem(id) or {id = id}
                local anchor, rotated = Grid.find(cells, box.capacity, data)
                while not anchor do
                    box.capacity = box.capacity + Grid.columns
                    anchor, rotated = Grid.find(cells, box.capacity, data)
                end
                box.placements[i] = {anchor = anchor, rotated = rotated}
                Grid.claim(cells, anchor, data, rotated)
            end
        end
    end
    return {unpack(box)}, box.revealed or 0, box.capacity, box.placements
end

function Loot.revealNext(run, roomId, boxIndex)
    local room = run.lootRooms[roomId]
    local box = room and room[boxIndex]
    if box then box.revealed = math.min(#box, (box.revealed or 0) + 1) end
end

function Loot.boxEntry(box, index)
    local place = box.placements[index]
    return place and (place.entry or Items:getItem(box[index]))
end

function Loot.boxCells(box, skip)
    local cells = {}
    for i, place in ipairs(box.placements) do
        if i ~= skip then
            Grid.claim(cells, place.anchor, Loot.boxEntry(box, i) or {id = box[i]}, place.rotated)
        end
    end
    return cells
end

function Loot.takeFromBox(run, roomId, boxIndex, index, inventory, anchor, rotated, equipment)
    local room = run.lootRooms[roomId]
    local box = room and room[boxIndex]
    if not box or not box[index] or index > (box.revealed or 0) then return false end
    local entry = Loot.boxEntry(box, index)
    if not entry then return false end
    local added
    if equipment then added = inventory:equipLoot(entry, equipment, anchor)
    elseif anchor then added = inventory:placeCargo(entry, anchor, rotated)
    else added = inventory:addItemToCompartment('ship', entry, entry.quantity or 1, true) end
    if not added then return false end
    table.remove(box, index)
    table.remove(box.placements, index)
    box.revealed = box.revealed - 1
    return true
end

function Loot.storeInBox(box, inventory, source, anchor, rotated, compartment)
    compartment = compartment or 'ship'
    if compartment == 'weapons' and source == 1 then return false end
    local entry = inventory:getCompartment(compartment).items[source]
    if not entry then return false end
    local cells = Loot.boxCells(box)
    if not anchor then anchor, rotated = Grid.find(cells, box.capacity, entry) end
    if not Grid.fits(cells, box.capacity, anchor, entry, rotated) then return false end
    local index = (box.revealed or 0) + 1
    inventory:removeItemFromCompartment(compartment, source)
    table.insert(box, index, entry.data.id)
    table.insert(box.placements, index, {anchor = anchor, rotated = rotated, entry = entry})
    box.revealed = index
    return true
end

return Loot
