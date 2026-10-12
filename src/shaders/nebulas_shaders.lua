-- src/shaders/nebulas_shaders.lua
-- Sistema especializado para gestión de shaders de nebulosas

local NebulasShaders = {}

-- Estado del sistema de shaders de nebulosas
NebulasShaders.state = {
    shader = nil,
    initialized = false,
    uniforms = {
        -- Uniforms vectoriales empaquetados (Fase 4: Batching y reducción de draw calls)
        u_time = 0.0,
        u_params1 = {0.0, 2.8, 0.75, 1.35},
        u_params2 = {0.18, 1.45, 0.85, 0.15},
        u_params3 = {0.85, 0.0, 0.35, 0.0},
        u_coreColor = {1.0, 1.0, 1.0},
        -- Aliases escalares mantenidos para total retrocompatibilidad y telemetría
        u_seed = 0.0,
        u_noiseScale = 2.8,
        u_warpAmp = 0.75,
        u_warpFreq = 1.35,
        u_softness = 0.18,
        u_intensity = 0.85,
        u_brightness = 1.45,
        u_parallax = 0.85,
        u_sparkleStrength = 0.15,
        u_morphology = 0.0,    -- 0: Difusa clásica, 1: Anular, 2: Bipolar, 3: Filamentosa
        u_irregularity = 0.35  -- Desgarro/irregularidad en bordes
    }
}

-- Buffers persistentes preasignados para evitar asignaciones de tabla por fotograma (GC-free)
local _packedP1 = {0.0, 2.8, 0.75, 1.35}
local _packedP2 = {0.18, 1.45, 0.85, 0.15}
local _packedP3 = {0.85, 0.0, 0.35, 0.0}
local _packedCore = {1.0, 1.0, 1.0}

