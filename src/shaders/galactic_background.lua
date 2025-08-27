-- src/shaders/galactic_background.lua
-- Shader para fondo galáctico procedural con polvo estelar, gas interestelar y polvo cósmico

local GalacticBackground = {}

local shader
local whiteImage

-- Configuración por defecto
GalacticBackground.settings = {
    intensity = 2.0,  -- Intensidad muy alta para máxima visibilidad
    detailLevel = 1.0,
    movementSpeed = 0.1, 
    colorPalette = {
        base = {0.3, 0.4, 0.7},         -- Azul mucho más brillante
        dust = {0.5, 0.6, 0.9},         -- Polvo estelar muy visible
        gas = {0.4, 0.5, 0.8},          -- Gas interestelar muy brillante
        nebula = {0.7, 0.5, 1.0}        -- Formaciones nebulares muy intensas
    }
}

-- Código del shader GLSL
local shaderCode = [[
    extern float u_time;
    extern vec2 u_camera;
    extern float u_zoom;
    extern vec2 u_resolution;
    extern float u_seed;
    extern float u_intensity;
    extern float u_detailLevel;
    extern float u_movementSpeed;
    extern vec3 u_baseColor;
    extern vec3 u_dustColor;
    extern vec3 u_gasColor;
    extern vec3 u_nebulaColor;
    extern float u_parallaxStrength;
    
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
    
    // Función de ruido procedural mejorada
    float hash(vec2 p) {
        p = fract(p * vec2(234.34, 435.345));
        p += dot(p, p + 34.23);
        return fract(p.x * p.y);
    }
    
    float noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        
        float a = hash(i);
        float b = hash(i + vec2(1.0, 0.0));
        float c = hash(i + vec2(0.0, 1.0));
        float d = hash(i + vec2(1.0, 1.0));
        
        return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    }
    
    // Ruido fractal para mayor detalle
    float fbm(vec2 p, int octaves) {
        float value = 0.0;
        float amplitude = 0.5;
        float frequency = 1.0;
        
        for (int i = 0; i < 6; i++) {
            if (i >= octaves) break;
            value += amplitude * noise(p * frequency);
            amplitude *= 0.5;
            frequency *= 2.0;
        }
        
        return value;
    }
    
    // Función para crear formaciones nebulares
    float nebulaPattern(vec2 p, float seed) {
        vec2 offset = vec2(seed * 123.45, seed * 678.90);
        p += offset;
        
        float n1 = fbm(p * 0.8, 4);
        float n2 = fbm(p * 1.5 + vec2(100.0), 3);
        float n3 = fbm(p * 3.0 + vec2(200.0), 2);
        
        // Combinar ruidos para crear formaciones complejas
        float pattern = n1 * 0.6 + n2 * 0.3 + n3 * 0.1;
        
        // Crear regiones más densas
        float density = smoothstep(0.3, 0.7, pattern);
        
        return density;
    }
    
    // Función para polvo estelar
    float dustPattern(vec2 p, float seed) {
        vec2 offset = vec2(seed * 456.78, seed * 901.23);
        p += offset;
        
        float dust = fbm(p * 2.0, 5);
        dust = pow(dust, 1.5); // Hacer el polvo más sutil
        
        // Añadir variaciones pequeñas
        float microDust = fbm(p * 8.0, 3) * 0.3;
        
        return dust + microDust;
    }
    
    // Función para gas interestelar
    float gasPattern(vec2 p, float seed, float time) {
        vec2 offset = vec2(seed * 789.01, seed * 234.56);
        p += offset;
        
        // Movimiento lento del gas
        vec2 flow = vec2(sin(time * 0.1), cos(time * 0.15)) * 0.5;
        p += flow;
        
        float gas = fbm(p * 1.2, 4);
        
        // Crear corrientes de gas
        float streams = sin(p.x * 0.5) * sin(p.y * 0.3) * 0.2;
        
        return gas + streams;
    }
    
    // Función para crear variaciones de color
    vec3 colorVariation(vec3 baseColor, float noise, float intensity) {
        // Boost de saturación y ligero contraste para evitar palidez
        vec3 variation = vec3(
            sin(noise * 6.2831) * 0.12,
            sin(noise * 6.2831 + 2.094) * 0.12,
            sin(noise * 6.2831 + 4.188) * 0.12
        );
        vec3 col = baseColor + variation * intensity;
        // Ajuste sutil de saturación
        float l = dot(col, vec3(0.299, 0.587, 0.114));
        col = mix(vec3(l), col, 1.15); // aumentar saturación ~15%
        // Corrección suave de gamma para levantar medios
        col = pow(max(col, 0.0), vec3(0.55)); // ajustar gamma 0.95 estaba
        return clamp(col, 0.0, 1.0);
    }
    
    vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 pixcoord) {
        // Convertir coordenadas de pantalla a coordenadas del mundo
        vec2 worldPos = (pixcoord - u_resolution * 0.5) / u_zoom + u_camera;
        
        // Aplicar parallax para profundidad
        vec2 parallaxPos = worldPos * (1.0 - u_parallaxStrength);
        
        // Movimiento y rotación sutil del fondo para dinamismo
        float time = u_time * u_movementSpeed;
        float angle = time * 0.02;
        mat2 rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
        vec2 rotatedPos = rot * parallaxPos;
        // Escalar coordenadas para el ruido sobre posición rotada
        vec2 noisePos = rotatedPos * 0.001 * u_detailLevel;
        
        // Generar patrones procedurales
        float nebula = nebulaPattern(noisePos, u_seed);
        float dust = dustPattern(noisePos * 1.5, u_seed + 100.0);
        float gas = gasPattern(noisePos * 0.8, u_seed + 200.0, time);
        
        // Combinar patrones con diferentes intensidades (aumentadas para mayor visibilidad)
        float nebulaIntensity = nebula * 0.8;
        float dustIntensity = dust * 0.6;
        float gasIntensity = gas * 0.5;
        
        // Crear variaciones de color
        float colorNoise = fbm(noisePos * 4.0, 3);
        
        vec3 nebulaColor = colorVariation(u_nebulaColor, colorNoise, 0.3);
        vec3 dustColor = colorVariation(u_dustColor, colorNoise + 0.5, 0.2);
        vec3 gasColor = colorVariation(u_gasColor, colorNoise + 1.0, 0.25);
        
        // Combinar todos los efectos
        vec3 finalColor = u_baseColor;
        finalColor = mix(finalColor, nebulaColor, nebulaIntensity);
        finalColor = mix(finalColor, dustColor, dustIntensity);
        finalColor = mix(finalColor, gasColor, gasIntensity);
        
        // Aplicar intensidad global con tone mapping para evitar blanqueo
        float exposure = clamp(u_intensity * 0.02, 0.1, 2.5);
        vec3 mapped = vec3(1.0) - exp(-finalColor * exposure);
        finalColor = clamp(mapped, 0.0, 1.0);
        
        // Crear gradiente sutil hacia los bordes para evitar cortes abruptos
        vec2 edgePos = abs(texcoord - 0.5) * 2.0;
        float edgeFade = 1.0 - smoothstep(0.7, 1.0, max(edgePos.x, edgePos.y));
        
        // Alpha final basado en la intensidad combinada (con clamp suave)
        float contentAlpha = (nebulaIntensity + dustIntensity + gasIntensity) * 0.8;
        // Aplicar un piso suave que preserve el fade hacia los bordes
        float minAlpha = 0.12;
        float alphaBase = minAlpha + (1.0 - minAlpha) * clamp(contentAlpha, 0.0, 1.0);
        float alpha = alphaBase * edgeFade;
        
        return vec4(finalColor, alpha * vcolor.a);
    }
]]

