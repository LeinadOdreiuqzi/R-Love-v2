-- src/states/station/engine/config.lua
-- Constantes centrales del motor de interiores Metroidvania.
-- Todo el "game feel" (física, cámara, puertas) se ajusta desde aquí.

local C = {}

-- Resolución virtual y adaptación a pantalla ------------------------------
C.ADAPTIVE_VIEWPORT = true      -- true: el viewport se adapta al 100% del ancho y largo del monitor (sin franjas negras)
C.TARGET_VIEW_H = 320           -- altura vertical virtual objetivo para calcular la escala automática
C.PIXEL_SCALE = nil             -- nil = automático según el monitor; número (ej. 2, 3) = escala entera fija
C.VIEW_W = 480                  -- dimensiones base / fallback
C.VIEW_H = 270
C.INTEGER_SCALE = true          -- escalado entero para píxeles nítidos

-- Rejilla -----------------------------------------------------------------
C.TILE = 16
C.SCREEN_TW = 30                -- tiles por pantalla (ancho)
C.SCREEN_TH = 17                -- tiles por pantalla (alto)
C.SCREEN_W = C.SCREEN_TW * C.TILE   -- 480 px
C.SCREEN_H = C.SCREEN_TH * C.TILE   -- 272 px

-- Jugador -----------------------------------------------------------------
C.player = {
    w = 10,
    h = 20,
    runSpeed = 112,             -- ~7 tiles/s
    groundAccel = 1400,
    groundDecel = 1900,
    airAccel = 1050,
    airDecel = 650,
    gravity = 900,
    fallGravityMult = 1.55,     -- caída más pesada que la subida
    maxFallSpeed = 340,
    jumpHeight = 56,            -- ~3.5 tiles
    jumpCutMult = 0.45,         -- salto variable al soltar
    coyoteTime = 0.10,
    jumpBufferTime = 0.12,
    dropThroughTime = 0.20,     -- atravesar plataformas one-way (abajo + salto)

    jetpack = {
        enabled = false,        -- desactivado temporalmente (futura habilidad)
        fuelMax = 1.2,
        rechargeGround = 1.0,
        rechargeAir = 0.0,
        thrust = 1500,
        maxAscendSpeed = 160,
    },
}
C.player.jumpVelocity = math.sqrt(2 * C.player.gravity * C.player.jumpHeight)

-- Cámara (estilo Hollow Knight) ------------------------------------------
C.camera = {
    deadzoneW = 40,             -- zona muerta horizontal (px virtuales)
    deadzoneUp = 36,            -- zona muerta vertical en el aire
    deadzoneDown = 20,
    lookAhead = 36,             -- adelanto en dirección de la mirada
    lookAheadSpeed = 3.0,
    followX = 7.0,
    followYGround = 5.0,        -- re-centrado al pisar suelo
    followYAir = 6.0,
    verticalOffset = 24,        -- el jugador queda algo por debajo del centro
    fallLookThreshold = 260,    -- velocidad de caída que activa "mirar abajo"
    fallLookAhead = 40,
}

-- Puertas -------------------------------------------------------------------
C.door = {
    openTime = 0.16,
    closeTime = 0.16,
    autoCloseDelay = 0.6,       -- se cierran solas tras alejarse el jugador
    length = 3,                 -- tamaño en tiles (alto en laterales, ancho en escotillas)
}

-- Transición entre salas -------------------------------------------------
C.transition = {
    panTime = 0.50,
    walkInTime = 0.22,
    walkInSpeedMult = 0.7,
    upwardPop = 250,            -- impulso al salir por una escotilla de suelo
}

-- Paleta base (interiores metálicos) ---------------------------------------
C.palette = {
    clear      = { 0.015, 0.015, 0.025 },
    letterbox  = { 0.0, 0.0, 0.0 },
    backWall   = { 0.065, 0.075, 0.105 },
    backPanel  = { 0.085, 0.097, 0.135 },
    backSeam   = { 0.045, 0.052, 0.075 },
    bgStruct   = { 0.115, 0.132, 0.175 },
    bgStructHi = { 0.160, 0.182, 0.235 },
    solid      = { 0.205, 0.232, 0.290 },
    solidInner = { 0.120, 0.137, 0.180 },
    solidLight = { 0.380, 0.425, 0.510 },
    solidDark  = { 0.085, 0.095, 0.130 },
    rivet      = { 0.290, 0.330, 0.410 },
    oneway     = { 0.430, 0.470, 0.550 },
    onewayDark = { 0.180, 0.200, 0.250 },
    doorFrame  = { 0.260, 0.290, 0.350 },
    doorShut   = { 0.150, 0.170, 0.215 },
    windowGlass = { 0.080, 0.220, 0.350, 0.35 },
    windowFrame = { 0.220, 0.260, 0.330 },
    player     = { 0.880, 0.920, 0.980 },
    playerDark = { 0.420, 0.470, 0.560 },
    visor      = { 0.350, 0.850, 1.000 },
}

return C
