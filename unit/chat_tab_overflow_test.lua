-- tests/unit/chat_tab_overflow_test.lua
-- Run: lua tests/unit/chat_tab_overflow_test.lua
local function makeFrame(ftype)
    local f = { ftype = ftype, shown = true, points = {} }
    local function noop() end
    f.SetPoint = function(s, ...) s.points[#s.points + 1] = { ... } end
    f.ClearAllPoints = function(s) s.points = {} end
    f.SetSize = noop; f.SetHeight = noop
    f.SetWidth = function(s, w) s.width = w end
    f.GetWidth = function(s) return s.width end -- nil until set
    f.Show = function(s) s.shown = true end
    f.Hide = function(s) s.shown = false end
    f.IsShown = function(s) return s.shown end
    f.SetShown = function(s, shown) s.shown = shown and true or false end
    f.IsMouseOver = function(s) return s.mouseOver == true end
    f.EnableMouse = noop
    f.EnableMouseWheel = function(s, enabled) s.mouseWheelEnabled = enabled end
    f.IsMouseWheelEnabled = function(s) return s.mouseWheelEnabled == true end
    f.RegisterForDrag = noop
    f.RegisterForClicks = noop
    f.SetAlpha = noop
    f.SetFrameLevel = noop
    f.GetFrameLevel = function() return 5 end
    f.GetParent = function(s) return s._parent end
    f.SetParent = function(s, p) s._parent = p end
    f.SetScript = function(s, k, v) s["_" .. k] = v end
    f.HookScript = function(s, k, v) s["_Hook" .. k] = v end
    f.CreateFontString = function()
        local fs = { points = {}, shown = true,
            SetPoint = function(o, ...) o.points[#o.points + 1] = { ... } end,
            ClearAllPoints = function(o) o.points = {} end,
            SetText = function(o, t) o.text = t end,
            GetStringWidth = function() return 30 end,
            GetFont = function() return "font.ttf", 11, "" end,
            SetFont = noop, SetFontObject = noop,
            SetTextColor = function(o, r, g, b) o.color = { r, g, b } end,
            SetShown = function(o, shown) o.shown = shown and true or false end,
            SetJustifyH = noop }
        return fs
    end
    f.CreateTexture = function()
        local tx = { SetPoint = noop, ClearAllPoints = noop,
            SetAllPoints = noop, SetTexture = noop,
            SetColorTexture = function(o, r, g, b, a) o.color = { r, g, b, a } end,
            SetHeight = noop, SetWidth = noop,
            SetShown = function(o, v) o.visible = v end,
            Hide = function(o) o.visible = false end }
        return tx
    end
    return f
end

local created = {}
function _G.CreateFrame(ftype, name, parent)
    local f = makeFrame(ftype)
    f.name = name
    f._parent = parent
    created[#created + 1] = f
    return f
end
_G.NUM_CHAT_WINDOWS = 10
function _G.GetChatWindowInfo() return "" end
_G.ChatFontNormal = {}
_G.ChatTypeInfo = { WHISPER = { r = 1, g = 0.5, b = 1 } }

local capturedGen
_G.MenuUtil = {
    CreateContextMenu = function(_, generator) capturedGen = generator end,
}

local function runMenu()
    assert(capturedGen, "menu generator expected")
    local root = { entries = {} }
    function root:CreateButton(text, callback)
        self.entries[#self.entries + 1] = { text = text, cb = callback }
        return self.entries[#self.entries]
    end
    function root:CreateRadio(text, isSelected, setSelected)
        self.entries[#self.entries + 1] = {
            text = text,
            selected = isSelected,
            cb = setSelected,
        }
        return self.entries[#self.entries]
    end
    function root:SetScrollMode(extent) self.scroll = extent end
    capturedGen(nil, root)
    capturedGen = nil
    return root
end

local container = makeFrame("Frame")
local setActiveCalls = {}
local activeFilter
local storeCb
local TabUI

local stubCustomTabs = {
    { name = "Alpha", groups = { A = true } },
    { name = "Beta",  groups = { B = true } },
    { name = "Gamma", groups = { C = true } },
    { name = "Delta", groups = { D = true } },
}
local stubConvs = {
    { key = "Pal-Realm", name = "Pal", windowID = 1 },
    { key = "Mage-Realm", name = "Mage", windowID = 1 },
    { key = "Priest-Realm", name = "Priest", windowID = 1 },
    { key = "Rogue-Realm", name = "Rogue", windowID = 1 },
}

local function makeFilter(td)
    return function(entry) return td.groups and td.groups[entry.k] or false end
end

local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Helpers = {
        IsSecretValue = function() return false end,
        GetGeneralFont = function() return "font.ttf" end,
        GetGeneralFontOutline = function() return "" end,
    },
    QUI = { Chat = {
        _internals = {
            GetSettings = function() return { enabled = true } end,
            IsChatEnabled = function(s) return s and s.enabled ~= false end,
            GetAccent = function() return { 0.2, 0.8, 0.6, 1 } end,
            GetThemeColors = function() return {
                bg = { 0.05, 0.06, 0.07, 1 },
                bgDark = { 0.01, 0.02, 0.03, 1 },
                border = { 0.3, 0.3, 0.3, 0.4 },
                text = { 1, 1, 1, 1 },
                textDim = { 0.7, 0.7, 0.7, 1 },
            } end,
        },
        DisplayLayer = { GetContainer = function() return container end },
        MessageStore = { OnAppend = function(fn) storeCb = fn end },
        ConversationManager = {
            EachForWindow = function(windowID, fn)
                for i = 1, #stubConvs do
                    if stubConvs[i].windowID == windowID then fn(stubConvs[i]) end
                end
            end,
            Close = function(key)
                for i = #stubConvs, 1, -1 do
                    if stubConvs[i].key == key then table.remove(stubConvs, i) end
                end
                TabUI.Rebuild()
            end,
        },
        TabManager = {
            SetActiveTab = function(_, td)
                activeFilter = td and makeFilter(td) or nil
                setActiveCalls[#setActiveCalls + 1] = { td = td }
            end,
            SetActiveConversation = function() end,
            GetActiveFilter = function() return activeFilter end,
            GetWindowTabs = function() return stubCustomTabs end,
            GetWindowTab = function(_, i) return stubCustomTabs[i] end,
            BuildTabFilter = makeFilter,
            BuildConversationFilter = function(key)
                return function(entry) return entry.conv == key end
            end,
        },
    } },
    UIKit = {
        CreateCloseButton = function(parent, opts)
            local close = makeFrame("Button")
            close._parent = parent
            close:SetScript("OnClick", opts.onClick)
            return close
        end,
    },
}

assert(loadfile("QUI_Chat/chat/tab_ui.lua"))("QUI", ns)
TabUI = ns.QUI.Chat.TabUI

TabUI.EnsureAttached()
local inst = TabUI._instances[1]
local bar = inst.bar
local function buttons() return inst.buttons end

local function visibleLabels()
    local out = {}
    for i = 1, #buttons() do
        local b = buttons()[i]
        if b:IsShown() then out[#out + 1] = b.label.text end
    end
    return table.concat(out, ",")
end

local function shown(label)
    for i = 1, #buttons() do
        local b = buttons()[i]
        if b.label.text == label then return b:IsShown() end
    end
    return false
end

local function findButton(label)
    for i = 1, #buttons() do
        if buttons()[i].label.text == label then return buttons()[i] end
    end
end

local function click(btn)
    assert(btn and btn._OnClick, "button must have OnClick script")
    btn._OnClick(btn, "LeftButton")
end

local function wheel(delta)
    assert(bar._OnMouseWheel, "bar must have OnMouseWheel script")
    bar._OnMouseWheel(bar, delta)
end

assert(#buttons() == 8, "4 saved tabs + 4 conversations expected, got " .. #buttons())
for i = 1, 8 do
    assert(buttons()[i]:IsShown(), "tab " .. i .. " should be visible with unknown bar width")
end
assert(inst.firstHidden == nil, "no overflow with unknown bar width")
assert(inst.overflowBtn and not inst.overflowBtn:IsShown(), "picker hidden when everything fits")

local saved = buttons()[1]
saved._OnEnter(saved)
assert(saved.close and not saved.close:IsShown(), "saved tabs never show a close button")
saved._OnLeave(saved)

local pal = assert(findButton("Pal"), "Pal conversation exists")
assert(not pal.close:IsShown(), "inactive conversation close starts hidden")
pal._OnEnter(pal)
assert(pal.close:IsShown(), "inactive conversation close appears on hover")
assert(pal.badge.shown == false, "close replaces the unread badge region")
pal.close.mouseOver = true
pal._OnLeave(pal)
assert(pal.close:IsShown(), "close stays visible while moving into the child button")
pal.close.mouseOver = false
pal.close._HookOnLeave(pal.close)
assert(not pal.close:IsShown(), "inactive conversation close hides after hover")
assert(pal.badge.shown == true, "badge region returns after hover")

bar.width = 200
bar._OnSizeChanged(bar)
assert(inst.firstHidden == 3, "tabs after visible slice should be hidden, got " .. tostring(inst.firstHidden))
assert(inst.visibleFirst == 1 and inst.visibleLast == 2,
    "initial visible slice should be tabs 1-2, got "
        .. tostring(inst.visibleFirst) .. "-" .. tostring(inst.visibleLast))
assert(buttons()[1]:IsShown() and buttons()[2]:IsShown(), "tabs 1-2 stay visible")
for i = 3, 8 do assert(not buttons()[i]:IsShown(), "later tabs hide until selected or scrolled") end
assert(inst.overflowBtn:IsShown(), "exact-tab picker appears")
assert(inst.overflowBtn.points[1][4] == 144, "picker follows the last visible tab without a gap")
assert(bar:IsMouseWheelEnabled(), "tab bar enables mouse wheel")
assert(visibleLabels() == "Alpha,Beta", "initial visible labels got " .. visibleLabels())

storeCb({ k = "D" })
assert(inst.unread[-4] == 1, "hidden tab still counts unread")
local accent = { 0.2, 0.8, 0.6 }
local c = inst.overflowBtn.label.color
assert(c and c[1] == accent[1] and c[2] == accent[2] and c[3] == accent[3],
    "picker uses the accent while a hidden tab has unread")

click(inst.overflowBtn)
local menu = runMenu()
assert(#menu.entries == 8, "picker lists every tab")
assert(menu.entries[1].text == "Alpha", "saved tabs retain display order")
assert(menu.entries[4].text == "Delta (1)", "picker shows unread counts")
assert(menu.entries[5].text == "|cffff80ffPal|r", "picker preserves conversation tint")
assert(menu.entries[1].selected(), "active tab is marked in the picker")
assert(menu.scroll and menu.scroll > 0, "long picker menus scroll")
menu.entries[4].cb()
assert(inst.activeID == -4, "picker activates an exact hidden tab")
assert(setActiveCalls[#setActiveCalls].td == stubCustomTabs[4], "activation applies the hidden tab data")
assert(inst.unread[-4] == nil, "activation clears unread")
assert(shown("Delta") == true, "selected hidden tab scrolls into view")

inst.scrollOffset = 0
TabUI.Rebuild()
assert(shown("Delta") == true, "ordinary rebuild keeps the active tab visible")

pal = assert(findButton("Pal"), "Pal remains visible beside Delta")
pal._OnClick(pal, "RightButton")
menu = runMenu()
assert(#menu.entries == 1 and menu.entries[1].text == "Close conversation",
    "conversation context menu exposes close")

wheel(-1)
wheel(-1)
assert(visibleLabels() == "Mage,Priest", "mouse wheel reaches the tail conversations")

pal.frameID = "conv:Rogue-Realm"
menu.entries[1].cb()
assert(inst.activeID == -4, "closing an inactive conversation keeps the active tab")
assert(not findButton("Pal") and findButton("Rogue"), "context close captures the intended conversation")
assert(visibleLabels() == "Mage,Priest", "closing before the viewport preserves visible tab identities")

local mage = assert(findButton("Mage"), "Mage survives the inactive close")
click(mage)
assert(inst.activeID == "conv:Mage-Realm", "Mage conversation activates")
assert(mage.close:IsShown(), "active conversation always shows its close button")
click(mage.close)
assert(inst.activeID == "conv:Priest-Realm", "closing the active conversation selects its right neighbor")
assert(shown("Priest"), "right-neighbor fallback remains visible")

local priest = assert(findButton("Priest"), "Priest survives as the active neighbor")
priest._OnClick(priest, "MiddleButton")
assert(inst.activeID == "conv:Rogue-Realm", "middle-click uses the same right-neighbor fallback")

local rogue = assert(findButton("Rogue"), "Rogue survives as the active neighbor")
click(rogue.close)
assert(inst.activeID == -4, "closing the last conversation falls back to its left neighbor")
assert(shown("Delta"), "left-neighbor fallback remains visible")

for i = 1, #buttons() do
    assert(type(buttons()[i].frameID) == "string" or not buttons()[i].close:IsShown(),
        "pooled close buttons stay hidden on saved tabs")
end

buttons()[1]._quiTabW = 500
buttons()[1]:SetWidth(500)
inst.scrollOffset = 0
bar._OnSizeChanged(bar)
assert(inst.overflowBtn.points[1][4] == 176, "oversized labels keep the picker inside the bar")
buttons()[1]._quiTabW = 72
buttons()[1]:SetWidth(72)

bar.width = 4000
bar._OnSizeChanged(bar)
assert(inst.firstHidden == nil, "wide layout removes overflow")
assert(not inst.overflowBtn:IsShown(), "picker hides when every tab fits")
assert(inst.scrollOffset == 0, "wide layout resets scroll offset")

inst.scrollOffset = 99
bar.width = 200
bar._OnSizeChanged(bar)
assert(inst.scrollOffset < 99, "resize clamps out-of-range scroll offset")
assert(inst.visibleFirst and inst.visibleLast and inst.visibleFirst <= inst.visibleLast,
    "narrow layout keeps a valid visible slice")
assert(inst.firstHidden ~= nil, "overflow re-engages")

print("OK chat_tab_overflow_test")
