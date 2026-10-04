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
    Bags = {}, Storage = {},
    Helpers = {
        CreateDBGetter = function() return function() return settings end end,
        GetCore = function() return nil end,
        GetGeneralFont = function() return "font" end,
        GetSkinColors = function() return 1, 1, 1 end,
    },
    UIKit = { DisablePixelSnap = noop, CreateBorderLines = noop, UpdateBorderLines = noop },
    SafeCallMethod = function() return true end,
}
(dofile("tests/helpers/locale.lua"))(ns)
_G.CreateFrame = frame
_G.InCombatLockdown = function() return false end
_G.CursorHasItem = function() return false end
_G.GetMoney = function() return 0 end
_G.geterrorhandler = function() return error end
_G.Enum = { BagSlotFlags = { DisableAutoSort = 1 } }
_G.C_Item = { GetItemFamily = function() return 0 end }
_G.C_Container = {
    GetBackpackAutosortDisabled = function() return false end,
    GetBagSlotFlag = function() return false end,
    GetContainerNumSlots = function(bagID) return bagID == 0 and 2 or 0 end,
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
for _, name in ipairs({ "grid_layout", "category_layout", "refresh_scope", "details", "chassis" }) do
    load("QUI_Bags/bags/views/" .. name .. ".lua")
end
load("QUI_Bags/bags/ops/sort_planner.lua")
ns.Bags.OpsShared = { PREFIX = "QUI", OpsBusy = function() return false end }
load("QUI_Bags/bags/ops/sort_executor.lua")

local win
ns.Bags.Chassis.CreateWindow = function()
    win = frame()
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
        local button = frame(); button.bagID = bagID
        liveButtons[#liveButtons + 1] = button
        return button
    end,
    CreateCached = function()
        local button = frame(); cachedButtons[#cachedButtons + 1] = button; return button
    end,
    Dress = dress, DressCached = dress, SetFocusFlash = noop, SetSelectedOverlay = noop,
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
ns.Bags.BagWindow.Show()
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
print("OK: bags_category_sort_refresh_test")
