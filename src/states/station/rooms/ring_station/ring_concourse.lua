-- src/states/station/rooms/ring_station/ring_concourse.lua
-- Gran Paseo Periférico (90x34 tiles, 1440x544 px).
-- Gran bulevar del cuadrante que recorre el arco del anillo:
-- pasarelas elevadas, pilares maestros de soporte y ventanales panorámicos
-- masivos con vistas al interior del toroide, el eje central y los rayos conectores.

local Builder = require 'src.states.station.engine.builder'

local b = Builder.new("ring_concourse", 90, 34, {
    name = "Gran Paseo Periférico · Sector Alfa",
    accent = { 0.30, 0.75, 1.00 },
})

-- 1. Casco perimetral blindado (1 tile)
b:box(1, 1, 90, 34, '#', 1)

-- 2. Suelo continuo del anillo (Deck Exterior)
b:hwall(1, 31, 90, 4)

-- 3. Ventanales Panorámicos Totales con Salto Estructural Central
-- Abarcan todo el fondo desde el techo (row 2) hasta el suelo (row 30),
-- divididos por un salto estructural central (col 40..49) donde se ancla la cabina de control.
-- Ala Izquierda (col 2..39, 38 tiles de ancho x 29 tiles de alto = 608x464 px)
b:wideScreen(2, 2, 38, 29)
-- Ala Derecha (col 50..89, 40 tiles de ancho x 29 tiles de alto = 640x464 px)
b:wideScreen(50, 2, 40, 29)

-- 4. Pasarela superior frente a los ventanales (soportada con pilares de celosía)
b:supportedPlatform(16, 16, 58, 'pillars')

-- 5. Pilares maestros de refuerzo estructural del anillo
for col = 14, 80, 16 do
    b:pillar(col, 2, 29)
end

-- 6. Terrazas y plataformas intermedias de tránsito
b:supportedPlatform(8, 23, 12, 'brackets')
b:supportedPlatform(24, 22, 14, 'pillars')
b:supportedPlatform(52, 22, 14, 'pillars')
b:supportedPlatform(70, 23, 12, 'brackets')

-- 7. Mampara de control superior suspendida
b:stamp(41, 12, {
    "########",
    "#......#",
    "########",
})

-- 8. Puertas Metroid:
-- - Izquierda (conecta con ring_airlock a row = 28)
-- - Derecha (conecta con ring_habitat a row = 28)
b:door("left", 28)
b:door("right", 28)

-- 9. Spawn secundario para pruebas
b:spawn("default", 6, 30)

return b:build()
