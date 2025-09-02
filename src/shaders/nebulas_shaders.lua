-- src/shaders/nebulas_shaders.lua
-- Sistema especializado para gestión de shaders de nebulosas

local NebulasShaders = {}

-- Estado del sistema de shaders de nebulosas
NebulasShaders.state = {
    shader = nil,
    initialized = false,
    uniforms = {
        -- Valores por defecto para uniforms del shader (densidad aumentada)
        u_time = 0.0,
        u_seed = 0.0,
        u_noiseScale = 2.8,
        u_warpAmp = 0.75,
        u_warpFreq = 1.35,
        u_softness = 0.18,
        u_intensity = 0.85,
        u_brightness = 1.45,
        u_parallax = 0.85,
        u_sparkleStrength = 0.15
    }
}

-- Código del shader de nebulosas con efectos avanzados
local nebulaShaderCode = [[
    extern float u_time;
    extern float u_seed;
    extern float u_noiseScale;
    extern float u_warpAmp;
    extern float u_warpFreq;
    extern float u_softness;
    extern float u_intensity;
    extern float u_brightness;
    extern float u_parallax;        // Parallax por-nebulosa
    extern float u_sparkleStrength; // Control de intensidad de destellos locales

    float hash(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
    }
    
    float noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        float a = hash(i);
        float b = hash(i + vec2(1.0, 0.0));
        float c = hash(i + vec2(0.0, 1.0));
        float d = hash(i + vec2(1.0, 1.0));
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
    }
    
    float fbm(vec2 p) {
        float v = 0.0;
        float a = 0.5;
        for (int i = 0; i < 5; i++) {
            v += a * noise(p);
            p *= 2.0;
            a *= 0.5;
        }
        return v;
    }
    
    vec2 domainWarp(vec2 p, float t) {
        float f = max(0.0001, u_warpFreq);
        vec2 q = vec2(
            fbm(p * f + t + u_seed),
            fbm(p * f - t + u_seed + 13.37)
        );
        q = (q - 0.5) * 2.0;
        return p + q * u_warpAmp;
    }
    
    vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
        vec2 uv = texcoord * 2.0 - 1.0;
        float r = length(uv);
        float s = clamp(u_softness, 0.0, 0.95);
        float mask = 1.0 - smoothstep(1.0 - s, 1.0, r);
        if (mask <= 0.0001) {
            return vec4(0.0);
        }

        // Movimiento más sutil y dependiente de parallax
        float par = clamp(u_parallax, 0.0, 1.0);
        float t = u_time * mix(0.015, 0.035, par);

        float ns = max(0.0001, u_noiseScale);
        vec2 p = uv * ns;
        p = domainWarp(p, t);
        float n = fbm(p);

        float cloud = smoothstep(0.25, 0.90, n);
        float centerBoost = smoothstep(1.0, 0.0, r);
        float density = cloud * (0.80 + 0.45 * centerBoost);

        // Niebla oscura en zonas superiores para contraste
        float darkFogNoise = fbm(p * 1.8 + vec2(t * 0.3, t * 0.2));
        float darkFogMask = smoothstep(0.4, 0.8, darkFogNoise) * smoothstep(0.3, 0.7, -uv.y + 0.2);
        float darkFogIntensity = darkFogMask * 0.25 * (1.0 - par * 0.3);

        // Niebla pálida en zonas centrales para profundidad
        float paleFogNoise = fbm(p * 0.9 + vec2(-t * 0.15, t * 0.25));
        float paleFogMask = smoothstep(0.3, 0.7, paleFogNoise) * centerBoost;
        float paleFogIntensity = paleFogMask * 0.18 * (0.8 + par * 0.4);

        // Destellos locales ("sparkle") controlados por u_sparkleStrength
        float sparkScale = 2.5 + par * 4.0;
        vec2 sp = p * sparkScale;

        float s1 = noise(sp + vec2(u_time * (1.6 + par * 0.8) + u_seed, -u_time * (1.1 + par * 0.5) + u_seed * 0.7));
        float s2 = noise(sp * 1.3 + vec2(-u_time * (1.4 + par * 0.6) + u_seed * 1.3, u_time * (0.9 + 0.4 * par)));
        float smax = max(s1, s2);

        float sparkMask = smoothstep(0.88, 1.0, smax) * mask;
        float sparkStrength = clamp(u_sparkleStrength, 0.0, 3.0) * (0.9 + 0.6 * par);

        vec4 texel = Texel(tex, texcoord);
        vec3 baseColor = color.rgb * texel.rgb * u_brightness;
        
        // Aplicar efectos de niebla para contraste
        vec3 darkFogColor = baseColor * (1.0 - darkFogIntensity * 0.7);
        vec3 paleFogColor = mix(darkFogColor, vec3(1.0, 0.98, 0.95) * u_brightness * 0.6, paleFogIntensity);
        
        vec3 finalColor = paleFogColor * (1.0 + sparkStrength * sparkMask);

        float a = mask * density * clamp(u_intensity, 0.0, 2.0) * texel.a;
        // Aumentar opacidad base para mayor visibilidad
        a *= 1.35;
        // El boost de alpha depende de sparkStrength (si es 0, no hay boost)
        float normalizedSpark = clamp(sparkStrength / 3.0, 0.0, 1.0);
        a *= (1.0 + 0.40 * sparkMask * normalizedSpark);

        return vec4(finalColor, color.a * a);
    }
]]

