-- src/entities/ai_controller.lua
-- Controlador de IA Ecológica (Ecosistema Vivo Indiferente al Jugador).
-- Cada nave controlada por IA tiene un Rol Ecológico y una Meta de Mundo propia
-- determinada por la Seed, percibiendo a otras naves únicamente a través de su
-- Firma de Emisión Espacial (signatureRadius) y línea de visión.

local AIController = {}
AIController.__index = AIController

local MathUtil = require 'src.utils.math_util'

local function getWorld()
    return package.loaded['src.core.world']
end

-- Roles ecológicos del cosmos
AIController.ROLES = {
    SCAVENGER = "SCAVENGER", -- Recolector / Desmantelador (Pacífico/Defensivo, busca asteroides, pecios e items)
    RAIDER    = "RAIDER",    -- Corsario / Merodeador (Oportunista, caza recolectores y objetivos heridos)
    WARDEN    = "WARDEN",    -- Centinela de Contención (Territorial, custodia ruinas y bordes de fase)
    NOMAD     = "NOMAD"      -- Explorador autónomo (Cruza el sector escaneando anomalías, defensivo)
}

-- Estados de comportamiento (Behavior Priority System)
AIController.STATES = {
    DISABLED   = "DISABLED",   -- Casco crítico / inutilizado (abordable en EVA)
    SURVIVE    = "SURVIVE",    -- Autopreservación (huida hacia cobertura/nebulosa)
    COMBAT     = "COMBAT",     -- Combate táctico contra amenaza u objetivo de caza
    WORLD_GOAL = "WORLD_GOAL", -- Ejecutando tarea propia del mundo (minar, desmantelar, patrullar)
    DRIFT      = "DRIFT"       -- Espera inercial ahorrando combustible
}

-- Configuración por rol
local ROLE_CONFIG = {
    SCAVENGER = {
        label = "Recolector",
        sensorBaseRange = 650,
        fleeHealthRatio = 0.35,
        aggression = 0.15,        -- Solo ataca en defensa propia
        preferredDistance = 260,
        workDuration = 9.0,       -- Segundos extrayendo de un asteroide o pecio
        cruiseSpeedFactor = 0.65,
        beaconColor = {0.95, 0.78, 0.20} -- Ámbar industrial
    },
    RAIDER = {
        label = "Corsario",
        sensorBaseRange = 950,
        fleeHealthRatio = 0.22,
        aggression = 0.85,        -- Caza presas vulnerables o con carga
        preferredDistance = 300,
        workDuration = 4.0,
        cruiseSpeedFactor = 0.85,
        beaconColor = {0.95, 0.22, 0.25} -- Carmesí hostil
    },
    WARDEN = {
        label = "Centinela",
        sensorBaseRange = 850,
        fleeHealthRatio = 0.0,    -- Los autómatas no huyen
        aggression = 0.50,        -- Ataca solo a infractores en su territorio
        territoryRadius = 900,
        preferredDistance = 340,
        workDuration = 6.0,
        cruiseSpeedFactor = 0.70,
        beaconColor = {0.25, 0.88, 1.00} -- Cian de contención antigua
    },
    NOMAD = {
        label = "Nómada",
        sensorBaseRange = 750,
        fleeHealthRatio = 0.30,
        aggression = 0.25,
        preferredDistance = 310,
        workDuration = 5.0,
        cruiseSpeedFactor = 0.75,
        beaconColor = {0.45, 0.92, 0.55} -- Verde exploración
    }
}

