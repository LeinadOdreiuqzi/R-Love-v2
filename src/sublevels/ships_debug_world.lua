-- src/sublevels/ships_debug_world.lua
-- Hangar de Exhibición y Banco de Pruebas de Naves y Nodrizas (Submundo Debug).
-- Permite apreciar los 10 arquetipos de naves (7 tácticas + 3 Nodrizas con sus escoltas),
-- inspeccionar su geometría, probar sus efectos diegéticos, activar vuelo IA o abordarlas en EVA.

local Naves = require 'src.entities.naves'
local AIController = require 'src.entities.ai_controller'
local World = require 'src.core.world'
local WeaponTrial = require 'src.sublevels.weapon_trial'

local ShipsDebugWorld = {
    pads = {},
    spawnedShips = {},
    autoRotate = false,
    showTacticalFX = true,
    liveAIMode = false,
    closestPad = nil
}

-- Catálogo de las 10 plataformas del Hangar Orbital
local HANGAR_LAYOUT = {
    -- FILA 1: Naves Tácticas y de Ecosistema (Y = 0)
    {
        index = 1, key = "1",
        shipType = "EXPLORER",
        title = "EXPLORADOR LIGERO",
        subtitle = "Clase Ligera Polivalente · Balanceada",
        role = AIController.ROLES.NOMAD,
        x = -1440, y = 0, padRadius = 95,
        badgeColor = { 0.30, 0.78, 1.00 },
        statsText = "HP: 80  |  Escudo: 50  |  Vel: 95  |  Arma: Plasma Simple"
    },
    {
        index = 2, key = "2",
        shipType = "FIGHTER",
        title = "CAZA DE COMBATE",
        subtitle = "Clase Asalto · Ráfagas Rápidas",
        role = AIController.ROLES.RAIDER,
        x = -960, y = 0, padRadius = 95,
        badgeColor = { 1.00, 0.38, 0.25 },
        statsText = "HP: 120 |  Escudo: 80  |  Vel: 85  |  Arma: Plasma Rápido"
    },
    {
        index = 3, key = "3",
        shipType = "CARGO",
        title = "CARGUERO PESADO",
        subtitle = "Clase Logística · Bodega Expandida",
        role = AIController.ROLES.SCAVENGER,
        x = -480, y = 0, padRadius = 105,
        badgeColor = { 0.95, 0.75, 0.25 },
        statsText = "HP: 200 |  Escudo: 120 |  Vel: 60  |  Arma: Láser Defensivo"
    },
    {
        index = 4, key = "4",
        shipType = "INTERCEPTOR",
        title = "INTERCEPTOR CORSARIO",
        subtitle = "Caza Aguja Violáceo · Derrape y Flanqueo",
        role = AIController.ROLES.RAIDER,
        x = 0, y = 0, padRadius = 95,
        badgeColor = { 0.78, 0.28, 1.00 },
        statsText = "HP: 75  |  Escudo: 45  |  Vel: 112 |  Arma: Aguja Rápida"
    },
    {
        index = 5, key = "5",
        shipType = "GUNSHIP",
        title = "CAÑONERA ACORAZADA",
        subtitle = "Plataforma Pesada · Salva con Telegrafía",
        role = AIController.ROLES.RAIDER,
        x = 480, y = 0, padRadius = 110,
        badgeColor = { 0.95, 0.25, 0.30 },
        statsText = "HP: 175 |  Escudo: 110 |  Vel: 66  |  Arma: Cañón Pesado"
    },
    {
        index = 6, key = "6",
        shipType = "SALVAGER",
        title = "DESMANTELADOR INDUSTRIAL",
        subtitle = "Catamarán Minero · Pinzas de Extracción",
        role = AIController.ROLES.SCAVENGER,
        x = 960, y = 0, padRadius = 105,
        badgeColor = { 1.00, 0.80, 0.20 },
        statsText = "HP: 140 |  Escudo: 75  |  Vel: 72  |  Arma: Cortador Industrial"
    },
    {
        index = 7, key = "7",
        shipType = "SENTINEL",
        title = "CONSTRUCTO CENTINELA",
        subtitle = "Guardián Antiguo · No Abordable (100% Destrucción)",
        role = AIController.ROLES.WARDEN,
        x = 1440, y = 0, padRadius = 100,
        badgeColor = { 0.20, 0.95, 1.00 },
        statsText = "HP: 135 |  Escudo: 145 |  Vel: 82  |  Arma: Pulso Arcano"
    },

    -- FILA 2: Nodrizas / Portanaves Capitales con sus Escuadrones (Y = 760)
    {
        index = 8, key = "8",
        shipType = "TITAN_EXCAVATOR",
        title = "NODRIZA: EXCAVADORA TITÁN",
        subtitle = "Portanaves Industrial · Refinería Móvil + Escoltas",
        role = AIController.ROLES.SCAVENGER,
        x = -960, y = 760, padRadius = 195,
        isMothership = true,
        badgeColor = { 1.00, 0.78, 0.22 },
        statsText = "HP: 420 |  Escudo: 260 |  Hangar: 2 SALVAGER |  Abordable en EVA",
        escorts = {
            { type = "SALVAGER", role = AIController.ROLES.SCAVENGER, ox = -135, oy = 65 },
            { type = "FIGHTER",  role = AIController.ROLES.NOMAD,     ox = 135,  oy = 65 }
        }
    },
    {
        index = 9, key = "9",
        shipType = "ECLIPSE",
        title = "NODRIZA: PORTANAVES ECLIPSE",
        subtitle = "Portanaves Morado/Obsidiana · Enlace de Escudo + Hangar",
        role = AIController.ROLES.RAIDER,
        x = 0, y = 760, padRadius = 210,
        isMothership = true,
        badgeColor = { 0.85, 0.25, 1.00 },
        statsText = "HP: 340 |  Escudo: 150 |  Hangar: 2 INTERCEPTOR |  Abordable en EVA",
        escorts = {
            { type = "INTERCEPTOR", role = AIController.ROLES.RAIDER, ox = -130, oy = 75 },
            { type = "INTERCEPTOR", role = AIController.ROLES.RAIDER, ox = 130,  oy = 75 }
        }
    },
    {
        index = 10, key = "0",
        shipType = "ARK_MONOLITH",
        title = "NODRIZA: ARCA MONOLITO",
        subtitle = "Matriz Nodal Centinela · Anillos Concéntricos + Drones",
        role = AIController.ROLES.WARDEN,
        x = 960, y = 760, padRadius = 200,
        isMothership = true,
        badgeColor = { 0.20, 0.95, 1.00 },
        statsText = "HP: 450 |  Escudo: 360 |  Hangar: 2 SENTINEL |  Autómata Antiguo",
        escorts = {
            { type = "SENTINEL", role = AIController.ROLES.WARDEN, ox = -145, oy = 0 },
            { type = "SENTINEL", role = AIController.ROLES.WARDEN, ox = 145,  oy = 0 }
        }
    }
}

