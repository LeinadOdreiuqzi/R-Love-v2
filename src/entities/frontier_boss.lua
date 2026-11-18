local Boss = {}
Boss.__index = Boss
local health, beamLength = 680, 940
local Sight = require 'src.entities.combat_sight'
local Math = require 'src.utils.math_util'
local Rig = require 'src.rendering.ships.frontier_boss_rig'
local durations = {arrival=2.2, sweepWarning=1.3, sweep=2.5, chargeWarning=1.3,
    charge=1.1, brake=1.15, pinWarning=1.65, pin=2.1, recover=2.8, reposition=1.8}
local attackNames = {arrival='Interdicción de frontera', sweepWarning='Emisores · armando barrido',
    sweep='Barrido alterno', chargeWarning='Rompefilas · fijando rumbo', charge='Rompefilas',
    brake='Frenado · placas abiertas', pinWarning='Portón · proyectando anclajes', pin='Portón de interdicción',
    recover='Núcleo expuesto', reposition='Reposicionando emisores', pursuit='Aproximación de interdicción'}
local function smooth(t) t=Math.clamp(t,0,1);return t*t*(3-2*t) end
local function angleDelta(from,to) return (to-from+math.pi)%(2*math.pi)-math.pi end

function Boss.new(encounter)
    local ship=require('src.entities.naves'):new(encounter.spawn.x,encounter.spawn.y,'GUNSHIP')
    local facing=math.atan2(encounter.player.y-ship.y,encounter.player.x-ship.x)
    local self=setmetatable({encounter=encounter,ship=ship,phase='arrival',elapsed=0,time=0,
        step=0,enraged=false,hitCooldown=0,aim=facing,turnVelocity=0,moveX=0,moveY=0,
        armSpread=0,coreExposure=0,bank=0},Boss)
    ship.size,ship.worldScale=52,1
    ship.shipName,ship.isAI,ship.isAbandoned='El Portero',true,false
    ship.combatContext=encounter.player.combatContext
    ship.aiFaction='FRONTIER_PORTERO'
    ship.stats.health.maxHealth,ship.stats.health.currentHealth=health,health
    ship.stats.shield.maxShield,ship.stats.shield.currentShield=0,0
    ship.rotation,ship.prevRotation=facing+math.pi*.5,facing+math.pi*.5
    ship.engineGlow=0
    ship.aiController={active=true,combatTarget=encounter.player,role='WARDEN'}
    ship.takeDamage=function(_,amount,source) return self:takeDamage(amount,source) end
    return self
end

function Boss:takeDamage(amount,attacker)
    if self.dead then return true end
    local source=attacker and (attacker.owner or attacker)
    local ship=self.ship
    if self.phase=='arrival' or source~=self.encounter.player or source.combatContext~=ship.combatContext then return false end
    local protected=self.encounter:activeGuards()>0 and .45 or .65
    local multiplier=self.phase=='recover' and 1.65 or self.phase=='brake' and 1.25 or protected
    local died=ship.stats:takeDamage(math.max(0,amount)*multiplier)
    if ship.stats.health.currentHealth<=health*.5 and not self.enraged then
        self.enraged=true
        self.fractureTime=self.time
    end
    if died then
        self.dead,ship.isDestroyed,ship.aiController.active=true,true,false
        if source.abilitySystem then source.abilitySystem:onKill(ship) end
        self.encounter:onVictory()
    end
    return died
end

function Boss:aimAtPlayer()
    local player=self.encounter.player
    local target=player.abilitySystem and player.abilitySystem.decoy or player
    self.aim=math.atan2(target.y-self.ship.y,target.x-self.ship.x)
    self.cachedBeams=nil
end

function Boss:setPhase(phase)
    self.phase,self.elapsed,self.cachedBeams=phase,0,nil
    if phase=='chargeWarning' or phase=='sweepWarning' or phase=='pinWarning' then
        self.attackEnraged=self.enraged
    end
    if phase=='chargeWarning' or phase=='sweepWarning' then
        local facing=self.ship.rotation-math.pi*.5
        self.aim=facing+Math.clamp(angleDelta(facing,self.aim),-.9,.9)
    end
    if phase=='sweepWarning' then self.sweepSide=self.step%2==0 and 1 or -1 end
    if phase=='pinWarning' then
        local ship=self.ship
        local target=self.encounter.player.abilitySystem and self.encounter.player.abilitySystem.decoy or self.encounter.player
        -- Target velocity uses the ship simulation's 60-unit movement scale.
        local vx,vy=(target.dx or 0)*60,(target.dy or 0)*60
        local offsetX,offsetY=vx*.4,vy*.4
        local offset=math.sqrt(offsetX*offsetX+offsetY*offsetY)
        if offset>120 then offsetX,offsetY=offsetX*120/offset,offsetY*120/offset end
        self.gate={x=target.x+offsetX,y=target.y+offsetY,angle=self.aim}
    end
