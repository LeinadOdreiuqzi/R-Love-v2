-- src/entities/naves.lua
-- Sistema de gestión de naves con persistencia de estado individual

local Naves = {}
local PlayerStats = require 'src.entities.player_stats'
local EVAPlayer = require 'src.entities.eva_player'
local InventorySystem = require 'src.maps.systems.inventory_system'
local InventoryUI = require 'src.ui.inventory_ui'
local EVAInventoryUI = require 'src.ui.eva_inventory_ui'
local WeaponSystem = require 'src.entities.weapon_system'
local ShipRenderer = require 'src.entities.ship_renderer'

-- Getter perezoso del World context para evitar require circular en el 
-- momento del módulo (main.lua carga Naves antes de crear el World).
local function getWorld()
    return package.loaded['src.core.world']
end

-- Configuración de tipos de naves
local SHIP_TYPES = {
    EXPLORER = {
        name = "Explorer",
        size = 14,
        maxFuel = 1000,
        maxHealth = 100,
        maxShield = 50,
        hyperTravelCapable = true,
        boostMultiplier = 1.8,
        maxSpeed = 80,
        acceleration = 12,
        defaultWeapon = "basic_laser_pistol"  -- Arma versátil para exploración
    },
    FIGHTER = {
        name = "Fighter",
        size = 13,
        maxFuel = 600,
        maxHealth = 80,
        maxShield = 30,
        hyperTravelCapable = false,
        boostMultiplier = 2.2,
        maxSpeed = 120,
        acceleration = 18,
        defaultWeapon = "kinetic_assault_rifle"  -- Arma de combate de alta cadencia
    },
    CARGO = {
        name = "Cargo",
        size = 20,
        maxFuel = 1500,
        maxHealth = 150,
        maxShield = 80,
        hyperTravelCapable = true,
        boostMultiplier = 1.3,
        maxSpeed = 50,
        acceleration = 8,
        defaultWeapon = "basic_laser_pistol"  -- Arma básica para defensa
    }
}

-- Registro global de naves
local shipRegistry = {}
local nextShipId = 1
local allShips = {}  -- Lista de todas las naves creadas

function Naves:new(x, y, shipType)
    shipType = shipType or "EXPLORER"
    local shipConfig = SHIP_TYPES[shipType] or SHIP_TYPES.EXPLORER
    
    local player = {}
    setmetatable(player, self)
    self.__index = self
    
    -- Información de la nave
    player.shipId = nextShipId
    nextShipId = nextShipId + 1
    player.shipType = shipType
    player.shipName = shipConfig.name .. " #" .. player.shipId
    player.shipConfig = shipConfig
    
    -- Position and movement
    player.x = x or 0
    player.y = y or 0
    player.dx = 0  -- Velocity X
    player.dy = 0  -- Velocity Y
    
    -- Movement parameters basados en configuración de nave
    player.maxSpeed = shipConfig.maxSpeed
    player.forwardAccel = shipConfig.acceleration
    player.strafeAccel = shipConfig.acceleration * 0.7
    player.backwardAccel = shipConfig.acceleration * 0.5
    player.drag = 0.94              -- More drag for better control
    player.brakePower = 0.8         -- Improved drift braking
    
    -- Parámetros balanceados para drift controlado
     player.rotationSpeed = 5.0      -- Velocidad de rotación controlada
     player.driftFactor = 0.88       -- Factor de drift reducido (88% inercia lateral)
     player.driftActivation = 6      -- Umbral reducido para activar drift
     player.driftTransition = 0.95   -- Transición más controlada
     player.gradualBraking = 0.85    -- Frenado más efectivo
     player.boostMultiplier = shipConfig.boostMultiplier
     player.boostDuration = 0        -- Duración actual del boost
     player.maxBoostDuration = 1.2   -- Duración máxima del boost (reducida)
     
     -- ESTADO PARA INTERPOLACIÓN (Fixed Timestep)
     player.prevX = player.x
     player.prevY = player.y
     player.prevRotation = player.rotation or 0

    
    -- Toggle de viaje rápido (100k)
    player.hyperTravelEnabled = false
    player.baseParams = {
        maxSpeed = player.maxSpeed,
        forwardAccel = player.forwardAccel,
        strafeAccel = player.strafeAccel,
        backwardAccel = player.backwardAccel,
        drag = player.drag,
    }
    player.hyperParams = {
        maxSpeed = 100000,    -- 100k unidades/seg (límite de velocidad)
        forwardAccel = 40000, -- acelerar rápido hacia 100k
        strafeAccel = 20000,
        backwardAccel = 15000,
        drag = 0.99,          -- menos pérdida de velocidad
    }
    
    -- State
    player.rotation = 0            -- Current rotation in radians
    player.targetRotation = 0      -- Target rotation for smooth turning
    player.isBraking = false
    player.isBoostActive = false   -- Estado del boost
    player.isDrifting = false      -- Estado del drift activo

    
    -- Mouse direction tracking
    player.mouseDirection = {x = 1, y = 0}  -- Default direction (right)
    player.minMouseDistance = 20    -- Minimum distance to avoid erratic behavior
    
    -- Get world scale from map
    local Map = require 'src.maps.map' 
    player.worldScale = Map.tileSize / 64 
    
    -- Ship dimensions and sprite
    player.size = shipConfig.size or 14  -- Tamaño según tipo de nave
    player.isPiloted = false             -- Controlado por el jugador o inactivo
    player.isAbandoned = true            -- Por defecto abandonada hasta que se asigne piloto
    player.sprite = nil
    player.spriteScale = 1.0  -- Scale factor for the sprite
    player.spriteOffsetX = 0  -- Offset for centering
    player.spriteOffsetY = 0
    
    -- Load sprite
    player:loadSprite()
    
    -- Visual effects
    player.engineGlow = 0
    player.thrusterParticles = {}
    
    -- Stats system basados en configuración de nave
    player.stats = PlayerStats:new()
    player.stats.health.maxHealth = shipConfig.maxHealth
    player.stats.health.currentHealth = shipConfig.maxHealth
    player.stats.shield.maxShield = shipConfig.maxShield
    player.stats.shield.currentShield = shipConfig.maxShield
    player.stats.fuel.maxFuel = shipConfig.maxFuel
    player.stats.fuel.currentFuel = shipConfig.maxFuel
    
    -- Sistema de inventario
    player.inventory = InventorySystem:new(shipType)
    player.inventory.player = player  -- Asignar referencia del jugador al inventario
    
    -- Sistema de armas con cambio rápido
    player.weaponSystem = WeaponSystem:new(player)

    -- Configuraciones específicas de la nave
    player.shipSettings = {
        hyperTravelEnabled = shipConfig.hyperTravelCapable,
        hyperTravelRange = shipConfig.hyperTravelCapable and 100000 or 0,
        autoRepairEnabled = true,
        shieldRegenRate = 1.0,
        fuelEfficiency = 1.0,
        damageResistance = 1.0
    }
    
    -- Estado de daño específico de la nave
    player.damageState = {
        hullIntegrity = 100,
        engineEfficiency = 100,
        shieldGeneratorStatus = 100,
        hyperDriveStatus = shipConfig.hyperTravelCapable and 100 or 0,
        lifeSupportStatus = 100
    }
    
    -- Registrar nave en el sistema
    shipRegistry[player.shipId] = {
        id = player.shipId,
        ship = player,
        type = shipType,
        name = player.shipName,
        position = {x = x or 0, y = y or 0},
        stats = player.stats,
        settings = player.shipSettings,
        damageState = player.damageState,
        inventory = {
            items = player.inventory.items,
            shipType = player.inventory.shipType,
            compartments = player.inventory.compartments and {
                eva = player.inventory.compartments.eva and {
                    maxSlots = player.inventory.compartments.eva.maxSlots,
                    items = player.inventory.compartments.eva.items
                } or { maxSlots = 3, items = { nil, nil, nil } }
            } or nil
        },
        lastSeen = love.timer.getTime()
    }
    
    -- EVA (Extra-Vehicular Activity) system
    player.isInEVA = false
    player.evaPlayer = EVAPlayer:new(player.x, player.y, player)  -- Crear EVA player desde el inicio
    player.evaPlayer.stats = player.stats  -- Compartir stats
    player.evaKeyPressed = false  -- Para evitar activación múltiple
    player.sKeyPressed = false    -- Para detectar combinación S+E
    
    -- Agregar nave a la lista global
    table.insert(allShips, player)
    
    return player
