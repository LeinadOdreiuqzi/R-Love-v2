-- src/world/sublevel_world.lua
-- Instancia ligera de mundo para subniveles, reutilizando sistemas del mapa

local VisibilityUtils = require 'src.maps.visibility_utils'
local MapRenderer = require 'src.maps.systems.map_renderer'
local MapGenerator = require 'src.maps.systems.map_generator'
local MapConfig = require 'src.maps.config.map_config'
local SeedSystem = require 'src.utils.seed_system'
local World = require 'src.core.world'
local CelestialRenderer = require 'src.sublevels.celestial_renderer'

local SublevelWorld = {}
SublevelWorld.__index = SublevelWorld

-- Presupuestos de generación/culling específicos para subnivel
SublevelWorld.config = {
    marginPx = 180,         -- margen de pantalla más pequeño que el mapa principal
    preloadRing = 1,        -- anillo de precarga reducido
    maxChunksPerFrame = 6   -- presupuesto de generación por frame
}

function SublevelWorld.new(cfg)
    local o = setmetatable({}, SublevelWorld)
    o.cfg = cfg or {}
    o.seed = tostring(o.cfg.numericSeed or 0)
    o.rng = SeedSystem.makeRNG(o.cfg.numericSeed or 0)
    o.chunks = {}
    o.lastPlayerPosition = { x = 0, y = 0 }
    return o
end

function SublevelWorld:isChunkInBounds(chunkX, chunkY)
    local sizePixels = (MapConfig.chunk.size or 64) * (MapConfig.chunk.tileSize or 32)
    local spacing = MapConfig.chunk.spacing or 0
    local stride = (sizePixels + spacing) * (MapConfig.chunk.worldScale or 1)
    local ex = (self.cfg.entry and self.cfg.entry.x) or 0
    local ey = (self.cfg.entry and self.cfg.entry.y) or 0
    local entryChunkX = math.floor(ex / stride)
    local entryChunkY = math.floor(ey / stride)
    local w = (self.cfg.size and self.cfg.size.width) or 8
    local h = (self.cfg.size and self.cfg.size.height) or 8
    local halfW = math.floor(w / 2)
    local halfH = math.floor(h / 2)
    local minX = entryChunkX - halfW
    local minY = entryChunkY - halfH
    local maxX = minX + w - 1
    local maxY = minY + h - 1
    return chunkX >= minX and chunkX <= maxX and chunkY >= minY and chunkY <= maxY
end

function SublevelWorld:getChunkNonBlocking(chunkX, chunkY)
    self.chunks[chunkX] = self.chunks[chunkX] or {}
    if self.chunks[chunkX][chunkY] then
        return self.chunks[chunkX][chunkY]
    end
    if not self:isChunkInBounds(chunkX, chunkY) then
        return nil
    end
    local chunk = MapGenerator.generateSubLevelChunk(chunkX, chunkY, self.cfg, self.rng)
    self.chunks[chunkX][chunkY] = chunk
    return chunk
end

function SublevelWorld:update(dt, player)
    if player then
        self.lastPlayerPosition.x = player.x or self.lastPlayerPosition.x
        self.lastPlayerPosition.y = player.y or self.lastPlayerPosition.y
    end

    if CelestialRenderer and CelestialRenderer.update then
        CelestialRenderer.update(dt)
    end

    -- Precarga limitada de chunks alrededor de la cámara para evitar sobrecarga
    local camera = World.get('camera')
    if not camera then return end

    local sizePixels = (MapConfig.chunk.size or 64) * (MapConfig.chunk.tileSize or 32)
    local spacing = MapConfig.chunk.spacing or 0
    local stride = (sizePixels + spacing) * (MapConfig.chunk.worldScale or 1)

    local centerChunkX = math.floor((camera.x or 0) / stride)
    local centerChunkY = math.floor((camera.y or 0) / stride)

    local generated = 0
    for dx = -1, 1 do
        for dy = -1, 1 do
            if generated >= (SublevelWorld.config.maxChunksPerFrame or 6) then break end
            local cx = centerChunkX + dx
            local cy = centerChunkY + dy
            if self:isChunkInBounds(cx, cy) then
                self.chunks[cx] = self.chunks[cx] or {}
                if not self.chunks[cx][cy] then
                    local chunk = self:getChunkNonBlocking(cx, cy)
                    if chunk then
                        generated = generated + 1
                    end
                end
            end
        end
        if generated >= (SublevelWorld.config.maxChunksPerFrame or 6) then break end
    end
end

function SublevelWorld:getBounds()
    local sizePixels = (MapConfig.chunk.size or 64) * (MapConfig.chunk.tileSize or 32)
    local spacing = MapConfig.chunk.spacing or 0
    local stride = (sizePixels + spacing) * (MapConfig.chunk.worldScale or 1)
    local w = (self.cfg.size and self.cfg.size.width) or 8
    local h = (self.cfg.size and self.cfg.size.height) or 8
    local halfW = math.floor(w / 2)
    local halfH = math.floor(h / 2)
    local minX = -halfW * stride
    local maxX = halfW * stride
    local minY = -halfH * stride
    local maxY = halfH * stride
    return minX, minY, maxX, maxY, stride
end

function SublevelWorld:draw(camera)
    local minX, minY, maxX, maxY, stride = self:getBounds()
    local meta = self.cfg and self.cfg.meta
    local accent = (meta and meta.accent) or {0.35, 0.75, 1.0}
    local tier = (meta and meta.tier) or 1
    local t = love.timer.getTime()

    local r, g, b, a = love.graphics.getColor()
    local width = maxX - minX
    local height = maxY - minY
    local cx = minX + width * 0.5
    local cy = minY + height * 0.5

    -- 1. Objetos celestiales y balizas en espacio de mundo local
    local CelestialRenderer = require 'src.sublevels.celestial_renderer'
    if CelestialRenderer then
        local player = World.get('player')
        if tier == 1 then
            if CelestialRenderer.drawWorldBeacons then
                CelestialRenderer.drawWorldBeacons(self.cfg, player)
            end
        else
            if CelestialRenderer.draw then
                CelestialRenderer.draw(self.cfg, camera, player, love.timer.getDelta())
            end
        end
    end

    -- 2. Marcadores perimetrales sutiles de la zona (sin rejilla de suelo cenital)
    local cornerLen = 140
    local pulse = 0.6 + 0.4 * math.sin(t * 1.5)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.35 * pulse)
    love.graphics.setLineWidth(2.0)
    -- TL
    love.graphics.line(minX, minY, minX + cornerLen, minY)
    love.graphics.line(minX, minY, minX, minY + cornerLen)
    -- TR
    love.graphics.line(maxX, minY, maxX - cornerLen, minY)
    love.graphics.line(maxX, minY, maxX, minY + cornerLen)
    -- BL
    love.graphics.line(minX, maxY, minX + cornerLen, maxY)
    love.graphics.line(minX, maxY, minX, maxY - cornerLen)
    -- BR
    love.graphics.line(maxX, maxY, maxX - cornerLen, maxY)
    love.graphics.line(maxX, maxY, maxX, maxY - cornerLen)

    love.graphics.setColor(r, g, b, a)
end

return SublevelWorld