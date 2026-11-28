-- Mercante de la run. Interfaz pública para navegación y presentación:
-- signal(run, ship) -> rumbo (radianes), fase y, al descubrirlo, coordenadas.
-- open(run, ship) -> copia de visita y ofertas al alcance de comercio.
-- buy(run, ship, fase, índice, "credits"|"materials"), sellRecord y learnSchematic
-- devuelven éxito o false y el motivo. Cada operación mueve una unidad.
local Seed = require 'src.utils.seed_system'
local Items = require 'src.item_systems.item_system'

local Merchant = {}
local chances = {0, 1, .45, .45, .55, .55, .55, .65, .65, .65, 1}
local equipment = {
    {'kinetic_assault_rifle', 'enhanced_thrusters'},
    {'energy_shotgun', 'rapid_fire_system'},
    {'gauss_railgun', 'reactive_armor_plating'},
    {'gravitic_wave_projector', 'afterburner_injector'},
    {'void_needle_dart', 'cataclysm_core'}
}

local function copy(t)
    if type(t) ~= 'table' then return t end
    local result = {}
    for k, v in pairs(t) do result[k] = copy(v) end
    return result
end

local function stock(phase, rng)
    local offers = {}
    local function add(id, units, credits, materials, schematic)
        offers[#offers + 1] = {item = id, remaining = units, credits = credits,
            materials = materials, schematic = schematic}
    end
    local function price(id)
        return assert(Items:getItem(id), id).value
    end
    local function gear(tier, materials)
        local pool = equipment[tier]
        local id = pool[rng:randomInt(#pool)]
        add(id, 1, price(id), materials)
    end
    add('repair_kit', 3, price('repair_kit'))
    add('salvaged_fuel', 3, price('salvaged_fuel'))
    if phase == 2 then
        add('hull_kit_enhanced', 1, price('hull_kit_enhanced'), {repair_kit = 1, titanium_ingot = 1})
        add('hull_kit_superior', 1, nil, {frontier_seal = 1})
        return offers
    end
    local reserve = rng:random() < .5 and 'enhanced_fuel' or 'hull_kit_enhanced'
    add(reserve, 2, price(reserve))
    if phase < 5 then
        gear(rng:randomInt(2))
    else
        local deluxeChance = phase >= 8 and .75 or .4
        if phase == 11 and rng:random() < .25 then
            gear(5, {confinement_coil = 2})
        else
            gear(rng:random() < deluxeChance and 3 or 2, {servo_actuator = 1, basic_circuit = 2})
        end
        -- El esquema abre un canje especializado en las visitas avanzadas.
        add('hull_kit_enhanced', 1, nil, {advanced_polymer = 1, cable_harness = 2}, 'kit_schematic')
        if phase == 11 then
            gear(4)
        elseif phase >= 8 then
            if rng:random() < .5 then gear(4)
            else add('hull_kit_superior', 1, price('hull_kit_superior')) end
        end
    end
    return offers
end

-- Proyección sobre el borde anterior más cercano; evita recorrer una franja entera.
local function position(x, y, previous, bounds, rng)
    local dx = math.min(math.abs(previous.minX-x), math.abs(previous.maxX-x))
    local dy = math.min(math.abs(previous.minY-y), math.abs(previous.maxY-y))
    local offset = rng:randomInt(500, 1200)
    local lateral = rng:randomInt(-650, 650)
    if dx <= dy then
        x = x < (previous.minX+previous.maxX)/2 and previous.minX-offset or previous.maxX+offset
        y = y + lateral
    else
        y = y < (previous.minY+previous.maxY)/2 and previous.minY-offset or previous.maxY+offset
        x = x + lateral
    end
    return math.min(bounds.maxX-1, math.max(bounds.minX+1, x)),
        math.min(bounds.maxY-1, math.max(bounds.minY+1, y))
end

function Merchant.advance(run, phase, x, y, previous, bounds)
    local state = run.merchant or {phase = 1, misses = 0}
    run.merchant = state
    if phase <= state.phase then return end
    for n = state.phase + 1, phase do
        local rng = Seed.makeRNG(('%s:merchant:%d:arrival'):format(run.seed, n))
        local arrived = rng:random() < chances[n] or state.misses >= 2
        state.phase, state.visit = n, nil
        if arrived then
            state.misses = 0
            if n == phase then
                local mx, my = position(x, y, previous, bounds, rng)
                state.visit = {phase = n, x = mx, y = my, discovered = false, offers = stock(n, rng)}
            end
        else
            state.misses = state.misses + 1
        end
    end
end

function Merchant.update(run, ship)
    local visit = run.merchant and run.merchant.visit
    if visit and not visit.discovered and (ship.x-visit.x)^2 + (ship.y-visit.y)^2 <= 900^2 then
        visit.discovered = true
    end
end

function Merchant.signal(run, ship)
    local v = run.merchant and run.merchant.visit
    if not v then return nil end
    return {phase = v.phase, bearing = math.atan2(v.y-ship.y, v.x-ship.x), discovered = v.discovered,
        x = v.discovered and v.x or nil, y = v.discovered and v.y or nil}
end

local function contact(run, ship, phase)
    local v = run.merchant and run.merchant.visit
    if not v or (phase and phase ~= v.phase) then return nil, 'El mercante ha partido.' end
    if run.defeat or not ship or ship.isInEVA or not ship.inventory or
        (ship.x-v.x)^2 + (ship.y-v.y)^2 > 240^2 then return nil, 'Acércate con la nave.' end
    v.discovered = true
    return v
end

function Merchant.open(run, ship)
    local v, reason = contact(run, ship)
    if not v then return nil, reason end
    local view = copy(v)
    view.credits = run.resources.credits
    view.recordPrice = Items:getItem('survey_record').value
    view.learned = copy(run.schematics)
    return view
end

function Merchant.buy(run, ship, phase, index, payment)
    local v, reason = contact(run, ship, phase)
    if not v then return false, reason end
    local offer = v.offers[index]
    if not phase or not offer or offer.remaining < 1 then return false, 'Oferta agotada o caducada.' end
    if offer.schematic and not run.schematics[offer.schematic] then return false, 'Falta el esquema.' end
    local cost, materials = 0, {}
    if payment == 'credits' and offer.credits then
        cost = offer.credits
        if run.resources.credits < cost then return false, 'Créditos insuficientes.' end
    elseif payment == 'materials' and offer.materials then
        materials = offer.materials
    else return false, 'Forma de pago no disponible.' end
    local ok, failure = ship.inventory:exchangeCargo(materials, Items:getItem(offer.item))
    if not ok then return false, failure end
    run:spendCredits(cost)
    offer.remaining = offer.remaining - 1
    return true
end

function Merchant.sellRecord(run, ship, phase)
    local v, reason = contact(run, ship, phase)
    if not v or phase ~= v.phase then return false, reason or 'Visita caducada.' end
    local ok, failure = ship.inventory:exchangeCargo({survey_record = 1})
    if not ok then return false, failure end
    run:addCredits(Items:getItem('survey_record').value)
    return true
end

function Merchant.learnSchematic(run, ship, phase)
    local v, reason = contact(run, ship, phase)
    if not v or phase ~= v.phase then return false, reason or 'Visita caducada.' end
    if run.schematics.kit_schematic then return false, 'Esquema ya registrado.' end
    local ok, failure = ship.inventory:exchangeCargo({kit_schematic = 1})
    if not ok then return false, failure end
    run.schematics.kit_schematic = true
    return true
end

Merchant.copyState = copy
return Merchant
