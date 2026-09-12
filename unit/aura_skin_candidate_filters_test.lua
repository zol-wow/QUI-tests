_G.AuraContainerSortMethod = { Default = 1 }
_G.AuraContainerSortDirection = { Normal = 1 }
_G.AnchorUtil = {
    FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 },
    FlowLayoutAxis = { Horizontal = 0, Vertical = 1 },
}

local ns = {}
assert(loadfile("core/aura_theme.lua"))("QUI", ns)
assert(loadfile("core/aura_skin.lua"))("QUI", ns)
local skin = ns.Addon.AuraSkin
local function container()
    local c = { groups = {}, writes = 0 }
    function c:HasAuraGroup(key) return self.groups[key] ~= nil end
    function c:AddAuraGroup(key, _, options) self.groups[key] = options end
    function c:SetAuraGroupFilterString() end
    function c:SetAuraGroupMaxFrameCount() end
    function c:SetAuraGroupSortMethod() end
    function c:SetAuraGroupCandidateFilters(key, filters)
        self.writes = self.writes + 1
        self.groups[key].candidateFilters = filters
    end
    function c:SetAuraGroupLayout() end
    function c:SetFlowLayoutAnchorPoint() end
    function c:SetFlowLayoutGrowthDirection() end
    function c:SetFlowLayoutPadding() end
    function c:SetFlowLayoutAxis() end
    function c:SetFlowLayoutMaximumLineSize() end
    return c
end

local c = container()
local g = { key = "aura", filter = "HELPFUL" }
local function configure(filters)
    g.candidateFilters = filters
    skin.Configure(c, { iconSize = 20 }, { g })
end
configure({ includeSpellIDs = { [123] = true }, maxDuration = 30 })
for _ = 1, 100 do
    configure({ includeSpellIDs = { [123] = true }, maxDuration = 30 })
end
assert(c.writes == 0, "unchanged Configure forces " .. c.writes .. " native aura rebuilds")

local filters = g.candidateFilters
filters.includeSpellIDs[456] = true
configure(filters)
assert(c.writes == 1, "in-place spell addition must reach the native group")
filters.includeSpellIDs[123] = nil
configure(filters)
assert(c.writes == 2, "in-place spell removal must reach the native group")
filters.maxDuration = nil
filters.isStealable = false
filters.includeDispelTypes = { Magic = true }
configure(filters)
assert(c.writes == 3, "scalar removals, false, and dispel maps must reach the native group")
configure({ includeSpellIDs = { [456] = true }, isStealable = false, includeDispelTypes = { Magic = true } })
assert(c.writes == 3, "fresh equal scalar and map values must reuse the native filters")
configure(nil)
assert(c.writes == 4, "clearing candidate restrictions must reach the native group")
configure({})
assert(c.writes == 4, "nil and empty top-level candidate filters are equivalent")
configure({ includeSpellIDs = {} })
assert(c.writes == 5, "empty include map must stay distinct from unrestricted filters")
configure({ includeSpellIDs = {} })
assert(c.writes == 5, "equal empty include maps must reuse the native filters")

local external = container()
external:AddAuraGroup("aura", "HELPFUL", {})
skin.SetGroupCandidateFilters(external, "aura", { includeSpellIDs = { [456] = true } })
skin.SetGroupCandidateFilters(external, "aura", { includeSpellIDs = { [456] = true } })
assert(external.writes == 1, "external groups must write once, then skip equal filters")
external:AddAuraGroup("other", "HELPFUL", {})
skin.SetGroupCandidateFilters(external, "other", { includeSpellIDs = { [456] = true } })
assert(external.writes == 2, "group keys must keep independent candidate snapshots")
print("OK: aura_skin_candidate_filters_test")
