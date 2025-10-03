-- Core del HUD: estado compartido, presets y utilidades
HUD = HUD or {}

-- Referencias de sistemas usados por el HUD (globales para módulos)
ChunkManager = require('src.maps.chunk_manager')
WeaponHUD = require('src.ui.weapon_hud')

-- Estado del HUD unificado con optimizaciones
hudState = {
  showInfo = true,
  showSeedInput = false,
  showBiomeInfo = true,
  showDebugMenu = false,
  phaseVisualsEnabled = true,
  seedInputText = "",
  font = nil,
  smallFont = nil,
  tinyFont = nil,

  renderCache = {
    lastUpdate = 0,
    updateInterval = 0.1,
    cachedStats = nil,
    cachedBiomeInfo = nil,
    dirtyFlags = { stats = true, biome = true, player = true }
  },

  stringPool = {},

  performance = {
    enableCaching = true,
    maxStringPoolSize = 50,
    reducedUpdateMode = false
  },

  stationHint = {
    enabled = true,
    show = false,
    placeholder = nil,
    distance = math.huge,
    enterRadiusFactor = 1.25,
    scanInterval = 0.25,
    lastScan = 0,
    scanMargin = 1,
    screenX = 0,
    screenY = 0
  }
}

-- Permitir activar/desactivar visuales de fases (para subniveles)
function HUD.setPhaseVisualsEnabled(enabled)
  hudState.phaseVisualsEnabled = not not enabled
end

-- Sistema de semillas alfanuméricas integrado (idéntico al original)
SeedSystem = {
  letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
  digits = "0123456789",

  generate = function()
    local chars = {}
    local letters = SeedSystem.letters
    local digits = SeedSystem.digits
    for i = 1, 5 do
      local randomIndex = math.random(1, #letters)
      table.insert(chars, letters:sub(randomIndex, randomIndex))
    end
    for i = 1, 5 do
      local randomIndex = math.random(1, #digits)
      table.insert(chars, digits:sub(randomIndex, randomIndex))
    end
    for i = #chars, 2, -1 do
      local j = math.random(i)
      chars[i], chars[j] = chars[j], chars[i]
    end
    return table.concat(chars)
  end,

  validate = function(seed)
    if type(seed) ~= "string" then return false end
    if #seed ~= 10 then return false end
    local letterCount, digitCount = 0, 0
    for i = 1, #seed do
      local char = seed:sub(i, i):upper()
      if char:match("[A-Z]") then
        letterCount = letterCount + 1
      elseif char:match("[0-9]") then
        digitCount = digitCount + 1
      else
        return false
      end
    end
    return letterCount == 5 and digitCount == 5
  end,

  normalize = function(input)
    if not input or input == "" then return SeedSystem.generate() end
    local normalized = tostring(input):upper()
    if SeedSystem.validate(normalized) then return normalized end
    if #normalized < 10 then
      local remaining = 10 - #normalized
      for i = 1, remaining do
        if math.random() < 0.5 then
          normalized = normalized .. SeedSystem.letters:sub(math.random(1, 26), math.random(1, 26))
        else
          normalized = normalized .. SeedSystem.digits:sub(math.random(1, 10), math.random(1, 10))
        end
      end
    elseif #normalized > 10 then
      normalized = normalized:sub(1, 10)
    end
    local cleanSeed = ""
    for i = 1, #normalized do
      local char = normalized:sub(i, i)
      if char:match("[A-Z0-9]") then
        cleanSeed = cleanSeed .. char
      else
        if math.random() < 0.5 then
          cleanSeed = cleanSeed .. SeedSystem.letters:sub(math.random(1, 26), math.random(1, 26))
        else
          cleanSeed = cleanSeed .. SeedSystem.digits:sub(math.random(1, 10), math.random(1, 10))
        end
      end
    end
    local letterCount, digitCount = 0, 0
    for i = 1, #cleanSeed do
      local char = cleanSeed:sub(i, i)
      if char:match("[A-Z]") then letterCount = letterCount + 1 else digitCount = digitCount + 1 end
    end
    if math.abs(letterCount - digitCount) > 2 then
      return SeedSystem.generate()
    end
    return cleanSeed
  end
}

presetSeeds = {
  {name = "Random", seed = SeedSystem.generate()},
  {name = "Dense Nebula", seed = "A5N9E3B7U1"},
  {name = "Open Void", seed = "S2P4A6C8E0"},
  {name = "Asteroid Fields", seed = "R3O7C9K2S6"},
  {name = "Ancient Mysteries", seed = "M1Y8S4T6I3"},
  {name = "Radiation Storm", seed = "H2A5Z9R3D7"},
  {name = "Crystal Caverns", seed = "C4R8Y1S5T9"},
  {name = "Quantum Rifts", seed = "Q3U6A7N2T4"},
  {name = "Lost Worlds", seed = "L6O1S4T9W3"},
  {name = "Deep Explorer", seed = "E2X8P5L7O9"}
}

currentPresetIndex = 1

-- Referencias a estado de juego (se actualizan dinámicamente)
gameState = nil
player = nil
Map = nil
gameDirector = nil
runState = nil
BiomeSystem = nil

-- Cache de información de bioma del jugador
biomeCache = {
  lastUpdate = 0,
  updateInterval = 0.5,
  currentBiome = nil,
  currentBiomeInfo = nil,
  biomeHistory = {},
  maxHistory = 10,
  debugInfo = nil,
  lastError = nil,
  lastSuccessfulUpdate = 0
}

return HUD