end

-- Métodos estáticos para gestión de naves
function Naves.getShipRegistry()
    return shipRegistry
end

function Naves.getShipById(shipId)
    for _, ship in ipairs(allShips) do
        if ship.shipId == shipId then
            return ship
        end
    end
    return nil
end

function Naves.getAllShips()
    return allShips
end

function Naves.getNearbyShips(x, y, radius)
    local nearbyShips = {}
    radius = radius or 500
    
    for _, ship in ipairs(allShips) do
        local sx = ship.x or 0
        local sy = ship.y or 0
        local distance = math.sqrt((sx - x)^2 + (sy - y)^2)
        if distance <= radius then
            table.insert(nearbyShips, {
                ship = ship,
                distance = distance
            })
        end
    end
    
    -- Ordenar por distancia
    table.sort(nearbyShips, function(a, b) return a.distance < b.distance end)
    return nearbyShips
end

function Naves.createShip(x, y, shipType)
    return Naves:new(x, y, shipType)
end

function Naves.removeShip(shipId)
    shipRegistry[shipId] = nil
    for i = #allShips, 1, -1 do
        if allShips[i].shipId == shipId then
            table.remove(allShips, i)
            break
        end
    end
end

function Naves.clearAllShips()
    allShips = {}
    shipRegistry = {}
    nextShipId = 1
end

function Naves:loadSprite()
    -- Solo la clase EXPLORER utiliza sprite (si está disponible); FIGHTER y CARGO usan diseño geométrico especializado
    if self.shipType ~= "EXPLORER" then
        self.sprite = nil
        return
    end

    local spritePaths = { "assets/images/Nave.png", "assets/images/nave.png" }
    local loaded = nil
    local finalPath = nil

    for _, path in ipairs(spritePaths) do
        local success, result = pcall(function()
            return love.graphics.newImage(path)
        end)
        if success and result then
            loaded = result
            finalPath = path
            break
        end
    end
    
    if loaded then
        self.sprite = loaded
        local spriteWidth = self.sprite:getWidth()
        local spriteHeight = self.sprite:getHeight()
        self.spriteOffsetX = spriteWidth / 2
        self.spriteOffsetY = spriteHeight / 2
        print("Ship sprite loaded successfully: " .. finalPath)
    else
        self.sprite = nil
    end
end

function Naves:updatePassivePhysics(dt)
    -- Fricción inercial en el espacio exterior
    local dragFactor = math.pow(self.drag or 0.94, dt * 60)
    self.dx = (self.dx or 0) * dragFactor
    self.dy = (self.dy or 0) * dragFactor

    local speed = math.sqrt(self.dx * self.dx + self.dy * self.dy)
    if speed < 0.5 then
        self.dx = 0
        self.dy = 0
    end

    -- Actualizar posición física
    self.x = self.x + self.dx * dt * 60
    self.y = self.y + self.dy * dt * 60

    -- Resolver colisiones contra asteroides para naves a la deriva
    if self.resolveAsteroidCollisions then
        self:resolveAsteroidCollisions(dt)
    end

    -- Suave deriva rotacional para naves abandonadas / a la deriva
    if self.driftAngularSpeed then
        self.rotation = (self.rotation or 0) + self.driftAngularSpeed * dt
    end

    -- Desvanecer brillo del motor
    self.engineGlow = math.max(0, (self.engineGlow or 0) - dt * 3)

    -- Actualizar proyectiles remanentes
    if self.updateProjectiles then
        self:updateProjectiles(dt)
    end
end

