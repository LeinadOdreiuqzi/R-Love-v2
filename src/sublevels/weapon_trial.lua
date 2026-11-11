local Inventory = require 'src.maps.systems.inventory_system'
local WeaponSystem = require 'src.entities.weapon_system'
local Items = require 'src.item_systems.item_system'

local Trial = {}
Trial.weapons = {'gauss_railgun', 'orbital_shredder', 'singularity_torpedo', 'energy_shotgun', 'plasma_rifle'}
Trial.lanes = {'Blanco fijo', 'Interceptor lateral', 'Fuego cruzado'}
Trial.distances = {220, 330, 480}

local function copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return setmetatable(result, getmetatable(source))
end

function Trial.start(player, settings, targets)
    local trial = {player = player, settings = settings, targets = targets, saved = {},
        time = 0, triggers = 0, ammo = 0, spawned = 0, maxVolley = 0, peak = 0,
        shield = 0, hull = 0, reload = 0, defeated = 0}
    local item = assert(Items:getItem(Trial.weapons[settings.weapon]))
    trial.name = (item.name or item.id):gsub('^★%s*', '')
    local keys = {'inventory', 'weaponSystem', 'stats', 'abilities', 'passiveModifiers',
        'abilitySystem', 'resistances', 'debugDisableSynergies', 'burn', 'lastAttacker',
        'lastDamageTime', '_lastShotTimestamp', 'weaponAuditActive'}
    for _, key in ipairs(keys) do trial.saved[key] = player[key] end
    trial.savedKeys = keys
    player.weaponAuditActive = true
    player.stats = copy(player.stats)
    for _, key in ipairs({'health', 'shield', 'fuel', 'debug', 'energy'}) do
        if player.stats[key] then player.stats[key] = copy(player.stats[key]) end
    end
    player.stats.health.currentHealth = player.stats.health.maxHealth
    player.stats.shield.currentShield = player.stats.shield.maxShield
    player.stats.debug.invulnerable = false
    player.stats.debug.infiniteFuel = true
    player.stats.debug.fastRegen = false
    player.abilities, player.passiveModifiers, player.resistances = {}, {}, {}
    player.burn, player.lastAttacker, player.abilitySystem = nil, nil, nil
    player.debugDisableSynergies = true
    player.inventory = Inventory:new(player.shipType)
    player.inventory.player = player
    player.weaponSystem = WeaponSystem:new(player)
    local ws = player.weaponSystem
    player.inventory:getCompartment('weapons').items[1] = nil
    assert(ws:equipWeapon(copy(item), 2))
    ws:switchToSlot(2)
    ws:setWeaponHardpointLevel(2, settings.level)
    local shoot = ws.shoot
    function ws:shoot(...)
        if trial.finished then return false end
        local before = #(player.projectiles or {})
        local fired = shoot(self, ...)
        if fired then
            local count = #(player.projectiles or {}) - before
            trial.firstShot = trial.firstShot or trial.time
            trial.triggers = trial.triggers + 1
            if self.currentWeapon.maxAmmo then trial.ammo = trial.ammo + 1 end
            trial.spawned = trial.spawned + count
            trial.maxVolley = math.max(trial.maxVolley, count)
            trial.peak = math.max(trial.peak, #(player.projectiles or {}))
        end
        return fired
    end
    for _, target in ipairs(targets) do
        if target.aiController then
            -- Training ships use normal damage, but never spawn campaign loot.
            target.aiController.onKilled = function(ai) ai.active = false end
        end
        local takeDamage = target.takeDamage
        function target:takeDamage(amount, source, kind)
            local owner = source and (source.owner or source)
            if owner ~= player or trial.finished then return false end
            local beforeShield, beforeHull = self.stats.shield.currentShield, self.stats.health.currentHealth
            local died = takeDamage(self, amount, source, kind)
            local shield = math.max(0, beforeShield - self.stats.shield.currentShield)
            local hull = math.max(0, beforeHull - self.stats.health.currentHealth)
            trial.shield, trial.hull = trial.shield + shield, trial.hull + hull
            if died and not self.weaponAuditDefeated then
                self.weaponAuditDefeated = true
                trial.defeated = trial.defeated + 1
                trial.firstKill = trial.firstKill or (trial.time - (trial.firstShot or trial.time))
            end
            return died
        end
    end
    return trial
end

function Trial.update(trial, dt)
    if trial.finished then return end
    trial.time = trial.time + dt
    local player = trial.player
    if player.weaponSystem.isReloading then trial.reload = trial.reload + dt end
    trial.finished = trial.defeated == #trial.targets or trial.time >= 45
        or player.stats.health.currentHealth <= 0
    if trial.finished then player.stats.debug.invulnerable = true end
end

function Trial.finish(trial)
    if not trial then return end
    for _, key in ipairs(trial.savedKeys) do trial.player[key] = trial.saved[key] end
end

return Trial
