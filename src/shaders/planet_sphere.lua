-- src/shaders/planet_sphere.lua
-- Shader GLSL de Pseudo-Esfera 2.5D con Terminador Solar, Atmósfera Rayleigh y UVs Dinámicas

local PlanetSphereShader = {
    shader = nil,
    initialized = false
}

local shaderCode = [[
    extern float u_time;
    extern float u_radius;
    extern vec2 u_center;
    extern vec3 u_lightDir;
    extern vec2 u_uvOffset;
    extern float u_atmosphereThickness;
    extern vec3 u_atmosphereColor;
    extern vec3 u_oceanColor;
    extern vec3 u_landColor;
    extern float u_specular;

    // Generador de ruido analítico pseudo-aleatorio
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
            p = p * 2.02 + vec2(1.7, 9.2);
            a *= 0.5;
        }
        return v;
    }

    vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
        // Coordenadas UV normalizadas respecto al quad del planeta y su atmósfera
        float maxR = 1.0 + u_atmosphereThickness;
        vec2 p = (texcoord - vec2(0.5)) * (2.0 * maxR);
        float r = length(p);

        // Descarte temprano fuera de la atmósfera
        if (r > maxR) {
            return vec4(0.0);
        }

        vec3 light = normalize(u_lightDir);
        vec3 view = vec3(0.0, 0.0, 1.0);

        // ─── 1. HALO ATMOSFÉRICO EXTERIOR (r > 1.0) ─────────────────────────
        if (r > 1.0) {
            float distNorm = (r - 1.0) / max(0.001, u_atmosphereThickness);
            float haloFade = exp(-distNorm * 3.8) * (1.0 - distNorm);
            
            // Dispersión mayor hacia el lado diurno del sol
            float sunFacing = dot(p / r, light.xy);
            float dayFactor = clamp(sunFacing * 0.55 + 0.45, 0.08, 1.0);
            
            // Tono crepuscular rojizo/dorado en el terminador atmosférico
            vec3 sunsetColor = vec3(1.0, 0.55, 0.25);
            float sunsetFactor = smoothstep(0.3, -0.2, abs(sunFacing));
            vec3 atmCol = mix(u_atmosphereColor, sunsetColor, sunsetFactor * 0.6);

            vec3 haloColor = atmCol * (haloFade * dayFactor * 2.2);
            float alpha = clamp(haloFade * dayFactor * 1.5, 0.0, 1.0);
            return vec4(haloColor, alpha);
        }

        // ─── 2. SUPERFICIE SÓLIDA DEL PLANETA (r <= 1.0) ────────────────────
        // Cálculo del vector normal esférico 3D en espacio de pantalla
        float z = sqrt(max(0.0, 1.0 - r * r));
        vec3 normal = vec3(p.x, p.y, z);

        // Proyección esférica de coordenadas UV (deforma la textura en 3D)
        float phi = atan(p.x, z) / 6.2831853;
        float theta = asin(clamp(p.y, -1.0, 1.0)) / 3.14159265 + 0.5;
        vec2 uv = vec2(phi, theta) + u_uvOffset;

        // Muestreo procedimental de continentes, océanos y cordilleras
        float elevation = fbm(uv * 5.2);
        elevation += 0.25 * fbm(uv * 14.0);

        // Paleta de superficie
        vec3 surfaceCol;
        bool isWater = (elevation < 0.50);
        
        if (isWater) {
            // Océanos profundos y costas turquesa
            float coast = smoothstep(0.42, 0.50, elevation);
            vec3 deepOcean = u_oceanColor;
            vec3 shallowCoast = vec3(0.12, 0.48, 0.65);
            surfaceCol = mix(deepOcean, shallowCoast, coast);
        } else {
            // Tierra firme y montañas
            float mountain = smoothstep(0.60, 0.78, elevation);
            vec3 lowLands = u_landColor;
            vec3 mountainColor = vec3(0.45, 0.42, 0.35);
            surfaceCol = mix(lowLands, mountainColor, mountain);
        }

        // Casquetes polares glaciares
        float polarDist = abs(p.y);
        float iceMask = smoothstep(0.72, 0.88, polarDist + 0.08 * fbm(uv * 8.0));
        vec3 iceColor = vec3(0.92, 0.96, 1.0);
        surfaceCol = mix(surfaceCol, iceColor, iceMask);

        // ─── 3. CAPA DE NUBES DINÁMICAS ─────────────────────────────────────
        vec2 cloudUv = uv + vec2(u_time * 0.006, 0.0);
        float cloudNoise = fbm(cloudUv * 6.5);
        cloudNoise += 0.2 * fbm(cloudUv * 16.0);
        float cloudDensity = smoothstep(0.48, 0.72, cloudNoise);

        // Sombra de nubes sobre la superficie
        vec2 cloudShadowOffset = -light.xy * 0.015;
        float cloudShadow = smoothstep(0.50, 0.75, fbm((cloudUv + cloudShadowOffset) * 6.5));
        surfaceCol *= (1.0 - cloudShadow * 0.4);

        // Combinación de nubes blancas sobre superficie
        vec3 cloudColor = vec3(0.96, 0.98, 1.0);
        surfaceCol = mix(surfaceCol, cloudColor, cloudDensity * 0.88);

        // ─── 4. ILUMINACIÓN Y TERMINADOR DÍA / NOCHE ─────────────────────────
        float NdotL = dot(normal, light);
        float dayNight = smoothstep(-0.12, 0.22, NdotL);
        
        // Brillo especular del sol sobre el agua
        float specularHighlight = 0.0;
        if (isWater && (cloudDensity < 0.25)) {
            vec3 reflectDir = reflect(-light, normal);
            float RdotV = max(0.0, dot(reflectDir, view));
            specularHighlight = pow(RdotV, 36.0) * u_specular * dayNight * (1.0 - iceMask);
        }

        // Luz ambiental nocturna (silueta visible del planeta en la noche cósmica)
        vec3 nightAmbient = vec3(0.015, 0.025, 0.05);
        vec3 litColor = surfaceCol * mix(nightAmbient, vec3(1.0), dayNight);
        litColor += vec3(1.0, 0.95, 0.85) * specularHighlight;

        // ─── 5. DISPERSIÓN ATMOSFÉRICA RAYLEIGH (LIMBO / FRESNEL) ───────────
        float fresnel = 1.0 - normal.z;
        float rimGlow = pow(fresnel, 3.4);
        
        // El resplandor es más brillante en la cara iluminada
        float rimSun = clamp(dot(normal.xy, light.xy) * 0.5 + 0.5, 0.15, 1.0);
        vec3 rimColor = u_atmosphereColor * (rimGlow * rimSun * 2.2);
        
        litColor += rimColor;

        // Suavizado del borde del disco planetario (antialiasing)
        float edgeAA = smoothstep(1.0, 0.992, r);

        return vec4(litColor, edgeAA * color.a);
    }
]]

function PlanetSphereShader.init()
    if PlanetSphereShader.initialized and PlanetSphereShader.shader then
        return true
    end

    local ok, s = pcall(love.graphics.newShader, shaderCode)
    if ok and s then
        PlanetSphereShader.shader = s
        PlanetSphereShader.initialized = true
        return true
    else
        print("[PlanetSphereShader] Error compiling shader: " .. tostring(s))
        return false
    end
end

function PlanetSphereShader.getShader()
    if not PlanetSphereShader.initialized then
        PlanetSphereShader.init()
    end
    return PlanetSphereShader.shader
end

return PlanetSphereShader
