-- src/shaders/shader_manager.lua
-- Sistema gestor de shaders unificado para eliminar shuttering

local ShaderManager = {}
local StarShader = require 'src.shaders.star_shader'
local StarfieldInstanced = require 'src.shaders.starfield_instanced'

-- Estado del gestor de shaders
ShaderManager.state = {
    -- Shaders precompilados
    shaders = {
        star = nil,
        asteroid = nil,
        nebula = nil,
        station = nil,
        wormhole = nil,
        star_instanced = nil
    },
    
    -- Status de precarga
    preloadStatus = {
        star = false,
        asteroid = false,
        nebula = false,
        station = false,
        wormhole = false,
        star_instanced = false
    },
    
    -- Imágenes base para batching
    baseImages = {
        white = nil,
        circle = nil
    },
    
    -- Configuración
    config = {
        preloadIncrementally = true,
        maxPreloadTimePerFrame = 0.002, -- 2ms max por frame
        preloadPriority = {"star", "star_instanced", "asteroid", "nebula", "station", "wormhole"}
    }
}

-- Inicializar el gestor de shaders
function ShaderManager.init()
    print("=== SHADER MANAGER INITIALIZING ===")

    -- Evitar doble init
    if ShaderManager.state.initialized then
        print("ShaderManager: init ya ejecutado, omitiendo re-inicialización")
        return
    end

    -- Crear imágenes base para batching
    ShaderManager.createBaseImages()
    
    -- Inicializar StarShader primero (crítico para estrellas)
    if StarShader and StarShader.init then
        StarShader.init()
        ShaderManager.state.shaders.star = StarShader.getShader()
        ShaderManager.state.preloadStatus.star = true
        print("✓ StarShader preloaded")
    end
    -- Inicializar StarfieldInstanced
    if StarfieldInstanced and StarfieldInstanced.init then
        StarfieldInstanced.init()
        ShaderManager.state.shaders.star_instanced = StarfieldInstanced.getShader()
        ShaderManager.state.preloadStatus.star_instanced = ShaderManager.state.shaders.star_instanced and true or false
        if ShaderManager.state.preloadStatus.star_instanced then
            print("✓ StarfieldInstanced shader preloaded")
        else
            print("✗ StarfieldInstanced shader failed to preload")
        end
    end
    
    -- Crear shaders básicos para otros objetos
    ShaderManager.createBasicShaders()
    -- Warmup de shaders para evitar stutter en primer uso
    ShaderManager.warmup()
    print("✓ ShaderManager initialized with " .. ShaderManager.getLoadedCount() .. " shaders")
    ShaderManager.state.initialized = true
end

-- Crear imágenes base para batching
function ShaderManager.createBaseImages()
    if not love.graphics then return end
    
    -- Imagen blanca 1x1 para shaders
    local whiteData = love.image.newImageData(1, 1)
    whiteData:setPixel(0, 0, 1, 1, 1, 1)
    if not ShaderManager.state.baseImages.white and love.graphics and love.image then
        ShaderManager.state.baseImages.white = love.graphics.newImage(whiteData)
        if ShaderManager.state.baseImages.white.setFilter then
            ShaderManager.state.baseImages.white:setFilter("linear", "linear")
        end
    end
    -- Crear white si aplica (no mostrado)
    -- Crear/forzar circle a 512 con alpha radial y filtro lineal
    local circleSize = 512
    local circleData = love.image.newImageData(circleSize, circleSize)
    local center = circleSize / 2
    for y = 0, circleSize - 1 do
        for x = 0, circleSize - 1 do
            local dx = (x + 0.5) - center
            local dy = (y + 0.5) - center
            local dist = math.sqrt(dx*dx + dy*dy) / (circleSize * 0.5)
            local alpha = 1.0 - math.min(1.0, dist)
            circleData:setPixel(x, y, 1, 1, 1, alpha)
        end
    end
    ShaderManager.state.baseImages = ShaderManager.state.baseImages or {}
    ShaderManager.state.baseImages.circle = love.graphics.newImage(circleData)
    if ShaderManager.state.baseImages.circle.setFilter then
        ShaderManager.state.baseImages.circle:setFilter("linear", "linear")
    end
    print("ShaderManager: base circle creado con tamaño " ..
        tostring(ShaderManager.state.baseImages.circle:getWidth()) .. "x" ..
        tostring(ShaderManager.state.baseImages.circle:getHeight()))
