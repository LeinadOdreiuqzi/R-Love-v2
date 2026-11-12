local Inventory = require 'src.maps.systems.inventory_system'
local WeaponSystem = require 'src.entities.weapon_system'
local Items = require 'src.item_systems.item_system'
local PlayerStats = require 'src.entities.player_stats'

local Trial = {}
Trial.weapons = {'gauss_railgun', 'orbital_shredder', 'singularity_torpedo', 'energy_shotgun', 'plasma_rifle'}
Trial.lanes = {'Blanco fijo', 'Interceptor lateral', 'Fuego cruzado', 'Duelo de chasis'}
Trial.distances = {220, 330, 480}
Trial.duelLane = 4
Trial.chassis = {'EXPLORER', 'INTERCEPTOR', 'CARGO'}

local chassisKeys = {'shipType', 'shipConfig', 'shipName', 'useStarterSprite', 'sprite',
    'hardpoints', 'size', 'hyperTravelEnabled', 'baseParams', 'shipSettings', 'damageState',
    'maxSpeed', 'forwardAccel', 'strafeAccel', 'backwardAccel', 'drag', 'boostMultiplier',
    'isBoostActive', 'isDrifting', 'boostDuration', 'rotation', 'prevRotation', 'takeDamage'}

local function copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return setmetatable(result, getmetatable(source))
end

function Trial.start(player, settings, targets)
    local trial = {player = player, settings = settings, targets = targets, saved = {},
        time = 0, triggers = 0, ammo = 0, spawned = 0, maxVolley = 0, peak = 0,
        shield = 0, hull = 0, reload = 0, defeated = 0}
    local duel = settings.lane == Trial.duelLane
    local item = assert(Items:getItem(Trial.weapons[duel and 1 or settings.weapon]))
    trial.name = (item.name or item.id):gsub('^★%s*', '')
    local keys = {'inventory', 'weaponSystem', 'stats', 'abilities', 'passiveModifiers',
        'abilitySystem', 'resistances', 'debugDisableSynergies', 'burn', 'lastAttacker',
        'lastDamageTime', '_lastShotTimestamp', 'weaponAuditActive'}
    if duel then
        for _, key in ipairs(chassisKeys) do keys[#keys + 1] = key end
    end
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
    player.stats.debug.infiniteFuel = not duel
    player.stats.debug.fastRegen = false
    player.abilities, player.passiveModifiers, player.resistances = {}, {}, {}
    player.burn, player.lastAttacker, player.abilitySystem = nil, nil, nil
    player.debugDisableSynergies = true
    player.inventory = Inventory:new(player.shipType)
    player.inventory.player = player
    player.weaponSystem = WeaponSystem:new(player)
    if duel then
        player.shipSettings, player.damageState = copy(player.shipSettings), copy(player.damageState)
        player:debugChangeShipType(Trial.chassis[settings.chassis or 1])
        player.stats = PlayerStats:new(player.shipConfig)
        player.rotation, player.prevRotation = 0, 0
        player:updateShipRegistry()
        trial.incomingHull, trial.incomingShield, trial.fuelUsed, trial.peakSpeed = 0, 0, 0, 0
        trial.lastX, trial.lastY = player.x, player.y
        trial.lastIncoming = 0
        local takeDamage = player.takeDamage
        function player:takeDamage(amount, source, kind)
            if trial.finished then return false end
            local shield, hull = self.stats.shield.currentShield, self.stats.health.currentHealth
            local died = takeDamage(self, amount, source, kind)
            local absorbed = math.max(0, shield - self.stats.shield.currentShield)
            local lost = math.max(0, hull - self.stats.health.currentHealth)
            trial.incomingShield = trial.incomingShield + absorbed
            trial.incomingHull = trial.incomingHull + lost
            if absorbed + lost > 0 then trial.lastIncoming = trial.time end
            return died
        end
    end
    local ws = player.weaponSystem
    player.inventory:getCompartment('weapons').items[1] = nil
    assert(ws:equipWeapon(copy(item), 2))
    ws:switchToSlot(2)
    ws:setWeaponHardpointLevel(2, duel and 1 or settings.level)
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
    local duel = trial.settings.lane == Trial.duelLane
    local withdrew = false
    if duel then
        local target = trial.targets[1]
        local dx, dy = player.x - target.x, player.y - target.y
        local movedX, movedY = player.x - trial.lastX, player.y - trial.lastY
        if dt > 0 then trial.peakSpeed = math.max(trial.peakSpeed, math.sqrt(movedX^2 + movedY^2) / dt) end
        trial.lastX, trial.lastY = player.x, player.y
        trial.fuelUsed = player.stats.fuel.maxFuel - player.stats.fuel.currentFuel
        withdrew = dx * dx + dy * dy >= 900^2 and trial.time - trial.lastIncoming >= 3
    end
    if player.stats.health.currentHealth <= 0 then trial.result = 'Derrota'
    elseif trial.defeated == #trial.targets then trial.result = 'Victoria'
    elseif withdrew then trial.result = 'Retirada'
    elseif trial.time >= 45 then trial.result = 'Tiempo agotado' end
    trial.finished = trial.result ~= nil
    if trial.finished then player.stats.debug.invulnerable = true end
end

function Trial.finish(trial)
    if not trial then return end
    for _, key in ipairs(trial.savedKeys) do trial.player[key] = trial.saved[key] end
    if trial.settings.lane == Trial.duelLane then
        local player = trial.player
        local registry = player.getShipRegistry()[player.shipId]
        if registry then registry.type, registry.name = player.shipType, player.shipName end
        player.dx, player.dy = 0, 0
        player:updateShipRegistry()
    end
end

return Trial
