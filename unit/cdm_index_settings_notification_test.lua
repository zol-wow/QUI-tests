local pending, callbacks, hooked = {}, {}, {}
local ns = {}

function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end }
end
function hooksecurefunc(object, method)
    hooked[#hooked + 1] = { object, method }
end
function wipe(t)
    for k in pairs(t) do t[k] = nil end
end
function issecretvalue() return false end

C_Timer = { After = function(_, callback) pending[#pending + 1] = callback end }
EventRegistry = { RegisterCallback = function(_, event, callback, owner)
    callbacks[event] = { callback, owner }
end }
Enum = { CooldownViewerCategory = {
    Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3,
} }
C_CooldownViewer = {
    GetCooldownViewerCooldownInfo = function() return { spellID = 111 } end,
}
local provider = { displayDataDirty = false, displayData = {
    orderedCooldownIDs = { 88 }, cooldownInfoByID = { [88] = { category = 0 } },
} }
local refreshes = 0
CooldownViewerSettings = {
    GetDataProvider = function() return provider end,
    RefreshLayout = function()
        refreshes = refreshes + 1
        provider.displayDataDirty = false
        provider.displayData = {
            orderedCooldownIDs = { 99 },
            cooldownInfoByID = { [99] = { category = 0 } },
        }
    end,
}
local nativeRefresh = CooldownViewerSettings.RefreshLayout

assert(loadfile("QUI_CDM/cdm/cdm_index.lua"))("QUI_CDM", ns)
assert(#hooked == 0, "index observation must not hook Blizzard settings refresh")
assert(CooldownViewerSettings.RefreshLayout == nativeRefresh,
    "native settings refresh must retain its original identity")
assert(ns.CDMIndex.GetOrdered(111).cooldownID == 88)

local observed = {}
ns.CDMIndex.Subscribe("test", function(reason)
    assert(reason == "refresh_layout", "existing subscriber reason must be preserved")
    observed[#observed + 1] = ns.CDMIndex.GetOrdered(111).cooldownID
end)
local event = assert(callbacks["CooldownViewerSettings.OnDataChanged"],
    "native data changes must invalidate the QUI index without a method hook")
assert(event[2] ~= CooldownViewerSettings, "QUI must own its callback separately")

provider.displayDataDirty = true
event[1](event[2])
event[1](event[2])
assert(#observed == 0 and refreshes == 0,
    "QUI subscribers must wait for native callbacks and must not trigger native refresh")
assert(#pending == 1, "one native change burst should schedule one index notification")
nativeRefresh()
table.remove(pending, 1)()
assert(#observed == 1 and observed[1] == 99,
    "subscribers must observe the rebuilt native spell order, not the previous snapshot")

event[1](event[2])
assert(#pending == 1, "later data changes must still notify after a completed refresh")
table.remove(pending, 1)()
assert(#observed == 2 and refreshes == 1)
print("OK: cdm_index_settings_notification_test")
