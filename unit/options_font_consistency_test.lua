local compile = loadstring or load
local function Read(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end
local function Slice(source, first, last)
    local start = assert(source:find(first, 1, true), first)
    return source:sub(start, assert(source:find(last, start, true), last) - 1)
end
local framework = Read("QUI_Options/framework.lua")
local uikit = Read("core/uikit.lua")
local preview = Read("QUI_UnitFrames/unitframes/settings/unit_frames_surface.lua")
local paths = {
    Quazii = "Interface\\AddOns\\QUI\\assets\\Quazii.ttf",
    Specimen = "Fonts/Specimen.ttf",
}
local fetches = 0
local lsm = {}
function lsm:Fetch(kind, name, noDefault)
    assert(kind == "font")
    fetches = fetches + 1
    return paths[name] or (not noDefault and "Fonts/WrongDefault.ttf") or nil
end
local nativePath = "Fonts/Sidebar.ttf"
local native = {}
function native:GetFont() return nativePath, 12, "" end
local helpers = {
    GetGeneralFont = function() return "Fonts/Gameplay.ttf" end,
    GetGeneralFontOutline = function() return "OUTLINE" end,
    ApplyFontWithFallback = function(fontString, path, size, flags)
        fontString.font = {path, size, flags}
    end,
}
local kit = {}
function kit.CreateButton(_, opts) return opts end
local gui = {}
local ns = {Helpers = helpers, UIKit = kit, LSM = lsm}
local getter = Slice(framework, "local FONT_PATH =", "local function CreateBackdrop(")
local setFont = Slice(framework, "local function SetFont(", "local function ApplyFontToFrameRecursive(")
local widgets = Slice(framework, "function GUI:CreateLabel(", "local function ApplyFallbackPixelBorder(")
local loadGUI = assert(compile("return function(GUI, LSM, GameFontNormal, ns, C, unpack)\n" .. getter .. setFont .. widgets .. "\nend"))
loadGUI()(gui, lsm, native, ns, {text = {1, 1, 1, 1}}, unpack or table.unpack)
local resolver = Slice(uikit, "function UIKit.ResolveFontPath(", "function UIKit.GetBackdropInfo(")
assert(compile("return function(UIKit, LSM, Helpers)\n" .. resolver .. "\nend"))()(kit, lsm, helpers)
assert(gui:GetFontPath() == nativePath and gui.FONT_PATH == nativePath, "options must use the actual sidebar template font")
local parent = {}
function parent:CreateFontString()
    local label = {}
    function label:SetText(value) self.text = value end
    function label:SetTextColor(...) self.color = {...} end
    return label
end
local label = gui:CreateLabel(parent, "Options", 12)
assert(label.font[1] == nativePath, "ordinary options labels must agree with the sidebar")
assert(gui:CreateButton(parent, "Apply").font == nativePath, "options buttons must pass the sidebar font explicitly")
nativePath = "Fonts/Blizzard.ttf"
assert(gui:GetFontPath() == nativePath and gui.FONT_PATH == nativePath, "options must follow the native sidebar when global font override is disabled or changes")
assert(gui:CreateLabel(parent, "Options", 12).font[1] == nativePath, "new labels must reflect the current sidebar font")
nativePath = nil
assert(gui:GetFontPath() == "Fonts/Blizzard.ttf", "a temporarily unavailable native font must retain the last usable path")
local before = fetches
assert(kit.ResolveFontPath("Interface\\AddOns\\QUI\\assets\\Quazii.ttf") == paths.Quazii, "backslash paths must bypass LSM name lookup")
assert(kit.ResolveFontPath("Fonts/Sidebar.ttf") == "Fonts/Sidebar.ttf", "forwardslash paths must bypass LSM name lookup")
assert(fetches == before, "explicit font paths must never query LSM")
assert(kit.ResolveFontPath("Quazii") == paths.Quazii, "registered font names must remain supported")
assert(kit.ResolveFontPath("Missing") == "Fonts/Gameplay.ttf", "missing names must not silently select LSM's default font")
assert(kit.ResolveFontPath() == "Fonts/Gameplay.ttf", "no-argument font resolution must retain gameplay semantics")
local previewCode = Slice(preview, "local function GetLSM()", "local function ResolveStatusBarTexture(")
local resolvePreview, resolveElement = assert(compile("return function(ns, LibStub)\n" .. previewCode .. "\nreturn ResolveUnitFrameFont, ResolveElementFont\nend"))()(ns)
local previewPath, previewOutline = resolvePreview()
assert(previewPath == "Fonts/Gameplay.ttf" and previewOutline == "OUTLINE", "unit-frame specimens must retain gameplay font and outline")
assert(resolveElement("Specimen", previewPath) == paths.Specimen, "configured preview specimens must retain their selected font")
assert(resolveElement("Missing", previewPath) == previewPath, "missing preview names must preserve their gameplay fallback")
print("OK: options_font_consistency_test")
