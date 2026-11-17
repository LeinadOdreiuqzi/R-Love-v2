local MapConfig = require 'src.maps.config.map_config'
local Biomes = require 'src.maps.biome_system'
local Seed = require 'src.utils.seed_system'
local Loot = require 'src.gameplay.loot'
local Inspection = require 'src.ui.loot_inspection'
local ConvoyArt = require 'src.rendering.ships.convoy_art'

local Sites = {}
local BT = Biomes.BiomeType
local rates = {
    [BT.DEEP_SPACE] = {4, 20, 3},
    [BT.NEBULA_FIELD] = {5, 23, 4},
    [BT.ASTEROID_BELT] = {6, 20, 3},
    [BT.GRAVITY_ANOMALY] = {5, 29, 6},
    [BT.RADIOACTIVE_ZONE] = {4, 28, 6},
    [BT.ANCIENT_RUINS] = {8, 32, 8}
}
local colors = {common = {.55, .78, .87}, rare = {.38, .65, 1}, exceptional = {1, .69, .28}}
local names = {common = 'Contenedor común', rare = 'Contenedor raro', exceptional = 'Contenedor excepcional'}
local tileSize = MapConfig.chunk.tileSize * MapConfig.chunk.worldScale
local stride = (MapConfig.chunk.size * MapConfig.chunk.tileSize + MapConfig.chunk.spacing) * MapConfig.chunk.worldScale
local scanRange = 1300
local inspection, activeRun, activePlayer
local currentX, currentY, candidates, loaded

function Sites.addConvoyBox(run, id, settled)
    if not inspection or run ~= activeRun or loaded[id] then return end
    local cargo = run.lootRooms[id].convoyCargo
    if math.abs(math.floor(cargo.x / stride) - currentX) > 1
        or math.abs(math.floor(cargo.y / stride) - currentY) > 1 then return end
    inspection:spawnBoxes({id = id, x = cargo.x, y = cargo.y,
        name = 'Convoy blindado', color = {1, .73, .35}}, settled)
    loaded[id] = true
end

function Sites.addConvoyWreck(run, id)
    if not inspection or run ~= activeRun or loaded[id] then return end
    local wreck = run.lootRooms[id].convoyWreck
    if math.abs(math.floor(wreck.x / stride) - currentX) > 1
        or math.abs(math.floor(wreck.y / stride) - currentY) > 1 then return end
    inspection.targets[#inspection.targets + 1] = {
        room = id, index = 1, x = wreck.x, y = wreck.y, rotation = wreck.rotation, size = wreck.size,
        name = 'Pecio del convoy', color = {1, .66, .35}, search = 0, drawWorld = ConvoyArt.drawWreck
    }
    loaded[id] = true
end

function Sites.candidate(seed, cx, cy, biome)
    if cx == 0 and cy == 0 then return nil end
    local id = ('salvage:%d:%d'):format(cx, cy)
    local rng = love.math.newRandomGenerator(Seed.toNumeric(tostring(seed) .. ':' .. id))
    local rate = rates[biome] or rates[BT.DEEP_SPACE]
    if rng:random() * 100 >= rate[1] then return nil end
    local quality = rng:random() * 100
    local rarity = quality < rate[3] and 'exceptional' or quality < rate[2] + rate[3] and 'rare' or 'common'
    local x = cx * stride + stride * (.27 + .46 * rng:random())
    local y = cy * stride + stride * (.25 + .50 * rng:random())
    local side = rng:random() < .5 and -1 or 1
    return {id = id, rarity = rarity, name = names[rarity], color = colors[rarity], x = x, y = y,
        keyX = x + side * 340, keyY = y + 140, cx = cx, cy = cy}
end

local function hasClearance(site, chunk)
    local minX, maxX = math.min(site.x - 165, site.keyX - 55), math.max(site.x + 165, site.keyX + 55)
    local minY, maxY = site.y - 180, site.keyY + 55
    local baseX, baseY = site.cx * stride, site.cy * stride
    for y = math.floor((minY - baseY) / tileSize), math.ceil((maxY - baseY) / tileSize) do
        local row = chunk.tiles and chunk.tiles[y]
        for x = math.floor((minX - baseX) / tileSize), math.ceil((maxX - baseX) / tileSize) do
            local cell = row and row[x]
            if cell and cell >= MapConfig.ObjectType.ASTEROID_SMALL
                and cell <= MapConfig.ObjectType.ASTEROID_LARGE then return false end
        end
    end
    for _, object in ipairs(chunk.specialObjects or {}) do
        local x = baseX + object.x * MapConfig.chunk.worldScale
        local y = baseY + object.y * MapConfig.chunk.worldScale
        local margin = math.max(180, (object.radius or object.size or 0) * MapConfig.chunk.worldScale)
        if x > minX - margin and x < maxX + margin and y > minY - margin and y < maxY + margin then
            return false
        end
    end
    return true