function Naves:update(dt)
    -- Actualizar registro de nave
    self:updateShipRegistry()
    -- Ensure we have a valid delta time
    dt = math.min(dt or 1/60, 1/30)
    
    local World = getWorld()
    local isPlayer = (self.isPiloted or (World and World.getPlayer and World.getPlayer() == self))

    -- Si esta nave no está siendo controlada por el jugador, solo actualizar física inercial pasiva
    if not isPlayer then
        self:updatePassivePhysics(dt)
        return
    end
    
    -- Handle EVA controls first
    self:handleEVAControls()
    
    -- If in EVA mode, update EVA player instead of ship
    if self.isInEVA then
        self:updateEVA(dt)
        return  -- Don't update ship physics when in EVA
    end
    
    -- Update weapon system
    if self.weaponSystem then
        self.weaponSystem:update(dt)
    end
    
    -- Update input state and handle rotation
    self:handleInput()
    
    -- ROTACIÓN INERCIAL HACIA EL MOUSE
    local mouseX, mouseY = love.mouse.getPosition()
    local screenX, screenY = love.graphics.getDimensions()
    
    -- Acceder a la cámara a través del bus central World
    local w = getWorld()
    local cam = (w and (w.getCamera and w.getCamera() or w.get('camera')))
    
    -- Convert mouse position to world coordinates
    local worldMouseX, worldMouseY = self.x, self.y
    if cam then
        worldMouseX, worldMouseY = cam:screenToWorld(mouseX, mouseY)
    end
    
    -- Calculate target angle to mouse
    local dx = worldMouseX - self.x
    local dy = worldMouseY - self.y
    local targetRotation = math.atan2(dy, dx) + (math.pi / 2)
    
    -- Smooth rotation towards target (rotación inercial)
    local angleDiff = targetRotation - self.rotation
    -- Normalize angle difference to [-π, π]
    while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
    while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end
    
    -- Apply gradual rotation
    self.rotation = self.rotation + angleDiff * self.rotationSpeed * dt
    
    -- Update mouse direction for movement
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance > 0 then
        self.mouseDirection.x = dx / distance
        self.mouseDirection.y = dy / distance
    end
    
    -- SISTEMA DE BOOST TEMPORAL
    if self.input.boost and self.boostDuration < self.maxBoostDuration then
        local wasBoostActive = self.isBoostActive
        self.boostDuration = math.min(self.maxBoostDuration, self.boostDuration + dt)
        self.isBoostActive = true
        
        -- Incrementar contador de boosts en RunState cuando se activa por primera vez
        if not wasBoostActive then
            -- Desacoplar estado usando el bus central World
            local w = getWorld()
            local rs = (w and (w.getRunState and w.getRunState() or w.get('runState')))
            if rs and rs.incrementBoosts then
                rs:incrementBoosts()
            end
            local audio = w and (w.getAudio and w.getAudio() or w.get('audio'))
            if audio and audio.play then
                audio.play("boost", { volume = 0.45, pitchVariation = 0.03 })
            end
        end
    else
        self.boostDuration = math.max(0, self.boostDuration - dt * 2)  -- Se agota más rápido
        self.isBoostActive = false
    end
    
    -- Check if can move (fuel or debug infinite fuel)
    local canMove = self.stats:canMove()
    
    -- Calculate movement based on input
    local moveX, moveY = 0, 0
    local isMoving = false
    
    -- Forward movement (W) - move toward mouse direction
    if self.input.forward and canMove then
        moveX = moveX + self.mouseDirection.x
        moveY = moveY + self.mouseDirection.y
        self.engineGlow = math.min(1, self.engineGlow + dt * 3)
        isMoving = true
    else
        self.engineGlow = math.max(0, self.engineGlow - dt * 2)
    end
    
    -- Support movements (A, S, D) - Vectores relativos a la orientación de la nave (rotation = 0 apunta hacia -Y)
    -- Vector frontal: F = (sin(theta), -cos(theta))
    -- Vector derecho: R = (cos(theta), sin(theta))
    -- Vector izquierdo: -R = (-cos(theta), -sin(theta))
    if self.input.left and canMove then       -- A - Strafe left relative to ship orientation
        local leftX = -math.cos(self.rotation)
        local leftY = -math.sin(self.rotation)
        moveX = moveX + leftX * 0.8  -- Mejorado para mejor control
        moveY = moveY + leftY * 0.8
        isMoving = true
    end
    
    if self.input.right and canMove then      -- D - Strafe right relative to ship orientation
        local rightX = math.cos(self.rotation)
        local rightY = math.sin(self.rotation)
        moveX = moveX + rightX * 0.8  -- Mejorado para mejor control
        moveY = moveY + rightY * 0.8
        isMoving = true
    end
    
    if self.input.backward and canMove then   -- S - Move backward relative to ship orientation (-F)
        local backX = -math.sin(self.rotation)
        local backY = math.cos(self.rotation)
        moveX = moveX + backX * 0.6  -- Movimiento hacia atrás relativo a la nave
        moveY = moveY + backY * 0.6
        isMoving = true
    end
    
    -- Modificador pasivo de velocidad (Propulsores Mejorados, etc.)
    local speedMod = self.passiveModifiers and self.passiveModifiers.speed
    local speedMult = 1.0
    local speedFlat = 0
    if type(speedMod) == "table" then
        speedMult = 1.0 + ((speedMod.percent or 0) / 100.0)
        speedFlat = speedMod.flat or 0
    elseif type(speedMod) == "number" then
        speedMult = 1.0 + (speedMod > 1 and (speedMod / 100.0) or speedMod)
    end
    local effectiveMaxSpeed = (self.maxSpeed + speedFlat) * speedMult
    
    -- Normalize movement vector if moving
    local moveLen = math.sqrt(moveX * moveX + moveY * moveY)
    if moveLen > 0 then
        moveX, moveY = moveX / moveLen, moveY / moveLen
        
        -- Determine acceleration type based on primary movement
        local accel = self.forwardAccel  -- Default acceleration
        if self.input.forward then
            accel = self.forwardAccel
        elseif self.input.backward and not (self.input.left or self.input.right) then
            accel = self.backwardAccel
        elseif (self.input.left or self.input.right) and not (self.input.forward or self.input.backward) then
            accel = self.strafeAccel
        end
        
        accel = (accel + speedFlat) * speedMult
        
        -- Aplicar multiplicador de boost si está activo
        if self.isBoostActive and self.boostDuration > 0 then
            accel = accel * self.boostMultiplier
        end
        
        -- Apply movement based on the normalized direction
        self.dx = self.dx + moveX * accel * dt
        self.dy = self.dy + moveY * accel * dt
    end
    
    -- SISTEMA DE DRIFT INTENSO CON BULLET TIME CINEMATOGRÁFICO
     if self.input.brake then
         -- Calcular velocidad actual
         local currentSpeed = math.sqrt(self.dx * self.dx + self.dy * self.dy)
         
         -- Activar drift intenso basado en velocidad
         if currentSpeed > self.driftActivation then
             -- DRIFT ACTIVO INTENSO - Preservar más inercia lateral
             local currentDirX = self.dx / currentSpeed
             local currentDirY = self.dy / currentSpeed
             
             -- Calcular componente hacia adelante (en dirección de la nave: cos(theta - pi/2), sin(theta - pi/2))
             local forwardX = math.sin(self.rotation)
             local forwardY = -math.cos(self.rotation)
             local forwardComponent = currentDirX * forwardX + currentDirY * forwardY
             
             -- Separar velocidad en componentes forward y lateral
             local forwardVelX = forwardComponent * forwardX
             local forwardVelY = forwardComponent * forwardY
             local lateralVelX = self.dx - forwardVelX
             local lateralVelY = self.dy - forwardVelY
             
             -- Frenado gradual diferenciado (más suave para drift intenso)
             local gradualBrakeFactor = math.pow(self.gradualBraking, dt * 60)
             forwardVelX = forwardVelX * gradualBrakeFactor
             forwardVelY = forwardVelY * gradualBrakeFactor
             
             -- Preservar inercia lateral controlada para drift balanceado (88% preservado)
             local driftPreservation = math.pow(self.driftFactor, dt * 60)
             lateralVelX = lateralVelX * driftPreservation
             lateralVelY = lateralVelY * driftPreservation
             
             -- Recombinar velocidades con transición suave
             self.dx = forwardVelX + lateralVelX
             self.dy = forwardVelY + lateralVelY
             
             -- Verificar que la velocidad total no exceda el límite durante el drift
             local totalSpeed = math.sqrt(self.dx * self.dx + self.dy * self.dy)
             if totalSpeed > effectiveMaxSpeed * 1.1 then  -- Permitir 10% extra durante drift
                 local limitFactor = (effectiveMaxSpeed * 1.1) / totalSpeed
                 self.dx = self.dx * limitFactor
                 self.dy = self.dy * limitFactor
             end
             
             -- Marcar drift activo
             self.isDrifting = true
             
         elseif currentSpeed > 2 then
             -- TRANSICIÓN GRADUAL - Velocidad media (umbral aumentado)
             local transitionFactor = math.pow(self.driftTransition, dt * 60)
             self.dx = self.dx * transitionFactor
             self.dy = self.dy * transitionFactor
             self.isDrifting = true
             
         else
             -- FRENADO FINAL - Velocidad muy baja
             local finalBrakeFactor = math.pow(self.brakePower * 0.4, dt * 60)
             self.dx = self.dx * finalBrakeFactor
             self.dy = self.dy * finalBrakeFactor
             self.isDrifting = false

         end
         
         -- Parar completamente solo si extremadamente lento
         local speed = math.sqrt(self.dx * self.dx + self.dy * self.dy)
         if speed < 1.0 then
             self.dx, self.dy = 0, 0
             self.isDrifting = false

         end
     else
         -- Drag normal del espacio cuando no se frena
         self.dx = self.dx * math.pow(self.drag, dt * 60)
         self.dy = self.dy * math.pow(self.drag, dt * 60)
         self.isDrifting = false

     end
     

    
    -- Limit maximum speed (con boost puede exceder temporalmente)
    local speed = math.sqrt(self.dx * self.dx + self.dy * self.dy)
    local currentMaxSpeed = effectiveMaxSpeed
    if self.isBoostActive and self.boostDuration > 0 then
        currentMaxSpeed = effectiveMaxSpeed * self.boostMultiplier
    end
    
    if speed > currentMaxSpeed then
        self.dx = (self.dx / speed) * currentMaxSpeed
        self.dy = (self.dy / speed) * currentMaxSpeed
    end
    
    -- Update position with phase restrictions
    local newX = self.x + self.dx * dt * 60
    local newY = self.y + self.dy * dt * 60
    
    -- Check phase system restrictions
    local PhaseSystem = require 'src.gameplay.phase_system'
    if PhaseSystem and PhaseSystem.config.restrictMovement then
        local success, result = pcall(function()
            return PhaseSystem.update(dt, newX, newY)
        end)
        
        if success and result == "boundary_hit" then
            -- Player hit phase boundary, clamp position
            local clampedX, clampedY = PhaseSystem.clampPlayerToCurrentPhase(newX, newY)
            self.x = clampedX
            self.y = clampedY
            
            -- Apply friction to velocity when hitting boundary
            self.dx = self.dx * 0.3
            self.dy = self.dy * 0.3
        else
            -- Normal movement
            self.x = newX
            self.y = newY
        end
    else
        -- No phase restrictions, normal movement
        self.x = newX
        self.y = newY
    end

    -- Resolver colisiones físicas nave-asteroide
    self:resolveAsteroidCollisions(dt)
    
    -- Thruster particles have been removed
    
    -- Update stats system
    self.stats:update(dt, isMoving)
    
    -- Actualizar proyectiles
    self:updateProjectiles(dt)
