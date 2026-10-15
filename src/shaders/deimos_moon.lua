-- src/shaders/deimos_moon.lua
-- Shader GLSL de la luna asteroide Deimos para la nave Marathon (Perspectiva Top-Down)
-- Morfología 1:1 con el modelo 3D de referencia y lore industrial de Marathon:
-- - Caparazón dorsal convexo facetado con cráter geológico y crestas de basalto
-- - Espolón rocoso inferior izquierdo robusto, geológico y angulado por cortes de cantera
-- - Interior con desgaste minero de alta gama: terrazas escalonadas de cantera (benches),
--   vetas de mineral de hierro/níquel expuestas por voladuras y estrías de corte industrial
-- - Renderizado en 2 pasadas: u_pass 1.0 (muro interior de cantera) y u_pass 2.0 (caparazón exterior)
-- - Normales facetadas con ruido Voronoi planar que replican fielmente la malla 3D poligonal

local DeimosMoonShader = {
    shader = nil,
    initialized = false
}

local shaderCode = [[
    extern vec3 u_lightDir;     // Vector solar (arriba-derecha)
    extern vec3 u_bounceColor;  // Planet-shine
    extern vec3 u_sunColor;     // Luz solar
    extern vec3 u_rockLight;    // Iluminación facetada clara exterior
    extern vec3 u_rockMid;      // Basalto medio
    extern vec3 u_rockDark;     // Sombra exterior
    extern float u_seed;
    extern float u_pass;        // 1.0 = Fondo interior cavernoso (detrás de la nave); 2.0 = Caparazón exterior

    vec2 hash22(vec2 p) {
        p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
        return fract(sin(p + u_seed) * 43758.5453);
    }

    float hash21(vec2 p) {
        return fract(sin(dot(p, vec2(127.1 + u_seed, 311.7 - u_seed))) * 43758.5453123);
    }

    float noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash21(i + vec2(0.0, 0.0)), hash21(i + vec2(1.0, 0.0)), u.x),
                   mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
    }

    float fbm(vec2 p) {
        float v = 0.0;
        float a = 0.5;
        for (int i = 0; i < 4; i++) {
            v += a * noise(p);
            p = p * 2.08 + vec2(3.1, 7.4);
            a *= 0.5;
        }
        return v;
    }

    // Voronoi celular para crear facetas poligonales planas (look 3D low-poly)
    vec3 voronoi(vec2 p) {
        vec2 n = floor(p);
        vec2 f = fract(p);
        vec2 mg, mr;
        float md = 8.0;
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec2 g = vec2(float(i), float(j));
                vec2 o = hash22(n + g);
                vec2 r = g + o - f;
                float d = dot(r, r);
                if (d < md) {
                    md = d;
                    mr = r;
                    mg = g;
                }
            }
        }
        return vec3(sqrt(md), n + mg);
    }

    float sdTaperedSegment(vec2 p, vec2 a, vec2 b, float r1, float r2) {
        vec2 pa = p - a, ba = b - a;
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        float r = mix(r1, r2, h);
        return length(pa - ba * h) - r;
    }

    // Evaluación morfológica top-down de Deimos:
    vec4 evaluateDeimosTopDown(vec2 p) {
        // Coordenadas normalizadas [-1.15, 1.15]
        
        // 1. DOMO DORSAL SUPERIOR (y < 0)
        vec2 pDome = vec2((p.x + 0.02) / 0.88, (p.y + 0.16) / 0.72);
        float rDome = length(pDome);
        float nDome = (fbm(p * 3.2 + vec2(1.5, 4.2)) - 0.5) * 0.12;
        float domeDist = rDome - (0.92 + nDome);

        // Cráter Swift en la cresta superior
        vec2 pCrater = vec2((p.x - 0.20) / 0.18, (p.y + 0.38) / 0.14);
        float rCrater = length(pCrater);
        if (rCrater < 1.0) {
            domeDist += (1.0 - rCrater * rCrater) * 0.08;
        }

        // 2. ESPOLÓN ROCOSO INFERIOR IZQUIERDO (ROBUSTO Y FRACTURADO POR MINERÍA)
        // Estructura firme de roca basáltica con quiebres angulares de corte de cantera:
        float dSpur1 = sdTaperedSegment(p, vec2(-0.70, 0.00), vec2(-0.76, 0.30), 0.22, 0.21);
        float dSpur2 = sdTaperedSegment(p, vec2(-0.76, 0.30), vec2(-0.64, 0.52), 0.21, 0.18);
        float dSpur3 = sdTaperedSegment(p, vec2(-0.64, 0.52), vec2(-0.46, 0.48), 0.18, 0.14);
        float spurDist = min(min(dSpur1, dSpur2), dSpur3);

        // 3. MASA ROCOSA DERECHA / PISO VENTRAL DERECHO (Pared de extracción este)
        float dRight1 = sdTaperedSegment(p, vec2(0.36, -0.40), vec2(0.55, 0.00), 0.18, 0.22);
        float dRight2 = sdTaperedSegment(p, vec2(0.55, 0.00), vec2(0.44, 0.54), 0.22, 0.20);
        float dRight3 = sdTaperedSegment(p, vec2(0.44, 0.54), vec2(0.20, 0.62), 0.20, 0.16);
        float rightDist = min(dRight1, min(dRight2, dRight3));

        // 4. CUELLO SUPERIOR DE LA POPA
        float neckDist = sdTaperedSegment(p, vec2(-0.76, -0.22), vec2(-0.70, 0.00), 0.18, 0.20);

        // Distancia a roca combinada exterior
        float rockDist = min(domeDist, min(spurDist, min(rightDist, neckDist)));

        // Micro-facetado angular en el contorno exterior
        vec3 vEdge = voronoi(p * 5.2);
        rockDist += (vEdge.x - 0.5) * 0.035;

        // 5. CAVIDAD VENTRAL MINERA (CÁMARA DE EXTRACCIÓN INDUSTRIAL)
        vec2 pCav = vec2((p.x + 0.02) / 0.44, (p.y - 0.24) / 0.36);
        float rCav = length(pCav);
        float nCav = (fbm(p * 4.0 + vec2(3.1, 7.8)) - 0.5) * 0.10;
        bool isCavity = (rCav < (0.95 + nCav)) && (p.y > -0.06);

        // Nicho de extracción entre el espolón y la quilla
        vec2 pMineNiche = vec2((p.x + 0.48) / 0.18, (p.y - 0.25) / 0.18);
        if (length(pMineNiche) < 0.90 && p.y > 0.02) {
            isCavity = true;
        }

        if (rockDist > 0.0) isCavity = false;

        return vec4(rockDist, isCavity ? 1.0 : 0.0, rDome, rCav);
    }

    vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
        vec2 p = (texcoord - vec2(0.5)) * 2.30;

        vec4 info = evaluateDeimosTopDown(p);
        float rockDist = info.x;
        bool isCavity  = (info.y > 0.5);
        float rDome    = info.z;
        float rCav     = info.w;

        // Fuera de la luna
        if (rockDist > 0.0) return vec4(0.0);
        float edgeAlpha = smoothstep(0.0, -0.015, rockDist);

        // CONTROL POR PASADA:
        // PASADA 1 (u_pass == 1.0): Fondo interior cavernoso (detrás de la nave).
        if (u_pass > 0.5 && u_pass < 1.5) {
            if (!isCavity) return vec4(0.0);
        }

        // PASADA 2 (u_pass == 2.0): Caparazón exterior en primer plano (delante de la nave).
        if (u_pass > 1.5) {
            if (isCavity) return vec4(0.0);
        }

        vec3 L = normalize(u_lightDir);

        // ====================================================================
        // CASO A: INTERIOR EXCAVADO POR MINERÍA CONTINUA (LORE DE DEIMOS)
        // ====================================================================
        if (isCavity) {
            // Geometría interior escalonada de cantera minera (benches con fracturas orgánicas):
            float benchNoise = (fbm(p * 5.5 + vec2(2.1, 7.3)) - 0.5) * 0.40;
            float benchCoord = (p.y * 7.5 + p.x * 1.6) + benchNoise;
            float benchEdge = fract(benchCoord);
            float benchStep = smoothstep(0.05, 0.25, benchEdge) * (1.0 - smoothstep(0.70, 0.95, benchEdge));

            // Concavidad de fondo con escalones de extracción
            float zCav = sqrt(max(0.0, 1.0 - clamp(rCav * 0.82, 0.0, 0.98))) * 0.92;
            vec3 N_cav = normalize(vec3(-p.x * 0.40, -p.y * 0.30 + (benchStep - 0.5) * 0.28, zCav));

            // Facetado Voronoi de roca fracturada por voladuras industriales
            vec3 vCavFace = voronoi(p * 6.5 + vec2(1.7, 3.2));
            vec2 cellIdCav = vCavFace.yz;
            vec2 facetTiltCav = (hash22(cellIdCav) - vec2(0.5)) * 0.42;
            N_cav.xy += facetTiltCav;

            // Estrías sutiles de corte de sierra por plasma / perforación
            float drillStriations = sin(p.x * 36.0 + fbm(p * 6.0) * 1.8);
            N_cav.x += drillStriations * 0.08;

            float creaseCav = smoothstep(0.02, 0.08, vCavFace.x);
            N_cav.xy += (hash22(cellIdCav * 1.5) - vec2(0.5)) * (1.0 - creaseCav) * 0.18;
            N_cav = normalize(N_cav);

            // Iluminación solar angular en las terrazas de la cantera
            float nDotL_cav = dot(N_cav, L);
            float directLight_cav = clamp(nDotL_cav * 1.10 + 0.20, 0.0, 1.0);

            // Sombra del techo y voladizos sobre las gradas inferiores
            float roofShadow = smoothstep(-0.06, 0.28, p.y);
            float rimShadowDist = smoothstep(0.0, -0.10, rockDist);
            float caveAmbient = mix(0.42, 0.88, roofShadow) * rimShadowDist;

            // PALETA MINERA: Basalto de cantera con vetas de mineral expuesto
            vec3 colBasaltShadow = vec3(0.18, 0.19, 0.24); // Sombra profunda de cantera
            vec3 colBasaltMid    = vec3(0.30, 0.32, 0.38); // Basalto medio cortado
            vec3 colBasaltLit    = vec3(0.46, 0.48, 0.54) * u_sunColor; // Rocas expuestas al sol

            // Vetas minerales (hierro oxidado y silicatos) expuestas por el tajo minero
            float oreVein = smoothstep(0.42, 0.58, fbm(p * 7.5 + vec2(3.4, 6.2))) *
                            (1.0 - smoothstep(0.62, 0.78, fbm(p * 7.5 + vec2(3.4, 6.2))));
            vec3 colOre = vec3(0.36, 0.26, 0.20); // Veta de hierro oxidado

            vec3 cavCol = mix(colBasaltShadow, colBasaltMid, directLight_cav * 1.4);
            if (directLight_cav > 0.40) {
                cavCol = mix(colBasaltMid, colBasaltLit, (directLight_cav - 0.40) * 1.8);
            }

            // Integrar las vetas minerales en las caras de roca
            cavCol = mix(cavCol, colOre * (directLight_cav * 0.8 + 0.45), oreVein * 0.30);

            // Resalte de las aristas cortadas por maquinaria (gradas mineras)
            float shelfHighlight = smoothstep(0.75, 0.95, benchEdge) * clamp(L.y * -0.8 + 0.5, 0.0, 1.0);
            cavCol += vec3(0.12, 0.13, 0.15) * shelfHighlight;

            cavCol *= caveAmbient;
            cavCol *= (0.80 + 0.20 * creaseCav);

            // Planet-shine en las paredes internas
            float bounceDot_cav = clamp(dot(N_cav, normalize(vec3(-0.65, 0.50, 0.25))), 0.0, 1.0);
            cavCol += u_bounceColor * (bounceDot_cav * 0.32);

            return vec4(cavCol * color.rgb, edgeAlpha * color.a);
        }

        // ====================================================================
        // CASO B: CAPARAZÓN EXTERIOR EN PRIMER PLANO (FRACTURAS Y BASALTO)
        // ====================================================================
        float zNorm = sqrt(max(0.0, -rockDist * 2.2));
        vec3 N = normalize(vec3(p.x * 1.05, p.y * 0.90, zNorm * 1.10));

        // Facetado Voronoi planar robusto
        vec3 vFace = voronoi(p * 5.8);
        vec2 cellId = vFace.yz;
        vec2 facetTilt = (hash22(cellId) - vec2(0.5)) * 0.45;
        N.xy += facetTilt;

        float edgeCrease = smoothstep(0.02, 0.07, vFace.x);
        N.xy += (hash22(cellId * 1.7) - vec2(0.5)) * (1.0 - edgeCrease) * 0.18;
        N = normalize(N);

        float nDotL = dot(N, L);
        float directLight = clamp(nDotL * 1.18 + 0.06, 0.0, 1.0);
        float shadowMask = smoothstep(-0.05, 0.25, nDotL);

        // Resplandor de cresta solar en facetas
        float rimGlint = 0.0;
        if (p.y < 0.10) {
            rimGlint = pow(clamp(dot(N, L), 0.0, 1.0), 3.5) * smoothstep(0.55, 0.92, rDome);
        }

        vec3 colDark  = u_rockDark;
        vec3 colMid   = u_rockMid;
        vec3 colLight = u_rockLight * u_sunColor;

        vec3 rockCol = mix(colDark, colMid, directLight * 1.6);
        if (directLight > 0.45) {
            rockCol = mix(colMid, colLight, (directLight - 0.45) * 2.2);
        }

        rockCol *= (0.78 + 0.22 * edgeCrease);

        float bounceDot = clamp(dot(N, normalize(vec3(-0.65, 0.50, 0.25))), 0.0, 1.0);
        rockCol += u_bounceColor * (bounceDot * 0.30 * (1.0 - shadowMask));
        rockCol += u_sunColor * rimGlint * 0.22;

        return vec4(rockCol * color.rgb, edgeAlpha * color.a);
    }
]]

function DeimosMoonShader.init()
    if DeimosMoonShader.initialized and DeimosMoonShader.shader then
        return true
    end

    local ok, s = pcall(love.graphics.newShader, shaderCode)
    if ok and s then
        DeimosMoonShader.shader = s
        DeimosMoonShader.initialized = true
        return true
    else
        print("[DeimosMoonShader] Error compiling shader: " .. tostring(s))
        return false
    end
end

function DeimosMoonShader.getShader()
    if not DeimosMoonShader.initialized then
        DeimosMoonShader.init()
    end
    return DeimosMoonShader.shader
end

return DeimosMoonShader
