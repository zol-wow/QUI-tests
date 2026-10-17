local H = (dofile("tests/helpers/spell_reminders.lua"))()
local R, layout = H.R, H.ns.QUI_LayoutMode
local createFrame = CreateFrame
local registrations = 0
local register = layout.RegisterElement
function layout:RegisterElement(def)
    registrations = registrations + 1
    register(self, def)
end
_G.CreateFrame = function(kind, name, parent, ...)
    local frame = createFrame(kind, name, parent, ...)
    frame.level = parent and parent:GetFrameLevel() + 1 or 1
    function frame:SetFrameLevel(level) self.level = level end
    function frame:EnableMouse(enabled) self.mouseEnabled = enabled end
    function frame:GetEffectiveScale() return self.scale or 1 end
    function frame:StartMoving() self.moving = true end
    function frame:StopMovingOrSizing() self.moving = false end
    function frame:GetCenter() return self.centerX or 500, self.centerY or 400 end
    local setShown = frame.SetShown
    function frame:SetShown(value)
        local wasShown = self:IsShown()
        setShown(self, value)
        if wasShown and not value and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    return frame
end
function UIParent:GetEffectiveScale() return 0.64 end
local config = R.Add(10060)
local host = R.hosts[10060]
host.scale = 0.8
assert(host.drag.mouseEnabled and host.drag:GetFrameLevel() > host.icon.cooldown:GetFrameLevel(),
    "the drag target must receive mouse input above cooldown artwork")
R.Preview(10060, true)
host.drag.scripts.OnDragStart()
assert(host.moving and host.dragging, "preview dragging must start movement")
host.centerX, host.centerY = 600, 300
local points = host.points
R.Update()
R.Refresh()
assert(host.points == points and host.moving, "timer updates and refreshes must preserve an active drag")
host.drag.scripts.OnDragStop()
assert(not host.moving and not host.dragging)
assert(config.x == 250 and config.y == -25, "saved offsets must use UIParent coordinates at different scales")
R.Refresh()
assert(host.points[1][4] == 250 and host.points[1][5] == -25)
H.profile.frameAnchoring["spellReminder:10060"] = { offsetX = 40, offsetY = 80 }
R.Refresh()
host.drag.scripts.OnDragStart()
host.drag.scripts.OnDragStop()
assert(not H.profile.frameAnchoring["spellReminder:10060"], "a free drag must replace the previous anchor")
R.Preview(10060, false)
assert(not host.icon.shown, "the PI preset has no gameplay icon before a cast")
local mover = layout.elements["spellReminder:10060"]
assert(type(mover.onOpen) == "function" and type(mover.onClose) == "function",
    "Layout Mode must own a preview lifecycle")
layout.isActive = true
local before = registrations
mover.onOpen()
assert(host.icon.shown and host.shown and not host.drag.shown,
    "Layout Mode must show the reminder while its own mover receives dragging")
assert(host.sample.shown, "Layout Mode must preview PI recipient alerts at the same anchor")
points = host.points
R.Refresh()
assert(registrations == before and host.points == points,
    "refreshing in Layout Mode must preserve the existing mover and its position")
mover.setGameplayHidden(true)
assert(host.shown, "gameplay hiding must preserve the Layout Mode preview")
layout.isActive = false
mover.onClose()
assert(not host.icon.shown and not host.shown, "closing Layout Mode must restore gameplay visibility")
mover.setGameplayHidden(false)
R.Preview(10060, true)
layout.isActive = true
mover.onOpen()
layout.isActive = false
mover.onClose()
assert(host.icon.shown and host.drag.shown, "Layout Mode must preserve an existing settings preview")
host.drag.scripts.OnDragStart()
R.Preview(10060, false)
assert(not host.moving and not host.dragging, "closing a preview during dragging must stop movement")
R.Preview(10060, true)
host.drag.scripts.OnDragStart()
H.combat = true
H.emit("PLAYER_REGEN_DISABLED")
assert(not host.moving and not host.dragging, "entering combat during dragging must stop movement")
host.drag.scripts.OnDragStart()
assert(not host.moving, "combat must not start a preview drag")
H.combat = false
R.Preview(10060, false)
H.db.enabled = false
assert(not mover.isEnabled(), "the master reminder toggle must disable its Layout Mode mover")
H.db.enabled = true
config.enabled = false
assert(not mover.isEnabled(), "a disabled reminder must have a disabled mover")
R.Remove(10060)
R.Add(10060)
assert(registrations == before + 1, "re-adding a removed reminder must register its mover again")
print("OK: reminder dragging, scale-aware offsets and Layout Mode preview lifecycle")
