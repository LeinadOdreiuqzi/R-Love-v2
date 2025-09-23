-- src/shaders/shader_manager.lua
-- Sistema gestor de shaders unificado para eliminar shuttering

local ShaderManager = {}
local StarShader = require 'src.shaders.star_shader'
local StarfieldInstanced = require 'src.shaders.starfield_instanced'
local BackgroundManager = require 'src.shaders.background_manager'
local NebulasShaders = require 'src.shaders.nebulas_shaders'
local AncientRuinsStations = require 'src.shaders.ancient_ruins_stations'

-- Cache de shaders optimizado
local shaderCache = {
    compiledShaders = {},
    shaderSources = {},
    lastCleanup = 0,
    cleanupInterval = 300.0, -- Limpiar cada 5 minutos
    maxCacheSize = 50,
    accessTimes = {}
}

-- Sistema de validación de uniforms integrado en ShaderManager

-- Estado del gestor de shaders
ShaderManager.state = {
    initialized = false,
    
    -- Shaders precompilados
    shaders = {
        star = nil,
        asteroid = nil,
        nebula = nil,
        station = nil,
        wormhole = nil,
        star_instanced = nil,
        galactic_background = nil,
        ancient_ruins = nil
    },
    
    -- Status de precarga
    preloadStatus = {
        star = false,
        asteroid = false,
        nebula = false,
        station = false,
        wormhole = false,
        star_instanced = false,
        galactic_background = false,
        ancient_ruins = false
    },
    
    -- Imágenes base para batching
    baseImages = {
        white = nil,
        circle = nil
    },
    
    -- Cache de texturas
    textureCache = {
        textures = {},
        maxSize = 100 * 1024 * 1024, -- 100MB
        currentSize = 0,
        lastCleanup = 0
    },
    
    -- OPTIMIZACIÓN: Cache de uniforms para evitar envíos redundantes
    uniformCache = {},
    lastActiveShader = nil,
    
    -- NUEVA OPTIMIZACIÓN: Estado de shaders y batching
    currentActiveShader = nil,
    shaderStateChanges = 0,
    uniformsSent = 0,
    batchedOperations = {},
    lastUniformValues = {},
    
    -- Configuración
    config = {
        preloadIncrementally = true,
        maxPreloadTimePerFrame = 0.002, -- 2ms max por frame
        preloadPriority = {"galactic_background", "star", "star_instanced", "asteroid", "nebula", "station", "wormhole", "ancient_ruins"}
    },
    
    -- Estadísticas
    stats = {
        loaded = 0,
        total = 0,
        compilationTime = 0,
        lastCompileTime = 0,
        cacheHits = 0,
        cacheMisses = 0,
        memoryUsage = 0
    }
}

-- Gestión de cache de shaders
function ShaderManager.getFromCache(shaderName, shaderCode)
    local cacheKey = shaderName .. "_" .. love.data.hash("sha1", shaderCode)
    
    if shaderCache.compiledShaders[cacheKey] then
        shaderCache.accessTimes[cacheKey] = love.timer.getTime()
        ShaderManager.state.stats.cacheHits = ShaderManager.state.stats.cacheHits + 1
        return shaderCache.compiledShaders[cacheKey]
    end
    
    ShaderManager.state.stats.cacheMisses = ShaderManager.state.stats.cacheMisses + 1
    return nil
end

function ShaderManager.addToCache(shaderName, shaderCode, shader)
    local cacheKey = shaderName .. "_" .. love.data.hash("sha1", shaderCode)
    
    -- Limpiar cache si está lleno
    if #shaderCache.compiledShaders >= shaderCache.maxCacheSize then
        ShaderManager.cleanupShaderCache()
    end
    
    shaderCache.compiledShaders[cacheKey] = shader
    shaderCache.shaderSources[cacheKey] = shaderCode
    shaderCache.accessTimes[cacheKey] = love.timer.getTime()
end

