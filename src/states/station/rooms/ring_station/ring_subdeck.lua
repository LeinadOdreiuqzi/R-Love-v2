-- src/states/station/rooms/ring_station/ring_subdeck.lua
-- Sub-cubierta Técnica & Maquinaria Centrífuga (90x17 tiles, 1440x272 px).
-- Nivel inferior pegado al casco exterior: simula la verticalidad moderada
-- que permite la sección transversal del anillo.
-- Alberga servomotores centrífugos, bombas de refrigerante, tuberías pesadas
-- y pasarelas de rejilla metálica con soportes reforzados.

local Builder = require 'src.states.station.engine.builder'

local b = Builder.new("ring_subdeck", 90, 17, {
    name = "Sub-cubierta · Maquinaria de Estabilización",
    accent = { 1.00, 0.65, 0.20 },
})

-- 1. Casco blindado de la sub-cubierta (1 tile)
b:box(1, 1, 90, 17, '#', 1)

-- 2. Suelo inferior reforzado (casco exterior del anillo)
b:hwall(1, 15, 90, 3)

-- 3. Escotilla en el techo hacia el Sector Residencial (col = 45)
b:door("up", 45)

-- 4. Plataforma de recepción bajo la escotilla del techo con soportes al suelo
b:supportedPlatform(40, 6, 12, 'pillars')

-- 5. Pasarelas de mantenimiento elevadas a lo largo del conducto técnico
b:supportedPlatform(10, 8, 24, 'pillars')
b:supportedPlatform(58, 8, 24, 'pillars')

-- 6. Bloques de generadores centrífugos y transformadores de energía
-- Generador izquierdo
b:stamp(16, 10, {
    "########",
    "#......#",
    "#..==..#",
    "########",
})
-- Generador derecho
b:stamp(66, 10, {
    "########",
    "#......#",
    "#..==..#",
    "########",
})

-- 7. Pilares estructurales masivos y cerchas de soporte
for col = 8, 84, 14 do
    b:pillar(col, 2, 13)
end

-- 8. Tuberías y conductos de refrigerante de fondo
b:conduit(6, 4, 80, false)
b:conduit(6, 12, 80, false)

-- 9. Spawn por defecto (sobre la plataforma de recepción de la escotilla)
b:spawn("default", 45, 5)

return b:build()
