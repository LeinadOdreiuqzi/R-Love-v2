local MapConfig = require 'src.maps.config.map_config'

local TwinkleManager = {}

-- Configuración
local cfgTw = (MapConfig.stars and MapConfig.stars.twinkle) or {}
local PHASE_BINS = cfgTw.phaseBins or 32
local PULSE_BINS = cfgTw.pulseBins or 32
local BAND_INTERVAL = (MapConfig.stars and MapConfig.stars.twinkleCacheInterval) or 0.05

-- Estado de caché
local currentBand = -1
local twinkleTable = {}   -- [type][phaseBin] = intensidad
local pulseTable = {}     -- [type][phaseBin] = intensidad
TwinkleManager.stats = { updates = 0, lastUpdateMs = 0, avgUpdateMs = 0, phaseBins = PHASE_BINS, pulseBins = PULSE_BINS }

-- Tabla de senos (fallback si no existe la global)
local sinTable = nil
local function ensureSinTable()
    if not sinTable then
        sinTable = {}
        for i = 0, 359 do
            sinTable[i] = math.sin(math.rad(i))
        end
    end
end

-- Velocidades típicas por tipo (compartidas)
local typeTwinkleSpeed = cfgTw.typeTwinkleSpeed or { [1] = 0.8, [2] = 1.0, [3] = 1.2, [4] = 1.5, [5] = 1.1 }
local typePulseSpeed   = cfgTw.typePulseSpeed   or { [1] = 5.0, [2] = 5.2, [3] = 5.5, [4] = 6.0, [5] = 6.5 }
local TYPE_COUNT = math.max(#typeTwinkleSpeed, #typePulseSpeed)

-- Cuantizar fase a bin
function TwinkleManager.phaseBin(offset)
    local deg = ((offset or 0) * 57.29) % 360
    local binSize = 360 / PHASE_BINS
    local bin = math.floor(deg / binSize)
    if bin < 0 then bin = 0 end
    if bin >= PHASE_BINS then bin = PHASE_BINS - 1 end
    return bin
end

-- Actualizar tablas por banda de tiempo + slowdown por zoom
function TwinkleManager.update(time, zoom)
    ensureSinTable()
    local band = math.floor(time / BAND_INTERVAL)
    local slowdown = (zoom and zoom > 1.2) and math.max(0.2, 1.0 / math.sqrt(zoom)) or 1.0

    if band == currentBand and TwinkleManager._lastSlowdown == slowdown then
        return
    end

    currentBand = band
    TwinkleManager._lastSlowdown = slowdown
    local baseTime = band * BAND_INTERVAL * slowdown
    local t0 = love.timer.getTime()

    for t = 1, TYPE_COUNT do
        twinkleTable[t] = twinkleTable[t] or {}
        pulseTable[t] = pulseTable[t] or {}
        local twSpeed = typeTwinkleSpeed[t] or 1.0
        local pSpeed = typePulseSpeed[t] or 5.0

        for b = 0, PHASE_BINS - 1 do
            local phaseDeg = (baseTime * twSpeed) * 57.29 + (b * (360 / PHASE_BINS))
            local idx = math.floor(phaseDeg) % 360
            local tw = 0.6 + 0.4 * (sinTable[idx] or math.sin(math.rad(idx)))
            twinkleTable[t][b] = tw

            local pDeg = (baseTime * pSpeed) * 57.29 + (b * (360 / PULSE_BINS))
            local pIdx = math.floor(pDeg) % 360
            local pVal = 0.8 + 0.2 * (sinTable[pIdx] or math.sin(math.rad(pIdx)))
            pulseTable[t][b] = pVal
        end
    end
    local t1 = love.timer.getTime()
    local elapsedMs = (t1 - t0) * 1000.0
    TwinkleManager.stats.lastUpdateMs = elapsedMs
    TwinkleManager.stats.updates = TwinkleManager.stats.updates + 1
    local n = TwinkleManager.stats.updates
    TwinkleManager.stats.avgUpdateMs = ((TwinkleManager.stats.avgUpdateMs * (n - 1)) + elapsedMs) / n
end

function TwinkleManager.getTwinkle(typeId, phaseBin)
    local t = math.max(1, math.min(typeId or 1, TYPE_COUNT))
    local b = math.max(0, math.min(phaseBin or 0, PHASE_BINS - 1))
    return (twinkleTable[t] and twinkleTable[t][b]) or 0.8
end

function TwinkleManager.getPulse(typeId, phaseBin)
    local t = math.max(1, math.min(typeId or 1, TYPE_COUNT))
    local b = math.max(0, math.min(phaseBin or 0, PULSE_BINS - 1))
    return (pulseTable[t] and pulseTable[t][b]) or 1.0
end

return TwinkleManager