-- Limpiar cache de shaders
function ShaderManager.cleanupShaderCache()
    local currentTime = love.timer.getTime()
    
    -- Ordenar por tiempo de acceso
    local cacheEntries = {}
    for key, time in pairs(shaderCache.accessTimes) do
        table.insert(cacheEntries, {key = key, time = time})
    end
    
    table.sort(cacheEntries, function(a, b) return a.time < b.time end)
    
    -- Remover los más antiguos (25% del cache)
    local toRemove = math.floor(#cacheEntries * 0.25)
    for i = 1, toRemove do
        local key = cacheEntries[i].key
        shaderCache.compiledShaders[key] = nil
        shaderCache.shaderSources[key] = nil
        shaderCache.accessTimes[key] = nil
    end
    
    print("ShaderManager: Cleaned " .. toRemove .. " shaders from cache")
end

-- Gestión de memoria de texturas
function ShaderManager.updateTextureMemory()
    local currentTime = love.timer.getTime()
    if currentTime - ShaderManager.state.textureCache.lastCleanup < 60.0 then return end
    
    local memoryUsage = 0
    for _, texture in pairs(ShaderManager.state.textureCache.textures) do
        if texture.size then
            memoryUsage = memoryUsage + texture.size
        end
    end
    
    ShaderManager.state.textureCache.currentSize = memoryUsage
    ShaderManager.state.stats.memoryUsage = memoryUsage
    
    -- Limpiar si excede el límite
    if memoryUsage > ShaderManager.state.textureCache.maxSize then
        ShaderManager.cleanupTextureCache()
    end
    
    ShaderManager.state.textureCache.lastCleanup = currentTime
end

function ShaderManager.cleanupTextureCache()
    -- Implementar limpieza de texturas menos utilizadas
    local cleaned = 0
    for key, texture in pairs(ShaderManager.state.textureCache.textures) do
        if texture.lastAccess and love.timer.getTime() - texture.lastAccess > 300 then
            ShaderManager.state.textureCache.textures[key] = nil
            cleaned = cleaned + 1
        end
    end
    
    print("ShaderManager: Cleaned " .. cleaned .. " textures from cache")
end

-- Sistema de dependencias de shaders para inicialización ordenada
local shaderDependencies = {
    -- Orden de inicialización: dependencias primero
    initOrder = {
        "base_images",      -- Imágenes base (sin dependencias)
        "star",             -- Shader básico de estrellas
        "star_instanced",   -- Depende de star shader
        "galactic_background", -- Fondo galáctico (independiente)
        "nebula",           -- Nebulosas (independiente)
        "asteroid",         -- Asteroides (independiente)
        "station",          -- Estaciones (independiente)
        "wormhole",         -- Efectos visuales críticos
        "ancient_ruins"     -- Ruinas antiguas (último)
    },
    
    -- Dependencias explícitas
    dependencies = {
        star_instanced = {"star"},
        wormhole = {"base_images"}
    },
    
    -- Validadores de parámetros para shaders críticos
    paramValidators = {
        wormhole = function(params)
            local required = {"u_time", "u_intensity", "u_color", "u_pulsePhase", "u_playerPos", "u_wormholePos", "u_parallaxStrength", "u_cameraZoom"}
            for _, param in ipairs(required) do
                if not params[param] then
                    return false, "Parámetro requerido faltante: " .. param
                end
            end
            
            -- Validaciones específicas
            if type(params.u_time) ~= "number" or params.u_time < 0 then
                return false, "u_time debe ser un número positivo"
            end
            if type(params.u_intensity) ~= "number" or params.u_intensity <= 0 then
                return false, "u_intensity debe ser un número positivo"
            end
            if type(params.u_color) ~= "table" or #params.u_color ~= 3 then
                return false, "u_color debe ser un array de 3 números [r,g,b]"
            end
            for i, c in ipairs(params.u_color) do
                if type(c) ~= "number" or c < 0 or c > 1 then
                    return false, "u_color[" .. i .. "] debe estar entre 0 y 1"
                end
            end
            if type(params.u_playerPos) ~= "table" or #params.u_playerPos ~= 2 then
                return false, "u_playerPos debe ser un array de 2 números [x,y]"
            end
            if type(params.u_wormholePos) ~= "table" or #params.u_wormholePos ~= 2 then
                return false, "u_wormholePos debe ser un array de 2 números [x,y]"
            end
            
            return true, nil
        end,
        
        asteroid = function(params)
            local required = {"u_squashX", "u_squashY", "u_noiseAmp", "u_noiseFreq", "u_seed", "u_rotation"}
            for _, param in ipairs(required) do
                if not params[param] then
                    return false, "Parámetro requerido faltante: " .. param
                end
            end
            
            if params.u_squashX <= 0 or params.u_squashY <= 0 then
                return false, "u_squashX y u_squashY deben ser positivos"
            end
            if params.u_noiseFreq <= 0 then
                return false, "u_noiseFreq debe ser positivo"
            end
            
            return true, nil
        end
    }
}

-- Validar parámetros de shader crítico
function ShaderManager.validateShaderParams(shaderName, params)
    local validator = shaderDependencies.paramValidators[shaderName]
    if validator then
        return validator(params)
    end
    return true, nil -- Sin validador específico = válido
end

-- Verificar dependencias antes de inicializar
function ShaderManager.checkDependencies(shaderName)
    local deps = shaderDependencies.dependencies[shaderName]
    if not deps then return true end
    
    for _, dep in ipairs(deps) do
        if not ShaderManager.state.preloadStatus[dep] then
            print("⚠ Dependencia no satisfecha: " .. shaderName .. " requiere " .. dep)
            return false
        end
    end
    return true
end

-- Inicializar el gestor de shaders con orden de dependencias
function ShaderManager.init()
    print("=== SHADER MANAGER INITIALIZING (ORDERED) ===")

    -- Evitar doble init
    if ShaderManager.state.initialized then
        print("ShaderManager: init ya ejecutado, omitiendo re-inicialización")
        return
    end

    -- Inicializar cache
    shaderCache.lastCleanup = love.timer.getTime()

    -- Inicializar en orden de dependencias
    for _, shaderType in ipairs(shaderDependencies.initOrder) do
        ShaderManager.initializeShaderByType(shaderType)
    end
    
    -- Warmup de shaders para evitar stutter en primer uso
    ShaderManager.warmup()
    print("✓ ShaderManager initialized with " .. ShaderManager.getLoadedCount() .. " shaders")
    print("✓ Shader cache enabled with max size: " .. shaderCache.maxCacheSize)
    print("✓ Dependency-ordered initialization completed")
    ShaderManager.state.initialized = true
end

-- Inicializar shader específico por tipo
function ShaderManager.initializeShaderByType(shaderType)
    if shaderType == "base_images" then
        ShaderManager.createBaseImages()
        print("✓ Base images created")
        
    elseif shaderType == "star" then
        if StarShader and StarShader.init then
            StarShader.init()
            ShaderManager.state.shaders.star = StarShader.getShader()
            ShaderManager.state.preloadStatus.star = true
            print("✓ StarShader preloaded")
        end
        
    elseif shaderType == "star_instanced" then
        if ShaderManager.checkDependencies("star_instanced") then
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
        end
        
    elseif shaderType == "galactic_background" then
        if BackgroundManager and BackgroundManager.init then
            BackgroundManager.init()
            local GalacticBackground = require 'src.shaders.galactic_background'
            ShaderManager.state.shaders.galactic_background = GalacticBackground.getShader()
            ShaderManager.state.preloadStatus.galactic_background = true
            print("✓ Galactic Background shader loaded successfully")
        end
        
    elseif shaderType == "nebula" then
        if NebulasShaders and NebulasShaders.init then
            local success = NebulasShaders.init()
            if success then
                ShaderManager.state.shaders.nebula = NebulasShaders.getShader()
                ShaderManager.state.preloadStatus.nebula = true
                print("✓ NebulasShaders preloaded")
            else
                print("✗ NebulasShaders failed to preload")
            end
        end
        
    elseif shaderType == "asteroid" or shaderType == "station" or shaderType == "wormhole" then
        ShaderManager.createBasicShaders()
        
    elseif shaderType == "ancient_ruins" then
        if AncientRuinsStations and AncientRuinsStations.init then
            local success = AncientRuinsStations.init()
            if success then
                ShaderManager.state.shaders.ancient_ruins = AncientRuinsStations.getShader()
                ShaderManager.state.preloadStatus.ancient_ruins = true
                print("✓ Ancient Ruins shader preloaded")
            else
                print("✗ Ancient Ruins shader failed to preload")
            end
        end
    end
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
    // u_size eliminado: no se usa en el shader
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
        
        // Rotación de la esfera según el ángulo de vista (sin mat2 para compatibilidad GLSL ES)
        float c = cos(viewAngle);
        float s = sin(viewAngle);
        
        float sphere = 0.0;
        
        // Capa externa con parallax
        vec2 outerParallax = calculateParallax(uv, playerOffset, 0.3);
        vec2 outerRotated = vec2(c * outerParallax.x - s * outerParallax.y, s * outerParallax.x + c * outerParallax.y);
        vec2 outerScale = vec2(radius, radius * (0.3 + perspective * 0.5));
        float outerDist = length(outerRotated / outerScale);
        sphere += smoothstep(1.0, 0.6, outerDist) * 0.15;
        
        // Capa media con parallax más fuerte
        vec2 midParallax = calculateParallax(uv, playerOffset, 0.6);
        vec2 midRotated = vec2(c * midParallax.x - s * midParallax.y, s * midParallax.x + c * midParallax.y);
        vec2 midScale = vec2(radius * 0.7, radius * (0.2 + perspective * 0.4));
        float midDist = length(midRotated / midScale);
        sphere += smoothstep(1.0, 0.4, midDist) * 0.35;
        
        // Núcleo con parallax máximo
        vec2 coreParallax = calculateParallax(uv, playerOffset, 1.0);
        vec2 coreRotated = vec2(c * coreParallax.x - s * coreParallax.y, s * coreParallax.x + c * coreParallax.y);
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
            // Rotación manual (sin mat2 para compatibilidad GLSL ES)
            vec2 rotated_uv = vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);
            uv = rotated_uv;

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
    
    -- Nebulosas ahora manejadas por NebulasShaders (código movido a nebulas_shaders.lua)
    
    -- Shader de estaciones ahora manejado por StationShaders module
    
    -- Crear shaders si Love2D está disponible
    if love.graphics and love.graphics.newShader then
        local success, shader
        -- Asteroide shader con validación de parámetros
        success, shader = pcall(love.graphics.newShader, asteroidShaderCode)
        if success then
            ShaderManager.state.shaders.asteroid = shader
            ShaderManager.state.preloadStatus.asteroid = true
            
            -- Defaults seguros para uniforms con validación
            local asteroidParams = {
                u_squashX = 1.0,
                u_squashY = 1.0,
                u_noiseAmp = 0.10,
                u_noiseFreq = 12.0,
                u_seed = 0.0,
                u_rotation = 0.0
            }
            
            -- Validar parámetros antes del envío
            local isValid, error = ShaderManager.validateShaderParams("asteroid", asteroidParams)
            if isValid then
                ShaderManager.sendUniforms(shader, asteroidParams)
                print("✓ Asteroid shader initialized with validated parameters")
            else
                print("⚠ Asteroid shader parameter validation failed: " .. error)
            end
        end
        
        -- Nebulosa shader ahora manejado por NebulasShaders
        
        -- Estación shader (usando módulo StationShaders)
        local StationShaders = require 'src.shaders.station_shaders'
        if StationShaders.init() then
            ShaderManager.state.shaders.station = StationShaders.getShader()
            ShaderManager.state.preloadStatus.station = true
            print("✓ Station shader loaded successfully via StationShaders module")
        else
            print("✗ Failed to load Station shader via StationShaders module")
        end

        -- Wormhole shader - Consolidado con validación crítica de parámetros
        if not ShaderManager.state.shaders.wormhole then
            success, shader = pcall(love.graphics.newShader, wormholeShaderCode)
            if success then
                ShaderManager.state.shaders.wormhole = shader
                ShaderManager.state.preloadStatus.wormhole = true
                
                -- Defaults seguros para uniforms con validación crítica
                local wormholeParams = {
                    u_time = 0,
                    u_intensity = 1.0,
                    u_color = {0.5, 0.8, 1.0},
                    u_pulsePhase = 0,
                    u_playerPos = {0, 0},
                    u_wormholePos = {0, 0},
                    u_parallaxStrength = 1.0,
                    u_cameraZoom = 1.0
                }
                
                -- Validar parámetros críticos antes del envío
                local isValid, error = ShaderManager.validateShaderParams("wormhole", wormholeParams)
                if isValid then
                    ShaderManager.sendUniforms(shader, wormholeParams)
                    print("✓ Wormhole shader loaded successfully with validated parameters")
                else
                    print("⚠ Wormhole shader parameter validation failed: " .. error)
                    -- Usar parámetros mínimos seguros en caso de fallo
                    ShaderManager.sendUniforms(shader, {
                        u_time = 0,
                        u_intensity = 1.0,
                        u_color = {1.0, 1.0, 1.0},
                        u_pulsePhase = 0,
                        u_playerPos = {0, 0},
                        u_wormholePos = {0, 0},
                        u_parallaxStrength = 0.5,
                        u_cameraZoom = 1.0
                    })
                end
            else
                print("✗ Failed to load Wormhole shader (createBasicShaders): " .. tostring(shader))
            end
        end
        
        -- Galactic Background shader
        if BackgroundManager and BackgroundManager.init then
            BackgroundManager.init()
            local GalacticBackground = require 'src.shaders.galactic_background'
            ShaderManager.state.shaders.galactic_background = GalacticBackground.getShader()
            ShaderManager.state.preloadStatus.galactic_background = true
            print("✓ Galactic Background shader loaded successfully")
        else
            print("✗ Failed to load Galactic Background shader")
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
    
    -- Usar NebulasShaders para actualizar nebulosas
    if NebulasShaders and NebulasShaders.update then
        NebulasShaders.update(dt)
    end
    
    if ShaderManager.state.shaders.wormhole then
        ShaderManager.sendUniform(ShaderManager.state.shaders.wormhole, "u_time", currentTime)
    end
    
    -- Optimizar cache automáticamente
    ShaderManager.optimizeCache()
    
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
    
    -- Cargar nebulosas usando NebulasShaders
    if shaderType == "nebula" and NebulasShaders then
        if not ShaderManager.state.shaders.nebula then
            local success = NebulasShaders.init()
            if success then
                ShaderManager.state.shaders.nebula = NebulasShaders.getShader()
                ShaderManager.state.preloadStatus.nebula = true
                print("✓ Nebula shader ensured on-demand")
            else
                print("✗ ensureShaderLoaded(nebula) failed")
            end
        end
        return ShaderManager.state.preloadStatus.nebula
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
    if shaderType == "wormhole" then
        -- Usar shader ya cargado o cargarlo si no existe
        if not ShaderManager.state.shaders.wormhole and love.graphics and love.graphics.newShader and wormholeShaderCode then
            local ok, shader = pcall(love.graphics.newShader, wormholeShaderCode)
            if ok then
                ShaderManager.state.shaders.wormhole = shader
                ShaderManager.state.preloadStatus.wormhole = true
                ShaderManager.sendUniforms(shader, {
                    u_time = love.timer.getTime() or 0,
                    u_intensity = 1.0,
                    u_color = {0.5, 0.8, 1.0},
                    u_pulsePhase = 0,
                    u_playerPos = {0, 0},
                    u_wormholePos = {0, 0},
                    u_parallaxStrength = 1.0,
                    u_cameraZoom = 1.0
                })
                print("✓ Wormhole shader ensured on-demand")
            else
                print("✗ ensureShaderLoaded(wormhole) failed: " .. tostring(shader))
            end
        end
        return ShaderManager.state.preloadStatus.wormhole
    end
    if shaderType == "galactic_background" and BackgroundManager then
        if not ShaderManager.state.shaders.galactic_background and BackgroundManager.init then
            BackgroundManager.init()
            local GalacticBackground = require 'src.shaders.galactic_background'
            ShaderManager.state.shaders.galactic_background = GalacticBackground.getShader()
            ShaderManager.state.preloadStatus.galactic_background = true
            print("✓ Galactic Background shader ensured on-demand")
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

