-- src/gameplay/phase_system.lua
-- Sistema de fases basado en sucesión de Fibonacci para delimitar secciones del mapa
-- Integrado con el sistema de coordenadas relativas del juego

local PhaseSystem = {}

-- Referencia al sistema de coordenadas (se carga dinámicamente)
local CoordinateSystem = nil

-- Configuración del sistema de fases
PhaseSystem.config = {
    totalPhases = 11,
    baseSize = nil,  -- Se calculará dinámicamente para alinearse con chunks
    currentPhase = 1,
    phaseTransitionActive = false,
    expansionRequested = false,
    boundaryThreshold = 5000,  -- Distancia para considerar "cerca del límite"
    restrictMovement = true,   -- Si debe restringir el movimiento del jugador
    -- Configuración para alineación con chunks
    chunkAlignment = {
        enabled = true,
        chunksPerPhaseBase = 12,  -- Número base de chunks por fase (12x12 = 144 chunks)
        chunkStride = 4096,       -- Stride calculado: (64 * 32) * 2.0 = 4096
        autoCalculate = true      -- Calcular automáticamente el stride desde MapConfig
    }
}

-- Sucesión de Fibonacci para las 11 fases
-- Secuencia modificada para evitar fases duplicadas (empezar con 1, 2 en lugar de 1, 1)
PhaseSystem.fibonacciSequence = {1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144}

-- Límites de cada fase calculados (en coordenadas del mundo)
PhaseSystem.phaseBounds = {}

-- Estado del sistema
PhaseSystem.state = {
    initialized = false,
    currentPhase = 1,
    maxUnlockedPhase = 1,
    playerCanExpand = false,
    lastPlayerPosition = {x = 0, y = 0},
    lastPlayerWorldPosition = {x = 0, y = 0},
    playerAtBoundary = false,
    expansionAvailable = false,
    mapFullyUnlocked = false,  -- Nuevo: indica si el mapa está completamente liberado
    showUnlockPrompt = false,  -- Nuevo: indica si mostrar el prompt para liberar el mapa
    -- Variables para feedback visual
    recentExpansion = false,   -- Indica si hubo una expansión reciente
    expansionTimer = 0,        -- Timer para mostrar el feedback de expansión
    expansionDuration = 3.0,   -- Duración del feedback de expansión (3 segundos)
    showExpansionPrompt = false, -- Indica si mostrar "E para expandir el mapa"
    lastExpandedPhase = 0      -- Última fase que fue expandida
}

-- Calcular el stride de chunks desde MapConfig
function PhaseSystem.calculateChunkStride()
    local success, MapConfig = pcall(require, "src.maps.config.map_config")
    if success and MapConfig and MapConfig.chunk then
        local chunkSize = MapConfig.chunk.size or 64
        local tileSize = MapConfig.chunk.tileSize or 32
        local worldScale = MapConfig.chunk.worldScale or 2.0
        local spacing = MapConfig.chunk.spacing or 0
        
        local stride = (chunkSize * tileSize + spacing) * worldScale
        PhaseSystem.config.chunkAlignment.chunkStride = stride
        
        print("PhaseSystem: Calculated chunk stride = " .. stride)
        return stride
    else
        print("PhaseSystem: Warning - Could not load MapConfig, using default stride")
        return PhaseSystem.config.chunkAlignment.chunkStride
    end
end

-- Calcular el baseSize alineado con chunks
function PhaseSystem.calculateAlignedBaseSize()
    local stride = PhaseSystem.config.chunkAlignment.chunkStride
    local chunksPerPhase = PhaseSystem.config.chunkAlignment.chunksPerPhaseBase
    
    if PhaseSystem.config.chunkAlignment.autoCalculate then
        stride = PhaseSystem.calculateChunkStride()
    end
    
    -- Calcular baseSize como múltiplo exacto del stride
    local baseSize = stride * chunksPerPhase
    PhaseSystem.config.baseSize = baseSize
    
    print("PhaseSystem: Aligned baseSize = " .. baseSize .. " (stride: " .. stride .. ", chunks: " .. chunksPerPhase .. ")")
    return baseSize
