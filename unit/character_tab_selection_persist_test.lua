
-- luacheck: globals CreateFrame C_Timer hooksecurefunc InCombatLockdown
-- luacheck: globals CharacterFrame CharacterFrameTab1 CharacterFrameTab2 CharacterFrameTab3
-- luacheck: globals PanelTemplates_GetSelectedTab PanelTemplates_SetTab

local function approx(a, b) return a and math.abs(a - b) < 1e-4 end

local function NewTexture()
    local t = {}
    function t:ClearAllPoints() end function t:SetPoint() end
    function t:SetHeight() end function t:SetWidth() end
    function t:Show() end function t:Hide() end
    function t:SetTexture() end
    function t:SetSize() end function t:SetTexCoord() end function t:SetAlpha() end
    function t:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function t:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
    return t
end

local function NewFrame()
    local f = { frameLevel = 4, id = 0 }
    function f:GetFrameLevel() return self.frameLevel end
    function f:SetFrameLevel(l) self.frameLevel = l end
    function f:SetFrameStrata() end
    function f:GetID() return self.id end
    function f:SetAllPoints() end
    function f:SetSize() end
    function f:ClearAllPoints() end
    function f:SetPoint() end
    function f:EnableMouse() end
    function f:GetEffectiveScale() return 1 end
    function f:Show() end function f:Hide() end
    function f:IsShown() return false end
    function f:GetWidth() return 100 end
    function f:GetHeight() return 100 end
    function f:RegisterEvent() end function f:UnregisterEvent() end
    function f:SetScript() end function f:GetScript() end function f:HookScript() end
    function f:CreateTexture() return NewTexture() end
    function f:SetBackdrop(info) self.backdrop = info end
    function f:GetBackdrop() return self.backdrop end
    function f:SetBackdropColor(r, g, b, a) self._quiBgR, self._quiBgG, self._quiBgB, self._quiBgA = r, g, b, a or 1 end
    function f:SetBackdropBorderColor(r, g, b, a) self._quiBorderR, self._quiBorderG, self._quiBorderB, self._quiBorderA = r, g, b, a or 1 end
    return f
end

local function CreateStateTable()
    local tbl = setmetatable({}, { __mode = "k" })
    local function get(key)
        local s = tbl[key]
        if not s then s = {}; tbl[key] = s end
        return s
    end
    return tbl, get
end

local BASE = { 0.10, 0.20, 0.30, 1, 0.40, 0.50, 0.60, 0.90 }

local ns = {
    Addon = { GetPixelSize = function() return 0.5 end },
    Helpers = {
        AssetPath = [[Interface\AddOns\QUI\assets\]],
        GetWindowColors = function() return unpack(BASE) end,
        CHROME = { BORDER_PX = 1, BG_FALLBACK = { 0.05, 0.05, 0.05, 0.95 }, BORDER_FALLBACK = { 0, 0, 0, 1 }, BUTTON_BOOST = 0.07, SCROLLROW_BOOST = 0.03, DEPTH = { PANEL = { boost = 0, alpha = 0.95 }, SUBPANEL = { boost = 0.04, alpha = 0.85 }, ROW = { boost = 0.07, alpha = 0.75 } } },
        CreateStateTable = CreateStateTable,
        GetCore = function()
            return { db = { profile = {
                general = { skinCharacterFrame = true },
                character = { enabled = false },
            } } }
        end,
        CreateSkinColorGetter = function()
            return function()
                return BASE[1], BASE[2], BASE[3], BASE[4], BASE[5], BASE[6], BASE[7], BASE[8]
            end
        end,
        GetGeneralFont = function() return "Interface\\QUIFont.ttf" end,
        SafeToNumber = function(v, d) return tonumber(v) or d end,
        SetFrameBackdropColor = function(frame, r, g, b, a)
            frame:SetBackdropColor(r, g, b, a)
            frame._quiBgR, frame._quiBgG, frame._quiBgB, frame._quiBgA = r, g, b, a
        end,
        SetFrameBackdropBorderColor = function(frame, r, g, b, a)
            frame:SetBackdropBorderColor(r, g, b, a)
            frame._quiBorderR, frame._quiBorderG, frame._quiBorderB, frame._quiBorderA = r, g, b, a
        end,
    },
    -- core/safecall.lua stub: silent pcall swallow matches the pre-SafeCall
    -- shape these tests were written against.
    SafeCall = function(_policy, fn, ...) return pcall(fn, ...) end,
    SafeCallMethod = function(_policy, obj, name, ...) return pcall(function(...) return obj[name](obj, ...) end, ...) end,
    SafeCallMethodIfPresent = function(_policy, obj, name, ...) if obj == nil then return nil end local okP, m = pcall(function() return obj[name] end) if not okP then return false end if m == nil then return nil end return pcall(m, obj, ...) end,
}