-- Sistema centralizado de gestión de estados de shaders
local currentShader = nil
local shaderStack = {}

-- OPTIMIZACIÓN: Función mejorada para establecer shader con verificación de estado
function ShaderManager.setShader(shaderName, params)
    local shader = nil
    
    if type(shaderName) == "string" then
        shader = ShaderManager.getShader(shaderName)
        if not shader then
            print("⚠ Shader '" .. shaderName .. "' no encontrado, usando fallback")
            return false
        end
    elseif shaderName and type(shaderName) == "userdata" then
        shader = shaderName
    end
    
    if shader then
        -- OPTIMIZACIÓN: Verificar si el shader ya está activo para evitar cambios redundantes
        if ShaderManager.state.currentActiveShader ~= shader then
            -- Registrar cambio de shader para profiling
            local actualShaderName = type(shaderName) == "string" and shaderName or "unknown"
            ShaderManager.recordShaderSwitch(actualShaderName)
            
            -- Guardar shader anterior en stack
            if currentShader then
                table.insert(shaderStack, currentShader)
            end
            
            love.graphics.setShader(shader)
            currentShader = shader
            ShaderManager.state.currentActiveShader = shader
            ShaderManager.state.shaderStateChanges = ShaderManager.state.shaderStateChanges + 1
            
            -- Limpiar cache de uniforms al cambiar shader
            ShaderManager.state.lastUniformValues = {}
        end
        
        -- Enviar parámetros si se proporcionan (con cache optimizado)
        if params and type(params) == "table" then
            ShaderManager.sendUniformsOptimized(shader, params)
        end
        
        return true
    end
    
    return false
