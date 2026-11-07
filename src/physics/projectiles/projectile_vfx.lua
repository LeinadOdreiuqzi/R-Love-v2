-- Shared textured composition. Effects belong to the firing ship and outlive shots.
local VFX = {}
local profiles = {}
local atlas, quads, batch
local states = setmetatable({}, {__mode = 'k'})
local MAX_EFFECTS = 1800
local TILE = 64

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
end

-- Generate the shared texture atlas once, independently of the projectile count.
local function initialize()
    if atlas then return end
    local data = love.image.newImageData(TILE * 6, TILE)
    for tile = 0, 5 do
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
    for i = 1, 6 do quads[i] = love.graphics.newQuad((i - 1) * TILE, 0, TILE, TILE, TILE * 6, TILE) end
    batch = love.graphics.newSpriteBatch(atlas, 32768, 'stream')
end

local function emit(owner, kind, x, y, color, size, duration, vx, vy, x2, y2)
    if not owner then return end
    local state = owner.projectileVFX
    if not state then
        state = {effects = {}, free = {}}
        owner.projectileVFX = state
        states[state] = true
    end
    if #state.effects >= 350 then return end
    local total = 0
    for live in pairs(states) do total = total + #live.effects end
    if total >= MAX_EFFECTS then return end
    local effect = table.remove(state.free) or {}
    effect.kind, effect.x, effect.y = kind, x, y
    effect.color, effect.size, effect.duration = color, size, duration
    effect.age, effect.vx, effect.vy = 0, vx or 0, vy or 0
    effect.x2, effect.y2 = x2, y2
    state.effects[#state.effects + 1] = effect
end

function VFX.updateProjectile(p, dt)
    local style = p.vfxProfile
    if not style or p:isDestroyed() then return end
    p.vfxTimer = p.vfxTimer + dt
    local interval = 1 / style.rate
    local count = math.min(3, math.floor(p.vfxTimer / interval))
    if count == 0 then return end
    p.vfxTimer = p.vfxTimer % interval
    local x, y = p:getPosition()
    for i = 1, count do
        local fraction = i / count
        local px = (p.prevX or x) + (x - (p.prevX or x)) * fraction
        local py = (p.prevY or y) + (y - (p.prevY or y)) * fraction
        local phase = p.age * 28 + i * 2.4
        local drift = style.family == 'saw' and 55 or 12
        emit(p.owner, 'trail', px, py, style.color, style.size * .8, .28,
            math.cos(phase) * drift, math.sin(phase) * drift)
    end
end

function VFX.impact(p, x, y, radius)
    local style = p.vfxProfile
    if not style then return end
    emit(p.owner, 'ring', x, y, style.color, radius or style.size * 3, .38)
    for i = 1, 8 do
        local angle = i * math.pi / 4 + p.age
        emit(p.owner, 'spark', x, y, style.color, 3, .32,
            math.cos(angle) * 95, math.sin(angle) * 95)
    end
end

function VFX.arc(p, x, y, x2, y2)
    local style = p.vfxProfile
    if style then emit(p.owner, 'arc', x, y, style.color, 2, .16, 0, 0, x2, y2) end
end

function VFX.update(owner, dt)
    local state = owner.projectileVFX
    if not state then return end
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
    sprite(1, (x + x2) / 2, (y + y2) / 2, math.atan2(dy, dx),
        math.sqrt(dx * dx + dy * dy) * .7, width, color, alpha)
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

local function drawBody(p)
    local style = p.vfxProfile
    local x, y = p:getPosition()
    local angle, age = p:getAngle(), p.age
    local size = style.size * (p.scaleMultiplier or 1)
    local color, family = style.color, style.family
    local pulse = 1 + .12 * math.sin(age * 19)
    sprite(1, x, y, 0, size * 2.4, size * 2.4, color, .55)
    if family == 'saw' then
        sprite(3, x, y, age * 28, size, size, color, 1)
        sprite(2, x, y, -age * 8, size * .65, size * .65, white, .8)
    elseif family == 'tesla' then
        sprite(5, x, y, age * 5, size * .6, size * .6, white, .95)
        for i = 1, 3 do
            local phase = age * 4 + i * math.pi * 2 / 3
            lightning(x, y, x + math.cos(phase) * size * 2, y + math.sin(phase) * size * 2,
                math.floor(age * 24) + i, color, .85)
        end
    elseif family == 'gravity' then
        sprite(2, x, y, age * 3, size * pulse, size * pulse * .55, color, 1)
        sprite(2, x, y, -age * 2, size * .8, size * .8, color, .8)
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
    if age < .08 then sprite(4, x, y, angle + math.pi / 2, size * 2, size, white, 1 - age / .08) end
end

function VFX.draw(owner)
    if not owner.projectiles and not owner.projectileVFX then return end
    initialize()
    love.graphics.push('all')
    love.graphics.setShader()
    love.graphics.setBlendMode('add', 'alphamultiply')
    batch:clear()
    local width, height = love.graphics.getDimensions()
    local function visible(x, y, margin)
        local sx, sy = love.graphics.transformPoint(x, y)
        return sx >= -margin and sy >= -margin and sx <= width + margin and sy <= height + margin
    end
    local state = owner.projectileVFX
    for _, effect in ipairs(state and state.effects or {}) do
        local t = effect.age / effect.duration
        local x, y = effect.x + effect.vx * effect.age, effect.y + effect.vy * effect.age
        if effect.kind == 'arc' then
            lightning(x, y, effect.x2, effect.y2, math.floor(effect.age * 40), effect.color, 1 - t)
        elseif visible(x, y, effect.size * 2 + 64) then
            if effect.kind == 'ring' then
                local radius = effect.size * (1 - (1 - t)^3)
                sprite(2, x, y, 0, radius / .72, radius / .72, effect.color, (1 - t)^2)
            else
                local size = effect.size * (1 + t * 1.5)
                sprite(1, x, y, t * 3, size, size, effect.color, (1 - t)^2 * .7)
            end
        end
    end
    for _, p in ipairs(owner.projectiles or {}) do
        if p.vfxProfile and not p:isDestroyed() then
            local x, y = p:getPosition()
            if visible(x, y, 150) then drawBody(p) end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(batch)
    love.graphics.pop()
end

return VFX
