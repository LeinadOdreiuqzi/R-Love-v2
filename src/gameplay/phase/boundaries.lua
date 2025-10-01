-- src/gameplay/phase/boundaries.lua
-- Funciones relacionadas con límites y proximidad a bordes

local PhaseSystem = require 'src.gameplay.phase.core'

-- Calcular la distancia mínima a los límites de la fase actual
function PhaseSystem.getDistanceToCurrentPhaseBoundary(playerX, playerY)
    local bounds = PhaseSystem.getCurrentPhaseBounds()
    if not bounds then return math.huge end
    
    -- Convertir a coordenadas del mundo
    local worldX, worldY = PhaseSystem.getWorldCoordinates(playerX, playerY)
    
    local distanceToEdge = math.min(
        math.abs(worldX - bounds.minX),
        math.abs(worldX - bounds.maxX),
        math.abs(worldY - bounds.minY),
        math.abs(worldY - bounds.maxY)
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
    
    -- Convertir a coordenadas del mundo
    local worldX, worldY = PhaseSystem.getWorldCoordinates(playerX, playerY)
    
    -- Verificar si está fuera de los límites
    return worldX < bounds.minX or worldX > bounds.maxX or 
           worldY < bounds.minY or worldY > bounds.maxY
end

return PhaseSystem