end

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

-- Verificar alineación entre chunks y límites de fase
function PhaseSystem.verifyChunkAlignment()
    if not PhaseSystem.config.chunkAlignment.enabled then
        return true
    end
    
    local stride = PhaseSystem.config.chunkAlignment.chunkStride
    local baseSize = PhaseSystem.config.baseSize
    
    print("=== CHUNK ALIGNMENT VERIFICATION ===")
    print("Chunk stride: " .. stride)
    print("Base size: " .. baseSize)
    print("Base size / stride: " .. (baseSize / stride))
    print("Is aligned: " .. tostring(baseSize % stride == 0))
    
    for phase = 1, math.min(5, PhaseSystem.config.totalPhases) do
        local fibValue = PhaseSystem.fibonacciSequence[phase]
        local size = baseSize * fibValue
        local halfSize = size / 2
        local chunksFromCenter = halfSize / stride
        
        print("Phase " .. phase .. ": Size=" .. size .. ", HalfSize=" .. halfSize .. 
              ", Chunks from center=" .. chunksFromCenter .. 
              ", Is aligned=" .. tostring(halfSize % stride == 0))
    end
    print("=====================================")
    
    return baseSize % stride == 0
end

-- Calcular los límites de cada fase usando la sucesión de Fibonacci
function PhaseSystem.calculatePhaseBounds()
    PhaseSystem.phaseBounds = {}
    
    for phase = 1, PhaseSystem.config.totalPhases do
        local fibValue = PhaseSystem.fibonacciSequence[phase]
        local size = PhaseSystem.config.baseSize * fibValue
        local halfSize = size / 2
        
        PhaseSystem.phaseBounds[phase] = {
            minX = -halfSize,
            maxX = halfSize,
            minY = -halfSize,
            maxY = halfSize,
            size = size,
            fibValue = fibValue
        }
        
        print("Phase " .. phase .. ": Fibonacci=" .. fibValue .. ", Size=" .. size .. 
              " (bounds: " .. (-halfSize) .. " to " .. halfSize .. ")")
    end
    
    -- Verificar alineación después de calcular los límites
    PhaseSystem.verifyChunkAlignment()
end

-- Obtener los límites de una fase específica
function PhaseSystem.getPhaseBounds(phase)
    if not phase or phase < 1 or phase > PhaseSystem.config.totalPhases then
        return nil
    end
    return PhaseSystem.phaseBounds[phase]
end

-- Obtener los límites de la fase actual
function PhaseSystem.getCurrentPhaseBounds()
    return PhaseSystem.getPhaseBounds(PhaseSystem.state.currentPhase)
end

-- Obtener string descriptivo de los límites de una fase
function PhaseSystem.getBoundsString(phase)
    local bounds = PhaseSystem.getPhaseBounds(phase)
    if not bounds then return "Invalid phase" end
    
    return string.format("%.0f to %.0f (size: %.0f)", 
                        bounds.minX, bounds.maxX, bounds.size)
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

