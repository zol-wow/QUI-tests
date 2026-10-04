local function noop() end
local function newFrame(x, y)
    local f = { x = x or 500, y = y or 400, width = 80, height = 40, scripts = {} }
    function f:GetCenter() return self.x, self.y end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetSize() return self.width, self.height end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:GetLeft() return self.x - self.width / 2 end
    function f:GetRight() return self.x + self.width / 2 end
    function f:GetTop() return self.y + self.height / 2 end
    function f:GetBottom() return self.y - self.height / 2 end
    function f:SetPoint(point, parent, relative, ox, oy)
        assert(point == "CENTER" and relative == "CENTER")
        self.x, self.y = parent.x + (ox or 0), parent.y + (oy or 0)
    end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:SetText(text) self.text = text end
    function f:IsShown() return true end
    function f:IsMouseOver() return false end
    function f:GetEffectiveScale() return 1 end
    f.ClearAllPoints, f.EnableKeyboard, f.RegisterEvent = noop, noop, noop
    f.SetAlpha, f.SetColor, f.SetLineSize, f.Hide, f.Show = noop, noop, noop, noop, noop
    f._coords, f._label, f._bg, f._border = f, f, f, f
    return f
end

UIParent = newFrame()
UIParent.width, UIParent.height = 1000, 800
CreateFrame = newFrame
C_Timer = { After = noop }
GameTooltip = { Hide = noop }
LibStub = function() return nil end
InCombatLockdown = function() return false end
local cursorX, cursorY, shiftHeld = 500, 400, false
GetCursorPosition = function() return cursorX, cursorY end
IsShiftKeyDown = function() return shiftHeld end
local fa = {}
local core = { db = { profile = { frameAnchoring = fa } } }
local ns = {
    Helpers = { GetCore = function() return core end, SafeToNumber = tonumber },
    UIKit = { GetPixelSize = function() return 1 end },
    L = setmetatable({}, { __index = function(_, key) return key end }),
    SafeCall = function(_, fn, ...) return fn(...) end,
    SafeCallMethod = function(_, frame, method, ...) return frame[method](frame, ...) end,
}
assert(loadfile("modules/layout/layoutmode.lua"))("QUI", ns)
assert(loadfile("modules/layout/layoutmode_ui.lua"))("QUI", ns)
local LM, UI = ns.QUI_LayoutMode, ns.QUI_LayoutMode_UI

local function findUpvalue(wanted)
    local seen = {}
    local function visit(fn)
        if type(fn) ~= "function" or seen[fn] then return end
        seen[fn] = true
        for i = 1, math.huge do
            local name, value = debug.getupvalue(fn, i)
            if not name then break end
            if name == wanted then return value end
            local found = visit(value)
            if found then return found end
        end
    end
    for _, fn in pairs(LM) do
        local found = visit(fn)
        if found then return found end
    end
    error("Missing production upvalue: " .. wanted)
end

local addScripts = findUpvalue("AddHandleScripts")
local commit = findUpvalue("CommitPositions")
local snapshot = findUpvalue("SnapshotPositions")
local revert = findUpvalue("RevertPositions")

local function setup(pending)
    for key in pairs(fa) do fa[key] = nil end
    LM._pendingPositions, LM._handles, LM._elements = {}, {}, {}
    LM.isActive, LM._hasChanges = true, false
    shiftHeld, UI.snapEnabled = false, false
    for _, key in ipairs({ "parent", "child" }) do
        local h = newFrame(key == "child" and 600 or 500, 400)
        local frame = newFrame(h.x, h.y)
        h._barKey = key
        LM._handles[key] = h
        LM._elements[key] = { key = key, getFrame = function() return frame end }
        addScripts(h, LM._elements[key])
    end
    fa.child = { parent = "parent", point = "LEFT", relative = "RIGHT", offsetX = 20, offsetY = 0 }
    if pending then
        LM._pendingPositions.child = {
            point = "CENTER", relPoint = "CENTER", offsetX = 100, offsetY = 0,
            anchorTarget = "parent", anchorPointSelf = "LEFT", anchorPointTarget = "RIGHT",
        }
    end
    return LM._handles.child, LM._handles.parent
end

