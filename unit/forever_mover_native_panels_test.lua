local nativeRoot = "tests/clients/forever/framexml/Interface/AddOns/Blizzard_UIParentPanelManager/Shared/"
local combat, nativeCall, delegate, boot
local frames, queued = {}, {}
local function noop() end
local Frame = {}
Frame.__index = Frame
function Frame:GetName() return self.name end
function Frame:GetParent() return self.parent end
function Frame:IsProtected() return self.protected end
function Frame:IsForbidden() return self.forbidden end
function Frame:SetForbidden() self.forbidden = true; delegate = self end
function Frame:GetAttribute(name) return self.attributes[name] end
function Frame:SetAttributeNoHandler(name, value) self.attributes[name] = value end
function Frame:SetAttribute(name, value)
    self.attributes[name] = value
    if self.scripts.OnAttributeChanged then
        local old = nativeCall
        nativeCall = self.forbidden or old
        self.scripts.OnAttributeChanged(self, name, value)
        nativeCall = old
    end
end
function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:GetScript(name) return self.scripts[name] end
function Frame:HookScript(name, fn) self.hooks[name] = fn end
function Frame:SetPoint(...)
    assert(not self.protected or nativeCall, "insecure SetPoint on protected frame")
    assert(not self.protected or not combat, "protected layout changed in combat")
    self.point = {...}
    self.placements = self.placements + 1
end
function Frame:ClearAllPoints()
    assert(not self.protected or nativeCall, "insecure ClearAllPoints on protected frame")
    self.point = nil
end
function Frame:GetPoint() return unpack(self.point or {}) end
function Frame:GetNumPoints() return self.point and 1 or 0 end
function Frame:SetScale() error("Forever must preserve protected scale") end
function Frame:GetScale() return self.scale end
function Frame:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:GetTop() return self.height end
function Frame:GetRight() return self.width end
function Frame:IsShown() return self.shown end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:SetShown(value) self.shown = value end
function Frame:IsMouseOver() return false end
function Frame:GetFrameLevel() return 1 end
function Frame:GetFrameStrata() return "MEDIUM" end
function Frame:Execute() error("Forever restricted compiler unavailable") end
for _, name in ipairs({"RegisterEvent", "SetAllPoints", "SetFrameStrata", "SetFrameLevel", "EnableMouseWheel", "EnableMouse", "RegisterForDrag", "SetPropagateMouseMotion", "SetPropagateMouseClicks", "SetMovable", "SetClampedToScreen", "Raise", "StartMoving", "StopMovingOrSizing"}) do Frame[name] = noop end
function CreateFrame(_, name, parent, template)
    assert(not template or not template:find("SecureHandler"), "Forever must not create secure script handlers")
    local f = setmetatable({ name = name, parent = parent, attributes = {}, scripts = {}, hooks = {}, width = 300, height = 200, scale = 1, placements = 0, shown = false }, Frame)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = CreateFrame("Frame", "UIParent")
UIParent.width, UIParent.height, UIParent.scale = 1600, 900, 0.8
UIParent.shown = true
RegisterGameMenuEscHandler = noop
GameMenuEscPriority = { AddOnPost = 1 }
function UIPanelWindows_Initialize()
    UIPanelWindows.MailFrame = { area = "left", pushable = 1, xoffset = 7, yoffset = 4 }
    UIPanelWindows.TestCenterPanel = { area = "center", pushable = 0 }
