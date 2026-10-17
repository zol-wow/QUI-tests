-- tests/unit/skinbase_category_text_accent_test.lua
-- Run: luajit tests/unit/skinbase_category_text_accent_test.lua
--
-- R2 (UI polish, Phase 0): the skin BORDER colour is not a text colour. With
-- a custom black border, or "hide skin borders" (alpha 0), every label that
-- was painted from GetSkinBorderColor() went black / invisible. SkinBase must
-- expose GetSkinTextAccent(): border RGB (alpha 1) only when the border is
-- opaque enough (a >= 0.5) and bright enough (rel. luminance >= 0.35),
-- otherwise white. RefreshCategorySelected must route through it, and the
-- category selection resolver must accept more than SelectedTexture.
-- luacheck: globals CreateFrame C_Timer hooksecurefunc ScrollUtil STANDARD_TEXT_FONT

local unpack = table.unpack or unpack
local function NewTexture() local t = { a = 1 }
    function t:ClearAllPoints() end function t:SetPoint() end function t:SetHeight() end
    function t:SetWidth() end function t:Show() self.shown = true end function t:Hide() self.shown = false end
    function t:IsShown() return self.shown end function t:SetAlpha(v) self.a = v end
    function t:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
    function t:SetTexture() end function t:SetColorTexture() end function t:SetVertexColor() end
    function t:SetAllPoints() end function t:IsObjectType(o) return o == "Texture" end
    return t end
