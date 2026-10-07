-- src/entities/naves.lua
-- Sistema de gestión de naves con persistencia de estado individual

local Naves = {}
local PlayerStats = require 'src.entities.player_stats'
local EVAPlayer = require 'src.entities.eva_player'
local InventorySystem = require 'src.maps.systems.inventory_system'
local InventoryUI = require 'src.ui.inventory_ui'
local EVAInventoryUI = require 'src.ui.eva_inventory_ui'
local WeaponSystem = require 'src.entities.weapon_system'

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
    
    -- Support movements (A, S, D) - CORREGIDO para orientación relativa a la nave
    if self.input.left and canMove then       -- A - Strafe left relative to ship orientation
        local leftX = -math.sin(self.rotation)
        local leftY = math.cos(self.rotation)
        moveX = moveX + leftX * 0.8  -- Mejorado para mejor control
        moveY = moveY + leftY * 0.8
        isMoving = true
    end
    
    if self.input.right and canMove then      -- D - Strafe right relative to ship orientation
        local rightX = math.sin(self.rotation)
        local rightY = -math.cos(self.rotation)
        moveX = moveX + rightX * 0.8  -- Mejorado para mejor control
        moveY = moveY + rightY * 0.8
        isMoving = true
    end
    
    if self.input.backward and canMove then   -- S - Move backward relative to ship orientation
        local backX = -math.cos(self.rotation)
        local backY = -math.sin(self.rotation)
        moveX = moveX + backX * 0.6  -- Movimiento hacia atrás relativo a la nave
        moveY = moveY + backY * 0.6
        isMoving = true
    end
    
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
             
             -- Calcular componente hacia adelante (en dirección de la nave)
             local forwardX = math.cos(self.rotation)
             local forwardY = math.sin(self.rotation)
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
             if totalSpeed > self.maxSpeed * 1.1 then  -- Permitir 10% extra durante drift
                 local limitFactor = (self.maxSpeed * 1.1) / totalSpeed
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
    local currentMaxSpeed = self.maxSpeed
    if self.isBoostActive and self.boostDuration > 0 then
        currentMaxSpeed = self.maxSpeed * self.boostMultiplier
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
    
    -- Thruster particles have been removed
    
    -- Update stats system
    self.stats:update(dt, isMoving)
    
    -- Actualizar proyectiles
    self:updateProjectiles(dt)
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
    return died
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

function Naves:drawThrusterFlame(offsetX, offsetY, width, color)
    local intensity = self.engineGlow or 1.0
    local time = love.timer.getTime()
    local pulse = 0.85 + 0.15 * math.sin(time * 16)
    local wiggle = math.sin(time * 24) * 0.08
    local length = width * 2.2 * pulse * intensity

    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.rotate(wiggle)

    -- Capa exterior de fuego
    love.graphics.setColor(color[1], color[2], color[3], 0.45 * intensity * pulse)
    love.graphics.polygon("fill",
        -width * 0.6, 0,
        0, length,
        width * 0.6, 0
    )

    -- Capa media brillante
    love.graphics.setColor(math.min(1, color[1] * 1.2), math.min(1, color[2] * 1.2), math.min(1, color[3] * 1.2), 0.75 * intensity * pulse)
    love.graphics.polygon("fill",
        -width * 0.35, 0,
        0, length * 0.65,
        width * 0.35, 0
    )

    -- Núcleo blanco caliente
    love.graphics.setColor(1.0, 1.0, 1.0, 0.9 * intensity * pulse)
    love.graphics.polygon("fill",
        -width * 0.18, 0,
        0, length * 0.35,
        width * 0.18, 0
    )

    love.graphics.pop()
end