function GalacticBackground.init()
    if not love or not love.graphics then return end
    if shader then return end
    
    local success, result = pcall(function()
        return love.graphics.newShader(shaderCode)
    end)
    
    if success then
        shader = result
        print("✓ Galactic background shader loaded successfully")
        
        -- Configurar valores por defecto
        GalacticBackground.updateUniforms()
    else
        print("✗ Failed to load galactic background shader: " .. tostring(result))
        return false
    end
    
    -- Crear imagen blanca para renderizado
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 1)
    whiteImage = love.graphics.newImage(data)
    whiteImage:setFilter("linear", "linear")
    
    return true
end

function GalacticBackground.updateUniforms()
    if not shader then return end
    
    local settings = GalacticBackground.settings
    
    shader:send("u_intensity", settings.intensity)
    shader:send("u_detailLevel", settings.detailLevel)
    shader:send("u_movementSpeed", settings.movementSpeed)
    shader:send("u_baseColor", settings.colorPalette.base)
    shader:send("u_dustColor", settings.colorPalette.dust)
    shader:send("u_gasColor", settings.colorPalette.gas)
    shader:send("u_nebulaColor", settings.colorPalette.nebula)
    shader:send("u_parallaxStrength", 0.05) -- Parallax muy sutil para el fondo
end

