-- src/shaders/station_shaders.lua
-- Módulo especializado para shaders de estaciones espaciales

local StationShaders = {}

-- Estado interno del módulo
StationShaders.state = {
    shader = nil,
    initialized = false,
    config = {
        -- Parámetros de control visual por LOD
        specular = {
            [0] = { intensity = 0.8, exponent = 32.0 },  -- LOD máximo: especular intenso
            [1] = { intensity = 0.6, exponent = 24.0 },  -- LOD alto: especular medio
            [2] = { intensity = 0.4, exponent = 16.0 },  -- LOD medio: especular reducido
            [3] = { intensity = 0.2, exponent = 12.0 },  -- LOD bajo: especular mínimo
            [4] = { intensity = 0.1, exponent = 8.0 }    -- LOD mínimo: especular muy bajo
        },
        rimLight = {
            [0] = { intensity = 0.35, width = 2.0 },     -- LOD máximo: rim intenso
            [1] = { intensity = 0.25, width = 2.2 },     -- LOD alto: rim medio
            [2] = { intensity = 0.15, width = 2.5 },     -- LOD medio: rim reducido
            [3] = { intensity = 0.08, width = 3.0 },     -- LOD bajo: rim mínimo
            [4] = { intensity = 0.05, width = 3.5 }      -- LOD mínimo: rim muy bajo
        },
        metallic = {
            baseReflectance = 0.7,
            anisotropyStrength = 0.03,
            brushedFrequency = 180.0
        },
        damage = {
            noiseFrequency = 120.0,
            crackThreshold = 0.97,
            colorTint = {0.45, 0.48, 0.55}
        }
    }
}

-- Código del shader de estaciones con parámetros expuestos
local function getStationShaderCode()
    return [[
        extern float u_time;
        extern float u_lod;
        extern float u_rotation;
        extern float u_damage;
        extern vec2 u_lightDir;
        extern float u_shapeType; // 0: ring, 1: modular, 2: elongated
        extern float u_seed;
        extern float u_size;
        extern float u_specularIntensity;
        extern float u_specularExponent;
        extern float u_rimIntensity;
        extern float u_rimWidth;

        float hash(float n) { return fract(sin(n) * 43758.5453123); }
        float noise(vec2 p) { return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }

        vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
            vec2 uv = texcoord - vec2(0.5);
            // Rotación
            float c = cos(u_rotation);
            float s = sin(u_rotation);
            uv = mat2(c, -s, s, c) * uv;

            float r = length(uv) * 2.0;
            float texA = Texel(tex, texcoord).a;

            // Máscara base y variantes según shapeType
            float mask = smoothstep(1.0, 0.97, r);
            if (u_shapeType < 0.5) {
                // Ring: anillo con hueco interior
                float inner = 0.55 + 0.05 * step(2.0, u_lod);
                float outerEdge = smoothstep(1.0, 0.97, r);
                float innerEdge = 1.0 - smoothstep(inner, inner - 0.03, r);
                mask = clamp(outerEdge * innerEdge, 0.0, 1.0);
            } else if (u_shapeType < 1.5) {
                // Modular: facetas sutiles para estructura modular
                float angle = atan(uv.y, uv.x);
                float facets = 0.04 * sin(angle * 6.0 + u_seed * 10.0);
                float rr = length(uv * (1.0 + facets)) * 2.0;
                mask = smoothstep(1.0, 0.96, rr);
            } else {
                // Elongated: compresión elíptica para naves alargadas
                vec2 e = uv; e.x *= 0.55;
                float rr = length(e) * 2.0;
                mask = smoothstep(1.0, 0.965, rr);
            }

            // Normal esférica aproximada para iluminación
            float zz = clamp(1.0 - dot(uv, uv) * 4.0, 0.0, 1.0);
            vec3 normal = normalize(vec3(uv * 2.0, sqrt(zz)));
            vec3 L = normalize(vec3(u_lightDir, 0.6));
            float lambert = max(dot(normal, L), 0.0);
            
            // Rim light con parámetros controlables
            float rim = pow(1.0 - max(normal.z, 0.0), u_rimWidth) * u_rimIntensity;

            // Comportamiento metálico y anisotropía sutil
            float brushed = 0.03 * sin((uv.x + uv.y * 1.7) * 180.0 + u_seed * 50.0);
            float metal = 0.7 + 0.3 * lambert + brushed;

            // Especular con parámetros controlables por LOD
            vec3 V = vec3(0.0, 0.0, 1.0);
            vec3 R = reflect(-L, normal);
            float spec = pow(max(dot(R, V), 0.0), u_specularExponent) * u_specularIntensity;

            // Daño: grunge + grietas
            float gn = noise(uv * (120.0 + u_seed * 3.0) + u_time * 0.1);
            float cracks = smoothstep(0.97, 1.0, sin((uv.x * 80.0 + u_seed * 12.0)) * sin((uv.y * 130.0 - u_seed * 7.0)));
            float damageMask = clamp(gn * 0.5 + cracks, 0.0, 1.0) * u_damage;

            // Composición final
            vec3 baseColor = color.rgb * (0.35 + 0.65 * metal);
            vec3 lit = baseColor * (0.6 + 0.6 * lambert) + vec3(1.0) * spec + baseColor * rim;
            vec3 damaged = mix(lit, lit * vec3(0.45, 0.48, 0.55), damageMask);

            float outAlpha = color.a * texA * mask * (0.9 - 0.25 * u_damage);
            return vec4(damaged, outAlpha);
        }
    ]]