local function clearShots(ship)
    for _, shot in ipairs(ship.projectiles or {}) do
        shot.explosion_radius = 0
        shot:destroy('hangar_reset')
    end
    ship.projectiles, ship.projectileVFX = {}, nil
end

function ShipsDebugWorld.cleanup()
    local player = World.get('player')
    if ShipsDebugWorld.weaponTrial then
        clearShots(ShipsDebugWorld.weaponTrial.player)
        WeaponTrial.finish(ShipsDebugWorld.weaponTrial)
        ShipsDebugWorld.weaponTrial = nil
    end
    for _, ship in ipairs(ShipsDebugWorld.spawnedShips) do
        if ship and ship ~= player and not ship.isPiloted then
            ship.isDestroyed = true
            clearShots(ship)
            if Naves and Naves.removeShip then
                Naves.removeShip(ship.shipId)
            end
            if World and World.removeEntity then
                World.removeEntity(ship)
            end
        end
    end
    ShipsDebugWorld.spawnedShips = {}
    ShipsDebugWorld.pads = {}
    ShipsDebugWorld.closestPad = nil
    ShipsDebugWorld.trial = nil
end

local function spawnHangarShip(x, y, shipType, role, extraOpts)
    local ship = Naves:new(x, y, shipType)
    ship.useStarterSprite = false
    ship.sprite = nil
    ship.rotation = 0
    ship.prevRotation = 0
    ship.dx = 0
    ship.dy = 0
    ship.driftAngularSpeed = 0

    local ai = AIController:new(ship, {
        role = role,
        rng = extraOpts and extraOpts.rng,
        trace = extraOpts and extraOpts.trace,
        homeX = x,
        homeY = y,
        wingmanOf = extraOpts and extraOpts.wingmanOf,
        formationSlotIndex = extraOpts and extraOpts.formationSlotIndex,
        formationOffsetX = extraOpts and extraOpts.formationOffsetX,
        formationOffsetY = extraOpts and extraOpts.formationOffsetY
    })
    ship.aiController = ai

    -- En modo exhibición estática están disponibles para ser inspeccionadas o abordadas en EVA (S+E -> E)
    ai.active = false
    ship.isAI = false
    ship.isAbandoned = true
    ship.isImmobilized = true
    ship.isPiloted = false
    ship.engineGlow = 0.85

    World.addEntity(ship)
    table.insert(ShipsDebugWorld.spawnedShips, ship)
    return ship
end

