-- src/sublevels/definitions/nebulae_debug.lua
-- Definición del Submundo de Debug para el Laboratorio de Nebulosas
-- Permite pruebas de generación procedural aleatoria y específica en un mundo acotado.

local NebulaeDebugDef = {
    id = "nebulae_debug",
    name = "Laboratorio de Nebulosas",
    ambientColor = { 0.008, 0.010, 0.018 },
    accentColor = { 0.85, 0.45, 0.95 },
    bounds = { width = 7000, height = 7000 },
    spawnX = 0,
    spawnY = 500
}

return NebulaeDebugDef
