-- src/utils/seed_system.lua

local SeedSystem = {}

-- Caracteres permitidos
SeedSystem.letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
SeedSystem.digits = "0123456789"

-- Generar semilla alfanumérica (5 letras + 5 dígitos mezclados)
function SeedSystem.generate()
    local chars = {}
    
    -- Agregar 5 letras aleatorias
    for i = 1, 5 do
        local randomIndex = math.random(1, #SeedSystem.letters)
        table.insert(chars, SeedSystem.letters:sub(randomIndex, randomIndex))
    end
    
    -- Agregar 5 dígitos aleatorios
    for i = 1, 5 do
        local randomIndex = math.random(1, #SeedSystem.digits)
        table.insert(chars, SeedSystem.digits:sub(randomIndex, randomIndex))
    end
    
    -- Mezclar los caracteres
    for i = #chars, 2, -1 do
        local j = math.random(i)
        chars[i], chars[j] = chars[j], chars[i]
    end
    
    return table.concat(chars)
end

-- Validar formato de semilla (10 caracteres alfanuméricos)
function SeedSystem.validate(seed)
    if type(seed) ~= "string" or #seed ~= 10 then
        return false
    end
    
    -- Verificar que todos los caracteres sean alfanuméricos
    if not seed:match("^[A-Z0-9]+$") then
        return false
    end
    
    -- Verificar que haya al menos una letra y un dígito
    if not seed:match("%a") or not seed:match("%d") then
        return false
    end
    
    return true
end

-- Convertir semilla a número para usar con math.randomseed
function SeedSystem.toNumber(seed)
    -- Si ya es un número, devolverlo directamente
    if type(seed) == "number" then
        return math.floor(seed) % (2^31)
    end
    
    -- Si no es un string o está vacío, generar una semilla aleatoria
    if type(seed) ~= "string" or #seed == 0 then
        seed = SeedSystem.generate()
    end
    
    -- Asegurarse de que la semilla sea válida
    if not SeedSystem.validate(seed) then
        -- Si no es válida, generar un hash numérico a partir de la cadena
        local hash = 0
        for i = 1, #seed do
            hash = (hash * 31 + string.byte(seed, i)) % (2^31)
        end
        return hash
    end
    
    -- Convertir la semilla a un número
    local num = 0
    for i = 1, #seed do
        local c = seed:sub(i, i)
        num = (num * 31 + string.byte(c)) % (2^31)
    end
    
    return num
end

-- Alias para compatibilidad con el código existente
SeedSystem.toNumeric = SeedSystem.toNumber

return SeedSystem
