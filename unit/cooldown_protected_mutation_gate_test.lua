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
        Clear = function(self) self.clearCount = (self.clearCount or 0) + 1 end,
        SetCooldownFromDurationObject = function(self)
            self.setCount = (self.setCount or 0) + 1
        end,
        SetCooldown = function(self)
            self.setCount = (self.setCount or 0) + 1
        end,
        SetCooldownFromExpirationTime = function(self)
            self.setCount = (self.setCount or 0) + 1
        end,
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

assert(Helpers.ClearCooldown(allowed) == true and allowed.clearCount == 1,
    "an allowed cooldown must clear")
assert(Helpers.ClearCooldown(blocked) == false and blocked.clearCount == nil,
    "a protected combat cooldown must not clear")
assert(Helpers.ApplyCooldownFromStart(blocked, {}, 1, 2) == false and blocked.setCount == nil,
    "a protected combat cooldown must reject duration-object writes")
assert(Helpers.ApplyCooldownFromAura(blocked, "raid1", 1, 3, 2) == false and blocked.setCount == nil,
    "a protected combat cooldown must reject aura cooldown writes")
assert(Helpers.ApplyCooldownFromStart(allowed, {}, 1, 2) == true and allowed.setCount == 1,
    "an unprotected combat cooldown must still accept writes")

inCombat = false
assert(Helpers.ClearCooldown(blocked) == true and blocked.clearCount == 1,
    "a deferred cooldown must clear after combat")

print("OK: cooldown_protected_mutation_gate_test")