function ShipsDebugWorld.init(cfg)
    ShipsDebugWorld.cleanup()
    ShipsDebugWorld.autoRotate = false
    ShipsDebugWorld.showTacticalFX = true
    ShipsDebugWorld.liveAIMode = false

    for _, def in ipairs(HANGAR_LAYOUT) do
        local pad = {
            index = def.index,
            key = def.key,
            shipType = def.shipType,
            title = def.title,
            subtitle = def.subtitle,
            role = def.role,
            x = def.x,
            y = def.y,
            padRadius = def.padRadius,
            isMothership = def.isMothership,
            badgeColor = def.badgeColor,
            statsText = def.statsText,
            escortShips = {}
        }

        pad.mainShip = spawnHangarShip(def.x, def.y, def.shipType, def.role)

        if def.escorts then
            for idx, ed in ipairs(def.escorts) do
                local ex = def.x + ed.ox
                local ey = def.y + ed.oy
                local escort = spawnHangarShip(ex, ey, ed.type, ed.role, {
                    wingmanOf = pad.mainShip,
                    formationSlotIndex = idx,
                    formationOffsetX = ed.ox,
                    formationOffsetY = ed.oy
                })
                table.insert(pad.escortShips, { ship = escort, ox = ed.ox, oy = ed.oy, slot = idx })
            end
            if pad.mainShip and pad.mainShip.aiController then
                local list = {}
                for _, e in ipairs(pad.escortShips) do table.insert(list, e.ship) end
                pad.mainShip.aiController.escorts = list
            end
        end

        table.insert(ShipsDebugWorld.pads, pad)
    end
end

function ShipsDebugWorld.setLiveAIMode(enabled)
    ShipsDebugWorld.liveAIMode = enabled
    local player = World.get('player')
    for _, pad in ipairs(ShipsDebugWorld.pads) do
        local s = pad.mainShip
        if s and s ~= player and not s.isPiloted and not s.isDestroyed then
            if enabled then
                s.isAI = true
                s.isAbandoned = false
                s.isImmobilized = false
                if s.aiController then
                    s.aiController.active = true
                    s.aiController:pickNewWorldGoal()
                end
            else
                s.isAI = false
                s.isAbandoned = true
                s.isImmobilized = true
                s.x, s.y = pad.x, pad.y
                s.prevX, s.prevY = pad.x, pad.y
                s.dx, s.dy = 0, 0
                s.rotation = 0
                if s.aiController then s.aiController.active = false end
            end
        end

        for _, ed in ipairs(pad.escortShips or {}) do
            local es = ed.ship
            if es and es ~= player and not es.isPiloted and not es.isDestroyed then
                if enabled then
                    es.isAI = true
                    es.isAbandoned = false
                    es.isImmobilized = false
                    if es.aiController then
                        es.aiController.active = true
                        es.aiController:pickNewWorldGoal()
                    end
                else
                    es.isAI = false
                    es.isAbandoned = true
                    es.isImmobilized = true
                    es.x, es.y = pad.x + ed.ox, pad.y + ed.oy
                    es.prevX, es.prevY = es.x, es.y
                    es.dx, es.dy = 0, 0
                    es.rotation = 0
                    if es.aiController then es.aiController.active = false end
                end
            end
        end
    end
end

local TRIALS = {
    {title = "Duelo · Interceptor", ships = {"INTERCEPTOR"}},
    {title = "Duelo · Artillería", ships = {"GUNSHIP"}},
    {title = "Escuadrón · 1 contra 3", ships = {"GUNSHIP", "INTERCEPTOR", "FIGHTER"}}
}
local TRIAL_WEAPONS = {
    INTERCEPTOR = "kinetic_assault_rifle",
    GUNSHIP = "gauss_railgun",
    FIGHTER = "plasma_rifle"
}

function ShipsDebugWorld.startTrial(index, player, camera)
    if not player or player.isInEVA or player.isDestroyed then return false end
    local spec = TRIALS[index]
    if not spec then return false end
    ShipsDebugWorld.cleanup()
    ShipsDebugWorld.liveAIMode = true
    local originX = 2800
    local trial = {index = index, title = spec.title, events = {}, time = 0,
        damage = 0, health = player.stats.health.currentHealth, shield = player.stats.shield.currentShield}
    ShipsDebugWorld.trial = trial
    local function trace(_, event)
        trial.events[event] = (trial.events[event] or 0) + 1
    end
    clearShots(player)
    player.x, player.y, player.prevX, player.prevY = originX, 340, originX, 340
    player.dx, player.dy = 0, 0
    if player.abilitySystem then player.abilitySystem:cancel() end
    if camera then camera:setPosition(player.x, player.y) end
    local Items = require 'src.item_systems.item_system'
    local leader
    for slot, kind in ipairs(spec.ships) do
        local x = originX + (slot == 1 and 0 or (slot == 2 and -220 or 220))
        local y = slot == 1 and -140 or -50
        local ship = spawnHangarShip(x, y, kind, AIController.ROLES.RAIDER, {
            rng = love.math.newRandomGenerator(801 + slot),
            trace = trace,
            wingmanOf = leader,
            formationSlotIndex = slot
        })
        leader = leader or ship
        ship.rotation = math.atan2(player.y - y, player.x - x) + math.pi * .5
        ship.prevRotation = ship.rotation
        ship.isAI, ship.isAbandoned, ship.isImmobilized = true, false, false
        ship.debugDisableSynergies = true
        local weapon = Items:getItem(TRIAL_WEAPONS[kind])
        if weapon and ship:equipWeapon(weapon, 2) then ship.weaponSystem:switchToSlot(2) end
        local ai = ship.aiController
        ai.active, ai.state, ai.combatTarget = true, AIController.STATES.COMBAT, player
        ai.combatMemoryTimer = 10
        ShipsDebugWorld.pads[slot] = {x = x, y = y, index = slot, padRadius = 50,
            mainShip = ship, title = kind, escortShips = {}}
    end
    return true
