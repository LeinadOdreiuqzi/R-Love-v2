-- src/maps/chunk_manager.lua (cabecera)
local ChunkManager = {}
local CoordinateSystem = require 'src.maps.coordinate_system'
local BiomeSystem = require 'src.maps.biome_system'
local MapConfig = require 'src.maps.config.map_config'
local MapGenerator = require 'src.maps.systems.map_generator'
local VisibilityUtils = require 'src.maps.visibility_utils'

-- Configuración del gestor de chunks
ChunkManager.config = {
    -- Tamaño de cada chunk
    chunkSize = 48,
    tileSize = 32,
    
    -- Gestión de memoria
    maxActiveChunks = 120,      -- Aumentado de 100 a 120
    maxCachedChunks = 250,      -- Aumentado de 200 a 250
    poolSize = 60,              -- Aumentado de 50 a 60
    
    -- Distancias de carga/descarga (aumentadas para mejor precarga)
    loadDistance = 4,           -- Aumentado de 3 a 4
    unloadDistance = 8,         -- Aumentado de 6 a 8
    preloadDistance = 6,        -- Aumentado de 2 a 6 para precarga más agresiva
    
    -- Precarga direccional
    directionalPreload = {
        enabled = true,
        lookAheadDistance = 3,  -- Chunks adicionales en dirección de movimiento
        velocityThreshold = 5,  -- Velocidad mínima para activar precarga direccional
        biasMultiplier = 1.5    -- Multiplicador de prioridad para dirección de movimiento
    },
    
    -- Prioridades de carga (menores números = mayor prioridad)
    priority = {
        immediate = 1,          -- Chunk donde está el jugador
        adjacent = 2,           -- Chunks adyacentes
        directional = 3,        -- Chunks en dirección de movimiento
        visible = 4,            -- Chunks visibles en pantalla
        preload = 5,            -- Chunks de precarga
        background = 6          -- Chunks de fondo
    },
    
    -- Configuración de generación
    maxGenerationTime = 0.003,  -- Fallback (3ms)
    maxObjectsPerFrame = 150,   -- Aumentado de 100 a 150

    -- Presupuesto adaptativo por frame
    useAdaptiveBudget = true,
    targetFrameSec = 1 / 60,        -- Objetivo ~16.67ms
    softBudgetFraction = 0.12,       -- 12% del frame objetivo (~2ms)
    minGenerationTime = 0.0015,      -- 1.5ms mínimo
    maxGenerationTimeAdaptive = 0.0035, -- 3.5ms máximo adaptativo
    reduceOnOvershoot = 0.5,         -- Reducir a la mitad si dt > target
    
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

-- Calcular prioridad de carga con sesgo direccional (top-level)
function ChunkManager.calculatePriorityWithDirection(chunkX, chunkY, playerChunkX, playerChunkY, playerVelX, playerVelY)
    local dx = math.abs(chunkX - playerChunkX)
    local dy = math.abs(chunkY - playerChunkY)
    local distance = math.max(dx, dy)  -- Distancia de Chebyshev

    -- Prioridad base según distancia
    local basePriority
    if distance == 0 then
        basePriority = ChunkManager.config.priority.immediate
    elseif distance == 1 then
        basePriority = ChunkManager.config.priority.adjacent
    elseif distance <= ChunkManager.config.loadDistance then
        basePriority = ChunkManager.config.priority.visible
    elseif distance <= ChunkManager.config.preloadDistance then
        basePriority = ChunkManager.config.priority.preload
    else
        basePriority = ChunkManager.config.priority.background
    end

    -- Sesgo direccional
    if ChunkManager.config.directionalPreload.enabled and playerVelX and playerVelY then
        local speed = math.sqrt(playerVelX * playerVelX + playerVelY * playerVelY)

        if speed > ChunkManager.config.directionalPreload.velocityThreshold then
            local directionX = chunkX - playerChunkX
            local directionY = chunkY - playerChunkY

            local normalizedVelX = playerVelX / speed
            local normalizedVelY = playerVelY / speed

            local alignment = 0
            if distance > 0 then
                local normalizedDirX = directionX / distance
                local normalizedDirY = directionY / distance
                alignment = normalizedVelX * normalizedDirX + normalizedVelY * normalizedDirY
            end

            if alignment > 0.3 then
                local bias = alignment * ChunkManager.config.directionalPreload.biasMultiplier
                basePriority = basePriority - bias

                if basePriority < ChunkManager.config.priority.directional then
                    basePriority = ChunkManager.config.priority.directional
                end
            end
        end
    end

    return basePriority
end

-- Insertar en cola de carga ordenada por prioridad (menor número = mayor prioridad)
function ChunkManager.insertLoadRequest(loadRequest)
    local queue = ChunkManager.state.loadQueue
    local inserted = false
    for i = 1, #queue do
        local q = queue[i]
        if loadRequest.priority < q.priority or
           (loadRequest.priority == q.priority and loadRequest.requestTime < q.requestTime) then
            table.insert(queue, i, loadRequest)
            inserted = true
            break
        end
    end
    if not inserted then
        table.insert(queue, loadRequest)
    end
end
-- Presupuesto de generación adaptativo (segundos)
function ChunkManager.computeGenerationBudget(dt)
    local cfg = ChunkManager.config
    local target = cfg.targetFrameSec or (1 / 60)
    local soft = (cfg.softBudgetFraction or 0.12) * target
    local base = soft
    local minB = cfg.minGenerationTime or 0.0015
    local maxB = cfg.maxGenerationTimeAdaptive or 0.0035
    -- Limitar por mínimos/máximos
    base = math.max(minB, math.min(maxB, base))
    -- Si el frame se pasa del objetivo, recortar el presupuesto
    if dt and dt > target then
        base = math.max(minB, base * (cfg.reduceOnOvershoot or 0.5))
    end
    return base
end
-- Procesar cola de carga con presupuesto de tiempo (segundos)
function ChunkManager.processLoadQueue(dt, timeBudgetSec)
    local startTime = love.timer.getTime()
    local budget = timeBudgetSec or 0.002
    local queue = ChunkManager.state.loadQueue

    while #queue > 0 and (love.timer.getTime() - startTime) < budget do
        local req = table.remove(queue, 1)
        local id = req.id

        -- Si ya está cargado o cacheado, saltar
        if not ChunkManager.state.activeChunks[id] and not ChunkManager.state.cachedChunks[id] then
            -- Generar chunk
            local chunk = MapGenerator.generateChunk(req.chunkX, req.chunkY)
            -- Normalizar a estructura esperada por ChunkManager
            chunk.id = id
            chunk.status = "complete"
            chunk.priority = req.priority
            chunk.lastAccess = love.timer.getTime()
            chunk.generated = true
            chunk.visible = false
            chunk.lodLevel = 0

            -- Activar directamente (rápido y simple)
            ChunkManager.state.activeChunks[id] = chunk
        end
    end
end

-- Descargar a caché los chunks demasiado lejanos
function ChunkManager.processUnloadQueue(playerChunkX, playerChunkY)
    local toCache = {}
    for id, chunk in pairs(ChunkManager.state.activeChunks) do
        local dx = math.abs(chunk.x - playerChunkX)
        local dy = math.abs(chunk.y - playerChunkY)
        local distance = math.max(dx, dy)
        if distance > ChunkManager.config.unloadDistance then
            table.insert(toCache, id)
        end
    end

    for _, id in ipairs(toCache) do
        local chunk = ChunkManager.state.activeChunks[id]
        ChunkManager.state.activeChunks[id] = nil
        -- Mantener como complete en caché; se promoverá si se vuelve a solicitar
        chunk.visible = false
        ChunkManager.state.cachedChunks[id] = chunk
        ChunkManager.state.stats.unloadRequests = ChunkManager.state.stats.unloadRequests + 1
    end
end

-- Limpiar caché por LRU
function ChunkManager.cleanupCache()
    local cachedCount = 0
    for _ in pairs(ChunkManager.state.cachedChunks) do cachedCount = cachedCount + 1 end
    if cachedCount <= ChunkManager.config.maxCachedChunks then return end

    -- Construir lista para ordenar por lastAccess asc (menos usados primero)
    local items = {}
    for id, chunk in pairs(ChunkManager.state.cachedChunks) do
        table.insert(items, { id = id, lastAccess = chunk.lastAccess or 0 })
    end
    table.sort(items, function(a, b) return a.lastAccess < b.lastAccess end)

    local target = math.floor(ChunkManager.config.maxCachedChunks * 0.8)
    local toRemove = cachedCount - target
    for i = 1, toRemove do
        local id = items[i] and items[i].id
        if id and ChunkManager.state.cachedChunks[id] then
            local chunk = ChunkManager.state.cachedChunks[id]
            ChunkManager.state.cachedChunks[id] = nil
            -- Devolver al pool si cabe, si no simplemente permitir GC
            ChunkManager.returnChunkToPool(chunk)
        end
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
function ChunkManager.requestChunkLoad(chunkX, chunkY, playerX, playerY, playerVelX, playerVelY)
    local chunkId = ChunkManager.generateChunkId(chunkX, chunkY)
    
    -- Verificar si ya está en cola de carga
    for _, request in ipairs(ChunkManager.state.loadQueue) do
        if request.id == chunkId then
            return nil  -- Ya está siendo procesado
        end
    end
    
    -- Determinar chunk del jugador usando MapConfig para asegurar determinismo
    local sizePixels = (MapConfig and MapConfig.chunk and MapConfig.chunk.size or ChunkManager.config.chunkSize)
        * (MapConfig and MapConfig.chunk and MapConfig.chunk.tileSize or ChunkManager.config.tileSize)
    local stride = sizePixels + ((MapConfig and MapConfig.chunk and MapConfig.chunk.spacing) or 0)
    local ws = (MapConfig and MapConfig.chunk and MapConfig.chunk.worldScale) or 1
    local playerChunkX = math.floor(playerX / (stride * ws))
    local playerChunkY = math.floor(playerY / (stride * ws))

    if type(playerX) ~= "number" or type(playerY) ~= "number" then
        playerChunkX = ChunkManager.state.lastPlayerChunkX or 0
        playerChunkY = ChunkManager.state.lastPlayerChunkY or 0
    else
        local computedX = math.floor(playerX / (stride * ws))
        local computedY = math.floor(playerY / (stride * ws))
        if (playerX == 0 and playerY == 0) and
           ((ChunkManager.state.lastPlayerChunkX or 0) ~= 0 or (ChunkManager.state.lastPlayerChunkY or 0) ~= 0) then
            playerChunkX = ChunkManager.state.lastPlayerChunkX
            playerChunkY = ChunkManager.state.lastPlayerChunkY
        else
            playerChunkX = computedX
            playerChunkY = computedY
        end
    end

    -- Calcular prioridad con sesgo direccional
    local priority = ChunkManager.calculatePriorityWithDirection(
        chunkX, chunkY, playerChunkX, playerChunkY, playerVelX, playerVelY
    )

    -- Crear solicitud de carga
    local loadRequest = {
        id = chunkId,
        chunkX = chunkX,
        chunkY = chunkY,
        priority = priority,
        requestTime = love.timer.getTime(),
        directional = (playerVelX and playerVelY) and true or false
    }

    -- Insertar en cola de carga ordenada por prioridad
    ChunkManager.insertLoadRequest(loadRequest)
    ChunkManager.state.stats.loadRequests = ChunkManager.state.stats.loadRequests + 1

    return nil  -- Chunk no disponible inmediatamente
end

    -- Actualizar gestión de chunks con velocidad del jugador
    function ChunkManager.update(dt, playerX, playerY, playerVelX, playerVelY)
        local startTime = love.timer.getTime()
        
        -- Actualizar posición del jugador
        local sizePixels = ChunkManager.config.chunkSize * ChunkManager.config.tileSize
        local stride = sizePixels + ((MapConfig and MapConfig.chunk and MapConfig.chunk.spacing) or 0)
        local ws = (MapConfig and MapConfig.chunk and MapConfig.chunk.worldScale) or 1
        local playerChunkX = math.floor(playerX / (stride * ws))
        local playerChunkY = math.floor(playerY / (stride * ws))
        
        ChunkManager.state.lastPlayerChunkX = playerChunkX
        ChunkManager.state.lastPlayerChunkY = playerChunkY
        
        -- Procesar cola de carga con presupuesto adaptativo
        local budget = ChunkManager.config.maxGenerationTime
        if ChunkManager.config.useAdaptiveBudget and ChunkManager.computeGenerationBudget then
            budget = ChunkManager.computeGenerationBudget(dt)
        end
        ChunkManager.state.stats.generationBudget = budget
        ChunkManager.processLoadQueue(dt, budget)
        
        -- Precarga direccional automática
        if ChunkManager.config.directionalPreload.enabled and playerVelX and playerVelY then
            ChunkManager.performDirectionalPreload(playerChunkX, playerChunkY, playerVelX, playerVelY)
        end
        
        -- Procesar descargas si es necesario
        if ChunkManager.countActiveChunks() > ChunkManager.config.maxActiveChunks * 0.9 then
            ChunkManager.processUnloadQueue(playerChunkX, playerChunkY)
        end
        
        -- Gestión de memoria si es necesario
        if ChunkManager.countCachedChunks() > ChunkManager.config.maxCachedChunks * 0.9 then
            ChunkManager.cleanupCache()
        end
        
        ChunkManager.state.stats.lastFrameTime = dt or 0
        ChunkManager.state.stats.generationTime = love.timer.getTime() - startTime
    end
    
    -- Realizar precarga direccional
    function ChunkManager.performDirectionalPreload(playerChunkX, playerChunkY, velX, velY)
        local speed = math.sqrt(velX * velX + velY * velY)
        if speed < ChunkManager.config.directionalPreload.velocityThreshold then return end
    
        local lookAhead = ChunkManager.config.directionalPreload.lookAheadDistance
        local normalizedVelX = velX / speed
        local normalizedVelY = velY / speed
    
        -- Redondeo seguro (Lua no tiene math.round estándar)
        local function round(n)
            if n >= 0 then
                return math.floor(n + 0.5)
            else
                return math.ceil(n - 0.5)
            end
        end
    
        for distance = 1, lookAhead do
            local futureX = playerChunkX + round(normalizedVelX * distance)
            local futureY = playerChunkY + round(normalizedVelY * distance)
    
            local chunkId = ChunkManager.generateChunkId(futureX, futureY)
    
            if not ChunkManager.state.activeChunks[chunkId] and not ChunkManager.isInLoadQueue(chunkId) then
                -- Pasar nil para usar lastPlayerChunk y evitar desfases de stride/escala
                ChunkManager.requestChunkLoad(futureX, futureY, nil, nil, velX, velY)
            end
        end
    end
    
    -- Verificar si un chunk está en la cola de carga
    function ChunkManager.isInLoadQueue(chunkId)
        for _, request in ipairs(ChunkManager.state.loadQueue) do
            if request.id == chunkId then return true end
        end
        return false
    end
    
    -- Contar chunks activos eficientemente
    function ChunkManager.countActiveChunks()
        local count = 0
        for _ in pairs(ChunkManager.state.activeChunks) do
            count = count + 1
        end
        return count
    end
    
    -- Contar chunks en cache eficientemente
    function ChunkManager.countCachedChunks()
        local count = 0
        for _ in pairs(ChunkManager.state.cachedChunks) do
            count = count + 1
        end
        return count
    end
    
    -- Obtener chunks visibles con margen ampliado
    function ChunkManager.getVisibleChunks(camera)
        local visibleChunks = {}
    
        -- Unificar cálculo de bounds (margen 300px, sin anillo extra aquí)
        local bounds = VisibilityUtils.getVisibleChunkBounds(camera, 300, 0)
    
        -- Recopilar chunks visibles
        for chunkY = bounds.startY, bounds.endY do
            for chunkX = bounds.startX, bounds.endX do
                local chunkId = ChunkManager.generateChunkId(chunkX, chunkY)
                local chunk = ChunkManager.state.activeChunks[chunkId]
                if chunk and chunk.status == "complete" then
                    chunk.visible = true
                    table.insert(visibleChunks, chunk)
                end
            end
        end
    
        return visibleChunks, bounds
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
            generationBudget = ChunkManager.state.stats.generationBudget,
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