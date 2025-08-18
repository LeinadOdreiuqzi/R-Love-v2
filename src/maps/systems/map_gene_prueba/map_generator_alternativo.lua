-- src/maps/systems/map_generator.lua
-- Sistema de generación de contenido del mapa
-- Asteroid Belt: Voronoi-like network (mejorada para navegación y forma orgánica)

local MapGenerator = {}
local PerlinNoise = require 'src.maps.perlin_noise'
local BiomeSystem = require 'src.maps.biome_system'
local MapConfig = require 'src.maps.config.map_config'

-- Función de ruido multi-octava
function MapGenerator.multiOctaveNoise(x, y, octaves, persistence, scale)
    local value = 0
    local amplitude = 1
    local frequency = scale
    local maxValue = 0
    for i = 1, octaves do
        value = value + PerlinNoise.noise(x * frequency, y * frequency) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
    end
    return value / maxValue
end

-- ===========================
-- Helpers (para el generador de red Voronoi-like)
-- ===========================
local function makeLCG(seed)
    local s = (seed % 2147483647)
    if s <= 0 then s = s + 2147483646 end
    return function()
        s = (s * 16807) % 2147483647
        return (s - 1) / 2147483646
    end
end

local function pointSegmentDistSq(px, py, x1, y1, x2, y2)
    local vx, vy = x2 - x1, y2 - y1
    local wx, wy = px - x1, py - y1
    local c = vx*wx + vy*wy
    if c <= 0 then
        local dx, dy = px - x1, py - y1
        return dx*dx + dy*dy
    end
    local d2 = vx*vx + vy*vy
    if c >= d2 then
        local dx, dy = px - x2, py - y2
        return dx*dx + dy*dy
    end
    local t = c / d2
    local projx, projy = x1 + vx * t, y1 + vy * t
    local dx, dy = px - projx, py - projy
    return dx*dx + dy*dy
end

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function lerp(a,b,t) return a + (b-a)*t end
local function dist(x1,y1,x2,y2)
    local dx = x1-x2; local dy = y1-y2; return math.sqrt(dx*dx + dy*dy)
end

