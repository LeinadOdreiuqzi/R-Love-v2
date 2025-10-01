-- src/gameplay/phase/coordinates.lua
-- Inicialización y funciones relacionadas con coordenadas

local PhaseSystem = require 'src.gameplay.phase.core'

-- Referencia al sistema de coordenadas (se carga dinámicamente)
local CoordinateSystem = nil

-- Inicializar el sistema de fases
function PhaseSystem.init()
    print("=== PHASE SYSTEM INITIALIZING ===")
    
    -- Cargar el sistema de coordenadas dinámicamente
    if not CoordinateSystem then
        local success, cs = pcall(require, "src.maps.coordinate_system")
        if success then
            CoordinateSystem = cs
            print("PhaseSystem: CoordinateSystem loaded successfully")
        else
            print("PhaseSystem: Warning - Could not load CoordinateSystem, using absolute coordinates")
        end
    end
    
    -- Calcular baseSize alineado con chunks
    if PhaseSystem.config.chunkAlignment.enabled then
        PhaseSystem.calculateAlignedBaseSize()
    else
        -- Fallback al valor por defecto si la alineación está deshabilitada
        PhaseSystem.config.baseSize = 50000
    end
    
    -- Calcular los límites de cada fase basados en Fibonacci
    PhaseSystem.calculatePhaseBounds()
    
    -- Inicializar estado
    PhaseSystem.state.initialized = true
    PhaseSystem.state.currentPhase = 1
    PhaseSystem.state.maxUnlockedPhase = 1
    PhaseSystem.state.playerCanExpand = false
    PhaseSystem.state.playerAtBoundary = false
    PhaseSystem.state.expansionAvailable = false
    
    print("Phase System initialized with " .. PhaseSystem.config.totalPhases .. " phases")
    print("Phase 1 bounds: " .. PhaseSystem.getBoundsString(1))
    print("Base size: " .. PhaseSystem.config.baseSize .. ", Boundary threshold: " .. PhaseSystem.config.boundaryThreshold)
    
    return true
end

-- Convertir coordenadas del jugador a coordenadas del mundo si es necesario
function PhaseSystem.getWorldCoordinates(x, y)
    if CoordinateSystem then
        -- Si tenemos el sistema de coordenadas, convertir a coordenadas del mundo
        return CoordinateSystem.relativeToWorld(x, y)
    else
        -- Si no, asumir que ya son coordenadas del mundo
        return x, y
    end
end

-- Verificar si una posición está dentro de los límites de una fase
function PhaseSystem.isPositionInPhase(x, y, phase)
    -- Si el mapa está completamente desbloqueado, todas las posiciones son válidas
    if PhaseSystem.state.mapFullyUnlocked then
        return true
    end
    
    local bounds = PhaseSystem.getPhaseBounds(phase)
    if not bounds then return false end
    
    -- Convertir a coordenadas del mundo si es necesario
    local worldX, worldY = PhaseSystem.getWorldCoordinates(x, y)
    
    -- CORRECCIÓN: Implementar tolerancia para manejar discrepancias de precisión
    -- Calcular tolerancia basada en el stride de chunks (aproximadamente 10% del stride)
    local tolerance = PhaseSystem.config.chunkAlignment.chunkStride * 0.1
    
    return worldX >= (bounds.minX - tolerance) and worldX <= (bounds.maxX + tolerance) and 
           worldY >= (bounds.minY - tolerance) and worldY <= (bounds.maxY + tolerance)
end

-- Verificar si una posición está dentro de la fase actual
function PhaseSystem.isPositionInCurrentPhase(x, y)
    -- Si el mapa está completamente desbloqueado, permitir cualquier posición
    if PhaseSystem.state.mapFullyUnlocked then
        return true
    end
    
    local bounds = PhaseSystem.getCurrentPhaseBounds()
    if not bounds then return false end
    
    -- Convertir a coordenadas del mundo si es necesario
    local worldX, worldY = PhaseSystem.getWorldCoordinates(x, y)
    
    -- CORRECCIÓN: Implementar tolerancia para manejar discrepancias de precisión
    -- Calcular tolerancia basada en el stride de chunks (aproximadamente 10% del stride)
    local tolerance = PhaseSystem.config.chunkAlignment.chunkStride * 0.1
    
    return worldX >= (bounds.minX - tolerance) and worldX <= (bounds.maxX + tolerance) and 
           worldY >= (bounds.minY - tolerance) and worldY <= (bounds.maxY + tolerance)
end

-- Restringir posición del jugador a los límites de la fase actual
function PhaseSystem.clampPlayerToCurrentPhase(playerX, playerY)
    local bounds = PhaseSystem.getCurrentPhaseBounds()
    if not bounds then return playerX, playerY end
    
    -- Convertir a coordenadas del mundo
    local worldX, worldY = PhaseSystem.getWorldCoordinates(playerX, playerY)
    
    -- Restringir a los límites
    worldX = math.max(bounds.minX, math.min(bounds.maxX, worldX))
    worldY = math.max(bounds.minY, math.min(bounds.maxY, worldY))
    
    -- Convertir de vuelta a coordenadas relativas si es necesario
    if CoordinateSystem then
        return CoordinateSystem.worldToRelative(worldX, worldY)
    else
        return worldX, worldY
    end
end

return PhaseSystem