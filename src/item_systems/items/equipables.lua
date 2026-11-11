-- Items Equipables para Space Roguelike
-- Armas, armaduras, herramientas y accesorios que se pueden equipar

local ItemSystem = require("src.item_systems.item_system")

local Equipables = {}

-- Slots de equipamiento
Equipables.SLOTS = {
    WEAPON_PRIMARY = "weapon_primary",
    WEAPON_SECONDARY = "weapon_secondary",
    ARMOR_HEAD = "armor_head",
    ARMOR_CHEST = "armor_chest",
    ARMOR_LEGS = "armor_legs",
    TOOL_MINING = "tool_mining",
    TOOL_REPAIR = "tool_repair",
    ACCESSORY_1 = "accessory_1",
    ACCESSORY_2 = "accessory_2",
    UTILITY = "utility",
    SHIELD = "shield"
}

-- Tipos de daño para armas
local DAMAGE_TYPES = {
    KINETIC = "kinetic",
    ENERGY = "energy",
    PLASMA = "plasma",
    EXPLOSIVE = "explosive"
}

-- Función auxiliar para registrar armas con integración limpia de 9 slots
local function registerWeapon(def)
    def.category = ItemSystem.CATEGORIES.EQUIPABLE
    def.equipType = ItemSystem.EQUIPABLE_TYPES.WEAPON
    def.slot = def.slot or Equipables.SLOTS.WEAPON_PRIMARY
    def.rarity = def.rarity or "weapon"
    def.tags = def.tags or {"weapon", def.damageType or "energy", "ranged"}

    if not def.onEquip then
        def.onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            if player.weaponSystem then
                local slot = 2
                for i = 1, 9 do
                    if not (player.inventory and player.inventory:getWeaponInSlot(i)) then
                        slot = i
                        break
                    end
                end
                player.weaponSystem:equipWeapon(self, slot)
            end
            return tostring(self.name) .. " equipada"
        end
    end

    if not def.onUnequip then
        def.onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            if player.weaponSystem and player.inventory then
                for i = 1, 9 do
                    local w = player.inventory:getWeaponInSlot(i)
                    if w and ((w.data and w.data.id == self.id) or w.id == self.id) then
                        player.weaponSystem:unequipWeapon(i)
                        break
                    end
                end
            end
            return tostring(self.name) .. " desequipada"
        end
    end

    ItemSystem:registerItem(def)
end

