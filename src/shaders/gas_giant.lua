-- src/shaders/gas_giant.lua
-- Shader GLSL de Gigante Gaseoso con Bandas Zonales, Vórtices de Coriolis y Atmósfera Rayleigh Celeste

local GasGiantShader = {
    shader = nil,
    initialized = false
}

local shaderCode = [[
    extern float u_time;
    extern vec3 u_lightDir;
    extern float u_atmosphereThickness;
    extern vec3 u_atmosphereColor;
    extern vec3 u_colorDeep;
    extern vec3 u_colorMid;
    extern vec3 u_colorLight;
    extern vec3 u_colorWhite;

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
            p = p * 2.04 + vec2(1.9, 5.7);
            a *= 0.5;
        }
        return v;
    }

    vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
        float maxR = 1.0 + u_atmosphereThickness;
        vec2 p = (texcoord - vec2(0.5)) * (2.0 * maxR);
        float r = length(p);

        if (r > maxR) {
            return vec4(0.0);
        }

        vec3 light = normalize(u_lightDir);

        // ─── 1. HALO ATMOSFÉRICO EXTERIOR (r > 1.0) ─────────────────────────
        if (r > 1.0) {
            float distNorm = (r - 1.0) / max(0.001, u_atmosphereThickness);
            float haloFade = exp(-distNorm * 3.6) * (1.0 - distNorm);
            float sunFacing = dot(p / r, light.xy);
            float dayFactor = clamp(sunFacing * 0.55 + 0.45, 0.06, 1.0);
            vec3 haloColor = u_atmosphereColor * (haloFade * dayFactor * 2.4);
            float alpha = clamp(haloFade * dayFactor * 1.6, 0.0, 1.0);
            return vec4(haloColor * color.rgb, alpha * color.a);
        }

        // ─── 2. SUPERFICIE ATMOSFÉRICA DEL GIGANTE GASEOSO (r <= 1.0) ───────
        float z = sqrt(max(0.0, 1.0 - r * r));
        vec3 normal = vec3(p.x, p.y, z);

        // Proyección esférica de latitud y longitud
        float phi = atan(p.x, z) / 3.14159265;
        float theta = asin(clamp(p.y, -1.0, 1.0)) / 1.5707963; // latitud [-1, 1]

        float t = u_time * 0.02;

        // Bandas zonales con cizalladura de vientos este-oeste
        float jetStream = sin(theta * 10.0) * 0.25 * t;
        vec2 uv = vec2(phi * 3.0 + jetStream, theta);

        // Turbulencia y remolinos de Coriolis
        float turbulence = fbm(uv * vec2(2.5, 9.0) + vec2(t * 0.1, 0.0));
        float fineBands = fbm(uv * vec2(6.0, 22.0) - vec2(t * 0.15, 0.0));

        // Patrón sinusoidal de bandas atmosféricas modulado por la turbulencia
        float bandPattern = sin(theta * 18.0 + turbulence * 2.2 + fineBands * 0.8) * 0.5 + 0.5;
        bandPattern = smoothstep(0.15, 0.85, bandPattern);

        // Remolino ciclónico / Vórtice de tormenta atmosférica
        vec2 stormCenter = vec2(0.25, -0.22);
        vec2 stormDelta = (vec2(phi, theta) - stormCenter) * vec2(1.0, 2.4);
        float stormDist = length(stormDelta);
        float stormSwirl = smoothstep(0.32, 0.04, stormDist);
        float stormSpiral = fbm(stormDelta * 8.0 + vec2(t * 0.3, t * 0.15));

        // Gradiente cromático de gas celeste / turquesa / menta helada
        vec3 atmCol = mix(u_colorDeep, u_colorMid, bandPattern);
        atmCol = mix(atmCol, u_colorLight, fineBands * 0.7);

        // Zonas de alta reflectividad (nubes cirros blancas en las crestas de viento)
        float cirrus = smoothstep(0.62, 0.88, turbulence + fineBands * 0.5);
        atmCol = mix(atmCol, u_colorWhite, cirrus * 0.75);

        // Tonalidad del ojo de la tormenta
        if (stormSwirl > 0.01) {
            vec3 stormColor = mix(u_colorLight, u_colorWhite, stormSpiral);
            atmCol = mix(atmCol, stormColor, stormSwirl * 0.65);
        }

        // ─── 3. ILUMINACIÓN Y TERMINADOR DÍA / NOCHE ─────────────────────────
        float NdotL = dot(normal, light);
        float dayNight = smoothstep(-0.15, 0.25, NdotL);

        // Silueta nocturna del gigante iluminada por dispersión interna
        vec3 nightGlow = u_colorDeep * 0.08;
        vec3 litColor = atmCol * mix(nightGlow, vec3(1.05), dayNight);

        // ─── 4. DISPERSIÓN ATMOSFÉRICA RAYLEIGH (LIMBO / FRESNEL) ───────────
        float fresnel = 1.0 - normal.z;
        float rimGlow = pow(fresnel, 3.8);
        float rimSun = clamp(dot(normal.xy, light.xy) * 0.5 + 0.5, 0.18, 1.0);
        vec3 rimColor = u_atmosphereColor * (rimGlow * rimSun * 1.8);
        litColor += rimColor;

        return vec4(litColor * color.rgb, color.a);
    }
]]

function GasGiantShader.init()
    if GasGiantShader.initialized and GasGiantShader.shader then
        return true
    end

    local ok, s = pcall(love.graphics.newShader, shaderCode)
    if ok and s then
        GasGiantShader.shader = s
        GasGiantShader.initialized = true
        return true
    else
        print("[GasGiantShader] Error compiling shader: " .. tostring(s))
        return false
    end
end

function GasGiantShader.getShader()
    if not GasGiantShader.initialized then
        GasGiantShader.init()
    end
    return GasGiantShader.shader
end

return GasGiantShader
