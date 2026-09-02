-- tests/unit/character_popout_ownership_test.lua
-- Run: luajit tests/unit/character_popout_ownership_test.lua
--
-- Equipment Manager / Titles side popouts are created by the chrome owner
-- (CharacterChrome.CreatePopout) with QUI chrome from the first frame: no
-- Blizzard dialog textures, no second module restyling them later. The
-- frame skin only re-tints through RefreshPopout, and theme changes survive
-- a scale refresh because the colours live in the shared pixel-backdrop
-- data.
-- luacheck: globals CreateFrame CharacterFrame QUI_EquipMgrPopup QUI_TitlesPopup
local Harness = dofile("tests/helpers/character_chrome_harness.lua")

local failures = 0
local function check(name, ok, detail)
    if ok then
        print(("  ok  %s"):format(name))
    else
        failures = failures + 1
        print(("FAIL  %s  %s"):format(name, detail or ""))
    end
end
local function approx(a, b) return type(a) == "number" and math.abs(a - b) < 1e-4 end

local env = Harness.Build({ loadFrameSkin = true })
env.SetGates(true, true)
env.BuildCharacterFrame()
local Chrome = env.Chrome
local SkinBase = env.SkinBase

---------------------------------------------------------------------------
-- 1. Creation: chrome from the start, published global, no dialog art
---------------------------------------------------------------------------
local popup = Chrome.CreatePopout("Equipment Manager", { name = "QUI_EquipMgrPopup" })
check("popout returned", popup ~= nil)
check("popout publishes its global", _G.QUI_EquipMgrPopup == popup)
check("popout is registered with the owner", Chrome.IsPopout(popup) == true)
check("popout starts hidden", popup:IsShown() == false)
check("popout sits on the DIALOG strata", popup.strata == "DIALOG")
check("popout is movable", popup.movable == true)
check("popout anchors past the extended shell",
    popup.points[1] and popup.points[1][1] == "TOPLEFT" and popup.points[1][3] == "TOPRIGHT"
    and popup.points[1][4] == 55 + 10)

local dialogArt = false
for _, info in ipairs(popup.backdropCalls) do
    if type(info) == "table" and (tostring(info.bgFile):find("DialogBox", 1, true) or tostring(info.edgeFile):find("DialogBox", 1, true)) then
        dialogArt = true
    end
end
check("no Blizzard dialog textures applied", dialogArt == false)
check("popout carries the skin bg colour", env.BgColor(popup) and approx(env.BgColor(popup)[1], env.colors[5]) and approx(env.BgColor(popup)[4], env.colors[8]))
check("popout carries the skin border colour", env.BorderColor(popup) and approx(env.BorderColor(popup)[1], env.colors[1]))
check("popout title text", popup.title and popup.title.text == "Equipment Manager")
check("popout title uses the QUI font at 14", popup.title.font == "QUIFont.ttf" and popup.title.fontSize == 14)
check("popout title uses the luminance-floored text accent",
    popup.title.textColor and approx(popup.title.textColor[1], env.colors[1]) and approx(popup.title.textColor[4], 1))
check("popout has a QUI close button", popup.closeButton ~= nil and popup.closeButton.template == nil)
check("close button is skinned by the owner", SkinBase.GetFrameData(popup.closeButton, "closeLabel") ~= nil)
popup:Show()
popup.closeButton:Fire("OnClick")
check("close button hides the popout", popup:IsShown() == false)

---------------------------------------------------------------------------
-- 2. Theme change survives a scale refresh (colour lives in backdrop data)
---------------------------------------------------------------------------
env.colors[1], env.colors[2], env.colors[3] = 0.9, 0.4, 0.2
env.colors[5], env.colors[6], env.colors[7] = 0.12, 0.13, 0.14
Chrome.RefreshTheme()
check("RefreshTheme re-tints the popout bg", approx(env.BgColor(popup)[1], 0.12))
check("RefreshTheme re-tints the popout border", approx(env.BorderColor(popup)[1], 0.9))
check("RefreshTheme re-tints the title", approx(popup.title.textColor[1], 0.9))
env.UIKit.RefreshScaleBoundWidgets()
check("scale refresh keeps the new bg", approx(env.BgColor(popup)[1], 0.12))
check("scale refresh keeps the new border", approx(env.BorderColor(popup)[1], 0.9))

---------------------------------------------------------------------------
-- 3. Frame skin only re-tints; the second popout goes the same way
---------------------------------------------------------------------------
local titles = Chrome.CreatePopout("Titles", { name = "QUI_TitlesPopup" })
check("second popout published", _G.QUI_TitlesPopup == titles)
local api = _G.QUI_CharacterFrameSkinning
env.colors[5] = 0.3
api.SkinEquipmentManager()
check("SkinEquipmentManager re-tints through the owner", approx(env.BgColor(popup)[1], 0.3))
env.colors[5] = 0.4
api.Refresh()
check("Refresh re-tints the equipment popout", approx(env.BgColor(popup)[1], 0.4))
check("Refresh re-tints the titles popout too", approx(env.BgColor(titles)[1], 0.4))
check("accent listener registered for live accent changes", #env.accentListeners >= 1)

---------------------------------------------------------------------------
-- 4. Source pins
---------------------------------------------------------------------------
local function readFile(path)
    local fh = assert(io.open(path, "rb"), "failed to open " .. path)
    local text = fh:read("*a"); fh:close(); return text
end
local pane = readFile("modules/skinning/character_pane/character.lua")
local skin = readFile("modules/skinning/frames/character.lua")
local chrome = readFile("modules/skinning/frames/character_chrome.lua")
check("enhancement creates popouts through the owner", pane:find("chrome.CreatePopout(titleText, { name = globalName })", 1, true) ~= nil)
check("enhancement has no dialog textures", pane:find("UI-DialogBox", 1, true) == nil)
check("chrome owner has no dialog textures", chrome:find("UI-DialogBox", 1, true) == nil)
check("frame skin no longer restyles the popout backdrop itself",
    skin:find("ApplyPixelBackdrop(popup,", 1, true) == nil)
check("frame skin re-tints through RefreshPopout", skin:find("chrome.RefreshPopout(popup)", 1, true) ~= nil)
check("popout title is canonical white-family font object",
    chrome:find('popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")', 1, true) ~= nil)

if failures > 0 then
    print(("FAIL: character_popout_ownership_test (%d)"):format(failures))
    os.exit(1)
end
print("OK: character_popout_ownership_test")