-- Actualizar el sistema de fases
function PhaseSystem.update(dt, playerX, playerY)
    if not PhaseSystem.state.initialized then return end
    
    -- Si el mapa está completamente desbloqueado, bloquear todas las funcionalidades del phase manager
    if PhaseSystem.state.mapFullyUnlocked then
        -- Solo actualizar posiciones para mantener compatibilidad con otros sistemas
        PhaseSystem.state.lastPlayerPosition.x = playerX
        PhaseSystem.state.lastPlayerPosition.y = playerY
        local worldX, worldY = PhaseSystem.getWorldCoordinates(playerX, playerY)
        PhaseSystem.state.lastPlayerWorldPosition.x = worldX
        PhaseSystem.state.lastPlayerWorldPosition.y = worldY
        
        -- Asegurar que todos los prompts estén desactivados
        PhaseSystem.state.showUnlockPrompt = false
        PhaseSystem.state.showExpansionPrompt = false
        PhaseSystem.state.playerCanExpand = false
        PhaseSystem.state.expansionAvailable = false
        PhaseSystem.state.playerAtBoundary = false
        PhaseSystem.state.recentExpansion = false
        
        return "map_unlocked"
    end
    
    -- Actualizar posición del jugador (relativa)
    PhaseSystem.state.lastPlayerPosition.x = playerX
    PhaseSystem.state.lastPlayerPosition.y = playerY
    
    -- Actualizar posición del jugador (mundo)
    local worldX, worldY = PhaseSystem.getWorldCoordinates(playerX, playerY)
    PhaseSystem.state.lastPlayerWorldPosition.x = worldX
    PhaseSystem.state.lastPlayerWorldPosition.y = worldY
    
    -- Verificar estado del jugador respecto a los límites
    local nearBoundary = PhaseSystem.isPlayerNearBoundary(playerX, playerY)
    local atBoundary = PhaseSystem.isPlayerAtBoundary(playerX, playerY)
    local canUnlockNext = PhaseSystem.state.currentPhase < PhaseSystem.config.totalPhases
    local inCurrentPhase = PhaseSystem.isPositionInCurrentPhase(playerX, playerY)
    
    -- Actualizar estado
    PhaseSystem.state.playerAtBoundary = atBoundary
    PhaseSystem.state.playerCanExpand = nearBoundary and canUnlockNext and inCurrentPhase
    PhaseSystem.state.expansionAvailable = canUnlockNext and nearBoundary
    
    -- Verificar si estamos en la última fase y cerca del borde
    if PhaseSystem.isAtFinalPhase() and nearBoundary and not PhaseSystem.state.mapFullyUnlocked then
        PhaseSystem.state.showUnlockPrompt = true
    else
        PhaseSystem.state.showUnlockPrompt = false
    end
    
    -- Actualizar feedback visual para expansiones normales
    if PhaseSystem.state.recentExpansion then
        PhaseSystem.state.expansionTimer = PhaseSystem.state.expansionTimer - dt
        if PhaseSystem.state.expansionTimer <= 0 then
            PhaseSystem.state.recentExpansion = false
            PhaseSystem.state.expansionTimer = 0
        end
    end
    
    -- Mostrar prompt de expansión cuando el jugador puede expandir (no en la fase final)
    if PhaseSystem.state.playerCanExpand and not PhaseSystem.isAtFinalPhase() then
        PhaseSystem.state.showExpansionPrompt = true
    else
        PhaseSystem.state.showExpansionPrompt = false
    end
    
    -- Manejar restricción de movimiento si está habilitada y el mapa no está liberado
    if PhaseSystem.config.restrictMovement and atBoundary and not PhaseSystem.state.playerCanExpand and not PhaseSystem.state.mapFullyUnlocked then
        -- El jugador está intentando salir de la fase sin poder expandir
        -- Esto se manejará en el sistema de movimiento del jugador
        return "boundary_hit"
    end
    
    -- Auto-expansión si el jugador está en la siguiente fase (fallback)
    if not inCurrentPhase and canUnlockNext then
        if PhaseSystem.isPositionInPhase(playerX, playerY, PhaseSystem.state.currentPhase + 1) then
            print("PhaseSystem: Auto-expanding to next phase (player reached next area)")
            PhaseSystem.expandToNextPhase()
            return "auto_expanded"
        end
    end
    
    return "normal"
end


