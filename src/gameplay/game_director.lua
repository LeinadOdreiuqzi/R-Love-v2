-- src/gameplay/game_director.lua
-- Orquestador del Ecosistema Vivo Determinista por Seed y Eventos del Mundo.
-- Gestiona la población ecológica de chunks (Recolectores, Corsarios, Centinelas y
-- Escenas Post-Batalla) sin girar artificialmente en torno al jugador.

local GameDirector = {}
GameDirector.__index = GameDirector

local World = require 'src.core.world'
local SeedSystem = require 'src.utils.seed_system'
local AIController = require 'src.entities.ai_controller'

GameDirector.__version = 2

function GameDirector:new(runState, opts)
    local o = {
        runState = runState or nil,
        enabled = true,
        paused = false,
        time = 0,
        threat = 0,
        version = GameDirector.__version,

        -- Reloj de lógica en pasos fijos
        tickRate = (opts and opts.tickRate) or 0.2,
        accumulator = 0,

        -- Estado de acciones del jugador
        playerActions = {
            isBoosting = false,
            isHyper = false,
            isInStation = false
        },

        -- Estado del Ecosistema Vivo (Determinista por Seed y Normalizado por Bioma)
        ecosystem = {
            populatedChunks = {},     -- [chunkKey] = true
            chunkTimers = {},         -- [chunkKey] = timestamp
            chunkCooldown = 60,       -- Segundos antes de refrescar el tráfico ecológico de un sector
            populatedSectors = {},    -- [sectorKey] = true
            activeAgents = {},        -- Lista de naves con AIController activo
            maxActiveAgents = 28,     -- Presupuesto para fauna regional, rutas inter-chunk y batallas raras
            checkAccumulator = 0.65,  -- Evaluar en el primer frame sin espera artificial
            checkInterval = 0.85,     -- Evaluar chunks del mapa cada 0.85s
            initialSectorSeeded = false,
            lastMajorClashTime = -999,
            lastMajorClashX = nil,
            lastMajorClashY = nil,
            minTimeBetweenMajorClashes = 90,  -- Mínimo ~1.5 minutos entre batallas de flotas masivas pre-iniciadas
            minDistBetweenMajorClashes = 4500, -- Mínimo ~4500px entre zonas de guerra masivas pre-iniciadas
            debrisSites = {},
            lastOpportunisticScavTime = -999
        },

        -- Sistema de eventos
        processEvents = true,
        eventQueue = {},
        listeners = {},

        debug = false
    }
    local gd = setmetatable(o, self)
    gd:addListener("SPAWN_OPPORTUNISTIC_SCAVENGER", function(payload)
        gd:handleOpportunisticScavengerSpawn(payload)
    end)
    return gd
end

-- Obtiene la semilla numérica base de la run actual
function GameDirector:getNumericSeed()
    local seedStr = (self.runState and self.runState.seed) or World.get('seed') or "A1B2C3D4E5"
    return SeedSystem.toNumeric(seedStr)
end

-- Crea una nave controlada por IA y la registra en el mundo y en el ecosistema
function GameDirector:spawnEcologicalShip(x, y, shipType, role, rng, extraOpts)
    local Naves = package.loaded['src.entities.naves'] or require('src.entities.naves')
    if not Naves or not Naves.new then return nil end

    extraOpts = extraOpts or {}
    if shipType == "DREADNOUGHT" then shipType = "ECLIPSE" end
    local ship = Naves:new(x, y, shipType or "EXPLORER")
    ship.useStarterSprite = false
    ship.sprite = nil
    local ai = AIController:new(ship, {
        role = role,
        faction = extraOpts.faction,
        rng = rng,
        homeX = extraOpts.homeX or x,
        homeY = extraOpts.homeY or y,
        namePrefix = extraOpts.namePrefix,
        wingmanOf = extraOpts.wingmanOf,
        formationSlotIndex = extraOpts.formationSlotIndex,
        formationOffsetX = extraOpts.formationOffsetX,
        formationOffsetY = extraOpts.formationOffsetY,
        warpInTimer = extraOpts.warpInTimer or 0.90
    })
    ship.aiController = ai
    if ship.inventory then
        ship.inventory.isAI = true
    end
    if extraOpts.faction then
        ship.aiFaction = extraOpts.faction
    end
    if extraOpts.isFactionCombatant then
        ship.isFactionCombatant = true
    end
    if extraOpts.entryAngle then
        ship.transitAngle = extraOpts.entryAngle
        ship.rotation = extraOpts.entryAngle + math.pi * 0.5
        ship.prevRotation = ship.rotation
        local entrySpd = (ship.maxSpeed or 70) * 0.55
        ship.dx = math.cos(extraOpts.entryAngle) * entrySpd
        ship.dy = math.sin(extraOpts.entryAngle) * entrySpd
    end

    World.addEntity(ship)
    table.insert(self.ecosystem.activeAgents, ship)
    return ship
end

-- Alias para despliegue de hangares desde AIController
function GameDirector:spawnAgent(x, y, role, shipType, rng, extraOpts)
    return self:spawnEcologicalShip(x, y, shipType, role, rng, extraOpts)
end