-- Carved corridor helper (dibuja un corredor entre dos puntos sobre tiles mundiales)
-- Recorta sólo dentro del chunk actual.
-- mode = "clear" -> pone EMPTY
-- mode = "thin"  -> reduce a ASTEROID_SMALL
local function carveCorridor(chunk, chunkX, chunkY, p1x, p1y, p2x, p2y, radius, mode, perlinScale)
    local size = MapConfig.chunk.size
    local worldX0 = chunkX * size
    local worldY0 = chunkY * size
    local wx1, wy1 = p1x, p1y
    local wx2, wy2 = p2x, p2y

    local L = math.max(1, math.floor(dist(wx1,wy1,wx2,wy2)))
    for i = 0, L do
        local t = i / math.max(1, L)
        local cx = lerp(wx1, wx2, t)
        local cy = lerp(wy1, wy2, t)
        local jitter = (PerlinNoise.noise((cx+13.1)*perlinScale, (cy+7.3)*perlinScale, 911) + 1)*0.5 - 0.5
        local r = math.max(0.8, radius * (1 + jitter * 0.45))
        local minx = math.floor(cx - r)
        local maxx = math.ceil(cx + r)
        local miny = math.floor(cy - r)
        local maxy = math.ceil(cy + r)
        for wy = miny, maxy do
            for wx = minx, maxx do
                if wx >= worldX0 and wx <= worldX0 + size - 1 and wy >= worldY0 and wy <= worldY0 + size - 1 then
                    local tx = wx - worldX0
                    local ty = wy - worldY0
                    local d2 = (wx - cx)*(wx - cx) + (wy - cy)*(wy - cy)
                    if d2 <= r*r then
                        if mode == "clear" then
                            chunk.tiles[ty][tx] = MapConfig.ObjectType.EMPTY
                        elseif mode == "thin" then
                            local cur = chunk.tiles[ty][tx]
                            if cur == MapConfig.ObjectType.ASTEROID_LARGE then
                                chunk.tiles[ty][tx] = MapConfig.ObjectType.ASTEROID_MEDIUM
                            elseif cur == MapConfig.ObjectType.ASTEROID_MEDIUM then
                                chunk.tiles[ty][tx] = MapConfig.ObjectType.ASTEROID_SMALL
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ===========================
-- Versión mejorada: generateAsteroidBeltNetwork
-- - máscara perlin por chunk para evitar rectángulos
-- - carving (MST + edges) **antes** de poblar
-- - población Voronoi-like que respeta corridors
-- - thinning/erosión post-proceso para crear huecos
-- ===========================
function MapGenerator.generateAsteroidBeltNetwork(chunk, chunkX, chunkY, densities, globalSeed)
    -- Parámetros (ajusta si hace falta)
    local siteCellSize           = 10        -- escala de la red en tiles
    local siteJitter             = 1.4       -- mayor jitter para romper rejilla
    local edgeConnectK           = 3
    local edgeThicknessBase      = 2.2
    local siteCoreRadiusFactor   = 1.05
    local clearingChance         = 0.09
    local clearingRadiusFactor   = 0.36
    local extraScatter           = 0.02
    local perlinScale            = 0.065
    local corridorMode           = "clear"   -- usar "thin" si quieres conservar más asteroides
    local carveCorridors         = true

    local worldSeed = globalSeed or 1337
    local baseDensity = math.max(0.14, (densities and densities.asteroids) or MapConfig.density.asteroids or 0.4)

    local size = MapConfig.chunk.size
    chunk.tiles = chunk.tiles or {}
    for y = 0, size - 1 do
        chunk.tiles[y] = chunk.tiles[y] or {}
        for x = 0, size - 1 do
            chunk.tiles[y][x] = MapConfig.ObjectType.EMPTY
        end
    end

    local worldX0 = chunkX * size
    local worldY0 = chunkY * size
    local worldX1 = worldX0 + size - 1
    local worldY1 = worldY0 + size - 1

    local seedForChunk = (worldSeed * 1103515245 + chunkX * 374761393 + chunkY * 668265263) % 2147483647
    local rnd = makeLCG(seedForChunk)

    -- ----- Máscara orgánica del chunk (evita rectángulos perfectos) -----
    local mask = {}
    local maskScale = 0.045
    local maskThreshold = 0.42 + (PerlinNoise.noise(chunkX*0.13, chunkY*0.13, 7)*0.05)
    for y = 0, size - 1 do
        mask[y] = {}
        for x = 0, size - 1 do
            local nx = (worldX0 + x) * maskScale
            local ny = (worldY0 + y) * maskScale
            local n = (PerlinNoise.noise(nx, ny, 11) * 0.6 + PerlinNoise.noise(nx * 1.9, ny * 1.9, 22) * 0.4)
            n = (n + 1) * 0.5
            mask[y][x] = (n > maskThreshold)
        end
    end

    -- fallback si máscara vacía
    local anyTrue = false
    for y = 0, size - 1 do for x = 0, size - 1 do if mask[y][x] then anyTrue = true; break end end if anyTrue then break end end
    if not anyTrue then for y=0,size-1 do for x=0,size-1 do mask[y][x]=true end end end

    -- ----- 1) Sitios mundiales (rejilla con jitter + Perlin perturb) -----
    local margin = math.ceil(siteCellSize * 2.8)
    local minGX = math.floor((worldX0 - margin) / siteCellSize)
    local maxGX = math.floor((worldX1 + margin) / siteCellSize)
    local minGY = math.floor((worldY0 - margin) / siteCellSize)
    local maxGY = math.floor((worldY1 + margin) / siteCellSize)

    local sites = {}
    for gy = minGY, maxGY do
        for gx = minGX, maxGX do
            local baseX = gx * siteCellSize
            local baseY = gy * siteCellSize
            local nx = (baseX + 1000) * perlinScale
            local ny = (baseY + 2000) * perlinScale
            local jx = (PerlinNoise.noise(nx, ny, 41) - 0.5) * siteCellSize * siteJitter
            local jy = (PerlinNoise.noise(nx + 57.3, ny + 19.7, 99) - 0.5) * siteCellSize * siteJitter
            -- perturb adicional que depende de Perlin para romper paralelismo
            local px = (PerlinNoise.noise(nx*1.7 + 19, ny*1.7 + 29, 55) - 0.5) * siteCellSize * 0.6
            local py = (PerlinNoise.noise(nx*1.3 + 71, ny*1.3 + 81, 101) - 0.5) * siteCellSize * 0.6
            local sx = baseX + jx + px
            local sy = baseY + jy + py
            local typeNoise = (PerlinNoise.noise((sx+13.7)*perlinScale, (sy+5.3)*perlinScale, 7) + 1) * 0.5
            local sizeType = 0
            if typeNoise > 0.82 then sizeType = 2
            elseif typeNoise > 0.55 then sizeType = 1
            else sizeType = 0 end
            local maxRadius = siteCellSize * (siteCoreRadiusFactor + sizeType * 0.5)
            table.insert(sites, {x = sx, y = sy, gx = gx, gy = gy, sizeType = sizeType, maxRadius = maxRadius, id = #sites + 1})
        end
    end

    -- ----- 2) Conectar aristas (k nearest) -----
    local edgesMap = {}
    for i = 1, #sites do
        local si = sites[i]
        local distances = {}
        for j = 1, #sites do
            if i ~= j then
                local sj = sites[j]
                local dx, dy = si.x - sj.x, si.y - sj.y
                table.insert(distances, {idx = j, d2 = dx*dx + dy*dy})
            end
        end
        table.sort(distances, function(a,b) return a.d2 < b.d2 end)
        for k = 1, math.min(edgeConnectK, #distances) do
            local other = distances[k].idx
            local a, b = math.min(i, other), math.max(i, other)
            local key = tostring(a) .. "_" .. tostring(b)
            if not edgesMap[key] then edgesMap[key] = {a = a, b = b, d2 = distances[k].d2} end
        end
    end
    local edgesArr = {}
    for k,v in pairs(edgesMap) do table.insert(edgesArr, v) end

    -- ----- 3) Carve corridors primero (asegura rutas limpias) -----
    if carveCorridors then
        local bigSites = {}
        for i,s in ipairs(sites) do if s.sizeType == 2 then table.insert(bigSites, {s=s, idx=i}) end end

        if #bigSites >= 2 then
            local n = #bigSites
            local inMST = {}
            local key = {}
            local parent = {}
            for i=1,n do key[i] = math.huge; parent[i] = nil; inMST[i] = false end
            key[1] = 0
            for iter=1,n do
                local u = nil; local best = math.huge
                for i=1,n do if not inMST[i] and key[i] < best then best = key[i]; u = i end end
                if not u then break end
                inMST[u] = true
                if parent[u] then
                    local a = bigSites[u].s; local b = bigSites[parent[u]].s
                    local corridorRadius = math.max(2.0, edgeThicknessBase * 2.6)
                    carveCorridor(chunk, chunkX, chunkY, a.x, a.y, b.x, b.y, corridorRadius, corridorMode, perlinScale)
                end
                for v=1,n do
                    if not inMST[v] then
                        local duv = dist(bigSites[u].s.x, bigSites[u].s.y, bigSites[v].s.x, bigSites[v].s.y)
                        if duv < key[v] then key[v] = duv; parent[v] = u end
                    end
                end
            end
        end

        -- tallar también un subconjunto de edgesArr (redundancia)
        local carveCount = math.max(4, math.floor(#edgesArr * 0.25))
        local edgedone = 0
        for i = 1, #edgesArr do
            if edgedone >= carveCount then break end
            local e = edgesArr[i]
            local sa = sites[e.a]; local sb = sites[e.b]
            local corridorRadius = math.max(1.8, edgeThicknessBase * 2.0)
            carveCorridor(chunk, chunkX, chunkY, sa.x, sa.y, sb.x, sb.y, corridorRadius, corridorMode, perlinScale)
            edgedone = edgedone + 1
        end
    end

    -- ----- 4) Filtrar sitios relevantes para este chunk -----
    local relevantSites = {}
    for i, s in ipairs(sites) do
        if s.x + s.maxRadius >= worldX0 - 2 and s.x - s.maxRadius <= worldX1 + 2
        and s.y + s.maxRadius >= worldY0 - 2 and s.y - s.maxRadius <= worldY1 + 2 then
            table.insert(relevantSites, {s = s, i = i})
        end
    end

    -- ----- 5) Población: cores y aristas (pero no sobrecorridors ya tallados) -----
    local placed = 0
    for ty = 0, size - 1 do
        for tx = 0, size - 1 do
            -- respetar máscara
            if not mask[ty][tx] then goto continue_tile end

            local wx = worldX0 + tx
            local wy = worldY0 + ty

            -- nearest site
            local nearest = nil
            local nearestD2 = math.huge
            for _, rs in ipairs(relevantSites) do
                local s = rs.s
                local dx, dy = s.x - wx, s.y - wy
                local d2 = dx*dx + dy*dy
                if d2 < nearestD2 then
                    nearestD2 = d2
                    nearest = s
                end
            end

            local placedHere = false

            if nearest then
                local d = math.sqrt(nearestD2)
                local r = nearest.maxRadius
                local normalized = math.min(1, d / math.max(0.0001, r))
                -- densidad más baja en núcleos para evitar masas sólidas
                local coreBase = 0.8
                if nearest.sizeType == 2 then coreBase = 0.78
                elseif nearest.sizeType == 1 then coreBase = 0.60
                else coreBase = 0.38 end
                -- atenuación fuerte con la distancia
                local coreProb = coreBase * (1 - normalized^2.0)

                -- clearing (huecos centrales)
                local seedForSite = math.floor((nearest.x * 73856093 + nearest.y * 19349663 + worldSeed) % 2147483647)
                local siteRnd = makeLCG(seedForSite)
                local isClearing = (siteRnd() < clearingChance)
                local clearingRadius = r * clearingRadiusFactor
                if isClearing and d < clearingRadius then coreProb = coreProb * 0.06 end

                -- no sobreescribir corredores tallados: si tile fue limpiado por carveCorridor permanece empty
                if chunk.tiles[ty][tx] == MapConfig.ObjectType.EMPTY then
                    local noise = (PerlinNoise.noise(wx*perlinScale, wy*perlinScale, 99) + 1) * 0.5
                    coreProb = coreProb * (0.55 + 0.6 * noise) * baseDensity * 1.0
                    if rnd() < coreProb then
                        if nearest.sizeType == 2 then
                            if rnd() < 0.30 then chunk.tiles[ty][tx] = MapConfig.ObjectType.ASTEROID_LARGE
                            elseif rnd() < 0.62 then chunk.tiles[ty][tx] = MapConfig.ObjectType.ASTEROID_MEDIUM
                            else chunk.tiles[ty][tx] = MapConfig.ObjectType.ASTEROID_SMALL end
                        elseif nearest.sizeType == 1 then
                            if rnd() < 0.26 then chunk.tiles[ty][tx] = MapConfig.ObjectType.ASTEROID_MEDIUM
                            else chunk.tiles[ty][tx] = MapConfig.ObjectType.ASTEROID_SMALL end
                        else
                            chunk.tiles[ty][tx] = MapConfig.ObjectType.ASTEROID_SMALL
                        end
                        placedHere = true
                        placed = placed + 1
                    end
                end
            end

            -- aristas (si tile aún vacío)
            if not placedHere and chunk.tiles[ty][tx] == MapConfig.ObjectType.EMPTY then
                local minEdgeD2 = math.huge
                for _, e in ipairs(edgesArr) do
                    local sa = sites[e.a]; local sb = sites[e.b]
                    local bboxMinX = math.min(sa.x, sb.x) - edgeThicknessBase*3
                    local bboxMaxX = math.max(sa.x, sb.x) + edgeThicknessBase*3
                    local bboxMinY = math.min(sa.y, sb.y) - edgeThicknessBase*3
                    local bboxMaxY = math.max(sa.y, sb.y) + edgeThicknessBase*3
                    if not (wx < bboxMinX or wx > bboxMaxX or wy < bboxMinY or wy > bboxMaxY) then
                        local d2 = pointSegmentDistSq(wx, wy, sa.x, sa.y, sb.x, sb.y)
                        if d2 < minEdgeD2 then minEdgeD2 = d2 end
                    end
                end
                if minEdgeD2 < (edgeThicknessBase * edgeThicknessBase * 4.0) then
                    local dEdge = math.sqrt(minEdgeD2)
                    local edgeProb = 1 - (dEdge / (edgeThicknessBase * 2.0))
                    edgeProb = math.max(0, edgeProb)
                    local noiseE = (PerlinNoise.noise(wx*perlinScale + 400, wy*perlinScale + 400, 123) + 1)*0.5
                    edgeProb = edgeProb * (0.55 + 0.6 * noiseE) * baseDensity
                    if rnd() < edgeProb then
                        if rnd() < 0.18 then chunk.tiles[ty][tx] = MapConfig.ObjectType.ASTEROID_MEDIUM
                        else chunk.tiles[ty][tx] = MapConfig.ObjectType.ASTEROID_SMALL end
                        placed = placed + 1
                        placedHere = true
                    end
                end
            end

            -- scatter muy ligero
            if not placedHere and chunk.tiles[ty][tx] == MapConfig.ObjectType.EMPTY and rnd() < extraScatter * baseDensity * 0.6 then
                chunk.tiles[ty][tx] = MapConfig.ObjectType.ASTEROID_SMALL
                placed = placed + 1
            end

            ::continue_tile::
        end
    end

    -- ----- 6) Post-procesado: thinning para romper masas sólidas -----
    local erosionChance = 0.45
    local toClear = {}
    for ty = 1, size - 2 do
        for tx = 1, size - 2 do
            if chunk.tiles[ty][tx] ~= MapConfig.ObjectType.EMPTY then
                local full = true
                for oy = -1,1 do
                    for ox = -1,1 do
                        if ox == 0 and oy == 0 then goto skipcell end
                        local nx = tx + ox; local ny = ty + oy
                        if chunk.tiles[ny][nx] == MapConfig.ObjectType.EMPTY then full = false; break end
                        ::skipcell::
                    end
                    if not full then break end
                end
                if full and rnd() < erosionChance then
                    table.insert(toClear, {x=tx,y=ty})
                end
            end
        end
    end
    for _, c in ipairs(toClear) do
        chunk.tiles[c.y][c.x] = MapConfig.ObjectType.EMPTY
    end

    -- ----- 7) fallback garantizar mínima cobertura -----
    local minAsteroids = math.floor(size * size * baseDensity * 0.28)
    if placed < minAsteroids then
        local attempts = 0
        while placed < minAsteroids and attempts < minAsteroids * 4 do
            attempts = attempts + 1
            local rx = math.floor(rnd() * size)
            local ry = math.floor(rnd() * size)
            if mask[ry][rx] and chunk.tiles[ry][rx] == MapConfig.ObjectType.EMPTY then
                local r = rnd()
                if r > 0.94 then chunk.tiles[ry][rx] = MapConfig.ObjectType.ASTEROID_LARGE
                elseif r > 0.7 then chunk.tiles[ry][rx] = MapConfig.ObjectType.ASTEROID_MEDIUM
                else chunk.tiles[ry][rx] = MapConfig.ObjectType.ASTEROID_SMALL
                end
                placed = placed + 1
            end
        end
    end

    return chunk
