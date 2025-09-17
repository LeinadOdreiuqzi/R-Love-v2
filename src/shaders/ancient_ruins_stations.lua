-- src/shaders/ancient_ruins_stations.lua
-- Shaders especializados para estaciones del bioma ancient_ruins
-- Variantes por forma: ring, modular, elongated
-- Estados: operational, damaged, ruins

local AncientRuinsStations = {}

-- Estado interno del módulo
AncientRuinsStations.state = {
    shader = nil,
    initialized = false,
    config = {
        -- Mapeo determinista de complexType a shapeType y state
        typeMapping = {
            -- Ring variants
            ["ring_operational"] = { shapeType = 0, state = 0 },
            ["ring_damaged"] = { shapeType = 0, state = 1 },
            ["ring_ruins"] = { shapeType = 0, state = 2 },
            -- Modular variants
            ["modular_operational"] = { shapeType = 1, state = 0 },
            ["modular_damaged"] = { shapeType = 1, state = 1 },
            ["modular_ruins"] = { shapeType = 1, state = 2 },
            -- Elongated variants
            ["elongated_operational"] = { shapeType = 2, state = 0 },
            ["elongated_damaged"] = { shapeType = 2, state = 1 },
            ["elongated_ruins"] = { shapeType = 2, state = 2 }
        },
        -- Parámetros específicos por estado (rediseñados para mayor distinción visual)
        stateParams = {
            [0] = { -- operational - estación completamente funcional
                damage = 0.02,
                gapSize = 0.005,
                panelVariation = 0.05,
                burnIntensity = 0.01,
                structuralIntegrity = 1.0,
                lightingIntensity = 1.0,
                colorSaturation = 1.0
            },
            [1] = { -- damaged - estación parcialmente dañada
                damage = 0.6,
                gapSize = 0.15,
                panelVariation = 0.5,
                burnIntensity = 0.4,
                structuralIntegrity = 0.7,
                lightingIntensity = 0.6,
                colorSaturation = 0.7
            },
            [2] = { -- ruins - estación en ruinas severas
                damage = 0.95,
                gapSize = 0.35,
                panelVariation = 0.9,
                burnIntensity = 0.8,
                structuralIntegrity = 0.3,
                lightingIntensity = 0.3,
                colorSaturation = 0.4
            }
        }
    }
}