function GalacticBackground.setSettings(newSettings)
    if not newSettings then return end
    
    for key, value in pairs(newSettings) do
        if key == "colorPalette" and type(value) == "table" then
            for colorKey, colorValue in pairs(value) do
                if GalacticBackground.settings.colorPalette[colorKey] then
                    GalacticBackground.settings.colorPalette[colorKey] = colorValue
                end
            end
        else
            GalacticBackground.settings[key] = value
        end
    end
    
    GalacticBackground.updateUniforms()
end

function GalacticBackground.getShader()
    return shader
end

function GalacticBackground.getWhiteImage()
    return whiteImage
end

function GalacticBackground.render(camera, seed)
    if not shader or not whiteImage then 
        return 
    end
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Actualizar uniforms dinámicos
    shader:send("u_time", love.timer.getTime())
    shader:send("u_camera", {camera.x or 0, camera.y or 0})
    shader:send("u_zoom", camera.zoom or 1.0)
    shader:send("u_resolution", {screenWidth, screenHeight})
    shader:send("u_seed", seed or 0)
    
    -- Renderizar fondo completo con margen para asegurar cobertura
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setShader(shader)
    love.graphics.setColor(1, 1, 1, 0.5)
    local margin = 256 -- píxeles extra alrededor
    love.graphics.draw(whiteImage, -margin, -margin, 0, screenWidth + margin * 2, screenHeight + margin * 2)
    love.graphics.setShader()
    love.graphics.pop()
end

-- Función para generar variaciones únicas por semilla
function GalacticBackground.generateVariation(seed)
    if not seed then return end
    
    -- Usar la semilla para generar variaciones en los parámetros
    local rng = love.math.newRandomGenerator(seed)
    
    -- Asegurar un mínimo de intensidad y paletas claras por semilla
    local minIntensity = 20.0
    local variation = {
        intensity = math.max(minIntensity, 80.0 + rng:random() * 40.0), -- clamp mínimo
        detailLevel = 0.8 + rng:random() * 0.4, -- 0.8 - 1.2
        movementSpeed = 0.05 + rng:random() * 0.1, -- 0.05 - 0.15
        colorPalette = {
            base = {
                math.max(0.25, 0.2 + rng:random() * 0.2),
                math.max(0.35, 0.3 + rng:random() * 0.2),
                math.max(0.55, 0.5 + rng:random() * 0.3)
            },
            dust = {
                math.max(0.45, 0.4 + rng:random() * 0.2),
                math.max(0.55, 0.5 + rng:random() * 0.2),
                math.max(0.75, 0.7 + rng:random() * 0.3)
            },
            gas = {
                math.max(0.35, 0.3 + rng:random() * 0.2),
                math.max(0.45, 0.4 + rng:random() * 0.2),
                math.max(0.65, 0.6 + rng:random() * 0.2)
            },
            nebula = {
                math.max(0.6, 0.5 + rng:random() * 0.3),
                math.max(0.35, 0.3 + rng:random() * 0.2),
                math.max(0.85, 0.8 + rng:random() * 0.2)
            }
        }
    }
    
    GalacticBackground.setSettings(variation)
end

return GalacticBackground