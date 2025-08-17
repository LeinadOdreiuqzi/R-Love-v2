-- src/maps/chunk_manager.lua
-- Sistema avanzado de gestión de chunks con pooling y priorización

local ChunkManager = {}
local CoordinateSystem = require 'src.maps.coordinate_system'
local BiomeSystem = require 'src.maps.biome_system'
local MapConfig = require 'src.maps.config.map_config'

-- Configuración del gestor de chunks
ChunkManager.config = {
    -- Tamaño de cada chunk
    chunkSize = 48,
    tileSize = 32,
    
    -- Gestión de memoria
    maxActiveChunks = 100,      -- Máximo de chunks activos
    maxCachedChunks = 200,      -- Máximo de chunks en cache
    poolSize = 50,              -- Tamaño del pool de chunks reutilizables
    
    -- Distancias de carga/descarga
    loadDistance = 3,           -- Distancia para cargar chunks
    unloadDistance = 6,         -- Distancia para descargar chunks
    preloadDistance = 2,        -- Distancia para precarga
    
    -- Prioridades de carga
    priority = {
        immediate = 1,          -- Chunk donde está el jugador
        adjacent = 2,           -- Chunks adyacentes
        visible = 3,            -- Chunks visibles en pantalla
        preload = 4,            -- Chunks de precarga
        background = 5          -- Chunks de fondo
    },
    
    -- Configuración de generación
    maxGenerationTime = 0.002,  -- Tiempo máximo por frame para generación (2ms)
    maxObjectsPerFrame = 100,   -- Objetos máximos a generar por frame
    
    -- Estadísticas
    enableStats = true
}

-- Estado del gestor
ChunkManager.state = {
    -- Chunks activos (completamente cargados)
    activeChunks = {},
    -- Chunks en cache (parcialmente cargados)
    cachedChunks = {},
    -- Pool de chunks reutilizables
    chunkPool = {},
    
    -- Queues de carga/descarga
    loadQueue = {},
    unloadQueue = {},
    generationQueue = {},
    
    -- Estado del jugador
    lastPlayerChunkX = 0,
    lastPlayerChunkY = 0,
    
    -- Estadísticas
    stats = {
        activeCount = 0,
        cachedCount = 0,
        poolCount = 0,
        loadRequests = 0,
        unloadRequests = 0,
        cacheHits = 0,
        cacheMisses = 0,
        generationTime = 0,
        lastFrameTime = 0
    }
}

-- Estructura de chunk
local ChunkStructure = {
    -- Identificación
    x = 0,
    y = 0,
    id = "",
    
    -- Estado
    status = "empty",      -- empty, generating, partial, complete
    lastAccess = 0,
    priority = 5,
    loadProgress = 0,      -- Progreso de carga 0-1
    
    -- Datos del chunk
    tiles = {},
    objects = {},
    biome = nil,
    specialObjects = {},
    
    -- Propiedades de renderizado
    bounds = {},
    visible = false,
    lodLevel = 0,
    
    -- Metadatos
    seed = 0,
    generated = false,
    version = 1
}

-- Inicializar el gestor de chunks
function ChunkManager.init(seed)
    ChunkManager.state.activeChunks = {}
    ChunkManager.state.cachedChunks = {}
    ChunkManager.state.chunkPool = {}
    ChunkManager.state.loadQueue = {}
    ChunkManager.state.unloadQueue = {}
    ChunkManager.state.generationQueue = {}
    
    -- Crear pool inicial de chunks
    for i = 1, ChunkManager.config.poolSize do
        local chunk = ChunkManager.createEmptyChunk()
        table.insert(ChunkManager.state.chunkPool, chunk)
    end
    
    -- Reset estadísticas
    ChunkManager.resetStats()
    
    print("ChunkManager initialized with pool size: " .. ChunkManager.config.poolSize)
end

-- Crear chunk vacío
function ChunkManager.createEmptyChunk()
    local chunk = {}
    for key, value in pairs(ChunkStructure) do
        if type(value) == "table" then
            chunk[key] = {}
        else
            chunk[key] = value
        end
    end
    return chunk
end

-- Obtener chunk del pool o crear uno nuevo
function ChunkManager.getChunkFromPool()
    if #ChunkManager.state.chunkPool > 0 then
        return table.remove(ChunkManager.state.chunkPool)
    else
        return ChunkManager.createEmptyChunk()
    end
