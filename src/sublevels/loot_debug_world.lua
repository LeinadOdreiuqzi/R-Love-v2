local Inventory = require 'src.maps.systems.inventory_system'
local WeaponSystem = require 'src.entities.weapon_system'
local PlayerStats = require 'src.entities.player_stats'
local Passives = require 'src.item_systems.passive_manager'
local Inspection = require 'src.ui.loot_inspection'

local Lab = setmetatable({}, {__index = Inspection})
Lab.__index = Lab
local targets = {
    {x = 0, y = 0, name = 'Dispensador de llaves', color = {.3, .85, 1}},
    {x = -310, y = -170, id = 'common', name = 'Común', color = {.55, .78, .87}},
    {x = 0, y = -170, id = 'rare', name = 'Rara', color = {.38, .65, 1}},
    {x = 310, y = -170, id = 'exceptional', name = 'Excepcional', color = {1, .69, .28}}
}
local keys = {'inventory', 'weaponSystem', 'stats', 'passiveModifiers', 'resistances',
    'abilities', 'abilitySystem', 'burn', 'weaponAuditActive', 'lootLabActive',
    'hyperTravelEnabled', 'maxSpeed', 'forwardAccel', 'strafeAccel', 'backwardAccel', 'drag',
    'boostDuration', 'isBoostActive', 'isDrifting', 'phantomPulseCooldown',
    'shipType', 'shipConfig', 'shipName', 'size', 'hardpoints', 'sprite', 'useStarterSprite',
    'visualBank', 'baseParams', 'boostMultiplier', 'shipSettings', 'damageState', 'debugDisableSynergies'}

function Lab.new(player, seed)
    local self = setmetatable({player = player, seed = tostring(seed), round = 0, saved = {}, targets = {},
        debugHint = '   [B] Naves   [F6] Reiniciar'}, Lab)
    for _, key in ipairs(keys) do self.saved[key] = player[key] end
    -- Chassis switching edits these tables in place. Keep the originals for exit.
    for _, key in ipairs({'shipSettings','damageState'}) do
        local copy = {}
        for k,v in pairs(player[key]) do copy[k] = v end
        player[key] = copy
    end
    self:reset()
    return self
end

local function removeTestPassives(player)
    local compartment = player.inventory:getCompartment('passives')
    for _, entry in pairs(compartment.items) do
        if entry.passiveId then Passives.removePassiveEffect(entry.passiveId) end
    end
end

function Lab:reset()
    local player = self.player
    require('src.core.inventory_manager').forceCloseAll()
    if self.round > 0 then removeTestPassives(player) end
    self.round = self.round + 1
    self.run = {seed = self.seed .. ':loot-lab:' .. self.round, lootRooms = {}}
    self.inspecting, self.boxes, self.targets = nil, {}, {}
    for i,template in ipairs(targets) do
        local target = {}
        for k,v in pairs(template) do target[k] = v end
        if target.id then target.name = 'Cápsula · ' .. target.name end
        self.targets[i] = target
    end
    self.message = 'Recoge una llave en el dispensador y acércate a una cápsula.'
    player.weaponAuditActive, player.lootLabActive = true, true
    if player.hyperTravelEnabled then player:toggleHyperTravel() end
    player.dx, player.dy, player.boostDuration = 0, 0, 0
    player.isBoostActive, player.isDrifting = false, false
    player.stats = PlayerStats:new(player.shipConfig)
    player.stats.debug.infiniteFuel, player.stats.debug.invulnerable = true, true
    player.abilities, player.passiveModifiers, player.resistances = {}, {}, {}
    player.abilitySystem, player.burn = nil, nil
    player.inventory = Inventory:new(player.shipType)
    player.inventory.player = player
    player.weaponSystem = WeaponSystem:new(player)
end

function Lab:close()
    require('src.core.inventory_manager').forceCloseAll()
    removeTestPassives(self.player)
    for _, key in ipairs(keys) do self.player[key] = self.saved[key] end
    local entry = self.player.getShipRegistry()[self.player.shipId]
    if entry then entry.type, entry.name = self.player.shipType, self.player.shipName end
    self.player:updateShipRegistry()
end

function Lab:keypressed(key)
    if key == 'f6' then self:reset(); return true end
    if key == 'b' then
        require('src.ui.combat_debug_menu').open(self.player, 'ships')
        return true
    end
    if key == '0' or key == 'f9' or key == 'f10' or key == 'y' then return true end
    return Inspection.keypressed(self, key)
end

return Lab