end
-- Shader de wormhole con efectos 3D y parallax
local wormholeShaderCode = [[
    extern float u_time;
    extern float u_intensity;
    extern float u_size;
    extern vec3 u_color;
    extern float u_pulsePhase;
    extern vec2 u_playerPos;     // Posición del jugador
    extern vec2 u_wormholePos;   // Posición del wormhole
    extern float u_parallaxStrength; // Fuerza del efecto parallax
    extern float u_cameraZoom;   // Zoom de la cámara
    
    // Función para crear efecto parallax 3D
    vec2 calculateParallax(vec2 uv, vec2 playerOffset, float depth) {
        // Normalizar la distancia del jugador
        float distance = length(playerOffset);
        vec2 direction = normalize(playerOffset);
        
        // Calcular desplazamiento parallax basado en profundidad
        float parallaxAmount = u_parallaxStrength * depth / (distance * 0.001 + 1.0);
        
        // Aplicar desplazamiento parallax
        return uv + direction * parallaxAmount;
    }
    
    // Función para crear esfera 3D con parallax
    float create3DSphereWithParallax(vec2 uv, float radius, vec2 playerOffset) {
        // Calcular ángulo de vista y distancia
        float viewAngle = atan(playerOffset.y, playerOffset.x);
        float distance = length(playerOffset);
        
        // Perspectiva 3D mejorada
        float perspective = 0.2 + 0.8 * (1.0 - min(1.0, distance * 0.0005));
        
        // Rotación de la esfera según el ángulo de vista
        mat2 rotation = mat2(
            cos(viewAngle), -sin(viewAngle),
            sin(viewAngle), cos(viewAngle)
        );
        
        float sphere = 0.0;
        
        // Capa externa con parallax
        vec2 outerParallax = calculateParallax(uv, playerOffset, 0.3);
        vec2 outerRotated = rotation * outerParallax;
        vec2 outerScale = vec2(radius, radius * (0.3 + perspective * 0.5));
        float outerDist = length(outerRotated / outerScale);
        sphere += smoothstep(1.0, 0.6, outerDist) * 0.15;
        
        // Capa media con parallax más fuerte
        vec2 midParallax = calculateParallax(uv, playerOffset, 0.6);
        vec2 midRotated = rotation * midParallax;
        vec2 midScale = vec2(radius * 0.7, radius * (0.2 + perspective * 0.4));
        float midDist = length(midRotated / midScale);
        sphere += smoothstep(1.0, 0.4, midDist) * 0.35;
        
        // Núcleo con parallax máximo
        vec2 coreParallax = calculateParallax(uv, playerOffset, 1.0);
        vec2 coreRotated = rotation * coreParallax;
        vec2 coreScale = vec2(radius * 0.4, radius * (0.1 + perspective * 0.3));
        float coreDist = length(coreRotated / coreScale);
        sphere += smoothstep(1.0, 0.1, coreDist) * 0.7;
        
        // Iluminación 3D con parallax
        vec3 normal = normalize(vec3(coreRotated, sqrt(max(0.0, 1.0 - dot(coreRotated, coreRotated)))));
        vec3 lightDir = normalize(vec3(cos(viewAngle), sin(viewAngle), 0.8));
        float lighting = 0.5 + 0.5 * max(0.0, dot(normal, lightDir));
        sphere *= lighting;
        
        // Vórtice rotatorio con efecto parallax
        float spiralAngle = atan(coreRotated.y, coreRotated.x) + u_time * (1.5 + perspective * 2.0);
        float spiral = sin(spiralAngle * 6.0 + length(coreRotated) * 8.0) * 0.5 + 0.5;
        sphere *= (0.7 + spiral * 0.3);
        
        // Efecto de profundidad con zoom
        float depthFactor = 1.0 + 0.3 * sin(distance * 0.005 + u_time) / u_cameraZoom;
        sphere *= depthFactor;
        
        return sphere;
    }
    
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec2 uv = texture_coords * 2.0 - 1.0;
        
        // Calcular offset del jugador relativo al wormhole
        vec2 playerOffset = u_playerPos - u_wormholePos;
        
        // Crear la esfera 3D con parallax
        float sphereIntensity = create3DSphereWithParallax(uv, 1.0, playerOffset);
        
        // Pulso temporal más dinámico con parallax
        float pulse = 0.6 + 0.4 * sin(u_time * 2.0 + u_pulsePhase + length(playerOffset) * 0.001);
        sphereIntensity *= pulse;
        
        // Distorsión espacial con efecto parallax
        float distortion = 1.0 + 0.2 * sin(u_time * 2.5 + length(uv) * 5.0 + length(playerOffset) * 0.002);
        sphereIntensity *= distortion;
        
        // Efecto de refracción en los bordes
        float edgeRefraction = 1.0 + 0.1 * sin(u_time * 4.0 + atan(uv.y, uv.x) * 3.0);
        sphereIntensity *= edgeRefraction;
        
        // Color final con gradiente 3D mejorado
        vec3 baseColor = u_color;
        vec3 highlightColor = u_color * 1.8;
        vec3 edgeColor = u_color * 0.6;
        
        float edgeFactor = smoothstep(0.2, 0.8, length(uv));
        vec3 finalColor = mix(
            mix(highlightColor, baseColor, sphereIntensity * 0.5),
            edgeColor,
            edgeFactor
        ) * u_intensity;
        
        // Alpha con falloff 3D más realista
        float alpha = sphereIntensity * smoothstep(1.8, 0.4, length(uv));
        
        return vec4(finalColor, alpha * color.a);
    }
]];
-- Crear shaders básicos para objetos
function ShaderManager.createBasicShaders()
    -- Shader básico para asteroides (efecto rocoso simple)
    local asteroidShaderCode = [[
        extern float u_squashX;
        extern float u_squashY;
        extern float u_noiseAmp;
        extern float u_noiseFreq;
        extern float u_seed;
        extern float u_rotation;

        float hash(float n) { return fract(sin(n) * 43758.5453123); }

        vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
            // Centrar y aplicar rotación + escala anisotrópica
            vec2 uv = texcoord - vec2(0.5);
            float c = cos(u_rotation);
            float s = sin(u_rotation);
            mat2 rot = mat2(c, -s, s, c);
            uv = rot * uv;

            // squash elíptico
            uv.x /= max(0.001, u_squashX);
            uv.y /= max(0.001, u_squashY);

            float dist = length(uv) * 2.0;

            // Rugosidad del borde con semilla por-asteroide
            float n = sin((uv.x + u_seed) * u_noiseFreq) * cos((uv.y - u_seed) * (u_noiseFreq * 0.8));
            dist += n * u_noiseAmp;

            float alpha = smoothstep(1.0, 0.7, dist);
            return vec4(color.rgb, color.a * alpha);
        }
    ]]
    
    -- Shader básico para nebulosas (efecto difuso)
    local nebulaShaderCode = [[
        extern float u_time;
        extern float u_seed;
        extern float u_noiseScale;
        extern float u_warpAmp;
        extern float u_warpFreq;
        extern float u_softness;
        extern float u_intensity;
        extern float u_brightness;
        extern float u_parallax;        // NUEVO: parallax por-nebulosa
        extern float u_sparkleStrength; // NUEVO: control de intensidad de destellos locales

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
        vec2 domainWarp(vec2 p, float t) {
            float f = max(0.0001, u_warpFreq);
            vec2 q = vec2(
                fbm(p * f + t + u_seed),
                fbm(p * f - t + u_seed + 13.37)
            );
            q = (q - 0.5) * 2.0;
            return p + q * u_warpAmp;
        }
        vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
            vec2 uv = texcoord * 2.0 - 1.0;
            float r = length(uv);
            float s = clamp(u_softness, 0.0, 0.95);
            float mask = 1.0 - smoothstep(1.0 - s, 1.0, r);
            if (mask <= 0.0001) {
                return vec4(0.0);
            }

            // Movimiento más sutil y dependiente de parallax
            float par = clamp(u_parallax, 0.0, 1.0);
            float t = u_time * mix(0.015, 0.035, par);

            float ns = max(0.0001, u_noiseScale);
            vec2 p = uv * ns;
            p = domainWarp(p, t);
            float n = fbm(p);

            float cloud = smoothstep(0.30, 0.95, n);
            float centerBoost = smoothstep(1.0, 0.0, r);
            float density = cloud * (0.65 + 0.35 * centerBoost);

            // Destellos locales (“sparkle”) — se mantienen pero controlados por u_sparkleStrength (0.0 = OFF)
            // float par = clamp(u_parallax, 0.0, 1.0);  // <- eliminado: ya definido arriba
            float sparkScale = 2.5 + par * 4.0;
            vec2 sp = p * sparkScale;

            float s1 = noise(sp + vec2(u_time * (1.6 + par * 0.8) + u_seed, -u_time * (1.1 + par * 0.5) + u_seed * 0.7));
            float s2 = noise(sp * 1.3 + vec2(-u_time * (1.4 + par * 0.6) + u_seed * 1.3, u_time * (0.9 + 0.4 * par)));
            float smax = max(s1, s2);

            float sparkMask = smoothstep(0.88, 1.0, smax) * mask;
            float sparkStrength = clamp(u_sparkleStrength, 0.0, 3.0) * (0.9 + 0.6 * par);

            vec4 texel = Texel(tex, texcoord);
            vec3 baseColor = color.rgb * texel.rgb * u_brightness;
            vec3 finalColor = baseColor * (1.0 + sparkStrength * sparkMask);

            float a = mask * density * clamp(u_intensity, 0.0, 2.0) * texel.a;
            // El boost de alpha depende de sparkStrength (si es 0, no hay boost)
            float normalizedSpark = clamp(sparkStrength / 3.0, 0.0, 1.0);
            a *= (1.0 + 0.30 * sparkMask * normalizedSpark);

            return vec4(finalColor, color.a * a);
        }
    ]]
    
    -- Shader básico para estaciones (efecto metálico)
    local stationShaderCode = [[
        vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords) {
            vec2 uv = texcoord;
            
            // Efecto metálico simple con reflexión
            float metallic = sin(uv.x * 20.0) * cos(uv.y * 20.0) * 0.1 + 0.9;
            vec3 metallicColor = color.rgb * metallic;
            
            return vec4(metallicColor, color.a);
        }
    ]]
    
    -- Crear shaders si Love2D está disponible
    if love.graphics and love.graphics.newShader then
        local success, shader
        -- Asteroide shader
        success, shader = pcall(love.graphics.newShader, asteroidShaderCode)
        if success then
            ShaderManager.state.shaders.asteroid = shader
            ShaderManager.state.preloadStatus.asteroid = true
            -- Defaults seguros para uniforms
            pcall(function()
                shader:send("u_squashX", 1.0)
                shader:send("u_squashY", 1.0)
                shader:send("u_noiseAmp", 0.10)
                shader:send("u_noiseFreq", 12.0)
                shader:send("u_seed", 0.0)
                shader:send("u_rotation", 0.0)
            end)
        end
        
        -- Nebulosa shader
        success, shader = pcall(love.graphics.newShader, nebulaShaderCode)
        if success then
            ShaderManager.state.shaders.nebula = shader
            ShaderManager.state.preloadStatus.nebula = true
            pcall(function()
                shader:send("u_seed", 0.0)
                shader:send("u_noiseScale", 2.5)
                shader:send("u_warpAmp", 0.65)
                shader:send("u_warpFreq", 1.25)
                shader:send("u_softness", 0.28)
                shader:send("u_intensity", 0.6)
                shader:send("u_brightness", 1.20)
                shader:send("u_parallax", 0.85)
                shader:send("u_sparkleStrength", 0.0)
                shader:send("u_time", love.timer.getTime())
            end)
        end
        
        -- Estación shader
        success, shader = pcall(love.graphics.newShader, stationShaderCode)
        if success then
            ShaderManager.state.shaders.station = shader
            ShaderManager.state.preloadStatus.station = true
        end

        -- Wormhole shader (AÑADIDO AQUÍ PARA QUE NO SE PIERDA EN ESTA SEGUNDA DEFINICIÓN)
        success, shader = pcall(love.graphics.newShader, wormholeShaderCode)
        if success then
            ShaderManager.state.shaders.wormhole = shader
            ShaderManager.state.preloadStatus.wormhole = true
            -- Defaults seguros para uniforms
            pcall(function()
                shader:send("u_time", 0)
                shader:send("u_intensity", 1.0)
                shader:send("u_color", {0.5, 0.8, 1.0})
                shader:send("u_pulsePhase", 0)
                shader:send("u_playerPos", {0, 0})
                shader:send("u_wormholePos", {0, 0})
                shader:send("u_parallaxStrength", 1.0)
                shader:send("u_cameraZoom", 1.0)
            end)
            print("✓ Wormhole shader loaded successfully (from second createBasicShaders)")
        else
            print("✗ Failed to load Wormhole shader (second createBasicShaders): " .. tostring(shader))
        end
    end
