local libraryPath = ... or "libs/LibRangeCheck-3.0/LibRangeCheck-3.0.lua"
local secret = dofile("tests/helpers/secret_sentinel.lua")
local restore = secret.InstallSecretStub()
local function noop() end
_G.CreateFrame = function()
    return { Hide = noop, Show = noop, SetScript = noop, RegisterEvent = noop, RegisterUnitEvent = noop }
end
_G.GetTime = function() return 10 end
_G.GetFramerate = function() return 60 end
_G.hooksecurefunc = noop
_G.C_ChatInfo = {}
_G.Enum = { SpellBookSpellBank = { Player = 0 } }
assert(secret.LoadInstrumented("libs/AceComm-3.0/ChatThrottleLib.lua"))()
local ctl = _G.ChatThrottleLib
local failures = 0
local function check(name, fn)
    local ok, err = pcall(fn)
    print((ok and "ok - " or "FAIL - ") .. name .. (ok and "" or ": " .. tostring(err)))
    if not ok then failures = failures + 1 end
end
local value = secret.MakeSecretSentinel()
local hooks = {
    chat = function(text, destination) ctl.Hook_SendChatMessage(text, "WHISPER", nil, destination) end,
    addon = function(text, destination) ctl.Hook_SendAddonMessage("QUI", text, "WHISPER", destination) end,
    logged = function(text, destination) ctl.Hook_SendAddonMessageLogged("QUI", text, "WHISPER", destination) end,
    battleNet = function(text, destination) ctl.Hook_BNSendGameData(destination, "QUI", text) end,
}
for name, hook in pairs(hooks) do
    check(name .. " ignores secret text and destination", function()
        ctl.avail, ctl.nBypass = 1000, 0
        hook(value, "Target")
        hook("hello", value)
        assert(ctl.avail == 1000 and ctl.nBypass == 0, "secret traffic changed bandwidth")
    end)
    check(name .. " accounts for ordinary traffic", function()
        ctl.avail, ctl.nBypass = 1000, 0
        hook("hello", "Target")
        local size = 5 + 6 + ctl.MSG_OVERHEAD + (name == "chat" and 0 or 3)
        assert(ctl.avail == 1000 - size and ctl.nBypass == size)
    end)
end
secret.RestoreSecretStub(restore)
_G.GetBuildInfo = function() return "12.1", "", "", 120100 end
_G.WOW_PROJECT_ID, _G.WOW_PROJECT_MAINLINE = 1, 1
_G.C_SpellBook = {}
_G.C_Item = {}
_G.UnitClass = function() return "Warrior", "WARRIOR" end
_G.C_Timer = { NewTicker = function() return {} end }
_G.tinsert, _G.tremove, _G.sort = table.insert, table.remove, table.sort
_G.strmatch = string.match
local slotCalls = 0
local function inventorySlot(name)
    assert(name == "HANDSSLOT")
    slotCalls = slotCalls + 1
    return 10
end
for _, modern in ipairs({ false, true }) do
    check("range library loads using " .. (modern and "namespaced" or "legacy") .. " inventory API", function()
        _G.LibStub = nil
        dofile("libs/LibStub/LibStub.lua")
        _G.GetInventorySlotInfo = not modern and inventorySlot or nil
        _G.C_PaperDollInfo = modern and { GetInventorySlotInfo = inventorySlot } or nil
        slotCalls = 0
        dofile(libraryPath)
        local range = _G.LibStub("LibRangeCheck-3.0")
        assert(slotCalls == 1 and range.frame and type(range.GetRange) == "function")
    end)
end
check("range item requests use direct APIs and retain failure and response handling", function()
    local now, itemInfo = 10, {}
    _G.GetTime = function() return now end
    _G.Item = nil
    _G.C_Item = {
        DoesItemExistByID = function(item) return item ~= 101 end,
        GetItemInfo = function(item) return itemInfo[item] end,
    }
    _G.LibStub = nil
    dofile("libs/LibStub/LibStub.lua")
    dofile(libraryPath)
    local range = _G.LibStub("LibRangeCheck-3.0")
    local registered = {}
    range.frame.IsEventRegistered = function(_, event) return registered[event] end
    range.frame.RegisterEvent = function(_, event) registered[event] = true end
    range.failedItemRequests[102] = true
    itemInfo[103] = "Cached item"
    local requests = { [5] = { 101, 102, 103 } }
    assert(range:processItemRequests(requests) == nil and next(requests) == nil)

    requests = { [10] = { 104 } }
    assert(range:processItemRequests(requests) == true and registered.GET_ITEM_INFO_RECEIVED)
    itemInfo[104] = "Received item"
    assert(range:processItemRequests(requests) == true, "pending request must wait for its response")
    range:GET_ITEM_INFO_RECEIVED("GET_ITEM_INFO_RECEIVED", 104, true)
    assert(range:processItemRequests(requests) == nil and next(requests) == nil)

    requests = { [15] = { 105 } }
    assert(range:processItemRequests(requests) == true)
    range:GET_ITEM_INFO_RECEIVED("GET_ITEM_INFO_RECEIVED", 105, false)
    assert(range:processItemRequests(requests) == nil and range.failedItemRequests[105])

    requests = { [20] = { 106 } }
    assert(range:processItemRequests(requests) == true)
    now = 21
    assert(range:processItemRequests(requests) == nil and range.failedItemRequests[106])
end)
check("patched range library supersedes upstream minor 38", function()
    _G.LibStub = nil
    dofile("libs/LibStub/LibStub.lua")
    local upstream = _G.LibStub:NewLibrary("LibRangeCheck-3.0", 38)
    local getRange = function() error("unpatched upstream checker") end
    upstream.GetRange = getRange
    dofile(libraryPath)
    local range, minor = _G.LibStub("LibRangeCheck-3.0")
    assert(range == upstream and minor > 38 and range.GetRange ~= getRange)
end)
assert(failures == 0, failures .. " vendor regression checks failed")
print("OK: vendor_library_updates_test")
