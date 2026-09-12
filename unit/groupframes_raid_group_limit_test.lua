-- Raid group limit: limitGroupsByRaidSize (1-4 Mythic / 1-6 elsewhere) and
-- hideBenchGroupsInMythic (1-6 in Mythic only). Slices the helper block out of
-- groupframes.lua and drives it with a stubbed GetInstanceInfo.
local SRC = "QUI_GroupFrames/groupframes/groupframes.lua"

local fh = assert(io.open(SRC, "rb"))
local source = fh:read("*a")
fh:close()

local fails = 0
local function check(name, ok, detail)
    if ok then print("  ok  " .. name)
    else fails = fails + 1; print("FAIL  " .. name .. (detail and ("  " .. detail) or "")) end
end

local blockStart = assert(source:find("_state.IsRaidGroupLimitEnabled = function", 1, true))
local blockEnd = assert(source:find("local function GetRaidColumnAnchorPoint", blockStart, true))
local blockSrc = source:sub(blockStart, blockEnd - 1)

local difficultyID = 0
local env = setmetatable({
    GetInstanceInfo = function() return "Raid", "raid", difficultyID end,
}, { __index = _G })
env._G = env

local _state = {}
local chunk = assert((loadstring or load)("local _state = ...\n" .. blockSrc))
if setfenv then setfenv(chunk, env) end
chunk(_state)

local MYTHIC, HEROIC = 16, 15

local function limitFor(layout, diff)
    difficultyID = diff
    return _state.GetRaidGroupLimit(layout),
        _state.GetRaidGroupFilterString(layout),
        _state.IsRaidSubgroupAllowed(7, layout)
end

-- No toggles: every group shows regardless of difficulty.
local none = {}
check("no toggle -> not enabled", _state.IsRaidGroupLimitEnabled(none) == false)
local limit, filter, allows7 = limitFor(none, MYTHIC)
check("no toggle, Mythic -> 8 groups, full filter, group 7 allowed",
    limit == 8 and filter == "1,2,3,4,5,6,7,8" and allows7 == true, tostring(limit) .. " " .. tostring(filter))

-- hideBenchGroupsInMythic: 1-6 in Mythic, untouched elsewhere.
local bench = { hideBenchGroupsInMythic = true }
check("bench toggle -> enabled", _state.IsRaidGroupLimitEnabled(bench) == true)
limit, filter, allows7 = limitFor(bench, MYTHIC)
check("bench toggle, Mythic -> 6 groups, filter 1-6, group 7 hidden",
    limit == 6 and filter == "1,2,3,4,5,6" and allows7 == false, tostring(limit) .. " " .. tostring(filter))
check("bench toggle, Mythic -> group 6 still allowed",
    _state.IsRaidSubgroupAllowed(6, bench) == true)
limit, filter, allows7 = limitFor(bench, HEROIC)
check("bench toggle, Heroic -> no cap",
    limit == 8 and filter == "1,2,3,4,5,6,7,8" and allows7 == true, tostring(limit) .. " " .. tostring(filter))
limit = limitFor(bench, 0)
check("bench toggle, open world -> no cap", limit == 8, tostring(limit))

-- limitGroupsByRaidSize keeps its existing behaviour.
local bySize = { limitGroupsByRaidSize = true }
limit = limitFor(bySize, MYTHIC)
check("raid-size toggle, Mythic -> 4 groups", limit == 4, tostring(limit))
limit = limitFor(bySize, HEROIC)
check("raid-size toggle, Heroic -> 6 groups", limit == 6, tostring(limit))

-- Both on: the stricter cap wins.
local both = { limitGroupsByRaidSize = true, hideBenchGroupsInMythic = true }
limit = limitFor(both, MYTHIC)
check("both toggles, Mythic -> 4 groups", limit == 4, tostring(limit))
limit = limitFor(both, HEROIC)
check("both toggles, Heroic -> 6 groups", limit == 6, tostring(limit))

-- Section/nameList mode gating reads the shared enable helper, not the old key.
local gateStart = assert(source:find("local function UseRaidSectionHeaders", 1, true))
local gateEnd = assert(source:find("local function GetLayoutGrowDirection", gateStart, true))
local gateSrc = source:sub(gateStart, gateEnd)
check("UseRaidSectionHeaders / UseRaidNameListSections go through IsRaidGroupLimitEnabled",
    select(2, gateSrc:gsub("IsRaidGroupLimitEnabled", "")) == 2
    and gateSrc:find("limitGroupsByRaidSize", 1, true) == nil)

if fails > 0 then
    print(("FAILED %d check(s)"):format(fails))
    os.exit(1)
end
print("PASS groupframes_raid_group_limit_test")