end

-- Actualización incremental de precarga (llamar cada frame)
function ShaderManager.update(dt)
    if not ShaderManager.state.config.preloadIncrementally then return end
    
    local startTime = love.timer.getTime()
    local maxTime = ShaderManager.state.config.maxPreloadTimePerFrame
    
    -- Actualizar tiempo en shaders que lo necesiten
    local currentTime = love.timer.getTime()
    if ShaderManager.state.shaders.nebula then
        ShaderManager.state.shaders.nebula:send("u_time", currentTime)
    end
    if ShaderManager.state.shaders.wormhole then
        ShaderManager.state.shaders.wormhole:send("u_time", currentTime)
    end
    
    -- Verificar que todos los shaders estén cargados
    for _, shaderType in ipairs(ShaderManager.state.config.preloadPriority) do
        if not ShaderManager.state.preloadStatus[shaderType] then
            -- Intentar cargar shader faltante
            if love.timer.getTime() - startTime < maxTime then
                ShaderManager.ensureShaderLoaded(shaderType)
            else
                break -- No exceder tiempo límite
            end
        end
    end
end

-- Asegurar que un shader esté cargado
function ShaderManager.ensureShaderLoaded(shaderType)
    if ShaderManager.state.preloadStatus[shaderType] then return true end
    
    if shaderType == "star" and StarShader then
        if not ShaderManager.state.shaders.star and StarShader.getShader then
            ShaderManager.state.shaders.star = StarShader.getShader()
            ShaderManager.state.preloadStatus.star = true
        end
    end
    -- cargar on-demand el instanced si fuera necesario
    if shaderType == "star_instanced" and StarfieldInstanced then
        if not ShaderManager.state.shaders.star_instanced and StarfieldInstanced.init then
            StarfieldInstanced.init()
            ShaderManager.state.shaders.star_instanced = StarfieldInstanced.getShader()
            ShaderManager.state.preloadStatus.star_instanced = ShaderManager.state.shaders.star_instanced and true or false
        end
        return ShaderManager.state.preloadStatus.star_instanced
    end
    if shaderType == "wormhole" and love.graphics and love.graphics.newShader and wormholeShaderCode then
        local ok, shader = pcall(love.graphics.newShader, wormholeShaderCode)
        if ok then
            ShaderManager.state.shaders.wormhole = shader
            ShaderManager.state.preloadStatus.wormhole = true
            pcall(function()
                shader:send("u_time", love.timer.getTime() or 0)
                shader:send("u_intensity", 1.0)
                -- shader:send("u_size", 1.0) -- eliminado: el shader no usa u_size
                shader:send("u_color", {0.5, 0.8, 1.0})
                shader:send("u_pulsePhase", 0)
                shader:send("u_playerPos", {0, 0})
                shader:send("u_wormholePos", {0, 0})
                shader:send("u_parallaxStrength", 1.0)
                shader:send("u_cameraZoom", 1.0)
            end)
            print("✓ Wormhole shader ensured on-demand")
        else
            print("✗ ensureShaderLoaded(wormhole) failed: " .. tostring(shader))
        end
    end
    return ShaderManager.state.preloadStatus[shaderType]
