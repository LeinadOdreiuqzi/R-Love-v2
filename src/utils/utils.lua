-- src/utils.lua

local Utils = {}

-- Función para calcular la distancia entre dos puntos
function Utils.distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- Función para verificar colisión entre dos rectángulos
function Utils.checkCollision(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and
           x2 < x1 + w1 and
           y1 < y2 + h2 and
           y2 < y1 + h1
end

-- Función para limitar un valor entre un mínimo y máximo
function Utils.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Función para interpolar linealmente entre dos valores
function Utils.lerp(a, b, t)
    return a + (b - a) * t
end

-- Función para generar un número aleatorio entre min y max
function Utils.randomRange(min, max)
    return math.random() * (max - min) + min
end

return Utils

