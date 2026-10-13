-- src/shaders/hyperspace_tunnel.lua
-- Shader para el túnel de hiperespacio 3D inspirado en Destiny 2 Jumpship Warp Screen
-- Sistema espectral dinámico multicromático (6+ bandas de emisión nebular en 3D),
-- morfología realista de nubes cósmicas con billows celulares y venas de absorción de polvo,
-- y generador procedural multicapa de estelas estelares (needle lasers y motas cometarias).

local HyperspaceTunnel = {}

local shader = nil
local initialized = false
local dummyImage = nil

-- Configuración por defecto
HyperspaceTunnel.config = {
    baseSpeed = 0.85,          -- Velocidad base fluida y majestuosa
    maxSpeedBoost = 2.2,       -- Aceleración suave y controlada
    intensity = 1.0,           -- Intensidad lumínica global
    direction = 1.0,           -- 1.0: Flujo hacia el espectador (Destiny 2)
    fov = 0.85,                -- Ángulo de visión / curvatura hiperbólica
    time = 0.0,
    flowPos = 0.0,             -- Posición integrada continua (cero tirones temporales)
    currentSeed = "DEFAULT",
    themeName = "Carina Orion"
}

-- Estado procedural activo generado a partir de la semilla
local proceduralState = {
    seedOffset = 42.1337,
    col1 = {0.06, 0.22, 0.72},      -- Azul zafiro profundo / índigo
    col2 = {0.15, 0.72, 0.98},      -- Cian eléctrico brillante / cerúleo
    col3 = {0.65, 0.92, 0.78},      -- Menta etérea / oro aguamarina pálido (Destiny 2 Bridge)
    col4 = {1.00, 0.72, 0.20},      -- Ámbar solar incandescente / oro
    col5 = {0.95, 0.36, 0.16},      -- Coral hidrógeno / naranja salmón
    col6 = {0.72, 0.12, 0.18},      -- Carmesí cósmico / rubí profundo
    colPeak = {1.00, 0.95, 0.85},   -- Resplandor pico blanco-oro

    spaceVoid = {0.005, 0.008, 0.016},
    dustColor = {0.012, 0.008, 0.010},
    coreColor = {1.00, 0.98, 0.92},
    flareColor = {0.65, 0.88, 1.00},

    cloudParams = {1.05, 1.35, 0.75, 1.25},   -- density, turbulenceScale, dustVeinStrength, contrast
    streakParams = {0.35, 0.48, 1.5, 3.2}     -- density, length, speedMul, width/sharpness
}

