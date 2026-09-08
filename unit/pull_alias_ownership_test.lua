local initPath = os.getenv("QUI_PULL_INIT") or "init.lua"
local framexml = "tests/framexml/Interface/AddOns/Blizzard_ChatFrameBase/Shared/"

local function session(loaded)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.table = setmetatable({ wipe = function(t)
        for key in pairs(t) do t[key] = nil end
    end }, { __index = table })
    env.strupper, env.strsub, env.strfind = string.upper, string.sub, string.find
    env.strmatch, env.strlen = string.match, string.len
    env.strtrim = function(s) return s:match("^%s*(.-)%s*$") end
    env.securecallfunction = function(fn, ...) return fn(...) end
    env.secureexecuterange = function(t, fn, ...)
        for key, value in pairs(t) do fn(key, value, ...) end
    end
    env.CreateFromMixins = function(t) return setmetatable({}, { __index = t }) end
    env.CreateFrame = function()
        return { Hide = function() end, RegisterEvent = function() end, SetScript = function() end }
    end
    env.ChatFrameConstants = { MaxRememberedWhisperTargets = 0 }
    env.ChatTypeInfo, env.ChatTypeGroup = {}, {}
    env.MAXEMOTEINDEX = 0
    env.DevTools_AddMessageHandler = function() end
    local countdowns = {}
    env.C_PartyInfo = { DoCountdown = function(seconds)
        countdowns[#countdowns + 1] = seconds
        return true
    end }
    env.C_AddOns = {
        GetAddOnMetadata = function() return "test" end,
        IsAddOnLoaded = function(name) return loaded and loaded[name] or false end,
    }
    local function load(path, ...)
        setfenv(assert(loadfile(path)), env)(...)
    end
    local chat = {}
    load(framexml .. "SlashCommandsRegistry.lua", "Blizzard_ChatFrameBase", chat)
    load(framexml .. "ChatFrameUtil.lua", "Blizzard_ChatFrameBase", chat)
    load(framexml .. "ChatFrameSetup.lua", "Blizzard_ChatFrameBase", chat)
    load(framexml .. "ChatFrameEditBox.lua", "Blizzard_ChatFrameBase", chat)
    load("libs/LibStub/LibStub.lua")
    load("libs/AceConsole-3.0/AceConsole-3.0.lua")
    env.LibStub:NewLibrary("AceAddon-3.0", 1).NewAddon = function()
        local addon = {
            CheckMediaRegistration = function() end,
            BackwardsCompat = function() end,
            RegisterEvent = function() end,
        }
        env.LibStub("AceConsole-3.0"):Embed(addon)
        return addon
    end
    load(initPath, "QUI", { L = setmetatable({}, { __index = function(_, key) return key end }) })
    env.QUI:OnInitialize()
    local box = setmetatable({
        GetText = function(self) return self.text end,
        AddHistoryLine = function() end,
        ClearChat = function() end,
        HandleChatType = function() return false end,
    }, { __index = env.ChatFrameEditBoxBaseMixin })
    local function send(text)
        box.text = text
        box:ParseText(1)
    end
    return env, send, countdowns
end

local failures = 0
local function check(name, test)
    local ok, err = pcall(test)
    if ok then
        print("PASS " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

check("BigWigs lazy core loading retains /pull", function()
    local env, send = session()
    env.QUI:OnEnable()
    env.ChatFrameUtil.ImportAllListsToHash()
    local calls = 0
    env.SLASH_pull1 = "/pull"
    env.SlashCmdList.pull = function()
        calls = calls + 1
        env.QUI:ADDON_LOADED("ADDON_LOADED", "BigWigs_Core")
    end
    send("/pull 10")
    assert(calls == 1, "first /pull must reach BigWigs before its core loads")
    assert(rawget(env.SlashCmdList, "pull") == nil, "native importer must consume the pending registration")
    send("/pull 10")
    assert(calls == 2, "BigWigs /pull must still dispatch after its core loads without a reload")
end)

check("known owners prevent early optional registration", function()
    for _, owner in ipairs({ "BigWigs", "BigWigs_Core", "DBM-Core" }) do
        local env = session({ [owner] = true })
        env.QUI:OnEnable()
        assert(not env.QUI.pullAliasOwned, owner .. " must retain /pull before its callback reaches the native hash")
        assert(env.SLASH_QUIPULL_ALIAS1 == nil, "QUI must not publish a competing /pull alias")
    end
end)

check("pending aliases retain their owner", function()
    local env, send = session()
    local calls = 0
    env.SLASH_OTHER1, env.SLASH_OTHER2 = "/other", "/PuLl"
    env.SlashCmdList.OTHER = function() calls = calls + 1 end
    env.QUI:OnEnable()
    assert(not env.QUI.pullAliasOwned, "an uncached secondary /pull alias must prevent a competing registration")
    send("/pull 10")
    assert(calls == 1, "the existing pending owner must receive /pull")
end)

check("cached owners retain their callback", function()
    local env, send = session()
    local calls = 0
    env.SLASH_OTHER1 = "/pull"
    env.SlashCmdList.OTHER = function() calls = calls + 1 end
    env.ChatFrameUtil.ImportAllListsToHash()
    env.QUI:OnEnable()
    env.QUI:ADDON_LOADED("ADDON_LOADED", "BigWigs_Core")
    send("/pull 10")
    assert(calls == 1, "an already cached owner must survive QUI startup and addon loading")
end)

check("repeated registration preserves cleanup and permanent aliases", function()
    local env, send, countdowns = session()
    env.QUI:OnEnable()
    send("/pull 12")
    assert(countdowns[1] == 12, "QUI must provide /pull when no other owner exists")
    assert(env.QUI:RegisterOptionalPullAlias(), "repeated registration must preserve QUI ownership")
    env.QUI:ADDON_LOADED("ADDON_LOADED", "UnrelatedAddon")
    send("/pull 13")
    assert(countdowns[2] == 13, "unrelated addons must leave QUI /pull intact")
    env.QUI:ADDON_LOADED("ADDON_LOADED", "DBM-Core")
    send("/pull 14")
    assert(#countdowns == 2, "releasing QUI ownership must remove its cached /pull callback")
    send("/qpull 15")
    send("/quipull 16")
    assert(countdowns[3] == 15 and countdowns[4] == 16, "permanent QUI aliases must survive optional /pull release")
end)

assert(failures == 0, tostring(failures) .. " pull ownership regressions failed")
