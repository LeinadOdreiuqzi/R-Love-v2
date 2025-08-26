-- src/shaders/starfield_instanced.lua
-- Shader instanced: procesa UNA sola estrella indicada por aStarIndex
-- Basado en starfield.glsl, mismo layout, sin bucle global.

local StarfieldInstanced = {}

local shader
local whiteImage

-- NUEVO: buffer y writer
local writerShader
local starDataCanvas
local starDataW, starDataH = 0, 0

local MapConfig = require 'src.maps.config.map_config'

-- Fragment shader (GLSL es-LÖVE)
local shaderCode = [[
#ifdef PIXEL

// Constantes
const float PI = 3.14159265358979323846;

// Uniforms (mismo layout que starfield.glsl + índice de estrella)
extern Image u_starData;
extern number u_stride;           // 4 (filas por estrella)
extern vec2   u_dataTexSize;

extern vec2   u_camera;
extern number u_zoom;
extern number u_worldScale;
extern vec2   u_viewportSize;
extern number u_time;
extern number u_parallaxStrength;
extern number u_twinkleEnabled;   // 0.0 / 1.0
extern number u_enhancedEffects;  // 0.0 / 1.0

extern number aStarIndex;         // índice de estrella a procesar

// NUEVO: Modo override (para dibujar una única estrella con datos enviados por uniform)
// u_o_d0: (screenX, screenY, screenRadiusPx, type)    cuando u_o_screenSpace > 0.5
// u_o_d1: (depth, brightness, twinklePhase, twinkleSpeed)
// u_o_d2: (r, g, b, a)
// u_o_d3: (pulsePhase, _, _, _)
extern number u_override;         // 1.0 activa override por-uniform
extern number u_o_screenSpace;    // 1.0 indica que u_o_d0.xy son coords de pantalla y u_o_d0.z es radio en px
extern vec4   u_o_d0;
extern vec4   u_o_d1;
extern vec4   u_o_d2;
extern vec4   u_o_d3;

// Helpers de muestreo del buffer (coords en texel -> coords normalizadas)
vec2 texelCoord(int x, int y, vec2 size) {
    return vec2((float(x) + 0.5) / size.x, (float(y) + 0.5) / size.y);
}

// Lee las 4 filas (stride = 4) para el índice de estrella 'idx'
void readStar(int idx,
              out vec4 d0, out vec4 d1, out vec4 d2, out vec4 d3)
{
    int x = idx;
    int y0 = 0;
    int y1 = y0 + 1;
    int y2 = y0 + 2;
    int y3 = y0 + 3;

    d0 = Texel(u_starData, texelCoord(x, y0, u_dataTexSize));
    d1 = Texel(u_starData, texelCoord(x, y1, u_dataTexSize));
    d2 = Texel(u_starData, texelCoord(x, y2, u_dataTexSize));
    d3 = Texel(u_starData, texelCoord(x, y3, u_dataTexSize));
}

// Parallax consistente con tu renderer
vec2 applyParallax(vec2 baseWorld, vec2 camera, float depth, float parallaxStrength) {
    float depthFactor = 1.0 - depth;
    vec2 parallaxShift = camera * depthFactor * parallaxStrength;
    return baseWorld - parallaxShift;
}

// Mundo -> Pantalla como en isObjectVisible
vec2 worldToScreen(vec2 world, vec2 camera, float zoom, vec2 viewport) {
    return (world - camera) * zoom + viewport * 0.5;
}

// Halo suave (intenso cerca del radio, cae hacia fuera)
float haloFalloff(float dist, float radius, float softness) {
    float inner = radius;
    float outer = radius * (1.0 + softness);
    float t = smoothstep(inner, outer, dist);
    return 1.0 - t;
}

// Disco sólido con borde suave
float circleFill(float dist, float radius) {
    float edge = 1.0;
    float t = smoothstep(max(0.0, radius - edge), radius, dist);
    return 1.0 - t;
}

// Flare tipo cruz mejorado (para type 4) - más nítido y brillante
float crossFlare(vec2 p, vec2 center, float width, float intensity) {
    vec2 d = abs(p - center);
    // Flares más nítidos con mejor falloff
    float flareH = exp(-pow(d.y / (width * 0.8), 1.8)) * exp(-d.x * 0.03);
    float flareV = exp(-pow(d.x / (width * 0.8), 1.8)) * exp(-d.y * 0.03);
    return (flareH + flareV) * intensity * 1.4; // Aumentar brillo
}

// Nuevo: Flare de 6 puntas (para type 5)
float sixPointFlare(vec2 p, vec2 center, float width, float intensity) {
    vec2 d = p - center;
    float angle = atan(d.y, d.x);
    float dist = length(d);
    
    // Crear 6 rayos rotados 60 grados entre sí
    float flare = 0.0;
    for (int i = 0; i < 6; i++) {
        float rayAngle = float(i) * PI / 3.0; // 60 grados en radianes
        float angleDiff = abs(angle - rayAngle);
        // Manejar wrap-around del ángulo
        angleDiff = min(angleDiff, abs(angleDiff - 2.0 * PI));
        angleDiff = min(angleDiff, abs(angleDiff + 2.0 * PI));
        
        // Crear rayo con falloff angular y radial
        float rayIntensity = exp(-pow(angleDiff / 0.15, 2.0)) * exp(-dist / (width * 1.2));
        flare += rayIntensity;
    }
    
    return flare * intensity * 1.2;
}

// Sistema de colores equilibrado y armónico
float baseProfile(float dist, float radius) {
    // Perfil gaussiano suave, agradable
    float x = clamp(dist / max(1.0, radius), 0.0, 1.0);
    return exp(-pow(x, 2.2));
}

vec3 desaturate(vec3 color, float amount) {
    float g = dot(color, vec3(0.299, 0.587, 0.114));
    return mix(color, vec3(g), clamp(amount, 0.0, 1.0));
}

// Sistema de colores mejorado para evitar blancos cegadores
vec3 enhanceColor(vec3 base, float intensity) {
    // Aumentar saturación y brillo sin llegar al blanco puro
    vec3 enhanced = base * intensity;
    // Limitar componentes individuales para evitar blancos absolutos
    enhanced = min(enhanced, vec3(0.95));
    // Aumentar saturación ligeramente
    float luminance = dot(enhanced, vec3(0.299, 0.587, 0.114));
    enhanced = mix(vec3(luminance), enhanced, 1.15);
    return enhanced;
}

vec3 coreTint(vec3 base, float brightness) {
    // Núcleo más cálido y saturado, evitando blancos puros
    vec3 warmTint = mix(base, vec3(1.0, 0.9, 0.8), 0.2);
    return enhanceColor(warmTint, min(brightness * 0.8, 0.9));
}

vec3 haloTint(vec3 base, float brightness) {
    // Halo más suave y colorido
    vec3 softened = desaturate(base, 0.2);
    return enhanceColor(softened, min(brightness * 0.4, 0.6));
}

vec3 bodyTint(vec3 base, float brightness) {
    // Cuerpo principal con colores ricos
    return enhanceColor(base, min(brightness * 0.9, 0.85));
}

vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoord)
{
    // Override por-uniform
    if (u_override > 0.5) {
        vec4 d0 = u_o_d0;
        vec4 d1 = u_o_d1;
        vec4 d2 = u_o_d2;
        vec4 d3 = u_o_d3;

        float type = d0.w;
        float brightness = d1.y;
        float twPhase = d1.z;
        float twSpeed = d1.w;
        vec3 c = d2.rgb;
        float a = d2.a;
        float pulsePhase = d3.x;

        // Reemplaza el bloque twinkle con una versión branchless equivalente
        // Antes:
        // float twinkle = 1.0;
        // if (u_twinkleEnabled > 0.5) {
        //     twinkle = 0.6 + 0.4 * sin(float(u_time) * twSpeed + twPhase);
        // }
        float twEnabled = step(0.5, u_twinkleEnabled);
        float twinkleSin = 0.6 + 0.4 * sin(float(u_time) * twSpeed + twPhase);
        float twinkle = mix(1.0, twinkleSin, twEnabled);
        float starBrightness = brightness * twinkle;

        // Unifica la comprobación de tipo
        bool isType4 = abs(type - 4.0) < 0.5;

        float pulseMul = 1.0;
        if (isType4) {
            float pulse = sin(float(u_time) * 6.0 + pulsePhase);
            pulseMul = (1.2 + 0.3 * pulse);
        }

        // NUEVO: define finalMul para corregir el error de compilación
        float finalMul = isType4 ? pulseMul : 1.0;

        vec2 center;
        float screenRadius;

        if (u_o_screenSpace > 0.5) {
            center = d0.xy;
            screenRadius = d0.z;
        } else {
            // Ruta alternativa: interpretar d0.xy como mundo y proyectar
            float depth = d1.x;
            vec2 baseWorld = d0.xy;
            vec2 world = applyParallax(baseWorld, u_camera, depth, float(u_parallaxStrength));
            float worldRadius = d0.z * float(u_worldScale);
            screenRadius = worldRadius * float(u_zoom);
            center = worldToScreen(world, u_camera, float(u_zoom), u_viewportSize);
        }

        if (screenRadius <= 0.0) return vec4(0.0);

        float dist = length(screenCoord - center);
        if (dist > screenRadius * 4.0) return vec4(0.0);

        vec3 accum = vec3(0.0);

        // Sistema de renderizado equilibrado
        if (u_enhancedEffects > 0.5) {
            float halo = haloFalloff(dist, screenRadius * 2.2, 0.8);
            vec3 haloCol = haloTint(c, starBrightness);
            accum += halo * haloCol;
        }

        float body = circleFill(dist, screenRadius * (isType4 ? 0.85 : 1.0));
        vec3 bodyCol = bodyTint(c, starBrightness);

        float core = circleFill(dist, screenRadius * 0.25);
        vec3 coreCol = coreTint(c, starBrightness);
        
        // Pulso más suave y controlado
        if (abs(type - 4.0) < 0.5) {
            float pulse = sin(float(u_time) * 5.0 + pulsePhase);
            pulseMul = (1.0 + 0.08 * pulse); // Pulso muy sutil
        }

        // Efectos especiales controlados
    if (u_enhancedEffects > 0.5 && isType4) {
        float width = max(1.8, screenRadius * 0.35);
        float flare = crossFlare(screenCoord, center, width, 0.8);
        vec3 flareCol = enhanceColor(c, starBrightness * 0.4);
        accum += flare * flareCol;
    } else if (u_enhancedEffects > 0.5 && abs(type - 5.0) < 0.5) {
        float width = max(1.8, screenRadius * 0.3);
        float flare = sixPointFlare(screenCoord, center, width, 0.9);
        vec3 flareCol = enhanceColor(c, starBrightness * 0.5);
        accum += flare * flareCol;
    }

        // Composición final equilibrada
        accum += body * bodyCol * finalMul;
        accum += core * coreCol * 0.9; // Núcleo ligeramente reducido

        // Alpha suave y controlado
        float luminance = dot(accum, vec3(0.299, 0.587, 0.114));
        float outAlpha = min(0.95, luminance) * a;
        return vec4(accum, outAlpha);
    }

    // Ruta original: leer del buffer por índice y proyectar
    int idx = int(aStarIndex);

    vec4 d0, d1, d2, d3;
    readStar(idx, d0, d1, d2, d3);

    vec2 baseWorld = d0.xy;
    float size = d0.z;
    float type = d0.w;

    float depth = d1.x;
    float brightness = d1.y;
    float twPhase = d1.z;
    float twSpeed = d1.w;

    vec4 starColor = d2;
    float pulsePhase = d3.x;

    vec2 world = applyParallax(baseWorld, u_camera, depth, float(u_parallaxStrength));
    float worldRadius = size * float(u_worldScale);
    float screenRadius = worldRadius * float(u_zoom);
    if (screenRadius <= 0.0) {
        return vec4(0.0);
    }

    vec2 center = worldToScreen(world, u_camera, float(u_zoom), u_viewportSize);
    float dist = length(screenCoord - center);
    if (dist > screenRadius * 4.0) return vec4(0.0);

    float twinkle = 1.0;
    if (u_twinkleEnabled > 0.5) {
        twinkle = 0.6 + 0.4 * sin(float(u_time) * twSpeed + twPhase);
    }
    float starBrightness = brightness * twinkle;

    bool isType4Main = abs(type - 4.0) < 0.5;
    
    float pulseMul = 1.0;
    if (isType4Main) {
        float pulse = sin(float(u_time) * 5.0 + pulsePhase);
        pulseMul = (1.0 + 0.08 * pulse); // Pulso muy sutil
    }

    vec3 c = starColor.rgb;
    float a = starColor.a;

    vec3 accum = vec3(0.0);

    // Sistema de renderizado equilibrado (ruta principal)
    if (u_enhancedEffects > 0.5) {
        float halo = haloFalloff(dist, screenRadius * 2.2, 0.8);
        vec3 haloCol = haloTint(c, starBrightness);
        accum += halo * haloCol;
    }

    float body = circleFill(dist, screenRadius * (isType4Main ? 0.85 : 1.0));
    vec3 bodyCol = bodyTint(c, starBrightness);

    float core = circleFill(dist, screenRadius * 0.25);
    vec3 coreCol = coreTint(c, starBrightness);

    // Efectos especiales controlados (ruta principal)
    if (u_enhancedEffects > 0.5 && isType4Main) {
        float width = max(1.8, screenRadius * 0.35);
        float flare = crossFlare(screenCoord, center, width, 0.8);
        vec3 flareCol = enhanceColor(c, starBrightness * 0.4);
        accum += flare * flareCol;
    } else if (u_enhancedEffects > 0.5 && abs(type - 5.0) < 0.5) {
        float width = max(1.8, screenRadius * 0.3);
        float flare = sixPointFlare(screenCoord, center, width, 0.9);
        vec3 flareCol = enhanceColor(c, starBrightness * 0.5);
        accum += flare * flareCol;
    }

    float finalMul = isType4Main ? pulseMul : 1.0;

    // Composición final equilibrada (ruta principal)
    accum += body * bodyCol * finalMul;
    accum += core * coreCol * 0.9;

    // Alpha suave y controlado (ruta principal)
    float luminance = dot(accum, vec3(0.299, 0.587, 0.114));
    float outAlpha = min(0.95, luminance) * a;
    return vec4(accum, outAlpha);
}

#endif
]]

