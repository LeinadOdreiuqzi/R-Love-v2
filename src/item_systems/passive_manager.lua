--[[
    Passive Manager - Sistema de Gestión de Efectos Pasivos
    
    Este módulo previene la duplicación de efectos pasivos y maneja
    correctamente el ciclo de vida de los efectos cuando los items
    son equipados, movidos o removidos.
    
    Características:
    - Seguimiento de efectos activos por ID único de item
    - Prevención automática de duplicaciones
    - Limpieza automática de efectos huérfanos
    - Integración transparente con el sistema existente
--]]

local PassiveManager = {}

-- Dependencias
local Passives = require("src.item_systems.items.passives")

-- Estado interno del manager
local state = {
    -- Flag de inicialización
    initialized = false,
    
    -- Tabla que mapea item_id -> { player, item_data, effects_applied }
    activeEffects = {},
    
    -- Contador para generar IDs únicos de items
    nextItemId = 1,
    
    -- Estadísticas para debugging
    stats = {
        totalEffectsApplied = 0,
        totalEffectsRemoved = 0,
        duplicationsBlocked = 0,
        orphanedEffectsCleaned = 0
    }
}

--[[
    Genera un ID único para un item
    @param itemData: datos del item
    @return: string ID único
--]]
local function generateItemId(itemData)
    local id = "item_" .. state.nextItemId .. "_" .. (itemData.id or "unknown")
    state.nextItemId = state.nextItemId + 1
    return id
end

--[[
    Verifica si un efecto ya está activo para un item específico
    @param itemId: ID único del item
    @return: boolean
--]]
local function isEffectActive(itemId)
    return state.activeEffects[itemId] ~= nil
end

--[[
    Aplica efectos pasivos de un item, previniendo duplicaciones
    @param player: referencia al jugador
    @param itemData: datos del item
    @param itemId: ID único del item (opcional, se genera si no se proporciona)
    @return: string itemId usado, nil si no se aplicó
--]]
function PassiveManager.applyPassiveEffect(player, itemData, itemId)
    -- Validar parámetros
    if not player or not itemData then
        print("[PassiveManager] Error: player o itemData es nil")
        return nil
    end
    
    -- Solo procesar items pasivos
    if not itemData.category or itemData.category ~= "passive" then
        return nil
    end
    
    -- Generar ID si no se proporciona
    if not itemId then
        itemId = generateItemId(itemData)
    end
    
    -- Verificar si el efecto ya está activo
    if isEffectActive(itemId) then
        state.stats.duplicationsBlocked = state.stats.duplicationsBlocked + 1
        print("[PassiveManager] Duplicación bloqueada para item: " .. (itemData.name or itemData.id or "unknown") .. " (ID: " .. itemId .. ")")
        return itemId
    end
    
    -- Aplicar los efectos reales usando el sistema original
    if itemData.passiveEffects then
        for _, effect in ipairs(itemData.passiveEffects) do
            if effect.type == "stat" then
                -- Aplicar modificador de estadística
                if not player.passiveModifiers then
                    player.passiveModifiers = {}
                end
                
                if not player.passiveModifiers[effect.stat] then
                    player.passiveModifiers[effect.stat] = { flat = 0, percent = 0 }
                end
                
                if effect.modifierType == "flat" then
                    player.passiveModifiers[effect.stat].flat = player.passiveModifiers[effect.stat].flat + effect.amount
                elseif effect.modifierType == "percent" then
                    player.passiveModifiers[effect.stat].percent = player.passiveModifiers[effect.stat].percent + effect.amount
                end
                
                -- Aplicar efectos específicos a las estadísticas del jugador
                if effect.stat == "max_health" and effect.modifierType == "flat" then
                    if player.stats and player.stats.health then
                        player.stats.health.maxHearts = player.stats.health.maxHearts + effect.amount
                        player.stats.health.maxHealth = player.stats.health.maxHealth + (effect.amount * 2) -- 1 corazón = 2 vida
                        player.stats.health.currentHealth = player.stats.health.currentHealth + (effect.amount * 2)
                        print("[PassiveManager] Aplicado a estadísticas: +" .. effect.amount .. " corazones")
                    end
                end
                
                print("[PassiveManager] Aplicado efecto de stat: " .. effect.stat .. " +" .. effect.amount .. " (" .. (effect.modifierType or "flat") .. ")")
            elseif effect.type == "resistance" then
                -- Aplicar resistencia
                if not player.resistances then
                    player.resistances = {}
                end
                player.resistances[effect.damageType] = (player.resistances[effect.damageType] or 0) + effect.amount
                print("[PassiveManager] Aplicado efecto de resistencia: " .. effect.damageType .. " +" .. effect.amount)
            elseif effect.type == "ability" then
                -- Aplicar habilidad
                if not player.abilities then
                    player.abilities = {}
                end
                player.abilities[effect.ability] = effect.value
                print("[PassiveManager] Aplicado efecto de habilidad: " .. effect.ability)
            end
        end
    end
    
    -- Registrar el efecto como activo
    state.activeEffects[itemId] = {
        player = player,
        itemData = itemData,
        appliedAt = love.timer.getTime(),
        effectsApplied = true
    }
    
    state.stats.totalEffectsApplied = state.stats.totalEffectsApplied + 1
    print("[PassiveManager] Efecto aplicado: " .. (itemData.name or itemData.id or "unknown") .. " (ID: " .. itemId .. ")")
    return itemId