end

function Naves:resolveAsteroidCollisions(dt)
    local okSub, SubLevelManager = pcall(function() return require 'src.maps.systems.sublevel_manager' end)
    if okSub and SubLevelManager and SubLevelManager.getStatus then
        local status = SubLevelManager.getStatus()
        if status and status.active then return end
    end

    local Map = package.loaded['src.maps.map']
    local MapConfig = package.loaded['src.maps.config.map_config']
    if not Map or not Map.getChunkNonBlocking or not MapConfig then return end

    local ws = MapConfig.chunk.worldScale or 1.0
    local tileSizeScaled = MapConfig.chunk.tileSize * ws
    local sizePixels = MapConfig.chunk.size * MapConfig.chunk.tileSize
    local strideScaled = (sizePixels + (MapConfig.chunk.spacing or 0)) * ws
    local baseSizes = (MapConfig.asteroids and MapConfig.asteroids.baseSizes) or {8, 15, 25}
    local sizeScale = (MapConfig.asteroids and MapConfig.asteroids.sizeScale) or 1.0

    local px, py = self.x or 0, self.y or 0
    local shipRadius = (self.size or 14) * (self.worldScale or 1) * 0.85
    local margin = shipRadius + (baseSizes[3] or 25) * sizeScale * ws * 1.4

    local minCX = math.floor((px - margin) / strideScaled)
    local maxCX = math.floor((px + margin) / strideScaled)
    local minCY = math.floor((py - margin) / strideScaled)
    local maxCY = math.floor((py + margin) / strideScaled)

    for cy = minCY, maxCY do
        for cx = minCX, maxCX do
            local chunk = Map.getChunkNonBlocking(cx, cy)
            if chunk and chunk.tiles then
                local chunkBaseX = cx * strideScaled
                local chunkBaseY = cy * strideScaled
                local chunkBaseTileX = cx * MapConfig.chunk.size
                local chunkBaseTileY = cy * MapConfig.chunk.size

                local minTX = math.max(0, math.floor((px - margin - chunkBaseX) / tileSizeScaled))
                local maxTX = math.min(MapConfig.chunk.size - 1, math.ceil((px + margin - chunkBaseX) / tileSizeScaled))
                local minTY = math.max(0, math.floor((py - margin - chunkBaseY) / tileSizeScaled))
                local maxTY = math.min(MapConfig.chunk.size - 1, math.ceil((py + margin - chunkBaseY) / tileSizeScaled))

                for ty = minTY, maxTY do
                    local row = chunk.tiles[ty]
                    if row then
                        local astY = chunkBaseY + ty * tileSizeScaled
                        local globalY = chunkBaseTileY + ty
                        for tx = minTX, maxTX do
                            local tileType = row[tx]
                            if tileType and tileType >= MapConfig.ObjectType.ASTEROID_SMALL and tileType <= MapConfig.ObjectType.ASTEROID_LARGE then
                                local astX = chunkBaseX + tx * tileSizeScaled
                                local globalX = chunkBaseTileX + tx
                                local baseSize = (baseSizes[tileType] or 15) * sizeScale * ws
                                local state = (globalX * 1103515245 + globalY * 12345 + tileType * 2654435761) % 4294967296
                                state = (state * 1664525 + 1013904223) % 4294967296
                                local r1 = state / 4294967296
                                local astRadius = baseSize * (0.8 + r1 * 0.4) * 0.85

                                local dx = self.x - astX
                                local dy = self.y - astY
                                local distSq = dx * dx + dy * dy
                                local minDist = shipRadius + astRadius
                                if distSq < minDist * minDist then
                                    local dist = math.sqrt(distSq)
                                    local nx, ny = 1, 0
                                    if dist > 0.0001 then
                                        nx, ny = dx / dist, dy / dist
                                    end
                                    local overlap = minDist - dist
                                    self.x = self.x + nx * overlap
                                    self.y = self.y + ny * overlap

                                    local vn = (self.dx or 0) * nx + (self.dy or 0) * ny
                                    if vn < 0 then
                                        local impactSpeed = -vn
                                        local restitution = 0.55
                                        self.dx = ((self.dx or 0) - (1 + restitution) * vn * nx) * 0.85
                                        self.dy = ((self.dy or 0) - (1 + restitution) * vn * ny) * 0.85

                                        local now = love.timer.getTime()
                                        if impactSpeed > 18 and (now - (self._lastImpactDamageTime or 0)) > 0.35 then
                                            self._lastImpactDamageTime = now
                                            local dmg = math.max(1, (impactSpeed - 18) * 0.35)
                                            self:takeDamage(dmg)
                                            if self.addImpactEffect then
                                                self:addImpactEffect(self.x - nx * shipRadius, self.y - ny * shipRadius, {1.0, 0.75, 0.3, 1.0})
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Colisión de nave contra objetos sólidos especiales (mega_asteroid, estaciones, dead_star)
    for cy = minCY - 1, maxCY + 1 do
        for cx = minCX - 1, maxCX + 1 do
            local chunk = Map.getChunkNonBlocking(cx, cy)
            if chunk and chunk.specialObjects then
                local chunkBaseX = cx * strideScaled
                local chunkBaseY = cy * strideScaled
                for i = 1, #chunk.specialObjects do
                    local obj = chunk.specialObjects[i]
                    if obj and (obj.type == "mega_asteroid" or obj.type == "ancient_station" or obj.type == "dead_star" or obj.type == MapConfig.ObjectType.STATION) then
                        local objX = chunkBaseX + (obj.x or 0) * ws
                        local objY = chunkBaseY + (obj.y or 0) * ws
                        local objRadius = (obj.size or 30) * 0.85
                        local dx = self.x - objX
                        local dy = self.y - objY
                        local distSq = dx * dx + dy * dy
                        local minDist = shipRadius + objRadius
                        if distSq < minDist * minDist then
                            local dist = math.sqrt(distSq)
                            local nx, ny = 1, 0
                            if dist > 0.0001 then
                                nx, ny = dx / dist, dy / dist
                            end
                            local overlap = minDist - dist
                            self.x = self.x + nx * overlap
                            self.y = self.y + ny * overlap

                            local vn = (self.dx or 0) * nx + (self.dy or 0) * ny
                            if vn < 0 then
                                local impactSpeed = -vn
                                local restitution = 0.55
                                self.dx = ((self.dx or 0) - (1 + restitution) * vn * nx) * 0.85
                                self.dy = ((self.dy or 0) - (1 + restitution) * vn * ny) * 0.85

                                local now = love.timer.getTime()
                                if impactSpeed > 18 and (now - (self._lastImpactDamageTime or 0)) > 0.35 then
                                    self._lastImpactDamageTime = now
                                    local dmg = math.max(1, (impactSpeed - 18) * 0.35)
                                    self:takeDamage(dmg)
                                    if self.addImpactEffect then
                                        self:addImpactEffect(self.x - nx * shipRadius, self.y - ny * shipRadius, {1.0, 0.75, 0.3, 1.0})
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function Naves:handleInput()
    -- Update input states
    self.input = {
        -- Movement controls
        forward = love.keyboard.isDown("w"),
        backward = love.keyboard.isDown("s"),
        left = love.keyboard.isDown("a"),
        right = love.keyboard.isDown("d"),
        brake = love.keyboard.isDown("lshift"),
        boost = love.keyboard.isDown("space"),  -- Boost temporal
    }
    self.input.isMoving = self.input.forward or self.input.backward or self.input.left or self.input.right
    
    -- Get mouse position in screen coordinates
    local mx, my = love.mouse.getPosition()
    
    -- Acceder a la cámara a través del bus central World
    local w = getWorld()
    local cam = (w and (w.getCamera and w.getCamera() or w.get('camera')))

    if cam then
        -- Convert mouse position to world coordinates using the camera
        local worldX, worldY = cam:screenToWorld(mx, my)
        
        if worldX and worldY then
            local dx = worldX - self.x
            local dy = worldY - self.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            -- Only update direction if mouse is far enough from player
            if distance > self.minMouseDistance then
                -- Normalize the direction vector
                self.mouseDirection.x = dx / distance
                self.mouseDirection.y = dy / distance
                
                -- La rotación ahora se maneja en la función update principal
            end
        end
    end
