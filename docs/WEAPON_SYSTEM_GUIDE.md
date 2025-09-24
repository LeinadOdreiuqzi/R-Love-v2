# Sistema de Armas - Guía Completa

## Descripción General

El sistema de armas implementado está inspirado en "Enter the Gungeon" y permite al jugador equipar hasta 4 armas simultáneamente, cambiar entre ellas rápidamente usando teclas numéricas o la rueda del mouse, y gestionar munición y recarga automáticamente.

## Características Principales

### 🔫 Cambio Rápido de Armas
- **Teclas 1-4**: Cambio directo a slot específico
- **Rueda del mouse**: Cambio secuencial entre armas
- **Animaciones visuales**: Efectos de cambio en el HUD

### 🎯 Sistema de Munición
- Munición limitada por arma (configurable)
- Recarga automática con barra de progreso
- Diferentes tipos de proyectiles por arma

### 📊 HUD Integrado
- Visualización de 4 slots de armas
- Información de munición actual
- Indicador de arma activa
- Barra de recarga en tiempo real

### ⚡ Integración Completa
- Compatible con sistema de inventario existente
- Integrado con sistema de disparos actual
- Soporte para diferentes tipos de proyectiles

## Archivos del Sistema

### Archivos Principales
- `src/entities/weapon_system.lua` - Lógica principal del sistema
- `src/ui/weapon_hud.lua` - Interfaz visual del sistema
- `src/utils/weapon_system_demo.lua` - Script de demostración

### Archivos Modificados
- `src/entities/naves.lua` - Integración con el jugador
- `src/ui/hud.lua` - Integración con HUD principal
- `src/item_systems/item_system.lua` - Método createItem agregado
- `src/item_systems/items/equipables.lua` - Nuevas armas agregadas

## Uso del Sistema

### Inicialización Automática
El sistema se inicializa automáticamente cuando se crea una nave:

```lua
-- En naves.lua, se crea automáticamente
player.weaponSystem = WeaponSystem:new(player)
```

### Equipar Armas
```lua
-- Equipar arma en slot específico
local weapon = ItemSystem:createItem("basic_laser_pistol")
player:equipWeapon(weapon, 1)  -- Slot 1

-- Auto-equipar desde inventario
player:autoEquipWeaponsFromInventory()
```

### Cambio de Armas
```lua
-- Cambiar a slot específico
player:switchToWeaponSlot(2)

-- El sistema también responde a:
-- - Teclas 1-4 automáticamente
-- - Rueda del mouse (wheelmoved)
```

### Disparar
```lua
-- El método shoot() existente ahora usa el sistema de armas
player:shoot(mouseX, mouseY)
```

## Controles

| Control | Acción |
|---------|--------|
| **1-4** | Cambiar a arma en slot específico |
| **Rueda ↑** | Siguiente arma disponible |
| **Rueda ↓** | Arma anterior disponible |
| **Click Izq** | Disparar arma actual |
| **R** | Recargar (si implementado) |

## Configuración

### Configuración del Sistema
En `weapon_system.lua`:

```lua
local WEAPON_CONFIG = {
    MAX_WEAPON_SLOTS = 4,  -- Máximo 4 armas
    QUICK_SWITCH_KEYS = {"1", "2", "3", "4"},
    SCROLL_SWITCH = true,  -- Cambio con rueda
    AUTO_RELOAD = true,    -- Recarga automática
    SHOW_WEAPON_HUD = true -- Mostrar HUD
}
```

### Configuración del HUD
En `weapon_hud.lua`:

```lua
local HUD_CONFIG = {
    position = { x = 50, y = 50 },  -- Posición en pantalla
    slotSize = 60,                  -- Tamaño de slots
    slotSpacing = 70,               -- Espaciado entre slots
    maxSlots = 4                    -- Slots a mostrar
}
```

## Armas Disponibles

### Armas Básicas
- **Pistola Láser Básica**: Arma estándar, daño medio
- **Cuchillo de Combate**: Arma cuerpo a cuerpo, sin munición

### Armas Avanzadas
- **Rifle de Asalto Cinético**: Alta cadencia, munición limitada
- **Rifle de Plasma**: Alto daño, consumo de energía
- **Cañón de Plasma Pesado**: Daño devastador, recarga lenta
- **Escopeta de Energía**: Múltiples proyectiles, corto alcance