end

function Boss:nextAttack()
    local distance=Math.distance(self.ship.x,self.ship.y,self.encounter.player.x,self.encounter.player.y)
    if distance>620 then self:setPhase('pursuit');return end
    self.step=self.step+1
    self:aimAtPlayer()
    local attack
    if distance>420 then attack='pinWarning'
    elseif self.step%3==0 then attack='pinWarning'
    elseif distance>290 and self.lastAttack~='chargeWarning' then attack='chargeWarning'
    elseif distance<210 then attack='sweepWarning'
    elseif self.lastAttack=='sweepWarning' then attack='chargeWarning'
    else attack='sweepWarning' end
    self.lastAttack=attack
    self:setPhase(attack)
end

-- The two arm sockets are shared by the art, charge effects and damaging beams.
function Boss:emitter(side)
    return Rig.emitter(self.ship,self.armSpread,self.bank,side)
end

function Boss:beams()
    if self.cachedBeams then return self.cachedBeams end
    local phase,time=self.phase,self.elapsed
    local result={}
    local function segment(x,y,angle,length,active,side,kind,alpha)
        local origin={x=x,y=y}
        if active and not Sight.clear(origin,x+math.cos(angle)*length,y+math.sin(angle)*length) then
            local clear,blocked=0,length
            for _=1,7 do
                local distance=(clear+blocked)/2
                if Sight.clear(origin,x+math.cos(angle)*distance,y+math.sin(angle)*distance) then clear=distance
                else blocked=distance end
            end
            length=clear
        end
        result[#result+1]={x=x,y=y,endX=x+math.cos(angle)*length,endY=y+math.sin(angle)*length,
            active=active,side=side,kind=kind,alpha=alpha or 1}
    end
    if phase=='sweepWarning' or phase=='sweep' then
        local first=self.attackEnraged and 1 or self.sweepSide or -1
        for index=1,2 do
            local side=index==1 and first or (self.attackEnraged and 1 or -first)
            local direction=index==1 and first or -first
            local start=(index-1)*1.35
            local progress=phase=='sweep' and Math.clamp((time-start)/1.15,0,1) or 0
            local active=phase=='sweep' and time>=start and time<start+1.15
            if (phase=='sweepWarning' or time<start+1.15) and not (self.enraged and side==-1) then
                local x,y=self:emitter(side)
                segment(x,y,self.aim+direction*(.72-1.44*smooth(progress)),beamLength,active,side,'sweep',index==1 and 1 or .45)
            end
        end
    elseif (phase=='pinWarning' or phase=='pin') and self.gate then
        local gate=self.gate
        local progress=phase=='pin' and smooth(time/durations.pin) or 0
        local gap=220-(self.attackEnraged and 110 or 92)*progress
        local nx,ny=-math.sin(gate.angle),math.cos(gate.angle)
        for _,side in ipairs({-1,1}) do
            local outer=gap*.5+210
            local x,y=gate.x+nx*side*outer,gate.y+ny*side*outer
            segment(x,y,gate.angle-side*math.pi*.5,210,phase=='pin',side,'gate')
        end
    end
    self.cachedBeams=result
    return result
end

