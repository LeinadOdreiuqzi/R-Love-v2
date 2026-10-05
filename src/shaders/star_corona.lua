-- src/shaders/star_corona.lua
-- Shader GLSL de Corona Solar Activa, Plasma Convectivo y Filamentos de Radiación

local StarCoronaShader = {
    shader = nil,
    initialized = false
}

local shaderCode = [[
    extern float u_time;
    extern vec3 u_surfaceColor;
    extern vec3 u_coronaColor;
    extern vec3 u_deepCoronaColor;
    extern float u_flareIntensity;

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
        for (int i = 0; i < 4; i++) {
            v += a * noise(p);
            p = p * 2.1 + vec2(2.1, 4.3);
            a *= 0.5;
        }
        return v;
    }

    vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
        // Mapeo UV con quad de extensión 2.6x el radio estelar
        float maxR = 2.6;
        vec2 p = (texcoord - vec2(0.5)) * (2.0 * maxR);
        float r = length(p);

        if (r > maxR) {
            return vec4(0.0);
        }

        float t = u_time * 0.4;
        float angle = atan(p.y, p.x);

        // ─── 1. FOTOSFERA Y CÉLULAS DE CONVECCIÓN (r <= 1.0) ────────────────
        vec2 warp = vec2(
            fbm(p * 4.2 + vec2(t * 0.3, t * 0.15)),
            fbm(p * 4.2 - vec2(t * 0.2, t * 0.25))
        );
        float granules = fbm(p * 9.5 + warp * 1.8);
        granules += 0.25 * fbm(p * 22.0 - warp * 0.8);

        float coreBrightness = 1.0 - smoothstep(0.0, 0.92, r);
        vec3 coreWhite = vec3(1.0, 0.98, 0.92) * 1.5;
        vec3 surfaceBase = mix(u_coronaColor, u_surfaceColor, granules);
        vec3 finalSurface = mix(surfaceBase, coreWhite, coreBrightness * 0.88);
        float limb = pow(clamp(r, 0.0, 1.0), 3.0);
        finalSurface += u_coronaColor * (limb * 0.8);

        // ─── 2. CORONA EXTERIOR Y FILAMENTOS (r > 0.95) ─────────────────────
        if (r > 0.95) {
            float dist = max(0.0, r - 0.95);
            
            // Rayos y serpentinas coronales moduladas por el ángulo
            vec2 polar = vec2(angle * 3.8197, dist * 2.5 - t * 0.8);
            float streamers = fbm(polar * 2.2);
            streamers += 0.3 * fbm(polar * 6.0 + t);

            // Caída exponencial de radiación con la distancia
            float decay = exp(-dist * 2.5) * smoothstep(maxR, maxR * 0.60, r);
            float coronaGlow = decay * (0.75 + 0.65 * streamers * u_flareIntensity);

            // Ondas de calor secundarias
            float heatWave = sin(r * 18.0 - t * 4.0 + angle * 4.0) * 0.5 + 0.5;
            coronaGlow += heatWave * decay * 0.22;

            // Spikes anamórficos de difracción estelar suaves y fotográficos
            float spikeX = exp(-abs(p.y) * 40.0) * exp(-abs(p.x) * 0.85) * 1.5;
            float spikeY = exp(-abs(p.x) * 40.0) * exp(-abs(p.y) * 0.85) * 1.5;
            coronaGlow += (spikeX + spikeY) * smoothstep(maxR, maxR * 0.68, r) * 1.3;

            // Degradado de color coronal: de dorado radiante a carmesí profundo
            vec3 cColor = mix(u_coronaColor, u_deepCoronaColor, clamp(dist * 0.75, 0.0, 1.0));
            cColor += vec3(1.0, 0.95, 0.82) * (spikeX + spikeY) * 0.85;
            cColor *= coronaGlow * 2.5;

            // Mezcla suave entre la superficie y la corona en la transición r in [0.95, 1.02]
            float blendFactor = smoothstep(0.95, 1.02, r);
            vec3 blendedRgb = mix(finalSurface, cColor, blendFactor);
            float blendedAlpha = mix(1.0, clamp(coronaGlow * 1.7, 0.0, 1.0), blendFactor);
            return vec4(blendedRgb, blendedAlpha * color.a);
        }

        return vec4(finalSurface, color.a);
    }
]]

function StarCoronaShader.init()
    if StarCoronaShader.initialized and StarCoronaShader.shader then
        return true
    end

    local ok, s = pcall(love.graphics.newShader, shaderCode)
    if ok and s then
        StarCoronaShader.shader = s
        StarCoronaShader.initialized = true
        return true
    else
        print("[StarCoronaShader] Error compiling shader: " .. tostring(s))
        return false
    end
end

function StarCoronaShader.getShader()
    if not StarCoronaShader.initialized then
        StarCoronaShader.init()
    end
    return StarCoronaShader.shader
end

return StarCoronaShader
