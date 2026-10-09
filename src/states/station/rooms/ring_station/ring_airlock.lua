-- src/states/station/rooms/ring_station/ring_airlock.lua
-- Esclusa de Atraque Periférica (60x34 tiles, 960x544 px).
-- Muelle de llegada donde atraca la nave: cámara de despresurización,
-- consola de control de atraque, pasarelas con soportes y ventanal de supervisión.

local Builder = require 'src.states.station.engine.builder'

local b = Builder.new("ring_airlock", 60, 34, {
    name = "Esclusa Periférica · Muelle 01",
    accent = { 0.35, 0.90, 0.75 },
})

-- 1. Casco perimetral blindado (1 tile)
b:box(1, 1, 60, 34, '#', 1)

-- 2. Suelo principal continuo del anillo (Deck Exterior)
b:hwall(1, 31, 60, 4)

-- 3. Ventanal Panorámico Total de la Esclusa (Abarca todo el fondo de la sala)
-- Desde la pared izquierda (col 2) hasta la derecha (col 59) y desde el techo (row 2) hasta el suelo (row 30).
-- 58 tiles de ancho x 29 tiles de alto = 928x464 px.
-- Toda la esclusa y sus pasarelas quedan inmersas frente al vacío cósmico exterior.
b:wideScreen(2, 2, 58, 29)

-- 4. Pasarela elevada de supervisión de atraque (soportada por pilares)
b:supportedPlatform(14, 18, 30, 'pillars')

-- 5. Pilares estructurales de soporte de la cubierta del anillo
b:pillar(12, 2, 29)
b:pillar(46, 2, 29)

-- 6. Plataformas intermedias de acceso técnico con ménsulas
b:supportedPlatform(6, 24, 10, 'brackets')
b:supportedPlatform(38, 24, 12, 'brackets')

-- 7. Consola de control de presurización (estampado ASCII)
b:stamp(4, 16, {
    "########",
    "#......#",
    "#..==..#",
    "########",
})

-- 8. Mampara de descompresión superior (arco suspendido)
b:stamp(46, 14, {
    "########",
    "#......#",
    "########",
})

-- 9. Puerta derecha hacia el Gran Paseo (row = 28)
b:door("right", 28)

-- 10. Punto de spawn inicial
b:spawn("default", 6, 30)

return b:build()
