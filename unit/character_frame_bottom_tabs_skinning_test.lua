-- tests/unit/character_frame_bottom_tabs_skinning_test.lua
-- Run: lua tests/unit/character_frame_bottom_tabs_skinning_test.lua

local function readFile(path)
    local fh = assert(io.open(path, "rb"), "failed to open " .. path)
    local text = fh:read("*a")
    fh:close()
    return text
end

local function assertContains(text, needle, reason)
    assert(text:find(needle, 1, true), reason)
end

local source = readFile("modules/skinning/frames/character.lua")
local chrome = readFile("modules/skinning/frames/character_chrome.lua")

-- CharacterFrame bottom tabs (Character / Reputation / Currency) must route
-- through the SHARED canonical verb, not a private fork. The former
-- StyleCharacterFrameTab / UpdateCharacterFrameTabSelectedState pair was a
-- byte-for-byte copy of SkinTabButton / RefreshTabSelected and silently drifted
-- from every other frame's tabs whenever the canonical tab look changed.
-- The one call site is the chrome owner's StyleTabs; frames/character.lua
-- delegates to it so both gates (skin / enhancement) style tabs identically.
assertContains(
    source,
    "local function SkinCharacterFrameTabs()",
    "Character frame skinning must define the bottom-tab skin entry point")
assertContains(
    source,
    "if chrome and chrome.StyleTabs then chrome.StyleTabs() end",
    "Character frame skinning must delegate bottom tabs to CharacterChrome.StyleTabs")
assert(not source:find("SkinBase.SkinTabGroup(", 1, true),
    "frames/character.lua must not keep a second SkinTabGroup call site for the bottom tabs")

assertContains(
    chrome,
    "function CharacterChrome.StyleTabs()",
    "Chrome owner must expose StyleTabs")
assertContains(
    chrome,
    "SkinBase.SkinTabGroup(SkinBase.CollectNumberedTabs(\"CharacterFrame\", 3), CharacterFrame",
    "Bottom CharacterFrame tabs must route through the canonical SkinBase.SkinTabGroup (covers CharacterFrameTab1..3 + selection dispatch + persisted selection tint)")

-- Must NOT reintroduce the private fork (the inconsistency root).
for _, text in ipairs({ source, chrome }) do
    assert(not text:find("local function StyleCharacterFrameTab", 1, true),
        "CharacterFrame tabs must not reintroduce the private StyleCharacterFrameTab fork; use SkinBase.SkinTabGroup")
    assert(not text:find("local function UpdateCharacterFrameTabSelectedState", 1, true),
        "CharacterFrame tabs must not reintroduce the private selection-state fork; RefreshTabSelected (via SkinTabGroup) owns this")
end

assertContains(
    source,
    "SkinBase.OnAddOnLoaded(\"Blizzard_UIPanels_Game\", InitializeCharacterFrameSkinning, 0)",
    "Character frame skinning must initialize when the current CharacterFrame addon loads")

assertContains(
    source,
    "SkinBase.OnAddOnLoaded(\"Blizzard_CharacterFrame\", InitializeCharacterFrameSkinning, 0)",
    "Character frame skinning must catch up if CharacterFrame is already loaded before ADDON_LOADED is observed")

assertContains(
    source,
    "SkinCharacterFrameTabs()",
    "Character frame setup must apply bottom tab skinning")

print("OK: character_frame_bottom_tabs_skinning_test")
