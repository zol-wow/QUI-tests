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
    panel:SetWidth(160)
    equipment.ScrollBox, titles.ScrollBox = frame(), frame()
    equipment.EquipSet, equipment.SaveSet = frame(), frame()
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
        PaperDollSidebarTab4 = forever and frame() or nil,
        CharacterFrameRightPaneHostStoneBg = { SetAtlas = function() end },
        PaperDollFrame_ShowSidebar = function() end,
        PaperDollFrame_UpdateSidebarTabs = false,
        PAPERDOLL_SIDEBARS = forever and { {}, {}, {}, {} } or { {}, {}, {} },
        SOUNDKIT = {}, PlaySound = function() end,
        frameState = state, EMPTY = {}, statsPanel = panel, slotOverlays = {}, allEquipmentSlots = {},
        GetSettings = function() return { enabled = enabled } end,
        GetSkinBase = function() return nil end,
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
    world.hooksecurefunc = function(target, method, callback)
        if type(target) == "string" then
            hooksecurefunc(world, target, method)
        else
            hooksecurefunc(target, method, callback)
        end
    end
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
    local nativeUpdates = 0
    if forever then
        world.CharacterStatsPaneScrollBox = native
        world.HasPetUI = function() return false end
        function world.PaperDollFrame:IsVisible() return self:IsShown() end
        function native:UpdateStats() nativeUpdates = nativeUpdates + 1 end
        local nativeEvents = assert(loadstring(slice(nativeSource, "function PaperDollFrame_QueuedUpdate(",
            "function PaperDollFrame_SetLevel(") .. slice(nativeSource, "function PaperDollFrame_UpdateStats()",
            "function PaperDollFrame_UpdateStatsInternal(")))
        setfenv(nativeEvents, world)
        nativeEvents()
    end
    if source:find("local function ShowCharacterSidebarPane(", 1, true) then
        local inline = assert(loadstring(slice(source, "local function ShowCharacterSidebarPane(",
            "local function RestoreCharacterPanePopouts()") .. "\nreturn ShowCharacterSidebarPane"))
        setfenv(inline, world)
        world.ShowCharacterSidebarPane = inline()
    end
    local hooks = assert(loadstring("local chrome = GetChrome()\n" .. slice(source,
        '    local nativeStatsPane = chrome and chrome.GetNativeStatsPane', "    if GearManagerPopupFrame then")))
    setfenv(hooks, world)
    hooks()
    world.PaperDollFrame_UpdateSidebarTabs = function() end
    local update = assert(loadstring(slice(source, "local function UpdateStatsPanel(", "local function GetAverageEquippedQuality(")
        .. slice(source, "ScheduleUpdate = function()", source:find("local function ShowCharacterSidebarPane(", 1, true)
            and "local function ShowCharacterSidebarPane(" or "-- Side popouts are built")
        .. "\nreturn UpdateStatsPanel"))
    setfenv(update, world)
    local updateStats = update()
    local function click(index)
        world.PaperDollFrame_SetSidebar(nil, index)
        world["PaperDollSidebarTab" .. index]:Fire("OnClick")
    end
    click(forever and 2 or 3)
    assert(equipment:IsShown() and equipment:GetParent() == character,
        "native equipment tab must stay inside the character panel")
    assert(not panel:IsShown(), "equipment selection must replace player stats")
    local actionTop = { equipment.EquipSet:GetPoint(1) }
    assert(actionTop[1] == "TOPLEFT" and actionTop[2] == equipment and actionTop[5] == -6, "equipment actions must leave space below the view icons")
    local equipmentTop = { equipment:GetPoint(1) }
    assert(equipmentTop[2] == panel, "equipment pane must occupy the stats area")
    assert(equipment.EquipSet:GetWidth() == 78 and equipment.SaveSet:GetWidth() == 78,
        "equipment actions must fit side by side inside the stats area")
    assert(not titlesPopup:IsShown(), "equipment tab must not open titles")
    if forever then
        assert(not panel:IsShown(), "equipment selection must hide player stats")
        world.ScheduleUpdate()
        click(3)
        assert(titles:IsShown() and titles:GetParent() == character,
            "Forever tab 3 must swap to inline titles")
        assert(not equipmentPopup:IsShown() and not panel:IsShown(), "titles tab must close equipment and player stats")
        harness.RunTimers()
        updateStats(panel, "player")
        assert(not panel:IsShown() and renders == 0, "queued and direct updates must not overlay titles")
        click(4)
        assert(pet:IsShown() and world.PaperDollFrame.currentSideBar == pet,
            "Forever tab 4 must retain native pet selection")
        assert(not equipmentPopup:IsShown() and not titlesPopup:IsShown(), "pet tab must close popouts")
        harness.RunTimers()
        updateStats(panel, "player")
        assert(not panel:IsShown() and renders == 0, "queued and direct updates must not overlay pet stats")
        click(1)
        updateStats(panel, "player")
        assert(panel:IsShown() and renders == 1, "player stats must render again after selecting Character")
        world.PaperDollFrame_SetSidebar(nil, 4)
        assert(not panel:IsShown(), "programmatic native pet selection must immediately hide custom player stats")
        world.PaperDollFrame_SetSidebar(nil, 1)
        harness.RunTimers()
        harness.RunTimers()
        assert(panel:IsShown(), "programmatic return from pet must refresh custom player stats without a click")
        local function nativeEvent(event)
            world.PaperDollFrame_OnEvent(world.PaperDollFrame, event, "player")
            world.PaperDollFrame:Fire("OnUpdate")
            harness.RunTimers()
        end
        for _, event in ipairs({ "UNIT_RESISTANCES", "UNIT_AURA", "UNIT_DAMAGE", "UNIT_SPELL_HASTE",
            "UNIT_MAXHEALTH", "COMBAT_RATING_UPDATE" }) do
            local before, nativeBefore = renders, nativeUpdates
            nativeEvent(event)
            assert(nativeUpdates == nativeBefore + 1, "native stats must process " .. event)
            assert(renders == before + 1, "visible custom stats must refresh after native " .. event)
        end
        click(4)
        local before = renders
        nativeEvent("UNIT_RESISTANCES")
        assert(renders == before and not panel:IsShown(), "native refresh must not overlay pet stats")
        enabled = false
        native:Show()
        harness.RunTimers()
        nativeEvent("UNIT_AURA")
        assert(renders == before, "disabled enhancement must not render after native stats refresh")
        click(2)
        assert(not equipmentPopup:IsShown() and equipment:GetParent() == character,
            "disabled enhancement must not open its popup")
        click(3)
        assert(not titlesPopup:IsShown() and titles:GetParent() == character,
            "disabled enhancement must preserve the native titles parent")
    else
        click(2)
        assert(titles:IsShown() and titles:GetParent() == character, "Retail tab 2 must swap to inline titles")
        updateStats(panel, "player")
        assert(not panel:IsShown() and renders == 0, "Retail stats refresh must not overlay titles")
        world.PaperDollSidebarTab3:Fire("OnClick")
        assert(equipment:IsShown() and not titles:IsShown(), "gear click must select the native equipment pane")
        updateStats(panel, "player")
        assert(not panel:IsShown() and renders == 0, "Retail stats refresh must not overlay equipment")
        click(1)
        updateStats(panel, "player")
        assert(panel:IsShown() and renders == 1, "Retail stats must return after selecting Character")
    end
end
print("OK forever_character_sidebar_routing_test")
