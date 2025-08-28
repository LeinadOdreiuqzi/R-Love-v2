-- Fullscreen Manager - Gestión robusta de pantalla completa
-- Garantiza compatibilidad total con la configuración del juego y manejo de eventos

local FullscreenManager = {}

-- Estado interno del manager
FullscreenManager.state = {
    isFullscreen = false,           -- Estado actual
    windowedMode = {                -- Configuración modo ventana
        width = 800,
        height = 600,
        x = nil,
        y = nil,
        resizable = true,
        borderless = false,
        display = 1
    },
    fullscreenMode = {              -- Configuración modo pantalla completa
        fullscreentype = "desktop", -- Puede ser "desktop" o "exclusive"
        display = 1,
        vsync = true
    },
    transitioning = false,          -- Flag para evitar transiciones simultáneas
    lastToggleTime = 0              -- Control de debounce
}

-- Configuración del manager
FullscreenManager.config = {
    debounceTime = 0.2,             -- Tiempo mínimo entre toggles (segundos)
    preserveWindowPosition = true,   -- Preservar posición de ventana
    autoCenter = true,              -- Centrar ventana al restaurar
    transitionDelay = 0.1           -- Delay para transiciones suaves
}

-- Inicializar el manager
function FullscreenManager.init()
    -- Obtener configuración actual de la ventana
    local width, height, flags = love.window.getMode()
    
    FullscreenManager.state.isFullscreen = flags.fullscreen
    
    if not FullscreenManager.state.isFullscreen then
        -- Guardar configuración de ventana actual
        FullscreenManager.state.windowedMode.width = width
        FullscreenManager.state.windowedMode.height = height
        FullscreenManager.state.windowedMode.resizable = flags.resizable
        FullscreenManager.state.windowedMode.borderless = flags.borderless
        FullscreenManager.state.windowedMode.display = flags.display or 1
        
        -- Obtener posición de ventana si es posible
        local x, y = love.window.getPosition()
        if x and y then
            FullscreenManager.state.windowedMode.x = x
            FullscreenManager.state.windowedMode.y = y
        end
    end
    
    -- Configurar modo pantalla completa desde conf.lua o por defecto
    FullscreenManager.state.fullscreenMode.fullscreentype = flags.fullscreentype or "desktop"
    FullscreenManager.state.fullscreenMode.display = flags.display or 1
    FullscreenManager.state.fullscreenMode.vsync = flags.vsync
    
    print("FullscreenManager initialized - Current mode: " .. 
          (FullscreenManager.state.isFullscreen and "Fullscreen" or "Windowed"))
end

-- Alternar entre modo ventana y pantalla completa
function FullscreenManager.toggle()
    local currentTime = love.timer.getTime()
    
    -- Verificar debounce
    if currentTime - FullscreenManager.state.lastToggleTime < FullscreenManager.config.debounceTime then
        return false
    end
    
    -- Evitar transiciones simultáneas
    if FullscreenManager.state.transitioning then
        return false
    end
    
    FullscreenManager.state.transitioning = true
    FullscreenManager.state.lastToggleTime = currentTime
    
    local success = false
    
    if FullscreenManager.state.isFullscreen then
        success = FullscreenManager.setWindowed()
    else
        success = FullscreenManager.setFullscreen()
    end
    
    -- Delay breve para transición suave
    if success and FullscreenManager.config.transitionDelay > 0 then
        love.timer.sleep(FullscreenManager.config.transitionDelay)
    end
    
    FullscreenManager.state.transitioning = false
    return success
end

-- Cambiar a modo pantalla completa
function FullscreenManager.setFullscreen()
    if FullscreenManager.state.isFullscreen then
        return true -- Ya está en pantalla completa
    end
    
    -- Guardar configuración actual de ventana antes del cambio
    local width, height, flags = love.window.getMode()
    if not flags.fullscreen then
        FullscreenManager.state.windowedMode.width = width
        FullscreenManager.state.windowedMode.height = height
        FullscreenManager.state.windowedMode.resizable = flags.resizable
        FullscreenManager.state.windowedMode.borderless = flags.borderless
        
        -- Guardar posición si está configurado
        if FullscreenManager.config.preserveWindowPosition then
            local x, y = love.window.getPosition()
            if x and y then
                FullscreenManager.state.windowedMode.x = x
                FullscreenManager.state.windowedMode.y = y
            end
        end
    end
    
    -- Configurar flags para pantalla completa
    local fullscreenFlags = {
        fullscreen = true,
        fullscreentype = FullscreenManager.state.fullscreenMode.fullscreentype,
        vsync = FullscreenManager.state.fullscreenMode.vsync,
        display = FullscreenManager.state.fullscreenMode.display,
        resizable = false,
        borderless = false
    }
    
    -- Aplicar cambio de modo
    local success = love.window.setMode(0, 0, fullscreenFlags)
    
    if success then
        FullscreenManager.state.isFullscreen = true
        print("Switched to fullscreen mode")
        
        -- Notificar a otros sistemas del cambio
        FullscreenManager.onModeChanged("fullscreen")
    else
        print("Failed to switch to fullscreen mode")
    end
    
    return success
end

