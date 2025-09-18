-- src/entities/eva_player.lua
-- Entidad para el jugador cuando está fuera de la nave (EVA - Extra-Vehicular Activity)

local EVAPlayer = {}
local PlayerStats = require 'src.entities.player_stats'

function EVAPlayer:new(x, y, shipRef)
    local evaPlayer = {}
    setmetatable(evaPlayer, self)
    self.__index = self
    
    -- Position and movement
    evaPlayer.x = x or 0
    evaPlayer.y = y or 0
    evaPlayer.dx = 0  -- Velocity X
    evaPlayer.dy = 0  -- Velocity Y
    
    -- EVA movement parameters (aumentados para mayor agilidad)
    evaPlayer.maxSpeed = 300           -- Velocidad máxima aumentada para mejor maniobrabilidad
    evaPlayer.acceleration = 800       -- Aceleración aumentada para respuesta más rápida
    evaPlayer.deceleration = 1000      -- Desaceleración para mejor control
    evaPlayer.drag = 0.85              -- Mayor resistencia en EVA
    evaPlayer.rotationSpeed = 8.0      -- Rotación más rápida para maniobras EVA
    
    -- State
    evaPlayer.rotation = 0             -- Current rotation in radians
    evaPlayer.targetRotation = 0       -- Target rotation for smooth turning
    
    -- Mouse direction tracking
    evaPlayer.mouseDirection = {x = 1, y = 0}  -- Default direction (right)
    evaPlayer.minMouseDistance = 20    -- Minimum distance to avoid erratic behavior
    
    -- Get world scale from map
    local Map = require 'src.maps.map' 
    evaPlayer.worldScale = Map.tileSize / 64 
    
    -- EVA suit dimensions and sprite
    evaPlayer.size = 6  -- Más pequeño que la nave
    evaPlayer.sprite = nil
    evaPlayer.spriteScale = 0.5  -- Escala más pequeña
    evaPlayer.spriteOffsetX = 0
    evaPlayer.spriteOffsetY = 0
    
    -- Reference to the ship
    evaPlayer.ship = shipRef
    evaPlayer.interactionRange = 30  -- Distancia para interactuar con la nave
    
    -- Load sprite
    evaPlayer:loadSprite()
    
    -- Stats system (compartido con la nave)
    evaPlayer.stats = PlayerStats:new()
    
    return evaPlayer
end

function EVAPlayer:loadSprite()
    -- Try to load the EVA suit sprite
    local spritePath = "assets/images/eva_suit.png"
    
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
        print("EVA suit sprite loaded successfully: " .. spritePath)
        print("Sprite dimensions: " .. spriteWidth .. "x" .. spriteHeight)
    else
        print("Warning: Could not load EVA suit sprite from " .. spritePath)
        print("Using fallback geometric drawing")
        self.sprite = nil
    end
end

function EVAPlayer:update(dt)
    -- Ensure we have a valid delta time
    dt = math.min(dt or 1/60, 1/30)
    
    -- Update input state and handle rotation
    self:handleInput(dt)
    
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
    
    -- Smooth rotation towards target
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
    
    -- Apply movement physics
    self:updateMovement(dt)
    
    -- Update position
    self.x = self.x + self.dx * dt
    self.y = self.y + self.dy * dt
end

function EVAPlayer:handleInput(dt)
    -- EVA movement controls (WASD)
    local moveX, moveY = 0, 0
    
    if love.keyboard.isDown('w') then
        moveY = moveY - 1
    end
    if love.keyboard.isDown('s') then
        moveY = moveY + 1
    end
    if love.keyboard.isDown('a') then
        moveX = moveX - 1
    end
    if love.keyboard.isDown('d') then
        moveX = moveX + 1
    end
    
    -- Normalize diagonal movement
    if moveX ~= 0 and moveY ~= 0 then
        local length = math.sqrt(moveX * moveX + moveY * moveY)
        moveX = moveX / length
        moveY = moveY / length
    end
    
    -- Apply acceleration
    if moveX ~= 0 or moveY ~= 0 then
        self.dx = self.dx + moveX * self.acceleration * dt
        self.dy = self.dy + moveY * self.acceleration * dt
    end
end

function EVAPlayer:updateMovement(dt)
    -- Apply drag mejorado
    local friction = 0.92
    self.dx = self.dx * friction
    self.dy = self.dy * friction
    
    -- Rotación suave hacia la dirección de movimiento
    if math.abs(self.dx) > 10 or math.abs(self.dy) > 10 then
        local targetAngle = math.atan2(self.dy, self.dx)
        local angleDiff = targetAngle - self.rotation
        
        -- Normalizar diferencia de ángulo
        while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
        while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end
        
        -- Aplicar rotación suave hacia movimiento
        self.rotation = self.rotation + angleDiff * (self.rotationSpeed * 0.3) * dt
    end
    
    -- Limit maximum speed
    local speed = math.sqrt(self.dx * self.dx + self.dy * self.dy)
    if speed > self.maxSpeed then
        self.dx = (self.dx / speed) * self.maxSpeed
        self.dy = (self.dy / speed) * self.maxSpeed
    end
end

function EVAPlayer:canEnterShip()
    if not self.ship then return false end
    
    local distance = math.sqrt((self.x - self.ship.x)^2 + (self.y - self.ship.y)^2)
    return distance <= self.interactionRange
end

function EVAPlayer:draw()
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.rotation)
    
    if self.sprite then
        -- Draw sprite
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            self.sprite,
            -self.spriteOffsetX * self.spriteScale,
            -self.spriteOffsetY * self.spriteScale,
            0,
            self.spriteScale,
            self.spriteScale
        )
    else
        -- Fallback: draw simple EVA suit representation
        love.graphics.setColor(0.8, 0.8, 0.9, 1)  -- Light blue-gray
        love.graphics.circle("fill", 0, 0, self.size)
        
        -- Draw direction indicator
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.line(0, 0, 0, -self.size)
        
        -- Draw helmet
        love.graphics.setColor(0.9, 0.9, 1, 0.7)
        love.graphics.circle("fill", 0, -2, self.size * 0.6)
    end
    
    love.graphics.pop()
    
    -- Draw interaction prompt if near ship
    if self:canEnterShip() then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Presiona E para entrar a la nave", self.x - 60, self.y - 30)
    end
end

return EVAPlayer