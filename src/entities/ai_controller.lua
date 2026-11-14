local CombatSight = require 'src.entities.combat_sight'
local Loot = require 'src.gameplay.loot'
-- src/entities/ai_controller.lua
-- Controlador de IA Táctica y Ecológica v3 (Pilotaje Inercial Orgánico, Esquiva Reactiva y Estados de Tensión).
-- Incluye:
--   1. Física de Pilotaje Real: Inercia angular (spring-damper), propulsión alineada con proa, propulsores laterales RCS
--      y Derrape Inercial (Drift) para girar el morro a alta velocidad manteniendo el vector de inercia.
--   2. Esquiva Reactiva (Micro-Dodging): Detección de proyectiles entrantes y línea de mira enemiga para ejecutar
--      impulsos laterales evasivos (jukes) y buscar cobertura tras asteroides.
--   3. Disciplina de Ráfagas y Seguimiento con Tiempo de Reacción: Disparo en ventanas intencionales (no metrónomo)
--      y predicción balística con inercia sensorial (esquivable mediante cambios bruscos de dirección/Drift).
--   4. Estados Contextuales no Binarios (ALERT):
--      - Advertencia Territorial (WARDEN / NOMAD encaran y avisan antes de abrir fuego).
--      - Acecho / Emboscada por Punto Ciego (RAIDER se aproxima por la cola antes de lanzarse al ataque).
--      - Señuelo de Pánico (SCAVENGER suelta carga para distraer a su cazador al huir).
--   5. Resolución de Muerte por % Determinista: ~78% Destrucción Total vs ~22% Nave Intacta pero Inmóvil.

local AIController = {}
AIController.__index = AIController

local MathUtil = require 'src.utils.math_util'

-- Roles ecológicos del cosmos
AIController.ROLES = {
    SCAVENGER = "SCAVENGER", -- Recolector / Desmantelador (Pacífico/Defensivo, busca asteroides, pecios e items)
    RAIDER    = "RAIDER",    -- Corsario / Merodeador (Oportunista, acecha y caza recolectores y objetivos vulnerables)
    WARDEN    = "WARDEN",    -- Centinela de Contención (Territorial, advierte a intrusos y custodia ruinas)
    NOMAD     = "NOMAD"      -- Explorador autónomo (Cruza el sector escaneando anomalías, cauteloso y defensivo)
}

-- Estados principales de comportamiento
AIController.STATES = {
    DISABLED   = "DISABLED",   -- Nave intacta pero inmovilizada (~22% al morir, abordable en EVA)
    DESTROYED  = "DESTROYED",  -- Nave destruida por completo (~78% al morir)
    SURVIVE    = "SURVIVE",    -- Autopreservación (huida con cobertura de asteroides y señuelo)
    COMBAT     = "COMBAT",     -- Combate táctico con derrape inercial, esquiva de proyectiles y ráfagas
    ALERT      = "ALERT",      -- Estado intermedio: Advertencia territorial (WARDEN/NOMAD) o Acecho (RAIDER)
    WORLD_GOAL = "WORLD_GOAL", -- Ejecutando tarea propia del mundo (minar, desmantelar, patrullar, escoltar)
    DRIFT      = "DRIFT"       -- Espera inercial
}

-- Configuración por rol ecológico
local ROLE_CONFIG = {
    SCAVENGER = {
        label = "Recolector",
        sensorBaseRange = 680,
        fovCos = -0.25,
        fleeHealthRatio = 0.40,
        aggression = 0.15,
        preferredDistance = 260,
        workDuration = 8.5,
        cruiseSpeedFactor = 0.72,
        intactChance = 0.25,
        burstMin = 2,
        burstMax = 4,
        burstPauseMin = 0.65,
        burstPauseMax = 1.15,
        dodgeSkill = 0.55,
        beaconColor = {0.95, 0.78, 0.20}
    },
    RAIDER = {
        label = "Corsario",
        sensorBaseRange = 900,
        fovCos = -0.35,
        fleeHealthRatio = 0.20,
        aggression = 0.85,
        preferredDistance = 290,
        workDuration = 4.0,
        cruiseSpeedFactor = 0.88,
        intactChance = 0.22,
        burstMin = 3,
        burstMax = 6,
        burstPauseMin = 0.38,
        burstPauseMax = 0.75,
        dodgeSkill = 0.85,
        beaconColor = {0.95, 0.22, 0.25}
    },
    WARDEN = {
        label = "Centinela",
        sensorBaseRange = 860,
        fovCos = -0.60,
        fleeHealthRatio = 0.0,
        aggression = 0.55,
        territoryRadius = 900,
        preferredDistance = 350,
        workDuration = 6.0,
        cruiseSpeedFactor = 0.76,
        intactChance = 0.0,
        burstMin = 2,
        burstMax = 4,
        burstPauseMin = 0.45,
        burstPauseMax = 0.80,
        dodgeSkill = 0.75,
        beaconColor = {0.25, 0.88, 1.00}
    },
    NOMAD = {
        label = "Nómada",
        sensorBaseRange = 760,
        fovCos = -0.30,
        fleeHealthRatio = 0.30,
        aggression = 0.25,
        preferredDistance = 310,
        workDuration = 5.0,
        cruiseSpeedFactor = 0.80,
        intactChance = 0.22,
        burstMin = 3,
        burstMax = 5,
        burstPauseMin = 0.45,
        burstPauseMax = 0.85,
        dodgeSkill = 0.70,
        beaconColor = {0.45, 0.92, 0.55}
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
        lootProfile = opts.lootProfile or Loot.enemyProfile(ship),
        state = AIController.STATES.WORLD_GOAL,
        active = true,

        -- RNG determinista local del agente
        rng = opts.rng,
        trace = opts.trace,
        homeX = opts.homeX or (ship and ship.x) or 0,
        homeY = opts.homeY or (ship and ship.y) or 0,

        -- Rasgos individuales de personalidad del piloto (generados por Seed para que dos naves iguales nunca sean idénticas)
        pilotPersonality = {
            aggressiveness = 0.85,
            preferredOrbitSide = 1,
            aimWanderSpeed = 2.3,
            aimWanderPhase = 0,
            reactionSpeed = 5.5
        },

        -- Física de rotación con inercia angular real
        angVel = 0,
        rcsThrustDir = 0, -- -1 (izquierda), 0, +1 (derecha) para efectos visuales RCS

        -- Coordinación de escuadrón (Wingman / Escolta / Nodriza)
        wingmanOf = opts.wingmanOf or nil,
        formationOffsetX = opts.formationOffsetX or -95,
        formationOffsetY = opts.formationOffsetY or 75,
        formationSlotIndex = opts.formationSlotIndex or 1,
        escorts = opts.escorts or {},
        isReceivingCarrierShield = false,
        hangarReserve = (ship and ship.shipConfig and ship.shipConfig.hangarReserve) or 0,
        hangarCooldown = 5.0,
        hangarFlashTimer = 0,
        warpInTimer = opts.warpInTimer or 0,

        -- Estado de alerta / acecho (ALERT)
        alertTarget = nil,
        alertMode = nil,       -- "WARN" (Centinela/Nómada) | "STALK" (Corsario)
        alertTimer = 0,
        alertMaxTimer = 2.4,

        -- Estado de combate táctico
        combatTarget = nil,
        combatMemoryTimer = 0,
        satiatedTimer = 0,     -- Enfriamiento tras abatir una presa (recolecta el botín en vez de atacar al jugador inmediatamente)
        lastAttacker = nil,
        tacticalPhase = "ENGAGE", -- "ENGAGE" | "PASS_AWAY" | "DRIFT_TURN" | "COVER_SEEK"
        tacticalTimer = 0,

        -- Memoria sensorial con tiempo de reacción humano (evita aimbot instantáneo)
        trackedTargetVx = 0,
        trackedTargetVy = 0,

        -- Esquiva reactiva de proyectiles (Micro-Dodging)
        jukeTimer = 0,
        jukeDirX = 0,
        jukeDirY = 0,
        dodgeCooldown = 0,
        underCrosshairTimer = 0,

        -- Disciplina de disparo por ráfagas (no metrónomo)
        burstShotsLeft = 4,
        burstPauseTimer = 0,
        lastObservedShotTime = 0,

        -- Señuelo de emergencia (SCAVENGER)
        panicJettisoned = false,

        -- Telegrafía de ataque pesado (GUNSHIP / SENTINEL)
        telegraphTimer = 0,
        telegraphDuration = 0.55,
        telegraphAimX = nil,
        telegraphAimY = nil,
        heavyBurstCooldown = 0,

        -- Meta del mundo actual
        worldGoal = {
            type = nil,
            targetX = nil,
            targetY = nil,
            targetEntity = nil,
            timer = 0,
            maxTimer = cfg.workDuration or 8.0,
            isWorking = false
        },

        -- Temporizadores internos
        decisionTimer = (opts.initialDelay or 0),
        decisionInterval = 0.25,
        strafeDir = (opts.wingmanOf and -1) or 1,
        strafeSwitchTimer = 2.0,
        salvageDropTimer = 0,

        -- Ciclo ecológico de botín (Carroñero oportunista post-batalla)
        scavengedLoot = {},
        salvageScheduleTimer = 0,
        salvageSiteTarget = nil,
        isTractorBeaming = false,
        tractorTargetX = nil,
        tractorTargetY = nil
    }, self)

    -- Inicializar personalidad única del piloto usando el RNG determinista
    ai.pilotPersonality.aggressiveness = ai:random(0.75, 1.25)
    ai.pilotPersonality.preferredOrbitSide = (ai:random() < 0.5) and -1 or 1
    ai.pilotPersonality.aimWanderSpeed = ai:random(1.7, 3.4)
    ai.pilotPersonality.aimWanderPhase = ai:random(0, math.pi * 2)
    ai.pilotPersonality.reactionSpeed = ai:random(4.2, 7.5)
    ai.strafeDir = opts.wingmanOf and (ai.formationSlotIndex % 2 == 0 and -1 or 1)
        or ai.pilotPersonality.preferredOrbitSide
    ai.burstShotsLeft = math.floor(ai:random(cfg.burstMin or 3, (cfg.burstMax or 5) + 0.9))

    if ship then
        ship.isAI = true
        ship.isAbandoned = false
        ship.isImmobilized = false
        ship.isPiloted = false
        ship.aiRole = role
        ship.aiFaction = opts.faction or role
        ship.shipName = (opts.namePrefix or cfg.label) .. " #" .. tostring(ship.shipId)
        if ship.stats and ship.stats.fuel then
            ship.stats.fuel.consumeRate = 0.06
        end
    end

    return ai
end

-- RNG determinista
function AIController:random(min, max)
    local r = (self.rng and self.rng.random and self.rng:random()) or math.random()
    if not min then return r end
    if not max then return 1 + math.floor(r * min) end
    return min + r * (max - min)
end

-- Comprueba si hay línea de visión despejada entre la nave IA y (tx, ty)
function AIController:hasLineOfSight(tx, ty)
    return CombatSight.clear(self.ship, tx, ty)
end

function AIController:recordCombat(event, target)
    if self.trace then self.trace(self, event, target) end
end

