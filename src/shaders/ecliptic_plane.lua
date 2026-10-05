-- src/shaders/ecliptic_plane.lua
-- Shader GLSL de Plano Orbital en Vista de Canto / Oblicua a 0° (Disco Zodiacal Natural, Translúcido y Elegante)

local EclipticPlaneShader = {
    shader = nil,
    initialized = false
}

local shaderCode = [[
    extern float u_time;
    extern vec3 u_color;          // Color cósmico base (cian/azul profundo)

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
        for (int i = 0; i < 3; i++) {
            v += a * noise(p);
            p = p * 2.15 + vec2(1.7, 3.2);
            a *= 0.5;
        }
        return v;
    }

    vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
        // Coordenadas normalizadas [-1, 1] en el plano elíptico de canto
        vec2 uv = (texcoord - vec2(0.5)) * 2.0;

        float rx = abs(uv.x);
        float ry = abs(uv.y);

        if (rx > 1.0 || ry > 1.0) {
            return vec4(0.0);
        }

        float t = u_time * 0.035;

        // ─── 1. PERFIL TRANSLÚCIDO DE CANTO (EDGE-ON DISK PROFILE) ──────────
        // Caída horizontal suave hacia los extremos del sistema
        float horizFalloff = smoothstep(1.0, 0.12, rx);

        // Caída vertical suave y etérea (sin saturación bloqueante)
        float vertProfile = exp(-pow(uv.y * 3.2, 2.0));
        float vertCore = exp(-pow(uv.y * 7.0, 2.0)) * 0.45;

        // Resplandor central suave de difusión estelar
        float centralBulge = exp(-length(vec2(uv.x * 2.5, uv.y * 4.5)) * 2.0);

        // ─── 2. FILAMENTOS Y POLVO CÓSMICO TRANSLÚCIDO ───────────────────────
        vec2 dustUv = vec2(uv.x * 3.5 - t * 0.35, uv.y * 8.0);
        float dustNoise = fbm(dustUv);
        dustNoise += 0.3 * fbm(vec2(uv.x * 8.0 + t * 0.15, uv.y * 16.0));

        // Banda sutil ecuatorial de polvo
        float dustLane = 1.0 - exp(-pow(uv.y * 9.0, 2.0)) * 0.35 * smoothstep(0.08, 0.6, rx);

        // Intensidad moderada para preservar la visibilidad de las estrellas y planetas de fondo
        float diskIntensity = (vertProfile * 0.32 + vertCore * 0.28 + centralBulge * 0.38) * horizFalloff;
        diskIntensity *= (0.70 + 0.30 * dustNoise) * dustLane;

        // ─── 3. GRADIENTE DE PROFUNDIDAD EN PERSPECTIVA (FALSO 3D) ─────────
        float depthFog = clamp(uv.y * 0.25 + 0.85, 0.65, 1.15);

        // ─── 4. PALETA DE COLOR CÓSMICA ELEGANTE ───────────────────────────
        // Núcleo cálido de stardust -> Cian translúcido -> Azul espacial profundo
        vec3 colCore = vec3(1.0, 0.92, 0.78);
        vec3 colMid = vec3(0.40, 0.70, 0.95);
        vec3 colOuter = u_color; // Cian/azul interestelar

        vec3 diskColor = mix(colCore, colMid, smoothstep(0.0, 0.40, rx));
        diskColor = mix(diskColor, colOuter, smoothstep(0.35, 0.90, rx));
        diskColor += colCore * (centralBulge * 0.45);

        vec3 finalRgb = diskColor * diskIntensity * 1.5 * depthFog;
        float totalAlpha = clamp(diskIntensity * 0.60 * depthFog, 0.0, 0.70);

        return vec4(finalRgb, totalAlpha * color.a);
    }
]]

function EclipticPlaneShader.init()
    if EclipticPlaneShader.initialized and EclipticPlaneShader.shader then
        return true
    end

    local ok, s = pcall(love.graphics.newShader, shaderCode)
    if ok and s then
        EclipticPlaneShader.shader = s
        EclipticPlaneShader.initialized = true
        return true
    else
        print("[EclipticPlaneShader] Error compiling shader: " .. tostring(s))
        return false
    end
end

function EclipticPlaneShader.getShader()
    if not EclipticPlaneShader.initialized then
        EclipticPlaneShader.init()
    end
    return EclipticPlaneShader.shader
end

return EclipticPlaneShader
