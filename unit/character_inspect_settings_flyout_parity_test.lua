-- tests/unit/character_inspect_settings_flyout_parity_test.lua
-- Run: luajit tests/unit/character_inspect_settings_flyout_parity_test.lua
--
-- The Character and Inspect settings flyouts used to be two hand-built
-- panels (118 px vs 70 px trigger, 53 px vs 5 px offset, wheel-only scroll
-- without a thumb vs UIPanelScrollFrameTemplate). Both now come from
-- CharacterChrome.CreateSettingsFlyout; only title and provider differ.
-- This builds two instances the way the two modules do and asserts the
-- shared geometry, scroll wiring (smooth scroll + thin bar, step 30), lazy
-- content build and close/refresh behaviour.
-- luacheck: globals CreateFrame CharacterFrame InspectFrame QUI_CharSettingsPanel QUI_InspectSettingsPanel
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

local env = Harness.Build()
env.SetGates(true, true)
local cf = env.BuildCharacterFrame()
local inspectFrame = env.NewFrame("Frame", "InspectFrame")
_G.InspectFrame = inspectFrame
local Chrome, UIKit, SkinBase = env.Chrome, env.UIKit, env.SkinBase

local built = {}
local function Provider(tag)
    return function(ctx)
        built[tag] = ctx
        local y = ctx.y
        local row = env.NewFrame("Frame", nil, ctx.scrollChild)
        y = ctx.PlaceRow(row, y)
        ctx.ResetRows()
        y = y - 250
        return y
    end
end

local charFlyout = Chrome.CreateSettingsFlyout(cf, {
    title = "QUI Character Panel",
    name = "QUI_CharSettingsPanel",
    triggerName = "QUI_CharacterSettingsBtn",
    triggerPoint = { "TOPRIGHT", cf, "TOPRIGHT", 6, -6 },
    extension = Chrome.CONFIG.PANEL_WIDTH_EXTENSION,
    provider = Provider("character"),
})
local inspectFlyout = Chrome.CreateSettingsFlyout(inspectFrame, {
    title = "QUI Inspect Panel",
    name = "QUI_InspectSettingsPanel",
    triggerName = "QUI_InspectSettingsBtn",
    triggerPoint = { "TOPRIGHT", inspectFrame, "TOPRIGHT", -5, -28 },
    extension = 0,
    provider = Provider("inspect"),
})
check("both flyouts built", charFlyout ~= nil and inspectFlyout ~= nil)
check("panels published under their globals",
    _G.QUI_CharSettingsPanel == charFlyout.panel and _G.QUI_InspectSettingsPanel == inspectFlyout.panel)

---------------------------------------------------------------------------
-- 1. Shared geometry
---------------------------------------------------------------------------
local ct, it = charFlyout.trigger, inspectFlyout.trigger
check("trigger width identical (118)", ct.width == 118 and it.width == 118, ("%s vs %s"):format(ct.width, it.width))
check("trigger height identical (20)", ct.height == 20 and it.height == 20)
check("trigger label text", charFlyout.triggerLabel.text == "Settings" and inspectFlyout.triggerLabel.text == "Settings")
check("trigger label font 12", charFlyout.triggerLabel.fontSize == 12 and inspectFlyout.triggerLabel.fontSize == 12)
check("trigger label idle white .85",
    approx(charFlyout.triggerLabel.textColor[4], 0.85) and approx(inspectFlyout.triggerLabel.textColor[4], 0.85))
check("trigger strata/level identical", ct.strata == it.strata and ct.level == it.level)

local cp, ip = charFlyout.panel, inspectFlyout.panel
check("panel size identical (450x600)", cp.width == 450 and cp.height == 600 and ip.width == 450 and ip.height == 600)
check("panel strata/level identical", cp.strata == ip.strata and cp.level == ip.level and cp.strata == "DIALOG")
check("panels start hidden", cp:IsShown() == false and ip:IsShown() == false)
local cpX, ipX = cp.points[1][4], ip.points[1][4]
check("flyout offset = extension + shared gap for both",
    cpX == 55 + Chrome.CONFIG.FLYOUT_GAP and ipX == 0 + Chrome.CONFIG.FLYOUT_GAP, ("%s / %s"):format(cpX, ipX))
