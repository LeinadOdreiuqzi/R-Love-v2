-- A batch spans one owner's projectile update, never a frame or a world change.
-- Missing chunks are cached too: requesting the same asynchronous load hundreds
-- of times cannot make it complete before this synchronous batch ends.
local Query = {}

function Query.begin(map)
    return {map = map, columns = {}, regions = {}}
end

function Query.solids(batch, minX, maxX, minY, maxY, stride, scale)
    local key = minX .. ':' .. maxX .. ':' .. minY .. ':' .. maxY
    local found = batch.regions[key]
    if found then return found end
    found = {}
    for y = minY - 2, maxY + 2 do
        for x = minX - 2, maxX + 2 do
            local chunk = Query.get(batch, x, y)
            for _, obj in ipairs(chunk and chunk.specialObjects or {}) do
                if obj.type == 'mega_asteroid' or obj.type == 'dead_star' then
                    found[#found + 1] = {x = x * stride + (obj.x or 0) * scale,
                        y = y * stride + (obj.y or 0) * scale, radius = (obj.size or 30) * .90}
                end
            end
        end
    end
    batch.regions[key] = found
    return found
end

function Query.get(batch, x, y)
    local column = batch.columns[x]
    if not column then column = {}; batch.columns[x] = column end
    local chunk = column[y]
    if chunk == nil then
        chunk = batch.map.getChunkNonBlocking(x, y) or false
        column[y] = chunk
    end
    return chunk or nil
end

return Query
