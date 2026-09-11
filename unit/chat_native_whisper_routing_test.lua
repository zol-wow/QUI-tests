local unpack = table.unpack or unpack
local function noop() end
local combat = false
local frames = {}

local function frame(name, parent)
    local f = { name = name, parent = parent, shown = true, events = {}, scripts = {}, attributes = {} }
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:SetParent(p) self.parent = p end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetFocus() self.focused = self:IsVisible() end
    function f:HasFocus() return self.focused end
    function f:SetScript(k, v) self.scripts[k] = v end
    function f:GetScript(k) return self.scripts[k] end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:UnregisterAllEvents() self.events = {} end
    function f:GetID() return self.id end
    function f:SetChatType(v) self.chatType = v end
    function f:GetChatType() return self.chatType or "SAY" end
    function f:SetStickyType(v) self.stickyType = v end
    function f:GetStickyType() return self.stickyType or "SAY" end
    function f:SetTellTarget(v) self.tellTarget = v end
    function f:SetText(v) self.text = v end
    function f:ParseText()
        self.tellTarget = self.text:match("^/w (%S+)")
        self.chatType = "WHISPER"
    end
    function f:Deactivate() self.focused = false end
    function f:SetAttribute(k, v) self.attributes[k] = v end
    function f:GetAttribute(k) return self.attributes[k] end
    function f:GetFontString() return self end
    for _, method in ipairs({ "SetFrameStrata", "Raise", "UpdateHeader", "SetAlpha",
        "UpdateNewcomerEditBoxHint", "SetFocusRegionsShown" }) do
        f[method] = noop
    end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end

