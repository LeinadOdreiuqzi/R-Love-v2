-- src/world/sublevel_world.lua
-- Instancia ligera de mundo para subniveles, reutilizando sistemas del mapa

local VisibilityUtils = require 'src.maps.visibility_utils'
local MapRenderer = require 'src.maps.systems.map_renderer'
local MapGenerator = require 'src.maps.systems.map_generator'
local MapConfig = require 'src.maps.config.map_config'
local SeedSystem = require 'src.utils.seed_system'

local SublevelWorld = {}
SublevelWorld.__index = SublevelWorld

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
end

function SublevelWorld:draw(camera)
    -- Subnivel sin contenido: no dibuja fondo/objetos.
    -- Sólo el jugador será visible desde la escena.
end

return SublevelWorld