end

--[[
    Remueve efectos pasivos de un item específico
    @param itemId: ID único del item
    @return: boolean éxito
--]]
function PassiveManager.removePassiveEffect(itemId)
    -- Verificar si el efecto está activo
    if not isEffectActive(itemId) then
        print("[PassiveManager] Advertencia: Intento de remover efecto no activo (ID: " .. (itemId or "nil") .. ")")
        return false
    end
    
    local effectData = state.activeEffects[itemId]
    local player = effectData.player
    local itemData = effectData.itemData
    
    -- Remover los efectos reales directamente
    if itemData and itemData.passiveEffects then
        for _, effect in ipairs(itemData.passiveEffects) do
            if effect.type == "stat" and player.passiveModifiers and player.passiveModifiers[effect.stat] then
                if effect.modifierType == "flat" then
                    player.passiveModifiers[effect.stat].flat = player.passiveModifiers[effect.stat].flat - effect.amount
                elseif effect.modifierType == "percent" then
                    player.passiveModifiers[effect.stat].percent = player.passiveModifiers[effect.stat].percent - effect.amount
                end
                
                -- Remover efectos específicos de las estadísticas del jugador
                if effect.stat == "max_health" and effect.modifierType == "flat" then
                    if player.stats and player.stats.health then
                        player.stats.health.maxHearts = math.max(1, player.stats.health.maxHearts - effect.amount)
                        player.stats.health.maxHealth = math.max(2, player.stats.health.maxHealth - (effect.amount * 2))
                        player.stats.health.currentHealth = math.min(player.stats.health.currentHealth, player.stats.health.maxHealth)
                        print("[PassiveManager] Removido de estadísticas: -" .. effect.amount .. " corazones")
                    end
                end
                
                print("[PassiveManager] Removido efecto de stat: " .. effect.stat .. " -" .. effect.amount .. " (" .. (effect.modifierType or "flat") .. ")")
            elseif effect.type == "resistance" and player.resistances then
                player.resistances[effect.damageType] = (player.resistances[effect.damageType] or 0) - effect.amount
                print("[PassiveManager] Removido efecto de resistencia: " .. effect.damageType .. " -" .. effect.amount)
            elseif effect.type == "ability" and player.abilities then
                player.abilities[effect.ability] = nil
                print("[PassiveManager] Removido efecto de habilidad: " .. effect.ability)
            end
        end
    end
    
    -- Limpiar el registro
    state.activeEffects[itemId] = nil
    state.stats.totalEffectsRemoved = state.stats.totalEffectsRemoved + 1
    print("[PassiveManager] Efecto removido: " .. (itemData.name or itemData.id or "unknown") .. " (ID: " .. itemId .. ")")
    return true
end

--[[
    Remueve todos los efectos activos de un jugador específico
    @param player: referencia al jugador
    @return: number cantidad de efectos removidos
--]]
function PassiveManager.removeAllPlayerEffects(player)
    local removedCount = 0
    local toRemove = {}
    
    -- Encontrar todos los efectos del jugador
    for itemId, effectData in pairs(state.activeEffects) do
        if effectData.player == player then
            table.insert(toRemove, itemId)
        end
    end
    
    -- Remover los efectos encontrados
    for _, itemId in ipairs(toRemove) do
        if PassiveManager.removePassiveEffect(itemId) then
            removedCount = removedCount + 1
        end
    end
    
    print("[PassiveManager] Removidos " .. removedCount .. " efectos del jugador")
    return removedCount
