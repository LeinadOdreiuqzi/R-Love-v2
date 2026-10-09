// src/shaders/ring_station_bg.glsl
// Shader dedicado para el exterior de la Estación Espacial de Anillo (Ring Station / Stanford Torus).
// Ambientado en el espacio profundo (sin planetas ni cuerpos extraños):
// - Vacío cósmico puro con campo estelar multicapa de alta definición y tenue polvo galáctico.
// - La colosal superestructura del arco opuesto del toroide (tubo presurizado 3D de titanio,
//   anillo secundario de tránsito, costillas maestras, aletas radiadoras térmicas, blindaje flotante,
//   paneles solares de silicio, cubiertas de ciudades iluminadas y bahías de atraque activas).
// - El Eje Central de Gravedad Cero (Spindle Hub): cilindro axial vertical alineado con el eje
//   de rotación normal al plano del anillo, tambores centrifugadores elípticos en perspectiva 3D,
//   astillero microgravitatorio con celosías y contenedores, bahía axial de atraque con luces de aproximación y mástil
//   sensor.
// - Puentes radiales de celosía (Elevator Spokes) rotatorios en perspectiva 3D verdadera,
//   conectando físicamente el Eje Central con el Arco Opuesto y los cuadrantes del toroide,
//   con vainas de transporte magnético de alta velocidad (Transit Pods).
// - Tráfico orbital de lanzaderas y chispas de soldadura EVA en el casco lejano.

extern float u_time;
extern vec2 u_camera;     // Coordenadas globales de la cámara en el mundo de la estación (px)
extern vec2 u_resolution; // Dimensiones del viewport
extern float u_spin;      // Ángulo de rotación centrífuga de la estación (rad)
extern vec3 u_accent;     // Color de acento de la estación

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#else
#define highp
#define mediump
#define lowp
#endif

