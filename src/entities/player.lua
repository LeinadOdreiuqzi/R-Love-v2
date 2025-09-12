-- src/entities/player.lua

local Player = {}
local PlayerStats = require 'src.entities.player_stats'

function Player:new(x, y)
    local player = {}
    setmetatable(player, self)
    self.__index = self
    
    -- Position and movement
    player.x = x or 0
    player.y = y or 0
    player.dx = 0  -- Velocity X
    player.dy = 0  -- Velocity Y
    
    -- Movement parameters (VELOCIDADES REDUCIDAS Y BALANCEADAS)
    player.maxSpeed = 80            -- Maximum speed (reducido significativamente)
    player.forwardAccel = 12        -- Forward acceleration (reducido)
    player.strafeAccel = 8          -- Strafe acceleration (A/D keys) - reducido
    player.backwardAccel = 6        -- Backward acceleration (S key) - reducido
    player.drag = 0.94              -- More drag for better control
    player.brakePower = 0.8         -- Improved drift braking
    
    -- Parámetros balanceados para drift controlado
     player.rotationSpeed = 5.0      -- Velocidad de rotación controlada
     player.driftFactor = 0.88       -- Factor de drift reducido (88% inercia lateral)
     player.driftActivation = 6      -- Umbral reducido para activar drift
     player.driftTransition = 0.95   -- Transición más controlada
     player.gradualBraking = 0.85    -- Frenado más efectivo
     player.boostMultiplier = 1.8    -- Multiplicador para boost temporal (reducido)
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
    
    -- Stats system
    player.stats = PlayerStats:new()
    
    return player
end

function Player:loadSprite()
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

function Player:update(dt)
    -- Ensure we have a valid delta time
    dt = math.min(dt or 1/60, 1/30)
    
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
        self.boostDuration = math.min(self.maxBoostDuration, self.boostDuration + dt)
        self.isBoostActive = true
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
    
    -- Update position
    self.x = self.x + self.dx * dt * 60
    self.y = self.y + self.dy * dt * 60
    
    -- Thruster particles have been removed
    
    -- Update stats system
    self.stats:update(dt, isMoving)
end

function Player:handleInput()
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

function Player:updateThrusterParticles(dt)
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
function Player:takeDamage(damage)
    return self.stats:takeDamage(damage)
end

function Player:heal(amount)
    self.stats:heal(amount)
end

function Player:addFuel(amount)
    self.stats:addFuel(amount)
end

function Player:draw()
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
end
function Player:toggleHyperTravel(targetMaxSpeed)
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
return Player