CreateFrame = function() return NewFrame() end
C_Timer = { After = function() end }
hooksecurefunc = function() end
function InCombatLockdown() return false end

assert(loadfile("core/uikit.lua"))("QUI", ns)
local SkinBase = ns.SkinBase
assert(type(SkinBase) == "table", "SkinBase must load from uikit.lua")
assert(loadfile("modules/skinning/frames/character_chrome.lua"))("QUI", ns)
assert(loadfile("modules/skinning/frames/character.lua"))("QUI", ns)

local API = _G.QUI_CharacterFrameSkinning
assert(type(API) == "table" and type(API.Refresh) == "function",
    "character.lua must expose _G.QUI_CharacterFrameSkinning.Refresh")

CharacterFrame = NewFrame()
CharacterFrame.selectedTab = 1
local tabs = {}
for i = 1, 3 do
    local tab = NewFrame()
    tab.id = i
    tabs[i] = tab
    _G["CharacterFrameTab" .. i] = tab
    -- Simulate the post-first-skin state: SkinBase.SkinTab early-returns on an
    -- already-styled tab, so pre-establish the backdrop + the skinColor/bgColor/
    -- skinTabFont frame data exactly as SkinTabButton sets them on first skin.
    -- SkinTabGroup's refreshAll() then drives the canonical RefreshTabSelected.
    SkinBase.CreateBackdrop(tab, BASE[1], BASE[2], BASE[3], BASE[4], BASE[5], BASE[6], BASE[7], 0.9)
    SkinBase.SetFrameData(tab, "skinColor", { BASE[1], BASE[2], BASE[3], BASE[4] })
    SkinBase.SetFrameData(tab, "bgColor", { BASE[5], BASE[6], BASE[7] })
    SkinBase.SetFrameData(tab, "skinTabFont", true)
    SkinBase.MarkStyled(tab)
end

API.Refresh()

local bd1 = SkinBase.GetBackdrop(tabs[1])
local bd2 = SkinBase.GetBackdrop(tabs[2])
assert(bd1 and bd2, "tabs must have SkinBase backdrops")

assert(approx(bd1._quiBgR, BASE[5]) and approx(bd1._quiBgG, BASE[6]) and approx(bd1._quiBgB, BASE[7]),
    "selected tabs must blend with the window fill")
assert(approx(bd2._quiBgR, BASE[5]) and approx(bd2._quiBgG, BASE[6]) and approx(bd2._quiBgA, bd1._quiBgA),
    "unselected tabs must use the same opaque fill")
ns.UIKit.RefreshScaleBoundWidgets()
assert(approx(bd1._quiBgR, BASE[5]) and approx(bd1._quiBgG, BASE[6]),
    "selected tab fill must survive scale refresh")
assert(approx(bd1._quiBorderR, bd2._quiBorderR) and approx(bd1._quiBorderG, bd2._quiBorderG),
    "selection must not add a second border treatment")
print("OK: character_tab_selection_persist_test")
