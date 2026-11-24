-- src/shaders/nebulas_shaders.lua
-- Sistema especializado para gestión de shaders de nebulosas

local NebulasShaders = {}

-- Estado del sistema de shaders de nebulosas
NebulasShaders.state = {
    shader = nil,
    initialized = false,
    uniforms = {
        -- Uniforms vectoriales empaquetados (Fase 4: Batching y reducción de draw calls)
        u_time = 0.0,
        u_params1 = {0.0, 2.8, 0.75, 1.35},
        u_params2 = {0.18, 1.45, 0.85, 0.15},
        u_params3 = {0.85, 0.0, 0.35, 0.0},
        u_coreColor = {1.0, 1.0, 1.0},
        -- Aliases escalares mantenidos para total retrocompatibilidad y telemetría
        u_seed = 0.0,
        u_noiseScale = 2.8,
        u_warpAmp = 0.75,
        u_warpFreq = 1.35,
        u_softness = 0.18,
        u_intensity = 0.85,
        u_brightness = 1.45,
        u_parallax = 0.85,
        u_sparkleStrength = 0.15,
        u_morphology = 0.0,    -- 0: Difusa clásica, 1: Anular, 2: Bipolar, 3: Filamentosa
        u_irregularity = 0.35  -- Desgarro/irregularidad en bordes
    }
}

-- Buffers persistentes preasignados para evitar asignaciones de tabla por fotograma (GC-free)
local _packedP1 = {0.0, 2.8, 0.75, 1.35}
local _packedP2 = {0.18, 1.45, 0.85, 0.15}
local _packedP3 = {0.85, 0.0, 0.35, 0.0}
local _packedCore = {1.0, 1.0, 1.0}

