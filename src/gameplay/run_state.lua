-- src/gameplay/run_state.lua
-- Esqueleto de RunState: contenedor de datos de una "run" actual.
-- No introduce comportamiento jugable todavía; solo define API y estructura para futuras implementaciones.

local RunState = {}
RunState.__index = RunState

-- NUEVO: utilidades y versionado
local SeedSystem = require 'src.utils.seed_system'
RunState.__version = 1

-- Getter perezoso del World (evita require circular)
local function getWorld()
    return package.loaded['src.core.world']
end

function RunState:new(opts)
    local o = {
        seed = opts and opts.seed or 0,
        started = true,
        time = 0,                -- tiempo total de la run en segundos
        sector = 1,              -- placeholder para sector/área actual
        phase = "in_space",      -- NUEVO: fase de la run (in_space, docked, ended, etc.)
        resources = {            -- recursos base (placeholders)
            fuel = 0,
            credits = 0,
            data = 0
        },
        objectives = {},         -- objetivos activos (placeholder)
        meta = {                 -- NUEVO: métricas de telemetría (placeholders)
            distanceTravelled = 0,
            eventsTriggered = 0,
            fuelConsumed = 0,
            damageTaken = 0,
            boostsUsed = 0,
            timeByBiome = {},
        },
        paused = false,
        rng = nil,               -- NUEVO: RNG determinista por run
        version = RunState.__version,
        debug = false            -- NUEVO: bandera de debug
    }
    setmetatable(o, self)

    -- Inicializar RNG determinista a partir de la semilla (alfanumérica o numérica)
    local numericSeed = type(o.seed) == 'number' and o.seed or SeedSystem.toNumeric(o.seed or "")
    if love and love.math and love.math.newRandomGenerator then
        o.rng = love.math.newRandomGenerator(numericSeed)
    else
        if SeedSystem and SeedSystem.makeRNG then
            o.rng = SeedSystem.makeRNG(numericSeed)
        end
    end

    return o
end

-- Ciclo principal
-- playerSpeed: velocidad escalar opcional pasada por el caller (evita acceso a _G)
function RunState:update(dt, playerSpeed)
    if self.paused then return end
    self.time = self.time + (dt or 0)
    
    -- Actualizar distancia recorrida
    -- Prioridad: argumento del caller > World > _G.player (compatibilidad legada)
    local speed = playerSpeed
    if not speed then
        local w = getWorld()
        local p = (w and w.getPlayer()) or _G.player
        if p and p.dx and p.dy then
            speed = math.sqrt(p.dx * p.dx + p.dy * p.dy)
        end
    end
    if speed then
        self.meta.distanceTravelled = self.meta.distanceTravelled + (speed * (dt or 0) * 0.01)
    end
end

-- Métodos para actualizar métricas
function RunState:addDistance(distance)
    self.meta.distanceTravelled = self.meta.distanceTravelled + (distance or 0)
end

function RunState:incrementBoosts()
    self.meta.boostsUsed = self.meta.boostsUsed + 1
end

function RunState:setSector(sector)
    self.sector = sector or self.sector
end

-- NUEVO: Gestión de fase
function RunState:setPhase(phase)
    self.phase = phase or self.phase
end

function RunState:getPhase()
    return self.phase
end

-- NUEVO: Utilidades de RNG determinista
function RunState:getRNG()
    return self.rng
end

function RunState:randf(a, b)
    a, b = a or 0, b or 1
    if not self.rng then
        return a + math.random() * (b - a)
    end
    if self.rng.randomRange then
        return self.rng:randomRange(a, b)
    end
    if self.rng.random then
        return a + self.rng:random() * (b - a)
    end
    return a + math.random() * (b - a)
end

function RunState:randi(a, b)
    a, b = a or 0, b or 1
    if not self.rng then
        return math.random(a, b)
    end
    if self.rng.randomInt then
        return self.rng:randomInt(a, b)
    end
    if self.rng.random then
        return self.rng:random(a, b)
    end
    return math.floor(a + math.random() * (b - a + 1))
end