function StarfieldInstanced.init()
    if shader then return end
    if not love.graphics then return end

    local ok, sh = pcall(love.graphics.newShader, shaderCode)
    if ok then
        shader = sh
        -- Imagen blanca 1x1 para dibujar quads
        local data = love.image.newImageData(1, 1)
        data:setPixel(0, 0, 1, 1, 1, 1)
        whiteImage = love.graphics.newImage(data)
        if whiteImage and whiteImage.setFilter then
            whiteImage:setFilter("linear", "linear")
        end

        -- Defaults seguros
        pcall(function()
            shader:send("u_stride", 4)
            shader:send("u_parallaxStrength", MapConfig.stars and (MapConfig.stars.parallaxStrength or 0.15) or 0.15)
            shader:send("u_twinkleEnabled", MapConfig.stars and (MapConfig.stars.twinkleEnabled and 1.0 or 0.0) or 1.0)
            shader:send("u_enhancedEffects", MapConfig.stars and (MapConfig.stars.enhancedEffects and 1.0 or 0.0) or 1.0)
            local w, h = love.graphics.getDimensions()
            shader:send("u_viewportSize", {w, h})
            shader:send("u_worldScale", MapConfig.chunk and (MapConfig.chunk.worldScale or 1.0) or 1.0)
            shader:send("u_zoom", 1.0)
            shader:send("u_camera", {0.0, 0.0})
            shader:send("u_time", love.timer.getTime() or 0.0)
            shader:send("aStarIndex", 0)
        end)
    else
        print("✗ StarfieldInstanced: error creando shader: " .. tostring(sh))
    end
