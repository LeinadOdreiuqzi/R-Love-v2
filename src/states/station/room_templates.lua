-- src/states/station/room_templates.lua

local Templates = {}

-- Utilidades para coherencia espacial
local function snap(n, grid)
    grid = grid or 8
    return math.floor(n / grid + 0.5) * grid
end
-- Salto del jugador de referencia (para no depender siempre del jetpack)
-- Con jumpVelocity=600 y gravity=1700, altura ~106 px. Diseñamos gaps verticales <= 96-110.
local MAX_STEP_H = 96

local function defaultVerticalDoors(w, h)
    -- Puertas verticales centradas y accesibles: arriba más baja y abajo por encima del suelo
    return {
        up   = { x = snap(w*0.5 - 32), y = 48,          w = 64, h = 24, side = 'up' },
        down = { x = snap(w*0.5 - 32), y = h - 56 - 40, w = 64, h = 24, side = 'down' },
    }
end
local function makeEntrance(rng)
    -- TODO: Plantilla simplificada - preparada para reintroducir mecánicas elaboradas
    local wBase, hBase = 1500, 900
    local w = snap(wBase + (rng and rng:randomInt(-120, 150) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-90, 120) or 0), 8)
    local ground = { x = 0, y = h - 84, w = w, h = 84 }

    local doors = {
        right = { x = w - 36, y = h - 84 - 96, w = 36, h = 96, side = 'right' }
    }
    local vdoors = defaultVerticalDoors(w, h)
    for k, v in pairs(vdoors) do doors[k] = v end

    return { name = 'entrance', category = 'entrance', width = w, height = h, platforms = { ground }, doors = doors, spawn = { x = 120, y = ground.y - 96 } }
end

local function makeCorridor(rng)
    -- TODO: Plantilla simplificada - preparada para reintroducir mecánicas elaboradas
    local wBase, hBase = 1200, 480
    local w = snap(wBase + (rng and rng:randomInt(-90, 120) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-40, 60) or 0), 8)
    local ground = { x = 0, y = h - 84, w = w, h = 84 }

    local doors = {
        left = { x = 0, y = h - 84 - 96, w = 36, h = 96, side = 'left' },
        right = { x = w - 36, y = h - 84 - 96, w = 36, h = 96, side = 'right' },
    }
    local vdoors = defaultVerticalDoors(w, h)
    for k, v in pairs(vdoors) do doors[k] = v end

    return { name = 'corridor', category = 'corridor', width = w, height = h, platforms = { ground }, doors = doors, spawn = { x = 90, y = ground.y - 96 } }
end

local function makeTransition(rng)
    -- TODO: Plantilla simplificada - preparada para reintroducir mecánicas elaboradas
    local wBase, hBase = 1440, 720
    local w = snap(wBase + (rng and rng:randomInt(-120, 150) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-60, 90) or 0), 8)
    local ground = { x = 0, y = h - 84, w = w, h = 84 }

    local doors = {
        left = { x = 0, y = h - 84 - 96, w = 36, h = 96, side = 'left' },
        right = { x = w - 36, y = h - 84 - 96, w = 36, h = 96, side = 'right' }
    }
    local vdoors = defaultVerticalDoors(w, h); for k, v in pairs(vdoors) do doors[k] = v end

    return { name = 'transition', category = 'common', width = w, height = h, platforms = { ground }, doors = doors, spawn = { x = 120, y = ground.y - 96 } }
end

local function makeFillerA(rng)
    -- TODO: Plantilla simplificada - preparada para reintroducir mecánicas elaboradas
    local wBase, hBase = 1560, 900
    local w = snap(wBase + (rng and rng:randomInt(-120, 150) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-90, 120) or 0), 8)
    local ground = { x = 0, y = h - 84, w = w, h = 84 }

    local doors = { left = { x = 0, y = h - 84 - 96, w = 36, h = 96, side = 'left' }, right = { x = w - 36, y = h - 84 - 96, w = 36, h = 96, side = 'right' } }
    local vdoors = defaultVerticalDoors(w, h); for k, v in pairs(vdoors) do doors[k] = v end

    return { name = 'filler_a', category = 'filler', width = w, height = h, platforms = { ground }, doors = doors, spawn = { x = 120, y = ground.y - 96 } }
end

local function makeFillerB(rng)
    -- TODO: Plantilla simplificada - preparada para reintroducir mecánicas elaboradas
    local wBase, hBase = 1680, 960
    local w = snap(wBase + (rng and rng:randomInt(-150, 180) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-90, 120) or 0), 8)
    local ground = { x = 0, y = h - 84, w = w, h = 84 }

    local doors = { left = { x = 0, y = h - 84 - 96, w = 36, h = 96, side = 'left' }, right = { x = w - 36, y = h - 84 - 96, w = 36, h = 96, side = 'right' } }
    local vdoors = defaultVerticalDoors(w, h); for k, v in pairs(vdoors) do doors[k] = v end

    return { name = 'filler_b', category = 'filler', width = w, height = h, platforms = { ground }, doors = doors, spawn = { x = 150, y = ground.y - 96 } }
end

