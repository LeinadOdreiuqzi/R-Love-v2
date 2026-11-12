-- Read-only combat view. No inventory mutations or recipe evaluation on draw.
local Synergy = require 'src.item_systems.synergy_engine'
local Items = require 'src.item_systems.item_system'
local View = {}

local function eachItem(player, visit)
    local inventory = player and player.inventory
    if not inventory then return end
    local seen = {}
    for name, comp in pairs(inventory.compartments or {}) do
        if comp.items and not seen[comp.items] then
            seen[comp.items] = true
            for slot, entry in pairs(comp.items) do
                if entry.data then visit(entry.data, name, slot) end
            end
        end
    end
end

function View.item(player, data)
    local result = {evolved = not not data.isEvolved, amplifications = {}, recipes = {}, equipped = false}
    local owned = {}
    eachItem(player, function(item, compartment)
        owned[item.id] = true
        if item == data and (compartment == 'weapons' or compartment == 'passives') then result.equipped = true end
    end)
    for _, amp in ipairs(data.activeSynergies or {}) do
        result.amplifications[#result.amplifications + 1] = {
            name = amp.name, equipped = result.equipped, weapon = data.name, passiveId = amp.passiveId}
    end
    if data.category == 'passive' then
        eachItem(player, function(weapon, compartment)
            for _, amp in ipairs(weapon.activeSynergies or {}) do
                if amp.passiveId == data.id then
                    result.amplifications[#result.amplifications + 1] = {
                        name = amp.name, equipped = compartment == 'weapons', weapon = weapon.name}
                end
            end
        end)
    end
    for _, hint in ipairs(Synergy.getPotentialSynergiesForItem(data.id)) do
        local partner = Items:getItem(hint.partnerId)
        result.recipes[#result.recipes + 1] = {
            partner = partner and partner.name or hint.partnerId, result = hint.resultName,
            available = owned[data.id] and owned[hint.partnerId] or false,
            disabled = player and player.debugDisableSynergies or false}
    end
    return result
end

function View.tooltip(player, data)
    local state, lines = View.item(player, data), {}
    local ws = player and player.weaponSystem
    local kit = player and data.id == 'repair_kit' and Items:getItem(data.id)
    if kit then
        local available, reason = kit:canUse(player)
        if not available then lines[#lines + 1] = {kind = 'muted', text = reason} end
    end
    if data.equipType == Items.EQUIPABLE_TYPES.WEAPON and ws then
        local low, high = ws:getEffectiveDamageRange(data)
        local damage = string.format('%.1f', low)
        if string.format('%.1f', high) ~= damage then
            damage = damage .. '-' .. string.format('%.1f', high)
        end
        lines[#lines + 1] = {kind = 'text', text = string.format(
            'Daño de referencia %s  |  Cadencia %.2f disp/s', damage, ws:getEffectiveFireRate(data))}
        if data.maxAmmo then
            lines[#lines + 1] = {kind = 'muted', text = string.format(
                'Cargador %d  |  Recarga %.2f s', data.maxAmmo, ws:getEffectiveReloadTime(data))}
        end
    end
    if state.evolved then lines[#lines + 1] = {kind = 'evolved', text = '★ EVOLUCIÓN · ' .. (state.equipped and 'equipada' or 'en carga')} end
    for _, amp in ipairs(state.amplifications) do
        lines[#lines + 1] = {kind = 'active', text = (amp.equipped and 'AMP EQUIPADA · ' or 'AMP EN CARGA · ') .. amp.name
            .. (data.category == 'passive' and (' / ' .. amp.weapon) or '')}
    end
    for _, recipe in ipairs(state.recipes) do
        lines[#lines + 1] = {kind = recipe.available and 'recipe' or 'muted',
            text = (recipe.available and 'RECETA DISPONIBLE' or 'RECETA · falta ' .. recipe.partner)
                .. (recipe.disabled and ' [sinergias OFF]' or '') .. '\n+ ' .. recipe.partner .. ' → ' .. recipe.result}
    end
    return lines, state
end

function View.ability(system, key)
    local remaining = system[key] or 0
    local active = key == 'q' and math.max(system.dashFlash or 0, system.overclock or 0,
        system.doubleCast or 0, system.decoy and system.decoy.life or 0)
        or (key == 'r' and system.field and system.field.life or 0)
    local available = system:available()
    return {key = key, remaining = remaining, active = active,
        state = not available and 'BLOQUEADA' or active > 0 and 'ACTIVA' or remaining > 0 and 'RECARGA' or 'LISTA'}
end

function View.weapons(player)
    local slots, ws = {}, player.weaponSystem
    for slot = 1, 9 do
        local entry = player.inventory:getWeaponInSlot(slot)
        local data = entry and entry.data
        local selected = slot == ws.currentSlot
        local progress = selected and ws.isReloading and ws:getReloadProgress() or 0
        slots[slot] = {slot = slot, data = data, selected = selected,
            ammo = data and data.maxAmmo and (ws.ammunition[data.id] or data.maxAmmo) or nil,
            reloading = selected and ws.isReloading and data ~= nil, progress = progress,
            amplifications = data and #(data.activeSynergies or {}) or 0}
    end
    return slots
end

return View