function Boss:manoeuvre(dt)
    local ship,player=self.ship,self.encounter.player
    local dx,dy=player.x-ship.x,player.y-ship.y
    local distance=math.max(1,math.sqrt(dx*dx+dy*dy))
    local phase=self.phase
    local side=self.step%2==0 and 1 or -1
    local radial=Math.clamp((distance-250)/180,-.35,1)
    local speed=170
    local lateral=side*(phase=='reposition' and .65 or .22)
    if phase=='arrival' then speed=45
    elseif phase=='recover' then speed=30
    elseif phase=='sweep' or phase=='pin' then speed=65
    elseif phase=='chargeWarning' then radial,lateral,speed=-.32,0,100 end
    local tx,ty=(dx/distance*radial-dy/distance*lateral)*speed,(dy/distance*radial+dx/distance*lateral)*speed
    local acceleration=phase=='charge' and 980 or 270
    if phase=='pursuit' then
        speed=Math.clamp(260+(distance-400)*.4,260,900)
        local lead=Math.clamp(distance/speed*.3,.15,.65)
        local lx,ly=dx+(player.dx or 0)*60*lead,dy+(player.dy or 0)*60*lead
        local leadDistance=math.max(1,math.sqrt(lx*lx+ly*ly))
        tx,ty=lx/leadDistance*speed,ly/leadDistance*speed
        acceleration=420
    elseif phase=='charge' then tx,ty=math.cos(self.aim)*640,math.sin(self.aim)*640
    elseif phase=='brake' then tx,ty=0,0;acceleration=510 end
    local vx,vy=tx-self.moveX,ty-self.moveY
    local change=math.sqrt(vx*vx+vy*vy)
    local blend=change>0 and math.min(1,acceleration*dt/change) or 0
    self.moveX,self.moveY=self.moveX+vx*blend,self.moveY+vy*blend
    local oldX,oldY=ship.x,ship.y
    local desiredX,desiredY=oldX+self.moveX*dt,oldY+self.moveY*dt
    ship.x,ship.y=self.encounter:constrain(ship,desiredX,desiredY)
    if math.abs(ship.x-desiredX)>1 then self.moveX=(ship.x-oldX)/dt end
    if math.abs(ship.y-desiredY)>1 then self.moveY=(ship.y-oldY)/dt end
    local heading=self.aim+math.pi*.5
    if phase=='arrival' or phase=='recover' or phase=='reposition' or phase=='pursuit' then heading=math.atan2(dy,dx)+math.pi*.5 end
    local error=angleDelta(ship.rotation,heading)
    local turnAcceleration=Math.clamp(error*7-self.turnVelocity*5,-3.2,3.2)
    self.turnVelocity=Math.clamp(self.turnVelocity+turnAcceleration*dt,-1.35,1.35)
    ship.rotation=ship.rotation+self.turnVelocity*dt
    local speedNow=math.sqrt(self.moveX^2+self.moveY^2)
    ship.engineGlow=ship.engineGlow+(math.min(.95,speedNow/540)-ship.engineGlow)*(1-math.exp(-7*dt))
    self.bank=self.bank+(-self.turnVelocity*.24-self.bank)*(1-math.exp(-5*dt))
    local spread=.06
    if phase=='recover' then spread=.38
    elseif phase=='chargeWarning' or phase=='charge' then spread=-.22
    elseif phase=='pinWarning' or phase=='pin' then spread=.30 end
    self.armSpread=self.armSpread+(spread-self.armSpread)*(1-math.exp(-5*dt))
    local exposure=phase=='recover' and 1 or phase=='brake' and .45 or 0
    self.coreExposure=self.coreExposure+(exposure-self.coreExposure)*(1-math.exp(-6*dt))
end

local function distanceToSegment(x,y,ax,ay,bx,by)
    local dx,dy=bx-ax,by-ay
    local t=Math.clamp(((x-ax)*dx+(y-ay)*dy)/math.max(1,dx*dx+dy*dy),0,1)
    return math.sqrt((x-ax-t*dx)^2+(y-ay-t*dy)^2)
end

