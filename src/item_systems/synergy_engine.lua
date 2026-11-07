-- src/item_systems/synergy_engine.lua
-- Motor de Sinergias y Evolución de 3 Reglas:
--   Regla 1 (Arma + Arma): Consume ambas armas -> Crea 1 Arma Evolucionada y libera 1 slot de arma.
--   Regla 2 (Pasiva + Pasiva): Consume ambas pasivas -> Crea 1 Pasiva Evolucionada y libera 1 slot de pasiva.
--   Regla 3 (Arma + Pasiva): Conserva ambos ítems -> Amplifica y muta los proyectiles del arma equipada.

local ItemSystem = require 'src.item_systems.item_system'
local PassiveManager = require 'src.item_systems.passive_manager'

local SynergyEngine = {}

-- ============================================================================
-- 1. RECETAS DE FUSIÓN ARMA + ARMA (7 Evoluciones — Regla 1)
-- ============================================================================
SynergyEngine.WEAPON_FUSIONS = {
    {
        id = "fusion_thermo_cluster",
        ingredients = { "energy_shotgun", "plasma_rifle" },
        result = "thermo_cluster_cannon",
        title = "Cañón Termoclástico"
    },
    {
        id = "fusion_photon_gatling",
        ingredients = { "basic_laser_pistol", "kinetic_assault_rifle" },
        result = "photon_pulse_gatling",
        title = "Gatling Fotónica de Pulso"
    },
    {
        id = "fusion_supernova_lance",
        ingredients = { "heavy_plasma_cannon", "gauss_railgun" },
        result = "supernova_rail_lance",
        title = "Lanza de Supernova"
    },
    {
        id = "fusion_valkyrie_swarm",
        ingredients = { "arc_tesla_emitter", "swarm_micro_missiles" },
        result = "valkyrie_storm_swarm",
        title = "Enjambre de Tormenta Voltaica"
    },
    {
        id = "fusion_orbital_shredder",
        ingredients = { "ricochet_shard_gun", "industrial_rip_saw" },
        result = "orbital_shredder",
        title = "Trituradora Orbital de Cuchillas"
    },
    {
        id = "fusion_thermal_shock",
        ingredients = { "magma_slag_thrower", "cryo_shard_blaster" },
        result = "thermal_shock_cannon",
        title = "Cañón de Choque Térmico"
    },
    {
        id = "fusion_singularity_torpedo",
        ingredients = { "gravitic_wave_projector", "heavy_torpedo_launcher" },
        result = "singularity_torpedo",
        title = "Torpedo de Singularidad"
    }
}

-- ============================================================================
-- 2. RECETAS DE FUSIÓN PASIVA + PASIVA (3 Evoluciones — Regla 2)
-- ============================================================================
SynergyEngine.PASSIVE_FUSIONS = {
    {
        id = "fusion_phantom_drive",
        ingredients = { "enhanced_thrusters", "inertial_gyro" },
        result = "phantom_vector_drive",
        title = "Motor Vectorial Fantasma"
    },
    {
        id = "fusion_hyperfrequence",
        ingredients = { "chrono_capacitor", "overclock_relay" },
        result = "hyperfrequence_core",
        title = "Núcleo de Hiper-Frecuencia"
    },
    {
        id = "fusion_storm_matrix",
        ingredients = { "voltaic_coil", "prism_split_lens" },
        result = "refracted_storm_matrix",
        title = "Matriz de Tormenta Refractada"
    }
}

