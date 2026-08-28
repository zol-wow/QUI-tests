-- tests/unit/bags_tooltip_counts_test.lua
-- Run: lua tests/unit/bags_tooltip_counts_test.lua

-- Class-color fixture: the formatter reads RAID_CLASS_COLORS directly
-- (chat-classcolors precedent — never via the CUSTOM-aware helper).
_G.RAID_CLASS_COLORS = {
    MAGE = { colorStr = "ff3fc7eb" },
    BROKEN = {}, -- entry without colorStr must fall back to uncolored
}

local callbacks, added = {}, {}
local settings = { behavior = { tooltipCounts = "on" } }
local shiftHeld = false
local currencyInfo = {}
local records = {
    ["Main-TestRealm"] = { details = { class = "MAGE" }, currencies = { [2706] = 3, [2803] = 999 } },
    ["Alpha-TestRealm"] = { details = {}, currencies = { [2706] = 9, [2803] = 999 } },
    ["Zulu-TestRealm"] = { details = {}, currencies = { [2706] = 9, [2803] = 999 } },
}

_G.Enum = { TooltipDataType = { Item = 0, Currency = 5 } }
_G.TooltipDataProcessor = {
    AddTooltipPostCall = function(kind, callback) callbacks[kind] = callback end,
}
_G.GameTooltip = {
    AddLine = function(_, text) added[#added + 1] = text end,
}
_G.ItemRefTooltip = {}
_G.IsShiftKeyDown = function() return shiftHeld end
_G.C_CurrencyInfo = {
    GetCurrencyInfo = function(id) return currencyInfo[id] end,
}

local ns = {
    Helpers = { CreateDBGetter = function() return function() return settings end end },
    Bags = { IsActive = function() return true end },
    Storage = {
        Summaries = {
            WARBAND_OWNER = ":warband",
            GUILD_PREFIX = ":guild:",
            GetCounts = function() return {} end,
        },
        Store = {
            GetCurrentCharacterKey = function() return "Main-TestRealm" end,
            ListCharacters = function() return { "Alpha-TestRealm", "Main-TestRealm", "Zulu-TestRealm" } end,
            GetCharacter = function(key) return records[key] end,
        },
    },
}
(dofile("tests/helpers/locale.lua"))(ns)
local chunk = assert(loadfile("QUI_Bags/bags/tooltip_counts.lua"))
chunk("QUI", ns)
local TooltipCounts = ns.Bags.TooltipCounts
assert(TooltipCounts and type(TooltipCounts.BuildCountLines) == "function",
    "TooltipCounts.BuildCountLines must be exported")

-- getOwnerInfo fixture: ownerKey → info table, mirroring what the hook-side
-- resolver produces ({ label, classToken|nil, isCurrent|nil, plainTotal|nil }).
local INFOS = {
    ["Main-TestRealm"]    = { label = "Main", classToken = "MAGE", isCurrent = true },
    ["Alt-TestRealm"]     = { label = "Alt" },
    ["Hoarder-TestRealm"] = { label = "Hoarder", classToken = "BROKEN" },
    [":warband"]          = { label = "Warband", plainTotal = true },
    [":guild:Guild-TestRealm"] = { label = "Guild", plainTotal = true },
}
local function getOwnerInfo(key) return INFOS[key] end

-- Test 1: empty / nil counts → {}
assert(#TooltipCounts.BuildCountLines({}, getOwnerInfo) == 0, "empty counts must yield no lines")
assert(#TooltipCounts.BuildCountLines(nil, getOwnerInfo) == 0, "nil counts must yield no lines")

-- Test 2: single owner → one line, class-colored label, location breakdown,
-- NO total line below the threshold
do
    local lines = TooltipCounts.BuildCountLines(
        { ["Main-TestRealm"] = { bags = 3, bank = 5 } }, getOwnerInfo)
    assert(#lines == 1, "single owner must yield exactly one line, got " .. #lines)
    assert(lines[1] == "|cff3fc7ebMain|r: 8 (bags 3, bank 5)",
        "single-owner line wrong: " .. lines[1])
end

-- Test 3: multi-owner ordering — current character first, then total desc;
-- total line when 2+ owners
do
    local lines = TooltipCounts.BuildCountLines({
        ["Main-TestRealm"] = { bags = 2 },          -- current, smallest total
        ["Alt-TestRealm"]  = { bags = 7, bank = 3 },
        [":warband"]       = { warband = 5 },
    }, getOwnerInfo)
    assert(#lines == 4, "3 owners + total expected, got " .. #lines)
    assert(lines[1]:find("Main", 1, true), "current character must sort first: " .. lines[1])
    assert(lines[2] == "Alt: 10 (bags 7, bank 3)", "second line must be largest non-current: " .. lines[2])
    assert(lines[3] == "Warband: 5", "third line wrong: " .. lines[3])
    assert(lines[4] == "Total: 17", "total line wrong: " .. lines[4])
end

-- Test 4: warband + guild labels are plain totals — no parenthetical
-- breakdown (their single location is implied by the label)
do
    local lines = TooltipCounts.BuildCountLines({
        [":warband"]                = { warband = 20 },
        [":guild:Guild-TestRealm"]  = { guild = 12 },
    }, getOwnerInfo)
    assert(lines[1] == "Warband: 20", "warband line wrong: " .. lines[1])
    assert(lines[2] == "Guild: 12", "guild line wrong: " .. lines[2])
    assert(lines[3] == "Total: 32", "total line wrong: " .. lines[3])
end

-- Test 5: exactly 2 owners crosses the total-line threshold
do
    local lines = TooltipCounts.BuildCountLines({
        ["Main-TestRealm"] = { bags = 1 },
        ["Alt-TestRealm"]  = { bags = 1 },
    }, getOwnerInfo)
    assert(#lines == 3, "2 owners must add a total line, got " .. #lines)
    assert(lines[3] == "Total: 2", "total line wrong: " .. lines[3])
end

-- Test 6: classToken without a colorStr entry (or missing from
-- RAID_CLASS_COLORS) renders uncolored
do
    local lines = TooltipCounts.BuildCountLines(
        { ["Hoarder-TestRealm"] = { bags = 4 } }, getOwnerInfo)
    assert(lines[1] == "Hoarder: 4 (bags 4)", "broken class entry must fall back: " .. lines[1])
    local unknownInfo = function() return { label = "X", classToken = "NOTACLASS" } end
    lines = TooltipCounts.BuildCountLines({ ["X-Y"] = { bags = 1 } }, unknownInfo)
    assert(lines[1] == "X: 1 (bags 1)", "unknown class token must fall back: " .. lines[1])
end

-- Test 7: breakdown follows the canonical location order regardless of
-- pairs() iteration; unknown future locations append (sorted) instead of
-- silently vanishing
do
    local lines = TooltipCounts.BuildCountLines({
        ["Alt-TestRealm"] = {
            auctions = 6, mail = 5, equipped = 1, bank = 4, bags = 2,
            zfuture = 9, afuture = 8,
        },
    }, getOwnerInfo)
    assert(lines[1] == "Alt: 35 (bags 2, bank 4, equipped 1, mail 5, auctions 6, afuture 8, zfuture 9)",
        "location ordering wrong: " .. lines[1])
end

-- Test 8: equal totals tie-break on label for deterministic output
do
    local lines = TooltipCounts.BuildCountLines({
        ["Alt-TestRealm"]     = { bags = 4 },
        ["Hoarder-TestRealm"] = { bags = 4 },
    }, getOwnerInfo)
    assert(lines[1]:find("Alt", 1, true) and lines[2]:find("Hoarder", 1, true),
        "equal totals must order by label: " .. lines[1] .. " / " .. lines[2])
end

-- Test 9: zero-count owners are skipped entirely (defensive — the index
-- never stores zeros, but a skipped owner must not consume the threshold)
do
    local lines = TooltipCounts.BuildCountLines({
        ["Main-TestRealm"] = { bags = 0 },
        ["Alt-TestRealm"]  = { bags = 3 },
    }, getOwnerInfo)
    assert(#lines == 1, "zero-total owner must be skipped, got " .. #lines .. " lines")
    assert(lines[1] == "Alt: 3 (bags 3)", "remaining owner wrong: " .. lines[1])
end

assert(type(callbacks[Enum.TooltipDataType.Item]) == "function",
    "item TooltipDataProcessor callback must remain registered")
local currencyPostCall = assert(callbacks[Enum.TooltipDataType.Currency],
    "currency TooltipDataProcessor callback must be registered")

currencyInfo[2706] = { isAccountWide = false, quantity = 500 }
added = {}
currencyPostCall(GameTooltip, { id = 2706 })
assert(#added == 5, "blank + 3 characters + total expected")
assert(added[1] == " ", "currency rows need a separator")
assert(added[2] == "|cff3fc7ebMain|r: 3", "current character must sort first")
assert(added[3] == "Alpha: 9", "equal totals must tie-break by label")
assert(added[4] == "Zulu: 9", "equal-total ordering wrong")
assert(added[5] == "Total: 21", "character total wrong")

currencyInfo[2803] = { isAccountWide = true, quantity = 41 }
added = {}
currencyPostCall(GameTooltip, { id = 2803 })
assert(#added == 2 and added[1] == " " and added[2] == "Warband (account-wide): 41",
    "account-wide currency must use the live Warband quantity once")

settings.behavior.tooltipCounts = "off"
added = {}
currencyPostCall(GameTooltip, { id = 2706 })
assert(#added == 0, "off mode must suppress currency counts")

settings.behavior.tooltipCounts = "modifier"
shiftHeld = false
currencyPostCall(GameTooltip, { id = 2706 })
assert(#added == 0, "modifier mode must suppress counts without Shift")

shiftHeld = true
currencyPostCall(GameTooltip, { id = 2706 })
assert(#added > 0, "modifier mode must show counts with Shift")

print("OK: bags_tooltip_counts_test")
