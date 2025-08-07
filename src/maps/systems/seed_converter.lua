-- src/maps/systems/seed_converter.lua
-- Sistema de conversión de semillas alfanuméricas

local SeedConverter = {}

-- Convertir semilla alfanumérica a numérica
function SeedConverter.toNumeric(alphaSeed)
    if type(alphaSeed) == "number" then
        return alphaSeed
    end
    
    local numericValue = 0
    local seedStr = tostring(alphaSeed):upper()
    
    for i = 1, #seedStr do
        local char = seedStr:sub(i, i)
        local charValue = 0
        
        if char:match("%d") then
            charValue = tonumber(char)
        else
            charValue = string.byte(char) - string.byte('A') + 10
        end
        
        -- Usar multiplicador primo para mejor distribución
        numericValue = numericValue + charValue * (37 ^ (i - 1))
    end
    
    -- Asegurar valor positivo y dentro de rango
    return math.abs(numericValue) % 2147483647
end

-- Validar si es semilla alfanumérica
function SeedConverter.isAlphanumeric(seed)
    if type(seed) ~= "string" then
        return false
    end
    
    if #seed ~= 10 then
        return false
    end
    
    local letterCount = 0
    local digitCount = 0
    
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
end

return SeedConverter