local function makeReactor(rng)
    -- TODO: Plantilla simplificada - preparada para reintroducir mecánicas elaboradas
    local wBase, hBase = 1560, 900
    local w = snap(wBase + (rng and rng:randomInt(-120, 150) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-90, 120) or 0), 8)
    local ground = { x = 0, y = h - 84, w = w, h = 84 }

    local doors = { left = { x = 0, y = h - 84 - 96, w = 36, h = 96, side = 'left' }, right = { x = w - 36, y = h - 84 - 96, w = 36, h = 96, side = 'right' } }
    local vdoors = defaultVerticalDoors(w, h); for k, v in pairs(vdoors) do doors[k] = v end

    return { name = 'reactor', category = 'specialized', width = w, height = h, platforms = { ground }, doors = doors, spawn = { x = 180, y = ground.y - 96 } }
end

local function makeHangar(rng)
    -- TODO: Plantilla simplificada - preparada para reintroducir mecánicas elaboradas
    local wBase, hBase = 1800, 960
    local w = snap(wBase + (rng and rng:randomInt(-150, 180) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-120, 120) or 0), 8)
    local ground = { x = 0, y = h - 84, w = w, h = 84 }

    local doors = { left = { x = 0, y = h - 84 - 96, w = 36, h = 96, side = 'left' }, right = { x = w - 36, y = h - 84 - 96, w = 36, h = 96, side = 'right' } }
    local vdoors = defaultVerticalDoors(w, h); for k, v in pairs(vdoors) do doors[k] = v end

    return { name = 'hangar', category = 'specialized', width = w, height = h, platforms = { ground }, doors = doors, spawn = { x = 180, y = ground.y - 96 } }
end

local function makeLaboratorio(rng)
    -- TODO: Plantilla simplificada - preparada para reintroducir mecánicas elaboradas
    local wBase, hBase = 1500, 900
    local w = snap(wBase + (rng and rng:randomInt(-120, 150) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-90, 120) or 0), 8)
    local ground = { x = 0, y = h - 84, w = w, h = 84 }

    local doors = { left = { x = 0, y = h - 84 - 96, w = 36, h = 96, side = 'left' }, right = { x = w - 36, y = h - 84 - 96, w = 36, h = 96, side = 'right' } }
    local vdoors = defaultVerticalDoors(w, h); for k, v in pairs(vdoors) do doors[k] = v end

    return { name = 'laboratorio', category = 'specialized', width = w, height = h, platforms = { ground }, doors = doors, spawn = { x = 180, y = ground.y - 96 } }
end

local function makeSecreto(rng)
    -- TODO: Plantilla simplificada - preparada para reintroducir mecánicas elaboradas
    local wBase, hBase = 1200, 720
    local w = snap(wBase + (rng and rng:randomInt(-90, 90) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-60, 60) or 0), 8)
    local ground = { x = 0, y = h - 84, w = w, h = 84 }

    local doors = {
        up = { x = snap(w*0.5 - 32), y = 0, w = 64, h = 24, side = 'up' }
    }
    return { name = 'secreto', category = 'specialized', width = w, height = h, platforms = { ground }, doors = doors, spawn = { x = w*0.5, y = ground.y - 96 } }
end

local function makeBoss(rng)
    -- TODO: Plantilla simplificada - preparada para reintroducir mecánicas elaboradas
    local wBase, hBase = 1920, 1080
    local w = snap(wBase + (rng and rng:randomInt(-150, 180) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-120, 150) or 0), 8)
    local ground = { x = 0, y = h - 84, w = w, h = 84 }

    local doors = {
        left = { x = 0, y = h - 84 - 120, w = 36, h = 120, side = 'left' },
        right = { x = w - 36, y = h - 84 - 120, w = 36, h = 120, side = 'right' }
    }
    local vdoors = defaultVerticalDoors(w, h); for k, v in pairs(vdoors) do doors[k] = v end

    return { name = 'boss', category = 'specialized', width = w, height = h, platforms = { ground }, doors = doors, spawn = { x = snap(w*0.5), y = ground.y - 96 } }
end

Templates.list = {
    entrance = makeEntrance,
    filler_a = makeFillerA,
    filler_b = makeFillerB,
    corridor = makeCorridor,
    transition = makeTransition,  -- Nueva sala de transición
    reactor = makeReactor,
    hangar = makeHangar,
    laboratorio = makeLaboratorio,
    secreto = makeSecreto,
    boss = makeBoss,
}

function Templates.build(name, rng)
    local ctor = Templates.list[name]
    if not ctor then
        ctor = makeCorridor
        name = 'corridor'
    end
    local room = ctor(rng)
    room.name = name
    return room
end

function Templates.randomByCategory(cat, rng)
    local r = rng and function(a,b) return rng:randomInt(a,b) end or function(a,b) return math.random(a,b) end
    if cat == 'entrance' then return 'entrance' end
    if cat == 'filler' then
        local keys = { 'filler_a', 'filler_b' }
        return keys[r(1,#keys)]
    end
    if cat == 'corridor' then return 'corridor' end
    if cat == 'common' then return 'transition' end  -- Nueva categoría para salas de transición
    if cat == 'specialized' then
        local keys = { 'reactor', 'hangar', 'laboratorio' }
        return keys[r(1,#keys)]
    end
    if cat == 'secret' then return 'secreto' end
    if cat == 'boss' then return 'boss' end
    return 'corridor'
end

function Templates.randomName(rng)
    local keys = { 'filler_a', 'filler_b', 'corridor', 'reactor', 'hangar', 'laboratorio' }
    local idx = rng and rng:randomInt(1, #keys) or math.random(1, #keys)
    return keys[idx]
end

return Templates