end

-- OPTIMIZACIÓN: Función mejorada para desactivar shader con verificación de estado
function ShaderManager.unsetShader()
    if currentShader or ShaderManager.state.currentActiveShader then
        love.graphics.setShader()
        currentShader = nil
        ShaderManager.state.currentActiveShader = nil
        ShaderManager.state.shaderStateChanges = ShaderManager.state.shaderStateChanges + 1
        ShaderManager.state.lastUniformValues = {}
        return true
    end
    return false
end

-- OPTIMIZACIÓN: Función mejorada para restaurar shader con verificación de estado
function ShaderManager.popShader()
    if #shaderStack > 0 then
        local previousShader = table.remove(shaderStack)
        -- Solo cambiar si es diferente al actual
        if ShaderManager.state.currentActiveShader ~= previousShader then
            love.graphics.setShader(previousShader)
            currentShader = previousShader
            ShaderManager.state.currentActiveShader = previousShader
            ShaderManager.state.shaderStateChanges = ShaderManager.state.shaderStateChanges + 1
            ShaderManager.state.lastUniformValues = {}
        end
        return true
    else
        ShaderManager.unsetShader()
        return false
    end
end

-- Función para obtener el shader actual
function ShaderManager.getCurrentShader()
    return currentShader
end

-- OPTIMIZACIÓN: Función mejorada para limpiar stack con verificación de estado
function ShaderManager.clearShaderStack()
    shaderStack = {}
    if currentShader or ShaderManager.state.currentActiveShader then
        currentShader = nil
        ShaderManager.state.currentActiveShader = nil
        ShaderManager.state.shaderStateChanges = ShaderManager.state.shaderStateChanges + 1
        ShaderManager.state.lastUniformValues = {}
        love.graphics.setShader()
    end
