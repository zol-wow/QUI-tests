local S = dofile("tests/helpers/secret_sentinel.lua")
S.InstallSecretStub()
local values = {}
local function opaque(value)
    local token = S.MakeSecretSentinel()
    values[token] = value
    return token
end
local function rendered(value)
    if issecretvalue(value) then return values[value] end
    return value
end

local nativeFormat = string.format
string.format = function(template, ...)
    local args = { ... }
    local restricted = issecretvalue(template)
    for i = 1, select("#", ...) do
        restricted = restricted or issecretvalue(args[i])
        args[i] = rendered(args[i])
    end
    local result = nativeFormat(rendered(template), unpack(args, 1, select("#", ...)))
    if restricted then return opaque(result) end
    return result
end

local errors = {}
_G.geterrorhandler = function()
    return function(err) errors[#errors + 1] = err end
end
local ns = {
    Helpers = { IsSecretValue = issecretvalue },
    QUI = { Chat = { _internals = { GetSettings = function() return {} end } } },
}
assert(loadfile("core/safecall.lua"))("QUI", ns)
assert(S.LoadInstrumented("QUI_Chat/chat/message_format.lua"))("QUI", ns)
local F = ns.QUI.Chat.MessageFormat
local achievement = "|cffffff00|Hachievement:6:Player-1-123:1:9:12:26:0:0:0:0|h[Level 10]|h|r"
local body = "%s has earned the achievement " .. achievement .. "!"
local expected = "|Hplayer:Ann|h[Ann]|h has earned the achievement " .. achievement .. "!"

for _, event in ipairs({ "CHAT_MSG_ACHIEVEMENT", "CHAT_MSG_GUILD_ACHIEVEMENT" }) do
    for _, secretBody in ipairs({ false, true }) do
        for _, secretSender in ipairs({ false, true }) do
            local text = secretBody and opaque(body) or body
            local sender = secretSender and opaque("Ann") or "Ann"
            local line, _, restricted = F.BuildEventLineFromArgs(event, text, sender)
            assert(rendered(line) == expected,
                event .. " must substitute the player and preserve the complete achievement hyperlink")
            assert(restricted == (secretBody or secretSender), "Formatted secrecy must reach capture")
            assert(#errors == 0, "Achievement formatting must not report an error")
        end
    end
end

string.format = nativeFormat
print("chat_achievement_secret_format_test: 8 cases passed")
