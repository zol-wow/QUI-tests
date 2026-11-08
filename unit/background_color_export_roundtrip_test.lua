local h = dofile("tools/_addon_env.lua").BuildHarness({ noSeed = true })
local core = h.QUICore

local function SameColor(actual, expected)
    if type(actual) ~= "table" then return false end
    for i = 1, 4 do
        if actual[i] ~= expected[i] then return false end
    end
    return true
end

for _, case in ipairs({
    { category = "skinning", prefixes = { "readyCheck", "alerts", "statusTrackingBars" } },
    { category = "trackersTimers", prefixes = { "swingTimers" } },
}) do
    h.db:SetProfile("BackgroundSource" .. case.category)
    local source = h.db.profile.general
    for index, prefix in ipairs(case.prefixes) do
        source[prefix .. "BgOverride"] = true
        source[prefix .. "HideBackground"] = index % 2 == 0
        source[prefix .. "BackgroundColor"] = { .2, .4, .6, .25 }
    end
    source.autoRepair = "guild"
    local exported = assert(core:ExportProfileSelectionToString({ case.category }))
    h.db:SetProfile("BackgroundTarget" .. case.category)
    local target = h.db.profile.general
    target.autoRepair = "off"
    target.untouchedBackgroundColor = { .1, .3, .5, .7 }
    for _, prefix in ipairs(case.prefixes) do
        target[prefix .. "BgOverride"] = false
        target[prefix .. "HideBackground"] = true
        target[prefix .. "BackgroundColor"] = { .9, .8, .7, 1 }
    end
    assert(core:ImportProfileSelectionFromString(exported, { case.category }))
    target = h.db.profile.general
    for index, prefix in ipairs(case.prefixes) do
        assert(target[prefix .. "BgOverride"] == true,
            case.category .. " selective import must preserve " .. prefix .. " background override")
        assert(target[prefix .. "HideBackground"] == (index % 2 == 0),
            case.category .. " selective import must preserve hidden and visible background choices")
        assert(SameColor(target[prefix .. "BackgroundColor"], { .2, .4, .6, .25 }),
            case.category .. " selective import must preserve custom background RGB and transparency")
    end
    assert(target.autoRepair == "off", "background imports must preserve unrelated gameplay choices")
    assert(SameColor(target.untouchedBackgroundColor, { .1, .3, .5, .7 }),
        "background imports must preserve unselected surfaces")
end

h.db:SetProfile("BagBackgroundSource")
local appearance = h.db.profile.bags.appearance
appearance.bgOverride = true
appearance.hideBackground = false
appearance.backgroundColor = { .2, .4, .6, .25 }
appearance.borderColorSource = "custom"
appearance.borderColor = { .6, .4, .2, .75 }
local exported = assert(core:ExportProfileSelectionToString({ "bags" }))
h.db:SetProfile("BagBackgroundTarget")
assert(core:ImportProfileSelectionFromString(exported, { "bags" }))
appearance = h.db.profile.bags.appearance
assert(appearance.bgOverride == true and appearance.hideBackground == false,
    "bags category must preserve the background override and visibility")
assert(SameColor(appearance.backgroundColor, { .2, .4, .6, .25 }),
    "bags category must preserve the background color and transparency")
assert(appearance.borderColorSource == "custom" and SameColor(appearance.borderColor, { .6, .4, .2, .75 }),
    "bags category must preserve custom border coloring alongside backgrounds")
print("OK: background colors survive their selective profile categories")
