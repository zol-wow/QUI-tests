-- tests/unit/character_chrome_ownership_matrix_test.lua
-- Run: luajit tests/unit/character_chrome_ownership_matrix_test.lua
--
-- ns.CharacterChrome is the single owner of the Character window chrome and
-- resolves who draws what from the two profile gates
-- (general.skinCharacterFrame x character.enabled). This drives the REAL
-- chrome owner through the harness for all four combinations and asserts:
--   off/off  nothing is written to Blizzard frames, no shell exists
--   off/on   enhancement fallback shell via EnsureShell; tabs/close styled;
--            native stats pane masked; no chrome-only slot borders
--   on/off   half-skinned: shell + tabs + close + chrome-only slot borders
--            + legible CharacterStatsPane (fonts restored to alpha 1)
--   on/on    shell owned by the skin, slots/stats left to the enhancement
-- luacheck: globals CreateFrame CharacterFrame CharacterStatsPane CharacterHeadSlot CharacterHeadSlotFrame
-- luacheck: globals PaperDollFrame_SetLabelAndText PaperDollSidebarTabs
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

---------------------------------------------------------------------------
-- 1. Pure resolver: every cell of the matrix
---------------------------------------------------------------------------
do
    local env = Harness.Build()
    local R = env.Chrome.ResolveOwnership

    local offoff = R(false, false)
    check("off/off: shell none", offoff.shell == "none")
    check("off/off: no tabs/close/popouts", not offoff.tabs and not offoff.close and not offoff.popouts)
    check("off/off: slots none, stats native", offoff.slots == "none" and offoff.statsPane == "native")
    check("off/off: not half-skinned", offoff.halfSkinned == false)

    local offon = R(false, true)
    check("off/on: shell enhancement", offon.shell == "enhancement")
    check("off/on: tabs/close/popouts via chrome", offon.tabs and offon.close and offon.popouts)
    check("off/on: slots + stats enhancement", offon.slots == "enhancement" and offon.statsPane == "enhancement")
    check("off/on: not half-skinned", offon.halfSkinned == false)

    local onoff = R(true, false)
    check("on/off: shell skin", onoff.shell == "skin")
    check("on/off: half-skinned", onoff.halfSkinned == true)
    check("on/off: slots chrome, stats chrome", onoff.slots == "chrome" and onoff.statsPane == "chrome")

    local onon = R(true, true)
    check("on/on: shell skin", onon.shell == "skin")
    check("on/on: slots + stats enhancement", onon.slots == "enhancement" and onon.statsPane == "enhancement")
    check("on/on: not half-skinned", onon.halfSkinned == false)

    check("GetOwnership reads the live profile", env.Chrome.GetOwnership().shell == "skin")
    env.SetGates(false, false)
    check("GetOwnership follows gate changes", env.Chrome.GetOwnership().shell == "none")
end

---------------------------------------------------------------------------
-- 2. off/off: stock Blizzard, no QUI writes
---------------------------------------------------------------------------
do
    local env = Harness.Build()
    env.SetGates(false, false)
    local cf = env.BuildCharacterFrame()
    local before = env.createCount
    local initialized = env.Chrome.Initialize()
    check("off/off: Initialize declines", initialized == false and env.Chrome.IsInitialized() == false)
    check("off/off: EnsureShell returns nil", env.Chrome.EnsureShell({ extended = true }) == nil)
    check("off/off: no frames created", env.createCount == before, tostring(env.createCount - before))
    check("off/off: nine slice untouched", cf.NineSlice:IsShown() == true)
    check("off/off: stats pane untouched", CharacterStatsPane:GetAlpha() == 1)
    check("off/off: close button untouched",
        env.SkinBase.GetFrameData(cf.CloseButton, "closeLabel") == nil)
    check("off/off: no slot border", env.Chrome.GetSlotBorder(CharacterHeadSlot) == nil)
end

