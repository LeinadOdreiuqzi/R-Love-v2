-- src/states/station/rooms/ring_station/map.lua
-- Layout global de la Estación Espacial de Anillo (Ring Station / Torus).
-- El recorrido principal es perimetral continuo a lo largo del arco del toroide,
-- con acceso a la sub-cubierta técnica inferior por escotilla de servicio.
--
-- Cuadrante del Anillo:
-- [ring_airlock] <---> [ring_concourse] <---> [ring_habitat] <---> [ring_command] <---> [ring_sector_omega]
-- (Hangar Atraque)    (Gran Paseo Curvo)     (Vivienda/Cultivo)    (Puesto de Mando)   (Bahía Industrial)
--                                                    |
--                                                    v (Escotilla)
--                                             [ring_subdeck]
--                                         (Maquinaria Centrífuga)

return {
    name = "Estación de Anillo · Cuadrante Solaris",
    start = { room = "ring_airlock", spawn = "default" },
    rooms = {
        { id = "ring_airlock",      gx = 0,  gy = 0 },   -- 60x34 tiles (2x2 pantallas)
        { id = "ring_concourse",    gx = 2,  gy = 0 },   -- 90x34 tiles (3x2 pantallas)
        { id = "ring_habitat",      gx = 5,  gy = 0 },   -- 90x34 tiles (3x2 pantallas)
        { id = "ring_subdeck",      gx = 5,  gy = 2 },   -- 90x17 tiles (3x1 pantallas, sub-cubierta)
        { id = "ring_command",      gx = 8,  gy = 0 },   -- 60x34 tiles (2x2 pantallas)
        { id = "ring_sector_omega", gx = 10, gy = 0 },   -- 180x34 tiles (6x2 pantallas)
    },
}
