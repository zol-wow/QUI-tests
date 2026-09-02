-- tests/unit/uikit_smooth_scroll_test.lua
-- UIKit.AttachSmoothScroll / UIKit.CreateScrollBar (core/uikit.lua): the one
-- easing controller every options scroll frame shares. Drives the driver's
-- OnUpdate with a fake clock and asserts:
--   * wheel notches accumulate on the in-flight TARGET, not the current offset
--   * the offset settles monotonically onto the target (never overshoots) and
--     the driver hides once landed
--   * targets clamp at 0 and at the (pixel-snapped) range
--   * scrollbar drag / click-to-jump cancel the easing and write directly
--   * hiding the scroll frame stops the driver and drops the stale target
--   * a range shrink re-clamps both an in-flight target and a settled offset
--   * ScrollTo(instant) snaps to the pixel grid; wheel snap option rounds to a
--     tile grid
-- Run: luajit tests/unit/uikit_smooth_scroll_test.lua
-- luacheck: globals CreateFrame GetCursorPosition IsMouseButtonDown QUI

local failures = 0
local function check(name, ok, detail)
    if ok then
        print(("  ok  %s"):format(name))
    else
        failures = failures + 1
        print(("FAIL  %s  %s"):format(name, detail or ""))
    end
end

---------------------------------------------------------------------------
-- Frame stubs
---------------------------------------------------------------------------
local cursorY = 0
local mouseDown = false
function GetCursorPosition() return 0, cursorY end
function IsMouseButtonDown() return mouseDown end

local pixelSize = 1
local frames = {}

local function NewTexture()
    local tex = {}
    function tex:SetAllPoints() end
    function tex:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function tex:SetSnapToPixelGrid(v) self.snap = v end
    function tex:SetTexelSnappingBias(v) self.bias = v end
    return tex
end