function AIController:new(ship, opts)
    opts = opts or {}
    local role = opts.role or AIController.ROLES.SCAVENGER
    local cfg = ROLE_CONFIG[role] or ROLE_CONFIG.SCAVENGER

    local ai = setmetatable({
        ship = ship,
        role = role,
        config = cfg,
        state = AIController.STATES.WORLD_GOAL,
        active = true,

        -- Semilla / RNG determinista local del agente
        rng = opts.rng,
        homeX = opts.homeX or (ship and ship.x) or 0,
        homeY = opts.homeY or (ship and ship.y) or 0,

        -- Objetivo de combate actual
        combatTarget = nil,
        combatMemoryTimer = 0,
        lastAttacker = nil,

        -- Meta del mundo actual (asteroide, pecio, estación o waypoint)
        worldGoal = {
            type = nil,       -- "mine_asteroid" | "salvage_wreck" | "patrol_anchor" | "collect_item" | "travel_waypoint"
            targetX = nil,
            targetY = nil,
            targetEntity = nil,
            timer = 0,
            maxTimer = cfg.workDuration or 8.0,
            isWorking = false -- True cuando está aplicando láser de extracción o escaneo
        },

        -- Temporizadores internos para decisiones suaves (evita jitter y ahorra CPU)
        decisionTimer = (opts.initialDelay or 0),
        decisionInterval = 0.35,
        strafeDir = 1,
        strafeSwitchTimer = 2.5,
        salvageDropTimer = 0
    }, self)

    if ship then
        ship.isAI = true
        ship.isAbandoned = false
        ship.isPiloted = false
        ship.aiRole = role
        ship.aiFaction = opts.faction or role
        ship.shipName = (opts.namePrefix or cfg.label) .. " #" .. tostring(ship.shipId)
        -- Asegurar combustible suficiente para operar en el ecosistema
        if ship.stats and ship.stats.fuel then
            ship.stats.fuel.consumeRate = 0.08 -- Consumo reducido para agentes autónomos
        end
    end

    return ai
end

-- Helper RNG determinista si está disponible
function AIController:random(min, max)
    local r = (self.rng and self.rng.random and self.rng:random()) or math.random()
    if not min then return r end
    if not max then return 1 + math.floor(r * min) end
    return min + r * (max - min)
end

-- Calcula si este agente puede detectar a otra entidad basándose en su Firma de Emisión Espacial
function AIController:canDetectEntity(otherShip)
    if not otherShip or otherShip == self.ship then return false, math.huge end
    if otherShip.isDestroyed then return false, math.huge end

    -- Si la otra nave está en modo EVA, evaluar detección contra el astronauta o contra su nave vacía
    local targetX, targetY = otherShip.x, otherShip.y
    local targetSignature = otherShip.signatureRadius or 300
    if otherShip.isInEVA and otherShip.evaPlayer then
        targetX = otherShip.evaPlayer.x or otherShip.x
        targetY = otherShip.evaPlayer.y or otherShip.y
        targetSignature = otherShip.evaPlayer.signatureRadius or 95
    end

    local dx = targetX - self.ship.x
    local dy = targetY - self.ship.y
    local dist = math.sqrt(dx * dx + dy * dy)

    -- Si nos acaba de disparar, conocemos su vector de ataque temporalmente
    if self.lastAttacker == otherShip and self.combatMemoryTimer > 0 then
        return dist <= (self.config.sensorBaseRange * 1.65), dist
    end

    -- Rango efectivo = promedio ponderado entre nuestro sensor y la Firma de Emisión del objetivo
    local effectiveDetectionRange = (self.config.sensorBaseRange * 0.45) + targetSignature
    return dist <= effectiveDetectionRange, dist
end