-- Código del shader de nebulosas con efectos avanzados
local nebulaShaderCode = [[
    extern float u_time;
    // Fase 4: Uniforms agrupados en vectores vec4 (reduce llamadas a glUniform en más de 70%)
    extern vec4 u_params1; // x: seed, y: noiseScale, z: warpAmp, w: warpFreq
    extern vec4 u_params2; // x: softness, y: brightness, z: parallax, w: sparkleStrength
    extern vec4 u_params3; // x: intensity, y: morphology, z: irregularity, w: speedMultiplier
    extern vec3 u_coreColor; // Color armónico del núcleo (Dual-Tone)

    #define u_seed            (u_params1.x)
    #define u_noiseScale      (u_params1.y)
    #define u_warpAmp         (u_params1.z)
    #define u_warpFreq        (u_params1.w)

    #define u_softness        (u_params2.x)
    #define u_brightness      (u_params2.y)
    #define u_parallax        (u_params2.z)
    #define u_sparkleStrength (u_params2.w)

    #define u_intensity       (u_params3.x)
    #define u_morphology      (u_params3.y)
    #define u_irregularity    (u_params3.z)
    #define u_speed           (u_params3.w)

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
            p *= 2.0;
            a *= 0.5;
        }
        return v;
    }
    
    vec2 domainWarp(vec2 p, float t, vec2 seedOff) {
        float f = max(0.0001, u_warpFreq);
        vec2 q = vec2(
            fbm(p * f + t + seedOff),
            fbm(p * f - t + seedOff + vec2(13.37, 7.19))
        );
        q = (q - 0.5) * 2.0;
        return p + q * u_warpAmp;
    }
    
    extern float u_volumeLight;
    extern vec4 u_regionLight; // XY en coordenadas locales, ZW en radios de iluminación
    extern vec4 u_embeddedLight; // ZW son cero si sólo ilumina la región
    extern vec4 u_gasBand;
    extern vec4 u_frontBand;
    extern vec3 u_outerBand;
    extern float u_dustDetailScale;
    extern float u_cloudBalance;
    extern int u_materialView;
    extern Image u_dustGrain;
    extern vec4 u_structure[6];
    float shapeDensity(vec2 uv,float r,vec2 p,float n) {
        float cloud = smoothstep(0.24, 0.90, n);
        float centerBoost = (1.0-smoothstep(0.0,1.0,r));

        // Modulación morfológica procedural:
        // 0: Difusa clásica (núcleo denso con halo suave)
        // 1: Anular (Ring/Burbuja con centro semivacío y borde luminoso)
        // 2: Bipolar (Reloj de arena / Lóbulos en alas de mariposa)
        // 3: Filamentosa (Velo cósmico con estrías turbulentas)
        float morph = clamp(u_morphology, 0.0, 3.0);
        float density = cloud * (0.80 + 0.45 * centerBoost);

        if (morph > 0.5 && morph < 1.5) {
            // Anular / Bubble
            float ringFactor = smoothstep(0.0, 0.42, r) * (1.0-smoothstep(.48,1.0,r));
            density = cloud * (0.28 + 1.35 * ringFactor);
        } else if (morph >= 1.5 && morph < 2.5) {
            // Bipolar
            float angle = atan(uv.y, uv.x);
            float lobe = pow(abs(cos(angle)), 1.6);
            float bipolarFactor = 0.35 + 0.95 * lobe * smoothstep(0.08, 0.75, r);
            density = cloud * (0.45 + 0.85 * bipolarFactor);
        } else if (morph >= 2.5) {
            // Filamentosa
            float filNoise = fbm(p * 2.3);
            float filFactor = pow(abs(sin(filNoise * 6.28)), 1.6);
            density = cloud * (0.48 + 1.05 * filFactor);
        }

        return density;
    }

    // Derivada del mismo ruido cúbico. La tangente sigue el pliegue del gas.
    vec2 foldTangent(vec2 p) {
        vec2 cell = floor(p), f = fract(p);
        vec2 w = f*f*(3.0-2.0*f), slope = 6.0*f*(1.0-f);
        float a = hash(cell), b = hash(cell+vec2(1,0));
        float c = hash(cell+vec2(0,1)), d = hash(cell+vec2(1,1));
        return vec2(mix(c-a,d-b,w.x)*slope.y,-mix(b-a,d-c,w.y)*slope.x);
    }

    vec4 dustNoise(vec2 p) {
        vec2 cell = floor(p), f = fract(p);
        return Texel(u_dustGrain,(cell+f*f*(3.0-2.0*f)+.5)/128.0);
    }

    struct DustBed {
        float bank;
        float clumping;
        float wingFraction;
        vec2 grainOffset;
    };

    vec2 streamCoordinates(vec2 offset, vec2 axis, float span, float bend) {
        float along = dot(offset,axis);
        float forward = clamp(along/span,0.0,1.2);
        return vec2(along, dot(offset,vec2(-axis.y,axis.x))-bend*span*forward*forward);
    }

    // Masa, pared iluminable y distancia elíptica. El polvo
    // se acumula en la ladera exterior de la pared que mira hacia el nudo.
    vec3 plume(vec2 offset, vec2 axis, float span, float breadth, float bend, float cavity,
               vec2 knotOffset, out float bank) {
        vec2 coords = streamCoordinates(offset,axis,span,bend);
        float t = coords.x/span, side = coords.y;
        vec2 normal = vec2(-axis.y,axis.x);
        float width = breadth*mix(.20+.35*u_structure[5].w,1.0,smoothstep(-.21,.49,t));
        vec2 crossSection = vec2((t-.38)/.67,side/width);
        float d = dot(crossSection,crossSection);
        float skirt = exp2(-(2.75-1.4*clamp(u_softness,0.0,.95))*d)*(1.0-smoothstep(1.05,2.7,d));
        vec2 outskirts = vec2((t-.28)/.92,side/(width+.12+.19*breadth));
        float mist = .13*exp2(-1.55*dot(outskirts,outskirts));
        float hollow = cavity*smoothstep(-.02,.35,t)*(1.0-smoothstep(.06,.69,d));
        float wall = .64*(1.0-smoothstep(.012,.25,abs(d-.52)))
                   + .55*(1.0-smoothstep(.006,.09,abs(d-.55)))
                   + .40*(1.0-smoothstep(.006,.13,abs(d-.83)));
        float flank = dot(knotOffset,normal) < 0.0 ? -1.0 : 1.0;
        float shoulder = smoothstep(.43,.72,d)*(1.0-smoothstep(.83,1.48,d));
        bank = shoulder*(.28+.72*cavity)*smoothstep(-.30,.48,flank*crossSection.y)
             * smoothstep(-.24,.04,t)*(1.0-smoothstep(.73,1.04,t));
        return vec3(.92*skirt*(1.0-hollow)+mist+.17*cavity*wall,wall*cavity,d);
    }

    vec4 gasStructure(vec2 uv, vec2 seedOff, out float outskirts, out DustBed bed) {
        vec4 billow = dustNoise(uv*2.15+seedOff);
        vec2 detailUV = uv*6.7 + seedOff.yx + 1.6*(billow.ba-.5);
        vec2 wrinkles = dustNoise(detailUV).ba-.5;
        float ripple = u_structure[5].z*(.70+.85*clamp(u_irregularity,0.0,.75));
        vec2 folded = uv + ripple*(1.45*(billow.rg-.5)+.66*wrinkles
                      +.20*(dustNoise(detailUV*2.8+wrinkles).rg-.5));
        float guard = 1.0-smoothstep(.63,1.0,max(dot(uv,uv),dot(folded,folded)));
        vec2 offset = folded-u_structure[0].xy;
        vec4 main = u_structure[1], wing = u_structure[2], mixWing = u_structure[3];
        vec2 axis = u_structure[0].zw, knotOffset = u_structure[4].xy-u_structure[0].xy;
        float mainBank, wingBank;
        vec3 a = plume(offset,axis,main.x,main.y,main.z,main.w,knotOffset,mainBank);
        vec3 b = plume(offset,wing.xy,wing.z,wing.w,mixWing.x,main.w*.62,knotOffset,wingBank);
        vec2 toKnot = (folded-u_structure[4].xy)/u_structure[4].z;
        float knot = u_structure[4].w*exp2(-2.3*dot(toKnot,toKnot));
        // Una cavidad o una grieta pueden ser tenues y seguir dentro de la nube.
        float wingBody = (1.0-smoothstep(.59,1.76,b.z))*smoothstep(.08,.49,mixWing.y);
        outskirts = min(smoothstep(.59,1.76,a.z),1.0-wingBody)*(1.0-smoothstep(.055,.32,knot));
        float wingMass = b.x*mixWing.y;
        float overlap = min(a.x,wingMass);
        float gas = max(max(a.x,wingMass),knot)+.12*overlap;
        // Gas tenue entre la raíz y el nudo. Su espesor acompaña al material
        // vecino y permite que se siga viendo gas delante de una hendidura.
        float alongKnot = clamp(dot(offset,knotOffset)/max(.001,dot(knotOffset,knotOffset)),0.0,1.0);
        vec2 gap = offset-alongKnot*knotOffset;
        float bridge = exp2(-dot(gap,gap)*28.0)*alongKnot*(1.0-alongKnot)
                     * smoothstep(0.0,.12,u_structure[4].w)*(.55+.85*billow.b);
        gas += bridge*smoothstep(.025,.30,a.x+wingMass+knot)
                   *(1.0-smoothstep(.10,.70,gas));
        // En la unión sólo hay cresta donde ambas corrientes aportan masa comparable.
        float join = smoothstep(.12,.45,overlap)*(1.0-smoothstep(.035,.33,abs(a.x-wingMass)))
                   * smoothstep(.035,.19,length(offset));
        float bank = max(mainBank,wingBank*mixWing.y);
        bed.clumping = .60*billow.b+.40*(wrinkles.x+.5);
        bed.bank = (bank + (1.0-bank)*.38*join)*(.60+.54*smoothstep(.23,.76,bed.clumping));
        bed.wingFraction = smoothstep(-.18,.18,wingMass-a.x);
        bed.grainOffset = uv-u_structure[0].xy+.62*ripple*(billow.rg-.5);
        // Frente molecular en el lado posterior de la raíz. El ala y el nudo
        // orientan el borde según la geometría de cada nube.
        vec2 rear = normalize(-axis+.55*knotOffset);
        float reach = dot(offset,rear);
        float across = dot(offset,vec2(-rear.y,rear.x));
        float width = main.y*(.075+.68*max(reach,0.0))+.014;
        float rim = (across-main.z*reach*reach+.025*wrinkles.y)/width;
        float rootFront = exp2(-rim*rim)*smoothstep(-.09,.08,reach)
                        *(1.0-smoothstep(.23,.56,reach))*mixWing.z;
        vec4 field = guard*vec4(gas, max(a.y,b.y*mixWing.y), rootFront, knot);
        // Una columna casi transparente se desvanece antes de integrar los ocho estratos.
        return field*smoothstep(.024,.063,field.x);
    }

    float dustCover(DustBed bed, float rootFront, float density, float gasNoise) {
        // En el interior también se ve polvo fino en los pliegues del propio gas.
        float fold = .76*gasNoise+.24*bed.clumping;
        float crease = 1.0-smoothstep(.018,.13,abs(fold-.53));
        float diffuseDust = smoothstep(.25,.72,density)*(.03+.13*smoothstep(.47,.71,fold)+.10*crease);
        return smoothstep(.055,.46,density)*(diffuseDust+1.18*bed.bank)+rootFront;
    }

    // Masa de gas y columna de polvo en un punto del trayecto hacia la fuente.
    vec2 sampleLightPath(vec2 uv, vec2 seedOff, float ns, float t, float abundance, bool coarse) {
        if (dot(uv,uv) >= 1.0) return vec2(0.0);
        DustBed bed;
        float outskirts;
        vec4 field = gasStructure(uv,seedOff,outskirts,bed);
        if (field.x < .00015) return vec2(0.0);
        // La muestra lejana usa las acumulaciones anchas del mismo campo de gas.
        float n = coarse ? bed.clumping : fbm(domainWarp(uv*ns+seedOff,t,seedOff));
        float density = field.x*(.36+.82*smoothstep(.18,.86,n));
        return vec2(density,abundance*dustCover(bed,field.z,density,n));
    }

    vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
        vec2 uv = texcoord * 2.0 - 1.0;

        // Desfase 2D único derivado de la semilla:
        // Asegura que cada nebulosa muestree una porción completamente distinta del campo de ruido fractal
        vec2 seedOff = vec2(
            sin(u_seed * 19.173 + 1.23) * 380.0,
            cos(u_seed * 27.831 + 4.56) * 380.0
        );

        // Perturbación del borde para silueta orgánica rasgada
        float irregular = clamp(u_irregularity, 0.0, 0.75);
        float radius = length(uv);
        float r = radius;
        float mask = 1.0;
        vec4 structure = vec4(0.0);
        float outskirts = 0.0;
        DustBed bed;
        if (u_volumeLight != 0.0) {
            if (radius >= 1.0 || color.a <= 0.0) return vec4(0.0);
            structure = gasStructure(uv,seedOff,outskirts,bed);
            if (structure.x < .00015) return vec4(0.0);
        } else {
            if (radius > 1.0+.25*irregular) return vec4(0.0);
            float edgeNoise = fbm(uv*2.2+seedOff*.15);
            r += (edgeNoise-.5)*irregular*.50;
            mask = 1.0-smoothstep(1.0-clamp(u_softness,0.0,.95),1.0,r);
            if (mask <= .0001) return vec4(0.0);
        }

        // Movimiento sutil y dependiente de parallax (reducido para un comportamiento cósmico majestuoso)
        float par = clamp(u_parallax, 0.0, 1.0);
        float speedFactor = (u_speed > 0.0) ? u_speed : 1.0;
        float t = u_time * mix(0.0035, 0.0080, par) * speedFactor;

        float ns = max(0.0001, u_noiseScale);
        vec2 p = uv * ns + seedOff;
        p = domainWarp(p, t, seedOff);
        float n = fbm(p);

        if (u_volumeLight != 0.0) {
            float density = structure.x*(.36+.82*smoothstep(.18,.86,n));
            bool embedded = u_embeddedLight.z > 0.0;
            vec4 keyLight = embedded ? u_embeddedLight : u_regionLight;
            vec2 toward = keyLight.xy - uv;
            vec2 lightDirection = toward/max(1.0,length(toward));
            vec2 curl = foldTangent(p*.8);
            vec2 folds = p*2.4 + curl*(.35+.32*sin(seedOff.y));
            float ridges = .5+.45*sin(seedOff.x);
            float abundance = clamp(u_gasBand.a/.80,0.0,1.0);
            float cover = abundance*dustCover(bed,structure.z,density,n);
            vec2 nearSample = sampleLightPath(uv+.22*lightDirection,seedOff,ns,t,abundance,false);
            vec2 farSample = sampleLightPath(uv+.62*lightDirection,seedOff,ns,t,abundance,true);
            float obstruction = nearSample.x, ahead = nearSample.y;
            // La primera muestra también orienta la cara iluminada. La segunda
            // atenúa sólo la luz directa que atraviesa ese tramo de la nube.
            float interveningDepth = .40*length(lightDirection)*dot(farSample,vec2(.35,2.8));
            float surface = smoothstep(-.06,.30,density-obstruction);
            float dustLoad = smoothstep(.80,1.30,u_gasBand.a);
            float dustOpacity = mix(4.2,9.0,dustLoad);
            // El polvo sigue las mismas coordenadas deformadas a todas las escalas.
            // El grano fino sólo modifica el material donde ya existe una columna.
            vec2 materialP = mix(uv*ns,p-seedOff,.26);
            vec2 fleckP = materialP*13.0+seedOff+.28*curl;
            vec4 tuft = dustNoise(fleckP);
            // Cada corriente lleva sus propias hebras. En el cruce se mezclan sus
            // densidades ya muestreadas para conservar la escala física del tejido.
            vec2 grainScale = ns*u_dustDetailScale*vec2(17.0,32.0);
            vec2 phase = seedOff.yx+.64*(tuft.ba-.5);
            vec2 mainUV = streamCoordinates(bed.grainOffset,u_structure[0].zw,u_structure[1].x,u_structure[1].z);
            vec2 wingUV = streamCoordinates(bed.grainOffset,u_structure[2].xy,u_structure[2].z,u_structure[3].x);
            vec4 fine = mix(dustNoise(mainUV*grainScale+phase),dustNoise(wingUV*grainScale-phase),bed.wingFraction);
            float grainTip = dustNoise(bed.grainOffset*(ns*68.0*u_dustDetailScale)+seedOff+.85*fine.ba).b;
            float fleck = .58*tuft.g+.22*fine.g+.20*grainTip;
            float inBank = smoothstep(.08,.85,bed.bank+structure.z);
            float localColumn = cover*(.68+.45*tuft.r+.16*fine.g+.20*dustLoad);
            float furrow = tuft.r-dustNoise(fleckP+.72*lightDirection).r;
            float relief = smoothstep(-.47,.47,furrow);
            float slope = (cover-ahead)/(.34+cover)+.34*(density-obstruction);
            float dustFace = smoothstep(-.18,.71,slope+.37*(fleck-.5));
            float shadowPath = mix(2.7,.14,dustFace)*localColumn+.52*ahead;
            float exposed = (.04+.96*dustFace)*(.64+.50*relief)*exp(-mix(.85,1.72,dustLoad)*shadowPath);
            float shield = obstruction+.54*ahead;
            vec2 lightOffset = toward*keyLight.zw;
            float planarDist2 = dot(lightOffset,lightOffset);
            float incident = 1.0/(1.0+planarDist2);
            float fill = 0.0;
            if (embedded) {
                vec2 regionalOffset = (u_regionLight.xy-uv)*u_regionLight.zw;
                fill = .16/((1.0+2.8*dot(regionalOffset,regionalOffset))*(1.0+shield));
            }
            float directWeight = 1.0-fill;
            vec2 sourceOffset = toward/u_structure[5].x;
            float sourceDist2 = dot(sourceOffset,sourceOffset);
            float hotGas = u_structure[5].y*(exp2(-1.65*sourceDist2)+.13*exp2(-.52*sourceDist2));
            float hotWhite = exp2(-1.30*sourceDist2);
            float paleFace = u_structure[3].w*(.20+.80*exposed);
            float column = color.a*2.6;
            const float dt = 1.0/8.0;
            // Profundidad en la columna local: cero mira a la cámara, uno al fondo.
            float nearFront = smoothstep(.10,.82,structure.z);
            float halfWidth = mix(mix(.19,.38,bed.clumping),.085,nearFront);
            float foldDepth = .49+.22*sin(seedOff.y+3.2*mix(mainUV.x,wingUV.x,bed.wingFraction))
                                 +.32*(bed.clumping-.5)-.48*nearFront;
            float dustCenter = clamp(foldDepth,halfWidth,1.0-halfWidth);
            // La cresta ya forma parte de localColumn. Su opacidad proviene
            // de la cantidad de material que atraviesa la línea de visión.
            float foldedColumn = column*density*u_intensity*.27*dustOpacity*localColumn;
            float previousDust = 0.0;
            // Un corte oblicuo por el material cambia de densidad con la profundidad.
            vec2 drift = mix(u_structure[0].zw,u_structure[2].xy,bed.wingFraction)*3.4;
            vec2 dustUV = bed.grainOffset*ns*(7.0+2.8*u_dustDetailScale)+seedOff.yx
                        +.86*(tuft.ba-.5)+.33*(fine.rg-.5);
            float transmission = 1.0;
            float dustDepth = 0.0;
            vec3 bands = vec3(0.0);
            // Entre dos estratos se cruza como máximo un plano de ruido. La
            // interpolación conserva el grano original y reutiliza ambos extremos.
            float depth = min(density,1.0);
            float plane = floor(seedOff.x+(.5-.5*dt)*depth*5.0);
            vec2 planeOffset = vec2(17.3,31.7);
            float grainLow = noise(folds+plane*planeOffset);
            float grainHigh = noise(folds+(plane+1.0)*planeOffset);
            for (int i=0; i<8; ++i) {
                float layer = (float(i)+.5)*dt;
                float z = (.5-layer)*depth;
                float slice = z*5.0+seedOff.x;
                float nextPlane = floor(slice);
                if (nextPlane < plane) {
                    grainHigh = grainLow;
                    plane = nextPlane;
                    grainLow = noise(folds+plane*planeOffset);
                }
                float f = fract(slice);
                float grain = mix(grainLow,grainHigh,f*f*(3.0-2.0*f));
                float detail = mix(grain,pow(1.0-abs(2.0*grain-1.0),3.0),ridges);
                float mass = density*(.35+1.5*detail)*sin(layer*3.14159)*u_intensity;
                float dz = z-.27;
                float distance2 = planarDist2+dz*dz;
                float direct = exp(-1.8*shield*sqrt(distance2)-interveningDepth)/(1.0+2.8*distance2);
                float light = fill+directWeight*direct;
                float excited = smoothstep(.25,.67,light+.20*(surface-.5));

                // La misma columna intercepta la luz del fondo y dispersa parte de
                // la iluminación incidente hacia el observador en su cara expuesta.
                // La diferencia de la columna acumulada conserva incluso hebras más finas que un estrato.
                float cumulativeDust = smoothstep(dustCenter-halfWidth,dustCenter+halfWidth,layer+.5*dt);
                float cloudlet = dustNoise(dustUV+z*drift).r;
                float packing = smoothstep(.24,.76,.54*cloudlet+.36*grain+.10*fine.g);
                float sliceDust = (cumulativeDust-previousDust)*foldedColumn/dt
                                *mix(.19,1.95,packing)*(.90+.20*inBank);
                previousDust = cumulativeDust;
                float dust = .16*localColumn*(.53+.76*grain);
                float dustExtinction = mass*column*dustOpacity*dust+sliceDust;
                float extinction = mass*column*(.82+.34*(1.0-excited))+dustExtinction;
                float stepT = exp(-extinction*dt);
                float path = extinction > .0001 ? (1.0-stepT)/extinction : dt;
                dustDepth += dustExtinction*dt;

                float gas = (.22+.90*(1.0-excited))*(.72+.42*grain);
                float front = u_frontBand.a*(.05+1.43*excited+.20*surface*surface)
                            *(.18+.93*surface+structure.y)*(.55+.90*detail);
                float ionization = min(1.2,density*(.54+1.10*light));
                float gasLight = ionization*(.34+2.10*light)/(1.0+1.9*dust);
                float reflected = light*exposed*ionization*(.40+.20*detail+.18*fleck);
                vec3 emission = vec3(mass*column*gas*gasLight,mass*column*front*gasLight,
                                     dustExtinction*reflected);
                bands += transmission*path*emission;
                transmission *= stepT;
            }
            vec3 ivory = vec3(1.0,.94,.89);
            float continuum = hotGas*(.74*bands.r+.60*bands.g);
            float knotLight = structure.w*structure.w*(1.6*bands.r+bands.g)*incident;
            // Redistribuir las dos emisiones después de integrar su absorción.
            float litFront = smoothstep(.15,.85,incident)*(.20+.80*smoothstep(.02,.75,surface+structure.y));
            float transfer = max(u_cloudBalance,0.0)*litFront*bands.r + min(u_cloudBalance,0.0)*bands.g;
            bands.r -= transfer;
            bands.g += transfer;
            float frontShare = bands.g/max(.0001,bands.r+bands.g);
            vec3 scattered = mix(mix(u_gasBand.rgb,u_frontBand.rgb,frontShare),ivory,paleFace*hotWhite);
            vec3 ionized = mix(u_frontBand.rgb,ivory,hotWhite);
            vec3 gasLight = bands.r*u_gasBand.rgb + bands.g*u_frontBand.rgb + bands.b*scattered;
            float thinLight = 0.0;
            if (outskirts > 0.0 && density < .43) {
                float skin = outskirts*(1.0-smoothstep(.17,.43,density))*(1.0-hotWhite)
                           *(1.0-smoothstep(.08,.52,localColumn+.72*abundance*structure.z));
                float wisps = .32+.68*smoothstep(.27,.68,.74*n+.26*fleck);
                thinLight = .12*skin*wisps*(incident+fill)*(1.0-transmission)/(1.0+2.6*ahead);
                gasLight = mix(gasLight,(bands.r+.85*bands.g+bands.b)*u_outerBand,.94*skin) + thinLight*u_outerBand;
            }
            vec3 radiance = u_brightness*(gasLight + continuum*ionized
                                       + knotLight*ivory);
            if (u_materialView != 0) {
                float signal = bands.r+thinLight;
                if (u_materialView == 2) signal = 2.0*bands.g;
                if (u_materialView == 3) signal = 1.0-exp(-dustDepth);
                if (u_materialView == 4) signal = u_brightness*bands.b;
                radiance = vec3(signal);
            }
            return vec4(radiance*u_volumeLight,1.0-transmission);
        }

        float density = shapeDensity(uv,r,p,n);
        float centerBoost = 1.0-smoothstep(0.0,1.0,r);
        float darkFogNoise = fbm(p * 1.8 + vec2(t * 0.18, t * 0.10));
        float darkFogIntensity = density*smoothstep(.30,.76,.64*n+.36*darkFogNoise);

        // Niebla pálida central para profundidad (movimiento suave)
        float paleFogNoise = fbm(p * 0.9 + vec2(-t * 0.18, t * 0.28));
        float paleFogMask = smoothstep(0.3, 0.7, paleFogNoise) * centerBoost;
        float paleFogIntensity = paleFogMask * 0.18 * (0.16 + par * 0.8);

        // Destellos estelares ("sparkle") controlados por u_sparkleStrength (parpadeo atenuado y suave)
        float sparkScale = 2.5 + par * 4.0;
        vec2 sp = p * sparkScale;

        float s1 = noise(sp + vec2(u_time * (0.45 + par * 0.25) * speedFactor + u_seed, -u_time * (0.35 + par * 0.20) * speedFactor + u_seed * 0.7));
        float s2 = noise(sp * 1.3 + vec2(-u_time * (0.40 + par * 0.20) * speedFactor + u_seed * 1.3, u_time * (0.30 + 0.15 * par) * speedFactor));
        float smax = max(s1, s2);

        float sparkMask = smoothstep(0.88, 1.0, smax) * mask;
        float sparkStrength = clamp(u_sparkleStrength, 0.0, 3.0) * (0.9 + 0.6 * par);

        vec4 texel = Texel(tex, texcoord);
        vec3 baseColor = color.rgb * texel.rgb * u_brightness;
        vec3 coreColor = u_coreColor * texel.rgb * u_brightness;
        
        // Aplicar absorción de polvo oscuro para contraste
        vec3 darkFogColor = baseColor * (1.0 - darkFogIntensity * 0.85);
        vec3 darkCoreColor = coreColor * (1.0 - darkFogIntensity * 0.70);
        
        // Transición dual-tone bi-tonal orgánica
        float coreBlend = smoothstep(0.18, 0.88, density * (0.6 + 0.4 * centerBoost));
        vec3 blendedBase = mix(darkFogColor, darkCoreColor, coreBlend * 0.82);
        
        // Armonización de micro-frecuencias
        float colorHarmony = smoothstep(0.2, 0.8, fbm(p * 0.7 + t * 0.05));
        vec3 harmonizedBase = mix(blendedBase, blendedBase * vec3(1.1, 0.95, 1.05), colorHarmony * 0.25);
        
        vec3 paleFogColor = mix(harmonizedBase, vec3(1.0, 0.98, 0.95) * u_brightness * 0.65, paleFogIntensity);
        vec3 finalColor = paleFogColor * (1.0 + sparkStrength * sparkMask);

        float a = mask * density * clamp(u_intensity, 0.0, 2.0) * texel.a;
        a *= 1.35;
        float normalizedSpark = clamp(sparkStrength / 3.0, 0.0, 1.0);
        a *= (1.0 + 0.40 * sparkMask * normalizedSpark);

        return vec4(finalColor, color.a * a);
    }
]]