function Naves:drawFighterShape(size, isAbandoned)
    local time = love.timer.getTime()
    local alpha = isAbandoned and 0.85 or 1.0

    -- Sombra
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.push()
    love.graphics.translate(3, 3)
    love.graphics.polygon("fill",
        0, -size * 1.8,
        -size * 1.4, size * 0.6,
        -size * 0.5, size * 1.0,
        0, size * 0.4,
        size * 0.5, size * 1.0,
        size * 1.4, size * 0.6
    )
    love.graphics.pop()

    -- Paleta (Grafito militar + carmesí de asalto)
    local cBody = isAbandoned and {0.14, 0.16, 0.19, alpha} or {0.18, 0.21, 0.26, alpha}
    local cAccent = isAbandoned and {0.55, 0.18, 0.20, alpha} or {0.92, 0.16, 0.22, alpha}
    local cMetal = isAbandoned and {0.25, 0.27, 0.30, alpha} or {0.40, 0.44, 0.50, alpha}
    local cGlass = isAbandoned and {0.35, 0.25, 0.10, alpha * 0.7} or {1.0, 0.68, 0.12, 0.95}

    -- 1. Alas principales (Forma en flecha agresiva)
    love.graphics.setColor(cBody[1], cBody[2], cBody[3], cBody[4])
    love.graphics.polygon("fill",
        0, -size * 1.2,
        -size * 1.45, size * 0.55,
        -size * 0.9, size * 0.85,
        0, size * 0.3,
        size * 0.9, size * 0.85,
        size * 1.45, size * 0.55
    )

    -- 2. Paneles de acento carmesí en los bordes de ataque de las alas
    love.graphics.setColor(cAccent[1], cAccent[2], cAccent[3], cAccent[4])
    -- Borde ala izquierda
    love.graphics.polygon("fill",
        -size * 0.3, -size * 0.4,
        -size * 1.45, size * 0.55,
        -size * 1.25, size * 0.55,
        -size * 0.2, -size * 0.2
    )
    -- Borde ala derecha
    love.graphics.polygon("fill",
        size * 0.3, -size * 0.4,
        size * 1.45, size * 0.55,
        size * 1.25, size * 0.55,
        size * 0.2, -size * 0.2
    )

    -- 3. Fuselaje central y morro afilado
    love.graphics.setColor(cMetal[1], cMetal[2], cMetal[3], cMetal[4])
    love.graphics.polygon("fill",
        0, -size * 1.8,
        -size * 0.45, -size * 0.2,
        -size * 0.45, size * 0.9,
        0, size * 0.6,
        size * 0.45, size * 0.9,
        size * 0.45, -size * 0.2
    )

    -- 4. Toberas gemelas reforzadas (Twin Engines)
    love.graphics.setColor(0.10, 0.11, 0.13, alpha)
    love.graphics.rectangle("fill", -size * 0.6, size * 0.8, size * 0.35, size * 0.35, 1, 1)
    love.graphics.rectangle("fill", size * 0.25, size * 0.8, size * 0.35, size * 0.35, 1, 1)

    -- 5. Cockpit angular ámbar de combate
    love.graphics.setColor(cGlass[1], cGlass[2], cGlass[3], cGlass[4])
    love.graphics.polygon("fill",
        0, -size * 1.3,
        -size * 0.22, -size * 0.45,
        0, -size * 0.25,
        size * 0.22, -size * 0.45
    )

    -- 6. Luces / Balizas tácticas
    if isAbandoned then
        local blink = 0.3 + 0.7 * math.abs(math.sin(time * 3.0))
        love.graphics.setColor(1.0, 0.15, 0.2, blink)
        love.graphics.circle("fill", -size * 1.4, size * 0.55, 2.0)
        love.graphics.circle("fill", size * 1.4, size * 0.55, 2.0)
    else
        love.graphics.setColor(1.0, 0.1, 0.1, 0.9)
        love.graphics.circle("fill", -size * 1.4, size * 0.55, 1.8)
        love.graphics.setColor(0.1, 1.0, 0.2, 0.9)
        love.graphics.circle("fill", size * 1.4, size * 0.55, 1.8)

        if self.engineGlow > 0 and (not self.stats or self.stats:canMove()) then
            self:drawThrusterFlame(-size * 0.42, size * 1.15, size * 0.45, {1.0, 0.35, 0.1})
            self:drawThrusterFlame(size * 0.42, size * 1.15, size * 0.45, {1.0, 0.35, 0.1})
        end
    end
