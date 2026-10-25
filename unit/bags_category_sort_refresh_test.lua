local function noop() end
local function frame()
    local f = { shown = true, scripts = {}, width = 18 }
    for _, method in ipairs({ "SetAllPoints", "SetFont", "SetTextColor", "SetJustifyH",
        "SetTexture", "SetVertexColor", "SetAtlas", "RegisterForClicks", "RegisterForDrag",
        "SetFrameLevel", "SetAlpha", "SetPassThroughButtons", "ApplyPosition" }) do
        f[method] = noop
    end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetShown(value) self.shown = value end
    function f:SetScript(key, value) self.scripts[key] = value end
    function f:GetScript(key) return self.scripts[key] end
    function f:SetSize(width, height) self.width, self.height = width, height end
    function f:GetWidth() return self.width end
    function f:GetFrameLevel() return 0 end
    function f:SetText(value) self.text = value end
    function f:GetStringWidth() return #(self.text or "") * 6 end
    function f:SetID(value) self.id = value end
    function f:GetID() return self.id end
    function f:GetBagID() return self.bagID end
    function f:ClearAllPoints() self.point = nil end
    function f:SetPoint(...) self.point = { ... } end
    function f:CreateTexture() return frame() end
    function f:CreateFontString() return frame() end
    return f
end

local deferLiveButtons = false
local equippedSizes = {}
local settings = {
    appearance = { layoutMode = "categories", columns = 6, iconSize = 24,
        spacing = 2, showBagSlots = false },
    behavior = { sortKey = "quality" },
}
local metadata = {
    [11] = { classID = 4, subClassID = 1, name = "Apple", ilvl = 100, expacID = 1 },
    [22] = { classID = 4, subClassID = 2, name = "Zebra", ilvl = 300, expacID = 2 },
}
local rec = { bags = { [0] = { size = 2, slots = {
    { itemID = 11, quality = 4, count = 1 },
    { itemID = 22, quality = 2, count = 1 },
} } }, details = { money = 0 } }
local ns = {
    Bags = { IsActive = function() return true end }, Storage = {},
    Helpers = {
        CreateDBGetter = function() return function() return settings end end,
        GetCore = function() return nil end,
        GetGeneralFont = function() return "font" end,
        GetSkinColors = function() return 1, 1, 1 end,
        GetWindowColors = function() return 1, 1, 1, 1, 0.05, 0.05, 0.05, 0.95 end,
    },
    UIKit = { DisablePixelSnap = noop, CreateBorderLines = noop, UpdateBorderLines = noop },
    SafeCallMethod = function() return true end,
}
(dofile("tests/helpers/locale.lua"))(ns)
_G.CreateFrame = frame
_G.InCombatLockdown = function() return deferLiveButtons end
_G.CursorHasItem = function() return false end
_G.GetMoney = function() return 0 end
_G.geterrorhandler = function() return error end
_G.Enum = { BagSlotFlags = { DisableAutoSort = 1 } }
_G.C_Item = { GetItemFamily = function() return 0 end }
_G.C_Container = {
    GetBackpackAutosortDisabled = function() return false end,
    GetBagSlotFlag = function() return false end,
    GetContainerNumSlots = function(bagID)
        return equippedSizes[bagID] or (rec.bags[bagID] and rec.bags[bagID].size) or 0
    end,
    GetContainerNumFreeSlots = function() return 0, 0 end,
    GetContainerItemInfo = function(bagID, slot)
        local entry = rec.bags[bagID] and rec.bags[bagID].slots[slot]
        if entry then
            return { itemID = entry.itemID, stackCount = entry.count, quality = entry.quality }
        end
    end,
}
ns.Storage.Store = {
    GetCurrentCharacter = function() return rec end,
    GetCurrentCharacterKey = function() return "live" end,
    GetCharacter = function() return rec end,
}
ns.Storage.ItemInfo = {
    GetDerived = function(itemID) return metadata[itemID] end,
    GetExtended = function(itemID) return metadata[itemID] end,
}

local function load(path)
    local chunk
    if path == "QUI_Bags/bags/views/bag_window.lua" and arg[1] then
        local file = assert(io.open(path, "rb"))
        local source = file:read("*a"); file:close()
        local count
        if arg[1] == "mutate-key" then
            source, count = source:gsub("key = behavior and behavior%.sortKey,", "key = nil,", 1)
        elseif arg[1] == "mutate-reverse" then
            source, count = source:gsub("reverse = behavior and behavior%.sortReverse,", "reverse = false,", 1)
        elseif arg[1] == "mutate-completion" then
            source, count = source:gsub('Start%("bags", BagWindow%.Refresh%)', 'Start("bags")', 1)
        elseif arg[1] == "mutate-prepare" then
            source, count = source:gsub("function BagWindow%.PrepareLiveButtons%(%)",
                "function BagWindow.PrepareLiveButtons() if true then return end", 1)
        elseif arg[1] == "mutate-dress-all" then
            source, count = source:gsub("if bagSet or dressAll then", "if bagSet then", 1)
        end
        assert(count == 1, "mutation must change one production branch")
        chunk = assert(loadstring(source, "@" .. path))
    else
        chunk = assert(loadfile(path))
    end
    chunk("QUI", ns)
