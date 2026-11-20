-- Local reflection from a sealed cargo capsule. All distances are world units.
local Local=require 'src.rendering.local_light'
local Light={}
Light.profiles={
    common={lanes=1,core=0xb4e2da,glow={.34,.71,.65},power=.50,radius=115},
    rare={lanes=2,core=0x99dbff,glow={.13,.47,1},power=.86,radius=145},
    exceptional={lanes=3,core=0xffe6a3,glow={1,.49,.10},power=1.12,radius=175},
}

function Light.sample(inspection,x,y,rotation)
    if not inspection then return end
    local best,dx,dy,profile=0
    for _,target in ipairs(inspection.targets) do
        local lamp=Light.profiles[target.rarity or target.id]
        if lamp and not inspection.run.lootRooms[target.id] then
            local vx,vy=target.x-x,target.y-y
            local power=Local.powerAt(vx,vy,lamp.radius,lamp.power)
            if power>best then best,dx,dy,profile=power,vx,vy,lamp end
        end
    end
    if not profile then return end
    return Local.toHull(dx,dy,rotation,profile.glow,best)
end

return Light