-- Catálogo de 6 Arquetipos Espectrales Armónicos (Bicolor astrofísico elegante, cero arcoíris)
local ARCHETYPES = {
    {
        name = "Destiny 2 Carina Conduit (Bicolor Cyan & Coral)",
        col1 = {0.03, 0.08, 0.30}, -- Índigo noche profundo (Sombra O-III)
        col2 = {0.08, 0.58, 0.88}, -- Cerúleo eléctrico vibrante (Cuerpo O-III)
        col3 = {0.30, 0.82, 0.98}, -- Cian estelar radiante (Cresta O-III)
        col4 = {0.28, 0.06, 0.10}, -- Vino granate profundo (Sombra H-α)
        col5 = {0.90, 0.36, 0.20}, -- Coral hidrógeno / salmón (Cuerpo H-α)
        col6 = {1.00, 0.68, 0.26}, -- Ámbar dorado cálido (Cresta H-α)
        colPeak = {1.00, 0.96, 0.88},
        spaceVoid = {0.003, 0.005, 0.012},
        dust = {0.010, 0.006, 0.005},
        core = {1.00, 0.98, 0.92},
        flare = {0.68, 0.88, 1.00},
        cloud = {1.05, 1.35, 0.75, 1.25},
        streak = {0.35, 0.48, 1.5, 3.2}
    },
    {
        name = "Tarantula Supernova (Rose-Gold & Deep Violet)",
        col1 = {0.07, 0.03, 0.25}, -- Amatista noche profunda (Sombra)
        col2 = {0.48, 0.22, 0.80}, -- Violeta real cósmico (Cuerpo)
        col3 = {0.80, 0.42, 0.92}, -- Rosa orquídea luminoso (Cresta)
        col4 = {0.26, 0.07, 0.14}, -- Ciruela ahumada (Sombra)
        col5 = {0.88, 0.36, 0.46}, -- Oro rosa / salmón suave (Cuerpo)
        col6 = {1.00, 0.72, 0.52}, -- Melocotón champagne (Cresta)
        colPeak = {1.00, 0.94, 0.90},
        spaceVoid = {0.005, 0.004, 0.012},
        dust = {0.012, 0.005, 0.008},
        core = {1.00, 0.96, 0.92},
        flare = {0.90, 0.70, 1.00},
        cloud = {1.15, 1.45, 0.80, 1.35},
        streak = {0.42, 0.52, 1.6, 3.0}
    },
    {
        name = "Pillars of Creation (Hubble Deep Teal & Solar Amber)",
        col1 = {0.02, 0.08, 0.22}, -- Abismo teal profundo (Sombra)
        col2 = {0.06, 0.55, 0.68}, -- Teal oxígeno clásico Hubble (Cuerpo)
        col3 = {0.20, 0.80, 0.85}, -- Aguamarina luminosa (Cresta)
        col4 = {0.24, 0.09, 0.04}, -- Tierra umber cósmica (Sombra)
        col5 = {0.85, 0.46, 0.14}, -- Cobre incandescente (Cuerpo)
        col6 = {1.00, 0.76, 0.25}, -- Ámbar solar dorado (Cresta)
        colPeak = {0.98, 1.00, 0.90},
        spaceVoid = {0.003, 0.006, 0.012},
        dust = {0.014, 0.008, 0.005},
        core = {0.98, 1.00, 0.92},
        flare = {0.50, 0.90, 0.85},
        cloud = {1.20, 1.25, 0.88, 1.40},
        streak = {0.30, 0.42, 1.4, 3.4}
    },
    {
        name = "Cygnus Arc (High-Energy Cobalt & Pure Cyan)",
        col1 = {0.03, 0.06, 0.28}, -- Azul cobalto medianoche (Sombra)
        col2 = {0.10, 0.52, 0.92}, -- Azul alta tensión (Cuerpo)
        col3 = {0.40, 0.85, 1.00}, -- Cian hielo brillante (Cresta)
        col4 = {0.05, 0.04, 0.22}, -- Ultramar profundo (Sombra)
        col5 = {0.35, 0.44, 0.88}, -- Pervinca eléctrico (Cuerpo)
        col6 = {0.78, 0.88, 1.00}, -- Diamante blanco-azul (Cresta)
        colPeak = {0.96, 0.98, 1.00},
        spaceVoid = {0.003, 0.004, 0.010},
        dust = {0.008, 0.006, 0.010},
        core = {1.00, 0.98, 1.00},
        flare = {0.65, 0.85, 1.00},
        cloud = {0.95, 1.55, 0.65, 1.20},
        streak = {0.45, 0.58, 1.8, 3.5}
    },
    {
        name = "Supernova Remnant (Cosmic Ruby & Starburst Amber)",
        col1 = {0.20, 0.03, 0.07}, -- Granate abisal (Sombra)
        col2 = {0.78, 0.15, 0.24}, -- Rubí cósmico intenso (Cuerpo)
        col3 = {0.96, 0.40, 0.30}, -- Coral vivo incandescente (Cresta)
        col4 = {0.18, 0.05, 0.03}, -- Castaño ahumado (Sombra)
        col5 = {0.88, 0.48, 0.12}, -- Ámbar fundido (Cuerpo)
        col6 = {1.00, 0.78, 0.30}, -- Oro solar brillante (Cresta)
        colPeak = {1.00, 0.96, 0.90},
        spaceVoid = {0.005, 0.004, 0.008},
        dust = {0.012, 0.006, 0.006},
        core = {1.00, 0.96, 0.92},
        flare = {1.00, 0.75, 0.55},
        cloud = {1.10, 1.40, 0.70, 1.30},
        streak = {0.38, 0.50, 1.7, 3.2}
    },
    {
        name = "Void Dynamo (Cosmic Twilight & Arc Cyan)",
        col1 = {0.04, 0.02, 0.16}, -- Índigo crepuscular oscuro (Sombra)
        col2 = {0.24, 0.15, 0.60}, -- Amatista crepúsculo (Cuerpo)
        col3 = {0.58, 0.48, 0.90}, -- Aurora lavanda suave (Cresta)
        col4 = {0.03, 0.07, 0.25}, -- Azul marino profundo (Sombra)
        col5 = {0.10, 0.58, 0.88}, -- Cerúleo eléctrico arco (Cuerpo)
        col6 = {0.35, 0.85, 0.96}, -- Aguamarina arco radiante (Cresta)
        colPeak = {0.96, 0.98, 1.00},
        spaceVoid = {0.003, 0.003, 0.008},
        dust = {0.008, 0.004, 0.009},
        core = {0.98, 0.96, 1.00},
        flare = {0.75, 0.70, 1.00},
        cloud = {1.12, 1.30, 0.82, 1.35},
        streak = {0.32, 0.46, 1.5, 3.1}
    }
}