## Agregar Nuevas Armas

### 1. Definir el Arma
En `equipables.lua`:

```lua
ItemSystem:registerItem({
    id = "mi_nueva_arma",
    name = "Mi Nueva Arma",
    description = "Descripción del arma",
    category = ItemSystem.CATEGORIES.EQUIPABLE,
    equipType = ItemSystem.EQUIPABLE_TYPES.WEAPON,
    slot = Equipables.SLOTS.WEAPON_PRIMARY,
    
    -- Estadísticas
    damage = { min = 20, max = 30 },
    fireRate = 2.0,
    maxAmmo = 15,
    reloadTime = 2.0,
    
    -- Funciones de equipar/desequipar
    onEquip = function(self, player) ... end,
    onUnequip = function(self, player) ... end
})
```

### 2. Crear Tipo de Proyectil (Opcional)
Si necesitas un proyectil específico, crea un archivo en `src/physics/projectiles/types/`.

### 3. Registrar en Sistema
```lua
-- El arma se registra automáticamente al llamar
Equipables.registerAll()
```

## Demostración

Para probar el sistema completo:

```lua
local WeaponSystemDemo = require 'src.utils.weapon_system_demo'

-- Ejecutar demostración completa
WeaponSystemDemo.runFullDemo(player)

-- O funciones específicas:
WeaponSystemDemo.equipDemoWeapons(player)
WeaponSystemDemo.showWeaponInfo(player)
WeaponSystemDemo.showControls()
```

## API del Sistema

### WeaponSystem

#### Métodos Principales
- `equipWeapon(weaponItem, slot)` - Equipar arma en slot
- `unequipWeapon(slot)` - Desequipar arma
- `switchToSlot(slot)` - Cambiar a slot específico
- `shoot(mouseX, mouseY)` - Disparar arma actual
- `reload()` - Recargar arma actual

#### Métodos de Información
- `getCurrentWeaponInfo()` - Info del arma actual
- `getEquippedWeapons()` - Lista de armas equipadas
- `canShoot()` - Verificar si puede disparar

### WeaponHUD

#### Métodos de Control
- `setVisible(visible)` - Mostrar/ocultar HUD
- `setPosition(x, y)` - Cambiar posición
- `onWeaponSwitch(slot)` - Notificar cambio de arma

## Integración con Sistemas Existentes

### Sistema de Inventario
- Las armas se almacenan en el inventario como items equipables
- Se pueden equipar/desequipar desde el inventario
- Compatible con sistema de rareza y valores

### Sistema de Disparos
- Usa el método `shoot()` existente como base
- Agrega verificaciones de munición y cadencia
- Compatible con sistema de proyectiles actual

### Sistema de Física
- Integrado con PhysicsManager existente
- Usa proyectiles del sistema actual
- Compatible con colisiones y efectos

## Solución de Problemas

### Problemas Comunes

1. **Armas no aparecen en HUD**
   - Verificar que WeaponHUD esté inicializado
   - Comprobar que las armas estén equipadas correctamente

2. **No se puede disparar**
   - Verificar munición disponible
   - Comprobar que no esté recargando
   - Verificar cadencia de disparo

3. **Cambio de armas no funciona**
   - Verificar que las teclas estén configuradas
   - Comprobar que haya armas en los slots

### Debug
```lua
-- Mostrar información del sistema
WeaponSystemDemo.showWeaponInfo(player)

-- Verificar armas equipadas
local weapons = player:getEquippedWeapons()
for slot, weapon in pairs(weapons) do
    print("Slot " .. slot .. ": " .. weapon.weapon.name)
end
```

## Futuras Mejoras

### Características Planeadas
- [ ] Modificadores de armas (attachments)
- [ ] Sistema de experiencia por arma
- [ ] Armas únicas con habilidades especiales
- [ ] Efectos de sonido por arma
- [ ] Animaciones de recarga más detalladas

### Optimizaciones
- [ ] Pool de proyectiles para mejor rendimiento
- [ ] Cache de información de armas
- [ ] Reducir llamadas de renderizado en HUD

---

**Nota**: Este sistema está completamente integrado con tu proyecto existente y mantiene compatibilidad con todos los sistemas actuales.