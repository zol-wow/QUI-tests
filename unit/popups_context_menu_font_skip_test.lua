-- tests/unit/popups_context_menu_font_skip_test.lua
-- Run: lua tests/unit/popups_context_menu_font_skip_test.lua
--
-- Regression: Blizzard's modern Menu manager owns its FontStrings through the
-- Compositor, which disallows SetFont (reading OR calling it reports via the
-- non-throwing assertsafe — pcall can't suppress it). So QUI must NOT run its
-- font skinning (SkinFrameText) over a Compositor-managed menu. Legacy
-- DropDownList menus are not Compositor-managed and still get the QUI font.

-- luacheck: globals CreateFrame hooksecurefunc C_Timer

CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end }
end
hooksecurefunc = function() end
C_Timer = { After = function(_, cb) cb() end }

local skinFrameTextTargets = {}  -- frame -> true (records who got font skinning)

local function NewMenuFrame(name)
    return {
        name = name,
        GetNumRegions = function() return 0 end,
        GetRegions = function() end,
        IsObjectType = function() return false end,
        IsForbidden = function() return false end,
        GetFrameLevel = function() return 5 end,
        IsShown = function() return true end,
        SetAlpha = function() end,
    }
end

local modernMenu = NewMenuFrame("CompositorMenu")
local legacyMenu = NewMenuFrame("DropDownList1")

local coreMock = {
    db = { profile = { general = { skinContextMenus = true, skinStaticPopups = true } } },
}
local managerMock = { GetOpenMenu = function() return modernMenu end }

-- Modern menu manager + a shown legacy dropdown, no static popups.
_G.Menu = { GetManager = function() return managerMock end }
_G.DropDownList1 = legacyMenu
_G.UIDROPDOWNMENU_MAXLEVELS = 1
_G.STATICPOPUP_NUMDIALOGS = 0

local ns = {
    Helpers = {
        CreateStateTable = function() return setmetatable({}, { __mode = "k" }) end,
        GetCore = function() return coreMock end,
        GetGeneralFont = function() return "Interface\\QUIFont.ttf" end,
    },
    SkinBase = {
        GetWindowColors = function() return 0.6, 0.7, 0.8, 1, 0.1, 0.2, 0.3, 0.9 end,
        GetSkinColors = function() return 0.6, 0.7, 0.8, 1, 0.1, 0.2, 0.3, 0.9 end,
        CreateBackdrop = function() end,
        GetBackdrop = function() return nil end,
        GetFrameData = function() return nil end,
        SetFrameData = function() end,
        SetInsetPixelPoints = function() end,
        SkinFrameText = function(frame) skinFrameTextTargets[frame] = true end,
    },
    -- Registry intentionally nil so the registration block is skipped.
}

assert(loadfile("modules/skinning/system/popups.lua"))("QUI", ns)

assert(type(_G.QUI_RefreshSystemPopupSkins) == "function",
    "popups must expose QUI_RefreshSystemPopupSkins")

_G.QUI_RefreshSystemPopupSkins()

assert(skinFrameTextTargets[modernMenu] == nil,
    "must NOT run SkinFrameText (font skinning) over a Compositor-managed modern menu — SetFont is disallowed there")
-- Legacy DropDownList menus no longer get SkinFrameText; font durability now comes from
-- ApplyButtonFontObjectsDeep driving button font objects for hover/disable swaps.
-- Interactive reverts on bare-root legacy menu entries are accepted under the global override.
assert(skinFrameTextTargets[legacyMenu] == nil,
    "legacy DropDownList menus must NOT get SkinFrameText — font objects are driven via ApplyButtonFontObjectsDeep")

print("OK: popups_context_menu_font_skip_test")
local function Font(r, g, b)
    return {
        color = {r,g,b,1},
        IsObjectType = function(_, kind) return kind == "FontString" end,
        GetTextColor = function(self) return unpack(self.color) end,
        SetTextColor = function(self, ...) self.color = {...} end,
        SetFont = function() error("compositor font mutation is forbidden") end,
    }
end
local heading = Font(1,.82,0)
local className = Font(.77,.12,.23)
local disabled = Font(.3,.3,.3)
local row = NewMenuFrame("NativeRow")
row.GetNumRegions = function() return 3 end
row.GetRegions = function() return heading,className,disabled end
row.arrow = {
    SetDesaturated = function(self, value) self.desaturated = value end,
    SetVertexColor = function(self, ...) self.color = {...} end,
}
local nativeClick = function() end
row.OnClick = nativeClick
modernMenu.GetNumChildren = function() return 1 end
modernMenu.GetChildren = function() return row end
_G.QUI_RefreshSystemPopupSkins()
assert(heading.color[1] == .9 and heading.color[2] == .9 and heading.color[3] == .9,
    "decorative gold section headings become neutral")
assert(className.color[1] == .77 and disabled.color[1] == .3,
    "semantic class colors and disabled state remain intact")
assert(row.arrow.desaturated and row.arrow.color[1] == .9,
    "submenu arrow stays visible with neutral artwork")
assert(row.OnClick == nativeClick, "native context-menu action is preserved")
