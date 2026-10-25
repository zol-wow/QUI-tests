local file = assert(io.open(os.getenv("QUI_NAVIGATION_GENERATOR") or "tools/generate_search_cache.lua", "rb"))
local source = file:read("*a")
file:close()
local cut = assert(source:find('local handle = assert(io.open(OUTPUT_PATH, "w"))', 1, true))
local catalog, settings, GUI, ns = assert(loadstring(source:sub(1, cut - 1)
    .. "\nreturn navigation_catalog, settings_entries, GUI, ns"))()

local failures = {}
local function Check(condition, message)
    if not condition then failures[#failures + 1] = message end
end
local byFeature = {}
for _, entry in ipairs(settings) do
    local feature = entry.featureId
    if feature then
        byFeature[feature] = byFeature[feature] or {}
        byFeature[feature][entry.label] = entry
    end
end
local function HasSetting(feature, label)
    Check(byFeature[feature] and byFeature[feature][label], feature .. " must index " .. label)
end
local function CheckColdSections(feature, expected)
    local tile = { config = { subPages = { { name = feature, featureId = feature } } } }
    local create = CreateFrame
    CreateFrame = function() error("cold settings navigation must not construct a page") end
    local links = GUI:GetTileNavigationPages(tile)
    CreateFrame = create
    Check(#links == #expected, feature .. " must expose all sections before the first click")
    for index, label in ipairs(expected) do
        Check(links[index] and links[index].sectionId == label,
            feature .. " cold section " .. index .. " must target " .. label)
    end
    Check(not tile._subPageBodies, feature .. " must remain unbuilt during navigation lookup")
end
ns.QUI_OptionsNavigationCatalog = catalog

local moverNS = { QUI_BlizzardMover = {}, L = setmetatable({}, { __index = function(_, key) return key end }) }
assert(loadfile("modules/qol/blizzard_mover_frames.lua"))("QUI", moverNS)
local moverData = moverNS.QUI_BlizzardMover._FrameRegistryData
local populated, groups = {}, {}
for _, entry in ipairs(moverData.frames) do
    populated[entry.group] = true
    HasSetting("blizzardMoverPage", entry.label or entry.id)
end
for id, group in pairs(moverData.groups) do
    if populated[id] then groups[#groups + 1] = { id = id, label = group.label or id } end
end
table.sort(groups, function(a, b) return moverData.groupOrder[a.id] < moverData.groupOrder[b.id] end)
local moverSections = { "General Settings" }
for _, group in ipairs(groups) do moverSections[#moverSections + 1] = group.label end
CheckColdSections("blizzardMoverPage", moverSections)
CheckColdSections("importExportPage", { "Export Current Profile", "Selective Export", "Import Profile String" })

for _, label in ipairs({
    "Show button bar for this frame", "Hide in combat", "Position", "Button spacing", "X offset", "Y offset",
}) do HasSetting("chatFrame1ButtonBar", label) end
for _, label in ipairs({
    "QUI options (/qui)", "Layout Mode", "Keybind mode", "Cooldown Manager", "Friends list", "Guild frame", "Reload UI",
}) do
    HasSetting("chatFrame1ButtonBar", label)
    local entry = byFeature.chatFrame1ButtonBar and byFeature.chatFrame1ButtonBar[label]
    Check(entry and entry.widgetType == "toggle" and not entry.widgetDescriptor,
        "Chat button " .. label .. " must navigate to its toggle without binding a reorderable array position")
end
for _, label in ipairs({ "Tab name", "Editing tab" }) do
    HasSetting("chatFrame1Filters", label)
end
local chatNS = { QUI = { Chat = { _internals = {} } } }
assert(loadfile("QUI_Chat/chat/tab_filters.lua"))("QUI", chatNS)
for _, group in ipairs(chatNS.QUI.Chat.TabFilters.GetStandardGroups()) do
    if group ~= "CHANNEL" then HasSetting("chatFrame1Filters", group) end
end

assert(#failures == 0, table.concat(failures, "\n"))
print("OK: generated menus and search include real mover, profile export, and chat dependencies")