end

-- Obtener shader para tipo específico
function ShaderManager.getShader(shaderType)
    ShaderManager.ensureShaderLoaded(shaderType)
    return ShaderManager.state.shaders[shaderType]
end

-- Obtener imagen base para batching
function ShaderManager.getBaseImage(imageType)
    if imageType == "white" then
        -- Garantizar que 'white' exista siempre
        if not ShaderManager.state.baseImages.white and love.graphics and love.image then
            local whiteData = love.image.newImageData(1, 1)
            whiteData:setPixel(0, 0, 1, 1, 1, 1)
            ShaderManager.state.baseImages.white = love.graphics.newImage(whiteData)
        end
        return ShaderManager.state.baseImages.white or (StarShader and StarShader.getWhiteImage and StarShader.getWhiteImage())
    elseif imageType == "circle" then
        ShaderManager.state.baseImages = ShaderManager.state.baseImages or {}
        local img = ShaderManager.state.baseImages.circle
        if img and img.getWidth then
            local w = img:getWidth()
            if w < 512 then
                print("ShaderManager: recreando circle de " .. tostring(w) .. " -> 512")
                local circleSize = 512
                local circleData = love.image.newImageData(circleSize, circleSize)
                local center = circleSize / 2
                for y = 0, circleSize - 1 do
                    for x = 0, circleSize - 1 do
                        local dx = (x + 0.5) - center
                        local dy = (y + 0.5) - center
                        local dist = math.sqrt(dx*dx + dy*dy) / (circleSize * 0.5)
                        local alpha = 1.0 - math.min(1.0, dist)
                        circleData:setPixel(x, y, 1, 1, 1, alpha)
                    end
                end
                img = love.graphics.newImage(circleData)
                if img.setFilter then img:setFilter("linear", "linear") end
                ShaderManager.state.baseImages.circle = img
                print("ShaderManager: circle recreado a " ..
                    tostring(img:getWidth()) .. "x" .. tostring(img:getHeight()))
            else
                if img.setFilter then img:setFilter("linear", "linear") end
            end
            return img
        end
        -- Fallback si no existe
        local circleSize = 512
        local circleData = love.image.newImageData(circleSize, circleSize)
        local center = circleSize / 2
        for y = 0, circleSize - 1 do
            for x = 0, circleSize - 1 do
                local dx = (x + 0.5) - center
                local dy = (y + 0.5) - center
                local dist = math.sqrt(dx*dx + dy*dy) / (circleSize * 0.5)
                local alpha = 1.0 - math.min(1.0, dist)
                circleData:setPixel(x, y, 1, 1, 1, alpha)
            end
        end
        img = love.graphics.newImage(circleData)
        if img.setFilter then img:setFilter("linear", "linear") end
        ShaderManager.state.baseImages.circle = img
        print("ShaderManager: circle creado (fallback) " ..
            tostring(img:getWidth()) .. "x" .. tostring(img:getHeight()))
        return img
    end

    return ShaderManager.state.baseImages.white or (StarShader and StarShader.getWhiteImage and StarShader.getWhiteImage())
