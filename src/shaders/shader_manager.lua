-- src/shaders/shader_manager.lua
-- Sistema gestor de shaders unificado para eliminar shuttering

local ShaderManager = {}
local StarShader = require 'src.shaders.star_shader'

-- Estado del gestor de shaders
ShaderManager.state = {
    -- Shaders precompilados
    shaders = {
        star = nil,
        asteroid = nil,
        nebula = nil,
        station = nil
    },
    
    -- Status de precarga
    preloadStatus = {
        star = false,
        asteroid = false,
        nebula = false,
        station = false
    },
    
    -- Imágenes base para batching
    baseImages = {
        white = nil,
        circle = nil
    },
    
    -- Configuración
    config = {
        preloadIncrementally = true,
        maxPreloadTimePerFrame = 0.002, -- 2ms max por frame
        preloadPriority = {"star", "asteroid", "nebula", "station"}
    }
}

-- Inicializar el gestor de shaders
function ShaderManager.init()
    print("=== SHADER MANAGER INITIALIZING ===")
    
    -- Crear imágenes base para batching
    ShaderManager.createBaseImages()
    
    -- Inicializar StarShader primero (crítico para estrellas)
    if StarShader and StarShader.init then
        StarShader.init()
        ShaderManager.state.shaders.star = StarShader.getShader()
        ShaderManager.state.preloadStatus.star = true
        print("✓ StarShader preloaded")
    end
    
    -- Crear shaders básicos para otros objetos
    ShaderManager.createBasicShaders()
    -- Warmup de shaders para evitar stutter en primer uso
    ShaderManager.warmup()
    print("✓ ShaderManager initialized with " .. ShaderManager.getLoadedCount() .. " shaders")
end

-- Crear imágenes base para batching
function ShaderManager.createBaseImages()
    if not love.graphics then return end
    
    -- Imagen blanca 1x1 para shaders
    local whiteData = love.image.newImageData(1, 1)
    whiteData:setPixel(0, 0, 1, 1, 1, 1)
    ShaderManager.state.baseImages.white = love.graphics.newImage(whiteData)
    
    -- Imagen circular para objetos sin shader
    local circleSize = 32
    local circleData = love.image.newImageData(circleSize, circleSize)
    local center = circleSize / 2
    for y = 0, circleSize - 1 do
        for x = 0, circleSize - 1 do
            local dx = x - center + 0.5
            local dy = y - center + 0.5
            local distance = math.sqrt(dx * dx + dy * dy)
            local alpha = math.max(0, 1 - distance / center)
            circleData:setPixel(x, y, 1, 1, 1, alpha)
        end
    end
    ShaderManager.state.baseImages.circle = love.graphics.newImage(circleData)
end

-- Crear shaders básicos para objetos
function ShaderManager.createBasicShaders()
    -- Shader básico para asteroides (efecto rocoso simple)
    local asteroidShaderCode = [[
        vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
            vec2 uv = texcoord - vec2(0.5);
            float dist = length(uv) * 2.0;
            
            // Efecto de rugosidad
            float noise = sin(uv.x * 15.0) * cos(uv.y * 12.0) * 0.1;
            dist += noise;
            
            float alpha = smoothstep(1.0, 0.7, dist);
            return vec4(color.rgb, color.a * alpha);
        }
    ]]
    
    -- Shader básico para nebulosas (efecto difuso)
    local nebulaShaderCode = [[
        extern float u_time;
        vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
            vec2 uv = texcoord - vec2(0.5);
            float dist = length(uv) * 2.0;
            
            // Efecto de pulso y ondulación
            float pulse = sin(u_time * 2.0) * 0.1 + 0.9;
            float wave = sin(dist * 8.0 - u_time * 3.0) * 0.05;
            
            float alpha = smoothstep(1.2, 0.0, dist + wave) * pulse;
            return vec4(color.rgb, color.a * alpha);
        }
    ]]
    
    -- Shader básico para estaciones (efecto metálico)
    local stationShaderCode = [[
        vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
            vec2 uv = texcoord;
            
            // Efecto metálico simple con reflexión
            float metallic = sin(uv.x * 20.0) * cos(uv.y * 20.0) * 0.1 + 0.9;
            vec3 metallicColor = color.rgb * metallic;
            
            return vec4(metallicColor, color.a);
        }
    ]]
    
    -- Crear shaders si Love2D está disponible
    if love.graphics and love.graphics.newShader then
        local success, shader
        
        -- Asteroide shader
        success, shader = pcall(love.graphics.newShader, asteroidShaderCode)
        if success then
            ShaderManager.state.shaders.asteroid = shader
            ShaderManager.state.preloadStatus.asteroid = true
        end
        
        -- Nebulosa shader
        success, shader = pcall(love.graphics.newShader, nebulaShaderCode)
        if success then
            ShaderManager.state.shaders.nebula = shader
            ShaderManager.state.preloadStatus.nebula = true
        end
        
        -- Estación shader
        success, shader = pcall(love.graphics.newShader, stationShaderCode)
        if success then
            ShaderManager.state.shaders.station = shader
            ShaderManager.state.preloadStatus.station = true
        end
    end
