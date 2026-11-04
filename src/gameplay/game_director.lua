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

        -- Estado del Ecosistema Vivo (Determinista por Seed)
        ecosystem = {
            populatedChunks = {},     -- [chunkKey] = true
            activeAgents = {},        -- Lista de naves con AIController activo
            maxActiveAgents = 12,     -- Presupuesto máximo de agentes simultáneos en simulación
            checkAccumulator = 0,
            checkInterval = 1.0,      -- Evaluar chunks cada 1.0s
            initialSectorSeeded = false
        },

        -- Sistema de eventos
        processEvents = true,
        eventQueue = {},
        listeners = {},

        debug = false
    }
    return setmetatable(o, self)
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
    local ship = Naves:new(x, y, shipType or "EXPLORER")
    local ai = AIController:new(ship, {
        role = role,
        rng = rng,
        homeX = extraOpts.homeX or x,
        homeY = extraOpts.homeY or y,
        namePrefix = extraOpts.namePrefix
    })
    ship.aiController = ai

    -- Equipar arma acorde al rol ecológico si está disponible
    local ItemSystem = package.loaded['src.item_systems.item_system']
    if ItemSystem and ItemSystem.getItem and ship.weaponSystem then
        local weaponId = nil
        if role == AIController.ROLES.RAIDER then
            weaponId = (rng and rng:random() < 0.4) and "energy_shotgun" or "kinetic_assault_rifle"
        elseif role == AIController.ROLES.WARDEN then
            weaponId = "plasma_rifle"
        elseif role == AIController.ROLES.SCAVENGER then
            weaponId = "basic_laser_pistol"
        end
        if weaponId then
            local wData = ItemSystem:getItem(weaponId)
            if wData and ship.equipWeapon then
                pcall(function() ship:equipWeapon(wData, 1) end)
            end
        end
    end

    World.addEntity(ship)
    table.insert(self.ecosystem.activeAgents, ship)
    return ship
end