-- Cambiar a modo ventana
function FullscreenManager.setWindowed()
    if not FullscreenManager.state.isFullscreen then
        return true -- Ya está en modo ventana
    end
    
    -- Configurar flags para modo ventana
    local windowedFlags = {
        fullscreen = false,
        resizable = FullscreenManager.state.windowedMode.resizable,
        borderless = FullscreenManager.state.windowedMode.borderless,
        display = FullscreenManager.state.windowedMode.display,
        vsync = FullscreenManager.state.fullscreenMode.vsync
    }
    
    -- Aplicar cambio de modo
    local success = love.window.setMode(
        FullscreenManager.state.windowedMode.width,
        FullscreenManager.state.windowedMode.height,
        windowedFlags
    )
    
    if success then
        FullscreenManager.state.isFullscreen = false
        print("Switched to windowed mode (" .. 
              FullscreenManager.state.windowedMode.width .. "x" .. 
              FullscreenManager.state.windowedMode.height .. ")")
        
        -- Restaurar posición de ventana
        if FullscreenManager.config.preserveWindowPosition and 
           FullscreenManager.state.windowedMode.x and 
           FullscreenManager.state.windowedMode.y then
            love.window.setPosition(
                FullscreenManager.state.windowedMode.x,
                FullscreenManager.state.windowedMode.y
            )
        elseif FullscreenManager.config.autoCenter then
            -- Centrar ventana si no hay posición guardada
            FullscreenManager.centerWindow()
        end
        
        -- Notificar a otros sistemas del cambio
        FullscreenManager.onModeChanged("windowed")
    else
        print("Failed to switch to windowed mode")
    end
    
    return success
end

-- Centrar ventana en la pantalla
function FullscreenManager.centerWindow()
    local displayIndex = FullscreenManager.state.windowedMode.display or 1
    local displayWidth, displayHeight = love.window.getDisplayDimensions(displayIndex)
    
    if displayWidth and displayHeight then
        local windowWidth = FullscreenManager.state.windowedMode.width
        local windowHeight = FullscreenManager.state.windowedMode.height
        
        local x = math.floor((displayWidth - windowWidth) / 2)
        local y = math.floor((displayHeight - windowHeight) / 2)
        
        love.window.setPosition(x, y)
        
        -- Actualizar posición guardada
        FullscreenManager.state.windowedMode.x = x
        FullscreenManager.state.windowedMode.y = y
    end
end

-- Callback cuando cambia el modo de pantalla
function FullscreenManager.onModeChanged(newMode)
    -- Hook para que otros sistemas se adapten al cambio
    -- Por ejemplo, notificar a la cámara, UI, etc.
    
    if _G.camera and _G.camera.updateScreenDimensions then
        _G.camera:updateScreenDimensions()
    end
    
    -- Notificar al Map si tiene función de actualización de dimensiones
    if Map and Map.updateScreenDimensions then
        Map.updateScreenDimensions()
    end
    
    -- Actualizar LoadingScreen si está activo
    if LoadingScreen and LoadingScreen.resize then
        LoadingScreen.resize(love.graphics.getWidth(), love.graphics.getHeight())
    end
end

-- Manejar evento de redimensionamiento (integración con love.resize)
function FullscreenManager.handleResize(w, h)
    if not FullscreenManager.state.transitioning then
        -- Actualizar dimensiones guardadas solo si no estamos en transición
        if not FullscreenManager.state.isFullscreen then
            FullscreenManager.state.windowedMode.width = w
            FullscreenManager.state.windowedMode.height = h
        end
    end
end

-- Obtener estado actual
function FullscreenManager.isFullscreen()
    return FullscreenManager.state.isFullscreen
end

-- Obtener información del modo actual
function FullscreenManager.getCurrentMode()
    return {
        isFullscreen = FullscreenManager.state.isFullscreen,
        width = love.graphics.getWidth(),
        height = love.graphics.getHeight(),
        transitioning = FullscreenManager.state.transitioning
    }
end

-- Configurar dimensiones de ventana (para uso desde configuración)
function FullscreenManager.setWindowedSize(width, height)
    FullscreenManager.state.windowedMode.width = width
    FullscreenManager.state.windowedMode.height = height
    
    -- Aplicar inmediatamente si estamos en modo ventana
    if not FullscreenManager.state.isFullscreen then
        love.window.setMode(width, height, {
            fullscreen = false,
            resizable = FullscreenManager.state.windowedMode.resizable,
            borderless = FullscreenManager.state.windowedMode.borderless
        })
    end
end

-- Configurar tipo de pantalla completa
function FullscreenManager.setFullscreenType(fstype)
    if fstype == "desktop" or fstype == "exclusive" then
        FullscreenManager.state.fullscreenMode.fullscreentype = fstype
        print("Fullscreen type set to: " .. fstype)
    else
        print("Invalid fullscreen type. Use 'desktop' or 'exclusive'")
    end
end

-- Obtener estadísticas del manager
function FullscreenManager.getStats()
    return {
        currentMode = FullscreenManager.state.isFullscreen and "Fullscreen" or "Windowed",
        windowedSize = FullscreenManager.state.windowedMode.width .. "x" .. FullscreenManager.state.windowedMode.height,
        fullscreenType = FullscreenManager.state.fullscreenMode.fullscreentype,
        transitioning = FullscreenManager.state.transitioning,
        preservePosition = FullscreenManager.config.preserveWindowPosition
    }
end

return FullscreenManager