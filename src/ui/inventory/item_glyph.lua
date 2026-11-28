-- Pixel silhouettes are drawn from the same masks in cargo, equipment and loot.
local masks = {
    kinetic = {"        ###", "   ###     ", " ##########", "###########", "## ###     ", "    ##     "},
    plasma = {"    ##  ## ", "   ########", " ###  ##  #", "###########", "##  ##  ## ", "    ##     "},
    energy = {"       ####", "   ######  ", "###########", " #######   ", "  ###      ", "  ##       "},
    explosive = {"    ####   ", " ######### ", "##  #######", " ######### ", "    ####   ", "   ##      "},
    consumable = {"   #####   ", "    # #    ", "   #####   ", "  ##   ##  ", "  #######  ", "   #####   "},
    material = {"    ###    ", "  ### ##   ", " ###   ##  ", " ######### ", "  #######  ", "    ###    "},
    passive = {"   # # #   ", "  #######  ", "###     ###", "  # ### #  ", "###     ###", "  #######  ", "   # # #   "},
    key = {"  ###      ", " ## ##     ", " ## #######", "  ###  # # ", "       #   "},
    equipable = {"    ###    ", "  #######  ", "  ##   ##  ", "  #######  ", "   #####   ", "    ###    "},
    valuable = {"    ###    ", "   ## ##   ", "  ##   ##  ", "  # ### #  ", "   ## ##   ", "    ###    "},
    schematic = {"  ######   ", "  #  # ##  ", "  #  ####  ", "  # ##  #  ", "  #   # #  ", "  #######  "},
    currency = {"    ###    ", "   #####   ", "  ## # ##  ", "  ## # ##  ", "   #####   ", "    ###    "},
    generic = {"   #####   ", "  ##   ##  ", "  # ### #  ", "  # ### #  ", "  ##   ##  ", "   #####   "}
}

local hullKit = {"   #####   ", "  ##   ##  ", " ######### ", " ##  #  ## ", " ## ### ## ", " ##  #  ## ", " ######### "}
local fuelTank = {"   ####    ", "   #  #    ", "  #######  ", "  ##   ##  ", "  ##  ###  ", "  ## ## #  ", "  #######  "}
local supplies = {
    repair_kit=hullKit, hull_kit_enhanced=hullKit, hull_kit_superior=hullKit,
    salvaged_fuel=fuelTank, enhanced_fuel=fuelTank
}

local function draw(data, x, y, size)
    local kind = data.damageType or data.category
    if data.id == 'salvage_room_key' then kind = 'key' end
    local mask = supplies[data.id] or masks[kind] or masks.generic
    local pixel = math.max(0.1, size/16)
    if pixel >= 1 then pixel = math.floor(pixel) end
    local left = math.floor(x+(size-11*pixel)/2)
    local top = math.floor(y+(size-#mask*pixel)/2)
    for row,line in ipairs(mask) do
        for start,run in line:gmatch('()(#+)') do
            love.graphics.rectangle('fill',left+(start-1)*pixel,top+(row-1)*pixel,#run*pixel,pixel)
        end
    end
end

return draw