end

function Sites.update(run, player, map, dt)
    if not run or not player then inspection, activeRun, activePlayer = nil, nil, nil; return end
    local cx, cy = math.floor(player.x / stride), math.floor(player.y / stride)
    if run ~= activeRun or player ~= activePlayer or cx ~= currentX or cy ~= currentY then
        activeRun, activePlayer, currentX, currentY = run, player, cx, cy
        candidates, loaded = {}, {}
        inspection = Inspection.new(player, run, {})
        for id, room in pairs(run.lootRooms) do
            if room.convoyCargo then Sites.addConvoyBox(run, id, true) end
            if room.convoyWreck then Sites.addConvoyWreck(run, id) end
        end
        for y = cy - 1, cy + 1 do
            for x = cx - 1, cx + 1 do
                local site = Sites.candidate(run.seed, x, y, Biomes.getBiomeForChunk(x, y))
                if site then candidates[#candidates + 1] = site end
            end
        end
    end
    for _, site in ipairs(candidates) do
        if not loaded[site.id] and (player.x - site.x)^2 + (player.y - site.y)^2 <= (scanRange + 700)^2 then
            local chunk = map.getChunkNonBlocking(site.cx, site.cy)
            if chunk then
                loaded[site.id] = true
                if hasClearance(site, chunk) then
                    local targets = inspection.targets
                    targets[#targets + 1] = site
                    if not run.salvageKeys[site.id] then
                        targets[#targets + 1] = {keyFor = site.id, x = site.keyX, y = site.keyY,
                            name = 'Baliza de acceso', color = {.3, .85, 1}}
                    end
                    if Loot.getRoomRarity(run, site.id) then inspection:spawnBoxes(site, true) end
                end
            end
        end
    end
    if player.isInEVA then inspection.inspecting = nil end
    inspection:update(dt)
end

function Sites.keypressed(player, key)
    if not inspection or activePlayer ~= player or player.isInEVA then return false end
    local target = key == 'e' and not inspection.inspecting and inspection:nearby()
    local handled = inspection:keypressed(key)
    if handled and target and target.keyFor and inspection.keyCollected then
        activeRun.salvageKeys[target.keyFor] = true
        for index, entry in ipairs(inspection.targets) do
            if entry == target then table.remove(inspection.targets, index); break end
        end
    end
    return handled
end

function Sites.mousepressed(player, x, y, button)
    if not inspection or activePlayer ~= player or not inspection.inspecting or player.isInEVA then return false end
    inspection:mousepressed(x, y, button)
    return true
end

function Sites.draw()
    if inspection then inspection:draw() end
end

function Sites.drawHUD(player, camera)
    if not inspection or activePlayer ~= player or player.isInEVA then return end
    if inspection.inspecting or inspection:nearby() then
        inspection:drawHUD()
        return
    end
    if not camera then return end
    local closest, distance = nil, scanRange^2
    for _, target in ipairs(inspection.targets) do
        local d = (target.x - player.x)^2 + (target.y - player.y)^2
        local room = target.room and activeRun.lootRooms[target.room]
        if d < distance and (not target.room or (room and #room[target.index] > 0)) then
            closest, distance = target, d
        end
    end
    for _, box in ipairs(inspection.boxes) do
        local room = activeRun.lootRooms[box.room]
        if room and room.convoyCargo then
            local d = (box.x - player.x)^2 + (box.y - player.y)^2
            if d < distance and #Loot.getBox(activeRun, box.room, box.index) > 0 then
                closest, distance = box, d
            end
        end
    end
    if not closest then return end
    local g = love.graphics
    local w, h = g.getDimensions()
    local x, y = camera:worldToScreen(closest.x, closest.y)
    g.push('all')
    g.setColor(closest.color)
    x, y = math.max(75, math.min(w - 75, x)), math.max(85, math.min(h - 120, y))
    g.circle('line', x, y, 6)
    g.printf(('%s · %.0f u'):format(closest.name, math.sqrt(distance)), x - 110, y + 10, 220, 'center')
    g.pop()
end

return Sites