end

function Naves:updateThrusterParticles(dt)
    -- Add new particles when moving forward
    if self.input.forward and math.random() < 0.8 and self.stats:canMove() then
        -- Calculate thruster position based on sprite or fallback size
        -- Now the thruster is at the bottom of the sprite (positive Y in sprite space)
        local thrusterOffset = self.sprite and (self.spriteOffsetY * self.spriteScale * 0.8) or self.size
        
        -- Calculate position in world space
        local particleX = self.x + math.sin(self.rotation) * thrusterOffset
        local particleY = self.y - math.cos(self.rotation) * thrusterOffset
        
        -- Calculate velocity in the direction the thruster is pointing (down in sprite space)
        local velX = math.sin(self.rotation) * 50
        local velY = -math.cos(self.rotation) * 50
        
        local particle = {
            x = particleX,
            y = particleY,
            vx = velX + math.random(-20, 20),
            vy = velY + math.random(-20, 20),
            life = 1,
            size = math.random(2, 4)
        }
        table.insert(self.thrusterParticles, particle)
    end
    
    -- Update existing particles
    for i = #self.thrusterParticles, 1, -1 do
        local p = self.thrusterParticles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt * 2
        
        if p.life <= 0 then
            table.remove(self.thrusterParticles, i)
        end
    end
end

-- Functions for testing damage and fuel
function Naves:takeDamage(damage)
    local died = self.stats:takeDamage(damage)
    local w = getWorld()
    local audio = w and (w.getAudio and w.getAudio() or w.get('audio'))
    if audio and audio.play then
        if died then
            audio.play("explosion", { volume = 0.9 })
        else
            audio.play("hit", { volume = 0.75, pitchVariation = 0.08 })
        end
    end
    if died then
        -- Nota: Aún no hay mecánica de muerte/respawn definida; mantener al jugador en su posición actual
        return true
    end
    return died
end

function Naves:die(spawnPoint)
    -- Reservado para futura mecánica de muerte; no teletransportar al jugador a (0, 0)
    local w = getWorld()
    local audio = w and (w.getAudio and w.getAudio() or w.get('audio'))
    if audio and audio.play then
        pcall(function() audio.play("explosion", { volume = 0.9 }) end)
    end
end

function Naves:heal(amount)
    self.stats:heal(amount)
end

function Naves:addFuel(amount)
    self.stats:addFuel(amount)
end

function Naves:savePreviousState()
    self.prevX = self.x
    self.prevY = self.y
    self.prevRotation = self.rotation or 0
    
    -- Si estamos en EVA, guardar también el estado del astronauta
    if self.isInEVA and self.evaPlayer and self.evaPlayer.savePreviousState then
        self.evaPlayer:savePreviousState()
    end
end

-- Renderizado geométrico de cascos y propulsores: ver src/entities/ship_renderer.lua
ShipRenderer.install(Naves)

