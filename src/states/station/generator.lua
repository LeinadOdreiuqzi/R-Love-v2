-- src/states/station/generator.lua

local Generator = {}
local Templates = require 'src.states.station.room_templates'
local SeedSystem = require 'src.utils.seed_system'

-- Genera un grafo lineal simple de N salas conectadas (MVP)
function Generator.generate(opts)
    opts = opts or {}
    local seed = opts.seed or 0
    local count = math.max(3, math.min(6, opts.count or 4))
    local rng = SeedSystem.makeRNG(seed)

    local rooms = {}
    local xOffset = 0
    for i = 1, count do
        -- Selección por categorías finitas
        local name
        if i == 1 then
            name = Templates.randomByCategory('entrance', rng)
        elseif i == count then
            name = Templates.randomByCategory('specialized', rng)
        else
            name = (rng:randomInt(1,3) == 1) and Templates.randomByCategory('corridor', rng) or Templates.randomByCategory('filler', rng)
        end
        local base = Templates.build(name, rng)
        -- Clonar shallow
        local r = {
            id = i,
            name = base.name,
            type = base.category or 'unknown',
            width = base.width,
            height = base.height,
            x = xOffset,
            y = 0,
            platforms = {},
            doors = {},
            spawn = { x = base.spawn.x + xOffset, y = base.spawn.y },
        }
        -- Offset plataformas a coords mundiales
        for _, p in ipairs(base.platforms or {}) do
            table.insert(r.platforms, { x = p.x + xOffset, y = p.y, w = p.w, h = p.h })
        end
        -- Offset puertas
        r.doors.left = base.doors.left and { x = base.doors.left.x + xOffset, y = base.doors.left.y, w = base.doors.left.w, h = base.doors.left.h, side = 'left', to = nil } or nil
        r.doors.right = base.doors.right and { x = base.doors.right.x + xOffset, y = base.doors.right.y, w = base.doors.right.w, h = base.doors.right.h, side = 'right', to = nil } or nil

        table.insert(rooms, r)
        -- Separación ampliada entre salas para espacios más grandes
        xOffset = xOffset + base.width + 180 -- Aumentado de 120 a 180 (1.5x)
    end

    -- Conectar en cadena: right i -> left i+1
    for i = 1, #rooms - 1 do
        if rooms[i].doors.right and rooms[i+1].doors.left then
            rooms[i].doors.right.to = { roomId = i + 1, door = 'left' }
            rooms[i + 1].doors.left.to = { roomId = i, door = 'right' }
        end
    end

    return {
        rooms = rooms,
        startRoomId = 1,
        rng = rng,
        seed = seed,
    }
end

-- Genera una zona abierta concatenando varias plantillas, con inicio y fin
function Generator.generateOpenZone(opts)
    opts = opts or {}
    local seed = opts.seed or 0
    local count = math.max(3, math.min(6, opts.count or 5))
    local separation = opts.separation or 180
    local rng = SeedSystem.makeRNG(seed)

    local segments = {}
    local xOffset = 0
    local totalWidth = 0
    local maxHeight = 0

    for i = 1, count do
        local name
        if i == 1 then
            name = Templates.randomByCategory('entrance', rng)
        elseif i == count then
            name = Templates.randomByCategory('specialized', rng)
        else
            name = (rng:randomInt(1,3) == 1) and Templates.randomByCategory('corridor', rng) or Templates.randomByCategory('filler', rng)
        end
        local base = Templates.build(name, rng)
        local seg = {
            id = i,
            name = base.name,
            type = base.category or 'unknown',
            width = base.width,
            height = base.height,
            x = xOffset,
            y = 0,
            platforms = {},
            doors = {},
            spawn = { x = base.spawn.x + xOffset, y = base.spawn.y },
        }
        for _, p in ipairs(base.platforms or {}) do
            table.insert(seg.platforms, { x = p.x + xOffset, y = p.y, w = p.w, h = p.h })
        end
        table.insert(segments, seg)
        xOffset = xOffset + base.width + separation
        totalWidth = xOffset - separation
        maxHeight = math.max(maxHeight, base.height)
    end

    local zone = {
        x = 0, y = 0,
        width = totalWidth,
        height = maxHeight,
        platforms = {},
        doors = {},
        spawn = { x = segments[1].spawn.x, y = segments[1].spawn.y },
        goal = nil,
    }
    for _, seg in ipairs(segments) do
        for _, p in ipairs(seg.platforms) do
            table.insert(zone.platforms, p)
        end
    end
    zone.goal = {
        x = zone.x + zone.width - 108,
        y = zone.y + zone.height - 84 - 120,
        w = 60,
        h = 120,
    }

    return { zone = zone, segments = segments, seed = seed, rng = rng }