end

--[[
    Limpia efectos huérfanos (efectos cuyo jugador ya no existe)
    @return: number cantidad de efectos limpiados
--]]
function PassiveManager.cleanupOrphanedEffects()
    local cleanedCount = 0
    local toRemove = {}
    
    -- Encontrar efectos huérfanos
    for itemId, effectData in pairs(state.activeEffects) do
        -- Verificar si el jugador aún existe (verificación básica)
        if not effectData.player or type(effectData.player) ~= "table" then
            table.insert(toRemove, itemId)
        end
    end
    
    -- Limpiar efectos huérfanos
    for _, itemId in ipairs(toRemove) do
        state.activeEffects[itemId] = nil
        cleanedCount = cleanedCount + 1
    end
    
    if cleanedCount > 0 then
        state.stats.orphanedEffectsCleaned = state.stats.orphanedEffectsCleaned + cleanedCount
        print("[PassiveManager] Limpiados " .. cleanedCount .. " efectos huérfanos")
    end
    
    return cleanedCount
end

--[[
    Obtiene información sobre un efecto activo
    @param itemId: ID único del item
    @return: tabla con información del efecto o nil
--]]
function PassiveManager.getEffectInfo(itemId)
    local effectData = state.activeEffects[itemId]
    if not effectData then
        return nil
    end
    
    return {
        itemId = itemId,
        itemName = effectData.itemData.name or effectData.itemData.id or "unknown",
        appliedAt = effectData.appliedAt,
        duration = love.timer.getTime() - effectData.appliedAt,
        player = effectData.player,
        itemData = effectData.itemData
    }
end

--[[
    Obtiene lista de todos los efectos activos
    @return: tabla con información de todos los efectos
--]]
function PassiveManager.getAllActiveEffects()
    local effects = {}
    
    for itemId, _ in pairs(state.activeEffects) do
        local info = PassiveManager.getEffectInfo(itemId)
        if info then
            table.insert(effects, info)
        end
    end
    
    return effects
end

--[[
    Obtiene estadísticas del manager
    @return: tabla con estadísticas
--]]
function PassiveManager.getStats()
    return {
        activeEffectsCount = table.getn and table.getn(state.activeEffects) or #state.activeEffects,
        totalEffectsApplied = state.stats.totalEffectsApplied,
        totalEffectsRemoved = state.stats.totalEffectsRemoved,
        duplicationsBlocked = state.stats.duplicationsBlocked,
        orphanedEffectsCleaned = state.stats.orphanedEffectsCleaned,
        nextItemId = state.nextItemId
    }
end

--[[
    Verifica la integridad del sistema y reporta problemas
    @return: tabla con reporte de integridad
--]]
function PassiveManager.checkIntegrity()
    local report = {
        totalActiveEffects = 0,
        potentialOrphans = 0,
        validEffects = 0,
        issues = {}
    }
    
    for itemId, effectData in pairs(state.activeEffects) do
        report.totalActiveEffects = report.totalActiveEffects + 1
        
        -- Verificar integridad del efecto
        if not effectData.player or not effectData.itemData then
            report.potentialOrphans = report.potentialOrphans + 1
            table.insert(report.issues, "Efecto potencialmente huérfano: " .. itemId)
        else
            report.validEffects = report.validEffects + 1
        end
    end
    
    return report
end

--[[
    Reinicia completamente el manager (útil para debugging)
--]]
function PassiveManager.reset()
    state.activeEffects = {}
    state.nextItemId = 1
    state.stats = {
        totalEffectsApplied = 0,
        totalEffectsRemoved = 0,
        duplicationsBlocked = 0,
        orphanedEffectsCleaned = 0
    }
    
    -- Restaurar estadísticas del jugador a valores base
    if player and player.stats then
        -- Restaurar sistema de vida a valores base
        if player.stats.health then
            player.stats.health.maxHearts = 5      -- Valor base
            player.stats.health.maxHealth = 10     -- Valor base (5 corazones * 2)
            -- Ajustar vida actual si excede el nuevo máximo
            player.stats.health.currentHealth = math.min(player.stats.health.currentHealth, player.stats.health.maxHealth)
            -- Actualizar display de corazones
            if player.stats.updateHeartDisplay then
                player.stats:updateHeartDisplay()
            end
        end
        
        -- Limpiar modificadores pasivos
        if player.passiveModifiers then
            player.passiveModifiers = {}
        end
        
        -- Limpiar resistencias
        if player.resistances then
            player.resistances = {}
        end
        
        print("[PassiveManager] Estadísticas del jugador restauradas a valores base")
    end
    
    -- No resetear el flag initialized aquí
    print("[PassiveManager] Sistema reiniciado")