end

function Naves:drawCargoShape(size, isAbandoned)
    local time = love.timer.getTime()
    local alpha = isAbandoned and 0.85 or 1.0

    -- Sombra
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.push()
    love.graphics.translate(4, 4)
    love.graphics.rectangle("fill", -size * 1.3, -size * 1.2, size * 2.6, size * 2.3, 4, 4)
    love.graphics.pop()

    -- Paleta (Titanio industrial + amarillo de maquinaria + visor esmeralda)
    local cHull = isAbandoned and {0.20, 0.22, 0.26, alpha} or {0.28, 0.32, 0.38, alpha}
    local cArmor = isAbandoned and {0.30, 0.33, 0.38, alpha} or {0.42, 0.46, 0.54, alpha}
    local cYellow = isAbandoned and {0.55, 0.42, 0.15, alpha} or {0.94, 0.72, 0.14, alpha}
    local cGlass = isAbandoned and {0.15, 0.30, 0.25, alpha * 0.7} or {0.18, 0.90, 0.65, 0.95}

    -- 1. Casco principal blindado (Octogonal ancho)
    love.graphics.setColor(cHull[1], cHull[2], cHull[3], cHull[4])
    love.graphics.polygon("fill",
        -size * 0.8, -size * 1.3,
        size * 0.8, -size * 1.3,
        size * 1.35, -size * 0.6,
        size * 1.35, size * 0.8,
        size * 0.9, size * 1.15,
        -size * 0.9, size * 1.15,
        -size * 1.35, size * 0.8,
        -size * 1.35, -size * 0.6
    )

    -- 2. Contenedores de carga laterales reforzados
    love.graphics.setColor(cArmor[1], cArmor[2], cArmor[3], cArmor[4])
    love.graphics.rectangle("fill", -size * 1.25, -size * 0.5, size * 0.55, size * 1.2, 2, 2)
    love.graphics.rectangle("fill", size * 0.70, -size * 0.5, size * 0.55, size * 1.2, 2, 2)

    -- 3. Bandas industriales en bahías de carga
    love.graphics.setColor(cYellow[1], cYellow[2], cYellow[3], cYellow[4])
    love.graphics.rectangle("fill", -size * 1.2, -size * 0.4, size * 0.45, size * 0.2)
    love.graphics.rectangle("fill", -size * 1.2, size * 0.3, size * 0.45, size * 0.2)
    love.graphics.rectangle("fill", size * 0.75, -size * 0.4, size * 0.45, size * 0.2)
    love.graphics.rectangle("fill", size * 0.75, size * 0.3, size * 0.45, size * 0.2)

    -- 4. Proa blindada reforzada (Ariete pesado)
    love.graphics.setColor(cYellow[1], cYellow[2], cYellow[3], cYellow[4])
    love.graphics.polygon("fill",
        -size * 0.65, -size * 1.25,
        size * 0.65, -size * 1.25,
        size * 0.45, -size * 0.95,
        -size * 0.45, -size * 0.95
    )

    -- 5. Puente de mando blindado (Visor verde esmeralda)
    love.graphics.setColor(cGlass[1], cGlass[2], cGlass[3], cGlass[4])
    love.graphics.rectangle("fill", -size * 0.35, -size * 0.9, size * 0.7, size * 0.25, 2, 2)

    -- 6. Bloque de 3 propulsores pesados
    love.graphics.setColor(0.12, 0.13, 0.16, alpha)
    love.graphics.rectangle("fill", -size * 0.85, size * 1.1, size * 0.4, size * 0.25, 1, 1)
    love.graphics.rectangle("fill", -size * 0.2, size * 1.15, size * 0.4, size * 0.30, 1, 1)
    love.graphics.rectangle("fill", size * 0.45, size * 1.1, size * 0.4, size * 0.25, 1, 1)

    -- 7. Balizas / Luces
    if isAbandoned then
        local blink = 0.3 + 0.7 * math.abs(math.sin(time * 2.0))
        love.graphics.setColor(1.0, 0.75, 0.1, blink)
        love.graphics.circle("fill", -size * 1.25, -size * 0.5, 2.5)
        love.graphics.circle("fill", size * 1.25, -size * 0.5, 2.5)
        love.graphics.circle("fill", -size * 1.25, size * 0.7, 2.5)
        love.graphics.circle("fill", size * 1.25, size * 0.7, 2.5)
    else
        if self.engineGlow > 0 and (not self.stats or self.stats:canMove()) then
            self:drawThrusterFlame(-size * 0.65, size * 1.35, size * 0.45, {0.2, 0.7, 1.0})
            self:drawThrusterFlame(0, size * 1.45, size * 0.55, {0.2, 0.85, 1.0})
            self:drawThrusterFlame(size * 0.65, size * 1.35, size * 0.45, {0.2, 0.7, 1.0})
        end
    end