end

function StarfieldInstanced.getShader()
    return shader
end

function StarfieldInstanced.getWhiteImage()
    return whiteImage
end

-- Enviar el buffer de datos de estrellas (u_starData) y su tamaño (ancho, alto) y stride (normalmente 4)
function StarfieldInstanced.setStarData(image, stride)
    if not shader or not image then return end
    local w, h = image:getDimensions()
    pcall(function()
        shader:send("u_starData", image)
        shader:send("u_dataTexSize", {w, h})
        shader:send("u_stride", stride or 4)
    end)
end

-- Uniforms globales (llamar por frame o cuando cambien)
function StarfieldInstanced.setGlobals(opts)
    if not shader then return end
    opts = opts or {}
    pcall(function()
        if opts.camera then shader:send("u_camera", {opts.camera.x or opts.camera[1] or 0, opts.camera.y or opts.camera[2] or 0}) end
        if opts.zoom then shader:send("u_zoom", opts.zoom) end
        if opts.worldScale then shader:send("u_worldScale", opts.worldScale) end
        if opts.viewportSize then shader:send("u_viewportSize", {opts.viewportSize[1], opts.viewportSize[2]}) end
        shader:send("u_time", opts.time or love.timer.getTime())
        if opts.parallaxStrength then shader:send("u_parallaxStrength", opts.parallaxStrength) end
        if opts.twinkleEnabled ~= nil then shader:send("u_twinkleEnabled", opts.twinkleEnabled and 1.0 or 0.0) end
        if opts.enhancedEffects ~= nil then shader:send("u_enhancedEffects", opts.enhancedEffects and 1.0 or 0.0) end
    end)