-- Código del shader especializado para ancient_ruins
local function getAncientRuinsShaderCode()
    return [[
        extern float u_time;
        extern float u_lod;
        extern float u_rotation;
        extern float u_shapeType; // 0: ring, 1: modular, 2: elongated
        extern float u_state; // 0: operational, 1: damaged, 2: ruins
        extern float u_seed;
        extern float u_damage;
        extern float u_gapSize;
        extern float u_panelVariation;
        extern float u_burnIntensity;
        extern float u_structuralIntegrity;
        extern float u_lightingIntensity;
        extern float u_colorSaturation;
        extern vec2 u_lightDir;
        extern vec3 u_ancientColor; // Color característico de ancient_ruins

        // Funciones de ruido mejoradas
        float hash(float n) { return fract(sin(n) * 43758.5453123); }
        float hash2(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
        
        float noise(vec2 p) {
            vec2 i = floor(p);
            vec2 f = fract(p);
            f = f * f * (3.0 - 2.0 * f);
            return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
                      mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
        }
        
        float fbm(vec2 p) {
            float value = 0.0;
            float amplitude = 0.5;
            for (int i = 0; i < 4; i++) {
                value += amplitude * noise(p);
                p *= 2.0;
                amplitude *= 0.5;
            }
            return value;
        }

        // Función de ruido mejorada para compatibilidad
        float improvedNoise(vec2 p) {
            return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
        }
        
        float improvedFbm(vec2 p) {
            float value = 0.0;
            float amplitude = 0.5;
            for (int i = 0; i < 4; i++) {
                value += amplitude * improvedNoise(p);
                p *= 2.0;
                amplitude *= 0.5;
            }
            return value;
        }
        
        // Función para calcular distancia de un punto a una línea
        float distanceToLine(vec2 point, vec2 lineStart, vec2 lineEnd) {
            vec2 lineDir = lineEnd - lineStart;
            vec2 pointDir = point - lineStart;
            float lineLength = length(lineDir);
            
            if (lineLength < 0.001) {
                return length(pointDir);
            }
            
            float t = clamp(dot(pointDir, lineDir) / (lineLength * lineLength), 0.0, 1.0);
            vec2 projection = lineStart + t * lineDir;
            return length(point - projection);
        }

        // Efectos específicos para ring_* (estructura independiente visible)
        float ringMask(vec2 uv, float seed, float gapSize, float damage, float structuralIntegrity) {
            float r = length(uv) * 2.0;
            float angle = atan(uv.y, uv.x) + 3.14159;
            
            // Anillo base con grosor variable según integridad estructural
            float baseThickness = 0.25 * structuralIntegrity + 0.1;
            float inner = 0.4 - baseThickness * 0.5;
            float outer = 0.4 + baseThickness * 0.5;
            
            // Para ruinas, crear múltiples anillos fragmentados
            if (structuralIntegrity < 0.5) {
                // Anillos fragmentados para ruinas
                float fragmentedRing = 0.0;
                for (int i = 0; i < 3; i++) {
                    float ringOffset = float(i) * 0.15;
                    float fragInner = inner + ringOffset;
                    float fragOuter = outer + ringOffset;
                    float fragIntensity = 1.0 - float(i) * 0.4;
                    
                    float ring = smoothstep(fragOuter + 0.05, fragOuter - 0.02, r) * 
                                (1.0 - smoothstep(fragInner + 0.02, fragInner - 0.05, r));
                    fragmentedRing += ring * fragIntensity;
                }
                fragmentedRing = min(fragmentedRing, 1.0);
                
                // Aplicar fragmentación severa
                float fragmentNoise = fbm(uv * 25.0 + seed * 6.0);
                fragmentedRing *= smoothstep(0.3, 0.7, fragmentNoise);
                
                return fragmentedRing * (0.2 + 0.3 * structuralIntegrity);
            }
            
            // Anillo normal para operational/damaged
            float ring = smoothstep(outer + 0.05, outer - 0.02, r) * 
                        (1.0 - smoothstep(inner + 0.02, inner - 0.05, r));
            
            // Segmentos con gaps controlados por estado
            float segments = 8.0 + 4.0 * hash(seed);
            float segmentAngle = angle * segments / (2.0 * 3.14159);
            float segmentNoise = noise(vec2(segmentAngle * 2.0, seed * 10.0));
            
            // Gaps más severos para damaged/ruins
            float gapThreshold = 0.7 - gapSize * 2.0;
            float gaps = step(gapThreshold, segmentNoise);
            
            // Detalles estructurales que se degradan
            float structuralDetails = structuralIntegrity;
            
            // Refuerzos radiales que se deterioran
            float radialPattern = abs(sin(angle * 6.0 + seed * 3.0));
            structuralDetails *= 0.6 + 0.4 * smoothstep(0.5, 1.0, radialPattern) * structuralIntegrity;
            
            // Erosión de bordes más agresiva
            float edgeNoise = fbm(uv * 50.0 + seed * 8.0);
            float edgeErosion = smoothstep(0.2, 0.9, edgeNoise) * damage * 0.6;
            
            // Grietas estructurales para damaged/ruins
            float cracks = 0.0;
            if (structuralIntegrity < 0.8) {
                for (int i = 0; i < 4; i++) {
                    float crackAngle = float(i) * 1.57 + seed * 2.0;
                    float crackDist = abs(sin(angle - crackAngle)) * r;
                    cracks += (1.0 - smoothstep(0.0, 0.03, crackDist)) * (1.0 - structuralIntegrity) * 0.8;
                }
            }
            
            // Agujeros masivos de impacto en anillos
            float impacts = 0.0;
            if (damage > 0.2) {
                // Agujeros grandes que rompen secciones del anillo
                for (int i = 0; i < 3; i++) {
                    vec2 impactCenter = vec2(
                        -0.6 + 1.2 * hash(seed + float(i) * 12.0),
                        -0.6 + 1.2 * hash(seed + float(i) * 22.0)
                    );
                    
                    float impactDist = length(uv - impactCenter);
                    
                    // Tamaño del agujero según estado
                    float baseSize = 0.18 + 0.28 * damage;
                    if (structuralIntegrity < 0.6) {
                        baseSize = 0.32 + 0.48 * (1.0 - structuralIntegrity); // Hasta 0.8 de radio
                    }
                    
                    // Forma irregular que sigue la curvatura del anillo
                    float angularVariation = sin(angle * 3.0 + seed * float(i) * 8.0) * 0.2;
                    float radialVariation = fbm(uv * 7.0 + seed * float(i) * 15.0) * 0.3;
                    float effectiveSize = baseSize + angularVariation + radialVariation;
                    
                    // Bordes completamente destrozados
                    float edgeDestruction = fbm(uv * 18.0 + seed * float(i) * 28.0) * 0.2;
                    float holeEdge = smoothstep(effectiveSize - 0.08, effectiveSize + edgeDestruction, impactDist);
                    
                    // Probabilidad de agujero
                    float holeChance = hash(seed + float(i) * 42.0);
                    float shouldExist = step(0.35 - damage * 0.25, holeChance);
                    
                    impacts = max(impacts, (1.0 - holeEdge) * shouldExist);
                }
                
                // Secciones del anillo completamente arrancadas para ruinas
                if (structuralIntegrity < 0.4) {
                    for (int j = 0; j < 2; j++) {
                        float sectionAngle = float(j) * 3.14159 + seed * 5.0;
                        float sectionWidth = 0.8 + 0.6 * (1.0 - structuralIntegrity);
                        
                        float angleDiff = abs(angle - sectionAngle);
                        if (angleDiff > 3.14159) angleDiff = 6.28318 - angleDiff;
                        
                        float sectionMask = 1.0 - smoothstep(0.0, sectionWidth, angleDiff);
                        
                        float sectionChance = hash(seed + float(j) * 67.0);
                        float sectionExists = step(0.4, sectionChance);
                        
                        impacts = max(impacts, sectionMask * sectionExists * 0.85);
                    }
                }
            }
            
            return ring * gaps * structuralDetails * (1.0 - edgeErosion) * (1.0 - cracks) * (1.0 - impacts);
        }

        // Efectos específicos para modular_* (estación espacial modular orgánica con daño)
        float modularMask(vec2 uv, float seed, float panelVariation, float damage, float structuralIntegrity) {
            float r = length(uv) * 2.0;
            float baseMask = smoothstep(1.0, 0.88, r);
            
            // Núcleo central circular más grande y prominente (se degrada)
            float coreRadius = 0.18 * mix(0.7, 1.0, structuralIntegrity);
            float centralCore = 1.0 - smoothstep(coreRadius - 0.02, coreRadius + 0.02, length(uv));
            centralCore *= structuralIntegrity; // El núcleo se degrada
            
            // Anillo interno de soporte estructural (se fragmenta)
            float innerRingRadius = 0.25;
            float innerRing = abs(length(uv) - innerRingRadius);
            innerRing = 1.0 - smoothstep(0.015, 0.025, innerRing);
            
            // Fragmentación del anillo interno
            if (structuralIntegrity < 0.8) {
                float ringFragments = fbm(uv * 15.0 + seed * 4.0);
                innerRing *= smoothstep(0.3, 0.8, ringFragments) * structuralIntegrity;
            }
            
            // Módulos principales distribuidos simétricamente (algunos se pierden)
            float mainModules = 0.0;
            float mainModuleCount = 6.0;
            for (int i = 0; i < 6; i++) {
                float moduleAngle = float(i) * 2.0 * 3.14159 / mainModuleCount + seed * 0.1;
                vec2 moduleCenter = vec2(cos(moduleAngle), sin(moduleAngle)) * 0.38;
                
                // Módulos hexagonales más orgánicos
                vec2 moduleUV = uv - moduleCenter;
                float moduleHexAngle = atan(moduleUV.y, moduleUV.x) + moduleAngle;
                float moduleHexRadius = length(moduleUV);
                float moduleHexSides = 6.0;
                float moduleHexPattern = cos(floor(0.5 + moduleHexAngle * moduleHexSides / (2.0 * 3.14159)) * 2.0 * 3.14159 / moduleHexSides - moduleHexAngle);
                
                float moduleShape = smoothstep(0.12, 0.08, moduleHexRadius) * smoothstep(0.7, 1.0, moduleHexPattern);
                
                // Detalles internos del módulo (se degradan)
                float moduleDetail = 1.0 - smoothstep(0.04, 0.06, length(moduleUV));
                moduleShape = max(moduleShape, moduleDetail * 0.8 * structuralIntegrity);
                
                // Los módulos se pierden con el daño
                float moduleHealth = hash(seed + float(i) * 10.0);
                moduleHealth = step(damage * 0.6, moduleHealth); // Algunos módulos se pierden
                moduleShape *= moduleHealth * mix(0.2, 1.0, structuralIntegrity);
                
                // Daño estructural en módulos supervivientes
                if (structuralIntegrity < 0.6) {
                    float moduleDamage = fbm(moduleUV * 12.0 + seed * float(i) * 8.0);
                    moduleShape *= smoothstep(0.2, 0.9, moduleDamage);
                }
                
                mainModules = max(mainModules, moduleShape);
            }
            
            // Módulos secundarios más pequeños (muy vulnerables al daño)
            float secondaryModules = 0.0;
            if (structuralIntegrity > 0.4) { // Solo existen si no hay mucho daño
                float secModuleCount = 12.0;
                for (int j = 0; j < 12; j++) {
                    float secAngle = float(j) * 2.0 * 3.14159 / secModuleCount + seed * 0.3;
                    vec2 secCenter = vec2(cos(secAngle), sin(secAngle)) * 0.55;
                    
                    float secDist = length(uv - secCenter);
                    float secModule = 1.0 - smoothstep(0.04, 0.06, secDist);
                    
                    // Solo algunos módulos secundarios existen y se pierden fácilmente
                    float secExists = step(0.6 + damage * 0.3, hash(seed + float(j) * 10.0));
                    secModule *= secExists * structuralIntegrity;
                    
                    secondaryModules = max(secondaryModules, secModule * 0.4);
                }
            }
            
            // Conectores estructurales mejorados (se degradan severamente)
            float connectors = 0.0;
            for (int k = 0; k < 6; k++) {
                float connAngle = float(k) * 2.0 * 3.14159 / 6.0 + seed * 0.1;
                vec2 connDir = vec2(cos(connAngle), sin(connAngle));
                
                // Conectores radiales desde el núcleo
                float radialDist = abs(dot(uv, vec2(-connDir.y, connDir.x)));
                float radialLength = dot(uv, connDir);
                
                if (radialLength > 0.15 && radialLength < 0.42) {
                    float connectorWidth = mix(0.02, 0.015, (radialLength - 0.15) / 0.27);
                    float connector = 1.0 - smoothstep(connectorWidth * 0.5, connectorWidth, radialDist);
                    
                    // Los conectores se degradan y fragmentan
                    connector *= mix(0.1, 1.0, structuralIntegrity);
                    
                    // Fragmentación de conectores
                    if (structuralIntegrity < 0.7) {
                        float connectorFragments = fbm(uv * 20.0 + seed * float(k) * 6.0);
                        connector *= smoothstep(0.4, 0.9, connectorFragments);
                    }
                    
                    connectors = max(connectors, connector * 0.5);
                }
            }
            
            // Anillo exterior decorativo (se destruye fácilmente)
            float outerRing = 0.0;
            if (structuralIntegrity > 0.6) {
                float outerRingRadius = 0.65;
                outerRing = abs(length(uv) - outerRingRadius);
                outerRing = (1.0 - smoothstep(0.008, 0.015, outerRing)) * 0.3 * structuralIntegrity;
            }
            
            // Efectos de deterioro general
            float moduleWear = 0.0;
            if (structuralIntegrity < 0.7) {
                float wearNoise = fbm(uv * 8.0 + seed * 5.0);
                moduleWear = (1.0 - structuralIntegrity) * wearNoise * 0.4;
            }
            
            // Combinar efectos modulares
            float finalMask = baseMask;
            finalMask = max(finalMask * centralCore, mainModules); // Núcleo o módulos
            finalMask = max(finalMask, secondaryModules);
            finalMask = max(finalMask, connectors);
            finalMask = max(finalMask, outerRing);
            finalMask = max(finalMask, innerRing * 0.8);
            finalMask *= (1.0 - moduleWear); // Aplicar desgaste
            
            return finalMask;
        }

        // Efectos específicos para elongated_* (estación espacial alargada agresiva con daño)
        float elongatedMask(vec2 uv, float seed, float burnIntensity, float damage, float structuralIntegrity) {
            // Transformar UV para orientación horizontal de estación alargada
            vec2 stationUV = vec2(uv.x, uv.y * 0.6); // Comprimir verticalmente para aspecto alargado
            float stationLength = abs(stationUV.x);
            float stationWidth = abs(stationUV.y);
            
            // Para ruinas, estructura completamente fragmentada
            if (structuralIntegrity < 0.4) {
                // Fragmentación severa en secciones triangulares
                float sectionSize = 0.25 + 0.15 * hash(seed * 2.0);
                vec2 sectionGrid = uv / sectionSize;
                vec2 sectionId = floor(sectionGrid);
                
                float sectionSeed = hash2(sectionId + seed * 200.0);
                float sectionExists = step(0.65, sectionSeed); // Solo 35% de secciones existen
                
                // Las secciones que existen están muy deterioradas
                float sectionDamage = 1.0 - sectionSeed * 0.5;
                
                // Bordes completamente irregulares con forma triangular residual
                float edgeNoise = fbm(uv * 15.0 + seed * 8.0);
                float triangularEdge = smoothstep(0.2, 0.8, edgeNoise);
                
                return sectionExists * sectionDamage * triangularEdge * 0.2;
            }
            
            // Cuerpo triangular principal agresivo (se degrada)
            float triangularBodyWidth = mix(0.15, 0.5, 1.0 - stationLength); // Más ancho en el centro
            triangularBodyWidth *= mix(0.6, 1.0, structuralIntegrity); // Se reduce con daño
            float triangularBody = smoothstep(triangularBodyWidth + 0.03, triangularBodyWidth - 0.03, stationWidth);
            triangularBody *= smoothstep(0.98, 0.1, stationLength); // Forma alargada completa
            
            // Daño en el cuerpo principal
            if (structuralIntegrity < 0.7) {
                float bodyDamage = fbm(stationUV * 6.0 + seed * 3.0);
                triangularBody *= smoothstep(0.2, 0.7, bodyDamage) * (0.4 + structuralIntegrity * 0.6);
            }
            
            // Espina dorsal central prominente - muy vulnerable
            float dorsalSpine = 0.0;
            if (structuralIntegrity > 0.4) {
                float spineWidth = 0.08 * structuralIntegrity;
                dorsalSpine = smoothstep(spineWidth + 0.01, spineWidth - 0.01, abs(stationUV.y));
                dorsalSpine *= smoothstep(0.95, 0.1, stationLength); // A lo largo de toda la estación
                
                // Detalles de la espina dorsal
                float spineDetails = sin(stationUV.x * 20.0 + seed) * 0.5 + 0.5;
                dorsalSpine *= smoothstep(0.3, 0.8, spineDetails);
            }
            
            // Costillas estructurales laterales (se destruyen fácilmente)
            float structuralRibs = 0.0;
            if (structuralIntegrity > 0.5) { // Solo parte superior
                // Costillas estructurales que se extienden desde la espina dorsal
                float ribCount = 12.0;
                for (int i = 0; i < 12; i++) {
                    float ribX = (float(i) / ribCount - 0.5) * 1.8;
                    float ribSide = (mod(float(i), 2.0)) * 2.0 - 1.0; // Alternar lados
                    
                    // Costillas que se extienden desde el centro hacia los bordes
                    float ribLength = mix(0.1, 0.3, 1.0 - abs(ribX));
                    vec2 ribStart = vec2(ribX, 0.0);
                    vec2 ribEnd = vec2(ribX, ribSide * ribLength);
                    
                    // Distancia a la línea de la costilla
                    float ribDist = distanceToLine(stationUV, ribStart, ribEnd);
                    float ribMask = 1.0 - smoothstep(0.01, 0.03, ribDist);
                    
                    // Las costillas se pierden con el daño
                    float ribHealth = hash(seed + float(i) * 25.0);
                    ribHealth = step(damage * 0.6, ribHealth);
                    ribMask *= ribHealth * structuralIntegrity;
                    
                    structuralRibs = max(structuralRibs, ribMask * 0.8);
                }
            }
            
            // Paneles hundidos con profundidad (se destruyen fácilmente)
            float sunkenPanels = 0.0;
            if (structuralIntegrity > 0.4) {
                // Paneles hexagonales hundidos a lo largo del cuerpo
                float panelSize = 0.15;
                vec2 panelGrid = stationUV / panelSize;
                vec2 panelId = floor(panelGrid);
                vec2 panelUV = fract(panelGrid) - 0.5;
                
                float panelSeed = hash2(panelId + seed * 100.0);
                float panelExists = step(0.4, panelSeed); // 60% de paneles existen
                
                // Forma hexagonal del panel
                float hexDist = length(panelUV);
                float hexMask = 1.0 - smoothstep(0.3, 0.4, hexDist);
                
                // Los paneles se pierden con el daño
                float panelHealth = step(damage * 0.7, panelSeed);
                sunkenPanels = panelExists * hexMask * panelHealth * structuralIntegrity * 0.3;
            }
            
            // Torres de comando laterales (muy vulnerables)
            float commandTowers = 0.0;
            if (structuralIntegrity > 0.6) {
                // Torres en posiciones específicas
                for (int i = 0; i < 4; i++) {
                    float towerX = (float(i) - 1.5) * 0.4;
                    float towerSide = (mod(float(i), 2.0)) * 2.0 - 1.0;
                    vec2 towerPos = vec2(towerX, towerSide * 0.4);
                    
                    float towerDist = length(stationUV - towerPos);
                    float towerMask = 1.0 - smoothstep(0.03, 0.05, towerDist);
                    
                    // Las torres se pierden fácilmente
                    float towerHealth = hash(seed + float(i) * 30.0);
                    towerHealth = step(damage * 0.3, towerHealth);
                    towerMask *= towerHealth * structuralIntegrity;
                    
                    commandTowers = max(commandTowers, towerMask * 1.2);
                }
            }
            
            // Vigas de soporte internas (se colapsan con daño)
            float supportBeams = 0.0;
            if (structuralIntegrity > 0.5) {
                // Vigas diagonales que cruzan la estructura
                float beamPattern = abs(sin(stationUV.x * 8.0 + stationUV.y * 6.0 + seed));
                supportBeams = smoothstep(0.8, 0.95, beamPattern) * 0.4 * structuralIntegrity;
                
                // Vigas longitudinales principales
                float longBeams = smoothstep(0.02, 0.01, abs(stationUV.y - 0.2)) + 
                                 smoothstep(0.02, 0.01, abs(stationUV.y + 0.2));
                supportBeams = max(supportBeams, longBeams * 0.6 * structuralIntegrity);
            }
            
            // Extremos puntiagudos agresivos (se degradan)
            float sharpEnds = 0.0;
            if (structuralIntegrity > 0.3) {
                // Extremos puntiagudos en ambos lados
                float frontTip = smoothstep(0.9, 0.98, stationLength) * 
                               smoothstep(0.1 * structuralIntegrity, 0.05 * structuralIntegrity, stationWidth);
                float backTip = smoothstep(0.9, 0.98, stationLength) * 
                              smoothstep(0.08 * structuralIntegrity, 0.04 * structuralIntegrity, stationWidth);
                
                sharpEnds = max(frontTip, backTip) * structuralIntegrity;
            }
            
            // Desgaste concentrado en bordes más dramático
            float edgeDist = abs(stationUV.x) / (0.25 + 0.1 * hash(seed));
            float edgeWear = smoothstep(0.7, 1.0, edgeDist) * damage * 1.8 * (2.0 - structuralIntegrity);
            
            // Marcas de quemadura triangulares más visibles
            float burnLines = 0.0;
            for (int i = 0; i < 5; i++) {
                float lineY = -0.5 + 1.0 * hash(seed + float(i));
                float lineDist = abs(stationUV.y - lineY);
                float lineIntensity = 1.0 - smoothstep(0.0, 0.06, lineDist);
                burnLines += lineIntensity * burnIntensity * 1.5;
            }
            
            // Impactos de batalla masivos y secciones faltantes
            float impacts = 0.0;
            
            // Agujeros grandes que atraviesan la estructura triangular
            for (int i = 0; i < 5; i++) {
                vec2 impactPos = vec2(
                    -0.8 + 1.6 * hash(seed + float(i) * 10.0),
                    -0.5 + 1.0 * hash(seed + float(i) * 20.0)
                );
                float impactDist = length(stationUV - impactPos);
                
                // Tamaño masivo según daño y integridad
                float baseSize = 0.15 + 0.25 * damage;
                if (structuralIntegrity < 0.6) {
                    baseSize = 0.3 + 0.4 * (1.0 - structuralIntegrity); // Hasta 0.7 de radio
                }
                
                // Forma completamente irregular triangular
                float irregularity = fbm(stationUV * 8.0 + seed * float(i) * 15.0) * 0.3;
                float effectiveSize = baseSize + irregularity;
                
                // Bordes completamente desgarrados
                float edgeDestruction = fbm(stationUV * 15.0 + seed * float(i) * 25.0) * 0.2;
                float holeEdge = smoothstep(effectiveSize - 0.08, effectiveSize + edgeDestruction, impactDist);
                
                // Mayor probabilidad de agujeros en estructuras dañadas
                float holeChance = hash(seed + float(i) * 35.0);
                float shouldExist = step(0.25 - damage * 0.15, holeChance);
                
                impacts = max(impacts, (1.0 - holeEdge) * shouldExist * burnIntensity);
            }
            
            // Secciones triangulares completamente arrancadas para ruinas
            if (structuralIntegrity < 0.4) {
                for (int k = 0; k < 4; k++) {
                    vec2 sectionPos = vec2(
                        -0.9 + 1.8 * hash(seed + float(k) * 75.0),
                        -0.6 + 1.2 * hash(seed + float(k) * 85.0)
                    );
                    
                    float sectionDist = length(stationUV - sectionPos);
                    float sectionSize = 0.2 + 0.3 * (1.0 - structuralIntegrity);
                    
                    // Forma de explosión triangular irregular
                    float explosionShape = fbm(stationUV * 5.0 + seed * float(k) * 40.0) * 0.4;
                    float sectionEdge = smoothstep(sectionSize - 0.1, sectionSize + explosionShape, sectionDist);
                    
                    float sectionChance = hash(seed + float(k) * 95.0);
                    float sectionExists = step(0.4, sectionChance);
                    
                    impacts = max(impacts, (1.0 - sectionEdge) * sectionExists * 0.85);
                }
            }
            
            // Grietas estructurales para damaged/ruins
            float cracks = 0.0;
            if (structuralIntegrity < 0.8) {
                float crackSeed = seed * 18.0;
                float mainCrack = abs(stationUV.y + sin(stationUV.x * 6.0 + crackSeed) * 0.08);
                mainCrack = 1.0 - smoothstep(0.0, 0.015 + damage * 0.05, mainCrack);
                cracks = mainCrack * (1.0 - structuralIntegrity) * 0.9;
            }
            
            // Combinar todos los elementos de la estación espacial alargada agresiva
            float finalMask = max(triangularBody, dorsalSpine);
            finalMask = max(finalMask, structuralRibs);
            finalMask = max(finalMask, sunkenPanels);
            finalMask = max(finalMask, commandTowers);
            finalMask = max(finalMask, supportBeams);
            finalMask = max(finalMask, sharpEnds);
            finalMask *= (1.0 - edgeWear) * (1.0 - burnLines * 0.6) * (1.0 - impacts * 0.85) * (1.0 - cracks);
            
            return finalMask;
        }

        vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
            vec2 uv = texcoord - vec2(0.5);
            
            // Rotación manual (sin mat2 para compatibilidad GLSL ES)
            float c = cos(u_rotation);
            float s = sin(u_rotation);
            vec2 rotated_uv = vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);
            uv = rotated_uv;
            
            float texA = Texel(tex, texcoord).a;
            float mask = 1.0;
            float structureMask = 1.0;
            
            // Aplicar efectos según shapeType
            if (u_shapeType < 0.5) {
                // Ring effects - generar estructura independiente
                structureMask = ringMask(uv, u_seed, u_gapSize, u_damage, u_structuralIntegrity);
                mask = max(texA, structureMask * 0.8); // Combinar textura original con estructura generada
            } else if (u_shapeType < 1.5) {
                // Modular effects - aplicar sobre textura existente
                mask = modularMask(uv, u_seed, u_panelVariation, u_damage, u_structuralIntegrity) * texA;
            } else {
                // Elongated effects - aplicar sobre textura existente
                mask = elongatedMask(uv, u_seed, u_burnIntensity, u_damage, u_structuralIntegrity) * texA;
            }
            
            // Iluminación básica modificada por estado
            float zz = clamp(1.0 - dot(uv, uv) * 4.0, 0.0, 1.0);
            vec3 normal = normalize(vec3(uv * 2.0, sqrt(zz)));
            vec3 L = normalize(vec3(u_lightDir, 0.6));
            float lambert = max(dot(normal, L), 0.0);
            
            // Ajustar iluminación según integridad estructural
            lambert = mix(lambert * 0.3, lambert, u_lightingIntensity * u_structuralIntegrity);
            
            // Color ancient_ruins con variación dramática por estado y tipo
            vec3 baseColor = mix(color.rgb, u_ancientColor, 0.4);
            
            // Variación de color por tipo de estación
            if (u_shapeType < 0.5) {
                // Ring: mantener tonos azules, pero degradar según estado
                vec3 ringColor = vec3(0.3, 0.6, 0.9);
                if (u_structuralIntegrity < 0.4) {
                    // Ruinas: azul muy apagado, casi gris
                    ringColor = vec3(0.2, 0.3, 0.4);
                } else if (u_structuralIntegrity < 0.7) {
                    // Dañado: azul oxidado
                    ringColor = vec3(0.25, 0.45, 0.6);
                }
                baseColor = mix(baseColor, ringColor, 0.3);
            } else if (u_shapeType < 1.5) {
                // Modular: tonos verde-azulados, degradar según estado
                vec3 modularColor = vec3(0.2, 0.7, 0.5);
                if (u_structuralIntegrity < 0.4) {
                    // Ruinas: verde muy oxidado, marrón
                    modularColor = vec3(0.3, 0.25, 0.15);
                } else if (u_structuralIntegrity < 0.7) {
                    // Dañado: verde apagado
                    modularColor = vec3(0.15, 0.5, 0.35);
                }
                baseColor = mix(baseColor, modularColor, 0.4);
            } else {
                // Elongated: tonos cálidos rojizo-naranjas, degradar según estado
                vec3 elongatedColor = vec3(0.8, 0.4, 0.2);
                if (u_structuralIntegrity < 0.4) {
                    // Ruinas: rojo muy oscuro, casi negro
                    elongatedColor = vec3(0.2, 0.1, 0.05);
                } else if (u_structuralIntegrity < 0.7) {
                    // Dañado: naranja apagado
                    elongatedColor = vec3(0.6, 0.3, 0.15);
                }
                baseColor = mix(baseColor, elongatedColor, 0.5);
            }
            
            // Aplicar saturación según estado
            float gray = dot(baseColor, vec3(0.299, 0.587, 0.114));
            baseColor = mix(vec3(gray), baseColor, u_colorSaturation);
            
            // Efectos de deterioro visual
            if (u_structuralIntegrity < 0.8) {
                // Añadir manchas de óxido y corrosión
                float corrosionNoise = fbm(uv * 8.0 + u_seed * 10.0);
                vec3 rustColor = vec3(0.4, 0.2, 0.1);
                float rustAmount = (1.0 - u_structuralIntegrity) * 0.6 * smoothstep(0.3, 0.8, corrosionNoise);
                baseColor = mix(baseColor, rustColor, rustAmount);
                
                // Reducir brillo general
                baseColor *= mix(0.4, 1.0, u_structuralIntegrity);
            }
            
            // Para ruinas, añadir efecto de polvo y decoloración
            if (u_structuralIntegrity < 0.4) {
                vec3 dustColor = vec3(0.3, 0.25, 0.2);
                baseColor = mix(baseColor, dustColor, 0.4);
                lambert *= 0.6; // Superficie muy opaca
            }
            
            baseColor = mix(baseColor, baseColor * 0.4, u_damage * 0.8);
            
            // Composición final con mejor contraste
            vec3 lit = baseColor * (0.3 + 0.7 * lambert);
            float alpha = color.a * mask * (1.0 - u_damage * 0.4);
            
            return vec4(lit, alpha);
        }
    ]]