end

-- OPTIMIZACIÓN: Sistema de batching para operaciones GPU
function ShaderManager.startBatch()
    ShaderManager.state.batchedOperations = {}
    return true
end

function ShaderManager.addToBatch(operation)
    if not ShaderManager.state.batchedOperations then
        ShaderManager.state.batchedOperations = {}
    end
    table.insert(ShaderManager.state.batchedOperations, operation)
end

function ShaderManager.executeBatch()
    if not ShaderManager.state.batchedOperations or #ShaderManager.state.batchedOperations == 0 then
        return true
    end
    
    local success = true
    local operationsExecuted = 0
    
    -- Agrupar operaciones por shader para minimizar cambios de estado
    local operationsByShader = {}
    for _, operation in ipairs(ShaderManager.state.batchedOperations) do
        local shader = operation.shader
        if not operationsByShader[shader] then
            operationsByShader[shader] = {}
        end
        table.insert(operationsByShader[shader], operation)
    end
    
    -- Ejecutar operaciones agrupadas
    for shader, operations in pairs(operationsByShader) do
        if ShaderManager.setShader(shader) then
            for _, operation in ipairs(operations) do
                if operation.type == "uniform" then
                    if not ShaderManager.sendUniformsOptimized(shader, operation.uniforms) then
                        success = false
                    end
                elseif operation.type == "draw" and operation.drawFunc then
                    local ok, err = pcall(operation.drawFunc)
                    if not ok then
                        print("⚠ Error en operación de dibujo batch: " .. tostring(err))
                        success = false
                    end
                end
                operationsExecuted = operationsExecuted + 1
            end
        else
            success = false
        end
    end
    
    -- Limpiar batch
    ShaderManager.state.batchedOperations = {}
    
    return success, operationsExecuted
end

function ShaderManager.clearBatch()
    ShaderManager.state.batchedOperations = {}
end