end
assert(loadfile(nativeRoot .. "UIPanelLayoutFrame.lua"))()
assert(loadfile(nativeRoot .. "UIParentPanelManager.lua"))("Blizzard_UIParentPanelManager", {})
local function nativeUpdate() _G.UpdateUIPanelPositions() end
InCombatLockdown = function() return combat end
IsShiftKeyDown = function() return true end
IsControlKeyDown = function() return true end
IsAltKeyDown = function() return false end
C_AddOns = { IsAddOnLoaded = function() return false end }
C_Timer = { After = function(_, fn) queued[#queued + 1] = fn end }
RunNextFrame = function(fn) queued[#queued + 1] = fn end
hooksecurefunc = noop
wipe = function(t) for k in pairs(t) do t[k] = nil end end

local profile = { blizzardMover = { enabled = true, scaleEnabled = true, positionPersistence = "reset", frames = {
    MailFrame = { point = "CENTER", x = 100, y = 30, scale = 1.7 },
    TestCenterPanel = { point = "BOTTOMRIGHT", x = -100, y = 230 },
    UnknownPanel = { point = "CENTER", x = 100, y = 100 },
} } }
local ns = { Client = { restrictedExecutionUnavailable = true }, Helpers = {
    GetProfile = function() return profile end,
    FrameMutationRestricted = function(frame) return frame:IsProtected() end,
}, Addon = { RegisterPostInitialize = function(_, callback) boot = callback end },
SafeCall = function(_, fn, ...) return pcall(fn, ...) end }
assert(loadfile(os.getenv("QUI_MOVER_SOURCE") or "modules/qol/blizzard_mover.lua"))("QUI", ns)
local mover = ns.QUI_BlizzardMover
mover.functions.InitDB()
local function register(name, slot, scale)
    local f = CreateFrame("Frame", name, UIParent)
    f.protected, f.scale, f.shown = true, scale or 1, true
    if slot then delegate[slot] = f; nativeUpdate() end
    mover.functions.RegisterFrame({ id = name, secureFrame = true, reassertOnDrift = true, useRootHandle = true })
    return f
end
local function closeTo(actual, expected, message)
    assert(math.abs(actual - expected) < 0.001, message .. ": " .. tostring(actual) .. " expected " .. tostring(expected))
end
local function tick()
    for _, frame in ipairs(frames) do if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame) end end
end
local mail = register("MailFrame", "left", 0.75)
local point, _, relPoint, x, y = mail:GetPoint()
assert(point == "TOPLEFT" and relPoint == "TOPLEFT", "native delegate uses its own anchor representation")
closeTo(x, 1600 / 0.75 / 2 + 100 - 150, "CENTER saved X converted at current scale")
closeTo(y, -900 / 0.75 / 2 + 30 + 100, "CENTER saved Y converted at current scale")
assert(mail.scale == 0.75, "saved custom scale remains unapplied")
local count = mail.placements
for _ = 1, 12 do tick() end
assert(mail.placements == count, "native anchor representation must not trigger drift loop")
nativeUpdate()
count = mail.placements
for _ = 1, 5 do tick() end
assert(mail.placements == count, "native relayout retains saved offset without repeated reassert")

local secretAnchor = {}
local ordinaryGetPoint = mail.GetPoint
mail.GetPoint = function() return "TOPLEFT", UIParent, "TOPLEFT", secretAnchor, 0 end
issecretvalue = function(value) return value == secretAnchor end
mover.functions.applyFrameSettings(mail, "MailFrame")
mail.GetPoint = ordinaryGetPoint
_G.SetUIPanelAttribute(mail, "xoffset", 900)
nativeUpdate()
count = mail.placements
tick()
assert(mail.placements > count, "secret anchor capture must retain drift recovery when coordinates become readable")
closeTo(mail.point[4], 1600 / 0.75 / 2 + 100 - 150, "readable drift restores saved X after secret anchor capture")

profile.blizzardMover.frames.MailFrame.y = -2000
mover.functions.applyFrameSettings(mail, "MailFrame")
local _, _, _, _, clampedY = mail:GetPoint()
closeTo(clampedY, (140 + mail.height * mail.scale - UIParent.height) / mail.scale, "native bottom clamp remains authoritative")
count = mail.placements
for _ = 1, 12 do tick() end
assert(mail.placements == count, "clamped position must not trigger drift loop")
profile.blizzardMover.frames.MailFrame.y = 30
combat = true
mover.functions.applyFrameSettings(mail, "MailFrame")
assert(mail.placements == count, "combat placement defers")
combat = false
boot()
for _, frame in ipairs(frames) do if frame.scripts.OnEvent then frame.scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED") end end
assert(mail.placements > count, "deferred position restores after combat")

profile.blizzardMover.frames.MailFrame.enabled = false
mover.functions.RefreshEntry("MailFrame")
assert(mail:GetAttribute("UIPanelLayout-xoffset") == 7 and mail:GetAttribute("UIPanelLayout-yoffset") == 4, "disable restores native layout attributes")
local _, _, _, defaultX, defaultY = mail:GetPoint()
closeTo(defaultX, 23 / 0.75, "disable restores native X")
closeTo(defaultY, -112 / 0.75, "disable restores native Y")
profile.blizzardMover.frames.MailFrame.enabled = true
mover.functions.RefreshEntry("MailFrame")
profile.blizzardMover.frames.MailFrame.point = nil
mover.functions.RefreshEntry("MailFrame")
assert(mail:GetAttribute("UIPanelLayout-xoffset") == 7, "clearing position restores attributes even when a saved scale remains")

profile.blizzardMover.positionPersistence = "close"
mover.variables.openPositions.MailFrame = { point = "TOPLEFT", x = 300, y = -250 }
mover.functions.applyFrameSettings(mail, "MailFrame")
mail:Hide()
delegate.left = nil
tick()
assert(mail:GetAttribute("UIPanelLayout-xoffset") == 7 and mail:GetAttribute("UIPanelLayout-yoffset") == 4, "close mode restores native attributes on hide")
mail:Show()
delegate.left = mail
nativeUpdate()
tick()
assert(mover.variables.openPositions.MailFrame == nil, "close mode does not revive old saved position")

profile.blizzardMover.positionPersistence = "reset"
profile.blizzardMover.frames.MailFrame.point = "CENTER"
mover.functions.applyFrameSettings(mail, "MailFrame")
combat = true
profile.blizzardMover.frames.MailFrame.enabled = false
mover.functions.RefreshEntry("MailFrame")
assert(mail:GetAttribute("UIPanelLayout-xoffset") ~= 7, "disable defers protected native reset in combat")
combat = false
for _, frame in ipairs(frames) do if frame.scripts.OnEvent then frame.scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED") end end
assert(mail:GetAttribute("UIPanelLayout-xoffset") == 7, "deferred disable resets after combat")

mail:Hide()
delegate.left = nil
local center = register("TestCenterPanel", "center", 1.25)
point, _, relPoint, x, y = center:GetPoint()
assert(point == "TOP" and relPoint == "TOP", "center native panels retain TOP anchor")
closeTo(x, 1600 / 1.25 / 2 - 100 - 150, "centerXOffset accounts for saved BOTTOMRIGHT")
closeTo(y, -900 / 1.25 + 230 + 200, "center panel saved Y converts to native TOP")
local unknown = register("UnknownPanel")
assert(unknown.placements == 0, "unregistered protected panels retain native position")
assert(_G.UIPanelWindows.UnknownPanel == nil, "mover must never register arbitrary panels")
for _, slot in ipairs({ "center", "right", "doublewide" }) do
    delegate.left, delegate.center, delegate.right, delegate.doublewide = nil, nil, nil, nil
    local name = "Pushed" .. slot
    UIPanelWindows[name] = { area = slot == "doublewide" and "doublewide" or "left" }
    profile.blizzardMover.frames[name] = { point = "TOPLEFT", x = 400, y = -150 }
    local pushed = register(name, slot, 1.2)
    local pt, _, _, px, py = pushed:GetPoint()
    assert(pt == "TOPLEFT", "pushed panels retain native TOPLEFT")
    closeTo(px, 400, slot .. " slot base converts saved X")
    closeTo(py, -150, slot .. " slot base converts saved Y")
end

delegate.left, delegate.center, delegate.right, delegate.doublewide = nil, nil, nil, nil
UIPanelWindows.AdaptivePanel = { area = "centerOrLeft" }
profile.blizzardMover.frames.AdaptivePanel = { point = "TOPLEFT", x = 400, y = -150 }
local adaptive = register("AdaptivePanel", "center", 1)
assert(adaptive.point[1] == "TOP", "centerOrLeft centers when alone")
mail.shown, delegate.left = true, mail
nativeUpdate()
mover.functions.applyFrameSettings(adaptive, "AdaptivePanel")
assert(adaptive.point[1] == "TOPLEFT", "centerOrLeft changes native anchor when another panel opens")
closeTo(adaptive.point[4], 400, "adaptive panel position survives native slot change")
profile.blizzardMover.positionPersistence = "lockout"
mover.variables.sessionPositions.AdaptivePanel = { point = "TOPLEFT", x = 450, y = -180 }
mover.functions.applyFrameSettings(adaptive, "AdaptivePanel")
mover.functions.ClearSessionPositions()
assert(adaptive:GetAttribute("UIPanelLayout-xoffset") == nil and adaptive:GetAttribute("UIPanelLayout-centerXOffset") == nil,
    "session reset restores original absent layout attributes")
print("OK forever_mover_native_panels_test")
