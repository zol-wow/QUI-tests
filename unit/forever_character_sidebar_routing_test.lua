local Harness = assert(loadfile("tests/helpers/character_chrome_harness.lua"))()
local function read(path)
    local file = assert(io.open(path, "r"))
    local text = file:read("*a")
    file:close()
    return text
end
local source = read(arg[1] or "modules/skinning/character_pane/character.lua")
local function slice(text, first, after)
    local start = assert(text:find(first, 1, true), first)
    local finish = assert(text:find(after, start + #first, true), after)
    return text:sub(start, finish - 1)
end
for _, forever in ipairs({ true, false }) do
    local harness = Harness.Build()
    local character = harness.BuildCharacterFrame()
    local function frame() return harness.NewFrame("Frame", nil, character) end
    local native, pet, panel, equipment, titles = frame(), frame(), frame(), frame(), frame()
    local equipmentPopup, titlesPopup = frame(), frame()
    local enabled, renders = true, 0
    equipment:Hide()
    titles:Hide()
    pet:Hide()
    equipmentPopup:Hide()
    titlesPopup:Hide()
    panel.scrollChild = {}
    local state = {}
    local world = setmetatable({
        ns = { Client = { isForever = forever }, QUI = {}, SafeCall = function()
            renders = renders + 1
            panel:Show()
            return true
        end },
        CharacterFrame = character,
        CharacterStatsPane = native,
        CharacterStatsPanePetScrollBox = pet,
        PaperDollFrame = frame(),
        PaperDollSidebarTab1 = frame(), PaperDollSidebarTab2 = frame(), PaperDollSidebarTab3 = frame(),
        CharacterFrameRightPaneHostStoneBg = { SetAtlas = function() end },
        PaperDollFrame_ShowSidebar = function() end,
        PaperDollFrame_UpdateSidebarTabs = false,
        PAPERDOLL_SIDEBARS = { {}, {}, {} },
        SOUNDKIT = {}, PlaySound = function() end,
        frameState = state, EMPTY = {}, statsPanel = panel, slotOverlays = {},
        GetSettings = function() return { enabled = enabled } end,
        GetChrome = function() return { GetNativeStatsPane = function() return native end } end,
        MaskNativeStatsPane = function() end,
        GetState = function(value) state[value] = state[value] or {}; return state[value] end,
        RestoreCharacterPanePopouts = function()
            equipmentPopup:Hide(); titlesPopup:Hide(); equipment:Hide(); titles:Hide()
        end,
        CreateEquipMgrPopup = function() return equipmentPopup end,
        CreateTitlesPopup = function() return titlesPopup end,
        UpdateAllSlotOverlays = function() end, UpdateILvlDisplay = function() end,
    }, { __index = _G })
    world._G = world
    world.PaperDollFrame.EquipmentManagerPane = equipment
    world.PaperDollFrame.TitleManagerPane = titles
    function character:GetStatsPane() return native end
    local path = forever and "tests/clients/forever/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua"
        or "tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua"
    local nativeSource = read(path)
    local nativeLoader = assert(loadstring(slice(nativeSource, "function GetPaperDollSideBarFrame(", "PAPERDOLL_STATINFO =")
        .. slice(nativeSource, "function PaperDollFrame_SetSidebar(", forever
            and "function PaperDollFrame_OnModelLoaded(" or "function PaperDollFrame_SidebarTab_OnEnter(")))
    setfenv(nativeLoader, world)
    nativeLoader()
    local hooks = assert(loadstring("local chrome = GetChrome()\n" .. slice(source,
        '    local nativeStatsPane = chrome and chrome.GetNativeStatsPane', "    if GearManagerPopupFrame then")))
    setfenv(hooks, world)
    hooks()
    world.PaperDollFrame_UpdateSidebarTabs = function() end
    local update = assert(loadstring(slice(source, "local function UpdateStatsPanel(", "local function GetAverageEquippedQuality(")
        .. slice(source, "ScheduleUpdate = function()", "-- Side popouts are built")
        .. "\nreturn UpdateStatsPanel"))
    setfenv(update, world)
    local updateStats = update()
    local function click(index)
        world.PaperDollFrame_SetSidebar(nil, index)
        world["PaperDollSidebarTab" .. index]:Fire("OnClick")
    end
    click(forever and 2 or 3)
    assert(equipmentPopup:IsShown() and equipment:GetParent() == equipmentPopup,
        "native equipment tab must open the equipment popup")
    assert(not titlesPopup:IsShown(), "equipment tab must not open titles")
    if forever then
        assert(not panel:IsShown(), "equipment selection must hide player stats")
        world.ScheduleUpdate()
        click(3)
        assert(pet:IsShown() and world.PaperDollFrame.currentSideBar == pet,
            "Forever tab 3 must retain native pet selection")
        assert(not equipmentPopup:IsShown() and not titlesPopup:IsShown(), "pet tab must close popouts")
        harness.RunTimers()
        updateStats(panel, "player")
        assert(not panel:IsShown() and renders == 0, "queued and direct updates must not overlay pet stats")
        click(1)
        updateStats(panel, "player")
        assert(panel:IsShown() and renders == 1, "player stats must render again after selecting Character")
        world.PaperDollFrame_SetSidebar(nil, 3)
        assert(not panel:IsShown(), "programmatic native pet selection must immediately hide custom player stats")
        world.PaperDollFrame_SetSidebar(nil, 1)
        harness.RunTimers()
        harness.RunTimers()
        assert(panel:IsShown(), "programmatic return from pet must refresh custom player stats without a click")
        enabled = false
        click(2)
        assert(not equipmentPopup:IsShown() and equipment:GetParent() == equipmentPopup,
            "disabled enhancement must not open its popup")
    else
        click(2)
        assert(titlesPopup:IsShown() and titles:GetParent() == titlesPopup, "Retail tab 2 must retain title popup")
    end
end
print("OK forever_character_sidebar_routing_test")