-- Envío seguro de uniforms con validación mejorada
function ShaderManager.sendUniform(shader, name, value)
    if not shader or not name then
        print("⚠ Shader o nombre de uniform inválido")
        return false
    end
    
    local valueType = type(value)
    if valueType ~= "number" and valueType ~= "table" and valueType ~= "userdata" then
        print("⚠ Tipo de uniform no válido: " .. valueType)
        return false
    end
    
    -- Validaciones específicas por tipo
    if valueType == "table" then
        for i, v in ipairs(value) do
            if type(v) ~= "number" then
                print("⚠ Array contiene valores no numéricos en posición " .. i)
                return false
            end
        end
        local len = #value
        if len < 1 or len > 4 then
            print("⚠ Longitud de vector inválida: " .. len)
            return false
        end
    elseif valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            print("⚠ Valor numérico inválido (NaN o infinito)")
            return false
        end
    end
    
    local success = pcall(function()
        shader:send(name, value)
    end)
    
    if not success then
        print("⚠ Failed to send uniform '" .. name .. "' to shader")
        return false
    end
    
    return true
end

-- OPTIMIZACIÓN: Envío optimizado de uniforms con cache para evitar redundancia
function ShaderManager.sendUniformsOptimized(shader, uniforms)
    if not shader or not uniforms then
        return false
    end
    
    -- Determinar tipo de shader para validación crítica
    local shaderType = nil
    for sType, sShader in pairs(ShaderManager.state.shaders) do
        if sShader == shader then
            shaderType = sType
            break
        end
    end
    
    -- Validar parámetros críticos si es un shader conocido
    if shaderType and shaderDependencies.paramValidators[shaderType] then
        local isValid, error = ShaderManager.validateShaderParams(shaderType, uniforms)
        if not isValid then
            print("⚠ Validación crítica falló para shader '" .. shaderType .. "': " .. error)
            return false
        end
    end
    
    local allSuccess = true
    local uniformsChanged = 0
    
    for name, value in pairs(uniforms) do
        -- OPTIMIZACIÓN: Verificar si el uniform ha cambiado antes de enviarlo
        local cacheKey = tostring(shader) .. "_" .. name
        local lastValue = ShaderManager.state.lastUniformValues[cacheKey]
        
        local valueChanged = false
        if lastValue == nil then
            valueChanged = true
        elseif type(value) == "table" and type(lastValue) == "table" then
            -- Comparar arrays/vectores
            if #value ~= #lastValue then
                valueChanged = true
            else
                for i = 1, #value do
                    if value[i] ~= lastValue[i] then
                        valueChanged = true
                        break
                    end
                end
            end
        elseif value ~= lastValue then
            valueChanged = true
        end
        
        if valueChanged then
            if ShaderManager.sendUniform(shader, name, value) then
                -- Guardar valor en cache
                if type(value) == "table" then
                    ShaderManager.state.lastUniformValues[cacheKey] = {table.unpack(value)}
                else
                    ShaderManager.state.lastUniformValues[cacheKey] = value
                end
                uniformsChanged = uniformsChanged + 1
                ShaderManager.state.uniformsSent = ShaderManager.state.uniformsSent + 1
            else
                allSuccess = false
            end
        end
    end
    
    return allSuccess
end

-- Envío de múltiples uniforms de forma segura con validación crítica (función original mantenida para compatibilidad)
function ShaderManager.sendUniforms(shader, uniforms)
    if not shader or not uniforms then
        return false
    end
    
    -- Determinar tipo de shader para validación crítica
    local shaderType = nil
    for sType, sShader in pairs(ShaderManager.state.shaders) do
        if sShader == shader then
            shaderType = sType
            break
        end
    end
    
    -- Validar parámetros críticos si es un shader conocido
    if shaderType and shaderDependencies.paramValidators[shaderType] then
        local isValid, error = ShaderManager.validateShaderParams(shaderType, uniforms)
        if not isValid then
            print("⚠ Validación crítica falló para shader '" .. shaderType .. "': " .. error)
            return false
        end
    end
    
    local allSuccess = true
    for name, value in pairs(uniforms) do
        if not ShaderManager.sendUniform(shader, name, value) then
            allSuccess = false
        else
            ShaderManager.state.uniformsSent = ShaderManager.state.uniformsSent + 1
        end
    end
    
    return allSuccess
end

-- OPTIMIZACIÓN: Sistema de cache mejorado con mejor gestión de memoria
function ShaderManager.optimizeCache()
    local currentTime = love.timer.getTime()
    
    -- Limpiar cache si es necesario
    if currentTime - shaderCache.lastCleanup > shaderCache.cleanupInterval then
        local cacheSize = 0
        for _ in pairs(shaderCache.compiledShaders) do
            cacheSize = cacheSize + 1
        end
        
        if cacheSize > shaderCache.maxCacheSize then
            -- Encontrar shaders menos usados
            local sortedAccess = {}
            for shaderName, accessTime in pairs(shaderCache.accessTimes) do
                table.insert(sortedAccess, {name = shaderName, time = accessTime})
            end
            
            table.sort(sortedAccess, function(a, b) return a.time < b.time end)
            
            -- Eliminar los 25% menos usados
            local toRemove = math.floor(cacheSize * 0.25)
            for i = 1, toRemove do
                local shaderName = sortedAccess[i].name
                ShaderManager.releaseShader(shaderName)
            end
            
            print("🧹 Cache optimizado: eliminados " .. toRemove .. " shaders")
        end
        
        shaderCache.lastCleanup = currentTime
    end
    
    -- Optimizar caché de texturas también
    ShaderManager.optimizeTextureCache()
