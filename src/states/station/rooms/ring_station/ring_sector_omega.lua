-- src/states/station/rooms/ring_station/ring_sector_omega.lua
-- Macro-Bahía Industrial del Anillo (180x34 tiles, 2880x544 px).
-- Gran sector expansivo a lo largo del arco del toroide:
-- vías de grúa pórtico suspendidas, contenedores de carga pesada,
-- mamparas estancas de aislamiento y ventanales segmentados
-- que muestran la perspectiva curvada infinita del anillo.

local Builder = require 'src.states.station.engine.builder'

local b = Builder.new("ring_sector_omega", 180, 34, {
    name = "Sector Omega · Bahía Industrial del Anillo",
    accent = { 0.25, 0.85, 0.95 },
})

-- 1. Casco perimetral blindado (1 tile)
b:box(1, 1, 180, 34, '#', 1)

-- 2. Suelo continuo del anillo (Deck Exterior)
b:hwall(1, 31, 180, 4)

-- 3. Bahías de Observación Industrial Totales con Saltos de Mamparo
-- Abarcan todo el fondo desde el techo (row 2) hasta el suelo (row 30),
-- divididas por las mamparas estancas de aislamiento (col 63..72 y col 123..132) como saltos estructurales.
-- Bahía Alfa (col 2..62, 61 tiles de ancho x 29 tiles de alto = 976x464 px)
b:wideScreen(2, 2, 61, 29)
-- Bahía Central Beta (col 73..122, 50 tiles de ancho x 29 tiles de alto = 800x464 px)
b:wideScreen(73, 2, 50, 29)
-- Bahía Gamma (col 133..179, 47 tiles de ancho x 29 tiles de alto = 752x464 px)
b:wideScreen(133, 2, 47, 29)

-- 4. Pasarela superior continua de supervisión industrial (soportada con pilares)
b:supportedPlatform(16, 14, 44, 'pillars')
b:supportedPlatform(74, 14, 48, 'pillars')
b:supportedPlatform(134, 14, 38, 'pillars')

-- 5. Pilares maestros de celosía que sostienen el arco del anillo
for col = 14, 170, 16 do
    b:pillar(col, 2, 29)
end

-- 6. Terrazas y plataformas intermedias de carga
b:supportedPlatform(8, 22, 14, 'brackets')
b:supportedPlatform(30, 21, 16, 'pillars')
b:supportedPlatform(54, 22, 12, 'brackets')
b:supportedPlatform(85, 21, 18, 'pillars')
b:supportedPlatform(115, 22, 14, 'brackets')
b:supportedPlatform(145, 21, 18, 'pillars')

-- 7. Contenedores de carga suspendidos
-- Contenedor Alfa
b:stamp(38, 16, {
    "##########",
    "#........#",
    "#..====..#",
    "##########",
})
-- Contenedor Beta
b:stamp(98, 16, {
    "##########",
    "#........#",
    "#..====..#",
    "##########",
})
-- Contenedor Gamma
b:stamp(155, 16, {
    "##########",
    "#........#",
    "#..====..#",
    "##########",
})

-- 8. Mamparas intermedias de aislamiento superiores
b:stamp(64, 12, {
    "########",
    "#......#",
    "########",
})

b:stamp(124, 12, {
    "########",
    "#......#",
    "########",
})

-- 9. Puerta izquierda hacia ring_command (row = 28)
b:door("left", 28)

-- 10. Spawn por defecto
b:spawn("default", 6, 30)

return b:build()
