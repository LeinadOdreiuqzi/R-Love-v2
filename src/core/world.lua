-- src/core/world.lua
-- Contexto central del juego (World Context / ECS Lite).
-- Actúa como bus de datos único: los sistemas leen/escriben aquí en lugar de
-- recibir argumentos sueltos o usar _G para acceder a datos globales.
-- No contiene lógica de juego, sólo datos y shortcuts de acceso.

local World = {}

-- Almacén interno privado
local _data = {
    -- Sistemas principales
    state    = nil,   -- gameState table (paused, loaded, etc.)
    player   = nil,   -- entidad principal del jugador (instancia de Naves)
    map      = nil,   -- módulo Map
    camera   = nil,   -- instancia Camera  (reemplaza _G.camera)
    physics  = nil,   -- instancia PhysicsManager  (reemplaza _G.physicsManager)
    runState = nil,   -- instancia RunState
    director = nil,   -- instancia GameDirector
    seed     = nil,   -- semilla actual (string alfanumérico)

    -- Entidades del mundo (jugador + futuras: enemigos, NPCs, etc.)
    entities = {},
    -- Índice rápido por ID para lookups O(1)
    _entityIndex = {},
    _nextEntityId = 1,
}

-- ─── Acceso genérico ───────────────────────────────────────────────────────

--- Registra cualquier sistema/dato bajo una clave.
---@param key string
---@param value any
function World.set(key, value)
    _data[key] = value
end

--- Lee un sistema/dato por clave.
---@param key string
---@return any
function World.get(key)
    return _data[key]
end

-- ─── Shortcuts de uso frecuente ────────────────────────────────────────────

function World.getPlayer()   return _data.player   end
function World.getCamera()   return _data.camera   end
function World.getMap()      return _data.map      end
function World.getPhysics()  return _data.physics  end
function World.getRunState() return _data.runState end
function World.getDirector() return _data.director end

--- Devuelve la tabla gameState (paused, loaded, currentSeed, etc.)
function World.getState()    return _data.state    end

-- ─── Sistema de entidades (ECS Lite) ──────────────────────────────────────

--- Agrega una entidad al mundo y le asigna un ID único.
--- La entidad puede ser cualquier tabla; opcionalmente puede tener .entityId ya puesto.
---@param entity table
---@return table entity (con .entityId asignado)
function World.addEntity(entity)
    if not entity then return entity end
    -- Asignar ID si no tiene uno
    if not entity.entityId then
        entity.entityId = _data._nextEntityId
        _data._nextEntityId = _data._nextEntityId + 1
    end
    table.insert(_data.entities, entity)
    _data._entityIndex[entity.entityId] = entity
    return entity
end

--- Elimina una entidad del mundo por referencia o por ID.
---@param entityOrId table|number
function World.removeEntity(entityOrId)
    local id
    if type(entityOrId) == "number" then
        id = entityOrId
    elseif type(entityOrId) == "table" then
        id = entityOrId.entityId
    end
    if not id then return end

    -- Eliminar del índice
    _data._entityIndex[id] = nil

    -- Eliminar de la lista (swap-remove O(1))
    for i = #_data.entities, 1, -1 do
        if _data.entities[i].entityId == id then
            _data.entities[i] = _data.entities[#_data.entities]
            _data.entities[#_data.entities] = nil
            break
        end
    end
end

--- Retorna la lista completa de entidades activas.
---@return table[]
function World.getEntities()
    return _data.entities
end

--- Retorna una entidad por su ID o nil si no existe.
---@param id number
---@return table|nil
function World.getEntityById(id)
    return _data._entityIndex[id]
end

--- Retorna todas las entidades que tengan un campo concreto (filtro por "componente").
--- Uso: World.getEntitiesWith("stats") para obtener todas con sistema de stats.
---@param componentKey string
---@return table[]
function World.getEntitiesWith(componentKey)
    local result = {}
    for _, entity in ipairs(_data.entities) do
        if entity[componentKey] ~= nil then
            result[#result + 1] = entity
        end
    end
    return result
end

-- ─── Utilidades ────────────────────────────────────────────────────────────

--- Limpia todos los datos del World (útil al regenerar el mundo con nueva seed).
--- Mantiene la estructura pero vacía los datos de juego.
function World.reset()
    _data.state    = nil
    _data.player   = nil
    _data.map      = nil
    _data.camera   = nil
    _data.physics  = nil
    _data.runState = nil
    _data.director = nil
    _data.seed     = nil
    _data.entities = {}
    _data._entityIndex = {}
    -- Mantenemos _nextEntityId para no reusar IDs en la misma sesión
end

--- Debug: imprime el estado actual del World en consola.
function World.dump()
    print("=== WORLD DUMP ===")
    print("  state:    ", _data.state    and "OK" or "nil")
    print("  player:   ", _data.player   and "OK" or "nil")
    print("  map:      ", _data.map      and "OK" or "nil")
    print("  camera:   ", _data.camera   and "OK" or "nil")
    print("  physics:  ", _data.physics  and "OK" or "nil")
    print("  runState: ", _data.runState and "OK" or "nil")
    print("  director: ", _data.director and "OK" or "nil")
    print("  seed:     ", _data.seed     or "nil")
    print("  entities: ", #_data.entities, "registered")
    print("==================")
end

return World
