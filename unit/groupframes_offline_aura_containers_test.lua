local function read(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local function between(source, first, last)
    local start = assert(source:find(first, 1, true), first)
    local finish = assert(source:find(last, start, true), last)
    return source:sub(start, finish - 1)
end

local function noop() end
local connected = { party1 = true, party2 = true, raid1 = true }
local combat = false
local created = 0
local queued = {}
local ns = {
    SafeCall = function(_, fn, ...) return pcall(fn, ...) end,
    AuraGlue = {
        ElementProfile = function() return {} end,
        ElementGroups = function() return { { key = "debuffs" } } end,
        RunConfigPass = function() return true end,
    },
    AuraSlots = { Park = noop, Sync = function() return true end },
}

UnitIsConnected = function(unit) return connected[unit] end
InCombatLockdown = function() return combat end
CreateFrame = function(kind)
    assert(kind == "AuraContainer")
    created = created + 1
    return {
        SetSize = noop, SetFrameLevel = noop, SetFrameStrata = noop,
        SetUnit = function(self, unit) self.unit = unit end,
        SetEnabled = function(self, enabled) self.enabled = enabled end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
    }
end
assert(loadfile("core/aura_surface.lua"))("QUI", ns)

local source = read("QUI_GroupFrames/groupframes/groupframes_auras.lua")
local runtime = between(source, "local function ApplyElementPass(frame, allowCreate)",
    "function QUI_GFA.TrackedAssistStale(frame)")
local env = setmetatable({
    ns = ns,
    QUI_GFA = { ProfileOverrides = function() return {} end, ApplyRangeGate = noop },
    GetFrameUnit = function(frame) return frame.unit end,
    ResolveAuraDeps = function() return true end,
    GetFrameAuraSettings = function() return {} end,
    GetDB = function() return {} end,
    ResolveContainerElements = function(frame) return frame.elements end,
    AuraGlue = ns.AuraGlue,
    ElementNeedsRangeGate = function() return false end,
    AnchorElementContainer = noop,
    CHROME_LEVELS = { AURA_HOST = 12 },
    QueueContainerCombatWork = function(frame) queued[frame] = true end,
}, { __index = _G })
local chunk = assert(loadstring(runtime .. "\nreturn QUI_GFA"))
setfenv(chunk, env)
local GFA = chunk()
ns.QUI_GroupFrameAuras = GFA

local eventSource = read("QUI_GroupFrames/groupframes/groupframes.lua")
local connectionBranch = between(eventSource,
    'elseif event == "UNIT_CONNECTION" or event == "UNIT_FLAGS" then',
    'elseif event == "UNIT_FACTION" then')
local eventChunk = assert(loadstring(
    "return function(event, frames)\nlocal nFrames = #frames\n"
    .. "local arg1 = frames[1].unit\nif false then\n"
    .. connectionBranch .. "\nend\nend"))
setfenv(eventChunk, setmetatable({
    ns = ns, UpdateConnection = noop, UpdateHealth = noop, UpdatePower = noop,
    _state = { RefreshTrackedSlotAssist = noop },
}, { __index = _G }))
local connectionEvent = eventChunk()

local function host(unit)
    return {
        unit = unit, _isRaid = unit == "raid1", GetFrameLevel = function() return 1 end,
        elements = {
            { mode = "filterStrip", auraType = "HARMFUL" },
            { mode = "tracked", spells = { 17 } },
        },
    }
end

local function expect(frame, visible, message)
    for _, container in ipairs(frame._quiAuraContainers) do
        assert(container.shown == visible and container.enabled == visible, message)
    end
end

local party = host("party1")
local sibling = host("party2")
GFA.ApplyStripContainers(party)
GFA.ApplyStripContainers(sibling)
expect(party, true, "connected member must retain live auras")
expect(sibling, true, "connected sibling must retain live auras")

connected.party1 = false
GFA.UpdateStripContainers(party)
expect(party, false, "refreshing an offline member must hide and disable its aura containers")
expect(sibling, true, "offline member must not hide a connected sibling's auras")

connected.party1 = true
GFA.UpdateStripContainers(party)
expect(party, true, "reconnecting must restore configured aura containers")
local allocations = created
for _, inCombat in ipairs({ false, true }) do
    combat = inCombat
    connected.party1 = false
    connectionEvent("UNIT_CONNECTION", { party })
    expect(party, false, "UNIT_CONNECTION must hide offline auras without waiting for UNIT_AURA")
    expect(sibling, true, "connection event must leave connected sibling visible")
    connected.party1 = true
    connectionEvent("UNIT_CONNECTION", { party })
    expect(party, true, "UNIT_CONNECTION must restore auras on reconnect, including in combat")
end
assert(created == allocations, "disconnect/reconnect must reuse pooled containers")
assert(queued[party], "combat styling must retain the existing deferred replay")

connected.party1 = false
GFA.ApplyStripContainers(party)
expect(party, false, "deferred settings replay must not resurrect offline auras")
local fresh = host("party1")
GFA.ApplyStripContainers(fresh)
expect(fresh, false, "a member already offline at creation must have hidden aura containers")

local raid = host("raid1")
GFA.ApplyStripContainers(raid)
connected.raid1 = false
connectionEvent("UNIT_CONNECTION", { raid })
expect(raid, false, "raid members must follow the same offline container policy")
connected.raid1 = true
connectionEvent("UNIT_CONNECTION", { raid })
expect(raid, true, "raid reconnect must restore live containers")

combat = false
connected.party1 = true
party.elements = { party.elements[1] }
connectionEvent("UNIT_CONNECTION", { party })
assert(party._quiAuraContainers[1].shown, "remaining configured strip must be restored")
assert(not party._quiAuraContainers[2].shown and not party._quiAuraContainers[2].enabled,
    "reconnect must not revive a retired pooled container")

local previous = GFA.UpdateStripContainers
local updates = 0
GFA.UpdateStripContainers = function(...) updates = updates + 1; return previous(...) end
connectionEvent("UNIT_FLAGS", { party })
assert(updates == 0, "unrelated UNIT_FLAGS must not rebuild aura containers")
print("PASS groupframes_offline_aura_containers_test")