check("flyout anchors TOPLEFT -> parent TOPRIGHT for both",
    cp.points[1][1] == "TOPLEFT" and cp.points[1][3] == "TOPRIGHT" and ip.points[1][1] == "TOPLEFT" and ip.points[1][3] == "TOPRIGHT")
check("panel bg/border from the skin palette",
    env.BgColor(cp) and approx(env.BgColor(cp)[1], env.colors[5]) and env.BorderColor(cp) and approx(env.BorderColor(cp)[1], env.colors[1]))
check("both panels carry the same colours",
    approx(env.BgColor(cp)[1], env.BgColor(ip)[1]) and approx(env.BorderColor(cp)[1], env.BorderColor(ip)[1]))
check("title text differs only", charFlyout.title.text == "QUI Character Panel" and inspectFlyout.title.text == "QUI Inspect Panel")
check("title font 14 on both", charFlyout.title.fontSize == 14 and inspectFlyout.title.fontSize == 14)
check("title uses the text accent", approx(charFlyout.title.textColor[1], env.colors[1]) and approx(inspectFlyout.title.textColor[1], env.colors[1]))
check("close button skinned on both",
    SkinBase.GetFrameData(charFlyout.closeButton, "closeLabel") ~= nil
    and SkinBase.GetFrameData(inspectFlyout.closeButton, "closeLabel") ~= nil)
check("no UIPanelCloseButton template", charFlyout.closeButton.template == nil and inspectFlyout.closeButton.template == nil)

---------------------------------------------------------------------------
-- 2. Shared scroll contract
---------------------------------------------------------------------------
local cCtl = UIKit.GetSmoothScroll(charFlyout.scrollFrame)
local iCtl = UIKit.GetSmoothScroll(inspectFlyout.scrollFrame)
check("smooth scroll attached to both", cCtl ~= nil and iCtl ~= nil)
check("scroll step 30 on both", cCtl and cCtl.step == 30 and iCtl and iCtl.step == 30)
check("scrollbar built on both", charFlyout.scroll and charFlyout.scroll.bar and inspectFlyout.scroll and inspectFlyout.scroll.bar)
check("scrollbar track width 4", charFlyout.scroll.bar.track.width == 4 and inspectFlyout.scroll.bar.track.width == 4)
check("scrollbar thumb tinted with scrollThumb",
    charFlyout.scroll.bar.thumbTexture.color and approx(charFlyout.scroll.bar.thumbTexture.color[4], 0.6))
check("scrollbar hidden while content fits", charFlyout.scroll.bar.track:IsShown() == false)
check("no bespoke OnMouseWheel: controller owns the wheel", charFlyout.scrollFrame.scripts.OnMouseWheel ~= nil and charFlyout.scrollFrame.wheel == true)
check("scroll frame gutter identical",
    charFlyout.scrollFrame.points[2][4] == -Chrome.CONFIG.FLYOUT_GUTTER and inspectFlyout.scrollFrame.points[2][4] == -Chrome.CONFIG.FLYOUT_GUTTER)
check("scroll child width identical", charFlyout.scrollChild.width == inspectFlyout.scrollChild.width)

---------------------------------------------------------------------------
-- 3. Lazy build + toggle + ctx contract
---------------------------------------------------------------------------
check("content not built until first open", built.character == nil and built.inspect == nil)
charFlyout.Toggle()
check("Toggle builds and shows", built.character ~= nil and cp:IsShown() == true)
local ctx = built.character
check("ctx exposes panel/scrollChild/GUI/PlaceRow/ResetRows/PAD/FORM_ROW",
    ctx.panel == cp and ctx.scrollChild == charFlyout.scrollChild and ctx.GUI ~= nil
    and type(ctx.PlaceRow) == "function" and type(ctx.ResetRows) == "function" and ctx.PAD == 8 and ctx.FORM_ROW == 28)