-- Evalúa el entorno para encontrar amenazas o presas sin centrarse artificialmente en el jugador
function AIController:evaluatePerception()
    local Naves = package.loaded['src.entities.naves']
    if not Naves or not Naves.getAllShips then return end

    local ships = Naves.getAllShips()
    local bestTarget = nil
    local bestScore = -math.huge

    local myHealthRatio = (self.ship.stats and self.ship.stats:getHealthPercentage() or 100) / 100

    -- Verificar si debemos huir por daño crítico
    if myHealthRatio <= self.config.fleeHealthRatio and self.config.fleeHealthRatio > 0 then
        if self.combatTarget or self.lastAttacker then
            self.state = AIController.STATES.SURVIVE
            return
        end
    end

    for i = 1, #ships do
        local candidate = ships[i]
        if candidate and candidate ~= self.ship and not candidate.isAbandoned then
            local detected, dist = self:canDetectEntity(candidate)
            if detected then
                local score = 0
                local candidateRole = candidate.aiRole or (candidate.isPiloted and "PLAYER" or "UNKNOWN")

                -- 1. Respuesta a quien nos atacó
                if candidate == self.lastAttacker and self.combatMemoryTimer > 0 then
                    score = score + 100
                end

                -- 2. Reglas ecológicas según nuestro Rol
                if self.role == AIController.ROLES.RAIDER then
                    -- Los Corsarios buscan Recolectores cargados o naves heridas/vulnerables
                    local targetHealthPct = (candidate.stats and candidate.stats:getHealthPercentage()) or 100
                    local targetShieldPct = (candidate.stats and candidate.stats:getShieldPercentage()) or 100

                    if candidateRole == AIController.ROLES.SCAVENGER then
                        score = score + 65 -- Presa natural favorita en el ecosistema
                    elseif candidateRole == AIController.ROLES.NOMAD then
                        score = score + 40
                    elseif candidateRole == "PLAYER" then
                        -- Oportunista: ataca al jugador si está herido, sin escudo, muy cerca o haciendo mucho ruido
                        local vulnerability = (100 - targetHealthPct) * 0.5 + (100 - targetShieldPct) * 0.35
                        local proximityBonus = dist < 480 and 35 or 0
                        local noiseBonus = (candidate.signatureRadius or 300) > 650 and 25 or 0
                        score = score + vulnerability + proximityBonus + noiseBonus - 15
                    elseif candidateRole == AIController.ROLES.WARDEN then
                        -- Los Corsarios evitan a los Centinelas salvo que ya estén peleando
                        score = score - 40
                    end

                elseif self.role == AIController.ROLES.WARDEN then
                    -- Los Centinelas custodian su territorio: atacan a Corsarios y a cualquiera que dispare o haga ruido excesivo cerca de su ancla
                    local distFromAnchor = MathUtil.distance(candidate.x, candidate.y, self.homeX, self.homeY)
                    local inTerritory = distFromAnchor <= (self.config.territoryRadius or 900)
                    if inTerritory then
                        if candidateRole == AIController.ROLES.RAIDER then
                            score = score + 75
                        elseif (candidate._signatureShotBoost or 0) > 50 or (candidate.signatureRadius or 0) > 780 then
                            -- Infractor disparando o sobrecargando motores en zona sagrada/borde
                            score = score + 60
                        elseif dist < 240 then
                            -- Violación de perímetro cercano
                            score = score + 35
                        end
                    end

                elseif self.role == AIController.ROLES.SCAVENGER or self.role == AIController.ROLES.NOMAD then
                    -- Pacíficos: solo pelean si fueron agredidos o si un Corsario se lanza encima de ellos
                    if candidate == self.lastAttacker and self.combatMemoryTimer > 0 then
                        score = score + 80
                    elseif candidateRole == AIController.ROLES.RAIDER and dist < 350 and candidate.aiController and candidate.aiController.combatTarget == self.ship then
                        score = score + 55
                    end
                end

                -- Penalización por distancia
                score = score - (dist * 0.03)

                if score > 25 and score > bestScore then
                    bestScore = score
                    bestTarget = candidate
                end
            end
        end
    end

    if bestTarget then
        self.combatTarget = bestTarget
        self.state = AIController.STATES.COMBAT
    else
        if self.combatMemoryTimer <= 0 then
            self.combatTarget = nil
            self.state = AIController.STATES.WORLD_GOAL
        end
    end
end

