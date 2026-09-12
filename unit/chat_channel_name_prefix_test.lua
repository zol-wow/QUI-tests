local errors = {}
_G.geterrorhandler = function()
    return function(err) errors[#errors + 1] = err end
end
_G.ChatFrameConstants = { MaxRememberedWhisperTargets = 10 }
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua"))()
_G.ChatFrameUtil.GetCommunityAndStreamName = function(clubId, streamId)
    assert(clubId == 123 and streamId == 456)
    return "Friends - General"
end
_G.CHAT_YOU_CHANGED_NOTICE = "Changed Channel: |Hchannel:%d|h[%s]|h"
_G.CHAT_OWNER_CHANGED_NOTICE = "[%d. %s] Owner: %s"

local ns = { QUI = { Chat = { _internals = {
    GetSettings = function() return { modifiers = { channelShorten = { enabled = false } } } end,
} } } }
assert(loadfile("core/safecall.lua"))("QUI", ns)
assert(loadfile("QUI_Chat/chat/message_format.lua"))("QUI", ns)
local F = ns.QUI.Chat.MessageFormat

for _, case in ipairs({
    { "", "" },
    { "Trade", "Trade" },
    { "Community:123:456", "Community:123:456" },
    { "2.Trade", "2.Trade" },
    { "2. ", "2. " },
    { "2. Trade", "2. Trade" },
    { "12. Community:123:456", "12. Friends - General" },
}) do
    local channel, expected = case[1], case[2]
    local line = F.BuildEventLineFromArgs("CHAT_MSG_CHANNEL_NOTICE",
        "YOU_CHANGED", "", "", channel, "", "", 0, 2, "")
    assert(line == "Changed Channel: |Hchannel:2|h[" .. expected .. "]|h",
        "Channel notice must retain its name: " .. channel)
    assert(#errors == 0, "Channel notice must not report a resolver error: " .. tostring(errors[1]))

    line = F.BuildEventLineFromArgs("CHAT_MSG_CHANNEL_NOTICE_USER",
        "OWNER_CHANGED", "Ann", "", channel, "", "", 0, 2, "")
    assert(line == "[2. " .. expected .. "] Owner: Ann", "Owner notice must retain its name")
    assert(#errors == 0, "Owner notice must not report a resolver error")

    for _, number in ipairs({ 0, 2 }) do
        line = F.BuildEventLine("CHAT_MSG_CHANNEL", { text = "hello", channelFull = channel, chNum = number })
        if channel ~= "" then
            assert(line:find("[" .. expected .. "]", 1, true), "Channel message must retain its label")
        end
        assert(#errors == 0, "Channel message must not report a resolver error")
    end
end

print("chat_channel_name_prefix_test: ok")