function AIController:reserveAttack(target)
    if (self.attackRest or 0) > 0 then return false end
    if self.attackTarget == target and (self.attackLease or 0) > 0 then return true end
    local Naves = package.loaded['src.entities.naves']
    local faction = self.ship.aiFaction
    for _, ally in ipairs(Naves and Naves.getAllShips() or {}) do
        local ai = ally.aiController
        if ally ~= self.ship and faction and ally.aiFaction == faction
            and ally.combatContext == self.ship.combatContext and not ally.isAbandoned and not ally.isDestroyed
            and ai and ai.active and ai.state == AIController.STATES.COMBAT
            and ai.combatTarget == target and ai.attackTarget == target and (ai.attackLease or 0) > 0 then
            self:recordCombat('squad_wait', target)
            return false
        end
    end
    self.attackLease, self.attackTarget = 1.25, target
    return true
end

function AIController:finishAttack(gap)
    self.attackLease = gap or 0
    self.attackRest = (gap or 0) + .5
end

function AIController:fireCombatShot(target, cue, x, y)
    local ship = self.ship
    local ws = ship.weaponSystem
    if not ship.shootAtWorld or (ws and ws.canShoot and not ws:canShoot()) then return false end
    self:recordCombat('attempt', target)
    if not self:hasLineOfSight(cue.x, cue.y)
        or ((x ~= cue.x or y ~= cue.y) and not self:hasLineOfSight(x, y)) then
        self:recordCombat('cover', target)
        return false
    end
    local Naves = package.loaded['src.entities.naves']
    for _, ally in ipairs(Naves and Naves.getAllShips() or {}) do
        if ally ~= ship and ally ~= target and ship.aiFaction and ally.aiFaction == ship.aiFaction
            and ally.combatContext == ship.combatContext and not ally.isAbandoned and not ally.isDestroyed
            and CombatSight.intersects(ship.x, ship.y, x, y, ally.x, ally.y, math.max(15, (ally.size or 14) * 1.15)) then
            self:recordCombat('friendly_lane', target)
            return false
        end
    end
    if not self:reserveAttack(target) then return false end
    if ship:shootAtWorld(x, y) then
        self:recordCombat('shot', target)
        return true
    end
    return false
end

function AIController:updateTelegraph(dt, target, cue, aimX, aimY, dist, range, duration, cooldown, cone)
    self.heavyBurstCooldown = math.max(0, (self.heavyBurstCooldown or 0) - dt)
    if self.telegraphTimer > 0 then
        self.telegraphTimer = self.telegraphTimer - dt
        -- Freeze the firing line during the last 0.18 s so the warning can be dodged.
        if self.telegraphTimer > .18 then
            self.telegraphAimX = MathUtil.lerp(self.telegraphAimX, aimX, math.min(1, dt * 3))
            self.telegraphAimY = MathUtil.lerp(self.telegraphAimY, aimY, math.min(1, dt * 3))
        end
        if self.telegraphTimer <= 0 then
            local fired = dist <= range and self:fireCombatShot(target, cue, self.telegraphAimX, self.telegraphAimY)
            self.heavyBurstCooldown = fired and cooldown or .25
            self:finishAttack(fired and .24 or 0)
        end
        return
    end
    if dist > range or self.heavyBurstCooldown > 0 then return end
    local ship = self.ship
    local angle = math.atan2(aimY - ship.y, aimX - ship.x) + math.pi * .5
    local delta = math.abs((angle - ship.rotation + math.pi) % (2 * math.pi) - math.pi)
    local ws = ship.weaponSystem
    if delta < cone and (not ws or not ws.canShoot or ws:canShoot())
        and self:hasLineOfSight(aimX, aimY) and self:reserveAttack(target) then
        self.telegraphDuration, self.telegraphTimer = duration, duration
        self.telegraphAimX, self.telegraphAimY = aimX, aimY
        self:recordCombat('telegraph', target)
    end
end

-- Percepción Física y Contextual
function AIController:canDetectEntity(otherShip)
    if not otherShip or otherShip == self.ship then return false, math.huge end
    if otherShip.isDestroyed or otherShip.combatContext ~= self.ship.combatContext then return false, math.huge end

    local targetX, targetY = otherShip.x, otherShip.y
    local isEVATarget = false
    if otherShip.isInEVA and otherShip.evaPlayer then
        targetX = otherShip.evaPlayer.x or otherShip.x
        targetY = otherShip.evaPlayer.y or otherShip.y
        isEVATarget = true
    end

    local dx = targetX - self.ship.x
    local dy = targetY - self.ship.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if self.lastAttacker == otherShip and self.combatMemoryTimer > 0 then
        return dist <= math.max(1650, (self.config.sensorBaseRange or 750) * 2.1), dist
    end
    if self.combatTarget == otherShip and self.combatMemoryTimer > 0 then
        return dist <= 2450, dist
    end

    local maxRange = self.config.sensorBaseRange or 750
    if isEVATarget then
        maxRange = maxRange * 0.55
    end

    local BiomeSystem = package.loaded['src.maps.biome_system']
    local MapConfig = package.loaded['src.maps.config.map_config']
    if BiomeSystem and BiomeSystem.getBiomeForChunk and MapConfig then
        local ws = (MapConfig.chunk and MapConfig.chunk.worldScale) or 2.0
        local stride = ((MapConfig.chunk.size * MapConfig.chunk.tileSize) + (MapConfig.chunk.spacing or 0)) * ws
        local cx = math.floor(targetX / stride)
        local cy = math.floor(targetY / stride)
        local ok, bType = pcall(BiomeSystem.getBiomeForChunk, cx, cy)
        if ok and BiomeSystem.BiomeType and bType == BiomeSystem.BiomeType.NEBULA then
            maxRange = maxRange * 0.60
        end
    end

    local now = love.timer and love.timer.getTime and love.timer.getTime() or 0
    local firedRecently = (now - (otherShip._lastShotTimestamp or -999)) < 2.5
    local isFlaring = firedRecently or otherShip.isBoostActive
    if isFlaring then
        maxRange = maxRange * 1.22
    end

    if dist > maxRange then
        return false, dist
    end

    if dist > 240 and not isFlaring then
        local lookX = math.sin(self.ship.rotation or 0)
        local lookY = -math.cos(self.ship.rotation or 0)
        local toTargetX = dx / math.max(1, dist)
        local toTargetY = dy / math.max(1, dist)
        local dot = lookX * toTargetX + lookY * toTargetY
        if dot < (self.config.fovCos or -0.3) then
            return false, dist
        end
    end

    if not self:hasLineOfSight(targetX, targetY) then
        return false, dist
    end

    return true, dist
end

-- Calcula un vector de repulsión contra asteroides cercanos y objetos especiales
function AIController:computeObstacleAvoidance()
    local ship = self.ship
    local avoidX, avoidY = 0, 0
    local Map = package.loaded['src.maps.map']
    local MapConfig = package.loaded['src.maps.config.map_config']
    if not ship.combatContext and Map and Map.getChunkNonBlocking and MapConfig then
        local ws = (MapConfig.chunk and MapConfig.chunk.worldScale) or 2.0
        local tileSizeScaled = (MapConfig.chunk.tileSize or 32) * ws
        local chunkSize = MapConfig.chunk.size or 64
        local strideScaled = ((chunkSize * (MapConfig.chunk.tileSize or 32)) + (MapConfig.chunk.spacing or 0)) * ws

        local lookAheadX = ship.x + (ship.dx or 0) * 16
        local lookAheadY = ship.y + (ship.dy or 0) * 16

        local cx = math.floor(lookAheadX / strideScaled)
        local cy = math.floor(lookAheadY / strideScaled)
        local chunk = Map.getChunkNonBlocking(cx, cy)
        if chunk then
            local chunkBaseX = cx * strideScaled
            local chunkBaseY = cy * strideScaled

            if chunk.tiles then
                local centerTileX = math.floor((lookAheadX - chunkBaseX) / tileSizeScaled)
                local centerTileY = math.floor((lookAheadY - chunkBaseY) / tileSizeScaled)
                local clearance = (ship.size or 16) * ws + tileSizeScaled * 1.05

                for ty = centerTileY - 2, centerTileY + 2 do
                    local row = chunk.tiles[ty]
                    if row then
                        for tx = centerTileX - 2, centerTileX + 2 do
                            local cell = row[tx]
                            if cell and cell >= MapConfig.ObjectType.ASTEROID_SMALL and cell <= MapConfig.ObjectType.ASTEROID_LARGE then
                                local astX = chunkBaseX + tx * tileSizeScaled
                                local astY = chunkBaseY + ty * tileSizeScaled
                                local rx = lookAheadX - astX
                                local ry = lookAheadY - astY
                                local d = math.sqrt(rx * rx + ry * ry)
                                if d < clearance and d > 0.01 then
                                    local weight = (clearance - d) / clearance
                                    avoidX = avoidX + (rx / d) * weight * 2.1
                                    avoidY = avoidY + (ry / d) * weight * 2.1
                                end
                            end
                        end
                    end
                end
            end

            if chunk.specialObjects then
                for i = 1, #chunk.specialObjects do
                    local obj = chunk.specialObjects[i]
                    if obj and obj.x and obj.y then
                        local ox = chunkBaseX + obj.x * ws
                        local oy = chunkBaseY + obj.y * ws
                        local objRadius = ((obj.radius or obj.size or 75) * ws) + (ship.size or 16) * 2.5
                        local rx = lookAheadX - ox
                        local ry = lookAheadY - oy
                        local d = math.sqrt(rx * rx + ry * ry)
                        if d < objRadius and d > 0.01 then
                            local weight = (objRadius - d) / objRadius
                            avoidX = avoidX + (rx / d) * weight * 2.8
                            avoidY = avoidY + (ry / d) * weight * 2.8
                        end
                    end
                end
            end
        end
    end

    -- Separación táctica entre naves para que las batallas grandes sean amplias y legibles (evita amontonamiento)
    local Naves = package.loaded['src.entities.naves']
    if Naves and Naves.getAllShips then
        local all = Naves.getAllShips()
        local minSep = ((ship.size or 16) + 155)
        for i = 1, #all do
            local other = all[i]
            if other and other ~= ship and other.combatContext == ship.combatContext and not other.isDestroyed and not other.isAbandoned then
                local sx = ship.x - (other.x or 0)
                local sy = ship.y - (other.y or 0)
                local sdSq = sx * sx + sy * sy
                local pairSep = minSep + (other.size or 16) * 1.4
                if sdSq < (pairSep * pairSep) and sdSq > 1 then
                    local sd = math.sqrt(sdSq)
                    local push = ((pairSep - sd) / pairSep) * 1.65
                    avoidX = avoidX + (sx / sd) * push
                    avoidY = avoidY + (sy / sd) * push
                end
            end
        end
    end

    return avoidX, avoidY
end

