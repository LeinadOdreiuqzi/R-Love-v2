-- src/states/station/rooms/ring_station/ring_command.lua
-- Puesto de Mando del Cuadrante Solaris (60x34 tiles, 960x544 px).
-- Centro neurálgico de operaciones y navegación del sector del anillo:
-- puente elevado de supervisión, consolas de computación de vuelo
-- y cúpula de observación orientada hacia el eje central del toroide.

local Builder = require 'src.states.station.engine.builder'

local b = Builder.new("ring_command", 60, 34, {
    name = "Puesto de Mando · Cuadrante Solaris",
    accent = { 0.70, 0.50, 1.00 },
})

-- 1. Casco perimetral blindado (1 tile)
b:box(1, 1, 60, 34, '#', 1)

-- 2. Suelo continuo del anillo (Deck Exterior)
b:hwall(1, 31, 60, 4)

-- 3. Cúpula Táctica Panorámica Total (Abarca todo el fondo de la sala)
-- Desde la pared izquierda (col 2) hasta la derecha (col 59) y desde el techo (row 2) hasta el suelo (row 30).
-- 58 tiles de ancho x 29 tiles de alto = 928x464 px.
-- El puente de mando completo queda envuelto por el cosmos con tinte táctico de baja refracción.
b:wideScreen(2, 2, 58, 29, {
    tint = { 0.10, 0.08, 0.20, 0.20 },
})

-- 4. Puente de mando superior suspendido frente a la cúpula
b:supportedPlatform(14, 14, 32, 'pillars')

-- 5. Consolas elevadas de monitoreo táctico y banco de datos
b:stamp(8, 16, {
    "########",
    "#......#",
    "#..==..#",
    "########",
})

b:stamp(44, 16, {
    "########",
    "#......#",
    "#..==..#",
    "########",
})

-- 6. Pilares estructurales de soporte
b:pillar(12, 3, 28)
b:pillar(48, 3, 28)

-- 7. Plataformas intermedias de acceso al puente con ménsulas
b:supportedPlatform(6, 23, 10, 'brackets')
b:supportedPlatform(44, 23, 10, 'brackets')

-- 8. Puertas Metroid (row = 28):
-- - Izquierda hacia ring_habitat
-- - Derecha hacia ring_sector_omega
b:door("left", 28)
b:door("right", 28)

-- 9. Spawn secundario
b:spawn("default", 6, 30)

return b:build()