end

-- OPTIMIZACIÓN: Función para liberar shader específico de forma segura
function ShaderManager.releaseShader(shaderName)
    if not shaderCache.compiledShaders[shaderName] then
        return false
    end
    
    local shader = shaderCache.compiledShaders[shaderName]
    
    -- Verificar si el shader está actualmente en uso
    if ShaderManager.state.currentActiveShader == shader then
        ShaderManager.unsetShader()
    end
    
    -- Remover del stack si está presente
    for i = #shaderStack, 1, -1 do
        if shaderStack[i] == shader then
            table.remove(shaderStack, i)
        end
    end
    
    -- Liberar recursos
    if shader and shader.release then
        shader:release()
    end
    
    -- Limpiar uniforms relacionados
    if ShaderManager.state.lastUniformValues then
        for key, _ in pairs(ShaderManager.state.lastUniformValues) do
            if key:find(shaderName, 1, true) then
                ShaderManager.state.lastUniformValues[key] = nil
            end
        end
    end
    
    -- Limpiar del cache
    shaderCache.compiledShaders[shaderName] = nil
    shaderCache.shaderSources[shaderName] = nil
    shaderCache.accessTimes[shaderName] = nil
    
    return true
end

-- OPTIMIZACIÓN: Función para optimizar caché de texturas
function ShaderManager.optimizeTextureCache()
    local maxTextureCacheSize = 15
    local currentSize = 0
    
    -- Verificar que textureCache.textures existe
    if not ShaderManager.state.textureCache or not ShaderManager.state.textureCache.textures then
        return
    end
    
    for _ in pairs(ShaderManager.state.textureCache.textures) do
        currentSize = currentSize + 1
    end
    
    if currentSize > maxTextureCacheSize then
        local textureList = {}
        for name, data in pairs(ShaderManager.state.textureCache.textures) do
            table.insert(textureList, {name = name, lastAccess = data.lastAccess or 0})
        end
        
        table.sort(textureList, function(a, b) return a.lastAccess < b.lastAccess end)
        
        local toRemove = currentSize - maxTextureCacheSize
        for i = 1, toRemove do
            local textureName = textureList[i].name
            if ShaderManager.state.textureCache.textures[textureName] and ShaderManager.state.textureCache.textures[textureName].texture then
                ShaderManager.state.textureCache.textures[textureName].texture:release()
            end
            ShaderManager.state.textureCache.textures[textureName] = nil
        end
    end
end

-- OPTIMIZACIÓN: Función para cleanup completo de recursos
function ShaderManager.cleanup()
    -- Limpiar shader activo
    ShaderManager.unsetShader()
    
    -- Liberar todos los shaders compilados
    for name, shader in pairs(shaderCache.compiledShaders) do
        if shader and shader.release then
            shader:release()
        end
    end
    
    -- Liberar todas las texturas
    if ShaderManager.state.textureCache and ShaderManager.state.textureCache.textures then
        for name, data in pairs(ShaderManager.state.textureCache.textures) do
            if data.texture and data.texture.release then
                data.texture:release()
            end
        end
    end
    
    -- Limpiar cachés
    shaderCache.compiledShaders = {}
    shaderCache.shaderSources = {}
    shaderCache.accessTimes = {}
    ShaderManager.state.textureCache.textures = {}
    ShaderManager.state.textureCache.currentSize = 0
    ShaderManager.state.uniformCache = {}
    
    -- Resetear estado
    ShaderManager.state.currentActiveShader = nil
    ShaderManager.state.shaderStateChanges = 0
    ShaderManager.state.uniformsSent = 0
    ShaderManager.state.batchedOperations = {}
    ShaderManager.state.lastUniformValues = {}
    
    -- Limpiar stack
    shaderStack = {}
    currentShader = nil
    
    -- Forzar garbage collection
    collectgarbage("collect")
end

-- OPTIMIZACIÓN: Sistema de profiling de rendimiento GPU
ShaderManager.profiling = {
    enabled = false,
    frameData = {},
    currentFrame = 1,
    maxFrames = 60, -- Mantener datos de 60 frames
    shaderSwitches = 0,
    uniformCalls = 0,
    batchOperations = 0,
    frameStartTime = 0,
    shaderTimes = {},
    lastGPUMemory = 0
}

-- Función para habilitar/deshabilitar profiling
function ShaderManager.setProfilingEnabled(enabled)
    ShaderManager.profiling.enabled = enabled
    -- Logs eliminados: no son necesarios para el funcionamiento
end

-- Función para iniciar profiling de frame
function ShaderManager.startFrameProfiling()
    if not ShaderManager.profiling.enabled then return end
    
    ShaderManager.profiling.frameStartTime = love.timer.getTime()
    ShaderManager.profiling.shaderSwitches = 0
    ShaderManager.profiling.uniformCalls = 0
    ShaderManager.profiling.batchOperations = 0
