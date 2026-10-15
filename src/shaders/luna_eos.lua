-- src/shaders/luna_eos.lua
-- Shader GLSL de Luna Eos (Luna Magenta / Rosa de Tau Ceti Tier 3)
-- Combinación armonizada:
-- - Atmósfera volumétrica y halo sedoso envolvente de luna_eos_preview.png (resplandor solar suave y crepúsculo violeta)
-- - Interior con velo atmosférico sutil (surfaceHaze), nubes orgánicas translúcidas y sombras proyectadas
-- - Geología equilibrada: Mares abisales ciruela profunda con costas de amatista (sin bordes cian) y continentes rosa cuarzo con relieve granate/cristal (sin tonos de moho/lodo)

local LunaEosShader = {
    shader = nil,
    initialized = false
}

local shaderCode = [[
    extern float u_time;
    extern vec3 u_lightDir;
    extern vec2 u_uvOffset;
    extern float u_atmosphereThickness;
    extern vec3 u_atmosphereColor; // Rosa / magenta orquídea
    extern vec3 u_landColor;       // Continentes rosa cuarzo / carmesí
    extern vec3 u_oceanColor;      // Mares ciruela profunda / amatista

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
        for (int i = 0; i < 6; i++) {
            v += a * noise(p);
            p = p * 2.02 + vec2(1.7, 9.2);
            a *= 0.5;
        }
        return v;
    }

    // Elevación geológica procedural continua
    float getElevation(vec2 uv) {
        vec2 warp = vec2(fbm(uv * 3.6), fbm(uv * 3.6 + vec2(4.2, 7.8))) * 0.17;
        vec2 wuv = uv + warp;
        float e = fbm(wuv * 4.4);
        e += 0.28 * fbm(wuv * 11.0);
        e += 0.12 * fbm(wuv * 24.0);
        return e;
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

        // ─── 1. HALO Y EXÓSFERA EXTERIOR (De luna_eos_preview.png) ───────────
        if (r > 1.0) {
            float distNorm = (r - 1.0) / max(0.001, u_atmosphereThickness);
            
            // Dispersión suave y gradual envolvente
            float haloFade = exp(-distNorm * 3.4) * (1.0 - distNorm);
            
            // Dispersión preferencial hacia el sol
            float sunFacing = dot(p / r, light.xy);
            float forwardScatter = clamp(sunFacing * 0.58 + 0.42, 0.0, 1.0);
            
            // Lado diurno = blanco nacarado / champán rosado; Lado nocturno = violeta profundo
            vec3 sunGlow = vec3(1.00, 0.92, 0.97);
            vec3 twilightCol = vec3(0.48, 0.14, 0.40);
            
            vec3 atmCol = mix(twilightCol, u_atmosphereColor, forwardScatter);
            atmCol = mix(atmCol, sunGlow, pow(max(0.0, sunFacing), 2.5) * 0.70);

            float intensity = haloFade * (0.15 + 2.05 * pow(forwardScatter, 1.4));
            float alpha = clamp(haloFade * (0.20 + 1.40 * forwardScatter), 0.0, 1.0);

            return vec4(atmCol * intensity * color.rgb, alpha * color.a);
        }

        // ─── 2. SUPERFICIE ESFÉRICA 3D ───────────────────────────────────────
        float z = sqrt(max(0.0, 1.0 - r * r));
        vec3 normal = vec3(p.x, p.y, z);

        // Proyección esférica de coordenadas UV
        float phi = atan(p.x, z) / 6.2831853;
        float theta = asin(clamp(p.y, -0.999, 0.999)) / 3.14159265 + 0.5;
        vec2 uv = vec2(phi, theta) + u_uvOffset;

        float elevation = getElevation(uv);

        // ─── PALETA GEOLÓGICA COMBINADA (Rica textura interior de preview.png) 
        vec3 surfaceCol;
        bool isWater = (elevation < 0.49);

        if (isWater) {
            // Cuencas abisales ciruela profunda con costas de amatista
            float coast = smoothstep(0.40, 0.49, elevation);
            vec3 deepOcean = u_oceanColor;
            vec3 shallowCoast = mix(u_oceanColor, vec3(0.64, 0.20, 0.48), 0.65);
            surfaceCol = mix(deepOcean, shallowCoast, coast);
        } else {
            // Continentes rosa cuarzo con cordilleras granate y crestas de cristal
            float highland = smoothstep(0.50, 0.68, elevation);
            float peak = smoothstep(0.68, 0.88, elevation);
            
            vec3 lowLands = u_landColor;
            vec3 garnetMountain = mix(u_landColor, vec3(0.36, 0.10, 0.24), 0.62);
            vec3 quartzPeak = vec3(0.96, 0.76, 0.88);
            
            surfaceCol = mix(lowLands, garnetMountain, highland * 0.70);
            surfaceCol = mix(surfaceCol, quartzPeak, peak * 0.45);
        }

        // Micro-grano mineral sutil para eliminar sensación de vector plano
        float mineralGrain = fbm(uv * 36.0);
        surfaceCol *= (0.93 + 0.14 * mineralGrain);

        // ─── 3. CAPA DE NUBES Y VELO SEDOSO (De luna_eos_preview.png) ────────
        vec2 cloudUv = uv + vec2(u_time * 0.004, 0.0);
        vec2 cloudWarp = vec2(fbm(cloudUv * 3.5), fbm(cloudUv * 3.5 + vec2(1.5, 6.2))) * 0.20;
        vec2 cUv = cloudUv + cloudWarp;

        float cloudNoise = fbm(cUv * 4.6) + 0.24 * fbm(cUv * 10.8);
        float cloudDensity = smoothstep(0.52, 0.78, cloudNoise);

        // Sombra suave de nubes sobre el terreno
        vec2 cloudShadowOffset = -light.xy * 0.015;
        float cloudShadow = smoothstep(0.52, 0.78, fbm((cUv + cloudShadowOffset) * 4.6));
        surfaceCol *= (1.0 - cloudShadow * 0.30);

        // Tonalidad de nubes: blanco sedoso con suave velo rosa cuarzo
        vec3 cloudCol = mix(vec3(0.97, 0.95, 0.98), vec3(1.00, 0.88, 0.94), fbm(cUv * 2.5));
        surfaceCol = mix(surfaceCol, cloudCol, cloudDensity * 0.75);

        // ─── 4. ILUMINACIÓN SOLAR Y TERMINADOR ────────────────────────────────
        float NdotL = dot(normal, light);
        float dayNight = smoothstep(-0.14, 0.22, NdotL);

        // Especular sutil en los mares
        float specularHighlight = 0.0;
        if (isWater && (cloudDensity < 0.22)) {
            vec3 reflectDir = reflect(-light, normal);
            float RdotV = max(0.0, dot(reflectDir, view));
            specularHighlight = pow(RdotV, 38.0) * dayNight;
        }

        // Luz ambiental cósmica profunda (violeta nocturno)
        vec3 nightAmbient = vec3(0.024, 0.014, 0.030);
        vec3 litColor = surfaceCol * mix(nightAmbient, vec3(1.0), dayNight);
        litColor += vec3(1.00, 0.90, 0.98) * (specularHighlight * 0.42);

        // ─── 5. PERSPECTIVA AÉREA Y RESPLANDOR RAYLEIGH/MIE (De preview.png) ──
        float fresnel = 1.0 - normal.z;
        float limbScattering = pow(fresnel, 3.2);

        float sunAngle = clamp(dot(normal.xy, light.xy) * 0.52 + 0.48, 0.0, 1.0);
        
        vec3 dayLimb = mix(u_atmosphereColor, vec3(1.00, 0.90, 0.96), 0.58);
        vec3 nightLimb = vec3(0.38, 0.12, 0.32);
        vec3 rimCol = mix(nightLimb, dayLimb, pow(sunAngle, 1.2));

        vec3 atmosphericLimb = rimCol * (limbScattering * (0.35 + 1.65 * sunAngle));

        // Velo atmosférico difuso sobre la cara del planeta (el look sedoso de preview.png)
        float surfaceHaze = pow(clamp(dot(normal, light) * 0.5 + 0.5, 0.0, 1.0), 1.4) * 0.20;
        vec3 innerHaze = u_atmosphereColor * surfaceHaze;

        litColor = mix(litColor, litColor * 0.86 + innerHaze, 0.28);
        litColor += atmosphericLimb;

        return vec4(litColor * color.rgb, color.a);
    }
]]

function LunaEosShader.init()
    if LunaEosShader.initialized and LunaEosShader.shader then
        return true
    end

    local ok, s = pcall(love.graphics.newShader, shaderCode)
    if ok and s then
        LunaEosShader.shader = s
        LunaEosShader.initialized = true
        return true
    else
        print("[LunaEosShader] Error compiling shader: " .. tostring(s))
        return false
    end
end

function LunaEosShader.getShader()
    if not LunaEosShader.initialized then
        LunaEosShader.init()
    end
    return LunaEosShader.shader
end

return LunaEosShader