end

-- Inicializar el módulo
function StationShaders.init()
    if StationShaders.state.initialized then
        return true
    end

    if not love.graphics or not love.graphics.newShader then
        print("✗ StationShaders: Love2D graphics not available")
        return false
    end

    local success, shader = pcall(love.graphics.newShader, getStationShaderCode())
    if success then
        StationShaders.state.shader = shader
        StationShaders.state.initialized = true
        print("✓ StationShaders: Shader de estaciones inicializado correctamente")
        return true
    else
        print("✗ StationShaders: Error al compilar shader: " .. tostring(shader))
        return false
    end
end

-- Obtener el shader compilado
function StationShaders.getShader()
    if not StationShaders.state.initialized then
        StationShaders.init()
    end
    return StationShaders.state.shader
end

-- Enviar uniforms base con parámetros por LOD
function StationShaders.sendUniforms(params)
    local shader = StationShaders.getShader()
    if not shader then return false end

    local lod = params.lod or 0
    local specConfig = StationShaders.state.config.specular[lod] or StationShaders.state.config.specular[4]
    local rimConfig = StationShaders.state.config.rimLight[lod] or StationShaders.state.config.rimLight[4]

    local function safeSend(name, value)
        pcall(function() shader:send(name, value) end)
    end

    -- Uniforms básicos
    safeSend("u_time", params.time or love.timer.getTime())
    safeSend("u_lod", lod)
    safeSend("u_rotation", params.rotation or 0)
    safeSend("u_damage", params.damage or 0)
    safeSend("u_lightDir", params.lightDir or {1, 0})
    safeSend("u_shapeType", params.shapeType or 1)
    safeSend("u_seed", params.seed or 0)
    safeSend("u_size", params.size or 100)

    -- Parámetros visuales por LOD
    safeSend("u_specularIntensity", specConfig.intensity)
    safeSend("u_specularExponent", specConfig.exponent)
    safeSend("u_rimIntensity", rimConfig.intensity)
    safeSend("u_rimWidth", rimConfig.width)

    return true
end

-- Configurar parámetros visuales por LOD
function StationShaders.setLODConfig(lod, specular, rimLight)
    if lod >= 0 and lod <= 4 then
        if specular then
            StationShaders.state.config.specular[lod] = specular
        end
        if rimLight then
            StationShaders.state.config.rimLight[lod] = rimLight
        end
    end
end

-- Obtener configuración actual
function StationShaders.getConfig()
    return StationShaders.state.config
end

-- Aplicar shader de forma segura
function StationShaders.setShader()
    local shader = StationShaders.getShader()
    if shader then
        love.graphics.setShader(shader)
        return true
    end
    return false
end

-- Remover shader
function StationShaders.unsetShader()
    love.graphics.setShader()
end

-- Debug: mostrar estado
function StationShaders.debugPrint()
    print("=== STATION SHADERS STATUS ===")
    print("Initialized:", StationShaders.state.initialized)
    print("Shader available:", StationShaders.state.shader ~= nil)
    if StationShaders.state.shader then
        print("✓ Station shader ready")
    else
        print("✗ Station shader not available")
    end
end

return StationShaders