end

-- Dibujar una estrella por índice, renderizando sobre un quad de pantalla completa (para test)
-- Nota: Esto es costoso. Para uso real, dibuja un quad centrado y del tamaño del star en pantalla.
function StarfieldInstanced.drawStarFullScreen(index)
    if not shader or not whiteImage then return end
    local w, h = love.graphics.getDimensions()
    -- Blending aditivo
    local oldBlend, oldAlpha = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")
    love.graphics.setShader(shader)
    pcall(function() shader:send("aStarIndex", index) end)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(whiteImage, 0, 0, 0, w, h)
    love.graphics.setShader()
    love.graphics.setBlendMode(oldBlend or "alpha", oldAlpha)
end

-- Dibujar una estrella por índice usando un quad (x,y centrado) y tamaño s (en píxeles)
-- Recomendado: s ~ 4 * radio_en_pantalla de la estrella
function StarfieldInstanced.drawStarQuad(index, x, y, s)
    if not shader or not whiteImage then return end
    -- Escala global configurable para instanced
    local instScale = (MapConfig.stars and MapConfig.stars.instancedSizeScale) or 1.3
    s = math.max(2, (s or 64) * instScale)
    local half = s * 0.5
    -- Blending aditivo
    local oldBlend, oldAlpha = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")
    love.graphics.setShader(shader)
    pcall(function() shader:send("aStarIndex", index) end)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(whiteImage, x - half, y - half, 0, s, s)
    love.graphics.setShader()
    love.graphics.setBlendMode(oldBlend or "alpha", oldAlpha)