end

function Naves:drawExplorerShape(size, isAbandoned)
    local time = love.timer.getTime()
    local alpha = isAbandoned and 0.85 or 1.0

    -- Sombra
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.push()
    love.graphics.translate(3, 3)
    love.graphics.polygon("fill",
        0, -size * 1.6,
        -size * 1.1, size * 0.9,
        0, size * 0.5,
        size * 1.1, size * 0.9
    )
    love.graphics.pop()

    -- Paleta (Cobalto espacial + detalles plateados + visor cian)
    local cBody = isAbandoned and {0.12, 0.22, 0.38, alpha} or {0.14, 0.36, 0.72, alpha}
    local cWing = isAbandoned and {0.22, 0.28, 0.36, alpha} or {0.32, 0.52, 0.85, alpha}
    local cAccent = isAbandoned and {0.40, 0.55, 0.65, alpha} or {0.80, 0.90, 1.0, alpha}
    local cGlass = isAbandoned and {0.15, 0.35, 0.45, alpha * 0.7} or {0.30, 0.85, 1.0, 0.95}

    -- 1. Alas delta
    love.graphics.setColor(cWing[1], cWing[2], cWing[3], cWing[4])
    love.graphics.polygon("fill",
        0, -size * 1.0,
        -size * 1.15, size * 0.85,
        0, size * 0.45,
        size * 1.15, size * 0.85
    )

    -- 2. Fuselaje principal
    love.graphics.setColor(cBody[1], cBody[2], cBody[3], cBody[4])
    love.graphics.polygon("fill",
        0, -size * 1.6,
        -size * 0.4, size * 0.8,
        0, size * 0.6,
        size * 0.4, size * 0.8
    )

    -- 3. Detalles de contorno
    love.graphics.setColor(cAccent[1], cAccent[2], cAccent[3], cAccent[4])
    love.graphics.polygon("line",
        0, -size * 1.6,
        -size * 0.4, size * 0.8,
        0, size * 0.6,
        size * 0.4, size * 0.8
    )

    -- 4. Cockpit cian
    love.graphics.setColor(cGlass[1], cGlass[2], cGlass[3], cGlass[4])
    love.graphics.polygon("fill",
        0, -size * 1.1,
        -size * 0.2, -size * 0.2,
        0, -size * 0.05,
        size * 0.2, -size * 0.2
    )

    -- 5. Propulsor central
    love.graphics.setColor(0.12, 0.14, 0.18, alpha)
    love.graphics.rectangle("fill", -size * 0.25, size * 0.75, size * 0.5, size * 0.3, 1, 1)

    -- 6. Balizas / Luces
    if isAbandoned then
        local blink = 0.3 + 0.7 * math.abs(math.sin(time * 2.2))
        love.graphics.setColor(0.2, 0.7, 1.0, blink)
        love.graphics.circle("fill", 0, -size * 0.1, 2.5)
    else
        if self.engineGlow > 0 and (not self.stats or self.stats:canMove()) then
            self:drawThrusterFlame(0, size * 1.05, size * 0.6, {0.3, 0.75, 1.0})
        end
    end
end