-- Selecciona una nueva tarea en el mundo (minar asteroide, desmantelar pecio, recoger item o patrullar)
function AIController:pickNewWorldGoal()
    local wg = self.worldGoal
    wg.isWorking = false
    wg.timer = 0
    wg.targetEntity = nil

    local WorldItems = package.loaded['src.item_systems.world_items']
    local Naves = package.loaded['src.entities.naves']
    local Map = package.loaded['src.maps.map']
    local MapConfig = package.loaded['src.maps.config.map_config']

    -- 1. Si es SCAVENGER: buscar primero items sueltos, luego naves abandonadas (¡incluso la del jugador si la dejó sola!), luego asteroides
    if self.role == AIController.ROLES.SCAVENGER then
        if WorldItems and WorldItems.getNearbyItems then
            local items = WorldItems.getNearbyItems(self.ship.x, self.ship.y, 700)
            if items and #items > 0 then
                local entry = items[1]
                local itemObj = entry.item or entry
                if itemObj and itemObj.x and itemObj.y then
                    wg.type = "collect_item"
                    wg.targetX = itemObj.x
                    wg.targetY = itemObj.y
                    wg.targetEntity = itemObj
                    wg.maxTimer = 3.0
                    return
                end
            end
        end

        -- Buscar nave abandonada o sin piloto en las cercanías para desmantelar
        if Naves and Naves.getNearbyShips then
            local nearby = Naves.getNearbyShips(self.ship.x, self.ship.y, 1100)
            for _, entry in ipairs(nearby) do
                local s = entry.ship
                if s and s ~= self.ship and (s.isAbandoned or s.isInEVA) then
                    wg.type = "salvage_wreck"
                    wg.targetX = s.x
                    wg.targetY = s.y
                    wg.targetEntity = s
                    wg.maxTimer = 9.0
                    return
                end
            end
        end

        -- Buscar un asteroide cercano en el chunk actual
        if Map and Map.getChunkNonBlocking and MapConfig then
            local ws = MapConfig.chunk.worldScale or 1.0
            local tileSizeScaled = MapConfig.chunk.tileSize * ws
            local strideScaled = ((MapConfig.chunk.size * MapConfig.chunk.tileSize) + (MapConfig.chunk.spacing or 0)) * ws
            local cx = math.floor(self.ship.x / strideScaled)
            local cy = math.floor(self.ship.y / strideScaled)
            local chunk = Map.getChunkNonBlocking(cx, cy)
            if chunk and chunk.tiles then
                local chunkBaseX = cx * strideScaled
                local chunkBaseY = cy * strideScaled
                for attempt = 1, 14 do
                    local tx = math.floor(self:random(0, MapConfig.chunk.size - 1))
                    local ty = math.floor(self:random(0, MapConfig.chunk.size - 1))
                    local row = chunk.tiles[ty]
                    if row and row[tx] and row[tx] >= MapConfig.ObjectType.ASTEROID_SMALL and row[tx] <= MapConfig.ObjectType.ASTEROID_LARGE then
                        wg.type = "mine_asteroid"
                        wg.targetX = chunkBaseX + tx * tileSizeScaled
                        wg.targetY = chunkBaseY + ty * tileSizeScaled
                        wg.maxTimer = 8.0
                        return
                    end
                end
            end
        end
    end

    -- 2. Si es WARDEN: patrullar en órbita alrededor de su estructura/ancla
    if self.role == AIController.ROLES.WARDEN then
        local angle = self:random(0, math.pi * 2)
        local orbitR = self:random(220, 520)
        wg.type = "patrol_anchor"
        wg.targetX = self.homeX + math.cos(angle) * orbitR
        wg.targetY = self.homeY + math.sin(angle) * orbitR
        wg.maxTimer = 7.0
        return
    end

    -- 3. Por defecto (RAIDER / NOMAD / Fallback): patrullar ruta amplia por el sector
    local angle = self:random(0, math.pi * 2)
    local dist = self:random(450, 1200)
    wg.type = "travel_waypoint"
    wg.targetX = self.homeX + math.cos(angle) * dist
    wg.targetY = self.homeY + math.sin(angle) * dist
    wg.maxTimer = 10.0