end

-- NUEVO: dibujar una estrella con uniforms (modo override en espacio de pantalla)
function StarfieldInstanced.drawStarWithUniforms(screenX, screenY, screenRadius, star, starConfig)
    if not shader or not whiteImage or not star then return end
    local color = star.color or {1,1,1,1}
    local brightness = (star.brightness or 1.0)
    local starType = star.type or 1
    local twSpeed = star.twinkleSpeed or 1.0
    local twPhase = (star.twinkle or 0.0)
    local pulsePhase = star.pulsePhase or 0.0
    local depth = star.depth or 0.5

    -- Aumentar tamaño aparente un ~25%
    local s = math.max(2, (screenRadius or 8) * 4.0 * 1.25)
    local half = s * 0.5

    -- Guardar y usar blending aditivo mientras dibujamos la estrella
    local oldBlend, oldAlpha = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")

    love.graphics.setShader(shader)
    pcall(function()
        shader:send("u_override", 1.0)
        shader:send("u_o_screenSpace", 1.0)
        shader:send("u_o_d0", {screenX or 0.0, screenY or 0.0, screenRadius or 0.0, starType})
        shader:send("u_o_d1", {depth, brightness, twPhase, twSpeed})
        shader:send("u_o_d2", {color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1})
        shader:send("u_o_d3", {pulsePhase, 0, 0, 0})
    end)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(whiteImage, (screenX or 0) - half, (screenY or 0) - half, 0, s, s)
    -- Desactivar override para no “ensuciar” el siguiente draw
    pcall(function() shader:send("u_override", 0.0) end)
    love.graphics.setShader()

    -- Restaurar blending previo
    love.graphics.setBlendMode(oldBlend or "alpha", oldAlpha)
