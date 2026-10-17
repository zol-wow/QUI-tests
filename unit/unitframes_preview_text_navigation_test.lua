local function NewFrame(parent)
    local frame = { parent = parent, shown = true, scripts = {}, width = 400, height = 100 }
    function frame:SetAllPoints(region) self.anchor = region end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:SetWidth(width) self.width = width end
    function frame:SetHeight(height) self.height = height end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:GetParent() return self.parent end
    function frame:GetFrameLevel() return 1 end
    function frame:SetScript(name, callback) self.scripts[name] = callback end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:SetShown(value) self.shown = value end
    function frame:CreateTexture() return NewFrame(self) end
    function frame:CreateFontString() return NewFrame(self) end
    function frame:GetChildren() end
    return setmetatable(frame, { __index = function() return function() end end })
end
_G.CreateFrame = function(_, _, parent) return NewFrame(parent) end
_G.UnitName = function() return "Player" end

local unit = { width = 200, height = 40, showName = true, showHealth = true }
local gui = { Tooltip = {} }
local navigation, tooltip, mock
function gui:CreateFormDropdown(parent) return NewFrame(parent) end
function gui.Tooltip:Show(anchor, _, options) tooltip = { anchor = anchor, title = options.title } end
function gui.Tooltip:Hide() tooltip = nil end
function gui:NavigateSearchResult(entry, options) navigation = { entry = entry, options = options } end
_G.QUI = { GUI = gui, db = { profile = { quiUnitFrames = { player = unit, target = unit }, general = {} } } }

local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Helpers = { SafeValue = function(value) return value end, ApplyFontWithFallback = function() end, ApplyTextureStyle = function() end },
    QUI_UnitFramesSettingsModel = {
        NormalizeUnitKey = function(key) return key end,
        IsPerUnitTab = function() return true end,
        GetTabDefinitions = function() return { { key = "general" }, { key = "text" } } end,
    },
    QUI_UnitFramesBodyPreview = { Build = function(frame) mock = frame end },
}
assert(loadfile("core/settings/full_surface.lua"))("QUI", ns)
assert(loadfile("QUI_UnitFrames/unitframes/settings/unit_frames_surface.lua"))("QUI", ns)
local surface = ns.QUI_UnitFramesSettingsSurface
surface.preview.build(NewFrame(), { autoHeight = false })
assert(mock._nameTextButton.anchor == mock._nameText and mock._healthTextButton.anchor == mock._healthText,
    "preview click targets must follow their live text bounds")

for _, selected in ipairs({ "player", "target", "player" }) do
    surface.SetSelectedUnit(selected)
    for _, target in ipairs({ { mock._nameTextButton, "Name Text" }, { mock._healthTextButton, "Health Text" } }) do
        target[1].scripts.OnEnter(target[1])
        assert(tooltip and tooltip.anchor == target[1] and tooltip.title == target[2])
        target[1].scripts.OnClick()
        assert(not tooltip)
        local entry, options = navigation.entry, navigation.options
        assert(entry.featureId == "unitFramesPage" and entry.tileId == "unit_frames")
        assert(entry.surfaceTabKey == "text" and entry.surfaceUnitKey == selected,
            "preview navigation must resolve the current selected unit at click time")
        assert(entry.sectionName == target[2] and options.scrollToLabel == target[2] and options.pulse == true,
            "preview navigation must scroll and pulse inside the active unit's cached text page")
    end
end

unit.showName, unit.showHealth = false, false
_G.QUI_RefreshUnitFramePreview()
assert(not mock._nameTextButton.shown and not mock._healthTextButton.shown,
    "hidden preview labels must not leave invisible click targets")
local previous = navigation
mock._nameTextButton.scripts.OnClick()
mock._healthTextButton.scripts.OnClick()
assert(navigation == previous)
unit.showName, unit.showHealth = true, true
_G.QUI_RefreshUnitFramePreview()
assert(mock._nameTextButton.shown and mock._healthTextButton.shown,
    "reenabling preview text must restore its navigation targets")
print("OK: unitframes_preview_text_navigation_test")
