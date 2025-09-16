-- src/states/station/room_templates.lua

local Templates = {}

-- Utilidades para coherencia espacial
local function snap(n, grid)
    grid = grid or 8
    return math.floor(n / grid + 0.5) * grid
end
local function clamp(v, a, b)
    if v < a then return a elseif v > b then return b else return v end
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

local function makeLinear(rng)
    local wBase, hBase = 960, 540
    local w = snap(wBase + (rng and rng:randomInt(-80, 80) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-40, 40) or 0), 8)
    local ground = { x = 0, y = h - 56, w = w, h = 56 }

    -- Plataforma central a altura alcanzable
    local midY = ground.y - clamp((rng and rng:randomInt(88, 110) or 96), 80, MAX_STEP_H)
    local midW = (rng and rng:randomInt(300, 380) or 340)
    local midX = clamp((rng and rng:randomInt(200, w - midW - 200) or math.floor((w-midW)/2)), 96, w - midW - 96)
    local mid = { x = snap(midX), y = snap(midY), w = snap(midW), h = 24 }

    local doors = {
        left = { x = 0, y = h - 56 - 64, w = 24, h = 64, side = 'left' },
        right = { x = w - 24, y = h - 56 - 64, w = 24, h = 64, side = 'right' }
    }
    local vdoors = defaultVerticalDoors(w, h)
    for k, v in pairs(vdoors) do doors[k] = v end

    -- Repisa debajo de la puerta superior
    local up = doors.up
    local helper = { x = clamp(up.x + 32 - 56, 0, w - 112), y = up.y + up.h + 8, w = 112, h = 12 }

    local plats = { ground, mid, helper }
    return { name = 'linear', width = w, height = h, platforms = plats, doors = doors, spawn = { x = 80, y = ground.y - 64 } }
end

local function makeStairs(rng)
    local wBase, hBase = 1000, 560
    local w = snap(wBase + (rng and rng:randomInt(-80, 100) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-40, 40) or 0), 8)
    local ground = { x = 0, y = h - 56, w = w, h = 56 }

    local steps = {}
    local stepCount = (rng and rng:randomInt(3, 5) or 4)
    local stepH = (rng and rng:randomInt(72, MAX_STEP_H) or 88)
    local sx = 144
    local sy = ground.y - 160
    for i = 1, stepCount do
        sy = sy - stepH
        local sw = (rng and rng:randomInt(160, 220) or 192)
        table.insert(steps, { x = snap(sx), y = snap(sy), w = snap(sw), h = 24 })
        sx = sx + (rng and rng:randomInt(160, 220) or 200)
    end

    local doors = {
        left = { x = 0, y = h - 56 - 64, w = 24, h = 64, side = 'left' },
        right = { x = w - 24, y = h - 56 - 64, w = 24, h = 64, side = 'right' }
    }
    local vdoors = defaultVerticalDoors(w, h)
    for k, v in pairs(vdoors) do doors[k] = v end

    local plats = { ground }
    for _, s in ipairs(steps) do table.insert(plats, s) end
    local up = doors.up
    table.insert(plats, { x = clamp(up.x + 32 - 56, 0, w - 112), y = up.y + up.h + 8, w = 112, h = 12 })
    return { name = 'stairs', width = w, height = h, platforms = plats, doors = doors, spawn = { x = 90, y = ground.y - 64 } }
end

