local secret = {}
local settings = { enabled = true, customDisplay = { combatLogTab = false, windows = {
    { tabs = { { name = "General", groups = {}, channels = {} } } },
    { tabs = { { name = "Second", groups = {}, channels = {} } } },
} } }
local shown, hovered = true, 2
local containers = {}
for id = 1, 2 do
    containers[id] = {
        IsShown = function() return shown end,
        IsMouseOver = function() return hovered == id end,
    }
end
local menus, activated, rebuilt, notified = {}, nil, 0, 0
_G.MenuUtil = { CreateContextMenu = function(owner, build)
    local menu = { owner = owner, buttons = {} }
    function menu:SetTag() end
    function menu:CreateTitle(title) self.title = title end
    function menu:CreateButton(label, callback)
        local button = { label = label, callback = callback, enabled = true }
        function button:SetEnabled(value) self.enabled = value end
        self.buttons[#self.buttons + 1] = button
        return button
    end
    build(owner, menu)
    menus[#menus + 1] = menu
end }
_G.MOVE_TO_NEW_WINDOW = "Move to New Window"
_G.FCF_CanOpenNewWindow = function() return true end
_G.ChatTypeInfo = { GUILD = {} }
_G.GUILD = "Guild"
_G.ChatFrameUtil = {
    ResolveChannelName = function(name) return name end,
    GetCommunityAndStreamFromChannel = function() end,
    PopOutChat = function() error("native popout must not receive QUI's missing source frame") end,
}
local file = assert(io.open("tests/framexml/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua"))
local source = file:read("*a")
file:close()
assert(loadstring(source:match("function ChatFrameUtil.ShowChatChannelContextMenu.-\nend")))()
local hooks = {}
_G.hooksecurefunc = function(object, name, hook)
    if type(object) == "string" then return end
    hooks[name] = hook
    local original = object[name]
    object[name] = function(...)
        original(...)
        hook(...)
    end
end
local ns = {
    Helpers = { IsSecretValue = function(value) return rawequal(value, secret) end },
    QUI = { Chat = {
        _internals = {
            GetSettings = function() return settings end,
            IsChatEnabled = function(value) return value.enabled end,
            NotifyChatSettingsChanged = function() notified = notified + 1 end,
        },
        DisplayLayer = {
            GetWindowCount = function() return 2 end,
            GetActiveWindow = function() return 1 end,
            GetContainer = function(id) return containers[id] end,
        },
        ChannelRegistry = { ResolveName = function(index)
            return index == 2 and "Trade" or nil
        end },
        TabUI = {
            Rebuild = function() rebuilt = rebuilt + 1 end,
            ActivateFrameID = function(window, frame) activated = { window, frame } end,
        },
    } },
}
(dofile("tests/helpers/locale.lua"))(ns)
assert(loadfile("QUI_Chat/chat/tab_manager.lua"))("QUI_Chat", ns)
assert(loadfile(os.getenv("QUI_CHANNEL_HYPERLINK_SOURCE") or "QUI_Chat/chat/hyperlinks.lua"))("QUI_Chat", ns)
_G.ChatFrameUtil.ShowChatChannelContextMenu(nil, "CHANNEL", "2", "2. Trade")
local menu = menus[#menus]
assert(menu.buttons[1].label == "Add Tab", "QUI channel menu must replace the native popout action")
menu.buttons[1].callback()
local tabs = ns.QUI.Chat.TabManager.GetWindowTabs(2)
assert(#tabs == 2 and tabs[2].name == "Trade" and tabs[2].channels.Trade,
    "channel tab belongs to the hovered QUI window")
assert(activated[1] == 2 and activated[2] == -2 and rebuilt == 1 and notified == 1,
    "new tab must be rebuilt, activated, and saved settings refreshed")
local filter = ns.QUI.Chat.TabManager.BuildTabFilter(tabs[2])
assert(filter({ ch = "Trade" }) and not filter({ ch = "General" }) and not filter({ k = "GUILD" }),
    "new tab shows only the selected channel")
assert(next(tabs[1].channels) == nil and next(tabs[1].groups) == nil,
    "original tab filters remain unchanged")
hovered = nil
_G.ChatFrameUtil.ShowChatChannelContextMenu(nil, "GUILD", nil, "|cff40ff40|Hchannel:GUILD|h[Guild]|h|r")
menus[#menus].buttons[1].callback()
local guildTab = ns.QUI.Chat.TabManager.GetWindowTabs(1)[2]
assert(guildTab.groups.GUILD and activated[1] == 1, "group labels use the active QUI window")
assert(guildTab.name == "Guild", "group tab names must use plain localized labels without hyperlink markup")
filter = ns.QUI.Chat.TabManager.BuildTabFilter(guildTab)
assert(filter({ k = "GUILD" }) and not filter({ k = "SAY" }), "group tab filters by the supplied group")
local count = #menus
hooks.ShowChatChannelContextMenu(nil, secret, "2", "Trade")
hooks.ShowChatChannelContextMenu(nil, "CHANNEL", secret, "Trade")
hooks.ShowChatChannelContextMenu(nil, "CHANNEL", "2", secret)
assert(#menus == count, "secret menu arguments must be rejected before use")
_G.ChatFrameUtil.ShowChatChannelContextMenu(nil, "CHANNEL", "99", "Unknown")
assert(not menus[#menus].buttons[1].enabled, "unresolved channels must not retain the native popout action")
for _, state in ipairs({ "disabled", "hidden", "native" }) do
    settings.enabled = state ~= "disabled"
    shown = state ~= "hidden"
    count = #menus
    _G.ChatFrameUtil.ShowChatChannelContextMenu(state == "native" and {} or nil, "CHANNEL", "2", "Trade")
    assert(#menus == count + 1 and menus[#menus].buttons[1].label == _G.MOVE_TO_NEW_WINDOW,
        "native menu must remain untouched for " .. state)
end
print("OK: chat_channel_context_menu_test")
