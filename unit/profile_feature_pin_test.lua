local env = dofile("tools/_addon_env.lua")

local h = env.LoadHarness({
    QUI_DB = {
        profileKeys = { ["TestChar - TestRealm"] = "Target" },
        profiles = {
            Target = {
                auraDisplays = { displays = { { id = "target" } } },
                quiGroupFrames = {
                    party = { general = { fontSize = 10 } },
                    clickCast = { keep = true },
                },
                frameAnchoring = {
                    auraDisplay_target = { offsetX = 1 },
                    partyFrames = { offsetX = 2 },
                    unrelated = { offsetX = 3 },
                },
            },
            Source = {
                auraDisplays = { displays = { { id = "source" } } },
                quiGroupFrames = { party = { general = { fontSize = 31 } } },
                raidBuffs = { iconSize = 44 },
                frameAnchoring = {
                    auraDisplay_source = { offsetX = 11 },
                    partyFrames = { offsetX = 12 },
                    raidFrames = { offsetX = 13 },
                },
            },
            Other = {
                auraDisplays = { displays = { { id = "other" } } },
            },
        },
    },
}, { noSeed = true })

local core = h.QUICore
local pins = h.ns.Settings.Pins
local source = h.db.profiles.Source
local activeSpecID = 105
h.ns.Helpers.GetCurrentSpecID = function() return activeSpecID end

assert(pins:IsPathPinnable("auraDisplays.displays.1.visibility", "dropdown", "always") == false)
assert(pins:IsPathPinnable("auraDisplays.displays.1.layout.spacing", "slider", 2) == false)
assert(pins:IsPathPinnable("auraDisplays.enabled", "checkbox", true) == true)

local legacyStore = h.db.global.profileFeaturePins
legacyStore.profiles.Target = { auraDisplays = "Source", groupFrames = "Source" }
assert(h.db.global.profileFeaturePins.profiles.Target.auraDisplays == "Source")
assert(h.db.global.profileFeaturePins.profiles.Target.groupFrames == "Source")
assert(h.db.global.profileFeaturePins.profiles.Other == nil)

local pinnedAuraOK, pinnedAuraError = core:CopyProfileSelection("Other", { "auraDisplays" })
assert(pinnedAuraOK == false and pinnedAuraError:find("Unpin", 1, true))
local pinnedPartyOK, pinnedPartyError = core:CopyProfileSelection("Other", { "groupFramesParty" })
assert(pinnedPartyOK == false and pinnedPartyError:find("Unpin", 1, true))

source.auraDisplays.displays[1].id = "source-updated"
source.frameAnchoring.auraDisplay_source.offsetX = 21
source.quiGroupFrames.party.general.fontSize = 41
source.frameAnchoring.partyFrames.offsetX = 22
h.db.profile.auraDisplays.displays[1].id = "local-edit"
h.db.profile.quiGroupFrames.party.general.fontSize = 9
h.db.profile.quiGroupFrames.clickCast.keep = "preserved"

assert(pins:ApplyProfileFeaturePins(h.db) == true)
assert(h.db.profile.auraDisplays.displays[1].id == "source-updated")
assert(h.db.profile.frameAnchoring.auraDisplay_target == nil)
assert(h.db.profile.frameAnchoring.auraDisplay_source.offsetX == 21)
assert(h.db.profile.quiGroupFrames.party.general.fontSize == 41)
assert(h.db.profile.quiGroupFrames.party.general.font == "Quazii")
assert(h.db.profile.quiGroupFrames.clickCast.keep == "preserved")
assert(h.db.profile.frameAnchoring.partyFrames.offsetX == 22)
assert(h.db.profile.frameAnchoring.unrelated.offsetX == 3)
h.db.profile.auraDisplays.displays[1].id = "isolated"
assert(source.auraDisplays.displays[1].id == "source-updated")