end

-- Alias: mantener compatibilidad
MapGenerator.generateAsteroidBeltField = MapGenerator.generateAsteroidBeltNetwork

-- ===========================
-- Otras funciones de generación (mantengo y adapto del archivo original)
-- ===========================

-- Generar asteroides balanceados (usa el generador de belt si corresponde)
function MapGenerator.generateBalancedAsteroids(chunk, chunkX, chunkY, densities)
    local asteroidDensity = densities.asteroids or MapConfig.density.asteroids
    if chunk.biome.type == BiomeSystem.BiomeType.ASTEROID_BELT then
        return MapGenerator.generateAsteroidBeltField(chunk, chunkX, chunkY, densities)
    end

    local placed = 0
    for y = 0, MapConfig.chunk.size - 1 do
        for x = 0, MapConfig.chunk.size - 1 do
            local globalX = chunkX * MapConfig.chunk.size + x
            local globalY = chunkY * MapConfig.chunk.size + y

            local noiseMain = MapGenerator.multiOctaveNoise(globalX, globalY, 4, 0.5, 0.025)
            local noiseDetail = MapGenerator.multiOctaveNoise(globalX, globalY, 2, 0.3, 0.12)
            local combinedNoise = (noiseMain * 0.7 + noiseDetail * 0.3)

            local threshold = 0.20
            if chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
                threshold = 0.25
                combinedNoise = combinedNoise * 0.9
            elseif chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
                threshold = 0.35
            elseif chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
                threshold = 0.18
                combinedNoise = combinedNoise * 1.1
            elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
                threshold = 0.4
            elseif chunk.biome.type == BiomeSystem.BiomeType.ANCIENT_RUINS then
                threshold = 0.45
            end

            if combinedNoise > threshold + 0.3 then
                chunk.tiles[y][x] = MapConfig.ObjectType.ASTEROID_LARGE
                placed = placed + 1
            elseif combinedNoise > threshold + 0.15 then
                chunk.tiles[y][x] = MapConfig.ObjectType.ASTEROID_MEDIUM
                placed = placed + 1
            elseif combinedNoise > threshold then
                chunk.tiles[y][x] = MapConfig.ObjectType.ASTEROID_SMALL
                placed = placed + 1
            end

            local randomFactor = math.random()
            if randomFactor < asteroidDensity * 0.08 then
                if chunk.tiles[y][x] == MapConfig.ObjectType.EMPTY then
                    chunk.tiles[y][x] = MapConfig.ObjectType.ASTEROID_SMALL
                end
            end
        end
    end

    -- fallback coverage (igual que antes)
    local size = MapConfig.chunk.size
    local totalTiles = size * size
    local minRatioByBiome = {
        [BiomeSystem.BiomeType.DEEP_SPACE] = 0.005,
        [BiomeSystem.BiomeType.NEBULA_FIELD] = 0.02,
        [BiomeSystem.BiomeType.ASTEROID_BELT] = 0.0,
        [BiomeSystem.BiomeType.GRAVITY_ANOMALY] = 0.015,
        [BiomeSystem.BiomeType.RADIOACTIVE_ZONE] = 0.01,
        [BiomeSystem.BiomeType.ANCIENT_RUINS] = 0.008
    }
    local minNeeded = math.floor(totalTiles * (minRatioByBiome[chunk.biome.type] or 0.01))
    if placed < minNeeded then
        local toAdd = minNeeded - placed
        local attempts = 0
        while toAdd > 0 and attempts < totalTiles * 2 do
            attempts = attempts + 1
            local rx = math.random(0, size - 1)
            local ry = math.random(0, size - 1)
            if chunk.tiles[ry][rx] == MapConfig.ObjectType.EMPTY then
                local roll = math.random()
                if roll < 0.15 then
                    chunk.tiles[ry][rx] = MapConfig.ObjectType.ASTEROID_LARGE
                elseif roll < 0.45 then
                    chunk.tiles[ry][rx] = MapConfig.ObjectType.ASTEROID_MEDIUM
                else
                    chunk.tiles[ry][rx] = MapConfig.ObjectType.ASTEROID_SMALL
                end
                toAdd = toAdd - 1
            end
        end
    end
