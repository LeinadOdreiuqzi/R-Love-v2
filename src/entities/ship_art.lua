-- Original fleet liveries. Geometry is authored at unit hull size and cached as
-- one colored mesh per chassis; propulsion still follows the ship's live state.
local Art = {}
local designs, meshes = {}, {}
local graphite, seam = 0x151d2c, 0x303b4c
local silver, frost = 0xb7c9df, 0xe3f0ff

local function builder()
    local vertices = {}
    local function face(color, ...)
        local r = math.floor(color / 65536) / 255
        local g = math.floor(color / 256) % 256 / 255
        local b = color % 256 / 255
        for _, tri in ipairs(love.math.triangulate({...})) do
            for i = 1, 6, 2 do
                vertices[#vertices + 1] = {tri[i], tri[i+1], 0, 0, r, g, b, 1}
            end
        end
    end
    local function stroke(color, width, x, y, x2, y2)
        local dx, dy = x2 - x, y2 - y
        local k = width * .5 / math.sqrt(dx*dx + dy*dy)
        local nx, ny = -dy*k, dx*k
        face(color, x+nx,y+ny, x2+nx,y2+ny, x2-nx,y2-ny, x-nx,y-ny)
    end
    local function band(color, x, y, w, h)
        face(color, x,y, x+w,y, x+w,y+h, x,y+h)
    end
    return vertices, face, stroke, band
end

designs.EXPLORER = function(f, s)
    -- Long survey lance; the outer foils float off the central spine.
    f(graphite, 0,-1.94, .40,-.72, .38,.96, 0,1.12, -.38,.96, -.40,-.72)
    for _, side in ipairs({-1,1}) do
        f(seam, side*.24,-.42, side*.74,-.30, side*1.27,.69, side*.90,.85, side*.33,.62)
        f(side<0 and 0x66a8f3 or 0x3b6ac1, side*.58,-.50, side*1.22,.39, side*1.38,.91,
            side*.92,.71, side*.55,.23)
        f(0xb8defe, side*.58,-.50, side*.99,.22, side*.73,.15)
        s(0x83f5ff,.065,side*.96,.57,side*1.22,.79)
    end
    f(silver, 0,-1.89, .27,-.67, .20,.66, -.03,.86, -.29,.59, -.29,-.58)
    f(0x6b8db8, 0,-1.89, .27,-.67, .20,.66, 0,.81)
    f(graphite, 0,-1.15, .21,-.56, .10,-.14, -.15,-.21, -.20,-.55)
    f(0x44d4f5, -.02,-1.03, .10,-.57, .04,-.31, -.12,-.51)
    s(frost,.05,0,-1.7,-.15,-.91)
    s(0x3685bc,.12,-.15,.56,.15,.56)
end

designs.FIGHTER = function(f, s)
    -- Split red blades, twin exhausts and a narrow amber pilot cell.
    f(graphite, 0,-1.87, .48,-.46, .39,.94, 0,.75, -.39,.94, -.48,-.46)
    for _, side in ipairs({-1,1}) do
        f(0x333b4b, side*.25,-.39, side*1.05,-.27, side*1.55,.54, side*1.11,.94, side*.36,.72)
        f(side<0 and 0xdb4147 or 0xa52639, side*.53,-.48, side*1.53,.54, side*1.22,.53,
            side*.89,.29, side*.60,.42)
        f(0x9aa5b6, side*.88,.50, side*1.26,.60, side*1.12,.81, side*.84,.74)
        f(0x151d26, side*.29,.42, side*.68,.58, side*.63,1.12, side*.31,1.12)
        s(0xff8155,.10,side*.34,1.05,side*.59,1.05)
        s(0xf1c1a1,.07,side*1.19,.26,side*1.34,.43)
    end
    f(0x8897ac, 0,-1.82, .25,-.40, .22,.48, -.22,.48, -.27,-.40)
    f(0x4b5262, 0,-1.82, .25,-.40, .22,.48, .03,.64)
    f(0xf9ad50, -.025,-1.23, .14,-.61, 0,-.33, -.14,-.56)
    s(0xffd99a,.05,-.025,-1.07,-.08,-.66)
end

designs.INTERCEPTOR = function(f, s)
    -- Retain the forward-swept blades and keep daylight beside the pilot cell.
    for _, side in ipairs({-1,1}) do
        f(0x1a172c, side*.17,.43, side*.42,.13, side*.82,-.73, side*.97,-.51,
            side*1.00,-.05, side*.73,.93, side*.52,.67)
        f(side<0 and 0x605478 or 0x45395d, side*.40,.38, side*.83,-.66, side*.91,-.48,
            side*.93,-.04, side*.73,.78, side*.57,.54)
        f(0x322744, side*.47,.33, side*.84,-.30, side*.95,-.19, side*.70,.66)
        -- Separate blade module on a narrow spar. Leave open space on both sides of the joint.
        f(0x312941, side*.91,-.47, side*1.23,-.53, side*1.23,-.41, side*.95,-.33)
        s(0x796a91,.038,side*.97,-.41,side*1.16,-.46)
        f(0x211931, side*1.06,-1.02, side*1.45,-.50, side*1.18,-.22, side*1.11,-.44)
        f(0xb45df2, side*1.08,-.98, side*1.42,-.50, side*1.20,-.29, side*1.15,-.47)
        s(0xe5adff,.062,side*1.11,-.89,side*1.34,-.51)
        s(0x9a82b1,.054,side*.46,.44,side*.74,.71)
        s(0x674996,.06,side*.73,.23,side*.86,.03)
    end
    f(0x252136, 0,-2.17, .27,-.91, .38,.17, .32,.86, .21,1.11, -.21,1.11, -.32,.86, -.38,.17, -.27,-.91)
    f(0x867d9e, 0,-2.13, -.20,-.87, -.28,.14, -.22,.86, 0,.72)
    f(0x544a70, 0,-2.13, .20,-.87, .28,.14, .22,.86, 0,.72)
    f(0x21172f, 0,-1.61, .19,-.50, .12,-.11, 0,.02, -.12,-.11, -.19,-.50)
    f(0xe14bbd, 0,-1.48, .12,-.49, 0,-.20, -.12,-.49)
    s(0xffbbe9,.048,-.025,-1.29,-.075,-.57)
    f(0x1a172c, -.19,.55, .19,.55, .16,1.06, -.16,1.06)
    s(0xe0a0ff,.092,-.12,.98,.12,.98)
end

designs.CARGO = function(f, s, box)
    -- A pressure cabin ahead of the two separate industrial freight racks.
    f(graphite, -.64,-1.26, .61,-1.26, 1.01,-.72, .92,1.10, .46,1.40, -.52,1.40, -1.03,.93, -1.06,-.68)
    f(0x758593, -.58,-1.22, .57,-1.22, .77,-.81, .38,-.46, -.39,-.46, -.78,-.81)
    f(0x294454, -.44,-1.09, .41,-1.09, .51,-.87, -.51,-.87)
    s(0x8ce9d1,.075,-.39,-.92,.36,-.92)
    f(0x4e5b67, -.33,-.57, .33,-.57, .34,1.12, .05,1.28, -.34,1.12)
    for _, side in ipairs({-1,1}) do
        f(0x536273, side*.31,-.69, side*1.02,-.60, side*1.36,-.20, side*1.29,.90, side*.88,1.21, side*.34,1.10)
        f(0xa97530, side*.44,-.54, side*1.01,-.48, side*1.17,-.19, side*1.10,.80, side*.44,.98)
        for row=0,2 do
            local y=-.35+row*.38
            box(0xe3a94e,side<0 and -1.04 or .51,y,.53,.24)
            s(0xffcf72,.046,side*.53,y+.035,side*1.0,y+.035)
        end
        s(0x324654,.10,side*.44,-.52,side*.44,1.02)
        s(0x6bffe2,.085,side*.73,1.13,side*.91,1.08)
    end
    s(0xffcf71,.15,-.27,-.68,.27,-.68)
    s(0x7ff4de,.10,-.17,1.22,.17,1.22)
end

designs.GUNSHIP = function(f, s, box)
    -- Armored shoulders leave a channel down each cannon barrel.
    f(0x322832, -.64,-1.24, .64,-1.24, 1.29,-.34, 1.20,1.08, .67,1.22, -.67,1.22, -1.20,1.08, -1.29,-.34)
    for _, side in ipairs({-1,1}) do
        f(0x605059, side*.42,-.77, side*1.11,-.70, side*1.33,-.17, side*1.14,.87, side*.52,.94)
        f(0x8e655d, side*.51,-.69, side*1.08,-.58, side*1.22,-.15, side*.72,-.22)
        f(0x191e2a, side*.69,-1.59, side*.99,-1.59, side*1.0,.57, side*.70,.78)
        s(0xb59da1,.08,side*.79,-1.50,side*.79,.39)
        for y=-.45,.52,.31 do
            s(0x493335,.095,side*.78,y,side*1.01,y+.04)
        end
        s(0xff723f,.10,side*.75,-1.34,side*.95,-1.34)
    end
    f(0x977d6f, -.44,-1.12, .44,-1.12, .54,.67, .28,1.04, -.31,1.04, -.54,.62)
    f(0x524146, 0,-1.12, .44,-1.12, .54,.67, .28,1.04, 0,.83)
    f(0xff985d, -.34,-.79, .34,-.79, .18,-.52, -.21,-.52)
    box(0x382932,-.24,.02,.48,.41)
    s(0xffc57a,.06,-.16,.13,.14,.13)
end

designs.SALVAGER = function(f, s, box)
    -- A complete tug chassis first, with the salvage rig carried on its shoulders.
    f(0x243632, -.50,-1.40, .49,-1.40, .73,-.92, .73,-.38, 1.13,-.16, 1.16,.86,
        .89,1.15, -.89,1.15, -1.16,.86, -1.13,-.16, -.73,-.38, -.73,-.92)
    for _, side in ipairs({-1,1}) do
        f(0x4e6255, side*.56,-.41, side*1.02,-.29, side*1.20,.12, side*1.12,.88,
            side*.81,1.17, side*.50,.97)
        f(0x718273, side*.58,-.28, side*.96,-.21, side*1.08,.08, side*.64,.21)
        f(0x172823, side*.58,.43, side*.99,.36, side*.98,.92, side*.68,1.05, side*.56,.89)
        s(0x80b69b,.064,side*.68,.58,side*.90,.58)
        s(0x85f5c4,.113,side*.66,1.03,side*.88,1.03)
    end
    f(0x798a71, -.43,-1.36, .43,-1.36, .65,-.91, .49,-.33, -.49,-.33, -.65,-.91)
    f(0x516a5e, -.56,-.85, .56,-.85, .43,-.36, -.43,-.36)
    f(0x193b38, -.39,-1.15, .37,-1.15, .48,-.89, .29,-.73, -.28,-.73, -.48,-.89)
    f(0x56af9f, -.32,-1.08, .32,-1.08, .38,-.92, -.38,-.92)
    s(0xa0f9d7,.055,-.30,-1.055,.30,-1.055)
    f(0x3e5447, -.44,-.34, .44,-.34, .48,.78, .26,1.02, -.26,1.02, -.48,.78)
    box(0x263b33,-.34,-.18,.68,.79)
    for y=-.11,.46,.18 do s(0x718777,.074,-.26,y,.26,y) end
    s(0xe8b452,.094,-.30,.70,.30,.70)
    -- Port sensor bar and a braced cutter on the other side.
    f(0x9a7838, -.66,-.26, -1.06,-.39, -1.05,-.97, -.78,-1.04, -.74,-.53)
    s(0xffd678,.092,-.96,-.91,-.80,-.95)
    f(0x7c6240, .59,-.24, 1.12,-.34, 1.32,-1.14, .99,-1.32, .85,-.69, .69,-.53)
    f(0xc39a51, .92,-.66, 1.18,-.59, 1.29,-1.15, 1.03,-1.27)
    s(0xf8cf7a,.063,1.03,-1.20,.96,-.79)
    f(0xb28a45, .96,-1.14, 1.28,-1.10, 1.33,-1.45, 1.24,-1.55, 1.16,-1.28,
        1.05,-1.28, 1.03,-1.54, .92,-1.49)
    s(0xffd678,.067,.94,-1.48,1.02,-1.51)
    s(0xffd678,.067,1.25,-1.51,1.31,-1.45)
    s(0x5a4c38,.07,1.00,-.86,1.19,-.81)
end

designs.SENTINEL = function(f, s)
    -- An iris contained by four independent pieces of a diamond frame.
    f(0x20354d, 0,-1.38, .78,-.21, .51,.68, 0,1.09, -.51,.68, -.78,-.21)
    for _, side in ipairs({-1,1}) do
        f(side<0 and 0xd0e1ed or 0x7c9bb9, 0,-1.72, side*1.33,.01, side*.89,.25, side*.51,-.02, 0,-.86)
        f(side<0 and 0x8eaac2 or 0x577390, side*1.33,.12, side*.80,.61, 0,1.61, 0,1.05, side*.55,.36)
        s(0x6af6f3,.085,side*.24,-1.20,side*.79,-.50)
        s(0xdef6ff,.045,side*.98,.16,side*.70,.52)
    end
    f(0x153543, 0,-.58, .50,-.27, .55,.33, 0,.62, -.55,.33, -.50,-.27)
    f(0x46c9dc, 0,-.43, .36,-.14, .35,.27, 0,.46, -.35,.27, -.36,-.14)
    f(0xc8ffff, 0,-.34, .20,-.13, .12,.10, -.16,.16, -.24,-.12)
end

designs.TITAN_EXCAVATOR = function(f, s, box)
    -- The jaw surrounds an exposed ore channel.
    f(0x213431, -.90,-.70, .90,-.70, 1.25,-.04, 1.24,.97, .84,1.26, -.85,1.26, -1.24,.91, -1.25,-.05)
    f(0x5c6c5b, -.60,-.76, .60,-.76, .75,.15, .63,1.06, -.63,1.06, -.76,.15)
    f(0x203d35, -.41,-.91, .41,-.91, .46,.34, -.46,.34)
    for _, side in ipairs({-1,1}) do
        f(0x695744, side*.56,-.59, side*.68,-1.50, side*1.05,-1.75, side*1.27,-1.43, side*1.34,.16, side*.99,.90, side*.58,.60)
        f(0xc09a4a, side*.70,-1.43, side*1.05,-1.71, side*1.20,-1.41, side*1.20,-.71, side*.75,-.73)
        for y=-1.37,-.72,.22 do
            s(0x4d4937,.10,side*.76,y+.12,side*1.14,y)
        end
        f(0x768574, side*.89,.07, side*1.24,.08, side*1.08,.66, side*.79,.62)
        s(0x87f2a3,.085,side*.82,.71,side*1.08,.75)
    end
    for y=-.74,.12,.25 do box(0x5ca66b,-.32,y,.64,.09) end
    f(0x78eaa0, 0,.27, .35,.53, .25,.90, -.26,.90, -.35,.53)
    f(0x163b37, 0,.39, .21,.57, .15,.79, -.16,.79, -.21,.57)
end

designs.ECLIPSE = function(f, s, box)
    -- Twin forward prongs frame a central hangar and a lit runway.
    f(0x27213b, -.44,-1.91, -.17,-1.74, -.10,-.64, .10,-.64, .17,-1.74, .44,-1.91,
        .59,-.40, 1.24,.35, 1.17,1.04, .56,1.31, -.56,1.31, -1.17,1.04, -1.24,.35, -.59,-.40)
    for _, side in ipairs({-1,1}) do
        f(side<0 and 0x6c547e or 0x4d385f, side*.39,-1.88, side*.60,-.58, side*1.28,.33, side*1.17,1.01, side*.45,1.18, side*.27,.40)
        f(0xb34261, side*.81,-.28, side*1.28,.33, side*1.10,.70, side*.70,.45)
        s(0xf783b4,.08,side*.79,-.19,side*1.17,.31)
        s(0x9c6bc5,.095,side*.40,-1.58,side*.50,-.77)
        s(0x392c53,.14,side*.54,.56,side*.87,.97)
    end
    f(0x9387a6, -.18,-.61, .18,-.61, .26,.79, .20,1.13, -.20,1.13, -.26,.79)
    f(0x29233e, -.11,-.56, .11,-.56, .16,.81, -.16,.81)
    for y=-.45,.70,.23 do box(0xe88de9,-.055,y,.11,.085) end
    f(0xffa5e2, 0,-.79, .16,-.53, 0,-.35, -.16,-.53)
    s(0xdebcf0,.07,-.15,.95,.15,.95)
end

designs.ARK_MONOLITH = function(f, s)
    -- Cut gold ring around a cold reactor. Keep open gaps between the spires.
    local ring = 1.14
    for i=0,11 do
        if i%3~=0 then
            local a,b=i*math.pi/6+.045,(i+1)*math.pi/6-.045
            local ca,sa,cb,sb=math.cos(a),math.sin(a),math.cos(b),math.sin(b)
            f(i%2==0 and 0xb89555 or 0xe6c983, ca*ring,sa*ring,cb*ring,sb*ring,
                cb*(ring-.12),sb*(ring-.12),ca*(ring-.12),sa*(ring-.12))
        end
    end
    for i=0,3 do
        local a=i*math.pi/2
        local function shard(color, ...)
            local xy={...}
            for j=1,#xy,2 do
                local x,y=xy[j],xy[j+1]
                xy[j],xy[j+1]=x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a)
            end
            f(color,unpack(xy))
        end
        local tip=i==0 and 1.78 or i==2 and 1.57 or 1.39
        shard(0x7b9aab, 0,-tip,.30,-.83,.28,-.48,0,-.33,-.28,-.48,-.30,-.83)
        shard(0xe0ebed, 0,-tip, .02,-.43, -.28,-.48, -.30,-.83)
        shard(0x4ed5e3, 0,-1.03,.082,-.66,0,-.52,-.085,-.66)
    end
    f(0x1d3347, 0,-.62,.49,-.34,.53,.28,0,.65,-.53,.28,-.49,-.34)
    f(0x59d8e0, 0,-.44,.36,-.22,.39,.20,0,.47,-.39,.20,-.36,-.22)
    f(0xd3fcff, 0,-.35,.26,-.16,.11,.19,-.23,.14,-.25,-.13)
