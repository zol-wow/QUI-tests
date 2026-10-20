_G.AuraContainerSortMethod = { Default = 1 }
_G.AuraContainerSortDirection = { Normal = 1 }
_G.AnchorUtil = {
    FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 },
    FlowLayoutAxis = { Horizontal = 0, Vertical = 1 },
}

local file = assert(io.open("tests/framexml/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua"))
local source = file:read("*a")
file:close()
local first = assert(source:find("function CustomAuraContainerSharedMixin:SetAuraGroupSortMethod", 1, true))
local last = assert(source:find("function CustomAuraContainerSharedMixin:AddAuraSlot", first, true))
local native = { CustomAuraContainerSharedMixin = {}, AuraContainerDirtyMask = { AuraFrameLayoutGroups = 1 },
    AuraContainerUtil = { GetAuraSortComparator = function(method, direction) return method .. ":" .. direction end } }
setmetatable(native, { __index = _G })
local chunk = assert(loadstring([[
local function GetRequiredAuraGroup(self, key) return assert(self.groups[key]) end
local function ValidateSortOptions(method, direction) assert(type(method) == "number" and type(direction) == "number") end
local function GetInboundAuraGroupLayoutOptions(layout) return layout end
]] .. source:sub(first, last - 1)))
setfenv(chunk, native)
chunk()

local ns = {}
assert(loadfile("core/aura_theme.lua"))("QUI", ns)
assert(loadfile("core/aura_skin.lua"))("QUI", ns)
local skin = ns.Addon.AuraSkin
local function container()
    local c = setmetatable({ groups = {}, layoutOptionsByAuraGroup = {}, sortRequests = 0, layoutRequests = 0 },
        { __index = native.CustomAuraContainerSharedMixin })
    function c:HasAuraGroup(key) return self.groups[key] ~= nil end
    function c:AddAuraGroup(key, filter, options)
        local group = { filter = filter, maxFrameCount = options.maxFrameCount }
        function group:SetAuraComparator(value) self.comparator = value end
        group:SetAuraComparator(native.AuraContainerUtil.GetAuraSortComparator(options.sortMethod or 1, options.sortDirection or 1))
        self.groups[key] = group
        self.layoutOptionsByAuraGroup[group] = options.layout
        if self.rejectAdd then error("add rejected") end
    end
    function c:RequestFrameAssignmentRefresh()
        self.sortRequests = self.sortRequests + 1
        if self.rejectSort then error("sort rejected") end
    end
    function c:MarkDirty(mask)
        assert(mask == native.AuraContainerDirtyMask.AuraFrameLayoutGroups)
        self.layoutRequests = self.layoutRequests + 1
        if self.rejectLayout then error("layout rejected") end
    end
    function c:SetAuraGroupFilterString(key, filter) self.groups[key].filter = filter end
    function c:SetAuraGroupMaxFrameCount(key, count) self.groups[key].maxFrameCount = count end
    function c:SetAuraGroupCandidateFilters() end
    function c:SetFlowLayoutAnchorPoint() end
    function c:SetFlowLayoutGrowthDirection() end
    function c:SetFlowLayoutPadding() end
    function c:SetFlowLayoutAxis() end
    function c:SetFlowLayoutMaximumLineSize() end
    return c
end

local c = container()
local profile = { iconSize = 20 }
local group = { key = "aura", filter = "HELPFUL" }
local function configure() skin.Configure(c, profile, { group }) end
configure()
for _ = 1, 100 do configure() end
assert(c.sortRequests == 0 and c.layoutRequests == 0,
    "unchanged configuration must not request native sorting or layout: " .. c.sortRequests .. "/" .. c.layoutRequests)

group.sortMethod = 2
configure()
assert(c.sortRequests == 1 and c.layoutRequests == 0)
group.sortDirection = 2
configure()
assert(c.sortRequests == 2 and c.layoutRequests == 0)
profile.iconSize = 24
configure()
assert(c.sortRequests == 2 and c.layoutRequests == 1)
group.elementSpacing, group.elementWidth, group.elementHeight, group.groupSpacing = 3, 35, 36, 4
configure()
assert(c.layoutRequests == 2, "in-place layout edits must be applied")
group.groupSpacing = nil
configure()
assert(c.layoutRequests == 3, "removing an optional layout value must be applied")
local other = { key = "other", filter = "HARMFUL" }
skin.Configure(c, profile, { other, group })
assert(c.layoutRequests == 4, "changing group order must update layoutIndex")
skin.Configure(c, profile, {})
assert(c.groups.aura.maxFrameCount == 0 and c.groups.other.maxFrameCount == 0)
skin.Configure(c, profile, { other, group })
assert(c.groups.aura.maxFrameCount > 0 and c.sortRequests == 2 and c.layoutRequests == 4,
    "retired groups must regain capacity without redundant sort/layout writes")

group.sortMethod = 3
c.rejectSort = true
assert(not pcall(skin.Configure, c, profile, { other, group }), "native sort failure must propagate")
c.rejectSort = false
skin.Configure(c, profile, { other, group })
assert(c.sortRequests == 4, "failed sort application must retry")
group.elementWidth = 40
c.rejectLayout = true
assert(not pcall(skin.Configure, c, profile, { other, group }), "native layout failure must propagate")
c.rejectLayout = false
skin.Configure(c, profile, { other, group })
assert(c.layoutRequests == 6, "failed layout application must retry")

local external = container()
external:AddAuraGroup("aura", "HELPFUL", {})
skin.Configure(external, profile, { group })
skin.Configure(external, profile, { group })
assert(external.sortRequests == 1 and external.layoutRequests == 1,
    "adopted groups must apply unknown configuration once, independently of other containers")
group.sortMethod, group.sortDirection = nil, nil
skin.Configure(external, profile, { group })
assert(external.sortRequests == 2, "resetting sort options must restore defaults")
profile.rowSpacing = 9
skin.Configure(external, profile, { group })
assert(external.layoutRequests == 2, "row spacing changes must update native layout")

local legacy = container()
legacy.SetAuraGroupFilterString = nil
local legacyGroup = { key = "legacy", filter = "HELPFUL" }
skin.Configure(legacy, profile, { legacyGroup })
legacyGroup.filter = "HARMFUL"
skin.Configure(legacy, profile, { legacyGroup })
assert(legacy.groups["legacy|HELPFUL"].maxFrameCount == 0 and legacy.groups["legacy|HARMFUL"].maxFrameCount > 0)
legacyGroup.filter = "HELPFUL"
skin.Configure(legacy, profile, { legacyGroup })
assert(legacy.groups["legacy|HELPFUL"].maxFrameCount > 0 and legacy.groups["legacy|HARMFUL"].maxFrameCount == 0)
assert(legacy.sortRequests == 0 and legacy.layoutRequests == 0,
    "legacy filter-qualified groups must retain independent configuration snapshots")

local failed = container()
failed.rejectAdd = true
assert(not pcall(skin.Configure, failed, profile, { group }))
failed.rejectAdd = false
skin.Configure(failed, profile, { group })
skin.Configure(failed, profile, { group })
assert(failed.sortRequests == 1 and failed.layoutRequests == 1,
    "a failed group creation must not cache unconfirmed settings")
print("OK: aura_skin_config_dedup_test")
