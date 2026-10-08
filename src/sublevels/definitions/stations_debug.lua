-- src/sublevels/definitions/stations_debug.lua
-- Definición del Submundo de Debug para Megaestructuras y Estaciones Espaciales
-- Permite visualizar, probar parallax 2.5D, rotaciones y variantes de daño.

local StationsDebug = {
    id = "stations_debug",
    name = "Estaciones Espaciales (Debug)",
    ambientColor = { 0.015, 0.018, 0.028 },
    accentColor = { 0.25, 0.85, 0.95 },
    bounds = { width = 18000, height = 18000 }
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

    -- 3. NAVES ALARGADAS (FINAL WEAPON - MEGA MAN X4)
    elongated_operational = {
        id = "elo_op",
        name = "Final Weapon - Operacional",
        shortName = "Final Weapon (Op)",
        complexType = "elongated_operational",
        damageState = "operational",
        colorBadge = { 0.95, 0.20, 0.35 },
        badgeText = "OPERACIONAL",
        size = 230,
        seed = 70707,
        desc = "Super-arma orbital Final Weapon: floración mecha abierta con núcleo de plasma frontal y fuste cónico posterior en profundidad."
    },
    elongated_damaged = {
        id = "elo_dmg",
        name = "Final Weapon - Dañada",
        shortName = "Final Weapon (Dmg)",
        complexType = "elongated_damaged",
        damageState = "damaged",
        colorBadge = { 0.95, 0.65, 0.20 },
        badgeText = "DAÑADA",
        size = 230,
        seed = 80808,
        desc = "Pétalos agrietados con fallos térmicos, núcleo inestable con arcos voltaicos y fugas de energía."
    },
    elongated_ruins = {
        id = "elo_rui",
        name = "Final Weapon - Ruinas",
        shortName = "Final Weapon (Rui)",
        complexType = "elongated_ruins",
        damageState = "ruins",
        colorBadge = { 0.90, 0.30, 0.30 },
        badgeText = "EN RUINAS",
        size = 230,
        seed = 90909,
        desc = "Super-arma destrozada: pétalos desgajados a la deriva, cañón carbonizado y fuste fracturado."
    },

    -- 4. CRUCERO ESTELAR CLASE AXIOM (NUEVA VARIANTE SCI-FI)
    axiom_operational = {
        id = "ax_op",
        name = "Crucero Axiom - Operacional",
        shortName = "Axiom (Op)",
        complexType = "axiom_operational",
        damageState = "operational",
        colorBadge = { 0.88, 0.92, 0.98 },
        badgeText = "OPERACIONAL",
        size = 230,
        seed = 77001,
        desc = "Crucero colosal clase Axiom: proa clíper aerodinámica, terrazas residenciales y quilla ventral profunda."
    },
    axiom_damaged = {
        id = "ax_dmg",
        name = "Crucero Axiom - Dañado",
        shortName = "Axiom (Dmg)",
        complexType = "axiom_damaged",
        damageState = "damaged",
        colorBadge = { 0.95, 0.65, 0.20 },
        badgeText = "DAÑADA",
        size = 230,
        seed = 77002,
        desc = "Alerón dorsal combado, blackout parcial en terrazas y balizas estroboscópicas de emergencia."
    },
    axiom_ruins = {
        id = "ax_rui",
        name = "Crucero Axiom - Ruinas",
        shortName = "Axiom (Rui)",
        complexType = "axiom_ruins",
        damageState = "ruins",
        colorBadge = { 0.90, 0.30, 0.30 },
        badgeText = "EN RUINAS",
        size = 230,
        seed = 77003,
        desc = "Casco seccionado con proa a la deriva, mamparos carbonizados expuestos y escombros en gravedad cero."
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

    -- Fila 1: Estaciones Anillo (Y = -2100)
    table.insert(stations, makeStation(MASTER_STATIONS.ring_operational,      -spacingX, -2100, 0.0))
    table.insert(stations, makeStation(MASTER_STATIONS.ring_damaged,          0,         -2100, 0.0))
    table.insert(stations, makeStation(MASTER_STATIONS.ring_ruins,            spacingX,  -2100, 0.0))

    -- Fila 2: Estaciones Modulares (Y = -700)
    table.insert(stations, makeStation(MASTER_STATIONS.modular_operational,   -spacingX, -700,  0.0))
    table.insert(stations, makeStation(MASTER_STATIONS.modular_damaged,       0,         -700,  0.0))
    table.insert(stations, makeStation(MASTER_STATIONS.modular_ruins,         spacingX,  -700,  0.0))

    -- Fila 3: Naves Alargadas (Diseño Original) (Y = 700)
    table.insert(stations, makeStation(MASTER_STATIONS.elongated_operational, -spacingX, 700,   0.0))
    table.insert(stations, makeStation(MASTER_STATIONS.elongated_damaged,     0,         700,   0.0))
    table.insert(stations, makeStation(MASTER_STATIONS.elongated_ruins,       spacingX,  700,   0.0))

    -- Fila 4: Cruceros Estelares Axiom (Nueva Variante) (Y = 2100)
    table.insert(stations, makeStation(MASTER_STATIONS.axiom_operational,     -spacingX, 2100,  0.0))
    table.insert(stations, makeStation(MASTER_STATIONS.axiom_damaged,         0,         2100,  0.0))
    table.insert(stations, makeStation(MASTER_STATIONS.axiom_ruins,           spacingX,  2100,  0.0))

    return stations
end

return StationsDebug
