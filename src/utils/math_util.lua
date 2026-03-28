-- src/utils/math_util.lua
-- Utilidades matemáticas para el proyecto

local MathUtil = {}

-- Interpolación lineal (lerp)
function MathUtil.lerp(a, b, t)
    return a + (b - a) * t
end

-- Interpolación angular suave (evita saltos al cruzar 0/360 grados)
function MathUtil.lerpAngle(a, b, t)
    local diff = (b - a) % (2 * math.pi)
    if diff > math.pi then
        diff = diff - 2 * math.pi
    elseif diff < -math.pi then
        diff = diff + 2 * math.pi
    end
    return a + diff * t
end

-- Limitar un valor entre un mínimo y un máximo
function MathUtil.clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

-- Distancia entre dos puntos
function MathUtil.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

return MathUtil
