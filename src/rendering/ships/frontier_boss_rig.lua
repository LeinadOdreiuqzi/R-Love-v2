-- Shared sockets keep the articulated pixel hull and attack origins aligned.
local Rig={scale=1.45,pivot=15}
function Rig.bank(bank)
    local value=math.max(-1,math.min(1,(bank or 0)/.32))
    return math.max(-2,math.min(2,math.floor(value*2+.5)))/2
end
function Rig.project(x,y,bank)
    local side=x==0 and 0 or x>0 and 1 or -1
    return x*(1-.14*math.abs(bank)+.10*bank*side),y+bank*x*.32
end
function Rig.armPoint(side,spread,bank,x,y)
    local rootX,rootY=Rig.project(side*Rig.pivot,0,bank)
    x,y=Rig.project(x+side*Rig.pivot,y,bank)
    x,y=x-rootX,y-rootY
    local angle=side*(spread or 0)
    return rootX+x*math.cos(angle)-y*math.sin(angle),rootY+x*math.sin(angle)+y*math.cos(angle)
end
function Rig.emitter(ship,spread,bank,side,pose)
    pose=pose or ship
    bank=Rig.bank(bank)
    local localX,localY=Rig.armPoint(side,spread,bank,side*21.5,-22.5)
    local rotation=pose.rotation
    return pose.x+(localX*math.cos(rotation)-localY*math.sin(rotation))*Rig.scale,
        pose.y+(localX*math.sin(rotation)+localY*math.cos(rotation))*Rig.scale
end
return Rig