end

-- Aplica rotación suave y empuje hacia un punto o vector deseado
function AIController:steerTowards(dt, targetX, targetY, desiredSpeedFactor, keepDistance)
    local ship = self.ship
    local dx = targetX - ship.x
    local dy = targetY - ship.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 0.001 then return dist end

    local dirX = dx / dist
    local dirY = dy / dist

    -- Rotar hacia el objetivo (en el sistema de Naves, rotation = atan2(dy, dx) + pi/2)
    local targetRot = math.atan2(dy, dx) + (math.pi * 2 * 0.25)
    local angleDiff = targetRot - (ship.rotation or 0)
    while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
    while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end

    ship.rotation = (ship.rotation or 0) + angleDiff * (ship.rotationSpeed or 4.5) * dt

    -- Determinar empuje según distancia deseada
    local stopDist = keepDistance or 40
    local accel = (ship.forwardAccel or 12) * (desiredSpeedFactor or 0.75)

    if dist > stopDist then
        ship.dx = (ship.dx or 0) + dirX * accel * dt
        ship.dy = (ship.dy or 0) + dirY * accel * dt
        ship.engineGlow = math.min(1.0, (ship.engineGlow or 0) + dt * 3.0)
        ship._aiIsMoving = true
    elseif dist < stopDist * 0.65 then
        -- Retroceder suavemente si está demasiado pegado
        ship.dx = (ship.dx or 0) - dirX * (accel * 0.5) * dt
        ship.dy = (ship.dy or 0) - dirY * (accel * 0.5) * dt
        ship.engineGlow = math.min(0.6, (ship.engineGlow or 0) + dt * 2.0)
        ship._aiIsMoving = true
    else
        -- Frenado inercial en posición de trabajo
        ship.dx = (ship.dx or 0) * math.pow(0.90, dt * 60)
        ship.dy = (ship.dy or 0) * math.pow(0.90, dt * 60)
        ship.engineGlow = math.max(0, (ship.engineGlow or 0) - dt * 2.5)
        ship._aiIsMoving = false
    end

    return dist
end