-- Detecta proyectiles entrantes o si el enemigo nos tiene directamente en su línea de mira para ejecutar una esquiva reactiva (Juke)
function AIController:evaluateIncomingThreats(dt, enemyShip, canReadAim)
    if self.dodgeCooldown > 0 then
        self.dodgeCooldown = math.max(0, self.dodgeCooldown - dt)
    end
    if self.jukeTimer > 0 then
        self.jukeTimer = math.max(0, self.jukeTimer - dt)
        return
    end
    if not enemyShip or self.dodgeCooldown > 0 then return end

    local ship = self.ship
    local dodgeSkill = self.config.dodgeSkill or 0.7

    -- 1. Escanear proyectiles activos disparados por el enemigo
    local projs = enemyShip.projectiles
    if projs and #projs > 0 then
        for i = 1, #projs do
            local p = projs[i]
            if p and not p.destroyed and p.x and p.y and p.vx and p.vy then
                local toShipX = ship.x - p.x
                local toShipY = ship.y - p.y
                local distSq = toShipX * toShipX + toShipY * toShipY
                if distSq < (340 * 340) and distSq > 4 then
                    local pSpeed = math.sqrt(p.vx * p.vx + p.vy * p.vy)
                    if pSpeed > 1 then
                        local pDirX = p.vx / pSpeed
                        local pDirY = p.vy / pSpeed
                        local projDist = math.sqrt(distSq)
                        local dot = (toShipX / projDist) * pDirX + (toShipY / projDist) * pDirY
                        -- Si el proyectil viene hacia nosotros
                        if dot > 0.78 then
                            -- Distancia perpendicular de paso (miss distance)
                            local cross = toShipX * pDirY - toShipY * pDirX
                            local hitThreshold = (ship.size or 16) * 2.8
                            if math.abs(cross) < hitThreshold and self:random() < dodgeSkill then
                                -- Esquivar perpendicularmente hacia el lado que nos aleja de la trayectoria del proyectil
                                local side = (cross >= 0) and 1 or -1
                                self.jukeDirX = -pDirY * side
                                self.jukeDirY = pDirX * side
                                self.jukeTimer = self:random(0.22, 0.34)
                                self.dodgeCooldown = self:random(0.75, 1.35)
                                self.strafeDir = side
                                self.rcsThrustDir = side
                                return
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. Conciencia de línea de mira ("Crosshair Awareness"): si el enemigo nos apunta fijamente durante > 0.7s, romper el ritmo
    if canReadAim ~= false and enemyShip.rotation and enemyShip.x and enemyShip.y then
        local enemyLookX = math.sin(enemyShip.rotation)
        local enemyLookY = -math.cos(enemyShip.rotation)
        local dx = ship.x - enemyShip.x
        local dy = ship.y - enemyShip.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < 600 and dist > 1 then
            local dot = (dx / dist) * enemyLookX + (dy / dist) * enemyLookY
            if dot > 0.94 then
                self.underCrosshairTimer = self.underCrosshairTimer + dt
                if self.underCrosshairTimer > 0.65 then
                    self.underCrosshairTimer = 0
                    self.strafeDir = -self.strafeDir
                    self.jukeDirX = -enemyLookY * self.strafeDir
                    self.jukeDirY = enemyLookX * self.strafeDir
                    self.jukeTimer = 0.24
                    self.dodgeCooldown = 1.1
                    self.rcsThrustDir = self.strafeDir
                end
            else
                self.underCrosshairTimer = math.max(0, self.underCrosshairTimer - dt * 2)
            end
        end
    end
end

-- Evalúa el entorno para encontrar amenazas, objetivos de acecho o intrusos territoriales
function AIController:evaluatePerception()
    local Naves = package.loaded['src.entities.naves']
    if not Naves or not Naves.getAllShips then return end

    local myHealthRatio = (self.ship.stats and self.ship.stats:getHealthPercentage() or 100) / 100
    if myHealthRatio <= self.config.fleeHealthRatio and self.config.fleeHealthRatio > 0 then
        if self.combatTarget or self.lastAttacker then
            self.state = AIController.STATES.SURVIVE
            return
        end
    end

    -- Si ya estamos en estado ALERT, su transición se maneja en updateAlert
    if self.state == AIController.STATES.ALERT and self.alertTarget and not self.alertTarget.isDestroyed then
        if self.lastAttacker then
            self.combatTarget = self.lastAttacker
            self.state = AIController.STATES.COMBAT
        end
        return
    end

    local ships = Naves.getAllShips()
    local bestTarget = nil
    local bestScore = -math.huge
    local bestDist = math.huge
    local now = love.timer and love.timer.getTime and love.timer.getTime() or 0

    -- Pre-chequeo: saber si hay naves IA de otra facción cerca para que las flotas no hagan focus grupal artificial al jugador
    local hasRivalAIInSector = false
    for i = 1, #ships do
        local c = ships[i]
        if c and c ~= self.ship and c.combatContext == self.ship.combatContext and not c.isPiloted and not c.isAbandoned and not c.isDestroyed then
            if c.aiFaction ~= self.ship.aiFaction then
                local dx = (c.x or 0) - self.ship.x
                local dy = (c.y or 0) - self.ship.y
                if (dx * dx + dy * dy) <= (1450 * 1450) then
                    hasRivalAIInSector = true
                    break
                end
            end
        end
    end

    -- Si somos escolta sin objetivo propio y el líder combate contra otra nave IA (no hacer focus de colmena al jugador), asistirlo
    if (not self.combatTarget or self.combatTarget.isDestroyed or self.combatTarget.isAbandoned)
       and self.wingmanOf and not self.wingmanOf.isDestroyed and not self.wingmanOf.isAbandoned then
        local leaderAI = self.wingmanOf.aiController
        if leaderAI and leaderAI.state == AIController.STATES.COMBAT and leaderAI.combatTarget then
            if not leaderAI.combatTarget.isPiloted or not hasRivalAIInSector then
                self.combatTarget = leaderAI.combatTarget
                self.state = AIController.STATES.COMBAT
                return
            end
        end
    end

    for i = 1, #ships do
        local candidate = ships[i]
        if candidate and candidate ~= self.ship and (not candidate.isAbandoned or candidate.isPiloted) and not candidate.isDestroyed then
            if candidate.aiFaction == self.ship.aiFaction and candidate ~= self.lastAttacker and candidate ~= self.combatTarget then
                -- Ignorar aliado de la misma facción
            else
                local detected, dist = self:canDetectEntity(candidate)
                if detected then
                    local score = 0
                    local candidateRole = candidate.aiRole or (candidate.isPiloted and "PLAYER" or "UNKNOWN")
                    local directlyShotMe = (candidate == self.lastAttacker and self.combatMemoryTimer > 0)

                    if directlyShotMe then
                        score = score + 165
                    end

                    -- Compromiso de duelo individual: mantener el enfoque en su duelo actual salvo que le disparen directamente
                    if self.state == AIController.STATES.COMBAT and self.combatTarget and not self.combatTarget.isDestroyed and not self.combatTarget.isAbandoned then
                        if candidate == self.combatTarget then
                            score = score + 110
                        elseif not directlyShotMe then
                            score = score - 95
                        end
                    end

                    -- Regla de Caos Multi-Facción: durante una batalla con otras naves IA cerca, NO hacer focus grupal al jugador.
                    -- Solo la nave específica a la que el jugador disparó (o una nave libre que lo perciba muy de cerca < 270px) lo ataca.
                    if candidateRole == "PLAYER" and hasRivalAIInSector and not directlyShotMe then
                        local isFreeAndVeryClose = (not self.combatTarget or self.combatTarget.isDestroyed) and (dist < 270)
                        if isFreeAndVeryClose then
                            score = score + 38
                        else
                            score = score - 260
                        end
                    end

                    if self.role == AIController.ROLES.RAIDER then
                        if (self.satiatedTimer or 0) > 0 and not directlyShotMe then
                            score = score - 120
                        end
                        local targetHealthPct = (candidate.stats and candidate.stats:getHealthPercentage()) or 100
                        local targetShieldPct = (candidate.stats and candidate.stats:getShieldPercentage()) or 100

                        if candidateRole == AIController.ROLES.SCAVENGER then
                            score = score + 72
                        elseif candidateRole == AIController.ROLES.NOMAD then
                            score = score + 48
                        elseif candidateRole == "PLAYER" then
                            local baseHunt = 58 * (self.pilotPersonality and self.pilotPersonality.aggressiveness or 1.0)
                            local vulnerability = (100 - targetHealthPct) * 0.35 + (100 - targetShieldPct) * 0.25
                            local proximityBonus = dist < 440 and 16 or 4
                            score = score + baseHunt + vulnerability + proximityBonus
                        elseif candidateRole == AIController.ROLES.WARDEN then
                            score = score - 45
                        end

                    elseif self.role == AIController.ROLES.WARDEN then
                        local distFromAnchor = MathUtil.distance(candidate.x, candidate.y, self.homeX, self.homeY)
                        local inTerritory = distFromAnchor <= (self.config.territoryRadius or 900)
                        if inTerritory then
                            if candidateRole == AIController.ROLES.RAIDER then
                                score = score + 80
                            elseif not hasRivalAIInSector and (now - (candidate._lastShotTimestamp or -999)) < 4.0 then
                                score = score + 75
                            elseif dist < 440 then
                                score = score + 42
                            end
                        end

                    elseif self.role == AIController.ROLES.NOMAD then
                        if directlyShotMe then
                            score = score + 90
                        elseif dist < 380 then
                            score = score + 35
                        end

                    elseif self.role == AIController.ROLES.SCAVENGER then
                        if directlyShotMe then
                            score = score + 85
                        elseif candidateRole == AIController.ROLES.RAIDER and dist < 380 and candidate.aiController and candidate.aiController.combatTarget == self.ship then
                            score = score + 60
                        end
                    end

                    -- Choque de Escuadrones Multi-Facción (programado o emergente al cruzarse dos facciones distintas)
                    if self.ship.isFactionCombatant and candidate.isFactionCombatant and candidate.aiFaction ~= self.ship.aiFaction then
                        score = score + 115
                    end

                    score = score - (dist * 0.025)

                    if score > 25 and score > bestScore then
                        bestScore = score
                        bestTarget = candidate
                        bestDist = dist
                    end
                end
            end
        end
    end

    if bestTarget then
        -- Si ya estábamos en combate con este objetivo, nos atacó o pertenece a una flota rival en guerra, ir a COMBAT directo
        local alreadyFighting = (self.state == AIController.STATES.COMBAT and self.combatTarget == bestTarget)
        local wasAttacked = (bestTarget == self.lastAttacker and self.combatMemoryTimer > 0)
        local isFactionWar = (self.ship.isFactionCombatant and bestTarget.isFactionCombatant and bestTarget.aiFaction ~= self.ship.aiFaction)
        local targetFiredRecently = (now - (bestTarget._lastShotTimestamp or -999)) < 3.0

        if alreadyFighting or wasAttacked or isFactionWar then
            self.combatTarget = bestTarget
            self.state = AIController.STATES.COMBAT
        elseif (self.role == AIController.ROLES.WARDEN or self.role == AIController.ROLES.NOMAD) and not targetFiredRecently and bestDist > 230 then
            -- Centinela o Nómada entra primero en estado de ADVERTENCIA / INSPECCIÓN en vez de disparar como autómata
            self.alertTarget = bestTarget
            self.alertMode = "WARN"
            self.alertTimer = 0
            self.alertMaxTimer = 2.4
            self.state = AIController.STATES.ALERT
        elseif self.role == AIController.ROLES.RAIDER and bestDist > 430 then
            -- Corsario entra primero en estado de ACECHO (aproximación sigilosa por el punto ciego antes de emboscar)
            self.alertTarget = bestTarget
            self.alertMode = "STALK"
            self.alertTimer = 0
            self.alertMaxTimer = 3.6
            self.state = AIController.STATES.ALERT
        else
            self.combatTarget = bestTarget
            self.state = AIController.STATES.COMBAT
        end
    else
        if self.combatMemoryTimer <= 0 and not (self.state == AIController.STATES.COMBAT and self.lastSeenX) then
            self.combatTarget = nil
            self.alertTarget = nil
            self.state = AIController.STATES.WORLD_GOAL
        end
    end
