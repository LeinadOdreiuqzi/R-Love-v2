-- src/gameplay/game_director.lua
-- Esqueleto de GameDirector: orquestador del ritmo y generación de eventos.
-- API estable y mejores prácticas listas para futuras integraciones. No cambia el gameplay actual.

local GameDirector = {}
GameDirector.__index = GameDirector
local World = require 'src.core.world'
GameDirector.__version = 1

function GameDirector:new(runState, opts)
    local o = {
        runState = runState or nil,   -- referencia al RunState actual (opcional)
        enabled = true,
        paused = false,
        time = 0,
        version = GameDirector.__version,

        -- Reloj de lógica en pasos fijos (placeholder)
        tickRate = (opts and opts.tickRate) or 0.2, -- segundos por tick
        accumulator = 0,
        
        -- Estado de acciones del jugador (esqueleto para futuras implementaciones)
        playerActions = {
            isBoosting = false,
            isHyper = false,
            isInStation = false
        },

        -- Sistema de eventos (no-op por defecto)
        processEvents = false,        -- si es true, se procesará la cola
        eventQueue = {},              -- { { t = tiempoAbsoluto, type = string, payload = table }, ... }
        listeners = {},               -- listeners[type] = { fn1, fn2, ... }

        debug = false
    }
    return setmetatable(o, self)
end

-- Hook de ciclo: mantiene el reloj y soporte de fixed-step sin lógica jugable
function GameDirector:update(dt)
    if not self.enabled then return end
    if self.paused then return end
    if self.runState and self.runState.isPaused and self.runState:isPaused() then return end

    dt = dt or 0
    self.time = self.time + dt
    
    -- Sincronizar con el estado del jugador
    local player = World.get('player')
    if player then
        self.playerActions.isBoosting = player.isBoostActive or false
        -- Actualizar otras acciones según sea necesario
    end
    
    self.accumulator = self.accumulator + dt

    -- Fixed-step placeholder (no-op)
    while self.accumulator >= self.tickRate do
        self:tick(self.tickRate)
        self.accumulator = self.accumulator - self.tickRate
    end

    if self.processEvents then
        self:processEventQueue()
    end
end

-- Tick de lógica a paso fijo (placeholder para futuras implementaciones)
function GameDirector:tick(dt)
    -- Futuro: disparar eventos, spawn de POIs, etc.
end

-- NUEVO: Control de acciones del jugador
function GameDirector:setPlayerBoosting(boosting)
    self.playerActions.isBoosting = not not boosting
end

function GameDirector:setPlayerHyper(hyper)
    self.playerActions.isHyper = not not hyper
end

function GameDirector:setPlayerInStation(inStation)
    self.playerActions.isInStation = not not inStation
end

-- Placeholder para futuras métricas de juego

-- API mínima/expandida para futuras integraciones
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

-- Funciones de métricas eliminadas - placeholder para futuras implementaciones

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

-- Sistema de eventos (placeholders seguros)
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
        local ok = pcall(fn, payload)
        if not ok then
            -- evitar romper el juego por listeners
        end
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
    self.playerActions = {
        isBoosting = false,
        isHyper = false,
        isInStation = false
    }
end

-- Serialización sencilla/versionada
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
    self.threat = math.max(0, math.min(self.threatConfig.maxThreat, data.threat or 0))
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

-- Utilidad de debug
function GameDirector:dump()
    return {
        time = self.time,
        threat = self.threat,
        threatPercent = self:getThreatPercent(),
        threatLevel = self:getThreatLevel(),
        enabled = self.enabled,
        paused = self.paused,
        tickRate = self.tickRate,
        playerActions = self.playerActions,
        queueLen = self.eventQueue and #self.eventQueue or 0
    }
end

return GameDirector