-- Ejecución del estado WORLD_GOAL (Agenda propia del ecosistema)
function AIController:updateWorldGoal(dt)
    local wg = self.worldGoal
    if not wg.type or not wg.targetX or not wg.targetY then
        self:pickNewWorldGoal()
        return
    end

    -- Si el objetivo es una entidad móvil o que puede desaparecer, sincronizar coordenadas
    if wg.targetEntity then
        if wg.type == "salvage_wreck" then
            local wreck = wg.targetEntity
            if not wreck.isAbandoned and not wreck.isInEVA then
                -- El dueño regresó a la nave o fue reactivada
                self:pickNewWorldGoal()
                return
            end
            wg.targetX, wg.targetY = wreck.x, wreck.y
        elseif wg.type == "collect_item" then
            local item = wg.targetEntity
            if not item or not item.x then
                self:pickNewWorldGoal()
                return
            end
            wg.targetX, wg.targetY = item.x, item.y
        end
    end

    local stopDist = (wg.type == "mine_asteroid" or wg.type == "salvage_wreck") and 115 or 55
    local dist = self:steerTowards(dt, wg.targetX, wg.targetY, self.config.cruiseSpeedFactor, stopDist)

    if dist <= stopDist + 35 then
        if wg.type == "mine_asteroid" or wg.type == "salvage_wreck" then
            wg.isWorking = true
            wg.timer = wg.timer + dt

            -- Si está desmantelando una nave (incluida la del jugador si la dejó abandonada en EVA), drena un poco de su combustible/casco
            if wg.type == "salvage_wreck" and wg.targetEntity then
                self.salvageDropTimer = self.salvageDropTimer + dt
                if self.salvageDropTimer >= 3.0 then
                    self.salvageDropTimer = 0
                    local wreck = wg.targetEntity
                    if wreck.stats and wreck.stats.fuel and wreck.stats.fuel.currentFuel > 10 then
                        wreck.stats.fuel.currentFuel = math.max(0, wreck.stats.fuel.currentFuel - 15)
                        if self.ship.stats and self.ship.stats.fuel then
                            self.ship.stats:addFuel(15)
                        end
                    end
                    if wreck.addImpactEffect then
                        wreck:addImpactEffect(wreck.x, wreck.y, {1.0, 0.8, 0.2, 1.0})
                    end
                end
            end

            if wg.timer >= wg.maxTimer then
                wg.isWorking = false
                -- Al terminar de minar, el Recolector gana recursos en su propio inventario
                if self.ship.inventory and self.ship.inventory.addItem then
                    local ItemSystem = package.loaded['src.item_systems.item_system']
                    if ItemSystem and ItemSystem.createItemInstance then
                        local dropId = (self:random() < 0.35) and "energy_crystal" or "iron_ore"
                        local inst = ItemSystem:createItemInstance(dropId, 2)
                        if inst then
                            pcall(function() self.ship.inventory:addItem(inst) end)
                        end
                    end
                end
                self:pickNewWorldGoal()
            end
        elseif wg.type == "collect_item" then
            -- Recoger el item flotante del mundo si llega hasta él
            local WorldItems = package.loaded['src.item_systems.world_items']
            if WorldItems and WorldItems.tryPickup and self.ship and self.ship.inventory then
                pcall(function() WorldItems.tryPickup(self.ship.x, self.ship.y, self.ship.inventory, false) end)
            end
            self:pickNewWorldGoal()
        else
            -- Llegó al waypoint de patrulla
            wg.timer = wg.timer + dt
            if wg.timer >= 1.5 then
                self:pickNewWorldGoal()
            end
        end
    else
        wg.isWorking = false
        wg.timer = wg.timer + dt * 0.25
        if wg.timer >= wg.maxTimer * 2.0 then
            -- Timeout por si quedó atascado detrás de asteroides
            self:pickNewWorldGoal()
        end
    end
end

-- Ejecución del estado COMBAT
function AIController:updateCombat(dt)
    self.worldGoal.isWorking = false
    local target = self.combatTarget

    if not target or (target.isAbandoned and not target.isInEVA) then
        self.combatTarget = nil
        self.state = AIController.STATES.WORLD_GOAL
        return
    end

    local targetEntity = (target.getActiveEntity and target:getActiveEntity()) or target
    local tx, ty = targetEntity.x or target.x, targetEntity.y or target.y
    local tvx, tvy = targetEntity.dx or target.dx or 0, targetEntity.dy or target.dy or 0

    local dx = tx - self.ship.x
    local dy = ty - self.ship.y
    local dist = math.sqrt(dx * dx + dy * dy)

    -- Si el objetivo se alejó demasiado y ocultó su firma (por ejemplo, entrando en nebulosa o apagando motores), pierde el rastro
    local detected = self:canDetectEntity(target)
    if not detected and self.combatMemoryTimer <= 0 or dist > 1800 then
        self.combatTarget = nil
        self.state = AIController.STATES.WORLD_GOAL
        return
    end

    -- Maniobra de combate con strafe lateral y distancia óptima
    local prefDist = self.config.preferredDistance or 300
    self:steerTowards(dt, tx, ty, 0.95, prefDist)

    -- Añadir movimiento lateral táctico (strafe) para que el combate sea dinámico
    self.strafeSwitchTimer = self.strafeSwitchTimer - dt
    if self.strafeSwitchTimer <= 0 then
        self.strafeDir = -self.strafeDir
        self.strafeSwitchTimer = self:random(1.8, 3.6)
    end

    if dist < prefDist * 1.4 and dist > 10 then
        local perpX = (-dy / dist) * self.strafeDir
        local perpY = (dx / dist) * self.strafeDir
        local strafeAccel = (self.ship.strafeAccel or 9) * 0.75
        self.ship.dx = (self.ship.dx or 0) + perpX * strafeAccel * dt
        self.ship.dy = (self.ship.dy or 0) + perpY * strafeAccel * dt
    end

    -- Predicción balística ligera para apuntar a objetivos en movimiento
    local leadTime = math.min(0.65, dist / 650)
    local aimX = tx + tvx * leadTime * 12
    local aimY = ty + tvy * leadTime * 12

    -- Disparar si está en rango y encarando aproximadamente al objetivo
    if dist <= 780 then
        local aimAngle = math.atan2(aimY - self.ship.y, aimX - self.ship.x) + (math.pi * 0.5)
        local angleDiff = math.abs(MathUtil.angleDifference and MathUtil.angleDifference(self.ship.rotation, aimAngle) or ((aimAngle - self.ship.rotation) % (math.pi * 2)))
        if angleDiff > math.pi then angleDiff = (math.pi * 2) - angleDiff end

        if angleDiff < 0.48 and self.ship.shootAtWorld then
            -- Pequeña dispersión natural para que sea esquivable por habilidad (AI Design Rule: readable, not aimbot)
            local spread = (self.role == AIController.ROLES.SCAVENGER) and 38 or 22
            local shotX = aimX + (self:random() - 0.5) * spread
            local shotY = aimY + (self:random() - 0.5) * spread
            self.ship:shootAtWorld(shotX, shotY)
        end
    end
