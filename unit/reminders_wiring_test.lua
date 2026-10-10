-- tests/unit/reminders_wiring_test.lua
-- Run: lua tests/unit/reminders_wiring_test.lua
--
-- Structural guard for the QUI_Reminders module: every place a new sibling
-- addon and its settings page have to be registered, plus the shared seams it
-- relies on in core and QUI_CDM, and the i18n reachability of its strings.

local function readAll(path)
    local f = assert(io.open(path, "rb"), "missing " .. path)
    local d = f:read("*a"); f:close()
    return d:gsub("\r\n", "\n")
end
local function has(body, needle, message)
    assert(body:find(needle, 1, true), message .. "\nmissing: " .. needle)
end

-- Manifest + folder shape.
local manifest = assert(loadfile("core/addon_manifest.lua"))()
local entry
for _, e in ipairs(manifest) do if e.folder == "QUI_Reminders" then entry = e end end
assert(entry and entry.class == "lod", "QUI_Reminders is a load-on-demand suite addon")
local toc = readAll("QUI_Reminders/QUI_Reminders.toc")
has(toc, "## LoadOnDemand: 1", "TOC LoD flag")
has(toc, "## Dependencies: QUI", "TOC dependency")
has(toc, "## OptionalDeps: BigWigs, DBM-Core", "boss mods load first when present")
for _, file in ipairs({ "bossmods", "journal", "defensives", "callout", "engine" }) do
    has(toc, "reminders\\" .. file .. ".lua", "TOC lists " .. file)
end
for _, file in ipairs({ "model", "catalog", "group_frames", "presentation", "sounds", "runtime", "tracking", "init" }) do
    has(toc, "spell_reminders\\" .. file .. ".lua", "module TOC owns spell reminder " .. file)
end

-- Settings page wiring.
local optionsToc = readAll("QUI_Options/QUI_Options.toc")
has(optionsToc, "..\\QUI_Reminders\\reminders\\settings\\reminders_content.lua", "QUI_Options loads the page")
local tile = readAll("QUI_Options/tiles/reminders.lua")
has(tile, 'featureId = "remindersPage"', "reminders tile routes to the defensive page")
has(tile, 'featureId = "spellRemindersPage"', "reminders tile routes to the spell page")
has(tile, 'moduleFeatureId = "moduleAddon_QUI_Reminders"', "tile uses the module addon switch")
has(readAll("QUI_Options/init.lua"), "ns.QUI_RemindersTile.Register(frame)", "sidebar registers the reminders tile")
has(optionsToc, "tiles\\reminders.lua", "options loads the reminders tile")
local searchTool = readAll("tools/generate_search_cache.lua")
has(searchTool, 'path:match("^QUI_Reminders/.+/settings/")', "search cache indexes both module pages")
local content = readAll("QUI_Reminders/reminders/settings/reminders_content.lua")
has(content, 'nav = { tileId = "reminders", subPageIndex = SUBPAGE_INDEX }', "defensive search route uses the reminders tile")
has(content, 'id = "remindersPage"', "feature id")
has(content, 'moverKey = "remindersCallout"', "mover key matches the anchor key")
for _, key in ipairs({ "enabled", "source", "leadTime", "linger", "onlyWhenTanking", "skipWhenCovered",
    "timelineAllEvents", "cdmGlow", "iconSize", "textSide", "priorities", "abilities", "ttsMode", "ttsText" }) do
    has(content, '"' .. key .. '"', "page wires " .. key)
end

-- Defaults, export coverage, module page, anchoring.
local defaults = readAll("core/defaults.lua")
has(defaults, "        reminders = {\n            enabled = false,", "profile defaults ship off")
has(defaults, "            remindersCallout = {", "frameAnchoring default for the callout")
has(defaults, "    global = {\n        reminders = { seen = {} },", "account-wide seen catalogue under defaults.global")
local profileIO = readAll("core/profile_io.lua")
has(profileIO, 'topLevelKeys = { "reminders" }', "selective export category")
local modulesPage = readAll("core/settings/content/module_addons_content.lua")
has(modulesPage, 'QUI_Reminders    = ns.L["Reminders"]', "Module Addons label")
local callout = readAll("QUI_Reminders/reminders/callout.lua")
has(callout, 'local ANCHOR_KEY = "remindersCallout"', "anchor key")
has(callout, "QUI_RegisterFrameResolver(ANCHOR_KEY", "frame resolver registered at runtime")
has(callout, "um:RegisterElement({", "layout mode element registered at runtime")
for _, field in ipairs({ "getFrame = ", "isEnabled = ", "setEnabled = ", "onOpen = ", "onClose = ", "setGameplayHidden = " }) do
    has(callout, field, "layout element uses the RegisterElement contract: " .. field)
