-- MagnifyingGlass.lua
-- Componente reutilizable para efecto de lupa con refracción realista en Love2D
-- Autor: Generado para proyecto Anomalia

local MagnifyingGlass = {}
MagnifyingGlass.__index = MagnifyingGlass

-- Constructor
function MagnifyingGlass.new(options)
    local self = setmetatable({}, MagnifyingGlass)
    
    -- Parámetros por defecto
    options = options or {}
    
    -- Posición y dimensiones
    self.x = options.x or 0
    self.y = options.y or 0
    self.radius = options.radius or 100
    
    -- Parámetros del efecto
    self.distortion_strength = options.distortion_strength or 1.0
    self.magnification = options.magnification or 1.5
    self.edge_softness = options.edge_softness or 0.15  -- Increased for smoother edges
    self.chromatic_aberration = options.chromatic_aberration or 0.001  -- Reduced for cleaner look
    
    
    
    -- Estado interno
    self.enabled = true
    self.canvas = nil
    self.pingCanvas = nil -- canvas auxiliar para multipase
    self.shader = nil
    self.screen_width = love.graphics.getWidth()
    self.screen_height = love.graphics.getHeight()

    -- Defaults para modo wave
    self.effect_type = 0 -- 0=lens, 1=wave (por defecto lente)
    self.wave_width = options.wave_width or 0.03
    self.wave_amplitude = options.wave_amplitude or 0.01
    
    -- Cargar shader
    self:loadShader()
    
    -- Crear canvas para renderizado
    self:createCanvas()
    
    return self
end

-- Cargar el shader GLSL
function MagnifyingGlass:loadShader()
    -- Usar la ruta del proyecto (virtual path de LÖVE)
    local shader_path = "src/shaders/magnifying_glass.glsl"
    
    -- Cargar shader (Love2D gestiona la VFS, no usar io.open)
    self.shader = love.graphics.newShader(shader_path)
    
    -- Configurar uniforms iniciales
    self:updateShaderUniforms()
end

-- Crear canvas para renderizado
function MagnifyingGlass:createCanvas()
    self.canvas = love.graphics.newCanvas(self.screen_width, self.screen_height)
    self.pingCanvas = love.graphics.newCanvas(self.screen_width, self.screen_height)
end

-- Garantizar tamaño correcto de los canvas
function MagnifyingGlass:ensureCanvas()
    local current_width = love.graphics.getWidth()
    local current_height = love.graphics.getHeight()
    if current_width ~= self.screen_width or current_height ~= self.screen_height or (not self.canvas) or (not self.pingCanvas) then
        self.screen_width = current_width
        self.screen_height = current_height
        -- Recrear canvases sin opciones inválidas; no usamos stencil en Canvas
        self:createCanvas()
        self:updateShaderUniforms()
    end
end

-- Actualizar uniforms del shader
function MagnifyingGlass:updateShaderUniforms()
    if not self.shader then return end
    
    -- Convertir posición a coordenadas normalizadas (0-1)
    local norm_x = self.x / self.screen_width
    local norm_y = self.y / self.screen_height
    local norm_radius = self.radius / math.min(self.screen_width, self.screen_height)
    
    -- Enviar parámetros al shader
    self.shader:send("u_magnifier_pos", {norm_x, norm_y})
    self.shader:send("u_magnifier_radius", norm_radius)
    self.shader:send("u_distortion_strength", self.distortion_strength)
    self.shader:send("u_magnification", self.magnification)
    self.shader:send("u_edge_softness", self.edge_softness)
    self.shader:send("u_chromatic_aberration", self.chromatic_aberration)
    -- Nuevos uniforms
    self.shader:send("u_effect_type", self.effect_type)
    self.shader:send("u_wave_width", self.wave_width)
    self.shader:send("u_wave_amplitude", self.wave_amplitude)
end

-- Enviar uniforms de una lente individual (tabla con campos normalizados)
function MagnifyingGlass:sendLensUniforms(l)
    if not self.shader or not l then return end
    -- l = { pos = {nx, ny}, radius = r, distortion_strength = s, magnification = m, edge_softness = e, chromatic_aberration = c }
    self.shader:send("u_magnifier_pos", l.pos)
    self.shader:send("u_magnifier_radius", l.radius)
    self.shader:send("u_distortion_strength", l.distortion_strength or self.distortion_strength)
    self.shader:send("u_magnification", l.magnification or self.magnification)
    self.shader:send("u_edge_softness", l.edge_softness or self.edge_softness)
    self.shader:send("u_chromatic_aberration", l.chromatic_aberration or self.chromatic_aberration)
    -- Tipo de efecto y parámetros de onda si aplica
    local et = l.effect_type or 0
    self.shader:send("u_effect_type", et)
    if et == 1 then
        self.shader:send("u_wave_width", l.wave_width or self.wave_width)
        self.shader:send("u_wave_amplitude", l.wave_amplitude or self.wave_amplitude)
    else
        -- Asegurar valores consistentes si el siguiente pase cambia de tipo
        self.shader:send("u_wave_width", self.wave_width)
        self.shader:send("u_wave_amplitude", self.wave_amplitude)
    end
