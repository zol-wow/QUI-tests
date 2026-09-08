-- tests/unit/character_module_disabled_native_fallback_test.lua
-- Run: lua tests/unit/character_module_disabled_native_fallback_test.lua

local function readFile(path)
    local fh = assert(io.open(path, "rb"), "failed to open " .. path)
    local text = fh:read("*a")
    fh:close()
    return text
end

local function assertContains(text, needle, reason)
    assert(text:find(needle, 1, true), reason)
end

-- The shell / decoration hiding moved from frames/character.lua into the
-- chrome owner (modules/skinning/frames/character_chrome.lua); the
-- "leave the native stats pane alone when the enhancement is off" contract
-- is pinned there now.
local characterChrome = readFile("modules/skinning/frames/character_chrome.lua")
local characterFrameSkin = readFile("modules/skinning/frames/character.lua")
local inspectFrameSkin = readFile("modules/skinning/frames/inspect.lua")
local inspectPane = readFile("modules/skinning/character_pane/inspect.lua")

local hideStart = assert(
    characterChrome:find("local function HideBlizzardDecorations(permanent)", 1, true),
    "Character chrome owner should have a decoration-hiding helper")
local hideEnd = assert(
    characterChrome:find("local function ApplyShellColors()", hideStart, true),
    "Character chrome decoration helper should precede the shell colour helper")
local hideBlock = characterChrome:sub(hideStart, hideEnd)

assertContains(
    characterChrome,
    "local function IsEnhancementOn()",
    "Chrome owner must know whether the QUI character pane replacement is enabled")

assertContains(
    characterChrome,
    "local function RestoreNativeStatsPane()",
    "Chrome owner must be able to restore Blizzard's native stats pane when the replacement is disabled")

assertContains(
    hideBlock,
    'if ownership.statsPane == "enhancement" then',
    "Chrome owner must only mask Blizzard's native stats pane when the QUI stats replacement is enabled")

assertContains(
    hideBlock,
    'elseif ownership.statsPane == "chrome" then',
    "Chrome owner must give the native stats pane a legible chrome-only skin when only the frame skin is on")

assertContains(
    hideBlock,
    "RestoreNativeStatsPane()",
    "Chrome owner must leave native stats visible when neither gate owns the stats pane")

assertContains(
    characterFrameSkin,
    "chrome.SetExtended(extended)",
    "Frame skinning must delegate the shell to the chrome owner")
assert(not characterFrameSkin:find("CreateFrame(\"Frame\", \"QUI_CharacterFrameBg_Skin\"", 1, true),
    "Frame skinning must not build its own shell any more")

assertContains(
    inspectFrameSkin,
    "settings.enabled == false",
    "Inspect frame skin background extension must honor the master character module toggle")

assertContains(
    inspectPane,
    "local function IsCharacterModuleEnabled(settings)",
    "Inspect overlay module must treat character.enabled as the master gate")

local hookStart = assert(
    inspectPane:find("local function HookInspectFrame()", 1, true),
    "Inspect overlay hook function should exist")
local hookEnd = assert(
    inspectPane:find('InspectFrame:HookScript("OnShow"', hookStart, true),
    "Inspect OnShow hook should be installed after the module gate")
local hookGateBlock = inspectPane:sub(hookStart, hookEnd)

assertContains(
    hookGateBlock,
    "if not IsCharacterModuleEnabled(settings) then return end",
    "Inspect overlay hooks must not install when the QUI character module is disabled")

local updateStart = assert(
    inspectPane:find("local function UpdateInspectFrame()", 1, true),
    "Inspect update function should exist")
local updateEnd = assert(
    inspectPane:find("local function HookInspectFrame()", updateStart, true),
    "Inspect update function should precede the hook section")
local updateBlock = inspectPane:sub(updateStart, updateEnd)

assertContains(
    updateBlock,
    "if not IsCharacterModuleEnabled(settings) then",
    "Inspect update path must hide QUI-owned overlays when the master module is disabled")

assertContains(
    updateBlock,
    "HideDetailedOverlays()",
    "Disabled character module must hide detailed inspect overlays")

assertContains(
    updateBlock,
    "HideLiteDisplays()",
    "Disabled character module must hide lite inspect overlays")

local rosterStart = assert(
    inspectPane:find("RefreshInspectUnitAfterRosterUpdate = function()", 1, true),
    "Inspect roster refresh helper should exist")
local rosterEnd = assert(
    inspectPane:find("RefreshCurrentInspectGUID = function", rosterStart, true),
    "Inspect roster refresh helper should precede GUID refresh helper")
local rosterBlock = inspectPane:sub(rosterStart, rosterEnd)

assertContains(
    rosterBlock,
    "if not IsCharacterModuleEnabled(GetSettings()) then return false end",
    "Inspect roster refresh must not rewrite InspectFrame state when the character module is disabled")

print("OK: character_module_disabled_native_fallback_test")