end

-- Ejecución del estado SURVIVE (Huida táctica)
function AIController:updateSurvive(dt)
    self.worldGoal.isWorking = false
    local threat = self.lastAttacker or self.combatTarget
    if not threat or not threat.x then
        self.state = AIController.STATES.WORLD_GOAL
        return
    end

    local dx = self.ship.x - threat.x
    local dy = self.ship.y - threat.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 1400 then
        -- Logró escapar de la amenaza
        self.combatTarget = nil
        self.lastAttacker = nil
        self.state = AIController.STATES.WORLD_GOAL
        return
    end

    local fleeX = self.ship.x + (dx / math.max(1, dist)) * 600
    local fleeY = self.ship.y + (dy / math.max(1, dist)) * 600

    self.ship.isBoostActive = true
    self:steerTowards(dt, fleeX, fleeY, 1.25, 0)
end

-- Ciclo principal de actualización de la IA (llamado desde Naves:update)
function AIController:update(dt)
    if not self.active or not self.ship then return end
    if self.state == AIController.STATES.DISABLED or self.ship.isAbandoned then return end

    if self.combatMemoryTimer > 0 then
        self.combatMemoryTimer = math.max(0, self.combatMemoryTimer - dt)
    end

    self.decisionTimer = self.decisionTimer - dt
    if self.decisionTimer <= 0 then
        self.decisionTimer = self.decisionInterval
        self:evaluatePerception()
    end

    self.ship.isBoostActive = false
    self.ship._aiIsMoving = false

    if self.state == AIController.STATES.SURVIVE then
        self:updateSurvive(dt)
    elseif self.state == AIController.STATES.COMBAT then
        self:updateCombat(dt)
    else
        self:updateWorldGoal(dt)
    end

    -- Limitar velocidad máxima según capacidades de la nave
    local maxSpd = self.ship.maxSpeed or 80
    if self.ship.isBoostActive then
        maxSpd = maxSpd * (self.ship.boostMultiplier or 1.5)
    end
    local spd = math.sqrt((self.ship.dx or 0)^2 + (self.ship.dy or 0)^2)
    if spd > maxSpd and spd > 0 then
        self.ship.dx = (self.ship.dx / spd) * maxSpd
        self.ship.dy = (self.ship.dy / spd) * maxSpd
    end

    -- Aplicar fricción espacial suave
    local dragFactor = math.pow(self.ship.drag or 0.94, dt * 60)
    self.ship.dx = (self.ship.dx or 0) * dragFactor
    self.ship.dy = (self.ship.dy or 0) * dragFactor

    -- Avanzar posición física y colisiones contra asteroides
    self.ship.x = self.ship.x + (self.ship.dx or 0) * dt * 60
    self.ship.y = self.ship.y + (self.ship.dy or 0) * dt * 60

    if self.ship.resolveAsteroidCollisions then
        self.ship:resolveAsteroidCollisions(dt)
    end

    if self.ship.weaponSystem and self.ship.weaponSystem.update then
        self.ship.weaponSystem:update(dt)
    end

    if self.ship.stats and self.ship.stats.update then
        self.ship.stats:update(dt, self.ship._aiIsMoving)
    end

    if self.ship.updateProjectiles then
        self.ship:updateProjectiles(dt)
    end
