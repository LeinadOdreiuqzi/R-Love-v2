local Items = require 'src.item_systems.item_system'

local Consumables = {}
local tiers = Items.RARITY

-- Equivalencias para partidas guardadas con el catálogo de prototipos.
local replacements = {
    hull_kit_deluxe = 'hull_kit_enhanced',
    hull_kit_prestige = 'hull_kit_superior',
    combat_stim = 'salvaged_fuel',
    energy_stim = 'enhanced_fuel',
    emergency_ration = 'repair_kit',
    medical_nanobots = 'eva_repair_kit',
    genetic_enhancement_serum = 'eva_repair_kit',
    universal_antidote = 'eva_repair_kit'
}

function Consumables.currentId(id)
    return replacements[id] or id
end

-- Reconstruir las fichas guardadas conservando la cantidad y posición de la pila.
function Consumables.refreshEntry(entry)
    local data = entry.data or entry
    local template = Items:getItem(Consumables.currentId(data.id))
    if template and (template.category == Items.CATEGORIES.CONSUMABLE or template.id == 'kit_schematic') then
        for key, value in pairs(template) do
            if key ~= 'quantity' then data[key] = value end
        end
    end
end

local function shipReady(player)
    return player and player.addFuel and not player.isInEVA and player.stats.health.currentHealth > 0
end

local function registerFuel(id, name, rarity, fraction, value)
    Items:registerItem({
        id = id, name = name, rarity = rarity, value = value,
        description = ('Repone hasta el %d%% del depósito de la nave.'):format(fraction * 100),
        category = Items.CATEGORIES.CONSUMABLE, stackable = true, maxStack = 5, weight = 1,
        canUse = function(_, player)
            if not shipReady(player) then return false, 'Necesitas una nave operativa.' end
            local fuel = player.stats.fuel
            return fuel.currentFuel < fuel.maxFuel, 'El depósito está lleno.'
        end,
        use = function(_, player)
            player:addFuel(player.stats.fuel.maxFuel * fraction)
            return 'Combustible repuesto'
        end
    })
end

local function registerKit(id, name, rarity, amount, value, integral)
    local description = ('Repara hasta %d puntos de casco'):format(amount)
    if integral then description = description .. ' y repone hasta el 50% del escudo y del combustible' end
    Items:registerItem({
        id = id, name = name, rarity = rarity, value = value,
        description = description .. ' tras 3 segundos sin recibir daño.',
        category = Items.CATEGORIES.CONSUMABLE, stackable = true, maxStack = 10, weight = 0.5,
        hullRepair = amount, icon = 'repair_kit', tags = {'repair', 'healing', 'ship'},
        canUse = function(_, player)
            if not shipReady(player) then return false, 'Necesitas una nave operativa.' end
            local stats = player.stats
            if stats:getRecoveryDelay() > 0 then return false, 'Reparación bloqueada por daño reciente.' end
            if stats.health.currentHealth < stats.health.maxHealth then return true end
            if integral then
                return stats.shield.currentShield < stats.shield.maxShield or stats.fuel.currentFuel < stats.fuel.maxFuel,
                    'El casco, el escudo y el depósito están completos.'
            end
            return false, 'El casco está intacto.'
        end,
        use = function(_, player)
            player:heal(amount)
            if integral then
                local shield = player.stats.shield
                shield.currentShield = math.min(shield.maxShield, shield.currentShield + shield.maxShield * 0.5)
                player:addFuel(player.stats.fuel.maxFuel * 0.5)
                return 'Kit de emergencia integral aplicado'
            end
            return 'Nave reparada'
        end
    })
end

function Consumables.registerAll()
    registerKit('repair_kit', 'Kit de reparación', tiers.COMMON, 50, 50)
    registerFuel('salvaged_fuel', 'Depósito de combustible', tiers.COMMON, 0.25, 45)
    registerKit('hull_kit_enhanced', 'Kit de reparación reforzado', tiers.UNCOMMON, 100, 110)
    registerFuel('enhanced_fuel', 'Depósito de alta capacidad', tiers.UNCOMMON, 0.5, 100)
    registerKit('hull_kit_superior', 'Kit de emergencia integral', tiers.EPIC, 100, 280, true)
    Items:registerItem({
        id = 'eva_repair_kit', name = 'Kit de reparación EVA', rarity = tiers.COMMON, value = 50,
        description = 'Cura hasta 25 puntos de vida del piloto durante una salida EVA.',
        category = Items.CATEGORIES.CONSUMABLE, stackable = true, maxStack = 5, weight = 0.5,
        icon = 'eva_repair_kit', tags = {'medical', 'eva', 'healing'},
        canUse = function(_, pilot)
            if not (pilot and pilot.ship and pilot.stats) then return false, 'Solo para el piloto en EVA.' end
            local health = pilot.stats.health
            return health.currentHealth > 0 and health.currentHealth < health.maxHealth, 'El piloto no necesita curación.'
        end,
        use = function(_, pilot)
            pilot.stats:heal(25)
            return 'Piloto curado'
        end
    })
end

return Consumables
