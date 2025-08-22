-- src/perlin_noise.lua

local PerlinNoise = {}

local SeedSystem = require 'src.utils.seed_system'

-- Tabla de permutación para el ruido de Perlin
local p = {}
local basePermutation = {
    151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225,
    140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148,
    247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32,
    57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175,
    74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122,
    60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54,
    65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169,
    200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64,
    52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212,
    207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213,
    119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9,
    129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104,
    218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241,
    81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157,
    184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93,
    222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180
}

-- Inicializa la tabla de permutación con una semilla
function PerlinNoise.init(seed)
    -- Usar RNG local determinista para no contaminar math.random global
    local rng = SeedSystem.makeRNG(seed or 0)

    -- Clonar permutación base para evitar barajar sobre estado anterior
    local perm = {}
    for i = 1, 256 do
        perm[i] = basePermutation[i]
    end

    -- Mezclar la tabla clonada con RNG local (idéntico estilo de barajado previo)
    for i = 1, 256 do
        local j = rng:randomInt(1, 256)
        perm[i], perm[j] = perm[j], perm[i]
    end
    
    -- Duplicar la tabla para evitar desbordamientos
    for i = 1, 256 do
        p[i] = perm[i]
        p[i + 256] = perm[i]
    end
end

-- Función de interpolación suave
local function fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

-- Función de interpolación lineal
local function lerp(t, a, b)
    return a + t * (b - a)
end

-- Función de gradiente
local function grad(hash, x, y, z)
    local h = hash % 16
    local u = h < 8 and x or y
    local v = h < 4 and y or (h == 12 or h == 14) and x or z
    return ((h % 2) == 0 and u or -u) + ((h % 4) < 2 and v or -v)
end

-- Función principal de ruido de Perlin
function PerlinNoise.noise(x, y, z)
    z = z or 0
    
    -- Encontrar las coordenadas de la unidad del cubo que contiene el punto
    local X = math.floor(x) % 256
    local Y = math.floor(y) % 256
    local Z = math.floor(z) % 256
    
    -- Encontrar las posiciones relativas del punto en el cubo
    x = x - math.floor(x)
    y = y - math.floor(y)
    z = z - math.floor(z)
    
    -- Calcular las curvas de desvanecimiento para cada coordenada
    local u = fade(x)
    local v = fade(y)
    local w = fade(z)
    
    -- Hash de las coordenadas de las 8 esquinas del cubo
    local A = p[X + 1] + Y
    local AA = p[A + 1] + Z
    local AB = p[A + 2] + Z
    local B = p[X + 2] + Y
    local BA = p[B + 1] + Z
    local BB = p[B + 2] + Z
    
    -- Agregar los resultados mezclados de las 8 esquinas del cubo
    return lerp(w, lerp(v, lerp(u, grad(p[AA + 1], x, y, z),
                                   grad(p[BA + 1], x - 1, y, z)),
                           lerp(u, grad(p[AB + 1], x, y - 1, z),
                                   grad(p[BB + 1], x - 1, y - 1, z))),
                   lerp(v, lerp(u, grad(p[AA + 2], x, y, z - 1),
                                   grad(p[BA + 2], x - 1, y, z - 1)),
                           lerp(u, grad(p[AB + 2], x, y - 1, z - 1),
                                   grad(p[BB + 2], x - 1, y - 1, z - 1))))
end

return PerlinNoise