end

-- Actualizar posición de la lupa
function MagnifyingGlass:setPosition(x, y)
    self.x = x
    self.y = y
    self:updateShaderUniforms()
end

-- Actualizar radio de la lupa
function MagnifyingGlass:setRadius(radius)
    self.radius = math.max(10, radius) -- Mínimo de 10 píxeles
    self:updateShaderUniforms()
end

-- Configurar intensidad de distorsión
function MagnifyingGlass:setDistortionStrength(strength)
    self.distortion_strength = math.max(0, math.min(2, strength)) -- Rango 0-2
    self:updateShaderUniforms()
end

-- Configurar factor de magnificación
function MagnifyingGlass:setMagnification(magnification)
    self.magnification = math.max(1, math.min(3, magnification)) -- Rango 1-3
    self:updateShaderUniforms()
end

-- Configurar suavidad del borde
function MagnifyingGlass:setEdgeSoftness(softness)
    self.edge_softness = math.max(0, math.min(1, softness)) -- Rango 0-1
    self:updateShaderUniforms()
end

-- Configurar aberración cromática
function MagnifyingGlass:setChromaticAberration(aberration)
    self.chromatic_aberration = math.max(0, math.min(0.01, aberration)) -- Rango 0-0.01
    self:updateShaderUniforms()
end



-- Habilitar/deshabilitar el efecto
function MagnifyingGlass:setEnabled(enabled)
    self.enabled = enabled
end

-- Verificar si el efecto está habilitado
function MagnifyingGlass:isEnabled()
    return self.enabled
end

-- Comenzar captura para aplicar el efecto
function MagnifyingGlass:beginCapture()
    if not self.enabled then return end
    self:ensureCanvas()
    -- Comenzar renderizado al canvas
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear()
end

-- Finalizar captura y aplicar el efecto (una sola lente usando uniforms por defecto)
function MagnifyingGlass:endCapture()
    if not self.enabled or not self.canvas or not self.shader then return end
    
    -- Finalizar renderizado al canvas
    love.graphics.setCanvas()
    
    -- Aplicar shader y dibujar el resultado en espacio de pantalla
    love.graphics.setShader(self.shader)
    
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, 0, 0)
    love.graphics.pop()
    
    -- Restaurar shader por defecto
    love.graphics.setShader()
end

-- Método multipase para aplicar varias lentes simultáneas
function MagnifyingGlass:applyMultiple(lenses, draw_function)
    if not self.enabled or not lenses or #lenses == 0 then
        if draw_function then draw_function() end
        return
    end

    self:ensureCanvas()

    -- 1) Capturar la escena objetivo
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0, 0, 0, 1)
    if draw_function then draw_function() end
    love.graphics.setCanvas()

    local src = self.canvas
    local dst = self.pingCanvas

    -- 2) Aplicar N pases (ping-pong) SIN stencil/scissor (el shader preserva fuera del radio)
    for i = 1, #lenses do
        local l = lenses[i]
        love.graphics.setCanvas(dst)
        love.graphics.clear(0, 0, 0, 0)

        -- Dibujar desde src con el shader activo en toda la pantalla
        love.graphics.setShader(self.shader)
        self:sendLensUniforms(l)
        love.graphics.push()
        love.graphics.origin()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(src, 0, 0)
        love.graphics.pop()

        -- Limpiar estados y canvas
        love.graphics.setShader()
        love.graphics.setCanvas()

        -- Intercambiar buffers
        src, dst = dst, src
    end

    -- 3) Dibujar el resultado final a pantalla (full-screen)
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")
    love.graphics.draw(src, 0, 0)
    love.graphics.setBlendMode("alpha")
    love.graphics.pop()

    -- Asegurar limpieza total de estados para evitar herencia en HUD
    love.graphics.setScissor()
    love.graphics.setStencilTest()
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")
end

-- Método de conveniencia para aplicar el efecto a una función de dibujo
function MagnifyingGlass:apply(draw_function)
    if not self.enabled then
        draw_function()
        return
    end
    
    self:beginCapture()
    draw_function()
    self:endCapture()
end

-- Dibujar indicador visual de la lupa (opcional, para debug)
function MagnifyingGlass:drawDebug()
    if not self.enabled then return end
    
    love.graphics.push()
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.circle("line", self.x, self.y, self.radius)
    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.circle("fill", self.x, self.y, self.radius)
    love.graphics.pop()
end

-- Limpiar recursos
function MagnifyingGlass:destroy()
    if self.canvas then
        self.canvas:release()
        self.canvas = nil
    end
    if self.pingCanvas then
        self.pingCanvas:release()
        self.pingCanvas = nil
    end
    if self.shader then
        self.shader:release()
        self.shader = nil
    end
end

-- Obtener información del estado actual
function MagnifyingGlass:getInfo()
    return {
        position = {x = self.x, y = self.y},
        radius = self.radius,
        distortion_strength = self.distortion_strength,
        magnification = self.magnification,
        edge_softness = self.edge_softness,
        chromatic_aberration = self.chromatic_aberration,
        enabled = self.enabled
    }
end

return MagnifyingGlass