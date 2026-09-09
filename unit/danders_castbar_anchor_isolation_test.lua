local inCombat = false
local frames, timers, postHooks = {}, {}, {}

local function reaches(frame, target, seen)
    if frame == target then return true end
    if not frame then return false end
    seen = seen or {}
    if seen[frame] then return false end
    seen[frame] = true
    return reaches(frame.parent, target, seen)
        or (frame.point and reaches(frame.point[2], target, seen)) or false
end

local function restricted(frame)
    for _, dependent in ipairs(frames) do
        if dependent.protected and reaches(dependent, frame) then return true end
    end
    return false
end

local function makeFrame(name, parent, protected)
    local frame = { name = name, parent = parent, protected = protected, scripts = {}, left = 100, bottom = 200, width = 160, height = 40 }
    frames[#frames + 1] = frame
    local function canMutate(self)
        assert(not inCombat or not restricted(self), self.name .. ": protected dependency blocks combat mutation")
    end
    function frame:GetParent() return self.parent end
    function frame:SetParent(value) canMutate(self); self.parent = value end
    function frame:ClearAllPoints() canMutate(self); self.point = nil end
    function frame:SetPoint(...) canMutate(self); self.point = { ... } end
    function frame:GetPoint() return unpack(self.point or {}) end
    function frame:GetNumPoints() return self.point and 1 or 0 end
    function frame:GetLeft() return self.left end
    function frame:GetRight() return self.left and self.left + self.width end
    function frame:GetBottom() return self.bottom end
    function frame:GetTop() return self.bottom and self.bottom + self.height end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:GetEffectiveScale() return self.scale or 1 end
    function frame:SetScale(value) canMutate(self); self.scale = value end
    function frame:SetHeight(value)
        canMutate(self)
        self.height = value
        if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, self.width, value) end
    end
    function frame:IsProtected() return self.protected or false end
    function frame:IsAnchoringRestricted() return restricted(self) end
    function frame:Show()
        canMutate(self)
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function frame:Hide() canMutate(self); self.shown = false end
    function frame:IsShown() return self.shown or false end
    function frame:RegisterEvent() end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:HookScript(event, callback)
        local previous = self.scripts[event]
        self.scripts[event] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    return frame
end

_G.UIParent = makeFrame("UIParent")
_G.CreateFrame = function(_, name, parent) return makeFrame(name or "eventFrame", parent) end
_G.InCombatLockdown = function() return inCombat end
_G.issecretvalue = function() return false end
_G.LibStub = function() return nil end
_G.hooksecurefunc = function(frame, method, callback)
    local original = frame[method]
    frame[method] = function(...)
        local result = { original(...) }
        callback(...)
        return unpack(result)
    end
end
_G.C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
local function runTimers()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do callback() end
end

local bar = makeFrame("playerCastbar", UIParent)
bar.width, bar.height = 300, 24
local party = makeFrame("DandersParty", UIParent)
local raid = makeFrame("DandersRaid", UIParent)
makeFrame("partyUnit", party, true)
makeFrame("raidUnit", raid, true)
local previewParty = makeFrame("previewParty", UIParent)
local previewRaid = makeFrame("previewRaid", UIParent)
_G.DandersFrames = { container = party }
_G.DandersFrames_IsReady = function() return true end
_G.DandersFrames_GetRaidContainer = function() return raid end
_G.DandersTestPartyContainer = previewParty
_G.DandersTestRaidContainer = previewRaid
local profile = {
    frameAnchoring = {},
    dandersFrames = {
        party = { enabled = true, anchorTo = "playerCastbar", absolutePoint = "CENTER", absoluteX = 467, absoluteY = 119, offsetY = 0 },
        raid = { enabled = true, anchorTo = "playerCastbar", absolutePoint = "CENTER", absoluteX = -520, absoluteY = 98, offsetY = 0 },
    },
}
local ns = {
    Addon = { db = { profile = profile } },
    L = setmetatable({}, { __index = function(_, key) return key end }),
    QUI_Castbar = { castbars = { player = bar } },
    QUI_Anchoring = { RegisterAnchoredFramesPostHook = function(key, callback) postHooks[key] = callback end },
    SafeCall = function(_, fn, ...) return pcall(fn, ...) end,
    SafeCallMethod = function(_, frame, method, ...) return pcall(frame[method], frame, ...) end,
}
assert(loadfile("core/utils.lua"))("QUI", ns)
assert(loadfile("modules/integrations/integration_shared.lua"))("QUI", ns)
assert(loadfile("modules/integrations/dandersframes.lua"))("QUI", ns)
local integration = ns.QUI_DandersFrames
integration:Initialize()