local function fire(h, event, ...)
    assert(h.scripts[event], "Missing event: " .. event)(h, ...)
end

local h, parent = setup(true)
snapshot()
fire(h, "OnMouseUp", "MiddleButton")
assert(fa.child.parent == "disabled", "middle-click must detach the saved anchor")
assert(not LM:IsElementAnchored("child"), "detached mover must be unlocked")
cursorX, cursorY = h:GetCenter()
fire(h, "OnDragStart")
assert(not h._anchorGroupHandles or not h._anchorGroupHandles.parent,
    "a detached mover must not collect its former parent into the next drag")
cursorX, cursorY = cursorX + 75, cursorY + 25
fire(h, "OnUpdate")
assert(parent.x == 500 and parent.y == 400, "dragging a detached mover must leave its former parent in place")
fire(h, "OnDragStop")
commit()
assert(fa.child.parent == "disabled", "saving the next drag must preserve detachment")
assert(fa.child.offsetX == 175 and fa.child.offsetY == 25, "saving must retain the independent position")
revert()
assert(fa.child.parent == "parent", "discard must restore the original anchor snapshot")

h = setup(true)
fire(h, "OnMouseUp", "MiddleButton")
LM:NudgeMover("child", 5, 0)
assert(fa.child.parent == "disabled", "nudging must not restore a stale pending anchor")
commit()
assert(fa.child.parent == "disabled" and fa.child.offsetX == 105,
    "saving a detached nudge must retain free placement")

h = setup(true)
fire(h, "OnMouseUp", "MiddleButton")
commit()
assert(fa.child.parent == "disabled", "saving immediately after middle-click must not restore the pending anchor")

h, parent = setup(true)
local follower = newFrame(h.x + 100, h.y)
local followerFrame = newFrame(follower.x, follower.y)
follower._barKey = "follower"
LM._handles.follower = follower
LM._elements.follower = { key = "follower", getFrame = function() return followerFrame end }
fa.follower = { parent = "child", point = "CENTER", relative = "CENTER", offsetX = 100, offsetY = 0 }
fire(h, "OnMouseUp", "MiddleButton")
cursorX, cursorY = h:GetCenter()
fire(h, "OnDragStart")
assert(h._anchorGroupHandles and h._anchorGroupHandles.follower,
    "detaching from a parent must preserve the mover's own anchored children")
cursorX = cursorX + 25
fire(h, "OnUpdate")
assert(follower.x == 725 and parent.x == 500,
    "only the retained descendant must follow a detached mover's drag")
fire(h, "OnDragStop")
commit()
assert(fa.child.parent == "disabled" and fa.follower.parent == "child",
    "saving must preserve the detached root and its retained descendants")

h = setup(true)
local savedX, savedY
LM._elements.child.savePosition = function(_, _, _, x, y) savedX, savedY = x, y end
LM:DetachElementAnchor("child")
commit()
assert(fa.child.parent == "disabled" and savedX == 100 and savedY == 0,
    "shared detach must retain pending coordinates for custom position savers")

h, parent = setup(false)
h._snapAnchorKey, h._snapAnchorPointSelf, h._snapAnchorPointTarget = "parent", "LEFT", "RIGHT"
fire(h, "OnMouseUp", "MiddleButton")
cursorX, cursorY = h:GetCenter()
fire(h, "OnDragStart")
cursorX = cursorX + 200
fire(h, "OnUpdate")
fire(h, "OnDragStop")
assert(fa.child.parent == "disabled", "a new drag with snapping disabled must not reuse the previous snap anchor")
commit()
assert(fa.child.parent == "disabled", "saving must preserve detachment with snapping disabled")

h, parent = setup(true)
fire(h, "OnMouseUp", "MiddleButton")
cursorX, cursorY, shiftHeld = h.x, h.y, true
fire(h, "OnDragStart")
cursorX = parent.x + parent.width
fire(h, "OnUpdate")
assert(h._snapAnchorKey == "parent", "Shift-drag must still allow a new intentional anchor")
fire(h, "OnDragStop")
commit()
assert(fa.child.parent == "parent", "a new intentional anchor must survive saving")

print("OK: layoutmode_detach_anchor_test")
