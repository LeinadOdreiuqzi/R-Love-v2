-- src/gameplay/phase/boundaries.lua
-- Funciones relacionadas con límites y proximidad a bordes

local PhaseSystem = require 'src.gameplay.phase.core'

-- Calcular la distancia mínima a los límites de la fase actual
function PhaseSystem.getDistanceToCurrentPhaseBoundary(playerX, playerY)
    local bounds = PhaseSystem.getCurrentPhaseBounds()
    if not bounds then return math.huge end
    
    local distanceToEdge = math.min(
        math.abs(playerX - bounds.minX),
        math.abs(playerX - bounds.maxX),
        math.abs(playerY - bounds.minY),
        math.abs(playerY - bounds.maxY)
    )
    
    return distanceToEdge
end

-- Verificar si el jugador está cerca del límite de la fase actual
function PhaseSystem.isPlayerNearBoundary(playerX, playerY, threshold)
    threshold = threshold or PhaseSystem.config.boundaryThreshold
    
    local distance = PhaseSystem.getDistanceToCurrentPhaseBoundary(playerX, playerY)
    return distance <= threshold
end

-- Verificar si el jugador está en el límite exacto (para restricción de movimiento)
function PhaseSystem.isPlayerAtBoundary(playerX, playerY)
    local bounds = PhaseSystem.getCurrentPhaseBounds()
    if not bounds then return false end
    
    -- Verificar si está fuera de los límites
    return playerX < bounds.minX or playerX > bounds.maxX or
           playerY < bounds.minY or playerY > bounds.maxY
end

return PhaseSystem
