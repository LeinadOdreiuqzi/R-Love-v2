-- src/game.lua

local Game = {}

function Game:new()
    local game = {}
    setmetatable(game, self)
    self.__index = self
    
    game.player = {
        x = 100,
        y = 100,
        width = 50,
        height = 50,
        speed = 200
    }
    
    return game
end

function Game:update(dt)
    -- Movimiento del jugador
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        self.player.x = self.player.x - self.player.speed * dt
    end
    
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        self.player.x = self.player.x + self.player.speed * dt
    end
    
    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        self.player.y = self.player.y - self.player.speed * dt
    end
    
    if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
        self.player.y = self.player.y + self.player.speed * dt
    end
    
    -- Mantener al jugador dentro de la pantalla
    self.player.x = math.max(0, math.min(love.graphics.getWidth() - self.player.width, self.player.x))
    self.player.y = math.max(0, math.min(love.graphics.getHeight() - self.player.height, self.player.y))
end

function Game:draw()
    -- Dibujar el jugador
    love.graphics.setColor(0, 1, 0) -- Verde
    love.graphics.rectangle("fill", self.player.x, self.player.y, self.player.width, self.player.height)
    
    -- Resetear color
    love.graphics.setColor(1, 1, 1)
    
    -- Instrucciones
    love.graphics.print("Usa WASD o las flechas para mover el cuadrado verde", 10, 10)
end

return Game

