local SECRET = {}
local inCombat = false

function LibStub() return nil end
function InCombatLockdown() return inCombat end
function issecretvalue(value) return value == SECRET end

local ns = {
    SafeCallMethod = function(_, object, method, ...)
        return pcall(object[method], object, ...)
    end,
}
assert(loadfile("core/utils.lua"))("QUI", ns)

local Helpers = assert(ns.Helpers)
local function cooldown(canChange)
    return {
        CanChangeProtectedState = function() return canChange end,
    }
end

local blocked = cooldown(false)
assert(Helpers.CanMutateCooldown(nil) == false)
assert(Helpers.CanMutateCooldown(blocked) == true,
    "protected cooldown state remains mutable out of combat")

inCombat = true
local allowed = cooldown(true)
assert(Helpers.CanMutateCooldown(allowed) == true,
    "an unprotected cooldown must remain mutable during combat")
assert(Helpers.CanMutateCooldown(blocked) == false,
    "a protected cooldown must be blocked during combat")
assert(Helpers.CanMutateCooldown(cooldown(SECRET)) == false,
    "a secret protected-state result must fail closed")

local throwing = cooldown(true)
throwing.CanChangeProtectedState = function() error("unreadable") end
assert(Helpers.CanMutateCooldown(throwing) == false,
    "a throwing protected-state probe must fail closed")

local legacyAllowed = {
    IsProtected = function() return false end,
    IsAnchoringRestricted = function() return true end,
}
local legacyBlocked = { IsProtected = function() return true end }
assert(Helpers.CanMutateCooldown(legacyAllowed) == true,
    "anchoring-only restrictions must not block cooldown state")
assert(Helpers.CanMutateCooldown(legacyBlocked) == false,
    "the IsProtected fallback must block protected cooldowns")

print("OK: cooldown_protected_mutation_gate_test")
