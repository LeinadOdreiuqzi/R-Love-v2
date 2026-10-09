-- src/states/station/rooms/test_station/sector_omega.lua
-- Macro-sala Metroidvania de 256x256 tiles (4096x4096 px) inspirada en Hollow Knight.
-- Diseñada con el nuevo DSL RoomBuilder: combina primitivas geométricas limpias
-- con bloques ASCII detallados. El jugador (10x20 px) explora un complejo colosal.

local Builder = require 'src.states.station.engine.builder'

local b = Builder.new("sector_omega", 256, 256, {
    name = "Sector Omega · Complejo Industrial",
    accent = { 0.30, 0.85, 0.95 },
})

-- 1. Casco exterior blindado (3 tiles de espesor en todo el perímetro)
b:box(1, 1, 256, 256, '#', 3)

-- 2. Pilares estructurales de fondo (se repiten en todo el sector)
for col = 20, 240, 24 do
    b:pillar(col, 4, 248)
end

-- =========================================================================
-- DECK 1: NIVEL SUPERIOR - ESCLUSA Y MUELLE DE ATRAQUE (ty = 4 .. 55)
-- =========================================================================
-- Suelo principal del muelle de entrada
b:hwall(4, 30, 75, 2)

-- Puerta hacia el Núcleo Central (hub) en la pared izquierda
b:door("left", 27)

-- Plataformas elevadas y pasarelas de observación en el muelle
b:platform(12, 23, 14)
b:platform(34, 17, 16)
b:platform(56, 11, 14)

-- Estructura de control / esclusa detallada (estampado ASCII)
b:stamp(22, 10, {
    "###########",
    "#.........#",
    "#..====...#",
    "#.........#",
    "#####.#####",
})

-- Techo intermedio separador entre Deck 1 y Deck 2
b:hwall(4, 55, 95, 2)
b:platform(75, 55, 12) -- abertura transitable con plataforma one-way

-- =========================================================================
-- EJE CENTRAL DE VENTILACIÓN Y ASCENSOR (tx = 100 .. 122, ty = 4 .. 245)
-- =========================================================================
-- Paredes del pozo vertical que conecta toda la estación
b:vwall(100, 4, 240, 2)
b:vwall(122, 4, 240, 2)

-- Plataformas escalonadas dentro del pozo para subir y bajar los 256 tiles
for py = 16, 235, 18 do
    local offset = ((py / 18) % 2 == 0) and 103 or 112
    b:platform(offset, py, 7)
end

-- Aberturas en las paredes del pozo para entrar/salir a los decks
b:fill(100, 25, 2, 6, '.')   -- acceso a Deck 1
b:fill(122, 25, 2, 6, '.')
b:fill(100, 85, 2, 8, '.')   -- acceso a Deck 2
b:fill(122, 85, 2, 8, '.')
b:fill(100, 165, 2, 8, '.')  -- acceso a Deck 3
b:fill(122, 165, 2, 8, '.')

-- =========================================================================
-- DECK 2: SECTOR DEL REACTOR CENTRAL (tx = 125 .. 252, ty = 40 .. 140)
-- =========================================================================
-- Suelo del sector del reactor
b:hwall(125, 140, 127, 3)

-- Núcleo del reactor: cámara blindada masiva
b:box(165, 75, 45, 45, '#', 3)
-- Interior del reactor con plataformas de servicio
b:platform(172, 90, 12)
b:platform(192, 102, 12)
b:fill(185, 75, 6, 3, '.') -- escotilla superior de acceso al reactor
b:platform(185, 75, 6)

-- Pasarelas suspendidas alrededor del reactor
b:platform(132, 60, 22)
b:platform(138, 85, 18)
b:platform(130, 110, 24)

b:platform(218, 65, 20)
b:platform(224, 90, 18)
b:platform(216, 115, 22)

-- =========================================================================
-- DECK 3: BAHÍA DE CARGA Y HANGAR DE MAQUINARIA (tx = 4 .. 98, ty = 60 .. 180)
-- =========================================================================
b:hwall(4, 180, 95, 3)

-- Estructuras de carga y contenedores industriales
b:box(15, 150, 20, 29, '#', 2)
b:box(45, 135, 24, 44, '#', 2)
b:box(75, 155, 18, 24, '#', 2)

-- Plataformas sobre los contenedores
b:platform(12, 142, 14)
b:platform(38, 128, 16)
b:platform(68, 148, 12)
b:platform(25, 115, 20)
b:platform(55, 100, 18)
b:platform(18, 85, 22)

-- =========================================================================
-- DECK 4: PROFUNDIDADES DE MANTENIMIENTO (ty = 185 .. 253)
-- =========================================================================
-- Suelo industrial inferior masivo (a 4000 px de profundidad)
b:hwall(4, 250, 248, 3)

-- Plataformas intermedias de acceso en el nivel subterráneo
for px = 15, 235, 30 do
    b:platform(px, 238, 15)
    b:platform(px + 12, 224, 12)
    b:platform(px, 210, 14)
end

-- Estación de investigación en las profundidades (estampado ASCII)
b:stamp(140, 235, {
    "#############################",
    "#...........................#",
    "#..======.......======......#",
    "#...........................#",
    "#######......:........#######",
    "#######......:........#######",
})

-- Spawns
b:spawn("default", 12, 28)
b:spawn("deep", 150, 248)

return b:build()
