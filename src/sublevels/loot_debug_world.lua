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
    'boostDuration', 'isBoostActive', 'isDrifting', 'phantomPulseCooldown'}

function Lab.new(player, seed)
    local self = setmetatable({player = player, seed = tostring(seed), round = 0, saved = {}, targets = targets,
        debugHint = '   [F6] Reiniciar prueba'}, Lab)
    for _, key in ipairs(keys) do self.saved[key] = player[key] end
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
    self.inspecting, self.boxes = nil, {}
    self.message = 'Recoge una llave en el dispensador y acércate a un contenedor.'
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
    self.player:updateShipRegistry()
end

function Lab:keypressed(key)
    if key == 'f6' then self:reset(); return true end
    if key == 'b' or key == '0' or key == 'f9' or key == 'f10' or key == 'y' then return true end
    return Inspection.keypressed(self, key)
end

return Lab
