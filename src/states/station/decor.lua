-- src/states/station/decor.lua

local Decor = {}
local Perlin = require 'src.maps.perlin_noise'
local SeedSystem = require 'src.utils.seed_system'

local function rectsIntersect(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

-- Genera decoraciones simples (paneles, cajas) evitando colisionar con plataformas
-- Ajustado para reaccionar sutilmente a room.type (categoría)
function Decor.decorateRoom(room, seed)
    local rng = SeedSystem.makeRNG(seed or 0)
    Perlin.init(seed or 0)

    local decos = {}

    -- Factor por tipo de sala (menos ruido en entrada/secret/boss)
    local t = (room.type or room.category or 'generic')
    local typeFactor = 1.0
    if t == 'entrance' then typeFactor = 0.6
    elseif t == 'corridor' then typeFactor = 1.0
    elseif t == 'filler' then typeFactor = 1.1
    elseif t == 'specialized' then typeFactor = 0.9
    elseif t == 'secret' then typeFactor = 0.5
    elseif t == 'boss' then typeFactor = 0.4
    end

    -- Aumentar intentos en función del área y el factor de tipo
    local baseAttempts = math.max(140, math.floor(room.width * room.height / 2200))
    local attempts = math.floor(baseAttempts * typeFactor)
    attempts = math.max(40, math.min(attempts, 320))
    
    for _ = 1, attempts do
        -- Tamaños más variados para espacios ampliados
        local w, h = rng:randomInt(20, 72), rng:randomInt(12, 32)
        
        -- Márgenes ajustados para salas más grandes
        local marginX = math.max(20, room.width * 0.05)
        local marginY = math.max(20, room.height * 0.05)
        
        local x = room.x + rng:randomInt(marginX, math.max(marginX, room.width - w - marginX))
        local y = room.y + rng:randomInt(marginY, math.max(marginY, room.height - h - marginY))
        
        -- Evitar plataformas y puertas (usar coords mundiales)
        local collides = false
        for _, p in ipairs(room.platforms or {}) do
            if rectsIntersect(x, y, w, h, p.x, p.y, p.w, p.h) then collides = true; break end
        end
        for _, d in pairs(room.doors or {}) do
            if rectsIntersect(x, y, w, h, d.x, d.y, d.w, d.h) then collides = true; break end
        end
        
        -- Evitar solapamiento con decoraciones existentes para mejor distribución
        for _, existing in ipairs(decos) do
            if rectsIntersect(x, y, w, h, existing.x, existing.y, existing.w, existing.h) then
                collides = true
                break
            end
        end
        
        if not collides then
            local n = Perlin.noise(x * 0.008, y * 0.008, 0)  -- Escala ajustada para espacios más grandes
            -- Distribución por tipo: más 'panel' en specialized/corridor; más 'crate' en filler/hangar; menos en boss/secret
            local biasPanel, biasRubble = 0, 0
            if t == 'specialized' then biasPanel = 0.10
            elseif t == 'corridor' then biasPanel = 0.05
            elseif t == 'filler' then biasPanel = -0.05
            elseif t == 'boss' or t == 'secret' then biasPanel = -0.10; biasRubble = -0.05
            end
            local v = n + biasPanel
            local kind = (v > 0.28) and 'panel' or ((n + biasRubble < -0.25) and 'rubble' or 'crate')
            table.insert(decos, { x = x, y = y, w = w, h = h, kind = kind })
        end
    end
    
    return decos
end

return Decor