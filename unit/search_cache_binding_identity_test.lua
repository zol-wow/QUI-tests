-- Same-label controls in actual providers must survive both generation and load.
local cache = dofile("tests/helpers/search_cache.lua")()
local required = {
    ["unitFramesPage|profile.quiUnitFrames.player|healthOffsetX"] = "X Offset",
    ["unitFramesPage|profile.quiUnitFrames.player|powerTextOffsetX"] = "X Offset",
    ["hudVisibilityPage|profile.actionBarsVisibility|fadeDuration"] = "Fade Duration (sec)",
    ["hudVisibilityPage|profile.chatVisibility|fadeDuration"] = "Fade Duration (sec)",
    ["skinningPage|profile.general|objectiveTrackerBorderColorSource"] = "Border Color Source",
}
local function Check(rows)
    local found = {}
    for _, entry in ipairs(rows) do
        local d = entry.widgetDescriptor or {}
        local key = table.concat({entry.featureId or "", d.dbPath or "", tostring(d.dbKey or "")}, "|")
        if required[key] then
            assert(entry.label == required[key], "actual provider label changed: " .. key)
            found[key] = true
        end
    end
    for key in pairs(required) do assert(found[key], "actual provider binding missing: " .. key) end
end
Check(cache.settings)
local file = assert(io.open("tools/generate_search_cache.lua")); local source=file:read("*a"); file:close()
local marker=assert(source:find('local frame = create_stub_node("Frame", nil, false)',1,true))
assert(loadstring(source:sub(1,marker-1)))()
QUI.GUI:ApplyGeneratedSearchCache(cache)
Check(QUI.GUI.StaticSettingsRegistry)
local GUI = QUI.GUI
local ns
for index = 1, math.huge do
    local name, value = debug.getupvalue(GUI.EnsureSearchCacheLoaded, index)
    if not name then break end
    if name == "ns" then ns = value; break end
end
assert(ns)
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end
for key, value in pairs(ns.defaults.profile) do QUI.QUICore.db.profile[key] = Copy(value) end
local createFrame = CreateFrame
CreateFrame = function(kind, name, parent, ...)
    local frame = createFrame(kind, name, parent, ...)
    if kind == "Slider" then
        frame.GetThumbTexture = function() return createFrame("Texture", nil, frame) end
    end
    return frame
end
local hudPaths = {
    ["profile.cdmVisibility"] = "CDM Visibility",
    ["profile.unitframesVisibility"] = "Unitframes Visibility",
    ["profile.customTrackersVisibility"] = "Custom Items/Spells Bars",
    ["profile.auraDisplays.hudVisibility"] = "Aura Displays",
    ["profile.actionBarsVisibility"] = "Action Bars Visibility",
    ["profile.chatVisibility"] = "Chat Frames Visibility",
}
local function CheckSearch()
    local hits, nav = GUI:ExecuteSearch("fade duration")
    local found, count = {}, 0
    for _, hit in ipairs(hits) do
        local e = hit.data
        local d = e.widgetDescriptor or {}
        if e.featureId == "hudVisibilityPage" and d.dbKey == "fadeDuration" then
            assert(hudPaths[d.dbPath], "unexpected HUD binding")
            assert(not found[d.dbPath], "duplicate HUD binding")
            found[d.dbPath] = true
            count = count + 1
        end
    end
    assert(count == 6, "search merged distinct HUD bindings: expected 6, got " .. count)
    return hits, nav
end
CheckSearch()
-- Identical display breadcrumbs must not collapse different real bindings,
-- including the render cache on a repeated query. Use actual cache descriptors.
local breadcrumb = GUI.GetSearchBreadcrumb
GUI.GetSearchBreadcrumb = function() return {"HUD Visibility"} end
local hits, nav = CheckSearch()
local content = CreateFrame("Frame"); content:SetSize(900, 700)
local built, original = {}, GUI.CreateSearchWidgetFromDescriptor
GUI.CreateSearchWidgetFromDescriptor = function(self, parent, entry, ...)
    local widget = original(self, parent, entry, ...)
    local descriptor = entry.widgetDescriptor or {}
    if descriptor.dbKey == "fadeDuration" and hudPaths[descriptor.dbPath] then
        assert(widget, "real HUD search widget did not build")
        built[descriptor.dbPath] = widget
    end
    return widget
end
GUI:RenderSearchResults(content, hits, "fade duration", nav)
local seen = {}
for path in pairs(hudPaths) do
    assert(built[path], "missing rendered binding " .. path)
    assert(not seen[built[path]], "two bindings reused the same widget")
    seen[built[path]] = true
end
local count = 0
for _ in pairs(content._searchRenderCache.widgets) do count = count + 1 end
GUI:RenderSearchResults(content, hits, "fade duration", nav)
local again = 0
for _ in pairs(content._searchRenderCache.widgets) do again = again + 1 end
assert(count == again, "repeated search changed widget cache identities")
GUI.GetSearchBreadcrumb = breadcrumb
for _,e in ipairs(GUI.StaticSettingsRegistry) do
    local d = e.widgetDescriptor or {}
    if e.featureId == "hudVisibilityPage" and d.dbKey == "fadeDuration" then
        assert(e.sectionName == hudPaths[d.dbPath], "HUD binding has no distinct visible section: " .. d.dbPath)
    end
end
print("OK: actual provider bindings survive cache, search merging, rendering, and repeated queries")