end

function ShipsDebugWorld.startWeaponTrial(settings, player, camera)
    if not player or player.isInEVA or player.isDestroyed then return false end
    local targets = {}
    if settings.lane == 3 or settings.lane == WeaponTrial.duelLane then
        local encounter = settings.lane == WeaponTrial.duelLane and 2 or 3
        if not ShipsDebugWorld.startTrial(encounter, player, camera) then return false end
        targets = ShipsDebugWorld.spawnedShips
    else
        ShipsDebugWorld.cleanup()
        clearShots(player)
        local x, y = 2800, 340
        player.x, player.y, player.prevX, player.prevY = x, y, x, y
        player.dx, player.dy = 0, 0
        if camera then camera:setPosition(x, y) end
        local target = spawnHangarShip(x + WeaponTrial.distances[settings.distance], y,
            settings.lane == 2 and 'INTERCEPTOR' or 'EXPLORER', AIController.ROLES.RAIDER)
        target.isAbandoned = false
        target.stats.shield.regenRate = 0
        targets[1] = target
    end
    ShipsDebugWorld.weaponTrial = WeaponTrial.start(player, settings, targets)
    return true
end

function ShipsDebugWorld.update(dt, player)
    local weaponTrial = ShipsDebugWorld.weaponTrial
    if weaponTrial then
        WeaponTrial.update(weaponTrial, dt)
        for _, target in ipairs(weaponTrial.targets) do
            if target.weaponAuditDefeated and not target.isDestroyed then
                target.isDestroyed = true
                clearShots(target)
                Naves.removeShip(target.shipId)
            end
        end
        if weaponTrial.finished then return end
        if weaponTrial.settings.lane <= 2 then
            local target = weaponTrial.targets[1]
            target.prevX, target.prevY = target.x, target.y
            if weaponTrial.settings.lane == 2 then
                local travel = weaponTrial.time % 4 / 2
                target.y = 340 - 144 + 288 * (1 - math.abs(travel - 1))
                target.dy = travel < 1 and 2.4 or -2.4
                target.rotation = travel < 1 and math.pi or 0
                target.prevRotation = target.rotation
            end
            target:updateBurn(dt)
            return
        end
    end
    local trial = ShipsDebugWorld.trial
    if trial then
        trial.time = trial.time + dt
        if player then
            local health, shield = player.stats.health.currentHealth, player.stats.shield.currentShield
            trial.damage = trial.damage + math.max(0, trial.health - health) + math.max(0, trial.shield - shield)
            trial.health, trial.shield = health, shield
        end
    end
    local activeEntity = (player and player.getActiveEntity and player:getActiveEntity()) or player
    local px = (activeEntity and activeEntity.x) or (player and player.x) or 0
    local py = (activeEntity and activeEntity.y) or (player and player.y) or 0
    local t = love.timer.getTime()

    local closest = nil
    local minDist = math.huge

    for _, pad in ipairs(ShipsDebugWorld.pads) do
        local dx = pad.x - px
        local dy = pad.y - py
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < minDist then
            minDist = dist
            closest = pad
        end

        local ship = pad.mainShip
        if ship and not ship.isPiloted and not ShipsDebugWorld.liveAIMode then
            ship.engineGlow = 0.75 + 0.25 * math.sin(t * 4.0 + pad.index)
            if ShipsDebugWorld.autoRotate then
                ship.rotation = (ship.rotation + 0.55 * dt) % (math.pi * 2)
                ship.prevRotation = ship.rotation
            end
        elseif ship and not ship.isPiloted and ShipsDebugWorld.liveAIMode and ship.update then
            if ship.savePreviousState then ship:savePreviousState() end
            ship:update(dt)
        end

        -- Orbitar o rotar escoltas suavemente en el hangar
        for _, ed in ipairs(pad.escortShips or {}) do
            local es = ed.ship
            if es and not es.isPiloted and not ShipsDebugWorld.liveAIMode then
                es.engineGlow = 0.85
                if ShipsDebugWorld.autoRotate then
                    local angle = t * 0.75 + ed.slot * math.pi
                    local rad = 140
                    es.x = pad.x + math.cos(angle) * rad
                    es.y = pad.y + math.sin(angle) * rad
                    es.prevX, es.prevY = es.x, es.y
                    es.rotation = angle + math.pi
                    es.prevRotation = es.rotation
                end
            elseif es and not es.isPiloted and ShipsDebugWorld.liveAIMode and es.update then
                if es.savePreviousState then es:savePreviousState() end
                es:update(dt)
            end
        end
    end

    ShipsDebugWorld.closestPad = closest
