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
    
    -- Movement parameters
    player.maxSpeed = 150           -- Maximum speed
    player.forwardAccel = 20        -- Forward acceleration (W key toward mouse)
    player.strafeAccel = 10         -- Strafe acceleration (A/D keys)
    player.backwardAccel = 10      -- Backward acceleration (S key)
    player.drag = 0.92              -- Air resistance (higher = less drag)
    player.brakePower = 0.6         -- How much to slow down when braking
    
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
    player.isBraking = false
    
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
    
    -- Support movements (A, S, D) - relative to current orientation
    if self.input.left and canMove then       -- A - Strafe left relative to facing direction
        local leftX = -math.sin(self.rotation)
        local leftY = math.cos(self.rotation)
        moveX = moveX + leftX * 0.7  -- Reduced power for strafe
        moveY = moveY + leftY * 0.7
        isMoving = true
    end
    
    if self.input.right and canMove then      -- D - Strafe right relative to facing direction
        local rightX = math.sin(self.rotation)
        local rightY = -math.cos(self.rotation)
        moveX = moveX + rightX * 0.7  -- Reduced power for strafe
        moveY = moveY + rightY * 0.7
        isMoving = true
    end
    
    if self.input.backward and canMove then   -- S - Move backward from mouse direction
        moveX = moveX - self.mouseDirection.x * 0.5  -- Reduced power for backward
        moveY = moveY - self.mouseDirection.y * 0.5
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
        
        -- Apply movement based on the normalized direction
        self.dx = self.dx + moveX * accel * dt
        self.dy = self.dy + moveY * accel * dt
    end
    
    -- Apply air resistance (drag) - stronger when braking
    local currentDrag = self.input.brake and self.drag * 0.9 or self.drag
    self.dx = self.dx * math.pow(currentDrag, dt * 60)
    self.dy = self.dy * math.pow(currentDrag, dt * 60)
    
    -- Apply braking if shift is held
    if self.input.brake then
        local brakeFactor = math.pow(self.brakePower, dt * 60)
        self.dx = self.dx * brakeFactor
        self.dy = self.dy * brakeFactor
        
        -- Stop completely if moving very slowly
        local speed = math.sqrt(self.dx * self.dx + self.dy * self.dy)
        if speed < 5 then
            self.dx, self.dy = 0, 0
        end
    end
    
    -- Limit maximum speed
    local speed = math.sqrt(self.dx * self.dx + self.dy * self.dy)
    if speed > self.maxSpeed then
        self.dx = (self.dx / speed) * self.maxSpeed
        self.dy = (self.dy / speed) * self.maxSpeed
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
                
                -- Update rotation to face mouse direction
                -- Adjust rotation for sprite orientation (sprites usually face up by default in LÖVE)
                -- Add 90 degrees (π/2 radians) to make the sprite point towards the cursor
                self.rotation = math.atan2(dy, dx) + (math.pi / 2)
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