-- Retícula periódica compartida por todas las semillas. Los niveles mip filtran
-- las hebras menores que un píxel al alejar la cámara.
local function makeDustGrain()
    local rng = love.math.newRandomGenerator(46391)
    local data = love.image.newImageData(128, 128, "rgba8")
    data:mapPixel(function()
        return rng:random(), rng:random(), rng:random(), rng:random()
    end)
    local grain = love.graphics.newImage(data, {linear = true, mipmaps = true})
    data:release()
    grain:setWrap("repeat", "repeat")
    grain:setFilter("linear", "linear")
    grain:setMipmapFilter("linear")
    return grain
end

-- Inicializar el sistema de shaders de nebulosas
function NebulasShaders.init()
    if NebulasShaders.state.initialized then
        print("NebulasShaders: Ya inicializado, omitiendo re-inicialización")
        return true
    end
    
    print("=== NEBULAS SHADERS INITIALIZING ===")
    
    if not love.graphics or not love.graphics.newShader then
        print("✗ NebulasShaders: Love2D graphics no disponible")
        return false
    end
    
    -- Crear shader de nebulosas
    local success, shader = pcall(love.graphics.newShader, nebulaShaderCode)
    if not success then
        print("✗ NebulasShaders: Error al crear shader - " .. tostring(shader))
        return false
    end
    
    NebulasShaders.state.shader = shader

    -- Instalar capa de compatibilidad transparente en el metatable de Shader
    -- para interceptar llamadas directas legacy (ej: shader:send("u_seed", ...) en loading_screen o renderers externos)
    if not NebulasShaders._hookInstalled and debug and debug.getmetatable then
        local mt = debug.getmetatable(shader)
        if mt and mt.__index and type(mt.__index.send) == "function" then
            local rawSend = mt.__index.send
            local rawHasUniform = mt.__index.hasUniform

            mt.__index.send = function(self, name, ...)
                if self == NebulasShaders.state.shader then
                    local u = NebulasShaders.state.uniforms
                    if name == "u_seed" then
                        local v = ...
                        _packedP1[1] = v; u.u_seed = v
                        return rawSend(self, "u_params1", _packedP1)
                    elseif name == "u_noiseScale" then
                        local v = ...
                        _packedP1[2] = v; u.u_noiseScale = v
                        return rawSend(self, "u_params1", _packedP1)
                    elseif name == "u_warpAmp" then
                        local v = ...
                        _packedP1[3] = v; u.u_warpAmp = v
                        return rawSend(self, "u_params1", _packedP1)
                    elseif name == "u_warpFreq" then
                        local v = ...
                        _packedP1[4] = v; u.u_warpFreq = v
                        return rawSend(self, "u_params1", _packedP1)
                    elseif name == "u_softness" then
                        local v = ...
                        _packedP2[1] = v; u.u_softness = v
                        return rawSend(self, "u_params2", _packedP2)
                    elseif name == "u_brightness" then
                        local v = ...
                        _packedP2[2] = v; u.u_brightness = v
                        return rawSend(self, "u_params2", _packedP2)
                    elseif name == "u_parallax" then
                        local v = ...
                        _packedP2[3] = v; u.u_parallax = v
                        return rawSend(self, "u_params2", _packedP2)
                    elseif name == "u_sparkleStrength" then
                        local v = ...
                        _packedP2[4] = v; u.u_sparkleStrength = v
                        return rawSend(self, "u_params2", _packedP2)
                    elseif name == "u_intensity" then
                        local v = ...
                        _packedP3[1] = v; u.u_intensity = v
                        return rawSend(self, "u_params3", _packedP3)
                    elseif name == "u_morphology" then
                        local v = ...
                        _packedP3[2] = v; u.u_morphology = v
                        return rawSend(self, "u_params3", _packedP3)
                    elseif name == "u_irregularity" then
                        local v = ...
                        _packedP3[3] = v; u.u_irregularity = v
                        return rawSend(self, "u_params3", _packedP3)
                    end
                end
                return rawSend(self, name, ...)
            end

            if rawHasUniform then
                mt.__index.hasUniform = function(self, name)
                    if self == NebulasShaders.state.shader then
                        if name == "u_seed" or name == "u_noiseScale" or name == "u_warpAmp" or name == "u_warpFreq"
                           or name == "u_softness" or name == "u_brightness" or name == "u_parallax" or name == "u_sparkleStrength"
                           or name == "u_intensity" or name == "u_morphology" or name == "u_irregularity" then
                            return true
                        end
                    end
                    return rawHasUniform(self, name)
                end
            end

            NebulasShaders._hookInstalled = true
        end
    end
    
    -- Configurar uniforms por defecto
    local ok, uniformError = pcall(function()
        shader:send("u_dustGrain", makeDustGrain())
        if shader:hasUniform("u_time") then shader:send("u_time", NebulasShaders.state.uniforms.u_time) end
        if shader:hasUniform("u_params1") then shader:send("u_params1", NebulasShaders.state.uniforms.u_params1) end
        if shader:hasUniform("u_params2") then shader:send("u_params2", NebulasShaders.state.uniforms.u_params2) end
        if shader:hasUniform("u_params3") then shader:send("u_params3", NebulasShaders.state.uniforms.u_params3) end
        if shader:hasUniform("u_coreColor") then shader:send("u_coreColor", NebulasShaders.state.uniforms.u_coreColor) end
    end)
    
    if not ok then
        NebulasShaders.state.shader = nil
        print("✗ NebulasShaders: Error al configurar uniforms por defecto - " .. tostring(uniformError))
        return false
    end
    
    NebulasShaders.state.initialized = true
    print("✓ NebulasShaders: Shader de nebulosas inicializado correctamente")
    return true