local function makeTwoTiers(rng)
    local wBase, hBase = 1040, 560
    local w = snap(wBase + (rng and rng:randomInt(-100, 120) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-40, 60) or 0), 8)
    local ground = { x = 0, y = h - 56, w = w, h = 56 }

    local upperY = ground.y - (rng and rng:randomInt(220, 260) or 240)
    local upperW = clamp((rng and rng:randomInt(math.floor(w * 0.6), math.floor(w * 0.8)) or (w - 300)), 480, w - 160)
    local upperX = clamp((rng and rng:randomInt(80, math.max(80, w - upperW - 80)) or 140), 64, w - upperW - 64)
    local upper = { x = snap(upperX), y = snap(upperY), w = snap(upperW), h = 24 }

    -- Escalera lateral para alcanzar el nivel superior con peldaños seguros
    local ladder = {}
    local stepH = (rng and rng:randomInt(72, MAX_STEP_H) or 88)
    local ly = upper.y + 24 + stepH
    local lx = upper.x - (rng and rng:randomInt(140, 180) or 160)
    local stepsCount = 3
    for i=1,stepsCount do
        table.insert(ladder, { x = snap(lx + (i-1)*64), y = snap(ly + (stepsCount-i)*stepH), w = 96, h = 20 })
    end

    local doors = {
        left = { x = 0, y = h - 56 - 64, w = 24, h = 64, side = 'left' },
        right = { x = w - 24, y = h - 56 - 64, w = 24, h = 64, side = 'right' }
    }
    local vdoors = defaultVerticalDoors(w, h)
    for k, v in pairs(vdoors) do doors[k] = v end

    local plats = { ground, upper }
    for _,p in ipairs(ladder) do table.insert(plats, p) end
    local up = doors.up
    table.insert(plats, { x = clamp(up.x + 32 - 56, 0, w - 112), y = up.y + up.h + 8, w = 112, h = 12 })
    return { name = 'two_tiers', width = w, height = h, platforms = plats, doors = doors, spawn = { x = 70, y = ground.y - 64 } }
end

local function makeLargeHangar(rng)
    local wBase, hBase = 1600, 720
    local w = snap(wBase + (rng and rng:randomInt(-120, 160) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-80, 80) or 0), 8)
    local ground = { x = 0, y = h - 56, w = w, h = 56 }

    local mid1 = { x = snap((rng and rng:randomInt(120, 260) or 200)), y = snap(ground.y - (rng and rng:randomInt(140, 180) or 160)), w = snap((rng and rng:randomInt(420, 560) or 500)), h = 24 }
    local mid2 = { x = snap((rng and rng:randomInt(760, 980) or 900)), y = snap(ground.y - (rng and rng:randomInt(200, 240) or 220)), w = snap((rng and rng:randomInt(420, 560) or 480)), h = 24 }
    local catwalk = { x = snap(100), y = snap(ground.y - (rng and rng:randomInt(320, 360) or 340)), w = snap(math.max(800, w - 200)), h = 18 }

    -- Escalera a la pasarela superior
    local ladder = {}
    local stepH = (rng and rng:randomInt(72, MAX_STEP_H) or 88)
    local baseX = 120
    for i=1,4 do
        local y = snap(catwalk.y + (4 - i + 1) * stepH)
        local x = snap(baseX + (i-1) * 80)
        table.insert(ladder, { x = x, y = y, w = 96, h = 20 })
    end

    local doors = {
        left = { x = 0, y = h - 56 - 80, w = 24, h = 80, side = 'left' },
        right = { x = w - 24, y = h - 56 - 80, w = 24, h = 80, side = 'right' }
    }
    local vdoors = defaultVerticalDoors(w, h)
    for k, v in pairs(vdoors) do doors[k] = v end

    local plats = { ground, mid1, mid2, catwalk }
    for _, p in ipairs(ladder) do table.insert(plats, p) end
    local up = doors.up
    table.insert(plats, { x = clamp(up.x + 32 - 56, 0, w - 112), y = up.y + up.h + 8, w = 112, h = 12 })
    return { name = 'large_hangar', width = w, height = h, platforms = plats, doors = doors, spawn = { x = 80, y = ground.y - 64 } }
end

local function makeVerticalShaft(rng)
    local wBase, hBase = 900, 1200
    local w = snap(wBase + (rng and rng:randomInt(-100, 120) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-200, 200) or 0), 8)
    local ground = { x = 0, y = h - 56, w = w, h = 56 }

    local tiers = {}
    local count = (rng and rng:randomInt(7, 10) or 8)
    local yCur = ground.y - 160
    local stepH = (rng and rng:randomInt(88, MAX_STEP_H) or 96)
    for i = 1, count do
        yCur = yCur - stepH
        local leftSide = (i % 2 == 0)
        local px = leftSide and (rng and rng:randomInt(80, 180) or 120) or (rng and rng:randomInt(math.floor(w*0.55), math.floor(w*0.75)) or 520)
        local pw = (rng and rng:randomInt(300, 420) or 360)
        table.insert(tiers, { x = snap(px), y = snap(yCur), w = snap(pw), h = 22 })
    end

    local doors = {
        left = { x = 0, y = h - 56 - 80, w = 24, h = 80, side = 'left' },
        right = { x = w - 24, y = h - 56 - 80, w = 24, h = 80, side = 'right' }
    }
    local vdoors = defaultVerticalDoors(w, h)
    for k, v in pairs(vdoors) do doors[k] = v end

    local plats = { ground }
    for _, p in ipairs(tiers) do table.insert(plats, p) end
    local up = doors.up
    table.insert(plats, { x = clamp(up.x + 32 - 56, 0, w - 112), y = up.y + up.h + 8, w = 112, h = 12 })
    return { name = 'vertical_shaft', width = w, height = h, platforms = plats, doors = doors, spawn = { x = 70, y = ground.y - 64 } }