function Naves:drawGeometricShip(isAbandoned)
    local size = self.size * (self.worldScale or 1)
    local shipType = self.shipType or "EXPLORER"
    
    if shipType == "FIGHTER" then
        self:drawFighterShape(size, isAbandoned)
    elseif shipType == "CARGO" then
        self:drawCargoShape(size, isAbandoned)
    else
        self:drawExplorerShape(size, isAbandoned)
    end
end

function Naves:draw()
    local World = getWorld()
    local isPlayer = (self.isPiloted or (World and World.getPlayer and World.getPlayer() == self))

    -- Si no es la nave controlada actualmente por el jugador, dibujarla en estado inactivo / abandonada
    if not isPlayer then
        self:drawAbandonedShip()
        return
    end

    -- Si está en modo EVA, dibujar la nave nodriza abandonada y al astronauta
    if self.isInEVA then
        self:drawAbandonedShip()
        self:drawEVA()
        return
    end
    
    local alpha = World and World.get('interpolationAlpha') or 1.0
    local MathUtil = require 'src.utils.math_util'
    
    -- Calcular posición y rotación interpolada
    local renderX = MathUtil.lerp(self.prevX or self.x, self.x, alpha)
    local renderY = MathUtil.lerp(self.prevY or self.y, self.y, alpha)
    local renderRot = MathUtil.lerpAngle(self.prevRotation or self.rotation, self.rotation, alpha)

    love.graphics.push()
    love.graphics.translate(renderX, renderY)
    love.graphics.rotate(renderRot)
    
    local r, g, b, a = love.graphics.getColor()
    
    -- Escudo visual activo
    local shieldPercentage = self.stats and self.stats:getShieldPercentage() or 0
    if shieldPercentage > 0 then
        local shieldAlpha = 0.25 + (shieldPercentage / 100) * 0.45
        local shieldRadius = (self.size * (self.worldScale or 1)) * 1.9
        
        love.graphics.setColor(0.2, 0.6, 1.0, shieldAlpha)
        love.graphics.circle("line", 0, 0, shieldRadius, 24)
        
        if self.stats.shield and self.stats.shield.isRegenerating then
            local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 8)
            love.graphics.setColor(0.2, 0.8, 1.0, pulse * 0.3)
            love.graphics.circle("line", 0, 0, shieldRadius * 1.08, 24)
        end
    end
    
    -- Dibujar la nave según sprite (Explorer) o geometría especializada (Fighter, Cargo, Explorer fallback)
    if self.sprite and self.shipType == "EXPLORER" then
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.push()
        love.graphics.translate(3, 3)
        love.graphics.draw(self.sprite, 
                          -self.spriteOffsetX * self.spriteScale, 
                          -self.spriteOffsetY * self.spriteScale, 
                          0, 
                          self.spriteScale, 
                          self.spriteScale)
        love.graphics.pop()

        local fuelPercentage = self.stats and self.stats:getFuelPercentage() or 100
        if fuelPercentage < 25 then
            love.graphics.setColor(1.0, 0.6, 0.4, 1.0)
        elseif fuelPercentage < 50 then
            love.graphics.setColor(1.0, 1.0, 0.6, 1.0)
        else
            love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
        end
        
        love.graphics.draw(self.sprite, 
                          -self.spriteOffsetX * self.spriteScale, 
                          -self.spriteOffsetY * self.spriteScale, 
                          0, 
                          self.spriteScale, 
                          self.spriteScale)
                          
        if self.engineGlow > 0 and (not self.stats or self.stats:canMove()) then
            self:drawThrusterFlame(0, self.spriteOffsetY * self.spriteScale * 0.85, self.size * 0.8, {1.0, 0.55, 0.1})
        end

        local blinkPhase = love.timer.getTime() * 3
        if math.sin(blinkPhase) > 0 then
            local lightOffset = self.spriteOffsetX * self.spriteScale * 0.6
            love.graphics.setColor(1, 0, 0, 1)
            love.graphics.circle("fill", -lightOffset, 0, 2)
            love.graphics.setColor(0, 1, 0, 1)
            love.graphics.circle("fill", lightOffset, 0, 2)
        end
    else
        self:drawGeometricShip(false)
    end
    
    -- Aviso de combustible crítico
    local fuelPercentage = self.stats and self.stats:getFuelPercentage() or 100
    if fuelPercentage < 15 and math.sin(love.timer.getTime() * 6) > 0 then
        love.graphics.setColor(1, 0, 0, 0.8)
        local warningRadius = (self.size * (self.worldScale or 1)) * 2.2
        love.graphics.circle("line", 0, 0, warningRadius, 16)
    end
    
    love.graphics.setColor(r, g, b, a)
    love.graphics.pop()
    
    -- Dibujar proyectiles de la nave
    love.graphics.push("all")
    self:drawProjectiles()
    love.graphics.pop()