end

function ShipsDebugWorld.draw(camera, player)
    if ShipsDebugWorld.trial or ShipsDebugWorld.weaponTrial then
        for _, ship in ipairs(ShipsDebugWorld.spawnedShips) do
            if not ship.isPiloted and not ship.isDestroyed then ship:draw() end
        end
        return
    end
    if #ShipsDebugWorld.pads == 0 then return end
    local t = love.timer.getTime()
    local r, g, b, a = love.graphics.getColor()

    -- 1. Líneas de pista del Hangar Orbital
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(0.18, 0.34, 0.55, 0.28)
    love.graphics.line(-1650, 0, 1650, 0)
    love.graphics.line(-1250, 760, 1250, 760)

    -- 2. Plataformas holográficas, demostración de haces diegéticos y dibujo en vivo de las naves
    for _, pad in ipairs(ShipsDebugWorld.pads) do
        local isNear = (pad == ShipsDebugWorld.closestPad)
        local bCol = pad.badgeColor or { 0.35, 0.75, 1.0 }
        local pulse = 0.65 + 0.35 * math.sin(t * 2.5 + pad.index)

        -- Plataforma circular del hangar (bajo la nave)
        love.graphics.setColor(0.03, 0.06, 0.11, 0.65)
        love.graphics.circle("fill", pad.x, pad.y, pad.padRadius, 40)

        love.graphics.setLineWidth(isNear and 2.5 or 1.2)
        love.graphics.setColor(bCol[1], bCol[2], bCol[3], (isNear and 0.75 or 0.35) * pulse)
        love.graphics.circle("line", pad.x, pad.y, pad.padRadius, 40)
        love.graphics.circle("line", pad.x, pad.y, pad.padRadius * 0.72, 32)

        -- Si showTacticalFX está activo y son Nodrizas, mostrar su Enlace de Escudo (Carrier Shield Tether) hacia sus escoltas
        local ship = pad.mainShip
        if ShipsDebugWorld.showTacticalFX and pad.isMothership and ship and not ship.isDestroyed then
            for _, ed in ipairs(pad.escortShips or {}) do
                local es = ed.ship
                if es and not es.isDestroyed then
                    love.graphics.setColor(bCol[1], bCol[2], bCol[3], 0.36 * pulse)
                    love.graphics.setLineWidth(4.0)
                    love.graphics.line(ship.x, ship.y, es.x, es.y)
                    love.graphics.setColor(0.90, 0.98, 1.0, 0.85 * pulse)
                    love.graphics.setLineWidth(1.4)
                    love.graphics.line(ship.x, ship.y, es.x, es.y)
                    love.graphics.circle("line", es.x, es.y, (es.size or 14) * 1.65, 20)
                end
            end
        end

        -- Renderizar la nave con sus colores activos reales (no apagados) aunque esté lista para ser abordada
        if ship and not ship.isDestroyed and not ship.isPiloted then
            if ShipsDebugWorld.liveAIMode and ship.draw then
                ship:draw()
            else
                love.graphics.push()
                love.graphics.translate(ship.x, ship.y)
                love.graphics.rotate(ship.rotation or 0)
                if ship.drawShieldEffect then ship:drawShieldEffect() end
                if ship.drawGeometricShip then ship:drawGeometricShip(false, ShipsDebugWorld.classicArt) end
                love.graphics.pop()
            end
        end

        for _, ed in ipairs(pad.escortShips or {}) do
            local es = ed.ship
            if es and not es.isDestroyed and not es.isPiloted then
                if ShipsDebugWorld.liveAIMode and es.draw then
                    es:draw()
                else
                    love.graphics.push()
                    love.graphics.translate(es.x, es.y)
                    love.graphics.rotate(es.rotation or 0)
                    if es.drawShieldEffect then es:drawShieldEffect() end
                    if es.drawGeometricShip then es:drawGeometricShip(false, ShipsDebugWorld.classicArt) end
                    love.graphics.pop()
                end
            end
        end

        -- 3. Placa holográfica de especificaciones sobre cada plataforma
        local tagW = pad.isMothership and 360 or 290
        local tagH = 66
        local tagX = pad.x - tagW * 0.5
        local tagY = pad.y - pad.padRadius - 82

        love.graphics.setColor(bCol[1], bCol[2], bCol[3], isNear and 0.65 or 0.30)
        love.graphics.setLineWidth(1)
        love.graphics.line(pad.x, tagY + tagH, pad.x, pad.y - pad.padRadius)

        love.graphics.setColor(0.04, 0.07, 0.13, isNear and 0.92 or 0.76)
        love.graphics.rectangle("fill", tagX, tagY, tagW, tagH, 6, 6)

        love.graphics.setColor(bCol[1], bCol[2], bCol[3], isNear and 0.90 or 0.45)
        love.graphics.setLineWidth(isNear and 1.8 or 1.0)
        love.graphics.rectangle("line", tagX, tagY, tagW, tagH, 6, 6)

        love.graphics.setColor(bCol[1], bCol[2], bCol[3], 1.0)
        love.graphics.printf(string.format("[%s] %s", pad.key, pad.title), tagX + 8, tagY + 7, tagW - 16, "center")

        love.graphics.setColor(0.82, 0.88, 0.96, 0.92)
        love.graphics.printf(pad.subtitle, tagX + 8, tagY + 26, tagW - 16, "center")

        love.graphics.setColor(0.60, 0.78, 0.95, 0.85)
        love.graphics.printf(pad.statsText, tagX + 8, tagY + 45, tagW - 16, "center")
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(r, g, b, a)
end