end

-- NUEVO: writer shader para construir el buffer u_starData (rgba32f Canvas)
local function ensureWriterShader()
    if writerShader then return end
    local code = [[
#ifdef PIXEL
extern vec4 u_value;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    // Escribe el valor tal cual (se usará sobre Canvas rgba32f con blending replace)
    return u_value;
}
#endif
]]
    local ok, sh = pcall(love.graphics.newShader, code)
    if ok then writerShader = sh else print("✗ StarfieldInstanced: error creando writerShader: "..tostring(sh)) end
end

-- NUEVO: iniciar la construcción del buffer para N estrellas (ancho=N, alto=4 filas)
function StarfieldInstanced.beginBuildStarData(count)
    if not love.graphics then return end
    ensureWriterShader()
    starDataW, starDataH = math.max(1, count or 1), 4
    -- Canvas float para valores fuera de [0,1]
    local ok, cvs = pcall(love.graphics.newCanvas, starDataW, starDataH, {format="rgba32f", readable=true})
    if not ok then
        print("✗ StarfieldInstanced: no se pudo crear Canvas rgba32f: "..tostring(cvs))
        return
    end
    starDataCanvas = cvs

    -- Preparar estado de dibujo
    love.graphics.push("all")
    love.graphics.setCanvas(starDataCanvas)
    love.graphics.clear(0,0,0,0)
    -- overwrite total al escribir píxeles
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.setShader(writerShader)
end

-- NUEVO: escribir 4 filas para una estrella en índice 'idx' (0-based)
-- d0=(x,y,size,type), d1=(depth,brightness,twPhase,twSpeed), d2=(r,g,b,a), d3=(pulsePhase,_,_,_)
function StarfieldInstanced.writeStarDataAt(idx, d0, d1, d2, d3)
    if not starDataCanvas or not writerShader then return end
    -- Guardar y normalizar los inputs a tablas de 4
    local function v4(v) return {v[1] or 0, v[2] or 0, v[3] or 0, v[4] or 0} end
    d0, d1, d2, d3 = v4(d0 or {}), v4(d1 or {}), v4(d2 or {}), v4(d3 or {})

    -- Para escribir exactamente el texel (idx,row), dibujamos rect de 1x1 px
    -- writerShader ignora color/textura y devuelve u_value
    pcall(function() writerShader:send("u_value", d0) end)
    love.graphics.rectangle("fill", idx, 0, 1, 1)

    pcall(function() writerShader:send("u_value", d1) end)
    love.graphics.rectangle("fill", idx, 1, 1, 1)

    pcall(function() writerShader:send("u_value", d2) end)
    love.graphics.rectangle("fill", idx, 2, 1, 1)

    pcall(function() writerShader:send("u_value", d3) end)
    love.graphics.rectangle("fill", idx, 3, 1, 1)
end

-- NUEVO: finalizar construcción y enviar al shader principal
function StarfieldInstanced.endBuildStarData()
    if not starDataCanvas then return end
    love.graphics.setShader()
    love.graphics.setCanvas()
    love.graphics.pop()

    -- Enviar a shader y configurar tamaño/stride
    StarfieldInstanced.setStarData(starDataCanvas, 4)
end

-- NUEVO: consultar si hay buffer cargado
function StarfieldInstanced.hasStarData()
    return starDataCanvas ~= nil
end

return StarfieldInstanced