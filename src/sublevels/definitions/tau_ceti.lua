-- src/sublevels/definitions/tau_ceti.lua
-- Definición declarativa del Submundo "Sistema Tau Ceti"
-- Vista de canto / oblicua a ~10-12 grados ("Escenario amplio" sin líneas de órbitas)

local TauCeti = {
    id = "tau_ceti",
    name = "Tau Ceti",
    tiers = {
        [1] = {
            id = "tau_ceti_1",
            tier = 1,
            name = "Tau Ceti - Sistema Exterior",
            ambientColor = { 0.012, 0.016, 0.030 },
            accentColor = { 0.40, 0.70, 1.00 },
            bounds = { width = 16000, height = 16000 },
            projection = {
                type = "edge_on_oblique",
                tiltAngle = math.rad(11), -- Inclinación muy baja: ~11 grados (vista de canto / oblicua rasante)
                yCompression = 0.19,     -- Factor de compresión vertical para el falso 3D de canto
                diskRadius = 3400,       -- Amplitud horizontal del escenario
                zodiacalDust = true
            },
            sun = {
                x = 0,
                y = 0,
                radius = 65,
                coronaRadius = 180,
                color = { 1.0, 0.94, 0.82 },
                glowColor = { 1.0, 0.70, 0.25 }
            },
            planets = {
                {
                    name = "Tau Ceti b",
                    orbitRadius = 650,
                    phase = 3.65, -- Lado izquierdo posterior
                    speed = 0.065,
                    size = 14,
                    color = { 0.84, 0.48, 0.30 },
                    atmosphere = { 0.92, 0.55, 0.35 },
                    hasTrail = true
                },
                {
                    name = "Tau Ceti c",
                    orbitRadius = 1250,
                    phase = 0.55, -- Lado derecho anterior
                    speed = 0.040,
                    size = 19,
                    color = { 0.88, 0.74, 0.48 },
                    atmosphere = { 0.85, 0.80, 0.60 },
                    hasTrail = true
                },
                {
                    name = "Tau Ceti e",
                    orbitRadius = 2300,
                    phase = 3.35, -- Lado izquierdo medio
                    speed = 0.022,
                    size = 25,
                    color = { 0.32, 0.70, 0.85 },
                    atmosphere = { 0.40, 0.82, 0.98 },
                    hasTrail = true
                },
                {
                    name = "Tau Ceti IV",
                    orbitRadius = 3100,
                    phase = 0.42, -- Lado derecho frontal prominente
                    speed = 0.015,
                    size = 46,
                    color = { 0.28, 0.78, 1.00 },
                    atmosphere = { 0.40, 0.85, 1.00 },
                    hasRing = true,
                    hasTrail = true,
                    isTarget = true
                }
            },
            asteroidBelt = {
                innerRadius = 1550,
                outerRadius = 1950,
                particleCount = 280,
                color = { 0.62, 0.65, 0.72 }
            },
            beacons = {
                {
                    id = "beacon_sun",
                    name = "Aproximación Solar (Tier 2)",
                    x = 450,
                    y = 120,
                    radius = 75,
                    targetTier = 2,
                    color = { 1.0, 0.75, 0.25 }
                },
                {
                    id = "beacon_planet",
                    name = "Inserción Orbital Tau Ceti IV (Tier 3)",
                    x = 680,
                    y = 540,
                    radius = 95,
                    targetTier = 3,
                    color = { 0.30, 0.85, 1.00 }
                }
            }
        },
        [2] = {
            id = "tau_ceti_2",
            tier = 2,
            name = "Tau Ceti - Corona Solar",
            ambientColor = { 0.07, 0.03, 0.015 },
            accentColor = { 1.00, 0.75, 0.30 },
            bounds = { width = 12000, height = 12000 },
            sun = {
                x = 0,
                y = -2200,
                radius = 1900,
                surfaceColor = { 1.0, 0.96, 0.85 },
                coronaColor = { 1.0, 0.58, 0.12 },
                deepCoronaColor = { 0.85, 0.25, 0.05 },
                heatDamageDistance = 2600,
                heatDamageRate = 12
            },
            solarWind = {
                intensity = 1.0,
                particleCount = 180,
                baseSpeed = 320,
                color = { 1.0, 0.82, 0.45 }
            },
            beacons = {
                {
                    id = "beacon_escape",
                    name = "Vector de Salida al Sistema Exterior (Tier 1)",
                    x = 0,
                    y = 3500,
                    radius = 100,
                    targetTier = 1,
                    color = { 0.40, 0.75, 1.00 }
                }
            }
        },
        [3] = {
            id = "tau_ceti_3",
            tier = 3,
            name = "Tau Ceti - Órbita Baja",
            ambientColor = { 0.012, 0.018, 0.035 },
            accentColor = { 0.30, 0.90, 0.65 },
            bounds = { width = 14000, height = 14000 },
            planet = {
                x = 0,
                y = 1200,
                radius = 1100,
                atmosphereThickness = 0.22,
                lightDir = { 0.75, -0.65, 0.35 }, -- Vector hacia el sol Tau Ceti
                surface = {
                    oceanColor = { 0.08, 0.22, 0.55 },
                    coastColor = { 0.15, 0.48, 0.68 },
                    landColor = { 0.22, 0.58, 0.32 },
                    mountainColor = { 0.45, 0.40, 0.32 },
                    iceColor = { 0.88, 0.94, 1.00 },
                    specularIntensity = 0.85
                },
                atmosphere = {
                    dayColor = { 0.35, 0.75, 1.00 },
                    twilightColor = { 1.00, 0.55, 0.25 },
                    rayleighStrength = 1.3
                },
                clouds = {
                    speed = 0.015,
                    density = 0.65,
                    shadowOffset = 18
                },
                rotationSpeed = 0.008
            },
            orbitalDebris = {
                count = 60,
                minDist = 1250,
                maxDist = 3000
            },
            beacons = {
                {
                    id = "beacon_high_orbit",
                    name = "Retorno al Sistema Exterior (Tier 1)",
                    x = 0,
                    y = -2200,
                    radius = 120,
                    targetTier = 1,
                    color = { 0.35, 0.75, 1.00 }
                }
            }
        }
    }
}

return TauCeti
