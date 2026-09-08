-- Run: lua tests/unit/cdm_reanchor_duration_override_test.lua
local ns = {}
assert(loadfile("core/safecall.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_reanchor_decorate.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_reanchor_realenv.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_reanchor_runtime.lua"))("QUI", ns)

local settings = {
    buff = { spellOverrides = { [123] = { hideDurationText = true } } },
}
local env = ns.CDMReanchorRealEnv.BuildEnv({
    CDMSpellData = {
        GetSpellOverride = function(_, key, spellID)
            local db = settings[key]
            return db and db.spellOverrides[spellID]
        end,
    },
})
local runtime = ns.CDMReanchorRuntime.New({
    bridge = { InstallAnchorGuard = function() end, OverlayRect = function() end },
    decorate = env.decorate,
})

local function makeIcon(id)
    local hidden
    local anchors = 0
    local countdownText = {
        ClearAllPoints = function() end,
        SetPoint = function() anchors = anchors + 1 end,
    }
    local frame = {
        Cooldown = {
            SetHideCountdownNumbers = function(_, value) hidden = value end,
            GetCountdownFontString = function() return countdownText end,
        },
        GetFrameLevel = function() return 1 end,
    }
    local entry = { id = id, spellID = id, viewerType = "buff", source = "blizzardCDM" }
    local wrapper = { frame = frame, liveFrame = frame, src = entry, reanchored = true }
    return wrapper, function() return hidden end, function() return anchors end
end

local buff, isBuffHidden, buffAnchors = makeIcon(123)
local neighbor, isNeighborHidden = makeIcon(456)
local rowConfig = { size = 40, hideDurationText = false }
local plan = { placements = {
    { icon = buff, x = 0, y = 0, rowConfig = rowConfig },
    { icon = neighbor, x = 40, y = 0, rowConfig = rowConfig },
} }

assert(runtime:PositionEntries({}, plan, "buff") == 2, "both native buff icons are placed")
assert(isBuffHidden() == true, "per-spell Hide Duration Text must hide the native buff countdown")
assert(buffAnchors() == 0, "a hidden countdown must not be reanchored")
assert(isNeighborHidden() == false, "a neighboring buff must retain its countdown")
assert(rowConfig.hideDurationText == false, "a per-spell override must not change the shared row config")

buff.frame.Cooldown:SetHideCountdownNumbers(false)
runtime:PositionEntries({}, plan, "buff")
assert(isBuffHidden() == true, "repeat decoration must reapply the per-spell duration setting")

settings.buff.spellOverrides[123] = nil
runtime:PositionEntries({}, plan, "buff")
assert(isBuffHidden() == false, "clearing the override must restore the row's visible countdown")
assert(buffAnchors() == 1, "restoring the countdown must restore its text position")

rowConfig.hideDurationText = true
settings.buff.spellOverrides[123] = { hideDurationText = false }
runtime:PositionEntries({}, plan, "buff")
assert(isBuffHidden() == false, "an explicit show override must take precedence over the row")
assert(buffAnchors() == 2, "an explicit show override must position the visible text even when the row hides it")
assert(isNeighborHidden() == true, "an entry without an override must inherit the hidden row setting")
assert(rowConfig.hideDurationText == true, "an explicit show override must not change the shared row")

settings.buff.spellOverrides[123] = { glowEnabled = false }
runtime:PositionEntries({}, plan, "buff")
assert(isBuffHidden() == true, "unrelated spell overrides must preserve the row's duration setting")

rowConfig.hideDurationText = nil
runtime:PositionEntries({}, plan, "buff")
assert(isBuffHidden() == false, "the default row setting must restore countdowns")

settings.buff.spellOverrides[123] = { hideDurationText = true }
buff.src.spellID = 789
buff.src.overrideSpellID = 790
runtime:PositionEntries({}, plan, "buff")
assert(isBuffHidden() == true, "remapped auras must use the stored entry ID from the settings panel")

runtime:PositionEntries({}, plan, "utility")
assert(isBuffHidden() == false, "overrides must come from the destination container")

buff.src = neighbor.src
runtime:PositionEntries({}, plan, "buff")
assert(isBuffHidden() == false, "a recycled Blizzard frame must use its current entry's override")

print("OK: cdm_reanchor_duration_override_test")
