local function noop() end
local function pointOffset(frame, point)
    local x, y = 0, 0
    if point:find("LEFT") then x = -frame:GetWidth() / 2
    elseif point:find("RIGHT") then x = frame:GetWidth() / 2 end
    if point:find("TOP") then y = frame:GetHeight() / 2
    elseif point:find("BOTTOM") then y = -frame:GetHeight() / 2 end
    return x, y
end
local function newFrame(x, y, width, height)
    local f = { x = x or 500, y = y or 400, width = width or 80, height = height or 40 }
    function f:GetCenter()
        if self.follow then return self.follow:GetCenter() end
        return self.x, self.y
    end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetSize() return self:GetWidth(), self:GetHeight() end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:GetLeft() return self:GetCenter() - self:GetWidth() / 2 end
    function f:GetRight() return self:GetCenter() + self:GetWidth() / 2 end
    function f:GetTop() local _, cy = self:GetCenter(); return cy + self:GetHeight() / 2 end
    function f:GetBottom() local _, cy = self:GetCenter(); return cy - self:GetHeight() / 2 end
    function f:SetPoint(point, parent, relative, ox, oy)
        local px, py = parent:GetCenter()
        local rx, ry = pointOffset(parent, relative)
        local sx, sy = pointOffset(self, point)
        self.follow = nil
        self.x, self.y = px + rx + (ox or 0) - sx, py + ry + (oy or 0) - sy
    end
    function f:SetAllPoints(parent) self.follow = parent end
    function f:GetParent() return self.parent end
    function f:GetObjectType() return "Frame" end
    function f:GetEffectiveScale() return 1 end
    function f:IsShown() return true end
    f.ClearAllPoints, f.SetFrameStrata, f.SetFrameLevel = noop, noop, noop
    f.SetScript, f.SetText, f.Show, f.Hide, f.SetLineSize, f.RegisterEvent = noop, noop, noop, noop, noop, noop
    f._coords = { SetText = noop, Show = noop, Hide = noop }
    f._label = { SetPoint = noop }
    return f
