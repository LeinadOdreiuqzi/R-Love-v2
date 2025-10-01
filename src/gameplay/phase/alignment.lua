-- src/gameplay/phase/alignment.lua
-- Funciones de alineación y cálculo de límites de fases

local PhaseSystem = require 'src.gameplay.phase.core'

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

return PhaseSystem