-- ============================================================================
-- 3. AMPLIFICACIONES CRUZADAS ARMA + PASIVA (Regla 3: Mantiene ambos ítems)
-- ============================================================================
SynergyEngine.AMPLIFICATIONS = {
    {
        id = "amp_voltaic_arc",
        name = "Sobrecarga Voltaica",
        passiveIds = { "voltaic_coil", "refracted_storm_matrix" },
        matchesWeapon = function(w)
            return w and (w.damageType == "energy" or w.damageType == "plasma")
        end,
        applyToWeapon = function(mods, passiveId)
            mods.chainArcBonus = (mods.chainArcBonus or 0) + (passiveId == "refracted_storm_matrix" and 2 or 1)
            mods.speedMult = (mods.speedMult or 1.0) * 1.20
            mods.voltaicTrail = true
        end
    },
    {
        id = "amp_prism_split",
        name = "Bifurcación Prismática",
        passiveIds = { "prism_split_lens", "refracted_storm_matrix" },
        matchesWeapon = function(w)
            return w ~= nil
        end,
        applyToWeapon = function(mods, passiveId)
            local interval = (passiveId == "refracted_storm_matrix") and 2 or 3
            mods.prismEveryN = math.min(mods.prismEveryN or 99, interval)
        end
    },
    {
        id = "amp_tungsten_pierce",
        name = "Perforación de Tungsteno",
        passiveIds = { "tungsten_sabot" },
        matchesWeapon = function(w)
            return w and w.damageType == "kinetic"
        end,
        applyToWeapon = function(mods)
            mods.forcePenetration = true
            mods.damageMult = (mods.damageMult or 1.0) * 1.15
        end
    },
    {
        id = "amp_thermite_burn",
        name = "Ignición de Termita",
        passiveIds = { "volatile_napalm_gel" },
        matchesWeapon = function(w)
            return w and (w.damageType == "plasma" or w.damageType == "explosive")
        end,
        applyToWeapon = function(mods)
            mods.statusEffect = mods.statusEffect or "burn"
            mods.explosionRadiusBonus = (mods.explosionRadiusBonus or 0) + 28
            mods.damageMult = (mods.damageMult or 1.0) * 1.10
        end
    },
    {
        id = "amp_neural_homing",
        name = "Rastreo Neuronal",
        passiveIds = { "neural_homing_chip" },
        matchesWeapon = function(w)
            return w ~= nil
        end,
        applyToWeapon = function(mods)
            mods.homingBonus = (mods.homingBonus or 0) + 2.2
        end
    }
}

local function cloneItemData(template)
    if not template then return nil end
    local copy = {}
    for k, v in pairs(template) do
        if type(v) == "table" then
            local sub = {}
            for sk, sv in pairs(v) do sub[sk] = sv end
            copy[k] = sub
        else
            copy[k] = v
        end
    end
    return copy
end