end

-- Precalentar todos los shaders
function ShaderManager.preloadAll()
    for _, shaderType in ipairs(ShaderManager.state.config.preloadPriority) do
        ShaderManager.ensureShaderLoaded(shaderType)
    end
end

-- Obtener estadísticas de carga
function ShaderManager.getStats()
    local loaded = ShaderManager.getLoadedCount()
    local total = #ShaderManager.state.config.preloadPriority
    
    return {
        loaded = loaded,
        total = total,
        percentage = (loaded / total) * 100,
        status = ShaderManager.state.preloadStatus
    }
end

-- Contar shaders cargados
function ShaderManager.getLoadedCount()
    local count = 0
    for _, loaded in pairs(ShaderManager.state.preloadStatus) do
        if loaded then count = count + 1 end
    end
    return count
end

-- Aplicar shader con fallback
function ShaderManager.setShader(shaderType)
    local shader = ShaderManager.getShader(shaderType)
    if shader then
        love.graphics.setShader(shader)
        return true
    end
    return false
end

-- Remover shader actual
function ShaderManager.unsetShader()
    love.graphics.setShader()
end

-- Debug: mostrar estado de shaders
function ShaderManager.debugPrint()
    print("=== SHADER MANAGER STATUS ===")
    for shaderType, loaded in pairs(ShaderManager.state.preloadStatus) do
        local status = loaded and "✓" or "✗"
        print(string.format("%s %s", status, shaderType))
    end
    local stats = ShaderManager.getStats()
    print(string.format("Total: %d/%d (%.1f%%)", stats.loaded, stats.total, stats.percentage))
end
function ShaderManager.warmup()
    if not love.graphics then return end

    local okCanvas, canvas = pcall(love.graphics.newCanvas, 2, 2)
    if not okCanvas or not canvas then return end

    local prevCanvas = love.graphics.getCanvas()
    local prevShader = love.graphics.getShader()
    local prevColor = {love.graphics.getColor()}

    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    local white = ShaderManager.getBaseImage("white")
    if white then
        for _, shaderType in ipairs(ShaderManager.state.config.preloadPriority) do
            local shader = ShaderManager.state.shaders[shaderType]
            if shader then
                love.graphics.setShader(shader)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(white, 0, 0)
                love.graphics.setShader()
            end
        end
    end

    love.graphics.setCanvas(prevCanvas)
    love.graphics.setShader(prevShader)
    love.graphics.setColor(prevColor[1], prevColor[2], prevColor[3], prevColor[4] or 1)
end
return ShaderManager