-- Expandir a la siguiente fase
function PhaseSystem.expandToNextPhase()
    if PhaseSystem.state.currentPhase >= PhaseSystem.config.totalPhases then
        print("Cannot expand: Already at maximum phase (" .. PhaseSystem.config.totalPhases .. ")")
        return false
    end
    
    local oldPhase = PhaseSystem.state.currentPhase
    PhaseSystem.state.currentPhase = PhaseSystem.state.currentPhase + 1
    PhaseSystem.state.maxUnlockedPhase = math.max(PhaseSystem.state.maxUnlockedPhase, PhaseSystem.state.currentPhase)
    PhaseSystem.state.playerCanExpand = false
    
    -- Activar feedback visual de expansión
    PhaseSystem.state.recentExpansion = true
    PhaseSystem.state.expansionTimer = PhaseSystem.state.expansionDuration
    PhaseSystem.state.lastExpandedPhase = PhaseSystem.state.currentPhase
    
    print("=== PHASE EXPANSION ===")
    print("Expanded from Phase " .. oldPhase .. " to Phase " .. PhaseSystem.state.currentPhase)
    print("New bounds: " .. PhaseSystem.getBoundsString(PhaseSystem.state.currentPhase))
    
    -- Notificar a otros sistemas sobre la expansión
    PhaseSystem.onPhaseExpanded(oldPhase, PhaseSystem.state.currentPhase)
    
    return true
end

-- Callback cuando se expande una fase (para que otros sistemas reaccionen)
function PhaseSystem.onPhaseExpanded(oldPhase, newPhase)
    -- Este método puede ser usado por otros sistemas para reaccionar a la expansión
    -- Por ejemplo, el ChunkManager podría cargar más chunks
    
    -- Notificar al sistema de chunks si existe
    local ChunkManager = require 'src.maps.chunk_manager'
    if ChunkManager and ChunkManager.onPhaseExpanded then
        ChunkManager.onPhaseExpanded(oldPhase, newPhase, PhaseSystem.getCurrentPhaseBounds())
    end
    
    -- Notificar al mapa principal
    local Map = require 'src.maps.map'
    if Map and Map.onPhaseExpanded then
        Map.onPhaseExpanded(oldPhase, newPhase, PhaseSystem.getCurrentPhaseBounds())
    end
end

-- Manejar input para expansión de fase y liberación del mapa
function PhaseSystem.handleInput(key)
    if key == "e" then
        -- Si el mapa ya está completamente desbloqueado, no hacer nada
        if PhaseSystem.state.mapFullyUnlocked then
            return false
        end
        
        -- Prioridad 1: Liberar todo el mapa si estamos en la fase final
        if PhaseSystem.shouldShowUnlockPrompt() then
            return PhaseSystem.handleUnlockInput(key)
        -- Prioridad 2: Expandir a la siguiente fase si es posible
        elseif PhaseSystem.state.playerCanExpand then
            return PhaseSystem.expandToNextPhase()
        end
    end
    return false
end

-- Obtener información del estado actual
function PhaseSystem.getStatus()
    return {
        initialized = PhaseSystem.state.initialized,
        currentPhase = PhaseSystem.state.currentPhase,
        maxUnlockedPhase = PhaseSystem.state.maxUnlockedPhase,
        totalPhases = PhaseSystem.config.totalPhases,
        canExpand = PhaseSystem.state.playerCanExpand,
        currentBounds = PhaseSystem.getCurrentPhaseBounds(),
        playerPosition = PhaseSystem.state.lastPlayerPosition
    }
end