check("ctx.y starts at -5", ctx.y == -5)
check("scroll child height from provider result", charFlyout.scrollChild.height == math.abs(-5 - 28 - 250) + 20)
charFlyout.Toggle()
check("Toggle again hides", cp:IsShown() == false)
charFlyout.Toggle()
check("provider runs once", cp:IsShown() == true and charFlyout.built == true)
cf:Hide()
check("parent hide closes the flyout", cp:IsShown() == false)

inspectFlyout.Toggle()
check("inspect provider ran with its own ctx", built.inspect ~= nil and built.inspect.panel == ip)
ctx = built.inspect
ctx.Reopen()
check("Reopen hides then re-shows on the next tick", ip:IsShown() == false)
env.RunTimers()
check("Reopen re-shows", ip:IsShown() == true)

-- Widget API missing: build is refused, nothing shown twice.
env.widgetAPI = false
local late = Chrome.CreateSettingsFlyout(cf, { title = "Late", provider = Provider("late") })
late.Toggle()
check("build refused without the widget API", late.built == false and built.late == nil)
env.widgetAPI = nil

---------------------------------------------------------------------------
-- 4. Theme refresh reaches both
---------------------------------------------------------------------------
env.colors[1], env.colors[5] = 0.9, 0.3
Chrome.RefreshTheme()
check("RefreshTheme re-tints both panels", approx(env.BorderColor(cp)[1], 0.9) and approx(env.BorderColor(ip)[1], 0.9) and approx(env.BgColor(cp)[1], 0.3))
check("RefreshTheme re-tints both triggers", approx(env.BorderColor(ct)[1], 0.9) and approx(env.BorderColor(it)[1], 0.9))
check("RefreshTheme re-tints both titles", approx(charFlyout.title.textColor[1], 0.9) and approx(inspectFlyout.title.textColor[1], 0.9))

---------------------------------------------------------------------------
-- 5. Source pins: both modules use the builder, no private panels
---------------------------------------------------------------------------
local function readFile(path)
    local fh = assert(io.open(path, "rb"), "failed to open " .. path)
    local text = fh:read("*a"); fh:close(); return text
end
local pane = readFile("modules/skinning/character_pane/character.lua")
local inspect = readFile("modules/skinning/character_pane/inspect.lua")
check("character pane uses the builder", pane:find("chrome.CreateSettingsFlyout(CharacterFrame, {", 1, true) ~= nil)
check("inspect pane uses the builder", inspect:find("chrome.CreateSettingsFlyout(InspectFrame, {", 1, true) ~= nil)
check("character pane has no private settings panel", pane:find('CreateFrame("Frame", "QUI_CharSettingsPanel"', 1, true) == nil)
check("inspect pane has no private settings panel", inspect:find('CreateFrame("Frame", "QUI_InspectSettingsPanel"', 1, true) == nil)
check("inspect pane dropped UIPanelScrollFrameTemplate", inspect:find("UIPanelScrollFrameTemplate", 1, true) == nil)
check("inspect pane dropped the custom-field glow", inspect:find("_accentGlow", 1, true) == nil)
check("character pane has no bespoke settings wheel handler", pane:find("current - delta * 30", 1, true) == nil)
check("character stats panel uses the shared scroll contract", pane:find("chrome.AttachScroll(scrollFrame", 1, true) ~= nil)
check("character stats panel dropped the 20 px jump", pane:find("current - delta * 20", 1, true) == nil)

if failures > 0 then
    print(("FAIL: character_inspect_settings_flyout_parity_test (%d)"):format(failures))
    os.exit(1)
end
print("OK: character_inspect_settings_flyout_parity_test")
