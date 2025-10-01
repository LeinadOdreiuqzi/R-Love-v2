-- src/gameplay/phase/core.lua
-- Núcleo del sistema de fases: tablas de configuración y estado

local PhaseSystem = {}

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

return PhaseSystem