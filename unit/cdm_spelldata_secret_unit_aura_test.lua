local SecretSentinel = dofile("tests/helpers/secret_sentinel.lua")
local restoreIsSecretValue = SecretSentinel.InstallSecretStub()
function InCombatLockdown() return false end
function wipe(tbl)
    for key in pairs(tbl) do tbl[key] = nil end
end
C_Timer = { After = function() end }
local frame
function CreateFrame()
    frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:RegisterUnitEvent(event) self.events[event] = true end
    function frame:SetScript(_, handler) self.script = handler end
    return frame
end
local notified = {}
local ns = {
    Helpers = {},
    CDMShared = { IsRuntimeEnabled = function() return true end },
    CDMSources = {},
    CDMIcons = { HandleRuntimeRefresh = function(event, unit, payload)
        assert(event == "UNIT_AURA" and payload == nil)
        notified[#notified + 1] = unit
    end },
}
dofile("tests/helpers/load_cdm_spelldata_runtime.lua")(ns)
assert(SecretSentinel.LoadInstrumented("QUI_CDM/cdm/cdm_spelldata.lua"))("QUI", ns)
ns.CDMSpellData:Initialize()
frame.script(frame, "UNIT_AURA", SecretSentinel.MakeSecretSentinel(), SecretSentinel.MakeSecretSentinel())
assert(#notified == 3 and notified[1] == "player" and notified[2] == "pet" and notified[3] == "target",
    "secret unit must invalidate all registered units without inspecting the payload")
for _, unit in ipairs({ "player", "pet", "target" }) do
    notified = {}
    frame.script(frame, "UNIT_AURA", unit, SecretSentinel.MakeSecretSentinel())
    assert(#notified == 1 and notified[1] == unit)
    frame.script(frame, "UNIT_AURA", unit, {
        isFullUpdate = SecretSentinel.MakeSecretSentinel(),
        addedAuras = SecretSentinel.MakeSecretSentinel(),
        removedAuraInstanceIDs = SecretSentinel.MakeSecretSentinel(),
    })
    assert(#notified == 2 and notified[2] == unit)
end
_G.issecretvalue = restoreIsSecretValue
print("OK: cdm_spelldata_secret_unit_aura_test")
