local eventFrame
_G.CreateFrame = function()
    local frame = { scripts = {} }
    function frame:RegisterEvent() end
    function frame:RegisterUnitEvent() end
    function frame:SetScript(name, callback) self.scripts[name] = callback end
    eventFrame = eventFrame or frame
    return frame
end
_G.wipe = function(t) for key in pairs(t) do t[key] = nil end; return t end
_G.UnitExists = function() return true end
_G.UnitIsDeadOrGhost = function() return false end
_G.UnitIsConnected = function() return true end
_G.UnitIsPlayer = function() return true end
_G.UnitCanAssist = function() return true end
_G.UnitInRange = function() return true, true end
_G.UnitIsUnit = function(unit, other) return unit == other end
_G.UnitClass = function() return "Mage", "MAGE" end
_G.InCombatLockdown = function() return false end
_G.C_Timer = { After = function(_, callback) callback() end }
_G.C_Spell = {
    GetSpellName = function(id) return "Spell " .. id end,
    GetSpellTexture = function(id) return id + 100000 end,
}
_G.C_UnitAuras = { GetAuraDataByIndex = function() return nil end }

local canonical, display = 290001, 290002
local items = { { spellID = canonical, displaySpellID = display, name = "Ranked buff", flags = 0, isKnown = true } }
_G.C_CooldownViewer = { GetGroupBuffItems = function() return items end }
local hidden = {}
_G.Enum = { CDMLayoutMode = { AccessOnly = 1 } }
local layout = {}
_G.CooldownViewerSettings = { GetLayoutManager = function()
    return { GetActiveLayout = function(_, mode) assert(mode == 1); return layout end }
end }
_G.CooldownManagerLayout_GetHiddenGroupBuffs = function(value)
    assert(value == layout)
    return hidden
end

local refreshes = 0
local ns = {
    Helpers = { IsSecretValue = function(value) return value == 290099 end },
    SafeCall = function(_, callback, ...) return pcall(callback, ...) end,
    QUI_GroupFrameAuras = { RefreshAll = function() refreshes = refreshes + 1 end },
}
assert(loadfile(arg[1] or "QUI_GroupFrames/groupframes/groupframes_missing_raid_buffs.lua"))("QUI_GroupFrames", ns)
local MRB = ns.QUI_GroupFrameMissingRaidBuffs
MRB:RegisterActivePredicate(function() return true end)
local element = { classDetection = false, buffChecks = { ["cdm:" .. canonical] = true }, maxIcons = 1 }
local function render(expectedID)
    local matches = MRB:BuildMatches("party1", element, {})
    assert(#matches == 1, "the canonical saved selection must still render its missing group buff")
    local aura = matches[1]
    assert(aura.spellId == expectedID, "rendered spell must use the current display rank")
    assert(aura.name == "Spell " .. expectedID, "cached label must follow the display rank")
    assert(aura.icon == expectedID + 100000, "rendered icon must follow the display rank")
    assert(aura.auraInstanceID == "QUI_MissingRaidBuff_cdm:" .. canonical,
        "synthetic aura identity must retain the canonical saved key across rank changes")
end
render(display)
local entry = MRB.RaidBuffs[#MRB.RaidBuffs]
assert(entry.key == "cdm:" .. canonical and #entry.ids == 1 and entry.ids[1] == canonical,
    "display rank must not rewrite canonical selection or aura lookup IDs")

items[1].displaySpellID = 290003
eventFrame.scripts.OnEvent(eventFrame, "SPELLS_CHANGED")
assert(refreshes == 1, "learned-rank changes must rebuild and refresh active missing-buff displays")
render(290003)
items[1].displaySpellID = nil
eventFrame.scripts.OnEvent(eventFrame, "COOLDOWN_VIEWER_DATA_LOADED")
render(canonical)
items[1].displaySpellID = "invalid"
MRB:RebuildRaidBuffs()
render(canonical)
items[1].displaySpellID = 290099
MRB:RebuildRaidBuffs()
render(canonical)

items[1].displaySpellID = display
hidden[1] = display
MRB:RebuildRaidBuffs()
render(display)
hidden[1] = canonical
eventFrame.scripts.OnEvent(eventFrame, "HIDDEN_GROUP_BUFFS_CHANGED")
assert(#MRB:BuildMatches("party1", element, {}) == 0,
    "hidden group buffs must match the canonical saved key rather than the display rank")
hidden[1] = nil
items[1].isKnown = false
MRB:RebuildRaidBuffs()
assert(#MRB:BuildMatches("party1", element, {}) == 0, "unknown native group buffs must remain excluded")
items = {}
MRB:RebuildRaidBuffs()
assert(#MRB.RaidBuffs == 6 and MRB.RaidBuffs[1].iconSpellID == 1459,
    "native group-buff rebuilds must retain the built-in raid-buff catalog")
print("OK: canonical group-buff identity survives display-rank changes and hidden-list updates")