end

-- Devolver chunk al pool
function ChunkManager.returnChunkToPool(chunk)
    if #ChunkManager.state.chunkPool < ChunkManager.config.poolSize then
        -- Limpiar chunk
        ChunkManager.cleanChunk(chunk)
        table.insert(ChunkManager.state.chunkPool, chunk)
        return true
    end
    return false
end

-- Limpiar chunk para reutilización
function ChunkManager.cleanChunk(chunk)
    chunk.tiles = {}
    chunk.objects = {}
    chunk.specialObjects = {}
    chunk.biome = nil
    chunk.status = "empty"
    chunk.loadProgress = 0
    chunk.generated = false
    chunk.visible = false
    chunk.lodLevel = 0
end

-- Generar ID único para chunk
function ChunkManager.generateChunkId(chunkX, chunkY)
    return string.format("chunk_%d_%d", chunkX, chunkY)
end

-- Calcular prioridad de carga basada en posición del jugador
function ChunkManager.calculatePriority(chunkX, chunkY, playerChunkX, playerChunkY)
    local dx = math.abs(chunkX - playerChunkX)
    local dy = math.abs(chunkY - playerChunkY)
    local distance = math.max(dx, dy)  -- Distancia de Chebyshev
    
    if distance == 0 then
        return ChunkManager.config.priority.immediate
    elseif distance == 1 then
        return ChunkManager.config.priority.adjacent
    elseif distance <= ChunkManager.config.loadDistance then
        return ChunkManager.config.priority.visible
    elseif distance <= ChunkManager.config.preloadDistance then
        return ChunkManager.config.priority.preload
    else
        return ChunkManager.config.priority.background
    end
end

-- Obtener chunk (principal función de acceso)
function ChunkManager.getChunk(chunkX, chunkY, playerX, playerY)
    local chunkId = ChunkManager.generateChunkId(chunkX, chunkY)
    local currentTime = love.timer.getTime()
    
    -- Verificar si está en chunks activos
    if ChunkManager.state.activeChunks[chunkId] then
        local chunk = ChunkManager.state.activeChunks[chunkId]
        chunk.lastAccess = currentTime
        ChunkManager.state.stats.cacheHits = ChunkManager.state.stats.cacheHits + 1
        return chunk
    end
    
    -- Verificar si está en cache
    if ChunkManager.state.cachedChunks[chunkId] then
        local chunk = ChunkManager.state.cachedChunks[chunkId]
        chunk.lastAccess = currentTime
        
        -- Promover a activo si está completo
        if chunk.status == "complete" then
            ChunkManager.state.cachedChunks[chunkId] = nil
            ChunkManager.state.activeChunks[chunkId] = chunk
            ChunkManager.state.stats.cacheHits = ChunkManager.state.stats.cacheHits + 1
            return chunk
        end
        
        ChunkManager.state.stats.cacheHits = ChunkManager.state.stats.cacheHits + 1
        return chunk
    end
    
    -- Cache miss - necesita cargar
    ChunkManager.state.stats.cacheMisses = ChunkManager.state.stats.cacheMisses + 1
    return ChunkManager.requestChunkLoad(chunkX, chunkY, playerX, playerY)
end

-- Solicitar carga de chunk
function ChunkManager.requestChunkLoad(chunkX, chunkY, playerX, playerY)
    local chunkId = ChunkManager.generateChunkId(chunkX, chunkY)
    
    -- Verificar si ya está en cola de carga
    for _, request in ipairs(ChunkManager.state.loadQueue) do
        if request.id == chunkId then
            return nil  -- Ya está siendo procesado
        end
    end
    
    -- Calcular prioridad
    local sizePixels = ChunkManager.config.chunkSize * ChunkManager.config.tileSize
    local stride = sizePixels + ((MapConfig and MapConfig.chunk and MapConfig.chunk.spacing) or 0)
    local ws = (MapConfig and MapConfig.chunk and MapConfig.chunk.worldScale) or 1
    local playerChunkX = math.floor(playerX / (stride * ws))
    local playerChunkY = math.floor(playerY / (stride * ws))
    
    local priority = ChunkManager.calculatePriority(chunkX, chunkY, playerChunkX, playerChunkY)
    
    -- Crear solicitud de carga
    local loadRequest = {
        id = chunkId,
        chunkX = chunkX,
        chunkY = chunkY,
        priority = priority,
        requestTime = love.timer.getTime()
    }
    
    -- Insertar en cola de carga ordenada por prioridad
    ChunkManager.insertLoadRequest(loadRequest)
    ChunkManager.state.stats.loadRequests = ChunkManager.state.stats.loadRequests + 1
    
    return nil  -- Chunk no disponible inmediatamente