end

-- Obtener el shader de nebulosas
function NebulasShaders.getShader()
    if not NebulasShaders.state.initialized then
        NebulasShaders.init()
    end
    return NebulasShaders.state.shader
end

-- Actualizar uniforms del shader (soporta vectores y nombres escalares para total compatibilidad)
function NebulasShaders.updateUniforms(uniforms)
    local shader = NebulasShaders.getShader()
    if not shader then return false end
    
    local success = pcall(function()
        local u = NebulasShaders.state.uniforms
        local p1Changed, p2Changed, p3Changed = false, false, false

        for uniform, value in pairs(uniforms) do
            if uniform == "u_time" then
                if shader:hasUniform("u_time") then shader:send("u_time", value) end
                u.u_time = value
            elseif uniform == "u_params1" then
                if shader:hasUniform("u_params1") then shader:send("u_params1", value) end
                u.u_params1 = value
            elseif uniform == "u_params2" then
                if shader:hasUniform("u_params2") then shader:send("u_params2", value) end
                u.u_params2 = value
            elseif uniform == "u_params3" then
                if shader:hasUniform("u_params3") then shader:send("u_params3", value) end
                u.u_params3 = value
            elseif uniform == "u_coreColor" then
                if shader:hasUniform("u_coreColor") then shader:send("u_coreColor", value) end
                u.u_coreColor = value
            -- Aliases escalares
            elseif uniform == "u_seed" then
                _packedP1[1] = value; u.u_seed = value; p1Changed = true
            elseif uniform == "u_noiseScale" then
                _packedP1[2] = value; u.u_noiseScale = value; p1Changed = true
            elseif uniform == "u_warpAmp" then
                _packedP1[3] = value; u.u_warpAmp = value; p1Changed = true
            elseif uniform == "u_warpFreq" then
                _packedP1[4] = value; u.u_warpFreq = value; p1Changed = true
            elseif uniform == "u_softness" then
                _packedP2[1] = value; u.u_softness = value; p2Changed = true
            elseif uniform == "u_brightness" then
                _packedP2[2] = value; u.u_brightness = value; p2Changed = true
            elseif uniform == "u_parallax" then
                _packedP2[3] = value; u.u_parallax = value; p2Changed = true
            elseif uniform == "u_sparkleStrength" then
                _packedP2[4] = value; u.u_sparkleStrength = value; p2Changed = true
            elseif uniform == "u_intensity" then
                _packedP3[1] = value; u.u_intensity = value; p3Changed = true
            elseif uniform == "u_morphology" then
                _packedP3[2] = value; u.u_morphology = value; p3Changed = true
            elseif uniform == "u_irregularity" then
                _packedP3[3] = value; u.u_irregularity = value; p3Changed = true
            elseif uniform == "u_speed" or uniform == "u_movementSpeed" then
                _packedP3[4] = value; u.u_speed = value; p3Changed = true
            end
        end

        if p1Changed and shader:hasUniform("u_params1") then shader:send("u_params1", _packedP1) end
        if p2Changed and shader:hasUniform("u_params2") then shader:send("u_params2", _packedP2) end
        if p3Changed and shader:hasUniform("u_params3") then shader:send("u_params3", _packedP3) end
    end)
    
    return success