end

-- Callback cuando la nave recibe daño de cualquier fuente (jugador, otro NPC o asteroide)
function AIController:onDamaged(damage, attacker)
    if not self.active or self.state == AIController.STATES.DISABLED then return end

    if attacker and attacker ~= self.ship then
        self.lastAttacker = attacker
        self.combatTarget = attacker
        self.combatMemoryTimer = 10.0

        local hpPct = (self.ship.stats and self.ship.stats:getHealthPercentage()) or 100
        if hpPct <= (self.config.fleeHealthRatio * 100) and self.config.fleeHealthRatio > 0 then
            self.state = AIController.STATES.SURVIVE
        else
            self.state = AIController.STATES.COMBAT
        end
    end
end

-- Callback cuando el casco de la nave llega a 0: se convierte en un pecio abordable y suelta botín físico
function AIController:onDisabled(attacker)
    if self.state == AIController.STATES.DISABLED then return end

    self.state = AIController.STATES.DISABLED
    self.active = false
    self.worldGoal.isWorking = false

    local ship = self.ship
    if not ship then return end

    ship.isAI = false
    ship.isAbandoned = true
    ship.isPiloted = false
    ship.engineGlow = 0
    ship.driftAngularSpeed = (self:random() - 0.5) * 0.12

    -- Dejar 1 punto de casco residual para que si el jugador decide abordarla en EVA pueda repararla o pilotarla en emergencia
    if ship.stats and ship.stats.health then
        ship.stats.health.currentHealth = math.max(2, math.floor(ship.stats.health.maxHealth * 0.15))
    end

    -- Soltar parte de sus suministros (Fuel / Materiales / Baterías de Escudo) al espacio exterior
    local WorldItems = package.loaded['src.item_systems.world_items']
    local ItemSystem = package.loaded['src.item_systems.item_system']
    if WorldItems and WorldItems.drop and ItemSystem and ItemSystem.getItem then
        local dropTable = { "iron_ore", "energy_crystal", "shield_battery", "health_potion" }
        local numDrops = (self.role == AIController.ROLES.SCAVENGER) and 3 or 2
        for i = 1, numDrops do
            local itemId = dropTable[1 + ((i + ship.shipId) % #dropTable)]
            local itemData = ItemSystem:getItem(itemId)
            if itemData then
                local angle = (i / numDrops) * math.pi * 2 + self:random(-0.3, 0.3)
                local tx = ship.x + math.cos(angle) * 45
                local ty = ship.y + math.sin(angle) * 45
                pcall(function() WorldItems.drop(itemData, ship.x, ship.y, tx, ty, 1) end)
            end
        end
    end

    if ship.addImpactEffect then
        ship:addImpactEffect(ship.x, ship.y, {1.0, 0.45, 0.15, 1.0})
    end

    print(string.format("[ECOSYSTEM] %s (%s) quedó inutilizada en (%.0f, %.0f) y ahora es abordable/saqueable.",
        ship.shipName or "Nave", self.role, ship.x, ship.y))
end

return AIController