-- Función para registrar todos los equipables
function Equipables.registerAll()
    -- =========================================================================
    -- 1. CATÁLOGO DE 20 ARMAS BASE (4 Familias: Cinética, Energía, Plasma, Exótica)
    -- =========================================================================

    -- [1] Pistola Láser Básica (Energía)
    registerWeapon({
        id = "basic_laser_pistol",
        name = "Pistola Láser Básica",
        description = "Pistola láser estándar precisa y de bajo consumo. Daño: 15-25 energía.",
        value = 200, weight = 1.2, icon = "laser_pistol",
        tags = {"weapon", "energy", "ranged", "laser"},
        damage = { min = 15, max = 25 }, damageType = DAMAGE_TYPES.ENERGY,
        range = 180, fireRate = 2.4, energyCost = 4, accuracy = 88,
        maxAmmo = 14, reloadTime = 1.6, automatic = false,
        projectileArchetype = "basic_red_projectile"
    })

    -- [2] Rifle de Plasma (Plasma)
    registerWeapon({
        id = "plasma_rifle",
        name = "Rifle de Plasma",
        description = "Rifle de plasma de largo alcance y daño sostenido. Daño: 30-45 plasma.",
        value = 800, weight = 2.5, icon = "plasma_rifle",
        tags = {"weapon", "plasma", "ranged", "heavy"},
        damage = { min = 30, max = 45 }, damageType = DAMAGE_TYPES.PLASMA,
        range = 260, fireRate = 1.4, energyCost = 10, accuracy = 80,
        maxAmmo = 20, reloadTime = 2.4, automatic = false,
        projectileArchetype = "plasma_projectile"
    })

    -- [3] Rifle de Asalto Cinético (Cinética)
    registerWeapon({
        id = "kinetic_assault_rifle",
        name = "Rifle de Asalto Cinético",
        description = "Rifle automático de proyectiles físicos de alta cadencia. Daño: 18-28 cinético.",
        value = 450, weight = 2.0, icon = "assault_rifle",
        tags = {"weapon", "kinetic", "ranged", "automatic"},
        damage = { min = 18, max = 28 }, damageType = DAMAGE_TYPES.KINETIC,
        range = 210, fireRate = 4.2, energyCost = 3, accuracy = 82,
        maxAmmo = 30, reloadTime = 1.5, automatic = true,
        projectileArchetype = "kinetic_projectile"
    })

    -- [4] Cañón de Plasma Pesado (Plasma)
    registerWeapon({
        id = "heavy_plasma_cannon",
        name = "Cañón de Plasma Pesado",
        description = "Artillería pesada de plasma con gran daño de impacto. Daño: 55-85 plasma.",
        value = 1500, weight = 4.0, icon = "plasma_cannon",
        tags = {"weapon", "plasma", "ranged", "heavy", "explosive"},
        damage = { min = 55, max = 85 }, damageType = DAMAGE_TYPES.PLASMA,
        range = 300, fireRate = 0.85, energyCost = 22, accuracy = 74,
        maxAmmo = 8, reloadTime = 3.2, automatic = false,
        projectileArchetype = "heavy_plasma_projectile"
    })

    -- [5] Escopeta de Energía (Energía)
    registerWeapon({
        id = "energy_shotgun",
        name = "Escopeta de Energía",
        description = "Dispersa un abanico de 5 pulsos fotónicos letales a corta distancia.",
        value = 700, weight = 2.8, icon = "energy_shotgun",
        tags = {"weapon", "energy", "ranged", "spread"},
        damage = { min = 12, max = 20 }, damageType = DAMAGE_TYPES.ENERGY,
        range = 110, fireRate = 1.5, energyCost = 14, accuracy = 65,
        maxAmmo = 12, reloadTime = 2.0, automatic = false,
        firePattern = "fan", projectileCount = 5, spreadAngle = math.pi / 6,
        projectileArchetype = "energy_shotgun_projectile"
    })

    -- [6] Autocañón Rotativo "Vulcan" (Cinética)
    registerWeapon({
        id = "rotary_autocannon",
        name = "Autocañón Rotativo Vulcan",
        description = "Acelera su cadencia de tiro cuanto más mantienes el disparo continuo.",
        value = 950, weight = 3.4, icon = "assault_rifle",
        tags = {"weapon", "kinetic", "ranged", "automatic", "spinup"},
        damage = { min = 14, max = 22 }, damageType = DAMAGE_TYPES.KINETIC,
        range = 200, fireRate = 6.5, energyCost = 2, accuracy = 72,
        maxAmmo = 60, reloadTime = 2.8, automatic = true,
        spinUpMaxBonus = 0.85,
        projectileArchetype = "kinetic_projectile"
    })

    -- [7] Cañón de Riel Gauss (Cinética)
    registerWeapon({
        id = "gauss_railgun",
        name = "Cañón de Riel Gauss",
        description = "Disparo hipersónico de tungsteno que perfora objetivos en línea recta.",
        value = 1250, weight = 3.2, icon = "plasma_rifle",
        tags = {"weapon", "kinetic", "ranged", "pierce", "sniper"},
        damage = { min = 48, max = 72 }, damageType = DAMAGE_TYPES.KINETIC,
        range = 420, fireRate = 1.0, energyCost = 16, accuracy = 98,
        maxAmmo = 6, reloadTime = 2.5, automatic = false,
        firePattern = "precision", penetration = true, penetrationDecay = .70, speedMultiplier = 1.75,
        projectileArchetype = "kinetic_projectile"
    })

    -- [8] Lanzador de Esquirlas (Cinética)
    registerWeapon({
        id = "ricochet_shard_gun",
        name = "Lanzador de Esquirlas",
        description = "Dispara discos metálicos angulados que rebotan hasta 3 veces en asteroides y cascos.",
        value = 680, weight = 2.1, icon = "assault_rifle",
        tags = {"weapon", "kinetic", "ranged", "ricochet"},
        damage = { min = 22, max = 32 }, damageType = DAMAGE_TYPES.KINETIC,
        range = 240, fireRate = 2.6, energyCost = 5, accuracy = 85,
        maxAmmo = 18, reloadTime = 1.8, automatic = false,
        bounces = 3,
        projectileArchetype = "kinetic_projectile"
    })

    -- [9] Cañón Antiaéreo Flak (Cinética)
    registerWeapon({
        id = "flak_shrapnel_cannon",
        name = "Cañón Antiaéreo Flak",
        description = "Obús pesado que estalla en una nube de 8 fragmentos cinéticos al impactar o expirar.",
        value = 880, weight = 3.1, icon = "energy_shotgun",
        tags = {"weapon", "kinetic", "ranged", "explosive", "flak"},
        damage = { min = 28, max = 42 }, damageType = DAMAGE_TYPES.KINETIC,
        range = 175, fireRate = 1.3, energyCost = 12, accuracy = 78,
        maxAmmo = 10, reloadTime = 2.3, automatic = false,
        clusterCount = 8,
        projectileArchetype = "kinetic_projectile"
    })

    -- [10] Carabina de Pulso Prismático (Energía)
    registerWeapon({
        id = "prism_pulse_carbine",
        name = "Carabina de Pulso Prismático",
        description = "Dispara una ráfaga tri-angular de 3 pulsos de luz refractada por tiro.",
        value = 740, weight = 1.9, icon = "laser_pistol",
        tags = {"weapon", "energy", "ranged", "prism"},
        damage = { min = 14, max = 21 }, damageType = DAMAGE_TYPES.ENERGY,
        range = 220, fireRate = 2.2, energyCost = 8, accuracy = 90,
        maxAmmo = 24, reloadTime = 1.7, automatic = true,
        projectileCount = 3, spreadAngle = math.pi / 14,
        projectileArchetype = "basic_red_projectile"
    })

    -- [11] Emisor de Arco Tesla (Energía)
    registerWeapon({
        id = "arc_tesla_emitter",
        name = "Emisor de Arco Tesla",
        description = "Esfera voltaica que al impactar salta en cadena eléctrica hacia un enemigo cercano.",
        value = 920, weight = 2.3, icon = "plasma_rifle",
        tags = {"weapon", "energy", "ranged", "voltaic", "chain"},
        damage = { min = 24, max = 36 }, damageType = DAMAGE_TYPES.ENERGY,
        range = 190, fireRate = 2.0, energyCost = 11, accuracy = 86,
        maxAmmo = 16, reloadTime = 2.0, automatic = false,
        chainArc = 1,
        projectileArchetype = "plasma_projectile"
    })

    -- [12] Lanza Fotónica de Fase (Energía)
    registerWeapon({
        id = "phase_beam_lance",
        name = "Lanza Fotónica de Fase",
        description = "Haz concentrado de alta velocidad que perfora escudos y atraviesa objetivos.",
        value = 1100, weight = 2.4, icon = "plasma_rifle",
        tags = {"weapon", "energy", "ranged", "pierce", "phase"},
        damage = { min = 36, max = 52 }, damageType = DAMAGE_TYPES.ENERGY,
        range = 340, fireRate = 1.35, energyCost = 14, accuracy = 96,
        maxAmmo = 10, reloadTime = 2.2, automatic = false,
        penetration = true, shieldBypass = 0.40, speedMultiplier = 1.5,
        projectileArchetype = "basic_red_projectile"
    })

    -- [13] Lanzador de Escoria Fundida (Plasma)
    registerWeapon({
        id = "magma_slag_thrower",
        name = "Lanzador de Escoria Fundida",
        description = "Escupe globos de magma incandescente que aplican quemadura térmica prolongada.",
        value = 840, weight = 2.9, icon = "plasma_cannon",
        tags = {"weapon", "plasma", "ranged", "thermal", "burn"},
        damage = { min = 26, max = 40 }, damageType = DAMAGE_TYPES.PLASMA,
        range = 165, fireRate = 1.8, energyCost = 10, accuracy = 76,
        maxAmmo = 16, reloadTime = 2.1, automatic = true,
        statusEffect = "burn",
        projectileArchetype = "heavy_plasma_projectile"
    })

    -- [14] Bláster de Agujas Criogénicas (Plasma)
    registerWeapon({
        id = "cryo_shard_blaster",
        name = "Bláster de Agujas Criogénicas",
        description = "Cristales helados a hipervelocidad que ralentizan un 35% los motores enemigos.",
        value = 820, weight = 2.0, icon = "laser_pistol",
        tags = {"weapon", "plasma", "ranged", "cryo", "slow"},
        damage = { min = 20, max = 30 }, damageType = DAMAGE_TYPES.PLASMA,
        range = 230, fireRate = 2.8, energyCost = 7, accuracy = 89,
        maxAmmo = 22, reloadTime = 1.8, automatic = true,
        statusEffect = "cryo_slow",
        projectileArchetype = "plasma_projectile"
    })

    -- [15] Mortero de Fulgor Solar (Plasma)
    registerWeapon({
        id = "solar_flare_mortar",
        name = "Mortero de Fulgor Solar",
        description = "Orbe solar pulsante que detona en un anillo térmico de gran radio.",
        value = 1150, weight = 3.5, icon = "plasma_cannon",
        tags = {"weapon", "plasma", "ranged", "explosive", "solar"},
        damage = { min = 44, max = 68 }, damageType = DAMAGE_TYPES.PLASMA,
        range = 250, fireRate = 1.0, energyCost = 18, accuracy = 75,
        maxAmmo = 8, reloadTime = 2.7, automatic = false,
        explosionRadius = 75,
        projectileArchetype = "heavy_plasma_projectile"
    })

    -- [16] Lanzador de Micro-Misiles (Exótica)
    registerWeapon({
        id = "swarm_micro_missiles",
        name = "Lanzador de Micro-Misiles",
        description = "Dispara una salva de 3 micro-misiles con rastreo magnético hacia naves hostiles.",
        value = 980, weight = 2.7, icon = "energy_shotgun",
        tags = {"weapon", "explosive", "ranged", "homing", "swarm"},
        damage = { min = 15, max = 24 }, damageType = DAMAGE_TYPES.EXPLOSIVE,
        range = 280, fireRate = 1.6, energyCost = 12, accuracy = 80,
        maxAmmo = 15, reloadTime = 2.2, automatic = false,
        projectileCount = 3, spreadAngle = math.pi / 5, homingStrength = 3.2,
        projectileArchetype = "energy_shotgun_projectile"
    })

    -- [17] Lanzatorpedos de Asedio (Exótica)
    registerWeapon({
        id = "heavy_torpedo_launcher",
        name = "Lanzatorpedos de Asedio",
        description = "Torpedo pesado con aceleración progresiva y devastadora onda expansiva.",
        value = 1400, weight = 4.2, icon = "plasma_cannon",
        tags = {"weapon", "explosive", "ranged", "heavy", "torpedo"},
        damage = { min = 65, max = 95 }, damageType = DAMAGE_TYPES.EXPLOSIVE,
        range = 350, fireRate = 0.7, energyCost = 24, accuracy = 82,
        maxAmmo = 6, reloadTime = 3.4, automatic = false,
        explosionRadius = 95, homingStrength = 1.2,
        projectileArchetype = "heavy_plasma_projectile"
    })

    -- [18] Lanzasierras de Desguace (Exótica)
    registerWeapon({
        id = "industrial_rip_saw",
        name = "Lanzasierras de Desguace",
        description = "Dispara discos de corte industrial que perforan y regresan hacia la nave como bumerán.",
        value = 890, weight = 3.0, icon = "assault_rifle",
        tags = {"weapon", "kinetic", "ranged", "saw", "boomerang"},
        damage = { min = 28, max = 42 }, damageType = DAMAGE_TYPES.KINETIC,
        range = 190, fireRate = 1.7, energyCost = 8, accuracy = 85,
        maxAmmo = 12, reloadTime = 2.0, automatic = false,
        penetration = true, isBoomerang = true,
        projectileArchetype = "kinetic_projectile"
    })

    -- [19] Proyector de Onda Gravítica (Exótica)
    registerWeapon({
        id = "gravitic_wave_projector",
        name = "Proyector de Onda Gravítica",
        description = "Media luna de distorsión espacial que empuja violentamente a las naves enemigas.",
        value = 960, weight = 2.6, icon = "plasma_rifle",
        tags = {"weapon", "energy", "ranged", "gravitic", "knockback"},
        damage = { min = 24, max = 36 }, damageType = DAMAGE_TYPES.ENERGY,
        range = 185, fireRate = 1.6, energyCost = 13, accuracy = 88,
        maxAmmo = 14, reloadTime = 2.1, automatic = false,
        penetration = true, knockbackForce = 260, scaleMultiplier = 1.4,
        projectileArchetype = "plasma_projectile"
    })

    -- [20] Aguijón del Vacío (Exótica)
    registerWeapon({
        id = "void_needle_dart",
        name = "Aguijón del Vacío",
        description = "Agujas oscuras de alta cadencia que implosionan con daño extra al recargar el arma.",
        value = 1050, weight = 1.8, icon = "laser_pistol",
        tags = {"weapon", "energy", "ranged", "void", "detonator"},
        damage = { min = 19, max = 29 }, damageType = DAMAGE_TYPES.ENERGY,
        range = 240, fireRate = 3.6, energyCost = 5, accuracy = 92,
        maxAmmo = 20, reloadTime = 1.6, automatic = true,
        voidDetonator = true,
        projectileArchetype = "basic_red_projectile"
    })

    -- =========================================================================
    -- 2. ARMAS EVOLUCIONADAS POR SINERGIA (Regla 1: Arma + Arma -> Libera 1 Slot)
    -- =========================================================================

    -- [E1] Escopeta de Energía + Rifle de Plasma -> Cañón Termoclástico
    registerWeapon({
        id = "thermo_cluster_cannon",
        name = "★ Cañón Termoclástico",
        description = "[EVOLUCIÓN] Dispara un abanico de esferas de plasma volátil que estallan en racimos térmicos.",
        rarity = ItemSystem.RARITY.EPIC, isEvolved = true,
        value = 2400, weight = 3.0, icon = "energy_shotgun",
        tags = {"weapon", "plasma", "energy", "evolved", "spread", "cluster"},
        damage = { min = 26, max = 38 }, damageType = DAMAGE_TYPES.PLASMA,
        range = 210, fireRate = 1.85, energyCost = 14, accuracy = 78,
        maxAmmo = 18, reloadTime = 1.8, automatic = true,
        projectileCount = 5, spreadAngle = math.pi / 6, clusterCount = 4, statusEffect = "burn",
        projectileArchetype = "plasma_projectile"
    })

    -- [E2] Pistola Láser Básica + Rifle de Asalto Cinético -> Gatling Fotónica de Pulso
    registerWeapon({
        id = "photon_pulse_gatling",
        name = "★ Gatling Fotónica de Pulso",
        description = "[EVOLUCIÓN] Ráfaga hiperveloz de agujas láser-cinéticas gemelas con perforación.",
        rarity = ItemSystem.RARITY.EPIC, isEvolved = true,
        value = 2100, weight = 2.2, icon = "assault_rifle",
        tags = {"weapon", "kinetic", "energy", "evolved", "automatic", "pierce"},
        damage = { min = 24, max = 35 }, damageType = DAMAGE_TYPES.ENERGY,
        range = 250, fireRate = 6.2, energyCost = 3, accuracy = 88,
        maxAmmo = 45, reloadTime = 1.4, automatic = true,
        projectileCount = 2, spreadAngle = 0.06, penetration = true, speedMultiplier = 1.35,
        projectileArchetype = "basic_red_projectile"
    })

    -- [E3] Cañón de Plasma Pesado + Cañón de Riel Gauss -> Lanza de Supernova
    registerWeapon({
        id = "supernova_rail_lance",
        name = "★ Lanza de Supernova",
        description = "[EVOLUCIÓN] Haz magnético relativista que atraviesa todas las naves y detona en supernova.",
        rarity = ItemSystem.RARITY.LEGENDARY, isEvolved = true,
        value = 3400, weight = 3.8, icon = "plasma_cannon",
        tags = {"weapon", "plasma", "kinetic", "evolved", "pierce", "explosive"},
        damage = { min = 95, max = 135 }, damageType = DAMAGE_TYPES.PLASMA,
        range = 460, fireRate = 1.15, energyCost = 20, accuracy = 99,
        maxAmmo = 10, reloadTime = 2.2, automatic = false,
        penetration = true, speedMultiplier = 1.85, scaleMultiplier = 1.45, explosionRadius = 90,
        projectileArchetype = "heavy_plasma_projectile"
    })

    -- [E4] Emisor de Arco Tesla + Lanzador de Micro-Misiles -> Enjambre de Tormenta Voltaica
    registerWeapon({
        id = "valkyrie_storm_swarm",
        name = "★ Enjambre de Tormenta Voltaica",
        description = "[EVOLUCIÓN] Salva de 4 misiles rastreadores que descargan arcos eléctricos en cadena.",
        rarity = ItemSystem.RARITY.EPIC, isEvolved = true,
        value = 2600, weight = 2.6, icon = "energy_shotgun",
        tags = {"weapon", "energy", "explosive", "evolved", "homing", "chain"},
        damage = { min = 24, max = 36 }, damageType = DAMAGE_TYPES.ENERGY,
        range = 310, fireRate = 2.0, energyCost = 12, accuracy = 86,
        maxAmmo = 20, reloadTime = 1.8, automatic = true,
        projectileCount = 4, spreadAngle = math.pi / 4, homingStrength = 3.8, chainArc = 2,
        projectileArchetype = "energy_shotgun_projectile"
    })

    -- [E5] Lanzador de Esquirlas + Lanzasierras de Desguace -> Trituradora Orbital de Cuchillas
    registerWeapon({
        id = "orbital_shredder",
        name = "★ Trituradora Orbital de Cuchillas",
        description = "[EVOLUCIÓN] Lanza una cuchilla que corta al salir y al volver. Cambia tu posición para dirigir el retorno.",
        rarity = ItemSystem.RARITY.EPIC, isEvolved = true,
        value = 2500, weight = 2.8, icon = "assault_rifle",
        tags = {"weapon", "kinetic", "evolved", "ricochet", "boomerang"},
        damage = { min = 38, max = 54 }, damageType = DAMAGE_TYPES.KINETIC,
        range = 260, fireRate = 2.3, energyCost = 8, accuracy = 90,
        maxAmmo = 20, reloadTime = 1.6, automatic = true,
        firePattern = "return", returnDistance = 390, isBoomerang = true, penetration = true, speedMultiplier = .52,
        projectileArchetype = "kinetic_projectile"
    })

    -- [E6] Lanzador de Escoria Fundida + Bláster de Agujas Criogénicas -> Cañón de Choque Térmico
    registerWeapon({
        id = "thermal_shock_cannon",
        name = "★ Cañón de Choque Térmico",
        description = "[EVOLUCIÓN] Dispara proyectiles duales de magma y criogenia que causan fractura térmica (+50% daño).",
        rarity = ItemSystem.RARITY.EPIC, isEvolved = true,
        value = 2550, weight = 2.5, icon = "plasma_rifle",
        tags = {"weapon", "plasma", "evolved", "thermal", "cryo"},
        damage = { min = 36, max = 52 }, damageType = DAMAGE_TYPES.PLASMA,
        range = 240, fireRate = 2.5, energyCost = 10, accuracy = 88,
        maxAmmo = 24, reloadTime = 1.7, automatic = true,
        projectileCount = 2, spreadAngle = 0.08, statusEffect = "thermal_shock",
        projectileArchetype = "plasma_projectile"
    })

    -- [E7] Proyector de Onda Gravítica + Lanzatorpedos de Asedio -> Torpedo de Singularidad
    registerWeapon({
        id = "singularity_torpedo",
        name = "★ Torpedo de Singularidad",
        description = "[EVOLUCIÓN] Planta un núcleo en la mira. El área atrae a las naves cercanas y avisa antes de implosionar.",
        rarity = ItemSystem.RARITY.LEGENDARY, isEvolved = true,
        value = 3200, weight = 3.9, icon = "plasma_cannon",
        tags = {"weapon", "explosive", "energy", "evolved", "gravitic", "singularity"},
        damage = { min = 85, max = 125 }, damageType = DAMAGE_TYPES.EXPLOSIVE,
        range = 360, fireRate = 0.95, energyCost = 22, accuracy = 88,
        maxAmmo = 8, reloadTime = 2.6, automatic = false,
        firePattern = "seed", anchorFuse = .75, explosionRadius = 120, graviticPull = 320, scaleMultiplier = 1.5,
        projectileArchetype = "heavy_plasma_projectile"
    })
    
    -- === ARMADURAS ===
    
    -- Casco EVA
    ItemSystem:registerItem({
        id = "eva_helmet",
        name = "Casco EVA",
        description = "Un casco espacial que proporciona protección y soporte vital. +10 Defensa, +20 Resistencia al vacío.",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.ARMOR,
        slot = Equipables.SLOTS.ARMOR_HEAD,
        rarity = ItemSystem.RARITY.UNCOMMON,
        value = 300,
        weight = 1.5,
        icon = "eva_helmet",
        tags = {"armor", "head", "eva", "life_support"},
        
        defense = 10,
        resistances = {
            vacuum = 20,
            radiation = 15
        },
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            if player.stats then
                player.stats.defense = (player.stats.defense or 0) + self.defense
            end
            return "Casco EVA equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            if player.stats then
                player.stats.defense = (player.stats.defense or 0) - self.defense
            end
            return "Casco EVA desequipado"
        end
    })
    
    -- Traje Espacial Reforzado
    ItemSystem:registerItem({
        id = "reinforced_spacesuit",
        name = "Traje Espacial Reforzado",
        description = "Un traje espacial con blindaje adicional. +25 Defensa, +30 Resistencia al vacío.",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.ARMOR,
        slot = Equipables.SLOTS.ARMOR_CHEST,
        rarity = ItemSystem.RARITY.RARE,
        value = 600,
        weight = 3.0,
        icon = "reinforced_suit",
        tags = {"armor", "chest", "eva", "heavy"},
        
        defense = 25,
        resistances = {
            vacuum = 30,
            kinetic = 20,
            energy = 10
        },
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            if player.stats then
                player.stats.defense = (player.stats.defense or 0) + self.defense
            end
            return "Traje espacial reforzado equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            if player.stats then
                player.stats.defense = (player.stats.defense or 0) - self.defense
            end
            return "Traje espacial reforzado desequipado"
        end
    })
    
    -- === HERRAMIENTAS ===
    
    -- Taladro Minero
    ItemSystem:registerItem({
        id = "mining_drill",
        name = "Taladro Minero",
        description = "Una herramienta especializada para extraer minerales. Eficiencia de minería +50%.",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.TOOL,
        slot = Equipables.SLOTS.TOOL_MINING,
        rarity = ItemSystem.RARITY.UNCOMMON,
        value = 400,
        weight = 2.0,
        icon = "mining_drill",
        tags = {"tool", "mining", "extraction"},
        
        miningEfficiency = 1.5,
        energyCost = 8,
        durability = 100,
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            return "Taladro minero equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            return "Taladro minero desequipado"
        end,
        
        use = function(self, player, target)
            if self.durability <= 0 then
                return "El taladro está dañado y necesita reparación"
            end
            
            self.durability = self.durability - 1
            return "Extrayendo minerales..."
        end
    })
    
    -- Kit de Reparación Avanzado
    ItemSystem:registerItem({
        id = "advanced_repair_kit",
        name = "Kit de Reparación Avanzado",
        description = "Herramientas avanzadas para reparar equipos. Eficiencia de reparación +75%.",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.TOOL,
        slot = Equipables.SLOTS.TOOL_REPAIR,
        rarity = ItemSystem.RARITY.RARE,
        value = 500,
        weight = 1.5,
        icon = "repair_kit_adv",
        tags = {"tool", "repair", "maintenance"},
        
        repairEfficiency = 1.75,
        energyCost = 5,
        durability = 150,
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            return "Kit de reparación avanzado equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            return "Kit de reparación avanzado desequipado"
        end,
        
        use = function(self, player, target)
            if self.durability <= 0 then
                return "El kit de reparación está agotado"
            end
            
            self.durability = self.durability - 1
            return "Reparando equipo..."
        end
    })
    
    -- === ACCESORIOS ===
    
    -- Anillo de Traducción Universal
    ItemSystem:registerItem({
        id = "universal_translator",
        name = "Anillo de Traducción Universal",
        description = "Un dispositivo que permite comunicarse con especies alienígenas.",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.ACCESSORY,
        slot = Equipables.SLOTS.ACCESSORY_1,
        rarity = ItemSystem.RARITY.EPIC,
        value = 1000,
        weight = 0.1,
        icon = "translator",
        tags = {"accessory", "communication", "alien"},
        
        abilities = {
            universal_translation = true
        },
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            if not player.abilities then
                player.abilities = {}
            end
            player.abilities.universal_translation = true
            return "Traductor universal activado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            if player.abilities then
                player.abilities.universal_translation = nil
            end
            return "Traductor universal desactivado"
        end
    })
    
    -- === UTILIDADES ===
    
    -- Escáner Básico
    ItemSystem:registerItem({
        id = "scanner_basic",
        name = "Escáner Básico",
        description = "Detecta recursos cercanos",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.UTILITY,
        slot = Equipables.SLOTS.UTILITY,
        rarity = ItemSystem.RARITY.COMMON,
        value = 150,
        weight = 0.5,
        icon = "scanner",
        tags = {"utility", "scanner", "detection"},
        
        stats = {
            range = 100
        },
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            return "Escáner básico equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            return "Escáner básico desequipado"
        end
    })
    
    -- Escudo Básico
    ItemSystem:registerItem({
        id = "shield_basic",
        name = "Escudo Básico",
        description = "Protección estándar",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.SHIELD,
        slot = Equipables.SLOTS.SHIELD,
        rarity = ItemSystem.RARITY.COMMON,
        value = 200,
        weight = 2.0,
        icon = "shield",
        tags = {"shield", "defense", "protection"},
        
        stats = {
            shield = 50,
            regen = 2
        },
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            return "Escudo básico equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            return "Escudo básico desequipado"
        end
    })
    
    -- Láser Básico
    ItemSystem:registerItem({
        id = "laser_basic",
        name = "Láser Básico",
        description = "Arma láser estándar",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.WEAPON,
        slot = Equipables.SLOTS.WEAPON_PRIMARY,
        rarity = ItemSystem.RARITY.COMMON,
        value = 100,
        weight = 1.0,
        icon = "laser",
        tags = {"weapon", "laser", "energy"},
        
        stats = {
            damage = 10,
            energy = 5
        },
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            return "Láser básico equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            return "Láser básico desequipado"
        end
    })
    
    -- Motor Básico
    ItemSystem:registerItem({
        id = "engine_basic",
        name = "Motor Básico",
        description = "Propulsión estándar",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.TOOL,
        slot = Equipables.SLOTS.TOOL_REPAIR,
        rarity = ItemSystem.RARITY.COMMON,
        value = 250,
        weight = 5.0,
        icon = "engine",
        tags = {"engine", "propulsion", "speed"},
        
        stats = {
            speed = 10,
            acceleration = 5
        },
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            return "Motor básico equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            return "Motor básico desequipado"
        end
    })
    
    print("Items equipables registrados: 12 items")
end

-- Función para obtener el daño total de un arma
function Equipables.getWeaponDamage(weapon)
    if not weapon.damage then return 0 end
    return math.random(weapon.damage.min, weapon.damage.max)
end

-- Función para verificar si un item puede ser equipado en un slot
function Equipables.canEquipInSlot(item, slot)
    return item.slot == slot
end

-- Función para obtener la defensa total del equipamiento
function Equipables.getTotalDefense(equipment)
    local totalDefense = 0
    for slot, item in pairs(equipment) do
        if item.defense then
            totalDefense = totalDefense + item.defense
        end
    end
    return totalDefense
end

return Equipables