end

-- Programa una incursión oportunista a un sitio de escombros/pecio detectado en el sector
function AIController:scheduleSalvageOpportunistic(x, y, delay, wreckShip)
    if self.state == AIController.STATES.SURVIVE then return end
    if self.state == AIController.STATES.COMBAT and (self.combatMemoryTimer or 0) > 8 then return end

    self.salvageScheduleTimer = math.max(0.1, delay or 6.0)
    self.salvageSiteTarget = {
        x = x,
        y = y,
        wreck = wreckShip
    }
end

-- Selecciona una nueva tarea en el mundo
function AIController:pickNewWorldGoal()
    self.isTractorBeaming = false
    local wg = self.worldGoal
    wg.isWorking = false
    wg.timer = 0
    wg.targetEntity = nil
    self.worldTasksCompleted = (self.worldTasksCompleted or 0) + 1

    if self.wingmanOf and not self.wingmanOf.isDestroyed and not self.wingmanOf.isAbandoned then
        wg.type = "escort_leader"
        wg.targetX = self.wingmanOf.x + self.formationOffsetX
        wg.targetY = self.wingmanOf.y + self.formationOffsetY
        wg.targetEntity = self.wingmanOf
        wg.maxTimer = 6.0
        return
    end

    local WorldItems = package.loaded['src.item_systems.world_items'] or require('src.item_systems.world_items')
    local Naves = package.loaded['src.entities.naves'] or require('src.entities.naves')
    local Map = package.loaded['src.maps.map']
    local MapConfig = package.loaded['src.maps.config.map_config']

    -- Ciclo autónomo: tras 2 tareas locales en el chunk, un recolector/minero emprende viaje hacia un chunk vecino
    local shouldMigrateChunk = (self.worldTasksCompleted % 3 == 0)

    if self.role == AIController.ROLES.SCAVENGER and not shouldMigrateChunk then
        if WorldItems and WorldItems.getNearbyItems then
            local items = WorldItems.getNearbyItems(self.ship.x, self.ship.y, 700, true)
            if items and #items > 0 then
                local entry = items[1]
                local itemObj = entry.item or entry
                if itemObj and itemObj.x and itemObj.y then
                    wg.type = "collect_item"
                    wg.targetX = itemObj.x
                    wg.targetY = itemObj.y
                    wg.targetEntity = itemObj
                    wg.maxTimer = 3.5
                    return
                end
            end
        end

        if Naves and Naves.getNearbyShips then
            local nearby = Naves.getNearbyShips(self.ship.x, self.ship.y, 1100)
            for _, entry in ipairs(nearby) do
                local s = entry.ship
                if s and s ~= self.ship and (s.isAbandoned or s.isInEVA) then
                    wg.type = "salvage_wreck"
                    wg.targetX = s.x
                    wg.targetY = s.y
                    wg.targetEntity = s
                    wg.maxTimer = (self.ship.shipType == "SALVAGER") and 6.5 or 9.0
                    return
                end
            end
        end

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
                        wg.maxTimer = (self.ship.shipType == "SALVAGER") and 6.5 or 9.0
                        return
                    end
                end
            end
        end
    end

    if self.role == AIController.ROLES.WARDEN and not self.ship.transitAngle then
        local angle = self:random(0, math.pi * 2)
        local orbitR = self:random(240, 560)
        wg.type = "patrol_anchor"
        wg.targetX = self.homeX + math.cos(angle) * orbitR
        wg.targetY = self.homeY + math.sin(angle) * orbitR
        wg.maxTimer = 8.0
        return
    end

    -- Rutas inter-chunk autónomas: las naves viajan entre chunks del mapa siguiendo su propio vector cósmico
    -- sin girar alrededor del jugador, permitiendo cruces 100% fortuitos cuando dos rutas se intersectan.
    local baseAngle = self.ship.transitAngle or self:random(0, math.pi * 2)
    local angle = baseAngle + self:random(-0.35, 0.35)
    self.ship.transitAngle = angle
    local dist = shouldMigrateChunk and self:random(2200, 3600) or (self.ship.transitAngle and self:random(1500, 2800) or self:random(900, 1800))
    wg.type = "travel_waypoint"
    wg.targetX = (self.ship.x or self.homeX) + math.cos(angle) * dist
    wg.targetY = (self.ship.y or self.homeY) + math.sin(angle) * dist
    wg.maxTimer = 18.0
end

-- =============================================================================
-- PILOTAJE FÍSICO REAL (Propulsores alineados con proa + RCS + Derrape Inercial)
-- =============================================================================
function AIController:steerTowards(dt, targetX, targetY, desiredSpeedFactor, keepDistance, aimOverrideX, aimOverrideY)
    local ship = self.ship
    local dx = targetX - ship.x
    local dy = targetY - ship.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 0.001 then return dist end

    local dirX = dx / dist
    local dirY = dy / dist

    -- 1. Combinar deseo de movimiento con repulsión de obstáculos y esquiva reactiva (Juke)
    local avoidX, avoidY = self:computeObstacleAvoidance()
    local avoidance = math.min(1, math.sqrt(avoidX * avoidX + avoidY * avoidY))
    local desire = 1 - avoidance * .75
    local desiredX = dirX * desire + avoidX
    local desiredY = dirY * desire + avoidY

    if self.jukeTimer > 0 then
        desiredX = desiredX + self.jukeDirX * 2.2
        desiredY = desiredY + self.jukeDirY * 2.2
        ship.isBoostActive = true
    end

    local desiredLen = math.sqrt(desiredX * desiredX + desiredY * desiredY)
    if desiredLen > 0.001 then
        desiredX = desiredX / desiredLen
        desiredY = desiredY / desiredLen
    else
        desiredX, desiredY = dirX, dirY
    end

    -- 2. Calcular hacia dónde quiere apuntar el morro el piloto
    local faceX = aimOverrideX and (aimOverrideX - ship.x) or desiredX
    local faceY = aimOverrideY and (aimOverrideY - ship.y) or desiredY
    local targetRot = math.atan2(faceY, faceX) + (math.pi * 0.5)

    -- Añadir micro-oscilación orgánica cuando está apuntando en combate (ningún piloto humano es un láser estático)
    if aimOverrideX then
        local now = self.simTime or 0
        local p = self.pilotPersonality
        local wander = math.sin(now * p.aimWanderSpeed + p.aimWanderPhase) * 0.045
        targetRot = targetRot + wander
    end

    local angleDiff = targetRot - (ship.rotation or 0)
    while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
    while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end

    -- 3. Determinar si el piloto activa el DERRAPE INERCIAL (Drift)
    -- Si la nave ya lleva velocidad y necesita girar el morro fuertemente (> 50 grados) o apuntar de costado mientras orbita
    local currentSpeed = math.sqrt((ship.dx or 0)^2 + (ship.dy or 0)^2)
    local forwardX = math.sin(ship.rotation or 0)
    local forwardY = -math.cos(ship.rotation or 0)
    local rightX = math.cos(ship.rotation or 0)
    local rightY = math.sin(ship.rotation or 0)

    local velAlign = 1.0
    if currentSpeed > 8 then
        velAlign = ((ship.dx / currentSpeed) * forwardX) + ((ship.dy / currentSpeed) * forwardY)
    end

    if currentSpeed > (ship.driftActivation or 18) and (math.abs(angleDiff) > 0.85 or (aimOverrideX and velAlign < 0.45)) then
        ship.isDrifting = true
    else
        ship.isDrifting = false
    end

    -- 4. Rotación con Inercia Angular Real (Spring-Damper Torque)
    local turnRate = (ship.rotationSpeed or 4.5) * (ship.isDrifting and 1.42 or 1.0)
    local desiredAngVel = math.max(-turnRate * 1.4, math.min(turnRate * 1.4, angleDiff * turnRate * 1.8))
    self.angVel = MathUtil.lerp(self.angVel or 0, desiredAngVel, math.min(1, dt * 11.0))
    ship.rotation = (ship.rotation or 0) + self.angVel * dt

    -- Recalcular vectores locales de la nave tras rotar
    forwardX = math.sin(ship.rotation)
    forwardY = -math.cos(ship.rotation)
    rightX = math.cos(ship.rotation)
    rightY = math.sin(ship.rotation)

    -- 5. Propulsión Física sobre los Ejes Reales de la Nave (Principal Frontal + RCS Lateral + Reversa)
    local stopDist = keepDistance or 40
    local speedFactor = (desiredSpeedFactor or .75) * (1 - avoidance * .35)
    local fwdAccel = (ship.forwardAccel or 12) * speedFactor * (ship.isBoostActive and (ship.boostMultiplier or 1.4) or 1.0)
    local strafeAccel = (ship.strafeAccel or 9.5) * speedFactor
    local backAccel = (ship.backwardAccel or 7.5) * speedFactor

    -- Proyectar el vector deseado sobre el eje frontal y el eje derecho de la nave
    local fwdProj = desiredX * forwardX + desiredY * forwardY
    local rightProj = desiredX * rightX + desiredY * rightY

    if dist > stopDist then
        -- Solo enciende el propulsor principal si el morro apunta razonablemente hacia la dirección de avance
        if fwdProj > 0.22 then
            local thrustPower = math.min(1.0, fwdProj * 1.15)
            ship.dx = (ship.dx or 0) + forwardX * fwdAccel * thrustPower * dt
            ship.dy = (ship.dy or 0) + forwardY * fwdAccel * thrustPower * dt
            ship.engineGlow = math.min(1.0, (ship.engineGlow or 0) + dt * 3.8)
            ship._aiIsMoving = true
        else
            ship.engineGlow = math.max(0.15, (ship.engineGlow or 0) - dt * 2.0)
        end

        -- Propulsores laterales RCS para corregir deriva o deslizarse en órbita
        if math.abs(rightProj) > 0.18 then
            ship.dx = (ship.dx or 0) + rightX * rightProj * strafeAccel * dt
            ship.dy = (ship.dy or 0) + rightY * rightProj * strafeAccel * dt
            self.rcsThrustDir = (rightProj > 0) and 1 or -1
            ship._aiIsMoving = true
        elseif self.jukeTimer <= 0 then
            self.rcsThrustDir = 0
        end

    elseif dist < stopDist * 0.72 then
        -- Demasiado cerca: encender retropropulsores de proa + propulsores laterales
        ship.dx = (ship.dx or 0) - forwardX * backAccel * 0.75 * dt + rightX * rightProj * strafeAccel * dt
        ship.dy = (ship.dy or 0) - forwardY * backAccel * 0.75 * dt + rightY * rightProj * strafeAccel * dt
        ship.engineGlow = math.min(0.55, (ship.engineGlow or 0) + dt * 2.0)
        ship._aiIsMoving = true
    else
        -- En banda óptima: mantener deriva suave y corrección de obstáculos
        if math.abs(rightProj) > 0.20 then
            ship.dx = (ship.dx or 0) + rightX * rightProj * (strafeAccel * 0.85) * dt
            ship.dy = (ship.dy or 0) + rightY * rightProj * (strafeAccel * 0.85) * dt
            self.rcsThrustDir = (rightProj > 0) and 1 or -1
        else
            self.rcsThrustDir = 0
        end
        ship.dx = (ship.dx or 0) * math.pow(0.93, dt * 60)
        ship.dy = (ship.dy or 0) * math.pow(0.93, dt * 60)
        ship.engineGlow = math.max(0, (ship.engineGlow or 0) - dt * 2.5)
        ship._aiIsMoving = false
    end

    -- 6. Si el Derrape Inercial está activo, conservar más momento lateral como en el jugador
    if ship.isDrifting and currentSpeed > 5 then
        local fwdVel = (ship.dx * forwardX + ship.dy * forwardY)
        local latVelX = ship.dx - fwdVel * forwardX
        local latVelY = ship.dy - fwdVel * forwardY
        local driftKeep = math.pow(ship.driftFactor or 0.96, dt * 60)
        ship.dx = fwdVel * forwardX * math.pow(ship.gradualBraking or 0.94, dt * 60) + latVelX * driftKeep
        ship.dy = fwdVel * forwardY * math.pow(ship.gradualBraking or 0.94, dt * 60) + latVelY * driftKeep
    end

    return dist
