local addonEnv = dofile("tools/_addon_env.lua")
addonEnv.LoadLibs()

for _, flavor in ipairs({ "retail", "forever", "classic" }) do
    local group, groups, spec, canUseTalents = 1, 2, 2, true
    local events = {}
    local frame = {
        RegisterEvent = function(_, event) events[event] = true end,
        RegisterUnitEvent = function(_, event, unit) assert(unit == "player"); events[event] = true end,
        UnregisterEvent = function(_, event) events[event] = nil end,
        SetScript = function(self, event, fn) self[event] = fn end,
    }
    local function Unexpected() error("wrong client specialization API") end
    local env = setmetatable({
        GetBuildInfo = function() return "", "", "", flavor == "forever" and 16001 or 120105 end,
        C_SpecializationInfo = {
            GetSpecialization = flavor == "retail" and function() return spec end or Unexpected,
            GetNumSpecializationsForClassID = function() return 2 end,
            CanPlayerUseTalentUI = function() return canUseTalents end,
            CanPlayerUseTalentSpecUI = function() return canUseTalents end,
            GetActiveSpecGroup = flavor ~= "retail" and function() return group end or Unexpected,
        },
        GetNumSpecializations = flavor == "retail" and function() return 2 end or Unexpected,
        GetNumSpecGroups = flavor == "forever" and function() return groups end or Unexpected,
        GetNumTalentGroups = flavor == "classic" and function() return groups end or Unexpected,
        ClassicExpansionAtLeast = function() return flavor ~= "classic" end,
        ClassicExpansionAtMost = function() return flavor == "classic" end,
        LE_EXPANSION_MISTS_OF_PANDARIA = 4,
        LE_EXPANSION_CATACLYSM = 3,
        LE_EXPANSION_SHADOWLANDS = 8,
        UnitClass = function() return "Priest", "PRIEST", 5 end,
        UnitClassBase = function() return "PRIEST", 5 end,
        GetSpecializationInfoForClassID = function(_, index) return index, "Spec" .. index end,
        IsLoggedIn = function() return true end,
        CreateFrame = function() return frame end,
        TALENT_SPEC_PRIMARY = "Primary",
        TALENT_SPEC_SECONDARY = "Secondary",
        RED_FONT_COLOR = { WrapTextInColorCode = function(_, text) return text end },
        wipe = function(t) for key in pairs(t) do t[key] = nil end end,
    }, { __index = _G })
    LibStub.libs["LibDualSpec-1.0"], LibStub.minors["LibDualSpec-1.0"] = nil, nil
    local previous = LibStub:NewLibrary("LibDualSpec-1.0", 35)
    local source = os.getenv("QUI_DUALSPEC_TEST_SOURCE") or "libs/LibDualSpec-1.0/LibDualSpec-1.0.lua"
    local chunk = assert(loadfile(source))
    setfenv(chunk, env)
    chunk()
    local library = LibStub("LibDualSpec-1.0")
    assert(library == previous and library.EnhanceDatabase,
        "QUI's patched library must replace an already-loaded upstream35")
    assert(library.currentSpec == (flavor == "retail" and 2 or 1))
    assert(events[flavor == "retail" and "PLAYER_SPECIALIZATION_CHANGED" or "ACTIVE_TALENT_GROUP_CHANGED"],
        "each client must register the event that drives its profile mapping")
    local db = LibStub("AceDB-3.0"):New({ profiles = { Default = {}, Other = { sentinel = 17 } } }, {}, true)
    local mapping = db:RegisterNamespace("LibDualSpec-1.0").char
    mapping.enabled, mapping[1], mapping[2] = true, "Default", "Other"
    library:EnhanceDatabase(db, "QUI")
    assert(db:GetCurrentProfile() == (flavor == "retail" and "Other" or "Default"))
    local event = flavor == "retail" and "PLAYER_SPECIALIZATION_CHANGED" or "ACTIVE_TALENT_GROUP_CHANGED"
    group, spec = 2, 1
    frame:OnEvent(event)
    assert(db:GetCurrentProfile() == (flavor == "retail" and "Default" or "Other"),
        "spec/group changes must activate the corresponding saved profile")
    if flavor == "retail" then
        for _, invalidSpec in ipairs({ 3, 5 }) do
            spec = invalidSpec
            frame:OnEvent(event)
            assert(library.currentSpec == 0 and db:GetCurrentProfile() == "Default",
                "out-of-range or initial specializations must not activate a saved mapping")
        end
        spec, canUseTalents = 2, false
    else
        groups, group = 1, 1
    end
    frame:OnEvent(event)
    assert(library.currentSpec == 0 and not db:IsDualSpecEnabled(),
        "locked dual spec or unavailable talents must disable automatic switching")
    assert(db:GetCurrentProfile() == (flavor == "retail" and "Default" or "Other"),
        "locking specialization must preserve the currently selected profile")
    groups, canUseTalents = 2, true
    frame:OnEvent(event)
    assert(db:IsDualSpecEnabled() and db:GetCurrentProfile() == (flavor == "retail" and "Other" or "Default"),
        "unlocking must restore the persisted profile mapping")
end

print("OK: libdualspec_client_switch")