-- Obtener información para mostrar en el HUD
function PhaseSystem.getHUDInfo()
    if not PhaseSystem.state.initialized then
        return {
            currentPhase = 0,
            totalPhases = PhaseSystem.config.totalPhases,
            canExpand = false,
            boundsString = "Not initialized",
            status = "Initializing...",
            distanceToBoundary = 0,
            expansionAvailable = false
        }
    end
    
    local distance = PhaseSystem.getDistanceToCurrentPhaseBoundary(
        PhaseSystem.state.lastPlayerPosition.x, 
        PhaseSystem.state.lastPlayerPosition.y
    )
    
    local status = "Exploring"
    if PhaseSystem.state.mapFullyUnlocked then
        status = "Exploring" -- Cambiar a un mensaje neutro para evitar spam
    elseif PhaseSystem.state.showUnlockPrompt then
        status = "PRESS E TO UNLOCK FULL MAP!"
    elseif PhaseSystem.state.playerAtBoundary then
        status = "At boundary"
    elseif PhaseSystem.state.playerCanExpand then
        status = "Can expand (Press E)"
    elseif PhaseSystem.state.expansionAvailable then
        status = "Near boundary"
    end
    
    return {
        currentPhase = PhaseSystem.state.currentPhase,
        totalPhases = PhaseSystem.config.totalPhases,
        canExpand = PhaseSystem.state.playerCanExpand,
        boundsString = PhaseSystem.getBoundsString(PhaseSystem.state.currentPhase),
        status = status,
        distanceToBoundary = math.floor(distance),
        expansionAvailable = PhaseSystem.state.expansionAvailable,
        atBoundary = PhaseSystem.state.playerAtBoundary,
        worldPosition = {
            x = math.floor(PhaseSystem.state.lastPlayerWorldPosition.x),
            y = math.floor(PhaseSystem.state.lastPlayerWorldPosition.y)
        },
        mapFullyUnlocked = PhaseSystem.state.mapFullyUnlocked,
        showUnlockPrompt = PhaseSystem.state.showUnlockPrompt,
        isAtFinalPhase = PhaseSystem.isAtFinalPhase(),
        -- Nueva información para feedback visual
        recentExpansion = PhaseSystem.state.recentExpansion,
        expansionTimer = PhaseSystem.state.expansionTimer,
        showExpansionPrompt = PhaseSystem.state.showExpansionPrompt,
        lastExpandedPhase = PhaseSystem.state.lastExpandedPhase
    }
end

-- Función de debug para mostrar información detallada
function PhaseSystem.printDebugInfo()
    print("=== PHASE SYSTEM DEBUG ===")
    local status = PhaseSystem.getStatus()
    
    print("Current Phase: " .. status.currentPhase .. "/" .. status.totalPhases)
    print("Max Unlocked: " .. status.maxUnlockedPhase)
    print("Can Expand: " .. tostring(status.canExpand))
    print("Player Position: (" .. status.playerPosition.x .. ", " .. status.playerPosition.y .. ")")
    
    if status.currentBounds then
        print("Current Bounds: " .. PhaseSystem.getBoundsString(status.currentPhase))
        print("Fibonacci Value: " .. status.currentBounds.fibValue)
    end
    
    print("All Phase Bounds:")
    for i = 1, PhaseSystem.config.totalPhases do
        local prefix = (i == status.currentPhase) and ">>> " or "    "
        print(prefix .. "Phase " .. i .. ": " .. PhaseSystem.getBoundsString(i))
    end
end

-- Verificar si estamos en la última fase
function PhaseSystem.isAtFinalPhase()
    return PhaseSystem.state.currentPhase >= PhaseSystem.config.totalPhases
end

-- Verificar si el mapa está completamente liberado
function PhaseSystem.isMapFullyUnlocked()
    return PhaseSystem.state.mapFullyUnlocked
end

-- Liberar todo el mapa (eliminar todas las restricciones)
function PhaseSystem.unlockFullMap()
    PhaseSystem.state.mapFullyUnlocked = true
    PhaseSystem.state.showUnlockPrompt = false
    PhaseSystem.config.restrictMovement = false
    print("=== MAP FULLY UNLOCKED ===")
    print("All phase restrictions removed - infinite exploration enabled!")
    return true
end

-- Verificar si debe mostrar el prompt para liberar el mapa
function PhaseSystem.shouldShowUnlockPrompt()
    return PhaseSystem.state.showUnlockPrompt and not PhaseSystem.state.mapFullyUnlocked
end

-- Manejar input para liberar el mapa
function PhaseSystem.handleUnlockInput(key)
    if key == "e" and PhaseSystem.shouldShowUnlockPrompt() then
        return PhaseSystem.unlockFullMap()
    end
    return false
end

-- Función para resetear el sistema (útil para testing)
function PhaseSystem.reset()
    PhaseSystem.state.currentPhase = 1
    PhaseSystem.state.maxUnlockedPhase = 1
    PhaseSystem.state.playerCanExpand = false
    PhaseSystem.state.mapFullyUnlocked = false
    PhaseSystem.state.showUnlockPrompt = false
    PhaseSystem.config.restrictMovement = true
    print("Phase System reset to Phase 1")
end

return PhaseSystem