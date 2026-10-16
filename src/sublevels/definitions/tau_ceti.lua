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
                    name = "Tau Ceti d (Super-Tierra Rocosa)",
                    orbitRadius = 2450,
                    phase = 2.20,
                    speed = 0.020,
                    size = 34,
                    type = "super_earth",
                    isTarget = true,
                    colors = {
                        atmosphere = { 0.98, 0.86, 0.38 }, -- Amarillo dorado cálido
                        terracotta = { 0.58, 0.25, 0.13 }, -- Continentes terracota rojizo / herrumbre
                        plains = { 0.76, 0.62, 0.36 },     -- Llanuras ocres / arena
                        basin = { 0.68, 0.84, 0.80 },      -- Cuencas verde-blanquecinas
                        cloudWhite = { 0.94, 0.98, 0.95 }, -- Nubes blancas
                        cloudGreen = { 0.74, 0.86, 0.78 }, -- Nubes verdosas
                        land = { 0.58, 0.25, 0.13 },
                        ocean = { 0.68, 0.84, 0.80 }
                    },
                    atmThickness = 0.22,
                    rotSpeed = 0.015,
                    moons = {
                        {
                            id = "eos",
                            name = "Luna Eos",
                            orbitRadius = 54,
                            speed = 0.28,
                            phase = 3.45,
                            size = 7.0,
                            shader = "luna_eos",
                            colors = {
                                ocean = { 0.35, 0.10, 0.25 },      -- Sombras ciruela profunda / amatista
                                land = { 0.85, 0.42, 0.62 },       -- Rosa cuarzo / magenta polvoriento
                                atmosphere = { 0.98, 0.55, 0.80 }  -- Corona atmosférica rosa brillante
                            },
                            atmThickness = 0.18,
                            rotSpeed = 0.015
                        },
                        {
                            id = "celere",
                            name = "Luna Célere",
                            orbitRadius = 86,
                            speed = 0.18,
                            phase = 1.95,
                            size = 4.2,
                            colors = {
                                ocean = { 0.12, 0.18, 0.28 },
                                land = { 0.68, 0.78, 0.88 },
                                atmosphere = { 0.60, 0.85, 1.00 }
                            },
                            atmThickness = 0.08,
                            specular = 0.7,
                            rotSpeed = 0.025
                        },
                        {
                            id = "ares",
                            name = "Luna Ares",
                            orbitRadius = 114,
                            speed = 0.12,
                            phase = 4.25,
                            size = 3.8,
                            colors = {
                                ocean = { 0.30, 0.11, 0.08 },
                                land = { 0.88, 0.38, 0.18 },
                                atmosphere = { 0.96, 0.46, 0.22 }
                            },
                            atmThickness = 0.12,
                            specular = 0.0,
                            rotSpeed = 0.012
                        },
                        {
                            id = "phobos",
                            name = "Luna Phobos",
                            orbitRadius = 140,
                            speed = 0.08,
                            phase = 1.15,
                            size = 2.2,
                            colors = {
                                ocean = { 0.22, 0.08, 0.06 },
                                land = { 0.78, 0.32, 0.15 },
                                atmosphere = { 0.88, 0.40, 0.18 }
                            },
                            atmThickness = 0.08,
                            specular = 0.0,
                            rotSpeed = 0.020
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
                    name = "Inserción Orbital Tau Ceti d (Tier 3)",
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
                    name = "Tirachinas Gravitacional hacia Tau Ceti d (Tier 3)",
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
            name = "Tau Ceti - Órbita Baja de Tau Ceti d",
            ambientColor = { 0.012, 0.018, 0.035 },
            accentColor = { 0.30, 0.90, 0.65 },
            bounds = { width = 16000, height = 16000 },
            entry = { x = 0, y = 2900 },
            centralPlanet = {
                name = "Tau Ceti d (Super-Tierra Rocosa)",
                radius = 580,
                atmosphereThickness = 0.22,
                screenPos = { xRatio = 0.68, yRatio = 0.82 },
                lightDir = { 0.65, 0.45, 0.60 },
                colors = {
                    atmosphere = { 0.98, 0.86, 0.38 }, -- Amarillo dorado cálido
                    terracotta = { 0.58, 0.25, 0.13 }, -- Continentes terracota rojizo / herrumbre
                    plains = { 0.76, 0.62, 0.36 },     -- Llanuras ocres / arena
                    basin = { 0.68, 0.84, 0.80 },      -- Cuencas verde-blanquecinas
                    cloudWhite = { 0.94, 0.98, 0.95 }, -- Nubes blancas
                    cloudGreen = { 0.74, 0.86, 0.78 }  -- Nubes verdosas
                },
                parallax = 0.008
            },
            gasGiant = nil, -- Reemplazado por centralPlanet (planeta rocoso sin anillos)
            backgroundMoons = {
                -- ─── LUNAS MARCIANAS LEJANAS (SOLAMENTE EN EL CUADRANTE IZQUIERDO SUPERIOR) ───
                {
                    id = "moon_mars_major",
                    name = "Luna Ares (Planetoide Herrumbre Marciano Lejano)",
                    radius = 42,                            -- Escala reducida para transmitir lejanía en el fondo cósmico
                    shader = "mars_moon",
                    renderBehind = true,                    -- Se renderiza antes del planeta central para situarse detrás
                    screenOffset = { x = -440, y = -460 },  -- Cuadrante izquierdo superior exclusivamente
                    parallax = 0.003,                       -- Parallax muy profundo (apenas se desplaza -> gran lejanía)
                    atmosphereThickness = 0.12,
                    uvOffset = { 0.18, 0.25 },
                    color = {
                        land = { 0.88, 0.38, 0.18 },       -- Terracota óxido de hierro / desiertos marcianos
                        ocean = { 0.30, 0.11, 0.08 },      -- Basalto volcánico oscuro / cuencas de impacto
                        atmosphere = { 0.96, 0.46, 0.22 }, -- Corona difusa tenue de polvo
                        ambient = { 0.22, 0.11, 0.08 }     -- Planet-shine cálido para visibilidad nítida en la sombra
                    }
                },
                {
                    id = "moon_mars_minor",
                    name = "Luna Phobos (Luna Menor Lejana de Basalto Rojizo)",
                    radius = 22,                            -- Dimensión pequeña de cuerpo cósmico remoto
                    shader = "mars_moon",
                    renderBehind = true,                    -- Se renderiza antes del planeta central para situarse detrás
                    screenOffset = { x = -580, y = -530 },  -- Cuadrante izquierdo superior más distante
                    parallax = 0.002,                       -- Fondo cósmico ultra-profundo
                    atmosphereThickness = 0.08,
                    uvOffset = { 0.45, 0.60 },
                    color = {
                        land = { 0.78, 0.32, 0.15 },       -- Roca férrica oxidada oscura
                        ocean = { 0.22, 0.08, 0.06 },      -- Umber basáltico profundo
                        atmosphere = { 0.88, 0.40, 0.18 }, -- Atmósfera muy tenue
                        ambient = { 0.18, 0.09, 0.06 }     -- Luz ambiental cálida visible
                    }
                },
                -- ─── LUNAS EN PRIMER PLANO (FRENTE AL PLANETA) ─────────────────────────
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

-- Alias retrocompatible para el planeta central de Tier 3
TauCeti.tiers[3].gasGiant = TauCeti.tiers[3].centralPlanet

return TauCeti