local unpinOK, unpinError = core:UnpinProfileSelection("auraDisplays")
assert(unpinOK == true, tostring(unpinError))
assert(source.auraDisplays.displays[1].id == "isolated")
source.auraDisplays.displays[1].id = "after-unpin"
assert(pins:ApplyProfileFeaturePins(h.db) == true)
assert(h.db.profile.auraDisplays.displays[1].id == "isolated")
assert(core:GetProfileFeatureSource("auraDisplays") == nil)

source.quiGroupFrames.clickCast = { source = true }
h.db.profile.quiGroupFrames.party.general.fontSize = 52
h.db.profile.quiGroupFrames.clickCast.keep = "target-only"
h.db.profile.frameAnchoring.partyFrames.offsetX = 32

local postInitialize
h.ns.Addon.RegisterPostInitialize = function(_, callback)
    postInitialize = callback
end
env.LoadAddonFile("core/settings/pins_lifecycle.lua", "QUI", h.ns)
assert(type(postInitialize) == "function")
postInitialize(core)
h.db:SetProfile("Other")
assert(source.quiGroupFrames.party.general.fontSize == 52)
assert(source.quiGroupFrames.clickCast.source == true)
assert(source.quiGroupFrames.clickCast.keep == nil)
assert(source.frameAnchoring.partyFrames.offsetX == 32)

legacyStore.profiles.Other = { groupFrames = "Source" }
assert(pins:ApplyProfileFeaturePins(h.db) == true)
assert(h.db.profile.quiGroupFrames.party.general.fontSize == 52)
assert(h.db.profile.frameAnchoring.partyFrames.offsetX == 32)

local unsupportedOK, unsupportedError = core:PinCurrentProfileSelection("theme")
assert(unsupportedOK == false and unsupportedError:find("Only Aura", 1, true))

pins:DropProfile("Source", h.db)
assert(core:GetProfileFeatureSource("groupFrames") == nil)

h.db.profile.auraDisplays = {
    displays = { {
        id = "global-source",
        auras = {
            elements = {
                ["*"] = { { iconSize = 14 } },
                [105] = { {
                    iconSize = 80,
                    spacing = 6,
                    rowSpacing = 7,
                    durationText = { size = 18 },
                    stackText = { size = 19 },
                } },
            },
        },
    } },
}
h.db.profile.quiGroupFrames = {
    party = {
        targetedSpells = { iconSize = 48 },
        auras = { elements = { ["*"] = { { iconSize = 12 } }, [105] = { { iconSize = 52 } } } },
    },
    raid = {
        targetedSpells = { iconSize = 49 },
        auras = { elements = { ["*"] = { { iconSize = 13 } }, [105] = { { iconSize = 53 } } } },
    },
}

local globalAuraOK, globalAuraError = core:PinCurrentProfileSelection("auraDisplays")
assert(globalAuraOK == true, tostring(globalAuraError))
local globalGroupOK, globalGroupError = core:PinCurrentProfileSelection("groupFrames")
assert(globalGroupOK == true, tostring(globalGroupError))
local globalStore = h.db.global.profileFeaturePins.sources
assert(globalStore.auraDisplays.profile == "Other" and globalStore.auraDisplays.specID == 105)
assert(globalStore.groupFrames.profile == "Other" and globalStore.groupFrames.specID == 105)
assert(h.db.global.profileFeaturePins.profiles.Target == nil)

activeSpecID = 104
h.db:SetProfile("Target")
assert(pins:ApplyProfileFeaturePins(h.db) == true)
local targetAura = h.db.profile.auraDisplays.displays[1].auras.elements[104][1]
assert(targetAura.iconSize == 80 and targetAura.spacing == 6 and targetAura.rowSpacing == 7,
    "global Aura pin did not map the source spec's icon layout sizes")
assert(targetAura.durationText.size == 18 and targetAura.stackText.size == 19,
    "global Aura pin did not map the source spec's text sizes")
assert(h.db.profile.quiGroupFrames.party.targetedSpells.iconSize == 48)
assert(h.db.profile.quiGroupFrames.raid.targetedSpells.iconSize == 49)
assert(h.db.profile.quiGroupFrames.party.auras.elements[104][1].iconSize == 52)
assert(h.db.profile.quiGroupFrames.raid.auras.elements[104][1].iconSize == 53)

