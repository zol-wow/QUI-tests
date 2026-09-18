local function read(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local function extract(source, signature)
    local start = assert(source:find(signature, 1, true), signature)
    local finish = assert(source:find("\nend\n", start, true)) + 4
    return source:sub(start, finish)
end

local source = read("QUI_GroupFrames/groupframes/groupframes.lua")
local editSource = read("QUI_GroupFrames/groupframes/groupframes_editmode.lua")
local env = setmetatable({}, {__index = _G})
local calls = {}
local function record(name)
    return function() calls[#calls + 1] = name end
end
env.ns = {Client = {restrictedExecutionUnavailable = true},
    QUI_GroupFrameBlizzard = {HideBlizzardFrames = record("suppress")}}
env.QUI_GF = {initialized = false}
env.QUI_GFEM = {}
env._state = {ApplyHUDLayering = record("layer")}
env.GetSettings = function() return {enabled = true} end
env.InCombatLockdown = function() return false end
for _, name in ipairs({"CreateHeaders", "CreateSpotlightHeader", "DestroySpotlightHeader",
    "RegisterEvents", "UpdateHeaderVisibility", "UpdateFrameScaling", "ResolveRangeSpells",
    "StartRangeCheck", "RefreshCachedEnabled", "InvalidateCache"}) do
    env[name] = record(name)
end
for _, name in ipairs({"Initialize", "RefreshSettings", "RecreateSpotlightHeader", "IsEnabled"}) do
    setfenv(assert(loadstring(extract(source, "function QUI_GF:" .. name .. "()"))), env)()
end
setfenv(assert(loadstring(extract(editSource, "function QUI_GFEM:CreateSpotlightHeader()"))), env)()

for _, unavailable in ipairs({true, false}) do
    env.ns.Client.restrictedExecutionUnavailable = unavailable
    calls = {}
    env.QUI_GF:Initialize()
    assert(env.QUI_GF.initialized, "both clients complete group frame initialization")
    assert(env.QUI_GF:IsEnabled(), "both clients respect enabled setting")
    assert(calls[1] == "CreateHeaders", "both clients create native secure headers")
    assert(calls[#calls] == "suppress", "native suppression follows replacement initialization")
    assert(not env._state.inInitSafeWindow, "initialization closes safe window")
    env.QUI_GF:RecreateSpotlightHeader()
    assert(calls[#calls] == "CreateSpotlightHeader", "Forever permits native spotlight headers")
end
print("OK: forever_groupframes_restricted_execution_test")
