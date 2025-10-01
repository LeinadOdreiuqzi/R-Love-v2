-- src/gameplay/phase/expansion.lua
-- Actualización del sistema, expansión de fases y HUD/estado

local PhaseSystem = require 'src.gameplay.phase.core'

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