end

-- Configurar uniforms específicos para una nebulosa (Fase 4: vectorizado y sin asignación de tablas)
function NebulasShaders.configureForNebula(nebula, currentTime)
    local shader = NebulasShaders.getShader()
    if not shader then return false end

    local seedVal = (nebula.seed or 0) * 0.001
    local noiseScaleVal = nebula.noiseScale or 2.5
    local warpAmpVal = nebula.warpAmp or 0.65
    local warpFreqVal = nebula.warpFreq or 1.25

    local softnessVal = nebula.softness or 0.28
    local brightnessVal = nebula.brightness or 1.20
    local parallaxVal = math.max(0.0, math.min(1.0, nebula.parallax or 0.85))
    local sparkleVal = nebula.sparkleStrength or 0.0

    local intensityVal = nebula.intensity or 0.6
    local morphologyVal = nebula.morphology or 0.0
    local irregularityVal = nebula.irregularity or 0.35
    local speedVal = nebula.speed or nebula.movementSpeed or 1.0

    local core = nebula.coreColor or {1.0, 1.0, 1.0}
    local cR = core[1] or 1.0
    local cG = core[2] or 1.0
    local cB = core[3] or 1.0

    _packedP1[1] = seedVal
    _packedP1[2] = noiseScaleVal
    _packedP1[3] = warpAmpVal
    _packedP1[4] = warpFreqVal

    _packedP2[1] = softnessVal
    _packedP2[2] = brightnessVal
    _packedP2[3] = parallaxVal
    _packedP2[4] = sparkleVal

    _packedP3[1] = intensityVal
    _packedP3[2] = morphologyVal
    _packedP3[3] = irregularityVal
    _packedP3[4] = speedVal

    _packedCore[1] = cR
    _packedCore[2] = cG
    _packedCore[3] = cB

    -- Sincronizar estado interno para debug/telemetría
    local u = NebulasShaders.state.uniforms
    u.u_params1 = _packedP1
    u.u_params2 = _packedP2
    u.u_params3 = _packedP3
    u.u_coreColor = _packedCore
    u.u_seed = seedVal
    u.u_noiseScale = noiseScaleVal
    u.u_warpAmp = warpAmpVal
    u.u_warpFreq = warpFreqVal
    u.u_softness = softnessVal
    u.u_brightness = brightnessVal
    u.u_parallax = parallaxVal
    u.u_sparkleStrength = sparkleVal
    u.u_intensity = intensityVal
    u.u_morphology = morphologyVal
    u.u_irregularity = irregularityVal
    u.u_speed = speedVal

    -- Actualizar u_time solo si se especifica y difiere
    if currentTime and currentTime ~= u.u_time and shader:hasUniform("u_time") then
        shader:send("u_time", currentTime)
        u.u_time = currentTime
    end

    -- 4 envíos vectoriales directos (reducción masiva de overhead de driver OpenGL)
    if shader:hasUniform("u_params1") then shader:send("u_params1", _packedP1) end
    if shader:hasUniform("u_params2") then shader:send("u_params2", _packedP2) end
    if shader:hasUniform("u_params3") then shader:send("u_params3", _packedP3) end
    if shader:hasUniform("u_coreColor") then shader:send("u_coreColor", _packedCore) end

    return true