end

-- Mapeo determinista de complexType a parámetros
function AncientRuinsStations.getShaderParams(complexType, seed)
    local mapping = AncientRuinsStations.state.config.typeMapping[complexType]
    if not mapping then
        -- Fallback para tipos no reconocidos
        mapping = { shapeType = 1, state = 1 }
    end
    
    local stateParams = AncientRuinsStations.state.config.stateParams[mapping.state]
    
    return {
        shapeType = mapping.shapeType,
        state = mapping.state,
        damage = stateParams.damage,
        gapSize = stateParams.gapSize,
        panelVariation = stateParams.panelVariation,
        burnIntensity = stateParams.burnIntensity,
        structuralIntegrity = stateParams.structuralIntegrity,
        lightingIntensity = stateParams.lightingIntensity,
        colorSaturation = stateParams.colorSaturation,
        seed = seed or 0,
        ancientColor = {0.6, 0.4, 0.7} -- Color púrpura característico
    }
end

-- Inicializar el módulo
function AncientRuinsStations.init()
    if AncientRuinsStations.state.initialized then
        return true
    end
    
    local success, shader = pcall(love.graphics.newShader, getAncientRuinsShaderCode())
    if success then
        AncientRuinsStations.state.shader = shader
        AncientRuinsStations.state.initialized = true
        print("✓ AncientRuinsStations: Shader especializado inicializado")
        return true
    else
        print("✗ AncientRuinsStations: Error al compilar shader: " .. tostring(shader))
        return false
    end
