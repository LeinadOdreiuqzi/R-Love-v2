-- src/states/station/decor.lua

local Decor = {}
local Perlin = require 'src.maps.perlin_noise'
local SeedSystem = require 'src.utils.seed_system'

local function rectsIntersect(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

-- Genera decoraciones simples (paneles, cajas) evitando colisionar con plataformas
function Decor.decorateRoom(room, seed)
    local rng = SeedSystem.makeRNG(seed or 0)
    Perlin.init(seed or 0)

    local decos = {}
    local attempts = 120
    for _ = 1, attempts do
        local w, h = rng:randomInt(16, 48), rng:randomInt(8, 20)
        local x = room.x + rng:randomInt(16, room.width - w - 16)
        -- y en coordenadas de mundo (consistente con plataformas/puertas)
        local y = room.y + rng:randomInt(16, room.height - h - 16)
        -- Evitar plataformas y puertas (usar coords mundiales)
        local collides = false
        for _, p in ipairs(room.platforms or {}) do
            if rectsIntersect(x, y, w, h, p.x, p.y, p.w, p.h) then collides = true; break end
        end
        for _, d in pairs(room.doors or {}) do
            if rectsIntersect(x, y, w, h, d.x, d.y, d.w, d.h) then collides = true; break end
        end
        if not collides then
            local n = Perlin.noise(x * 0.01, y * 0.01, 0)
            local kind = (n > 0.3) and 'panel' or ((n < -0.3) and 'rubble' or 'crate')
            table.insert(decos, { x = x, y = y, w = w, h = h, kind = kind })
        end
    end
    return decos
end

return Decor