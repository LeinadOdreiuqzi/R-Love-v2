-- src/entities/naves.lua
-- Sistema de gestión de naves con persistencia de estado individual

local Naves = {}
local PlayerStats = require 'src.entities.player_stats'
local EVAPlayer = require 'src.entities.eva_player'
local InventorySystem = require 'src.maps.systems.inventory_system'
local InventoryUI = require 'src.ui.inventory_ui'
local EVAInventoryUI = require 'src.ui.eva_inventory_ui'
local WeaponSystem = require 'src.entities.weapon_system'

-- Configuración de tipos de naves
local SHIP_TYPES = {
    EXPLORER = {
        name = "Explorer",
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
    player.size = 12  -- Base size for collision/effects
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
    return shipRegistry[shipId]
end

function Naves.getAllShips()
    local ships = {}
    for id, ship in pairs(shipRegistry) do
        table.insert(ships, ship)
    end
    return ships
end

function Naves.getNearbyShips(x, y, radius)
    local nearbyShips = {}
    radius = radius or 500
    
    for id, ship in pairs(shipRegistry) do
        local distance = math.sqrt((ship.position.x - x)^2 + (ship.position.y - y)^2)
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
end

function Naves:loadSprite()
    -- Try to load the ship sprite
    local spritePath = "assets/images/nave.png"
    
    -- Check if file exists and load it
    local success, result = pcall(function()
        return love.graphics.newImage(spritePath)
    end)
    
    if success and result then
        self.sprite = result
        -- Calculate sprite dimensions and offsets for centering
        local spriteWidth = self.sprite:getWidth()
        local spriteHeight = self.sprite:getHeight()
        self.spriteOffsetX = spriteWidth / 2
        self.spriteOffsetY = spriteHeight / 2
        print("Ship sprite loaded successfully: " .. spritePath)
        print("Sprite dimensions: " .. spriteWidth .. "x" .. spriteHeight)
    else
        print("Warning: Could not load ship sprite from " .. spritePath)
        print("Using fallback geometric drawing")
        self.sprite = nil
    end
end

function Naves:update(dt)
    -- Actualizar registro de nave
    self:updateShipRegistry()
    -- Ensure we have a valid delta time
    dt = math.min(dt or 1/60, 1/30)
    
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
    
    -- Convert mouse position to world coordinates
    local worldMouseX = (mouseX - screenX/2) / camera.zoom + camera.x
    local worldMouseY = (mouseY - screenY/2) / camera.zoom + camera.y
    
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
        if not wasBoostActive and _G.runState and _G.runState.incrementBoosts then
            _G.runState:incrementBoosts()
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
    
    -- Access the global camera instance
    local cam = _G.camera 

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
    return self.stats:takeDamage(damage)
end

function Naves:heal(amount)
    self.stats:heal(amount)
end

function Naves:addFuel(amount)
    self.stats:addFuel(amount)
end

function Naves:draw()
    -- If in EVA mode, draw both the abandoned ship and the EVA player
    if self.isInEVA then
        self:drawAbandonedShip()
        self:drawEVA()
        return
    end
    
    -- Thruster particles have been removed as requested
    
    -- Save the current graphics state
    love.graphics.push()
    
    -- Move to player position
    love.graphics.translate(self.x, self.y)
    
    -- Rotate around the center
    love.graphics.rotate(self.rotation)
    
    -- Save the current color
    local r, g, b, a = love.graphics.getColor()
    
    -- Draw shadow first
    if self.sprite then
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.push()
        love.graphics.translate(3, 3)  -- Shadow offset
        love.graphics.draw(self.sprite, 
                          -self.spriteOffsetX * self.spriteScale, 
                          -self.spriteOffsetY * self.spriteScale, 
                          0, 
                          self.spriteScale, 
                          self.spriteScale)
        love.graphics.pop()
    else
        -- Fallback shadow for geometric ship
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.push()
        love.graphics.translate(3, 3)
        love.graphics.polygon("fill", 
            self.size * 1.5, 0,
            -self.size, -self.size,
            -self.size, self.size
        )
        love.graphics.pop()
    end
    
    -- Shield visual effect
    local shieldPercentage = self.stats:getShieldPercentage()
    if shieldPercentage > 0 then
        local shieldAlpha = 0.3 + (shieldPercentage / 100) * 0.4
        local shieldRadius = self.sprite and 
                           (math.max(self.spriteOffsetX, self.spriteOffsetY) * self.spriteScale * 1.2) or 
                           (self.size * 1.8)
        
        love.graphics.setColor(0.2, 0.6, 1.0, shieldAlpha)
        love.graphics.circle("line", 0, 0, shieldRadius, 16)
        
        if self.stats.shield.isRegenerating then
            local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 8)
            love.graphics.setColor(0.2, 0.8, 1.0, pulse * 0.3)
            love.graphics.circle("line", 0, 0, shieldRadius * 1.1, 20)
        end
    end
    
    -- Draw the main ship
    if self.sprite then
        -- SPRITE VERSION
        -- Apply color tinting based on fuel level
        local fuelPercentage = self.stats:getFuelPercentage()
        if fuelPercentage < 25 then
            love.graphics.setColor(1.0, 0.6, 0.4, 1.0)  -- Reddish tint when low fuel
        elseif fuelPercentage < 50 then
            love.graphics.setColor(1.0, 1.0, 0.6, 1.0)  -- Yellowish tint when medium fuel
        else
            love.graphics.setColor(1.0, 1.0, 1.0, 1.0)  -- Normal color
        end
        
        -- Draw the sprite centered
        love.graphics.draw(self.sprite, 
                          -self.spriteOffsetX * self.spriteScale, 
                          -self.spriteOffsetY * self.spriteScale, 
                          0, 
                          self.spriteScale, 
                          self.spriteScale)
    else
        -- FALLBACK GEOMETRIC VERSION (if sprite fails to load)
        local size = self.size * self.worldScale
        
        -- Main body color changes based on fuel level
        local fuelPercentage = self.stats:getFuelPercentage()
        local bodyColor = {0.15, 0.4, 0.8}
        if fuelPercentage < 25 then
            bodyColor = {0.6, 0.3, 0.1}  -- Brown when low fuel
        elseif fuelPercentage < 50 then
            bodyColor = {0.6, 0.6, 0.1}  -- Yellow when medium fuel
        end
        
        -- Main body
        love.graphics.setColor(bodyColor[1], bodyColor[2], bodyColor[3], 1.0)
        love.graphics.polygon("fill", 
            size * 1.5, 0,        -- Front point
            -size, -size,         -- Back left point
            -size * 0.5, 0,       -- Back center
            -size, size           -- Back right point
        )
        
        -- Cockpit window
        love.graphics.setColor(0.3, 0.7, 1.0, 0.9)
        love.graphics.polygon("fill",
            size * 1.2, 0,
            size * 0.3, -size * 0.3,
            size * 0.3, size * 0.3
        )
        
        -- Ship highlight (top edge)
        love.graphics.setColor(0.4, 0.7, 1.0, 0.8)
        love.graphics.polygon("fill",
            size * 1.5, 0,
            -size, -size,
            -size * 0.7, -size * 0.7,
            size * 1.2, 0
        )
    end
    
    -- Engine glow when moving forward (works with both sprite and geometric)
    if self.engineGlow > 0 and self.stats:canMove() then
        local intensity = self.engineGlow
        local thrusterY = self.sprite and (self.spriteOffsetY * self.spriteScale * 0.9) or (self.size * 1.2)
        local thrusterWidth = self.sprite and (self.spriteOffsetX * self.spriteScale * 0.4) or (self.size * 0.7)
        local glowLength = thrusterY * 0.8  -- Length of the glow effect
        
        -- Save the current transformation
        love.graphics.push()
        
        -- Move to the thruster position (bottom center of the ship)
        love.graphics.translate(0, thrusterY)
        
        -- Add some dynamic movement to the glow
        local time = love.timer.getTime()
        local pulse = 0.9 + 0.1 * math.sin(time * 5)  -- Pulsing effect
        local wiggle = math.sin(time * 8) * 0.1  -- Side-to-side movement
        
        love.graphics.push()
        love.graphics.translate(wiggle * 5, 0)  -- Apply wiggle
        
        -- Outer glow (wider and more transparent)
        love.graphics.setColor(1.0, 0.5, 0.1, intensity * 0.3 * pulse)
        love.graphics.polygon("fill",
            -thrusterWidth * 1.2, 0,
            wiggle * 10, glowLength * 2.5 * (0.9 + 0.2 * math.sin(time * 4)),
            thrusterWidth * 1.2, 0
        )
        
        -- Middle glow
        love.graphics.setColor(1.0, 0.6, 0.2, intensity * 0.6 * pulse)
        love.graphics.polygon("fill",
            -thrusterWidth * 0.8, 0,
            wiggle * 5, glowLength * 1.8 * (0.95 + 0.1 * math.sin(time * 3)),
            thrusterWidth * 0.8, 0
        )
        
        -- Inner bright glow
        love.graphics.setColor(1.0, 0.8, 0.4, intensity * 0.9 * pulse)
        love.graphics.polygon("fill",
            -thrusterWidth * 0.5, 0,
            0, glowLength * 1.2 * (1 + 0.05 * math.sin(time * 2)),
            thrusterWidth * 0.5, 0
        )
        
        -- Core (brightest part at the base)
        love.graphics.setColor(1.0, 1.0, 0.8, intensity * pulse)
        love.graphics.rectangle("fill", 
            -thrusterWidth * 0.3 + wiggle * 2, 
            -thrusterWidth * 0.3, 
            thrusterWidth * 0.6, 
            thrusterWidth * 0.6
        )
        
        love.graphics.pop()  -- Pop the wiggle transformation
        love.graphics.pop()  -- Pop the thruster position
        
        -- Navigation lights (only if using sprite)
        if self.sprite then
            local blinkPhase = love.timer.getTime() * 3
            if math.sin(blinkPhase) > 0 then
                local lightOffset = self.spriteOffsetX * self.spriteScale * 0.6
                
                -- Red light on left side (port)
                love.graphics.setColor(1, 0, 0, 1)
                love.graphics.circle("fill", -lightOffset, 0, 2)
                
                -- Green light on right side (starboard)
                love.graphics.setColor(0, 1, 0, 1)
                love.graphics.circle("fill", lightOffset, 0, 2)
            end
        end
    end
    
    -- Low fuel warning
    local fuelPercentage = self.stats:getFuelPercentage()
    if fuelPercentage < 15 and math.sin(love.timer.getTime() * 6) > 0 then
        love.graphics.setColor(1, 0, 0, 0.8)
        local warningRadius = self.sprite and 
                             (math.max(self.spriteOffsetX, self.spriteOffsetY) * self.spriteScale * 1.5) or 
                             (self.size * 2.5)
        love.graphics.circle("line", 0, 0, warningRadius, 12)
    end
    
    -- Restore the color
    love.graphics.setColor(r, g, b, a)
    
    -- Restore the graphics state
    love.graphics.pop()
    
    -- Dibujar proyectiles
    self:drawProjectiles()
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

function Naves:exitEVA()
    if not self.isInEVA or not self.evaPlayer then return false end
    
    -- Return player to ship position
    self.x = self.evaPlayer.x
    self.y = self.evaPlayer.y
    
    -- Keep EVA player but change state
    self.isInEVA = false

    -- Cerrar inventario EVA si estuviera abierto al volver a la nave
    if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() then
        if EVAInventoryUI.close then
            EVAInventoryUI:close()
        else
            EVAInventoryUI:toggle()
        end
    end
    
    print("Player returned to ship")
    return true
end

function Naves:handleEVAControls()
    -- Check for S+E combination to exit ship
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
        -- Check for E to enter ship (only if near ship)
        local ePressed = love.keyboard.isDown('e')
        
        if ePressed and not self.evaKeyPressed and self.evaPlayer:canEnterShip() then
            self.evaKeyPressed = true
            self:exitEVA()
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
    -- Draw the ship as abandoned (dimmed and without effects)
    love.graphics.push()
    
    -- Move to ship position
    love.graphics.translate(self.x, self.y)
    
    -- Rotate around the center
    love.graphics.rotate(self.rotation)
    
    -- Save the current color
    local r, g, b, a = love.graphics.getColor()
    
    -- Draw shadow first
    if self.sprite then
        love.graphics.setColor(0, 0, 0, 0.2)
        love.graphics.push()
        love.graphics.translate(3, 3)  -- Shadow offset
        love.graphics.draw(self.sprite, 
                          -self.spriteOffsetX * self.spriteScale, 
                          -self.spriteOffsetY * self.spriteScale, 
                          0, 
                          self.spriteScale, 
                          self.spriteScale)
        love.graphics.pop()
    end
    
    -- Draw the main ship (dimmed)
    if self.sprite then
        -- Dimmed sprite version
        love.graphics.setColor(0.5, 0.5, 0.5, 0.8)  -- Dimmed color
        
        -- Draw the sprite centered
        love.graphics.draw(self.sprite, 
                          -self.spriteOffsetX * self.spriteScale, 
                          -self.spriteOffsetY * self.spriteScale, 
                          0, 
                          self.spriteScale, 
                          self.spriteScale)
    else
        -- FALLBACK GEOMETRIC VERSION (dimmed)
        local size = self.size * self.worldScale
        
        -- Main body (dimmed)
        love.graphics.setColor(0.1, 0.2, 0.4, 0.8)
        love.graphics.polygon("fill", 
            size * 1.5, 0,        -- Front point
            -size, -size,         -- Back left point
            -size * 0.5, 0,       -- Back center
            -size, size           -- Back right point
        )
        
        -- Cockpit window (dimmed)
        love.graphics.setColor(0.1, 0.3, 0.5, 0.6)
        love.graphics.polygon("fill",
            size * 1.2, 0,
            size * 0.3, -size * 0.3,
            size * 0.3, size * 0.3
        )
    end
    
    -- Indicador visual sutil (sin texto)
    
    -- Restore the color
    love.graphics.setColor(r, g, b, a)
    
    -- Restore the graphics state
    love.graphics.pop()
end

-- Funciones estáticas para gestión de naves
function Naves.getAllShips()
    return allShips
end

function Naves.getShipById(shipId)
    for _, ship in ipairs(allShips) do
        if ship.shipId == shipId then
            return ship
        end
    end
    return nil
end

function Naves.getShipRegistry()
    return shipRegistry
end

function Naves.switchToShip(targetShip, currentShip)
    if not targetShip or not currentShip then
        print("[SHIP SWITCH] Error: Invalid ships provided")
        return false
    end
    
    -- Guardar estado de la nave actual
    local currentState = currentShip:saveShipState()
    print("[SHIP SWITCH] Saved state for ship", currentShip.shipId, "(", currentShip.shipName, ")")
    
    -- Cargar estado de la nave objetivo
    local targetState = targetShip:saveShipState()
    print("[SHIP SWITCH] Switching to ship", targetShip.shipId, "(", targetShip.shipName, ")")
    
    -- Transferir posición de cámara/jugador
    targetShip.x = currentShip.x
    targetShip.y = currentShip.y
    
    print("[SHIP SWITCH] Ship switch completed successfully")
    print("  From:", currentShip.shipName, "(Type:", currentShip.shipType, ")")
    print("  To:", targetShip.shipName, "(Type:", targetShip.shipType, ")")
    
    -- Mostrar inventario de la nueva nave para verificar persistencia
    if targetShip.inventory and targetShip.inventory.items then
        local itemCount = 0
        for slot, item in pairs(targetShip.inventory.items) do
            if item then itemCount = itemCount + 1 end
        end
        print("  Inventory items:", itemCount)
    end
    
    return true
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
    
    -- Verificar que tenemos acceso al mundo de física
    if not _G.physicsManager or not _G.physicsManager:getWorld() then
        print("[SHOOT] Error: Physics world not available")
        return false
    end
    
    -- Convertir coordenadas del mouse a coordenadas del mundo
    local worldMouseX, worldMouseY
    if _G.camera then
        worldMouseX, worldMouseY = _G.camera:screenToWorld(mouseX, mouseY)
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
    
    -- Crear el proyectil
    local BasicRedProjectile = require('src.physics.projectiles.types.basic_red_projectile')
    local projectile = BasicRedProjectile.new(_G.physicsManager:getWorld(), spawnX, spawnY, angle)
    
    -- Agregar el proyectil al sistema de física
    if projectile and _G.physicsManager.addProjectile then
        _G.physicsManager:addProjectile(projectile)
        
        -- Almacenar el proyectil para actualizaciones y renderizado
        if not self.projectiles then
            self.projectiles = {}
        end
        table.insert(self.projectiles, projectile)
        
        print("[SHOOT] Fired projectile from (", spawnX, ",", spawnY, ")")
        return true
    else
        print("[SHOOT] Error: Could not create projectile or PhysicsManager doesn't have addProjectile method")
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