end

-- Obtener el shader
function AncientRuinsStations.getShader()
    if not AncientRuinsStations.state.initialized then
        AncientRuinsStations.init()
    end
    return AncientRuinsStations.state.shader
end

-- Enviar uniforms con parámetros específicos
function AncientRuinsStations.sendUniforms(params)
    local shader = AncientRuinsStations.getShader()
    if not shader then return false end
    
    local function safeSend(name, value)
        pcall(function() shader:send(name, value) end)
    end
    
    -- Uniforms básicos
    safeSend("u_time", params.time or love.timer.getTime())
    safeSend("u_lod", params.lod or 0)
    safeSend("u_rotation", params.rotation or 0)
    safeSend("u_shapeType", params.shapeType or 1)
    safeSend("u_state", params.state or 1)
    safeSend("u_seed", params.seed or 0)
    safeSend("u_lightDir", params.lightDir or {1, 0})
    
    -- Parámetros específicos de ancient_ruins
    safeSend("u_damage", params.damage or 0.5)
    safeSend("u_gapSize", params.gapSize or 0.1)
    safeSend("u_panelVariation", params.panelVariation or 0.3)
    safeSend("u_burnIntensity", params.burnIntensity or 0.3)
    safeSend("u_structuralIntegrity", params.structuralIntegrity or 0.7)
    safeSend("u_lightingIntensity", params.lightingIntensity or 1.0)
    safeSend("u_colorSaturation", params.colorSaturation or 1.0)
    safeSend("u_ancientColor", params.ancientColor or {0.6, 0.4, 0.7})
    
    return true
end

-- Aplicar shader
function AncientRuinsStations.setShader()
    local shader = AncientRuinsStations.getShader()
    if shader then
        love.graphics.setShader(shader)
        return true
    end
    return false
end

-- Remover shader
function AncientRuinsStations.unsetShader()
    love.graphics.setShader()
end

return AncientRuinsStations