end

local function makeAtriumMultiTier(rng)
    local wBase, hBase = 1400, 900
    local w = snap(wBase + (rng and rng:randomInt(-140, 180) or 0), 8)
    local h = snap(hBase + (rng and rng:randomInt(-120, 160) or 0), 8)
    local ground = { x = 0, y = h - 56, w = w, h = 56 }

    local ring1Y = ground.y - (rng and rng:randomInt(200, 240) or 220)
    local ring2Y = ground.y - (rng and rng:randomInt(360, 420) or 380)
    local ring1 = { x = snap((rng and rng:randomInt(80, 180) or 120)), y = snap(ring1Y), w = snap(w - (rng and rng:randomInt(200, 300) or 240)), h = 24 }
    local ring2 = { x = snap((rng and rng:randomInt(180, 300) or 240)), y = snap(ring2Y), w = snap(w - (rng and rng:randomInt(460, 560) or 500)), h = 24 }

    local bridges = {
        { x = snap(w * 0.5 - (rng and rng:randomInt(160, 220) or 200)), y = snap(ground.y - (rng and rng:randomInt(420, 480) or 440)), w = snap((rng and rng:randomInt(300, 420) or 360)), h = 18 },
        { x = snap(w * 0.5 - (rng and rng:randomInt(120, 180) or 160)), y = snap(ground.y - (rng and rng:randomInt(240, 300) or 270)), w = snap((rng and rng:randomInt(240, 360) or 300)), h = 18 },
    }

    -- Conectores verticales tipo escalera en extremos
    local connectors = {}
    local stepH = (rng and rng:randomInt(72, MAX_STEP_H) or 88)
    local cx = 120
    local y = ring1.y + stepH
    table.insert(connectors, { x = snap(cx), y = snap(y), w = 100, h = 20 })
    y = y + stepH
    table.insert(connectors, { x = snap(cx + 80), y = snap(y), w = 100, h = 20 })
    -- ring1 -> ring2
    y = ring2.y + stepH
    table.insert(connectors, { x = snap(w - 220), y = snap(y), w = 100, h = 20 })
    y = y + stepH
    table.insert(connectors, { x = snap(w - 300), y = snap(y), w = 100, h = 20 })

    local doors = {
        left = { x = 0, y = h - 56 - 80, w = 24, h = 80, side = 'left' },
        right = { x = w - 24, y = h - 56 - 80, w = 24, h = 80, side = 'right' }
    }
    local vdoors = defaultVerticalDoors(w, h)
    for k, v in pairs(vdoors) do doors[k] = v end

    local plats = { ground, ring1, ring2 }
    for _, b in ipairs(bridges) do table.insert(plats, b) end
    for _, c in ipairs(connectors) do table.insert(plats, c) end
    local up = doors.up
    table.insert(plats, { x = clamp(up.x + 32 - 56, 0, w - 112), y = up.y + up.h + 8, w = 112, h = 12 })
    return { name = 'atrium_multi_tier', width = w, height = h, platforms = plats, doors = doors, spawn = { x = 120, y = ground.y - 64 } }
end

Templates.list = {
    linear = makeLinear,
    stairs = makeStairs,
    two_tiers = makeTwoTiers,
    large_hangar = makeLargeHangar,
    vertical_shaft = makeVerticalShaft,
    atrium_multi_tier = makeAtriumMultiTier,
}

function Templates.build(name, rng)
    local ctor = Templates.list[name] or makeLinear
    local room = ctor(rng)
    return room
end

function Templates.randomName(rng)
    local keys = { 'linear', 'stairs', 'two_tiers', 'large_hangar', 'vertical_shaft', 'atrium_multi_tier' }
    local idx = rng and rng:randomInt(1, #keys) or math.random(1, #keys)
    return keys[idx]
end

return Templates