end

-- =============================================================================
-- ESTADO ALERT (Advertencia Territorial de Centinelas/Nómadas o Acecho Corsario)
-- =============================================================================
function AIController:updateAlert(dt)
    self.worldGoal.isWorking = false
    local target = self.alertTarget
    if not target or target.isDestroyed or target.combatContext ~= self.ship.combatContext
        or (target.isAbandoned and not target.isInEVA) then
        self.alertTarget = nil
        self.state = AIController.STATES.WORLD_GOAL
        return
    end

    local targetEntity = (target.getActiveEntity and target:getActiveEntity()) or target
    if target.abilitySystem and target.abilitySystem.decoy then targetEntity = target.abilitySystem.decoy end
    local tx, ty = targetEntity.x or target.x, targetEntity.y or target.y
    local dx = tx - self.ship.x
    local dy = ty - self.ship.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local now = love.timer and love.timer.getTime and love.timer.getTime() or 0

    self.alertTimer = self.alertTimer + dt

    if self.alertMode == "WARN" then
        -- ADVERTENCIA TERRITORIAL (WARDEN / NOMAD):
        -- Mantiene la distancia, encara directamente al intruso y hace destellar su baliza
        self:steerTowards(dt, tx, ty, 0.60, 340, tx, ty)

        -- Si el intruso dispara o invade la zona crítica (< 240px), abre fuego de inmediato
        local firedRecently = (now - (target._lastShotTimestamp or -999)) < 2.0
        if firedRecently or dist < 240 then
            self.combatTarget = target
            self.alertTarget = nil
            self.state = AIController.STATES.COMBAT
            return
        end

        -- Si tras el tiempo de advertencia el intruso se aleja (> 430px), vuelve en paz a su rutina
        if self.alertTimer >= self.alertMaxTimer then
            if dist > 390 then
                self.alertTarget = nil
                self.state = AIController.STATES.WORLD_GOAL
            else
                -- No hizo caso a la advertencia: iniciar combate
                self.combatTarget = target
                self.alertTarget = nil
                self.state = AIController.STATES.COMBAT
            end
        end

    elseif self.alertMode == "STALK" then
        -- ACECHO CORSARIO (RAIDER):
        -- Se aproxima buscando el punto ciego trasero de la presa sin activar el Boost todavía
        local tRot = target.rotation or 0
        local behindX = tx - math.sin(tRot) * 260
        local behindY = ty + math.cos(tRot) * 260
        self:steerTowards(dt, behindX, behindY, 0.85, 80, tx, ty)

        -- Romper el acecho y lanzar la emboscada cuando está cerca (< 410px), cuando la presa entra en EVA o tras el timer
        if dist < 410 or target.isInEVA or self.alertTimer >= self.alertMaxTimer then
            self.combatTarget = target
            self.alertTarget = nil
            self.ship.isBoostActive = true
            self.state = AIController.STATES.COMBAT
        end
    end
end

-- Ejecución del estado WORLD_GOAL
function AIController:updateWorldGoal(dt)
    self.telegraphTimer = 0
    local wg = self.worldGoal
    if not wg.type or not wg.targetX or not wg.targetY then
        self:pickNewWorldGoal()
        return
    end

    if wg.type == "escort_leader" then
        local leader = wg.targetEntity
        if not leader or leader.isDestroyed or leader.isAbandoned then
            self.wingmanOf = nil
            self.isReceivingCarrierShield = false
            self:pickNewWorldGoal()
            return
        end

        local isMothershipLeader = leader.shipConfig and leader.shipConfig.isMothership
        if isMothershipLeader and leader.shipType ~= "ECLIPSE" and leader.shipType ~= "DREADNOUGHT" then
            -- Órbita viva satelital alrededor de Nodrizas Industriales (TITAN_EXCAVATOR) o Monolitos (ARK_MONOLITH)
            local now = love.timer and love.timer.getTime and love.timer.getTime() or 0
            local slotAngle = now * 0.65 + (self.formationSlotIndex or 1) * (math.pi * 0.66)
            local orbitRadius = (leader.size or 38) * 3.1
            wg.targetX = leader.x + math.cos(slotAngle) * orbitRadius
            wg.targetY = leader.y + math.sin(slotAngle) * orbitRadius
        else
            -- Formación en V táctica rotada según la orientación del líder (ECLIPSE o líder de escuadrón)
            local lRot = leader.rotation or 0
            local cosR, sinR = math.cos(lRot), math.sin(lRot)
            local ox = self.formationOffsetX * cosR - self.formationOffsetY * sinR
            local oy = self.formationOffsetX * sinR + self.formationOffsetY * cosR
            wg.targetX = leader.x + ox
            wg.targetY = leader.y + oy
        end

        -- Si el escolta tiene el escudo incompleto y vuela cerca de su Nodriza, recibe enlace de escudo pasivo
        local myShieldPct = (self.ship.stats and self.ship.stats:getShieldPercentage()) or 100
        local distToLeader = math.sqrt((leader.x - self.ship.x)^2 + (leader.y - self.ship.y)^2)
        if isMothershipLeader and myShieldPct < 98 and distToLeader <= 260 and self.ship.stats and self.ship.stats.shield then
            self.isReceivingCarrierShield = true
            local sh = self.ship.stats.shield
            sh.currentShield = math.min(sh.maxShield, (sh.currentShield or 0) + 25 * dt)
        else
            self.isReceivingCarrierShield = false
        end

        self:steerTowards(dt, wg.targetX, wg.targetY, 0.94, 32)
        return
    end

    if wg.type == "investigate_salvage" then
        local WorldItems = package.loaded['src.item_systems.world_items'] or require('src.item_systems.world_items')
        local Naves = package.loaded['src.entities.naves'] or require('src.entities.naves')
        local nearbyItems = WorldItems and WorldItems.getNearbyItems and WorldItems.getNearbyItems(self.ship.x, self.ship.y, 650, true)

        if nearbyItems and #nearbyItems > 0 then
            -- 1. Hay ítems sueltos flotando: dirigirse al más cercano y aspirarlo con rayo tractor
            local entry = nearbyItems[1]
            local itemObj = entry.item or entry
            local itemDist = entry.distance or math.sqrt((itemObj.x - self.ship.x)^2 + (itemObj.y - self.ship.y)^2)

            if itemDist <= 180 then
                self.isTractorBeaming = true
                self.tractorTargetX = itemObj.x
                self.tractorTargetY = itemObj.y

                -- Tirar físicamente del ítem hacia la nave
                local pullSpd = 145 * dt
                local toShipX = (self.ship.x - itemObj.x) / math.max(1, itemDist)
                local toShipY = (self.ship.y - itemObj.y) / math.max(1, itemDist)
                itemObj.x = itemObj.x + toShipX * pullSpd
                itemObj.y = itemObj.y + toShipY * pullSpd

                if itemDist <= 85 then
                    local picked = WorldItems.tryPickup(self.ship.x, self.ship.y, self.ship.inventory, false)
                    if picked and #picked > 0 then
                        self.scavengedLoot = self.scavengedLoot or {}
                        for _, p in ipairs(picked) do
                            table.insert(self.scavengedLoot, {
                                data = p.itemData or { id = p.name, name = p.name },
                                quantity = p.quantity or 1,
                                name = p.name
                            })
                        end
                        if self.ship.inventory and self.ship.inventory.items then
                            for slot = 1, (self.ship.inventory.maxSlots or 12) do
                                self.ship.inventory.items[slot] = nil
                            end
                        end
                    end
                end
                self:steerTowards(dt, itemObj.x, itemObj.y, 0.45, 45, itemObj.x, itemObj.y)
            else
                self.isTractorBeaming = false
                self:steerTowards(dt, itemObj.x, itemObj.y, 0.78, 55, itemObj.x, itemObj.y)
            end
            wg.timer = 0
            return
        end

        -- 2. Si no hay ítems sueltos, buscar si hay algún pecio inmóvil / abordable en la zona
        local wreck = wg.targetEntity
        if not wreck or wreck.isDestroyed or (not wreck.isAbandoned and not wreck.isInEVA) then
            if Naves and Naves.getNearbyShips then
                local nearby = Naves.getNearbyShips(self.ship.x, self.ship.y, 800)
                for _, sEntry in ipairs(nearby) do
                    local s = sEntry.ship
                    if s and s ~= self.ship and not s.isDestroyed and (s.isAbandoned or s.isInEVA) then
                        wreck = s
                        wg.targetEntity = s
                        break
                    end
                end
            end
        end

        if wreck and not wreck.isDestroyed and (wreck.isAbandoned or wreck.isInEVA) then
            local wDx = wreck.x - self.ship.x
            local wDy = wreck.y - self.ship.y
            local wDist = math.sqrt(wDx * wDx + wDy * wDy)

            if wDist <= 145 then
                self.isTractorBeaming = true
                self.tractorTargetX = wreck.x
                self.tractorTargetY = wreck.y
                self.salvageDropTimer = (self.salvageDropTimer or 0) + dt

                if self.salvageDropTimer >= 2.5 then
                    self.salvageDropTimer = 0
                    if wreck.stats and wreck.stats.fuel and wreck.stats.fuel.currentFuel > 5 then
                        wreck.stats.fuel.currentFuel = math.max(0, wreck.stats.fuel.currentFuel - 15)
                        if self.ship.stats and self.ship.stats.fuel then
                            self.ship.stats:addFuel(15)
                        end
                    end
                    local dropId = (self:random() < 0.45) and "energy_crystal" or "iron_ore"
                    local ItemSystem = package.loaded['src.item_systems.item_system'] or require('src.item_systems.item_system')
                    local itemData = ItemSystem and ItemSystem.getItem and ItemSystem:getItem(dropId)
                    if itemData then
                        self.scavengedLoot = self.scavengedLoot or {}
                        table.insert(self.scavengedLoot, { data = itemData, quantity = 1, name = itemData.name })
                    end
                    if wreck.addImpactEffect then
                        wreck:addImpactEffect(wreck.x, wreck.y, {1.0, 0.8, 0.2, 1.0})
                    end
                end

                wg.timer = wg.timer + dt
                if wg.timer >= (wg.maxTimer or 14.0) then
                    self.isTractorBeaming = false
                    self:pickNewWorldGoal()
                    return
                end
                self:steerTowards(dt, wreck.x, wreck.y, 0.35, 115, wreck.x, wreck.y)
                return
            else
                self.isTractorBeaming = false
                self:steerTowards(dt, wreck.x, wreck.y, 0.75, 115, wreck.x, wreck.y)
                return
            end
        end

        -- 3. Si no hay ítems ni pecios en la zona: volar hacia el punto de escombros
        self.isTractorBeaming = false
        local distToTarget = self:steerTowards(dt, wg.targetX, wg.targetY, self.config.cruiseSpeedFactor, 60)
        wg.timer = wg.timer + dt
        if distToTarget <= 75 or wg.timer >= (wg.maxTimer or 18.0) then
            self:pickNewWorldGoal()
            return
        end
        return
    end

    if wg.targetEntity then
        if wg.type == "salvage_wreck" then
            local wreck = wg.targetEntity
            if wreck.isDestroyed or (not wreck.isAbandoned and not wreck.isInEVA) then
                self.isTractorBeaming = false
                self:pickNewWorldGoal()
                return
            end
            wg.targetX, wg.targetY = wreck.x, wreck.y
        elseif wg.type == "collect_item" then
            local item = wg.targetEntity
            if not item or not item.x then
                self.isTractorBeaming = false
                self:pickNewWorldGoal()
                return
            end
            wg.targetX, wg.targetY = item.x, item.y
        end
    end

    local stopDist = (wg.type == "mine_asteroid" or wg.type == "salvage_wreck") and 115 or 55
    local aimX = (wg.type == "mine_asteroid" or wg.type == "salvage_wreck") and wg.targetX or nil
    local aimY = (wg.type == "mine_asteroid" or wg.type == "salvage_wreck") and wg.targetY or nil
    local dist = self:steerTowards(dt, wg.targetX, wg.targetY, self.config.cruiseSpeedFactor, stopDist, aimX, aimY)

    if dist <= stopDist + 35 then
        if wg.type == "mine_asteroid" or wg.type == "salvage_wreck" then
            wg.isWorking = true
            wg.timer = wg.timer + dt

            if wg.type == "salvage_wreck" and wg.targetEntity then
                self.isTractorBeaming = true
                self.tractorTargetX = wg.targetX
                self.tractorTargetY = wg.targetY
                self.salvageDropTimer = self.salvageDropTimer + dt
                if self.salvageDropTimer >= 2.8 then
                    self.salvageDropTimer = 0
                    local wreck = wg.targetEntity
                    if wreck.stats and wreck.stats.fuel and wreck.stats.fuel.currentFuel > 10 then
                        wreck.stats.fuel.currentFuel = math.max(0, wreck.stats.fuel.currentFuel - 15)
                        if self.ship.stats and self.ship.stats.fuel then
                            self.ship.stats:addFuel(15)
                        end
                    end
                    local dropId = (self:random() < 0.40) and "energy_crystal" or "iron_ore"
                    local ItemSystem = package.loaded['src.item_systems.item_system'] or require('src.item_systems.item_system')
                    local itemData = ItemSystem and ItemSystem.getItem and ItemSystem:getItem(dropId)
                    if itemData then
                        self.scavengedLoot = self.scavengedLoot or {}
                        table.insert(self.scavengedLoot, { data = itemData, quantity = 1, name = itemData.name })
                    end
                    if wreck.addImpactEffect then
                        wreck:addImpactEffect(wreck.x, wreck.y, {1.0, 0.8, 0.2, 1.0})
                    end
                end
            end

            if wg.timer >= wg.maxTimer then
                wg.isWorking = false
                self.isTractorBeaming = false
                if self.ship.inventory and self.ship.inventory.addItem then
                    local ItemSystem = package.loaded['src.item_systems.item_system'] or require('src.item_systems.item_system')
                    if ItemSystem and ItemSystem.createItemInstance then
                        local dropId = (self:random() < 0.40) and "energy_crystal" or "iron_ore"
                        local inst = ItemSystem:createItemInstance(dropId, 2)
                        if inst then
                            pcall(function() self.ship.inventory:addItem(inst) end)
                        end
                    end
                end
                self:pickNewWorldGoal()
            end
        elseif wg.type == "collect_item" then
            local WorldItems = package.loaded['src.item_systems.world_items'] or require('src.item_systems.world_items')
            if WorldItems and WorldItems.tryPickup and self.ship and self.ship.inventory then
                local picked = WorldItems.tryPickup(self.ship.x, self.ship.y, self.ship.inventory, false)
                if picked and #picked > 0 then
                    self.scavengedLoot = self.scavengedLoot or {}
                    for _, p in ipairs(picked) do
                        table.insert(self.scavengedLoot, {
                            data = p.itemData or { id = p.name, name = p.name },
                            quantity = p.quantity or 1,
                            name = p.name
                        })
                    end
                end
            end
            self.isTractorBeaming = false
            self:pickNewWorldGoal()
        else
            self.isTractorBeaming = false
            wg.timer = wg.timer + dt
            if wg.timer >= 1.2 then
                self:pickNewWorldGoal()
            end
        end
    else
        self.isTractorBeaming = false
        wg.isWorking = false
        wg.timer = wg.timer + dt * 0.25
        if wg.timer >= wg.maxTimer * 2.0 then
            self:pickNewWorldGoal()
        end
    end