h.db.profile.auraDisplays.displays[1].auras.elements[104][1].iconSize = 91
assert(pins:SyncProfileFeatureSources(h.db, "auraDisplays") == true)
assert(h.db.profiles.Other.auraDisplays.displays[1].auras.elements[105][1].iconSize == 91,
    "global Aura edits did not sync back to the pinned source spec")

activeSpecID = 105
h.db:SetProfile("Other")
assert(pins:ApplyProfileFeaturePins(h.db) == false, "global source profile must not overwrite itself")
local globalUnpinOK, globalUnpinError = core:UnpinProfileSelection("auraDisplays")
assert(globalUnpinOK == true, tostring(globalUnpinError))
assert(core:GetProfileFeatureSource("auraDisplays") == nil)
pins:DropProfile("Other", h.db)
assert(core:GetProfileFeatureSource("groupFrames") == nil)

local mainFile = assert(io.open("core/main.lua", "rb"))
local mainSource = mainFile:read("*a")
mainFile:close()
local initStart = assert(mainSource:find("function QUICore:OnInitialize()", 1, true))
local dualSpec = assert(mainSource:find("LibDualSpec:EnhanceDatabase", initStart, true))
local initApply = assert(mainSource:find("pins:ApplyProfileFeaturePins(self.db)", dualSpec, true))
assert(dualSpec < initApply)
local changeStart = assert(mainSource:find("function QUICore:OnProfileChanged", 1, true))
local runLate = assert(mainSource:find("ns.Migrations.RunLate(self.db)", changeStart, true))
local changeApply = assert(mainSource:find("pins:ApplyProfileFeaturePins(self.db)", runLate, true))
local cleanup = assert(mainSource:find("if self.CleanupFontRegistry then", changeApply, true))
assert(runLate < changeApply and changeApply < cleanup)

local lifecycleFile = assert(io.open("core/settings/pins_lifecycle.lua", "rb"))
local lifecycleSource = lifecycleFile:read("*a")
lifecycleFile:close()
assert(lifecycleSource:find('db.RegisterCallback(Lifecycle, "OnProfileShutdown", "SyncProfileFeatures")', 1, true))
assert(lifecycleSource:find('db.RegisterCallback(Lifecycle, "OnDatabaseShutdown", "SyncProfileFeatures")', 1, true))

local profileIOFile = assert(io.open("core/profile_io.lua", "rb"))
local profileIOSource = profileIOFile:read("*a")
profileIOFile:close()
local fullApply = assert(profileIOSource:find("local function ApplyFullProfilePayload", 1, true))
local fullSync = assert(profileIOSource:find("SettingsPins:SyncProfileFeatureSources(core.db)", fullApply, true))
local fullWipe = assert(profileIOSource:find("for key in pairs(profile) do", fullSync, true))
assert(fullSync < fullWipe)
local selectiveApply = assert(profileIOSource:find("local function RunImportProfileSelection", 1, true))
local selectiveSync = assert(profileIOSource:find("SettingsPins:SyncProfileFeatureSources(core.db)", selectiveApply, true))
local selectiveCopy = assert(profileIOSource:find("local previousProfile = CloneValue(profile)", selectiveSync, true))
assert(selectiveSync < selectiveCopy)

local profilesFile = assert(io.open("core/settings/content/profiles_content.lua", "rb"))
local profilesSource = profilesFile:read("*a")
profilesFile:close()
local resetStart = assert(profilesSource:find("local resetProfileCell", 1, true))
local resetSync = assert(profilesSource:find("core:SyncProfileFeatureSources()", resetStart, true))
local resetCall = assert(profilesSource:find("dbRef:ResetProfile()", resetSync, true))
assert(resetSync < resetCall)
local copyStart = assert(profilesSource:find("local copyDropdown", resetCall, true))
local copySync = assert(profilesSource:find("core:SyncProfileFeatureSources()", copyStart, true))
local copyCall = assert(profilesSource:find("dbRef:CopyProfile(value)", copySync, true))
assert(copySync < copyCall)

print("ok profile feature pin")
