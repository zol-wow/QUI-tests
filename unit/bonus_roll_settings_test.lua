local widgets, frames, providers = {}, {}, {}
local methods = {}
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(value) self.width = value end
function methods:GetWidth() return self.width or 0 end
function methods:HookScript(key, callback) self.scripts[key] = callback end
function methods:EnableMouse(value) self.mouse = value end
function methods:SetAlpha(value) self.alpha = value end
function methods:SetTextColor(...) self.color = { ... } end
function methods:SetFont() end
function methods:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function methods:SetNonSpaceWrap() end
function methods:SetAllPoints() end
function methods:SetColorTexture() end
function methods:SetTexture() end
function methods:AddMaskTexture() end
function methods:GetChildren() end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:SetHeight(value) self.height = value end
function methods:GetHeight() return self.height or 0 end
function methods:SetShown(value) self.shown = value end
function methods:IsShown() return self.shown ~= false end
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true end
function methods:SetEnabled(value) self.enabled = value end
function methods:SetText(value) self.text = value end
function methods:SetScript(key, callback) self.scripts[key] = callback end
function methods:SetParent(parent) self.parent = parent end
function methods:GetParent() return self.parent end
function methods:SetPoint(...) self.point = { ... } end
function methods:ClearAllPoints() self.point = nil end
function methods:SetJustifyH() end
function methods:SetWordWrap() end
local function Frame(_, _, parent)
    local frame = setmetatable({ parent = parent, scripts = {}, shown = true }, { __index = methods })
    frames[#frames + 1] = frame
    return frame
end
function methods:CreateTexture() return Frame(nil, nil, self) end
methods.CreateMaskTexture = methods.CreateTexture
methods.CreateFontString = methods.CreateTexture
_G.CreateFrame = Frame
local GUI = {
    Colors = { text = { 1, 1, 1, 1 }, textMuted = { 1, 1, 1, 0.45 },
        toggleOff = { 1, 1, 1, 0.12 }, toggleThumb = { 1, 1, 1, 1 }, accent = { 0.2, 0.8, 0.6, 1 } },
    _searchContext = {},
    HasGeneratedSearchCache = function() return true end,
}
_G.QUI = { GUI = GUI }
local function Widget(parent, label, key, db, callback, info)
    local widget = Frame(nil, nil, parent)
    widget.label, widget.key, widget.db, widget.callback, widget.info = label, key, db, callback, info
    widget.section = GUI._searchContext.sectionName
    function widget:SetValue(value)
        self.db[self.key] = value
        if self.callback then self.callback(value) end
    end
    widgets[#widgets + 1] = widget
    return widget
end
function GUI:CreateFormSlider(parent, label, _, _, _, key, db, callback, info)
    return Widget(parent, label, key, db, callback, info)
end
function GUI:CreateButton(parent, label, _, height, callback)
    local button = Widget(parent, label, nil, nil, callback)
    button:SetHeight(height)
    return button
end
function GUI:CreateLabel(parent, text)
    local label = Frame(nil, nil, parent)
    label:SetText(text)
    return label
end
function GUI:AttachTooltip(frame, description, label)
    frame._quiTooltipDescription, frame._quiTooltipLabel = description, label
end
function GUI:SetSearchSection(section) self._searchContext.sectionName = section end
function GUI:ShowConfirmation(options) self.confirmation = options end
local profile = { general = { bonusRoll = { enabled = false, announce = true, difficulty = {}, mythicPlus = { mode = "show", minLevel = 10 } } } }
local pending, recovered, cleared, notified = nil, 0, 0, 0
local feature
local ns = {
    UIKit = { CreateChevronCaret = function(parent) return Frame(nil, nil, parent) end },
    Helpers = {
        AssetPath = "Interface\\AddOns\\QUI\\assets\\",
        ApplyFontWithFallback = function(font, ...) font:SetFont(...) end,
    },
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Settings = {
        ProviderFeatures = { Register = function(_, spec) feature = spec; return spec end },
        ProviderPanels = { RegisterAfterLoad = function(_, callback) callback() end },
        RenderAdapters = { NotifyProviderChanged = function() notified = notified + 1 end },
    },
    BonusRoll = {
        GetPendingRoll = function() return pending end,
        ShowPendingRoll = function() recovered = recovered + 1 end,
        ClearFilters = function() cleared = cleared + 1 end,
        GetEncounterGroups = function(id)
            return { { id = id, name = "Group " .. id, encounters = { { id = 101, name = "Boss A" }, { id = 102, name = "Boss B" } } } }
        end,
        GetSeenDifficulties = function() return { 233, 999 } end,
    },
    QUI_Options = {
        PADDING = 15,
        CreateAccentDotLabel = function(parent, text) GUI:SetSearchSection(text); return Frame(nil, nil, parent) end,
        CreateSettingsCardGroup = function(parent)
            local card = { frame = Frame(nil, nil, parent), count = 0 }
            function card.AddRow(left, right)
                card.count = card.count + 1
                left.paired = right
                if right then right.paired = left end
            end
            function card.Finalize() card.frame:SetHeight(card.count * 32) end
            return card
        end,
    },
    QUI_LayoutMode_Settings = { RegisterSharedProvider = function(_, key, provider) providers[key] = provider end },
    QUI_LayoutMode_Utils = {
        GetProfileDB = function() return profile end,
        BuildPositionCollapsible = function(_, _, _, sections) sections[#sections + 1] = "position" end,
        BuildOpenFullSettingsLink = function(_, _, sections) sections[#sections + 1] = "link" end,
        StandardRelayout = function(content, sections) content.sections = sections; content:SetHeight(80) end,
    },
}
local function Extract(path, first, last)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    local start = assert(source:find(first, 1, true))
    return source:sub(start, assert(source:find(last, start, true)) - 1)
end
local function Noop() end
local function BindWidgetMethod(_, callback) return function(_, ...) return callback(...) end end
local loader = loadstring or load
local framework = "QUI_Options/framework.lua"
local toggles = Extract(framework, "-- BEGIN widget disabled mute", "-- END widget disabled mute")
    .. Extract(framework, "-- BEGIN pill toggle", "-- BEGIN square checkbox")
local sync = Extract(framework, "local function IsTransientOptionsBinding", "local function ShouldRegisterSearchSetting")
    .. Extract(framework, "local function GetProviderSyncContext", "local function BuildPinnedWidgetDescriptor")
    .. Extract(framework, "function GUI:SetWidgetProviderSyncOptions", "function GUI:NotifyProviderChangedForWidget")
local dropdown = Extract(framework, "function GUI:CreateFormDropdown", "function GUI:CreateFormColorPicker")
local parameters = "ns, GUI, C, FORM_ROW_HEIGHT, SetFont, "
    .. "MaybeUpdatePinnedWidgetValue, BroadcastToSiblings, BindWidgetMethod, "
    .. "RegisterWidgetInstance, MaybeBindPinnedWidget, RegisterSearchSettingWidgetForBinding, AttachFormWidgetTooltip"
assert(loader("return function(" .. parameters .. ")\n" .. sync .. toggles .. dropdown .. "\nend"))()(ns, GUI, GUI.Colors,
    28, Noop, Noop, Noop, BindWidgetMethod, Noop, Noop, Noop, Noop)
local CreateFormCheckbox = GUI.CreateFormCheckbox
function GUI:CreateFormCheckbox(parent, label, key, db, callback, info)
    local widget = CreateFormCheckbox(self, parent, label, key, db, callback, info)
    widget.key, widget.db, widget.callback, widget.info = key, db, callback, info
    widgets[#widgets + 1] = widget
    return widget
end
local CreateFormDropdown = GUI.CreateFormDropdown
function GUI:CreateFormDropdown(parent, label, options, key, db, callback, info)
    local widget = CreateFormDropdown(self, parent, label, options, key, db, callback, info)
    widget.key, widget.db, widget.callback, widget.info = key, db, callback, info
    widgets[#widgets + 1] = widget
    return widget
end
local rows = Extract("QUI_Options/shared.lua", "-- BEGIN setting row state", "-- END setting row state")
assert(loader("return function(ns, QUI, Helpers)\n" .. rows .. "\nend"))()(ns, _G.QUI, ns.Helpers)
local BuildSettingRow = ns.QUI_Options.BuildSettingRow
function ns.QUI_Options.BuildSettingRow(parent, label, widget, ...)
    local row = BuildSettingRow(parent, label, widget, ...)
    widget.rowLabel = label
    return row
end
assert(loadfile("core/settings_layout_shared.lua"))("QUI", ns)
assert(loadfile("modules/layout/settings/bonus_roll_provider.lua"))("QUI", ns)
assert(feature.nav.tileId == "qol" and feature.nav.subPageIndex == 16)
assert(feature.getDB(profile) == profile.general.bonusRoll)
local content = Frame()
content._quiProviderSync = { providerKey = "bonusRollFrame", surfaceId = "bonusRollTest" }
providers.bonusRollFrame.build(content, "bonusRollFrame")
local function Find(label, difficulty)
    for _, widget in ipairs(widgets) do
        if (widget.rowLabel == label or widget.label == label) and (not difficulty or widget.db == profile.general.bonusRoll.difficulty[difficulty]
            or widget.db == profile.general.bonusRoll.difficulty[difficulty].encounters) then return widget end
    end
    error("Missing widget: " .. label)
end
local function Section(title)
    for _, frame in ipairs(frames) do if frame._sectionTitle == title then return frame end end
    error("Missing section: " .. title)
end
local function Click(label, index)
    for _, widget in ipairs(widgets) do
        if widget.label == label then
            index = (index or 1) - 1
            if index == 0 then assert(widget.enabled ~= false); widget.callback(); return end
        end
    end
    error("Missing button: " .. label)
end
for _, title in ipairs({ "Raids", "World Bosses", "Dungeons & Mythic+", "Delves & Other Content" }) do
    local header = Find(title)
    assert(header.section == title, title .. " captured the previous search section")
    Section(title):SetExpanded(false)
    feature.searchNavigate({ label = title, sectionName = header.section })
    assert(Section(title)._expanded, title .. " search did not open its own section")
end
local db = profile.general.bonusRoll
assert(Find("Show a Chat Link When a Roll Is Hidden").isEnabled == false)
assert(Find("Show Pending Roll").enabled == false)
local master = Find("Enable Bonus Roll Filtering")
assert(master:GetWidth() == 26 and master:GetHeight() == 14, "Master toggle must fit its settings row")
assert(master.point[1] == "RIGHT" and master.point[2] == master.parent and master.point[3] == "RIGHT")
assert(master.track:GetWidth() == 26 and master.track:GetHeight() == 14)
assert(master.track.point[1] == "LEFT" and master.track.point[2] == master and master.track.point[3] == "LEFT")
assert(master.track.point[4] == 0, "Master toggle must not extend beyond its settings row")
assert(master.parent._label.text == "Enable Bonus Roll Filtering" and master.label == nil)
assert(master.parent.paired == Find("Show a Chat Link When a Roll Is Hidden").parent,
    "General toggles must share the two-column settings row")
assert(Find("Show Pending Roll").parent.paired == Find("Clear All Filters").parent)
assert(Find("Hide Normal Dungeon Rolls").parent.paired == Find("Hide Heroic Dungeon Rolls").parent)
assert(Find("Boss A", 14).parent.paired == Find("Boss B", 14).parent)
master.track.scripts.OnClick(master.track)
assert(db.enabled == true and master.GetValue() == true)
assert(Find("Show a Chat Link When a Roll Is Hidden").isEnabled)
master.track.scripts.OnClick(master.track)
assert(db.enabled == false and master.GetValue() == false)
assert(Find("Show a Chat Link When a Roll Is Hidden").isEnabled == false)
master.track.scripts.OnClick(master.track)
assert(Find("Show a Chat Link When a Roll Is Hidden").isEnabled)
local difficulty = Find("Raid Difficulty")
local notificationsBeforeSelection = notified
for _, id in ipairs({ 15, 16, 17, 220, 14 }) do
    difficulty:SetValue(id)
    assert(difficulty.GetValue() == id)
    for _, option in ipairs(difficulty.options) do
        if option.value == id then
            assert(difficulty.dropdown.selected.text == option.text)
            assert(Find("Hide All " .. option.text .. " Raid Rolls").parent.parent.parent:IsShown())
        end
    end
    assert(notified == notificationsBeforeSelection, "Raid navigation must not trigger a structural provider rebuild")
end
Find("Boss A", 14):SetValue(true)
assert(db.difficulty[14].encounters[101] == true and db.difficulty[15].encounters[101] == nil)
assert(Find("Boss A", 14).info.searchable == false and Find("Boss A", 14).info.pinnable == false)
Find("Hide All Normal Raid Rolls"):SetValue(true)
assert(Find("Boss A", 14).isEnabled == false and db.difficulty[14].encounters[101])
Find("Hide All Normal Raid Rolls"):SetValue(false)
assert(Find("Boss A", 14).isEnabled)
Click("Select All", 2)
assert(db.difficulty[14].encounters[101] and db.difficulty[14].encounters[102])
Click("Clear Selection", 2)
assert(db.difficulty[14].encounters[101] == false and db.difficulty[14].encounters[102] == false)
local raid = Section("Raids")
local before = content:GetHeight()
raid:SetExpanded(false)
assert(content:GetHeight() < before)
feature.searchNavigate({ label = "Hide All Mythic Raid Rolls", sectionName = "Raids" })
assert(raid._expanded and Find("Raid Difficulty").db.difficulty == 16)
local collapsedHeight = content:GetHeight()
Section("Group 16"):SetExpanded(true)
assert(content:GetHeight() > collapsedHeight)
Section("Group 16"):SetExpanded(false)
assert(content:GetHeight() == collapsedHeight)
local minimum = Find("Minimum Key Level")
assert(minimum.parent.parent:IsShown() == false)
Find("Mythic+ Rolls"):SetValue("minimum")
assert(minimum.parent.parent:IsShown())
Find("Mythic+ Rolls"):SetValue("show")
assert(minimum.parent.parent:IsShown() == false)
feature.searchNavigate({ label = "Minimum Key Level", sectionName = "Dungeons & Mythic+" })
assert(minimum.parent.parent:IsShown() and db.mythicPlus.mode == "show")
assert(Section("Dungeons & Mythic+")._expanded)
Find("Mythic+ Rolls"):SetValue("hide")
assert(minimum.parent.parent:IsShown() == false)
Find("Mythic+ Rolls"):SetValue("minimum")
Find("Mythic+ Rolls"):SetValue("show")
assert(minimum.parent.parent:IsShown() == false)
assert(db.difficulty[999] and not db.difficulty[233])
pending = { token = 1 }
Find("Show Pending Roll").scripts.OnUpdate(nil, 0.5)
Click("Show Pending Roll")
assert(recovered == 1)
pending = nil
Find("Show Pending Roll").scripts.OnUpdate(nil, 0.5)
assert(Find("Show Pending Roll").enabled == false)
Click("Clear All Filters")
assert(cleared == 0 and GUI.confirmation)
GUI.confirmation.onAccept()
assert(cleared == 1 and notified >= 2)
Click("Clear All Filters")
local originalProfile = profile
profile = { general = { bonusRoll = {} } }
GUI.confirmation.onAccept()
assert(cleared == 1)
profile = originalProfile
ns.QUI_LayoutMode_Utils._layoutModePositionOnly = true
local drawer = Frame()
providers.bonusRollFrame.build(drawer, "bonusRollFrame")
assert(drawer.sections[1] == "position" and drawer.sections[2] == "link")
ns.QUI_LayoutMode_Utils._layoutModePositionOnly = false
ns.BonusRoll = nil
widgets = {}
profile.general.bonusRoll.difficulty[14] = { hide = true }
providers.bonusRollFrame.build(Frame(), "bonusRollFrame")
assert(Find("Hide All Mythic Raid Rolls") and Find("Hide All World Boss Rolls") and Find("Hide Delve Rolls"))
assert(profile.general.bonusRoll.difficulty[14].encounters)
print("bonus_roll_settings_test: passed")
