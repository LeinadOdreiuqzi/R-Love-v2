-- Shared textured composition. Effects belong to the firing ship and outlive shots.
local VFX = {}
local profiles = {}
local atlas, quads, batch
local states = setmetatable({}, {__mode = 'k'})
local MAX_EFFECTS = 1800
local TILE = 64
local TILE_COUNT = 8
local TRAIL_POINTS = 16
local TRAIL_LIFE = .22
local MAX_TRAILS = 1200

local function flightAngle(p)
    local vx, vy = p:getVelocity()
    if vx * vx + vy * vy > .001 then return math.atan2(vy, vx) end
    return p:getAngle()
end

local function profile(id, family, r, g, b, size, rate)
    profiles[id] = {family = family, color = {r, g, b}, size = size, rate = rate}
end

profile('basic_laser_pistol', 'rail', 1, .25, .18, 3, 24)
profile('plasma_rifle', 'plasma', .15, .8, 1, 7, 35)
profile('kinetic_assault_rifle', 'crystal', 1, .8, .4, 3, 20)
profile('heavy_plasma_cannon', 'thermal', .4, .7, 1, 11, 30)
profile('energy_shotgun', 'plasma', .4, 1, .6, 4, 20)
profile('rotary_autocannon', 'rail', 1, .65, .25, 2, 16)
profile('gauss_railgun', 'rail', .35, .7, 1, 7, 40)
profile('ricochet_shard_gun', 'crystal', .5, 1, .85, 6, 24)
profile('flak_shrapnel_cannon', 'crystal', 1, .65, .3, 5, 20)
profile('prism_pulse_carbine', 'crystal', 1, .4, .9, 5, 28)
profile('arc_tesla_emitter', 'tesla', .3, .65, 1, 8, 30)
profile('phase_beam_lance', 'rail', .9, .35, 1, 9, 32)
profile('magma_slag_thrower', 'thermal', 1, .3, .06, 9, 26)
profile('cryo_shard_blaster', 'crystal', .3, .9, 1, 7, 24)
profile('solar_flare_mortar', 'thermal', 1, .7, .15, 13, 24)
profile('swarm_micro_missiles', 'rail', .65, 1, .3, 4, 25)
profile('heavy_torpedo_launcher', 'thermal', 1, .45, .2, 12, 22)
profile('industrial_rip_saw', 'saw', 1, .65, .2, 11, 30)
profile('gravitic_wave_projector', 'gravity', .65, .3, 1, 12, 24)
profile('void_needle_dart', 'gravity', .85, .3, 1, 5, 28)
profile('thermo_cluster_cannon', 'thermal', 1, .4, .12, 11, 32)
profile('photon_pulse_gatling', 'rail', 1, .9, .4, 4, 32)
profile('supernova_rail_lance', 'rail', 1, .6, .8, 12, 40)
profile('valkyrie_storm_swarm', 'tesla', .55, .85, 1, 7, 28)
profile('orbital_shredder', 'saw', .5, 1, .8, 15, 35)
profile('thermal_shock_cannon', 'thermal', .5, .8, 1, 12, 32)
profile('singularity_torpedo', 'gravity', .7, .4, 1, 18, 30)

function VFX.attach(projectile)
    projectile.vfxProfile = profiles[projectile.config.weaponId]
    projectile.vfxTimer = 0
    projectile.vfxLastX, projectile.vfxLastY = projectile.x, projectile.y
    projectile.vfxMods = projectile.config.visualMods or {}
end

-- Generate the shared texture atlas once, independently of the projectile count.
local function initialize()
    if atlas then return end
    local data = love.image.newImageData(TILE * TILE_COUNT, TILE)
    for tile = 0, TILE_COUNT - 1 do
        for y = 0, TILE - 1 do
            for x = 0, TILE - 1 do
                local dx, dy = (x - 31.5) / 31, (y - 31.5) / 31
                local radius = math.sqrt(dx * dx + dy * dy)
                local angle = math.atan2(dy, dx)
                local alpha
                if tile == 0 then
                    alpha = math.max(0, 1 - radius)^3
                elseif tile == 1 then
                    alpha = math.max(0, 1 - math.abs(radius - .72) / .09)
                elseif tile == 2 then
                    local edge = .7 + .13 * math.sin(angle * 12)
                    alpha = math.min(1, math.max(0, (edge - radius) * 35))
                    if radius < .25 then alpha = 0 end
                elseif tile == 3 then
                    alpha = math.max(0, 1 - math.abs(dx) - math.abs(dy) * 1.8)
                elseif tile == 7 then
                    alpha = math.min(1, math.max(0, (.62 - radius) * 40))
                elseif tile == 6 then
                    alpha = math.max(0, 1 - math.abs(dy))^2 * math.min(1, math.max(0, (1 - math.abs(dx)) * 16))
                else
                    local edge = .62 + .12 * math.sin(angle * 5 + tile) + .08 * math.cos(angle * 9 - tile)
                    alpha = math.max(0, math.min(1, (edge - radius) * 7))
                    alpha = alpha * (.65 + .35 * math.sin(radius * 24 + angle * 3 + tile)^2)
                end
                data:setPixel(tile * TILE + x, y, 1, 1, 1, alpha)
            end
        end
    end
    atlas = love.graphics.newImage(data)
    atlas:setFilter('linear', 'linear')
    data:release()
    quads = {}
    for i = 1, TILE_COUNT do quads[i] = love.graphics.newQuad((i - 1) * TILE, 0, TILE, TILE, TILE * TILE_COUNT, TILE) end
    batch = love.graphics.newSpriteBatch(atlas, 32768, 'stream')