end

-- Generar nebulosas balanceadas
function MapGenerator.generateBalancedNebulae(chunk, chunkX, chunkY, densities)
    local nebulaObjects = {}
    local nebulaDensity = densities.nebulae or MapConfig.density.nebulae

    local baseNumNebulae = math.max(1, math.floor(nebulaDensity * 0.8))
    local maxNebulae = 6

    local numNebulae
    if chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
        numNebulae = math.min(3, baseNumNebulae)
    elseif chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
        numNebulae = math.min(maxNebulae, baseNumNebulae * 4)
    elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
        numNebulae = math.min(maxNebulae, baseNumNebulae * 2)
    elseif chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
        numNebulae = math.min(4, baseNumNebulae * 1.5)
    else
        numNebulae = math.min(4, baseNumNebulae)
    end

    for i = 1, numNebulae do
        local x = math.random(0, MapConfig.chunk.size - 1)
        local y = math.random(0, MapConfig.chunk.size - 1)
        local globalX = chunkX * MapConfig.chunk.size + x
        local globalY = chunkY * MapConfig.chunk.size + y

        local nebulaChance = MapGenerator.multiOctaveNoise(globalX, globalY, 3, 0.5, 0.035)
        local threshold = 0.25

        if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
            threshold = 0.05
        elseif chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
            threshold = 0.35
        elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
            threshold = 0.15
        elseif chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
            threshold = 0.20
        end

        local shouldGenerate = false
        if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
            shouldGenerate = (nebulaChance > threshold) or (math.random() < 0.4)
        elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
            shouldGenerate = (nebulaChance > threshold) or (math.random() < 0.25)
        else
            shouldGenerate = nebulaChance > threshold
        end

        if shouldGenerate then
            local nebula = {
                type = MapConfig.ObjectType.NEBULA,
                x = x * MapConfig.chunk.tileSize,
                y = y * MapConfig.chunk.tileSize,
                size = math.random(60, 160) * MapConfig.chunk.worldScale,
                color = MapConfig.colors.nebulae[math.random(1, #MapConfig.colors.nebulae)],
                intensity = math.random(25, 60) / 100,
                biomeType = chunk.biome.type,
                globalX = globalX,
                globalY = globalY
            }

            if chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
                nebula.size = nebula.size * math.random(120, 180) / 100
                nebula.intensity = nebula.intensity * math.random(110, 150) / 100
            elseif chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
                nebula.size = nebula.size * math.random(80, 130) / 100
                nebula.intensity = nebula.intensity * math.random(120, 160) / 100
                nebula.color = {0.8, 0.6, 0.2, 0.5}
            end

            table.insert(nebulaObjects, nebula)
        end
    end

    chunk.objects.nebulae = nebulaObjects
end

-- Generar objetos especiales balanceados
function MapGenerator.generateBalancedSpecialObjects(chunk, chunkX, chunkY, densities)
    chunk.specialObjects = {}

    local stationDensity = densities.stations or MapConfig.density.stations
    local wormholeDensity = densities.wormholes or MapConfig.density.wormholes

    -- Use Perlin noise for station generation
    local stationNoise = MapGenerator.multiOctaveNoise(chunkX, chunkY, 2, 0.5, 0.01)
    if stationNoise < stationDensity then
        local station = {
            type = MapConfig.ObjectType.STATION,
            x = math.random(10, MapConfig.chunk.size - 10) * MapConfig.chunk.tileSize,
            y = math.random(10, MapConfig.chunk.size - 10) * MapConfig.chunk.tileSize,
            size = math.random(18, 40) * MapConfig.chunk.worldScale,
            rotation = math.random() * math.pi * 2,
            active = true,
            biomeType = chunk.biome.type
        }
        table.insert(chunk.specialObjects, station)
    end

    -- Use Perlin noise for wormhole generation
    local wormholeNoise = MapGenerator.multiOctaveNoise(chunkX + 0.5, chunkY + 0.5, 2, 0.5, 0.01)
    if wormholeNoise < wormholeDensity then
        local wormhole = {
            type = MapConfig.ObjectType.WORMHOLE,
            x = math.random(8, MapConfig.chunk.size - 8) * MapConfig.chunk.tileSize,
            y = math.random(8, MapConfig.chunk.size - 8) * MapConfig.chunk.tileSize,
            size = math.random(15, 25) * MapConfig.chunk.worldScale,
            pulsePhase = math.random() * math.pi * 2,
            active = true,
            biomeType = chunk.biome.type
        }
        table.insert(chunk.specialObjects, wormhole)
    end

    -- Fallback: asegurar al menos 1 wormhole ocasional en Gravity Anomaly si no se generó por ruido
    if chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
        local hasWormhole = false
        for _, obj in ipairs(chunk.specialObjects) do
            if obj.type == MapConfig.ObjectType.WORMHOLE then
                hasWormhole = true
                break
            end
        end
        if not hasWormhole and math.random() < 0.25 then
            local wormhole = {
                type = MapConfig.ObjectType.WORMHOLE,
                x = math.random(8, MapConfig.chunk.size - 8) * MapConfig.chunk.tileSize,
                y = math.random(8, MapConfig.chunk.size - 8) * MapConfig.chunk.tileSize,
                size = math.random(16, 28) * MapConfig.chunk.worldScale,
                pulsePhase = math.random() * math.pi * 2,
                active = true,
                biomeType = chunk.biome.type
            }
            table.insert(chunk.specialObjects, wormhole)
        end
    end
end

-- Generar estrellas balanceadas
function MapGenerator.generateBalancedStars(chunk, chunkX, chunkY, densities)
    local stars = {}
    local starDensity = densities.stars or MapConfig.density.stars
    local baseNumStars = math.floor(MapConfig.chunk.size * MapConfig.chunk.size * starDensity * 0.2)

    local numStars = baseNumStars * 2.0
    if chunk.biome.type == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
        numStars = baseNumStars * 3.0
    elseif chunk.biome.type == BiomeSystem.BiomeType.NEBULA_FIELD then
        numStars = baseNumStars * 2.2
    elseif chunk.biome.type == BiomeSystem.BiomeType.ASTEROID_BELT then
        numStars = baseNumStars * 1.8
    elseif chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE then
        numStars = baseNumStars * 2.5
    end

    local sectorsPerSide = 6
    local sectorSize = MapConfig.chunk.size * MapConfig.chunk.tileSize / sectorsPerSide
    local starsPerSector = math.ceil(numStars / (sectorsPerSide * sectorsPerSide))

    for sectorY = 0, sectorsPerSide - 1 do
        for sectorX = 0, sectorsPerSide - 1 do
            local sectorStars = starsPerSector
            if math.random() < 0.3 then
                sectorStars = sectorStars + math.random(1, 3)
            end

            for i = 1, sectorStars do
                local x = sectorX * sectorSize + math.random(sectorSize * 0.1, sectorSize * 0.9)
                local y = sectorY * sectorSize + math.random(sectorSize * 0.1, sectorSize * 0.9)

                local starTypeRoll = math.random(1, 100)
                local starType

                if starTypeRoll <= 30 then
                    starType = 1
                elseif starTypeRoll <= 50 then
                    starType = 2
                elseif starTypeRoll <= 65 then
                    starType = 3
                elseif starTypeRoll <= 80 then
                    starType = 4
                elseif starTypeRoll <= 92 then
                    starType = 5
                else
                    starType = 6
                end

                if chunk.biome.type == BiomeSystem.BiomeType.DEEP_SPACE and math.random() < 0.25 then
                    starType = math.min(6, starType + 1)
                end

                local starConfigs = {
                    [1] = {size = math.random(1, 2), depth = math.random(0.85, 0.95)},
                    [2] = {size = math.random(2, 3), depth = math.random(0.7, 0.85)},
                    [3] = {size = math.random(3, 4), depth = math.random(0.5, 0.7)},
                    [4] = {size = math.random(3, 5), depth = math.random(0.3, 0.5)},
                    [5] = {size = math.random(4, 6), depth = math.random(0.15, 0.3)},
                    [6] = {size = math.random(5, 8), depth = math.random(0.05, 0.15)}
                }

                local config = starConfigs[starType]
                local star = {
                    x = x,
                    y = y,
                    size = config.size,
                    type = starType,
                    color = MapConfig.colors.stars[math.random(1, #MapConfig.colors.stars)],
                    twinkle = math.random() * math.pi * 2,
                    twinkleSpeed = math.random(0.5, 3.0),
                    depth = config.depth,
                    brightness = math.random(0.8, 1.2),
                    pulsePhase = math.random() * math.pi * 2,
                    biomeType = chunk.biome.type
                }

                table.insert(stars, star)
            end
        end
    end

    chunk.objects.stars = stars
end

-- Generar chunk completo
function MapGenerator.generateChunk(chunkX, chunkY)
    local chunk = {
        x = chunkX,
        y = chunkY,
        tiles = {},
        objects = {stars = {}, nebulae = {}},
        specialObjects = {},
        bounds = (function()
            local sizePixels = MapConfig.chunk.size * MapConfig.chunk.tileSize
            local spacing = MapConfig.chunk.spacing or 0
            local stride = sizePixels + spacing
            local left = chunkX * stride
            local top = chunkY * stride
            return {
                left = left,
                top = top,
                right = left + stride,
                bottom = top + stride
            }
        end)()
    }

    -- Determinar bioma
    local biomeInfo = BiomeSystem.getBiomeInfo(chunkX, chunkY)
    chunk.biome = biomeInfo

    -- Inicializar tiles
    for y = 0, MapConfig.chunk.size - 1 do
        chunk.tiles[y] = {}
        for x = 0, MapConfig.chunk.size - 1 do
            chunk.tiles[y][x] = MapConfig.ObjectType.EMPTY
        end
    end

    -- Generar contenido usando densidades modificadas por bioma
    local modifiedDensities = BiomeSystem.modifyDensities(MapConfig.density, biomeInfo.type, chunkX, chunkY)

    MapGenerator.generateBalancedAsteroids(chunk, chunkX, chunkY, modifiedDensities)
    MapGenerator.generateBalancedNebulae(chunk, chunkX, chunkY, modifiedDensities)
    MapGenerator.generateBalancedSpecialObjects(chunk, chunkX, chunkY, modifiedDensities)
    MapGenerator.generateBalancedStars(chunk, chunkX, chunkY, modifiedDensities)

    BiomeSystem.generateSpecialFeatures(chunk, chunkX, chunkY, biomeInfo.type)

    return chunk
end

return MapGenerator
