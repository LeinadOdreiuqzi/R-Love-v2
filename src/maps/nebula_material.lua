local Biomes = require 'src.maps.biome_system'
local Config = require 'src.maps.config.map_config'
local Color = require 'src.utils.color_harmony'
local Seeds = require 'src.utils.seed_system'

local Material = {}
local chunk = Config.chunk
local stride = (chunk.size * chunk.tileSize + chunk.spacing) * chunk.worldScale
local harmonyOffset = {complementary = .5, splitComplementary = .42, triadic = 1/3, analogous = .10}

Material.harmonies = {
    { id = nil, name = "Aleatoria / Perfil" },
    { id = "cosmic", name = "Cosmic (Emisión Estelar)" },
    { id = "complementary", name = "Complementary (Alto Contraste)" },
    { id = "splitComplementary", name = "Split-Complementary (Equilibrado)" },
    { id = "triadic", name = "Triadic (Tríada Energética)" },
    { id = "analogous", name = "Analogous (Transición Suave)" }
}

Material.hues = {
    { val = nil,    name = "Libre 360° (Todo el espectro)" },
    { val = 0.00,   name = "Rojo / Carmesí (0°)" },
    { val = 0.10,   name = "Dorado / Ámbar (36°)" },
    { val = 0.25,   name = "Lima Eléctrico (90°)" },
    { val = 0.38,   name = "Esmeralda Puro (137°)" },
    { val = 0.50,   name = "Cian / Turquesa (180°)" },
    { val = 0.62,   name = "Azul Cobalto (223°)" },
    { val = 0.77,   name = "Violeta / Amatista (277°)" },
    { val = 0.90,   name = "Magenta / Fucsia (324°)" }
}

Material.colorModes = {
    { id = nil, name = "Mixto (50% A / 50% B)" },
    { id = "A", name = "Forma A (Mono-Tonal Puro)" },
    { id = "B", name = "Forma B (Bi-Tonal Dual-Tone)" }
}

-- El velo prolonga el recorrido desde el frente iluminado hacia el gas difuso.
-- El giro se reduce si los matices son opuestos o alguna banda es casi gris.
function Material.outerColor(region, out)
    if region.outerGas then return region.outerGas end
    local gas, front = region.gas, region.front
    local gasHue, gasSat, gasValue = Color.rgb2hsv(gas[1], gas[2], gas[3])
    local frontHue, frontSat = Color.rgb2hsv(front[1], front[2], front[3])
    local turn = math.sin((gasHue-frontHue)*2*math.pi) * math.min(gasSat, frontSat)
    local hue = (gasHue + .08*turn) % 1
    local r,g,b = Color.hsv2rgb(hue, gasSat, 1)
    -- En RGB lineal, el verde y el amarillo necesitan menos energía para verse igual de tenues.
    local luminance = .2126*r + .7152*g + .0722*b
    local value = gasValue * math.min(.86, .18/luminance)
    out[1], out[2], out[3] = r*value, g*value, b*value
    return out
end

-- RGB lineal de las dos emisiones. El cuarto componente modula el polvo o el frente.
function Material.createRegion(seed, x, y, span, fixedHue, harmony, mode)
    local rng = Seeds.makeRNG(seed)
    local warm = rng:randomRange(-.065, .085)
    local cool = rng:randomRange(.46, .645)
    local gasHue, frontHue = warm, cool
    if rng:random() < .38 then gasHue, frontHue = cool, warm end
    local offset = (frontHue - gasHue + .5) % 1 - .5
    if harmonyOffset[harmony] then
        offset = (offset < 0 and -1 or 1) * harmonyOffset[harmony]
    end
    gasHue = fixedHue or gasHue
    local gas = {Color.hsv2rgb(gasHue % 1, rng:randomRange(.88,.96), 1)}
    local front = {Color.hsv2rgb((gasHue + offset) % 1, rng:randomRange(.89,.97), .96)}
    gas[4] = rng:randomRange(.80,1.30)
    front[4] = rng:randomRange(.85,1.22)
    if mode == "A" then front[4] = .65 elseif mode == "B" then front[4] = 1.55 end
    return {
        gas = gas, front = front,
        lightX = x + span * rng:randomRange(-.19,.19),
        lightY = y + span * rng:randomRange(-.19,.19),
        reach = span * rng:randomRange(.24,.34)
    }
end

function Material.forNode(node)
    if not node.nebulaMaterial then
        local seed = Biomes.hashChunk(math.floor(node.x), math.floor(node.y))
        -- La selección regional tiene su propia secuencia para conservar la luz y la distribución del mapa.
        local palette = love.math.newRandomGenerator(seed, 73157)
        local hue = Material.hues[palette:random(#Material.hues)].val
        local harmony = Material.harmonies[palette:random(2, #Material.harmonies)].id
        local mode = Material.colorModes[palette:random(#Material.colorModes)].id
        node.nebulaMaterial = Material.createRegion(seed, node.x * stride, node.y * stride, stride, hue, harmony, mode)
    end
    return node.nebulaMaterial
end

-- También resuelve nubes de partidas anteriores que sólo tienen posición y semilla.
function Material.atWorld(x, y)
    return Material.forNode(Biomes.sampleBiomeBlend(x / stride, y / stride, true).nebulaRegion)
end

-- La semilla elige una proporción reproducible para cada nube.
-- Un campo continuo limita el acento de las nubes vecinas incluso entre chunks.
function Material.cloudBalance(region, x, y, cloud)
    local seed = cloud.seed or 0
    local roll = (seed * .754877666 + .31) % 1
    local scale = math.max(1, region.reach)
    local area = love.math.noise(x/scale, y/scale)
    local accent = math.max(0, math.min(1, (area-.24)/.42))
    return -.78 + roll^1.5*(.60+1.04*accent)
end

-- Lleva la fuente del mundo al espacio de la nube, incluyendo su giro y excentricidad.
function Material.projectLight(region, x, y, size, aspect, rotation, out)
    local dx, dy = region.lightX - x, region.lightY - y
    local c, s = math.cos(rotation), math.sin(rotation)
    local rx, ry = size * aspect, size / aspect
    out[1], out[2] = (c * dx + s * dy) / rx, (c * dy - s * dx) / ry
    out[3], out[4] = rx / region.reach, ry / region.reach
end

return Material
