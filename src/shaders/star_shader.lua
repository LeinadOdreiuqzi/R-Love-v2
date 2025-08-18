-- src/shaders/star_shader.lua
-- Módulo de shader para renderizar estrellas con halo y parpadeo (twinkle)

local StarShader = {}

local shader
local whiteImage
 
-- Ajustes globales de intensidad/control visual
StarShader.settings = {
    haloMultiplier = 1.0,
    flareMultiplier = 1.0,
    coreMultiplier = 1.0
}

function StarShader.setVisualConfig(cfg)
    if not cfg then return end
    if cfg.haloMultiplier then StarShader.settings.haloMultiplier = cfg.haloMultiplier end
    if cfg.flareMultiplier then StarShader.settings.flareMultiplier = cfg.flareMultiplier end
    if cfg.coreMultiplier then StarShader.settings.coreMultiplier = cfg.coreMultiplier end
end

-- Código del shader (GLSL ES compatible con LÖVE)
-- Se dibuja sobre un quad con coords 0..1; "texcoord" nos da posición local en el quad
-- El color final se modula por love_Color (setColor desde CPU)
local shaderCode = [[
    extern float u_haloSize;
    extern float u_coreSize;
    extern float u_flareStrength;
    extern float u_crossSharpness;
    extern float u_corePower;
    extern float u_haloPower;
    
    // High precision para cálculos de posición
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
    
    // Función para convertir coordenadas a alta precisión
    vec2 toHighPrecision(vec2 pos) {
        // Ajustar la escala para mantener precisión con coordenadas grandes
        const float invScale = 0.1; // Ajustar según sea necesario
        return pos * invScale;
    }
    
    vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 pixcoord) {
        // Usar coordenadas locales del quad (0..1) para el renderizado
        vec2 uv = texcoord;
        vec2 centered = uv - vec2(0.5);
        float r = length(centered) * 2.0; // 0..~1 al borde del quad

        // Halo suave
        float halo = smoothstep(u_haloSize, 0.0, r);

        // Núcleo más concentrado
        float core = smoothstep(u_coreSize, 0.0, r);

        // Starflare en cruz (simple)
        float angX = abs(centered.x);
        float angY = abs(centered.y);
        float flare = max(0.0, 1.0 - (angX * u_crossSharpness)) + 
                     max(0.0, 1.0 - (angY * u_crossSharpness));
        flare *= u_flareStrength; // controlable

        // Calcular alpha final
        float alpha = clamp(core * u_corePower + halo * u_haloPower + flare, 0.0, 1.0);

        // El sampler sólo aporta un texel blanco (1x1), usamos vcolor como color base
        vec4 base = vcolor;
        return vec4(base.rgb, base.a * alpha);
    }
]]

function StarShader.init()
    if not love or not love.graphics then return end
    if shader then return end

    shader = love.graphics.newShader(shaderCode)

    -- Valores por defecto (similar al estilo anterior básico)
    shader:send("u_haloSize", 1.2)
    shader:send("u_coreSize", 0.6)
    shader:send("u_flareStrength", 0.15)
    shader:send("u_crossSharpness", 8.0)
    shader:send("u_corePower", 0.9)
    shader:send("u_haloPower", 0.35)

    -- Imagen blanca 1x1 para dibujar quads con texcoords 0..1
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 1)
    whiteImage = love.graphics.newImage(data)
end

function StarShader.getShader()
    return shader
end

function StarShader.getWhiteImage()
    return whiteImage
end

-- Dibuja una estrella con el shader. size = radio base en píxeles.
-- color = {r,g,b,a}, brightness y twinkleIntensity modulan el color final.
-- Para evitar problemas de precisión con coordenadas grandes, se recomienda usar coordenadas relativas a la cámara
function StarShader.drawStar(x, y, size, color, brightness, twinkleIntensity, starType)
    if not shader or not whiteImage then return end

    local screenX, screenY = x, y
    -- Ajustes por tipo para replicar estilos previos
    starType = starType or 1

    -- Ajustar parámetros según el tipo de estrella
    local haloSize = 1.2
    local coreSize = 0.6
    local flareStrength = 0.12
    local crossSharpness = 9.0
    local corePower = 0.95
    local haloPower = 0.33
    local quadMul = 2.8

    if starType == 4 then
        -- Super brillante con flares en cruz marcados
        haloSize = 1.4
        coreSize = 0.55
        flareStrength = 0.35
        crossSharpness = 5.0
        corePower = 1.05
        haloPower = 0.45
        quadMul = 4.0
    elseif starType == 1 then
        -- Estrella básica (parecida a antes)
        haloSize = 1.25
        coreSize = 0.6
        flareStrength = 0.10
        crossSharpness = 10.0
        corePower = 0.9
        haloPower = 0.30
        quadMul = 2.6
    else
        -- Otros tipos: valores intermedios
        haloSize = 1.3
        coreSize = 0.58
        flareStrength = 0.18
        crossSharpness = 8.0
        corePower = 0.95
        haloPower = 0.35
        quadMul = 3.0
    end

    -- Aplicar multiplicadores globales desde settings
    local haloMul = StarShader.settings.haloMultiplier or 1.0
    local flareMul = StarShader.settings.flareMultiplier or 1.0
    local coreMul = StarShader.settings.coreMultiplier or 1.0

    shader:send("u_haloSize", haloSize)
    shader:send("u_coreSize", coreSize)
    shader:send("u_flareStrength", flareStrength * flareMul)
    shader:send("u_crossSharpness", crossSharpness)
    shader:send("u_corePower", corePower * coreMul)
    shader:send("u_haloPower", haloPower * haloMul)

    local s = math.max(2, size * quadMul) -- rectángulo ajustado al halo
    local half = s * 0.5

    -- Modulación del color final
    local r = (color[1] or 1) * (brightness or 1) * (twinkleIntensity or 1)
    local g = (color[2] or 1) * (brightness or 1) * (twinkleIntensity or 1)
    local b = (color[3] or 1) * (brightness or 1) * (twinkleIntensity or 1)
    local a = color[4] or 1

    love.graphics.setShader(shader)
    love.graphics.setColor(r, g, b, a)
    love.graphics.draw(whiteImage, x - half, y - half, 0, s, s)
    love.graphics.setShader()
end

return StarShader