-- Función hash determinista rápida (compatible Lua 5.1 / LuaJIT)
local function hashSeed(seedStr)
    local s = tostring(seedStr or "DEF_WARP")
    local h = 5381
    for i = 1, #s do
        local b = s:byte(i)
        h = ((h * 33) + b) % 2147483647
    end
    return h
end

-- Generador pseudoaleatorio LCG
local function makeRNG(seedVal)
    local s = hashSeed(seedVal)
    return function()
        s = (s * 1103515245 + 12345) % 2147483648
        return s / 2147483648
    end
end

-- Generar estado procedural completo a partir de la semilla cósmica
function HyperspaceTunnel.setSeed(seedStr)
    HyperspaceTunnel.config.currentSeed = tostring(seedStr or "DEFAULT")
    local rng = makeRNG(seedStr)

    -- Selección del arquetipo espectral
    local numArch = #ARCHETYPES
    local archIdx = math.floor(rng() * numArch) + 1
    if archIdx > numArch then archIdx = numArch end
    local arch = ARCHETYPES[archIdx]
    HyperspaceTunnel.config.themeName = arch.name

    local function jitterColor(rgb, amount)
        local amt = amount or 0.03
        return {
            math.max(0.0, math.min(1.0, rgb[1] + (rng() - 0.5) * amt)),
            math.max(0.0, math.min(1.0, rgb[2] + (rng() - 0.5) * amt)),
            math.max(0.0, math.min(1.0, rgb[3] + (rng() - 0.5) * amt))
        }
    end

    proceduralState.seedOffset = rng() * 1000.0

    -- Asignación de los 6 colores espectrales dinámicos
    proceduralState.col1    = jitterColor(arch.col1, 0.03)
    proceduralState.col2    = jitterColor(arch.col2, 0.04)
    proceduralState.col3    = jitterColor(arch.col3, 0.04)
    proceduralState.col4    = jitterColor(arch.col4, 0.03)
    proceduralState.col5    = jitterColor(arch.col5, 0.04)
    proceduralState.col6    = jitterColor(arch.col6, 0.03)
    proceduralState.colPeak = jitterColor(arch.colPeak, 0.02)

    proceduralState.spaceVoid  = arch.spaceVoid
    proceduralState.dustColor  = arch.dust
    proceduralState.coreColor  = arch.core
    proceduralState.flareColor = arch.flare

    -- Parámetros de nubes y estelas
    local c = arch.cloud
    proceduralState.cloudParams = {
        c[1] * (0.92 + rng() * 0.16),
        c[2] * (0.90 + rng() * 0.20),
        c[3] * (0.85 + rng() * 0.30),
        c[4] * (0.95 + rng() * 0.15)
    }

    local s = arch.streak
    proceduralState.streakParams = {
        math.max(0.20, math.min(0.65, s[1] + (rng() - 0.5) * 0.15)),
        math.max(0.25, math.min(0.75, s[2] + (rng() - 0.5) * 0.20)),
        s[3] * (0.88 + rng() * 0.25),
        s[4] * (0.90 + rng() * 0.20)
    }

    print(string.format("★ HyperspaceTunnel: Generated sector '%s' [Archetype: %s]", tostring(seedStr), arch.name))
