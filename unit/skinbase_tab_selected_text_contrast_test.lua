-- tests/unit/skinbase_tab_selected_text_contrast_test.lua
-- Run: luajit tests/unit/skinbase_tab_selected_text_contrast_test.lua
--
-- R1 (UI polish, Phase 0): the selected Blizzard tab must read as SELECTED.
-- RefreshTabSelected used to paint the selected label 0.9 grey and the rest
-- 0.55 grey, and IsTabSelected returned false for any tab with `isDisabled`
-- set — but PanelTemplates disables the selected tab, so the active tab of
-- every skinned window looked greyed out. Contract (palette ladder):
--   selected            -> white, alpha 1.0 (+ 1px accent underline)
--   unselected          -> white, alpha 0.55
--   disabled+unselected -> white, alpha 0.30
-- luacheck: globals CreateFrame C_Timer hooksecurefunc PanelTemplates_GetSelectedTab PanelTemplates_SetTab ScrollUtil

local unpack = table.unpack or unpack

local function NewTexture()
    local t = { alpha = 1 }
    function t:SetAlpha(a) self.alpha = a end
    function t:SetTexture(f) self.file = f end
    function t:SetColorTexture(r, g, b, a) self.colorTexture = { r, g, b, a } end
    function t:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
    function t:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
    function t:SetText(text) self.text = text end
    function t:SetFont(font, size, flags) self.font, self.fontSize, self.fontFlags = font, size, flags end
    function t:GetFont() return self.font, self.fontSize or 12, self.fontFlags end
    function t:ClearAllPoints() self.points = {} end
    function t:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
    function t:SetHeight(h) self.height = h end
    function t:SetWidth(w) self.width = w end
    function t:SetSize(w, h) self.width, self.height = w, h end
    function t:GetWidth() return self.width or 0 end
    function t:GetStringWidth() return self.stringWidth or 0 end
    function t:Show() self.visible = true end
    function t:Hide() self.visible = false end
    function t:SetShown(v) self.visible = v and true or false end
    function t:IsShown() return self.visible end
    function t:SetDrawLayer() end
    function t:IsObjectType(objType) return objType == "Texture" end
    return t
end

