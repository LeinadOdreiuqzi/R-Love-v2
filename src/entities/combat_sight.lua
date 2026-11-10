local Query = require 'src.physics.projectiles.collision_query'
local Sight = {}

function Sight.intersects(x, y, tx, ty, cx, cy, radius)
    local dx, dy = tx - x, ty - y
    local length = dx * dx + dy * dy
    if length == 0 then return false end
    local t = math.max(0, math.min(1, ((cx - x) * dx + (cy - y) * dy) / length))
    return (x + dx * t - cx)^2 + (y + dy * t - cy)^2 < radius^2
end

function Sight.clear(ship, tx, ty)
    local x, y = ship.x, ship.y
    if ship.combatContext then
        local meta = ship.combatContext.meta or {}
        local stations = package.loaded['src.sublevels.stations_debug_world']
        if meta.subworldId == 'stations_debug' and stations then
            for _, station in ipairs(stations.stations or {}) do
                if Sight.intersects(x, y, tx, ty, station.x, station.y, (station.size or 120) * .45) then return false end
            end
        end
        return true
    end

    local map = package.loaded['src.maps.map']
    local config = package.loaded['src.maps.config.map_config']
    if not map or not map.getChunkNonBlocking or not config then return true end
    local grid = config.chunk
    local scale = grid.worldScale or 1
    local tile = grid.tileSize * scale
    local stride = tile * grid.size + (grid.spacing or 0) * scale
    local asteroids = config.asteroids or {}
    local sizes = asteroids.baseSizes or {8, 15, 25}
    local sizeScale = (asteroids.sizeScale or 1) * scale
    local margin = math.max(sizes[1], sizes[2], sizes[3]) * sizeScale * 1.26
    local left, right = math.min(x, tx) - margin, math.max(x, tx) + margin
    local top, bottom = math.min(y, ty) - margin, math.max(y, ty) + margin
    local minX, maxX = math.floor(left / stride), math.floor(right / stride)
    local minY, maxY = math.floor(top / stride), math.floor(bottom / stride)
    local query = Query.begin(map)
    for _, obj in ipairs(Query.solids(query, minX, maxX, minY, maxY, stride, scale)) do
        if Sight.intersects(x, y, tx, ty, obj.x, obj.y, obj.radius) then return false end
    end
    local types = config.ObjectType
    for cy = minY, maxY do
        for cx = minX, maxX do
            local chunk = Query.get(query, cx, cy)
            if chunk and chunk.tiles then
                local ox, oy = cx * stride, cy * stride
                for iy = math.max(0, math.floor((top - oy) / tile)), math.min(grid.size - 1, math.ceil((bottom - oy) / tile)) do
                    local row = chunk.tiles[iy]
                    if row then
                        for ix = math.max(0, math.floor((left - ox) / tile)), math.min(grid.size - 1, math.ceil((right - ox) / tile)) do
                            local kind = row[ix]
                            if kind and kind >= types.ASTEROID_SMALL and kind <= types.ASTEROID_LARGE then
                                local gx, gy = cx * grid.size + ix, cy * grid.size + iy
                                local seed = (gx * 1103515245 + gy * 12345 + kind * 2654435761) % 4294967296
                                seed = (seed * 1664525 + 1013904223) % 4294967296
                                local radius = (sizes[kind] or 15) * sizeScale * (.8 + seed / 4294967296 * .4) * 1.05
                                if Sight.intersects(x, y, tx, ty, ox + ix * tile, oy + iy * tile, radius) then return false end
                            end
                        end
                    end
                end
            end
        end
    end
    return true
end

return Sight
