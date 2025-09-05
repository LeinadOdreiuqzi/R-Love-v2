-- src/utils/camera.lua

local Camera = {}
local OptimizedRenderer = require 'src.maps.optimized_renderer'

function Camera:new()
    local camera = {}
    setmetatable(camera, self)
    self.__index = self
    
    -- Position and view
    camera.x = 0
    camera.y = 0
    camera.zoom = 0.7
    camera.targetZoom = 0.7
    camera.minZoom = 0.2
    camera.maxZoom = 2.0
    camera.zoomSpeed = 0.1
    
    -- Configuración simplificada sin optimizaciones adaptativas
    
    -- Auto zoom desactivado por defecto para no “volver” tras zoom manual
    camera.autoZoomEnabled = false
    camera.baseZoom = 1.15
    
    -- Initialize screen dimensions safely
    camera:updateScreenDimensions()
    
    -- Movement
    camera.smoothness = 4.0  -- Lower is smoother
    camera.offsetX = camera.screenWidth / 2
    camera.offsetY = camera.screenHeight / 2
    
    -- Effects
    camera.shake = 0
    camera.shakeIntensity = 0
    
    return camera
end

-- Update screen dimensions (call this if the window is resized)
function Camera:updateScreenDimensions()
    -- Safely get window dimensions with fallbacks
    local success, width, height = pcall(love.graphics.getDimensions)
    if not success or not width or not height then
        width = 800
        height = 600
    end
    
    self.screenWidth = width
    self.screenHeight = height
    self.offsetX = width / 2
    self.offsetY = height / 2
    
    -- Initialize position if not set
    self.x = self.x or 0
    self.y = self.y or 0
    self.zoom = self.zoom or 1
    self.targetZoom = self.targetZoom or 1
end

-- Actualizar estado de la cámara
function Camera:update(dt)
    -- Actualizar zoom suavemente
    self.zoom = self.zoom + (self.targetZoom - self.zoom) * 0.1
    
    -- Actualizar efectos de cámara
    if self.shake > 0 then
        self.shake = math.max(0, self.shake - 1)
    end
end

-- Apply camera transformation
function Camera:apply()
    love.graphics.push()
    
    -- Calculate shake offset
    local shakeX, shakeY = 0, 0
    if self.shake > 0 then
        shakeX = math.random(-self.shakeIntensity, self.shakeIntensity)
        shakeY = math.random(-self.shakeIntensity, self.shakeIntensity)
    end
    
    -- Apply transformations
    love.graphics.translate(self.offsetX + shakeX, self.offsetY + shakeY)
    love.graphics.scale(self.zoom, self.zoom)
    love.graphics.translate(-self.x, -self.y)
end

-- Undo camera transformation
function Camera:unapply()
    love.graphics.pop()
end

-- Move camera
function Camera:move(dx, dy)
    self.x = self.x + dx
    self.y = self.y + dy
end

-- Set camera position
function Camera:setPosition(x, y)
    self.x = x
    self.y = y
end

-- Follow a target with smooth movement and return target position
function Camera:follow(target, dt)
    if not target or not target.x or not target.y then 
        return self.x, self.y
    end
    
    dt = dt or 1/60
    
    -- Calculate target position with some lookahead based on velocity
    local lookAheadX = (target.dx or 0) * 0.3
    local lookAheadY = (target.dy or 0) * 0.3
    
    -- Calculate target position
    local targetX = target.x + lookAheadX
    local targetY = target.y + lookAheadY
    
    -- Calculate distance to target
    local dx = targetX - self.x
    local dy = targetY - self.y
    local distance = math.sqrt(dx*dx + dy*dy)
    
    -- Dynamic smoothness based on distance
    local smoothness = self.smoothness * (1 + distance * 0.001)
    local lerpFactor = 1 - math.exp(-smoothness * dt * 5)
    
    -- Apply smooth following
    self.x = self.x + dx * lerpFactor
    self.y = self.y + dy * lerpFactor
    
    -- Auto-zoom basado en velocidad SOLO si está habilitado
    if self.autoZoomEnabled then
        local speed = math.sqrt((target.dx or 0)^2 + (target.dy or 0)^2)
        local baseZoom = self.baseZoom or 1.0
        local targetZoom = baseZoom * (1 - math.min(0.2, speed * 0.0005))
        self:zoomTo(self.targetZoom + (targetZoom - self.targetZoom) * 0.1)
    end
    
    -- Return target position for synchronization
    return targetX, targetY
end

-- Convert screen coordinates to world coordinates
function Camera:screenToWorld(screenX, screenY)
    -- Ensure metatable and methods are intact
    if type(self.updateScreenDimensions) ~= "function" then
        setmetatable(self, Camera)
        Camera.__index = Camera
    end

    -- Ensure we have valid dimensions and zoom
    if not self.screenWidth or not self.screenHeight then
        if type(self.updateScreenDimensions) == "function" then
            self:updateScreenDimensions()
        else
            -- Fallback safe defaults
            self.screenWidth, self.screenHeight = 800, 600
            self.offsetX, self.offsetY = 400, 300
        end
    end

    -- Fallback if dimensions are still invalid
    if not self.screenWidth or not self.screenHeight or not self.zoom then
        return screenX, screenY
    end
    
    -- Calculate relative position from center
    local relX = (screenX - (self.offsetX or 0)) / (self.zoom or 1)
    local relY = (screenY - (self.offsetY or 0)) / (self.zoom or 1)
    
    -- Regular 2D conversion with safety checks
    return (self.x or 0) + relX, (self.y or 0) + relY
end

-- Convert world coordinates to screen coordinates
function Camera:worldToScreen(worldX, worldY)
    -- Ensure metatable and methods are intact
    if type(self.updateScreenDimensions) ~= "function" then
        setmetatable(self, Camera)
        Camera.__index = Camera
    end

    -- Ensure we have valid dimensions
    if not self.screenWidth or not self.screenHeight then
        if type(self.updateScreenDimensions) == "function" then
            self:updateScreenDimensions()
        else
            self.screenWidth, self.screenHeight = 800, 600
            self.offsetX, self.offsetY = 400, 300
        end
    end

    return (worldX - self.x) * self.zoom + self.offsetX,
           (worldY - self.y) * self.zoom + self.offsetY
end

-- Handle mouse wheel for zooming
function Camera:wheelmoved(x, y)
    if y ~= 0 then
        self:zoomTo(self.targetZoom + y * self.zoomSpeed * self.targetZoom)
    end
end

-- Set zoom level with bounds checking
function Camera:zoomTo(zoomLevel)
    self.targetZoom = math.max(self.minZoom, math.min(self.maxZoom, zoomLevel))
end

-- Add screen shake effect
function Camera:shake(intensity, duration)
    self.shake = duration or 10
    self.shakeIntensity = intensity or 5
end

-- Habilitar/deshabilitar auto-zoom dinámico
function Camera:setAutoZoomEnabled(enabled)
    self.autoZoomEnabled = not not enabled
end
return Camera