---------------------------------------------------------------------------
-- 3. off/on: enhancement fallback shell through the owner
---------------------------------------------------------------------------
do
    local env = Harness.Build()
    env.SetGates(false, true)
    local cf = env.BuildCharacterFrame()
    local tabCalls = 0
    local realSkinTabGroup = env.SkinBase.SkinTabGroup
    env.SkinBase.SkinTabGroup = function(...) tabCalls = tabCalls + 1; return realSkinTabGroup(...) end

    check("off/on: Initialize runs", env.Chrome.Initialize() == true)
    check("off/on: Initialize does not build the skin shell", env.Chrome.GetShell() == nil)
    check("off/on: tabs styled by the owner", tabCalls >= 1)
    check("off/on: close button styled by the owner",
        env.SkinBase.GetFrameData(cf.CloseButton, "closeLabel") ~= nil)

    local shell = env.Chrome.EnsureShell({ extended = true })
    check("off/on: EnsureShell builds the fallback shell", shell ~= nil and shell.name == "QUI_CharacterFrameBg_Skin")
    check("off/on: fallback shell reaches past the frame",
        shell and shell.points[2] and shell.points[2][4] == 55 and shell.points[2][5] == -50)
    check("off/on: fallback shell carries the skin bg colour",
        shell and env.BgColor(shell) and approx(env.BgColor(shell)[1], env.colors[5]))
    check("off/on: native stats pane masked for the enhancement", CharacterStatsPane:GetAlpha() == 0)
    check("off/on: no chrome-only slot border", env.Chrome.GetSlotBorder(CharacterHeadSlot) == nil)
    check("off/on: OwnsShell is false (enhancement owns it)", env.Chrome.OwnsShell() == false)

    -- Fallback shell hides are one-shot: the enhancement re-shows native
    -- chrome on other tabs, so a Show() must not be defeated by a hook.
    cf.NineSlice:Show()
    check("off/on: nine slice hide is not pinned", cf.NineSlice:IsShown() == true)
end

---------------------------------------------------------------------------
-- 4. on/off: half-skinned gets chrome-only slots / close / stats pane
---------------------------------------------------------------------------
do
    local env = Harness.Build()
    env.SetGates(true, false)
    local cf = env.BuildCharacterFrame()
    CharacterStatsPane:SetAlpha(0) -- as a previous enhancement session may have left it

    check("on/off: Initialize runs", env.Chrome.Initialize() == true)
    local shell = env.Chrome.GetShell()
    check("on/off: skin shell pre-built while hidden", shell ~= nil and shell.allPoints == cf)
    check("on/off: OwnsShell", env.Chrome.OwnsShell() == true)
    check("on/off: nine slice hidden", cf.NineSlice:IsShown() == false)
    cf.NineSlice:Show()
    check("on/off: nine slice hide is pinned (skin owner)", cf.NineSlice:IsShown() == false)

    local border = env.Chrome.GetSlotBorder(CharacterHeadSlot)
    check("on/off: chrome-only slot border exists", border ~= nil)
    check("on/off: slot border shown + tinted with the skin border",
        border and border:IsShown() and env.BorderColor(border) and approx(env.BorderColor(border)[1], env.colors[1]))
    check("on/off: Blizzard slot ring hidden", CharacterHeadSlotFrame:IsShown() == false)
    CharacterHeadSlotFrame:Show()
    check("on/off: slot ring stays hidden while half-skinned", CharacterHeadSlotFrame:IsShown() == false)
    check("on/off: slot icon trimmed", CharacterHeadSlot.icon.texCoord ~= nil)

    check("on/off: close button skinned", env.SkinBase.GetFrameData(cf.CloseButton, "closeLabel") ~= nil)
    check("on/off: sidebar decor hidden", PaperDollSidebarTabs.DecorLeft:IsShown() == false)

    check("on/off: stats pane restored to full alpha", CharacterStatsPane:GetAlpha() == 1)
    check("on/off: class art hidden", CharacterStatsPane.ClassBackground:GetAlpha() == 0)
    local title = CharacterStatsPane.AttributesCategory.Title
    check("on/off: category title uses the QUI font", title.font == "QUIFont.ttf")
    check("on/off: category title uses the text accent", title.textColor and approx(title.textColor[1], env.colors[1]))
    check("on/off: category parchment hidden", CharacterStatsPane.AttributesCategory.Background:GetAlpha() == 0)
    check("on/off: item level value font", CharacterStatsPane.ItemLevelFrame.Value.font == "QUIFont.ttf")

    -- Rows appear later through Blizzard's label writer; the post-hook skins them.
    local row = CharacterStatsPane.statsFramePool.Acquire()
    PaperDollFrame_SetLabelAndText(row, "Strength", "123")
    check("on/off: stat row label font via hook", row.Label.font == "QUIFont.ttf")
    check("on/off: stat row value white 1.0", row.Value.textColor and approx(row.Value.textColor[4], 1))
    check("on/off: stat row label white .85", row.Label.textColor and approx(row.Label.textColor[4], 0.85))
    check("on/off: stat row bounce line hidden", row.Background:GetAlpha() == 0)
    check("on/off: row state stored off-frame",
        env.SkinBase.GetFrameData(row, "qCharChromeStatRow") == true and rawget(row, "qCharChromeStatRow") == nil)

    -- Theme refresh re-tints the slot border from the live skin colour.
    env.colors[1], env.colors[2], env.colors[3] = 0.9, 0.3, 0.3
    env.Chrome.RefreshTheme()
    check("on/off: RefreshTheme re-tints slot borders", border and approx(env.BorderColor(border)[1], 0.9))
    check("on/off: RefreshTheme re-tints the shell", approx(env.BorderColor(shell)[1], 0.9))
