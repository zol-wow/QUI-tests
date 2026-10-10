local function run(path, env, ...)
    local chunk = assert(loadfile(path))
    setfenv(chunk, setmetatable(env, { __index = _G }))
    return chunk(...)
end

for _, legacyPresent in ipairs({ false, true }) do
    local currentSpec = 2
    local specID = 1487
    local env = {
        C_SpecializationInfo = {
            GetSpecialization = function() return currentSpec end,
            GetSpecializationInfo = function(index)
                assert(index == currentSpec)
                return specID, "Priest", nil, 1, "HEALER"
            end,
            GetNumSpecializationsForClassID = function(classID)
                assert(classID == 5)
                return 2
            end,
            GetActiveSpecGroup = function() error("must not substitute talent groups for specs") end,
            CanPlayerUseTalentSpecUI = function() return true end,
        },
        ClassicExpansionAtLeast = function() return true end,
        ClassicExpansionAtMost = function() return false end,
        UnitClassBase = function() return "PRIEST", 5 end,
        GetSpecializationInfoForClassID = function(_, index) return index, "Spec" .. index end,
        GetLocale = function() return "enUS" end,
        IsLoggedIn = function() return true end,
        LE_EXPANSION_MISTS_OF_PANDARIA = 4,
        LE_EXPANSION_SHADOWLANDS = 8,
        LE_EXPANSION_CATACLYSM = 3,
        wipe = function(t) for key in pairs(t) do t[key] = nil end return t end,
    }
    if legacyPresent then
        env.GetSpecialization = function() error("deprecated GetSpecialization called") end
        env.GetSpecializationInfo = function() error("deprecated GetSpecializationInfo called") end
    end
    local frames = {}
    env.CreateFrame = function()
        local frame = {
            RegisterEvent = function() end,
            UnregisterEvent = function() end,
            RegisterUnitEvent = function() end,
            SetScript = function(self, name, callback) self[name] = callback end,
        }
        frames[#frames + 1] = frame
        return frame
    end
    local library
    env.LibStub = setmetatable({
        NewLibrary = function() library = {}; return library end,
    }, { __call = function() return nil end })
    run("libs/LibDualSpec-1.0/LibDualSpec-1.0.lua", env)
    assert(library.currentSpec == 2, "login must use modern spec index without deprecated aliases")
    currentSpec = 1
    frames[1]:OnEvent("PLAYER_SPECIALIZATION_CHANGED")
    assert(library.currentSpec == 1, "spec-change event must use modern spec index")

    local ns = { AuraElements = {}, L = setmetatable({}, { __index = function(_, key) return key end }) }
    run("core/aura_wizard.lua", env, "QUI", ns)
    assert(ns.QUI_AuraWizard.PlayerSpecID() == 1487, "Forever spec ID must survive unchanged")
    assert(ns.QUI_AuraWizard.PlayerRole() == "HEALER", "role must use namespaced specialization info")
    specID = 256
    assert(ns.QUI_AuraWizard.PlayerSpecID() == 256, "Retail spec IDs must still work")
    currentSpec = nil
    assert(ns.QUI_AuraWizard.PlayerSpecID() == nil, "unavailable spec remains nil-safe")
end

print("forever_specialization_api_test passed")
