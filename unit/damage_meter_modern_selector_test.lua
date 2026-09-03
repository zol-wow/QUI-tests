local function readAll(path)
    local file = assert(io.open(path, "rb"))
    local data = file:read("*a")
    file:close()
    return data:gsub("\r\n", "\n")
end

local src = readAll("QUI_DamageMeter/damage_meter/damage_meter.lua")
local startAt = assert(src:find("function Data:ClearSourceGUIDCache", 1, true))
local endAt = assert(src:find("\nlocal function TableOrEmpty", startAt, true))
local chunk = src:sub(startAt, endAt - 1)

local secret = {}
local env = {
    Data = { _sourceGUIDBySelector = {}, _inCombat = false },
    SessionKey = function(sessionType, sessionID)
        return sessionID and ("id:" .. sessionID) or ("type:" .. sessionType)
    end,
    IsSecretValue = function(value) return value == secret end,
    Helpers = { SafeValue = function(value, fallback)
        return value == secret and fallback or value
    end },
    UnitGUID = function(unit) return unit == "player" and "Player-Local" or nil end,
}
setmetatable(env, { __index = _G })
local loader = assert(loadstring(chunk .. "\nreturn Data"))
setfenv(loader, env)
local Data = loader()

Data:_CacheSourceGUIDs("type:1", {
    { specIconID = 101, sourceGUID = "Player-One" },
    { specIconID = 202, sourceGUID = "Player-Two" },
})
assert(Data._sourceGUIDBySelector["type:1"][101] == "Player-One")

Data:_CacheSourceGUIDs("type:1", {
    { specIconID = 101, sourceGUID = "Player-Other" },
})
assert(Data._sourceGUIDBySelector["type:1"][101] == false)

local guid, creatureID, kind = Data:ResolveSourceSelector({
    sourceGUID = "Player-Readable",
    specIconID = 101,
}, 1, nil, true)
assert(guid == "Player-Readable" and creatureID == nil and kind == "direct")

guid, creatureID, kind = Data:ResolveSourceSelector({
    sourceGUID = secret,
    specIconID = 202,
}, 1, nil, true)
assert(guid == "Player-Two" and creatureID == nil and kind == "cache")

guid, creatureID, kind = Data:ResolveSourceSelector({
    sourceGUID = secret,
    specIconID = 101,
    isLocalPlayer = true,
}, 1, nil, true)
assert(guid == "Player-Local" and creatureID == nil and kind == "local")

guid, creatureID, kind = Data:ResolveSourceSelector({
    sourceGUID = secret,
    specIconID = 101,
    isLocalPlayer = false,
}, 1, nil, true)
assert(guid == nil and creatureID == nil and kind == "restricted")

Data._inCombat = true
Data:_CacheSourceGUIDs("type:1", {
    { specIconID = 303, sourceGUID = "Player-Late" },
})
assert(Data._sourceGUIDBySelector["type:1"][303] == nil)

Data:ClearSourceGUIDCache()
assert(next(Data._sourceGUIDBySelector) == nil)
Data._sourceGUIDBySelector = {
    ["type:1"] = { [101] = "Player-Live" },
    ["id:77"] = { [202] = "Player-Historical" },
}
Data:ClearLiveSourceGUIDCache()
assert(Data._sourceGUIDBySelector["type:1"] == nil)
assert(Data._sourceGUIDBySelector["id:77"][202] == "Player-Historical")
local beginStart = assert(src:find("function Data:BeginCombat", 1, true))
local beginEnd = assert(src:find("\nfunction Data:EndCombat", beginStart, true))
assert(src:sub(beginStart, beginEnd - 1):find("self:ClearLiveSourceGUIDCache()", 1, true))
assert(src:find('elseif event == "GROUP_ROSTER_UPDATE" then\n        Data:ClearSourceGUIDCache()', 1, true))
assert(src:find('elseif event == "PLAYER_ENTERING_WORLD" then\n        Data:ClearSourceGUIDCache()', 1, true))

print("OK: damage_meter_modern_selector_test")