end
load("core/storage/bus.lua")
local storageLoader = dofile("tests/helpers/load_storage_data.lua")
storageLoader.InstallBaseStubs()
load("core/storage/scan_bank.lua")
for _, name in ipairs({ "grid_layout", "category_layout", "refresh_scope", "details", "chassis" }) do
    load("QUI_Bags/bags/views/" .. name .. ".lua")
end
load("QUI_Bags/bags/ops/sort_planner.lua")
ns.Bags.OpsShared = { PREFIX = "QUI", OpsBusy = function() return false end }
load("QUI_Bags/bags/ops/sort_executor.lua")

local win
ns.Bags.Chassis.CreateWindow = function()
    win = frame()
    win:Hide()
    for _, key in ipairs({ "_header", "_footer", "_body", "_title", "_searchBox", "_close" }) do
        win[key] = frame()
    end
    function win:SetContentSize(width, height) self.contentW, self.contentH = width, height end
    return win
end
ns.Bags.CurrencyBar = { Attach = noop }
ns.Bags.OwnerSelect = { Attach = function()
    local owner = frame(); owner.Update = noop; return owner
end }
local liveButtons, cachedButtons = {}, {}
local function dress(button, entry) button.entry = entry end
ns.Bags.ItemButtons = {
    AddSlotBackground = noop, CreateHolder = frame,
    CreateLive = function(_, bagID)
        if deferLiveButtons then return nil end
        local button = frame(); button.bagID = bagID; button.live = true
        liveButtons[#liveButtons + 1] = button
        return button
    end,
    CreateCached = function()
        local button = frame(); cachedButtons[#cachedButtons + 1] = button; return button
    end,
    Dress = function(button, entry)
        assert(button.live, "native dressing must not receive a cached combat fallback")
        dress(button, entry)
    end,
    DressCached = function(button, entry)
        assert(not button.live, "cached dressing must not replace native item interactions")
        dress(button, entry)
    end,
    SetFocusFlash = noop, SetSelectedOverlay = noop, SetFreeCount = noop,
}
ns.Bags.Transfers = { ResolveItemRightClickRoute = function() return nil end }
ns.Bags.Junk = { IsMerchantOpen = function() return false end }
load("QUI_Bags/bags/views/bag_window.lua")

local function order(buttons, first, second, label)
    local x = {}
    for _, button in ipairs(buttons) do
        if button.shown and button.entry then x[button.entry.itemID] = button.point[4] end
    end
    assert(x[first] and x[second] and x[first] < x[second], label)
end
local function repaint(changed)
    ns.Storage.Bus.Publish("BagsChanged", "live", changed)
    assert(win:GetScript("OnUpdate"), "changed event must schedule repaint")
    win:GetScript("OnUpdate")(win)
end
local menu = {}
_G.MenuUtil = { CreateContextMenu = function(anchor, build)
    local root = { CreateTitle = noop, CreateButton = noop }
    function root:CreateRadio(label, _, click) menu[label] = click end
    function root:CreateCheckbox(label, _, click) menu[label] = click end
    build(anchor, root)
end }
deferLiveButtons = true
settings.behavior.sortKey = "name"
ns.Bags.BagWindow.Show()
assert(#liveButtons == 0 and #cachedButtons == 2,
    "first opening after a combat reload must display both items without native button creation")
order(cachedButtons, 11, 22, "combat fallback must display the current items")
rec.bags[0].slots[1] = { itemID = 11, quality = 4, count = 7 }
repaint({ 0 })
assert(cachedButtons[1].entry.count == 7 and cachedButtons[1].shown,
    "combat fallback must follow bag updates without requiring relayout")
deferLiveButtons = false
repaint({ 0 })
assert(#liveButtons == 2 and liveButtons[1].shown and not cachedButtons[1].shown,
    "out-of-combat bag updates must show prepared replacements even before the regen handler runs")
settings.behavior.sortKey = "quality"
rec.bags[0].slots[1].count = 1
ns.Bags.BagWindow.Refresh()
assert(not cachedButtons[1].shown and not cachedButtons[2].shown,
    "out-of-combat refresh must replace visual fallbacks with native item buttons")
order(liveButtons, 11, 22, "initial quality order")
win._sortBtn:GetScript("OnClick")(win._sortBtn, "RightButton")
menu[ns.L["Item Level"]]()
assert(settings.behavior.sortKey == "ilvl", "menu must select item level")
order(liveButtons, 22, 11, "menu key must refresh real category positions")
menu[ns.L["Reverse order"]]()
assert(settings.behavior.sortReverse, "menu must toggle reverse")
order(liveButtons, 11, 22, "reverse menu must refresh real category positions")
settings.behavior.sortReverse = false
repaint({})
order(liveButtons, 22, 11, "dress-all must relayout changed reverse")
metadata[11].ilvl = 400
repaint({})
order(liveButtons, 11, 22, "dress-all must relayout changed metadata")
settings.behavior.sortKey = "name"
settings.behavior.sortReverse = true
ns.Bags.BagWindow.Refresh()
order(liveButtons, 22, 11, "reversed name display")
settings.behavior.sortReverse = false
win._sortBtn:GetScript("OnClick")(win._sortBtn, "LeftButton")
assert(not ns.Bags.SortExecutor.IsRunning(), "already physically name-sorted bags require zero moves")
order(liveButtons, 11, 22, "zero-move sort completion must refresh category positions")
ns.Bags.BagWindow.SetViewedCharacter("cached")
settings.behavior.sortKey = "ilvl"
metadata[22].ilvl = 500
repaint({ 0 })
order(cachedButtons, 22, 11, "cached dress-all must relayout metadata and selected key")
settings.appearance.layoutMode = "flat"
ns.Bags.BagWindow.Refresh()
order(cachedButtons, 11, 22, "flat view must preserve physical slot order")
ns.Bags.BagWindow.SetViewedCharacter(nil)
deferLiveButtons = true
rec.bags[0].size = 3
rec.bags[0].slots[3] = { itemID = 11, quality = 4, count = 2 }
rec.bags[0].slots[1] = { itemID = 22, quality = 2, count = 3 }
ns.Bags.BagWindow.Refresh()
assert(#liveButtons == 2, "deferred creation must not add a combat-born item button")
assert(#cachedButtons == 3 and cachedButtons[3].shown and cachedButtons[3].entry.count == 2,
    "a newly needed slot must remain visible during combat")
assert(liveButtons[1].shown and liveButtons[1].entry.count == 3,
    "an unavailable new slot must not prevent existing live slots from updating")
ns.Bags.BagWindow.SetViewedCharacter("cached")
assert(#cachedButtons == 3, "cached browsing must still build slots during combat")
ns.Bags.BagWindow.SetViewedCharacter(nil)
deferLiveButtons = false
ns.Bags.BagWindow.Refresh()
assert(#liveButtons == 3 and liveButtons[3].shown and liveButtons[3].entry.count == 2,
    "a deferred live slot must appear on the next out-of-combat refresh")
ns.Bags.BagWindow.Hide()
liveButtons, cachedButtons = {}, {}
rec.bags[1] = { size = 2, slots = {} }
equippedSizes[5] = 2
settings.appearance.hiddenBags = { [1] = true }
settings.appearance.groupEmptySlots = true
ns.Bags.IsActive = function() return true end
load("core/storage/bus.lua")
load("QUI_Bags/bags/views/bag_window.lua")
if ns.Bags.BagWindow.PrepareLiveButtons then ns.Bags.BagWindow.PrepareLiveButtons() end
assert(#liveButtons == 7 and not ns.Bags.BagWindow.IsShown(),
    "prepare must create hidden, empty and not-yet-scanned equipped slots without opening bags")
for _, button in ipairs(liveButtons) do
    assert(not button.shown and button.id and button._quiSelectCatcher and button._quiDepositCatcher,
        "prepared slots must stay hidden and retain normal item interaction overlays")
end
rec.bags[1].size = 3
ns.Storage.Bus.Publish("BagsChanged", "live", { 1 })
assert(#liveButtons == 8 and not ns.Bags.BagWindow.IsShown(),
    "bag capacity changes must prepare new slots while the window is closed")
ns.Storage.Bus.Publish("BagsChanged", "live", {})
assert(#liveButtons == 8, "repeat bag updates must reuse prepared native buttons")
deferLiveButtons = true
settings.appearance.hiddenBags = nil
rec.bags[1].slots[3] = { itemID = 22, quality = 2, count = 9 }
ns.Bags.BagWindow.Show()
assert(#liveButtons == 8 and #cachedButtons == 0,
    "first combat open must reuse prepared native slots, including previously hidden slots")
assert(liveButtons[8].shown and liveButtons[8].entry.count == 9,
    "prepared hidden slots must display their current contents on the first combat open")
print("OK: bags_category_sort_refresh_test")