end
designs.DREADNOUGHT = designs.ECLIPSE

local engines = {
    EXPLORER = {{0,1,.38}}, FIGHTER = {{-.45,1.07,.29},{.45,1.07,.29}},
    CARGO = {{-.83,1.17,.29},{0,1.31,.35},{.83,1.17,.29}},
    INTERCEPTOR = {{0,1.07,.46}},
    GUNSHIP = {{-.68,1.1,.40},{.68,1.1,.40}}, SALVAGER = {{-.77,1.08,.34},{.77,1.08,.34}},
    SENTINEL = {{0,1.31,.32}}, TITAN_EXCAVATOR = {{-.84,1.08,.34},{-.32,1.24,.40},{.32,1.24,.40},{.84,1.08,.34}},
    ECLIPSE = {{-.82,1.06,.35},{0,1.12,.48},{.82,1.06,.35}}, ARK_MONOLITH = {{0,1.46,.47}}
}
engines.DREADNOUGHT = engines.ECLIPSE
local drive = {FIGHTER={1,.31,.20}, INTERCEPTOR={.87,.26,1}, GUNSHIP={1,.42,.22}, SALVAGER={.48,1,.65},
    TITAN_EXCAVATOR={.43,1,.56}, ECLIPSE={.8,.27,1}, DREADNOUGHT={.8,.27,1}}