// Generadores de números pseudo-aleatorios deterministas
float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash11(float p)
{
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

// Distancia euclídea aproximada a un segmento de línea 2D
float distToSegment(vec2 p, vec2 a, vec2 b, out float projT)
{
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    projT = h;
    return length(pa - ba * h);
}

vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords)
{
    vec2 uv = screen_coords / u_resolution;

    // =========================================================================
    // 1. VACÍO CÓSMICO PROFUNDO (Deep Space Void)
    // =========================================================================
    vec3 col = vec3(0.005, 0.007, 0.012);

    // Tenue banda de polvo galáctico en el infinito (Milky Way dust lane)
    float mwBand = exp(-pow((uv.y - 0.45 - (uv.x - 0.5) * 0.18) * 4.2, 2.0));
    col += vec3(0.012, 0.018, 0.030) * mwBand * 0.70;

    // =========================================================================
    // 2. CAMPO ESTELAR MULTICAPA DE ALTA DEFINICIÓN (Distant Starfield)
    // =========================================================================
    // Capa A: Polvo estelar ultra-lejano (micro-estrellas densas, parallax 0.006)
    vec2 stDeepPos = screen_coords + u_camera * 0.006;
    vec2 stDeepCell = floor(stDeepPos / 14.0);
    float stDeepR = hash12(stDeepCell);
    if (stDeepR > 0.88)
    {
        vec2 stLocal = fract(stDeepPos / 14.0) - 0.5;
        float d = length(stLocal);
        col += vec3(0.42, 0.58, 0.80) * smoothstep(0.18, 0.0, d) * 0.35;
    }

    // Capa B: Campo estelar medio con temperaturas espectrales (parallax 0.015)
    vec2 stMidPos = screen_coords + u_camera * 0.015;
    vec2 stMidCell = floor(stMidPos / 22.0);
    float stMidR = hash12(stMidCell);
    if (stMidR > 0.82)
    {
        vec2 stLocal = fract(stMidPos / 22.0) - 0.5;
        float d = length(stLocal);
        float tw = 0.70 + 0.30 * sin(u_time * 2.2 + stMidR * 30.0);
        vec3 stColor = vec3(0.85, 0.92, 1.0); // Blanco azulado estándar
        if (stMidR > 0.96)
            stColor = vec3(1.0, 0.76, 0.42); // Gigante naranja/ámbar
        else if (stMidR > 0.91)
            stColor = vec3(0.68, 0.88, 1.0); // Tipo B azul brillante
        else if (stMidR > 0.86)
            stColor = vec3(1.0, 0.96, 0.82); // Tipo G amarillo solar
        col += stColor * smoothstep(0.14, 0.0, d) * tw * 0.85;
    }

    // Capa C: Estrellas brillantes con destello de difracción en cruz (parallax 0.024)
    vec2 stBriPos = screen_coords + u_camera * 0.024;
    vec2 stBriCell = floor(stBriPos / 68.0);
    float stBriR = hash12(stBriCell);
    if (stBriR > 0.94)
    {
        vec2 stLocal = fract(stBriPos / 68.0) - 0.5;
        vec2 pxDiff = stLocal * 68.0;
        float d = length(pxDiff);
        float tw = 0.80 + 0.20 * sin(u_time * 3.5 + stBriR * 15.0);

        col += vec3(0.92, 0.97, 1.0) * smoothstep(2.5, 0.0, d) * tw * 1.30;
        float spikeH = smoothstep(1.0, 0.0, abs(pxDiff.y)) * smoothstep(14.0, 0.0, abs(pxDiff.x));
        float spikeV = smoothstep(1.0, 0.0, abs(pxDiff.x)) * smoothstep(14.0, 0.0, abs(pxDiff.y));
        col += vec3(0.60, 0.85, 1.0) * (spikeH + spikeV) * tw * 0.45;
    }

    // =========================================================================
    // 3. SISTEMA GEOMÉTRICO UNIFICADO DEL TOROIDE (Unified Torus Frame)
    // El Eje Central, los Puentes Radiales y el Arco Opuesto comparten
    // el mismo centro de curvatura y perspectiva 3D elíptica.
    // =========================================================================
    vec2 hubScreenCenter = vec2(u_resolution.x * 0.50, u_resolution.y * 0.58);
    00 vec2 torusCenter = hubScreenCenter - (u_camera - vec2(2400.0, 272.0)) * vec2(0.038, 0.020);

    float Rx = max(u_resolution.x * 0.75 + abs(torusCenter.x - u_resolution.x * 0.50) * 1.2, 440.0);
    float Ry = max(u_resolution.y * 0.52 + abs(torusCenter.y - u_resolution.y * 0.58) * 0.8, 220.0);
    float tiltRatio = Ry / Rx;

    vec2 pTorus = screen_coords - torusCenter;

    float normX = pTorus.x / Rx;
    float normY = pTorus.y / Ry;
    float rEll = sqrt(normX * normX + normY * normY);

    float gradLen = sqrt(pow(normX / Rx, 2.0) + pow(normY / Ry, 2.0));
    float distToTorus = (rEll - 1.0) / max(gradLen, 0.0001); // distancia en px a la elipse central

    float arcAngle = atan(normX, -normY);

    // =========================================================================
    // 4. EJE CENTRAL DE GRAVEDAD CERO (DISEÑO CANÓNICO DE LA ESTACIÓN)
    // 100% idéntico a la vista exterior del sobre-mundo (station_ring_renderer.lua):
    // - Tambor cilíndrico volumétrico con extrusión vertical hacia abajo.
    // - Cúpula superior elíptica con bisel de titanio, anillo intermedio, iris
    //   polar de 8 sectores y túnel axial con anillo cian resplandeciente.
    // - Puente horizontal principal en celosía con patrón 'X' (Main Gantry).
    // - Radios estructurales a 270° (hacia el arco opuesto), 225°, 315° y 90°.
    // - Módulo auxiliar sensor pod en el cuadrante inferior izquierdo a 142°.
    // =========================================================================
    vec2 pHub = screen_coords - torusCenter;

    // Paleta canónica de materiales (station_ring_renderer.lua)
    vec3 c_hullDeep = vec3(0.10, 0.12, 0.17);
    vec3 c_hullDark = vec3(0.16, 0.19, 0.26);
    vec3 c_hullMid = vec3(0.25, 0.30, 0.40);
    vec3 c_hullLight = vec3(0.36, 0.43, 0.55);
    vec3 c_hullHighlight = vec3(0.52, 0.60, 0.74);
    vec3 c_wallShade = vec3(0.12, 0.15, 0.21);
    vec3 c_trussSteel = vec3(0.28, 0.34, 0.46);
    vec3 c_trussLight = vec3(0.42, 0.50, 0.64);
    vec3 c_accentCyan = mix(vec3(0.45, 0.70, 0.94), u_accent, 0.40);
    vec3 c_accentBright = mix(vec3(0.75, 0.90, 1.00), min(u_accent * 1.3, vec3(1.0)), 0.35);
    vec3 c_corridorLight = vec3(0.40, 0.62, 0.88);
    vec3 c_windowWhite = vec3(0.85, 0.92, 1.00);

    // Dimensiones canónicas proporcionales del tambor central
    float hubR = 54.0;                        // Radio horizontal del tambor (px)
    float hubRy = hubR * 0.58;                // ~31.3 px (proyección de perspectiva yFlatten ≈ 0.58)
    float hubH = 34.0;                        // Altura de la pared cilíndrica vertical (px)
    vec2 topCenter = vec2(0.0, -hubH * 0.40); // Centro de la tapa superior (-13.6 px)
    vec2 botCenter = vec2(0.0, hubH * 0.60);  // Centro de la base inferior (+20.4 px)

    // -------------------------------------------------------------------------
    // 4.1 PUENTE HORIZONTAL PRINCIPAL EN CELOSÍA 'X' (Main Gantry)
    // Se extiende de este a oeste conectando el hub con el anillo a través del horizonte.
    // Visible a los costados del tambor central (|pHub.x| > hubR * 0.88)
    // -------------------------------------------------------------------------
    if (abs(pHub.x) > hubR * 0.88 && abs(pHub.y) < 11.0)
    {
        float gantryH = 8.0;
        float dTopBoom = abs(pHub.y - (-gantryH));
        float dBotBoom = abs(pHub.y - (+gantryH));

        // Vigas horizontales superior e inferior
        if (dTopBoom < 1.5 || dBotBoom < 1.5)
        {
            float boomMask = smoothstep(1.5, 0.4, min(dTopBoom, dBotBoom));
            col = mix(col, c_hullDark, boomMask * 0.95);
        }

        // Celosía interna con cruces en 'X' cada 15 px
        if (abs(pHub.y) < gantryH)
        {
            float cellW = 15.0;
            float cellX = mod(pHub.x + 1000.0, cellW) - cellW * 0.5;
            float diagY = pHub.y * (cellW * 0.5 / gantryH);
            float dX1 = abs(cellX - diagY);
            float dX2 = abs(cellX + diagY);
            float dTrussX = min(dX1, dX2);

            // Puntales verticales cada 15 px
            float dVertical = abs(cellX);
            float trussMin = min(dTrussX, dVertical);

            if (trussMin < 1.3)
            {
                float trussMask = smoothstep(1.3, 0.3, trussMin);
                col = mix(col, c_trussSteel, trussMask * 0.92);
            }

            // Pasillo interior con luz guía constante
            float dCenter = abs(pHub.y);
            if (dCenter < 1.2)
            {
                float lightMask = smoothstep(1.2, 0.0, dCenter);
                col = mix(col, c_corridorLight, lightMask * 0.85);
            }
        }
    }

    // -------------------------------------------------------------------------
    // 4.2 RADIOS ESTRUCTURALES DEL EJE (Structural Radial Spokes)
    // Conectan el Hub cilíndrico hacia el arco opuesto y cuadrantes
    // -------------------------------------------------------------------------
    // Spoke Posterior hacia el ápice del Arco Opuesto (270° / hacia arriba)
    {
        vec2 ptStart = torusCenter + vec2(0.0, topCenter.y - hubRy * 0.95);
        vec2 ptEnd = torusCenter + vec2(0.0, -Ry * 0.96);
        float dummyT = 0.0;
        float dSpk = distToSegment(screen_coords, ptStart, ptEnd, dummyT);
        if (dSpk < 2.5)
        {
            float spkM = smoothstep(2.5, 1.0, dSpk);
            vec3 spkCol = c_hullDark;
            if (dSpk < 1.1)
                spkCol = c_trussLight;
            col = mix(col, spkCol, spkM * 0.92);
        }
    }

    // Spokes Diagonales Posteriores (225° y 315°) hacia el anillo posterior
    for (int sd = -1; sd <= 1; sd += 2)
    {
        float sgn = float(sd);
        vec2 ptStart = torusCenter + vec2(sgn * hubR * 0.67, -hubRy * 0.67);
        vec2 ptEnd = torusCenter + vec2(sgn * Rx * 0.71, -Ry * 0.71);
        float dummyT = 0.0;
        float dSpk = distToSegment(screen_coords, ptStart, ptEnd, dummyT);
        if (dSpk < 2.2)
        {
            float spkM = smoothstep(2.2, 0.8, dSpk);
            col = mix(col, c_hullDark, spkM * 0.88);
        }
    }

    // -------------------------------------------------------------------------
    // 4.6 PUENTES RADIALES GIRATORIOS (Rotating Elevator Spokes)
    // Conectan el Eje Central con el Arco Opuesto superior (u_spin).
    // Por la lógica física de la estación de anillo (el observador habita en el arco frontal inferior),
    // los radios elevadores conectan hacia el Arco Opuesto visible en el cielo (sy <= 0.0).
    // En la parte más baja (sy > 0.0), no se observan líneas giratorias en el vacío inferior.
    // -------------------------------------------------------------------------
    for (int i = 0; i < 4; i++)
    {
        float a = u_spin + float(i) * 1.5707963;
        float sx = sin(a) * Rx;
        float sy = -cos(a) * Ry;

        if (sy <= 0.0)
        {
            float horizonFade = clamp(-sy / (Ry * 0.15), 0.0, 1.0);
            vec2 ptStart = torusCenter + vec2(sx * 0.12, sy * 0.12);
            vec2 ptEnd = torusCenter + vec2(sx * 0.98, sy * 0.98);
            float projT = 0.0;
            float dSpk = distToSegment(screen_coords, ptStart, ptEnd, projT);

            if (dSpk < 2.2)
            {
                float spkM = smoothstep(2.2, 0.8, dSpk);
                col = mix(col, c_hullDark, spkM * horizonFade * 0.88);
            }

            // Vainas de transporte magnético de alta velocidad (Transit Pods)
            float podT1 = mod(u_time * 0.18 + float(i) * 0.25, 0.82) + 0.10;
            vec2 podPos1 = mix(ptStart, ptEnd, podT1);
            float dPod1 = length(screen_coords - podPos1);
            if (dPod1 < 2.5)
            {
                col = mix(col, vec3(1.0, 0.92, 0.60), smoothstep(2.5, 0.0, dPod1) * horizonFade * 0.95);
            }

            float podT2 = 0.92 - mod(u_time * 0.14 + float(i) * 0.31, 0.82);
            vec2 podPos2 = mix(ptStart, ptEnd, podT2);
            float dPod2 = length(screen_coords - podPos2);
            if (dPod2 < 2.5)
            {
                col = mix(col, vec3(1.0, 0.92, 0.60), smoothstep(2.5, 0.0, dPod2) * horizonFade * 0.95);
            }
        }
    }

    // -------------------------------------------------------------------------
    // 4.3 MÓDULO AUXILIAR / SENSOR POD (Cuadrante frontal izquierdo a 142°)
    // Sostenido por anclaje diagonal desde el hub (idéntico a station_ring_renderer.lua)
    // -------------------------------------------------------------------------
    {
        vec2 podPos = torusCenter + vec2(-hubR * 1.72, hubRy * 1.34);

        // Brazo diagonal de anclaje de celosía
        vec2 strutStart = torusCenter + vec2(-hubR * 0.82, botCenter.y * 0.40);
        float dummyT = 0.0;
        float dStrut = distToSegment(screen_coords, strutStart, podPos, dummyT);
        if (dStrut < 1.8)
        {
            float strutM = smoothstep(1.8, 0.6, dStrut);
            col = mix(col, c_trussSteel, strutM * 0.92);
        }

        // Pod esférico presurizado con elipse inclinada (podRadius = 14 px)
        vec2 pPod = screen_coords - podPos;
        float podR = 14.0;
        float podRy = podR * 0.58; // ~8.1 px
        float dPodEll = sqrt(pow(pPod.x / podR, 2.0) + pow(pPod.y / podRy, 2.0));

        if (dPodEll < 1.0)
        {
            float podMask = smoothstep(1.0, 0.88, dPodEll);
            vec3 podCol = c_hullDark;

            // Borde biselado
            if (dPodEll > 0.80)
            {
                podCol = c_hullLight;
            }
            // Núcleo de energía / sensor óptico cian
            else if (dPodEll < 0.48)
            {
                podCol = c_accentCyan;
                if (dPodEll < 0.24)
                {
                    podCol = c_accentBright;
                }
                // Retículo óptico en cruz
                if (abs(pPod.x) < 0.8 || abs(pPod.y) < 0.8)
                {
                    podCol = c_windowWhite;
                }
            }

            col = mix(col, podCol, podMask);
        }
    }

    // -------------------------------------------------------------------------
    // 4.4 PARED CILÍNDRICA VERTICAL DEL TAMBOR CENTRAL (Drum Cylindrical Body)
    // Extrusión volumétrica hacia abajo con juntas de placas verticales
    // -------------------------------------------------------------------------
    if (abs(pHub.x) < hubR)
    {
        float nx = pHub.x / hubR;
        float capYOffset = hubRy * sqrt(max(0.0, 1.0 - nx * nx));
        float yTopCurve = topCenter.y + capYOffset;
        float yBotCurve = botCenter.y + capYOffset;

        // Pared cilíndrica entre la curva superior y la base inferior
        if (pHub.y > yTopCurve - 1.0 && pHub.y < yBotCurve)
        {
            float wallMask = smoothstep(yBotCurve, yBotCurve - 1.5, pHub.y) * smoothstep(hubR, hubR - 1.2, abs(pHub.x));

            // Sombreado cilíndrico metálico idéntico al renderizador exterior
            float midAngle = asin(clamp(nx, -0.999, 0.999));
            float shade = 0.68 + 0.32 * cos(midAngle - 0.45);
            vec3 wallCol = c_wallShade * shade;

            // Juntas verticales de placas en el cilindro
            float seamAngle = mod(midAngle * (hubR / 12.0) + 10.0, 1.0);
            if (seamAngle < 0.10)
            {
                wallCol -= vec3(0.04, 0.05, 0.07);
            }

            // Borde inferior resaltado
            if (pHub.y > yBotCurve - 2.5)
            {
                wallCol += vec3(0.08, 0.10, 0.14);
            }

            col = mix(col, wallCol, wallMask);
        }
    }

    // -------------------------------------------------------------------------
    // 4.5 TAPA / CÚPULA SUPERIOR DEL HUB DE MANDO (Top Cap Face en z = zTop)
    // Idéntico a drawCentralHub3D en station_ring_renderer.lua:
    // - Base hullDark con bisel exterior de titanio hullHighlight
    // - Anillo intermedio hullMid / hullLight
    // - Iris polar central de observación dividido en 8 sectores
    // - Túnel axial de gravedad cero con anillo cian resplandeciente
    // -------------------------------------------------------------------------
    vec2 pCap = pHub - topCenter;
    float rCapEll = sqrt(pow(pCap.x / hubR, 2.0) + pow(pCap.y / hubRy, 2.0));

    if (rCapEll < 1.0)
    {
        float capMask = smoothstep(1.0, 0.93, rCapEll);
        vec3 capCol = c_hullDark;

        // 1. Bisel exterior de titanio en la cima del Hub
        if (rCapEll > 0.88)
        {
            float rimGlow = smoothstep(0.88, 0.97, rCapEll);
            capCol = mix(capCol, c_hullHighlight, rimGlow);
        }

        // 2. Ranura oscura exterior
        if (rCapEll > 0.68 && rCapEll < 0.74)
        {
            capCol = c_hullDeep;
        }

        // 3. Anillo intermedio de acople (r = hubR * 0.65)
        if (rCapEll > 0.46 && rCapEll <= 0.68)
        {
            capCol = c_hullMid;
            if (rCapEll > 0.64 || rCapEll < 0.49)
            {
                capCol = c_hullLight;
            }
        }

        // 4. Iris polar central de observación (dividido en 8 sectores angulares)
        if (rCapEll <= 0.46)
        {
            capCol = c_hullDeep;

            // Borde del iris
            if (rCapEll > 0.42)
            {
                capCol = c_hullHighlight;
            }

            // 8 rayos radiales del iris a 45 grados (k * 45°)
            float irisAngle = atan(pCap.y / 0.58, pCap.x);
            float sectorMod = mod(irisAngle + 3.14159265 * 0.125, 3.14159265 * 0.25) - 3.14159265 * 0.125;
            float spokeDist = abs(sin(sectorMod)) * (rCapEll * hubR);
            if (spokeDist < 0.95 && rCapEll > 0.20)
            {
                capCol = c_hullHighlight;
            }
        }

        // 5. Túnel axial Zero-G en el centro (r = hubR * 0.20)
        if (rCapEll <= 0.21)
        {
            capCol = c_hullDark;
            // Borde cian resplandeciente del túnel axial
            if (rCapEll > 0.14)
            {
                float ringCian = smoothstep(0.14, 0.18, rCapEll) * smoothstep(0.22, 0.18, rCapEll);
                capCol = mix(capCol, c_accentCyan, ringCian * 0.95);
            }
            if (rCapEll < 0.12)
            {
                capCol = vec3(0.08, 0.10, 0.14); // Interior oscuro del túnel
            }
        }

        col = mix(col, capCol, capMask);
    }

    // =========================================================================
    // 6. LA COLOSAL SUPERESTRUCTURA DEL ARCO OPUESTO (Opposite Torus Superstructure)
    // Curvatura elíptica continua que se extiende de horizonte a horizonte
    // =========================================================================
    if (pTorus.y < Ry * 0.40 && abs(arcAngle) < 1.85)
    {
        float arcWorldX = arcAngle * 1100.0 + u_camera.x * 0.06;
        float dHull = distToTorus; // Distancia signed a la elipse central (px)

        // ---------------------------------------------------------------------
        // 6.1 Aletas radiadoras térmicas y paneles solares (Borde exterior)
        // dHull en [-36.0, -16.0]
        // ---------------------------------------------------------------------
        if (dHull < -16.0 && dHull > -36.0)
        {
            float finMod = mod(arcWorldX, 58.0);

            // Aletas radiadoras de enfriamiento térmico
            if (finMod < 16.0)
            {
                float finMask = smoothstep(-36.0, -33.0, dHull) * smoothstep(-16.0, -18.0, dHull);
                vec3 radCol = vec3(0.10, 0.12, 0.16);
                float heatCore = exp(-pow((dHull + 26.0) * 0.22, 2.0));
                radCol += vec3(0.48, 0.08, 0.04) * heatCore * 0.65;
                if (finMod < 2.0 || finMod > 14.0 || dHull < -33.0)
                {
                    radCol = vec3(0.20, 0.25, 0.32);
                }
                col = mix(col, radCol, finMask * 0.92);
            }
            // Paneles solares fotovoltaicos desplegables
            else if (finMod > 26.0 && finMod < 48.0 && dHull > -28.0)
            {
                float solarMask = smoothstep(-28.0, -26.0, dHull) * smoothstep(-16.0, -18.0, dHull);
                vec3 solarCol = vec3(0.06, 0.12, 0.24);
                float cellGrid = step(0.15, fract(finMod / 3.2)) * step(0.20, fract(dHull / 2.8));
                solarCol += vec3(0.10, 0.22, 0.45) * cellGrid;
                col = mix(col, solarCol, solarMask * 0.85);
            }
        }

        // ---------------------------------------------------------------------
        // 6.2 Blindaje Flotante de Titanio (Floating Armor Plating)
        // Módulos de blindaje ablativo flotantes paralelos al casco exterior: dHull en [-21.0, -16.5]
        // ---------------------------------------------------------------------
        if (dHull < -16.5 && dHull > -21.5)
        {
            float armorSeg = mod(arcWorldX, 36.0);
            if (armorSeg > 3.0 && armorSeg < 33.0)
            {
                float plateMask = smoothstep(-21.5, -20.5, dHull) * smoothstep(-16.5, -17.5, dHull);
                vec3 plateCol = vec3(0.16, 0.20, 0.27);
                if (dHull < -20.0)
                    plateCol += vec3(0.08, 0.10, 0.14);
                col = mix(col, plateCol, plateMask * 0.92);
            }
        }

        // ---------------------------------------------------------------------
        // 6.3 Casco Presurizado Principal del Toroide (Primary Pressurized Torus Hull)
        // Espesor monumental de 32 px: dHull en [-16.0, +16.0]
        // ---------------------------------------------------------------------
        if (abs(dHull) < 16.0)
        {
            float hullMask = smoothstep(16.0, 14.8, abs(dHull));
            float heightRel = dHull / 16.0;

            vec3 hullCol = vec3(0.13, 0.16, 0.22);
            float metallicShade = 0.72 - heightRel * 0.28;
            hullCol *= metallicShade;

            // Costillas maestras estructurales (Rib Bulkheads cada 32 px)
            float ribCoord = mod(arcWorldX, 32.0);
            if (ribCoord < 2.5)
            {
                hullCol += vec3(0.09, 0.11, 0.15);
            }
            else if (ribCoord < 4.2)
            {
                hullCol -= vec3(0.05, 0.06, 0.08);
            }

            // Biseles de titanio reforzado
            if (abs(dHull) > 13.5)
            {
                hullCol += vec3(0.16, 0.22, 0.30);
            }

            // Bahías de atraque activas y hangares de servicio
            float hangarCoord = mod(arcWorldX + 24.0, 160.0);
            if (hangarCoord < 24.0 && abs(heightRel) < 0.50)
            {
                vec3 hangarCol = vec3(0.26, 0.19, 0.09);
                float runwayMark = step(0.45, fract(hangarCoord / 5.5));
                hangarCol += vec3(0.15, 0.95, 0.55) * runwayMark * 0.85;
                hullCol = mix(hullCol, hangarCol, 0.90);
            }

            // Nodos de Empalme de los Puentes Radiales (Spoke Terminals)
            float spokeAnchor = mod(arcWorldX + 60.0, 240.0);
            if (spokeAnchor < 20.0 && heightRel > 0.40)
            {
                hullCol = mix(hullCol, vec3(0.24, 0.30, 0.40), 0.85);
                if (spokeAnchor > 6.0 && spokeAnchor < 14.0)
                {
                    hullCol += vec3(0.95, 0.65, 0.15) * 0.80;
                }
            }

            // CUBIERTAS HABITACIONALES ILUMINADAS (City Lights in Space)
            bool inUpperDeck = (heightRel > -0.72 && heightRel < -0.28);
            bool inLowerDeck = (heightRel > 0.15 && heightRel < 0.62);
            if ((inUpperDeck || inLowerDeck) && !(hangarCoord < 26.0))
            {
                vec2 winCell = floor(vec2(arcWorldX * 0.32, dHull * 0.90));
                float winR = hash12(winCell);
                if (winR > 0.46)
                {
                    vec3 winGlow = vec3(1.0, 0.88, 0.55);
                    if (winR > 0.84)
                        winGlow = vec3(0.40, 0.85, 1.0);
                    else if (winR > 0.72)
                        winGlow = vec3(0.95, 0.95, 1.0);
                    else if (winR > 0.62)
                        winGlow = vec3(0.45, 0.90, 0.55);

                    float winBright = (0.60 + 0.40 * winR);
                    hullCol += winGlow * winBright * 0.90;
                }
            }

            // Franja de servicio y conductos técnicos centrales
            if (abs(heightRel) < 0.14)
            {
                hullCol = vec3(0.08, 0.10, 0.14);
                if (fract(arcWorldX * 0.09) < 0.28)
                {
                    hullCol += vec3(0.20, 0.65, 0.95) * 0.45;
                }
            }

            // Balizas aeronáuticas de advertencia
            float beaconMod = mod(arcWorldX, 96.0);
            if (beaconMod < 4.0 && abs(dHull) > 12.0)
            {
                float bPhase = hash11(floor(arcWorldX / 96.0));
                float bStrobe = step(0.85, sin(u_time * 4.5 + bPhase * 6.28));
                vec3 strobeCol = (heightRel < 0.0) ? vec3(1.0, 0.15, 0.15) : vec3(1.0, 0.70, 0.10);
                hullCol += strobeCol * bStrobe * 2.4;
            }

            col = mix(col, hullCol, hullMask);
        }

        // ---------------------------------------------------------------------
        // 6.4 Anillo Secundario de Tránsito y Distribución (Inner Transit Tube)
        // Paralelo en el lado cóncavo interior: dHull en [+16.0, +28.0]
        // ---------------------------------------------------------------------
        if (dHull > 16.0 && dHull < 28.0)
        {
            float trussBeam = step(0.78, sin(arcWorldX * 0.35 + dHull * 0.40));
            float trussMask = smoothstep(16.0, 18.0, dHull) * smoothstep(24.0, 22.0, dHull);
            col = mix(col, vec3(0.14, 0.17, 0.22), trussMask * trussBeam * 0.85);

            if (dHull > 23.0 && dHull < 27.5)
            {
                float tubeMask = smoothstep(23.0, 24.0, dHull) * smoothstep(27.5, 26.5, dHull);
                vec3 tubeCol = vec3(0.16, 0.20, 0.28);
                float magPulse = smoothstep(0.85, 1.0, sin(arcWorldX * 0.08 - u_time * 6.0));
                tubeCol += vec3(0.30, 0.85, 1.0) * magPulse * 0.95;
                col = mix(col, tubeCol, tubeMask * 0.90);
            }
        }
    }

    // =========================================================================
    // 7. TRÁFICO ORBITAL Y LANZADERAS (Local Orbit Logistics)
    // =========================================================================
    for (int i = 0; i < 3; i++)
    {
        float fI = float(i);
        float tSpeed = 24.0 + fI * 14.0;
        float pathDir = (mod(fI, 2.0) == 0.0) ? 1.0 : -1.0;

        float shipWorldX = u_time * tSpeed * pathDir + fI * 450.0;
        float shipScreenX = mod(shipWorldX - u_camera.x * 0.08, u_resolution.x + 140.0) - 70.0;
        float shipScreenY = u_resolution.y * (0.28 + fI * 0.18) - (u_camera.y - 272.0) * 0.02;

        vec2 shipDiff = screen_coords - vec2(shipScreenX, shipScreenY);
        float dShip = length(shipDiff);

        if (dShip < 3.0)
        {
            col += vec3(0.85, 0.92, 1.0) * smoothstep(3.0, 0.0, dShip);
        }

        vec2 trailVec = shipDiff;
        trailVec.x *= -pathDir;
        if (trailVec.x > 0.0 && trailVec.x < 24.0 && abs(trailVec.y) < 1.6)
        {
            float trailFade = (1.0 - trailVec.x / 24.0) * smoothstep(1.6, 0.0, abs(trailVec.y));
            vec3 plumeColor = (fI == 1.0) ? vec3(1.0, 0.55, 0.15) : vec3(0.25, 0.85, 1.0);
            col += plumeColor * trailFade * 0.75;
        }
    }

    // =========================================================================
    // 8. DESTELLOS DE SOLDADURA EXTERIOR (EVA Repair Sparks)
    // =========================================================================
    float weldCycle = sin(u_time * 6.5);
    if (weldCycle > 0.72)
    {
        vec2 weldPos = torusCenter + vec2(-Rx * 0.45, -Ry * 0.85);
        float dWeld = length(screen_coords - weldPos);
        if (dWeld < 6.0)
        {
            float sparkTwinkle = hash11(u_time * 30.0);
            col += vec3(0.70, 0.90, 1.0) * smoothstep(6.0, 0.0, dWeld) * sparkTwinkle * 1.6;
        }
    }

    return vec4(col, 1.0) * color;
}
