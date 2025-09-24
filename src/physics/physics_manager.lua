--[[
    Physics Manager - Sistema de Física Box2D para LÖVE2D
    
    Este archivo actúa como el coordinador principal del sistema de física,
    manejando la inicialización, actualización y limpieza del mundo Box2D.
    
    Responsabilidades:
    - Inicializar el mundo de física Box2D
    - Coordinar todos los subsistemas de física
    - Manejar el ciclo de vida del mundo físico
    - Proporcionar interfaz unificada para otros sistemas
--]]

local PhysicsManager = {}
PhysicsManager.__index = PhysicsManager

-- Dependencias del sistema de física
local PhysicsConfig = require('src.physics.config.physics_config')
local CollisionHandler = require('src.physics.collisions.collision_handler')
local TrajectoryCalculator = require('src.physics.trajectories.trajectory_calculator')
local PhysicsEffects = require('src.physics.effects.physics_effects')

-- Variables del mundo físico
local world = nil
local gravity_x = 0
local gravity_y = 0
local meter = 64 -- Píxeles por metro (ajustar según necesidades del juego)

--[[
    Inicializa el sistema de física Box2D
    @param config: tabla de configuración opcional
    @return: instancia del PhysicsManager
--]]
function PhysicsManager.new(config)
    local self = setmetatable({}, PhysicsManager)
    
    -- Aplicar configuración personalizada si se proporciona
    if config then
        gravity_x = config.gravity_x or PhysicsConfig.DEFAULT_GRAVITY_X
        gravity_y = config.gravity_y or PhysicsConfig.DEFAULT_GRAVITY_Y
        meter = config.meter or PhysicsConfig.DEFAULT_METER
    else
        gravity_x = PhysicsConfig.DEFAULT_GRAVITY_X
        gravity_y = PhysicsConfig.DEFAULT_GRAVITY_Y
        meter = PhysicsConfig.DEFAULT_METER
    end
    
    -- Inicializar el mundo Box2D
    self:initializeWorld()
    
    -- Inicializar subsistemas
    self:initializeSubsystems()
    
    return self
end

--[[
    Inicializa el mundo Box2D con la configuración especificada
--]]
function PhysicsManager:initializeWorld()
    -- TODO: Implementar inicialización completa del mundo Box2D
    -- Crear mundo con gravedad especificada
    world = love.physics.newWorld(gravity_x, gravity_y, true)
    
    -- Configurar callbacks de colisión
    self:setupCollisionCallbacks()
    
    print("[PhysicsManager] Mundo Box2D inicializado con gravedad: (" .. gravity_x .. ", " .. gravity_y .. ")")
end

--[[
    Configura los callbacks de colisión del mundo Box2D
--]]
function PhysicsManager:setupCollisionCallbacks()
    -- TODO: Implementar callbacks de colisión completos
    world:setCallbacks(
        function(a, b, coll) -- beginContact
            CollisionHandler.handleBeginContact(a, b, coll)
        end,
        function(a, b, coll) -- endContact
            CollisionHandler.handleEndContact(a, b, coll)
        end,
        function(a, b, coll) -- preSolve
            CollisionHandler.handlePreSolve(a, b, coll)
        end,
        function(a, b, coll, normalimpulse, tangentimpulse) -- postSolve
            CollisionHandler.handlePostSolve(a, b, coll, normalimpulse, tangentimpulse)
        end
    )
end

--[[
    Inicializa todos los subsistemas de física
--]]
function PhysicsManager:initializeSubsystems()
    -- TODO: Implementar inicialización de subsistemas
    -- Inicializar manejador de colisiones
    CollisionHandler.initialize(world)
    
    -- Inicializar calculadora de trayectorias
    TrajectoryCalculator.initialize()
    
    -- Inicializar sistema de efectos
    PhysicsEffects.initialize(world)
    
    print("[PhysicsManager] Subsistemas de física inicializados")
end

