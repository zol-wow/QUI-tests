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

local auraOK, auraError = core:PinProfileSelection("Source", "auraDisplays")
assert(auraOK == true, tostring(auraError))
local groupOK, groupError = core:PinProfileSelection("Source", "groupFrames")
assert(groupOK == true, tostring(groupError))
local legacyStore = h.db.global.profileFeaturePins
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

targetAura.iconSize = 82
local optOutOK, optOutError = core:SetProfileFeaturePinOptOut("auraDisplays", true)
assert(optOutOK == true, tostring(optOutError))
assert(h.db.profiles.Other.auraDisplays.displays[1].auras.elements[105][1].iconSize == 82,
    "opting out must sync the last pinned edit into the global source")
assert(core:IsProfileFeaturePinOptedOut("auraDisplays") == true)
assert(core:GetProfileFeatureSource("auraDisplays") == "Other",
    "configured source lookup must remain backward-compatible while opted out")
assert(pins:GetEffectiveProfileFeatureSource("auraDisplays", h.db) == nil)
h.db.profile.auraDisplays.displays[1].auras.elements[104][1].iconSize = 96
assert(pins:SyncProfileFeatureSources(h.db, "auraDisplays") == false)
assert(h.db.profiles.Other.auraDisplays.displays[1].auras.elements[105][1].iconSize == 82,
    "opted-out profile edits must not sync into the global source")
assert(pins:ApplyProfileFeaturePins(h.db, { "auraDisplays" }) == false)
assert(h.db.profile.auraDisplays.displays[1].auras.elements[104][1].iconSize == 96,
    "global apply must not overwrite an opted-out profile")
local rejoinOK, rejoinError = core:SetProfileFeaturePinOptOut("auraDisplays", false)
assert(rejoinOK == true, tostring(rejoinError))
assert(core:IsProfileFeaturePinOptedOut("auraDisplays") == false)
assert(h.db.profile.auraDisplays.displays[1].auras.elements[104][1].iconSize == 82,
    "rejoining must apply the pinned source bucket")

h.db.profile.auraDisplays.displays[1].auras.elements[104][1].iconSize = 91
local refreshedCategories
h.ns.Registry = {
    RefreshByCategories = function(_, categories)
        refreshedCategories = categories
    end,
}
activeSpecID = 103
assert(pins:HandleProfileFeatureSpecChanged(h.db) == true)
assert(h.db.profiles.Other.auraDisplays.displays[1].auras.elements[105][1].iconSize == 91,
    "spec change did not sync the previous active bucket back to the source spec")
assert(h.db.profile.auraDisplays.displays[1].auras.elements[103][1].iconSize == 91,
    "spec change did not apply the pinned source bucket to the new active spec")
assert(refreshedCategories[1] == "groupFrames" and refreshedCategories[2] == "auraDisplays",
    "spec change did not refresh the globally pinned features")

h.db:SetProfile("Other")
h.db.profile.auraDisplays.displays[1].auras.elements[103] = nil
assert(pins:ApplyProfileFeaturePins(h.db) == true)
assert(h.db.profile.auraDisplays.displays[1].auras.elements[103][1].iconSize == 91,
    "source profile load did not map the canonical bucket into the active spec")
h.db.profile.auraDisplays.displays[1].auras.elements[103][1].iconSize = 92
activeSpecID = 104
assert(pins:HandleProfileFeatureSpecChanged(h.db) == true)
assert(h.db.profile.auraDisplays.displays[1].auras.elements[105][1].iconSize == 92,
    "source profile spec change did not sync edits into the canonical source bucket")
assert(h.db.profile.auraDisplays.displays[1].auras.elements[104][1].iconSize == 92,
    "source profile spec change did not map the canonical bucket into the new spec")
h.db.profile.auraDisplays.displays[1].auras.elements[104][1].iconSize = 93
assert(pins:SyncProfileFeatureSources(h.db, "auraDisplays") == true)
assert(h.db.profile.auraDisplays.displays[1].auras.elements[105][1].iconSize == 93,
    "source profile shutdown sync did not preserve edits from the active mapped spec")

local sourceOptOutOK, sourceOptOutError = core:SetProfileFeaturePinOptOut("auraDisplays", true)
assert(sourceOptOutOK == false and sourceOptOutError:find("source profile", 1, true),
    "the global source must not be allowed to ignore its own pin")

activeSpecID = 104
h.db:SetProfile("Target")
assert(pins:ApplyProfileFeaturePins(h.db) == true)
assert(core:SetProfileFeaturePinOptOut("auraDisplays", true) == true)
assert(core:SetProfileFeaturePinOptOut("groupFrames", true) == true)
h.db.profile.auraDisplays.displays[1].auras.elements[103] = { { iconSize = 123 } }
h.db.profile.quiGroupFrames.party.auras.elements[103] = { { iconSize = 124 } }
activeSpecID = 103
refreshedCategories = nil
assert(pins:HandleProfileFeatureSpecChanged(h.db) == false,
    "spec changes must skip categories opted out by the active profile")
assert(h.db.profile.auraDisplays.displays[1].auras.elements[103][1].iconSize == 123)
assert(h.db.profile.quiGroupFrames.party.auras.elements[103][1].iconSize == 124)
assert(refreshedCategories == nil, "opted-out categories must not be refreshed on spec change")
local independentCopyOK, independentCopyError = core:CopyProfileSelection("Other", { "auraDisplays" })
assert(independentCopyOK == true, tostring(independentCopyError))
assert(core:SetProfileFeaturePinOptOut("auraDisplays", false) == true)
assert(core:SetProfileFeaturePinOptOut("groupFrames", false) == true)
assert(h.db.profile.auraDisplays.displays[1].auras.elements[103][1].iconSize == 93,
    "rejoining after an independent copy must restore the global Aura settings")
assert(h.db.profile.quiGroupFrames.party.auras.elements[103][1].iconSize == 52,
    "rejoining must restore the global Group Frame settings")

assert(core:SetProfileFeaturePinOptOut("auraDisplays", true) == true)
local globalUnpinOK, globalUnpinError = core:UnpinProfileSelection("auraDisplays")
assert(globalUnpinOK == true, tostring(globalUnpinError))
assert(core:GetProfileFeatureSource("auraDisplays") == nil)
assert(h.db.global.profileFeaturePins.optOuts.Target == nil,
    "global unpin must clear dormant per-profile opt-outs")
assert(core:SetProfileFeaturePinOptOut("groupFrames", true) == true)
pins:DropProfile("Other", h.db)
assert(core:GetProfileFeatureSource("groupFrames") == nil)
assert(h.db.global.profileFeaturePins.optOuts.Target == nil,
    "deleting a global source must clear that category's opt-outs")

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

local auraContextFile = assert(io.open("core/aura_context.lua", "rb"))
local auraContextSource = auraContextFile:read("*a")
auraContextFile:close()
local specEvent = assert(auraContextSource:find('f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")', 1, true))
local specPinApply = assert(auraContextSource:find("pins:HandleProfileFeatureSpecChanged()", specEvent, true))
local specAuraRefresh = assert(auraContextSource:find("RefreshAuraSurfaces()", specPinApply, true))
assert(specEvent < specPinApply and specPinApply < specAuraRefresh)

print("ok profile feature pin")