end

-- Insertar solicitud de carga manteniendo orden por prioridad
function ChunkManager.insertLoadRequest(request)
    local inserted = false
    for i, existingRequest in ipairs(ChunkManager.state.loadQueue) do
        if request.priority < existingRequest.priority then
            table.insert(ChunkManager.state.loadQueue, i, request)
            inserted = true
            break
        end
    end
    
    if not inserted then
        table.insert(ChunkManager.state.loadQueue, request)
    end
end

-- Procesar cola de carga (llamar cada frame)
function ChunkManager.processLoadQueue(dt, maxTime)
    maxTime = maxTime or ChunkManager.config.maxGenerationTime
    local startTime = love.timer.getTime()
    local processedCount = 0
    
    while #ChunkManager.state.loadQueue > 0 and (love.timer.getTime() - startTime) < maxTime do
        local request = table.remove(ChunkManager.state.loadQueue, 1)
        
        -- Verificar si el chunk aún es relevante
        if ChunkManager.isChunkRelevant(request.chunkX, request.chunkY) then
            ChunkManager.generateChunk(request.chunkX, request.chunkY)
            processedCount = processedCount + 1
        end
        
        -- Limitar objetos procesados por frame
        if processedCount >= ChunkManager.config.maxObjectsPerFrame then
            break
        end
    end
    
    ChunkManager.state.stats.lastFrameTime = love.timer.getTime() - startTime
    return processedCount
end

-- Verificar si un chunk sigue siendo relevante
function ChunkManager.isChunkRelevant(chunkX, chunkY)
    local dx = math.abs(chunkX - ChunkManager.state.lastPlayerChunkX)
    local dy = math.abs(chunkY - ChunkManager.state.lastPlayerChunkY)
    local distance = math.max(dx, dy)
    
    return distance <= ChunkManager.config.unloadDistance
end

-- Generar chunk completamente
function ChunkManager.generateChunk(chunkX, chunkY)
    local chunkId = ChunkManager.generateChunkId(chunkX, chunkY)
    local chunk = ChunkManager.getChunkFromPool()
    
    -- Configurar chunk básico
    chunk.x = chunkX
    chunk.y = chunkY
    chunk.id = chunkId
    chunk.status = "generating"
    chunk.lastAccess = love.timer.getTime()
    chunk.generated = false
    
    -- Calcular bounds
    do
        local sizePixels = ChunkManager.config.chunkSize * ChunkManager.config.tileSize
        local spacing = (MapConfig and MapConfig.chunk and MapConfig.chunk.spacing) or 0
        local stride = sizePixels + spacing
        local left = chunkX * stride
        local top = chunkY * stride
        chunk.bounds = {
            left = left,
            top = top,
            right = left + stride,
            bottom = top + stride
        }
    end
    
    -- Generar contenido del chunk (delegado al sistema existente)
    ChunkManager.generateChunkContent(chunk)
    
    -- Marcar como completo
    chunk.status = "complete"
    chunk.loadProgress = 1.0
    chunk.generated = true
    
    -- Agregar a chunks activos
    ChunkManager.state.activeChunks[chunkId] = chunk
    ChunkManager.state.stats.activeCount = ChunkManager.state.stats.activeCount + 1
    
    return chunk
end

-- Generar contenido del chunk (integración con sistema existente)
function ChunkManager.generateChunkContent(chunk)
    local Map = require 'src.maps.map'
    
    -- Determinar bioma para este chunk
    local biomeInfo = BiomeSystem.getBiomeInfo(chunk.x, chunk.y)
    chunk.biome = biomeInfo
    
    -- Inicializar tiles
    chunk.tiles = {}
    for y = 0, ChunkManager.config.chunkSize - 1 do
        chunk.tiles[y] = {}
        for x = 0, ChunkManager.config.chunkSize - 1 do
            chunk.tiles[y][x] = 0  -- Empty by default
        end
    end
    
    -- Inicializar objetos
    chunk.objects = {
        stars = {},
        nebulae = {}
    }
    chunk.specialObjects = {}
    
    -- Generar usando el sistema existente del mapa
    local tempChunk = Map.generateChunk(chunk.x, chunk.y)
    
    -- Copiar datos generados
    chunk.tiles = tempChunk.tiles
    chunk.objects = tempChunk.objects
    chunk.specialObjects = tempChunk.specialObjects
    chunk.biome = tempChunk.biome