end

-- Asignar arquetipo explícito para previsualizaciones y control determinista
function HyperspaceTunnel.setArchetype(archIdx)
    local idx = math.max(1, math.min(#ARCHETYPES, archIdx or 1))
    local arch = ARCHETYPES[idx]
    HyperspaceTunnel.config.themeName = arch.name
    proceduralState.col1 = arch.col1
    proceduralState.col2 = arch.col2
    proceduralState.col3 = arch.col3
    proceduralState.col4 = arch.col4
    proceduralState.col5 = arch.col5
    proceduralState.col6 = arch.col6
    proceduralState.colPeak = arch.colPeak
    proceduralState.spaceVoid = arch.spaceVoid
    proceduralState.dustColor = arch.dust
    proceduralState.coreColor = arch.core
    proceduralState.flareColor = arch.flare
    proceduralState.cloudParams = arch.cloud
    proceduralState.streakParams = arch.streak
    print(string.format("★ HyperspaceTunnel: Explicit archetype set: %s", arch.name))
end

-- Código del shader GLSL para LÖVE
local shaderSource = [[
    #ifdef GL_ES
    #ifdef GL_FRAGMENT_PRECISION_HIGH
    precision highp float;
    #else
    precision mediump float;
    #endif
    #endif

    extern float u_time;
    extern float u_flowPos;
    extern vec2 u_resolution;
    extern vec2 u_center;
    extern float u_speed;
    extern float u_direction;
    extern float u_progress;
    extern float u_alpha;
    extern float u_seedOffset;

    // 6 Colores del espectro nebular multidimensional
    extern vec3 u_col1;
    extern vec3 u_col2;
    extern vec3 u_col3;
    extern vec3 u_col4;
    extern vec3 u_col5;
    extern vec3 u_col6;
    extern vec3 u_colPeak;

    // Entorno y singularidad
    extern vec3 u_spaceVoid;
    extern vec3 u_dustColor;
    extern vec3 u_coreColor;
    extern vec3 u_flareColor;

    // Parámetros procedurales
    extern vec4 u_cloudParams;  // x: density, y: turbScale, z: dustVeinStrength, w: contrast
    extern vec4 u_streakParams; // x: density, y: length, z: speedMul, w: sharpness

    // Hash 3D rápido y de alta dispersión
    float hash31(vec3 p) {
        p = fract(p * vec3(443.897, 441.423, 437.195));
        p += dot(p, p.yzx + 19.19);
        return fract((p.x + p.y) * p.z);
    }

    // Ruido tridimensional continuo (Value noise trilineal)
    float noise3D(vec3 p) {
        vec3 i = floor(p);
        vec3 f = fract(p);
        vec3 u = f * f * (3.0 - 2.0 * f);

        float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
        float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
        float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
        float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
        float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
        float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
        float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
        float n111 = hash31(i + vec3(1.0, 1.0, 1.0));

        return mix(
            mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
            mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y),
            u.z
        );
    }

    // FBM 3D estándar de 4 octavas
    float fbm3D(vec3 p) {
        float v = 0.0;
        float a = 0.5;
        vec3 shift = vec3(100.0);
        for (int i = 0; i < 4; i++) {
            v += a * noise3D(p);
            p = p * 2.04 + shift;
            a *= 0.5;
        }
        return v;
    }

    // FBM Celular Billowy (lóbulos y racimos cúmulos de nubes cósmicas)
    float billowFBM(vec3 p) {
        float v = 0.0;
        float a = 0.5;
        vec3 shift = vec3(50.0);
        for (int i = 0; i < 4; i++) {
            float n = noise3D(p);
            v += a * (1.0 - abs(n - 0.5) * 2.0);
            p = p * 2.02 + shift;
            a *= 0.5;
        }
        return v;
    }

    vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 screen_coords) {
        // Coordenadas normalizadas centradas en el punto de fuga
        vec2 p = (screen_coords - u_center) / u_resolution.y;

        // Micro-deriva orgánica de la cámara (sensación de inercia y vuelo en gravedad cero)
        vec2 camFloat = vec2(sin(u_time * 0.38) * 0.007, cos(u_time * 0.28) * 0.004);
        p += camFloat;

        float r = length(p);
        float angle = atan(p.y, p.x);

        // 1. Proyección hiperbólica con offset suave (sin singularidades numéricas en r -> 0)
        float zDepth = 1.0 / (r + 0.038);
        float z = pow(zDepth, 0.84);

        // Rotación orbital y torsión vórtice suave
        float roll = u_time * 0.06 + u_flowPos * 0.012;
        float twist = z * 0.035;
        float a = angle + roll + twist;

        // Coordenada continua de desplazamiento a lo largo del túnel
        float flow = u_flowPos * u_direction;
        float zCoord = z * 0.20 + flow * 0.55;

        // Coordenadas cilíndricas tridimensionales continuas
        vec3 cyl = vec3(cos(a) * 1.25, sin(a) * 1.25, zCoord);

        // 2. Dinámica de fluidos cósmicos con doble Domain Warping (vorticidad y volutas de humo/seda)
        vec3 warp1 = vec3(
            noise3D(cyl * 0.85 + vec3(u_seedOffset, 0.0, flow * 0.08)),
            noise3D(cyl * 0.85 + vec3(3.7 + u_seedOffset, 1.4, -flow * 0.07)),
            noise3D(cyl * 0.85 + vec3(1.2, 7.8 + u_seedOffset, flow * 0.09))
        ) - 0.5;

        vec3 pWarp = cyl * u_cloudParams.y + warp1 * 0.90;

        // Segunda capa de advección fluida: crea suaves espirales y filamentos
        vec3 warp2 = vec3(
            noise3D(pWarp * 1.35 + vec3(5.1, 8.2, u_time * 0.04)),
            noise3D(pWarp * 1.35 + vec3(9.3, 2.7, -u_time * 0.035)),
            noise3D(pWarp * 1.35 + vec3(1.7, 4.4, u_time * 0.045))
        ) - 0.5;

        vec3 pFluid = pWarp + warp2 * 0.40;

        // Morfología: Billow FBM suave + FBM continuo (aspecto aterciopelado)
        float baseNoise = fbm3D(pFluid * 1.05);
        float billows   = billowFBM(pFluid * 1.25 + vec3(5.2, 2.1, 7.3));
        float rawCloud  = baseNoise * 0.50 + billows * 0.50;

        // Densidad neta de gas cósmico con transiciones aterciopeladas
        float cloudDensity = smoothstep(0.24, 0.72, rawCloud * u_cloudParams.x);
        cloudDensity = pow(cloudDensity, u_cloudParams.w);

        // Vetas de absorción de polvo cósmico frío
        vec3 dustPos = pFluid * 1.30 + vec3(18.2 + u_seedOffset, 4.3, 9.1);
        float dustNoise = fbm3D(dustPos);
        float dustVein = smoothstep(0.34, 0.80, dustNoise) * u_cloudParams.z;

        float gasEmission = cloudDensity * (1.0 - dustVein * 0.80);

        // 3. Distribución cromática astrofísica armónica (Atmósfera Primaria + Corrientes de Acento)
        // Gas Primario: sombreado volumétrico dimensional según densidad (Sombra -> Cuerpo -> Cresta)
        float primShade = smoothstep(0.18, 0.65, cloudDensity);
        vec3 colPrimary = mix(u_col1, u_col2, primShade);
        colPrimary = mix(colPrimary, u_col3, smoothstep(0.55, 0.90, cloudDensity));

        // Gas de Acento (Secundario): sombreado volumétrico dimensional según densidad
        float accShade = smoothstep(0.18, 0.65, cloudDensity);
        vec3 colAccent = mix(u_col4, u_col5, accShade);
        colAccent = mix(colAccent, u_col6, smoothstep(0.55, 0.90, cloudDensity));

        // Corrientes cósmicas tridimensionales que entrelazan los dos gases orgánicamente
        float streamNoise = fbm3D(pFluid * 0.65 + vec3(u_seedOffset, 2.5, zCoord * 0.08));
        float streamLobe  = sin(a * 2.0 + zCoord * 0.28 + u_seedOffset) * 0.32;
        float streamField = streamNoise + streamLobe;
        float accentWeight = smoothstep(0.48, 0.76, streamField);

        // Mezcla física entre el gas primario y los ríos de gas de acento
        vec3 gasBaseCol = mix(colPrimary, colAccent, accentWeight);

        // Iluminación estelar frontal (forward scattering hacia la singularidad)
        float forwardScatter = exp(-r * 6.0) * pow(cloudDensity, 1.2);
        vec3 cloudColor = mix(gasBaseCol, u_colPeak, clamp(forwardScatter * 0.65, 0.0, 0.85));

        // Composición de pared del túnel: gas emisor sobre el vacío cósmico profundo
        vec3 tunnelWall = mix(u_spaceVoid, cloudColor * (1.12 + forwardScatter * 0.35), gasEmission);
        tunnelWall = mix(tunnelWall, u_dustColor, dustVein * cloudDensity * 0.70);

        // Apertura central suave del túnel
        float wallFade = smoothstep(0.025, 0.19, r);
        vec3 cloudsOut = tunnelWall * wallFade;

        // 4. Rayos Crepusculares Volumétricos Majestuosos (Broad Ethereal Light Shafts)
        float rayAngle = angle + roll * 0.25;
        float ray1 = sin(rayAngle * 5.0 + u_time * 0.12) * 0.5 + 0.5;
        float ray2 = sin(rayAngle * 8.0 - u_time * 0.09 + 1.2) * 0.5 + 0.5;
        float ray3 = cos(rayAngle * 3.0 + u_time * 0.06) * 0.5 + 0.5;
        float godRays = pow(ray1 * 0.45 + ray2 * 0.35 + ray3 * 0.20, 3.2);

        float rayFalloff = exp(-r * 3.4) * smoothstep(1.35, 0.05, r);
        vec3 rayTint = mix(vec3(1.0, 0.97, 0.92), gasBaseCol, 0.35);
        vec3 rayLight = rayTint * godRays * rayFalloff * 1.6 * (1.1 - cloudDensity * 0.50);

        // 5. Estelas de Luz de Seda y Micro-Brasas (Laminar Silk Streams, sutiles y elegantes)
        float streakSector = a * 14.0;
        float streakFract  = fract(streakSector);
        float streakId     = floor(streakSector);
        float streakRand   = fract(sin(streakId * 73.15 + u_seedOffset) * 43758.5453);

        vec3 streaksOut = vec3(0.0);
        if (streakRand > 0.74) {
            float distFromCenter = abs(streakFract - 0.5);
            float filamentProfile = exp(-distFromCenter * distFromCenter * 50.0);
            float filamentGlow = exp(-distFromCenter * 10.0) * 0.25;
            float totalCrossSection = filamentProfile + filamentGlow;

            float filamentSpeed = 0.60 + streakRand * 0.30;
            float filamentZ = fract(z * 0.24 + flow * 0.32 * filamentSpeed + streakRand);
            float tail = smoothstep(0.0, 0.18, filamentZ) * smoothstep(0.90, 0.20, filamentZ);

            float filamentIntensity = totalCrossSection * tail * smoothstep(0.06, 0.32, r) * smoothstep(1.30, 0.60, r);
            vec3 filamentColor = mix(gasBaseCol * 1.3, vec3(1.0, 0.98, 0.92), 0.55);
            streaksOut = filamentColor * filamentIntensity * 0.95;
        }

        // Micro-brasas cósmicas flotando suavemente en paralaje
        float emberSector = a * 20.0;
        float emberId = floor(emberSector);
        float emberRand = fract(sin(emberId * 113.7 + u_seedOffset * 1.5) * 31415.9);
        if (emberRand > 0.88) {
            float emberZ = fract(z * 0.32 + flow * 0.45 + emberRand);
            float emberTrail = smoothstep(0.0, 0.10, emberZ) * smoothstep(0.40, 0.10, emberZ);
            float emberDot = exp(-pow(abs(fract(emberSector) - 0.5) * 8.0, 2.0));
            vec3 emberCol = mix(gasBaseCol, u_colPeak, emberRand);
            streaksOut += emberCol * emberDot * emberTrail * smoothstep(0.08, 0.35, r) * 0.70;
        }

        // 6. Singularidad Central Deslumbrante (Blinding White-Hot Singularity)
        float coreR = r;
        float coreInner = exp(-coreR * 42.0);
        float coreMid   = exp(-coreR * 14.0);
        float coreAura  = 0.0035 / (coreR * coreR + 0.0018);
        vec3 coreLight = u_coreColor * coreInner * 3.8 +
                         mix(u_coreColor, u_flareColor, 0.30) * coreMid * 1.6 +
                         u_flareColor * coreAura * 0.35;

        // 7. Destello Anamórfico Horizontal (Anamorphic Lens Flare)
        float flareY = abs(p.y);
        float flareX = abs(p.x);
        float flareCore = exp(-flareY * 85.0) * exp(-flareX * 3.2);
        float flareGlow = exp(-flareY * 22.0) * exp(-flareX * 1.6) * 0.25;
        vec3 flareLight = u_flareColor * (flareCore + flareGlow) * 1.4;

        // 8. Composición Multicapa
        vec3 finalColor = cloudsOut + rayLight + streaksOut + coreLight + flareLight;

        // 9. Viñeta Cinematográfica (Enmarca el túnel con oscuridad espacial en los bordes)
        float vignette = smoothstep(1.45, 0.45, length(p));
        finalColor *= vignette;

        // 10. ACES Filmic Tone Mapping (Conserva el contraste profundo y el resplandor cálido)
        vec3 x = max(vec3(0.0), finalColor);
        vec3 tonemapped = (x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14);

        // Dither sutil para evitar cualquier banding de 8 bits
        float dither = (fract(sin(dot(screen_coords, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
        tonemapped += dither;

        return vec4(clamp(tonemapped, 0.0, 1.0), u_alpha * vcolor.a);
    }
]]

-- Inicialización del shader
function HyperspaceTunnel.init()
    if initialized and shader then return true end
    if not love or not love.graphics then return false end

    local success, result = pcall(function()
        return love.graphics.newShader(shaderSource)
    end)

    if success then
        shader = result
        initialized = true
        print("✓ HyperspaceTunnel: Destiny 2 procedural warp tunnel shader compiled successfully")
        HyperspaceTunnel.setSeed(HyperspaceTunnel.config.currentSeed)
    else
        print("✗ HyperspaceTunnel: Shader compilation failed: " .. tostring(result))
        shader = nil
        initialized = false
        return false
    end

    if not dummyImage then
        local imgData = love.image.newImageData(1, 1)
        imgData:setPixel(0, 0, 1, 1, 1, 1)
        dummyImage = love.graphics.newImage(imgData)
    end

    return true
end

-- Actualización temporal y velocidad
function HyperspaceTunnel.update(dt, progress)
    local p = progress or 0
    HyperspaceTunnel.config.time = HyperspaceTunnel.config.time + dt
    local speed = HyperspaceTunnel.config.baseSpeed + HyperspaceTunnel.config.maxSpeedBoost * (p ^ 1.2)
    HyperspaceTunnel.config.flowPos = (HyperspaceTunnel.config.flowPos or 0) + speed * dt
end

-- Renderizado a pantalla completa del túnel hiperespacial
function HyperspaceTunnel.draw(cx, cy, width, height, alpha, progress)
    if not initialized or not shader then
        if not HyperspaceTunnel.init() then return false end
    end

    local p = progress or 0
    local speed = HyperspaceTunnel.config.baseSpeed + HyperspaceTunnel.config.maxSpeedBoost * (p ^ 1.2)
    local time = HyperspaceTunnel.config.time
    local flowPos = HyperspaceTunnel.config.flowPos or (time * speed)

    love.graphics.setShader(shader)

    -- Envío seguro de uniforms dinámicos
    if shader:hasUniform("u_time") then
        shader:send("u_time", time)
    end
    if shader:hasUniform("u_flowPos") then
        shader:send("u_flowPos", flowPos)
    end
    if shader:hasUniform("u_resolution") then
        shader:send("u_resolution", {width, height})
    end
    if shader:hasUniform("u_center") then
        shader:send("u_center", {cx, cy})
    end
    if shader:hasUniform("u_speed") then
        shader:send("u_speed", speed)
    end
    if shader:hasUniform("u_direction") then
        shader:send("u_direction", HyperspaceTunnel.config.direction or 1.0)
    end
    if shader:hasUniform("u_progress") then
        shader:send("u_progress", p)
    end
    if shader:hasUniform("u_alpha") then
        shader:send("u_alpha", alpha or 1.0)
    end
    if shader:hasUniform("u_seedOffset") then
        shader:send("u_seedOffset", proceduralState.seedOffset)
    end

    -- Envío del espectro cromático de 6 bandas
    if shader:hasUniform("u_col1") then
        shader:send("u_col1", proceduralState.col1)
    end
    if shader:hasUniform("u_col2") then
        shader:send("u_col2", proceduralState.col2)
    end
    if shader:hasUniform("u_col3") then
        shader:send("u_col3", proceduralState.col3)
    end
    if shader:hasUniform("u_col4") then
        shader:send("u_col4", proceduralState.col4)
    end
    if shader:hasUniform("u_col5") then
        shader:send("u_col5", proceduralState.col5)
    end
    if shader:hasUniform("u_col6") then
        shader:send("u_col6", proceduralState.col6)
    end
    if shader:hasUniform("u_colPeak") then
        shader:send("u_colPeak", proceduralState.colPeak)
    end

    -- Vacío interestelar, polvo oscuro y singularidad
    if shader:hasUniform("u_spaceVoid") then
        shader:send("u_spaceVoid", proceduralState.spaceVoid)
    end
    if shader:hasUniform("u_dustColor") then
        shader:send("u_dustColor", proceduralState.dustColor)
    end
    if shader:hasUniform("u_coreColor") then
        shader:send("u_coreColor", proceduralState.coreColor)
    end
    if shader:hasUniform("u_flareColor") then
        shader:send("u_flareColor", proceduralState.flareColor)
    end

    -- Parámetros de morfología de nubes y estela
    if shader:hasUniform("u_cloudParams") then
        shader:send("u_cloudParams", proceduralState.cloudParams)
    end
    if shader:hasUniform("u_streakParams") then
        shader:send("u_streakParams", proceduralState.streakParams)
    end

    -- Renderizar quad a pantalla completa
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
    love.graphics.rectangle("fill", 0, 0, width, height)

    love.graphics.setShader()
    return true
end

function HyperspaceTunnel.getShader()
    return shader
end

function HyperspaceTunnel.isInitialized()
    return initialized
end

function HyperspaceTunnel.getThemeName()
    return HyperspaceTunnel.config.themeName
end

return HyperspaceTunnel
