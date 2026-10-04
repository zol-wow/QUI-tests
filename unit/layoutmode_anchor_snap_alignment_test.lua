local function noop() end
local function newFrame(x, y, width, height)
    local f = { x = x or 500, y = y or 400, width = width or 80, height = height or 40, scripts = {} }
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
    f._coords = { SetText = noop, Show = noop, Hide = noop }
    f._label = { SetPoint = noop, SetText = noop }
    f._bg, f._border = f, f
    return f
end

UIParent = newFrame(500, 400, 1000, 800)
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
    Helpers = {
        GetCore = function() return core end,
        SafeToNumber = function(value, fallback) return tonumber(value) or fallback end,
    },
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

local function register(key, x, y, width, height)
    local h, frame = newFrame(x, y, width, height), newFrame(x, y, width, height)
    h._barKey = key
    LM._handles[key] = h
    LM._elements[key] = { key = key, getFrame = function() return frame end }
    addScripts(h, LM._elements[key])
    return h, frame
end

local function setup(snapEnabled, targetY, dragWidth, dragHeight)
    for key in pairs(fa) do fa[key] = nil end
    LM._pendingPositions, LM._handles, LM._elements = {}, {}, {}
    LM.isActive, LM._hasChanges = true, false
    UI.snapEnabled, shiftHeld = snapEnabled, true
    local h, frame = register("child", 700, 600, dragWidth or 80, dragHeight or 40)
    local target = register("target", 200, targetY or 200, 160, 60)
    return h, target, frame
end

local function fire(h, event, ...)
    assert(h.scripts[event], "Missing event: " .. event)(h, ...)
end

local function drag(h, x, y)
    cursorX, cursorY = h:GetCenter()
    fire(h, "OnDragStart")
    cursorX, cursorY = x, y
    fire(h, "OnUpdate")
end

local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function aligned(h, frame, x, y, point, relative, label)
    equal(h.x, x, label .. " handle X")
    equal(h.y, y, label .. " handle Y")
    equal(frame.x, x, label .. " frame X")
    equal(frame.y, y, label .. " frame Y")
    equal(h._snapAnchorKey, "target", label .. " target")
    equal(h._snapAnchorPointSelf, point, label .. " self point")
    equal(h._snapAnchorPointTarget, relative, label .. " target point")
    fire(h, "OnDragStop")
    equal(frame.x, x, label .. " dropped frame X")
    equal(frame.y, y, label .. " dropped frame Y")
    equal(LM._pendingPositions.child.offsetX, x - 500, label .. " pending center X")
    equal(LM._pendingPositions.child.offsetY, y - 400, label .. " pending center Y")
    equal(fa.child.parent, "target", label .. " live parent")
    equal(fa.child.point, point, label .. " live self point")
    equal(fa.child.relative, relative, label .. " live target point")
    equal(fa.child.offsetX, 0, label .. " live gap X")
    equal(fa.child.offsetY, 0, label .. " live gap Y")
    commit()
    equal(fa.child.parent, "target", label .. " saved parent")
    equal(fa.child.point, point, label .. " saved self point")
    equal(fa.child.relative, relative, label .. " saved target point")
    equal(fa.child.offsetX, 0, label .. " saved gap X")
    equal(fa.child.offsetY, 0, label .. " saved gap Y")
end