-- Inicializar el sistema de shaders de nebulosas
function NebulasShaders.init()
    if NebulasShaders.state.initialized then
        print("NebulasShaders: Ya inicializado, omitiendo re-inicialización")
        return true
    end
    
    print("=== NEBULAS SHADERS INITIALIZING ===")
    
    if not love.graphics or not love.graphics.newShader then
        print("✗ NebulasShaders: Love2D graphics no disponible")
        return false
    end
    
    -- Crear shader de nebulosas
    local success, shader = pcall(love.graphics.newShader, nebulaShaderCode)
    if not success then
        print("✗ NebulasShaders: Error al crear shader - " .. tostring(shader))
        return false
    end
    
    NebulasShaders.state.shader = shader
    
    -- Configurar uniforms por defecto
    local ok = pcall(function()
        for uniform, value in pairs(NebulasShaders.state.uniforms) do
            shader:send(uniform, value)
        end
    end)
    
    if not ok then
        print("✗ NebulasShaders: Error al configurar uniforms por defecto")
        return false
    end
    
    NebulasShaders.state.initialized = true
    print("✓ NebulasShaders: Shader de nebulosas inicializado correctamente")
    return true
end

-- Obtener el shader de nebulosas
function NebulasShaders.getShader()
    if not NebulasShaders.state.initialized then
        NebulasShaders.init()
    end
    return NebulasShaders.state.shader
end

-- Actualizar uniforms del shader
function NebulasShaders.updateUniforms(uniforms)
    local shader = NebulasShaders.getShader()
    if not shader then return false end
    
    local success = pcall(function()
        for uniform, value in pairs(uniforms) do
            if NebulasShaders.state.uniforms[uniform] ~= nil then
                shader:send(uniform, value)
                NebulasShaders.state.uniforms[uniform] = value
            end
        end
    end)
    
    return success
end

-- Configurar uniforms específicos para una nebulosa
function NebulasShaders.configureForNebula(nebula, currentTime)
    local uniforms = {
        u_time = currentTime or love.timer.getTime(),
        u_seed = (nebula.seed or 0) * 0.001,
        u_noiseScale = nebula.noiseScale or 2.5,
        u_warpAmp = nebula.warpAmp or 0.65,
        u_warpFreq = nebula.warpFreq or 1.25,
        u_softness = nebula.softness or 0.28,
        u_intensity = nebula.intensity or 0.6,
        u_brightness = nebula.brightness or 1.20,
        u_parallax = math.max(0.0, math.min(1.0, nebula.parallax or 0.85)),
        u_sparkleStrength = nebula.sparkleStrength or 0.0
    }
    
    return NebulasShaders.updateUniforms(uniforms)
end

-- Actualizar tiempo del shader (llamar cada frame)
function NebulasShaders.update(dt)
    if not NebulasShaders.state.initialized then return end
    
    local currentTime = love.timer.getTime()
    NebulasShaders.updateUniforms({u_time = currentTime})
end

-- Aplicar shader de nebulosas
function NebulasShaders.setShader()
    local shader = NebulasShaders.getShader()
    if shader then
        love.graphics.setShader(shader)
        return true
    end
    return false
end

-- Remover shader
function NebulasShaders.unsetShader()
    love.graphics.setShader()
end

-- Verificar si el shader está disponible
function NebulasShaders.isAvailable()
    return NebulasShaders.state.initialized and NebulasShaders.state.shader ~= nil
end

-- Obtener información de estado
function NebulasShaders.getStatus()
    return {
        initialized = NebulasShaders.state.initialized,
        shaderLoaded = NebulasShaders.state.shader ~= nil,
        uniforms = NebulasShaders.state.uniforms
    }
end

-- Debug: imprimir estado
function NebulasShaders.debugPrint()
    print("=== NEBULAS SHADERS STATUS ===")
    local status = NebulasShaders.getStatus()
    print("Initialized: " .. tostring(status.initialized))
    print("Shader Loaded: " .. tostring(status.shaderLoaded))
    print("Current Uniforms:")
    for uniform, value in pairs(status.uniforms) do
        print("  " .. uniform .. ": " .. tostring(value))
    end
end

return NebulasShaders