local function NewFrame(parent)
    local f = { parent = parent, textures = {}, points = {}, frameLevel = 4, scripts = {}, enabled = true }
    function f:CreateTexture() local t = NewTexture(); self.textures[#self.textures + 1] = t; return t end
    function f:CreateFontString() return NewTexture() end
    function f:SetAllPoints() end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetFrameLevel(l) self.frameLevel = l end
    function f:GetFrameLevel() return self.frameLevel end
    function f:EnableMouse() end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:SetWidth(w) self.width = w end
    function f:GetWidth() return self.width or 0 end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:GetRegions() return unpack(self.textures) end
    function f:GetNumRegions() return #self.textures end
    function f:GetHighlightTexture() self.highlight = self.highlight or NewTexture(); return self.highlight end
    function f:GetPushedTexture() return nil end
    function f:GetNormalTexture() return nil end
    function f:GetDisabledTexture() return nil end
    function f:GetFontString() return self.Text end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:HookScript(event, fn) self.scripts[event] = fn end
    function f:SetNormalFontObject(o) self.normalFontObject = o end
    function f:SetHighlightFontObject(o) self.highlightFontObject = o end
    function f:SetDisabledFontObject(o) self.disabledFontObject = o end
    function f:IsEnabled() return self.enabled end
    function f:GetParent() return self.parent end
    return f
end

function CreateFrame(_, _, parent) return NewFrame(parent) end
C_Timer = { After = function(_, fn) fn() end }
function hooksecurefunc(target, method, hook)
    if type(target) == "string" then
        local original = _G[target]
        if type(original) ~= "function" then return end
        _G[target] = function(...)
            local results = { original(...) }
            hook(...)
            return unpack(results)
        end
        return
    end
    if type(target) ~= "table" or type(target[method]) ~= "function" then return end
    local original = target[method]
    target[method] = function(self, ...)
        original(self, ...)
        hook(self, ...)
    end
end
function CreateFont(name)
    local obj = { name = name }
    function obj:SetFont(font, size, flags) self.font, self.size, self.flags = font, size, flags end
    function obj:SetFontObject(o) self.fontObject = o end
    function obj:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
    return obj
end
function PanelTemplates_GetSelectedTab(frame) return frame.selectedTab end
function PanelTemplates_SetTab(frame, id) frame.selectedTab = id end
ScrollUtil = { AddAcquiredFrameCallback = function() end }

local function CreateStateTable()
    local tbl = setmetatable({}, { __mode = "k" })
    return tbl, function(k) local s = tbl[k]; if not s then s = {}; tbl[k] = s end; return s end
end

local ns = {
    SafeCall = function(_policy, fn, ...) return pcall(fn, ...) end,
    SafeCallMethod = function(_policy, obj, name, ...) return pcall(function(...) return obj[name](obj, ...) end, ...) end,
    SafeCallMethodIfPresent = function(_policy, obj, name, ...)
        if obj == nil then return nil end
        local okP, m = pcall(function() return obj[name] end)
        if not okP then return false end
        if m == nil then return nil end
        return pcall(m, obj, ...)
    end,
    Helpers = {
        CHROME = { BORDER_PX = 1, BG_FALLBACK = { 0.05, 0.05, 0.05, 0.95 }, BORDER_FALLBACK = { 0, 0, 0, 1 }, BUTTON_BOOST = 0.07, SCROLLROW_BOOST = 0.03, DEPTH = { PANEL = { boost = 0, alpha = 0.95 }, SUBPANEL = { boost = 0.04, alpha = 0.85 }, ROW = { boost = 0.07, alpha = 0.75 } } },
        CreateStateTable = CreateStateTable,
        GetCore = function()
            return {
                GetPixelSize = function() return 1 end,
                db = { profile = { general = { applyGlobalFontToBlizzard = true } } },
            }
        end,
        SafeToNumber = function(v, d) return tonumber(v) or d end,
        GetSkinBorderColor = function() return 0.6, 0.7, 0.8, 1 end,
        GetSkinBgColorWithOverride = function() return 0.1, 0.2, 0.3, 0.9 end,
        GetSkinBarColor = function() return 0.5, 0.5, 0.5, 1 end,
        GetGeneralFont = function() return "Interface\\QUIFont.ttf" end,
        GetGeneralFontOutline = function() return "OUTLINE" end,
    },
    UIKit = { RegisterScaleRefresh = function() end },
}

assert(loadfile("core/uikit.lua"))("QUI", ns)
local SkinBase = ns.SkinBase

local function NewTab(owner)
    local tab = NewFrame(owner)
    tab.Text = NewTexture()
    tab.Left, tab.Middle, tab.Right = NewTexture(), NewTexture(), NewTexture()
    return tab
end

local function near(a, b) return math.abs((a or -99) - b) < 1e-9 end

---------------------------------------------------------------------------
-- (a) PanelTemplates-style owner: selected tab is white 1.0, others 0.55.
---------------------------------------------------------------------------
local owner = NewFrame()
local tabA, tabB, tabC = NewTab(owner), NewTab(owner), NewTab(owner)
owner.Tabs = { tabA, tabB, tabC }
owner.selectedTab = 1
SkinBase.SkinTabGroup(owner.Tabs, owner)

local function TextColor(tab) return tab.Text.textColor end
assert(TextColor(tabA)[1] == 1 and TextColor(tabA)[2] == 1 and TextColor(tabA)[3] == 1 and TextColor(tabA)[4] == 1,
    "selected tab label must be pure white at alpha 1.0 (was 0.9 grey)")
assert(TextColor(tabB)[1] == 1 and near(TextColor(tabB)[4], 0.55),
    "unselected tab label must be white at alpha 0.55 (not a grey RGB)")

-- PanelTemplates disables the SELECTED tab via tab:Disable() and may also carry
-- `isDisabled` while still being the owner's selectedTab. Selection signals must
-- win over the disabled flag.
tabA.isDisabled = 1
tabA.enabled = false
SkinBase.RefreshTabSelected(tabA, owner)
assert(TextColor(tabA)[1] == 1 and TextColor(tabA)[4] == 1,
    "selected tab with isDisabled=true must stay white 1.0 (PanelTemplates disables the selected tab)")

-- A tab that is disabled AND not selected drops to the disabled rung (0.30).
tabC.isDisabled = 1
tabC.enabled = false
SkinBase.RefreshTabSelected(tabC, owner)
assert(TextColor(tabC)[1] == 1 and near(TextColor(tabC)[4], 0.30),
    "disabled + unselected tab must be white at alpha 0.30")

-- Selection change repaints: B becomes selected (white 1), A drops to 0.55.
tabA.isDisabled = nil
tabA.enabled = true
owner.selectedTab = 2
tabB.scripts.OnClick(tabB)
assert(TextColor(tabB)[4] == 1 and near(TextColor(tabA)[4], 0.55),
    "text alpha must follow the selected tab after a click")

---------------------------------------------------------------------------
-- (a2) Accent underline: 1px, shown only on the selected tab.
---------------------------------------------------------------------------
local ulB = SkinBase.GetFrameData(tabB, "tabUnderline")
local ulA = SkinBase.GetFrameData(tabA, "tabUnderline")
assert(ulB and ulB:IsShown(), "selected tab must show the accent underline")
assert(ulA and not ulA:IsShown(), "unselected tab must hide the accent underline")
assert(ulB.height == 1, "underline must be exactly 1 physical pixel tall at pixel size 1")
assert(ulB.colorTexture and near(ulB.colorTexture[1], 0.6) and near(ulB.colorTexture[2], 0.7),
    "underline must use the skin accent colour")

---------------------------------------------------------------------------
-- (a3) Hover on an unselected tab lifts the label to 0.85; leave restores.
---------------------------------------------------------------------------
local hoverOwner = NewFrame()
local hA, hB = NewTab(hoverOwner), NewTab(hoverOwner)
hoverOwner.Tabs = { hA, hB }
hoverOwner.selectedTab = 1
SkinBase.SkinTabGroup(hoverOwner.Tabs, hoverOwner, { hover = true })
hB.scripts.OnEnter(hB)
assert(near(TextColor(hB)[4], 0.85), "hovered unselected tab label must be white at alpha 0.85")
hB.scripts.OnLeave(hB)
assert(near(TextColor(hB)[4], 0.55), "leaving an unselected tab must restore alpha 0.55")
hA.scripts.OnEnter(hA)
assert(TextColor(hA)[4] == 1, "hovering the selected tab must keep it at alpha 1.0")

---------------------------------------------------------------------------
-- (a4) Font objects: the disabled font object of a selected tab must not be
-- the grey "disabled" colour (PanelTemplates renders the selected tab through
-- its DisabledFontObject).
---------------------------------------------------------------------------
local selObj = hA.disabledFontObject
assert(type(selObj) == "table" and selObj.textColor and selObj.textColor[1] == 1 and selObj.textColor[4] == 1,
    "selected tab's disabled font object must carry the selected (white 1.0) colour")

---------------------------------------------------------------------------
-- (a5) TabSystem (isSelected) tabs: SetTabVisuallySelected refresh path.
---------------------------------------------------------------------------
local sysOwner = NewFrame()
sysOwner.TabSystem = NewFrame()
local sA, sB = NewTab(sysOwner.TabSystem), NewTab(sysOwner.TabSystem)
sA.tabID, sB.tabID = 1, 2
sysOwner.TabSystem.tabs = { sA, sB }
sysOwner.TabSystem.selectedTabID = 1
function sysOwner.TabSystem:GetSelectedTab() return self.selectedTabID end
function sysOwner.TabSystem:SetTab(id) self:SetTabVisuallySelected(id) end
function sysOwner.TabSystem:SetTabVisuallySelected(id)
    self.selectedTabID = id
    for _, t in ipairs(self.tabs) do t:SetTabSelected(t.tabID == id) end
end
for _, t in ipairs(sysOwner.TabSystem.tabs) do
    function t:SetTabSelected(v) self.isSelected = v end
end
SkinBase.SkinTabGroup(sysOwner.TabSystem.tabs, sysOwner)
assert(TextColor(sA)[4] == 1 and near(TextColor(sB)[4], 0.55), "TabSystem initial selection must paint white/0.55")
sysOwner.TabSystem:SetTabVisuallySelected(2)
assert(TextColor(sB)[4] == 1 and near(TextColor(sA)[4], 0.55),
    "SetTabVisuallySelected must repaint tab text (hook must be installed)")

print("OK: skinbase_tab_selected_text_contrast_test")