end

-- =============================================================================
-- ESTADO COMBAT (Pilotaje Dinámico, Esquiva de Proyectiles y Ráfagas)
-- =============================================================================
function AIController:updateCombat(dt)
    self.worldGoal.isWorking = false
    local target = self.combatTarget

    if not target or target.isDestroyed or (target.isAbandoned and not target.isInEVA) then
        -- Si abatió a su objetivo, entra en periodo de saciado/saqueo para no encadenar agresiones artificiales contra el jugador
        if target and (target.isDestroyed or target.isAbandoned) then
            self.satiatedTimer = 18.0
        end
        self.combatTarget = nil
        self.telegraphTimer = 0
        self.state = AIController.STATES.WORLD_GOAL
        self:pickNewWorldGoal()
        return
    end

    if target.combatContext ~= self.ship.combatContext then
        self.combatTarget, self.telegraphTimer, self.attackLease = nil, 0, 0
        self.state = AIController.STATES.WORLD_GOAL
        return
    end

    local targetEntity = (target.getActiveEntity and target:getActiveEntity()) or target
    local decoy = target.abilitySystem and target.abilitySystem.decoy
    local cue = decoy or targetEntity
    if self.observedTarget ~= target or self.observedCue ~= cue then
        if self.observedTarget ~= target then
            self.lastSeenX, self.lastSeenY, self.searchTime = nil, nil, 0
        end
        self.observedTarget, self.observedCue = target, cue
        self.trackedTargetVx, self.trackedTargetVy = nil, nil
        self.sightTimer, self.telegraphTimer, self.attackLease = 0, 0, 0
    end
    self.sightTimer = (self.sightTimer or 0) - dt
    if self.sightTimer <= 0 then
        local visible = (cue.x - self.ship.x)^2 + (cue.y - self.ship.y)^2 <= 1800^2
            and self:hasLineOfSight(cue.x, cue.y)
        if visible ~= self.targetVisible then self:recordCombat(visible and 'visible' or 'cover', target) end
        self.targetVisible = visible
        if visible then
            self.lastSeenX, self.lastSeenY = cue.x, cue.y
            self.seenVx, self.seenVy = cue.dx or 0, cue.dy or 0
        end
        self.sightTimer = .12
    end
    self:evaluateIncomingThreats(dt, target, self.targetVisible and not decoy)
    if not self.targetVisible then
        self.telegraphTimer, self.attackLease = 0, 0
        self.searchTime = (self.searchTime or 0) + dt
        if self.lastSeenX and self.searchTime <= 3.2 then
            if self.searchTime == dt then self:recordCombat('search', target) end
            self:steerTowards(dt, self.lastSeenX, self.lastSeenY, .65, 75)
        else
            self:recordCombat('lost', target)
            self.combatTarget, self.lastSeenX, self.combatMemoryTimer = nil, nil, 0
            self.state = AIController.STATES.WORLD_GOAL
            self:pickNewWorldGoal()
        end
        return
    end

    local tx, ty = self.lastSeenX, self.lastSeenY
    self.searchTime = 0
    local rawTvx, rawTvy = self.seenVx, self.seenVy
    local reactRate = math.min(1, dt * (self.pilotPersonality.reactionSpeed or 5.5))
    self.trackedTargetVx = MathUtil.lerp(self.trackedTargetVx or rawTvx, rawTvx, reactRate)
    self.trackedTargetVy = MathUtil.lerp(self.trackedTargetVy or rawTvy, rawTvy, reactRate)
    local dx, dy = tx - self.ship.x, ty - self.ship.y
    local dist = math.sqrt(dx * dx + dy * dy)

    local shipType = self.ship.shipType or "FIGHTER"
    local isMothership = (self.ship.shipConfig and self.ship.shipConfig.isMothership) or false
    local myShieldPct = (self.ship.stats and self.ship.stats:getShieldPercentage()) or 100
    local myHealthPct = (self.ship.stats and self.ship.stats:getHealthPercentage()) or 100

    local leadTime = math.min(0.62, dist / 680)
    local aimX = tx + self.trackedTargetVx * leadTime * 11.5
    local aimY = ty + self.trackedTargetVy * leadTime * 11.5

    -- =========================================================================
    -- TÁCTICA DE ESCUADRÓN NODRIZA: Repliegue de Escoltas para Recargar Escudo (Carrier Shield Tether)
    -- =========================================================================
    if self.wingmanOf and self.wingmanOf.shipConfig and self.wingmanOf.shipConfig.isMothership
       and not self.wingmanOf.isDestroyed and not self.wingmanOf.isAbandoned then
        local leader = self.wingmanOf
        local distToLeader = math.sqrt((leader.x - self.ship.x)^2 + (leader.y - self.ship.y)^2)
        if myShieldPct <= 18 or (self.isReceivingCarrierShield and myShieldPct < 82) then
            self.telegraphTimer, self.attackLease = 0, 0
            self.ship.isBoostActive = (distToLeader > 210)
            self:steerTowards(dt, leader.x, leader.y, 1.18, 95, aimX, aimY)
            if distToLeader <= 250 and self.ship.stats and self.ship.stats.shield then
                self.isReceivingCarrierShield = true
                local sh = self.ship.stats.shield
                sh.currentShield = math.min(sh.maxShield, (sh.currentShield or 0) + 32 * dt)
            else
                self.isReceivingCarrierShield = false
            end
            return
        else
            self.isReceivingCarrierShield = false
        end
    else
        self.isReceivingCarrierShield = false
    end

    -- A damaged pilot opens distance while an ally keeps the pressure.
    if not isMothership and (myShieldPct <= 12 and myHealthPct < 85 or self.tacticalRetreat) then
        self.tacticalRetreat = myShieldPct < 42
        if self.tacticalRetreat then
            self.telegraphTimer, self.attackLease = 0, 0
            local retreat = math.max(0, 480 - dist)
            local nx, ny = dx / math.max(1, dist), dy / math.max(1, dist)
            self.ship.isBoostActive = dist < 300
            self:steerTowards(dt, self.ship.x - nx * retreat - ny * 130 * self.strafeDir,
                self.ship.y - ny * retreat + nx * 130 * self.strafeDir, 1.05, 45, aimX, aimY)
            return
        end
    end

    -- =========================================================================
    -- ARQUETIPO 0: NODRIZAS / PORTANAVES (TITAN_EXCAVATOR, ECLIPSE, ARK_MONOLITH)
    -- =========================================================================
    if isMothership then
        local isEclipse = (shipType == "ECLIPSE" or shipType == "DREADNOUGHT")
        local standoffDist = isEclipse and 410 or 440
        local orbitX = tx - (dx / math.max(1, dist)) * standoffDist + (-dy / math.max(1, dist)) * 180 * self.strafeDir
        local orbitY = ty - (dy / math.max(1, dist)) * standoffDist + (dx / math.max(1, dist)) * 180 * self.strafeDir
        self:steerTowards(dt, orbitX, orbitY, 0.78, 65, aimX, aimY)

        -- Despliegue de Hangar en Combate: lanza un escolta de reserva cuando entra en combate
        self.hangarCooldown = math.max(0, (self.hangarCooldown or 0) - dt)
        if (self.hangarReserve or 0) > 0 and self.hangarCooldown <= 0 and dist <= 980 then
            self.hangarReserve = self.hangarReserve - 1
            self.hangarCooldown = 14.5
            self.hangarFlashTimer = 0.85

            local World = package.loaded['src.core.world']
            local director = World and (World.get('director') or World.get('gameDirector'))
            local Naves = package.loaded['src.entities.naves']
            local hangarClass = (self.ship.shipConfig and self.ship.shipConfig.hangarClass) or "FIGHTER"
            local launchAngle = (self.ship.rotation or 0) + ((self.hangarReserve % 2 == 0) and 1.2 or -1.2)
            local lx = self.ship.x + math.sin(launchAngle) * ((self.ship.size or 38) * 1.4)
            local ly = self.ship.y - math.cos(launchAngle) * ((self.ship.size or 38) * 1.4)
            local slotIdx = #(self.escorts or {}) + 1
            local escort = nil
            if director and director.spawnEcologicalShip then
                escort = director:spawnEcologicalShip(lx, ly, hangarClass, self.role, self.rng, {
                    wingmanOf = self.ship,
                    formationSlotIndex = slotIdx,
                    formationOffsetX = ((slotIdx % 2 == 0) and 1 or -1) * 115,
                    formationOffsetY = 85
                })
            elseif Naves and Naves.new then
                escort = Naves:new(lx, ly, hangarClass)
                escort.useStarterSprite = false
                escort.sprite = nil
                escort.aiController = AIController:new(escort, {
                    role = self.role,
                    rng = self.rng,
                    wingmanOf = self.ship,
                    formationSlotIndex = slotIdx,
                    formationOffsetX = ((slotIdx % 2 == 0) and 1 or -1) * 115,
                    formationOffsetY = 85
                })
                if World and World.addEntity then World.addEntity(escort) end
            end
            if escort and escort.aiController then
                escort.aiFaction = self.ship.aiFaction
                escort.isFactionCombatant = self.ship.isFactionCombatant
                escort.dx = math.sin(launchAngle) * 48
                escort.dy = -math.cos(launchAngle) * 48
                escort.aiController.combatTarget = target
                escort.aiController.state = AIController.STATES.COMBAT
                self.escorts = self.escorts or {}
                table.insert(self.escorts, escort)
            end
        end

        self:updateTelegraph(dt, target, cue, aimX, aimY, dist, 880, .62, isEclipse and 1.25 or 1.45, .52)
        return

    -- =========================================================================
    -- ARQUETIPO 1: INTERCEPTOR (Pasadas en Curva + Giro con Derrape Inercial)
    -- =========================================================================
    elseif shipType == "INTERCEPTOR" then
        self.tacticalTimer = self.tacticalTimer - dt
        if self.tacticalPhase == "ENGAGE" then
            -- Aproximación en arco ligeramente desplazado (no en línea recta frontal suicida)
            local flankAngle = math.atan2(dy, dx) + (0.32 * self.strafeDir)
            local approachX = tx - math.cos(flankAngle) * 90
            local approachY = ty - math.sin(flankAngle) * 90
            self.ship.isBoostActive = (dist > 280)
            self:steerTowards(dt, approachX, approachY, 1.12, 85, aimX, aimY)

            if dist < 175 or self.tacticalTimer <= -4.2 then
                self.tacticalPhase = "PASS_AWAY"
                self.tacticalTimer = self:random(1.6, 2.3)
                self.strafeDir = -self.strafeDir
            end
        else
            -- Romper contacto a gran velocidad y usar Drift al final para volver a encarar
            self.ship.isBoostActive = (self.tacticalTimer > 0.6)
            local escapeX = self.ship.x - dx + (-dy * 0.75 * self.strafeDir)
            local escapeY = self.ship.y - dy + (dx * 0.75 * self.strafeDir)
            local lookAtX = (self.tacticalTimer < 0.65) and aimX or nil
            local lookAtY = (self.tacticalTimer < 0.65) and aimY or nil
            self:steerTowards(dt, escapeX, escapeY, 1.15, 0, lookAtX, lookAtY)

            if self.tacticalTimer <= 0 or dist > 480 then
                self.tacticalPhase = "ENGAGE"
                self.tacticalTimer = 0
            end
        end

    -- =========================================================================
    -- ARQUETIPO 2: GUNSHIP o SENTINEL (Artillería Pesada con Telegrafía)
    -- =========================================================================
    elseif shipType == "GUNSHIP" or shipType == "SENTINEL" then
        local standoffDist = (shipType == "GUNSHIP") and 410 or 350
        local orbitX = tx - (dx / math.max(1, dist)) * standoffDist + (-dy / math.max(1, dist)) * 140 * self.strafeDir
        local orbitY = ty - (dy / math.max(1, dist)) * standoffDist + (dx / math.max(1, dist)) * 140 * self.strafeDir
        self:steerTowards(dt, orbitX, orbitY, 0.85, 45, aimX, aimY)

        local gunship = shipType == "GUNSHIP"
        self:updateTelegraph(dt, target, cue, aimX, aimY, dist, 780,
            gunship and .58 or .45, gunship and 1.35 or 1.10, .42)
        return

    -- =========================================================================
    -- ARQUETIPO 3: FIGHTER / EXPLORER / ESTÁNDAR (Órbita Dinámica con Derrape)
    -- =========================================================================
    else
        self.strafeSwitchTimer = self.strafeSwitchTimer - dt
        if self.strafeSwitchTimer <= 0 then
            -- No siempre invierte el strafe: 65% invierte, 35% mantiene para no ser un péndulo predecible
            if self:random() < 0.65 then
                self.strafeDir = -self.strafeDir
            end
            self.strafeSwitchTimer = self:random(1.5, 3.2)
        end

        local prefDist = (self.config.preferredDistance or 290) * self.pilotPersonality.aggressiveness
        local orbitOffset = self.wingmanOf and (110 + 38 * self.formationSlotIndex) or 165
        -- Punto deseado en órbita tangencial alrededor del objetivo (obliga a usar Drift para mirar al centro mientras se mueve por la tangente)
        local nx = dx / math.max(1, dist)
        local ny = dy / math.max(1, dist)
        local tangentX = -ny * self.strafeDir
        local tangentY = nx * self.strafeDir

        local desiredSlotX = tx - nx * prefDist + tangentX * orbitOffset
        local desiredSlotY = ty - ny * prefDist + tangentY * orbitOffset

        self:steerTowards(dt, desiredSlotX, desiredSlotY, 0.98, 45, aimX, aimY)
    end

    -- =========================================================================
    -- DISCIPLINA DE DISPARO POR RÁFAGAS (Evita cadencia robótica de metrónomo)
    -- =========================================================================
    if self.burstPauseTimer > 0 then
        self.burstPauseTimer = math.max(0, self.burstPauseTimer - dt)
        return
    end

    if dist <= 760 then
        local aimAngle = math.atan2(aimY - self.ship.y, aimX - self.ship.x) + (math.pi * 0.5)
        local angleDiff = math.abs((aimAngle - self.ship.rotation) % (math.pi * 2))
        if angleDiff > math.pi then angleDiff = (math.pi * 2) - angleDiff end

        if angleDiff < 0.44 and self.ship.shootAtWorld then
            local spread = (self.role == AIController.ROLES.SCAVENGER) and 32 or 16
            local shotX = aimX + (self:random() - 0.5) * spread
            local shotY = aimY + (self:random() - 0.5) * spread
            if self:fireCombatShot(target, cue, shotX, shotY) then
                self.burstShotsLeft = (self.burstShotsLeft or 3) - 1
                if self.burstShotsLeft <= 0 then
                    self:finishAttack(.24)
                    self.burstPauseTimer = self:random(self.config.burstPauseMin or 0.4, self.config.burstPauseMax or 0.85)
                    self.burstShotsLeft = math.floor(self:random(self.config.burstMin or 3, (self.config.burstMax or 5) + 0.9))
                end
            end
        end
    end
