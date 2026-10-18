local Harness = dofile("tests/helpers/character_chrome_harness.lua")

local function Build(shown, enabled, combat)
    local env = Harness.Build()
    _G.InCombatLockdown = function() return combat == true end
    assert(loadfile("core/uikit.lua"))("QUI", env.ns)
    env.SkinBase = env.ns.SkinBase
    env.profile.general.skinEncounterJournal = enabled
    local frame = env.NewFrame("Frame")
    frame:SetShown(shown)
    _G.EncounterJournal = frame
    local callbacks = {}
    env.SkinBase.OnAddOnLoaded = function(addon, callback) callbacks[addon] = callback end
    local chromeCount = 0
    local skinChrome = env.SkinBase.SkinButtonFrameTemplate
    env.SkinBase.SkinButtonFrameTemplate = function(target)
        if target == frame then chromeCount = chromeCount + 1 end
        return skinChrome(target)
    end
    local nativeLootUpdate = function() end
    _G.EncounterJournal_LootUpdate = nativeLootUpdate
    assert(loadfile(os.getenv("QUI_JOURNALS_SOURCE") or "modules/skinning/frames/journals.lua"))("QUI", env.ns)
    return env, frame, callbacks.Blizzard_EncounterJournal,
        function() return chromeCount end, nativeLootUpdate
end

local env, frame, loaded, count, nativeLootUpdate = Build(false, true, true)
loaded()
loaded()
_G.QUI_RefreshEncounterJournalColors()
assert(count() == 0 and not env.SkinBase.IsSkinned(frame),
    "loading or refreshing a hidden journal must not initialize its skin")
assert(_G.EncounterJournal_LootUpdate == nativeLootUpdate,
    "hidden journal must not install expensive content update hooks")
assert(#frame.hooks.OnShow == 1, "repeated load and refresh must share one pending show hook")
frame:Show()
assert(count() == 1 and env.SkinBase.IsSkinned(frame), "first opening in combat must initialize the journal skin")
assert(_G.EncounterJournal_LootUpdate ~= nativeLootUpdate, "first opening must install native content hooks")
env.RunTimers()
local hooks = #frame.hooks.OnShow
frame:Hide()
frame:Show()
loaded()
_G.QUI_RefreshEncounterJournalColors()
assert(count() == 1 and #frame.hooks.OnShow == hooks, "later openings must preserve one skin initialization")

env, frame, loaded, count = Build(true, true, true)
loaded()
assert(count() == 1 and env.SkinBase.IsSkinned(frame), "already-visible journal must initialize during a combat reload")

env, frame, loaded, count = Build(false, false)
loaded()
_G.QUI_RefreshEncounterJournalColors()
frame:Show()
assert(count() == 0 and not frame.hooks.OnShow, "disabled journal skin must leave native loading untouched")

env, frame, loaded, count = Build(false, true, true)
loaded()
env.profile.general.skinEncounterJournal = false
frame:Show()
assert(count() == 0, "a disabled pending skin must not initialize on first show")
env.profile.general.skinEncounterJournal = true
_G.QUI_RefreshEncounterJournalColors()
assert(count() == 1, "reenabling a visible journal through refresh must initialize its skin")

print("OK: encounter_journal_startup_test")
