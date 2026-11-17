local Grid = {columns = 4, version = 2}

local footprints = {[1] = {1, 1}, [2] = {2, 1}, [4] = {2, 2}, [6] = {2, 3}}
local largeWeapons = {gauss_railgun = true, heavy_plasma_cannon = true,
    heavy_torpedo_launcher = true, singularity_torpedo = true, gravitic_wave_projector = true}

function Grid.dimensions(item, rotated)
    local data = item.data or item
    local size = data.cargoSize
    if not footprints[size] then
        if data.equipType == 'weapon' then size = largeWeapons[data.id] and 6 or (data.id == 'basic_laser_pistol' and 2 or 4)
        elseif data.category == 'equipable' or data.category == 'passive' then size = 2
        else size = 1 end
    end
    local shape = footprints[size]
    if rotated == nil then rotated = item.rotated end
    if rotated and size == 6 then return shape[2], shape[1] end
    return shape[1], shape[2]
end

function Grid.canRotate(item)
    local w, h = Grid.dimensions(item, false)
    return w * h == 6
end

function Grid.claim(cells, anchor, item, rotated, columns)
    columns = columns or Grid.columns
    local w, h = Grid.dimensions(item, rotated)
    for y = 0, h - 1 do
        for x = 0, w - 1 do cells[anchor + y * columns + x] = anchor end
    end
end

function Grid.occupancy(items, skipA, skipB, columns)
    local cells = {}
    for anchor, item in pairs(items) do
        if anchor ~= skipA and anchor ~= skipB then Grid.claim(cells, anchor, item, nil, columns) end
    end
    return cells
end

function Grid.fits(cells, capacity, anchor, item, rotated, columns)
    columns = columns or Grid.columns
    if not anchor or anchor < 1 or anchor > capacity then return false end
    local w, h = Grid.dimensions(item, rotated)
    if (anchor - 1) % columns + w > columns
        or anchor + (h - 1) * columns + w - 1 > capacity then return false end
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            if cells[anchor + y * columns + x] then return false end
        end
    end
    return true
end

function Grid.find(cells, capacity, item, columns)
    local rotatable = Grid.canRotate(item)
    local rotated = rotatable and item.rotated == true
    for attempt = 1, rotatable and 2 or 1 do
        local orientation = (attempt == 1 and rotated) or (attempt == 2 and not rotated)
        for anchor = 1, capacity do
            if Grid.fits(cells, capacity, anchor, item, orientation, columns) then return anchor, orientation end
        end
    end
end

-- Place the larger pieces first. The first free cell must be an anchor or a gap.
function Grid.pack(capacity, items, columns)
    columns = columns or Grid.columns
    local groups = {[1] = {}, [2] = {}, [4] = {}, [6] = {}}
    local remaining = 0
    for _, item in ipairs(items) do
        local w, h = Grid.dimensions(item)
        local area = w * h
        local group = groups[area]
        group[#group + 1] = item
        remaining = remaining + area
    end
    if remaining > capacity or #groups[2] > math.floor(columns / 2) * math.floor(capacity / columns) then return nil end

    local sizes = {6, 4, 2}
    local cells, packed, failed, bits = {}, {}, {}, {}
    for slot = 1, capacity do bits[slot] = 2 ^ (slot - 1) end
    local counts = {[2] = #groups[2], [4] = #groups[4], [6] = #groups[6]}
    local function search(anchor, free, area, mask)
        if area == #groups[1] then return true end
        while anchor <= capacity and cells[anchor] do anchor = anchor + 1 end
        local key = (((mask * 17 + counts[2]) * 9 + counts[4]) * 6 + counts[6])
        if failed[key] then return false end
        for _, size in ipairs(sizes) do
            local count = counts[size]
            if count > 0 then
                local item = groups[size][#groups[size] - count + 1]
                local preferred = size == 6 and item.rotated == true
                for attempt = 1, size == 6 and 2 or 1 do
                    local rotated = (attempt == 1 and preferred) or (attempt == 2 and not preferred)
                    if Grid.fits(cells, capacity, anchor, item, rotated, columns) then
                        local w, h = Grid.dimensions(item, rotated)
                        local nextMask = mask
                        for y = 0, h - 1 do
                            for x = 0, w - 1 do
                                local slot = anchor + y * columns + x
                                cells[slot], nextMask = true, nextMask + bits[slot]
                            end
                        end
                        counts[size] = count - 1
                        packed[anchor] = {item = item, rotated = rotated}
                        if search(anchor + 1, free - size, area - size, nextMask) then return true end
                        packed[anchor], counts[size] = nil, count
                        for y = 0, h - 1 do
                            for x = 0, w - 1 do cells[anchor + y * columns + x] = nil end
                        end
                    end
                end
            end
        end
        if free > area then
            cells[anchor] = true
            local result = search(anchor + 1, free - 1, area, mask + bits[anchor])
            cells[anchor] = nil
            if result then return true end
        end
        failed[key] = true
        return false
    end

    if not search(1, capacity, remaining, 0) then return nil end
    local slot = 1
    for _, item in ipairs(groups[1]) do
        while cells[slot] do slot = slot + 1 end
        packed[slot], cells[slot] = {item = item, rotated = false}, true
    end
    return packed
end

return Grid
