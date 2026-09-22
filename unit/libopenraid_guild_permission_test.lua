local function noop() end
local inGuild, canSpeak, group, instance = true, false, nil, false
local sent, ticker, serverTime = {}, nil, 0
local aceComm
local library = {}
local deflate = {
    CompressDeflate = function(_, data) return data end,
    EncodeForWoWAddonChannel = function(_, data) return data end,
}
local environment = setmetatable({
    GetBuildInfo = function() return "12.0", "", "", 120000 end,
    WOW_PROJECT_ID = 1,
    WOW_PROJECT_MAINLINE = 1,
    LE_PARTY_CATEGORY_INSTANCE = 2,
    InCombatLockdown = function() return false end,
    UnitAffectingCombat = function() return false end,
    IsInGuild = function() return inGuild end,
    IsInGroup = function(category) return group ~= nil and (category == nil or instance) end,
    IsInRaid = function(category) return group == "RAID" and (category == nil or instance) end,
    GetServerTime = function() return serverTime end,
    date = os.date,
    tinsert = table.insert,
    C_Container = {},
    C_CVar = { RegisterCVar = noop, GetCVar = function() return "0" end },
    C_GuildInfo = { CanSpeakInGuildChat = function() return canSpeak end },
    C_ChatInfo = {
        RegisterAddonMessagePrefix = noop,
        SendAddonMessage = function(prefix, data, channel)
            assert(prefix == "LRS" and data == "J", "guild request payload changed")
            sent[#sent + 1] = channel
        end,
    },
    C_Timer = {
        After = noop,
        NewTicker = function(_, callback)
            ticker = callback
            return { Cancel = noop }
        end,
    },
    CreateFrame = function()
        return { RegisterEvent = noop, RegisterUnitEvent = noop, SetScript = noop }
    end,
    LibStub = {
        NewLibrary = function() return library end,
        GetLibrary = function(_, name)
            if name == "LibDeflate" then return deflate end
            if name == "AceComm-3.0" then return aceComm end
        end,
    },
    bit = { band = function(value, mask)
        mask = tonumber(mask)
        return math.floor(value / mask) % 2 * mask
    end },
}, { __index = _G })
environment._G = environment
local path = "libs/LibOpenRaid/LibOpenRaid.lua"
local chunk = assert(loadfile(path))
if setfenv then
    setfenv(chunk, environment)
else
    chunk = assert(loadfile(path, "t", environment))
end
chunk()

local function check(expected, flags)
    sent = {}
    library.commHandler.SendCommData("J", flags)
    serverTime = serverTime + 1
    ticker()
    local actual = table.concat(sent, ",")
    assert(actual == expected, "expected channels '" .. expected .. "', got '" .. actual .. "'")
end

check("", 4)
canSpeak = true
check("GUILD", 4)
canSpeak = false
check("", 4)
inGuild, canSpeak = false, true
check("", 4)
inGuild, canSpeak = true, false

for _, channel in ipairs({ "PARTY", "RAID" }) do
    group = channel
    check(channel)
    check(channel, 7)
    instance = true
    check("INSTANCE_CHAT", 7)
    instance = false
end

local aceSends = 0
aceComm = { SendCommMessage = function(_, prefix, data, channel)
    aceSends = aceSends + 1
    environment.C_ChatInfo.SendAddonMessage(prefix, data, channel)
end }
group = nil
check("", 4)
canSpeak = true
check("GUILD", 4)
canSpeak, group = false, "PARTY"
check("PARTY", 7)
assert(aceSends == 2, "allowed guild and party messages must use AceComm when loaded")

print("PASS libopenraid_guild_permission_test")
