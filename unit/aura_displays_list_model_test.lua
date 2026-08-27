local function fail(msg)
    print("FAIL: aura_displays_list_model_test - " .. msg)
    os.exit(1)
end

local ns = {}
ns.L = setmetatable({}, { __index = function(_, k) return k end })
ns.Helpers = {}
assert(loadfile("modules/trackers/settings/aura_displays_content.lua"))("QUI", ns)
local Page = ns.QUI_AuraDisplaysOptions
if type(Page) ~= "table" or type(Page.BuildListModel) ~= "function" then
    fail("BuildListModel must be exported")
end

local displays = {
    { id = "d1", name = "Immolate", group = "Raid" },
    { id = "d2", name = "Doom", group = "Raid" },
    { id = "d3", name = "HoTs" },
    { id = "d4", name = "Subbed", group = "RaidChild" },
}
local tree = { children = {
    [""] = { "Raid", "Empty" },
    Raid = { "RaidChild" },
    RaidChild = {},
    Empty = {},
} }

local function build(search, isCollapsed)
    return Page.BuildListModel(displays, search, isCollapsed or function() return false end, tree)
end

-- Default expansion: nested headers with subtree counts, then Ungrouped.
local model = build(nil)
if #model ~= 8 then fail("expected 8 nodes, got " .. #model) end
if model[1].kind ~= "header" or model[1].group ~= "Raid" or model[1].count ~= 3 then
    fail("Raid header must count its whole subtree (2 own + 1 nested)")
end
if model[2].display.id ~= "d1" or model[3].display.id ~= "d2" then
    fail("group displays must follow their header in order")
end
if model[4].kind ~= "header" or model[4].group ~= "RaidChild"
    or model[4].depth ~= 1 or model[4].count ~= 1 then
    fail("nested group header must sit under its parent with depth 1")
end
if model[5].display.id ~= "d4" or model[5].depth ~= 2 then
    fail("nested displays must carry their tree depth")
end
if model[6].kind ~= "header" or model[6].group ~= "Empty" or model[6].count ~= 0 then
    fail("empty groups must render with count 0 so they stay configurable")
end
if model[7].group ~= "" or model[8].display.id ~= "d3" then
    fail("ungrouped section must come last")
end

-- Collapsing a parent hides the whole subtree but keeps the subtree count.
local collapsed = build(nil, function(g) return g == "Raid" end)
if #collapsed ~= 4 then fail("collapsed Raid must hide displays and nested groups") end
if collapsed[1].collapsed ~= true or collapsed[1].count ~= 3 then
    fail("collapsed header must keep its subtree count")
end

-- Collapsing only the child leaves the parent's own displays visible.
local childCollapsed = build(nil, function(g) return g == "RaidChild" end)
if #childCollapsed ~= 7 then fail("collapsed child must hide only its displays") end

-- Search prunes non-matching branches and overrides collapse.
local filtered = build("doom", function(g) return g == "Raid" end)
if #filtered ~= 2 or filtered[1].group ~= "Raid" or filtered[1].count ~= 1
    or filtered[2].display.id ~= "d2" then
    fail("search must keep only matching branches and override collapse")
end

-- Matching an ancestor group name keeps every display in its subtree.
local byGroup = build("raid")
local count = 0
for i = 1, #byGroup do
    if byGroup[i].kind == "display" then count = count + 1 end
end
if count ~= 3 then
    fail("ancestor group-name search must keep the subtree's displays, got " .. count)
end

print("OK: aura_displays_list_model_test")