end

-- Actualización incremental de precarga (llamar cada frame)
function ShaderManager.update(dt)
    if not ShaderManager.state.config.preloadIncrementally then return end
    
    local startTime = love.timer.getTime()
    local maxTime = ShaderManager.state.config.maxPreloadTimePerFrame
    
    -- Actualizar tiempo en shaders que lo necesiten
    if ShaderManager.state.shaders.nebula then
        local currentTime = love.timer.getTime()
        ShaderManager.state.shaders.nebula:send("u_time", currentTime)
    end
    
    -- Verificar que todos los shaders estén cargados
    for _, shaderType in ipairs(ShaderManager.state.config.preloadPriority) do
        if not ShaderManager.state.preloadStatus[shaderType] then
            -- Intentar cargar shader faltante
            if love.timer.getTime() - startTime < maxTime then
                ShaderManager.ensureShaderLoaded(shaderType)
            else
                break -- No exceder tiempo límite
            end
        end
    end
end

-- Asegurar que un shader esté cargado
function ShaderManager.ensureShaderLoaded(shaderType)
    if ShaderManager.state.preloadStatus[shaderType] then return true end
    
    if shaderType == "star" and StarShader then
        if not ShaderManager.state.shaders.star and StarShader.getShader then
            ShaderManager.state.shaders.star = StarShader.getShader()
            ShaderManager.state.preloadStatus.star = true
        end
    end
    
    return ShaderManager.state.preloadStatus[shaderType]
end

-- Obtener shader para tipo específico
function ShaderManager.getShader(shaderType)
    ShaderManager.ensureShaderLoaded(shaderType)
    return ShaderManager.state.shaders[shaderType]
end

-- Obtener imagen base para batching
function ShaderManager.getBaseImage(imageType)
    if imageType == "white" then
        return ShaderManager.state.baseImages.white or (StarShader and StarShader.getWhiteImage and StarShader.getWhiteImage())
    elseif imageType == "circle" then
        return ShaderManager.state.baseImages.circle
    end
    
    return ShaderManager.state.baseImages.white
end

-- Precalentar todos los shaders
function ShaderManager.preloadAll()
    for _, shaderType in ipairs(ShaderManager.state.config.preloadPriority) do
        ShaderManager.ensureShaderLoaded(shaderType)
    end
end

-- Obtener estadísticas de carga
function ShaderManager.getStats()
    local loaded = ShaderManager.getLoadedCount()
    local total = #ShaderManager.state.config.preloadPriority
    
    return {
        loaded = loaded,
        total = total,
        percentage = (loaded / total) * 100,
        status = ShaderManager.state.preloadStatus
    }
end

-- Contar shaders cargados
function ShaderManager.getLoadedCount()
    local count = 0
    for _, loaded in pairs(ShaderManager.state.preloadStatus) do
        if loaded then count = count + 1 end
    end
    return count
end

-- Aplicar shader con fallback
function ShaderManager.setShader(shaderType)
    local shader = ShaderManager.getShader(shaderType)
    if shader then
        love.graphics.setShader(shader)
        return true
    end
    return false
end

-- Remover shader actual
function ShaderManager.unsetShader()
    love.graphics.setShader()
end

-- Debug: mostrar estado de shaders
function ShaderManager.debugPrint()
    print("=== SHADER MANAGER STATUS ===")
    for shaderType, loaded in pairs(ShaderManager.state.preloadStatus) do
        local status = loaded and "✓" or "✗"
        print(string.format("%s %s", status, shaderType))
    end
    local stats = ShaderManager.getStats()
    print(string.format("Total: %d/%d (%.1f%%)", stats.loaded, stats.total, stats.percentage))
end
function ShaderManager.warmup()
    if not love.graphics then return end

    local okCanvas, canvas = pcall(love.graphics.newCanvas, 2, 2)
    if not okCanvas or not canvas then return end

    local prevCanvas = love.graphics.getCanvas()
    local prevShader = love.graphics.getShader()
    local prevColor = {love.graphics.getColor()}

    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    local white = ShaderManager.getBaseImage("white")
    if white then
        for _, shaderType in ipairs(ShaderManager.state.config.preloadPriority) do
            local shader = ShaderManager.state.shaders[shaderType]
            if shader then
                love.graphics.setShader(shader)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(white, 0, 0)
                love.graphics.setShader()
            end
        end
    end

    love.graphics.setCanvas(prevCanvas)
    love.graphics.setShader(prevShader)
    love.graphics.setColor(prevColor[1], prevColor[2], prevColor[3], prevColor[4] or 1)
end
return ShaderManager
