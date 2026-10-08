function LibStub() return nil end

local ns = {}
assert(loadfile("core/utils.lua"))("QUI", ns)

local nativeFont = "Fonts\\ARIALN.TTF"
local selectedFont = "Interface\\AddOns\\QUI\\assets\\Quazii.ttf"
local core = { db = { profile = { general = {
    applyGlobalFontToBlizzard = true, skinCommunities = false,
} } } }
ns.Addon = core
ns.LSM = { Fetch = function() return selectedFont end }
ns.SafeCallMethod = function(_, object, method, ...)
    return pcall(object[method], object, ...)
end

function _G.CreateFontFamily(_, members)
    return { members = members, font = members[1].file, size = members[1].height, flags = members[1].flags }
end

local function NewText(kind, size, justifyV)
    local original = { font = nativeFont, size = size, flags = "" }
    local text = { font = nativeFont, size = size, flags = "", object = original,
        justifyH = "LEFT", justifyV = justifyV }
    function text:IsObjectType(objectType) return objectType == kind end
    function text:GetFont() return self.font, self.size, self.flags end
    function text:SetFont(font, height, flags) self.font, self.size, self.flags = font, height, flags end
    function text:GetFontObject() return self.object end
    function text:SetFontObject(object)
        assert(object ~= self, "restoring an editbox's runtime font object can overflow the client stack")
        self.object = object
        self.font, self.size, self.flags = object.font, object.size, object.flags
        self.justifyH, self.justifyV = "CENTER", "MIDDLE"
    end
    function text:GetJustifyH() return self.justifyH end
    function text:GetJustifyV() return self.justifyV end
    function text:SetJustifyH(value) self.justifyH = value end
    function text:SetJustifyV(value) self.justifyV = value end
    function text:SetMaxLines() end
    function text:SetOnScrollChangedCallback() end
    if kind == "EditBox" then text.object = text end
    return text, original
end

local events, timers = {}, {}
function _G.CreateFrame()
    return {
        RegisterEvent = function(_, event) events[event] = true end,
        SetScript = function(_, _, callback) events.callback = callback end,
    }
end
_G.C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
local function FlushTimers()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do callback() end
end

_G.NUM_CHAT_WINDOWS = 1
_G.ChatFrame1 = NewText("ScrollingMessageFrame", 16, "BOTTOM")
_G.DEFAULT_CHAT_FRAME = _G.ChatFrame1
_G.ScrollUtil = { InitScrollingMessageFrameWithScrollBar = function() end }
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_Communities/CommunitiesChatFrame.lua"))()
assert(loadfile("core/font_system.lua"))("QUI", ns)

core:ApplyGlobalFont()
assert(_G.ChatFrame1.font == selectedFont, "ordinary chat must still follow the global font")

local message, originalMessageFont = NewText("ScrollingMessageFrame", 14, "TOP")
local input = NewText("EditBox", 13, "MIDDLE")
_G.CommunitiesFrame = { Chat = { MessageFrame = message, ScrollBar = {} }, ChatEditBox = input }
_G.CommunitiesChatMixin.OnLoad(_G.CommunitiesFrame.Chat)
assert(message.font == selectedFont and not message.object.members,
    "native guild chat copies the default frame's physical font without its glyph fallback family")

assert(events.ADDON_LOADED, "guild chat needs a font update when Blizzard_Communities loads on demand")
events.callback(nil, "ADDON_LOADED", "Blizzard_Other")
assert(#timers == 0, "unrelated addon loads must not refresh chat fonts")
events.callback(nil, "ADDON_LOADED", "Blizzard_Communities")
FlushTimers()
assert(message.font == selectedFont and message.object.members,
    "late-loaded guild messages must receive the QUI font family even when the physical path already matches")
assert(input.font == selectedFont and input.object.members,
    "guild chat input must follow the global font even with the Communities skin disabled")
assert(message.size == 16 and input.size == 13, "guild message and input font sizes must remain independent")
assert(message.justifyH == "LEFT" and message.justifyV == "TOP", "guild messages must remain left/top aligned")
assert(input.justifyH == "LEFT", "guild input must remain left aligned")
local alphabets = {}
for _, member in ipairs(message.object.members) do alphabets[member.alphabet] = member.file end
assert(alphabets.korean == "Fonts\\2002.TTF" and alphabets.simplifiedchinese == "Fonts\\ARKai_T.ttf",
    "guild chat must retain the shared character fallback fonts")

selectedFont = "Fonts\\MORPHEUS.TTF"
core:ApplyGlobalFont()
assert(message.font == selectedFont and input.font == selectedFont,
    "changing the selected QUI font must update existing guild messages and input")

events.callback(nil, "ADDON_LOADED", "Blizzard_Communities")
core.db.profile.general.applyGlobalFontToBlizzard = false
core:ApplyGlobalFont()
FlushTimers()
assert(message.object == originalMessageFont and message.font == nativeFont,
    "disabling the global override must restore the guild message font object")
assert(input.font == nativeFont and input.size == 13 and input.flags == "",
    "disabling the global override must restore input using physical font values")
assert(message.justifyH == "LEFT" and message.justifyV == "TOP", "restoration must preserve guild message alignment")
events.callback(nil, "ADDON_LOADED", "Blizzard_Communities")
FlushTimers()
assert(message.font == nativeFont and input.font == nativeFont, "addon loading must respect a disabled global font override")

core.db.profile.general.applyGlobalFontToBlizzard = true
core:ApplyGlobalFont()
assert(message.font == selectedFont and input.font == selectedFont,
    "guild chat already loaded before enabling the global override must also update")

core.db.profile.general.applyGlobalFontToBlizzard = false
core:ApplyGlobalFont()
local createFontFamily = _G.CreateFontFamily
_G.CreateFontFamily = nil
core.db.profile.general.applyGlobalFontToBlizzard = true
core:ApplyGlobalFont()
assert(message.font == selectedFont and input.font == selectedFont,
    "guild chat must still apply the font when font families are unavailable")
core.db.profile.general.applyGlobalFontToBlizzard = false
core:ApplyGlobalFont()
assert(message.font == nativeFont and input.font == nativeFont,
    "direct-font fallback must still restore both guild chat widgets")
_G.CreateFontFamily = createFontFamily

print("OK: communities_chat_global_font_test")
