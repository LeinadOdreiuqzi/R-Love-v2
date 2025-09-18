-- src/states/state_manager.lua
-- Gestor modular de estados con pila y transiciones (fade)

local StateManager = {}
StateManager.__index = StateManager

function StateManager:new()
    local o = {
        stack = {},
        transition = {
            active = false,
            mode = "in",   -- 'in' aparece desde negro, 'out' desvanece hacia negro
            t = 0,
            duration = 0.0,
            color = {0, 0, 0, 1},
        }
    }
    return setmetatable(o, self)
end

function StateManager:top()
    return self.stack[#self.stack]
end

function StateManager:blocksUnderlying()
    local top = self:top()
    return top and top.suspendUnderlying or false
end

local function startTransition(self, mode, duration)
    self.transition.active = duration and duration > 0
    self.transition.mode = mode or "in"
    self.transition.t = 0
    self.transition.duration = duration or 0
end

function StateManager:push(state, opts)
    opts = opts or {}
    if state.setManager then state:setManager(self) end
    if opts.suspendUnderlying ~= nil then state.suspendUnderlying = opts.suspendUnderlying end
    if opts.isOverlay ~= nil then state.isOverlay = opts.isOverlay end
    table.insert(self.stack, state)
    if state.enter then state:enter(opts.params) end
    startTransition(self, "in", opts.fadeDuration or 0.25)
end

function StateManager:pop(opts)
    opts = opts or {}
    local top = self:top()
    if not top then return end
    if top.exit then top:exit() end
    table.remove(self.stack)
    local newTop = self:top()
    if newTop and newTop.resume then newTop:resume() end
    startTransition(self, "in", opts.fadeDuration or 0.2)
end

function StateManager:switch(state, opts)
    opts = opts or {}
    local old = self:top()
    if old and old.exit then old:exit() end
    if state.setManager then state:setManager(self) end
    self.stack[#self.stack] = state
    if state.enter then state:enter(opts.params) end
    startTransition(self, "in", opts.fadeDuration or 0.25)
end

function StateManager:update(dt)
    -- Actualizar transición
    if self.transition.active then
        self.transition.t = math.min(self.transition.t + dt, self.transition.duration)
        if self.transition.t >= self.transition.duration then
            self.transition.active = false
        end
    end

    -- Actualizar solo el tope
    local top = self:top()
    if top and top.update then top:update(dt) end
end

function StateManager:draw()
    -- Dibujar estados en orden según overlay; si alguno no es overlay y está debajo del tope bloqueante,
    -- el main decidirá si dibujar o no. Aquí dibujamos únicamente los estados de la pila (overlays o escena actual).
    for i = 1, #self.stack do
        local st = self.stack[i]
        if st and st.draw then st:draw() end
    end

    -- Dibujar overlay de transición (fade)
    if self.transition.active and self.transition.duration > 0 then
        local k = self.transition.t / self.transition.duration
        if self.transition.mode == "in" then
            k = 1.0 - k
        end
        local r, g, b, a = self.transition.color[1], self.transition.color[2], self.transition.color[3], (self.transition.color[4] or 1) * k
        if a > 0.001 then
            local lr, lg, lb, la = love.graphics.getColor()
            love.graphics.setColor(r, g, b, a)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
            love.graphics.setColor(lr, lg, lb, la)
        end
    end
end

-- Entrada: propagar desde el tope hacia abajo hasta que un estado lo maneje
function StateManager:keypressed(key)
    for i = #self.stack, 1, -1 do
        local st = self.stack[i]
        if st and st.keypressed and st:keypressed(key) then
            return true
        end
        -- Si el estado de arriba es bloqueante, no propagamos a inferiores
        if i == #self.stack and st and st.suspendUnderlying then
            break
        end
    end
    return false
end

function StateManager:textinput(text)
    for i = #self.stack, 1, -1 do
        local st = self.stack[i]
        if st and st.textinput and st:textinput(text) then
            return true
        end
        if i == #self.stack and st and st.suspendUnderlying then
            break
        end
    end
    return false
end

function StateManager:wheelmoved(x, y)
    for i = #self.stack, 1, -1 do
        local st = self.stack[i]
        if st and st.wheelmoved and st:wheelmoved(x, y) then
            return true
        end
        if i == #self.stack and st and st.suspendUnderlying then
            break
        end
    end
    return false
end

function StateManager:resize(w, h)
    for i = #self.stack, 1, -1 do
        local st = self.stack[i]
        if st and st.resize then st:resize(w, h) end
        if i == #self.stack and st and st.suspendUnderlying then
            break
        end
    end
end

-- Limpiar todos los estados de la pila (útil para regeneración de mundo)
function StateManager:clear()
    -- Llamar exit en todos los estados antes de limpiar
    for i = #self.stack, 1, -1 do
        local st = self.stack[i]
        if st and st.exit then
            st:exit()
        end
    end
    
    -- Limpiar la pila
    self.stack = {}
    
    -- Resetear transición
    self.transition.active = false
    self.transition.t = 0
end

return StateManager