end

-- Genera un grafo 2D con conexiones up/down/left/right, inspirado en la estructura de niveles de Metal Warriors
function Generator.generateGrid(opts)
    opts = opts or {}
    local seed = opts.seed or 0
    local rows = math.max(2, math.min(3, opts.rows or 3))
    local cols = math.max(3, math.min(5, opts.cols or 4))
    -- Separación ampliada para acomodar espacios más grandes
    local separation = opts.separation or 180 -- Aumentado de 120 a 180 (1.5x)
    local rng = SeedSystem.makeRNG(seed)

    -- Random walk para definir celdas visitadas y asegurar conectividad
    local visited = {}
    for r=1,rows do visited[r] = {} end
    local function key(r,c) return r..":"..c end
    local function unkey(k) 
        local r, c = k:match("([^:]+):([^:]+)")
        return tonumber(r), tonumber(c)
    end
    local order = {}
    local cr, cc = 1, 1
    visited[cr][cc] = true
    table.insert(order, {r=cr,c=cc})
    local steps = rows*cols + rng:randomInt(rows, cols)
    for i=1,steps do
        local dirPick = rng:randomInt(1,4)
        local nr, nc = cr, cc
        if dirPick == 1 then
            nc = math.max(1, cc-1)
        elseif dirPick == 2 then
            nc = math.min(cols, cc+1)
        elseif dirPick == 3 then
            nr = math.max(1, cr-1)
        else
            nr = math.min(rows, cr+1)
        end
        cr, cc = nr, nc
        if not visited[cr][cc] then
            visited[cr][cc] = true
            table.insert(order, {r=cr,c=cc})
        end
    end

    -- Recopilar lista de celdas ocupadas
    local cells = {}
    local cellIndexByRC = {}
    for _,pos in ipairs(order) do
        if not cellIndexByRC[key(pos.r,pos.c)] then
            table.insert(cells, {r=pos.r,c=pos.c})
            cellIndexByRC[key(pos.r,pos.c)] = #cells
        end
    end

    -- Determinar adyacencias por celda
    local function has(r,c) return visited[r] and visited[r][c] end
    local adj = {}
    for _,cell in ipairs(cells) do
        local r,c = cell.r, cell.c
        adj[key(r,c)] = {
            left = has(r,c-1),
            right = has(r,c+1),
            up = has(r-1,c),
            down = has(r+1,c),
        }
    end

    -- Asignar categorías y plantillas finitas a cada celda
    local bases = {}
    -- Determinar celda de inicio (preferir 1,1 si existe, si no, la primera visitada)
    local startRC = has(1,1) and {r=1,c=1} or { r = cells[1].r, c = cells[1].c }
    -- Determinar celda del jefe como la más alejada por distancia Manhattan
    local bossRC = startRC
    local maxDist = -1
    for _,cell in ipairs(cells) do
        local d = math.abs(cell.r - startRC.r) + math.abs(cell.c - startRC.c)
        if d > maxDist then
            maxDist = d
            bossRC = { r = cell.r, c = cell.c }
        end
    end


    -- Calcular distancias desde la entrada para distribución por capas
    local function calculateDistance(r1, c1, r2, c2)
        return math.abs(r1 - r2) + math.abs(c1 - c2)
    end
    
    -- Clasificar celdas por distancia desde la entrada
    local cellsByDistance = {}
    for _,cell in ipairs(cells) do
        local dist = calculateDistance(cell.r, cell.c, startRC.r, startRC.c)
        if not cellsByDistance[dist] then
            cellsByDistance[dist] = {}
        end
        table.insert(cellsByDistance[dist], cell)
    end
    
    -- Determinar capas concéntricas
    local maxDistance = 0
    for dist, _ in pairs(cellsByDistance) do
        maxDistance = math.max(maxDistance, dist)
    end
    
    -- Definir rangos de capas para distribución progresiva
    local layers = {
        entrance = { min = 0, max = 0 },                                    -- Solo entrada
        corridor_near = { min = 1, max = math.max(1, math.floor(maxDistance * 0.3)) },  -- 30% inicial
        common = { min = math.max(1, math.floor(maxDistance * 0.2)), max = math.max(2, math.floor(maxDistance * 0.6)) }, -- 20%-60%
        specialized = { min = math.max(2, math.floor(maxDistance * 0.4)), max = math.max(3, math.floor(maxDistance * 0.8)) }, -- 40%-80%
        corridor_far = { min = math.max(1, math.floor(maxDistance * 0.6)), max = maxDistance }, -- 60%-final
        boss = { min = maxDistance, max = maxDistance }                     -- Solo boss al final
    }

    -- Elegir salas especializadas en las capas correctas
    local available = {}
    for _,cell in ipairs(cells) do
        if not (cell.r == startRC.r and cell.c == startRC.c) and not (cell.r == bossRC.r and cell.c == bossRC.c) then
            local dist = calculateDistance(cell.r, cell.c, startRC.r, startRC.c)
            -- Solo considerar celdas en la capa especializada
            if dist >= layers.specialized.min and dist <= layers.specialized.max then
                table.insert(available, { r = cell.r, c = cell.c })
            end
        end
    end
    local specializedSet = {}
    local specializedCount = (#cells >= 5) and 2 or 1
    -- Asegurar que hay candidatos en la capa especializada
    if #available > 0 then
        for i=1,math.min(specializedCount, #available) do
            local idx = rng:randomInt(1, #available)
            specializedSet[key(available[idx].r, available[idx].c)] = true
            table.remove(available, idx)
        end
    end
    
    -- Posible sala secreta: requiere vecino arriba y estar en capa media-tardía
    local secretKey = nil
    local secretCandidates = {}
    for _,cell in ipairs(cells) do
        local k = key(cell.r, cell.c)
        local dist = calculateDistance(cell.r, cell.c, startRC.r, startRC.c)
        if not (cell.r == startRC.r and cell.c == startRC.c) 
           and not (cell.r == bossRC.r and cell.c == bossRC.c) 
           and not specializedSet[k]
           and dist >= layers.common.min and dist <= layers.specialized.max then -- En capas media-tardía
            local a = adj[k]
            if a and a.up then table.insert(secretCandidates, { r = cell.r, c = cell.c }) end
        end
    end
    if #secretCandidates > 0 and rng:randomInt(1,3) == 1 then
        local sc = secretCandidates[rng:randomInt(1, #secretCandidates)]
        secretKey = key(sc.r, sc.c)
    end

    -- Variables de balance locales
    local namesByCell, corridorCells, counts, totalCells, corridorCap, fillerMin, commonMin
    -- Inicialización de estructuras de balance (evita nil cuando el primer ciclo es especial)
    namesByCell = {}
    corridorCells = {}
    counts = { corridor = 0, filler = 0, common = 0 }
    totalCells = #cells
    corridorCap = math.max(1, math.floor(totalCells * 0.20))  -- Reducido de 25% a 20%
    fillerMin   = math.max(1, math.floor(totalCells * 0.25))  -- Reducido de 35% a 25%
    commonMin   = math.max(1, math.floor(totalCells * 0.15))  -- Nuevo: mínimo 15% salas comunes

    for _,cell in ipairs(cells) do
        local r,c = cell.r, cell.c
        local k = key(r,c)
        local a = adj[k]
        local cellDistance = calculateDistance(r, c, startRC.r, startRC.c)
        local name
        
        if r == startRC.r and c == startRC.c then
            name = Templates.randomByCategory('entrance', rng)
        elseif r == bossRC.r and c == bossRC.c then
            name = Templates.randomByCategory('boss', rng)
        elseif secretKey and k == secretKey then
            name = Templates.randomByCategory('secret', rng)
        elseif specializedSet[k] then
            -- Solo asignar especializada si está en la capa correcta
            if cellDistance >= layers.specialized.min and cellDistance <= layers.specialized.max then
                name = Templates.randomByCategory('specialized', rng)
            else
                -- Si está fuera de la capa, convertir a común o filler según distancia
                if cellDistance >= layers.common.min and cellDistance <= layers.common.max then
                    name = Templates.randomByCategory('common', rng)
                    counts.common = counts.common + 1
                else
                    name = Templates.randomByCategory('filler', rng)
                    counts.filler = counts.filler + 1
                end
            end
        else
            -- Distribución por capas para salas normales
            local degree = (a.left and 1 or 0) + (a.right and 1 or 0) + (a.up and 1 or 0) + (a.down and 1 or 0)
            local horiz2 = (a.left and 1 or 0) + (a.right and 1 or 0)
            local vert2  = (a.up and 1 or 0) + (a.down and 1 or 0)
            local corridorWanted = (horiz2 == 2 and vert2 == 0) or (horiz2 == 0 and vert2 == 2)
            
            -- Determinar si es una conexión crítica (cerca de entrada, especializada o boss)
            local nearStart = cellDistance <= 2
            local nearSpecialized = false
            local nearBoss = cellDistance >= maxDistance - 2
            
            -- Verificar proximidad a salas especializadas
            for specKey, _ in pairs(specializedSet) do
                local specR, specC = unkey(specKey)
                local distToSpec = calculateDistance(cell.r, cell.c, specR, specC)
                if distToSpec <= 2 then
                    nearSpecialized = true
                    break
                end
            end
            
            local isCriticalConnection = nearStart or nearSpecialized or nearBoss
            
            if cellDistance >= layers.corridor_near.min and cellDistance <= layers.corridor_near.max and corridorWanted and counts.corridor < corridorCap then
                -- Pasillos cerca de la entrada - alta prioridad
                name = Templates.randomByCategory('corridor', rng)
                counts.corridor = counts.corridor + 1
                table.insert(corridorCells, k)
            elseif isCriticalConnection and corridorWanted and counts.corridor < corridorCap then
                -- Pasillos que conectan áreas críticas - alta prioridad
                name = Templates.randomByCategory('corridor', rng)
                counts.corridor = counts.corridor + 1
                table.insert(corridorCells, k)
            elseif cellDistance >= layers.common.min and cellDistance <= layers.common.max and counts.common < commonMin then
                -- Salas comunes en la zona media
                name = Templates.randomByCategory('common', rng)
                counts.common = counts.common + 1
            elseif cellDistance >= layers.corridor_far.min and corridorWanted and counts.corridor < corridorCap then
                -- Pasillos hacia el final para crear suspense antes del boss
                name = Templates.randomByCategory('corridor', rng)
                counts.corridor = counts.corridor + 1
                table.insert(corridorCells, k)
            else
                -- Fillers como relleno general
                name = Templates.randomByCategory('filler', rng)
                counts.filler = counts.filler + 1
            end
        end
        -- Almacenar nombre sin construir base aún (reeequilibrio después)
        namesByCell[k] = name
        -- NO construir aquí; reequilibramos primero y luego construimos
    end

    -- Reequilibrio posterior: asegurar mínimos/máximos antes de construir bases
    if counts and totalCells then
        -- Reducir pasillos si exceden el límite
        if counts.corridor > corridorCap then
            local toReduce = counts.corridor - corridorCap
            for i=1,toReduce do
                local ck = table.remove(corridorCells)
                if ck then 
                    namesByCell[ck] = Templates.randomByCategory('filler', rng)
                    counts.corridor = counts.corridor - 1
                    counts.filler = counts.filler + 1
                end
            end
        end
        
        -- Asegurar mínimo de salas comunes
        if counts.common < commonMin then
            local toAdd = commonMin - counts.common
            local converted = 0
            for _,cell in ipairs(cells) do
                if converted >= toAdd then break end
                local k2 = key(cell.r, cell.c)
                if not (cell.r == startRC.r and cell.c == startRC.c)
                   and not (cell.r == bossRC.r and cell.c == bossRC.c)
                   and not (secretKey and k2 == secretKey)
                   and not specializedSet[k2]
                   and namesByCell[k2] == Templates.randomByCategory('filler', rng) then
                    namesByCell[k2] = Templates.randomByCategory('common', rng)
                    counts.filler = counts.filler - 1
                    counts.common = counts.common + 1
                    converted = converted + 1
                end
            end
        end
        
        -- Asegurar mínimo de fillers
        if counts.filler < fillerMin then
            for _,cell in ipairs(cells) do
                local k2 = key(cell.r, cell.c)
                if not (cell.r == startRC.r and cell.c == startRC.c)
                   and not (cell.r == bossRC.r and cell.c == bossRC.c)
                   and not (secretKey and k2 == secretKey)
                   and not specializedSet[k2]
                   and namesByCell[k2] == Templates.randomByCategory('corridor', rng) then
                    namesByCell[k2] = Templates.randomByCategory('filler', rng)
                    counts.corridor = counts.corridor - 1
                    counts.filler = counts.filler + 1
                    if counts.filler >= fillerMin then break end
                end
            end
        end
    end

    -- Construir bases conforme al namesByCell resultante
    bases = {}
    for _,cell in ipairs(cells) do
        local r,c = cell.r, cell.c
        local nm = namesByCell[key(r,c)]
        local base = Templates.build(nm, rng)
        bases[key(r,c)] = base
    end

    -- Calcular tamaños por columna y fila
    local colWidth = {}
    local rowHeight = {}
    for _,cell in ipairs(cells) do
        local r,c = cell.r, cell.c
        local base = bases[key(r,c)]
        colWidth[c] = math.max(colWidth[c] or 0, base.width)
        rowHeight[r] = math.max(rowHeight[r] or 0, base.height)
    end

    -- Offsets acumulados con separaciones ampliadas
    local xOffsets = {}
    local yOffsets = {}
    local acc = 0
    for c=1,cols do
        if colWidth[c] then
            xOffsets[c] = acc
            acc = acc + colWidth[c] + separation
        else
            xOffsets[c] = acc
            -- Dimensiones por defecto ampliadas para celdas vacías
            acc = acc + 900 + separation -- Aumentado de 600 a 900 (1.5x)
        end
    end
    acc = 0
    for r=1,rows do
        if rowHeight[r] then
            yOffsets[r] = acc
            acc = acc + rowHeight[r] + separation
        else
            yOffsets[r] = acc
            -- Dimensiones por defecto ampliadas para celdas vacías
            acc = acc + 720 + separation -- Aumentado de 480 a 720 (1.5x)
        end
    end

    -- Construir rooms con offsets y puertas
    local rooms = {}
    local indexByRC = {}
    for _,cell in ipairs(cells) do
        local r,c = cell.r, cell.c
        local base = bases[key(r,c)]
        local rx = xOffsets[c]
        local ry = yOffsets[r]
        local room = {
            id = #rooms + 1,
            name = base.name,
            type = base.category or 'unknown',
            width = base.width,
            height = base.height,
            x = rx,
            y = ry,
            platforms = {},
            doors = {},
            spawn = { x = base.spawn.x + rx, y = base.spawn.y + ry },
            grid = { r = r, c = c },
        }
        for _,p in ipairs(base.platforms or {}) do
            table.insert(room.platforms, { x = p.x + rx, y = p.y + ry, w = p.w, h = p.h })
        end
        local function copyDoor(d)
            return d and { x = d.x + rx, y = d.y + ry, w = d.w, h = d.h, side = d.side, to = nil } or nil
        end
        room.doors.left  = copyDoor(base.doors.left)
        room.doors.right = copyDoor(base.doors.right)
        room.doors.up    = copyDoor(base.doors.up)
        room.doors.down  = copyDoor(base.doors.down)

        table.insert(rooms, room)
        indexByRC[key(r,c)] = room.id
    end

    -- Conectar puertas entre vecinos
    for _,room in ipairs(rooms) do
        local r,c = room.grid.r, room.grid.c
        local leftId  = indexByRC[key(r, c-1)]
        local rightId = indexByRC[key(r, c+1)]
        local upId    = indexByRC[key(r-1, c)]
        local downId  = indexByRC[key(r+1, c)]
        if leftId and room.doors.left then
            room.doors.left.to = { roomId = leftId, door = 'right' }
        end
        if rightId and room.doors.right then
            room.doors.right.to = { roomId = rightId, door = 'left' }
        end
        if upId and room.doors.up then
            room.doors.up.to = { roomId = upId, door = 'down' }
        end
        if downId and room.doors.down then
            room.doors.down.to = { roomId = downId, door = 'up' }
        end
        -- Eliminar puertas sin conexión
        for _, side in ipairs({ 'left','right','up','down' }) do
            local d = room.doors[side]
            if d and not d.to then
                room.doors[side] = nil
            end
        end
    end

    local startRoomId = indexByRC[key(1,1)] or 1

    return {
        rooms = rooms,
        startRoomId = startRoomId,
        rng = rng,
        seed = seed,
        rows = rows,
        cols = cols,
        separation = separation,
    }
end

return Generator