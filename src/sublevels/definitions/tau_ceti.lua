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
                    id = "tau_ceti_b",
                    name = "Tau Ceti b",
                    orbitRadius = 640,
                    phase = 3.85,
                    speed = 0.055,
                    size = 14,
                    type = "rocky",
                    colors = {
                        ocean = { 0.26, 0.22, 0.20 },      -- Basalto oscuro y cráteres
                        land = { 0.58, 0.44, 0.32 },       -- Tierras altas calcinadas por el sol
                        atmosphere = { 0.65, 0.45, 0.30 }  -- Velo mineral tenue
                    },
                    atmThickness = 0.03,
                    specular = 0.1,
                    rotSpeed = 0.012
                },
                {
                    id = "tau_ceti_c",
                    name = "Tau Ceti c",
                    orbitRadius = 1200,
                    phase = 0.65,
                    speed = 0.036,
                    size = 18,
                    type = "desert",
                    colors = {
                        ocean = { 0.60, 0.30, 0.16 },      -- Cañones y fallas de óxido férrico
                        land = { 0.88, 0.62, 0.36 },       -- Dunas doradas y mesetas de arenisca
                        atmosphere = { 0.92, 0.66, 0.42 }  -- Atmósfera desértica cálida
                    },
                    atmThickness = 0.11,
                    specular = 0.2,
                    rotSpeed = 0.020
                },
                {
                    id = "tau_ceti_d",
                    name = "Tau Ceti d",
                    orbitRadius = 2280,
                    phase = 2.20,
                    speed = 0.022,
                    size = 21,
                    type = "ice",
                    colors = {
                        ocean = { 0.20, 0.44, 0.65 },      -- Fisuras oceánicas heladas
                        land = { 0.85, 0.92, 0.98 },       -- Placas glaciares de nieve reflectante
                        atmosphere = { 0.65, 0.84, 1.00 }  -- Corona de bruma criogénica
                    },
                    atmThickness = 0.19,
                    specular = 1.8,
                    rotSpeed = 0.015
                },
                {
                    id = "tau_ceti_e",
                    name = "Tau Ceti e (Gigante Gaseoso)",
                    orbitRadius = 3200,
                    phase = 0.42,
                    speed = 0.014,
                    size = 46,
                    isGasGiant = true,
                    isTarget = true,
                    atmosphereThickness = 0.22,
                    colors = {
                        deep = { 0.05, 0.22, 0.38 },      -- Azul abisal profundo
                        mid = { 0.16, 0.54, 0.78 },       -- Celeste cerúleo
                        light = { 0.54, 0.86, 0.95 },     -- Celeste hielo brillante
                        white = { 0.92, 0.98, 1.00 },     -- Blanco cirro polar
                        atmosphere = { 0.30, 0.85, 1.00 } -- Resplandor Rayleigh celeste
                    },
                    rings = {
                        tilt = -0.38,
                        innerRatio = 1.25,
                        outerRatio = 2.30,
                        yFlatten = 0.25,
                        color = { 0.80, 0.94, 1.00, 0.65 }
                    },
                    moons = {
                        {
                            id = "tau_ceti_iv",
                            name = "Tau Ceti IV",
                            orbitRadius = 66,
                            speed = 0.28,
                            phase = 0.85,
                            size = 8.5,
                            isTarget = true,
                            colors = {
                                ocean = { 0.08, 0.28, 0.62 },
                                land = { 0.20, 0.62, 0.38 },
                                atmosphere = { 0.40, 0.85, 1.00 }
                            },
                            atmThickness = 0.24,
                            specular = 1.4,
                            rotSpeed = 0.02
                        },
                        {
                            id = "eos",
                            name = "Luna Eos",
                            orbitRadius = 112,
                            speed = 0.18,
                            phase = 3.45,
                            size = 5.8,
                            colors = {
                                ocean = { 0.35, 0.10, 0.25 },
                                land = { 0.85, 0.42, 0.62 },
                                atmosphere = { 0.98, 0.55, 0.80 }
                            },
                            atmThickness = 0.16,
                            specular = 0.2,
                            rotSpeed = 0.015
                        },
                        {
                            id = "celere",
                            name = "Luna Célere",
                            orbitRadius = 38,
                            speed = 0.44,
                            phase = 1.95,
                            size = 3.2,
                            colors = {
                                ocean = { 0.12, 0.18, 0.28 },
                                land = { 0.68, 0.78, 0.88 },
                                atmosphere = { 0.60, 0.85, 1.00 }
                            },
                            atmThickness = 0.08,
                            specular = 0.7,
                            rotSpeed = 0.025
                        }
                    }
                },
                {
                    id = "tau_ceti_f",
                    name = "Tau Ceti f",
                    orbitRadius = 4250,
                    phase = 5.10,
                    speed = 0.009,
                    size = 15,
                    type = "methane",
                    colors = {
                        ocean = { 0.16, 0.10, 0.28 },      -- Lagos de hidrocarburos densos
                        land = { 0.48, 0.32, 0.62 },       -- Hielos de metano y tolinas violetas
                        atmosphere = { 0.62, 0.42, 0.85 }  -- Resplandor violeta profundo
                    },
                    atmThickness = 0.14,
                    specular = 0.5,
                    rotSpeed = 0.010
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
                },
                {
                    id = "beacon_exit",
                    name = "Portal Hiperespacial - Salida al Mapa Estelar (E)",
                    x = -750,
                    y = -450,
                    radius = 85,
                    isExit = true,
                    color = { 0.55, 0.40, 0.95 }
                }
            }
        },
        [2] = {
            id = "tau_ceti_2",
            tier = 2,
            name = "Tau Ceti - Corona Solar",
            ambientColor = { 0.08, 0.035, 0.015 },
            accentColor = { 1.00, 0.75, 0.28 },
            bounds = { width = 16000, height = 16000 },
            entry = { x = 0, y = 4900 },
            sun = {
                x = 0,
                y = 0,
                radius = 3200,
                surfaceColor = { 1.0, 0.96, 0.85 },
                coronaColor = { 1.0, 0.58, 0.12 },
                deepCoronaColor = { 0.85, 0.22, 0.05 },
                heatDamageDistance = 4100,
                heatDamageRate = 18,
                safeCorridorRadius = 4900
            },
            solarWind = {
                intensity = 1.2,
                particleCount = 260,
                minDist = 3300,
                maxDist = 8000,
                baseSpeed = 620,
                color = { 1.0, 0.85, 0.45 }
            },
            beacons = {
                {
                    id = "beacon_escape",
                    name = "Vector de Escape al Sistema Exterior (Tier 1)",
                    x = 0,
                    y = 5600,
                    radius = 120,
                    targetTier = 1,
                    color = { 0.40, 0.75, 1.00 }
                },
                {
                    id = "beacon_slingshot",
                    name = "Tirachinas Gravitacional hacia Tau Ceti IV (Tier 3)",
                    x = 5600,
                    y = 0,
                    radius = 120,
                    targetTier = 3,
                    color = { 0.30, 0.90, 0.65 }
                }
            }
        },
        [3] = {
            id = "tau_ceti_3",
            tier = 3,
            name = "Tau Ceti - Órbita Baja",
            ambientColor = { 0.012, 0.018, 0.035 },
            accentColor = { 0.30, 0.90, 0.65 },
            bounds = { width = 16000, height = 16000 },
            entry = { x = 0, y = 2900 },
            gasGiant = {
                name = "Tau Ceti e (Gigante Gaseoso)",
                radius = 580,
                atmosphereThickness = 0.22,
                screenPos = { xRatio = 0.68, yRatio = 0.82 },
                lightDir = { 0.65, 0.45, 0.60 },
                colors = {
                    deep = { 0.05, 0.22, 0.38 },      -- Azul abisal profundo
                    mid = { 0.16, 0.54, 0.78 },       -- Celeste cerúleo
                    light = { 0.54, 0.86, 0.95 },     -- Celeste hielo brillante
                    white = { 0.92, 0.98, 1.00 },     -- Blanco cirro polar
                    atmosphere = { 0.30, 0.85, 1.00 } -- Resplandor Rayleigh celeste
                },
                rings = {
                    tilt = -0.42,
                    innerRadius = 660,
                    outerRadius = 1450,
                    yFlatten = 0.28,
                    color = { 0.85, 0.96, 1.00, 0.70 }
                },
                parallax = 0.008
            },
            backgroundMoons = {
                {
                    id = "moon_magenta",
                    name = "Luna Eos (Tonalidad Magenta / Rosa)",
                    radius = 92,
                    color = {
                        ocean = { 0.35, 0.10, 0.25 },      -- Sombras ciruela profunda
                        land = { 0.85, 0.42, 0.62 },       -- Rosa / magenta polvoriento
                        atmosphere = { 0.98, 0.55, 0.80 }  -- Corona atmosférica rosa brillante
                    },
                    screenOffset = { x = -340, y = -110 },  -- Despejado a la izquierda sin solapamiento con la nave
                    parallax = 0.016,
                    hasMarathon = true
                },
                {
                    id = "moon_secondary",
                    name = "Luna Célere (Hielo Plateado)",
                    radius = 32,
                    color = {
                        ocean = { 0.12, 0.18, 0.28 },
                        land = { 0.68, 0.78, 0.88 },
                        atmosphere = { 0.60, 0.85, 1.00 }
                    },
                    screenOffset = { x = 250, y = -270 },
                    parallax = 0.012,
                    hasMarathon = false
                }
            },
            marathonShip = {
                name = "UESC Marathon",
                length = 95,
                orbitRadius = 145,
                orbitSpeed = 0.04,
                colors = {
                    hull = { 0.14, 0.38, 0.85 },
                    plating = { 0.26, 0.72, 0.95 },
                    asteroid = { 0.24, 0.26, 0.30 },
                    asteroidLight = { 0.46, 0.50, 0.55 },
                    arches = { 0.08, 0.52, 1.00 },
                    strobe = { 0.40, 1.00, 0.60 }
                }
            },
            planet = {
                x = 0,
                y = 0,
                radius = 2600,
                atmosphereThickness = 0.24,
                lightDir = { 0.65, 0.55, 0.52 }, -- Iluminación frontal diurna hacia la órbita baja
                surface = {
                    oceanColor = { 0.08, 0.24, 0.58 },
                    coastColor = { 0.15, 0.52, 0.72 },
                    landColor = { 0.22, 0.60, 0.35 },
                    mountainColor = { 0.45, 0.42, 0.34 },
                    iceColor = { 0.90, 0.95, 1.00 },
                    specularIntensity = 1.10
                },
                atmosphere = {
                    dayColor = { 0.38, 0.80, 1.00 },
                    twilightColor = { 1.00, 0.55, 0.25 },
                    rayleighStrength = 1.4
                },
                clouds = {
                    speed = 0.012,
                    density = 0.65,
                    shadowOffset = 22
                },
                rotationSpeed = 0.006
            },
            orbitalDebris = {
                count = 75,
                minDist = 2800,
                maxDist = 5800
            },
            beacons = {
                {
                    id = "beacon_high_orbit",
                    name = "Vector de Retorno al Sistema Exterior (Tier 1)",
                    x = 0,
                    y = 5200,
                    radius = 120,
                    targetTier = 1,
                    color = { 0.35, 0.75, 1.00 }
                },
                {
                    id = "beacon_solar_dive",
                    name = "Inyección Orbital hacia Corona Solar (Tier 2)",
                    x = 5200,
                    y = 0,
                    radius = 120,
                    targetTier = 2,
                    color = { 1.00, 0.70, 0.25 }
                }
            }
        }
    }
}

return TauCeti