end

-- Ejecución del estado SURVIVE (Huida con Señuelo de Carga y Evasión)
function AIController:updateSurvive(dt)
    self.worldGoal.isWorking = false
    self.telegraphTimer = 0
    local threat = self.lastAttacker or self.combatTarget
    if not threat or not threat.x then
        self.state = AIController.STATES.WORLD_GOAL
        return
    end

    self:evaluateIncomingThreats(dt, threat)

    -- Si es un Recolector (SCAVENGER) en pánico y aún no ha soltado señuelo, suelta una caja de mineral para distraer al Corsario
    if self.role == AIController.ROLES.SCAVENGER and not self.panicJettisoned then
        self.panicJettisoned = true
        self:dropLoot(1, false)
    end

    local dx = self.ship.x - threat.x
    local dy = self.ship.y - threat.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 1450 then
        self.combatTarget = nil
        self.lastAttacker = nil
        self.state = AIController.STATES.WORLD_GOAL
        return
    end

    local nx = dx / math.max(1, dist)
    local ny = dy / math.max(1, dist)
    local weave = math.sin((love.timer and love.timer.getTime() or 0) * 4.5 + (self.ship.shipId or 1)) * 0.52
    local fleeX = self.ship.x + (nx - ny * weave) * 600
    local fleeY = self.ship.y + (ny + nx * weave) * 600

    self.ship.isBoostActive = true
    self:steerTowards(dt, fleeX, fleeY, 1.25, 0)
end