end

-- Función para finalizar profiling de frame
function ShaderManager.endFrameProfiling()
    if not ShaderManager.profiling.enabled then return end
    
    local frameTime = love.timer.getTime() - ShaderManager.profiling.frameStartTime
    local currentFrame = ShaderManager.profiling.currentFrame
    
    -- Obtener memoria GPU aproximada (usando estadísticas de LÖVE)
    local stats = love.graphics.getStats()
    local gpuMemory = stats.texturememory or 0
    
    ShaderManager.profiling.frameData[currentFrame] = {
        frameTime = frameTime,
        shaderSwitches = ShaderManager.profiling.shaderSwitches,
        uniformCalls = ShaderManager.profiling.uniformCalls,
        batchOperations = ShaderManager.profiling.batchOperations,
        gpuMemory = gpuMemory,
        timestamp = love.timer.getTime()
    }
    
    -- Avanzar al siguiente frame
    ShaderManager.profiling.currentFrame = (currentFrame % ShaderManager.profiling.maxFrames) + 1
end

-- Función para registrar cambio de shader
function ShaderManager.recordShaderSwitch(shaderName)
    if not ShaderManager.profiling.enabled then return end
    
    ShaderManager.profiling.shaderSwitches = ShaderManager.profiling.shaderSwitches + 1
    
    -- Registrar tiempo por shader
    if not ShaderManager.profiling.shaderTimes[shaderName] then
        ShaderManager.profiling.shaderTimes[shaderName] = {
            totalTime = 0,
            calls = 0,
            lastStart = love.timer.getTime()
        }
    else
        ShaderManager.profiling.shaderTimes[shaderName].calls = ShaderManager.profiling.shaderTimes[shaderName].calls + 1
        ShaderManager.profiling.shaderTimes[shaderName].lastStart = love.timer.getTime()
    end
end

-- Función para registrar llamada de uniform
function ShaderManager.recordUniformCall()
    if not ShaderManager.profiling.enabled then return end
    ShaderManager.profiling.uniformCalls = ShaderManager.profiling.uniformCalls + 1
end

-- Función para registrar operación batch
function ShaderManager.recordBatchOperation()
    if not ShaderManager.profiling.enabled then return end
    ShaderManager.profiling.batchOperations = ShaderManager.profiling.batchOperations + 1
end

-- Función para obtener estadísticas de rendimiento
function ShaderManager.getPerformanceStats()
    if not ShaderManager.profiling.enabled then
        return { error = "Profiling no está habilitado" }
    end
    
    local frameData = ShaderManager.profiling.frameData
    local validFrames = {}
    
    -- Filtrar frames válidos
    for i = 1, ShaderManager.profiling.maxFrames do
        if frameData[i] then
            table.insert(validFrames, frameData[i])
        end
    end
    
    if #validFrames == 0 then
        return { error = "No hay datos de profiling disponibles" }
    end
    
    -- Calcular estadísticas
    local totalFrameTime = 0
    local totalShaderSwitches = 0
    local totalUniformCalls = 0
    local totalBatchOps = 0
    local maxFrameTime = 0
    local minFrameTime = math.huge
    
    for _, frame in ipairs(validFrames) do
        totalFrameTime = totalFrameTime + frame.frameTime
        totalShaderSwitches = totalShaderSwitches + frame.shaderSwitches
        totalUniformCalls = totalUniformCalls + frame.uniformCalls
        totalBatchOps = totalBatchOps + frame.batchOperations
        maxFrameTime = math.max(maxFrameTime, frame.frameTime)
        minFrameTime = math.min(minFrameTime, frame.frameTime)
    end
    
    local avgFrameTime = totalFrameTime / #validFrames
    local avgShaderSwitches = totalShaderSwitches / #validFrames
    local avgUniformCalls = totalUniformCalls / #validFrames
    local avgBatchOps = totalBatchOps / #validFrames
    
    return {
        frames = #validFrames,
        avgFrameTime = avgFrameTime,
        maxFrameTime = maxFrameTime,
        minFrameTime = minFrameTime,
        avgShaderSwitches = avgShaderSwitches,
        avgUniformCalls = avgUniformCalls,
        avgBatchOperations = avgBatchOps,
        totalStateChanges = ShaderManager.state.shaderStateChanges,
        totalUniformsSent = ShaderManager.state.uniformsSent,
        shaderTimes = ShaderManager.profiling.shaderTimes,
        cacheStats = {
            shadersLoaded = ShaderManager.getLoadedCount(),
            texturesLoaded = 0 -- Se calculará dinámicamente
        }
    }
end

-- Función eliminada: printPerformanceReport no se usaba en el código

-- Obtener estadísticas de carga
function ShaderManager.getStats()
    local loaded = ShaderManager.getLoadedCount()
    local total = #ShaderManager.state.config.preloadPriority
    
    return {
        loaded = loaded,
        total = total,
        percentage = (loaded / total) * 100,
        status = ShaderManager.state.preloadStatus,
        current_shader = currentShader and "active" or "none",
        shader_stack_depth = #shaderStack
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

-- Funciones duplicadas eliminadas - usar las del sistema centralizado arriba

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
