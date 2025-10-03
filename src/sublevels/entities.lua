-- src/sublevels/entities.lua
-- Módulo base para entidades propias del subnivel (enemigos, interactivos)

local Entities = {}

function Entities.init(cfg)
    Entities.cfg = cfg or {}
    Entities._initialized = true
end

function Entities.update(dt, world, player)
    if not Entities._initialized then return end
    -- Placeholder: actualizar IA/estado de entidades del subnivel
end

function Entities.draw(camera, world)
    if not Entities._initialized then return end
    -- Placeholder: dibujar entidades del subnivel
end

return Entities