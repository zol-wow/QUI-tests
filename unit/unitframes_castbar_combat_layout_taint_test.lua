-- tests/unit/unitframes_castbar_combat_layout_taint_test.lua
-- Run: lua tests/unit/unitframes_castbar_combat_layout_taint_test.lua
--
-- Regression guard for the "AddOn 'QUI' tried to call the protected function
-- 'Frame:SetHeight()'" taint error.
--
-- Root cause: a target/focus-change event can fire synchronously inside a secure
-- execution context. Pressing a key bound to TargetNearestEnemy (a protected
-- action, only restricted in combat) changes the target, dispatching
-- PLAYER_TARGET_CHANGED synchronously while the secure call is still on the stack.
-- The castbar's OnEvent handler ran Cast() there, and Cast() makes protected calls
-- (anchorFrame:SetHeight(), icon:Show()/Hide(), channel-tick SetPoint/Hide, ...),
-- each of which is ADDON_ACTION_BLOCKED in that context.
--
-- Fix: in combat the target/focus-change handlers defer Cast() by one frame
-- (C_Timer.After(0)), moving it out of the secure execution context into a normal,
-- unrestricted frame. Out of combat there is no restriction, so Cast() runs
-- synchronously for an instant update.
--
-- This test drives the real OnEvent handler and proves: in combat the protected
-- geometry does NOT run synchronously (it is deferred), and the deferred callback
-- applies it; out of combat it runs synchronously with no defer.
-- luacheck: globals GetTime CreateFrame InCombatLockdown UnitCastingInfo UnitChannelInfo UnitClass UnitGUID UIParent RAID_CLASS_COLORS C_Timer C_RestrictedActions EventRegistry hooksecurefunc LibStub UnitExists

local function noop() end
local inCombat = false
local protectedCallsAllowed = true
local createdFrames = {}
local fractions = { TOPLEFT = {0, 1}, TOP = {0.5, 1}, TOPRIGHT = {1, 1}, LEFT = {0, 0.5}, CENTER = {0.5, 0.5}, RIGHT = {1, 0.5}, BOTTOMLEFT = {0, 0}, BOTTOM = {0.5, 0}, BOTTOMRIGHT = {1, 0} }