-- Ciclo principal de actualización de la IA
function AIController:update(dt)
    if not self.active or not self.ship then return end
    if self.state == AIController.STATES.DISABLED or self.state == AIController.STATES.DESTROYED or self.ship.isAbandoned or self.ship.isDestroyed then
        return
    end

    self.simTime = (self.simTime or 0) + dt
    local previousLease = self.attackLease or 0
    self.attackLease = math.max(0, previousLease - dt)
    self.attackRest = math.max(0, (self.attackRest or 0) - dt)
    if previousLease > 0 and self.attackLease == 0 then
        self.attackRest = math.max(self.attackRest, .35)
    end
    local previousState = self.state
    if previousState ~= AIController.STATES.COMBAT then self.tacticalRetreat = false end

    if self.combatMemoryTimer > 0 then
        self.combatMemoryTimer = math.max(0, self.combatMemoryTimer - dt)
    end
    if (self.satiatedTimer or 0) > 0 then
        self.satiatedTimer = math.max(0, self.satiatedTimer - dt)
    end
    if (self.hangarFlashTimer or 0) > 0 then
        self.hangarFlashTimer = math.max(0, self.hangarFlashTimer - dt)
    end
    if (self.warpInTimer or 0) > 0 then
        self.warpInTimer = math.max(0, self.warpInTimer - dt)
    end
    if (self.salvageScheduleTimer or 0) > 0 then
        self.salvageScheduleTimer = self.salvageScheduleTimer - dt
        if self.salvageScheduleTimer <= 0 then
            self.salvageScheduleTimer = 0
            if self.salvageSiteTarget and self.state ~= AIController.STATES.SURVIVE and self.state ~= AIController.STATES.COMBAT then
                local st = self.salvageSiteTarget
                self.worldGoal = {
                    type = "investigate_salvage",
                    targetX = st.x,
                    targetY = st.y,
                    targetEntity = st.wreck,
                    timer = 0,
                    maxTimer = 28.0,
                    isWorking = false
                }
                self.state = AIController.STATES.WORLD_GOAL
                self.salvageSiteTarget = nil
            end
        end
    end

    self.decisionTimer = self.decisionTimer - dt
    if self.decisionTimer <= 0 then
        local interval = self.decisionInterval
        local World = package.loaded['src.core.world']
        local player = World and World.getPlayer()
        if self.state == AIController.STATES.WORLD_GOAL and player
            and (player.x - self.ship.x)^2 + (player.y - self.ship.y)^2 > 1700^2 then
            interval = interval * 2
        end
        self.decisionTimer = interval
        self:evaluatePerception()
    end

    self.ship.isBoostActive = false
    self.ship._aiIsMoving = false
    if self.state ~= AIController.STATES.WORLD_GOAL then
        self.isTractorBeaming = false
    end

    if self.state == AIController.STATES.SURVIVE then
        self:updateSurvive(dt)
    elseif self.state == AIController.STATES.COMBAT then
        self:updateCombat(dt)
    elseif self.state == AIController.STATES.ALERT then
        self:updateAlert(dt)
    else
        self:updateWorldGoal(dt)
    end

    if self.state ~= previousState then self:recordCombat('state_' .. self.state, self.combatTarget) end
    if self.state ~= AIController.STATES.COMBAT then
        self.telegraphTimer, self.attackLease = 0, 0
    end

    -- Limitar velocidad máxima según capacidades de la nave
    local maxSpd = self.ship.maxSpeed or 80
    if self.ship.isBoostActive then
        maxSpd = maxSpd * (self.ship.boostMultiplier or 1.5)
    elseif self.ship.isDrifting then
        maxSpd = maxSpd * 1.10
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

-- Callback cuando la nave recibe daño
function AIController:onDamaged(damage, attacker)
    if not self.active or self.state == AIController.STATES.DISABLED or self.state == AIController.STATES.DESTROYED then return end

    if attacker and attacker ~= self.ship then
        self.lastAttacker = attacker
        self.combatTarget = attacker
        self.alertTarget = nil
        self.combatMemoryTimer = 10.0
        self.isTractorBeaming = false
        self.salvageScheduleTimer = 0

        -- Impulso evasivo inmediato al recibir impacto sorpresa
        if self.jukeTimer <= 0 and self.dodgeCooldown <= 0 then
            local side = (self:random() < 0.5) and 1 or -1
            local rot = self.ship.rotation or 0
            self.jukeDirX = math.cos(rot) * side
            self.jukeDirY = math.sin(rot) * side
            self.jukeTimer = 0.25
            self.dodgeCooldown = 0.85
            self.rcsThrustDir = side
        end

        local hpPct = (self.ship.stats and self.ship.stats:getHealthPercentage()) or 100
        if hpPct <= (self.config.fleeHealthRatio * 100) and self.config.fleeHealthRatio > 0 then
            self.state = AIController.STATES.SURVIVE
        else
            self.state = AIController.STATES.COMBAT
        end
    end
end

-- Suelta el botín físico al espacio exterior (y eyecta el botín robado si dropAllScavenged es true)
function AIController:dropLoot(numDrops, dropAllScavenged, playerKill)
    local ship = self.ship
    if not ship then return end
    local WorldItems = package.loaded['src.item_systems.world_items'] or require('src.item_systems.world_items')
    local ItemSystem = package.loaded['src.item_systems.item_system'] or require('src.item_systems.item_system')
    if WorldItems and WorldItems.drop and ItemSystem and ItemSystem.getItem then
        local dropTable = { "iron_ore", "energy_crystal", "repair_kit", "basic_circuit", "energy_stim" }
        numDrops = numDrops or 1
        local roll = playerKill and Loot.roll(self.lootProfile, self)[1]
        for i = 1, numDrops do
            local itemId = i == 1 and roll or dropTable[1 + ((i + (ship.shipId or 1)) % #dropTable)]
            local itemData = ItemSystem:getItem(itemId)
            if itemData then
                local angle = (i / math.max(1, numDrops or 1)) * math.pi * 2 + self:random(-0.35, 0.35)
                local tx = ship.x + math.cos(angle) * 48
                local ty = ship.y + math.sin(angle) * 48
                pcall(function() WorldItems.drop(itemData, ship.x, ship.y, tx, ty, 1) end)
            end
        end

        -- CAZADOR CAZADO: Al ser destruida o inutilizada la nave, soltar todo el botín acumulado/robado
        if dropAllScavenged ~= false and self.scavengedLoot and #self.scavengedLoot > 0 then
            print(string.format("[ECOSYSTEM] ¡CAZADOR CAZADO! %s soltó %d ítems previamente recolectados/robados.",
                ship.shipName or "Carroñero", #self.scavengedLoot))
            for _, loot in ipairs(self.scavengedLoot) do
                local itemData = loot.data or loot
                if itemData then
                    local angle = self:random(0, math.pi * 2)
                    local dist = self:random(40, 95)
                    local tx = ship.x + math.cos(angle) * dist
                    local ty = ship.y + math.sin(angle) * dist
                    local qty = loot.quantity or 1
                    pcall(function() WorldItems.drop(itemData, ship.x, ship.y, tx, ty, qty) end)
                end
            end
            self.scavengedLoot = {}
        elseif dropAllScavenged == false and self.scavengedLoot and #self.scavengedLoot > 0 then
            -- Soltar solo 1 ítem carroñado como señuelo de pánico
            local decoy = table.remove(self.scavengedLoot, 1)
            if decoy and decoy.data then
                local angle = self:random(0, math.pi * 2)
                local tx = ship.x + math.cos(angle) * 45
                local ty = ship.y + math.sin(angle) * 45
                pcall(function() WorldItems.drop(decoy.data, ship.x, ship.y, tx, ty, decoy.quantity or 1) end)
            end
        end

        -- Eyectar cualquier inventario residual en slots
        if dropAllScavenged ~= false and ship.inventory and ship.inventory.items then
            for slot = 1, (ship.inventory.maxSlots or 12) do
                local slotItem = ship.inventory.items[slot]
                if slotItem and slotItem.data then
                    local angle = self:random(0, math.pi * 2)
                    local dist = self:random(40, 95)
                    local tx = ship.x + math.cos(angle) * dist
                    local ty = ship.y + math.sin(angle) * dist
                    pcall(function() WorldItems.drop(slotItem.data, ship.x, ship.y, tx, ty, slotItem.quantity or 1) end)
                    ship.inventory.items[slot] = nil
                end
            end
        end
    end
end

-- Callback cuando el casco de la nave llega a 0:
--   - ~78% (100% en SENTINEL): Se destruye por completo.
--   - ~22%: Queda intacta pero completamente inmóvil (dx=0, dy=0, driftAngularSpeed=0), abordable en EVA.
function AIController:onKilled(attacker)
    if self.state == AIController.STATES.DISABLED or self.state == AIController.STATES.DESTROYED then return end

    self.active = false
    self.worldGoal.isWorking = false
    self.telegraphTimer = 0
    self.isTractorBeaming = false
    self.salvageScheduleTimer = 0

    local ship = self.ship
    if not ship then return end

    -- Colapso de Comando de Escuadrón (si esta nave era una Nodriza / Portanaves)
    local isMothership = (ship.shipConfig and ship.shipConfig.isMothership) or false
    if isMothership and self.escorts then
        for _, escort in ipairs(self.escorts) do
            if escort and not escort.isDestroyed and escort.aiController then
                escort.aiController.wingmanOf = nil
                escort.aiController.isReceivingCarrierShield = false
                if escort.aiController.role == AIController.ROLES.SCAVENGER then
                    escort.aiController.lastAttacker = attacker or escort.aiController.combatTarget
                    escort.aiController.state = AIController.STATES.SURVIVE
                end
            end
        end
    end

    local unmanned = ship.shipConfig and ship.shipConfig.unmanned
    local intactChance = unmanned and 0.0 or (self.config.intactChance or 0.22)
    local roll = self:random()

    local World = package.loaded['src.core.world']
    local Naves = package.loaded['src.entities.naves']
    local owner = attacker and (attacker.owner or attacker)
    local playerKill = owner and World and owner == World.getPlayer()

    if roll <= intactChance then
        self.state = AIController.STATES.DISABLED
        ship.isAI = false
        ship.isAbandoned = true
        ship.isImmobilized = true
        ship.isPiloted = false
        ship.isDrifting = false
        ship.engineGlow = 0

        ship.dx = 0
        ship.dy = 0
        ship.driftAngularSpeed = 0

        if ship.stats and ship.stats.health then
            ship.stats.health.currentHealth = math.max(2, math.floor(ship.stats.health.maxHealth * 0.18))
        end

        local drops = isMothership and 3 or 1
        self:dropLoot(drops, true, playerKill)

        local director = World and (World.get('director') or World.get('gameDirector'))
        if director and director.notifyDebrisSite then
            director:notifyDebrisSite(ship.x, ship.y, drops, ship)
        end

        if ship.addImpactEffect then
            ship:addImpactEffect(ship.x, ship.y, {0.3, 0.85, 1.0, 1.0})
        end

        print(string.format("[ECOSYSTEM] %s (%s) quedó INTACTA E INMÓVIL (%.0f%% roll) en (%.0f, %.0f) -> Abordable en EVA.",
            ship.shipName or "Nave", ship.shipType or "SHIP", roll * 100, ship.x, ship.y))
    else
        self.state = AIController.STATES.DESTROYED
        ship.isAI = false
        ship.isDestroyed = true
        ship.isAbandoned = false
        ship.isPiloted = false

        local drops = isMothership and 5 or ((self.role == AIController.ROLES.SCAVENGER) and 3 or 2)
        self:dropLoot(drops, true, playerKill)

        local director = World and (World.get('director') or World.get('gameDirector'))
        if director and director.notifyDebrisSite then
            director:notifyDebrisSite(ship.x, ship.y, drops, nil)
        end

        local audio = World and ((World.getAudio and World.getAudio()) or World.get('audio'))
        if audio and audio.play then
            pcall(function() audio:play('Thrusters_Explosion', { volume = 0.65 }) end)
        end

        if Naves and Naves.removeShip then
            Naves.removeShip(ship.shipId)
        end
        if World and World.removeEntity then
            World.removeEntity(ship)
        end

        print(string.format("[ECOSYSTEM] %s (%s) fue DESTRUIDA por completo en (%.0f, %.0f).",
            ship.shipName or "Nave", ship.shipType or "SHIP", ship.x, ship.y))
    end
end

AIController.onDisabled = AIController.onKilled

return AIController