-- Crea una Flota Nodriza (Portanaves Capital + Escuadrón de Escoltas sincronizado)
function GameDirector:spawnMothershipFleet(x, y, carrierType, role, rng, extraOpts)
    if not carrierType or carrierType == "DREADNOUGHT" then
        carrierType = "ECLIPSE"
    end
    extraOpts = extraOpts or {}
    if not role then
        if carrierType == "TITAN_EXCAVATOR" then
            role = AIController.ROLES.SCAVENGER
            extraOpts.faction = extraOpts.faction or "SIGNAL_AMBER"
        elseif carrierType == "ARK_MONOLITH" then
            role = AIController.ROLES.WARDEN
            extraOpts.faction = extraOpts.faction or "SIGNAL_CYAN"
        else
            role = AIController.ROLES.RAIDER
            extraOpts.faction = extraOpts.faction or "SIGNAL_VIOLET"
        end
    else
        if carrierType == "TITAN_EXCAVATOR" then
            extraOpts.faction = extraOpts.faction or "SIGNAL_AMBER"
        elseif carrierType == "ARK_MONOLITH" then
            extraOpts.faction = extraOpts.faction or "SIGNAL_CYAN"
        else
            extraOpts.faction = extraOpts.faction or "SIGNAL_VIOLET"
        end
    end
    if extraOpts.isFactionCombatant == nil then
        extraOpts.isFactionCombatant = true
    end

    local mothership = self:spawnEcologicalShip(x, y, carrierType, role, rng, extraOpts)
    if not mothership or not mothership.aiController then return nil, {} end
    mothership.aiController:pickNewWorldGoal()

    local escorts = {}
    local escortDefs = {}
    if carrierType == "TITAN_EXCAVATOR" then
        escortDefs = {
            { type = "SALVAGER", role = AIController.ROLES.SCAVENGER, ox = -125, oy = 75 },
            { type = "FIGHTER",  role = AIController.ROLES.NOMAD,     ox = 125,  oy = 75 }
        }
    elseif carrierType == "ARK_MONOLITH" then
        escortDefs = {
            { type = "SENTINEL", role = AIController.ROLES.WARDEN, ox = -135, oy = 0 },
            { type = "SENTINEL", role = AIController.ROLES.WARDEN, ox = 135,  oy = 0 }
        }
    else -- ECLIPSE
        escortDefs = {
            { type = "INTERCEPTOR", role = AIController.ROLES.RAIDER, ox = -115, oy = 85 },
            { type = "INTERCEPTOR", role = AIController.ROLES.RAIDER, ox = 115,  oy = 85 }
        }
    end

    for idx, ed in ipairs(escortDefs) do
        local escort = self:spawnEcologicalShip(x + ed.ox, y + ed.oy, ed.type, ed.role, rng, {
            wingmanOf = mothership,
            formationSlotIndex = idx,
            formationOffsetX = ed.ox,
            formationOffsetY = ed.oy,
            faction = extraOpts.faction,
            isFactionCombatant = extraOpts.isFactionCombatant,
            entryAngle = extraOpts.entryAngle
        })
        if escort and escort.aiController then
            escort.aiController:pickNewWorldGoal()
            table.insert(escorts, escort)
        end
    end

    mothership.aiController.escorts = escorts
    return mothership, escorts
end

