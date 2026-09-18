local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    return source
end

local function dependsOn(frame, target, seen)
    if frame == target then return true end
    if seen[frame] then return false end
    seen[frame] = true
    for _, point in pairs(frame.points) do
        if dependsOn(point[2], target, seen) then return true end
    end
    return false
end

local function frame()
    local value = { points = {}, width = 24, height = 24 }
    function value:GetWidth() return self.width end
    function value:GetHeight() return self.height end
    function value:ClearAllPoints() self.points = {} end
    function value:SetPoint(point, relative, relativePoint, x, y)
        assert(not dependsOn(relative, self, {}), "Cannot anchor to a region dependent on it")
        self.points[point] = { point, relative, relativePoint, x, y }
    end
    function value:SetShown(shown) self.shown = shown end
    return value
end

local hasPet = false
local pixelSize = 1
local world = setmetatable({
    QUICore = { GetPixelSize = function() return pixelSize end },
    CharacterFrame = frame(), PaperDollSidebarTabs = frame(),
    PaperDollSidebarTab1 = frame(), PaperDollSidebarTab2 = frame(), PaperDollSidebarTab3 = frame(),
    HasPetUI = function() return hasPet end,
}, { __index = _G })
world._G = world
world.PaperDollSidebarTabs:SetPoint("TOP", world.CharacterFrame, "TOPRIGHT", 0, 0)

local nativeSource = read("tests/clients/forever/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua")
local nativeStart = assert(nativeSource:find("function PaperDollFrame_UpdateSidebarTabLayout()", 1, true))
local nativeEnd = assert(nativeSource:find("function PaperDollFrame_UpdateSidebarTabs()", nativeStart, true))
local native = assert(loadstring(nativeSource:sub(nativeStart, nativeEnd - 1)))
setfenv(native, world)
native()

local source = read("modules/skinning/character_pane/character.lua")
local first = assert(source:find("local function StyleSidebarTabs()", 1, true))
local last = assert(source:find("local function GetItemQualityColorRGB", first, true))
local loader = assert(loadstring("local sidebarTabBaseWidth, sidebarTabBaseHeight\n"
    .. "local function StyleSidebarTab() end\n" .. source:sub(first, last - 1)
    .. "\nreturn StyleSidebarTabs"))
setfenv(loader, world)
local style = loader()

for _, pet in ipairs({ false, true, false, true }) do
    hasPet = pet
    pixelSize = pet and 0.75 or 1
    world.PaperDollFrame_UpdateSidebarTabLayout()
    assert(world.PaperDollSidebarTab3.shown == pet, "native pet-tab visibility must remain intact")
    style()
    local firstTab = world.PaperDollSidebarTab1.points.TOPLEFT
    assert(firstTab[2] == world.CharacterFrame and firstTab[4] == -74 and firstTab[5] == -40,
        "QUI sidebar tab placement must remain unchanged")
    local edge = world.PaperDollSidebarTabs.points.BOTTOMRIGHT
    assert(edge[2] == world.CharacterFrame and edge[4] == -26 + 24 * pixelSize
        and edge[5] == -40 - 24 * pixelSize, "container bounds must follow the pixel-scaled last tab")
    world.PaperDollFrame_UpdateSidebarTabLayout()
end

print("OK: native Forever sidebar relayout after QUI styling with and without a pet")
