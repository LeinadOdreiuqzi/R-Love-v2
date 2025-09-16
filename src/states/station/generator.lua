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
        local name = Templates.randomName(rng)
        local base = Templates.build(name, rng)
        -- Clonar shallow
        local r = {
            id = i,
            name = base.name,
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
        r.doors.left = { x = base.doors.left.x + xOffset, y = base.doors.left.y, w = base.doors.left.w, h = base.doors.left.h, side = 'left', to = nil }
        r.doors.right = { x = base.doors.right.x + xOffset, y = base.doors.right.y, w = base.doors.right.w, h = base.doors.right.h, side = 'right', to = nil }

        table.insert(rooms, r)
        xOffset = xOffset + base.width + 120 -- separación entre salas
    end

    -- Conectar en cadena: right i -> left i+1
    for i = 1, #rooms - 1 do
        rooms[i].doors.right.to = { roomId = i + 1, door = 'left' }
        rooms[i + 1].doors.left.to = { roomId = i, door = 'right' }
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
    local separation = opts.separation or 120
    local rng = SeedSystem.makeRNG(seed)

    local segments = {}
    local xOffset = 0
    local totalWidth = 0
    local maxHeight = 0

    for i = 1, count do
        local name = Templates.randomName(rng)
        local base = Templates.build(name, rng)
        local seg = {
            id = i,
            name = base.name,
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

    -- Construir zona única
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
    -- Meta al final de la zona (columna alta estilo compuerta)
    zone.goal = {
        x = zone.x + zone.width - 72,
        y = zone.y + zone.height - 56 - 80,
        w = 40,
        h = 80,
    }

    return { zone = zone, segments = segments, seed = seed, rng = rng }
end

-- Genera un grafo 2D con conexiones up/down/left/right, inspirado en la estructura de niveles de Metal Warriors
function Generator.generateGrid(opts)
    opts = opts or {}
    local seed = opts.seed or 0
    local rows = math.max(2, math.min(3, opts.rows or 3))
    local cols = math.max(3, math.min(5, opts.cols or 4))
    local separation = opts.separation or 120
    local rng = SeedSystem.makeRNG(seed)

    -- Random walk para definir celdas visitadas y asegurar conectividad
    local visited = {}
    for r=1,rows do visited[r] = {} end
    local function key(r,c) return r..":"..c end
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

    -- Elegir plantillas por celda según patrón de conexiones
    local bases = {}
    for _,cell in ipairs(cells) do
        local r,c = cell.r, cell.c
        local a = adj[key(r,c)]
        local name
        if (a.up or a.down) and not (a.left or a.right) then
            name = 'vertical_shaft'
        elseif (a.left or a.right) and not (a.up or a.down) then
            if rng:randomInt(1,3) == 1 then
                name = 'large_hangar'
            else
                name = Templates.randomName(rng)
            end
        else
            if rng:randomInt(1,2) == 1 then
                name = 'atrium_multi_tier'
            else
                name = Templates.randomName(rng)
            end
        end
        local base = Templates.build(name, rng)
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

    -- Offsets acumulados
    local xOffsets = {}
    local yOffsets = {}
    local acc = 0
    for c=1,cols do
        if colWidth[c] then
            xOffsets[c] = acc
            acc = acc + colWidth[c] + separation
        else
            xOffsets[c] = acc
            acc = acc + 600 + separation
        end
    end
    acc = 0
    for r=1,rows do
        if rowHeight[r] then
            yOffsets[r] = acc
            acc = acc + rowHeight[r] + separation
        else
            yOffsets[r] = acc
            acc = acc + 480 + separation
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