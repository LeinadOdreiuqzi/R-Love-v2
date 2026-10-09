-- src/states/station/rooms/ring_station/ring_habitat.lua
-- Sector Residencial & Bio-Domo Hidropónico (90x34 tiles, 1440x544 px).
-- Módulos de habitación de la tripulación y agricultura hidropónica vertical.
-- Incluye la escotilla de servicio en el suelo para descender a la sub-cubierta técnica.

local Builder = require 'src.states.station.engine.builder'

local b = Builder.new("ring_habitat", 90, 34, {
    name = "Sector Residencial & Hidroponía",
    accent = { 0.45, 0.95, 0.55 },
})

-- 1. Casco perimetral blindado (1 tile)
b:box(1, 1, 90, 34, '#', 1)

-- 2. Suelo continuo del anillo (Deck Exterior)
b:hwall(1, 31, 90, 4)

-- 3. Ventanales Panorámicos Totales con Saltos Habitacionales
-- Abarcan todo el fondo desde el techo (row 2) hasta el suelo (row 30),
-- utilizando los dos bloques residenciales (col 8..20 y col 70..82) como saltos estructurales de mamparo.
-- Ala de Acceso Izquierda (col 2..7, 6 tiles de ancho x 29 tiles de alto)
b:wideScreen(2, 2, 6, 29)
-- Bio-Domo Hidropónico Central (col 21..69, 49 tiles de ancho x 29 tiles de alto = 784x464 px)
b:wideScreen(21, 2, 49, 29)
-- Ala de Acceso Derecha (col 83..89, 7 tiles de ancho x 29 tiles de alto)
b:wideScreen(83, 2, 7, 29)

-- 4. Pasarela superior frente a los invernaderos
b:supportedPlatform(20, 14, 50, 'pillars')

-- 5. Módulos de habitación suspendidos (izquierda y derecha)
-- Módulo residencial izquierdo
b:stamp(8, 16, {
    "#############",
    "#...........#",
    "#..=======..#",
    "#...........#",
    "#############",
})
-- Módulo residencial derecho
b:stamp(70, 16, {
    "#############",
    "#...........#",
    "#..=======..#",
    "#...........#",
    "#############",
})

-- 6. Terrazas escalonadas de cultivo hidropónico con soportes
b:supportedPlatform(24, 23, 14, 'pillars')
b:supportedPlatform(52, 23, 14, 'pillars')

-- 7. Pilares estructurales de soporte
b:pillar(16, 3, 28)
b:pillar(40, 3, 28)
b:pillar(50, 3, 28)
b:pillar(74, 3, 28)

-- 8. Escotilla en el suelo hacia la sub-cubierta de mantenimiento (col = 45)
-- Nota: La escotilla mide 3 tiles de ancho (col = 45, 46, 47).
b:door("down", 45)

-- 9. Puertas laterales (row = 28):
-- - Izquierda hacia ring_concourse
-- - Derecha hacia ring_command
b:door("left", 28)
b:door("right", 28)

-- 10. Spawn por defecto
b:spawn("default", 6, 30)

return b:build()