UIParent = frame("UIParent")
_G.GeneralDockManager = frame("GeneralDockManager", UIParent)
GENERAL_CHAT_DOCK = _G.GeneralDockManager
_G.CHAT_FRAMES = {}
local function chatFrame(id)
    local name = "ChatFrame" .. id
    local f = frame(name, UIParent)
    f.id = id
    frame(name .. "Tab", _G.GeneralDockManager)
    frame(name .. "ButtonFrame", f)
    f.editBox = frame(name .. "EditBox", UIParent)
    f.editBox.chatFrame = f
    f.editBox.header = frame(nil, f.editBox)
    _G.CHAT_FRAMES[#_G.CHAT_FRAMES + 1] = name
    return f
end

chatFrame(1)
chatFrame(2)
chatFrame(3)
NUM_CHAT_WINDOWS = 3
FloatingChatFrameManager = frame("FloatingChatFrameManager", UIParent)
ChatTypeGroup = {
    WHISPER = { "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM" },
    BN_WHISPER = { "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM" },
}
ChatFrameConstants = { MaxRememberedWhisperTargets = 10 }
C_GameRules = { GetActiveGameMode = function() return 0 end }
Enum = { GameMode = { Plunderstorm = 1 } }
C_EventUtils = { IsEventValid = function() return true end }
C_Timer = { After = function(_, callback) callback() end }
SLASH_WHISPER1 = "/w"
strsub, strupper = string.sub, string.upper
local style, selected = "im", _G.ChatFrame3
local whisperMode, cvarWrites = "popout", 0
local function dispatch(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f:GetScript("OnEvent") then
            f:GetScript("OnEvent")(f, event, ...)
        end
    end
end
function GetCVar(name) return name == "chatStyle" and style or whisperMode end
local deferCVarEvents, cvarEvents = false, {}
C_CVar = { SetCVar = function(name, value)
    assert(name == "whisperMode", "only whisperMode should be normalized")
    local changed = whisperMode ~= value
    whisperMode = value
    cvarWrites = cvarWrites + 1
    assert(cvarWrites < 30, "synchronous CVAR_UPDATE must not recurse")
    if changed then
        if deferCVarEvents then
            cvarEvents[#cvarEvents + 1] = { name, value }
        else
            dispatch("CVAR_UPDATE", name, value)
        end
    end
end }
function InCombatLockdown() return combat end
function IsVoiceTranscription() return false end
function FCFDock_GetSelectedWindow() return selected end
function CreateFrame(_, name, parent) return frame(name, parent) end
FCFClickAnywhereButton_UpdateState = noop
UIFrameFadeRemoveFrame = noop
FCF_OpenNewWindow = noop
FCF_OpenTemporaryWindow = noop

local function pack(...) return { n = select("#", ...), ... } end
function hooksecurefunc(object, name, hook)
    if type(object) == "string" then object, name, hook = _G, object, name end
    local original = assert(object[name], name)
    object[name] = function(...)
        local result = pack(original(...))
        hook(...)
        return unpack(result, 1, result.n)
    end
end

local nativeRoot = "tests/framexml/Interface/AddOns/Blizzard_ChatFrameBase/"
assert(loadfile(nativeRoot .. "Shared/ChatFrameUtil.lua"))("Blizzard_ChatFrameBase", {})
local settings = { enabled = true }
local ns = {
    Helpers = { IsSecretValue = function() return false end },
    SafeCall = function(_, fn, ...) return pcall(fn, ...) end,
    SafeCallMethod = function(_, object, method, ...) return pcall(object[method], object, ...) end,
    SafeCallMethodIfPresent = function(_, object, method, ...)
        if object and object[method] then return pcall(object[method], object, ...) end
    end,
    QUI = { Chat = {
        _internals = {
            GetSettings = function() return settings end,
            IsChatEnabled = function(s) return s.enabled end,
        },
    } },
}
assert(loadfile(os.getenv("QUI_WHISPER_SUPPRESS_SOURCE") or "QUI_Chat/chat/blizzard_suppress.lua"))("QUI", ns)
local suppress = ns.QUI.Chat.BlizzardSuppress
suppress.Apply()
for _, f in ipairs(frames) do
    if f.events.PLAYER_ENTERING_WORLD then f:GetScript("OnEvent")(f, "PLAYER_ENTERING_WORLD") end
end
assert(suppress.IsActive(), "suppression must be active")

combat = true
for _, chatType in ipairs({ "WHISPER", "BN_WHISPER" }) do
    LAST_ACTIVE_CHAT_EDIT_BOX, _G.ACTIVE_CHAT_EDIT_BOX = nil, nil
    selected = _G.ChatFrame3
    if chatType == "WHISPER" then
        ChatFrameUtil.SendTell("Player-Realm")
    else
        ChatFrameUtil.SendBNetTell("BattleFriend")
    end
    assert(_G.ACTIVE_CHAT_EDIT_BOX == _G.ChatFrame3.editBox, "native IM picker must select the dock's last window")
    assert(_G.ACTIVE_CHAT_EDIT_BOX:IsVisible() and _G.ACTIVE_CHAT_EDIT_BOX:HasFocus(),
        "combat whisper silently targets an editbox under a hidden ordinary chat frame")
    assert(_G.ACTIVE_CHAT_EDIT_BOX:GetChatType() == chatType, "native whisper type must survive activation")
end
for _, event in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" }) do
    assert(ChatFrame1.events[event], "native reply history event must remain registered: " .. event)
    ChatFrame1:RegisterEvent(event)
    assert(ChatFrame1.events[event], "native reply history event must survive outside registrations: " .. event)
end

ChatFrameUtil.SetLastTellTarget("ReplyFriend", "BN_WHISPER")
ChatFrameUtil.ReplyTell()
assert(_G.ACTIVE_CHAT_EDIT_BOX.tellTarget == "ReplyFriend" and _G.ACTIVE_CHAT_EDIT_BOX:HasFocus(),
    "native reply must focus a visible editbox with the last sender")

for _, chatStyle in ipairs({ "im", "classic" }) do
    style = chatStyle
    LAST_ACTIVE_CHAT_EDIT_BOX, _G.ACTIVE_CHAT_EDIT_BOX = _G.ChatFrame3.editBox, nil
    ChatFrameUtil.SendBNetTell("BattleFriend")
    local expected = style == "classic" and ChatFrame1.editBox or _G.ChatFrame3.editBox
    assert(_G.ACTIVE_CHAT_EDIT_BOX == expected and expected:IsVisible() and expected:HasFocus(),
        "both native chat styles must activate visible inputs in combat")
end

assert(whisperMode == "popout_and_inline" and suppress.GetWhisperMode() == "popout",
    "native reply bookkeeping needs inline delivery while QUI remembers the user's popout preference")
assert(cvarWrites == 1, "normalization should write the native CVar once")
assert(not _G.GeneralDockManager:IsVisible(), "Blizzard's dock must remain hidden")

combat = false
settings.enabled = false
suppress.Apply()
assert(whisperMode == "popout" and suppress.GetWhisperMode() == "popout",
    "disabling QUI chat must restore the original native whisper preference")
for _, mode in ipairs({ "inline", "popout_and_inline" }) do
    C_CVar.SetCVar("whisperMode", mode)
    local previousWrites = cvarWrites
    settings.enabled = true
    suppress.Apply()
    assert(whisperMode == mode and suppress.GetWhisperMode() == mode,
        "inline and Both preferences must remain unchanged during suppression")
    settings.enabled = false
    suppress.Apply()
    assert(whisperMode == mode and cvarWrites == previousWrites,
        "unchanged preferences must not be rewritten on activation or restoration")
end

C_CVar.SetCVar("whisperMode", "popout")
settings.enabled = true
suppress.Apply()
C_CVar.SetCVar("whisperMode", "inline")
assert(whisperMode == "inline" and suppress.GetWhisperMode() == "inline",
    "a live user preference change must replace the saved popout preference")
C_CVar.SetCVar("whisperMode", "popout")
assert(whisperMode == "popout_and_inline" and suppress.GetWhisperMode() == "popout",
    "live popout selection must normalize without losing the requested mode")
C_CVar.SetCVar("whisperMode", "popout_and_inline")
assert(suppress.GetWhisperMode() == "popout_and_inline",
    "explicit Both selection must replace Popout even when no CVAR_UPDATE fires")
C_CVar.SetCVar("whisperMode", "inline")
deferCVarEvents = true
C_CVar.SetCVar("whisperMode", "popout")
for _, event in ipairs(cvarEvents) do dispatch("CVAR_UPDATE", unpack(event)) end
deferCVarEvents = false
assert(suppress.GetWhisperMode() == "popout" and whisperMode == "popout_and_inline",
    "delayed user and normalization events must preserve the requested Popout mode")
dispatch("PLAYER_LOGOUT")
assert(whisperMode == "popout", "logout must persist the user's preference instead of QUI's normalized value")

print("OK: chat_native_whisper_routing_test")
