-- Dimensiones locales en píxeles nominales. El radio del hábitat es 100.
local Model = {}
local tau = 2 * math.pi
local colors = {
    iron={.18,.23,.29}, steel={.36,.44,.51}, panel={.67,.73,.74},
    ivory={.81,.83,.78}, joint={.105,.15,.20}, copper={.72,.42,.21},
    teal={.13,.40,.46}, glass={.17,.29,.36}, lamp={.48,.90,.93},
    amber={1,.62,.22}, ash={.35,.36,.38}, scar={.27,.21,.20},
}
local function polar(radius,angle,height)
    return {radius*math.cos(angle),radius*math.sin(angle),height}
end
function Model.build(state,part)
    local vertices={}
    local carrierPart=part=='carriers'
    local ruins=state=='ruins'
    local worn=state~='operational'
    local blank={0,0,0}
    local onCarrier=0
    local function triangle(a,b,c,color,ma,mb,mc)
        if (onCarrier==1)~=carrierPart then return end
        local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
        local vx,vy,vz=c[1]-a[1],c[2]-a[2],c[3]-a[3]
        local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
        local len=math.sqrt(nx*nx+ny*ny+nz*nz)
        if len<.00001 then return end
        local mat=colors[color]
        local function vertex(p,m)
            vertices[#vertices+1]={p[1],p[2],p[3],nx/len,ny/len,nz/len,
                mat[1],mat[2],mat[3],m[1],m[2],m[3],onCarrier}
        end
        vertex(a,ma or blank)
        vertex(b,mb or blank)
        vertex(c,mc or blank)
    end
    local function quad(a,b,c,d,color)
        triangle(a,b,c,color)
        triangle(a,c,d,color)
    end
    -- Extruded annular profiles. End caps remain visible at a hull breach.
    local function sector(a,b,profile)
        local left,right={},{}
        for k,p in ipairs(profile) do
            left[k],right[k]=polar(p[1],a,p[2]),polar(p[1],b,p[2])
        end
        for k,p in ipairs(profile) do
            local j=k%#profile+1
            quad(left[k],right[k],right[j],left[j],p[3])
        end
        for k=2,#profile-1 do
            triangle(left[1],left[k],left[k+1],'steel')
            triangle(right[1],right[k],right[k+1],'steel')
        end
    end
    local function band(a,b,inner,outer,z,h,color)
        sector(a,b,{{inner,z,color},{outer,z,color},{outer,z+h,color},{inner,z+h,color}})
    end

    -- A recessed belt of windows between the pressure hull and its lower lip.
    local count=40
    for i=0,count-1 do
        local a,b=tau*i/count,tau*(i+1)/count
        local breach=worn and (i==4 or i==5)
        local missing=ruins and (i>=3 and i<=8 or i>=19 and i<=24 or i>=31 and i<=33)
        if missing and (i==3 or i==8 or i==19 or i==24 or i==31 or i==33) then
            local tail=(i==8 or i==24 or i==33)
            local function stump(r,h,length,mat)
                local lo=tail and b-length or a
                band(lo,lo+length,r,r+1.6,h,1.6,mat)
            end
            stump(82,-5,.095,'steel')
            stump(93,3,.064,'copper')
            stump(88,-7,.128,'iron')
        end
        if not missing then
            -- Continuous runner on the inner wall, including across the damaged sector.
            band(a,b,77,80,1,2,breach and 'scar' or 'steel')
            if breach then
                band(a,b,81,84,-5,2,'scar')
                band(a,b,94,97,-6,1.7,'steel')
                band(a,a+.017,82,97,-5,3,'copper')
            else
                local skin=ruins and 'ash' or i%5==0 and 'ivory' or 'panel'
                sector(a+.002,b-.002,{
                    {79,-5,'iron'},{82,-9,'steel'},{97,-9,'steel'},{101,-5,'joint'},
                    {100,-2,'glass'},{100,3,'steel'},{99,7,skin},
                    {95,10,skin},{83,10,'steel'},{79,6,'iron'},
                })
                band(a+.011,b-.011,84,93,10,.7,i%5==0 and 'copper' or skin)
                band(a+.015,b-.015,94.4,95.8,10,.45,'steel')
                for j=0,2 do
                    local t=a+.019+.043*j
                    quad(polar(100.2,t,-1.5),polar(100.2,t+.025,-1.5),
                        polar(100.2,t+.025,1),polar(100.2,t,1),
                        ruins and 'joint' or worn and i%4==0 and 'amber' or 'lamp')
                end
                if i%5==2 then
                    for j=1,3 do
                        band(a+.027*j,a+.027*j+.013,85,91,10.75,.4,'iron')
                    end
                end
            end
        end
    end

    onCarrier=1
    for lane=1,4 do
        local angle=(lane-1)*tau/4+.72
        local co,si=math.cos(angle),math.sin(angle)
        local function point(r,w,h) return {r*co-w*si,r*si+w*co,h} end
        local function box(r,s,l,u,z,h,top,side)
            local a,b,c,d=point(r,l,h),point(s,l,h),point(s,u,h),point(r,u,h)
            quad(a,b,c,d,top)
            quad(point(r,l,z),point(s,l,z),b,a,side)
            quad(point(s,u,z),point(r,u,z),d,c,side)
            quad(point(r,u,z),point(r,l,z),a,d,side)
            quad(point(s,l,z),point(s,u,z),c,b,side)
        end
        local cut=(lane==1 and worn) or (lane==3 and ruins)
        local stop=cut and 47 or 84
        -- The second route coordinate wraps around the cylinder once.
        local function tube(start,finish,radius,material,route)
            local function rim(r,turn)
                local phi=tau*turn
                return point(r,radius*math.cos(phi),1+radius*math.sin(phi))
            end
            for i=0,11 do
                local v,w=i/12,(i+1)/12
                local a,b,c,d=rim(start,v),rim(finish,v),rim(finish,w),rim(start,w)
                if route then
                    local u0,u1=(start-18)/66,(finish-18)/66
                    triangle(a,b,c,material,{u0,v,lane},{u1,v,lane},{u1,w,lane})
                    triangle(a,c,d,material,{u0,v,lane},{u1,w,lane},{u0,w,lane})
                else
                    quad(a,b,c,d,material)
                end
                triangle(point(finish,0,1),c,b,'iron')
                triangle(point(start,0,1),a,d,'iron')
            end
        end
        tube(18,stop,3.1,ruins and 'ash' or 'steel',not cut and not ruins)
        tube(22,25,3.7,'iron')
        if cut then
            tube(stop-2,stop,3.5,'scar')
            tube(stop,stop+4,1.3,'steel')
            tube(30,37,3.5,ruins and 'iron' or 'copper')
        else
            tube(73,76,3.7,'iron')
            box(75,86,-5.7,5.7,-2,6,ruins and 'ash' or 'ivory','steel')
            box(77,82,-4,4,6,7,'teal','iron')
        end
    end
    onCarrier=0
    -- Transfer drum, clerestory, stepped roof and inset axial hatch.
    for i=0,15 do
        local a,b=tau*i/16,tau*(i+1)/16
        sector(a,b,{{.01,-7,'iron'},{20,-7,'steel'},{24,-3,'steel'},
            {24,7,'iron'},{22,10,'glass'},{22,15,'panel'},{19,18,'ivory'},
            {14,18,'steel'},{13,21,'teal'},{8,21,'joint'},{7,19,'iron'},{.01,19,'joint'}})
        if not ruins then
            band(a+.045,b-.04,22,22.25,10.8,2,worn and 'amber' or 'lamp')
        end
    end
    -- Raised control room overlooking the four departure bays.
    for i=0,7 do
        local a,b=tau*i/8,tau*(i+1)/8
        sector(a,b,{{.01,19,'iron'},{7,19,'steel'},{8,21,'steel'},
            {7.5,24,ruins and 'ash' or 'teal'},{6,26,'panel'},{.01,26,'steel'}})
    end
    for i=0,3 do
        local a,b=tau*i/4+.24,tau*i/4+.39
        band(a,b,15,17,18,1.2,worn and 'scar' or 'copper')
    end
    return love.graphics.newMesh({{'VertexPosition','float',3},{'FaceNormal','float',3},
        {'Material','float',3},{'Route','float',4}},vertices,'triangles','static')
end
return Model