end
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
                        PassiveManager.applyPassiveEffect(item, self, uniqueId)
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

function Naves:drawAbandonedShip()
    local World = getWorld()
    local alpha = World and World.get('interpolationAlpha') or 1.0
    local MathUtil = require 'src.utils.math_util'

    -- Interpolación de posición y rotación para naves a la deriva / abandonadas
    local renderX = MathUtil.lerp(self.prevX or self.x, self.x, alpha)
    local renderY = MathUtil.lerp(self.prevY or self.y, self.y, alpha)
    local renderRot = MathUtil.lerpAngle(self.prevRotation or self.rotation, self.rotation, alpha)

    love.graphics.push()
    love.graphics.translate(renderX, renderY)
    love.graphics.rotate(renderRot)
    
    local r, g, b, a = love.graphics.getColor()
    
    -- Si tiene sprite y es EXPLORER:
    if self.sprite and self.shipType == "EXPLORER" then
        love.graphics.setColor(0, 0, 0, 0.2)
        love.graphics.push()
        love.graphics.translate(3, 3)
        love.graphics.draw(self.sprite, 
                          -self.spriteOffsetX * self.spriteScale, 
                          -self.spriteOffsetY * self.spriteScale, 
                          0, 
                          self.spriteScale, 
                          self.spriteScale)
        love.graphics.pop()

        love.graphics.setColor(0.5, 0.55, 0.65, 0.85)
        love.graphics.draw(self.sprite, 
                          -self.spriteOffsetX * self.spriteScale, 
                          -self.spriteOffsetY * self.spriteScale, 
                          0, 
                          self.spriteScale, 
                          self.spriteScale)

        local blink = 0.3 + 0.7 * math.abs(math.sin(love.timer.getTime() * 2.5))
        love.graphics.setColor(0.2, 0.6, 1.0, blink)
        love.graphics.circle("fill", 0, -self.spriteOffsetY * 0.3, 2.5)
    else
        -- Dibujado geométrico dedicado según clase (FIGHTER, CARGO, EXPLORER) en modo abandonado
        self:drawGeometricShip(true)
    end
    
    love.graphics.setColor(r, g, b, a)
    love.graphics.pop()
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
    Actualiza todos los proyectiles activos
    @param dt: tiempo delta
--]]
function Naves:updateProjectiles(dt)
    if not self.projectiles then
        return
    end
    
    -- Actualizar proyectiles y remover los destruidos
    for i = #self.projectiles, 1, -1 do
        local projectile = self.projectiles[i]
        
        if projectile:isDestroyed() then
            -- Remover proyectil destruido
            table.remove(self.projectiles, i)
        else
            -- Actualizar proyectil activo
            projectile:update(dt)
        end
    end
end

--[[
    Renderiza todos los proyectiles activos
--]]
function Naves:drawProjectiles()
    if not self.projectiles then
        return
    end
    
    for _, projectile in ipairs(self.projectiles) do
        if not projectile:isDestroyed() then
            projectile:draw()
        end
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
    local custom_config = nil
    local ok, SubLevelManager = pcall(function() return require 'src.maps.systems.sublevel_manager' end)
    if ok and SubLevelManager and SubLevelManager.getStatus then
        local status = SubLevelManager.getStatus()
        if status and status.active then
            custom_config = { world_bounds = { min_x = -20000, max_x = 20000, min_y = -20000, max_y = 20000 } }
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
