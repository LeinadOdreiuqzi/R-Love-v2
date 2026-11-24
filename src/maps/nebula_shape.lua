local Shape = {FAN = 4}
local cache = setmetatable({}, {__mode = "k"})

local function seeded(seed, salt)
    local whole = math.floor(seed)
    return love.math.newRandomGenerator(whole % 4294967296, salt + math.floor((seed-whole)*16777216))
end

-- El tipo clásico se conserva también en partidas anteriores. La elección
-- visual usa otra secuencia para no desplazar los objetos del chunk.
function Shape.visualMorphology(seed, morph)
    morph = morph or 0
    if morph ~= 0 and morph ~= 2 then return morph end
    local chance = morph == 0 and .51 or .34
    return seeded(seed or 0, 195907):random() < chance and Shape.FAN or morph
end

-- La referencia fija y sus variantes se construyen en el mismo sistema local.
-- La raíz, el ala y el nudo se reflejan y giran juntos con el frente de polvo.
local function makeFan(rng)
    local function vary(center, spread)
        if not rng then return center end
        return center + (2*rng:random()-1)*spread
    end
    local angle = vary(0,math.pi)
    local c,s = math.cos(angle),math.sin(angle)
    local hand = rng and rng:random() < .5 and -1 or 1
    local function orient(x,y)
        return c*hand*x-s*y, s*hand*x+c*y
    end

    local rx,ry = vary(-.08,.15),vary(.27,.16)
    local x,y = orient(rx,ry)
    local dx,dy = orient(.045,-.999)
    local turn = vary(0,.47)
    local ct,st = math.cos(turn),math.sin(turn)
    local bx,by = orient(.52*ct-.854*st,.52*st+.854*ct)
    local kx,ky = orient(rx-vary(.35,.12),ry+vary(.17,.11))
    local shape = {
        {x,y,dx,dy},
        {vary(.94,.17),vary(.51,.15),hand*vary(-.035,.27),vary(.58,.21)},
        {bx,by,vary(.77,.15),vary(.20,.08)},
        {hand*vary(-1.05,.36),vary(.86,.13),vary(1.75,.51),vary(.12,.07)},
        {kx,ky,vary(.135,.045),rng and vary(.68,.29) or .06},
        {rng and vary(.19,.048) or .22,rng and (2.8+4.8*rng:random()^1.4) or 8.8,
            vary(.145,.06),vary(.84,.13)}
    }
    if rng then
        local lx,ly = orient(rx+vary(0,.035),ry+vary(0,.028))
        shape.source = {lx,ly,vary(1.10,.20)}
    end
    return shape
end

Shape.orionFan = makeFan()

-- Dos corrientes comparten una raíz. Su longitud útil termina dentro del radio
-- que ya utiliza el mapa para colocar y descartar la nube.
local function room(x, y, dx, dy)
    local along = x*dx + y*dy
    return math.sqrt(.90^2 - x*x - y*y + along*along) - along
end

function Shape.forCloud(cloud)
    if cloud.structure then return cloud.structure end
    local seed, morph = cloud.seed or 0, cloud.morphology or 0
    local entry = cache[cloud]
    if entry and entry.seed == seed and entry.morph == morph and entry.visual == cloud.visualMorphology then
        return entry
    end

    local rng = seeded(seed, 71357)
    if (cloud.visualMorphology or Shape.visualMorphology(seed,morph)) == Shape.FAN then
        entry = makeFan(rng)
        entry.seed,entry.morph,entry.visual = seed,morph,cloud.visualMorphology
        cache[cloud] = entry
        return entry
    end
    local function range(lo, hi) return lo + (hi-lo)*rng:random() end
    local angle = range(0, 2*math.pi)
    local dx, dy = math.cos(angle), math.sin(angle)
    local back, across = range(-.15,.46), range(-.19,.19)
    local x, y = -back*dx-across*dy, -back*dy+across*dx
    local spread = morph == 2 and range(2.35,3.65) or range(.66,5.60)
    local bx, by = math.cos(angle+spread), math.sin(angle+spread)
    local length = room(x,y,dx,dy)*range(.88,1.09)
    local wing = room(x,y,bx,by)*range(.65,1.07)
    local width = morph == 3 and range(.13,.34) or range(.26,.72)
    local cavity = morph == 1 and range(.73,.96) or range(.02,.81)
    local wingWeight = morph == 2 and range(.70,1.0) or range(.24,.96)
    local side = rng:random() < .5 and -1 or 1
    local separation, advance = range(.19,.40)*side, range(-.16,.20)
    local knotX, knotY = x-separation*dy+advance*dx, y+separation*dx+advance*dy
    -- Disposición de los seis vec4 de u_structure, en coordenadas de la nube.
    entry = {
        {x, y, dx, dy},                                              -- raíz y dirección principal
        {length, width, range(-.52,.52), cavity},                    -- longitud, ancho, curva, hueco
        {bx, by, wing, range(.14,.57)},                              -- dirección, longitud y ancho del ala
        {range(-.56,.56), wingWeight, range(.07,.96), range(.10,.62)}, -- curva, masa, polvo frontal, albedo neutro
        {knotX, knotY, range(.12,.28), .86*rng:random()^2},           -- posición, radio y masa del nudo
        {range(.09,.21), .12+2.2*rng:random()^3, range(.10,.27), range(.32,.93)}, -- radio y potencia de la fuente, pliegue, apertura
        seed = seed, morph = morph, visual = cloud.visualMorphology
    }
    cache[cloud] = entry
    return entry
end

return Shape
