-- src/states/station/rooms/test_station/map.lua
-- Layout global de la estación: posición de cada sala en la cuadrícula de pantallas.
-- 1 pantalla = 30x17 tiles (480x272 px). Las puertas se enlazan solas por vecindad.
--
--   gx:  0         1    2    3         4    5
--  gy0 [entrance][ corridor ][shaft]        [storage]
--  gy1                       [shaft][   hub    ]
--  gy2                              [   hub    ]

return {
    name = "Estación de Pruebas",
    start = { room = "entrance", spawn = "default" },
    rooms = {
        { id = "entrance",     gx = 0, gy = 0 },   -- 1x1 pantallas
        { id = "corridor",     gx = 1, gy = 0 },   -- 2x1 pantallas
        { id = "shaft",        gx = 3, gy = 0 },   -- 1x2 pantallas
        { id = "hub",          gx = 4, gy = 1 },   -- 2x2 pantallas
        { id = "storage",      gx = 5, gy = 0 },   -- 1x1 pantallas
        { id = "sector_omega", gx = 6, gy = 1 },   -- 256x256 tiles (4096x4096 px)
    },
}