function Naves:toggleHyperTravel(targetMaxSpeed)
    self.hyperTravelEnabled = not self.hyperTravelEnabled
    
    if self.hyperTravelEnabled then
        if targetMaxSpeed and type(targetMaxSpeed) == "number" then
            self.hyperParams.maxSpeed = targetMaxSpeed
        end
        self.maxSpeed = self.hyperParams.maxSpeed
        self.forwardAccel = self.hyperParams.forwardAccel
        self.strafeAccel = self.hyperParams.strafeAccel
        self.backwardAccel = self.hyperParams.backwardAccel
        self.drag = self.hyperParams.drag
    else
        self.maxSpeed = self.baseParams.maxSpeed
        self.forwardAccel = self.baseParams.forwardAccel
        self.strafeAccel = self.baseParams.strafeAccel
        self.backwardAccel = self.baseParams.backwardAccel
        self.drag = self.baseParams.drag
        
        -- Limitar la velocidad actual al máximo normal cuando se apaga el modo
        local speed = math.sqrt(self.dx * self.dx + self.dy * self.dy)
        if speed > self.maxSpeed and speed > 0 then
            self.dx = (self.dx / speed) * self.maxSpeed
            self.dy = (self.dy / speed) * self.maxSpeed
        end
    end
    
    return self.hyperTravelEnabled
end

-- Métodos de persistencia de estado
function Naves:updateShipRegistry()
    if shipRegistry[self.shipId] then
        shipRegistry[self.shipId].position = {x = self.x, y = self.y}
        shipRegistry[self.shipId].stats = self.stats
        shipRegistry[self.shipId].settings = self.shipSettings
        shipRegistry[self.shipId].damageState = self.damageState
        -- Actualizar inventario en el registro
        shipRegistry[self.shipId].inventory = self.inventory and {
            items = self.inventory.items,
            shipType = self.inventory.shipType,
            compartments = self.inventory.compartments and {
                eva = self.inventory.compartments.eva and {
                    maxSlots = self.inventory.compartments.eva.maxSlots,
                    items = self.inventory.compartments.eva.items
                } or { maxSlots = 3, items = { nil, nil, nil } }
            } or nil
        } or nil
        shipRegistry[self.shipId].lastSeen = love.timer.getTime()
    end
end

function Naves:saveShipState()
    -- Guardar estado completo de la nave
    local state = {
        shipId = self.shipId,
        shipType = self.shipType,
        shipName = self.shipName,
        position = {x = self.x, y = self.y},
        velocity = {dx = self.dx, dy = self.dy},
        rotation = self.rotation,
        stats = {
            health = {
                current = self.stats.health.currentHealth,
                max = self.stats.health.maxHealth
            },
            shield = {
                current = self.stats.shield.currentShield,
                max = self.stats.shield.maxShield
            },
            fuel = {
                current = self.stats.fuel.currentFuel,
                max = self.stats.fuel.maxFuel
            }
        },
        settings = self.shipSettings,
        damageState = self.damageState,
        -- Guardar inventario específico de la nave
        inventory = self.inventory and {
            items = self.inventory.items,
            shipType = self.inventory.shipType,
            compartments = self.inventory.compartments and {
                eva = self.inventory.compartments.eva and {
                    maxSlots = self.inventory.compartments.eva.maxSlots,
                    items = self.inventory.compartments.eva.items
                } or { maxSlots = 3, items = { nil, nil, nil } }
            } or nil
        } or nil,
        timestamp = love.timer.getTime()
    }
    return state
end

function Naves:loadShipState(state)
    if not state then return false end
    
    self.x = state.position.x
    self.y = state.position.y
    self.dx = state.velocity.dx or 0
    self.dy = state.velocity.dy or 0
    self.rotation = state.rotation or 0
    
    -- Restaurar estadísticas
    if state.stats then
        if state.stats.health then
            self.stats.health.currentHealth = state.stats.health.current
            self.stats.health.maxHealth = state.stats.health.max
        end
        if state.stats.shield then
            self.stats.shield.currentShield = state.stats.shield.current
            self.stats.shield.maxShield = state.stats.shield.max
        end
        if state.stats.fuel then
            self.stats.fuel.currentFuel = state.stats.fuel.current
            self.stats.fuel.maxFuel = state.stats.fuel.max
        end
    end
    
    -- Restaurar configuraciones y estado de daño
    if state.settings then
        self.shipSettings = state.settings
    end
    if state.damageState then
        self.damageState = state.damageState
    end
    
    -- Restaurar inventario específico de la nave
    if state.inventory then
        -- Si ya existe un inventario, restaurar su estado
        if self.inventory then
            self.inventory.items = state.inventory.items or {}
            self.inventory.shipType = state.inventory.shipType or self.shipType
            self.inventory.player = self  -- Asegurar referencia del jugador
        else
            -- Crear nuevo inventario con el estado guardado
            local InventorySystem = require 'src.maps.systems.inventory_system'
            self.inventory = InventorySystem:new(state.inventory.shipType or self.shipType)
            self.inventory.items = state.inventory.items or {}
            self.inventory.player = self  -- Asignar referencia del jugador al inventario
        end
        -- Restaurar compartimentos si existen (especialmente EVA)
        if state.inventory.compartments and state.inventory.compartments.eva then
            if self.inventory.compartments and self.inventory.compartments.eva then
                self.inventory.compartments.eva.maxSlots = state.inventory.compartments.eva.maxSlots or self.inventory.compartments.eva.maxSlots or 3
                self.inventory.compartments.eva.items = state.inventory.compartments.eva.items or self.inventory.compartments.eva.items or { nil, nil, nil }
            end
        end
        
        -- Restaurar efectos pasivos después de cargar el inventario
        if self.inventory and self.inventory.compartments and self.inventory.compartments.passives then
            local PassiveManager = require 'src.item_systems.passive_manager'
            PassiveManager.initialize()
            
            local passiveComp = self.inventory.compartments.passives
            if passiveComp and passiveComp.items then
                for slotIndex, item in pairs(passiveComp.items) do
                    if item and item.data then
                        -- Aplicar efecto pasivo con ID único basado en slot
                        local uniqueId = "passive_slot_" .. slotIndex
                        PassiveManager.applyPassiveEffect(self, item.data, uniqueId)
                    end
                end
            end
        end
    end
    
    self:updateShipRegistry()
    return true
end

function Naves:applyDamage(damageType, amount)
    -- Aplicar daño específico por tipo
    amount = amount * (self.shipSettings.damageResistance or 1.0)
    
    if damageType == "hull" then
        self.damageState.hullIntegrity = math.max(0, self.damageState.hullIntegrity - amount)
        self.stats.health.currentHealth = math.max(0, self.stats.health.currentHealth - amount)
    elseif damageType == "engine" then
        self.damageState.engineEfficiency = math.max(0, self.damageState.engineEfficiency - amount)
    elseif damageType == "shield" then
        self.damageState.shieldGeneratorStatus = math.max(0, self.damageState.shieldGeneratorStatus - amount)
    elseif damageType == "hyperdrive" then
        self.damageState.hyperDriveStatus = math.max(0, self.damageState.hyperDriveStatus - amount)
    elseif damageType == "lifesupport" then
        self.damageState.lifeSupportStatus = math.max(0, self.damageState.lifeSupportStatus - amount)
    end
    
    self:updateShipRegistry()
end

