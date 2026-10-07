-- src/sublevels/definitions/stations_debug.lua
-- Definición del Submundo de Debug para Megaestructuras y Estaciones Espaciales
-- Permite visualizar, probar parallax 2.5D, rotaciones y variantes de daño.

local StationsDebug = {
    id = "stations_debug",
    name = "Estaciones Espaciales (Debug)",
    ambientColor = { 0.015, 0.018, 0.028 },
    accentColor = { 0.25, 0.85, 0.95 },
    bounds = { width = 16000, height = 16000 }
}

-- Definición de estaciones maestras por tipo y estado
local MASTER_STATIONS = {
    -- 1. ESTACIONES TIPO ANILLO (TOROIDAL RING)
    ring_operational = {
        id = "ring_op",
        name = "Estación Anillo - Operacional",
        shortName = "Anillo (Op)",
        complexType = "ring_operational",
        damageState = "operational",
        colorBadge = { 0.35, 0.85, 1.00 },
        badgeText = "OPERACIONAL",
        size = 230,
        seed = 10101,
        desc = "Toroide presurizado íntegro con puentes radiales, blindaje flotante y bahía activa."
    },
    ring_damaged = {
        id = "ring_dmg",
        name = "Estación Anillo - Dañada",
        shortName = "Anillo (Dmg)",
        complexType = "ring_damaged",
        damageState = "damaged",
        colorBadge = { 0.95, 0.65, 0.20 },
        badgeText = "DAÑADA",
        size = 230,
        seed = 20202,
        desc = "Brechas en el casco, blindaje desprendido, conductos rotos y bengalas de emergencia."
    },
    ring_ruins = {
        id = "ring_rui",
        name = "Estación Anillo - Ruinas",
        shortName = "Anillo (Rui)",
        complexType = "ring_ruins",
        damageState = "ruins",
        colorBadge = { 0.90, 0.30, 0.30 },
        badgeText = "EN RUINAS",
        size = 230,
        seed = 30303,
        desc = "Toroide seccionado a la deriva, blackout total, vigas retorcidas y campo de escombros."
    },

    -- 2. ESTACIONES MODULARES (BRUTALIST CITADEL / EL ARCA)
    modular_operational = {
        id = "mod_op",
        name = "Estación Modular - Operacional",
        shortName = "Modular (Op)",
        complexType = "modular_operational",
        damageState = "operational",
        colorBadge = { 0.30, 0.92, 0.65 },
        badgeText = "OPERACIONAL",
        size = 230,
        seed = 40404,
        desc = "5 brazos radiales con ciudadelas habitacionales, tambor ventral y halo de reactor."
    },
    modular_damaged = {
        id = "mod_dmg",
        name = "Estación Modular - Dañada",
        shortName = "Modular (Dmg)",
        complexType = "modular_damaged",
        damageState = "damaged",
        colorBadge = { 0.95, 0.65, 0.20 },
        badgeText = "DAÑADA",
        size = 230,
        seed = 50505,
        desc = "Fallo en reactor central, brazo 3 parcialmente despresurizado y balizas ámbar."
    },
    modular_ruins = {
        id = "mod_rui",
        name = "Estación Modular - Ruinas",
        shortName = "Modular (Rui)",
        complexType = "modular_ruins",
        damageState = "ruins",
        colorBadge = { 0.90, 0.30, 0.30 },
        badgeText = "EN RUINAS",
        size = 230,
        seed = 60606,
        desc = "Brazos 2 y 4 cercenados con ciudadelas a la deriva, rescoldos térmicos y blindaje flotante."
    },

    -- 3. NAVES ALARGADAS (ELONGATED CRUISER / DREADNOUGHT)
    elongated_operational = {
        id = "elo_op",
        name = "Nave Alargada - Operacional",
        shortName = "Alargada (Op)",
        complexType = "elongated_operational",
        damageState = "operational",
        colorBadge = { 1.00, 0.70, 0.35 },
        badgeText = "OPERACIONAL",
        size = 230,
        seed = 70707,
        desc = "Crucero interestelar militar pesado de aleación bronce con propulsores de iones."
    },
    elongated_damaged = {
        id = "elo_dmg",
        name = "Nave Alargada - Dañada",
        shortName = "Alargada (Dmg)",
        complexType = "elongated_damaged",
        damageState = "damaged",
        colorBadge = { 0.95, 0.65, 0.20 },
        badgeText = "DAÑADA",
        size = 230,
        seed = 80808,
        desc = "Impactos cinéticos en quilla, paneles solares desgarrados e incendios contenidos."
    },
    elongated_ruins = {
        id = "elo_rui",
        name = "Nave Alargada - Ruinas",
        shortName = "Alargada (Rui)",
        complexType = "elongated_ruins",
        damageState = "ruins",
        colorBadge = { 0.90, 0.30, 0.30 },
        badgeText = "EN RUINAS",
        size = 230,
        seed = 90909,
        desc = "Casco partido en dos mitades a la deriva, pérdida de atmósfera y escombros de aleación."
    }
}

-- Función constructora para clonar un placeholder con posición y rotación
local function makeStation(proto, x, y, rot)
    return {
        id = proto.id,
        name = proto.name,
        shortName = proto.shortName,
        complexType = proto.complexType,
        damageState = proto.damageState,
        colorBadge = proto.colorBadge,
        badgeText = proto.badgeText,
        desc = proto.desc,
        size = proto.size,
        seed = proto.seed,
        x = x,
        y = y,
        rotation = rot or 0.0,
        baseRotation = rot or 0.0,
        rotSpeed = 0.04
    }
end

-- ============================================================================
-- GENERADOR DE NIVELES POR TIER
-- ============================================================================

function StationsDebug.getStationsForTier(tier)
    local stations = {}
    local spacingX = 1400

    -- Fila 1: Estaciones Anillo (Y = -1400)
    table.insert(stations, makeStation(MASTER_STATIONS.ring_operational,      -spacingX, -1400, 0.0))
    table.insert(stations, makeStation(MASTER_STATIONS.ring_damaged,          0,         -1400, 0.0))
    table.insert(stations, makeStation(MASTER_STATIONS.ring_ruins,            spacingX,  -1400, 0.0))

    -- Fila 2: Estaciones Modulares (Y = 0)
    table.insert(stations, makeStation(MASTER_STATIONS.modular_operational,   -spacingX, 0,     0.0))
    table.insert(stations, makeStation(MASTER_STATIONS.modular_damaged,       0,         0,     0.0))
    table.insert(stations, makeStation(MASTER_STATIONS.modular_ruins,         spacingX,  0,     0.0))

    -- Fila 3: Naves Alargadas (Y = 1400)
    table.insert(stations, makeStation(MASTER_STATIONS.elongated_operational, -spacingX, 1400,  0.0))
    table.insert(stations, makeStation(MASTER_STATIONS.elongated_damaged,     0,         1400,  0.0))
    table.insert(stations, makeStation(MASTER_STATIONS.elongated_ruins,       spacingX,  1400,  0.0))

    return stations
end

return StationsDebug
