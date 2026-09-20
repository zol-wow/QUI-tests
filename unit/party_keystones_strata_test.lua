local file = assert(io.open(arg[1] or "modules/dungeon/party_keystones.lua", "r"))
local source = file:read("*a")
file:close()

local combat, layoutMode = false, false
local uiParent = { scale = 0.72 }
function uiParent:GetEffectiveScale() return self.scale end
local tracker = { strata = "MEDIUM", level = 2, parent = uiParent, scale = 1, parentsSet = 0 }
function tracker:ClearAllPoints() self.point = nil end
function tracker:SetFrameStrata(strata) self.strata = strata end
function tracker:GetFrameStrata() return self.strata end
function tracker:SetFrameLevel(level) self.level = level end
function tracker:GetFrameLevel() return self.level end
function tracker:GetParent() return self.parent end
function tracker:SetParent(parent)
    assert(not combat, "Protected teleport ancestors cannot be reparented in combat")
    self.parent = parent
    self.parentsSet = self.parentsSet + 1
end
function tracker:SetIgnoreParentScale(ignore) self.ignoreParentScale = ignore end
function tracker:SetScale(scale) self.scale = scale end
function tracker:GetEffectiveScale()
    return self.scale * (self.ignoreParentScale and 1 or self.parent:GetEffectiveScale())
end
function tracker:SetPoint(...) self.point = { ... } end
function tracker:SetScript() end

local settings = {
    keyTrackerPoint = "LEFT",
    keyTrackerRelPoint = "RIGHT",
    keyTrackerOffsetX = 12,
    keyTrackerOffsetY = -8,
}
local env = {
    UIParent = uiParent,
    KeyTrackerFrame = tracker,
    GetSettings = function() return settings end,
    InCombatLockdown = function() return combat end,
    Helpers = { IsSecretValue = function() return false end },
    _G = { QUI_IsLayoutModeActive = function() return layoutMode end },
}
local positionSource = assert(source:match("(local function PositionKeyTracker%(%)\n.-\nend)"))
local layeringSource = source:match("(local function UpdateKeyTrackerLayering%(%)\n.-)\nlocal function PositionKeyTracker") or ""
local chunk = assert(loadstring(layeringSource .. "\n" .. positionSource .. "\nreturn PositionKeyTracker"))
setfenv(chunk, env)
local position = chunk()

position()
assert(tracker.parent == uiParent and tracker.point == nil, "Missing Group Finder must leave the tracker unattached")

env.PVEFrame = {
    level = 1, strata = "MEDIUM", scale = 1.44,
    GetFrameStrata = function(self) return self.strata end,
    GetFrameLevel = function(self) return self.level end,
    GetEffectiveScale = function(self) return self.scale end,
}
local effectiveScale = tracker:GetEffectiveScale()
position()
assert(tracker.parent == env.PVEFrame,
    "The key list must belong to the instance window's frame tree; matching MEDIUM levels 1/2 alone failed live dragging")
assert(tracker:GetEffectiveScale() == effectiveScale, "Attaching to a scaled instance window must preserve the key list's size")
env.PVEFrame.scale = 2.16
assert(tracker:GetEffectiveScale() == effectiveScale, "Instance window scaling must not resize the attached key list")

for _, strata in ipairs({ "MEDIUM", "LOW", "HIGH" }) do
    env.PVEFrame.strata = strata
    position()
    assert(tracker.strata == strata, "Attached keystone list must match instance panel strata: " .. strata)
    assert(tracker.point[1] == "LEFT" and tracker.point[2] == env.PVEFrame
        and tracker.point[3] == "RIGHT" and tracker.point[4] == 12 and tracker.point[5] == -8,
        "Attaching the key list must preserve configured anchors and offsets")
end
assert(tracker.parentsSet == 1, "Refreshing an attached list must not repeatedly reparent it")

local layoutHandle = {}
layoutMode = true
layoutHandle._savedTargetParent = tracker.parent
layoutHandle._savedTargetStrata = tracker.strata
function layoutHandle:GetCenter() return nil end
tracker.parent, tracker.strata = layoutHandle, "DIALOG"
local point = tracker.point
position()
assert(tracker.parent == layoutHandle and tracker.strata == "DIALOG" and tracker.point == point,
    "Layout Mode must keep ownership of the preview parent, strata, and anchors")
layoutMode = false
file = assert(io.open("modules/layout/layoutmode.lua", "r"))
local layoutSource = file:read("*a")
file:close()
local restoreSource = assert(layoutSource:match("(local function RestoreTargetFrame%(.-\nend)"))
local restoreEnv = {
    _G = {},
    ns = { SafeCallMethod = function(_, target, method, ...) return target[method](target, ...) end },
}
chunk = assert(loadstring(restoreSource .. "\nreturn RestoreTargetFrame"))
setfenv(chunk, restoreEnv)
chunk()(layoutHandle, { getFrame = function() return tracker end })
assert(tracker.parent == env.PVEFrame and tracker.strata == "HIGH",
    "Actual Layout Mode restoration must recover the instance parent and strata without refreshing")
assert(tracker:GetEffectiveScale() == effectiveScale, "Layout Mode restoration must preserve the independent scale")

local events = {}
function events:RegisterEvent(event) self[event] = true end
function events:SetScript(_, callback) self.callback = callback end
env.CreateFrame = function() return events end
env.RefreshKeyTracker = position
local visibilityUpdates = 0
env.UpdateVisibility = function() visibilityUpdates = visibilityUpdates + 1 end
local eventSource = assert(source:match('(local eventFrame = CreateFrame%("Frame"%).-)\nif openRaidLib then'))
chunk = assert(loadstring(eventSource))
setfenv(chunk, env)
chunk()

combat = true
tracker.parent = uiParent
point = tracker.point
position()
assert(tracker.parent == uiParent and tracker.point == point, "Combat must defer attachment and preserve existing anchors")
assert(events.PLAYER_REGEN_ENABLED, "Combat-deferred attachment needs a recovery event")
combat = false
events.callback(events, "PLAYER_REGEN_ENABLED")
assert(tracker.parent == env.PVEFrame, "Combat-end must attach the tracker without reopening the panel")

uiParent.scale = 0.9
assert(events.UI_SCALE_CHANGED, "The independent tracker scale must follow main UI scale changes")
events.callback(events, "UI_SCALE_CHANGED")
assert(tracker:GetEffectiveScale() == uiParent.scale, "Changing UI scale must retain the previous UIParent-relative size")
local previousUpdates = visibilityUpdates
layoutMode = true
events.callback(events, "UI_SCALE_CHANGED")
assert(visibilityUpdates == previousUpdates, "UI scale changes during Layout Mode must not hide its preview")
assert(not source:find('SetScript("OnUpdate", UpdateKeyTrackerLayering)', 1, true),
    "Native attachment must replace the unsuccessful per-frame numeric-level polling")

print("OK: party_keystones_strata_test")
