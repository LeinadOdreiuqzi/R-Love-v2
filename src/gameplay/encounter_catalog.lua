local Phase = require 'src.gameplay.phase_system'
local BT = require('src.maps.biome_system').BiomeType

local Catalog = {
    armoredConvoy = {
        name = 'Convoy blindado',
        ratesByBiome = {
            [BT.DEEP_SPACE] = {2, 4, 6, 8},
            [BT.NEBULA_FIELD] = {1, 3, 5, 7}
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

return Catalog