-- Crea un sitio post-batalla (Arqueología Espacial + Rastro de Escombros) determinista por Seed
function GameDirector:spawnAftermathSite(x, y, rng)
    local Naves = package.loaded['src.entities.naves'] or require('src.entities.naves')
    local WorldItems = package.loaded['src.item_systems.world_items']
    local ItemSystem = package.loaded['src.item_systems.item_system']
    if not Naves then return end

    local shipTypes = { "CARGO", "FIGHTER", "EXPLORER" }
    local chosenType = shipTypes[1 + math.floor((rng:random() * #shipTypes)) % #shipTypes]
    local wreck = Naves:new(x, y, chosenType)
    wreck.isPiloted = false
    wreck.isAbandoned = true
    wreck.isAI = false
    wreck.driftAngularSpeed = (rng:random() - 0.5) * 0.09

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

-- Limpia agentes autónomos muy lejanos para mantener el rendimiento óptimo
function GameDirector:pruneDistantAgents(playerX, playerY, maxDist)
    local agents = self.ecosystem.activeAgents
    local maxDistSq = maxDist * maxDist

    for i = #agents, 1, -1 do
        local ship = agents[i]
        if not ship or ship.isPiloted then
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

-- Evalúa y puebla un chunk de forma 100% determinista a partir de la Seed y la Ventana Cronológica
function GameDirector:populateChunkDeterministically(cx, cy, strideScaled)
    local key = tostring(cx) .. ":" .. tostring(cy)
    if self.ecosystem.populatedChunks[key] then return end
    self.ecosystem.populatedChunks[key] = true

    if #self.ecosystem.activeAgents >= self.ecosystem.maxActiveAgents then
        return
    end

    local baseSeed = self:getNumericSeed()
    local chunkSeed = (baseSeed + cx * 73856093 + cy * 19349663) % 2147483647
    local rng = SeedSystem.makeRNG(chunkSeed)

    -- En el chunk (0,0) de inicio creamos una escena ecológica inmediata pero controlada
    local chunkCenterX = (cx + 0.5) * strideScaled
    local chunkCenterY = (cy + 0.5) * strideScaled

    if cx == 0 and cy == 0 then
        -- Un Recolector trabajando cerca de (650, -350) y un Nómada o Corsario en el borde del chunk
        local scav = self:spawnEcologicalShip(620, -340, "CARGO", AIController.ROLES.SCAVENGER, rng)
        local raider = self:spawnEcologicalShip(1150, -520, "FIGHTER", AIController.ROLES.RAIDER, rng)
        if scav and scav.aiController then
            scav.aiController:pickNewWorldGoal()
        end
        if raider and raider.aiController then
            raider.aiController:pickNewWorldGoal()
        end
        return
    end

    -- Consultar el chunk y su bioma
    local Map = package.loaded['src.maps.map']
    local BiomeSystem = package.loaded['src.maps.biome_system']
    local chunk = Map and Map.getChunkNonBlocking and Map.getChunkNonBlocking(cx, cy)

    -- 1. Si el chunk contiene una Estación Antigua, spawnear un Centinela (WARDEN) custodiándola
    if chunk and chunk.specialObjects then
        for i = 1, #chunk.specialObjects do
            local obj = chunk.specialObjects[i]
            if obj and (obj.type == "ancient_station" or obj.type == "station") then
                local MapConfig = package.loaded['src.maps.config.map_config']
                local ws = (MapConfig and MapConfig.chunk and MapConfig.chunk.worldScale) or 1.0
                local stX = cx * strideScaled + (obj.x or 0) * ws
                local stY = cy * strideScaled + (obj.y or 0) * ws
                self:spawnEcologicalShip(stX + 220, stY - 180, "FIGHTER", AIController.ROLES.WARDEN, rng, {
                    homeX = stX,
                    homeY = stY
                })
                return
            end
        end
    end

    -- 2. Probabilidad determinista de actividad ecológica en este chunk (55%)
    local roll = rng:random()
    if roll > 0.55 then return end

    -- Capa Cronológica: el estado del suceso depende de la semilla y del bloque de tiempo de la run
    local timeBlock = math.floor((self.time or 0) / 90)
    local chronoPhase = (math.floor(rng:random() * 100) + timeBlock) % 3

    local spawnX = chunkCenterX + (rng:random() - 0.5) * (strideScaled * 0.55)
    local spawnY = chunkCenterY + (rng:random() - 0.5) * (strideScaled * 0.55)

    if chronoPhase == 0 then
        -- Fase A: Operación de recolección/exploración activa
        local ship = self:spawnEcologicalShip(spawnX, spawnY, "CARGO", AIController.ROLES.SCAVENGER, rng)
        if ship and ship.aiController then
            ship.aiController:pickNewWorldGoal()
        end
        if rng:random() < 0.45 then
            self:spawnEcologicalShip(spawnX + 280, spawnY - 160, "EXPLORER", AIController.ROLES.NOMAD, rng)
        end

    elseif chronoPhase == 1 then
        -- Fase B: Escaramuza en curso (Corsario emboscando a un Recolector o Nómada)
        local preyRole = (rng:random() < 0.7) and AIController.ROLES.SCAVENGER or AIController.ROLES.NOMAD
        local preyType = (preyRole == AIController.ROLES.SCAVENGER) and "CARGO" or "EXPLORER"
        local prey = self:spawnEcologicalShip(spawnX, spawnY, preyType, preyRole, rng)
        local raider = self:spawnEcologicalShip(spawnX + 380, spawnY + 140, "FIGHTER", AIController.ROLES.RAIDER, rng)
        if raider and raider.aiController and prey then
            raider.aiController.combatTarget = prey
            raider.aiController.state = AIController.STATES.COMBAT
        end

    else
        -- Fase C: Arqueología Espacial (Escena post-batalla con pecio dañado, rastro de recursos y un carroñero)
        local wreck = self:spawnAftermathSite(spawnX, spawnY, rng)
        if rng:random() < 0.65 then
            local scav = self:spawnEcologicalShip(spawnX - 320, spawnY + 240, "CARGO", AIController.ROLES.SCAVENGER, rng)
            if scav and scav.aiController and wreck then
                scav.aiController.worldGoal.type = "salvage_wreck"
                scav.aiController.worldGoal.targetX = wreck.x
                scav.aiController.worldGoal.targetY = wreck.y
                scav.aiController.worldGoal.targetEntity = wreck
            end
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

    -- 1. Limpiar agentes muy alejados (> 3 chunks de distancia)
    self:pruneDistantAgents(px, py, strideScaled * 3.0)

    -- 2. Evaluar y poblar de forma determinista el anillo de chunks alrededor del jugador
    local pcx = math.floor(px / strideScaled)
    local pcy = math.floor(py / strideScaled)

    for dy = -1, 1 do
        for dx = -1, 1 do
            self:populateChunkDeterministically(pcx + dx, pcy + dy, strideScaled)
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
