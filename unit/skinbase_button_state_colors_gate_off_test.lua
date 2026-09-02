-- tests/unit/skinbase_button_state_colors_gate_off_test.lua
-- Run: luajit tests/unit/skinbase_button_state_colors_gate_off_test.lua
--
-- R3 (UI polish, Phase 0): "enabled button looks disabled". Button STATE
-- colours (enabled white / disabled grey) were coupled to the typography
-- preference `general.applyGlobalFontToBlizzard`: ApplyButtonFontObjects
-- early-returned when the gate was off, so no colour was ever applied and
-- Blizzard's font objects (gold / dark grey on a dark QUI backdrop) won.
-- Contract:
--   * font FACE stays gated (typography preference untouched);
--   * state COLOURS are ungated: SkinButton -> white label; Disable() ->
--     disabled colour; Enable() -> white again, with the gate OFF;
--   * hover font-object swaps are re-asserted (OnEnter/OnLeave hooked);
--   * the disabled font object never inherits the normal colour.
-- luacheck: globals CreateFrame C_Timer hooksecurefunc ScrollUtil STANDARD_TEXT_FONT CreateFont

local unpack = table.unpack or unpack
local function NewTexture()
    local t = { a = 1 }
    function t:ClearAllPoints() end function t:SetPoint() end function t:SetHeight() end
    function t:SetWidth() end function t:Show() self.shown = true end function t:Hide() self.shown = false end
    function t:IsShown() return self.shown end function t:SetAlpha(v) self.a = v end
    function t:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
    function t:SetFont(font, size, flags) self.font, self.size, self.flags = font, size, flags end
    function t:GetFont() return self.font, self.size or 12, self.flags end
    function t:SetTexture() end function t:SetColorTexture() end function t:SetVertexColor() end
    function t:SetAllPoints() end function t:IsObjectType(o) return o == "Texture" end
    return t
