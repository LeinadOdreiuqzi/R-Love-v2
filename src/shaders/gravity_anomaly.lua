-- src/shaders/gravity_anomaly.lua
-- Shader para bioma de anomalía gravitatoria con distorsión de luz

-- Módulo en blanco/no-op para mantener las rutas de implementación del bioma GRAVITY_ANOMALY
local GravitationalAnomalyShader = {}

-- Código del shader de anomalía gravitatoria
local gravitationalAnomalyShaderCode = [[
    extern float u_time;
    extern float u_intensity;
    extern vec2 u_anomalyCenter;     // Centro de la anomalía gravitatoria
    extern float u_anomalyStrength;  // Fuerza de la anomalía
    extern float u_anomalyRadius;    // Radio de influencia
    extern vec2 u_screenSize;        // Tamaño de la pantalla
    extern vec2 u_cameraPos;         // Posición de la cámara
    
    // Función para simular lente gravitacional
    vec2 gravitationalLensing(vec2 uv, vec2 anomalyPos, float strength, float radius) {
        vec2 toAnomaly = uv - anomalyPos;
        float distance = length(toAnomaly);
        
        // Evitar división por cero
        if (distance < 0.001) return uv;
        
        // Calcular deflexión gravitacional (aproximación de lente débil)
        float lensStrength = strength / (distance * distance + 0.1);
        lensStrength *= smoothstep(radius * 2.0, 0.0, distance);
        
        // Aplicar deflexión
        vec2 deflection = normalize(toAnomaly) * lensStrength;
        return uv + deflection;
    }
    
    // Función para crear ondas gravitacionales
    float gravitationalWaves(vec2 uv, vec2 anomalyPos, float time) {
        float distance = length(uv - anomalyPos);
        float wave1 = sin(distance * 8.0 - time * 4.0) * 0.5 + 0.5;
        float wave2 = sin(distance * 12.0 - time * 6.0) * 0.3 + 0.7;
        float wave3 = sin(distance * 16.0 - time * 8.0) * 0.2 + 0.8;
        
        return wave1 * wave2 * wave3;
    }
    
    // Función para crear distorsión del espacio-tiempo
    vec2 spacetimeDistortion(vec2 uv, vec2 anomalyPos, float strength, float time) {
        vec2 toAnomaly = uv - anomalyPos;
        float distance = length(toAnomaly);
        
        // Rotación del espacio-tiempo
        float rotation = strength * 0.5 / (distance + 0.1) * sin(time * 2.0);
        
        mat2 rotMatrix = mat2(
            cos(rotation), -sin(rotation),
            sin(rotation), cos(rotation)
        );
        
        return anomalyPos + rotMatrix * toAnomaly;
    }
    
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec2 uv = texture_coords;
        
        // Convertir coordenadas de pantalla a coordenadas del mundo
        vec2 worldPos = (screen_coords - u_screenSize * 0.5) + u_cameraPos;
        vec2 anomalyWorldPos = u_anomalyCenter;
        
        // Normalizar coordenadas para el efecto
        vec2 normalizedUV = (worldPos - anomalyWorldPos) / u_anomalyRadius;
        vec2 normalizedAnomaly = vec2(0.0, 0.0);
        
        // Aplicar lente gravitacional
        vec2 lensedUV = gravitationalLensing(normalizedUV, normalizedAnomaly, u_anomalyStrength, 1.0);
        
        // Aplicar distorsión del espacio-tiempo
        vec2 distortedUV = spacetimeDistortion(lensedUV, normalizedAnomaly, u_anomalyStrength * 0.3, u_time);
        
        // Calcular nuevas coordenadas de textura
        vec2 newTexCoords = texture_coords + (distortedUV - normalizedUV) * 0.1;
        newTexCoords = clamp(newTexCoords, 0.0, 1.0);
        
        // Obtener color de la textura con distorsión
        vec4 distortedColor = Texel(texture, newTexCoords);
        
        // Crear ondas gravitacionales
        float waves = gravitationalWaves(normalizedUV, normalizedAnomaly, u_time);
        
        // Efecto de aberración cromática
        float distance = length(normalizedUV);
        float chromaticStrength = u_anomalyStrength * 0.02 / (distance + 0.1);
        
        vec4 redChannel = Texel(texture, newTexCoords + vec2(chromaticStrength, 0.0));
        vec4 greenChannel = distortedColor;
        vec4 blueChannel = Texel(texture, newTexCoords - vec2(chromaticStrength, 0.0));
        
        vec4 chromaticColor = vec4(redChannel.r, greenChannel.g, blueChannel.b, distortedColor.a);
        
        // Aplicar ondas gravitacionales
        chromaticColor.rgb *= waves;
        
        // Efecto de brillo en el centro de la anomalía
        float centerGlow = 1.0 + u_anomalyStrength * 0.5 * exp(-distance * 2.0);
        chromaticColor.rgb *= centerGlow;
        
        // Aplicar intensidad general
        chromaticColor.rgb *= u_intensity;
        
        return chromaticColor * color;
    }
]];

-- Estado del shader
GravitationalAnomalyShader.shader = nil
GravitationalAnomalyShader.initialized = false

function GravitationalAnomalyShader.init()
    -- No-op: mantener ruta sin inicializar shaders
    GravitationalAnomalyShader.initialized = true
end

-- Obtener el shader
function GravitationalAnomalyShader.getShader()
    -- No-op: no hay shader activo
    return nil
end

-- Configurar parámetros de la anomalía
function GravitationalAnomalyShader.setAnomalyParams(centerX, centerY, strength, radius)
    -- No-op: mantener firma para futura implementación
end

-- Actualizar tiempo y posición de cámara
function GravitationalAnomalyShader.update(dt, cameraX, cameraY)
    -- No-op
end

-- Aplicar el efecto de anomalía gravitatoria
function GravitationalAnomalyShader.apply(intensity)
    -- No-op: no aplicar setShader
end

-- Desactivar el shader
function GravitationalAnomalyShader.disable()
    -- No-op: no tocar el estado global de shader
end

return GravitationalAnomalyShader