end
UIParent = newFrame(500, 400, 1000, 800)
CreateFrame = function() return newFrame() end
C_Timer = { After = noop }
LibStub = function() return nil end
local combat = false
InCombatLockdown = function() return combat end
local anchors = {}
local core = { db = { profile = { frameAnchoring = anchors } } }
local reportedErrors = {}
geterrorhandler = function()
    return function(err) reportedErrors[#reportedErrors + 1] = err end
end
local ns = {
    Helpers = {
        GetCore = function() return core end,
        SafeToNumber = function(value, fallback) return tonumber(value) or fallback end,
    },
    UIKit = { GetPixelSize = function() return 1 end },
    L = setmetatable({}, { __index = function(_, key) return key end }),
}
assert(loadfile("core/safecall.lua"))("QUI", ns)
assert(loadfile(arg[1] or "modules/layout/layoutmode.lua"))("QUI", ns)
local LM = ns.QUI_LayoutMode
local file = assert(io.open(arg[2] or "modules/layout/anchoring.lua", "r"))
local source = file:read("*a")
file:close()
local first = assert(source:find("_G.QUI_ReassertAnchorAfterResize = function(key)", 1, true))
local last = assert(source:find("_G.QUI_ReanchorFramePositionOnly", first, true))
local chunk = assert(loadstring(source:sub(first, last - 1)))
setfenv(chunk, setmetatable({ ns = ns, QUICore = core,
    GetSavedFrameAnchorSettings = function(db, key) return db and db[key] end,
}, { __index = _G }))
chunk()
local applied = {}
_G.QUI_ForceReapplyFrameAnchor = function(key)
    applied[#applied + 1] = key
    assert(#applied < 50, "resize must terminate even when saved anchors contain a cycle")
    local settings, def = anchors[key], LM._elements[key]
    if not settings or not def or not settings.parent or settings.parent == "disabled" then return end
    local parent = settings.parent == "screen" and UIParent or LM._elements[settings.parent].getFrame()
    def.getFrame():SetPoint(settings.point, parent, settings.relative, settings.offsetX, settings.offsetY)
end
local function register(key, overlay, parent)
    local frame, handle = newFrame(600, 500, 80.5, 40.5), newFrame(600, 500, 80.5, 40.5)
    LM._elements[key] = { key = key, getFrame = function() return frame end }
    LM._handles[key] = handle
    handle._barKey = key
    if overlay then
        handle._isChildOverlay, handle._parentFrame, handle.follow = true, frame, frame
        function handle:GetWidth() return frame:GetWidth() end
        function handle:GetHeight() return frame:GetHeight() end
    else
        handle._savedTargetParent, frame.parent = UIParent, handle
    end
    if parent then
        anchors[key] = { parent = parent, point = "TOPLEFT", relative = parent == "screen" and "CENTER" or "BOTTOMRIGHT",
            offsetX = 7.25, offsetY = -5.75 }
        _G.QUI_ForceReapplyFrameAnchor(key)
    end
    LM:SyncElement(key)
    return frame, handle
end
local function pending(key)
    local frame = LM._elements[key].getFrame()
    local x, y = frame:GetCenter()
    local entry = anchors[key]
    local value = { offsetX = x - 500, offsetY = y - 400,
        anchorTarget = entry and entry.parent, anchorPointSelf = entry and entry.point,
        anchorPointTarget = entry and entry.relative }
    LM._pendingPositions[key] = value
    return value
end
local function aligned(key)
    local entry, frame = anchors[key], LM._elements[key].getFrame()
    local parent = entry.parent == "screen" and UIParent or LM._elements[entry.parent].getFrame()
    local px, py = parent:GetCenter()
    local rx, ry = pointOffset(parent, entry.relative)
    local sx, sy = pointOffset(frame, entry.point)
    local x, y = frame:GetCenter()
    assert(x + sx == px + rx + entry.offsetX, key .. " must retain its horizontal anchor gap")
    assert(y + sy == py + ry + entry.offsetY, key .. " must retain its vertical anchor gap")
    local hx, hy = LM._handles[key]:GetCenter()
    assert(hx == x and hy == y, key .. " handle must match its frame")
end
local function reset()
    for key in pairs(anchors) do anchors[key] = nil end
    LM._elements, LM._handles, LM._pendingPositions = {}, {}, {}
    LM.isActive, LM._combatSuspended, combat = true, false, false
    applied = {}
end
for _, overlay in ipairs({ false, true }) do
    for _, callback in ipairs({ "shared", "sync" }) do
        reset()
        local root = register("root", overlay, "screen")
        register("child", not overlay, "root")
        register("grandchild", overlay, "child")
        register("greatgrandchild", not overlay, "grandchild")
        register("unrelated", true)
        local detached = register("detached", true, "root")
        anchors.detached.parent = "disabled"
        local detachedPending = pending("detached")
        local detachedX, detachedY = detached:GetCenter()
        register("custom", true, "root")
        LM._elements.custom.usesCustomPositionPersistence = true
        local unrelated, custom = pending("unrelated"), pending("custom")
        local saved = {}
        for _, key in ipairs({ "root", "child", "grandchild", "greatgrandchild" }) do
            aligned(key)
            saved[key] = pending(key)
            LM:SyncElement(key)
            assert(LM._pendingPositions[key] == saved[key], "unchanged size must preserve pending " .. key)
        end
        for _, size in ipairs({ { 130.5, 90.5 }, { 50.5, 20.5 } }) do
            root:SetSize(size[1], size[2])
            if callback == "sync" then LM:SyncElement("root") else _G.QUI_ReassertAnchorAfterResize("root") end
            for _, key in ipairs({ "root", "child", "grandchild", "greatgrandchild" }) do
                aligned(key)
                assert(anchors[key].offsetX == 7.25 and anchors[key].offsetY == -5.75,
                    "resize must preserve fractional saved gaps")
                pending(key)
            end
            assert(LM._pendingPositions.unrelated == unrelated, "resize must preserve unrelated free pending placement")
            assert(LM._pendingPositions.custom == custom, "resize must preserve custom persistence pending placement")
            assert(LM._pendingPositions.detached == detachedPending, "resize must preserve detached child pending placement")
            local dx, dy = detached:GetCenter()
            assert(dx == detachedX and dy == detachedY, "resizing a former parent must not move its detached child")
        end
    end
end
for _, overlay in ipairs({ false, true }) do
    reset()
    local root = register("root", overlay)
    local free = pending("root")
    register("child", not overlay, "root")
    pending("child")
    root:SetSize(130.5, 90.5)
    _G.QUI_ReassertAnchorAfterResize("root")
    aligned("child")
    assert(LM._pendingPositions.root == free, "free parent resize must preserve its pending position")
end
for _, overlay in ipairs({ false, true }) do
    reset()
    local root = register("root", overlay, "screen")
    LM._elements.root.usesCustomPositionPersistence = true
    local custom = pending("root")
    custom.offsetX, custom.offsetY = 31.25, -42.75
    LM:SyncElement("root")
    register("child", not overlay, "root")
    pending("child")
    root:SetSize(130.5, 90.5)
    applied = {}
    _G.QUI_ReassertAnchorAfterResize("root")
    assert(LM._pendingPositions.root == custom, "custom root must preserve pending placement despite stale anchor settings")
    local x, y = root:GetCenter()
    assert(x == 531.25 and y == 357.25, "custom root resize must retain its pending center")
    assert(#applied == 1 and applied[1] == "child", "stale custom root anchors must not be reapplied")
    aligned("child")
end
for _, guard in ipairs({ "combat", "drag" }) do
    reset()
    local root = register("root", true, "screen")
    register("child", false, "root")
    local savedRoot, savedChild = pending("root"), pending("child")
    root:SetSize(130.5, 90.5)
    applied = {}
    if guard == "combat" then combat = true else LM._handles.child._dragging = true end
    _G.QUI_ReassertAnchorAfterResize("root")
    assert(#applied == 0, guard .. " must prevent anchor mutation")
    assert(LM._pendingPositions.root == savedRoot and LM._pendingPositions.child == savedChild,
        guard .. " must preserve pending positions")
end
reset()
register("root", true, "screen")
register("child", false, "root")
anchors.root.parent = "child"
applied = {}
_G.QUI_ReassertAnchorAfterResize("root")
assert(#applied <= 2, "each member of an anchor cycle must be applied at most once")
assert(#reportedErrors == 0, "resize fixtures must complete without suppressed errors")
reset()
local root = register("root", true, "screen")
register("child", false, "root")
pending("root")
pending("child")
root:SetSize(130.5, 90.5)
local reapply = _G.QUI_ForceReapplyFrameAnchor
_G.QUI_ForceReapplyFrameAnchor = function(key)
    if key == "child" then error("injected resize anchor failure") end
    return reapply(key)
end
_G.QUI_ReassertAnchorAfterResize("root")
assert(not LM._resizingAnchors, "an anchor error must release the resize reentry guard")
assert(#reportedErrors == 1 and tostring(reportedErrors[1]):find("injected resize anchor failure", 1, true),
    "unexpected anchor errors must reach the real SafeCall error handler")
_G.QUI_ForceReapplyFrameAnchor = reapply
root:SetSize(150.5, 110.5)
_G.QUI_ReassertAnchorAfterResize("root")
aligned("root")
aligned("child")
assert(not LM._resizingAnchors and #reportedErrors == 1, "later resizes must recover without suppressed failures")
print("OK: layoutmode_resize_anchor_chain_test")
