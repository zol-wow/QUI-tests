
local function makeFrame()
    local frame = { shown = false, scripts = {}, events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(scriptName, handler) self.scripts[scriptName] = handler end
    function frame:IsShown() return self.shown end
    function frame:Show() self.shown = true end
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
assert(loadfile(os.getenv("QUI_TOOLTIP_SOURCE") or "modules/skinning/system/tooltips.lua"))("QUI", ns)
local frames = {}
for _, name in ipairs({ "PetJournalPrimaryAbilityTooltip", "PetJournalSecondaryAbilityTooltip" }) do
    local tooltip = makeFrame()
    tooltip.NineSlice = makeFrame()
    tooltip.NineSlice:Show()
    local icon = { alpha = 1, texture = "native-pet-type-art" }
    tooltip.AbilityIcon = icon
    tooltip.description = "native ability damage and hit chance"
    tooltip.speciesID = 123
    _G[name] = tooltip
    frames[#frames + 1] = tooltip
end
eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "Blizzard_Collections")
for _, tooltip in ipairs(frames) do
    local frame = createdFrames[tooltip]
    assert(frame and frame.chrome and frame.chrome.radius == 6, "late Pet Journal ability tooltip must acquire rounded QUI chrome")
    assert(not tooltip.NineSlice:IsShown(), "Pet Journal ability tooltip must suppress native NineSlice")
    assert(tooltip.AbilityIcon.alpha == 1 and tooltip.AbilityIcon.texture == "native-pet-type-art", "pet type artwork must survive")
    assert(tooltip.description == "native ability damage and hit chance" and tooltip.speciesID == 123, "native ability data must survive")
    tooltip:Show()
    assert(frame:IsShown() and not tooltip.NineSlice:IsShown(), "native tooltip Show must retain QUI chrome")
end
print("OK: pet_journal_ability_tooltip_test")