function Boss:update(dt)
    if self.dead then return end
    local ship,player=self.ship,self.encounter.player
    ship:savePreviousState()
    ship:updateBurn(dt);ship:updateProjectiles(dt)
    if self.dead then return end
    self.elapsed,self.time=self.elapsed+dt,self.time+dt
    self.cachedBeams=nil
    self.hitCooldown=math.max(0,self.hitCooldown-dt)
    local phase=self.phase
    local tracking=phase=='chargeWarning' and self.elapsed<durations.chargeWarning-.5
        or phase=='sweepWarning' and self.elapsed<durations.sweepWarning-.45
    if tracking then
        local oldAim=self.aim
        self:aimAtPlayer()
        self.aim=oldAim+Math.clamp(angleDelta(oldAim,self.aim),-1.15*dt,1.15*dt)
    end
    local oldX,oldY=ship.x,ship.y
    self:manoeuvre(dt)
    if phase=='charge' and self.hitCooldown==0
        and distanceToSegment(player.x,player.y,oldX,oldY,ship.x,ship.y)<ship.size+player.size then
        player:takeDamage(18,ship,'collision');self.hitCooldown=.55
    end
    for _,beam in ipairs(self:beams()) do
        if beam.active and self.hitCooldown==0 and distanceToSegment(player.x,player.y,beam.x,beam.y,beam.endX,beam.endY)<=player.size+8 then
            player:takeDamage(8,ship);self.hitCooldown=.42
        end
    end
    local distance=Math.distance(ship.x,ship.y,player.x,player.y)
    if phase=='pursuit' then
        if distance<=390 then self:setPhase('reposition') end
        return
    end
    if phase=='reposition' and distance>620 then self:setPhase('pursuit');return end
    if self.elapsed<durations[phase] then return end
    if (phase=='sweepWarning' and distance>760) or (phase=='pinWarning' and distance>850)
        or (phase=='chargeWarning' and distance>780) then self:setPhase('pursuit');return end
    if phase=='reposition' and self.elapsed<durations.reposition+2.4 then
        local heading=math.atan2(player.y-ship.y,player.x-ship.x)+math.pi*.5
        if math.abs(angleDelta(ship.rotation,heading))>.2 then return end
    end
    if phase=='arrival' or phase=='reposition' then self:nextAttack()
    elseif phase=='recover' then self:setPhase('reposition')
    elseif phase=='sweepWarning' then self:setPhase('sweep')
    elseif phase=='chargeWarning' then self:setPhase('charge')
    elseif phase=='charge' then self:setPhase('brake')
    elseif phase=='pinWarning' then self:setPhase('pin')
    elseif phase=='brake' and self.enraged and distance<540 then self:aimAtPlayer();self:setPhase('sweepWarning')
    else self:setPhase('recover') end
end

function Boss:drawTelegraphs()
    local g=love.graphics
    g.push('all')
    for _,beam in ipairs(self:beams()) do
        if beam.active then
            local pulse=.75+.25*math.sin(self.time*8)^2
            g.setLineWidth(19);g.setColor(1,.18,.25,.16*pulse)
            g.line(beam.x,beam.y,beam.endX,beam.endY)
            g.setLineWidth(7);g.setColor(1,.38,.32,.95)
            g.line(beam.x,beam.y,beam.endX,beam.endY)
            local dx,dy=beam.endX-beam.x,beam.endY-beam.y
            local length=math.sqrt(dx*dx+dy*dy)
            if length>1 then
                g.setLineWidth(2);g.setColor(1,.88,.62,.85)
                for index=1,4 do
                    local t=(index*.25+self.time*1.4)%1
                    local tail=math.max(0,t-18/length)
                    g.line(beam.x+dx*tail,beam.y+dy*tail,beam.x+dx*t,beam.y+dy*t)
                end
            end
            g.setColor(1,.66,.30,.65)
            g.circle('fill',beam.x,beam.y,4)
        elseif beam.kind=='gate' then
            -- Only the charging anchors exist before firing: no future path or end markers.
            local charge=smooth(self.elapsed/durations.pinWarning)
            g.setColor(1,.59,.25,.2+.5*charge);g.setLineWidth(1.5)
            local spin=self.time*beam.side*2
            g.arc('line','open',beam.x,beam.y,12-5*charge,spin,spin+math.pi*1.5)
            g.circle('fill',beam.x,beam.y,2+charge)
        end
    end
    g.pop()
end
function Boss:drawHUD()
    local g=love.graphics
    local Theme=require 'src.ui.combat_theme';Theme.init()
    local width=math.min(440,g.getWidth()-60)
    local x=(g.getWidth()-width)/2
    g.push('all');g.setFont(Theme.title);g.setColor(.91,.88,.83)
    g.printf('EL PORTERO',x,18,width,'center')
    g.setColor(.14,.09,.12,.95);g.rectangle('fill',x,44,width,6)
    g.setColor(self.enraged and {1,.36,.30} or {.95,.65,.36})
    g.rectangle('fill',x,44,width*self.ship.stats.health.currentHealth/health,6)
    g.setFont(Theme.small)
    g.setColor(self.phase=='recover' and {.4,.93,1} or {.78,.81,.87})
    g.printf(attackNames[self.phase],x,57,width,'center')
    if self.encounter.supportWarning then
        g.setColor(1,.73,.34);g.printf('Desplegando escoltas',x,73,width,'center')
    elseif self.encounter:activeGuards()>0 then
        g.setColor(.45,.83,.95);g.printf('Escoltas enlazadas · blindaje reforzado',x,73,width,'center')
    end
    g.pop()
end
return Boss

