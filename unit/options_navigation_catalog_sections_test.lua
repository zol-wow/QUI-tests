local file = assert(io.open(os.getenv("QUI_NAVIGATION_GENERATOR") or "tools/generate_search_cache.lua", "rb"))
local source = file:read("*a")
file:close()
local cut = assert(source:find('local handle = assert(io.open(OUTPUT_PATH, "w"))', 1, true))
local catalog, GUI, ns = assert(loadstring(source:sub(1, cut - 1) .. "\nreturn navigation_catalog, GUI, ns"))()

local function Sections(featureId, tabKey)
    local record = assert(catalog[featureId], "missing feature: " .. featureId)
    for _, tab in ipairs(record.tabs) do
        if tab.key == tabKey then
            local result = {}
            for _, section in ipairs(assert(tab.sections, "missing sections for " .. featureId .. ":" .. tabKey)) do
                assert(not result[section.id], "section labels must deduplicate across provider variants")
                assert(section.label == section.id, "cold section identifiers must match rendered labels")
                local seen = {}
                for _, context in ipairs(assert(section.contexts)) do
                    if featureId == "cooldownManagerContainersPage" then
                        assert(type(context.order) == "number" and context.order > 0 and context.order % 1 == 0,
                            "CDM section contexts must preserve their rendered position")
                    else
                        assert(context.order == nil, "partial surface captures must preserve the catalog's existing section order")
                    end
                    local key = table.concat({ context.providerKey or "", context.surfaceUnitKey or "", context.surfaceTypeKey or "" }, "\31")
                    assert(not seen[key], "repeated renders must not duplicate section contexts")
                    seen[key] = true
                end
                result[section.id] = section
            end
            return result
        end
    end
    error("missing tab: " .. featureId .. ":" .. tabKey)
end

local perBar = assert(catalog.actionBarsPerBar, "unopened Per Bar settings must have navigation sections")
local expectedPerBar = { "Layout", "Visual", "Keybind Text", "Macro Names", "Stack Count", "Cooldown Duration Text", "Context Visibility" }
assert(#perBar.sections == #expectedPerBar, "cold Per Bar sections must match the initially selected bar's real headings")
for index, label in ipairs(expectedPerBar) do
    assert(perBar.sections[index].id == label and perBar.sections[index].label == label,
        "Per Bar section links must use the same heading identifiers and order as the editor")
end
ns.QUI_OptionsNavigationCatalog = catalog
local coldPerBar = { config = { subPages = { { name = "Per-Bar", featureId = "actionBarsPerBar" } } } }
local perBarLinks = GUI:GetTileNavigationPages(coldPerBar)
assert(#perBarLinks == #expectedPerBar and not coldPerBar._subPageBodies,
    "Per Bar must expose its section submenu before constructing any settings body")
for index, label in ipairs(expectedPerBar) do
    assert(perBarLinks[index].sectionId == label, "cold Per Bar section links must target the real editor headings")
end

local soundNS = { L = setmetatable({}, { __index = function(_, key) return key end }) }
assert(loadfile("modules/qol/sound_mute_catalog.lua"))("QUI", soundNS)
local expectedSoundSections = { "Sound Mute" }
for _, category in ipairs(soundNS.SoundMuteCatalog.categories) do
    expectedSoundSections[#expectedSoundSections + 1] = category.label
end
local sound = assert(catalog.soundMute, "Sound Mute must have cold navigation metadata")
assert(#sound.sections == #expectedSoundSections,
    "Sound Mute cold navigation must include every runtime category before the page is opened")
local coldSound = { config = { subPages = { { name = "Sound Mute", featureId = "soundMute" } } } }
local create = CreateFrame
CreateFrame = function() error("cold Sound Mute navigation must not construct settings frames") end
local soundLinks = GUI:GetTileNavigationPages(coldSound)
CreateFrame = create
assert(#soundLinks == #expectedSoundSections and not coldSound._subPageBodies,
    "Sound Mute categories must be visible without constructing its settings page")
for index, label in ipairs(expectedSoundSections) do
    assert(sound.sections[index].id == label and soundLinks[index].sectionId == label,
        "Sound Mute cold navigation must preserve runtime category order and heading targets")
end

local general = Sections("groupFramesPage", "general")
local appearance = Sections("groupFramesPage", "appearance")
local layout = Sections("groupFramesPage", "layout")
assert(general["Range Check"], "initial surface tabs must retain section shortcuts")
assert(appearance["Dispel Overlay"], "unopened appearance tabs must include section shortcuts")
assert(layout["Spotlight"], "raid-only sections must be harvested after the party variant")
local spotlightContexts = assert(layout["Spotlight"].contexts, "variant-only sections must declare their contexts")
assert(#spotlightContexts == 1 and spotlightContexts[1].providerKey == "raidFrames",
    "Spotlight must never become a Party shortcut")
local function HasContext(section, field, value)
    for _, context in ipairs(assert(section.contexts)) do
        if context[field] == value then return true end
    end
    return false
end
assert(HasContext(general["Range Check"], "providerKey", "partyFrames")
    and HasContext(general["Range Check"], "providerKey", "raidFrames"),
    "shared group sections must retain both provider contexts")
assert(not general["Dispel Overlay"] and not appearance["Range Check"], "sections must remain scoped to their tabs")
assert(Sections("unitFramesPage", "castbar")["Channel Ticks"], "unit frame sections must include unopened tabs")
local channelTicks = Sections("unitFramesPage", "castbar")["Channel Ticks"]
assert(HasContext(channelTicks, "surfaceUnitKey", "player") and HasContext(channelTicks, "surfaceUnitKey", "target"),
    "unit sections must retain their unit selections")
assert(Sections("nameplatesPage", "colors")["Reaction Colors"], "nameplate sections must include unopened tabs")
local reactionColors = Sections("nameplatesPage", "colors")["Reaction Colors"]
assert(HasContext(reactionColors, "surfaceTypeKey", "friendly") and HasContext(reactionColors, "surfaceTypeKey", "enemyNPC"),
    "nameplate sections must retain their type selections")
assert(Sections("cooldownManagerContainersPage", "effects")["Cooldown Swipe"], "CDM sections must include unopened tabs")
assert(Sections("spellRemindersPage", "timing")["Reminder Timing"], "reminder tabs must retain their own sections")
local timingContexts = Sections("spellRemindersPage", "timing")["Reminder Timing"].contexts
assert(#timingContexts == 1 and timingContexts[1].providerKey == nil
    and timingContexts[1].surfaceUnitKey == nil and timingContexts[1].surfaceTypeKey == nil,
    "context-independent sections must retain an empty universal context")
assert(Sections("spellRemindersPage", "tracking")["Raid Tracking"], "PI-specific tabs must be available before a reminder is selected")
local requests = Sections("spellRemindersPage", "requests")
assert(requests["Priority Order"] and requests["Rotation Order"], "reminder sections must combine alternate request modes")
for index, key in ipairs({ "timing", "appearance", "sounds", "load", "tracking", "buffs", "requests" }) do
    assert(catalog.spellRemindersPage.tabs[index].key == key, "cold reminder tabs must preserve the provider's order")
end

print("OK: cold navigation catalogs contain scoped sections for every rendered surface tab")
