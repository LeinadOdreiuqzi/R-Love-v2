// src/shaders/ring_station_bg.glsl
// Shader dedicado para el fondo de la Estación Espacial de Anillo (Ring Station / Torus).
// Genera: espacio profundo, nebulosas interestelares, estrellas con twinkle,
// el colosal arco curvado opuesto del toroide, el eje central (hub) y radios giratorios con rotación centrífuga.

extern float u_time;
extern vec2 u_camera;        // Coordenadas globales de la cámara en el mundo de la estación (px)
extern vec2 u_resolution;    // Dimensiones del viewport
extern float u_spin;         // Ángulo de rotación centrífuga de la estación (rad)
extern vec3 u_accent;        // Color de acento de la estación

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

// Generadores de ruido procedural
float hash12(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    v += 0.500 * noise(p); p *= 2.02;
    v += 0.250 * noise(p); p *= 2.03;
    v += 0.125 * noise(p);
    return v;
}

vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
    vec2 uv = screen_coords / u_resolution;
    
    // 1. ESPACIO PROFUNDO Y NEBULOSA INTERESTELAR (Parallax factor: 0.03)
    vec2 nebCoord = (screen_coords + u_camera * 0.03) * 0.0018;
    float n1 = fbm(nebCoord + vec2(u_time * 0.006, 0.0));
    float n2 = fbm(nebCoord * 1.6 - vec2(0.0, u_time * 0.005));
    
    // Gradiente cósmico base: índigo muy oscuro a cian profundo
    vec3 spaceColor = vec3(0.012, 0.015, 0.026);
    vec3 nebCyan = vec3(0.04, 0.13, 0.20) * (n1 * 1.4);
    vec3 nebPurple = vec3(0.09, 0.04, 0.16) * (n2 * 1.1);
    vec3 col = spaceColor + nebCyan + nebPurple;

    // 2. CAMPO ESTELAR MULTICAPA (Parallax factor: 0.05)
    vec2 starPos = screen_coords + u_camera * 0.05;
    vec2 starCell = floor(starPos / 24.0);
    vec2 starLocal = fract(starPos / 24.0) - 0.5;
    float starRand = hash12(starCell);
    
    if (starRand > 0.78) {
        float dStar = length(starLocal);
        float twinkle = 0.65 + 0.35 * sin(u_time * 2.5 + starRand * 18.0);
        float starBrightness = smoothstep(0.12, 0.0, dStar) * twinkle;
        
        // Matiz de la estrella (azules, blancas y ámbar cálido)
        vec3 starTint = vec3(0.85, 0.95, 1.0);
        if (starRand > 0.95) starTint = vec3(1.0, 0.82, 0.55);
        else if (starRand > 0.88) starTint = vec3(0.65, 0.85, 1.0);
        
        col += starTint * starBrightness * (0.6 + 0.4 * starRand);
    }

    // Estrellas más distantes y densas (polvo estelar)
    vec2 faintPos = screen_coords + u_camera * 0.02;
    vec2 faintCell = floor(faintPos / 14.0);
    float faintRand = hash12(faintCell);
    if (faintRand > 0.91) {
        vec2 faintLocal = fract(faintPos / 14.0) - 0.5;
        float dFaint = length(faintLocal);
        col += vec3(0.55, 0.70, 0.90) * smoothstep(0.18, 0.0, dFaint) * 0.25;
    }

    // 3. EJE CENTRAL Y RADIOS GIRATORIOS (Central Hub & Spokes) (Parallax: 0.10)
    // El eje central está suspendido en el centro geométrico del toroide
    vec2 hubScreenCenter = vec2(u_resolution.x * 0.5, u_resolution.y * 0.38);
    // Desplazamiento parallax relativo al centro de la estación
    vec2 hubPos = hubScreenCenter - (u_camera - vec2(2400.0, 272.0)) * vec2(0.09, 0.06);
    
    // Coordenadas relativas al eje central
    vec2 diffHub = screen_coords - hubPos;
    float distHub = length(diffHub);
    
    // Radios estructurales (Spokes): conectan el hub con el anillo
    // Giran con la velocidad centrífuga u_spin
    if (distHub > 18.0 && distHub < 260.0) {
        float angleSpoke = atan(diffHub.y, diffHub.x) - u_spin;
        // 4 radios principales a 90 grados
        float spokeWave = abs(sin(angleSpoke * 2.0));
        float spokeWidth = 2.4 / (distHub * 0.02 + 1.0);
        float spokeMask = smoothstep(spokeWidth * 0.04, 0.0, spokeWave);
        
        if (spokeMask > 0.0) {
            // Estructura de celosía del radio
            vec3 spokeCol = vec3(0.18, 0.22, 0.28);
            // Luces de tránsito a lo largo del radio
            float podPos = fract((distHub - u_time * 24.0) / 48.0);
            float podLight = smoothstep(0.08, 0.0, abs(podPos - 0.5));
            spokeCol += vec3(0.3, 0.8, 1.0) * podLight * 0.6;
            
            col = mix(col, spokeCol, spokeMask * 0.85);
        }
    }
    
    // Módulo central cilíndrico (Central Hub)
    if (distHub < 22.0) {
        float hubMask = smoothstep(22.0, 20.0, distHub);
        vec3 hubCol = vec3(0.24, 0.28, 0.36);
        // Sombreado 3D cilíndrico
        float shade = clamp(diffHub.y / 20.0 * 0.5 + 0.6, 0.3, 1.0);
        hubCol *= shade;
        // Núcleo de atraque central
        if (distHub < 8.0) {
            hubCol = vec3(0.12, 0.15, 0.20);
        }
        // Luces de baliza de navegación (parpadeo rojo y cian)
        float beaconFlash = step(0.5, fract(u_time * 1.5));
        if (distHub > 14.0 && distHub < 18.0) {
            hubCol += vec3(1.0, 0.2, 0.2) * beaconFlash * 0.8;
        }
        col = mix(col, hubCol, hubMask);
    }

    // 4. EL COLOSAL ARCO OPUESTO DEL ANILLO (Opposite Ring Arc) (Parallax: 0.18)
    // Curvatura hiperbólica/elíptica que cruza majestuosamente el cielo de la estación
    float ringWorldX = screen_coords.x + u_camera.x * 0.18;
    // Perfil parabólico de arco que desciende suavemente hacia ambos extremos
    float normX = (screen_coords.x / u_resolution.x) - 0.5;
    float arcCenterY = u_resolution.y * 0.30 + (normX * normX) * 90.0 - (u_camera.y - 272.0) * 0.10;
    float arcThick = 26.0;
    float distArc = abs(screen_coords.y - arcCenterY);
    
    if (distArc < arcThick) {
        float edgeBlend = smoothstep(arcThick, arcThick - 1.5, distArc);
        // Casco exterior blindado del anillo opuesto
        vec3 ringHull = vec3(0.15, 0.18, 0.24);
        
        // Bisel superior e inferior del casco
        float rimHighlight = smoothstep(arcThick - 3.0, arcThick - 0.5, distArc);
        ringHull += vec3(0.25, 0.30, 0.38) * rimHighlight;
        
        // Costillas modulares y bahías a lo largo del arco
        float moduleSeam = smoothstep(0.92, 1.0, sin(ringWorldX * 0.08));
        ringHull -= vec3(0.06, 0.07, 0.09) * moduleSeam;
        
        // Ventanales habitables iluminados del anillo opuesto (miles de luces cálidas y cian)
        if (distArc < 12.0) {
            vec2 winGrid = floor(vec2(ringWorldX * 0.22, distArc * 0.8));
            float winRand = hash12(winGrid);
            if (winRand > 0.60) {
                vec3 winGlow = (winRand > 0.85) ? vec3(1.0, 0.88, 0.55) : vec3(0.40, 0.85, 1.00);
                ringHull += winGlow * (0.45 + 0.35 * winRand);
            }
        }
        
        // Balizas estroboscópicas rojas de señalización exterior a intervalos regulares
        float beaconGrid = floor(ringWorldX * 0.015);
        float beaconPhase = hash11(beaconGrid);
        float beaconFlash = step(0.88, sin(u_time * 4.0 + beaconPhase * 6.28));
        if (abs(distArc - (arcThick - 3.0)) < 2.0 && fract(ringWorldX * 0.015) < 0.08) {
            ringHull += vec3(1.0, 0.15, 0.15) * beaconFlash * 1.5;
        }

        col = mix(col, ringHull, edgeBlend);
    }

    // 5. TRÁFICO EXTERIOR Y LANZADERAS ORBITALES (Parallax: 0.28)
    // Pequeñas lanzaderas autónomas de mantenimiento cruzando el vacío
    for (int i = 0; i < 2; i++) {
        float fI = float(i);
        float droneSpeed = 16.0 + fI * 8.0;
        float droneX = mod(u_time * droneSpeed + fI * 340.0 - u_camera.x * 0.28, u_resolution.x + 80.0) - 40.0;
        float droneY = u_resolution.y * (0.22 + fI * 0.25) - u_camera.y * 0.12;
        vec2 droneDiff = screen_coords - vec2(droneX, droneY);
        float dDrone = length(droneDiff);
        if (dDrone < 3.5) {
            float droneFlash = 0.7 + 0.3 * sin(u_time * 8.0 + fI * 2.0);
            col += vec3(0.3, 0.9, 1.0) * droneFlash * smoothstep(3.5, 0.0, dDrone);
        }
    }

    return vec4(col, 1.0) * color;
}