function ShipsDebugWorld.drawHUD()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local r, g, b, a = love.graphics.getColor()

    local panelW = math.min(820, sw - 24)
    local weaponTrial = ShipsDebugWorld.weaponTrial
    local chassisDuel = weaponTrial and weaponTrial.settings.lane == WeaponTrial.duelLane
    local panelH = chassisDuel and 100 or 82
    local px = (sw - panelW) * 0.5
    local py = (ShipsDebugWorld.trial or weaponTrial) and 66 or sh - panelH - 82

    love.graphics.setColor(0.03, 0.06, 0.11, 0.88)
    love.graphics.rectangle("fill", px, py, panelW, panelH, 8, 8)
    love.graphics.setColor(0.30, 0.75, 1.0, 0.70)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", px, py, panelW, panelH, 8, 8)

    if weaponTrial then
        local s = weaponTrial.settings
        local distance = s.lane <= 2 and (' · ' .. WeaponTrial.distances[s.distance] .. ' u') or ''
        love.graphics.setColor(.75, .94, 1, 1)
        if chassisDuel then
            love.graphics.printf(string.format("%s contra Gunship · Gauss N1 · %.1f s%s",
                weaponTrial.player.shipConfig.name, weaponTrial.time,
                weaponTrial.result and (' · ' .. weaponTrial.result) or ''),
                px + 8, py + 5, panelW - 16, 'center')
            love.graphics.printf(string.format("Daño recibido · Escudo %.0f · Casco %.0f | Daño infligido %.0f",
                weaponTrial.incomingShield, weaponTrial.incomingHull, weaponTrial.shield + weaponTrial.hull),
                px + 8, py + 23, panelW - 16, 'center')
            love.graphics.printf(string.format("Tiros %d · Velocidad pico %.0f u/s · Combustible usado %.2f",
                weaponTrial.triggers, weaponTrial.peakSpeed, weaponTrial.fuelUsed),
                px + 8, py + 41, panelW - 16, 'center')
            love.graphics.printf("Para retirarte, aléjate 900 u y evita el daño durante 3 s.",
                px + 8, py + 59, panelW - 16, 'center')
            love.graphics.printf("[N] Cambiar chasis  [K] Repetir  [F] Volver al hangar",
                px + 8, py + 77, panelW - 16, 'center')
            love.graphics.setLineWidth(1)
            love.graphics.setColor(r, g, b, a)
            return
        end
        love.graphics.printf(string.format("%s · %s%s · N%d · %.1f s%s", weaponTrial.name,
            WeaponTrial.lanes[s.lane], distance, s.level, weaponTrial.time, weaponTrial.finished and ' · FIN' or ''),
            px + 8, py + 5, panelW - 16, 'center')
        love.graphics.printf(string.format("Gatillos %d · Munición %d · Proyectiles %d · Salva máx. %d · Pico vivo %d",
            weaponTrial.triggers, weaponTrial.ammo, weaponTrial.spawned, weaponTrial.maxVolley, weaponTrial.peak),
            px + 8, py + 23, panelW - 16, 'center')
        love.graphics.printf(string.format("Escudo %.0f · Casco %.0f · Derribos %d/%d · 1.ª baja %s · Recarga %.1fs",
            weaponTrial.shield, weaponTrial.hull, weaponTrial.defeated, #weaponTrial.targets,
            weaponTrial.firstKill and string.format('%.2fs', weaponTrial.firstKill) or '-',
            weaponTrial.reload), px + 8, py + 41, panelW - 16, 'center')
        love.graphics.printf("[1–5] Arma  [J] Pista  [U] Distancia  [H] Nivel  [Z] Zoom  [K] Repetir  [F] Salir",
            px + 8, py + 59, panelW - 16, 'center')
        love.graphics.setLineWidth(1)
        love.graphics.setColor(r, g, b, a)
        return
    end
    local trial = ShipsDebugWorld.trial
    if trial then
        local events = trial.events
        love.graphics.setColor(.75, .94, 1, 1)
        love.graphics.printf(string.format("%s  ·  %.1fs  ·  Daño recibido %.1f", trial.title, trial.time, trial.damage), px + 12, py + 10, panelW - 24, "center")
        love.graphics.printf(string.format("Avisos %d | Intentos %d | Disparos %d | Cobertura %d | Esperas %d",
            events.telegraph or 0, events.attempt or 0, events.shot or 0, events.cover or 0, events.squad_wait or 0),
            px + 12, py + 33, panelW - 24, "center")
        love.graphics.printf("[J] Siguiente  |  [K] Repetir  |  [F] Volver al hangar", px + 12, py + 55, panelW - 24, "center")
        love.graphics.setLineWidth(1)
        love.graphics.setColor(r, g, b, a)
        return
    end

    local closestName = ShipsDebugWorld.closestPad and ShipsDebugWorld.closestPad.title or "HANGAR CENTRAL"
    if ShipsDebugWorld.classicArt and not ShipsDebugWorld.liveAIMode then closestName = closestName .. " · Clásico" end
    local rotLabel = ShipsDebugWorld.autoRotate and "ACTIVA" or "PAUSADA"
    local fxLabel = ShipsDebugWorld.showTacticalFX and "VISIBLES" or "OCULTOS"
    local aiLabel = ShipsDebugWorld.liveAIMode and "VUELO IA EN VIVO" or "EXHIBICIÓN / ABORDABLE"

    love.graphics.setColor(0.40, 0.88, 1.0, 1.0)
    love.graphics.printf(
        string.format("HANGAR DE NAVES Y NODRIZAS  ·  Plataforma Cercana: %s  ·  Modo: %s", closestName, aiLabel),
        px + 14, py + 10, panelW - 28, "center"
    )

    love.graphics.setColor(0.88, 0.92, 0.98, 0.95)
    love.graphics.printf(
        "[1-7] Naves Tácticas   |   [8] Excavadora Titán   |   [9] Portanaves Eclipse   |   [0] Arca Monolito",
        px + 14, py + 33, panelW - 28, "center"
    )

    love.graphics.setColor(0.68, 0.82, 0.95, 0.90)
    love.graphics.printf(
        string.format("[R] Rotación (%s) | [T] Enlaces (%s) | [F] Vuelo IA (%s) | [C] Facciones | [J] IA | [L] Armas | [N] Chasis | [V] Arte",
            rotLabel, fxLabel, aiLabel),
        px + 14, py + 55, panelW - 28, "center"
    )

    love.graphics.setLineWidth(1)
    love.graphics.setColor(r, g, b, a)