local function NewFrame(kind, parent)
    local f = {
        kind = kind, parent = parent, scripts = {}, hooks = {}, shown = true,
        level = 1, height = 100, width = 4, top = 200, bottom = 100,
        offset = 0, range = 0, points = {},
    }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:GetScript(name) return self.scripts[name] end
    function f:HookScript(name, fn)
        self.hooks[name] = self.hooks[name] or {}
        table.insert(self.hooks[name], fn)
    end
    function f:Fire(name, ...)
        if self.scripts[name] then self.scripts[name](self, ...) end
        for _, h in ipairs(self.hooks[name] or {}) do h(self, ...) end
    end
    function f:Show() self.shown = true end
    function f:Hide()
        local was = self.shown
        self.shown = false
        if was and self.kind == "ScrollFrame" then self:Fire("OnHide") end
    end
    function f:IsShown() return self.shown end
    function f:EnableMouseWheel(v) self.wheel = v end
    function f:EnableMouse(v) self.mouse = v end
    function f:RegisterForDrag() end
    function f:SetFrameLevel(l) self.level = l end
    function f:GetFrameLevel() return self.level end
    function f:SetWidth(w) self.width = w end
    function f:SetHeight(h) self.height = h end
    function f:GetHeight() return self.height end
    function f:GetWidth() return self.width end
    function f:GetTop() return self.top end
    function f:GetBottom() return self.bottom end
    function f:GetEffectiveScale() return 1 end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:ClearAllPoints() self.points = {} end
    function f:CreateTexture() return NewTexture() end
    function f:SetVerticalScroll(v)
        self.writes = (self.writes or 0) + 1
        self.offset = v
        self:Fire("OnVerticalScroll", v)
    end
    function f:GetVerticalScroll() return self.offset end
    function f:GetVerticalScrollRange() return self.range end
    function f:SetRange(r)
        self.range = r
        self:Fire("OnScrollRangeChanged", 0, r)
    end
    frames[#frames + 1] = f
    return f
end

function CreateFrame(kind, _, parent) return NewFrame(kind, parent) end

local ns = {
    Helpers = {
        CHROME = { BORDER_PX = 1, BG_FALLBACK = { 0.05, 0.05, 0.05, 0.95 }, BORDER_FALLBACK = { 0, 0, 0, 1 }, BUTTON_BOOST = 0.07, SCROLLROW_BOOST = 0.03, DEPTH = { PANEL = { boost = 0, alpha = 0.95 }, SUBPANEL = { boost = 0.04, alpha = 0.85 }, ROW = { boost = 0.07, alpha = 0.75 } } },
        CreateStateTable = function() return setmetatable({}, { __mode = "k" }) end,
        SafeToNumber = function(value, fallback) return tonumber(value) or fallback end,
        IsSecretValue = function() return false end,
    },
}
local core = {}
function core:GetPixelSize() return pixelSize end
function core:Pixels(v) return v * pixelSize end
function ns.Helpers.GetCore() return core end

QUI = { GUI = { Colors = { scrollThumb = { 0.2, 0.8, 0.6, 0.6 }, scrollTrack = { 1, 1, 1, 0.02 } } } }
local accentListeners = {}
function QUI.GUI:OnAccentChanged(fn) accentListeners[#accentListeners + 1] = fn end

assert(loadfile("core/safecall.lua"))("QUI", ns)
assert(loadfile("core/uikit.lua"))("QUI", ns)
local UIKit = ns.UIKit
check("UIKit exposes AttachSmoothScroll + CreateScrollBar + GetSmoothScroll",
    type(UIKit.AttachSmoothScroll) == "function"
    and type(UIKit.CreateScrollBar) == "function"
    and type(UIKit.GetSmoothScroll) == "function")

local function findDriver(sf)
    for _, f in ipairs(frames) do
        if f.parent == sf and f.kind == "Frame" and f.scripts.OnUpdate then return f end
    end
end

local function run(driver, frames_, dt)
    for _ = 1, frames_ do
        if not driver.shown then return end
        driver.scripts.OnUpdate(driver, dt or (1 / 60))
    end
end

---------------------------------------------------------------------------
-- 1. Attach + wheel accumulation on the target
---------------------------------------------------------------------------
local sf = NewFrame("ScrollFrame")
sf.range = 1000
local positions = {}
local ctl = UIKit.AttachSmoothScroll(sf, {
    step = 60,
    onPosition = function(_, offset, settled) positions[#positions + 1] = { offset, settled } end,
})
local driver = findDriver(sf)
check("driver frame is a hidden child of the scroll frame", driver ~= nil and driver.shown == false)
check("attach enables the wheel and installs OnMouseWheel", sf.wheel == true and sf.scripts.OnMouseWheel ~= nil)
check("GetSmoothScroll returns the same controller", UIKit.GetSmoothScroll(sf) == ctl)
check("re-attach returns the existing controller", UIKit.AttachSmoothScroll(sf, { step = 60 }) == ctl)

sf.scripts.OnMouseWheel(sf, -1)
check("one notch down sets target = step", ctl:GetTarget() == 60, tostring(ctl:GetTarget()))
check("driver shows while animating", driver.shown == true and ctl:IsAnimating())
run(driver, 2)
local mid = sf.offset
check("offset moved but has not landed after 2 frames", mid > 0 and mid < 60, tostring(mid))
sf.scripts.OnMouseWheel(sf, -1)
sf.scripts.OnMouseWheel(sf, -1)
check("chained notches accumulate on the target, not the offset", ctl:GetTarget() == 180,
    ("target=%s offset=%s"):format(tostring(ctl:GetTarget()), tostring(sf.offset)))

---------------------------------------------------------------------------
-- 2. Monotonic settle without overshoot; driver hides when landed
---------------------------------------------------------------------------
local last = sf.offset
local monotonic, overshoot = true, false
for _ = 1, 400 do
    if not driver.shown then break end
    driver.scripts.OnUpdate(driver, 1 / 60)
    if sf.offset < last then monotonic = false end
    if sf.offset > 180 then overshoot = true end
    last = sf.offset
end
check("offset lands exactly on the target", sf.offset == 180, tostring(sf.offset))
check("approach is monotonic", monotonic)
check("never overshoots the target", not overshoot)
check("driver hides once settled and target clears", driver.shown == false and not ctl:IsAnimating())
check("final listener call reports settled=true",
    positions[#positions][1] == 180 and positions[#positions][2] == true)
check("interim writes sit on the pixel grid", (function()
    for _, p in ipairs(positions) do
        if p[1] ~= math.floor(p[1]) then return false end
    end
    return true
end)())

-- Large elapsed (stall) jumps straight to the target in one tick.
sf.scripts.OnMouseWheel(sf, -1)
run(driver, 1, 1.0)
check("a long frame lands in one tick", sf.offset == 240 and driver.shown == false, tostring(sf.offset))

---------------------------------------------------------------------------
-- 3. Clamp at 0 and at range
---------------------------------------------------------------------------
for _ = 1, 30 do sf.scripts.OnMouseWheel(sf, 1) end
check("target clamps at 0", ctl:GetTarget() == 0, tostring(ctl:GetTarget()))
run(driver, 400)
check("offset settles at 0", sf.offset == 0 and driver.shown == false)
for _ = 1, 30 do sf.scripts.OnMouseWheel(sf, -1) end
check("target clamps at range", ctl:GetTarget() == 1000, tostring(ctl:GetTarget()))
run(driver, 400)
check("offset settles at range", sf.offset == 1000)
last = sf.offset
sf.scripts.OnMouseWheel(sf, 1)
local upMonotonic = true
for _ = 1, 400 do
    if not driver.shown then break end
    driver.scripts.OnUpdate(driver, 1 / 60)
    if sf.offset > last then upMonotonic = false end
    last = sf.offset
end
check("scrolling up settles monotonically too", upMonotonic and sf.offset == 940, tostring(sf.offset))

-- Wheel on a frame with no range is a no-op.
local flat = NewFrame("ScrollFrame")
flat.range = 0
local flatCtl = UIKit.AttachSmoothScroll(flat, { step = 60 })
flat.scripts.OnMouseWheel(flat, -1)
check("wheel with zero range does nothing", not flatCtl:IsAnimating() and flat.offset == 0)

---------------------------------------------------------------------------
-- 4. Range shrink re-clamps an in-flight target and a settled offset
---------------------------------------------------------------------------
ctl:ScrollTo(0, true)
sf.scripts.OnMouseWheel(sf, -1)
sf.scripts.OnMouseWheel(sf, -1)
sf.scripts.OnMouseWheel(sf, -1)
sf:SetRange(100)
check("in-flight target re-clamps when the range shrinks", ctl:GetTarget() == 100, tostring(ctl:GetTarget()))
run(driver, 400)
check("settles on the new range", sf.offset == 100)
sf:SetRange(40)
check("settled offset pulled back inside a shrunken range", sf.offset == 40 and not ctl:IsAnimating(), tostring(sf.offset))
sf:SetRange(1000)

---------------------------------------------------------------------------
-- 5. ScrollTo: instant vs eased, pixel snapping, shared target
---------------------------------------------------------------------------
ctl:ScrollTo(300, true)
check("ScrollTo(instant) writes directly and stays idle", sf.offset == 300 and not ctl:IsAnimating())
ctl:ScrollTo(500)
check("ScrollTo(eased) shares the wheel target", ctl:IsAnimating() and ctl:GetTarget() == 500)
sf.scripts.OnMouseWheel(sf, 1)
check("wheel during a programmatic scroll builds on that target", ctl:GetTarget() == 440, tostring(ctl:GetTarget()))
ctl:Cancel()
check("Cancel hides the driver and drops the target", driver.shown == false and ctl:GetTarget() == sf.offset)

pixelSize = 0.5
ctl:ScrollTo(10.3, true)
check("instant target snaps to the physical pixel grid (0.5 px)", sf.offset == 10.5, tostring(sf.offset))
ctl:ScrollTo(20.2, true)
check("snap rounds to nearest grid step", sf.offset == 20, tostring(sf.offset))
pixelSize = 1

sf.range = 1000.7
ctl:ScrollTo(5000, true)
check("range snaps DOWN to the pixel grid so the target never exceeds it", sf.offset == 1000, tostring(sf.offset))
sf.range = 1000

-- Wheel snap option (sidebar tiles)
local tiles = NewFrame("ScrollFrame")
tiles.range = 1000
local tileCtl = UIKit.AttachSmoothScroll(tiles, { step = 45, snap = 28 })
tiles.scripts.OnMouseWheel(tiles, -1)
check("snap option rounds wheel targets to the tile grid", tileCtl:GetTarget() == 56, tostring(tileCtl:GetTarget()))
tiles.scripts.OnMouseWheel(tiles, -1)
check("snap keeps accumulating on the grid", tileCtl:GetTarget() == 112, tostring(tileCtl:GetTarget()))

-- Custom getRange (multi-line edit box whose native range lies)
local box = NewFrame("ScrollFrame")
box.range = 0
local boxCtl = UIKit.AttachSmoothScroll(box, { step = 40, getRange = function() return 90 end })
for _ = 1, 5 do box.scripts.OnMouseWheel(box, -1) end
check("getRange overrides the native range", boxCtl:GetTarget() == 90, tostring(boxCtl:GetTarget()))

-- A foreign write mid-easing (template scrollbar drag, direct SetVerticalScroll)
-- hands the offset over: the controller cancels instead of fighting it.
ctl:ScrollTo(0, true)
ctl:ScrollTo(600)
run(driver, 3)
check("easing in flight before the foreign write", ctl:IsAnimating())
sf.offset = 333
run(driver, 1)
check("foreign write cancels the easing", not ctl:IsAnimating() and driver.shown == false)
check("foreign offset is left alone", sf.offset == 333, tostring(sf.offset))
sf.scripts.OnMouseWheel(sf, -1)
check("next notch builds on the foreign offset", ctl:GetTarget() == 393, tostring(ctl:GetTarget()))
run(driver, 400)
check("float-noise read-backs do not cancel", sf.offset == 393, tostring(sf.offset))

-- A settle write is still flagged animating for OnVerticalScroll hooks, so a
-- hook can tell "landed" from "someone else wrote".
ctl:ScrollTo(0, true)
local animatingAtSettle
sf:HookScript("OnVerticalScroll", function(_, v)
    if v == 60 then animatingAtSettle = ctl:IsAnimating() end
end)
ctl:ScrollTo(60)
run(driver, 400)
check("settle write fires OnVerticalScroll while still animating", animatingAtSettle == true)
check("settle then stops", not ctl:IsAnimating())

---------------------------------------------------------------------------
-- 6. Listener add/remove
---------------------------------------------------------------------------
local seen = 0
local function listener() seen = seen + 1 end
ctl:AddListener(listener)
ctl:AddListener(listener)
ctl:ScrollTo(10, true)
check("AddListener dedups and fires on writes", seen == 1, tostring(seen))
ctl:RemoveListener(listener)
ctl:ScrollTo(20, true)
check("RemoveListener stops delivery", seen == 1, tostring(seen))

---------------------------------------------------------------------------
-- 7. Hide cleanup stops the driver
---------------------------------------------------------------------------
ctl:ScrollTo(600)
check("animating before hide", driver.shown == true)
sf:Hide()
check("OnHide cancels the easing and hides the driver", driver.shown == false and not ctl:IsAnimating())
sf:Show()
run(driver, 5)
check("re-show does not resume the stale target", sf.offset == 20, tostring(sf.offset))

---------------------------------------------------------------------------
-- 8. Scrollbar: visibility, geometry, drag cancels easing, click-to-jump
---------------------------------------------------------------------------
sf.height = 100
sf.range = 900     -- content 1000 tall in a 100 px viewport
local bar = UIKit.CreateScrollBar(sf, { minThumb = 30 })
bar.track.height = 100
bar.track.top = 200
bar.track.bottom = 100
check("bar shows while content overflows", bar.track.shown == true and bar.hit.shown == true)
bar:Update()
check("thumb height is proportional with a 30 px floor", bar.thumb.height == 30, tostring(bar.thumb.height))
check("thumb tinted from GUI.Colors.scrollThumb", bar.thumbTexture.color[1] == 0.2 and bar.thumbTexture.color[4] == 0.6)
check("track tinted from GUI.Colors.scrollTrack", bar.trackTexture.color[4] == 0.02)
check("hit button is 16 px wide and invisible (no textures)", bar.hit.width == 16)

ctl:ScrollTo(0, true)
ctl:ScrollTo(450)
check("easing in flight before drag", ctl:IsAnimating())
-- Grab the thumb (thumb spans top 200 -> 170 after Update at offset 0)
bar:Update()
bar.thumb.top = 200
bar.thumb.bottom = 170
cursorY = 185
mouseDown = true
bar.hit.scripts.OnMouseDown(bar.hit, "LeftButton")
check("mouse-down on the thumb cancels the easing", not ctl:IsAnimating() and driver.shown == false)
check("mouse-down on the thumb does not jump", sf.offset == 0, tostring(sf.offset))
cursorY = 185 - 35   -- drag 35 px down over a 70 px travel = half the range
bar.hit.scripts.OnUpdate(bar.hit)
check("drag writes directly: half travel = half range", sf.offset == 450, tostring(sf.offset))
check("drag reports IsDragging", bar:IsDragging())
mouseDown = false
bar.hit.scripts.OnUpdate(bar.hit)
check("drag auto-releases when the button is no longer held", not bar:IsDragging() and bar.hit.scripts.OnUpdate == nil)
check("thumb moved with the drag", bar.thumb.points[#bar.thumb.points][5] == -35, tostring(bar.thumb.points[#bar.thumb.points][5]))

-- Click-to-jump below the thumb: centre the thumb under the cursor
ctl:ScrollTo(0, true)
bar:Update()
bar.thumb.top = 200
bar.thumb.bottom = 170
cursorY = 200 - 15 - 70   -- thumb centre at the bottom of the travel
mouseDown = true
bar.hit.scripts.OnMouseDown(bar.hit, "LeftButton")
check("click-to-jump lands the thumb under the cursor (range end)", sf.offset == 900, tostring(sf.offset))
check("click-to-jump starts a drag", bar:IsDragging())
mouseDown = false
bar.hit.scripts.OnMouseUp(bar.hit, "LeftButton")
check("mouse-up ends the drag", not bar:IsDragging())

sf:SetRange(0)
check("bar hides when content fits", bar.track.shown == false and bar.hit.shown == false)
sf:SetRange(900)
check("bar re-shows on range change", bar.track.shown == true)

QUI.GUI.Colors.scrollThumb[1] = 0.9
for _, fn in ipairs(accentListeners) do fn() end
check("accent change re-tints the thumb", bar.thumbTexture.color[1] == 0.9)

-- A bar on a frame without a controller still clamps direct writes
local bare = NewFrame("ScrollFrame")
bare.range = 50
bare.height = 100
local bareBar = UIKit.CreateScrollBar(bare)
bareBar.track.height = 100
bareBar.track.top = 200
bareBar:Update()
bare.offset = 0
bareBar.thumb.top = 200
bareBar.thumb.bottom = 100
cursorY = 0
mouseDown = true
bareBar.hit.scripts.OnMouseDown(bareBar.hit, "LeftButton")
check("controller-less bar jumps and clamps to range", bare.offset == 50, tostring(bare.offset))
mouseDown = false

if failures > 0 then
    print(("FAILED: %d check(s)"):format(failures))
    os.exit(1)
end
print("OK: uikit_smooth_scroll_test")