end

-- Actualizar gestión de chunks (llamar cada frame)
function ChunkManager.update(dt, playerX, playerY)
    local startTime = love.timer.getTime()
    
    -- Actualizar posición del jugador
    local sizePixels = ChunkManager.config.chunkSize * ChunkManager.config.tileSize
    local stride = sizePixels + ((MapConfig and MapConfig.chunk and MapConfig.chunk.spacing) or 0)
    local ws = (MapConfig and MapConfig.chunk and MapConfig.chunk.worldScale) or 1
    local playerChunkX = math.floor(playerX / (stride * ws))
    local playerChunkY = math.floor(playerY / (stride * ws))
    
    ChunkManager.state.lastPlayerChunkX = playerChunkX
    ChunkManager.state.lastPlayerChunkY = playerChunkY
    
    -- Procesar cola de carga
    ChunkManager.processLoadQueue(dt)
    
    -- Procesar descargas si es necesario
    if #ChunkManager.state.activeChunks > ChunkManager.config.maxActiveChunks * 0.9 then
        ChunkManager.processUnloadQueue(playerChunkX, playerChunkY)
    end
    
    -- Gestión de memoria si es necesario
    if #ChunkManager.state.cachedChunks > ChunkManager.config.maxCachedChunks * 0.9 then
        ChunkManager.cleanupCache()
    end
    
    ChunkManager.state.stats.generationTime = love.timer.getTime() - startTime
end

-- Procesar cola de descarga
function ChunkManager.processUnloadQueue(playerChunkX, playerChunkY)
    local toUnload = {}
    
    -- Encontrar chunks a descargar
    for chunkId, chunk in pairs(ChunkManager.state.activeChunks) do
        local distance = math.max(
            math.abs(chunk.x - playerChunkX),
            math.abs(chunk.y - playerChunkY)
        )
        
        if distance > ChunkManager.config.unloadDistance then
            table.insert(toUnload, {id = chunkId, chunk = chunk, distance = distance})
        end
    end
    
    -- Ordenar por distancia (más lejanos primero)
    table.sort(toUnload, function(a, b) return a.distance > b.distance end)
    
    -- Descargar chunks
    local unloadCount = 0
    local maxUnloads = 5  -- Limitar descargas por frame
    
    for _, unloadData in ipairs(toUnload) do
        if unloadCount >= maxUnloads then break end
        
        ChunkManager.unloadChunk(unloadData.id, unloadData.chunk)
        unloadCount = unloadCount + 1
    end
    
    ChunkManager.state.stats.unloadRequests = ChunkManager.state.stats.unloadRequests + unloadCount
end

-- Descargar chunk específico
function ChunkManager.unloadChunk(chunkId, chunk)
    -- Mover de activo a cache
    ChunkManager.state.activeChunks[chunkId] = nil
    ChunkManager.state.cachedChunks[chunkId] = chunk
    
    -- Reducir nivel de detalle para cache
    chunk.status = "cached"
    
    -- Actualizar estadísticas
    ChunkManager.state.stats.activeCount = ChunkManager.state.stats.activeCount - 1
    ChunkManager.state.stats.cachedCount = ChunkManager.state.stats.cachedCount + 1
end