end

function ShipsDebugWorld.triggerFleetClashDemo()
    ShipsDebugWorld.setLiveAIMode(true)
    local allCombatants = {}
    local factionCycle = { "SIGNAL_VIOLET", "SIGNAL_AMBER", "SIGNAL_CYAN" }

    for idx, pad in ipairs(ShipsDebugWorld.pads) do
        local facId = factionCycle[1 + ((idx - 1) % #factionCycle)]
        if pad.isMothership then
            if pad.shipType == "TITAN_EXCAVATOR" then facId = "SIGNAL_AMBER"
            elseif pad.shipType == "ECLIPSE" then facId = "SIGNAL_VIOLET"
            elseif pad.shipType == "ARK_MONOLITH" then facId = "SIGNAL_CYAN" end
        end

        local ringAngle = ((idx - 1) / #ShipsDebugWorld.pads) * math.pi * 2
        local ringRadius = pad.isMothership and 1050 or 720
        local baseX = math.cos(ringAngle) * ringRadius
        local baseY = 380 + math.sin(ringAngle) * (ringRadius * 0.68)

        if pad.mainShip and not pad.mainShip.isPiloted and not pad.mainShip.isDestroyed then
            pad.mainShip.x = baseX
            pad.mainShip.y = baseY
            pad.mainShip.prevX = baseX
            pad.mainShip.prevY = baseY
            pad.mainShip.aiFaction = facId
            pad.mainShip.isFactionCombatant = true
            table.insert(allCombatants, pad.mainShip)
        end
        for eIdx, ed in ipairs(pad.escortShips or {}) do
            if ed.ship and not ed.ship.isPiloted and not ed.ship.isDestroyed then
                local ex = baseX + (ed.ox or (eIdx * 145))
                local ey = baseY + (ed.oy or 110)
                ed.ship.x = ex
                ed.ship.y = ey
                ed.ship.prevX = ex
                ed.ship.prevY = ey
                ed.ship.aiFaction = facId
                ed.ship.isFactionCombatant = true
                table.insert(allCombatants, ed.ship)
            end
        end
    end

    -- Emparejar cada nave con un rival individual de distinta facción sin fijar lastAttacker
    for i, ship in ipairs(allCombatants) do
        local rival = nil
        for offset = 1, #allCombatants do
            local candidate = allCombatants[1 + ((i + offset - 1) % #allCombatants)]
            if candidate and candidate ~= ship and candidate.aiFaction ~= ship.aiFaction then
                rival = candidate
                break
            end
        end
        if ship.aiController and rival then
            ship.aiController.combatTarget = rival
            ship.aiController.lastAttacker = nil
            ship.aiController.combatMemoryTimer = 28.0
            ship.aiController.state = AIController.STATES.COMBAT
        end
    end
end

function ShipsDebugWorld.keypressed(key, player, camera)
    local weaponTrial = ShipsDebugWorld.weaponTrial
    if key == 'n' then
        local chassis = weaponTrial and weaponTrial.settings.chassis or 0
        return ShipsDebugWorld.startWeaponTrial({weapon = 1, lane = WeaponTrial.duelLane,
            distance = 2, level = 1, chassis = chassis % #WeaponTrial.chassis + 1}, player, camera)
    end
    if weaponTrial then
        local s = weaponTrial.settings
        local duel = s.lane == WeaponTrial.duelLane
        local nextSettings = {weapon = s.weapon, lane = s.lane, distance = s.distance, level = s.level, chassis = s.chassis}
        local slot = tonumber(key)
        if duel and (slot or key == 'h' or key == 'j' or key == 'u') then
            return true
        elseif slot and slot >= 1 and slot <= #WeaponTrial.weapons then
            nextSettings.weapon = slot
        elseif key == 'j' then nextSettings.lane = s.lane % (WeaponTrial.duelLane - 1) + 1
        elseif key == 'u' and s.lane ~= 3 then nextSettings.distance = s.distance % #WeaponTrial.distances + 1
        elseif key == 'h' then nextSettings.level = s.level == 1 and 4 or 1
        elseif key == 'z' then
            if camera then camera:zoomTo(camera.targetZoom < .8 and 1.05 or .55) end
            return true
        elseif key == 'f' or key == 'l' then
            ShipsDebugWorld.init({})
            player.x, player.y, player.prevX, player.prevY = 0, 340, 0, 340
            player.dx, player.dy = 0, 0
            if camera then camera:setPosition(0, 340) end
            return true
        elseif key == 'c' then
            player.weaponSystem:reload()
            return true
        elseif key ~= 'k' then
            return key == 'b' or key == 'tab' or key == 'e' or key == 'f9' or key == 'f10'
        end
        return ShipsDebugWorld.startWeaponTrial(nextSettings, player, camera)
    elseif key == 'l' then
        return ShipsDebugWorld.startWeaponTrial({weapon = 1, lane = 1, distance = 2, level = 1}, player, camera)
    end
    local trial = ShipsDebugWorld.trial
    if key == 'v' and not trial and not ShipsDebugWorld.liveAIMode then
        ShipsDebugWorld.classicArt = not ShipsDebugWorld.classicArt
        return true
    end
    if key == "j" then
        return ShipsDebugWorld.startTrial(trial and trial.index % #TRIALS + 1 or 1, player, camera)
    elseif trial and key == "k" then
        return ShipsDebugWorld.startTrial(trial.index, player, camera)
    elseif trial and key == "f" then
        ShipsDebugWorld.init({})
        return true
    elseif trial then
        return false
    elseif key == "r" then
        ShipsDebugWorld.autoRotate = not ShipsDebugWorld.autoRotate
        return true
    elseif key == "t" then
        ShipsDebugWorld.showTacticalFX = not ShipsDebugWorld.showTacticalFX
        return true
    elseif key == "f" then
        if ShipsDebugWorld.liveAIMode then
            ShipsDebugWorld.init({})
        else
            ShipsDebugWorld.setLiveAIMode(true)
        end
        return true
    elseif key == "c" then
        ShipsDebugWorld.triggerFleetClashDemo()
        return true
    end

    local normalizedKey = tostring(key or ""):gsub("^kp", "")
    for _, pad in ipairs(ShipsDebugWorld.pads) do
        if normalizedKey == pad.key then
            local targetX = pad.x
            local targetY = pad.y + pad.padRadius + 130
            local activeEntity = (player and player.getActiveEntity and player:getActiveEntity()) or player
            if activeEntity then
                activeEntity.x = targetX
                activeEntity.y = targetY
                activeEntity.prevX = targetX
                activeEntity.prevY = targetY
                activeEntity.dx = 0
                activeEntity.dy = 0
                if activeEntity.body and activeEntity.body.setPosition then
                    activeEntity.body:setPosition(targetX, targetY)
                    activeEntity.body:setLinearVelocity(0, 0)
                end
            end
            if player then
                player.x = targetX
                player.y = targetY
                player.prevX = targetX
                player.prevY = targetY
                player.dx = 0
                player.dy = 0
            end
            if camera and camera.setPosition then
                camera:setPosition(pad.x, pad.y)
            end
            return true
        end
    end

    return false
end

return ShipsDebugWorld