local function NewFrame()
    local f = { textures = {}, level = 4 }
    function f:CreateTexture() local t = NewTexture(); self.textures[#self.textures+1] = t; return t end
    function f:SetAllPoints() end function f:SetFrameLevel(l) self.level = l end
    function f:GetFrameLevel() return self.level end function f:EnableMouse() end
    function f:Show() end function f:Hide() end function f:HookScript(e, fn) self["on"..e] = fn end
    function f:GetRegions() return unpack(self.textures) end
    function f:GetNumRegions() return #self.textures end
    function f:GetHighlightTexture() return nil end function f:GetNormalTexture() return nil end
    function f:GetPushedTexture() return nil end
    function f:GetParent() return self.parent end
    function f:SetBackdrop() end
    function f:SetBackdropColor(...) self.bgc = { ... } end
    function f:SetBackdropBorderColor(...) self.bdc = { ... } end
    return f
end
CreateFrame = function() return NewFrame() end
C_Timer = { After = function(_, fn) fn() end }
function hooksecurefunc() end
ScrollUtil = { AddAcquiredFrameCallback = function() end }
STANDARD_TEXT_FONT = "x"
local function CreateStateTable() local t = setmetatable({}, { __mode = "k" }); return t, function(k) local s=t[k]; if not s then s={}; t[k]=s end; return s end end
local CHROME = { BORDER_PX=1, BG_FALLBACK={0.05,0.05,0.05,0.95}, BORDER_FALLBACK={0,0,0,1}, BUTTON_BOOST=0.07, SCROLLROW_BOOST=0.03, DEPTH={PANEL={boost=0,alpha=0.95},SUBPANEL={boost=0.04,alpha=0.85},ROW={boost=0.07,alpha=0.75}} }
local border = {0.6,0.7,0.8,1}
local ns = { Helpers = { CHROME=CHROME, CreateStateTable=CreateStateTable,
    GetCore = function() return {} end, SafeToNumber = function(v,d) return tonumber(v) or d end,
    GetSkinBorderColor = function() return border[1],border[2],border[3],border[4] end,
    GetSkinBgColorWithOverride = function() return 0.1,0.2,0.3,0.9 end,
    GetGeneralFont = function() return "Q" end, GetGeneralFontOutline = function() return "" end },
    UIKit = { RegisterScaleRefresh = function() end } }
assert(loadfile("core/uikit.lua"))("QUI", ns)
local SkinBase = ns.SkinBase

assert(type(SkinBase.GetSkinTextAccent) == "function", "SkinBase.GetSkinTextAccent must exist next to GetSkinColors")

local function near(a, b) return math.abs((a or -99) - b) < 1e-9 end

---------------------------------------------------------------------------
-- GetSkinTextAccent contract
---------------------------------------------------------------------------
local r, g, b, a = SkinBase.GetSkinTextAccent()
assert(near(r, 0.6) and near(g, 0.7) and near(b, 0.8) and a == 1,
    "bright opaque border -> accent text = border RGB at alpha 1")

border = { 0, 0, 0, 1 }
r, g, b, a = SkinBase.GetSkinTextAccent()
assert(r >= 0.9 and g >= 0.9 and b >= 0.9 and a == 1, "black border -> white text (luminance floor)")

border = { 0.9, 0.9, 0.9, 0 }
r, g, b, a = SkinBase.GetSkinTextAccent()
assert(r >= 0.9 and g >= 0.9 and b >= 0.9 and a == 1, "hidden border (alpha 0) -> white text at alpha 1")

border = { 0.9, 0.9, 0.9, 0.4 }
r, g, b, a = SkinBase.GetSkinTextAccent()
assert(r >= 0.9 and a == 1, "translucent border (alpha < 0.5) -> white text at alpha 1")

border = { 0.2, 0.3, 0.9, 1 } -- rel. luminance ~0.32: too dark to be text
r, g, b = SkinBase.GetSkinTextAccent()
assert(r >= 0.9 and g >= 0.9 and b >= 0.9, "dark saturated border (luminance < 0.35) -> white text")

border = { 0.376, 0.647, 0.980, 1 } -- default QUI blue, luminance ~0.61
r, g, b = SkinBase.GetSkinTextAccent()
assert(near(r, 0.376) and near(g, 0.647), "default accent passes the luminance floor unchanged")

---------------------------------------------------------------------------
-- RefreshCategorySelected: selected text readable with black / hidden border
---------------------------------------------------------------------------
border = { 0, 0, 0, 1 }
local btn = NewFrame()
btn.SelectedTexture = NewTexture(); btn.SelectedTexture:Show()
btn.Label = NewTexture()
SkinBase.SkinCategoryButton(btn)
local c = btn.Label.textColor
assert(c[1] >= 0.9 and c[2] >= 0.9 and c[3] >= 0.9 and c[4] == 1,
    "selected category text must be readable (>= 0.9 RGB, alpha 1) with a black skin border")

border = { 0.5, 0.5, 0.5, 0 }
SkinBase.RefreshWidget(btn)
c = btn.Label.textColor
assert(c[1] >= 0.9 and c[2] >= 0.9 and c[3] >= 0.9 and c[4] == 1,
    "selected category text must be readable with hidden (alpha 0) skin borders")

-- Explicit selectedTextColor opt still wins.
border = { 0, 0, 0, 1 }
local btn2 = NewFrame()
btn2.SelectedTexture = NewTexture(); btn2.SelectedTexture:Show()
btn2.Label = NewTexture()
SkinBase.SkinCategoryButton(btn2, { selectedTextColor = { 1, 1, 1, 1 }, textColor = { 0.72, 0.78, 0.85, 1 } })
assert(btn2.Label.textColor[1] == 1, "selectedTextColor opt is honoured")
btn2.SelectedTexture:Hide()
SkinBase.RefreshCategorySelected(btn2)
assert(near(btn2.Label.textColor[1], 0.72), "textColor opt is honoured for the unselected state")

---------------------------------------------------------------------------
-- Selection resolver: more than SelectedTexture
---------------------------------------------------------------------------
border = { 0.6, 0.7, 0.8, 1 }
local function Selected(button)
    local bd = SkinBase.GetBackdrop(button)
    return near(bd._quiBgA, 0.75)
end

local b3 = NewFrame(); b3.Label = NewTexture()
b3.isSelected = true
SkinBase.SkinCategoryButton(b3)
assert(Selected(b3), "resolver must accept button.isSelected")

local b4 = NewFrame(); b4.Label = NewTexture()
b4.selected = true
SkinBase.SkinCategoryButton(b4)
assert(Selected(b4), "resolver must accept button.selected")

local b5 = NewFrame(); b5.Label = NewTexture()
function b5:IsSelected() return true end
SkinBase.SkinCategoryButton(b5)
assert(Selected(b5), "resolver must accept button:IsSelected()")

local b6 = NewFrame(); b6.Label = NewTexture()
SkinBase.SkinCategoryButton(b6, { isSelected = function(button) return button.custom == true end })
assert(not Selected(b6), "opts.isSelected callback false -> unselected")
b6.custom = true
SkinBase.RefreshCategorySelected(b6)
assert(Selected(b6), "opts.isSelected callback true -> selected")

local list = NewFrame()
list.selectedID = 7
local b7 = NewFrame(); b7.Label = NewTexture(); b7.parent = list; b7.categoryID = 7
SkinBase.SkinCategoryButton(b7)
assert(Selected(b7), "resolver must accept owner.selectedID matching the button id")
list.selectedID = 8
SkinBase.RefreshCategorySelected(b7)
assert(not Selected(b7), "owner.selectedID mismatch -> unselected")

local list2 = NewFrame()
local b8 = NewFrame(); b8.Label = NewTexture(); b8.parent = list2
function list2:GetSelected() return b8 end
SkinBase.SkinCategoryButton(b8)
assert(Selected(b8), "resolver must accept owner:GetSelected() returning the button")

print("OK: skinbase_category_text_accent_test")