-- Equipment first makes fusion placement deterministic across compartments.
local function compartments(inventory)
    local result, seen = {}, {}
    local function add(name)
        local comp = inventory:getCompartment(name)
        if comp and comp.items and not seen[comp.items] then
            result[#result + 1] = {name = name, comp = comp, order = #result + 1}
            seen[comp.items] = true
        end
    end
    add("weapons")
    add("passives")
    add("ship")
    local names = {}
    for name in pairs(inventory.compartments or {}) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do add(name) end
    return result
end

local function findItem(containers, id)
    for _, container in ipairs(containers) do
        for slot = 1, container.comp.maxSlots do
            local entry = container.comp.items[slot]
            if entry and entry.data and entry.data.id == id then
                return {container = container, slot = slot, entry = entry}
            end
        end
    end
end

local function accepts(container, data)
    local kind = data.category == "equipable" and data.equipType or data.category
    return not container.comp.allowedTypes or container.comp.allowedTypes[kind]
end

local function destination(containers, a, b, data)
    -- Reuse a consumed slot, retaining equipped results whenever possible.
    local candidates = {a, b}
    if b.container.order < a.container.order
        or (a.container == b.container and b.slot < a.slot) then
        candidates = {b, a}
    end
    for _, ref in ipairs(candidates) do
        if (ref.entry.quantity or 1) == 1 and accepts(ref.container, data) then return ref end
    end
    for _, container in ipairs(containers) do
        if accepts(container, data) then
            for slot = 1, container.comp.maxSlots do
                if not container.comp.items[slot] then return {container = container, slot = slot} end
            end
        end
    end
end

local function consume(ref, player)
    local quantity = ref.entry.quantity or 1
    if quantity > 1 then
        ref.entry.quantity = quantity - 1
        ref.entry.data.quantity = quantity - 1
    else
        if ref.entry.passiveId then
            PassiveManager.removePassiveEffect(ref.entry.passiveId)
        elseif ref.container.name == "passives" then
            PassiveManager.removePassiveEffect(player, ref.entry.data)
        end
        ref.container.comp.items[ref.slot] = nil
    end
end

local function fuse(player, containers, recipes, rule)
    local changed = false
    for _, recipe in ipairs(recipes) do
        local a = findItem(containers, recipe.ingredients[1])
        local b = findItem(containers, recipe.ingredients[2])
        local template = ItemSystem:getItem(recipe.result)
        while a and b and template do
            local target = destination(containers, a, b, template)
            if not target then break end
            local data = cloneItemData(template)
            data.isEvolved, data.fuzedFrom = true, {recipe.ingredients[1], recipe.ingredients[2]}
            consume(a, player)
            consume(b, player)
            local entry = {data = data, quantity = 1}
            if target.container.name == "passives" then
                entry.passiveId = PassiveManager.applyPassiveEffect(player, data)
            end
            target.container.comp.items[target.slot] = entry
            local weaponSystem = player.weaponSystem
            if weaponSystem and target.container.name == "weapons" then
                if data.maxAmmo then weaponSystem.ammunition[data.id] = data.maxAmmo end
                if (a.container.name == "weapons" and weaponSystem.currentSlot == a.slot)
                    or (b.container.name == "weapons" and weaponSystem.currentSlot == b.slot) then
                    weaponSystem.currentSlot = target.slot
                    weaponSystem.isReloading = false
                end
            end
            local event = {rule = rule, recipeId = recipe.id, resultId = data.id,
                resultName = data.name, keptSlot = target.slot, compartment = target.container.name,
                timestamp = love.timer.getTime()}
            player.lastSynergyEvent = event
            player.synergyHistory[#player.synergyHistory + 1] = event
            changed = true
            a = findItem(containers, recipe.ingredients[1])
            b = findItem(containers, recipe.ingredients[2])
        end
    end
    return changed
end

local function evaluateInventory(player)
    local containers = compartments(player.inventory)
    player.synergyHistory = player.synergyHistory or {}
    local changed = false
    if not player.debugDisableSynergies then
        changed = fuse(player, containers, SynergyEngine.WEAPON_FUSIONS, "WEAPON_FUSION")
        changed = fuse(player, containers, SynergyEngine.PASSIVE_FUSIONS, "PASSIVE_FUSION") or changed
    end
    local passiveIds = {}
    for _, container in ipairs(containers) do
        for _, entry in pairs(container.comp.items) do
            if entry.data and entry.data.category == "passive" then passiveIds[entry.data.id] = true end
        end
    end
    for _, container in ipairs(containers) do
        for _, entry in pairs(container.comp.items) do
            local weapon = entry.data
            if weapon and weapon.equipType == "weapon" then
                local mods, active = {}, {}
                if not player.debugDisableSynergies then
                    for _, amp in ipairs(SynergyEngine.AMPLIFICATIONS) do
                        for _, id in ipairs(amp.passiveIds) do
                            if passiveIds[id] and amp.matchesWeapon(weapon) then
                                amp.applyToWeapon(mods, id)
                                active[#active + 1] = {id = amp.id, name = amp.name, passiveId = id}
                                break
                            end
                        end
                    end
                end
                weapon.synergyMods, weapon.activeSynergies, weapon.synergyCount = mods, active, #active
            end
        end
    end
    local ws = player.weaponSystem
    if ws then
        local entry = player.inventory:getWeaponInSlot(ws.currentSlot or 1)
        if not entry then
            local comp = player.inventory:getCompartment("weapons")
            for slot = 1, comp and comp.maxSlots or 0 do
                if comp.items[slot] then
                    ws.currentSlot, entry = slot, comp.items[slot]
                    break
                end
            end
        end
        local current = entry and entry.data or nil
        if current ~= ws.currentWeapon then ws.isReloading = false end
        ws.currentWeapon = current
        if current and current.maxAmmo and ws.ammunition[current.id] == nil then
            ws.ammunition[current.id] = current.maxAmmo
        end
    end
    return changed
end

function SynergyEngine.evaluate(player)
    if not player or not player.inventory or player._evaluatingSynergies then return false end
    player._evaluatingSynergies = true
    local ok, result = pcall(evaluateInventory, player)
    player._evaluatingSynergies = false
    if not ok then error(result, 0) end
    return result
end

-- Consultar posibles sinergias de un ítem para mostrar en Tooltips de UI
function SynergyEngine.getPotentialSynergiesForItem(itemId)
    if not itemId then return {} end
    local hints = {}
    for _, r in ipairs(SynergyEngine.WEAPON_FUSIONS) do
        if r.ingredients[1] == itemId then
            table.insert(hints, { partnerId = r.ingredients[2], resultName = r.title, type = "WEAPON_FUSION" })
        elseif r.ingredients[2] == itemId then
            table.insert(hints, { partnerId = r.ingredients[1], resultName = r.title, type = "WEAPON_FUSION" })
        end
    end
    for _, r in ipairs(SynergyEngine.PASSIVE_FUSIONS) do
        if r.ingredients[1] == itemId then
            table.insert(hints, { partnerId = r.ingredients[2], resultName = r.title, type = "PASSIVE_FUSION" })
        elseif r.ingredients[2] == itemId then
            table.insert(hints, { partnerId = r.ingredients[1], resultName = r.title, type = "PASSIVE_FUSION" })
        end
    end
    return hints
end

return SynergyEngine

