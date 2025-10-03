-- src/sublevels/spawns.lua
-- Módulo base para reglas de aparición (spawns) dentro del subnivel

local Spawns = {}

function Spawns.init(cfg)
    Spawns.cfg = cfg or {}
    Spawns._initialized = true
end

function Spawns.update(dt, world, player)
    if not Spawns._initialized then return end
    -- Placeholder: lógica de spawn basada en posición del jugador y seed del subnivel
end

function Spawns.draw(camera, world)
    -- Placeholder de visualización de puntos de spawn si se requiere debug
end

return Spawns