-- Crea un Choque de Escuadrones Multi-Facción Espacioso:
-- scale == "MEDIUM" -> 4 vs 4 (8 naves, arena amplia de ~1320px)
-- scale == "MASSIVE" -> 7 vs 7 (14 naves) o 3 Facciones 5 vs 5 vs 4 (14 naves con Nodrizas, arena de ~1920px)
function GameDirector:spawnFleetClashEncounter(centerX, centerY, rng, scale)
    scale = scale or ((rng:random() < 0.45) and "MASSIVE" or "MEDIUM")

    -- Contexto físico en el centro de la disputa: pecios y recursos flotando
    self:spawnAftermathSite(centerX, centerY, rng)
    if scale == "MASSIVE" then
        local offAngle = rng:random() * math.pi * 2
        self:spawnAftermathSite(centerX + math.cos(offAngle) * 320, centerY + math.sin(offAngle) * 320, rng)
    end

    local factionTemplates = {
        {
            id = "SIGNAL_VIOLET",
            role = AIController.ROLES.RAIDER,
            flagships = { "GUNSHIP", "ECLIPSE" },
            subCommanders = { "GUNSHIP", "FIGHTER" },
            roster = { "INTERCEPTOR", "FIGHTER", "INTERCEPTOR", "GUNSHIP", "FIGHTER" }
        },
        {
            id = "SIGNAL_AMBER",
            role = AIController.ROLES.NOMAD,
            flagships = { "GUNSHIP", "TITAN_EXCAVATOR" },
            subCommanders = { "SALVAGER", "GUNSHIP" },
            roster = { "FIGHTER", "SALVAGER", "EXPLORER", "FIGHTER", "CARGO" }
        },
        {
            id = "SIGNAL_CYAN",
            role = AIController.ROLES.WARDEN,
            flagships = { "SENTINEL", "ARK_MONOLITH" },
            subCommanders = { "SENTINEL", "FIGHTER" },
            roster = { "SENTINEL", "EXPLORER", "FIGHTER", "SENTINEL", "INTERCEPTOR" }
        }
    }

    local idxA = 1 + math.floor(rng:random() * #factionTemplates) % #factionTemplates
    local idxB = 1 + ((idxA + math.floor(rng:random() * (#factionTemplates - 1))) % #factionTemplates)
    local idxC = 1
    for k = 1, #factionTemplates do
        if k ~= idxA and k ~= idxB then idxC = k break end
    end

    local facA = factionTemplates[idxA]
    local facB = factionTemplates[idxB]
    local facC = factionTemplates[idxC]

    local isThreeWay = (scale == "MASSIVE" and rng:random() < 0.40)
    local sepDist = (scale == "MASSIVE") and 940 or 660
    local lateralGap = (scale == "MASSIVE") and 225 or 175
    local rowDepthGap = (scale == "MASSIVE") and 195 or 145

    local axisAngle = rng:random() * math.pi * 2

    local function spawnFactionSquad(fx, fy, towardAngle, fDef, totalShips, forceMothership)
        local outList = {}
        local useMothership = forceMothership or (scale == "MASSIVE" and rng:random() < 0.80) or (rng:random() < 0.35)
        local flagType = useMothership and fDef.flagships[2] or fDef.flagships[1]

        local leader = self:spawnEcologicalShip(fx, fy, flagType, fDef.role, rng, {
            faction = fDef.id,
            isFactionCombatant = true,
            entryAngle = towardAngle,
            homeX = centerX,
            homeY = centerY
        })
        if leader then table.insert(outList, leader) end

        local escortCount = math.max(1, totalShips - 1)
        for i = 1, escortCount do
            local shipClass
            if i == 1 and scale == "MASSIVE" then
                shipClass = fDef.subCommanders[1 + (i % #fDef.subCommanders)]
            else
                shipClass = fDef.roster[1 + ((i - 1) % #fDef.roster)]
            end

            local side = (i % 2 == 0) and 1 or -1
            local wingRank = math.ceil(i / 2)
            local latDist = lateralGap * side * wingRank + (rng:random() - 0.5) * 45
            local backDist = rowDepthGap * ((i % 2) + 0.5) + (rng:random() - 0.5) * 40

            local spreadX = -math.sin(towardAngle) * latDist - math.cos(towardAngle) * backDist
            local spreadY =  math.cos(towardAngle) * latDist - math.sin(towardAngle) * backDist

            local member = self:spawnEcologicalShip(fx + spreadX, fy + spreadY, shipClass, fDef.role, rng, {
                faction = fDef.id,
                isFactionCombatant = true,
                wingmanOf = leader,
                formationSlotIndex = i,
                formationOffsetX = spreadX,
                formationOffsetY = spreadY,
                entryAngle = towardAngle,
                homeX = centerX,
                homeY = centerY
            })
            if member then table.insert(outList, member) end
        end

        if leader and leader.aiController then
            leader.aiController.escorts = outList
        end
        return outList
    end

    local ax = centerX - math.cos(axisAngle) * sepDist
    local ay = centerY - math.sin(axisAngle) * sepDist
    local bx = centerX + math.cos(axisAngle) * sepDist
    local by = centerY + math.sin(axisAngle) * sepDist

    local countPerSide = (scale == "MASSIVE") and (isThreeWay and 5 or 7) or 4
    local fleetA = spawnFactionSquad(ax, ay, axisAngle, facA, countPerSide, scale == "MASSIVE")
    local fleetB = spawnFactionSquad(bx, by, axisAngle + math.pi, facB, countPerSide, scale == "MASSIVE")
    local fleetC = {}

    if isThreeWay then
        local cAngle = axisAngle + math.pi * 0.66
        local cx = centerX + math.cos(cAngle) * sepDist
        local cy = centerY + math.sin(cAngle) * sepDist
        fleetC = spawnFactionSquad(cx, cy, cAngle + math.pi, facC, 4, false)
    end

    -- Emparejar duelos individuales cruzados SIN forzar lastAttacker (lastAttacker queda libre para quien dispare de verdad)
    local enemiesForA = {}
    for _, s in ipairs(fleetB) do table.insert(enemiesForA, s) end
    for _, s in ipairs(fleetC) do table.insert(enemiesForA, s) end

    local enemiesForB = {}
    for _, s in ipairs(fleetA) do table.insert(enemiesForB, s) end
    for _, s in ipairs(fleetC) do table.insert(enemiesForB, s) end

    local enemiesForC = {}
    for _, s in ipairs(fleetA) do table.insert(enemiesForC, s) end
    for _, s in ipairs(fleetB) do table.insert(enemiesForC, s) end

    local function assignIndividualDuels(squad, rivalPool)
        if #rivalPool == 0 then return end
        for i, ship in ipairs(squad) do
            local rival = rivalPool[1 + ((i - 1) % #rivalPool)]
            if ship.aiController and rival then
                ship.aiController.combatTarget = rival
                ship.aiController.lastAttacker = nil
                ship.aiController.combatMemoryTimer = 22.0
                ship.aiController.state = AIController.STATES.COMBAT
            end
        end
    end

    assignIndividualDuels(fleetA, enemiesForA)
    assignIndividualDuels(fleetB, enemiesForB)
    assignIndividualDuels(fleetC, enemiesForC)

    return fleetA, fleetB, fleetC
end

-- Crea un sitio post-batalla (Arqueología Espacial + Rastro de Escombros) determinista por Seed
function GameDirector:spawnAftermathSite(x, y, rng)
    local Naves = package.loaded['src.entities.naves'] or require('src.entities.naves')
    local WorldItems = package.loaded['src.item_systems.world_items'] or require('src.item_systems.world_items')
    local ItemSystem = package.loaded['src.item_systems.item_system'] or require('src.item_systems.item_system')
    if not Naves then return end

    local shipTypes = { "SALVAGER", "INTERCEPTOR", "GUNSHIP", "FIGHTER", "CARGO" }
    local chosenType = shipTypes[1 + math.floor((rng:random() * #shipTypes)) % #shipTypes]
    local wreck = Naves:new(x, y, chosenType)
    wreck.useStarterSprite = false
    wreck.sprite = nil
    wreck.isPiloted = false
    wreck.isAbandoned = true
    wreck.isImmobilized = true
    wreck.isAI = false
    wreck.dx = 0
    wreck.dy = 0
    wreck.driftAngularSpeed = 0

    -- Dejar el casco dañado como evidencia del combate previo
    if wreck.stats and wreck.stats.health then
        wreck.stats.health.currentHealth = math.max(2, math.floor(wreck.stats.health.maxHealth * (0.20 + rng:random() * 0.25)))
    end

    World.addEntity(wreck)

    -- Generar un rastro direccional de recursos ("Breadcrumb Trail" de leveldesigner.md)
    if WorldItems and WorldItems.drop and ItemSystem and ItemSystem.getItem then
        local trailAngle = rng:random() * math.pi * 2
        local lootPool = { "iron_ore", "energy_crystal", "shield_battery", "basic_circuit" }
        for i = 1, 3 do
            local dist = 55 * i + rng:random(-15, 15)
            local lx = x + math.cos(trailAngle) * dist
            local ly = y + math.sin(trailAngle) * dist
            local itemId = lootPool[1 + (i % #lootPool)]
            local itemData = ItemSystem:getItem(itemId)
            if itemData then
                pcall(function() WorldItems.drop(itemData, x, y, lx, ly, 1) end)
            end
        end
    end

    return wreck
end

-- Notifica al ecosistema sobre la creación de un nuevo sitio de escombros o pecios post-combate
function GameDirector:notifyDebrisSite(x, y, lootCount, wreckShip)
    if not x or not y then return end
    lootCount = lootCount or 1

    local now = self.time or 0
    if not self.ecosystem.debrisSites then
        self.ecosystem.debrisSites = {}
    end

    table.insert(self.ecosystem.debrisSites, {
        x = x,
        y = y,
        lootCount = lootCount,
        wreck = wreckShip,
        createdTime = now
    })

    -- 1. Buscar si hay algún carroñero ya activo en el sector (< 2200px)
    local bestScavenger = nil
    local bestDistSq = 2200 * 2200

    for _, agent in ipairs(self.ecosystem.activeAgents or {}) do
        if agent and not agent.isDestroyed and not agent.isAbandoned and agent.aiController then
            local ai = agent.aiController
            local isScavengerRole = (ai.role == AIController.ROLES.SCAVENGER) or (agent.shipType == "SALVAGER") or (agent.shipType == "CARGO")
            local isAvailable = (ai.state == AIController.STATES.WORLD_GOAL or (ai.state == AIController.STATES.COMBAT and (ai.combatMemoryTimer or 0) <= 6))
            if isScavengerRole and isAvailable then
                local dx = agent.x - x
                local dy = agent.y - y
                local dSq = dx * dx + dy * dy
                if dSq < bestDistSq then
                    bestDistSq = dSq
                    bestScavenger = ai
                end
            end
        end
    end

    if bestScavenger then
        -- Carroñero local en el sector: programar su llegada con un retraso natural (6.0 - 10.0s)
        -- para otorgar al jugador ventaja táctica y tiempo para recoger el botín inicial
        local delay = 6.0 + bestScavenger:random() * 4.0
        bestScavenger:scheduleSalvageOpportunistic(x, y, delay, wreckShip)
        return
    end

    -- 2. Si no hay carroñeros en el sector y hay suficiente botín (lootCount >= 2 o pecio intacto):
    -- Evaluar cooldown de aparición en el horizonte (mínimo 45s)
    local lastHorizonScav = self.ecosystem.lastOpportunisticScavTime or -999
    if (now - lastHorizonScav) >= 45 and #self.ecosystem.activeAgents < self.ecosystem.maxActiveAgents then
        self.ecosystem.lastOpportunisticScavTime = now
        local horizonDelay = 7.5 + (math.random() * 4.0)
        self:scheduleEvent(horizonDelay, "SPAWN_OPPORTUNISTIC_SCAVENGER", {
            targetX = x,
            targetY = y,
            wreck = wreckShip
        })
    end
end

-- Despliega un carroñero oportunista desde el anillo de horizonte para investigar un sitio de escombros
function GameDirector:handleOpportunisticScavengerSpawn(payload)
    if not payload or not payload.targetX or not payload.targetY then return end
    if #self.ecosystem.activeAgents >= self.ecosystem.maxActiveAgents then return end

    local player = World.get('player')
    local px = (player and player.x) or payload.targetX
    local py = (player and player.y) or payload.targetY

    local baseSeed = self:getNumericSeed()
    local rng = SeedSystem.makeRNG((baseSeed + math.floor((self.time or 0) * 100)) % 2147483647)

    -- Aparece en el Anillo de Horizonte (1480 - 1780 px del jugador o del sitio)
    local angle = rng:random() * math.pi * 2
    local dist = 1480 + rng:random() * 300
    local spawnX = payload.targetX + math.cos(angle) * dist
    local spawnY = payload.targetY + math.sin(angle) * dist

    local towardSiteAngle = math.atan2(payload.targetY - spawnY, payload.targetX - spawnX)

    local scavType = (rng:random() < 0.70) and "SALVAGER" or "CARGO"
    local scavShip = self:spawnEcologicalShip(spawnX, spawnY, scavType, AIController.ROLES.SCAVENGER, rng, {
        faction = "SIGNAL_AMBER",
        isFactionCombatant = true,
        entryAngle = towardSiteAngle,
        homeX = payload.targetX,
        homeY = payload.targetY
    })

    if scavShip and scavShip.aiController then
        scavShip.aiController.worldGoal = {
            type = "investigate_salvage",
            targetX = payload.targetX,
            targetY = payload.targetY,
            targetEntity = payload.wreck,
            timer = 0,
            maxTimer = 28.0,
            isWorking = false
        }
        print(string.format("[ECOSYSTEM] Carroñero Oportunista %s detectó escombros en (%.0f, %.0f) y se aproxima desde el horizonte (%.0f, %.0f).",
            scavShip.shipName or scavType, payload.targetX, payload.targetY, spawnX, spawnY))
    end
end

-- Limpia agentes autónomos muy lejanos o ya destruidos para mantener el rendimiento óptimo
function GameDirector:pruneDistantAgents(playerX, playerY, maxDist)
    local agents = self.ecosystem.activeAgents
    local maxDistSq = maxDist * maxDist

    for i = #agents, 1, -1 do
        local ship = agents[i]
        if not ship or ship.isPiloted or ship.isDestroyed or ship.isAbandoned then
            table.remove(agents, i)
        else
            local dx = (ship.x or 0) - playerX
            local dy = (ship.y or 0) - playerY
            local distSq = dx * dx + dy * dy
            if distSq > maxDistSq then
                local Naves = package.loaded['src.entities.naves']
                if Naves and Naves.removeShip then
                    Naves.removeShip(ship.shipId)
                end
                World.removeEntity(ship)
                table.remove(agents, i)
            end
        end
    end
end

-- Verifica si el mundo permite iniciar un conflicto mayor (4v4 o 7v7) respetando espaciado temporal y geográfico
function GameDirector:canTriggerMajorClash(x, y)
    local eco = self.ecosystem
    if (self.time or 0) - (eco.lastMajorClashTime or -999) < (eco.minTimeBetweenMajorClashes or 90) then
        return false
    end
    if eco.lastMajorClashX and eco.lastMajorClashY then
        local dx = x - eco.lastMajorClashX
        local dy = y - eco.lastMajorClashY
        local minDist = eco.minDistBetweenMajorClashes or 4500
        if (dx * dx + dy * dy) < (minDist * minDist) then
            return false
        end
    end
    return true
end

function GameDirector:registerMajorClash(x, y)
    self.ecosystem.lastMajorClashTime = self.time or 0
    self.ecosystem.lastMajorClashX = x
    self.ecosystem.lastMajorClashY = y
end

-- Obtiene el bioma del chunk y detecta si es una frontera territorial con otro bioma distinto
function GameDirector:getChunkBiomeAndBorder(cx, cy)
    local BiomeSystem = package.loaded['src.maps.biome_system'] or require('src.maps.biome_system')
    local BT = (BiomeSystem and BiomeSystem.BiomeType) or {
        DEEP_SPACE = 1, NEBULA_FIELD = 2, ASTEROID_BELT = 3,
        GRAVITY_ANOMALY = 4, RADIOACTIVE_ZONE = 5, ANCIENT_RUINS = 6
    }
    local mainBiome = BT.DEEP_SPACE
    if BiomeSystem and BiomeSystem.getBiomeForChunk then
        local ok, b = pcall(BiomeSystem.getBiomeForChunk, cx, cy)
        if ok and b then mainBiome = b end
    end

    local isBorder = false
    local neighborBiome = mainBiome
    if BiomeSystem and BiomeSystem.getBiomeForChunk then
        local offsets = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} }
        for _, off in ipairs(offsets) do
            local okN, nb = pcall(BiomeSystem.getBiomeForChunk, cx + off[1], cy + off[2])
            if okN and nb and nb ~= mainBiome then
                isBorder = true
                neighborBiome = nb
                break
            end
        end
    end

    return mainBiome, isBorder, neighborBiome, BT
end

-- Evalúa y puebla un chunk de forma determinista y balanceada por bioma,
-- asegurando presencia regular de enemigos recurrentes (Corsarios), mineros y nómadas
function GameDirector:populateChunkDeterministically(cx, cy, strideScaled, playerX, playerY)
    local key = tostring(cx) .. ":" .. tostring(cy)
    local lastPop = self.ecosystem.chunkTimers and self.ecosystem.chunkTimers[key]
    if lastPop and (self.time - lastPop) < (self.ecosystem.chunkCooldown or 60) then
        return
    end

    if #self.ecosystem.activeAgents >= self.ecosystem.maxActiveAgents then
        return
    end

    if not self.ecosystem.chunkTimers then self.ecosystem.chunkTimers = {} end
    self.ecosystem.chunkTimers[key] = self.time
    self.ecosystem.populatedChunks[key] = true

    local baseSeed = self:getNumericSeed()
    local chunkSeed = (baseSeed + cx * 73856093 + cy * 19349663) % 2147483647
    local rng = SeedSystem.makeRNG(chunkSeed)

    local chunkCenterX = (cx + 0.5) * strideScaled
    local chunkCenterY = (cy + 0.5) * strideScaled

    local Map = package.loaded['src.maps.map']
    local chunk = Map and Map.getChunkNonBlocking and Map.getChunkNonBlocking(cx, cy)

    -- 1. Si el chunk contiene una Estación Antigua, spawnear su custodio nativo (SENTINEL o ARK_MONOLITH)
    if chunk and chunk.specialObjects then
        for i = 1, #chunk.specialObjects do
            local obj = chunk.specialObjects[i]
            if obj and (obj.type == "ancient_station" or obj.type == "station") then
                local MapConfig = package.loaded['src.maps.config.map_config']
                local ws = (MapConfig and MapConfig.chunk and MapConfig.chunk.worldScale) or 1.0
                local stX = cx * strideScaled + (obj.x or 0) * ws
                local stY = cy * strideScaled + (obj.y or 0) * ws
                if rng:random() < 0.28 then
                    self:spawnMothershipFleet(stX + 460, stY - 380, "ARK_MONOLITH", AIController.ROLES.WARDEN, rng)
                else
                    self:spawnEcologicalShip(stX + 380, stY - 320, "SENTINEL", AIController.ROLES.WARDEN, rng, {
                        faction = "SIGNAL_CYAN",
                        isFactionCombatant = true,
                        homeX = stX,
                        homeY = stY
                    })
                end
                return
            end
        end
    end

    -- 2. Densidad Ecológica Normalizada por Bioma (El espacio tiene zonas tranquilas y zonas activas reales)
    local biome, isBorderChunk, _, BT = self:getChunkBiomeAndBorder(cx, cy)
    local activityDensityByBiome = {
        [BT.DEEP_SPACE]       = 0.58, -- Espacio profundo activo con tráfico comercial y piratería
        [BT.NEBULA_FIELD]     = 0.70, -- Alta actividad corsaria oculta en el gas
        [BT.ASTEROID_BELT]    = 0.75, -- Zona industrial minera y asaltos a cargueros
        [BT.GRAVITY_ANOMALY]  = 0.55,
        [BT.RADIOACTIVE_ZONE] = 0.60,
        [BT.ANCIENT_RUINS]    = 0.70
    }

    local isStartChunk = (cx == 0 and cy == 0)
    local activityChance = isStartChunk and 0.88 or (activityDensityByBiome[biome] or 0.60)
    if rng:random() > activityChance then
        return
    end

    -- 3. Posicionamiento en el Anillo de Horizonte (1420 - 1800 px del jugador):
    -- Fuera del borde de pantalla (cero pop-in), detectado por sensores HUD de horizonte
    -- y con rumbo hacia el sector para cruzarse de forma natural en los siguientes 10-25 segundos.
    local player = World.get('player')
    local px = playerX or (player and player.x)
    local py = playerY or (player and player.y)

    local spawnX, spawnY, transitAngle
    if px and py then
        local horizonAngle = rng:random() * math.pi * 2
        local horizonDist = 1420 + rng:random() * 380
        spawnX = px + math.cos(horizonAngle) * horizonDist
        spawnY = py + math.sin(horizonAngle) * horizonDist
        transitAngle = horizonAngle + math.pi + (rng:random() - 0.5) * 0.90
    else
        spawnX = chunkCenterX + (rng:random() - 0.5) * (strideScaled * 0.45)
        spawnY = chunkCenterY + (rng:random() - 0.5) * (strideScaled * 0.45)
        transitAngle = rng:random() * math.pi * 2
    end

    -- 4. Pirámide Ecológica Normalizada:
    --   0.00 - 0.56 (56%): Fauna Cotidiana Recurrente (Enemigos corsarios, mineros, centinelas y nómadas habituales)
    --   0.56 - 0.78 (22%): Escaramuza Dinámica / Asalto Corsario a Minero (combate orgánico entre facciones)
    --   0.78 - 0.88 (10%): Vestigio Espacial / Pecio con Carroñero o Trampa
    --   0.88 - 0.95 (7%):  Flota Nodriza Capital Regional
    --   0.95 - 1.00 (5%):  Gran Choque de Flotas (4v4 o 7v7 Masiva), sujeto a enfriamiento global
    local tierRoll = rng:random()

    if tierRoll < 0.56 then
        -- TIER 1: FAUNA COTIDIANA RECURRENTE (Enemigos y Civiles habituales)
        local raiderWeight = 0.45 -- 45% en Deep Space
        if biome == BT.NEBULA_FIELD then raiderWeight = 0.70
        elseif biome == BT.ASTEROID_BELT then raiderWeight = 0.40
        elseif biome == BT.ANCIENT_RUINS then raiderWeight = 0.35
        elseif biome == BT.RADIOACTIVE_ZONE then raiderWeight = 0.55 end

        local isHostileRaider = (rng:random() < raiderWeight)

        if isHostileRaider then
            -- CORSARIO HOSTIL (SIGNAL_VIOLET): Enemigo recurrente patrullando / cazando
            local raiderClasses = { "INTERCEPTOR", "FIGHTER", "INTERCEPTOR", "GUNSHIP" }
            local rClass = raiderClasses[1 + math.floor(rng:random() * #raiderClasses) % #raiderClasses]
            local raider = self:spawnEcologicalShip(spawnX, spawnY, rClass, AIController.ROLES.RAIDER, rng, {
                faction = "SIGNAL_VIOLET",
                isFactionCombatant = true,
                entryAngle = transitAngle
            })
            if raider and raider.aiController then raider.aiController:pickNewWorldGoal() end

            -- 35% de probabilidad de tener un segundo caza de apoyo (dúo corsario)
            if rng:random() < 0.35 then
                local wing = self:spawnEcologicalShip(spawnX + 160, spawnY - 110, "INTERCEPTOR", AIController.ROLES.RAIDER, rng, {
                    faction = "SIGNAL_VIOLET",
                    isFactionCombatant = true,
                    wingmanOf = raider,
                    formationOffsetX = 140,
                    formationOffsetY = -95,
                    entryAngle = transitAngle
                })
                if wing and wing.aiController then wing.aiController:pickNewWorldGoal() end
            end

        elseif biome == BT.ANCIENT_RUINS or (biome == BT.GRAVITY_ANOMALY and rng:random() < 0.50) then
            -- GUARDIÁN CENTINELA (SIGNAL_CYAN): Constructo antiguo vigilando el sector
            local sentinel = self:spawnEcologicalShip(spawnX, spawnY, "SENTINEL", AIController.ROLES.WARDEN, rng, {
                faction = "SIGNAL_CYAN",
                isFactionCombatant = true,
                homeX = spawnX,
                homeY = spawnY
            })
            if sentinel and sentinel.aiController then sentinel.aiController:pickNewWorldGoal() end

        elseif biome == BT.ASTEROID_BELT or rng:random() < 0.35 then
            -- MINERO INDUSTRIAL (SIGNAL_AMBER): Salvager extrayendo mineral o carguero
            local mainType = (rng:random() < 0.65) and "SALVAGER" or "CARGO"
            local miner = self:spawnEcologicalShip(spawnX, spawnY, mainType, AIController.ROLES.SCAVENGER, rng, {
                faction = "SIGNAL_AMBER",
                isFactionCombatant = true,
                entryAngle = transitAngle
            })
            if miner and miner.aiController then miner.aiController:pickNewWorldGoal() end

            if rng:random() < 0.40 then
                local partnerType = (mainType == "SALVAGER") and "CARGO" or "FIGHTER"
                local partnerRole = (partnerType == "FIGHTER") and AIController.ROLES.NOMAD or AIController.ROLES.SCAVENGER
                local partner = self:spawnEcologicalShip(spawnX + 175, spawnY - 120, partnerType, partnerRole, rng, {
                    faction = "SIGNAL_AMBER",
                    isFactionCombatant = true,
                    wingmanOf = miner,
                    formationOffsetX = 150,
                    formationOffsetY = -105,
                    entryAngle = transitAngle
                })
                if partner and partner.aiController then partner.aiController:pickNewWorldGoal() end
            end

        else
            -- VIAJERO / NÓMADA (SIGNAL_AMBER): Explorador o convoy comercial
            local tClass = (rng:random() < 0.60) and "EXPLORER" or "FIGHTER"
            local traveler = self:spawnEcologicalShip(spawnX, spawnY, tClass, AIController.ROLES.NOMAD, rng, {
                faction = "SIGNAL_AMBER",
                isFactionCombatant = true,
                entryAngle = transitAngle
            })
            if traveler and traveler.aiController then traveler.aiController:pickNewWorldGoal() end
        end

    elseif tierRoll < 0.78 then
        -- TIER 2: ESCARAMUZA DINÁMICA O ASALTO CORSARIO (Encuentro orgánico entre 2 facciones)
        -- Un corsario Violeta atacando a una nave minera o mercante Ámbar con contexto real
        local scavShip = self:spawnEcologicalShip(spawnX - 130, spawnY + 90, "SALVAGER", AIController.ROLES.SCAVENGER, rng, {
            faction = "SIGNAL_AMBER",
            isFactionCombatant = true,
            entryAngle = transitAngle
        })
        local raiderType = (rng:random() < 0.55) and "INTERCEPTOR" or "FIGHTER"
        local raiderShip = self:spawnEcologicalShip(spawnX + 220, spawnY - 140, raiderType, AIController.ROLES.RAIDER, rng, {
            faction = "SIGNAL_VIOLET",
            isFactionCombatant = true,
            entryAngle = transitAngle + math.pi * 0.8
        })

        if scavShip and raiderShip and raiderShip.aiController and scavShip.aiController then
            raiderShip.aiController.combatTarget = scavShip
            raiderShip.aiController.state = AIController.STATES.COMBAT
            raiderShip.aiController.combatMemoryTimer = 22.0
            scavShip.aiController.combatTarget = raiderShip
            scavShip.aiController.state = AIController.STATES.COMBAT
            scavShip.aiController.combatMemoryTimer = 22.0
        end

    elseif tierRoll < 0.88 then
        -- TIER 3: VESTIGIO ESPACIAL / PECIO A LA DERIVA (50% con carroñero o corsario examinando el botín)
        local wreck = self:spawnAftermathSite(spawnX, spawnY, rng)
        if rng:random() < 0.50 then
            local isRaider = (rng:random() < 0.45)
            local sType = isRaider and "INTERCEPTOR" or "SALVAGER"
            local sFac = isRaider and "SIGNAL_VIOLET" or "SIGNAL_AMBER"
            local sRole = isRaider and AIController.ROLES.RAIDER or AIController.ROLES.SCAVENGER
            local looter = self:spawnEcologicalShip(spawnX - 170, spawnY + 115, sType, sRole, rng, {
                faction = sFac,
                isFactionCombatant = true,
                entryAngle = transitAngle
            })
            if looter and looter.aiController and wreck then
                looter.aiController.worldGoal.type = "salvage_wreck"
                looter.aiController.worldGoal.targetX = wreck.x
                looter.aiController.worldGoal.targetY = wreck.y
                looter.aiController.worldGoal.targetEntity = wreck
            end
        end

    elseif tierRoll < 0.95 then
        -- TIER 4: FLOTA NODRIZA CAPITAL EN OPERACIÓN REGIONAL
        local carrierType = "ECLIPSE" -- Corsaria Violeta por defecto
        if biome == BT.ASTEROID_BELT then
            carrierType = (rng:random() < 0.65) and "TITAN_EXCAVATOR" or "ECLIPSE"
        elseif biome == BT.ANCIENT_RUINS or biome == BT.GRAVITY_ANOMALY then
            carrierType = (rng:random() < 0.70) and "ARK_MONOLITH" or "ECLIPSE"
        end
        self:spawnMothershipFleet(spawnX, spawnY, carrierType, nil, rng, {
            entryAngle = transitAngle
        })

    else
        -- TIER 5 (RARO ~5%): GRAN CHOQUE DE FLOTAS MULTI-FACCIÓN
        local clashX, clashY = spawnX, spawnY
        if px and py then
            local cDist = 2100 + rng:random() * 350
            local cAngle = transitAngle + math.pi
            clashX = px + math.cos(cAngle) * cDist
            clashY = py + math.sin(cAngle) * cDist
        end
        if self:canTriggerMajorClash(clashX, clashY) then
            local clashScale = (isBorderChunk and rng:random() < 0.40) and "MASSIVE" or "MEDIUM"
            self:registerMajorClash(clashX, clashY)
            self:spawnFleetClashEncounter(clashX, clashY, rng, clashScale)
        else
            -- Si el enfriamiento global de batallas está activo, degenera a pecio
            self:spawnAftermathSite(spawnX, spawnY, rng)
        end
    end
end

function GameDirector:update(dt)
    if not self.enabled then return end
    if self.paused then return end
    if self.runState and self.runState.isPaused and self.runState:isPaused() then return end

    dt = dt or 0
    self.time = self.time + dt

    local player = World.get('player')
    if player then
        self.playerActions.isBoosting = player.isBoostActive or false
    end

    self.accumulator = self.accumulator + dt

    while self.accumulator >= self.tickRate do
        self:tick(self.tickRate)
        self.accumulator = self.accumulator - self.tickRate
    end

    if self.processEvents then
        self:processEventQueue()
    end
end

function GameDirector:tick(dt)
    -- No poblar el overworld si estamos dentro de un subnivel o estación
    if self.playerActions.isInStation then return end
    local okSub, SubLevelManager = pcall(function() return require 'src.maps.systems.sublevel_manager' end)
    if okSub and SubLevelManager and SubLevelManager.getStatus then
        local status = SubLevelManager.getStatus()
        if status and status.active then return end
    end

    self.ecosystem.checkAccumulator = self.ecosystem.checkAccumulator + dt
    if self.ecosystem.checkAccumulator < self.ecosystem.checkInterval then
        return
    end
    self.ecosystem.checkAccumulator = 0

    local player = World.get('player')
    if not player or not player.x or not player.y then return end

    local MapConfig = package.loaded['src.maps.config.map_config']
    local ws = (MapConfig and MapConfig.chunk and MapConfig.chunk.worldScale) or 2.0
    local tileSize = (MapConfig and MapConfig.chunk and MapConfig.chunk.tileSize) or 32
    local chunkSize = (MapConfig and MapConfig.chunk and MapConfig.chunk.size) or 64
    local spacing = (MapConfig and MapConfig.chunk and MapConfig.chunk.spacing) or 0
    local strideScaled = ((chunkSize * tileSize) + spacing) * ws

    local activeEntity = (player.getActiveEntity and player:getActiveEntity()) or player
    local px, py = activeEntity.x or player.x, activeEntity.y or player.y

    -- 1. Mantener activas las entidades en un radio amplio (3800px)
    self:pruneDistantAgents(px, py, 3800)

    -- 2. Evaluar el sector actual del jugador para generar tráfico y vida ecológica
    local pcx = math.floor(px / strideScaled)
    local pcy = math.floor(py / strideScaled)
    self:populateChunkDeterministically(pcx, pcy, strideScaled, px, py)

    -- Si el jugador está cerca del borde con un chunk vecino (< 2600px del centro contiguo), evaluarlo también
    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (dx == 0 and dy == 0) then
                local ncx = pcx + dx
                local ncy = pcy + dy
                local nCenterX = (ncx + 0.5) * strideScaled
                local nCenterY = (ncy + 0.5) * strideScaled
                local distSq = (nCenterX - px)^2 + (nCenterY - py)^2
                if distSq <= (2600 * 2600) then
                    self:populateChunkDeterministically(ncx, ncy, strideScaled, px, py)
                end
            end
        end
    end
end

function GameDirector:setPlayerBoosting(boosting)
    self.playerActions.isBoosting = not not boosting
end

function GameDirector:setPlayerHyper(hyper)
    self.playerActions.isHyper = not not hyper
end

function GameDirector:setPlayerInStation(inStation)
    self.playerActions.isInStation = not not inStation
end

function GameDirector:setRunState(rs)
    self.runState = rs
end

function GameDirector:getRunState()
    return self.runState
end

function GameDirector:getRNG()
    if self.runState and self.runState.getRNG then
        return self.runState:getRNG()
    end
    return nil
end

function GameDirector:getTime()
    return self.time
end

function GameDirector:setEnabled(flag)
    self.enabled = not not flag
end

function GameDirector:isEnabled()
    return self.enabled
end

function GameDirector:setPaused(p)
    self.paused = not not p
end

function GameDirector:isPaused()
    return self.paused
end

function GameDirector:setTickRate(seconds)
    if type(seconds) == 'number' and seconds > 0 then
        self.tickRate = seconds
    end
end

function GameDirector:addListener(eventType, listener)
    if type(eventType) ~= 'string' or type(listener) ~= 'function' then return end
    self.listeners[eventType] = self.listeners[eventType] or {}
    table.insert(self.listeners[eventType], listener)
end

function GameDirector:removeListener(eventType, listener)
    local lst = self.listeners[eventType]
    if not lst then return end
    for i = #lst, 1, -1 do
        if lst[i] == listener then table.remove(lst, i) end
    end
end

function GameDirector:emit(eventType, payload)
    local lst = self.listeners[eventType]
    if not lst then return end
    for _, fn in ipairs(lst) do
        pcall(fn, payload)
    end
end

function GameDirector:scheduleEvent(timeFromNow, eventType, payload)
    local t = (self.time or 0) + math.max(0, timeFromNow or 0)
    table.insert(self.eventQueue, { t = t, type = eventType, payload = payload })
end

function GameDirector:processEventQueue()
    if not self.eventQueue or #self.eventQueue == 0 then return end
    local now = self.time or 0
    local remaining = {}
    for i = 1, #self.eventQueue do
        local ev = self.eventQueue[i]
        if ev and ev.t <= now then
            self:emit(ev.type, ev.payload)
        else
            table.insert(remaining, ev)
        end
    end
    self.eventQueue = remaining
end

function GameDirector:reset()
    self.time = 0
    self.threat = 0
    self.accumulator = 0
    self.eventQueue = {}
    self.ecosystem.populatedChunks = {}
    self.ecosystem.activeAgents = {}
    self.ecosystem.checkAccumulator = 0
    self.ecosystem.lastMajorClashTime = -999
    self.ecosystem.lastMajorClashX = nil
    self.ecosystem.lastMajorClashY = nil
    self.ecosystem.debrisSites = {}
    self.ecosystem.lastOpportunisticScavTime = -999
    self.playerActions = {
        isBoosting = false,
        isHyper = false,
        isInStation = false
    }
end

function GameDirector:serialize()
    return {
        version = self.version or GameDirector.__version,
        time = self.time,
        threat = self.threat,
        enabled = self.enabled,
        paused = self.paused,
        tickRate = self.tickRate,
        playerActions = self.playerActions
    }
end

function GameDirector:deserialize(data)
    if type(data) ~= 'table' then return end
    self.version = data.version or GameDirector.__version
    self.time = data.time or 0
    local maxThreat = (self.threatConfig and self.threatConfig.maxThreat) or math.huge
    self.threat = math.max(0, math.min(maxThreat, data.threat or 0))
    self.enabled = data.enabled ~= false
    self.paused = not not data.paused
    if type(data.tickRate) == 'number' and data.tickRate > 0 then
        self.tickRate = data.tickRate
    end
    if type(data.playerActions) == 'table' then
        self.playerActions = {
            isBoosting = not not data.playerActions.isBoosting,
            isHyper = not not data.playerActions.isHyper,
            isInStation = not not data.playerActions.isInStation
        }
    end
end

function GameDirector:dump()
    return {
        time = self.time,
        threat = self.threat or 0,
        enabled = self.enabled,
        paused = self.paused,
        tickRate = self.tickRate,
        playerActions = self.playerActions,
        activeAgents = self.ecosystem and #self.ecosystem.activeAgents or 0,
        queueLen = self.eventQueue and #self.eventQueue or 0
    }
end

return GameDirector
