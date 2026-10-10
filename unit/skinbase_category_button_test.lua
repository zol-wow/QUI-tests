-- tests/unit/skinbase_category_button_test.lua
-- Run: lua tests/unit/skinbase_category_button_test.lua
-- #2: SkinCategoryButton applies selected vs unselected backdrop by SelectedTexture
-- visibility; SkinButton honors belowChildren; SkinEditBox honors alpha opts.

-- luacheck: globals CreateFrame C_Timer hooksecurefunc ScrollUtil STANDARD_TEXT_FONT
local unpack = table.unpack or unpack
local function NewTexture() local t = { a = 1 }
    function t:ClearAllPoints() end function t:SetPoint() end function t:SetHeight() end
    function t:SetWidth() end function t:Show() self.shown = true end function t:Hide() self.shown = false end
    function t:IsShown() return self.shown end function t:SetAlpha(v) self.a = v end
    function t:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
    function t:SetTexture() end function t:SetColorTexture() end function t:SetVertexColor() end
    function t:SetAllPoints() end function t:IsObjectType(o) return o == "Texture" end
    function t:SetSize(w, h) self.width, self.height = w, h end
    function t:SetTexCoord(...) self.texCoord = {...} end
    function t:SetShown(v) if v then self:Show() else self:Hide() end end
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
    function f:SetBackdrop() end
    function f:SetBackdropColor(...) self.bgc = { ... } end
    function f:SetBackdropBorderColor(...) self.bdc = { ... } end
    function f:GetWidth() return self.width or 100 end
    function f:GetHeight() return self.height or 100 end
    function f:GetLeft() return 0 end
    function f:GetBottom() return 0 end
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
local ns = { Helpers = { AssetPath = [[Interface\AddOns\QUI\assets\]], CHROME=CHROME, CreateStateTable=CreateStateTable,
    GetCore = function() return {} end, SafeToNumber = function(v,d) return tonumber(v) or d end,
    GetSkinBorderColor = function() return border[1],border[2],border[3],border[4] end,
    GetSkinBgColorWithOverride = function() return 0.1,0.2,0.3,0.9 end,
    GetGeneralFont = function() return "Q" end, GetGeneralFontOutline = function() return "" end },
    UIKit = { RegisterScaleRefresh = function() end } }
assert(loadfile("core/uikit.lua"))("QUI", ns)
local SkinBase = ns.SkinBase

assert(type(SkinBase.SkinCategoryButton) == "function", "SkinCategoryButton must exist")
assert(type(SkinBase.RefreshCategorySelected) == "function", "RefreshCategorySelected must exist")

-- Selected button: backdrop = ROW depth (bg + 0.07, alpha 0.75). The manual render
-- path overrides SetBackdropColor → read back via _quiBgA.
local btn = NewFrame()
btn.SelectedTexture = NewTexture(); btn.SelectedTexture:Show()
btn.Label = NewTexture()
SkinBase.SkinCategoryButton(btn)
local bd = SkinBase.GetBackdrop(btn)
assert(math.abs(bd._quiBgA - 0.75) < 1e-9, "selected category button uses ROW alpha 0.75")
assert(math.abs(btn.Label.textColor[1] - 0.6) < 1e-9, "selected category button uses accent text")

-- Unselected: alpha 0.7 (dimmer), border halved
btn.SelectedTexture:Hide()
SkinBase.RefreshCategorySelected(btn)
assert(math.abs(bd._quiBgA - 0.7) < 1e-9, "unselected category button uses dimmer alpha 0.7")
assert(btn.Label.textColor[1] == 1, "unselected category button uses white text")
border = {0.2,0.3,0.4,0.9}
SkinBase.RefreshWidget(btn)
assert(math.abs(bd._quiBorderR - 0.2) < 1e-9 and math.abs(bd._quiBorderA - 0.45) < 1e-9,
    "RefreshWidget must update category selected-state colors")

-- SkinButton belowChildren lowers the backdrop frame level
local b2 = NewFrame(); b2.level = 5
SkinBase.SkinButton(b2, { belowChildren = true })
assert(SkinBase.GetBackdrop(b2):GetFrameLevel() == 4, "belowChildren lowers backdrop level by 1")

-- SkinEditBox alpha opts
local eb = NewFrame()
SkinBase.SkinEditBox(eb, { borderAlpha = 0.5, bgAlpha = 0.8 })
local ebd = SkinBase.GetBackdrop(eb)
assert(math.abs(ebd._quiBgA - 0.8) < 1e-9, "SkinEditBox bgAlpha override applied")

ns.Helpers.GetWindowColors = function() return 0.12, 0.16, 0.18, 0.8, 0.07, 0.10, 0.12, 0.9 end
local satinButton = NewFrame()
SkinBase.SkinButton(satinButton)
local satinBackdrop = SkinBase.GetBackdrop(satinButton)
assert(math.abs(satinBackdrop._quiBorderR - 0.12) < 1e-9, "idle button uses neutral window border")
SkinBase.SetRowHovered(satinButton, true)
assert(math.abs(satinBackdrop._quiBorderR - border[1] * 1.3) < 1e-9, "button hover preserves semantic accent")
SkinBase.SetRowHovered(satinButton, false)
assert(math.abs(satinBackdrop._quiBorderR - 0.12) < 1e-9, "button hover leave restores neutral window border")
SkinBase.SetButtonVariant(satinButton, "destructive")
local destructiveR = satinBackdrop._quiBorderR
SkinBase.SetRowHovered(satinButton, true)
SkinBase.SetRowHovered(satinButton, false)
assert(satinBackdrop._quiBorderR == destructiveR, "destructive border survives hover leave")
SkinBase.SetButtonVariant(satinButton, nil)
assert(math.abs(satinBackdrop._quiBorderR - 0.12) < 1e-9, "cleared variant restores neutral window border")
SkinBase.RefreshWidget(satinButton)
assert(math.abs(satinBackdrop._quiBorderR - 0.12) < 1e-9, "theme refresh preserves neutral button chrome")

local satinCategory = NewFrame()
satinCategory.SelectedTexture = NewTexture()
satinCategory.SelectedTexture:Show()
SkinBase.SkinCategoryButton(satinCategory)
local categoryBackdrop = SkinBase.GetBackdrop(satinCategory)
assert(math.abs(categoryBackdrop._quiBorderR - border[1]) < 1e-9, "selected category preserves semantic accent")
satinCategory.SelectedTexture:Hide()
SkinBase.RefreshWidget(satinCategory)
assert(math.abs(categoryBackdrop._quiBorderR - 0.12) < 1e-9, "inactive category uses neutral window border")
local dr, dg, db = SkinBase.GetDepthColor("PANEL")
assert(dr == 0.07 and dg == 0.10 and db == 0.12, "depth colors derive from window background")

print("OK: skinbase_category_button_test")
