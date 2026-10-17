local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinLegacySystem = true
env.profile.general.applyGlobalFontToBlizzard = true
local corpus = "tests/clients/forever/framexml/Interface/AddOns/"
_G.CreateFromMixins = function(...)
    local result = {}
    for _, mixin in ipairs({...}) do for key, value in pairs(mixin) do result[key] = value end end
    return result
end
_G.CallbackRegistryMixin = {}
local function color(r, g, b)
    return { GetRGB = function() return r, g, b end }
end
_G.NORMAL_FONT_COLOR = color(1, .82, 0)
_G.WHITE_FONT_COLOR = color(1, 1, 1)
_G.DISABLED_FONT_COLOR = color(.5, .5, .5)
_G.HIGHLIGHT_FONT_COLOR = color(1, 1, 1)
_G.TextureKitConstants = { UseAtlasSize = true }
local unviewed, viewed, sounds = {}, {}, 0
_G.LegacyChallengeViewedUtil = {
    CategoryHasUnviewedChallenges = function(id) return unviewed[id] == true end,
    MarkCategoryViewed = function(id) viewed[id] = true end,
}
_G.SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
_G.PlaySound = function() sounds = sounds + 1 end
assert(loadfile(corpus .. "Blizzard_SharedXML/ListTemplates.lua"))()
assert(loadfile(corpus .. "Blizzard_LegacySystem/Blizzard_LegacyChallengeCategoryList.lua"))()
local root = env.NewFrame("Frame")
root.CloseButton = false
root.Tabs = {}
root.Pages = {}
_G.LegacySystemFrame = root
local category = env.NewFrame("Frame", nil, root)
root.ChallengesPage = { CategoryList = category }
for key, value in pairs(_G.LegacyChallengeCategoryListMixin) do category[key] = value end
local box = env.NewFrame("Frame", nil, category)
category.ScrollBox = box
local rows = {}
function box:HasView() return true end
function box:ForEachFrame(fn) for _, row in ipairs(rows) do fn(row) end end
local acquired
_G.ScrollUtil.AddAcquiredFrameCallback = function(_, fn) acquired = fn end
local registry, callbacks = {}, {}
ns.Registry = { Register = function(_, key, entry) registry[key] = entry end }
skin.OnAddOnLoaded = function(addon, fn) callbacks[addon] = fn end
local function node(id, parent, collapsed)
    local n = { data = { categoryInfo = { id = id, name = "Category " .. id }, isParent = parent }, collapsed = collapsed }
    function n:GetData() return self.data end
    function n:IsCollapsed() return self.collapsed end
    function n:ToggleCollapsed() self.collapsed = not self.collapsed end
    return n
end
local function row(n, selected)
    local b = env.NewFrame("Button", nil, box)
    b:SetSize(330, 25)
    b.RegisterForWidgetSet = false
    b.DisabledTexture = false
    b.ButtonText = b:CreateFontString()
    function b:GetFontString() return self.ButtonText end
    function b:IsMouseMotionFocus() return self.mouseOver == true end
    function b:GetData() return self.node:GetData() end
    b.normalTexture = b:CreateTexture()
    b.highlightTexture = b:CreateTexture()
    b.NotificationIcon = b:CreateTexture()
    b.NotificationIcon:SetAtlas("UI-HUD-MicroMenu-Communities-Icon-Notification")
    b.NotificationIcon:SetAlpha(.65)
    b.CollapseButton = env.NewFrame("Button", nil, b)
    b.CollapseButton.Icon = b.CollapseButton:CreateTexture()
    b.CollapseButton.UpdateCollapsedState = _G.CollapseButtonMixin.UpdateCollapsedState
    for key, value in pairs(_G.ListHeaderVisualMixin) do b[key] = value end
    for key, value in pairs(_G.LegacyChallengeCategoryMixin) do b[key] = value end
    b:SetScript("OnEnter", b.OnEnter)
    b:SetScript("OnLeave", b.OnLeave)
    b:SetScript("OnClick", function(self)
        category:SelectCategory(self:GetData(), self:GetNode(), self, true)
    end)
    b:Init(n, selected)
    return b
end
local parentNode, leafNode = node(1, true, true), node(2, false, false)
unviewed[1] = true
local parent, leaf = row(parentNode, false), row(leafNode, true)
rows = { parent, leaf }
local click = parent:GetScript("OnClick")
category.selectionBehavior = {
    ClearSelections = function() category.cleared = (category.cleared or 0) + 1 end,
    Select = function() error("unexpected leaf selection") end,
}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI", ns)
callbacks.Blizzard_LegacySystem()
env.RunTimers()
local function check(b, selected)
    local bd = skin.GetBackdrop(b)
    assert(bd and bd._quiRoundedSurface, "Legacy categories must use shared rounded category chrome")
    assert(b:GetNormalTexture():GetAlpha() == 0 and b:GetHighlightTexture():GetAlpha() == 0,
        "native category card art must remain suppressed")
    assert(b.NotificationIcon:GetAlpha() == .65, "notification badge opacity must remain")
    assert(b.ButtonText.textColor[1] == (selected and 1 or .92),
        "native selection must control neutral/selected category typography")
    assert(b:GetWidth() == 330 and b:GetHeight() == 25, "native row geometry must remain")
end
check(parent, false); check(leaf, true)
assert(parent.NotificationIcon:IsShown() and not leaf.NotificationIcon:IsShown(),
    "native badge visibility must remain")
assert(parent.CollapseButton:IsShown() and not leaf.CollapseButton:IsShown()
    and parent.CollapseButton.Icon.atlas == "common-button-list-plus", "native collapse glyph must remain")
parent:Fire("OnClick")
check(parent, true); check(leaf, false)
assert(viewed[1] and sounds == 1 and category.cleared == 1 and not parentNode:IsCollapsed()
    and parent.CollapseButton.Icon.atlas == "common-button-list-minus", "native parent click must toggle and select once")
parent:Fire("OnEnter"); parent:Fire("OnLeave"); check(parent, true)
local replacement = node(3, false, false)
unviewed[3] = true
parent:Init(replacement, false)
check(parent, false)
assert(not parent.CollapseButton:IsShown() and parent.NotificationIcon:IsShown()
    and parent.NotificationIcon.points[1][2] == -10, "native pooled leaf layout must remain")
parent:GetNormalTexture():SetAlpha(1); parent:GetHighlightTexture():SetAlpha(.4)
check(parent, false)
local later = row(node(4, true, true), false)
rows[#rows + 1] = later
acquired(box, later); env.RunTimers(); check(later, false)
local backdrop = skin.GetBackdrop(later)
registry.skinLegacySystem.refresh()
assert(skin.GetBackdrop(later) == backdrop and sounds == 1 and parent:GetScript("OnClick") == click,
    "theme refresh must reuse surfaces and retain native handler ownership")
env.profile.general.skinLegacySystem = false
local disabled = row(node(5, true, false), false)
acquired(box, disabled); env.RunTimers()
assert(not skin.GetBackdrop(disabled) and disabled:GetNormalTexture():GetAlpha() == 1,
    "disabled skin must leave newly acquired categories native")
env.profile.general.skinLegacySystem = true
local forbidden = row(node(6, true, false), false)
function forbidden:IsForbidden() return true end
acquired(box, forbidden); env.RunTimers()
assert(not skin.GetBackdrop(forbidden), "forbidden categories must remain untouched")
print("Legacy category native lifecycle passed")