-- API mínima para futuras integraciones
function RunState:reset(seed)
    self.seed = seed or self.seed
    self.time = 0
    self.sector = 1
    self.phase = "in_space"
    self.resources.fuel = 0
    self.resources.credits = 0
    self.resources.data = 0
    self.objectives = {}
    self.meta = { distanceTravelled = 0, eventsTriggered = 0, fuelConsumed = 0, damageTaken = 0, boostsUsed = 0, timeByBiome = {} }
    self.started = true
    self.paused = false
    -- Re-seed RNG
    local numericSeed = type(self.seed) == 'number' and self.seed or SeedSystem.toNumeric(self.seed or "")
    if love and love.math and love.math.newRandomGenerator then
        self.rng = love.math.newRandomGenerator(numericSeed)
    else
        if SeedSystem and SeedSystem.makeRNG then
            self.rng = SeedSystem.makeRNG(numericSeed)
        end
    end
end

function RunState:setPaused(p)
    self.paused = not not p
end

function RunState:isPaused()
    return self.paused
end

function RunState:getSeed()
    return self.seed
end

function RunState:getTime()
    return self.time
end

function RunState:getSector()
    return self.sector
end

function RunState:getResources()
    return self.resources
end

function RunState:setResources(res)
    if type(res) == 'table' then
        self.resources.fuel = math.max(0, res.fuel or self.resources.fuel)
        self.resources.credits = math.max(0, res.credits or self.resources.credits)
        self.resources.data = math.max(0, res.data or self.resources.data)
    end
end

-- NUEVO: helpers de recursos con clamps
function RunState:addFuel(amount)
    local a = amount or 0
    self.resources.fuel = math.max(0, (self.resources.fuel or 0) + a)
    if a < 0 then self.meta.fuelConsumed = math.max(0, (self.meta.fuelConsumed or 0) + (-a)) end
end

function RunState:consumeFuel(amount)
    self:addFuel(-(amount or 0))
end

function RunState:addCredits(amount)
    local a = amount or 0
    self.resources.credits = math.max(0, (self.resources.credits or 0) + a)
end

function RunState:spendCredits(amount)
    self:addCredits(-(amount or 0))
end

function RunState:addData(amount)
    local a = amount or 0
    self.resources.data = math.max(0, (self.resources.data or 0) + a)
end

-- NUEVO: métricas simples
function RunState:addDistance(d)
    self.meta.distanceTravelled = math.max(0, (self.meta.distanceTravelled or 0) + (d or 0))
end

function RunState:incrementEvents(n)
    self.meta.eventsTriggered = math.max(0, (self.meta.eventsTriggered or 0) + (n or 1))
end

-- Serialización simple (extendida)
function RunState:serialize()
    return {
        version = self.version or RunState.__version,
        seed = self.seed,
        time = self.time,
        sector = self.sector,
        phase = self.phase,
        resources = {
            fuel = self.resources.fuel,
            credits = self.resources.credits,
            data = self.resources.data
        },
        objectives = self.objectives,
        meta = self.meta,
        paused = self.paused,
        started = self.started,
    }
end

function RunState:deserialize(data)
    if type(data) ~= 'table' then return end
    self.version = data.version or RunState.__version
    self.seed = data.seed or self.seed
    self.time = data.time or 0
    self.sector = data.sector or 1
    self.phase = data.phase or "in_space"
    if type(data.resources) == 'table' then
        self.resources.fuel = data.resources.fuel or 0
        self.resources.credits = data.resources.credits or 0
        self.resources.data = data.resources.data or 0
    end
    self.objectives = data.objectives or {}
    self.meta = data.meta or { distanceTravelled = 0, eventsTriggered = 0, fuelConsumed = 0, damageTaken = 0, boostsUsed = 0, timeByBiome = {} }
    self.paused = not not data.paused
    self.started = data.started ~= false

    -- Re-seed RNG para consistencia tras cargar
    local numericSeed = type(self.seed) == 'number' and self.seed or SeedSystem.toNumeric(self.seed or "")
    if love and love.math and love.math.newRandomGenerator then
        self.rng = love.math.newRandomGenerator(numericSeed)
    else
        if SeedSystem and SeedSystem.makeRNG then
            self.rng = SeedSystem.makeRNG(numericSeed)
        end
    end
end

-- NUEVO: utilidades de debug
function RunState:dump()
    return {
        seed = self.seed,
        time = self.time,
        sector = self.sector,
        phase = self.phase,
        paused = self.paused,
        resources = self.resources,
        meta = self.meta
    }
end

return RunState