end

---------------------------------------------------------------------------
-- 5. on/on: full redesign, enhancement owns slots and stats
---------------------------------------------------------------------------
do
    local env = Harness.Build()
    env.SetGates(true, true)
    local cf = env.BuildCharacterFrame()
    local masked = 0
    env.ns.QUI_MaskNativeStatsPane = function() masked = masked + 1 end

    check("on/on: Initialize runs", env.Chrome.Initialize() == true)
    check("on/on: skin shell exists", env.Chrome.GetShell() ~= nil)
    check("on/on: no chrome-only slot border", env.Chrome.GetSlotBorder(CharacterHeadSlot) == nil)
    check("on/on: slot ring left to the enhancement", CharacterHeadSlotFrame:IsShown() == true)
    check("on/on: stats pane masked through the enhancement's mask", masked >= 1)
    check("on/on: category title not restyled by chrome",
        CharacterStatsPane.AttributesCategory.Title.font == nil)

    local shell = env.Chrome.SetExtended(true)
    check("on/on: SetExtended(true) reaches past the frame",
        shell and shell.points[2] and shell.points[2][4] == 55)
    env.Chrome.SetExtended(false)
    check("on/on: SetExtended(false) hugs the frame", shell.allPoints == cf)
    check("on/on: close button skinned", env.SkinBase.GetFrameData(cf.CloseButton, "closeLabel") ~= nil)
end

---------------------------------------------------------------------------
-- 6. frames/character.lua delegates through the owner
---------------------------------------------------------------------------
do
    local env = Harness.Build({ loadFrameSkin = true })
    env.SetGates(true, false)
    local api = _G.QUI_CharacterFrameSkinning
    check("frame skin API exposes OwnsBackground + SetExtended + StyleCloseButton",
        type(api.OwnsBackground) == "function" and type(api.SetExtended) == "function"
        and type(api.StyleCloseButton) == "function")
    check("OwnsBackground follows the chrome owner", api.OwnsBackground() == true)
    env.SetGates(false, true)
    check("OwnsBackground false when the enhancement owns the shell", api.OwnsBackground() == false)
end

---------------------------------------------------------------------------
-- 7. Source pins: the enhancement pane delegates chrome, no second shell
---------------------------------------------------------------------------
do
    local fh = assert(io.open("modules/skinning/character_pane/character.lua", "rb"))
    local pane = fh:read("*a"); fh:close()
    check("enhancement: fallback shell via EnsureShell", pane:find("chrome.EnsureShell({ extended = true })", 1, true) ~= nil)
    check("enhancement: no private shell frame", pane:find("QUI_CharacterFrameBg_CharPane", 1, true) == nil)
    check("enhancement: close button via owner", pane:find("chrome.StyleCloseButton(button)", 1, true) ~= nil)
    check("enhancement: no direct SkinChromeCloseButton call", pane:find("skinBase.SkinChromeCloseButton(", 1, true) == nil)
    check("enhancement: IsSkinningHandlingBackground asks OwnsShell", pane:find("chrome.OwnsShell()", 1, true) ~= nil)

    fh = assert(io.open("QUI.toc", "rb"))
    local toc = fh:read("*a"); fh:close()
    local chromeAt = toc:find("modules\\skinning\\frames\\character_chrome.lua", 1, true)
    local paneAt = toc:find("modules\\skinning\\character_pane\\character.lua", 1, true)
    local skinAt = toc:find("modules\\skinning\\frames\\character.lua", 1, true)
    check("toc: chrome owner listed", chromeAt ~= nil)
    check("toc: chrome owner loads before both character modules",
        chromeAt and paneAt and skinAt and chromeAt < paneAt and chromeAt < skinAt)
end

if failures > 0 then
    print(("FAIL: character_chrome_ownership_matrix_test (%d)"):format(failures))
    os.exit(1)
end
print("OK: character_chrome_ownership_matrix_test")