end

-- Actualizar tiempo explícito del shader
function NebulasShaders.updateTime(time)
    local shader = NebulasShaders.getShader()
    if shader and shader:hasUniform("u_time") then
        local t = time or love.timer.getTime()
        shader:send("u_time", t)
        NebulasShaders.state.uniforms.u_time = t
    end
end

-- Actualizar tiempo del shader (llamar cada frame)
function NebulasShaders.update(dt)
    if not NebulasShaders.state.initialized then return end
    NebulasShaders.updateTime(love.timer.getTime())
end

-- Aplicar shader de nebulosas
function NebulasShaders.setShader()
    local shader = NebulasShaders.getShader()
    if shader then
        love.graphics.setShader(shader)
        local now = love.timer.getTime()
        if shader:hasUniform("u_time") and NebulasShaders.state.uniforms.u_time ~= now then
            shader:send("u_time", now)
            NebulasShaders.state.uniforms.u_time = now
        end
        return true
    end
    return false
end

-- Remover shader
function NebulasShaders.unsetShader()
    love.graphics.setShader()
end

-- Verificar si el shader está disponible
function NebulasShaders.isAvailable()
    return NebulasShaders.state.initialized and NebulasShaders.state.shader ~= nil
end

-- Obtener información de estado
function NebulasShaders.getStatus()
    return {
        initialized = NebulasShaders.state.initialized,
        shaderLoaded = NebulasShaders.state.shader ~= nil,
        uniforms = NebulasShaders.state.uniforms
    }
end

-- Debug: imprimir estado
function NebulasShaders.debugPrint()
    print("=== NEBULAS SHADERS STATUS ===")
    local status = NebulasShaders.getStatus()
    print("Initialized: " .. tostring(status.initialized))
    print("Shader Loaded: " .. tostring(status.shaderLoaded))
    print("Current Uniforms:")
    for uniform, value in pairs(status.uniforms) do
        print("  " .. uniform .. ": " .. tostring(value))
    end
end

return NebulasShaders
