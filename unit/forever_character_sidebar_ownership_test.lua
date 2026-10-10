local Harness = dofile("tests/helpers/character_chrome_harness.lua")
local function read(path)
    local f = assert(io.open(path))
    local s = f:read("*a")
    f:close()
    return s
end
local function slice(source, first, last)
    local a = assert(source:find(first, 1, true))
    return source:sub(a, assert(source:find(last, a + 1, true)) - 1)
end
local source = read(arg[1] or "modules/skinning/character_pane/character.lua")
local nativeSource = read("tests/clients/forever/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua")
for _, forever in ipairs({ true, false }) do
    local h = Harness.Build()
    local character = h.BuildCharacterFrame()
    local stats = h.NewFrame("Frame", nil, character)
    local previous = h.NewFrame("Frame", nil, character)
    stats:Hide()
    local updates = 0
    local env = setmetatable({
        ns = { Client = { isForever = forever }, SafeCall = function(_, fn, ...) return pcall(fn, ...) end },
        PaperDollFrame = { currentSideBar = previous },
        PaperDollSidebarTab1 = {}, PAPERDOLL_SIDEBARS = { {} },
        GetPaperDollSideBarFrame = function() return stats end,
        PaperDollFrame_ShowSidebar = function() end,
        PaperDollFrame_UpdateSidebarTabs = function() updates = updates + 1 end,
        SetSidebarTabSelected = function(tab, selected) if tab then tab.selected = selected end end,
        UpdateSidebarTabBorder = function() end,
        SOUNDKIT = {}, PlaySound = function() end,
    }, { __index = _G })
    env._G = env
    local setter = assert(loadstring(slice(nativeSource, "function PaperDollFrame_SetSidebar(", "function PaperDollFrame_OnModelLoaded(")))
    setfenv(setter, env)()
    local chunk = assert(loadstring(slice(source, "local function SelectCharacterStatsSidebarTab()", "local characterFrameHooked =") .. "\nreturn SelectCharacterStatsSidebarTab"))
    setfenv(chunk, env)
    local selectStats = chunk()
    selectStats()
    if forever then
        assert(not stats:IsShown(), "collapsed Forever details must remain hidden")
        assert(env.PaperDollFrame.currentSideBar == previous, "addon OnShow must not rewrite native sidebar selection")
        assert(updates == 0 and env.PaperDollSidebarTab1.selected == nil, "native tab state must remain owned by FrameXML")
    else
        assert(stats:IsShown() and env.PaperDollFrame.currentSideBar == stats, "Retail stats selection must remain unchanged")
        assert(env.PaperDollSidebarTab1.selected == true, "Retail must still select the stats tab")
    end
end
print("OK: forever_character_sidebar_ownership_test")
