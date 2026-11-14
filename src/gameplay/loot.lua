local Items = require 'src.item_systems.item_system'
local Seed = require 'src.utils.seed_system'

local Loot = {roomKeyId = 'salvage_room_key'}

-- Pesos propios de R-Love. Orden de rareza: común a legendaria.
local profiles = {
    enemy = {1, 1, {76, 19, 4, .9, .1}, 1},
    reinforced = {4, 4, {60, 27, 10, 2.5, .5}, 1},
    small = {8, 8, {76, 19, 4, .9, .1}, 1},
    standard = {22, 22, {44, 36, 15, 4, 1}, 2},
    elite = {12, 13, {35, 36, 20, 7, 2}, 1},
    capital = {20, 20, {25, 33, 28, 11, 3}, 1},
    roomCommon = {8, 8, {52, 32, 12, 3.5, .5}},
    roomRare = {12, 12, {32, 38, 22, 7, 1}},
    roomExceptional = {16, 16, {20, 30, 34, 13, 3}}
}

local roomProfiles = {
    common = {profile = 'roomCommon', minBoxes = 2, extraBoxChance = .25, itemWeights = {30, 50, 20}},
    rare = {profile = 'roomRare', minBoxes = 2, extraBoxChance = .75, itemWeights = {10, 30, 45, 15}},
    exceptional = {profile = 'roomExceptional', minBoxes = 3, extraBoxChance = .12, itemWeights = {5, 20, 40, 27, 8}}
}

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

function Loot.roll(profileId, rng, count)
    local profile = assert(profiles[profileId], 'Perfil de botín desconocido')
    local result = {}
    local categories = {profile[1], profile[2], 100 - profile[1] - profile[2]}
    for i = 1, count or profile[4] or 1 do
        local pool = pools[choose(rng, categories)]
        local tier = choose(rng, {unpack(profile[3], 1, #pool)})
        local ids = pool[tier]
        result[i] = ids[1 + math.floor(rng:random() * #ids)]
    end
    return result
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
                boxes[index] = Loot.roll(config.profile, rng, size)
                boxes[index].revealed = 0
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
    if box then return {unpack(box)}, box.revealed or 0 end
end

function Loot.revealNext(run, roomId, boxIndex)
    local room = run.lootRooms[roomId]
    local box = room and room[boxIndex]
    if box then box.revealed = math.min(#box, (box.revealed or 0) + 1) end
end

function Loot.takeFromBox(run, roomId, boxIndex, itemIndex, inventory)
    local room = run.lootRooms[roomId]
    local box = room and room[boxIndex]
    local id = box and box[itemIndex]
    local item = id and Items:getItem(id)
    if not item or itemIndex > (box.revealed or 0)
        or not inventory:addItemToCompartment('ship', item, 1) then return false end
    table.remove(box, itemIndex)
    box.revealed = box.revealed - 1
    return true
end

return Loot