local cases = {
    { "above left", 163, 255, 160, 250, "BOTTOMLEFT", "TOPLEFT" },
    { "below left", 163, 145, 160, 150, "TOPLEFT", "BOTTOMLEFT" },
    { "above center", 202, 255, 200, 250, "BOTTOM", "TOP" },
    { "above right", 237, 255, 240, 250, "BOTTOMRIGHT", "TOPRIGHT" },
    { "left top", 75, 213, 80, 210, "TOPRIGHT", "TOPLEFT" },
    { "right top", 325, 213, 320, 210, "TOPLEFT", "TOPRIGHT" },
    { "right center", 325, 202, 320, 200, "LEFT", "RIGHT" },
    { "right bottom", 325, 187, 320, 190, "BOTTOMLEFT", "BOTTOMRIGHT" },
}
for _, snapEnabled in ipairs({ false, true }) do
    for _, case in ipairs(cases) do
        local h, _, frame = setup(snapEnabled)
        drag(h, case[2], case[3])
        aligned(h, frame, case[4], case[5], case[6], case[7], case[1] .. " snap " .. tostring(snapEnabled))
    end
    local h, _, frame = setup(snapEnabled, nil, 80, 20)
    drag(h, 163, 233)
    aligned(h, frame, 160, 240, "BOTTOMLEFT", "TOPLEFT", "above shallow overlap snap " .. tostring(snapEnabled))
    h, _, frame = setup(snapEnabled, nil, 80, 20)
    drag(h, 163, 167)
    aligned(h, frame, 160, 160, "TOPLEFT", "BOTTOMLEFT", "below shallow overlap snap " .. tostring(snapEnabled))
    h, _, frame = setup(snapEnabled, nil, 20, 40)
    drag(h, 283, 213)
    aligned(h, frame, 290, 210, "TOPLEFT", "TOPRIGHT", "right shallow overlap snap " .. tostring(snapEnabled))
    h, _, frame = setup(snapEnabled, nil, 20, 40)
    drag(h, 117, 213)
    aligned(h, frame, 110, 210, "TOPRIGHT", "TOPLEFT", "left shallow overlap snap " .. tostring(snapEnabled))
    h, _, frame = setup(snapEnabled, nil, 81, 41)
    drag(h, 163, 256)
    aligned(h, frame, 160.5, 250.5, "BOTTOMLEFT", "TOPLEFT", "odd size seam snap " .. tostring(snapEnabled))
    h, _, frame = setup(snapEnabled, nil, 80.5, 40.5)
    drag(h, 163, 256)
    aligned(h, frame, 160.25, 250.25, "BOTTOMLEFT", "TOPLEFT", "fractional size seam snap " .. tostring(snapEnabled))
    h, _, frame = setup(snapEnabled)
    drag(h, 202, 202)
    aligned(h, frame, 200, 200, "CENTER", "CENTER", "overlapping center anchor snap " .. tostring(snapEnabled))
    for _, size in ipairs({ { 80, 40 }, { 83, 43 } }) do
        h, _, frame = setup(snapEnabled, nil, 81, 41)
        local dx, dy = (81 + size[1]) / 2, (41 + size[2]) / 2
        local follower, followerFrame = register("follower", 700 + dx, 600 + dy, size[1], size[2])
        fa.follower = { parent = "child", point = "BOTTOMLEFT", relative = "TOPRIGHT", offsetX = 0, offsetY = 0 }
        drag(h, 163, 256)
        equal(follower.x, 160.5 + dx, "odd-size root retains follower X")
        equal(follower.y, 250.5 + dy, "odd-size root retains follower Y")
        equal(followerFrame.x, 160.5 + dx, "odd-size root retains follower frame X")
        equal(followerFrame.y, 250.5 + dy, "odd-size root retains follower frame Y")
        aligned(h, frame, 160.5, 250.5, "BOTTOMLEFT", "TOPLEFT", "odd-size root with follower snap " .. tostring(snapEnabled))
        equal(follower.x, 160.5 + dx, "dropped odd-size root retains follower X")
        equal(follower.y, 250.5 + dy, "dropped odd-size root retains follower Y")
        equal(fa.follower.parent, "child", "follower retains parent")
        equal(fa.follower.point, "BOTTOMLEFT", "follower retains self point")
        equal(fa.follower.relative, "TOPRIGHT", "follower retains target point")
        equal(fa.follower.offsetX, 0, "follower retains gap X")
        equal(fa.follower.offsetY, 0, "follower retains gap Y")
        for _ = 1, 2 do
            LM:SyncElement("child")
            LM:SyncElement("follower")
            equal(h.x, 160.5, "refresh retains exact root X")
            equal(h.y, 250.5, "refresh retains exact root Y")
            equal(follower.x, 160.5 + dx, "refresh retains exact follower X")
            equal(follower.y, 250.5 + dy, "refresh retains exact follower Y")
        end
    end
    h = setup(snapEnabled)
    drag(h, 163, 255)
    equal(h._snapAnchorKey, "target", "Shift-release fixture must first preview an anchor")
    shiftHeld = false
    fire(h, "OnUpdate")
    equal(h._snapAnchorKey, nil, "releasing Shift clears the previous target")
    equal(h._snapAnchorPointSelf, nil, "releasing Shift clears the previous self point")
    equal(h._snapAnchorPointTarget, nil, "releasing Shift clears the previous target point")
    fire(h, "OnDragStop")
    commit()
    equal(fa.child.parent, nil, "releasing Shift saves free placement")