local function newRegion(frameType, parent)
    local region = {
        frameType = frameType or "Frame",
        parent = parent,
        width = 0,
        height = 0,
        shown = true,
        alpha = 1,
        frameLevel = 1,
        frameStrata = "MEDIUM",
        points = {},
        protected = false,
        anchoringRestricted = false,
    }

    local function sizeChanged(self)
        if self.scripts and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, self.width, self.height) end
    end
    function region:SetSize(width, height) self.width = width; self.height = height; sizeChanged(self) end
    function region:SetWidth(width) self.width = width; sizeChanged(self) end
    function region:SetHeight(height)
        if not protectedCallsAllowed or (inCombat and (self.protected or self.anchoringRestricted)) then
            error("ADDON_ACTION_BLOCKED: Frame:SetHeight()")
        end
        self.height = height
    end
    function region:GetWidth() return self.width end
    function region:GetHeight() return self.height end
    function region:GetLeft()
        local point = self.points[1]
        if point then
            local relative = point[2]
            return relative:GetLeft() + relative:GetWidth() * fractions[point[3]][1] + (point[4] or 0) - self.width * fractions[point[1]][1]
        end
        return self.left or 0
    end
    function region:GetRight() return self:GetLeft() + self.width end
    function region:GetBottom()
        local point = self.points[1]
        if point then
            local relative = point[2]
            return relative:GetBottom() + relative:GetHeight() * fractions[point[3]][2] + (point[5] or 0) - self.height * fractions[point[1]][2]
        end
        return self.bottom or 0
    end
    function region:GetTop() return self:GetBottom() + self.height end
    function region:GetEffectiveScale() return self.scale or 1 end
    function region:SetScale(scale) self.scale = scale end
    function region:GetNumPoints() return #self.points end
    function region:GetPoint(index)
        local point = self.points[index or 1]
        if point then return unpack(point) end
    end
    function region:SetPoint(...)
        local point = {...}
        local replaced = false
        for index, existing in ipairs(self.points) do
            if existing[1] == point[1] then self.points[index] = point; replaced = true; break end
        end
        if not replaced then self.points[#self.points + 1] = point end
        local relativeTo = point[2]
        self.anchoringRestricted = relativeTo and relativeTo ~= UIParent
            and ((relativeTo.IsProtected and relativeTo:IsProtected())
                or (relativeTo.IsAnchoringRestricted and relativeTo:IsAnchoringRestricted()))
            or false
    end
    function region:ClearAllPoints()
        self.points = {}
        self.anchoringRestricted = false
    end
    function region:SetAllPoints(anchor) self.allPoints = anchor or self.parent or true end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:IsShown() return self.shown end
    function region:IsVisible() return self.shown and self.alpha ~= 0 end
    function region:SetAlpha(alpha) self.alpha = alpha end
    function region:GetAlpha() return self.alpha end
    function region:SetFrameStrata(strata) self.frameStrata = strata end
    function region:GetFrameStrata() return self.frameStrata end
    function region:SetFrameLevel(level) self.frameLevel = level end
    function region:GetFrameLevel() return self.frameLevel end
    function region:GetParent() return self.parent end
    function region:IsProtected() return self.protected end
    function region:IsAnchoringRestricted() return self.anchoringRestricted end
    function region:CreateTexture() return newRegion("Texture", self) end

    function region:CreateFontString()
        local fs = newRegion("FontString", self)
        fs.fontPath = "Fonts\\FRIZQT__.TTF"
        fs.fontSize = 12
        fs.fontFlags = ""
        function fs:SetFont(path, size, flags) self.fontPath = path; self.fontSize = size; self.fontFlags = flags end
        function fs:GetFont() return self.fontPath, self.fontSize, self.fontFlags end
        function fs:SetText(text) self.text = text end
        function fs:SetFormattedText(format, value) self.text = string.format(format, value) end
        function fs:GetStringWidth() return #(self.text or "") * 6 end
        function fs:SetTextColor(r, g, b, a) self.textColor = {r, g, b, a} end
        function fs:SetWordWrap(value) self.wordWrap = value end
        function fs:SetJustifyH(value) self.justifyH = value end
        function fs:SetJustifyV(value) self.justifyV = value end
        return fs
    end

    function region:SetScript(scriptName, handler) self.scripts = self.scripts or {}; self.scripts[scriptName] = handler end
    function region:HookScript(scriptName, handler)
        local previous = self.scripts and self.scripts[scriptName]
        self:SetScript(scriptName, function(...)
            if previous then previous(...) end
            handler(...)
        end)
    end
    function region:RegisterUnitEvent(event, ...) self.unitEvents = self.unitEvents or {}; self.unitEvents[event] = {...} end
    function region:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
    function region:UnregisterAllEvents() self.unitEvents = {}; self.events = {} end
    function region:SetMovable(value) self.movable = value end
    function region:EnableMouse(value) self.mouseEnabled = value end
    function region:RegisterForDrag(...) self.dragButtons = {...} end
    function region:SetClampedToScreen(value) self.clampedToScreen = value end
    function region:GetCenter() return 0, 0 end
    function region:SetMinMaxValues(minValue, maxValue) self.minValue = minValue; self.maxValue = maxValue end
    function region:SetValue(value) self.value = value end
    function region:SetStatusBarColor(r, g, b, a) self.statusBarColor = {r, g, b, a} end
    function region:SetStatusBarTexture(texture) self.statusBarTexture = texture end
    function region:GetStatusBarTexture()
        if not self.statusBarTextureRegion then
            self.statusBarTextureRegion = newRegion("Texture", self)
        end
        return self.statusBarTextureRegion
    end
    function region:SetReverseFill(value) self.reverseFill = value end
    function region:SetTexture(texture) self.texture = texture end
    function region:GetTexture() return self.texture end
    function region:SetColorTexture(r, g, b, a) self.colorTexture = {r, g, b, a} end
    function region:SetVertexColor(r, g, b, a) self.vertexColor = {r, g, b, a} end
    function region:SetTexCoord(...) self.texCoord = {...} end
    function region:SetSnapToPixelGrid(value) self.snapToPixelGrid = value end
    function region:SetTexelSnappingBias(value) self.texelSnappingBias = value end

    return region
end

local now = 100

-- Mutable combat state and a *queuing* timer: C_Timer.After records callbacks so
-- the test can assert work was deferred (not run) and then fire it on demand.
local timerQueue = {}
local timerSchedules = 0
local function flushTimers()
    local pending = timerQueue
    timerQueue = {}
    for _, cb in ipairs(pending) do cb() end
end

function GetTime() return now end
function CreateFrame(frameType, name, parent)
    local frame = newRegion(frameType, parent)
    frame.name = name
    createdFrames[#createdFrames + 1] = frame
    return frame
end
function hooksecurefunc(object, method, callback)
    local original = assert(object[method])
    object[method] = function(...)
        local results = {original(...)}
        callback(...)
        return unpack(results)
    end
end
function InCombatLockdown() return inCombat end
function UnitCastingInfo(unit)
    -- The target castbar watches "target"; report an active (non-channeled) cast
    -- so Cast() enters the real-cast branch that applies the protected geometry.
    if unit == "target" or unit == "player" or unit == "boss1" or unit == "boss2" then
        return "Frostbolt", "Frostbolt", 135846, (now - 0.2) * 1000, (now + 2.8) * 1000, false, "CastGUID", false, 116, nil, 0
    end
    return nil
end
function UnitChannelInfo() return nil end
function UnitExists() return true end
function UnitClass() return "Target", "MAGE" end
function UnitGUID() return "Creature-0000-00000001" end

UIParent = newRegion("Frame")
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
C_Timer = {
    After = function(_, callback)
        timerSchedules = timerSchedules + 1
        timerQueue[#timerQueue + 1] = callback
    end,
    NewTicker = function(interval, callback)
        assert(interval >= 0.05, "cast permission polling must be throttled")
        timerSchedules = timerSchedules + 1
        local ticker = {}
        function ticker:Cancel() self.cancelled = true end
        local function tick()
            if ticker.cancelled then return end
            callback(ticker)
            if not ticker.cancelled then timerQueue[#timerQueue + 1] = tick end
        end
        timerQueue[#timerQueue + 1] = tick
        return ticker
    end,
}
C_RestrictedActions = { CheckAllowProtectedFunctions = function() return protectedCallsAllowed end }
EventRegistry = { RegisterCallback = noop }

local ns = { Helpers = {}, Addon = {}, QUI_Anchoring = { ApplyAllFrameAnchors = function(_, apply) if apply then apply() end end } }
local pixelScale = 1
ns.Helpers.IsSecretValue = function() return false end
ns.Helpers.ApplyBarStyle = function(bar, path) bar:SetStatusBarTexture(path) end
ns.Helpers.ApplyTextureStyle = function(_, texture, path) texture:SetTexture(path) end
ns.Helpers.ApplyIconStyle = function() end
ns.Helpers.SafeValue = function(value) return value end
ns.Helpers.EnsureDefaults = function(tbl, defaults)
    for key, value in pairs(defaults) do
        if tbl[key] == nil then tbl[key] = value end
    end
end
ns.Helpers.GetGeneralFont = function() return "Fonts\\FRIZQT__.TTF" end
ns.Helpers.GetGeneralFontOutline = function() return "" end
ns.Helpers.GetCore = function() return ns.Addon end
ns.Helpers.Clamp = function(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end
ns.Helpers.CreateStateTable = function() return setmetatable({}, { __mode = "k" }) end
ns.Helpers.CHROME = { BORDER_PX = 1, BG_FALLBACK = { 0.05, 0.05, 0.05, 0.95 }, BORDER_FALLBACK = { 0, 0, 0, 1 }, BUTTON_BOOST = 0.07, SCROLLROW_BOOST = 0.03, DEPTH = { PANEL = { boost = 0, alpha = 0.95 }, SUBPANEL = { boost = 0.04, alpha = 0.85 }, ROW = { boost = 0.07, alpha = 0.75 } } }

function ns.Addon:PixelRound(value) return math.floor((value / pixelScale) + 0.5) * pixelScale end
function ns.Addon:Pixels(value) return value * pixelScale end
function ns.Addon:GetPixelSize() return pixelScale end
function ns.Addon:SetPixelPerfectSize(frame, width, height) frame:SetSize(math.floor(width + 0.5) * pixelScale, math.floor(height + 0.5) * pixelScale) end
function ns.Addon:SetPixelPerfectHeight(frame, height) frame:SetHeight(math.floor(height + 0.5) * pixelScale) end
function ns.Addon:SetPixelPerfectPoint(frame, point, relativeTo, relativePoint, x, y) frame:SetPoint(point, relativeTo, relativePoint, x, y) end
function ns.Addon:SetSnappedPoint(frame, point, relativeTo, relativePoint, x, y) frame:SetPoint(point, relativeTo, relativePoint, x, y) end
function ns.Addon:ApplyPixelSnapping() end
function ns.Addon:ApplyFont(fontString, _, size, path, outline) fontString:SetFont(path, size, outline) end

local realUtils = { Helpers = {} }
LibStub = function() return nil end
assert(loadfile("core/utils.lua"))("QUI", realUtils)
for _, name in ipairs({"PinFrameToTargetAbsolute", "FrameMutationRestricted", "BaseClearAllPoints", "BaseSetPoint"}) do
    ns.Helpers[name] = realUtils.Helpers[name]
end

assert(loadfile("core/uikit.lua"))("QUI", ns)
assert(loadfile("core/cast_engine.lua"))("QUI", ns)
assert(loadfile(os.getenv("QUI_CASTBAR_SOURCE") or "QUI_UnitFrames/unitframes/castbar.lua"))("QUI", ns)

local settings = {
    target = {
        castbar = {
            enabled = true,
            showIcon = true,
            iconSize = 22,
            iconScale = 1,
            iconSpacing = 0,
            iconAnchor = "LEFT",
            iconBorderSize = 1,
            iconBorderColor = {0, 0, 0, 1},
            width = 220,
            height = 18,
            borderSize = 1,
            borderColor = {0, 0, 0, 1},
            color = {1, 0.7, 0, 1},
            bgColor = {0.149, 0.149, 0.149, 1},
            texture = "Flat",
            showSpellText = true,
            showTimeText = true,
        },
    },
}
settings.boss = settings.target

ns.QUI_Castbar:SetHelpers({
    GetUnitSettings = function(unit) return settings[unit] end,
    GetGeneralSettings = function() return {} end,
    GetDB = function() return { general = {} } end,
    GetTexturePath = function() return "Interface\\Buttons\\WHITE8x8" end,
    GetUnitClassColor = function() return 1, 1, 1, 1 end,
    TruncateName = function(name) return name end,
})

local unitFrame = newRegion("Frame", UIParent)
unitFrame:SetSize(220, 40)
unitFrame.protected = true

-- A target castbar registers PLAYER_TARGET_CHANGED -- the secure-execution vector.
local castbar = assert(ns.QUI_Castbar:CreateCastbar(unitFrame, "target", "target"))
assert(not castbar:IsAnchoringRestricted(),
    "target castbar should pin to UIParent instead of the protected unit frame")
local onEvent = assert(castbar.scripts and castbar.scripts.OnEvent,
    "castbar should wire an OnEvent handler")

-- Spy on the exact protected call the bug report blocked: anchorFrame:SetHeight().
local realSetHeight = castbar.SetHeight
local setHeightCalls = 0
castbar.SetHeight = function(self, height)
    setHeightCalls = setHeightCalls + 1
    return realSetHeight(self, height)
end

for _, event in ipairs({"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START"}) do
    inCombat = true
    protectedCallsAllowed = false
    setHeightCalls = 0
    timerQueue = {}
    local ok, err = pcall(onEvent, castbar, event, "target", "CastGUID", 116)
    assert(ok, event .. " should not hit protected castbar geometry: " .. tostring(err))
    assert(setHeightCalls == 0, event .. " should defer while protected calls are denied")
    assert(#timerQueue >= 1, event .. " should queue a deferred cast")
    local retryCallback = timerQueue[1]
    onEvent(castbar, event, "target", "CastGUID", 133)
    assert(#timerQueue == 1, event .. " must coalesce repeated denied events")
    local scheduled = timerSchedules
    for _ = 1, 3 do
        flushTimers()
        assert(setHeightCalls == 0, event .. " must recheck permission on every deferred retry")
        assert(#timerQueue == 1, event .. " must retain one retry while permission remains denied")
        assert(timerQueue[1] == retryCallback, event .. " must reuse its callback while permission remains denied")
        assert(timerSchedules == scheduled, event .. " must not schedule new timers while permission remains denied")
    end
    protectedCallsAllowed = true
    flushTimers()
    assert(setHeightCalls >= 1, event .. " should update after leaving the denied context")
    assert(castbar.channelSpellID == 133, event .. " must replay the latest coalesced cast arguments")
    assert(#timerQueue == 0, event .. " must stop retrying once permission returns")
end

for _, event in ipairs({"UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED"}) do
    protectedCallsAllowed = false
    setHeightCalls = 0
    timerQueue = {}
    onEvent(castbar, "UNIT_SPELLCAST_START", "target", "CastGUID", 116)
    local castingInfo = UnitCastingInfo
    UnitCastingInfo = function() return nil end
    onEvent(castbar, event, "target", "CastGUID", 116)
    flushTimers()
    UnitCastingInfo = castingInfo
    assert(setHeightCalls == 0, event .. " must not replay canceled cast geometry")
    assert(#timerQueue == 0, event .. " must stop retries even while permission remains denied")
end
protectedCallsAllowed = true

protectedCallsAllowed = false
onEvent(castbar, "UNIT_SPELLCAST_START", "target", "CastGUID", 116)
local castingInfo = UnitCastingInfo
UnitCastingInfo = function() return nil end
onEvent(castbar, "UNIT_SPELLCAST_STOP", "target", "CastGUID", 116)
UnitCastingInfo = castingInfo
onEvent(castbar, "UNIT_SPELLCAST_START", "target", "CastGUID", 133)
flushTimers()
assert(#timerQueue == 1, "a canceled callback must not revive alongside a newer cast retry")
protectedCallsAllowed = true
castbar:Cast(133, false, true)
setHeightCalls = 0
flushTimers()
assert(setHeightCalls == 0, "an immediate permitted Cast must invalidate any pending replay")
assert(#timerQueue == 0, "an immediate permitted Cast must stop its pending retry")

inCombat = false
local bossFrame = newRegion("Frame", UIParent)
bossFrame:SetSize(220, 40)
bossFrame.protected = true
local bossCastbar = assert(ns.QUI_Castbar:CreateBossCastbar(bossFrame, "boss1", 1))
assert(not bossCastbar:IsAnchoringRestricted(),
    "boss castbar should pin to UIParent instead of the protected boss frame")

local bossOnEvent = assert(bossCastbar.scripts and bossCastbar.scripts.OnEvent)
local bossSetHeight = bossCastbar.SetHeight
local bossHeightCalls = 0
bossCastbar.SetHeight = function(self, height)
    bossHeightCalls = bossHeightCalls + 1
    return bossSetHeight(self, height)
end

for _, event in ipairs({"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_STOP"}) do
    inCombat = false
    bossCastbar:Hide()
    inCombat = true
    protectedCallsAllowed = false
    bossHeightCalls = 0
    timerQueue = {}
    local ok, err = pcall(bossOnEvent, bossCastbar, event, "boss1")
    assert(ok, "boss " .. event .. " should not hit protected geometry: " .. tostring(err))
    assert(bossHeightCalls == 0, "boss " .. event .. " should defer while protected calls are denied")
    assert(not bossCastbar:IsVisible(), "boss cast must remain hidden while protected calls are denied")
    assert(#timerQueue == 1, "boss " .. event .. " should queue one deferred cast")
    local retryCallback = timerQueue[1]
    bossOnEvent(bossCastbar, "UNIT_SPELLCAST_SUCCEEDED", "boss1")
    assert(#timerQueue == 1, "boss events must coalesce while permission is denied")
    assert(bossCastbar._quiPendingCastRetry.fromCastStart == nil,
        "boss retry must retain the latest refresh argument")
    bossOnEvent(bossCastbar, "UNIT_SPELLCAST_START", "boss1")
    assert(bossCastbar._quiPendingCastRetry.fromCastStart == true,
        "boss retry must retain the latest START argument")
    local scheduled = timerSchedules
    for _ = 1, 3 do
        flushTimers()
        assert(bossHeightCalls == 0, "boss " .. event .. " must recheck permission on every deferred retry")
        assert(#timerQueue == 1 and timerQueue[1] == retryCallback,
            "boss retries must retain one reusable callback")
        assert(timerSchedules == scheduled, "boss retries must not allocate new timers each tick")
    end
    protectedCallsAllowed = true
    flushTimers()
    assert(bossHeightCalls >= 1, "boss " .. event .. " should recover active cast geometry after deferral")
    assert(bossCastbar:IsVisible(), "boss " .. event .. " must display the cast in combat after permission returns")
end

for _, event in ipairs({"UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED"}) do
    protectedCallsAllowed = false
    bossHeightCalls = 0
    bossOnEvent(bossCastbar, "UNIT_SPELLCAST_START", "boss1")
    local originalCastingInfo = UnitCastingInfo
    UnitCastingInfo = function() return nil end
    bossOnEvent(bossCastbar, event, "boss1")
    flushTimers()
    UnitCastingInfo = originalCastingInfo
    assert(#timerQueue == 0 and bossCastbar._quiPendingCastRetry == nil,
        "boss " .. event .. " must cancel retries when the cast has ended")
    assert(bossHeightCalls == 0, "canceled boss retries must not change geometry")
end
bossOnEvent(bossCastbar, "UNIT_SPELLCAST_START", "boss1")
local originalCastingInfo = UnitCastingInfo
UnitCastingInfo = function() return nil end
bossOnEvent(bossCastbar, "UNIT_SPELLCAST_STOP", "boss1")
UnitCastingInfo = originalCastingInfo
bossOnEvent(bossCastbar, "UNIT_SPELLCAST_START", "boss1")
flushTimers()
assert(#timerQueue == 1, "a canceled boss callback must not revive beside a new cast")
protectedCallsAllowed = true
bossCastbar:Cast(true)
bossHeightCalls = 0
flushTimers()
assert(bossHeightCalls == 0 and #timerQueue == 0,
    "an immediate permitted boss Cast must cancel pending replay")

inCombat = false
castbar:Hide()
inCombat = true
onEvent(castbar, "UNIT_SPELLCAST_START", "target", "CastGUID", 116)
assert(castbar:IsVisible(), "a castbar hidden after preview must show for the next permitted combat cast")

local bossCastingInfo = UnitCastingInfo
UnitCastingInfo = function() return nil end
bossOnEvent(bossCastbar, "UNIT_SPELLCAST_STOP", "boss1")
flushTimers()
assert(not bossCastbar:IsVisible(), "a completed boss cast must disappear during combat")
UnitCastingInfo = bossCastingInfo
bossOnEvent(bossCastbar, "UNIT_SPELLCAST_START", "boss1")
assert(bossCastbar:IsVisible(), "the next boss cast must reappear during the same combat")

protectedCallsAllowed = false
timerQueue = {}
bossOnEvent(bossCastbar, "UNIT_SPELLCAST_START", "boss1")
assert(#timerQueue >= 1, "boss cast should queue before destruction")
bossCastbar._quiDestroyed = true
bossHeightCalls = 0
protectedCallsAllowed = true
flushTimers()
assert(bossHeightCalls == 0, "a deferred boss cast must not touch a destroyed castbar")
bossCastbar._quiDestroyed = nil
protectedCallsAllowed = false
bossOnEvent(bossCastbar, "UNIT_SPELLCAST_START", "boss1")
ns.QUI_Castbar.DestroyCastbar(bossCastbar)
flushTimers()
assert(#timerQueue == 0 and bossCastbar._quiPendingCastRetry == nil,
    "boss destruction must cancel retries while permission is still denied")
protectedCallsAllowed = true

-- In combat, a target-change event must NOT run protected geometry synchronously
-- (it could be inside a secure execution context). It must defer Cast().
inCombat = true
setHeightCalls = 0
timerQueue = {}
onEvent(castbar, "PLAYER_TARGET_CHANGED")
assert(setHeightCalls == 0,
    "in combat, PLAYER_TARGET_CHANGED must not run anchorFrame:SetHeight() synchronously "
    .. "(got " .. setHeightCalls .. ") -- secure-execution taint vector")
assert(#timerQueue >= 1,
    "in combat, PLAYER_TARGET_CHANGED must defer Cast() to a later frame")

protectedCallsAllowed = false
flushTimers()
assert(setHeightCalls == 0, "target-change retries must also wait for protected-call permission")
protectedCallsAllowed = true

-- Firing the deferred callback (now outside the secure context) applies the layout.
flushTimers()
assert(setHeightCalls >= 1,
    "the deferred cast should apply the layout once outside the secure context "
    .. "(got " .. setHeightCalls .. ")")

-- A deferred callback whose castbar was destroyed before it fires must no-op.
inCombat = true
timerQueue = {}
onEvent(castbar, "PLAYER_TARGET_CHANGED")
assert(#timerQueue >= 1, "expected a deferred cast to be queued")
castbar._quiDestroyed = true
setHeightCalls = 0
flushTimers()
assert(setHeightCalls == 0,
    "a deferred cast for a destroyed castbar must not touch the orphaned frame")
castbar._quiDestroyed = nil

inCombat = false
protectedCallsAllowed = false
timerQueue = {}
setHeightCalls = 0
castbar:Cast(116, false, true)
assert(setHeightCalls == 0, "direct Cast calls must respect permission denial outside combat")
assert(#timerQueue == 1, "direct Cast calls must queue recovery when denied")
castbar._quiDestroyed = true
protectedCallsAllowed = true
flushTimers()
assert(setHeightCalls == 0, "a deferred spellcast must not touch a destroyed castbar")
assert(#timerQueue == 0, "destroying a castbar must stop its deferred retries")
castbar._quiDestroyed = nil

-- Out of combat there is no restriction: the cast runs synchronously, no defer.
inCombat = false
setHeightCalls = 0
timerQueue = {}
onEvent(castbar, "PLAYER_TARGET_CHANGED")
assert(setHeightCalls >= 1,
    "out of combat, PLAYER_TARGET_CHANGED should run the cast synchronously "
    .. "(got " .. setHeightCalls .. ")")

inCombat = false
settings.target.castbar.anchor = "unitframe"
local realPinFrameToTargetAbsolute = ns.Helpers.PinFrameToTargetAbsolute
local pinAvailable = false
ns.Helpers.PinFrameToTargetAbsolute = function(...)
    if not pinAvailable then return false end
    return realPinFrameToTargetAbsolute(...)
end
timerQueue = {}

local unavailableCastbar = assert(ns.QUI_Castbar:CreateCastbar(unitFrame, "target", "target"))
flushTimers()
local unavailablePoint, unavailableRelativeTo = unavailableCastbar:GetPoint()
assert(unavailablePoint and unavailableRelativeTo == UIParent,
    "failed initial and deferred pins must leave the castbar positioned relative to UIParent")
assert(not unavailableCastbar:IsAnchoringRestricted(),
    "persistent unreadable geometry must not restrict the castbar")

local fallbackCastbar = assert(ns.QUI_Castbar:CreateCastbar(unitFrame, "target", "target"))
assert(not fallbackCastbar:IsAnchoringRestricted(),
    "failed absolute pin must not fall back to the protected unit frame")

pinAvailable = true
flushTimers()
assert(not fallbackCastbar:IsAnchoringRestricted(),
    "deferred absolute pin must keep the castbar unrestricted")
local fallbackPoint, fallbackRelativeTo, fallbackRelativePoint = fallbackCastbar:GetPoint()
assert(fallbackPoint == "TOP" and fallbackRelativeTo == UIParent and fallbackRelativePoint == "BOTTOMLEFT",
    "deferred absolute pin must recover the castbar position")

inCombat = true
local fallbackOnEvent = assert(fallbackCastbar.scripts and fallbackCastbar.scripts.OnEvent)
local ok, err = pcall(fallbackOnEvent, fallbackCastbar,
    "UNIT_SPELLCAST_START", "target", "CastGUID", 116)
assert(ok, "restricted-anchor fallback must not block spellcast layout: " .. tostring(err))

ns.Helpers.PinFrameToTargetAbsolute = realPinFrameToTargetAbsolute
protectedCallsAllowed = true
inCombat = false
timerQueue = {}

local function assertPinned(bar, target, xOffset, yOffset, message)
    local point, relative, relativePoint, x, y = bar:GetPoint()
    local targetScale = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local barScale = bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local expectedX = (target:GetLeft() + target:GetWidth() / 2) * targetScale + xOffset
    local expectedY = target:GetBottom() * targetScale + yOffset
    assert(point == "TOP" and relative == UIParent and relativePoint == "BOTTOMLEFT", message .. ": must remain isolated from the protected target")
    assert(math.abs(x * barScale - expectedX) < 0.01 and math.abs(y * barScale - expectedY) < 0.01,
        message .. ": expected " .. expectedX .. "," .. expectedY .. "; got " .. x * barScale .. "," .. y * barScale)
end

local firstBoss = newRegion("Frame", UIParent)
firstBoss.protected = true
firstBoss:SetSize(220, 40)
firstBoss:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 100, 300)
local secondBoss = newRegion("Frame", UIParent)
secondBoss.protected = true
secondBoss:SetSize(220, 40)
secondBoss:SetPoint("TOPLEFT", firstBoss, "BOTTOMLEFT", 0, -30)
local firstBossBar = assert(ns.QUI_Castbar:CreateBossCastbar(firstBoss, "boss1", 1))
local secondBossBar = assert(ns.QUI_Castbar:CreateBossCastbar(secondBoss, "boss2", 2))
local originalCast = firstBossBar.Cast
firstBossBar:Cast(true)
local originalUpdate = firstBossBar.scripts.OnUpdate
firstBoss:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 700, 400)
inCombat = true
flushTimers()
assertPinned(firstBossBar, firstBoss, 0, -25, "boss castbar must follow saved layout during combat reload")
assertPinned(secondBossBar, secondBoss, 0, -25, "stacked boss castbar must follow inherited movement")
assert(firstBossBar.Cast == originalCast and firstBossBar.scripts.OnUpdate == originalUpdate,
    "position refresh must preserve the active cast and its update handler")

local function dispatchEvent(event)
    for _, frame in ipairs(createdFrames) do
        if frame.events and frame.events[event] and frame.scripts and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, event)
        end
    end
end

ns.QUI_Anchoring:ApplyAllFrameAnchors(function()
    firstBoss.points[1][4] = 850
    firstBoss.points[1][5] = 450
end)
assertPinned(firstBossBar, firstBoss, 0, -25, "saved layout completion must immediately update boss castbars")
assertPinned(secondBossBar, secondBoss, 0, -25, "saved layout completion must update stacked castbars")

local siblings = {}
for _, key in ipairs({"player", "target", "focus", "pet", "targettarget"}) do
    local config = {}
    for name, value in pairs(settings.target.castbar) do config[name] = value end
    config.anchor, config.offsetX, config.offsetY, config.widthAdjustment = "unitframe", 7, -19, 3
    settings[key] = {castbar = config}
    local target = newRegion("Frame", UIParent)
    target.protected = true
    target:SetSize(240, 50)
    target:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 600)
    local bar = assert(ns.QUI_Castbar:CreateCastbar(target, key, key))
    siblings[key] = {bar = bar, target = target}
    target:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 500, 350)
    target:SetSize(280, 60)
    flushTimers()
    assertPinned(bar, target, 7, -19, key .. " castbar must follow its unit frame during combat")
    assert(bar:GetWidth() == 286, key .. " castbar must retain automatic width after target resize")
end

local viewers = {}
_G.QUI_GetCDMViewerFrame = function(key) return viewers[key] end
_G.QUI_GetCDMViewerState = function(viewer) return viewer.layoutState end
for _, key in ipairs({"essential", "utility"}) do
    local viewer = newRegion("Frame", UIParent)
    viewer.protected = true
    viewer:SetSize(330, 50)
    viewer:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 400, 300)
    viewers[key] = viewer
    viewer.layoutState = {layoutDir = "HORIZONTAL", bottomRowYOffset = -12}
    settings.focus.castbar.anchor = key
    local bar = assert(ns.QUI_Castbar:CreateCastbar(siblings.focus.target, "focus", "focus"))
    viewer:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 550, 425)
    viewer:SetSize(360, 70)
    flushTimers()
    assertPinned(bar, viewer, 7, -31, key .. " CDM castbar must follow settled viewer geometry")
    assert(bar:GetWidth() == 366, key .. " CDM castbar must follow viewer width")
    viewer.layoutState.bottomRowYOffset = -27.4
    viewer:SetSize(360, 100)
    flushTimers()
    assertPinned(bar, viewer, 7, -46, key .. " CDM castbar must use the current rounded bottom-row offset during combat")
    viewer.layoutState.layoutDir = "VERTICAL"
    viewer:SetSize(70, 360)
    flushTimers()
    assertPinned(bar, viewer, 7, -19, key .. " vertical CDM layout must discard horizontal row adjustment")
end

for key, anchorKey in pairs({target = "targetCastbar", targettarget = "totCastbar"}) do
    local ownedBar = siblings[key].bar
    _G.QUI_HasFrameAnchor = function(candidate) return candidate == anchorKey end
    ownedBar:ClearAllPoints()
    ownedBar:SetPoint("CENTER", UIParent, "CENTER", 31, 47)
    siblings[key].target:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 900, 700)
    flushTimers()
    local ownedPoint, _, _, ownedX, ownedY = ownedBar:GetPoint()
    assert(ownedPoint == "CENTER" and ownedX == 31 and ownedY == 47,
        key .. " default castbar following must not overwrite its saved generic layout anchor")
end
_G.QUI_HasFrameAnchor = nil

local destroyedBar = siblings.pet.bar
siblings.pet.target:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 300, 200)
ns.QUI_Castbar.DestroyCastbar(destroyedBar)
flushTimers()
assert(destroyedBar:GetNumPoints() == 0 and not destroyedBar:IsShown(),
    "queued pin refresh must not reposition or show a destroyed castbar")
siblings.pet.target:SetSize(350, 70)
flushTimers()
assert(destroyedBar:GetNumPoints() == 0,
    "future target changes must not revive a destroyed castbar")

firstBoss.points[1][4] = 625
firstBoss.points[1][5] = 375
dispatchEvent("PLAYER_ENTERING_WORLD")
flushTimers()
assertPinned(firstBossBar, firstBoss, 0, -25, "entering-world settling must refresh existing castbar positions")

firstBoss:SetScale(1.25)
flushTimers()
assertPinned(firstBossBar, firstBoss, 0, -25, "castbar pin must follow target scale changes")

firstBossBar:SetScale(0.8)
flushTimers()
assertPinned(firstBossBar, firstBoss, 0, -25, "castbar pin must preserve screen position after its own scale changes")

local _, _, _, allowedX, allowedY = firstBossBar:GetPoint()
protectedCallsAllowed = false
firstBoss:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 475, 325)
flushTimers()
local _, _, _, deniedX, deniedY = firstBossBar:GetPoint()
assert(allowedX == deniedX and allowedY == deniedY,
    "pin refresh must not mutate castbar geometry while protected functions are denied")
protectedCallsAllowed = true
dispatchEvent("PLAYER_REGEN_ENABLED")
flushTimers()
assertPinned(firstBossBar, firstBoss, 0, -25, "deferred geometry must recover after combat")

local sizedBoss = newRegion("Frame", UIParent)
sizedBoss.protected = true
sizedBoss:SetSize(220, 40)
sizedBoss:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 400, 500)
local configuredBossWidth = settings.boss.castbar.width
settings.boss.castbar.width = 0
local autoWidthBossBar = assert(ns.QUI_Castbar:CreateBossCastbar(sizedBoss, "boss3", 3))
settings.boss.castbar.width = 190
local fixedWidthBossBar = assert(ns.QUI_Castbar:CreateBossCastbar(sizedBoss, "boss4", 4))
settings.boss.castbar.width = configuredBossWidth
sizedBoss:SetSize(320, 60)
flushTimers()
assert(autoWidthBossBar:GetWidth() == 320, "automatic boss castbar width must follow saved boss-frame sizing")
assert(fixedWidthBossBar:GetWidth() == 190, "explicit boss castbar width must survive boss-frame sizing")

local ancestor = newRegion("Frame", UIParent)
ancestor:SetSize(500, 200)
ancestor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 100, 100)
firstBoss:SetPoint("BOTTOMLEFT", ancestor, "BOTTOMLEFT", 20, 30)
siblings.target.target:SetPoint("BOTTOMLEFT", ancestor, "BOTTOMLEFT", 40, 50)
flushTimers()
ancestor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 300, 225)
firstBossBar:Cast(true)
secondBossBar:Cast(true)
siblings.target.bar:Cast(116, false, true)
assertPinned(firstBossBar, firstBoss, 0, -25, "boss cast start must catch inherited ancestor movement")
assertPinned(secondBossBar, secondBoss, 0, -25, "stacked boss cast start must catch inherited ancestor movement")
assertPinned(siblings.target.bar, siblings.target.target, 7, -19, "ordinary cast start must catch inherited ancestor movement")
ancestor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 425, 325)
firstBossBar.scripts.OnUpdate(firstBossBar, 0.1)
secondBossBar.scripts.OnUpdate(secondBossBar, 0.1)
siblings.target.bar.scripts.OnUpdate(siblings.target.bar, 0.1)
assertPinned(firstBossBar, firstBoss, 0, -25, "active boss cast must follow inherited ancestor movement")
assertPinned(secondBossBar, secondBoss, 0, -25, "active stacked boss cast must follow inherited ancestor movement")
assertPinned(siblings.target.bar, siblings.target.target, 7, -19, "active ordinary cast must follow inherited ancestor movement")

local layoutModeActive = true
_G.QUI_IsLayoutModeActive = function() return layoutModeActive end
local mover = newRegion("Frame", UIParent)
mover:SetSize(280, 18)
mover:SetPoint("CENTER", UIParent, "CENTER", 250, 175)
local movedBar = siblings.target.bar
movedBar:ClearAllPoints()
movedBar:SetPoint("CENTER", mover, "CENTER", 11, 13)
movedBar:Cast(116, false, true)
movedBar.scripts.OnUpdate(movedBar, 0.1)
siblings.target.target:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 600, 550)
flushTimers()
local moverPoint, moverRelative, moverRelativePoint, moverX, moverY = movedBar:GetPoint()
assert(moverPoint == "CENTER" and moverRelative == mover and moverRelativePoint == "CENTER" and moverX == 11 and moverY == 13,
    "active cast and queued geometry refresh must preserve Layout Mode's temporary mover anchor")
layoutModeActive = false
ns.QUI_Anchoring:ApplyAllFrameAnchors()
assertPinned(movedBar, siblings.target.target, 7, -19, "leaving Layout Mode must resume default castbar following")
_G.QUI_IsLayoutModeActive = nil

print("OK: unitframes_castbar_combat_layout_taint_test")