end

local function stateFor(owner)
    if not owner then return end
    local state = owner.projectileVFX
    if not state then
        state = {effects = {}, free = {}, trails = {}, freeTrails = {}, time = 0}
        owner.projectileVFX = state
        states[state] = true
    end
    return state
end

local function emit(owner, kind, x, y, color, size, duration, vx, vy, x2, y2, family, angle)
    local state = stateFor(owner)
    if not state then return end
    local important = kind == 'impact' or kind == 'arc' or kind == 'ring'
    local limit = important and 350 or 260
    if #state.effects >= limit then return end
    local total = 0
    for live in pairs(states) do total = total + #live.effects end
    if total >= (important and MAX_EFFECTS or 1500) then return end
    local effect = table.remove(state.free) or {}
    effect.kind, effect.x, effect.y = kind, x, y
    effect.color, effect.size, effect.duration = color, size, duration
    effect.age, effect.vx, effect.vy = 0, vx or 0, vy or 0
    effect.x2, effect.y2, effect.family, effect.angle = x2, y2, family, angle or 0
    state.effects[#state.effects + 1] = effect
end

function VFX.pulse(owner, radius, color)
    emit(owner, 'ring', owner.x, owner.y, color, radius, .42)
end

local function addPoint(trail, x, y, time)
    trail.head = trail.head % TRAIL_POINTS + 1
    local point = trail.points[trail.head]
    point.x, point.y, point.time = x, y, time
    trail.count = math.min(TRAIL_POINTS, trail.count + 1)
end

local function updateTrail(p, state, x, y)
    local trail = p.vfxTrail
    if not trail then
        if #state.trails >= 600 then return end
        local total = 0
        for live in pairs(states) do total = total + #live.trails end
        if total >= MAX_TRAILS then return end
        trail = table.remove(state.freeTrails)
        if not trail then
            trail = {points = {}}
            for i = 1, TRAIL_POINTS do trail.points[i] = {} end
        end
        trail.head, trail.count, trail.owner = 0, 0, p
        trail.color = p.vfxProfile.color
        trail.width = math.max(1.5, p.vfxProfile.size * .4 * (p.scaleMultiplier or 1))
        trail.voltaic = p.vfxMods.voltaic
        addPoint(trail, p.vfxLastX, p.vfxLastY, state.time)
        state.trails[#state.trails + 1] = trail
        p.vfxTrail = trail
    end
    -- A teleport or debug reposition must not leave a streak across the map.
    local dx, dy = x - p.vfxLastX, y - p.vfxLastY
    if dx * dx + dy * dy > 500 * 500 then trail.count = 0 end
    addPoint(trail, x, y, state.time)
    trail.lastTime = state.time
end

function VFX.updateProjectile(p, dt)
    local style = p.vfxProfile
    if not style then return end
    local state = stateFor(p.owner)
    if not state then return end
    local x, y = p:getPosition()
    updateTrail(p, state, x, y)
    p.vfxLastX, p.vfxLastY = x, y
    if p:isDestroyed() then return end
    p.vfxTimer = p.vfxTimer + dt
    local interval = 1 / style.rate
    if p.vfxTimer < interval then return end
    p.vfxTimer = p.vfxTimer % interval
    if style.family == 'saw' or style.family == 'thermal' then
        local phase = p.age * 28
        local kind = style.family == 'saw' and 'spark' or 'ember'
        emit(p.owner, kind, x, y, style.color, 2, .25,
            math.cos(phase) * 45, math.sin(phase) * 45, nil, nil, style.family, phase)
    end
end

function VFX.impact(p, x, y, radius)
    local style = p.vfxProfile
    if not style then return end
    local family, angle = style.family, flightAngle(p)
    emit(p.owner, 'impact', x, y, style.color, style.size * 3, .36,
        0, 0, nil, nil, family, angle)
    -- This boundary is reserved for an actual area-damage event.
    if radius then emit(p.owner, 'ring', x, y, style.color, radius, .42) end
    for i = 1, 6 do
        local direction = angle + i * math.pi / 3
        if family == 'rail' then direction = angle + (i - 3.5) * .13 end
        local kind = 'spark'
        if family == 'crystal' then kind = 'fragment'
        elseif family == 'thermal' or family == 'plasma' then kind = 'ember' end
        emit(p.owner, kind, x, y, style.color, 3, .32,
            math.cos(direction) * 95, math.sin(direction) * 95, nil, nil, family, direction)
    end
end

function VFX.arc(p, x, y, x2, y2)
    local style = p.vfxProfile
    if style then emit(p.owner, 'arc', x, y, style.color, 2, .16, 0, 0, x2, y2) end
end

function VFX.update(owner, dt)
    local state = owner.projectileVFX
    if not state then return end
    state.time = state.time + dt
    for i = #state.trails, 1, -1 do
        local trail = state.trails[i]
        if state.time - trail.lastTime >= TRAIL_LIFE then
            trail.owner.vfxTrail = nil
            trail.owner = nil
            state.trails[i] = state.trails[#state.trails]
            state.trails[#state.trails] = nil
            state.freeTrails[#state.freeTrails + 1] = trail
        end
    end
    for i = #state.effects, 1, -1 do
        local effect = state.effects[i]
        effect.age = effect.age + dt
        if effect.age >= effect.duration then
            state.effects[i] = state.effects[#state.effects]
            state.effects[#state.effects] = nil
            state.free[#state.free + 1] = effect
        end
    end
end

local function sprite(tile, x, y, angle, sx, sy, color, alpha)
    batch:setColor(color[1], color[2], color[3], alpha)
    batch:add(quads[tile], x, y, angle, sx / 32, sy / 32, 32, 32)
end

local white = {1, 1, 1}
local function segment(x, y, x2, y2, width, color, alpha)
    local dx, dy = x2 - x, y2 - y
    sprite(7, (x + x2) / 2, (y + y2) / 2, math.atan2(dy, dx),
        math.sqrt(dx * dx + dy * dy) * .5 + width * .25, width, color, alpha)
end

local function lightning(x, y, x2, y2, phase, color, alpha)
    local dx, dy = x2 - x, y2 - y
    local length = math.max(1, math.sqrt(dx * dx + dy * dy))
    local previousX, previousY = x, y
    for i = 1, 7 do
        local t = i / 7
        local bend = math.sin(i * 15.7 + phase) * math.sin(t * math.pi) * math.min(12, length * .2)
        local px, py = x + dx * t - dy / length * bend, y + dy * t + dx / length * bend
        segment(previousX, previousY, px, py, 3, color, alpha)
        segment(previousX, previousY, px, py, 1, white, alpha)
        previousX, previousY = px, py
    end
end

local cyan, prism, orange, dark = {.3, .8, 1}, {.9, .4, 1}, {1, .35, .08}, {.008, .006, .018}

local function drawImpact(effect, t)
    local x, y, size, color = effect.x, effect.y, effect.size, effect.color
    local alpha, family = (1 - t)^2, effect.family
    local spread = size * (.2 + t)
    if family == 'rail' then
        sprite(4, x, y, effect.angle, spread * 1.5, size * .15 * (1 - t), white, alpha)
        sprite(4, x, y, effect.angle + math.pi / 2, size * .5, size * .12, color, alpha)
    elseif family == 'saw' then
        sprite(3, x, y, effect.angle + t * 8, spread * .55, spread * .55, color, alpha)
    elseif family == 'crystal' then
        for i = 1, 4 do
            local angle = effect.angle + i * math.pi / 2
            sprite(4, x + math.cos(angle) * spread, y + math.sin(angle) * spread,
                angle, size * .35 * (1 - t), size * .15, color, alpha)
        end
    elseif family == 'tesla' then
        for i = 1, 4 do
            local angle = effect.angle + i * math.pi / 2
            lightning(x, y, x + math.cos(angle) * spread, y + math.sin(angle) * spread,
                math.floor(t * 8) + i, color, alpha)
        end
    elseif family == 'gravity' then
        local radius = size * (1 - t)^2
        sprite(2, x, y, 0, radius, radius * .6, color, alpha)
        sprite(2, x, y, t * 4, spread, spread, color, alpha * .5)
    else
        sprite(5, x, y, t * 3, spread, spread, color, alpha)
        sprite(6, x, y, -t * 4, spread * .8, spread * .8, color, alpha)
        sprite(1, x, y, 0, size * .4 * (1 - t), size * .4 * (1 - t), white, alpha)
    end
end

local function drawTrail(trail, time, detail, stride)
    stride = stride or 1
    for i = 1, trail.count - 1, stride do
        local newer = trail.points[(trail.head - i) % TRAIL_POINTS + 1]
        local offset = math.min(trail.count, i + stride)
        local older = trail.points[(trail.head - offset) % TRAIL_POINTS + 1]
        local alpha = math.max(0, 1 - (time - older.time) / TRAIL_LIFE)
        if alpha > 0 then
            segment(older.x, older.y, newer.x, newer.y, trail.width * (.2 + alpha), trail.color, alpha * .55)
            if detail and trail.voltaic and i % 3 == 1 then
                lightning(older.x, older.y, newer.x, newer.y, i, cyan, alpha * .7)
            end
        end
    end
end

local function drawBody(p, detail)
    local style = p.vfxProfile
    local x, y = p:getPosition()
    local angle, age = flightAngle(p), p.age
    local size = style.size * (p.scaleMultiplier or 1)
    local color, family = style.color, style.family
    local pulse = 1 + .12 * math.sin(age * 19)
    if family ~= 'gravity' then
        sprite(1, x, y, 0, size * 2.4, size * 2.4, color, .4)
    end
    if family == 'saw' then
        sprite(3, x, y, age * 28, size, size, color, 1)
        sprite(2, x, y, -age * 8, size * .65, size * .65, white, .8)
    elseif family == 'tesla' then
        sprite(5, x, y, age * 5, size * .6, size * .6, white, .95)
        for i = 1, detail and 3 or 1 do
            local phase = age * 4 + i * math.pi * 2 / 3
            lightning(x, y, x + math.cos(phase) * size * 2, y + math.sin(phase) * size * 2,
                math.floor(age * 24) + i, color, .85)
        end
    elseif family == 'gravity' then
        sprite(2, x, y, age * 3, size * pulse, size * pulse * .55, color, 1)
        sprite(2, x, y, -age * 2, size * .8, size * .8, color, .8)
        if p.graviticPull > 0 then
            local radius = p.graviticRadius
            sprite(2, x, y, 0, radius / .72, radius / .72, color, .12)
            for i = 1, detail and 6 or 2 do
                local phase = age * .7 + i / 6
                local distance = radius * (1 - phase % 1)
                local orbit = age * 1.8 + i * 2.4
                sprite(4, x + math.cos(orbit) * distance, y + math.sin(orbit) * distance,
                    orbit, 4, 2, color, .45 * math.sin((phase % 1) * math.pi))
            end
        end
    elseif family == 'crystal' then
        sprite(4, x, y, angle, size * 1.7, size, color, 1)
        sprite(4, x, y, angle + .25 * math.sin(age * 10), size, size * .5, white, .9)
    elseif family == 'rail' then
        sprite(4, x, y, angle, size * 4, size * .6, color, 1)
        sprite(1, x, y, angle, size * 3, size * .25, white, 1)
    else
        sprite(5, x, y, age * 4, size * pulse, size * pulse, color, .85)
        sprite(6, x, y, -age * 6, size * .8, size * .8, color, .85)
        sprite(1, x, y, 0, size * .8, size * .8, white, 1)
    end
    local mods = p.vfxMods
    if mods.reinforced then sprite(4, x, y, angle, size * 2, size * .25, white, .9) end
    if mods.prism then
        sprite(4, x, y, angle + age * 7, size * 1.2, size * .7, prism, .6)
    end
    if detail and mods.voltaic and family ~= 'tesla' then
        lightning(x - size, y, x + size, y, math.floor(age * 20), cyan, .8)
    end
    if detail and mods.thermal then
        sprite(6, x, y, age * 5, size * .85, size * .85, orange, .55)
    end
    if detail and mods.homing then
        local orbit = angle + math.pi / 2
        sprite(4, x + math.cos(orbit) * size, y + math.sin(orbit) * size, angle, 3, 1, cyan, .8)
        sprite(4, x - math.cos(orbit) * size, y - math.sin(orbit) * size, angle, 3, 1, cyan, .8)
    end
    if age < .08 then sprite(4, x, y, angle + math.pi / 2, size * 2, size, white, 1 - age / .08) end
end

function VFX.draw(owner)
    if not owner.projectiles and not owner.projectileVFX then return end
    initialize()
    local g = love.graphics
    g.push('all')
    g.setShader()
    local width, height = g.getDimensions()
    local ox, oy = g.transformPoint(0, 0)
    local ux, uy = g.transformPoint(1, 0)
    local vx, vy = g.transformPoint(0, 1)
    local scale = math.max(math.sqrt((ux - ox)^2 + (uy - oy)^2), math.sqrt((vx - ox)^2 + (vy - oy)^2))
    local function visible(x, y, margin)
        local sx, sy = g.transformPoint(x, y)
        margin = margin * scale + 4
        return sx >= -margin and sy >= -margin and sx <= width + margin and sy <= height + margin
    end
    local function segmentVisible(x, y, x2, y2, margin)
        local sx, sy = g.transformPoint(x, y)
        local tx, ty = g.transformPoint(x2, y2)
        margin = margin * scale + 4
        return math.max(sx, tx) >= -margin and math.min(sx, tx) <= width + margin
            and math.max(sy, ty) >= -margin and math.min(sy, ty) <= height + margin
    end
    local state = owner.projectileVFX
    local secondaryDetail = #(owner.projectiles or {}) <= 240
    g.setBlendMode('alpha', 'alphamultiply')
    batch:clear()
    for _, p in ipairs(owner.projectiles or {}) do
        if p.vfxProfile and p.vfxProfile.family == 'gravity' and not p:isDestroyed() then
            local x, y = p:getPosition()
            local size = p.vfxProfile.size * (p.scaleMultiplier or 1)
            if visible(x, y, size * 2) then sprite(8, x, y, 0, size, size, dark, .98) end
        end
    end
    g.setColor(1, 1, 1, 1)
    g.draw(batch)
    g.setBlendMode('add', 'alphamultiply')
    batch:clear()
    for _, trail in ipairs(state and state.trails or {}) do
        local first = trail.points[trail.head]
        local last = trail.points[(trail.head - trail.count) % TRAIL_POINTS + 1]
        -- Scan points as well as endpoints so curved trails crossing the viewport survive culling.
        local onScreen = segmentVisible(first.x, first.y, last.x, last.y, 32)
        for i = 1, trail.count do
            local point = trail.points[(trail.head - i) % TRAIL_POINTS + 1]
            onScreen = onScreen or visible(point.x, point.y, 32)
        end
        -- Under dense fire merge adjacent visual segments, retaining endpoints,
        -- the complete history and real impact/arc effects. Simulation is unchanged.
        if onScreen then drawTrail(trail, state.time, secondaryDetail and scale * trail.width > 2, secondaryDetail and 1 or 2) end
    end
    for _, effect in ipairs(state and state.effects or {}) do
        local t = effect.age / effect.duration
        local x, y = effect.x + effect.vx * effect.age, effect.y + effect.vy * effect.age
        if effect.kind == 'arc' then
            if segmentVisible(x, y, effect.x2, effect.y2, 20) then
                lightning(x, y, effect.x2, effect.y2, math.floor(effect.age * 40), effect.color, 1 - t)
            end
        elseif visible(x, y, effect.size * 2 + 32) then
            if effect.kind == 'impact' then
                drawImpact(effect, t)
            elseif effect.kind == 'ring' then
                local radius = effect.size * (1 - (1 - t)^3)
                sprite(2, x, y, 0, radius / .72, radius / .72, effect.color, (1 - t)^2)
            elseif effect.kind == 'spark' then
                sprite(4, x, y, effect.angle, effect.size * 2 * (1 - t), 1, effect.color, 1 - t)
            elseif effect.kind == 'fragment' then
                sprite(4, x, y, effect.angle + t * 8, effect.size, effect.size * .6, effect.color, 1 - t)
            else
                local size = effect.size * (1 + t * 1.5)
                sprite(5, x, y, t * 3, size, size, effect.color, (1 - t)^2 * .7)
            end
        end
    end
    for _, p in ipairs(owner.projectiles or {}) do
        if p.vfxProfile and not p:isDestroyed() then
            local x, y = p:getPosition()
            local extent = math.max(p.vfxProfile.size * 5, p.graviticPull > 0 and p.graviticRadius or 0)
            if visible(x, y, extent) then drawBody(p, secondaryDetail and p.vfxProfile.size * scale >= 4) end
        end
    end
    g.setColor(1, 1, 1, 1)
    g.draw(batch)
    g.pop()
end

return VFX
