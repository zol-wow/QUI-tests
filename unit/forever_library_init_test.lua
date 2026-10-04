local project = {}
for _, path in ipairs({ "ProjectConstants.lua", "Camelot/ProjectConstants.lua" }) do
    local chunk = assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_ProjectConstants/" .. path))
    setfenv(chunk, project)
    chunk()
end

local function loadOpenRaid(version, interfaceVersion, shouldInitialize)
    local initialized = false
    local env = setmetatable({
        GetBuildInfo = function() return version, interfaceVersion == 16001 and "70205" or "69893", "", interfaceVersion end,
        WOW_PROJECT_ID = interfaceVersion == 16001 and project.WOW_PROJECT_CAMELOT or project.WOW_PROJECT_MAINLINE,
        WOW_PROJECT_MAINLINE = project.WOW_PROJECT_MAINLINE,
        LibStub = { NewLibrary = function() initialized = true; return nil end },
    }, { __index = _G })
    env._G = env
    for _, path in ipairs({ "LibOpenRaid.lua", "Functions.lua", "GetPlayerInformation.lua", "Deprecated.lua", "ThingsToMantain_Midnight.lua" }) do
        local chunk = assert(loadfile("libs/LibOpenRaid/" .. path))
        setfenv(chunk, env)
        chunk()
    end
    assert(initialized == shouldInitialize, "wrong library initialization policy for " .. version)
    assert(env.LIB_OPEN_RAID_CAN_LOAD == false, "skipped library must leave following chunks inactive")
end

loadOpenRaid("1.60.1", 16001, false)
loadOpenRaid("12.1.5", 120105, true)
print("OK: unsupported Forever OpenRaid dataset does not initialize")
