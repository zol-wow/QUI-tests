-- Run: lua tests/unit/cdm_icons_usability_cooldown_transition_test.lua
-- Exercise the renderer and range policy across cooldown/GCD event ordering.
-- luacheck: globals InCombatLockdown GetTime wipe CreateFrame C_Timer

local function noop() end
local inCombat = false
function InCombatLockdown() return inCombat end
function GetTime() return 100 end
function wipe(tbl)
    for key in pairs(tbl) do tbl[key] = nil end
end
function CreateFrame()
    return {
        RegisterEvent = noop,
        RegisterUnitEvent = noop,
        UnregisterAllEvents = noop,
        SetScript = noop,
        Show = noop,
        Hide = noop,
    }
end
C_Timer = {
    After = function(_, callback) callback() end,
    NewTimer = function() return { Cancel = noop } end,
}

local settings = {
    iconDisplayMode = "always",
    desaturateOnCooldown = true,
    usabilityIndicator = true,
}
local ncdm = { essential = settings, containers = {} }
local phase = "idle"
local usable = false
local duration = {}
local ns = {
    Helpers = {
        GetGeneralFont = function() return "Fonts\\FRIZQT__.TTF" end,
        GetGeneralFontOutline = function() return "" end,
        CreateDBGetter = function() return function() return ncdm end end,
        IsSecretValue = function() return false end,
        SafeValue = function(value) return value end,
        SafeToNumber = function(value) return value end,
        CanAccessTable = function(value) return type(value) == "table" end,
        IsEditModeActive = function() return false end,
        IsLayoutModeActive = function() return false end,
    },
    Addon = { db = { profile = { ncdm = ncdm }, char = { ncdm = {} } } },
    CDMShared = {
        IsRuntimeEnabled = function() return true end,
        IsSafeNumeric = function(value) return type(value) == "number" end,
    },
    CDMSources = {
        QuerySpellUsable = function(spellID) return usable, not usable and spellID == 10002 end,
        QuerySpellCooldown = function()
            return { isActive = phase ~= "idle", isOnGCD = phase == "gcd" }
        end,
        QuerySpellCooldownDuration = function()
            if phase ~= "idle" then return duration end
        end,
    },
    CDMIconFactory = {
        _iconPools = { essential = {} },
        _recyclePool = {},
        _FinalizeImports = noop,
        AcquireIcon = noop,
        ReleaseIcon = noop,
        SyncCooldownBling = noop,
    },
    _OwnedSwipe = {
        ApplyToIcon = noop,
        GetSettings = function()
            return { showGCDSwipe = true, showCooldownSwipe = true }
        end,
    },
}

dofile("tests/helpers/load_cdm_icon_runtime.lua")(ns)
assert(loadfile("QUI_CDM/cdm/cdm_resolvers.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_runtime_store.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_icon_renderer.lua"))("QUI", ns)

local function makeIcon(spellID)
    local icon = {
        _spellEntry = {
            id = spellID, spellID = spellID, name = tostring(spellID),
            kind = "cooldown", viewerType = "essential", type = "spell",
        },
        Cooldown = {
            Clear = noop,
            SetReverse = noop,
            SetCooldownFromDurationObject = noop,
            Show = noop,
        },
        Icon = {
            SetAlpha = noop,
            SetTexture = noop,
            SetDesaturated = function(self, value) self.desaturated = value end,
            SetVertexColor = function(self, r, g, b) self.color = { r, g, b } end,
        },
        Border = { SetAlpha = noop },
        DurationText = { SetAlpha = noop },
        StackText = { SetAlpha = noop },
        IsShown = function() return true end,
        Show = noop,
        Hide = noop,
        SetAlpha = noop,
    }
    return icon
end

local icons = ns.CDMIcons
local function assertDimmed(icon, message)
    assert(icon.Icon.color and icon.Icon.color[1] == 0.4, message)
end

for _, combat in ipairs({ false, true }) do
    inCombat = combat
    phase = "idle"
    usable = false
    local first, second = makeIcon(10001), makeIcon(10002)
    ns.CDMIconFactory._iconPools.essential = { first, second }
    icons:UpdateCooldownOnly(true, true)
    icons:UpdateAllIconRanges()
    assertDimmed(first, "resource-starved spell should initially be dimmed")
    assertDimmed(second, "second resource-starved spell should initially be dimmed")

    -- An ordinary refresh can see the GCD before SPELL_UPDATE_COOLDOWN supplies
    -- the trusted isOnGCD field. The resolver initially returns cooldown mode.
    phase = "gcd"
    icons:UpdateCooldownOnly(false, true)
    assert(first._resolvedCooldownMode == "cooldown", "exercise the untrusted GCD refresh")
    icons:UpdateAllIconRanges()
    assert(first.Icon.color[1] == 1 and first._usabilityTinted == nil,
        "cooldown styling should still suppress the usability tint")

    -- The trusted refresh releases cooldown desaturation. Usability has never
    -- changed and its next event may still be waiting in the combat queue.
    icons:UpdateCooldownOnly(true, true)
    assert(first._resolvedCooldownMode == "gcd-only", "trusted refresh must classify the GCD")
    assert(first.Icon.desaturated == false, "GCD must release cooldown desaturation")
    assertDimmed(first, "GCD transition must not brighten a resource-starved spell before the usability event")
    assertDimmed(second, "GCD transition must preserve the second spell's unusable tint")

    phase = "idle"
    icons:UpdateCooldownOnly(true, true)
    assertDimmed(first, "GCD expiry must preserve the unusable tint")

    usable = true
    icons:UpdateAllIconRanges()
    assert(first.Icon.color[1] == 1, "a spell should brighten when it actually becomes usable")

    phase = "cooldown"
    icons:UpdateCooldownOnly(true, true)
    usable = false
    icons:UpdateAllIconRanges()
    assert(first._usabilityTinted == nil, "real cooldown styling should keep priority")
    phase = "idle"
    icons:UpdateCooldownOnly(true, true)
    assertDimmed(first, "usability changes during a real cooldown must take effect when it ends")

    -- A ready event received during cooldown must also replace the remembered
    -- unusable state, so ending the cooldown does not restore a stale tint.
    phase = "cooldown"
    icons:UpdateCooldownOnly(true, true)
    usable = true
    icons:UpdateAllIconRanges()
    phase = "idle"
    icons:UpdateCooldownOnly(true, true)
    assert(first.Icon.color[1] == 1, "cooldown expiry must respect readiness learned during cooldown")

    usable = false
    icons:UpdateAllIconRanges()
    phase = "cooldown"
    icons:UpdateCooldownOnly(true, true)
    settings.usabilityIndicator = false
    icons:UpdateAllIconRanges()
    phase = "idle"
    icons:UpdateCooldownOnly(true, true)
    assert(first.Icon.color[1] == 1 and first._lastVisualState == nil,
        "disabling usability during cooldown must discard the remembered tint")
    settings.usabilityIndicator = true
end

print("OK: cdm_icons_usability_cooldown_transition_test")