local defaultDrive = {.28,.87,1}
local beacons = {
    EXPLORER={{-.99,.51,.32,.92,1}},
    FIGHTER={{-1.36,.57,1,.28,.23},{1.36,.57,.35,.95,.51}},
    CARGO={{-.88,1.07,.40,1,.78},{.88,1.07,.40,1,.78}},
    INTERCEPTOR={{-1.22,-.52,.81,.43,1},{1.22,-.52,.81,.43,1}},
    GUNSHIP={{-.85,-1.31,1,.54,.28},{.85,-1.31,1,.54,.28}},
    SALVAGER={{1.23,-1.41,1,.76,.31}}, SENTINEL={{0,-.06,.52,.98,1}},
    TITAN_EXCAVATOR={{0,.59,.44,1,.61}},
    ECLIPSE={{0,-.55,.99,.53,.86}}, ARK_MONOLITH={{0,0,.53,.98,1}}
}
beacons.DREADNOUGHT = beacons.ECLIPSE

function Art.draw(ship, size, abandoned)
    local id = ship.shipType
    local design = designs[id]
    if not design then return false end
    local g = love.graphics
    if not meshes[id] then
        local vertices, face, stroke, band = builder()
        design(face, stroke, band)
        meshes[id] = g.newMesh(vertices, 'triangles', 'static')
    end
    if not abandoned and (ship.engineGlow or 0) > 0 and (not ship.stats or ship.stats:canMove()) then
        for _, nozzle in ipairs(engines[id]) do
            ship:drawThrusterFlame(nozzle[1]*size, nozzle[2]*size, nozzle[3]*size, drive[id] or defaultDrive)
        end
    end
    local light = abandoned and .60 or 1
    g.setColor(light, light, light, 1)
    g.draw(meshes[id], 0, 0, 0, size, size)
    if abandoned then
        g.setColor(1,.24,.20,.42 + .40 * math.sin(love.timer.getTime() * 4)^2)
        g.circle('fill',0,-size*.25,math.max(1,size*.095),8)
    else
        local phase = love.timer.getTime() * 3 + (ship.shipId or 0)
        local intensity = .62 + .31 * math.sin(phase)^2
        for _, beacon in ipairs(beacons[id]) do
            g.setColor(beacon[3], beacon[4], beacon[5], intensity)
            g.circle('fill', beacon[1]*size, beacon[2]*size, math.max(.55,size*.074), 8)
        end
    end
    return true
end

return Art