-- Código del shader de nebulosas con efectos avanzados
local nebulaShaderCode = [[
    extern float u_time;
    // Fase 4: Uniforms agrupados en vectores vec4 (reduce llamadas a glUniform en más de 70%)
    extern vec4 u_params1; // x: seed, y: noiseScale, z: warpAmp, w: warpFreq
    extern vec4 u_params2; // x: softness, y: brightness, z: parallax, w: sparkleStrength
    extern vec4 u_params3; // x: intensity, y: morphology, z: irregularity, w: unused (0.0)
    extern vec3 u_coreColor; // Color armónico del núcleo (Dual-Tone)

    #define u_seed            (u_params1.x)
    #define u_noiseScale      (u_params1.y)
    #define u_warpAmp         (u_params1.z)
    #define u_warpFreq        (u_params1.w)

    #define u_softness        (u_params2.x)
    #define u_brightness      (u_params2.y)
    #define u_parallax        (u_params2.z)
    #define u_sparkleStrength (u_params2.w)

    #define u_intensity       (u_params3.x)
    #define u_morphology      (u_params3.y)
    #define u_irregularity    (u_params3.z)

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
    
    vec2 domainWarp(vec2 p, float t, vec2 seedOff) {
        float f = max(0.0001, u_warpFreq);
        vec2 q = vec2(
            fbm(p * f + t + seedOff),
            fbm(p * f - t + seedOff + vec2(13.37, 7.19))
        );
        q = (q - 0.5) * 2.0;
        return p + q * u_warpAmp;
    }
    
    vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
        vec2 uv = texcoord * 2.0 - 1.0;

        // Desfase 2D único derivado de la semilla:
        // Asegura que cada nebulosa muestree una porción completamente distinta del campo de ruido fractal
        vec2 seedOff = vec2(
            sin(u_seed * 19.173 + 1.23) * 380.0,
            cos(u_seed * 27.831 + 4.56) * 380.0
        );

        // Perturbación del borde para silueta orgánica rasgada
        float edgeNoise = fbm(uv * 2.2 + seedOff * 0.15);
        float irregular = clamp(u_irregularity, 0.0, 0.75);
        float r = length(uv) + (edgeNoise - 0.5) * irregular * 0.50;

        float s = clamp(u_softness, 0.0, 0.95);
        float mask = 1.0 - smoothstep(1.0 - s, 1.0, r);
        if (mask <= 0.0001) {
            return vec4(0.0);
        }

        // Movimiento sutil y dependiente de parallax
        float par = clamp(u_parallax, 0.0, 1.0);
        float t = u_time * mix(0.008, 0.018, par);

        float ns = max(0.0001, u_noiseScale);
        vec2 p = uv * ns + seedOff;
        p = domainWarp(p, t, seedOff);
        float n = fbm(p);

        float cloud = smoothstep(0.24, 0.90, n);
        float centerBoost = smoothstep(1.0, 0.0, r);

        // Modulación morfológica procedural:
        // 0: Difusa clásica (núcleo denso con halo suave)
        // 1: Anular (Ring/Burbuja con centro semivacío y borde luminoso)
        // 2: Bipolar (Reloj de arena / Lóbulos en alas de mariposa)
        // 3: Filamentosa (Velo cósmico con estrías turbulentas)
        float morph = clamp(u_morphology, 0.0, 3.0);
        float density = cloud * (0.80 + 0.45 * centerBoost);

        if (morph > 0.5 && morph < 1.5) {
            // Anular / Bubble
            float ringFactor = smoothstep(0.0, 0.42, r) * smoothstep(1.0, 0.48, r);
            density = cloud * (0.28 + 1.35 * ringFactor);
        } else if (morph >= 1.5 && morph < 2.5) {
            // Bipolar
            float angle = atan(uv.y, uv.x);
            float lobe = pow(abs(cos(angle)), 1.6);
            float bipolarFactor = 0.35 + 0.95 * lobe * smoothstep(0.08, 0.75, r);
            density = cloud * (0.45 + 0.85 * bipolarFactor);
        } else if (morph >= 2.5) {
            // Filamentosa
            float filNoise = fbm(p * 2.3);
            float filFactor = pow(abs(sin(filNoise * 6.28)), 1.6);
            density = cloud * (0.48 + 1.05 * filFactor);
        }

        // Banda oscura de polvo cósmico con orientación procedural
        float dirAngle = sin(u_seed * 43.12) * 3.14159;
        vec2 dirVec = vec2(cos(dirAngle), sin(dirAngle));
        float dirCoord = dot(uv, dirVec);
        float darkFogNoise = fbm(p * 1.8 + vec2(t * 0.30, t * 0.15));
        float darkFogMask = smoothstep(0.35, 0.85, darkFogNoise) * smoothstep(0.25, 0.75, dirCoord + 0.15);
        float darkFogIntensity = darkFogMask * 0.80 * (0.8 + par * 0.4);

        // Niebla pálida central para profundidad
        float paleFogNoise = fbm(p * 0.9 + vec2(-t * 0.30, t * 0.50));
        float paleFogMask = smoothstep(0.3, 0.7, paleFogNoise) * centerBoost;
        float paleFogIntensity = paleFogMask * 0.18 * (0.16 + par * 0.8);

        // Destellos estelares ("sparkle") controlados por u_sparkleStrength
        float sparkScale = 2.5 + par * 4.0;
        vec2 sp = p * sparkScale;

        float s1 = noise(sp + vec2(u_time * (0.8 + par * 0.4) + u_seed, -u_time * (0.6 + par * 0.3) + u_seed * 0.7));
        float s2 = noise(sp * 1.3 + vec2(-u_time * (0.7 + par * 0.3) + u_seed * 1.3, u_time * (0.5 + 0.2 * par)));
        float smax = max(s1, s2);

        float sparkMask = smoothstep(0.88, 1.0, smax) * mask;
        float sparkStrength = clamp(u_sparkleStrength, 0.0, 3.0) * (0.9 + 0.6 * par);

        vec4 texel = Texel(tex, texcoord);
        vec3 baseColor = color.rgb * texel.rgb * u_brightness;
        vec3 coreColor = u_coreColor * texel.rgb * u_brightness;
        
        // Aplicar absorción de polvo oscuro para contraste
        vec3 darkFogColor = baseColor * (1.0 - darkFogIntensity * 0.85);
        vec3 darkCoreColor = coreColor * (1.0 - darkFogIntensity * 0.70);
        
        // Transición dual-tone bi-tonal orgánica
        float coreBlend = smoothstep(0.18, 0.88, density * (0.6 + 0.4 * centerBoost));
        vec3 blendedBase = mix(darkFogColor, darkCoreColor, coreBlend * 0.82);
        
        // Armonización de micro-frecuencias
        float colorHarmony = smoothstep(0.2, 0.8, fbm(p * 0.7 + t * 0.05));
        vec3 harmonizedBase = mix(blendedBase, blendedBase * vec3(1.1, 0.95, 1.05), colorHarmony * 0.25);
        
        vec3 paleFogColor = mix(harmonizedBase, vec3(1.0, 0.98, 0.95) * u_brightness * 0.65, paleFogIntensity);
        vec3 finalColor = paleFogColor * (1.0 + sparkStrength * sparkMask);

        float a = mask * density * clamp(u_intensity, 0.0, 2.0) * texel.a;
        a *= 1.35;
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

    -- Instalar capa de compatibilidad transparente en el metatable de Shader
    -- para interceptar llamadas directas legacy (ej: shader:send("u_seed", ...) en loading_screen o renderers externos)
    if not NebulasShaders._hookInstalled and debug and debug.getmetatable then
        local mt = debug.getmetatable(shader)
        if mt and mt.__index and type(mt.__index.send) == "function" then
            local rawSend = mt.__index.send
            local rawHasUniform = mt.__index.hasUniform

            mt.__index.send = function(self, name, ...)
                if self == NebulasShaders.state.shader then
                    local u = NebulasShaders.state.uniforms
                    if name == "u_seed" then
                        local v = ...
                        _packedP1[1] = v; u.u_seed = v
                        return rawSend(self, "u_params1", _packedP1)
                    elseif name == "u_noiseScale" then
                        local v = ...
                        _packedP1[2] = v; u.u_noiseScale = v
                        return rawSend(self, "u_params1", _packedP1)
                    elseif name == "u_warpAmp" then
                        local v = ...
                        _packedP1[3] = v; u.u_warpAmp = v
                        return rawSend(self, "u_params1", _packedP1)
                    elseif name == "u_warpFreq" then
                        local v = ...
                        _packedP1[4] = v; u.u_warpFreq = v
                        return rawSend(self, "u_params1", _packedP1)
                    elseif name == "u_softness" then
                        local v = ...
                        _packedP2[1] = v; u.u_softness = v
                        return rawSend(self, "u_params2", _packedP2)
                    elseif name == "u_brightness" then
                        local v = ...
                        _packedP2[2] = v; u.u_brightness = v
                        return rawSend(self, "u_params2", _packedP2)
                    elseif name == "u_parallax" then
                        local v = ...
                        _packedP2[3] = v; u.u_parallax = v
                        return rawSend(self, "u_params2", _packedP2)
                    elseif name == "u_sparkleStrength" then
                        local v = ...
                        _packedP2[4] = v; u.u_sparkleStrength = v
                        return rawSend(self, "u_params2", _packedP2)
                    elseif name == "u_intensity" then
                        local v = ...
                        _packedP3[1] = v; u.u_intensity = v
                        return rawSend(self, "u_params3", _packedP3)
                    elseif name == "u_morphology" then
                        local v = ...
                        _packedP3[2] = v; u.u_morphology = v
                        return rawSend(self, "u_params3", _packedP3)
                    elseif name == "u_irregularity" then
                        local v = ...
                        _packedP3[3] = v; u.u_irregularity = v
                        return rawSend(self, "u_params3", _packedP3)
                    end
                end
                return rawSend(self, name, ...)
            end

            if rawHasUniform then
                mt.__index.hasUniform = function(self, name)
                    if self == NebulasShaders.state.shader then
                        if name == "u_seed" or name == "u_noiseScale" or name == "u_warpAmp" or name == "u_warpFreq"
                           or name == "u_softness" or name == "u_brightness" or name == "u_parallax" or name == "u_sparkleStrength"
                           or name == "u_intensity" or name == "u_morphology" or name == "u_irregularity" then
                            return true
                        end
                    end
                    return rawHasUniform(self, name)
                end
            end

            NebulasShaders._hookInstalled = true
        end
    end
    
    -- Configurar uniforms por defecto
    local ok = pcall(function()
        if shader:hasUniform("u_time") then shader:send("u_time", NebulasShaders.state.uniforms.u_time) end
        if shader:hasUniform("u_params1") then shader:send("u_params1", NebulasShaders.state.uniforms.u_params1) end
        if shader:hasUniform("u_params2") then shader:send("u_params2", NebulasShaders.state.uniforms.u_params2) end
        if shader:hasUniform("u_params3") then shader:send("u_params3", NebulasShaders.state.uniforms.u_params3) end
        if shader:hasUniform("u_coreColor") then shader:send("u_coreColor", NebulasShaders.state.uniforms.u_coreColor) end
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

-- Actualizar uniforms del shader (soporta vectores y nombres escalares para total compatibilidad)
function NebulasShaders.updateUniforms(uniforms)
    local shader = NebulasShaders.getShader()
    if not shader then return false end
    
    local success = pcall(function()
        local u = NebulasShaders.state.uniforms
        local p1Changed, p2Changed, p3Changed = false, false, false

        for uniform, value in pairs(uniforms) do
            if uniform == "u_time" then
                if shader:hasUniform("u_time") then shader:send("u_time", value) end
                u.u_time = value
            elseif uniform == "u_params1" then
                if shader:hasUniform("u_params1") then shader:send("u_params1", value) end
                u.u_params1 = value
            elseif uniform == "u_params2" then
                if shader:hasUniform("u_params2") then shader:send("u_params2", value) end
                u.u_params2 = value
            elseif uniform == "u_params3" then
                if shader:hasUniform("u_params3") then shader:send("u_params3", value) end
                u.u_params3 = value
            elseif uniform == "u_coreColor" then
                if shader:hasUniform("u_coreColor") then shader:send("u_coreColor", value) end
                u.u_coreColor = value
            -- Aliases escalares
            elseif uniform == "u_seed" then
                _packedP1[1] = value; u.u_seed = value; p1Changed = true
            elseif uniform == "u_noiseScale" then
                _packedP1[2] = value; u.u_noiseScale = value; p1Changed = true
            elseif uniform == "u_warpAmp" then
                _packedP1[3] = value; u.u_warpAmp = value; p1Changed = true
            elseif uniform == "u_warpFreq" then
                _packedP1[4] = value; u.u_warpFreq = value; p1Changed = true
            elseif uniform == "u_softness" then
                _packedP2[1] = value; u.u_softness = value; p2Changed = true
            elseif uniform == "u_brightness" then
                _packedP2[2] = value; u.u_brightness = value; p2Changed = true
            elseif uniform == "u_parallax" then
                _packedP2[3] = value; u.u_parallax = value; p2Changed = true
            elseif uniform == "u_sparkleStrength" then
                _packedP2[4] = value; u.u_sparkleStrength = value; p2Changed = true
            elseif uniform == "u_intensity" then
                _packedP3[1] = value; u.u_intensity = value; p3Changed = true
            elseif uniform == "u_morphology" then
                _packedP3[2] = value; u.u_morphology = value; p3Changed = true
            elseif uniform == "u_irregularity" then
                _packedP3[3] = value; u.u_irregularity = value; p3Changed = true
            end
        end

        if p1Changed and shader:hasUniform("u_params1") then shader:send("u_params1", _packedP1) end
        if p2Changed and shader:hasUniform("u_params2") then shader:send("u_params2", _packedP2) end
        if p3Changed and shader:hasUniform("u_params3") then shader:send("u_params3", _packedP3) end
    end)
    
    return success
end

-- Configurar uniforms específicos para una nebulosa (Fase 4: vectorizado y sin asignación de tablas)
function NebulasShaders.configureForNebula(nebula, currentTime)
    local shader = NebulasShaders.getShader()
    if not shader then return false end

    local seedVal = (nebula.seed or 0) * 0.001
    local noiseScaleVal = nebula.noiseScale or 2.5
    local warpAmpVal = nebula.warpAmp or 0.65
    local warpFreqVal = nebula.warpFreq or 1.25

    local softnessVal = nebula.softness or 0.28
    local brightnessVal = nebula.brightness or 1.20
    local parallaxVal = math.max(0.0, math.min(1.0, nebula.parallax or 0.85))
    local sparkleVal = nebula.sparkleStrength or 0.0

    local intensityVal = nebula.intensity or 0.6
    local morphologyVal = nebula.morphology or 0.0
    local irregularityVal = nebula.irregularity or 0.35

    local core = nebula.coreColor or {1.0, 1.0, 1.0}
    local cR = core[1] or 1.0
    local cG = core[2] or 1.0
    local cB = core[3] or 1.0

    _packedP1[1] = seedVal
    _packedP1[2] = noiseScaleVal
    _packedP1[3] = warpAmpVal
    _packedP1[4] = warpFreqVal

    _packedP2[1] = softnessVal
    _packedP2[2] = brightnessVal
    _packedP2[3] = parallaxVal
    _packedP2[4] = sparkleVal

    _packedP3[1] = intensityVal
    _packedP3[2] = morphologyVal
    _packedP3[3] = irregularityVal
    _packedP3[4] = 0.0

    _packedCore[1] = cR
    _packedCore[2] = cG
    _packedCore[3] = cB

    -- Sincronizar estado interno para debug/telemetría
    local u = NebulasShaders.state.uniforms
    u.u_params1 = _packedP1
    u.u_params2 = _packedP2
    u.u_params3 = _packedP3
    u.u_coreColor = _packedCore
    u.u_seed = seedVal
    u.u_noiseScale = noiseScaleVal
    u.u_warpAmp = warpAmpVal
    u.u_warpFreq = warpFreqVal
    u.u_softness = softnessVal
    u.u_brightness = brightnessVal
    u.u_parallax = parallaxVal
    u.u_sparkleStrength = sparkleVal
    u.u_intensity = intensityVal
    u.u_morphology = morphologyVal
    u.u_irregularity = irregularityVal

    -- Actualizar u_time solo si se especifica y difiere
    if currentTime and currentTime ~= u.u_time and shader:hasUniform("u_time") then
        shader:send("u_time", currentTime)
        u.u_time = currentTime
    end

    -- 4 envíos vectoriales directos (reducción masiva de overhead de driver OpenGL)
    if shader:hasUniform("u_params1") then shader:send("u_params1", _packedP1) end
    if shader:hasUniform("u_params2") then shader:send("u_params2", _packedP2) end
    if shader:hasUniform("u_params3") then shader:send("u_params3", _packedP3) end
    if shader:hasUniform("u_coreColor") then shader:send("u_coreColor", _packedCore) end

    return true
end

-- Actualizar tiempo explícito del shader
function NebulasShaders.updateTime(time)
    local shader = NebulasShaders.getShader()
    if shader and shader:hasUniform("u_time") then
        local t = time or love.timer.getTime()
        shader:send("u_time", t)
        NebulasShaders.state.uniforms.u_time = t
    end
end

-- Actualizar tiempo del shader (llamar cada frame)
function NebulasShaders.update(dt)
    if not NebulasShaders.state.initialized then return end
    NebulasShaders.updateTime(love.timer.getTime())
end

-- Aplicar shader de nebulosas
function NebulasShaders.setShader()
    local shader = NebulasShaders.getShader()
    if shader then
        love.graphics.setShader(shader)
        local now = love.timer.getTime()
        if shader:hasUniform("u_time") and NebulasShaders.state.uniforms.u_time ~= now then
            shader:send("u_time", now)
            NebulasShaders.state.uniforms.u_time = now
        end
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