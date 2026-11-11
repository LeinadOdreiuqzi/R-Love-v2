-- Items Pasivos para Space Roguelike
-- Items que otorgan efectos permanentes mientras están en el inventario

local ItemSystem = require("src.item_systems.item_system")
local PassiveManager = require("src.item_systems.passive_manager")

local Passives = {}

-- Modificadores base para items pasivos
local Modifiers = {
    -- Modificadores de estadísticas
    statModifier = function(player, stat, amount, type)
        if not player.passiveModifiers then
            player.passiveModifiers = {}
        end
        
        if not player.passiveModifiers[stat] then
            player.passiveModifiers[stat] = { flat = 0, percent = 0 }
        end
        
        if type == "flat" then
            player.passiveModifiers[stat].flat = player.passiveModifiers[stat].flat + amount
        elseif type == "percent" then
            player.passiveModifiers[stat].percent = player.passiveModifiers[stat].percent + amount
        end
    end,
    
    -- Resistencias
    resistanceModifier = function(player, damageType, amount)
        if not player.resistances then
            player.resistances = {}
        end
        
        player.resistances[damageType] = (player.resistances[damageType] or 0) + amount
    end,
    
    -- Habilidades especiales
    abilityModifier = function(player, ability, value)
        if not player.abilities then
            player.abilities = {}
        end
        
        player.abilities[ability] = value
    end
}

-- NOTA: Las funciones applyPassiveEffect y removePassiveEffect han sido movidas
-- al PassiveManager para centralizar el manejo de efectos pasivos y evitar duplicaciones

local function registerPassive(def)
    def.category = ItemSystem.CATEGORIES.PASSIVE
    def.stackable = false
    def.value = def.value or 550
    def.weight = def.weight or 0.5
    def.icon = def.icon or def.id
    def.tags = def.tags or {"passive"}

    if not def.onAcquire then
        def.onAcquire = function(self, player)
            self.passiveId = PassiveManager.applyPassiveEffect(player, self, self.passiveId)
            return tostring(self.name) .. " activado"
        end
    end

    if not def.onRemove then
        def.onRemove = function(self, player)
            PassiveManager.removePassiveEffect(player, self)
            self.passiveId = nil
            return tostring(self.name) .. " desactivado"
        end
    end

    ItemSystem:registerItem(def)
end