function Naves:repairSystem(systemType, amount)
    -- Reparar sistema específico
    if systemType == "hull" then
        self.damageState.hullIntegrity = math.min(100, self.damageState.hullIntegrity + amount)
    elseif systemType == "engine" then
        self.damageState.engineEfficiency = math.min(100, self.damageState.engineEfficiency + amount)
    elseif systemType == "shield" then
        self.damageState.shieldGeneratorStatus = math.min(100, self.damageState.shieldGeneratorStatus + amount)
    elseif systemType == "hyperdrive" then
        self.damageState.hyperDriveStatus = math.min(100, self.damageState.hyperDriveStatus + amount)
    elseif systemType == "lifesupport" then
        self.damageState.lifeSupportStatus = math.min(100, self.damageState.lifeSupportStatus + amount)
    end
    
    self:updateShipRegistry()
end

-- EVA System Methods
function Naves:enterEVA()
    if self.isInEVA then return false end
    
    -- Update EVA player position to ship position
    if self.evaPlayer then
        self.evaPlayer.x = self.x
        self.evaPlayer.y = self.y
    end
    self.isInEVA = true

    -- Cerrar inventario de la nave si estuviera abierto al salir a EVA
    if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
        if InventoryUI.close then
            InventoryUI:close()
        else
            -- Fallback por si no existe close
            InventoryUI:toggle()
        end
    end
    
    print("Player entered EVA mode")
    return true
end

function Naves:exitEVA(targetShip)
    if not self.isInEVA or not self.evaPlayer then return false end

    -- Si no se especifica targetShip, buscar la nave abordable más cercana
    if not targetShip then
        local canEnter, nearbyShip = self.evaPlayer:canEnterShip()
        if canEnter and nearbyShip then
            targetShip = nearbyShip
        else
            targetShip = self.evaPlayer.ship or self
        end
    end

    local World = getWorld()
    local audio = World and (World.getAudio and World.getAudio() or World.get('audio'))

    -- Cerrar inventario EVA si estuviera abierto al volver a la nave
    if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() then
        if EVAInventoryUI.close then
            EVAInventoryUI:close()
        else
            EVAInventoryUI:toggle()
        end
    end

    -- CASO 1: Re-entrar a la misma nave de la que se salió
    if targetShip == self then
        self.isInEVA = false
        self.isPiloted = true
        self.isAbandoned = false
        self.evaPlayer.ship = self
        self.evaKeyPressed = true
        
        if audio and audio.play then
            pcall(function() audio.play("item_equip", { volume = 0.75, pitch = 1.1 }) end)
        end

        print(string.format("[EVA] Re-entrada a la nave: %s (ID %d)", self.shipName, self.shipId))
        return true
    end

    -- CASO 2: Abordar una nueva nave (Boarding & Ship Switch)
    print(string.format("[BOARDING] Abordando nueva nave: %s (ID %d) desde %s (ID %d)",
        targetShip.shipName, targetShip.shipId, self.shipName, self.shipId))

    -- 1. Desactivar y abandonar la nave anterior (permanece en su posición real en el espacio)
    self.isPiloted = false
    self.isAbandoned = true
    self.isInEVA = false
    self.evaKeyPressed = false
    self.dx = (self.dx or 0) * 0.4
    self.dy = (self.dy or 0) * 0.4

    -- 2. Activar la nave abordada
    targetShip.isPiloted = true
    targetShip.isAbandoned = false
    targetShip.isInEVA = false
    targetShip.driftAngularSpeed = 0 -- Frenar deriva rotacional pasiva
    targetShip.evaKeyPressed = true

    -- 3. Conectar el astronauta EVA a la nueva nave
    if not targetShip.evaPlayer then
        targetShip.evaPlayer = self.evaPlayer
    end
    targetShip.evaPlayer.ship = targetShip
    targetShip.evaPlayer.stats = targetShip.stats

    -- 4. Actualizar el World context (nueva entidad activa del jugador)
    if World and World.set then
        World.set('player', targetShip)
    end

    -- 5. Actualizar la cámara para que siga suavemente a la nueva nave
    local camera = World and (World.getCamera and World.getCamera() or World.get('camera'))
    if camera and type(camera.follow) == "function" then
        pcall(function() camera:follow(targetShip, 0) end)
    end

    -- 6. Actualizar las referencias del HUD
    local HUD = package.loaded['src.ui.hud.core']
    if HUD and HUD.updateReferences then
        pcall(function() HUD.updateReferences(World) end)
    end

    -- 7. Efecto de audio de compuerta presurizada / abordaje
    if audio and audio.play then
        pcall(function() audio.play("item_equip", { volume = 0.85, pitch = 0.95 }) end)
    end

    print(string.format("✓ [BOARDING] ¡Abordaje exitoso! Ahora pilotas: %s (%s)",
        targetShip.shipName, targetShip.shipType))
    return true
end

function Naves:handleEVAControls()
    -- Combinación S+E para salir de la nave a modo EVA
    if not self.isInEVA then
        local sPressed = love.keyboard.isDown('s')
        local ePressed = love.keyboard.isDown('e')
        
        if sPressed and ePressed and not self.evaKeyPressed then
            self.evaKeyPressed = true
            self:enterEVA()
        elseif not (sPressed and ePressed) then
            self.evaKeyPressed = false
        end
    else
        -- Tecla E para abordar la nave cercana (propia o abandonada)
        local ePressed = love.keyboard.isDown('e')
        
        if ePressed and not self.evaKeyPressed then
            local canEnter, targetShip = self.evaPlayer:canEnterShip()
            if canEnter and targetShip then
                self.evaKeyPressed = true
                self:exitEVA(targetShip)
            end
        elseif not ePressed then
            self.evaKeyPressed = false
        end
    end
end

function Naves:updateEVA(dt)
    if self.isInEVA and self.evaPlayer then
        self.evaPlayer:update(dt)
    end
end

function Naves:drawEVA()
    if self.isInEVA and self.evaPlayer then
        self.evaPlayer:draw()
    end
end

function Naves:getActiveEntity()
    if self.isInEVA and self.evaPlayer then
        return self.evaPlayer
    else
        return self
    end
end


function Naves.boardShip(targetShip, pilotEntity)
    if not targetShip then return false end
    local World = getWorld()
    local currentPlayer = World and (World.getPlayer and World.getPlayer() or World.get('player'))
    
    if currentPlayer and currentPlayer.exitEVA then
        return currentPlayer:exitEVA(targetShip)
    end
    return false
end

function Naves.switchToShip(targetShip, currentShip)
    if not targetShip then
        print("[SHIP SWITCH] Error: Invalid target ship provided")
        return false
    end
    
    local World = getWorld()
    currentShip = currentShip or (World and (World.getPlayer and World.getPlayer() or World.get('player')))
    if currentShip and currentShip.exitEVA then
        return currentShip:exitEVA(targetShip)
    end
    return false
end

