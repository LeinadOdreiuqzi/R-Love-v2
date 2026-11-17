local Phase = require 'src.gameplay.phase_system'
local BT = require('src.maps.biome_system').BiomeType
local Seed = require 'src.utils.seed_system'

local Catalog = {
    maxSpecialChance = .03,
    armoredConvoy = {
        name = 'Convoy blindado',
        ratesByBiome = {
            [BT.DEEP_SPACE] = {.25, .40, .60, .80},
            [BT.NEBULA_FIELD] = {.15, .30, .45, .60}
        }
    },
    salvageSite = {
        name = 'Contenedor sellado',
        ratesByBiome = {
            [BT.DEEP_SPACE] = {.80, 1, 1.20, 1.40},
            [BT.NEBULA_FIELD] = {.90, 1.10, 1.30, 1.50},
            [BT.ASTEROID_BELT] = {1, 1.20, 1.40, 1.60},
            [BT.GRAVITY_ANOMALY] = {.80, 1, 1.20, 1.40},
            [BT.RADIOACTIVE_ZONE] = {.70, .90, 1.10, 1.30},
            [BT.ANCIENT_RUINS] = {1.20, 1.40, 1.60, 1.80}
        }
    }
}

function Catalog.phaseForSector(cx, cy, stride)
    if not Phase.state.initialized then return Phase.state.currentPhase end
    local x, y = (cx + .5) * stride, (cy + .5) * stride
    for phase = 1, Phase.state.currentPhase do
        local bounds = Phase.getPhaseBounds(phase)
        if bounds and x >= bounds.minX and x < bounds.maxX and y >= bounds.minY and y < bounds.maxY then
            return phase
        end
    end
    if Phase.state.mapFullyUnlocked then return Phase.config.totalPhases end
end

function Catalog.chance(encounter, biome, phase)
    local rates = encounter.ratesByBiome[biome]
    if not rates or not phase then return 0 end
    local band = phase == 1 and 1 or phase <= 4 and 2 or phase <= 7 and 3 or 4
    return rates[band] / 100
end

local function sectorPriority(seed, cx, cy)
    local numeric = Seed.toNumeric(('%s:world-encounter:%d:%d'):format(seed, cx, cy))
    return love.math.newRandomGenerator(numeric):random()
end

function Catalog.select(seed, cx, cy, biome, phase)
    if cx == 0 and cy == 0 then return end
    local convoy = Catalog.chance(Catalog.armoredConvoy, biome, phase)
    local salvage = Catalog.chance(Catalog.salvageSite, biome, phase)
    assert(convoy + salvage <= Catalog.maxSpecialChance, 'Presupuesto de encuentros excedido')
    local priority = sectorPriority(seed, cx, cy)
    if priority >= convoy + salvage then return end
    -- Nearby sectors use the same priorities, independently of discovery order.
    for y = cy - 1, cy + 1 do
        for x = cx - 1, cx + 1 do
            if (x ~= cx or y ~= cy) and (x ~= 0 or y ~= 0) then
                local neighbor = sectorPriority(seed, x, y)
                if neighbor < priority or (neighbor == priority and (y < cy or (y == cy and x < cx))) then return end
            end
        end
    end
    return priority < convoy and 'armoredConvoy' or 'salvageSite'
end

return Catalog
