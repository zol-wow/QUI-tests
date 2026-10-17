local H = (dofile("tests/helpers/spell_reminders.lua"))({ deferRuntime = true })
local ns = H.ns
local methods = getmetatable(UIParent).__index
local createFontString = methods.CreateFontString
function methods:CreateFontString(name, layer, template)
    local text = createFontString(self)
    if template then text:SetFont("font", 12, "") end
    return text
end
function methods:GetFont() return self.font, self.fontSize, self.fontFlags end
function methods:GetParent() return self.parent end
function methods:SetParent(parent) self.parent = parent end
function methods:GetFrameStrata() return self.strata or "MEDIUM" end
function methods:SetFrameStrata(value) self.strata = value end
function methods:GetFrameLevel() return self.level or 0 end
function methods:SetFrameLevel(value) self.level = value end
function methods:GetScale() return 1 end
function methods:GetAlpha() return self.alpha or 1 end
function methods:SetMovable(value) self.movable = value end
function methods:IsMovable() return self.movable == true end
function methods:IsMouseOver() return false end
function methods:EnableMouse(value) self.mouseEnabled = value end
function methods:EnableKeyboard() end
function methods:SetPropagateKeyboardInput() end
function methods:UnregisterAllEvents() self.events = {} end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetAllPoints(target) self.anchor = target or self.parent end
function methods:SetPoint(...)
    local point = { ... }
    for index, existing in ipairs(self.points) do
        if existing[1] == point[1] then self.points[index] = point; return end
    end
    self.points[#self.points + 1] = point
end
local fractions = {
    TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
    LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
    BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}
local function Rect(frame)
    if frame == UIParent then return 0, 0, frame.width, frame.height end
    if frame.anchor then return Rect(frame.anchor) end
    if #frame.points == 0 then return nil end
    local axes = { {}, {} }
    for _, point in ipairs(frame.points) do
        local target = type(point[2]) == "table" and point[2] or frame.parent
        local left, bottom, width, height = Rect(target)
        if not left then return nil end
        local selfFraction = fractions[point[1]]
        local targetFraction = fractions[type(point[3]) == "string" and point[3] or point[1]]
        axes[1][#axes[1] + 1] = { fraction = selfFraction[1], value = left + width * targetFraction[1] + (point[4] or 0) }
        axes[2][#axes[2] + 1] = { fraction = selfFraction[2], value = bottom + height * targetFraction[2] + (point[5] or 0) }
    end
    local function Solve(points, size)
        local first = points[1]
        for i = 2, #points do
            local other = points[i]
            if other.fraction ~= first.fraction then
                size = (other.value - first.value) / (other.fraction - first.fraction)
                break
            end
        end
        return first.value - first.fraction * size, size
    end
    local left, width = Solve(axes[1], frame.width)
    local bottom, height = Solve(axes[2], frame.height)
    return left, bottom, width, height
end
function methods:GetCenter()
    local left, bottom, width, height = Rect(self)
    if left then return left + width / 2, bottom + height / 2 end
end
function methods:ClearAllPoints() self.points = {}; self.anchor = nil end
function methods:GetLeft() return Rect(self) end
function methods:GetRight() local left, _, width = Rect(self); return left and left + width end
function methods:GetTop() local left, bottom, _, height = Rect(self); return left and bottom + height end
function methods:GetBottom() local _, bottom = Rect(self); return bottom end
function methods:GetWidth() local left, _, width = Rect(self); return left and width or self.width end
function methods:GetHeight() local left, _, _, height = Rect(self); return left and height or self.height end
function methods:GetSize() return self:GetWidth(), self:GetHeight() end
local function Contains(frame, x, y)
    return frame:IsVisible() and frame.mouseEnabled and x >= frame:GetLeft() and x <= frame:GetRight()
        and y >= frame:GetBottom() and y <= frame:GetTop()
end
UIParent:SetSize(1000, 800)
ns.UIKit = { GetPixelSize = function() return 1 end,
        CreateIconButton = function()
            return {SetPoint=function()end, SetFrameLevel=function()end,
                Show=function()end, Hide=function()end, IsMouseOver=function()return false end}
        end }
ns.Helpers.SafeToNumber = function(value, fallback) return type(value) == "number" and value or fallback end
ns.SafeCall = function(_, callback, ...)
    local ok, result = pcall(callback, ...)
    assert(ok, result)
    return ok, result
end
ns.SafeCallMethod = function(_, owner, method, ...)
    return ns.SafeCall(nil, owner[method], owner, ...)
end
local pending = {}
C_Timer.After = function(delay, callback)
    if delay == 0 then pending[#pending + 1] = callback end
end
local function Flush()
    local current = pending
    pending = {}
    for _, callback in ipairs(current) do callback() end
end
local cursorX, cursorY = 500, 200
GetCursorPosition = function() return cursorX, cursorY end
IsShiftKeyDown = function() return false end
GameTooltip = {
    Hide = function(self) self.shown = false end,
    SetOwner = function(self, owner) self.owner = owner end,
    ClearLines = function(self) self.lines = {} end,
    AddLine = function(self, text) self.lines[#self.lines + 1] = text end,
    Show = function(self) self.shown = true end,
}
LibStub = function() return nil end
wipe = function(value) for key in pairs(value) do value[key] = nil end; return value end
assert(loadfile("modules/layout/layoutmode.lua"))("QUI", ns)
local layout = ns.QUI_LayoutMode
layout._firstOpenDone = true
local settingsKey
ns.QUI_LayoutMode_Settings = {
    Show = function(_, key) settingsKey = key end,
    Reset = function() settingsKey = nil end,
    Hide = function() settingsKey = nil end,
    IsShown = function() return settingsKey ~= nil end,
}
H.LoadRuntime()
local R = H.R
layout:Open()
Flush()
R.Add(10060)
local host = R.hosts[10060]
local key = "spellReminder:10060"
Flush()
local handle = assert(layout._handles[key], "Layout Mode must create the reminder mover")
assert(handle._isChildOverlay and handle:GetParent() == host,
    "reminders must use the standard owned-frame overlay without reparenting their aura host")
assert(handle._bg and handle._border and handle._label and handle._coords and handle._groupLabel,
    "reminder movers must have the same visuals as other Layout Mode widgets")
assert(handle:IsVisible() and handle.mouseEnabled and host.icon:IsShown() and not host.drag:IsShown(),
    "the Layout Mode overlay must be visible and own reminder mouse input")
cursorX, cursorY = host.sample:GetCenter()
assert(Contains(handle, cursorX, cursorY), "the visible PI Recipient panel must be inside the actual mover hit area")
assert(handle._groupLabel:IsShown() and handle._coords:IsShown(),
    "the expanded preview mover must show the standard group and coordinate labels")
handle.scripts.OnEnter(handle)
assert(GameTooltip.shown and GameTooltip.owner == handle and GameTooltip.lines[2] == "Drag to move",
    "hovering the PI Recipient panel must show the standard mover tooltip")
handle.scripts.OnMouseUp(handle, "RightButton")
assert(layout._selectedKey == key and settingsKey == key,
    "the real mover click must select the reminder and open its settings")
local function Drag(dx, dy)
    cursorX, cursorY = host.sample:GetCenter()
    assert(Contains(handle, cursorX, cursorY), "the recipient panel must receive the drag")
    handle.scripts.OnDragStart(handle)
    assert(handle._dragging and handle.scripts.OnUpdate, "the real mover must begin dragging")
    cursorX, cursorY = cursorX + dx, cursorY + dy
    handle.scripts.OnUpdate(handle)
    handle.scripts.OnDragStop(handle)
end
Drag(80, 45)
assert(H.profile.frameAnchoring[key].offsetX == 80 and H.profile.frameAnchoring[key].offsetY == -155,
    "the real mover must save its drag through the normal anchor contract")
layout:SaveAndClose()
R.Refresh()
local x, y = host:GetCenter()
assert(x == 580 and y == 245, "saved Layout Mode movement must survive reminder refresh")
layout:Open()
Flush()
handle = layout._handles[key]
Drag(-35, 20)
layout:DiscardAndClose()
R.Refresh()
x, y = host:GetCenter()
assert(x == 580 and y == 245 and H.profile.frameAnchoring[key].offsetX == 80,
    "discard must restore the previous reminder anchor")
layout:Open()
Flush()
R.Add(29166)
local added = R.hosts[29166]
local addedHandle = layout._handles["spellReminder:29166"]
assert(added:GetCenter() ~= nil and addedHandle and addedHandle:IsVisible(),
    "a reminder added during Layout Mode must start positioned with a visible mover")
assert(added.layoutPreview and added.icon:IsShown(),
    "a reminder added during Layout Mode must receive its preview lifecycle")
local anchoredKey = "spellReminder:12345"
H.profile.frameAnchoring[anchoredKey] = {
    parent = "screen", point = "CENTER", relative = "CENTER", offsetX = -140, offsetY = 75,
}
R.Add(12345)
local anchored = R.hosts[12345]
local anchoredHandle = layout._handles[anchoredKey]
x, y = anchored:GetCenter()
assert(x == 360 and y == 475 and anchoredHandle._isChildOverlay and anchoredHandle:IsVisible(),
    "initial registration in active Layout Mode must apply saved anchors to the real owned overlay")
R.Remove(12345)
assert(not layout._handles[anchoredKey] and not anchored.layoutPreview,
    "removing an active reminder must release its mover and preview")
R.Add(12345)
x, y = anchored:GetCenter()
assert(R.hosts[12345] == anchored and x == 360 and y == 475 and anchored.layoutPreview,
    "re-adding a parked reminder during Layout Mode must restore its anchor and preview")
assert(layout._handles[anchoredKey]._isChildOverlay and layout._handles[anchoredKey]:IsVisible(),
    "re-adding a reminder must restore the standard owned overlay")
R.Remove(10060)
R.Add(10060)
handle = layout._handles[key]
cursorX, cursorY = host.sample:GetCenter()
assert(R.hosts[10060] == host and Contains(handle, cursorX, cursorY),
    "re-adding PI during Layout Mode must restore the recipient panel mover bounds")
layout:DiscardAndClose()
assert(not added.layoutPreview, "closing Layout Mode must clear dynamically registered previews")
assert(not anchored.layoutPreview, "closing Layout Mode must clear re-registered previews")
assert(R.Get(10060).x == 0 and R.Get(10060).y == -200, "Layout Mode must preserve fallback position settings")
R.Preview(10060, true)
cursorX, cursorY = host.sample:GetCenter()
assert(Contains(host.drag, cursorX, cursorY), "settings Preview drag bounds must include the recipient panel")
host.drag.scripts.OnDragStart()
assert(host.dragging, "the settings preview must accept dragging from the recipient panel")
host.drag.scripts.OnDragStop()
R.Preview(10060, false)
local currentConfig = R.Get(10060)
currentConfig.size = 180
R.Preview(10060, true)
assert(host.drag:GetRight() >= host.icon:GetRight(), "preview bounds must include imported icons wider than the sample")
R.Preview(10060, false)
print("OK: actual reminder Layout Mode overlay, drag, save, discard and active registration")

layout:Open()
Flush()
handle = layout._handles[key]
Drag(15, -10)
local pendingPosition = layout._pendingPositions[key]
local pendingX, pendingY = host:GetCenter()
R.Refresh()
Flush()
local refreshedX, refreshedY = host:GetCenter()
assert(layout._handles[key] == handle and layout._pendingPositions[key] == pendingPosition
    and refreshedX == pendingX and refreshedY == pendingY,
    "an unchanged enabled refresh must preserve the active handle and its pending position")
for _, size in ipairs({250, 100}) do
    currentConfig.size = size
    R.Refresh()
    Flush()
    refreshedX, refreshedY = host:GetCenter()
    assert(handle:GetWidth() == (size == 250 and 250 or 140) and handle:GetRight() >= host.icon:GetRight(),
        "editing icon size in Layout Mode must grow or shrink its mover around the icon and PI recipient sample")
    assert(layout._handles[key] == handle and layout._pendingPositions[key] == pendingPosition
        and refreshedX == pendingX and refreshedY == pendingY,
        "resizing a reminder must preserve its existing handle, pending position and host center")
end
addedHandle = layout._handles["spellReminder:29166"]
for _, size in ipairs({96, 32}) do
    R.Get(29166).size = size
    R.Refresh()
    Flush()
    assert(layout._handles["spellReminder:29166"] == addedHandle and addedHandle:GetWidth() == size,
        "ordinary reminder movers must follow icon size edits without replacing their handles")
end
currentConfig.enabled = false
R.Refresh()
Flush()
assert(not layout._handles[key] and not host.layoutPreview and not host.icon:IsShown() and not host.sample:IsShown(),
    "disabling an existing reminder through settings must release its mover and Layout Mode preview")
R.Preview(10060, true)
assert(not layout._handles[key] and not host.layoutPreview and host.icon:IsShown() and host.sample:IsShown(),
    "an explicitly requested settings preview must remain available while the reminder is disabled")
R.Preview(10060, false)
currentConfig.enabled = true
R.Refresh()
Flush()
handle = assert(layout._handles[key], "re-enabling an existing reminder through settings must restore its mover")
assert(handle:IsVisible() and host.layoutPreview and host.icon:IsShown() and host.sample:IsShown(),
    "re-enabling a reminder must restore its visible icon and recipient preview")
H.db.enabled = false
R.Refresh()
Flush()
assert(not layout._handles[key] and not layout._handles["spellReminder:29166"]
    and not host.layoutPreview and not added.layoutPreview and not host.sample:IsShown(),
    "disabling the reminder master switch must release every existing mover and preview")
H.db.enabled = true
R.Refresh()
Flush()
handle = assert(layout._handles[key], "re-enabling the master switch must restore existing reminder movers")
assert(handle:IsVisible() and host.layoutPreview and host.icon:IsShown() and host.sample:IsShown()
    and layout._handles["spellReminder:29166"] and added.layoutPreview,
    "re-enabling the master switch must restore each enabled reminder preview")
layout:DiscardAndClose()
print("OK: settings and master toggles reconcile existing reminder movers without resetting unchanged positions")
