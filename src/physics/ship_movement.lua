local Movement = {}

-- Swept circle against local solid circles. Unlike endpoint penetration tests,
-- this also stops a long displacement from crossing an entire obstacle.
function Movement.constrain(x, y, targetX, targetY, radius, bounds, solids)
    targetX = math.max(bounds.minX + radius, math.min(bounds.maxX - radius, targetX))
    targetY = math.max(bounds.minY + radius, math.min(bounds.maxY - radius, targetY))
    local dx, dy = targetX - x, targetY - y
    local lengthSq, fraction = dx * dx + dy * dy, 1
    if lengthSq == 0 then return targetX, targetY end
    for _, solid in ipairs(solids or {}) do
        local sx, sy = x - solid.x, y - solid.y
        local r = radius + (solid.radius or (solid.size or 120) * .45)
        local c, b = sx * sx + sy * sy - r * r, sx * dx + sy * dy
        if c < 0 then
            -- Permit escape from an overlapping spawn, but never move deeper.
            if b < 0 then fraction = 0 end
        elseif b < 0 then
            local discriminant = b * b - lengthSq * c
            if discriminant >= 0 then
                local hit = (-b - math.sqrt(discriminant)) / lengthSq
                if hit >= 0 and hit <= fraction then fraction = math.max(0, hit - .001) end
            end
        end
    end
    return x + dx * fraction, y + dy * fraction
end

return Movement
