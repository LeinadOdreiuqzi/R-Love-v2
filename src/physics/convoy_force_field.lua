local Field = {
    points = {{-1.24, -3.23}, {1.24, -3.23}, {2.73, -1.66}, {2.73, 1.40},
        {1.30, 2.86}, {-1.30, 2.86}, {-2.73, 1.40}, {-2.73, -1.66}},
    flashDuration = .32
}

function Field.scale(ship)
    return ship.size * (ship.worldScale or 1)
end

function Field.toLocal(ship, x, y)
    local dx, dy = x - ship.x, y - ship.y
    local cos, sin = math.cos(ship.rotation), math.sin(ship.rotation)
    local size = Field.scale(ship)
    return (dx * cos + dy * sin) / size, (dy * cos - dx * sin) / size
end

-- Clip the swept projectile against the inward-facing half-planes.
local edges = {}
local radiusSquared = 0
for index, point in ipairs(Field.points) do
    local nextPoint = Field.points[index % #Field.points + 1]
    local dx, dy = nextPoint[1] - point[1], nextPoint[2] - point[2]
    local length = math.sqrt(dx * dx + dy * dy)
    local nx, ny = -dy / length, dx / length
    edges[index] = {nx, ny, nx * point[1] + ny * point[2]}
    radiusSquared = math.max(radiusSquared, point[1]^2 + point[2]^2)
end
Field.radius = math.sqrt(radiusSquared)

function Field.intersect(ship, x1, y1, x2, y2, radius)
    local ax, ay = Field.toLocal(ship, x1, y1)
    local bx, by = Field.toLocal(ship, x2, y2)
    local margin = radius / Field.scale(ship)
    local enter, leave = 0, 1
    for _, edge in ipairs(edges) do
        local start = edge[1] * ax + edge[2] * ay - edge[3] + margin
        local finish = edge[1] * bx + edge[2] * by - edge[3] + margin
        if start < 0 and finish < 0 then return false end
        if start < 0 then enter = math.max(enter, start / (start - finish)) end
        if finish < 0 then leave = math.min(leave, start / (start - finish)) end
        if enter > leave then return false end
    end
    return true, x1 + (x2 - x1) * enter, y1 + (y2 - y1) * enter
end

return Field
