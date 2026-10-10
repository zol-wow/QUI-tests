
local function makeFrame()
    local frame = { shown = false, scripts = {}, events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(scriptName, handler) self.scripts[scriptName] = handler end
    function frame:IsShown() return self.shown end
    function frame:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function frame:HookScript(name, callback) self.scripts[name] = callback end
    function frame:Hide() self.shown = false end
    function frame:SetAllPoints() self.allPoints = true end
    function frame:ClearAllPoints() self.points = nil end
    function frame:SetPoint(point, relativeTo, relativePoint, x, y)
        self.points = self.points or {}
        self.points[#self.points + 1] = {
            point = point, relativeTo = relativeTo,
            relativePoint = relativePoint, x = x, y = y,
        }
    end
    function frame:EnableMouse() end
    function frame:SetFrameLevel(level) self.frameLevel = level end
    function frame:SetFrameStrata(strata) self.frameStrata = strata end
    function frame:GetWidth() return 200 end
    function frame:GetHeight() return 80 end
    function frame:GetFrameLevel() return 10 end
    function frame:GetFrameStrata() return "TOOLTIP" end
    function frame:GetOwner() return nil end
    return frame
end

local function makeFontObject(path, size, flags)
    local fontObject = { path = path, size = size, flags = flags }
    function fontObject:GetFont() return self.path, self.size, self.flags end
    function fontObject:SetFont(p, s, f) self.path, self.size, self.flags = p, s, f end
    return fontObject
end

local eventFrame

_G.UIParent = makeFrame()
_G.WorldFrame = makeFrame()
_G.GameTooltip = makeFrame()
_G.GameTooltip.shown = true
_G.GameTooltipHeaderText = makeFontObject("Fonts\\FRIZQT__.TTF", 14, "")
_G.GameTooltipText = makeFontObject("Fonts\\FRIZQT__.TTF", 12, "")

_G.ItemRefTooltip = makeFrame()
_G.ItemRefTooltip.CloseButton = makeFrame()

_G.InCombatLockdown = function() return false end
_G.issecretvalue = function() return false end
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.ADDON_LOADED = "ADDON_LOADED"
local createdFrames = {}
_G.CreateFrame = function(_, _, parent)
    local frame = makeFrame()
    if parent then createdFrames[parent] = frame end
    if not eventFrame then eventFrame = frame end
    return frame
end
_G.C_Timer = { After = function(_, callback) callback() end }
_G.hooksecurefunc = function(owner, name, callback)
    if type(owner) == "table" and type(owner[name]) == "function" then
        local original = owner[name]
        owner[name] = function(self, ...)
            original(self, ...)
            callback(self, ...)
        end
    end
end
_G.wipe = function(tbl)
    for key in pairs(tbl) do tbl[key] = nil end
end

local skinnedCloseButtons = {}

local ns = {
    Helpers = {
        GetCore = function()
            return {
                db = { profile = { tooltip = {
                    enabled = true, skinTooltips = true, fontSize = 13,
                } } },
            }
        end,
        CreateStateTable = function() return setmetatable({}, { __mode = "k" }) end,
        GetSkinBorderColor = function() return 1, 1, 1, 1 end,
        GetSkinBgColor = function() return 0, 0, 0, 1 end,
        GetGeneralFont = function() return "Fonts\\FRIZQT__.TTF" end,
        GetGeneralFontOutline = function() return "OUTLINE" end,
        IsSecretValue = function() return false end,
    },
    SkinBase = {
        SkinFrameText = function() end,
        SkinCloseButton = function(button)
            skinnedCloseButtons[#skinnedCloseButtons + 1] = button
        end,
        SetPixelPoint = function(region, point, relativeTo, relativePoint, x, y)
            if region.ClearAllPoints then region:ClearAllPoints() end
            if region.SetPoint then region:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0) end
        end,
    },
    UIKit = {
        CreateBackground = function() return { SetVertexColor = function() end } end,
        CreateBorderLines = function() end,
        UpdateBorderLines = function() end,
    },
    WhenLoggedIn = function(fn) fn() end,
    SafeCall = function(_policy, fn, ...) return pcall(fn, ...) end,
    SafeCallMethod = function(_policy, obj, name, ...) return pcall(function(...) return obj[name](obj, ...) end, ...) end,
    SafeCallMethodIfPresent = function(_policy, obj, name, ...) if obj == nil then return nil end local okP, m = pcall(function() return obj[name] end) if not okP then return false end if m == nil then return nil end return pcall(m, obj, ...) end,
}


ns.SkinBase.ApplyChromeBackdrop = function(frame, options) frame.chrome = options end
ns.Helpers.GetWindowColors = function() return .2, .2, .2, 1, .02, .02, .02, 1 end
ns.SafeCall = function(_, callback, ...)
    local ok, result = pcall(callback, ...)
    assert(ok, result)
    return ok, result
end

EmbeddedItemTooltip = makeFrame()
EmbeddedItemTooltip.NineSlice = makeFrame()
EmbeddedItemTooltip.NineSlice:Show()
function EmbeddedItemTooltip:GetParent() return UIParent end
function EmbeddedItemTooltip:UpdateTooltipSize() error("native widget sizing must not be changed") end
EmbeddedItemTooltip.ItemTooltip = makeFrame()
EmbeddedItemTooltip.ItemTooltip.Tooltip = makeFrame()
EmbeddedItemTooltip.ItemTooltip.FollowerTooltip = makeFrame()
GameTooltip.ItemTooltip = makeFrame()
GameTooltip.ItemTooltip.Tooltip = makeFrame()
local nativeWidget = { text = "Enemy groups affected: 4", shown = true }
EmbeddedItemTooltip.widget = nativeWidget
assert(loadfile(os.getenv("QUI_TOOLTIP_SOURCE") or "modules/skinning/system/tooltips.lua"))("QUI", ns)
local chrome = createdFrames[EmbeddedItemTooltip]
assert(chrome and chrome.chrome.radius == 6, "standalone EmbeddedItemTooltip must acquire QUI chrome")
assert(not EmbeddedItemTooltip.NineSlice:IsShown(), "standalone native NineSlice must be suppressed")
chrome:Hide()
EmbeddedItemTooltip:Show()
assert(chrome:IsShown(), "native OnShow/SetShown must restore outer chrome")
assert(EmbeddedItemTooltip.widget == nativeWidget and nativeWidget.text == "Enemy groups affected: 4" and nativeWidget.shown, "native widget data and visibility must survive")
for _, root in ipairs({ EmbeddedItemTooltip.ItemTooltip, GameTooltip.ItemTooltip }) do
    assert(not createdFrames[root] and not createdFrames[root.Tooltip] and not createdFrames[root.FollowerTooltip], "internal embedded cards must remain unstyled")
    assert(not root.Tooltip.scripts.OnShow, "internal cards must not acquire skin hooks")
end
ns.QUI_RefreshTooltipFontSize()
print("OK: tooltip_standalone_embedded_chrome_test")