end
assert(not callout:find("previewOn", 1, true), "no adapter-only shorthand fields")
has(callout, "gameplayHidden = hide and true or false", "gameplay-hidden state is remembered")
has(callout, "if gameplayHidden then return false end", "a hidden element does not show a new callout")
has(callout, "if GetTime() >= hideAt then", "unhiding drops an expired callout")
local engine = readAll("QUI_Reminders/reminders/engine.lua")
assert(not engine:find("_G.QUI_", 1, true), "engine exports on ns.*, never _G")

-- Shared seams the module leans on.
local mainToc = readAll("QUI.toc")
assert(not mainToc:find("modules\\combat\\reminders\\", 1, true), "spell reminders no longer load in QUI core")
assert(not mainToc:find("QUI_Reminders", 1, true), "the core manifest does not load the optional reminders module's files")
has(mainToc, "core\\announce.lua", "announce seam ships in core")
local announce = readAll("core/announce.lua")
has(announce, "function Announce.PlaySound", "sound")
has(announce, "function Announce.Speak", "TTS")
has(announce, "function Announce.Chat", "chat")
local alerts = readAll("QUI_CDM/cdm/cdm_alerts.lua")
has(alerts, "ns.Announce.RegisterSoundResolver", "CDM sound kits plug into the shared seam")
has(alerts, "return ns.Announce.Speak(text)", "CDM TTS delegates")
local effects = readAll("QUI_CDM/cdm/cdm_effects.lua")
has(effects, "ns._OwnedGlows.FindIconBySpellID = FindIconBySpellID", "CDM icon lookup exported")
local init = readAll("init.lua")
has(init, 'input:match("^reminders%s+test%s*$")', "slash test command")

-- The priority list follows spec switches and edits the spec shown at click time.
has(content, 'frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")', "priority section repaints on spec change")
has(content, "specID ~= shownSpecID", "row callbacks verify the displayed spec")

-- Hovering a row shows the real spell or trinket tooltip on every list.
has(content, "GameTooltip.SetSpellByID, GameTooltip, r.tooltipSpellID", "spell rows show the spell tooltip")
has(content, 'GameTooltip.SetInventoryItem, GameTooltip, "player", r.tooltipSlot', "trinket rows show the item tooltip")
has(content, "hit:SetAllPoints(r.icon)", "only the icon is the hover target")
has(content, '"ANCHOR_CURSOR"', "tooltip anchors at the cursor")
assert(select(2, content:gsub("r%.tooltipSpellID = ", "")) >= 3, "priority, ability and seen rows all bind a tooltip")

-- Load-order sanity: the settings page must not run when the module is absent.
has(content, "if not ns.Reminders then", "page notes when the module is not loaded")

-- Strings reach the locale extractor.
local extractor = assert(loadfile("tools/i18n/extract_strings.lua"))()
local function keysOf(path) return extractor.collectKeys(readAll(path)) end
local engineKeys = keysOf("QUI_Reminders/reminders/engine.lua")
for _, key in ipairs({ "%s incoming - using %s", "Boss ability", "Test" }) do
    assert(engineKeys[key], "engine text must reach the locale extractor: " .. key)
end
local calloutKeys = keysOf("QUI_Reminders/reminders/callout.lua")
for _, key in ipairs({ "Reminder Callout", "QoL", "Defensive" }) do
    assert(calloutKeys[key], "callout text must reach the locale extractor: " .. key)
end
local pageKeys = keysOf("QUI_Reminders/reminders/settings/reminders_content.lua")
for _, key in ipairs({ "Enable Defensive Reminders", "Boss Mod Source", "Defensive Priority", "Boss Abilities", "Tick My Role",
    "Seen From Boss Mods", "Blizzard Encounter Timeline", "Warning Time" }) do
    assert(pageKeys[key], "page text must reach the locale extractor: " .. key)
end
local initKeys = keysOf("init.lua")
assert(initKeys["Reminders test: calling %s."] and initKeys["Reminders module is not loaded."], "slash feedback localized")
local modulesKeys = keysOf("core/settings/content/module_addons_content.lua")
assert(modulesKeys["Reminders"] and modulesKeys["Defensive callouts, spell cooldown reminders, and Power Infusion coordination."])

print("OK: reminders_wiring_test")