end

for _, deferred in ipairs({ false, true }) do
    local h, _, frame = setup(true, nil, 81, 41)
    drag(h, 163, 256)
    aligned(h, frame, 160.5, 250.5, "BOTTOMLEFT", "TOPLEFT", "nudge fixture")
    assert(LM:NudgeMover("child", 1, 0, deferred))
    equal(h.x, 161.5, "horizontal nudge moves exactly one pixel")
    equal(h.y, 250.5, "horizontal nudge preserves flush vertical seam")
    equal(frame.x, 161.5, "horizontal nudge moves live frame exactly one pixel")
    equal(frame.y, 250.5, "horizontal nudge preserves live frame vertical seam")
    if deferred then assert(LM:NudgeMover("child", 0, 0)) end
    equal(fa.child.offsetX, 1, "nudge saves exactly one pixel horizontal gap")
    equal(fa.child.offsetY, 0, "nudge keeps zero vertical gap")
    assert(LM:NudgeMover("child", 0, -1))
    commit()
    equal(fa.child.offsetX, 1, "vertical nudge preserves pending horizontal gap")
    equal(fa.child.offsetY, -1, "vertical nudge saves exactly one pixel vertical gap")
end

local h, _, frame = setup(true, 345)
drag(h, 163, 400)
aligned(h, frame, 160, 395, "BOTTOMLEFT", "TOPLEFT", "screen Y guide must not replace target seam")

for _, snapEnabled in ipairs({ false, true }) do
    local h, _, frame = setup(snapEnabled)
    drag(h, 163, 255)
    equal(h._snapAnchorPointSelf, "BOTTOMLEFT", "gesture starts at left corner")
    cursorX = 202
    fire(h, "OnUpdate")
    equal(h.x, 200, "gesture moves to center")
    equal(h._snapAnchorPointSelf, "BOTTOM", "gesture selects center anchor")
    cursorX = 237
    fire(h, "OnUpdate")
    equal(h.x, 240, "gesture moves to right corner")
    equal(h._snapAnchorPointSelf, "BOTTOMRIGHT", "gesture selects right corner")
    cursorX = 163
    fire(h, "OnUpdate")
    aligned(h, frame, 160, 250, "BOTTOMLEFT", "TOPLEFT", "gesture returns to left corner snap " .. tostring(snapEnabled))
end

h, _, frame = setup(true)
register("remote", 163, 550, 80, 40)
drag(h, 163, 255)
aligned(h, frame, 160, 250, "BOTTOMLEFT", "TOPLEFT", "remote X guide must not replace target cross alignment")

h, _, frame = setup(true)
shiftHeld = false
register("remote", 163, 550, 80, 40)
drag(h, 163, 255)
equal(h.x, 163, "ordinary drag retains remote X guide")
equal(h.y, 250, "ordinary drag retains independent target Y guide")
equal(h._snapAnchorKey, nil, "ordinary drag creates no anchor")
fire(h, "OnDragStop")
commit()
equal(fa.child.parent, nil, "ordinary drag saves free placement")
equal(fa.child.offsetX, -337, "ordinary drag saved X")
equal(fa.child.offsetY, -150, "ordinary drag saved Y")

h, _, frame = setup(false)
shiftHeld = false
drag(h, 163, 255)
equal(h.x, 163, "ordinary drag with Snap Off retains X")
equal(h.y, 255, "ordinary drag with Snap Off retains Y")
equal(h._snapAnchorKey, nil, "Snap Off ordinary drag creates no anchor")
fire(h, "OnDragStop")

h = setup(true)
fa.target = { parent = "child", point = "CENTER", relative = "CENTER", offsetX = -500, offsetY = -400 }
drag(h, 163, 255)
assert(h._anchorGroupKeys and h._anchorGroupKeys.target, "fixture must collect the descendant")
equal(h._snapAnchorKey, nil, "Shift drag must not anchor to its excluded descendant")
fire(h, "OnDragStop")
commit()
equal(fa.child.parent, nil, "excluded descendant must not become the root's parent")
equal(fa.target.parent, "child", "descendant must retain its existing parent")

print("OK: layoutmode_anchor_snap_alignment_test")
