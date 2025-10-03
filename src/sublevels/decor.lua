-- src/sublevels/decor.lua
-- Módulo base para decoración/props específicos del subnivel

local Decor = {}

function Decor.init(cfg)
    Decor.cfg = cfg or {}
    Decor._initialized = true
end

function Decor.update(dt, world, player)
    if not Decor._initialized then return end
    -- Placeholder: actualizar animaciones o estados de props
end

function Decor.draw(camera, world)
    if not Decor._initialized then return end
    -- Placeholder: dibujar props/decoro del subnivel
end

return Decor