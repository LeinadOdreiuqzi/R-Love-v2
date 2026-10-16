-- src/shaders/mars_moon.lua
-- Shader GLSL de Luna / Planetoide Marciano (Tau Ceti Tier 3)
-- Diseñado específicamente para cuerpos celestes de corteza marciana:
-- - Tonalidades rojizas / herrumbre de óxido férrico (terracota, ocre, arcilla)
-- - Cuencas volcánicas y llanuras basálticas oscuras (Syrtis Major, Acidalia)
-- - Cráteres de impacto detallados con crestas elevadas y picos centrales
-- - Atmósfera tenue de polvo en suspensión con dispersión Rayleigh salmón/ámbar
-- - Casquetes polares sutiles de escarcha / hielo seco (dióxido de carbono)
-- - Luz ambiental cálida (planet-shine) para garantizar visibilidad contrastada
--   incluso cuando se sitúa en la zona de sombra detrás del planeta principal ("pero visiblemente")

local MarsMoonShader = {
    shader = nil,
    initialized = false
}

local shaderCode = [[
    extern float u_time;
    extern vec3 u_lightDir;
    extern vec2 u_uvOffset;
    extern float u_atmosphereThickness;
    extern vec3 u_atmosphereColor; // Ámbar / salmón marciano
    extern vec3 u_landColor;       // Terracota / herrumbre óxido de hierro
    extern vec3 u_basinColor;      // Basalto oscuro / cuencas volcánicas
    extern vec3 u_ambientColor;    // Planet-shine cálido de sombra

    float hash(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
    }

    float noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
                   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
    }

    float fbm(vec2 p) {
        float v = 0.0;
        float a = 0.5;
        for (int i = 0; i < 5; i++) {
            v += a * noise(p);
            p = p * 2.04 + vec2(2.3, 5.7);
            a *= 0.5;
        }
        return v;
    }

    // Perfil de cráter de impacto marciano (borde sobreelevado + cuenca excavada + pico central)
    float crater(vec2 p, vec2 c, float rad) {
        float d = length(p - c);
        float rim = smoothstep(rad * 1.25, rad * 0.95, d);
        float bowl = smoothstep(rad * 0.95, 0.0, d);
        float peak = smoothstep(rad * 0.25, 0.0, d) * 0.45;
        return rim * 0.35 - bowl * 0.45 + peak;
    }

    vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
        float maxR = 1.0 + u_atmosphereThickness;
        vec2 p = (texcoord - vec2(0.5)) * (2.0 * maxR);
        float r = length(p);

        if (r > maxR) {
            return vec4(0.0);
        }

        vec3 light = normalize(u_lightDir);
        vec3 view = vec3(0.0, 0.0, 1.0);

        // ─── 1. EXÓSFERA Y DISPERSIÓN DE POLVO MARCIANO (r > 1.0) ─────────────
        if (r > 1.0) {
            float distNorm = (r - 1.0) / max(0.001, u_atmosphereThickness);
            float haloFade = exp(-distNorm * 3.6) * (1.0 - distNorm);

            float sunFacing = dot(p / r, light.xy);
            float dayFactor = clamp(sunFacing * 0.55 + 0.45, 0.12, 1.0);

            vec3 sunsetColor = vec3(1.0, 0.50, 0.22);
            vec3 atmCol = mix(u_atmosphereColor, sunsetColor, smoothstep(0.4, -0.3, abs(sunFacing)) * 0.65);

            vec3 haloColor = atmCol * (haloFade * dayFactor * 2.1);
            float alpha = clamp(haloFade * dayFactor * 1.4, 0.0, 1.0);
            return vec4(haloColor * color.rgb, alpha * color.a);
        }

        // ─── 2. SUPERFICIE SÓLIDA MARCIANA (r <= 1.0) ─────────────────────────
        float z = sqrt(max(0.0, 1.0 - r * r));
        vec3 normal = vec3(p.x, p.y, z);

        // Proyección esférica de texturas con rotación y viento procedimental
        float phi = atan(p.x, z) / 6.2831853;
        float theta = asin(clamp(p.y, -1.0, 1.0)) / 3.14159265 + 0.5;
        vec2 uv = vec2(phi, theta) + u_uvOffset + vec2(u_time * 0.0008, 0.0);

        // Warp continental y cañones de falla tipo Valles Marineris
        vec2 warp = vec2(fbm(uv * 3.8), fbm(uv * 3.8 + vec2(4.1, 7.3))) * 0.18;
        vec2 wuv = uv + warp;

        float elevation = fbm(wuv * 4.2);
        elevation += 0.26 * fbm(wuv * 9.6);
        elevation += 0.12 * fbm(wuv * 22.0);

        // Cráteres de impacto repartidos en la superficie marciana
        elevation += crater(wuv, vec2(0.28, 0.52), 0.075);
        elevation += crater(wuv, vec2(0.36, 0.44), 0.050);
        elevation += crater(wuv, vec2(0.20, 0.68), 0.060);
        elevation += crater(wuv, vec2(0.48, 0.38), 0.090);
        elevation += crater(wuv, vec2(0.14, 0.32), 0.045);

        // Falla de cañón tectónico marciano
        float riftDist = abs(wuv.y - (0.50 + 0.06 * sin(wuv.x * 12.0)));
        float canyon = smoothstep(0.035, 0.0, riftDist) * smoothstep(0.15, 0.35, wuv.x) * smoothstep(0.70, 0.50, wuv.x);
        elevation -= canyon * 0.32;

        // Estratificación de materiales marcianos:
        // - Basaltos oscuros y lechos de cráter (baja elevación)
        // - Tierras altas de óxido de hierro / terracota (media)
        // - Mesetas y bordes de cráter con polvo ocre claro (alta)
        float basinMask = smoothstep(0.48, 0.34, elevation);
        float highlandMask = smoothstep(0.52, 0.72, elevation);
        float peakMask = smoothstep(0.72, 0.88, elevation);

        vec3 surfaceCol = mix(u_landColor, u_basinColor, basinMask);
        vec3 ocreHighlands = u_landColor * vec3(1.18, 1.10, 0.88);
        surfaceCol = mix(surfaceCol, ocreHighlands, highlandMask * 0.75);
        surfaceCol = mix(surfaceCol, vec3(0.92, 0.55, 0.30), peakMask * 0.50);

        // Textura granular de polvo y roca
        float dustNoise = fbm(wuv * 36.0);
        surfaceCol *= (0.86 + 0.28 * dustNoise);

        // Velo de tormentas de polvo marcianas en movimiento dinámico
        vec2 stormUv = wuv * 4.0 + vec2(u_time * 0.003, u_time * 0.001);
        float storm = smoothstep(0.62, 0.85, fbm(stormUv));
        surfaceCol = mix(surfaceCol, u_atmosphereColor * 1.12, storm * 0.24);

        // Casquete polar marciano (escarcha / dióxido de carbono)
        vec3 poleDir = normalize(vec3(0.22, 0.97, 0.0));
        float lat = abs(dot(normal, poleDir));
        float iceMask = smoothstep(0.90, 0.97, lat + 0.03 * fbm(uv * 7.0));
        vec3 polarIce = vec3(0.95, 0.92, 0.90);
        surfaceCol = mix(surfaceCol, polarIce, iceMask * 0.90);

        // ─── 3. ILUMINACIÓN SOLAR Y LUZ AMBIENTAL DE SOMBRA ───────────────────
        float NdotL = dot(normal, light);
        float directSun = smoothstep(-0.14, 0.22, NdotL);

        // Luz ambiental cálida (planet-shine / resplandor en la zona de sombra):
        // Garantiza que la luna no sea una mancha negra en la sombra, sino que mantenga
        // sus tonos rojizos y relieve claramente distinguibles ("pero visiblemente")
        vec3 ambient = u_ambientColor;
        vec3 litColor = surfaceCol * mix(ambient, vec3(1.0), directSun);

        // ─── 4. DISPERSIÓN RAYLEIGH EN EL LIMBO (FRESNEL DE POLVO) ────────────
        float fresnel = 1.0 - normal.z;
        float rimGlow = pow(fresnel, 4.0);
        float rimSun = clamp(dot(normal.xy, light.xy) * 0.5 + 0.5, 0.20, 1.0);
        vec3 rimColor = u_atmosphereColor * (rimGlow * rimSun * 1.5);
        litColor += rimColor;

        return vec4(litColor * color.rgb, color.a);
    }
]]

function MarsMoonShader.init()
    if MarsMoonShader.initialized and MarsMoonShader.shader then
        return true
    end

    local ok, s = pcall(love.graphics.newShader, shaderCode)
    if ok and s then
        MarsMoonShader.shader = s
        MarsMoonShader.initialized = true
        return true
    else
        print("[MarsMoonShader] Error compiling shader: " .. tostring(s))
        return false
    end
end

function MarsMoonShader.getShader()
    if not MarsMoonShader.initialized then
        MarsMoonShader.init()
    end
    return MarsMoonShader.shader
end

return MarsMoonShader
