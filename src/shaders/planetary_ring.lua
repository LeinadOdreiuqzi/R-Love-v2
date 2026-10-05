-- src/shaders/planetary_ring.lua
-- Shader GLSL de Anillos Planetarios Helados (Banda Continua Fotorealista con División de Cassini y Sub-anillos)

local PlanetaryRingShader = {
    shader = nil,
    initialized = false
}

local shaderCode = [[
    extern float u_time;
    extern float u_innerRatio;   // Radio interno relativo [0..1]
    extern float u_yFlatten;     // Aplanamiento elíptico por inclinación orbital (ej: 0.24)
    extern float u_drawSide;     // -1.0 = sólo mitad posterior, +1.0 = sólo mitad frontal, 0.0 = completo
    extern vec3 u_ringColor;     // Tonalidad del hielo cósmico (ej: 0.75, 0.90, 1.00)
    extern vec3 u_ringHighlight; // Resplandor especular / frontal (ej: 0.95, 0.98, 1.00)
    extern float u_baseAlpha;    // Opacidad global

    float hash(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
    }

    vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
        // Coordenadas normalizadas [-1, 1] en el plano del anillo
        vec2 p = (texcoord - vec2(0.5)) * 2.0;

        // Oclusión por hemisferio (frente vs fondo)
        if (u_drawSide < -0.5 && p.y > 0.0) {
            return vec4(0.0);
        }
        if (u_drawSide > 0.5 && p.y < 0.0) {
            return vec4(0.0);
        }

        // Radio en el plano circular del anillo (des-aplanando la proyección oblicua)
        float r = length(vec2(p.x, p.y / max(0.01, u_yFlatten)));

        if (r < u_innerRatio || r > 1.0) {
            return vec4(0.0);
        }

        // Coordenada radial normalizada entre borde interior (0.0) y exterior (1.0)
        float rNorm = (r - u_innerRatio) / (1.0 - u_innerRatio);

        // Suavizado en bordes interior y exterior
        float edgeFade = smoothstep(0.0, 0.03, rNorm) * smoothstep(1.0, 0.96, rNorm);

        // ─── ESTRUCTURA DE BANDAS DE LOS ANILLOS ──────────────────────────────
        // 1. Anillo C (Interior sutil): rNorm in [0.0, 0.24]
        // 2. Anillo B (Principal denso y brillante): rNorm in [0.24, 0.58]
        // 3. División de Cassini (Brecha oscura): rNorm in [0.58, 0.65]
        // 4. Anillo A (Exterior elegante): rNorm in [0.65, 0.95]
        // 5. División de Encke y borde F: rNorm in [0.95, 1.00]

        float density = 0.0;
        if (rNorm < 0.24) {
            density = mix(0.15, 0.35, rNorm / 0.24);
        } else if (rNorm < 0.58) {
            float bFrac = (rNorm - 0.24) / 0.34;
            density = mix(0.70, 0.95, sin(bFrac * 3.14159));
        } else if (rNorm < 0.65) {
            // Brecha de Cassini
            density = 0.02;
        } else if (rNorm < 0.95) {
            float aFrac = (rNorm - 0.65) / 0.30;
            density = mix(0.45, 0.68, sin(aFrac * 3.14159));
        } else {
            density = 0.18;
        }

        // Cientos de finos sub-anillos microscópicos de partículas de hielo en lenta rotación
        float microRipples = sin(rNorm * 110.0 + u_time * 0.05) * 0.12 + sin(rNorm * 280.0 - u_time * 0.08) * 0.06;
        density = clamp(density + microRipples, 0.0, 1.0);

        // Gradiente de color según densidad
        vec3 col = mix(u_ringColor, u_ringHighlight, density * 0.65);

        // Resplandor de ángulo rasante hacia los extremos de la elipse
        float limbGlow = 0.85 + 0.35 * abs(p.x);
        col *= limbGlow;

        float alpha = density * edgeFade * u_baseAlpha * color.a;
        return vec4(col, alpha);
    }
]]

function PlanetaryRingShader.init()
    if PlanetaryRingShader.initialized and PlanetaryRingShader.shader then
        return true
    end

    local ok, s = pcall(love.graphics.newShader, shaderCode)
    if ok and s then
        PlanetaryRingShader.shader = s
        PlanetaryRingShader.initialized = true
        return true
    else
        print("[PlanetaryRingShader] Error compiling shader: " .. tostring(s))
        return false
    end
end

function PlanetaryRingShader.getShader()
    if not PlanetaryRingShader.initialized then
        PlanetaryRingShader.init()
    end
    return PlanetaryRingShader.shader
end

return PlanetaryRingShader
