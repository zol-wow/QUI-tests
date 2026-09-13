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

_G.Ambiguate = function(name, mode)
    local result = rendered(name)
    if mode == "short" or result:match("%-Sargeras$") then
        result = result:match("^[^-]+")
    end
    if issecretvalue(name) then return opaque(result) end
    return result
end
_G.CHAT_GUILD_GET = "[Guild] %s: "

local errors = {}
_G.geterrorhandler = function()
    return function(err) errors[#errors + 1] = err end
end
local settings = { modifiers = { classColors = { enabled = false } } }
local ns = {
    Helpers = { IsSecretValue = issecretvalue },
    QUI = { Chat = { _internals = { GetSettings = function() return settings end } } },
}
assert(loadfile("core/safecall.lua"))("QUI", ns)
assert(S.LoadInstrumented("QUI_Chat/chat/message_format.lua"))("QUI", ns)
local F = ns.QUI.Chat.MessageFormat
local cases = {
    { name = "Cilk-Sargeras", hidden = "Cilk", shown = "Cilk" },
    { name = "Erassah-Sargeras", hidden = "Erassah", shown = "Erassah" },
    { name = "Remote-Stormrage", hidden = "Remote", shown = "Remote-Stormrage" },
}

for _, show in ipairs({ false, true }) do
    settings.modifiers.showRealmNames = show
    for _, case in ipairs(cases) do
        for _, secretSender in ipairs({ false, true }) do
            for _, secretBody in ipairs({ false, true }) do
                local sender = secretSender and opaque(case.name) or case.name
                local body = secretBody and opaque("test") or "test"
                local line, _, restricted = F.BuildEventLineFromArgs("CHAT_MSG_GUILD",
                    body, sender, nil, nil, nil, nil, nil, nil, nil, nil, 1, "Player-1")
                local output = rendered(line)
                local expected = show and case.shown or case.hidden
                assert(output:find("|h[" .. expected .. "]|h", 1, true),
                    "Guild sender must display " .. expected .. " with showRealmNames=" .. tostring(show))
                assert(output:find("|Hplayer:" .. case.name .. ":", 1, true)
                    or output:find("|Hplayer:" .. case.name .. "|h", 1, true),
                    "Realm formatting must preserve the full clickable player identity")
                assert(restricted == (secretSender or secretBody), "Formatted secrecy must reach capture")
                assert(issecretvalue(line) == restricted, "Formatted text must preserve secrecy")
                assert(#errors == 0, "Sender formatting must not report an error")
            end
        end
    end
end

string.format = nativeFormat
print("chat_secret_sender_realm_names_test: 24 cases passed")
