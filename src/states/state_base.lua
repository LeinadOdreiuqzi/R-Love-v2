-- src/states/state_base.lua
-- Base modular para estados de juego en LÖVE2D
-- Provee callbacks por defecto y banderas comunes para facilitar la expansión.

local StateBase = {}
StateBase.__index = StateBase

-- Crear un nuevo estado base
function StateBase:new(opts)
    local o = {
        name = (opts and opts.name) or "UnnamedState",
        -- Cuando es true, bloquea update y draw del gameplay subyacente
        suspendUnderlying = (opts and opts.suspendUnderlying) or false,
        -- Cuando es true, el estado se dibuja sobre el gameplay (overlay)
        isOverlay = (opts and opts.isOverlay) or false,
    }
    return setmetatable(o, self)
end

-- Inyección del gestor para permitir autopop/switch desde el estado
function StateBase:setManager(manager)
    self.manager = manager
end

-- Ciclo de vida
function StateBase:enter(params) end
function StateBase:exit() end
function StateBase:pause() end
function StateBase:resume() end

-- Bucle
function StateBase:update(dt) end
function StateBase:draw() end

-- Entrada
-- Devuelve true si el evento fue manejado y debe detener la propagación
function StateBase:keypressed(key) return false end
function StateBase:textinput(text) return false end
function StateBase:wheelmoved(x, y) return false end
function StateBase:resize(w, h) end

return StateBase