--[[
    Registra un destello y chispas de impacto en coordenadas del mundo
--]]
function Naves:addImpactEffect(x, y, color)
    self.impactEffects = self.impactEffects or {}
    if #self.impactEffects >= 24 then
        table.remove(self.impactEffects, 1)
    end
    local c = color or {1.0, 0.45, 0.25, 1.0}
    local sparks = {}
    for i = 1, 6 do
        local a = (i / 6) * math.pi * 2 + (math.random() - 0.5) * 0.45
        local spd = 35 + math.random() * 55
        sparks[i] = {
            vx = math.cos(a) * spd,
            vy = math.sin(a) * spd
        }
    end
    table.insert(self.impactEffects, {
        x = x,
        y = y,
        age = 0,
        duration = 0.22,
        color = {c[1] or 1, c[2] or 0.5, c[3] or 0.3},
        sparks = sparks
    })
end

--[[
    Actualiza todos los proyectiles activos y efectos de impacto
    @param dt: tiempo delta
--]]
function Naves:updateProjectiles(dt)
    if self.impactEffects then
        for i = #self.impactEffects, 1, -1 do
            local eff = self.impactEffects[i]
            eff.age = eff.age + dt
            if eff.age >= eff.duration then
                table.remove(self.impactEffects, i)
            end
        end
    end

    if not self.projectiles then
        return
    end
    
    -- Actualizar proyectiles y remover los destruidos en el mismo frame
    for i = #self.projectiles, 1, -1 do
        local projectile = self.projectiles[i]
        
        if projectile:isDestroyed() then
            table.remove(self.projectiles, i)
        else
            projectile:update(dt)
            if projectile:isDestroyed() then
                table.remove(self.projectiles, i)
            end
        end
    end
end

--[[
    Renderiza todos los proyectiles activos y efectos de impacto
--]]
function Naves:drawProjectiles()
    if self.projectiles then
        for _, projectile in ipairs(self.projectiles) do
            if not projectile:isDestroyed() then
                projectile:draw()
            end
        end
    end

    if self.impactEffects and #self.impactEffects > 0 then
        local r, g, b, a = love.graphics.getColor()
        for i = 1, #self.impactEffects do
            local eff = self.impactEffects[i]
            local k = math.min(1, eff.age / eff.duration)
            local alpha = 1.0 - k
            local radius = 3 + k * 14
            love.graphics.setColor(eff.color[1], eff.color[2], eff.color[3], alpha * 0.75)
            love.graphics.circle("line", eff.x, eff.y, radius)
            love.graphics.setColor(1, 1, 1, alpha * 0.9)
            love.graphics.circle("fill", eff.x, eff.y, (1.0 - k) * 4)
            for s = 1, #eff.sparks do
                local sp = eff.sparks[s]
                local sx = eff.x + sp.vx * eff.age
                local sy = eff.y + sp.vy * eff.age
                love.graphics.setColor(eff.color[1], eff.color[2], eff.color[3], alpha)
                love.graphics.circle("fill", sx, sy, 1.5 * alpha)
            end
        end
        love.graphics.setColor(r, g, b, a)
    end
end

--[[
    Dispara un proyectil desde la nave hacia la posición del mouse
    @param mouseX, mouseY: posición del mouse en coordenadas de pantalla
--]]
function Naves:shoot(mouseX, mouseY)
    -- Verificar que la nave no esté en EVA
    if self.isInEVA then
        return false
    end
    
    -- Si tenemos sistema de armas, usarlo en su lugar
    if self.weaponSystem and self.weaponSystem.currentWeapon then
        return self.weaponSystem:shoot(mouseX, mouseY)
    end
    
    -- Acceso a sistemas (física opcional si opera por cinemática desacoplada)
    local w = getWorld()
    local physMgr = w and w.get('physics')
    local box2dWorld = (physMgr and physMgr.getWorld and physMgr:getWorld()) or nil
    
    -- Convertir coordenadas del mouse a coordenadas del mundo
    local worldMouseX, worldMouseY
    local cam = (w and (w.getCamera and w.getCamera() or w.get('camera')))
    if cam then
        worldMouseX, worldMouseY = cam:screenToWorld(mouseX, mouseY)
    else
        -- Fallback si no hay cámara
        worldMouseX, worldMouseY = mouseX, mouseY
    end
    
    -- Posición de spawn del proyectil (frente de la nave)
    local dx = worldMouseX - self.x
    local dy = worldMouseY - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Evitar división por cero
    if distance < 1 then
        return
    end
    
    -- Normalizar dirección para calcular posición de spawn
    dx = dx / distance
    dy = dy / distance
    
    local spawnDistance = self.size + 10 -- Un poco adelante de la nave
    local spawnX = self.x + dx * spawnDistance
    local spawnY = self.y + dy * spawnDistance
    
    -- Calcular ángulo de disparo
    local angle = math.atan2(dy, dx)
    
    -- Crear el proyectil, aplicando límites si estamos en subnivel
    local custom_config = { owner = self }
    local ok, SubLevelManager = pcall(function() return require 'src.maps.systems.sublevel_manager' end)
    if ok and SubLevelManager and SubLevelManager.getStatus then
        local status = SubLevelManager.getStatus()
        if status and status.active then
            custom_config.world_bounds = { min_x = -20000, max_x = 20000, min_y = -20000, max_y = 20000 }
        end
    end

    local BasicRedProjectile = require('src.physics.projectiles.types.basic_red_projectile')
    local projectile = BasicRedProjectile.new(box2dWorld, spawnX, spawnY, angle, nil, custom_config)
    
    -- Agregar el proyectil al sistema de física si está disponible
    if projectile then
        if physMgr and physMgr.addProjectile then
            physMgr:addProjectile(projectile)
        end
        
        -- Almacenar el proyectil para actualizaciones y renderizado
        if not self.projectiles then
            self.projectiles = {}
        end
        table.insert(self.projectiles, projectile)
        
        local audio = w and (w.getAudio and w.getAudio() or w.get('audio'))
        if audio and audio.play then
            audio.play("laser", { pitchVariation = 0.05, volume = 0.8 })
        end
        
        print("[SHOOT] Fired projectile from (", spawnX, ",", spawnY, ")")
        return true
    else
        print("[SHOOT] Error: Could not create projectile")
        return false
    end
end

-- Manejar rueda del mouse para cambio de armas
function Naves:wheelmoved(x, y)
    if self.weaponSystem then
        self.weaponSystem:wheelmoved(x, y)
    end
end

-- Métodos de conveniencia para el sistema de armas
function Naves:equipWeapon(weaponItem, slot)
    if self.weaponSystem then
        return self.weaponSystem:equipWeapon(weaponItem, slot)
    end
    return false
end

function Naves:getCurrentWeaponInfo()
    if self.weaponSystem then
        return self.weaponSystem:getCurrentWeaponInfo()
    end
    return nil
end

function Naves:getEquippedWeapons()
    if self.weaponSystem then
        return self.weaponSystem:getEquippedWeapons()
    end
    return {}
end

function Naves:switchToWeaponSlot(slot)
    if self.weaponSystem then
        return self.weaponSystem:switchToSlot(slot)
    end
    return false
end

function Naves:autoEquipWeaponsFromInventory()
    if self.weaponSystem then
        return self.weaponSystem:autoEquipFromInventory()
    end
    return false
end

return Naves