-- Función para registrar todos los items pasivos
function Passives.registerAll()
    -- =========================================================================
    -- PILAR A: PASIVAS DE JUGADOR / CHASIS / PILOTAJE (1 a 7)
    -- =========================================================================

    -- [1] Propulsores Mejorados
    registerPassive({
        id = "enhanced_thrusters",
        name = "Propulsores Mejorados",
        description = "Propulsores de alta eficiencia que aumentan la velocidad y aceleración en un 10%.",
        value = 500, weight = 0.8, icon = "enhanced_thrusters",
        tags = {"propulsion", "speed", "movement"},
        passiveEffects = {
            { type = "stat", stat = "speed", amount = 10, modifierType = "percent" }
        }
    })

    -- [2] Corazón Auxiliar
    registerPassive({
        id = "auxiliary_heart",
        name = "Corazón Auxiliar",
        description = "Un núcleo vital auxiliar que aumenta la integridad máxima del casco en +1 corazón.",
        value = 800, weight = 0.3, icon = "auxiliary_heart",
        tags = {"health", "life", "medical"},
        passiveEffects = {
            { type = "stat", stat = "max_health", amount = 1, modifierType = "flat" }
        }
    })

    -- [3] Giroscopio de Derrape
    registerPassive({
        id = "inertial_gyro",
        name = "Giroscopio de Derrape",
        description = "Derrapar con Shift conserva más momento lineal y aumenta la velocidad de giro un +35%.",
        value = 620, weight = 0.6,
        tags = {"movement", "drift", "rotation"},
        passiveEffects = {
            { type = "stat", stat = "rotation_speed", amount = 35, modifierType = "percent" },
            { type = "ability", ability = "inertial_gyro", value = true }
        }
    })

    -- [4] Blindaje Reactivo
    registerPassive({
        id = "reactive_armor_plating",
        name = "Blindaje Reactivo",
        description = "Reduce el daño por colisión un 25% y emite una onda de choque cuando tu escudo se rompe.",
        value = 740, weight = 1.1,
        tags = {"defense", "hull", "shockwave"},
        passiveEffects = {
            { type = "resistance", damageType = "collision", amount = 25 },
            { type = "ability", ability = "shield_break_shockwave", value = true }
        }
    })

    -- [5] Matriz Magnética de Botín
    registerPassive({
        id = "salvage_magnet_array",
        name = "Matriz Magnética de Botín",
        description = "Duplica el radio de atracción de botín y recoger botín a bordo restaura +4 de escudo.",
        value = 600, weight = 0.5,
        tags = {"utility", "salvage", "shield"},
        passiveEffects = {
            { type = "stat", stat = "pickup_radius", amount = 100, modifierType = "percent" },
            { type = "ability", ability = "scrap_shield_siphon", value = 4 }
        }
    })

    -- [6] Inyector de Postquemador
    registerPassive({
        id = "afterburner_injector",
        name = "Inyector de Postquemador",
        description = "El Turbo (Espacio) dura un +30% más y consume un 25% menos de combustible.",
        value = 580, weight = 0.7,
        tags = {"propulsion", "boost", "fuel"},
        passiveEffects = {
            { type = "stat", stat = "boost_duration", amount = 30, modifierType = "percent" },
            { type = "ability", ability = "afterburner_efficiency", value = 0.75 }
        }
    })

    -- [7] Nano-Soldador de Casco
    registerPassive({
        id = "hull_nano_welder",
        name = "Nano-Soldador de Casco",
        description = "Mientras tu escudo esté por encima del 80%, regenera gradualmente la salud del casco.",
        value = 880, weight = 0.4,
        tags = {"health", "regen", "repair"},
        passiveEffects = {
            { type = "ability", ability = "passive_hull_regen", value = 0.25 }
        }
    })

    -- =========================================================================
    -- PILAR B: PASIVAS DE HABILIDADES ACTIVAS Q Y R (8 a 13)
    -- =========================================================================

    -- [8] Capacitor Crono-Táctico
    registerPassive({
        id = "chrono_capacitor",
        name = "Capacitor Crono-Táctico",
        description = "Reduce el tiempo de enfriamiento de la Habilidad Táctica (Q) en un 25%.",
        value = 680, weight = 0.4,
        tags = {"ability", "cooldown", "tactical_q"},
        passiveEffects = {
            { type = "stat", stat = "cooldown_reduction_q", amount = 25, modifierType = "percent" }
        }
    })

    -- [9] Dinamo de Combate
    registerPassive({
        id = "singularity_dynamo",
        name = "Dinamo de Combate",
        description = "Cada nave hostil destruida recarga instantáneamente 2.5s de la Habilidad Definitiva (R).",
        value = 760, weight = 0.6,
        tags = {"ability", "ultimate_r", "combat"},
        passiveEffects = {
            { type = "ability", ability = "kill_cd_refund_r", value = 2.5 }
        }
    })

    -- [10] Módulo de Eco Dimensional
    registerPassive({
        id = "phase_echo_decoy",
        name = "Módulo de Eco Dimensional",
        description = "Al activar tu Habilidad Táctica (Q), dejas un señuelo holográfico que desvía el fuego enemigo por 2s.",
        value = 720, weight = 0.5,
        tags = {"ability", "tactical_q", "decoy"},
        passiveEffects = {
            { type = "ability", ability = "q_spawns_decoy", value = 2.0 }
        }
    })

    -- [11] Relé de Sobrecarga Táctica
    registerPassive({
        id = "overclock_relay",
        name = "Relé de Sobrecarga Táctica",
        description = "Durante 3s tras usar (Q), tus armas ganan +30% de cadencia y no consumen energía.",
        value = 790, weight = 0.5,
        tags = {"ability", "tactical_q", "weapons"},
        passiveEffects = {
            { type = "ability", ability = "q_overclock_weapons", value = 3.0 }
        }
    })

    -- [12] Amplificador de Cataclismo
    registerPassive({
        id = "cataclysm_core",
        name = "Amplificador de Cataclismo",
        description = "Aumenta la duración y el radio de impacto de la Habilidad Definitiva (R) en un +30%.",
        value = 920, weight = 0.8,
        tags = {"ability", "ultimate_r", "power"},
        passiveEffects = {
            { type = "stat", stat = "ultimate_power_r", amount = 30, modifierType = "percent" }
        }
    })

    -- [13] Convertidor de Pulso a Escudo
    registerPassive({
        id = "shield_surge_converter",
        name = "Convertidor de Pulso a Escudo",
        description = "Activar (Q) restaura 15% de escudo; activar (R) restaura el 100% del escudo al instante.",
        value = 810, weight = 0.6,
        tags = {"ability", "shield", "defense"},
        passiveEffects = {
            { type = "ability", ability = "ability_shield_restore", value = true }
        }
    })

    -- =========================================================================
    -- PILAR C: PASIVAS DE ARMAS Y PROYECTILES + REGLA 3 (14 a 20)
    -- =========================================================================

    -- [14] Sistema de Fuego Rápido
    registerPassive({
        id = "rapid_fire_system",
        name = "Sistema de Disparo Rápido",
        description = "Sistema automatizado que aumenta la cadencia de disparo de todas las armas en un 12%.",
        value = 450, weight = 0.5, icon = "rapid_fire_system",
        tags = {"weapons", "fire_rate", "automation"},
        passiveEffects = {
            { type = "stat", stat = "fire_rate", amount = 12, modifierType = "percent" }
        }
    })

    -- [15] Bobina Voltaica (Sinergia Regla 3 con Armas de Energía/Plasma)
    registerPassive({
        id = "voltaic_coil",
        name = "Bobina Voltaica",
        description = "+20% velocidad de proyectil. Tus armas de Energía/Plasma encadenan un arco eléctrico al impactar.",
        value = 780, weight = 0.6,
        tags = {"weapons", "voltaic", "synergy_mod"},
        passiveEffects = {
            { type = "stat", stat = "projectile_speed", amount = 20, modifierType = "percent" },
            { type = "ability", ability = "chain_lightning_on_hit", value = 1 }
        }
    })

    -- [16] Lente de Prisma Refractor (Sinergia Regla 3: Disparo bifurcado extra)
    registerPassive({
        id = "prism_split_lens",
        name = "Lente de Prisma Refractor",
        description = "El primer impacto de cada tercer disparo refracta un pulso hacia otro blanco cercano.",
        value = 840, weight = 0.4,
        tags = {"weapons", "prism", "synergy_mod"},
        passiveEffects = {
            { type = "ability", ability = "prism_extra_shot_every", value = 3 }
        }
    })

    -- [17] Sabot de Tungsteno (Sinergia Regla 3 con Armas Cinéticas)
    registerPassive({
        id = "tungsten_sabot",
        name = "Sabot de Tungsteno",
        description = "+15% daño de armas y otorga perforación (pierce) a todos los proyectiles cinéticos.",
        value = 760, weight = 0.9,
        tags = {"weapons", "kinetic", "pierce", "synergy_mod"},
        passiveEffects = {
            { type = "stat", stat = "damage", amount = 15, modifierType = "percent" },
            { type = "ability", ability = "kinetic_pierce_bonus", value = 1 }
        }
    })

    -- [18] Cápsula de Gel Termita (Sinergia Regla 3 con Armas de Plasma/Explosivas)
    registerPassive({
        id = "volatile_napalm_gel",
        name = "Cápsula de Gel Termita",
        description = "+10% daño. Los proyectiles de Plasma y Explosivos aplican quemadura térmica al impactar.",
        value = 720, weight = 0.7,
        tags = {"weapons", "thermal", "burn", "synergy_mod"},
        passiveEffects = {
            { type = "stat", stat = "damage", amount = 10, modifierType = "percent" },
            { type = "ability", ability = "thermal_aoe_burn", value = true }
        }
    })

    -- [19] Chip de Puntería Neuronal (Sinergia Regla 3: Soft Homing global)
    registerPassive({
        id = "neural_homing_chip",
        name = "Chip de Puntería Neuronal",
        description = "Otorga a todos los proyectiles disparados una curvatura magnética suave hacia naves hostiles.",
        value = 890, weight = 0.3,
        tags = {"weapons", "homing", "synergy_mod"},
        passiveEffects = {
            { type = "ability", ability = "soft_homing_projectiles", value = 1.8 }
        }
    })

    -- [20] Cargador de Reserva Activa
    registerPassive({
        id = "autoloader_magazine",
        name = "Cargador de Reserva Activa",
        description = "Reduce el tiempo de recarga un 20% y recarga automáticamente las armas guardadas en otros slots.",
        value = 690, weight = 0.6,
        tags = {"weapons", "reload", "automation"},
        passiveEffects = {
            { type = "stat", stat = "reload_speed", amount = 20, modifierType = "percent" },
            { type = "ability", ability = "holster_auto_reload", value = 2.5 }
        }
    })

    -- =========================================================================
    -- 3. PASIVAS EVOLUCIONADAS / RELIQUIAS (Regla 2: Pasiva + Pasiva -> Libera 1 Slot)
    -- =========================================================================

    -- [E8] Propulsores Mejorados + Giroscopio de Derrape -> Motor Vectorial Fantasma
    registerPassive({
        id = "phantom_vector_drive",
        name = "★ Motor Vectorial Fantasma",
        description = "[EVOLUCIÓN] +25% velocidad, +50% giro en derrape y emite pulsos cinéticos al derrapar con turbo.",
        rarity = ItemSystem.RARITY.EPIC, isEvolved = true,
        value = 1800, weight = 0.9,
        tags = {"passive", "movement", "evolved", "drift"},
        passiveEffects = {
            { type = "stat", stat = "speed", amount = 25, modifierType = "percent" },
            { type = "stat", stat = "rotation_speed", amount = 50, modifierType = "percent" },
            { type = "ability", ability = "phantom_drift_wave", value = true }
        }
    })

    -- [E9] Capacitor Crono-Táctico + Relé de Sobrecarga Táctica -> Núcleo de Hiper-Frecuencia
    registerPassive({
        id = "hyperfrequence_core",
        name = "★ Núcleo de Hiper-Frecuencia",
        description = "[EVOLUCIÓN] -35% cooldown en (Q) y tras activar (Q) tus armas emiten un eco diferido por disparo durante 3.5s.",
        rarity = ItemSystem.RARITY.EPIC, isEvolved = true,
        value = 2100, weight = 0.6,
        tags = {"passive", "ability", "weapons", "evolved"},
        passiveEffects = {
            { type = "stat", stat = "cooldown_reduction_q", amount = 35, modifierType = "percent" },
            { type = "ability", ability = "q_double_cast_weapons", value = 3.5 }
        }
    })

    -- [E10] Bobina Voltaica + Lente de Prisma Refractor -> Matriz de Tormenta Refractada
    registerPassive({
        id = "refracted_storm_matrix",
        name = "★ Matriz de Tormenta Refractada",
        description = "[EVOLUCIÓN] +30% velocidad de proyectil, refracta el primer impacto cada 2 tiros y encadena rayos eléctricos.",
        rarity = ItemSystem.RARITY.LEGENDARY, isEvolved = true,
        value = 2300, weight = 0.7,
        tags = {"passive", "weapons", "voltaic", "prism", "evolved"},
        passiveEffects = {
            { type = "stat", stat = "projectile_speed", amount = 30, modifierType = "percent" },
            { type = "ability", ability = "prism_extra_shot_every", value = 2 },
            { type = "ability", ability = "chain_lightning_on_hit", value = 2 },
            { type = "ability", ability = "storm_matrix_fork", value = true }
        }
    })

    print("Items pasivos registrados: 23 items (20 base + 3 evoluciones)")
end

-- NOTA: Las funciones applyPassiveEffect y removePassiveEffect han sido
-- centralizadas en PassiveManager para evitar duplicaciones

return Passives