local g=love.graphics
local function ink(hex)
    local n=tonumber(hex,16)
    g.setColor(math.floor(n/65536)/255,math.floor(n/256)%256/255,n%256/255,1)
end
local function poly(hex,...) ink(hex); g.polygon('fill',...) end
local function oval(hex,x,y,rx,ry)
    ink(hex); g.ellipse('fill',x,y,rx,ry,64)
end
-- Fractures are drawn in the plane of the glass, so their silhouette
-- and interior ribs share the same foreshortening as the city.
local function fracture(x,y,r,ry,seed,wreck)
    local angle=({[23]=-.28,[67]=2.58,[11]=-.95,[80]=.62})[seed] or .62
    local co,si=math.cos(angle),math.sin(angle)
    local function trace(coords)
        local points={}
        for i=1,#coords,2 do
            local u,v=coords[i],coords[i+1]
            points[#points+1]=x+r*(u*co-v*si)
            points[#points+1]=y+ry*(u*si+v*co)
        end
        return points
    end
    local function patch(col,coords)
        ink(col);g.polygon('fill',trace(coords))
    end
    local function seam(col,coords)
        ink(col);g.line(trace(coords))
    end
    if wreck then
        -- Cut through the rim, leaving sky between torn ribs.
        g.setBlendMode('replace','premultiplied')
        g.setColor(0,0,0,0)
        g.polygon('fill',trace({.33,-.53,1.28,-.71,1.3,.70,.51,.51,.60,.23,.30,.09,.45,-.15}))
        g.setBlendMode('alpha','alphamultiply')
        patch('293637',{.02,-.32,.33,-.53,.45,-.15,.30,.09,.60,.23,.51,.51,.16,.34})
        patch('616963',{.16,.34,.51,.51,.60,.23,.46,.30,.27,.22})
        patch('94795c',{.36,-.49,.98,-.57,.87,-.48,.39,-.39})
        patch('787e70',{.49,.23,.86,.27,.77,.36,.54,.33})
        seam('41494a',{.50,.29,.64,.53,.76,.58,.84,.52})
        seam('b0a88a',{.05,-.34,.24,-.47,.33,-.53})
    else
        -- A missing outer pane breaks the contour even at approach zoom.
        g.setBlendMode('replace','premultiplied')
        g.setColor(0,0,0,0)
        g.polygon('fill',trace({.68,-.26,1.24,-.38,1.26,.32,.79,.21,.86,.04,.70,-.03}))
        g.setBlendMode('alpha','alphamultiply')
        patch('465956',{.03,-.46,.44,-.56,.83,-.24,.76,.15,.85,.32,.51,.56,.20,.31,.31,.10})
        patch('29383b',{.12,-.37,.43,-.46,.74,-.21,.64,.10,.73,.24,.51,.42,.31,.24,.39,.04})
        for j=0,2 do
            local v=-.24+j*.21
            seam('807a65',{.27,v,.45,v+.06,.50,v+.02,.65,v+.06})
        end
        patch('a8c6ac',{.03,-.46,.34,-.39,.28,-.19})
        seam('dadab1',{.75,.15,.85,.32,.66,.43})
        seam('6a7771',{.34,-.48,.23,-.67,.09,-.60,-.05,-.80})
        seam('ebdfb7',{.21,.31,.08,.42,.01,.37,-.15,.56})
        seam('71857c',{.08,.42,.07,.65,-.02,.73})
        patch('e2a85f',{.43,.30,.52,.33,.49,.41,.40,.37})
    end
end
local function pod(x,y,r,seed,damage)
    local ry=r*.335
    oval('182a34',x,y+2,r+1,ry+1)
    oval('466366',x,y+1,r,ry)
    oval('a3b09b',x,y,r,ry)
    local cy=y-r*.055
    oval('638e8a',x,cy,r-.8,ry)
    oval(damage==2 and '829b92' or 'acd1af',x,cy-1,r-2,ry-1)
    local rng=love.math.newRandomGenerator(seed)
    -- Wide avenues divide grouped silhouettes into miniature neighbourhoods.
    for row=-8,8 do
        for col=-24,24 do
            local u=col/24+rng:random()*.027
            local v=row/9+rng:random()*.075
            if u*u+v*v<.86 and math.abs(math.sin(u*6+v*3))>.21 and math.abs(v+.24*u)>.07 then
                local bx,by=x+u*r,cy+v*ry
                local w=r*(.012+.022*rng:random())
                local h=r*(.018+.07*rng:random())*(1-.55*(u*u+v*v))
                poly(damage==2 and '52635f' or v<-.18 and '88ac9b' or '6d9991',bx,by,bx,by-h,bx+w,by-h-.5,bx+w,by)
                poly(damage==2 and '939c87' or 'c3d9b5',bx+w,by-h-.5,bx+w+1,by-h,bx+w+1,by,bx+w,by)
            end
        end
    end
    -- Meridians bend from the crown socket to the outer pressure seal.
    local hx,hy=x-r*.05,y-ry*.55
    for k=0,5 do
        local a=k*math.pi/3+.20
        local ex,ey=x+r*.98*math.cos(a),cy+ry*.98*math.sin(a)
        local pts={}
        for j=0,12 do
            local t=j/12
            pts[#pts+1]=hx+(ex-hx)*t
            pts[#pts+1]=hy+(ey-hy)*t-math.sin(math.pi*t)*r*.087
        end
        ink('536c65'); g.setLineWidth(math.max(1,r*.025)); g.line(pts)
        ink('e1dfb2'); g.setLineWidth(1); g.line(pts)
    end
    oval('405854',hx,hy,r*.25,ry*.29)
    oval(damage==2 and '70766b' or 'ddd9a9',hx,hy-1,r*.235,ry*.25)
    oval(damage==2 and '485854' or 'a7c7a5',hx,hy-.8,r*.194,ry*.18)
    for j=0,7 do
        local a=.28+j*.36
        local px=x+math.cos(a)*r*.97
        local py=y+math.sin(a)*ry
        ink(damage==2 and '515d59' or j%3==0 and 'd3f0d1' or '607a79'); g.rectangle('fill',px,py,2,1)
    end
    if damage>0 then fracture(x,cy,r,ry,seed,damage==2) end
end

-- Cache the approved glasswork independently of the large hull orientation.
local sprites={}
local function dome(radius,seed,damage)
    local key=seed*3+damage
    if sprites[key] then return sprites[key] end
    local w,h=radius*2+6,math.ceil(radius*.9)+8
    local c=g.newCanvas(w,h,{dpiscale=1})
    c:setFilter('nearest','nearest')
    g.push('all')
    g.reset()
    g.setCanvas(c)
    g.clear(0,0,0,0)
    g.setLineStyle('rough')
    pod(w/2,h/2,radius,seed,damage)
    g.pop()
    sprites[key]=c
    return c
end
return dome