end

--[[
    Verifica si el manager está inicializado
--]]
function PassiveManager.isInitialized()
    return state.initialized
end

--[[
    Inicializa el manager
--]]
function PassiveManager.initialize()
    if state.initialized then
        print("[PassiveManager] Ya está inicializado, omitiendo re-inicialización")
        return
    end
    
    PassiveManager.reset()
    state.initialized = true
    print("[PassiveManager] Sistema de gestión de efectos pasivos inicializado")
end

-- Función de debug para obtener estadísticas
function PassiveManager.getDebugStats()
    local effectsByType = {}
    local effectsById = {}
    local totalCount = 0
    
    -- Contar manualmente para evitar problemas con table.getn
    for itemId, effectData in pairs(state.activeEffects) do
        totalCount = totalCount + 1
        local effectType = effectData.itemData.id or "unknown"
        effectsByType[effectType] = (effectsByType[effectType] or 0) + 1
        effectsById[itemId] = {
            type = effectType,
            name = effectData.itemData.name or "Unknown"
        }
    end
    
    return {
        totalActiveEffects = totalCount,
        effectsByType = effectsByType,
        effectsById = effectsById
    }
end

-- Función de debug para imprimir el estado actual
function PassiveManager.printDebugInfo()
    if not state.initialized then
        print("[PassiveManager DEBUG] ❌ Sistema no inicializado")
        return
    end
    
    print("=== PASSIVE MANAGER DEBUG ===")
    print("Estado del sistema:")
    print("  Inicializado: " .. tostring(state.initialized))
    print("  Próximo ID: " .. state.nextItemId)
    
    -- Debug directo de state.activeEffects
    local directCount = 0
    print("\nEfectos en state.activeEffects:")
    for itemId, effectData in pairs(state.activeEffects) do
        directCount = directCount + 1
        local itemName = effectData.itemData and effectData.itemData.name or "Unknown"
        print("  " .. itemId .. " -> " .. itemName)
    end
    print("Conteo directo: " .. directCount)
    
    local stats = PassiveManager.getDebugStats()
    print("Conteo por getDebugStats: " .. stats.totalActiveEffects)
    
    print("\nEstadísticas generales:")
    print("  Total aplicados: " .. state.stats.totalEffectsApplied)
    print("  Total removidos: " .. state.stats.totalEffectsRemoved)
    print("  Duplicaciones bloqueadas: " .. state.stats.duplicationsBlocked)
    
    if stats.totalActiveEffects > 0 then
        print("\nEfectos por tipo:")
        for effectType, count in pairs(stats.effectsByType) do
            print("  " .. effectType .. ": " .. count .. " instancia(s)")
            if count > 1 then
                print("  ⚠️  POSIBLE DUPLICACIÓN DETECTADA!")
            end
        end
        
        print("\nEfectos por ID:")
        for id, info in pairs(stats.effectsById) do
            print("  " .. id .. " -> " .. info.name .. " (" .. info.type .. ")")
        end
        
        -- Mostrar estadísticas del jugador si hay efectos activos
        local firstEffect = next(state.activeEffects)
        if firstEffect and state.activeEffects[firstEffect].player then
            local player = state.activeEffects[firstEffect].player
            print("\n[PassiveManager DEBUG] Estadísticas del Jugador:")
            if player.passiveModifiers then
                print("  Modificadores pasivos:")
                for stat, mods in pairs(player.passiveModifiers) do
                    print("    " .. stat .. ": flat=" .. (mods.flat or 0) .. ", percent=" .. (mods.percent or 0))
                end
            else
                print("  Sin modificadores pasivos")
            end
            
            if player.resistances then
                print("  Resistencias:")
                for damageType, value in pairs(player.resistances) do
                    print("    " .. damageType .. ": " .. value)
                end
            end
            
            if player.abilities then
                print("  Habilidades:")
                for ability, value in pairs(player.abilities) do
                    print("    " .. ability .. ": " .. tostring(value))
                end
            end
        end
    else
        print("\n❌ No hay efectos activos")
    end
    print("=== FIN DEBUG ===")
end

return PassiveManager