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
        -- Parámetros específicos por estado (ajustados para mayor distinción visual)
        stateParams = {
            [0] = { -- operational
                damage = 0.05,
                gapSize = 0.01,
                panelVariation = 0.1,
                burnIntensity = 0.02
            },
            [1] = { -- damaged
                damage = 0.5,
                gapSize = 0.12,
                panelVariation = 0.4,
                burnIntensity = 0.35
            },
            [2] = { -- ruins
                damage = 0.9,
                gapSize = 0.25,
                panelVariation = 0.8,
                burnIntensity = 0.7
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

        // Efectos específicos para ring_* (estructura independiente visible)
        float ringMask(vec2 uv, float seed, float gapSize, float damage) {
            float r = length(uv) * 2.0;
            float angle = atan(uv.y, uv.x) + 3.14159;
            
            // Anillo base más grueso y visible
            float inner = 0.35 + 0.1 * damage;
            float outer = 1.0 - 0.03 * damage;
            float ring = smoothstep(outer + 0.05, outer - 0.02, r) * (1.0 - smoothstep(inner + 0.02, inner - 0.05, r));
            
            // Segmentos con gaps más controlados
            float segments = 6.0 + 3.0 * hash(seed);
            float segmentAngle = angle * segments / (2.0 * 3.14159);
            float segmentNoise = noise(vec2(segmentAngle * 1.5, seed * 8.0));
            
            // Gaps más moderados para mantener visibilidad
            float gapThreshold = 0.6 - gapSize * 1.5;
            float gaps = step(gapThreshold, segmentNoise);
            
            // Detalles estructurales adicionales
            float structuralDetails = 1.0;
            // Refuerzos radiales
            float radialPattern = abs(sin(angle * 4.0 + seed * 2.0));
            structuralDetails *= 0.8 + 0.2 * smoothstep(0.7, 1.0, radialPattern);
            
            // Erosión más sutil para mantener estructura
            float edgeNoise = fbm(uv * 40.0 + seed * 4.0);
            float edgeErosion = smoothstep(0.4, 0.8, edgeNoise) * damage * 0.3;
            
            return ring * gaps * structuralDetails * (1.0 - edgeErosion);
        }

        // Efectos específicos para modular_* (panelado industrial distintivo)
        float modularMask(vec2 uv, float seed, float panelVariation, float damage) {
            float r = length(uv) * 2.0;
            float baseMask = smoothstep(1.0, 0.92, r);
            
            // Panelado hexagonal más distintivo
            float scale = 8.0 + 3.0 * hash(seed);
            vec2 grid = uv * scale;
            vec2 gridId = floor(grid);
            vec2 gridUv = fract(grid) - 0.5;
            
            // Juntas entre paneles más pronunciadas
            float jointWidth = 0.12 + 0.08 * damage;
            float joints = 1.0 - smoothstep(0.0, jointWidth, min(abs(gridUv.x), abs(gridUv.y)));
            
            // Patrón hexagonal adicional
            float hexPattern = abs(gridUv.x) + abs(gridUv.y) + abs(gridUv.x - gridUv.y);
            hexPattern = 1.0 - smoothstep(0.8, 1.0, hexPattern);
            
            // Remaches más visibles en esquinas
            float rivetDist = length(gridUv);
            float rivets = 1.0 - smoothstep(0.3, 0.38, rivetDist);
            rivets *= step(0.25, rivetDist); // Hueco central más grande
            
            // Variación de paneles más dramática
            float panelSeed = hash2(gridId + seed * 100.0);
            float panelHealth = 1.0 - panelVariation * panelSeed * 1.5;
            panelHealth = mix(panelHealth, panelHealth * 0.2, damage);
            
            // Daño específico en juntas más visible
            float jointDamage = fbm(gridId * 0.7 + seed * 5.0) * damage;
            joints = mix(joints, joints * 0.1, jointDamage);
            
            return baseMask * panelHealth * hexPattern * (1.0 - joints * 0.8) * (1.0 - rivets * 0.4);
        }

        // Efectos específicos para elongated_* (patrones lineales militares distintivos)
        float elongatedMask(vec2 uv, float seed, float burnIntensity, float damage) {
            // Compresión elíptica más pronunciada para forma alargada
            vec2 elongated = uv;
            elongated.x *= 0.3 + 0.15 * hash(seed);
            float r = length(elongated) * 2.0;
            float baseMask = smoothstep(1.0, 0.88, r);
            
            // Bandas longitudinales más definidas (estilo militar)
            float bands = sin(uv.x * 16.0 + seed * 7.0) * 0.5 + 0.5;
            bands = smoothstep(0.2, 0.8, bands);
            
            // Líneas de refuerzo estructural
            float reinforcement = abs(sin(uv.y * 8.0 + seed * 3.0));
            reinforcement = 1.0 - smoothstep(0.8, 0.95, reinforcement);
            
            // Desgaste concentrado en bordes más dramático
            float edgeDist = abs(uv.x) / (0.3 + 0.15 * hash(seed));
            float edgeWear = smoothstep(0.6, 1.0, edgeDist) * damage * 1.5;
            
            // Burn marks lineales más visibles
            float burnLines = 0.0;
            for (int i = 0; i < 4; i++) {
                float lineY = -0.4 + 0.8 * hash(seed + float(i));
                float lineDist = abs(uv.y - lineY);
                float lineIntensity = 1.0 - smoothstep(0.0, 0.08, lineDist);
                burnLines += lineIntensity * burnIntensity * 1.2;
            }
            
            // Impactos de batalla más grandes
            float impacts = 0.0;
            for (int i = 0; i < 6; i++) {
                vec2 impactPos = vec2(
                    -0.5 + 1.0 * hash(seed + float(i) * 10.0),
                    -0.3 + 0.6 * hash(seed + float(i) * 20.0)
                );
                float impactDist = length(uv - impactPos);
                float impactSize = 0.03 + 0.05 * damage;
                impacts += (1.0 - smoothstep(0.0, impactSize, impactDist)) * burnIntensity * 1.3;
            }
            
            return baseMask * bands * reinforcement * (1.0 - edgeWear) * (1.0 - burnLines * 0.7) * (1.0 - impacts * 0.9);
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
                structureMask = ringMask(uv, u_seed, u_gapSize, u_damage);
                mask = max(texA, structureMask * 0.8); // Combinar textura original con estructura generada
            } else if (u_shapeType < 1.5) {
                // Modular effects - aplicar sobre textura existente
                mask = modularMask(uv, u_seed, u_panelVariation, u_damage) * texA;
            } else {
                // Elongated effects - aplicar sobre textura existente
                mask = elongatedMask(uv, u_seed, u_burnIntensity, u_damage) * texA;
            }
            
            // Iluminación básica
            float zz = clamp(1.0 - dot(uv, uv) * 4.0, 0.0, 1.0);
            vec3 normal = normalize(vec3(uv * 2.0, sqrt(zz)));
            vec3 L = normalize(vec3(u_lightDir, 0.6));
            float lambert = max(dot(normal, L), 0.0);
            
            // Color ancient_ruins con variación por estado y tipo
            vec3 baseColor = mix(color.rgb, u_ancientColor, 0.4);
            
            // Variación de color por tipo de estación
            if (u_shapeType < 0.5) {
                // Ring: mantener tonos azules
                baseColor = mix(baseColor, vec3(0.3, 0.6, 0.9), 0.3);
            } else if (u_shapeType < 1.5) {
                // Modular: tonos verde-azulados
                baseColor = mix(baseColor, vec3(0.2, 0.7, 0.5), 0.4);
            } else {
                // Elongated: tonos cálidos rojizo-naranjas
                baseColor = mix(baseColor, vec3(0.8, 0.4, 0.2), 0.5);
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