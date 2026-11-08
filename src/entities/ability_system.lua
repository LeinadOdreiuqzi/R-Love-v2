local Ability = {}
Ability.__index = Ability

local function percent(owner, key)
    local value = (owner.passiveModifiers or {})[key]
    return type(value) == 'table' and (value.percent or 0) or tonumber(value) or 0
end

function Ability.new(owner)
    return setmetatable({owner = owner, q = 0, r = 0, clock = 0, echoes = {}, overclock = 0, doubleCast = 0}, Ability)
end

function Ability:cancel()
    self.field, self.decoy = nil, nil
    self.echoes, self.overclock, self.doubleCast = {}, 0, 0
end

function Ability:available()
    local p = self.owner
    return not p.isInEVA and not p.isDestroyed and p.stats and p.stats.health.currentHealth > 0
end

function Ability:restoreShield(fraction)
    local p = self.owner
    if (p.abilities or {}).ability_shield_restore and p.stats.shield then
        local s = p.stats.shield
        s.currentShield = math.min(s.maxShield, s.currentShield + s.maxShield * fraction)
    end
end

function Ability:triggerTactical()
    if self.q > 0 or not self:available() then return false end
    local sub = package.loaded['src.maps.systems.sublevel_manager']
    local status = sub and sub.getStatus and sub.getStatus()
    if status and status.active then return false end
    self.echoes = {}
    local p, mods = self.owner, self.owner.abilities or {}
    self.q = 6 * (1 - math.min(90, math.max(0, percent(p, 'cooldown_reduction_q'))) / 100)
    if mods.q_spawns_decoy then
        self.decoy = {x = p.x, y = p.y, dx = 0, dy = 0, life = mods.q_spawns_decoy}
    end
    self.overclock = tonumber(mods.q_overclock_weapons) or 0
    self.doubleCast = tonumber(mods.q_double_cast_weapons) or 0
    local angle = p.rotation or 0
    local vx, vy = math.sin(angle) * 6, -math.cos(angle) * 6
    -- Keep the existing movement solver responsible for asteroid contacts.
    local phase = package.loaded['src.gameplay.phase_system']
    -- Interior geometry has a separate movement solver; do not bypass it.
    if not (status and status.active) then
        for i = 1, 30 do
            local x, y = p.x, p.y
            p.x, p.y = x + vx, y + vy
            if phase and phase.config.restrictMovement and phase.clampPlayerToCurrentPhase then
                p.x, p.y = phase.clampPlayerToCurrentPhase(p.x, p.y)
            end
            if p.resolveAsteroidCollisions then p:resolveAsteroidCollisions(1 / 60) end
            if i % 5 == 0 then self.echoes[#self.echoes + 1] = {x = p.x, y = p.y, angle = angle, life = .35} end
            if math.abs(p.x - x - vx) + math.abs(p.y - y - vy) > 1 then break end
        end
    end
    self:restoreShield(.15)
    return true
end

function Ability:triggerUltimate()
    if self.r > 0 or not self:available() then return false end
    local scale = 1 + math.max(0, percent(self.owner, 'ultimate_power_r')) / 100
    self.r = 25
    self.field = {life = 5 * scale, radius = 180 * scale}
    self:restoreShield(1)
    return true
end

function Ability:onKill(target)
    if not target or target._abilityKillCredited then return end
    target._abilityKillCredited = true
    self.r = math.max(0, self.r - (tonumber((self.owner.abilities or {}).kill_cd_refund_r) or 0))
end

function Ability:isHostile(ship)
    local ai = ship.aiController
    if ship.wingmanOf == self.owner or (ai and ai.wingmanOf == self.owner) then return false end
    if ship.aiFaction and self.owner.aiFaction and ship.aiFaction == self.owner.aiFaction then return false end
    return ship ~= self.owner and not ship.isDestroyed and not ship.isAbandoned and ai
        and (ai.combatTarget == self.owner or ship.lastAttacker == self.owner or ai.role == 'RAIDER')
end

function Ability:update(dt, ships)
    self.clock = self.clock + dt
    self.q, self.r = math.max(0, self.q - dt), math.max(0, self.r - dt)
    if not self:available() then self:cancel(); return end
    self.overclock, self.doubleCast = math.max(0, self.overclock - dt), math.max(0, self.doubleCast - dt)
    for i = #self.echoes, 1, -1 do
        self.echoes[i].life = self.echoes[i].life - dt
        if self.echoes[i].life <= 0 then table.remove(self.echoes, i) end
    end
    if self.decoy then
        self.decoy.life = self.decoy.life - dt
        if self.decoy.life <= 0 then self.decoy = nil end
    end
    if self.field then
        local field, p = self.field, self.owner
        local elapsed = math.min(dt, field.life)
        field.life = field.life - dt
        for _, ship in pairs(ships or {}) do
            if self:isHostile(ship) and (ship.x - p.x)^2 + (ship.y - p.y)^2 <= field.radius^2 then
                ship:takeDamage(12 * elapsed, p)
                local drag = math.exp(-2 * elapsed)
                ship.dx, ship.dy = (ship.dx or 0) * drag, (ship.dy or 0) * drag
            end
        end
        if field.life <= 0 then self.field = nil end
    end
end

function Ability:draw()
    local g, p = love.graphics, self.owner
    g.push('all')
    g.setBlendMode('add')
    local function silhouette(x, y, angle, alpha)
        g.push()
        g.translate(x, y); g.rotate(angle)
        g.setColor(.15, .8, 1, alpha)
        local s = p.size or 22
        g.polygon('line', 0, -s, s * .6, s * .7, 0, s * .3, -s * .6, s * .7)
        g.pop()
    end
    for _, e in ipairs(self.echoes) do silhouette(e.x, e.y, e.angle, e.life * 2) end
    if self.decoy then silhouette(self.decoy.x, self.decoy.y, p.rotation or 0, .5 + .2 * math.sin(self.clock * 20)) end
    if self.field then
        local radius = self.field.radius
        g.setColor(.15, .4, 1, .05)
        g.circle('fill', p.x, p.y, radius, 64)
        g.setLineWidth(2)
        g.setColor(.3, .7, 1, math.min(1, self.field.life) * .65)
        g.circle('line', p.x, p.y, radius, 64)
        for i = 1, 3 do
            local t = (self.clock * .7 + i / 3) % 1
            g.setColor(.2, .7, 1, (1 - t) * .3)
            g.circle('line', p.x, p.y, radius * t, 48)
        end
    end
    g.pop()
end

function Ability:drawHUD()
    if not self:available() then return end
    local g = love.graphics
    g.push('all'); g.origin()
    local y = g.getHeight() - 60
    for i, key in ipairs({'q', 'r'}) do
        local x, remaining = math.max(20, (g.getWidth() - 308) / 2) + (i - 1) * 158, self[key]
        g.setColor(.02, .04, .09, .9); g.rectangle('fill', x, y, 150, 42, 5)
        g.setColor(.3, .8, 1, 1)
        g.print(key:upper() .. ' ' .. (key == 'q' and 'Phase Dash' or 'Matrix Overload'), x + 7, y + 4)
        g.print(remaining > 0 and string.format('%.1f s', remaining) or 'LISTA', x + 7, y + 23)
    end
    g.pop()
end

return Ability