assert(profile.dandersFrames.party.anchorTo == "playerCastbar" and profile.dandersFrames.raid.anchorTo == "playerCastbar",
    "saved party and raid castbar anchors must remain enabled")
inCombat = true
local ok, err = pcall(bar.Show, bar)
assert(ok and bar.shown, "Danders anchors must permit player castbar Show in combat: " .. tostring(err))
bar:SetHeight(32)
local partyPoint = party.point
integration:ApplyAllPositions()
assert(party.point == partyPoint, "protected live container must defer combat movement")
inCombat = false
for _, frame in ipairs(frames) do
    if frame.scripts.OnEvent then frame.scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED") end
end
runTimers()
for _, frame in ipairs({ party, raid, previewParty, previewRaid }) do
    assert(frame.point and frame.point[2] == UIParent, frame.name .. " must have no native dependency on the castbar")
    assert(frame.point[4] == 250 and frame.point[5] == 200, frame.name .. " must retain its target-relative screen position")
end
bar.left = 400
assert(postHooks.dandersframes, "integration must register for anchor updates")()
assert(party.point[4] == 550 and raid.point[4] == 550, "party and raid must follow castbar movement outside combat")
bar.left = 600
bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
runTimers()
assert(party.point[4] == 750 and raid.point[4] == 750, "target SetPoint must refresh live followers")

profile.dandersFrames.raid.targetPoint = "TOP"
profile.dandersFrames.raid.offsetX = 8
profile.dandersFrames.raid.offsetY = -4
raid:SetScale(2)
runTimers()
assert(raid.point[4] == 383 and raid.point[5] == 112, "absolute pin must preserve container-scaled offsets")
bar:SetHeight(40)
runTimers()
assert(raid.point[5] == 116, "target resize must refresh target-relative placement")

local lastPartyPoint, lastRaidPoint = party.point, raid.point
bar.left = nil
integration:ApplyAllPositions()
assert(party.point == lastPartyPoint and raid.point == lastRaidPoint,
    "unavailable target geometry must preserve the last isolated position")
bar.left = 700
bar:Show()
runTimers()
assert(party.point[4] == 850, "target OnShow must recover temporarily unavailable geometry")

inCombat = true
lastPartyPoint, lastRaidPoint = party.point, raid.point
bar.left = 800
bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
runTimers()
assert(party.point == lastPartyPoint and raid.point == lastRaidPoint,
    "protected followers must retain position through target movement in combat")
inCombat = false
for _, frame in ipairs(frames) do
    if frame.scripts.OnEvent then frame.scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED") end
end
runTimers()
assert(party.point[4] == 950 and raid.point[4] == 483,
    "deferred live followers must catch up after combat")
bar:SetScale(2)
runTimers()
assert(party.point[4] == 1900 and raid.point[4] == 958 and raid.point[5] == 236,
    "target SetScale must refresh followers without another geometry event")
assert(#timers == 0, "target scale refresh must not schedule itself indefinitely")
raid:SetScale(1)
previewParty:SetScale(2)
assert(#timers == 1, "container scale changes must share one pending refresh")
runTimers()
assert(raid.point[4] == 1908 and raid.point[5] == 476,
    "live container SetScale must retain its anchor and scaled offsets")
assert(previewParty.point[4] == 950 and previewParty.point[5] == 200,
    "preview container SetScale must retain its anchor")
assert(#timers == 0, "container scale refresh must not schedule itself indefinitely")
print("OK: danders_castbar_anchor_isolation_test")
