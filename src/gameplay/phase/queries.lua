-- src/gameplay/phase/queries.lua
-- Funciones de consulta de límites y strings descriptivos

local PhaseSystem = require 'src.gameplay.phase.core'

-- Obtener los límites de una fase específica
function PhaseSystem.getPhaseBounds(phase)
    if not phase or phase < 1 or phase > PhaseSystem.config.totalPhases then
        return nil
    end
    return PhaseSystem.phaseBounds[phase]
end

-- Obtener los límites de la fase actual
function PhaseSystem.getCurrentPhaseBounds()
    -- Permitir límites temporales para modos especiales (p.ej., subniveles)
    if PhaseSystem.state and PhaseSystem.state.temporaryBounds then
        return PhaseSystem.state.temporaryBounds
    end
    return PhaseSystem.getPhaseBounds(PhaseSystem.state.currentPhase)
end

-- Obtener string descriptivo de los límites de una fase
function PhaseSystem.getBoundsString(phase)
    local bounds = PhaseSystem.getPhaseBounds(phase)
    if not bounds then return "Invalid phase" end
    
    return string.format("%.0f to %.0f (size: %.0f)", 
                        bounds.minX, bounds.maxX, bounds.size)
end

return PhaseSystem