local function noop() end

local function run(historyEnabled, hasHistory, chatEnabled)
    local frames, timers = {}, {}
    local now = 1700000000
    _G.CreateFrame = function()
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:UnregisterAllEvents() self.events = {} end
        function frame:SetScript(script, fn) self[script] = fn end
        frames[#frames + 1] = frame
        return frame
    end
    local function fire(event, ...)
        for i = 1, #frames do
            local frame = frames[i]
            if frame.events[event] then frame.OnEvent(frame, event, ...) end
        end
    end
    _G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    _G.GetServerTime = function() return now end
    _G.hooksecurefunc = noop
    _G.geterrorhandler = function() return error end
    _G.ChatTypeInfo = { GUILD = { r = 0, g = 1, b = 0 } }
    _G.GUILD_MOTD_TEMPLATE = "GMOTD: %s"
    _G.DEFAULT_CHAT_FRAME = {
        GetNumMessages = function() return 1 end,
        GetMessageInfo = function() return "early addon message", 1, 1, 1 end,
    }
    _G.QUI = { db = { keys = { char = "Player - Realm" } } }
    _G.QUIDB = { char = { ["Player - Realm"] = { chat = { history = {
        entries = hasHistory and {
            { m = "old guild message", t = now - 10, f = 1, c = "GUILD", ev = "CHAT_MSG_GUILD" },
        } or {},
    } } } } }
    _G.QUI_ChatHistory = nil

    local settings = {
        enabled = chatEnabled,
        history = { enabled = historyEnabled, showSeparators = true, replayLines = 10 },
    }
    local shown = {}
    local ns = {
        SafeCall = function(_, fn, ...) return pcall(fn, ...) end,
        Helpers = {
            CreateDBGetter = function() return function() return settings end end,
            CreateStateTable = function() return {}, noop end,
            IsSecretValue = function() return false end,
        },
        UIKit = {},
        QUI = { Chat = {
            Sounds = { Setup = noop },
            Copy = { SetupURLClick = noop },
            MessageFormat = { ColorForTypeKey = function() return 0, 1, 0 end },
        } },
    }
    local Chat = ns.QUI.Chat
    local function load(name)
        assert(loadfile("QUI_Chat/chat/" .. name .. ".lua"))("QUI_Chat", ns)
    end
    load("chat")
    load("history_storage")
    load("history")
    load("message_store")
    load("message_capture")
    local subscribed = false
    Chat.DisplayLayer = {
        EnsureCreated = function()
            if not subscribed then
                subscribed = true
                Chat.MessageStore.OnAppend(function(entry) shown[#shown + 1] = entry end)
            end
        end,
        Refresh = noop, Show = noop, Hide = noop,
        IsCreated = function() return subscribed end,
    }
    Chat.TabManager = { ReapplyAll = function()
        shown = {}
        Chat.MessageStore.ForEach(function(entry) shown[#shown + 1] = entry end)
    end }
    load("display_fallback")

    fire("ADDON_LOADED", "QUI_Chat")
    fire("GUILD_MOTD", "before login")
    fire("PLAYER_LOGIN")
    fire("GUILD_MOTD", "after login")
    fire("PLAYER_ENTERING_WORLD")
    for i = 1, #timers do timers[i]() end
    Chat.DisplayFallback.Apply()

    local expected = {}
    if chatEnabled then
        if historyEnabled and hasHistory then
            expected = { "---- Previous session ----", "old guild message", "---- Resumed ----" }
        end
        expected[#expected + 1] = "early addon message"
        expected[#expected + 1] = "GMOTD: before login"
        expected[#expected + 1] = "GMOTD: after login"
    end
    local actual = {}
    Chat.MessageStore.ForEach(function(entry) actual[#actual + 1] = entry.m end)
    assert(table.concat(actual, "|") == table.concat(expected, "|"),
        "history must precede native backfill and fresh messages exactly once; got " .. table.concat(actual, "|"))
    assert(#shown == #expected, "display rebuild must include restored and fresh messages once")
    for i = 1, #expected do
        assert(shown[i].m == expected[i], "display order must match session order at " .. i)
    end
    local saved = Chat.HistoryStorage.Snapshot()
    local oldCount = hasHistory and 1 or 0
    local freshCount = chatEnabled and historyEnabled and 2 or 0
    assert(#saved == oldCount + freshCount, "replay and native backfill must not be persisted as fresh chat")
    if freshCount > 0 then
        assert(saved[oldCount + 1].m == "GMOTD: before login", "pre-login chat must still be saved")
        assert(saved[oldCount + 2].m == "GMOTD: after login", "post-login chat must still be saved")
    end
end

run(true, true, true)
run(false, true, true)
run(true, false, true)
run(true, true, false)
print("OK: chat_history_login_order_test")