end
local function NewButton()
    local f = { textures = {}, level = 4, scripts = {}, enabled = true }
    f.Text = NewTexture()
    function f:CreateTexture() local t = NewTexture(); self.textures[#self.textures+1] = t; return t end
    function f:SetAllPoints() end function f:SetFrameLevel(l) self.level = l end
    function f:GetFrameLevel() return self.level end function f:EnableMouse() end
    function f:Show() end function f:Hide() end
    function f:HookScript(e, fn)
        local prev = self.scripts[e]
        self.scripts[e] = prev and function(...) prev(...); fn(...) end or fn
    end
    function f:GetRegions() return unpack(self.textures) end
    function f:GetNumRegions() return #self.textures end
    function f:GetHighlightTexture() return nil end function f:GetNormalTexture() return nil end
    function f:GetPushedTexture() return nil end function f:GetDisabledTexture() return nil end
    function f:GetFontString() return self.Text end
    function f:SetNormalFontObject(o) self.normalFontObject = o end
    function f:SetHighlightFontObject(o) self.highlightFontObject = o end
    function f:SetDisabledFontObject(o) self.disabledFontObject = o end
    function f:IsEnabled() return self.enabled end
    -- Blizzard semantics: a state change re-applies the active font object's
    -- colour to the label, then fires the script.
    function f:Disable()
        self.enabled = false
        if self.disabledFontObject and self.disabledFontObject.textColor then
            self.Text:SetTextColor(unpack(self.disabledFontObject.textColor))
        else
            self.Text:SetTextColor(0.5, 0.5, 0.5, 1) -- GameFontDisable
        end
        if self.scripts.OnDisable then self.scripts.OnDisable(self) end
    end
    function f:Enable()
        self.enabled = true
        if self.normalFontObject and self.normalFontObject.textColor then
            self.Text:SetTextColor(unpack(self.normalFontObject.textColor))
        else
            self.Text:SetTextColor(1, 0.82, 0, 1) -- GameFontNormal gold
        end
        if self.scripts.OnEnable then self.scripts.OnEnable(self) end
    end
    return f
end
CreateFrame = function() return NewButton() end
C_Timer = { After = function(_, fn) fn() end }
function hooksecurefunc() end
ScrollUtil = { AddAcquiredFrameCallback = function() end }
STANDARD_TEXT_FONT = "x"
function CreateFont(name)
    local obj = { name = name }
    function obj:SetFont(font, size, flags) self.font, self.size, self.flags = font, size, flags end
    function obj:SetFontObject(o) self.fontObject = o end
    function obj:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
    return obj
end
local function CreateStateTable() local t = setmetatable({}, { __mode = "k" }); return t, function(k) local s=t[k]; if not s then s={}; t[k]=s end; return s end end
local CHROME = { BORDER_PX=1, BG_FALLBACK={0.05,0.05,0.05,0.95}, BORDER_FALLBACK={0,0,0,1}, BUTTON_BOOST=0.07, SCROLLROW_BOOST=0.03, DEPTH={PANEL={boost=0,alpha=0.95},SUBPANEL={boost=0.04,alpha=0.85},ROW={boost=0.07,alpha=0.75}} }

local function LoadWithGate(gate)
    local ns = { Helpers = { CHROME=CHROME, CreateStateTable=CreateStateTable,
        GetCore = function() return { db = { profile = { general = { applyGlobalFontToBlizzard = gate } } } } end,
        SafeToNumber = function(v,d) return tonumber(v) or d end,
        GetSkinBorderColor = function() return 0.6, 0.7, 0.8, 1 end,
        GetSkinBgColorWithOverride = function() return 0.1, 0.2, 0.3, 0.9 end,
        GetGeneralFont = function() return "QUIFont" end, GetGeneralFontOutline = function() return "" end },
        UIKit = { RegisterScaleRefresh = function() end } }
    assert(loadfile("core/uikit.lua"))("QUI", ns)
    return ns.SkinBase
end

local function IsWhite(c) return c and c[1] == 1 and c[2] == 1 and c[3] == 1 and c[4] == 1 end

---------------------------------------------------------------------------
-- Gate OFF: colours still applied, font face untouched
---------------------------------------------------------------------------
do
    local SkinBase = LoadWithGate(false)
    assert(type(SkinBase.ApplyButtonStateColors) == "function", "SkinBase.ApplyButtonStateColors must exist")

    local btn = NewButton()
    SkinBase.SkinButton(btn)
    assert(IsWhite(btn.Text.textColor), "SkinButton must paint an enabled label white with the font gate OFF")
    assert(btn.Text.font == nil, "font FACE must stay gated: no QUI font applied when the gate is off")
    assert(btn.normalFontObject == nil, "font objects must stay gated when the gate is off")

    btn:Disable()
    local c = btn.Text.textColor
    assert(c and c[1] < 0.7 and c[1] == c[2] and c[2] == c[3],
        "Disable() must leave the label in the disabled (grey) colour with the gate OFF")

    btn:Enable()
    assert(IsWhite(btn.Text.textColor), "Enable() must restore a white label with the gate OFF (was gold/grey)")

    -- Hover swaps font objects in the engine; QUI must re-assert after both.
    assert(btn.scripts.OnEnter and btn.scripts.OnLeave, "SkinButton must hook OnEnter/OnLeave to re-assert state colours")
    btn.Text:SetTextColor(1, 0.82, 0, 1) -- simulate highlight font object colour
    btn.scripts.OnEnter(btn)
    assert(IsWhite(btn.Text.textColor), "OnEnter must re-assert the enabled label colour")
    btn.Text:SetTextColor(1, 0.82, 0, 1)
    btn.scripts.OnLeave(btn)
    assert(IsWhite(btn.Text.textColor), "OnLeave must re-assert the enabled label colour")

    -- Custom colours flow through the ungated path too.
    local custom = NewButton()
    SkinBase.SkinButton(custom, { fontColor = { 0.9, 0.8, 0.7, 1 }, disabledFontColor = { 0.3, 0.3, 0.3, 1 } })
    assert(math.abs(custom.Text.textColor[1] - 0.9) < 1e-9, "custom fontColor applied with the gate OFF")
    custom:Disable()
    assert(math.abs(custom.Text.textColor[1] - 0.3) < 1e-9, "custom disabledFontColor applied with the gate OFF")
end

---------------------------------------------------------------------------
-- Gate ON: font objects installed; disabled object never = normal colour
---------------------------------------------------------------------------
do
    local SkinBase = LoadWithGate(true)
    local btn = NewButton()
    SkinBase.SkinButton(btn)
    assert(IsWhite(btn.Text.textColor), "SkinButton must paint an enabled label white with the font gate ON")
    assert(btn.Text.font == "QUIFont", "font FACE applied when the gate is on")
    assert(type(btn.normalFontObject) == "table" and IsWhite(btn.normalFontObject.textColor),
        "normal font object carries the enabled colour")
    assert(type(btn.disabledFontObject) == "table" and btn.disabledFontObject ~= btn.normalFontObject
        and btn.disabledFontObject.textColor[1] < 0.7,
        "disabled font object must be a distinct grey object, never the normal colour")

    -- Even when only a normal colour is passed, disabled must not fall back to it.
    local only = NewButton()
    SkinBase.ApplyButtonFontObjects(only, { color = { 1, 1, 1, 1 } })
    assert(only.disabledFontObject.textColor[1] < 0.7,
        "ApplyButtonFontObjects without disabledColor must still install a grey disabled font object")

    btn:Disable()
    assert(btn.Text.textColor[1] < 0.7, "Disable() -> disabled colour with the gate ON")
    btn:Enable()
    assert(IsWhite(btn.Text.textColor), "Enable() -> white with the gate ON")
end

print("OK: skinbase_button_state_colors_gate_off_test")
