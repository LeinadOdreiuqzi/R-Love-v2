-- src/shaders/rocky_planet.lua
-- Shader GLSL de Planeta Rocoso Gigante (Super-Tierra de Tau Ceti Tier 3)
-- - Coherencia total de sombras e iluminación solar con las lunas secundarias (u_lightDir: {0.65, 0.45, 0.60})
-- - Atmósfera y bruma envolvente en tonalidades amarillas doradas con limbo Rayleigh.
-- - Superficie rocosa con continentes terracota/óxido rojizo, llanuras ocres y grandes cuencas minerales verde-blanquecinas con cráteres de impacto.
-- - Cobertura nubosa estilizada ("algunas nubes") en tonalidades blancas y verdosas.
-- - Relámpagos sub-atmosféricos espontáneos y realistas: tenues, difusos en las nubes y bajo la atmósfera, visibles en la zona nocturna/crepuscular.

local RockyPlanetShader = {
    shader = nil,
    initialized = false
}

local shaderCode = [[
    extern float u_time;
    extern vec3 u_lightDir;
    extern vec2 u_uvOffset;
    extern float u_atmosphereThickness;
    extern vec3 u_atmosphereColor; // Amarillo dorado cálido
    extern vec3 u_landTerracotta;  // Continentes terracota rojizo / marrón oxidado
    extern vec3 u_landPlains;      // Llanuras ocres / arena
    extern vec3 u_basinColor;      // Cuencas verde-blanquecinas
    extern vec3 u_cloudWhite;      // Nubes blancas
    extern vec3 u_cloudGreen;      // Nubes verdosas

    float hash(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
    }

    vec2 hash2(vec2 p) {
        return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
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
        for (int i = 0; i < 6; i++) {
            v += a * noise(p);
            p = p * 2.06 + vec2(1.7, 9.2);
            a *= 0.5;
        }
        return v;
    }

    // Cráteres de impacto geológicos naturales
    float crater(vec2 p, vec2 center, float radius) {
        float d = length(p - center);
        float rNorm = d / radius;
        if (rNorm > 1.35) return 0.0;
        float rim = smoothstep(0.70, 0.95, rNorm) * (1.0 - smoothstep(0.95, 1.25, rNorm)) * 0.20;
        float bowl = (1.0 - smoothstep(0.0, 0.82, rNorm)) * -0.24;
        return rim + bowl;
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

        // ─── 1. HALO ATMOSFÉRICO EXTERIOR (Coherente con la luz de las lunas) ─
        if (r > 1.0) {
            float distNorm = (r - 1.0) / max(0.001, u_atmosphereThickness);
            float haloFade = exp(-distNorm * 3.6) * (1.0 - distNorm);
            
            // Dispersión alineada con light.xy
            float sunFacing = dot(p / r, light.xy);
            float dayFactor = clamp(sunFacing * 0.55 + 0.45, 0.04, 1.0);
            
            vec3 sunsetColor = vec3(1.0, 0.65, 0.22);
            float sunsetFactor = smoothstep(0.35, -0.25, abs(sunFacing));
            vec3 atmCol = mix(u_atmosphereColor, sunsetColor, sunsetFactor * 0.55);

            vec3 haloColor = atmCol * (haloFade * dayFactor * 2.2);
            float alpha = clamp(haloFade * dayFactor * 1.5, 0.0, 1.0);
            return vec4(haloColor * color.rgb, alpha * color.a);
        }

        // ─── 2. SUPERFICIE ROCOSA 3D ─────────────────────────────────────────
        float z = sqrt(max(0.0, 1.0 - r * r));
        vec3 normal = vec3(p.x, p.y, z);

        // Proyección esférica de textura UV
        float phi = atan(p.x, z) / 6.2831853;
        float theta = asin(clamp(p.y, -1.0, 1.0)) / 3.14159265 + 0.5;
        vec2 uv = vec2(phi, theta) + u_uvOffset;

        // Warp para placas continentales y costas fractales
        vec2 warp = vec2(fbm(uv * 3.5), fbm(uv * 3.5 + vec2(5.2, 1.3))) * 0.20;
        vec2 wuv = uv + warp;

        float elevation = fbm(wuv * 3.6);
        elevation += 0.28 * fbm(wuv * 8.5);
        elevation += 0.12 * fbm(wuv * 20.0);

        // Cráteres de impacto
        elevation += crater(wuv, vec2(0.24, 0.48), 0.08);
        elevation += crater(wuv, vec2(0.33, 0.43), 0.05);
        elevation += crater(wuv, vec2(0.18, 0.64), 0.065);
        elevation += crater(wuv, vec2(0.42, 0.36), 0.09);

        // Distribución de materiales:
        float basinMask = smoothstep(0.50, 0.36, elevation);
        float continentMask = smoothstep(0.50, 0.66, elevation);
        float peakMask = smoothstep(0.70, 0.86, elevation);

        vec3 surfaceCol = mix(u_landPlains, u_basinColor, basinMask);
        surfaceCol = mix(surfaceCol, u_landTerracotta, continentMask);
        surfaceCol = mix(surfaceCol, vec3(0.36, 0.15, 0.09), peakMask * 0.55);

        float saltCrust = smoothstep(0.34, 0.44, elevation) * basinMask;
        surfaceCol = mix(surfaceCol, vec3(0.85, 0.94, 0.90), saltCrust * 0.38);

        float rockNoise = fbm(wuv * 32.0);
        surfaceCol *= (0.88 + 0.24 * rockNoise);

        // ─── 3. CAPA DE NUBES BLANCAS Y VERDOSAS ──────────────────────────────
        vec2 cloudUv = uv + vec2(u_time * 0.003, 0.0);
        vec2 cloudWarp = vec2(fbm(cloudUv * 3.2), fbm(cloudUv * 3.2 + vec2(2.1, 7.8))) * 0.22;
        vec2 cUv = cloudUv + cloudWarp;

        float cloudNoise = fbm(cUv * 4.2) + 0.26 * fbm(cUv * 9.5);
        float cloudDensity = smoothstep(0.60, 0.82, cloudNoise);

        // Sombra de nubes
        vec2 cloudShadowOffset = -light.xy * 0.015;
        float cloudShadow = smoothstep(0.60, 0.82, fbm((cUv + cloudShadowOffset) * 4.2));
        surfaceCol *= (1.0 - cloudShadow * 0.28);

        // Tonalidad blanco-verdosa de las nubes
        float greenTint = smoothstep(0.42, 0.72, fbm(cUv * 2.8 + vec2(3.1, 4.2)));
        vec3 cloudColor = mix(u_cloudWhite, u_cloudGreen, greenTint * 0.65);
        surfaceCol = mix(surfaceCol, cloudColor, cloudDensity * 0.82);

        // ─── 4. ILUMINACIÓN SOLAR Y TERMINADOR (COHERENCIA CON LAS LUNAS) ─────
        float NdotL = dot(normal, light);
        float directSun = smoothstep(-0.14, 0.22, NdotL);

        vec3 nightAmbient = vec3(0.016, 0.018, 0.024);
        vec3 litColor = surfaceCol * mix(nightAmbient, vec3(1.0), directSun);

        // ─── 5. RELÁMPAGOS SUB-ATMOSFÉRICOS ESPONTÁNEOS (LÓGICA FÍSICA) ────────
        // - Solo ocurren esporádicamente dentro de densas capas de nubes.
        // - Solo son visibles en la noche cósmica o en el crepúsculo (no en pleno día).
        // - La luz se propaga de forma difusa y tenue bajo el manto nuboso y la atmósfera.
        vec3 lightningGlow = vec3(0.0);

        if (directSun < 0.45 && cloudDensity > 0.20) {
            // 3 centros de tormenta atmosférica profunda
            vec2 stormCenters[3];
            stormCenters[0] = vec2(0.22, 0.52); // Cerca del terminador
            stormCenters[1] = vec2(0.15, 0.70); // Cuadrante nocturno
            stormCenters[2] = vec2(0.35, 0.60); // Zona crepuscular inferior

            for (int i = 0; i < 3; i++) {
                vec2 sPos = stormCenters[i];
                float dist = length(uv - sPos);
                if (dist < 0.12) {
                    // Cadencia lenta y espontánea: la mayoría de los ciclos no disparan nada
                    float stormRate = 0.55 + float(i) * 0.15;
                    float cycle = floor(u_time * stormRate + float(i) * 11.3);
                    float phase = fract(u_time * stormRate + float(i) * 11.3);

                    // Probabilidad baja para que sean verdaderamente espontáneos (~22% de probabilidad)
                    float strikeProb = hash(vec2(cycle, float(i) * 43.7));
                    if (strikeProb > 0.78 && phase < 0.12) {
                        // Pulso rápido muy breve (~150ms) simulando relámpago intra-nube
                        float microFlash = sin(phase * 80.0) * exp(-phase * 35.0);
                        microFlash = clamp(microFlash, 0.0, 1.0);

                        // Difusión suave y tenue dentro de la nube (sin rayos láser)
                        float cloudDiffusion = exp(-dist * 45.0) * microFlash * cloudDensity;
                        
                        // Atenuación en el terminador
                        float darknessFactor = (1.0 - smoothstep(0.0, 0.45, directSun));
                        
                        // Tono eléctrico sutil filtrado por la masa nubosa (verde-azulado tenue)
                        vec3 colSubCloud = mix(vec3(0.55, 0.85, 0.90), vec3(0.30, 0.85, 0.55), greenTint);
                        
                        // Intensidad reducida drásticamente para que sea elegante y realista
                        lightningGlow += colSubCloud * (cloudDiffusion * 0.45 * darknessFactor);
                    }
                }
            }
        }

        litColor += lightningGlow;

        // ─── 6. BRUMA Y LIMBO ATMOSFÉRICO AMARILLO DORADO (SOBRE LA SUPERFICIE)
        // La atmósfera cubre la superficie y los relámpagos que ocurren debajo
        float fresnel = 1.0 - normal.z;
        float rimGlow = pow(fresnel, 3.4);
        
        float sunHaze = clamp(dot(normal.xy, light.xy) * 0.5 + 0.5, 0.12, 1.0);
        vec3 atmLimb = u_atmosphereColor * (rimGlow * sunHaze * 1.8);

        // Bruma amarilla cálida envolvente suave sobre todo el disco
        float globalHaze = pow(clamp(dot(normal, light) * 0.50 + 0.50, 0.0, 1.0), 1.2) * 0.22;
        vec3 hazeCol = u_atmosphereColor * globalHaze;

        litColor = mix(litColor, litColor * 0.88 + hazeCol, 0.32);
        litColor += atmLimb;

        return vec4(litColor * color.rgb, color.a);
    }
]]

function RockyPlanetShader.init()
    if RockyPlanetShader.initialized and RockyPlanetShader.shader then
        return true
    end

    local ok, s = pcall(love.graphics.newShader, shaderCode)
    if ok and s then
        RockyPlanetShader.shader = s
        RockyPlanetShader.initialized = true
        return true
    else
        print("[RockyPlanetShader] Error compiling shader: " .. tostring(s))
        return false
    end
end

function RockyPlanetShader.getShader()
    if not RockyPlanetShader.initialized then
        RockyPlanetShader.init()
    end
    return RockyPlanetShader.shader
end

return RockyPlanetShader