--[[
    Actualiza el mundo de física
    @param dt: tiempo delta desde la última actualización
--]]
function PhysicsManager:update(dt)
    -- TODO: Implementar lógica de actualización completa
    if world then
        -- Actualizar mundo Box2D
        world:update(dt)
        
        -- Actualizar subsistemas
        self:updateSubsystems(dt)
    end
end

--[[
    Actualiza todos los subsistemas de física
    @param dt: tiempo delta
--]]
function PhysicsManager:updateSubsystems(dt)
    -- TODO: Implementar actualización de subsistemas
    CollisionHandler.update(dt)
    TrajectoryCalculator.update(dt)
    PhysicsEffects.update(dt)
end

--[[
    Renderiza elementos de debug del sistema de física
--]]
function PhysicsManager:drawDebug()
    -- TODO: Implementar renderizado de debug completo
    if world and PhysicsConfig.DEBUG_DRAW_ENABLED then
        -- Dibujar cuerpos y formas para debug
        self:drawBodies()
        self:drawJoints()
    end
end

--[[
    Dibuja todos los cuerpos del mundo para debug
--]]
function PhysicsManager:drawBodies()
    -- TODO: Implementar dibujo de cuerpos para debug
    local bodies = world:getBodies()
    for _, body in ipairs(bodies) do
        local fixtures = body:getFixtures()
        for _, fixture in ipairs(fixtures) do
            local shape = fixture:getShape()
            -- Dibujar según el tipo de forma
            -- Implementar lógica específica para cada tipo
        end
    end
end

--[[
    Dibuja todas las articulaciones del mundo para debug
--]]
function PhysicsManager:drawJoints()
    -- TODO: Implementar dibujo de articulaciones para debug
    local joints = world:getJoints()
    for _, joint in ipairs(joints) do
        -- Dibujar articulaciones según su tipo
        -- Implementar lógica específica
    end
end

--[[
    Añade un proyectil al mundo de física
    @param projectile: instancia del proyectil a añadir
    @return: true si se añadió exitosamente, false en caso contrario
--]]
function PhysicsManager:addProjectile(projectile)
    if not world then
        print("[PhysicsManager] Error: No hay mundo de física disponible")
        return false
    end
    
    if not projectile then
        print("[PhysicsManager] Error: Proyectil inválido")
        return false
    end
    
    -- El proyectil ya debería tener su cuerpo físico creado
    -- Solo necesitamos registrarlo si es necesario
    print("[PhysicsManager] Proyectil añadido al mundo de física")
    return true
end

--[[
    Obtiene el mundo Box2D actual
    @return: mundo Box2D
--]]
function PhysicsManager:getWorld()
    return world
end

--[[
    Obtiene la escala de metros por píxel
    @return: número de píxeles por metro
--]]
function PhysicsManager:getMeter()
    return meter
end

--[[
    Convierte píxeles a metros
    @param pixels: valor en píxeles
    @return: valor en metros
--]]
function PhysicsManager:pixelsToMeters(pixels)
    return pixels / meter
end

--[[
    Convierte metros a píxeles
    @param meters: valor en metros
    @return: valor en píxeles
--]]
function PhysicsManager:metersToPixels(meters)
    return meters * meter
end

--[[
    Limpia y destruye el mundo de física
--]]
function PhysicsManager:destroy()
    -- TODO: Implementar limpieza completa del sistema
    if world then
        -- Limpiar subsistemas
        CollisionHandler.cleanup()
        TrajectoryCalculator.cleanup()
        PhysicsEffects.cleanup()
        
        -- Destruir mundo
        world:destroy()
        world = nil
        
        print("[PhysicsManager] Sistema de física destruido")
    end
end

--[[
    Pausa/reanuda la simulación física
    @param paused: true para pausar, false para reanudar
--]]
function PhysicsManager:setPaused(paused)
    -- TODO: Implementar sistema de pausa
    -- Almacenar estado de pausa para controlar actualizaciones
end

return PhysicsManager