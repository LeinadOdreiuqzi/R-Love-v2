-- Each horizontal slice has its own horizontal scale around the same optical axis.
local utf8 = require 'utf8'
local Glitch = {}
local rng
local symbols = "#%/+=?*<>:|"

local function burst(channel, text, font, now)
    rng = rng or love.math.newRandomGenerator(os.time())
    channel.text = text
    channel.font = font
    channel.started = now
    channel.duration = .14 + rng:random()*.04
    channel.nextAt = now + 3 + rng:random()*4
    channel.amount = .12 + rng:random()*.12
    channel.polarity = rng:random(0,1)*2-1
    channel.seam = .32 + rng:random()*.12
    channel.cells = {}
    local width = font:getWidth(text)
    local left = 0
    for pos, code in utf8.codes(text) do
        local after = utf8.offset(text,2,pos) or #text+1
        local right = font:getWidth(text:sub(1,after-1))
        if code > 32 and right > left then
            local id = rng:random(#symbols)
            local other = (id-1+rng:random(1,#symbols-1))%#symbols+1
            local distance = math.abs((left+right)/width-1)
            channel.cells[#channel.cells+1] = {
                center = (left+right)*.5, width = right-left,
                original = text:sub(pos,after-1),
                first = symbols:sub(id,id), second = symbols:sub(other,other),
                restore = .40 + distance*.39 + rng:random()*.09
            }
        end
        left = right
    end
end

function Glitch.print(channel,text,x,y,scale)
    local g = love.graphics
    scale = scale or 1
    local settings = package.loaded['src.ui.loading_screen']
    if settings and settings.config.reducedEffects then
        channel.text = nil
        g.print(text,x,y,0,scale,scale)
        return
    end
    local now, font = love.timer.getTime(), g.getFont()
    if channel.text ~= text or channel.font ~= font or now >= channel.nextAt then
        burst(channel,text,font,now)
    end
    local t = (now-channel.started)/channel.duration
    if t < 0 or t >= 1 or #channel.cells == 0 then
        g.print(text,x,y,0,scale,scale)
        return
    end

    local width, height = font:getWidth(text)*scale, font:getHeight()*scale
    local center = x+width*.5
    local envelope = math.sin(math.pi*t)^.7
    local stretch = channel.amount*channel.polarity*envelope*math.cos(1.65*math.pi*t)
    local seam = channel.seam+.055*math.sin(math.pi*2*t)
    -- Preserve parent clipping and pixel-align adjacent bands at compact UI scales.
    local function clipBand(top,bottom)
        local x1,y1 = g.transformPoint(x,y+height*top)
        local x2,y2 = g.transformPoint(x+width,y+height*bottom)
        x1,y1 = math.floor(x1+.5),math.floor(y1+.5)
        g.intersectScissor(x1,y1,math.floor(x2+.5)-x1,math.floor(y2+.5)-y1)
    end
    local function printBand(top,bottom,factor)
        g.push('all')
        clipBand(top,bottom)
        g.print(text,center-width*factor*.5,y,0,scale*factor,scale)
        g.pop()
    end

    printBand(0,seam,1+stretch)
    printBand(seam+.33,1,1-stretch*.85)
    g.push('all')
    clipBand(seam,seam+.33)
    local factor = 1-stretch*.45
    for _,cell in ipairs(channel.cells) do
        local glyph = cell.original
        if t < cell.restore then glyph = t < .27 and cell.first or cell.second end
        local glyphWidth = math.max(1,font:getWidth(glyph))
        local sx = scale*factor*math.min(1,cell.width/glyphWidth)
        local cx = center+(cell.center*scale-width*.5)*factor
        g.print(glyph,cx-glyphWidth*sx*.5,y,0,sx,scale)
    end
    g.pop()
end

return Glitch
