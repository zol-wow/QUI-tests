local profile = {}
local additions = {}
local removals = {}
local nextRegistrationID = 0

Enum = {
    UnitAuraSoundTrigger = {
        Added = 0,
        ApplicationsIncreased = 1,
        Removed = 2,
    },
}
C_Secrets = { ShouldAurasBeSecret = function() return false end }
InCombatLockdown = function() return false end
C_UnitAuras = {
    AddAuraSound = function(trigger, info)
        nextRegistrationID = nextRegistrationID + 1
        additions[#additions + 1] = { trigger = trigger, info = info, id = nextRegistrationID }
        return nextRegistrationID
    end,
    RemoveAuraSound = function(id)
        removals[#removals + 1] = id
    end,
}

local ns = {
    SafeCall = function(_, fn, ...)
        return pcall(fn, ...)
    end,
    Helpers = {
        GetProfile = function() return profile end,
        GetCurrentSpecID = function() return 105 end,
        GetModuleSettings = function(name, defaults)
            if not profile[name] then
                profile[name] = {}
                for key, value in pairs(defaults or {}) do profile[name][key] = value end
            end
            return profile[name]
        end,
    },
    LSM = {
        Fetch = function(_, mediaType, name)
            if mediaType == "sound" and name == "Test Sound" then return "Sounds/Test.ogg" end
        end,
    },
}

assert(loadfile("core/aura_elements.lua"))("QUI", ns)
assert(loadfile("modules/trackers/aura_displays.lua"))("QUI", ns)

local AD = ns.QUI_AuraDisplays
local element = ns.AuraElements.NewTrackedElement({ 12345 }, "icon")
element.auraSounds = {
    [12345] = {
        added = "Test Sound",
        applicationsIncreased = "Test Sound",
        removed = "Test Sound",
    },
}
local display = AD.NewDisplay("Alerts")
display.auras = { enabled = true, elements = { ["*"] = { element } } }

AD._ReconcileAuraSounds(AD.Store())
assert(#additions == 3, "three configured native aura sounds should register")
assert(additions[1].info.unitToken == "player", "registration should use the display's fixed unit")
assert(additions[1].info.spellID == 12345, "registration should use the tracked aura spell")
assert(additions[1].info.soundFileName == "Sounds/Test.ogg", "registration should resolve LSM media")

AD._ReconcileAuraSounds(AD.Store())
assert(#additions == 3 and #removals == 0, "unchanged registrations should be reused")

element.auraSounds[12345].removed = "Sound/Interface/RaidWarning.ogg"
AD._ReconcileAuraSounds(AD.Store())
assert(#additions == 4 and #removals == 1, "changing one sound should replace only its registration")

element.onlyMineSpells = { [12345] = true }
AD._ReconcileAuraSounds(AD.Store())
assert(#removals == 4, "caster-filtered entries should remove unsupported native registrations")

element.onlyMineSpells = nil
display.unitMode = "name"
AD._ReconcileAuraSounds(AD.Store())
assert(#additions == 4, "dynamic unit displays should not register native aura sounds")

display.unitMode = "token"
display.auras.enabled = false
AD._ReconcileAuraSounds(AD.Store())
assert(#additions == 4, "disabled aura stores should not register native aura sounds")

print("OK: aura_displays_sound_reconcile_test")