-- Limpiar cache antiguo
function ChunkManager.cleanupCache()
    local cacheList = {}
    
    -- Crear lista ordenada por tiempo de acceso
    for chunkId, chunk in pairs(ChunkManager.state.cachedChunks) do
        table.insert(cacheList, {id = chunkId, chunk = chunk})
    end
    
    table.sort(cacheList, function(a, b) return a.chunk.lastAccess < b.chunk.lastAccess end)
    
    -- Remover chunks más antiguos
    local removeCount = math.max(0, #cacheList - ChunkManager.config.maxCachedChunks)
    
    for i = 1, removeCount do
        local chunkData = cacheList[i]
        ChunkManager.state.cachedChunks[chunkData.id] = nil
        ChunkManager.returnChunkToPool(chunkData.chunk)
        ChunkManager.state.stats.cachedCount = ChunkManager.state.stats.cachedCount - 1
    end
end

-- Obtener chunks visibles para renderizado
function ChunkManager.getVisibleChunks(camera)
    local visibleChunks = {}
    
    -- Calcular área visible
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    local margin = 100
    local worldLeft, worldTop = camera:screenToWorld(0 - margin, 0 - margin)
    local worldRight, worldBottom = camera:screenToWorld(screenWidth + margin, screenHeight + margin)
    
    local sizePixels = ChunkManager.config.chunkSize * ChunkManager.config.tileSize
    local stride = sizePixels + ((MapConfig and MapConfig.chunk and MapConfig.chunk.spacing) or 0)
    local ws = (MapConfig and MapConfig.chunk and MapConfig.chunk.worldScale) or 1
    local strideScaled = stride * ws
    local chunkStartX = math.floor(worldLeft / strideScaled)
    local chunkStartY = math.floor(worldTop / strideScaled)
    local chunkEndX = math.ceil(worldRight / strideScaled)
    local chunkEndY = math.ceil(worldBottom / strideScaled)
    
    -- Recopilar chunks visibles
    for chunkY = chunkStartY, chunkEndY do
        for chunkX = chunkStartX, chunkEndX do
            local chunkId = ChunkManager.generateChunkId(chunkX, chunkY)
            local chunk = ChunkManager.state.activeChunks[chunkId]
            
            if chunk and chunk.status == "complete" then
                chunk.visible = true
                table.insert(visibleChunks, chunk)
            end
        end
    end
    
    return visibleChunks, {
        startX = chunkStartX, startY = chunkStartY,
        endX = chunkEndX, endY = chunkEndY,
        worldLeft = worldLeft, worldTop = worldTop,
        worldRight = worldRight, worldBottom = worldBottom
    }
end

-- Obtener estadísticas del gestor
function ChunkManager.getStats()
    -- Actualizar contadores actuales
    ChunkManager.state.stats.activeCount = 0
    ChunkManager.state.stats.cachedCount = 0
    
    for _ in pairs(ChunkManager.state.activeChunks) do
        ChunkManager.state.stats.activeCount = ChunkManager.state.stats.activeCount + 1
    end
    
    for _ in pairs(ChunkManager.state.cachedChunks) do
        ChunkManager.state.stats.cachedCount = ChunkManager.state.stats.cachedCount + 1
    end
    
    ChunkManager.state.stats.poolCount = #ChunkManager.state.chunkPool
    
    return {
        active = ChunkManager.state.stats.activeCount,
        cached = ChunkManager.state.stats.cachedCount,
        pooled = ChunkManager.state.stats.poolCount,
        loadQueue = #ChunkManager.state.loadQueue,
        unloadQueue = #ChunkManager.state.unloadQueue,
        cacheHitRatio = ChunkManager.state.stats.cacheHits / 
                       math.max(1, ChunkManager.state.stats.cacheHits + ChunkManager.state.stats.cacheMisses),
        generationTime = ChunkManager.state.stats.generationTime,
        lastFrameTime = ChunkManager.state.stats.lastFrameTime,
        playerChunk = {
            x = ChunkManager.state.lastPlayerChunkX,
            y = ChunkManager.state.lastPlayerChunkY
        }
    }
end

-- Reset estadísticas
function ChunkManager.resetStats()
    ChunkManager.state.stats = {
        activeCount = 0,
        cachedCount = 0,
        poolCount = 0,
        loadRequests = 0,
        unloadRequests = 0,
        cacheHits = 0,
        cacheMisses = 0,
        generationTime = 0,
        lastFrameTime = 0
    }
end

-- Función de limpieza completa
function ChunkManager.cleanup()
    -- Devolver todos los chunks al pool
    for chunkId, chunk in pairs(ChunkManager.state.activeChunks) do
        ChunkManager.returnChunkToPool(chunk)
    end
    
    for chunkId, chunk in pairs(ChunkManager.state.cachedChunks) do
        ChunkManager.returnChunkToPool(chunk)
    end
    
    -- Limpiar estructuras
    ChunkManager.state.activeChunks = {}
    ChunkManager.state.cachedChunks = {}
    ChunkManager.state.loadQueue = {}
    ChunkManager.state.unloadQueue = {}
    ChunkManager.state.generationQueue = {}
    
    print("ChunkManager cleanup completed")
end

return ChunkManager