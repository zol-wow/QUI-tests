-- tests/unit/options_tooltip_service_test.lua
-- Behaviour pins for the options-owned tooltip service (GUI.Tooltip in
-- QUI_Options/framework.lua): the two persistent AnimationGroups, owner
-- tracking, the showOptionTooltips gate, anchor presets, screen clamp and
-- accent re-tint. The service block is extracted between its BEGIN/END
-- markers and run against a minimal frame/AnimationGroup stub.
-- Run: luajit tests/unit/options_tooltip_service_test.lua
-- luacheck: globals CreateFrame UIParent GetCursorPosition GetScreenWidth GetScreenHeight issecretvalue

local fails = 0
local function check(name, ok, detail)
    if ok then
        print("  ok  " .. name)
    else
        fails = fails + 1
        print("FAIL  " .. name .. (detail and ("  " .. tostring(detail)) or ""))
    end
end

local function readAll(path)
    local f = assert(io.open(path, "rb"))
    local d = f:read("*a"); f:close()
    return (d:gsub("\r\n", "\n"))
end

local src = readAll("QUI_Options/framework.lua")
local startAt = assert(src:find("-- BEGIN GUI.Tooltip service", 1, true), "BEGIN marker")
local endAt = assert(src:find("-- END GUI.Tooltip service", startAt, true), "END marker")
local block = src:sub(startAt, endAt - 1)

---------------------------------------------------------------------------
-- Stubs
---------------------------------------------------------------------------
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
issecretvalue = function(v) return v == SECRET end

local callLog = {}
local function log(entry) callLog[#callLog + 1] = entry end

local function NewAnimation()
    local anim = {}
    function anim:SetFromAlpha(a) self.fromAlpha = a end
    function anim:SetToAlpha(a) self.toAlpha = a end
    function anim:SetDuration(d) self.duration = d end
    function anim:SetSmoothing(s) self.smoothing = s end
    return anim
end

local function NewAnimationGroup(name)
    local group = { name = name, playing = false, scripts = {}, anims = {} }
    function group:CreateAnimation(kind)
        local anim = NewAnimation()
        anim.kind = kind
        self.anims[#self.anims + 1] = anim
        return anim
    end
    function group:SetScript(handler, fn) self.scripts[handler] = fn end
    function group:Play() self.playing = true; self.playCount = (self.playCount or 0) + 1; log(self.name .. ":Play") end
    function group:Stop() self.playing = false; self.stopCount = (self.stopCount or 0) + 1; log(self.name .. ":Stop") end
    function group:IsPlaying() return self.playing end
    -- test helper: run to completion
    function group:Finish()
        self.playing = false
        if self.scripts.OnFinished then self.scripts.OnFinished(self) end
    end
    return group
end

local function NewFontString()
    local fs = { shown = false, width = 0, text = "", stringWidth = 80, stringHeight = 12 }
    function fs:SetJustifyH(j) self.justifyH = j end
    function fs:SetJustifyV(j) self.justifyV = j end
    function fs:SetWordWrap(w) self.wordWrap = w end
    function fs:SetTextColor(r, g, b, a) self.color = { r, g, b, a } end
    function fs:SetWidth(w) self.width = w end
    function fs:SetText(t) self.text = t end
    function fs:SetFont(path, size, flags) self.font = { path, size, flags } end
    function fs:Show() self.shown = true end
    function fs:Hide() self.shown = false end
    function fs:GetStringWidth() return self.stringWidth end
    function fs:GetStringHeight() return self.stringHeight end
    function fs:ClearAllPoints() self.points = {} end
    function fs:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
    return fs
end

local frameCounter = 0
local function NewFrame(parent)
    frameCounter = frameCounter + 1
    local frame = { id = frameCounter, parent = parent, shown = false, alpha = 1, scale = 1, points = {}, fontStrings = {}, groups = {} }
    frame.geometry = { left = 100, right = 200, top = 300, bottom = 250 }
    function frame:SetFrameStrata(s) self.strata = s end
    function frame:SetFrameLevel(l) self.level = l end
    function frame:GetFrameLevel() return self.level or 1 end
    function frame:EnableMouse(e) self.mouse = e end
    function frame:SetSize(w, h) self.w, self.h = w, h end
    function frame:SetAlpha(a) self.alpha = a end
    function frame:GetAlpha() return self.alpha end
    function frame:Show() self.shown = true; log("frame:Show") end
    function frame:Hide() self.shown = false; log("frame:Hide") end
    function frame:IsShown() return self.shown end
    function frame:SetScale(s) self.scale = s end
    function frame:GetScale() return self.scale end
    function frame:GetEffectiveScale() return self.scale end
    function frame:GetParent() return self.parent end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function frame:GetPoint(i)
        local p = self.points[i or 1]
        if not p then return nil end
        return p[1], p[2], p[3], p[4], p[5]
    end
    function frame:GetLeft() return self.geometry.left end
    function frame:GetRight() return self.geometry.right end
    function frame:GetTop() return self.geometry.top end
    function frame:GetBottom() return self.geometry.bottom end
    function frame:CreateTexture()
        local tex = {}
        function tex:SetAllPoints() end
        function tex:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
        self.bgTexture = tex
        return tex
    end
    function frame:CreateFontString()
        local fs = NewFontString()
        self.fontStrings[#self.fontStrings + 1] = fs
        return fs
    end
    function frame:CreateAnimationGroup()
        local name = (#self.groups == 0) and "fadeIn" or "fadeOut"
        local group = NewAnimationGroup(name)
        self.groups[#self.groups + 1] = group
        return group
    end
    return frame
end

UIParent = NewFrame(nil)
UIParent.scale = 1
GetCursorPosition = function() return 400, 300 end
GetScreenWidth = function() return 1000 end
GetScreenHeight = function() return 800 end

local createdFrames = {}
CreateFrame = function(_, name, parent)
    local f = NewFrame(parent)
    f.name = name
    createdFrames[#createdFrames + 1] = f
    return f
end

local borderUpdates = {}
local ns = {
    Helpers = { IsSecretValue = function(v) return v == SECRET end },
    UIKit = {
        CreateBorderLines = function() end,
        UpdateBorderLines = function(_, _, r, g, b, a) borderUpdates[#borderUpdates + 1] = { r, g, b, a } end,
    },
    SafeCall = function(_, fn, ...)
        local ok, ret = pcall(fn, ...)
        return ok, ret
    end,
}
local QUI = { db = { profile = { general = { showOptionTooltips = true } } } }
local panel = NewFrame(UIParent)
panel.scale = 0.8
local accentListeners = {}
local GUI = {
    MainFrame = panel,
    GetFontPath = function() return "TestFont.ttf" end,
    OnAccentChanged = function(_, fn) accentListeners[#accentListeners + 1] = fn; return true end,
}
local C = {
    bg = { 0.05, 0.07, 0.09, 0.97 },
    borderStrong = { 1, 1, 1, 0.1 },
    accentText = { 0.2, 0.8, 0.6, 1 },
    text = { 1, 1, 1, 1 },
}

local loader = loadstring or load
local chunk = assert(loader("return function(ns, QUI, GUI, C)\n" .. block .. "\nend", "GUI.Tooltip"))
chunk()(ns, QUI, GUI, C)
local Tooltip = GUI.Tooltip
check("service exported as GUI.Tooltip", type(Tooltip) == "table" and type(Tooltip.Show) == "function")

local function panelChild()
    local f = NewFrame(panel)
    return f
end

local function shownLines(tip)
    local out = {}
    for _, fs in ipairs(tip._fontStrings) do
        if fs.shown then out[#out + 1] = fs end
    end
    return out
end

---------------------------------------------------------------------------
-- Frame + AnimationGroup construction
---------------------------------------------------------------------------
local tip = Tooltip:GetFrame()
check("frame created lazily on TOOLTIP strata, hidden", tip.strata == "TOOLTIP" and tip.shown == false)
check("frame is parented to UIParent", tip.parent == UIParent)
check("two persistent AnimationGroups", #tip.groups == 2 and tip._fadeIn == tip.groups[1] and tip._fadeOut == tip.groups[2])
local fadeInAnim, fadeOutAnim = tip._fadeIn.anims[1], tip._fadeOut.anims[1]
check("fade-in Alpha 0->1, 0.25s, OUT",
    fadeInAnim.kind == "Alpha" and fadeInAnim.fromAlpha == 0 and fadeInAnim.toAlpha == 1
    and fadeInAnim.duration == 0.25 and fadeInAnim.smoothing == "OUT")
check("fade-out Alpha ->0, 0.25s, IN",
    fadeOutAnim.kind == "Alpha" and fadeOutAnim.toAlpha == 0
    and fadeOutAnim.duration == 0.25 and fadeOutAnim.smoothing == "IN")
check("fade-out anim exposed for SetFromAlpha", tip._fadeOutAnim == fadeOutAnim)
check("second GetFrame returns the same frame", Tooltip:GetFrame() == tip)
check("accent listener registered", #accentListeners == 1)
check("styled from GUI.Colors bg", tip.bgTexture.color[1] == 0.05 and tip.bgTexture.color[4] == 0.97)
check("border from borderStrong", borderUpdates[1] and borderUpdates[1][4] == 0.1)

---------------------------------------------------------------------------
-- Show: stop both, content, alpha 0 + Show, play fade-in
---------------------------------------------------------------------------
local A = panelChild()
callLog = {}
local shown = Tooltip:Show(A, "Body text", { title = "Title" })
check("Show returns true", shown == true)
check("frame shown at alpha 0 before fade-in", tip.shown == true and tip.alpha == 0)
check("both groups stopped before Show/Play",
    callLog[1] == "fadeOut:Stop" and callLog[2] == "fadeIn:Stop"
    and callLog[#callLog] == "fadeIn:Play", table.concat(callLog, ","))
check("fade-in playing", tip._fadeIn.playing == true and tip._fadeOut.playing == false)
local lines = shownLines(tip)
check("title + body lines rendered", #lines == 2 and lines[1].text == "Title" and lines[2].text == "Body text")
check("title coloured with accentText", lines[1].color[1] == 0.2 and lines[1].color[2] == 0.8 and lines[1].color[3] == 0.6)
check("title font larger than body", lines[1].font[2] == 12 and lines[2].font[2] == 11)
check("body white by alpha", lines[2].color[1] == 1 and lines[2].color[4] == 0.85)
check("owner tracked", Tooltip:GetOwner() == A and Tooltip:IsOwned(A) == true)
check("scale follows panel scale for panel anchors", tip.scale == 0.8)
check("default TOP preset anchors BOTTOM->TOP",
    tip.points[1][1] == "BOTTOM" and tip.points[1][2] == A and tip.points[1][3] == "TOP" and tip.points[1][5] == 4)
check("width from natural string width + padding, height from stacked lines",
    tip.w == 80 + 16 and tip.h == 12 + 2 + 12 + 16)

tip._fadeIn:Finish()
check("fade-in OnFinished pins alpha 1", tip.alpha == 1)

---------------------------------------------------------------------------
-- Hide: from-alpha continues from current alpha
---------------------------------------------------------------------------
tip.alpha = 0.4
callLog = {}
Tooltip:Hide()
check("Hide stops fade-in", callLog[1] == "fadeIn:Stop")
check("fade-out starts from current alpha", fadeOutAnim.fromAlpha == 0.4 and tip._fadeOut.playing == true)
check("frame still shown during fade-out", tip.shown == true)
check("owner cleared on Hide", Tooltip:GetOwner() == nil)
local playsBefore = tip._fadeOut.playCount
Tooltip:Hide()
check("second Hide does not restart a running fade-out", tip._fadeOut.playCount == playsBefore)
tip._fadeOut:Finish()
check("fade-out OnFinished hides and resets scale", tip.shown == false and tip.scale == 1 and tip.alpha == 0)

---------------------------------------------------------------------------
-- Re-target during fade-out: Stop both, no flicker (no intermediate Hide)
---------------------------------------------------------------------------
Tooltip:Show(A, "A text")
tip.alpha = 1
Tooltip:Hide()
check("fading out from A", tip._fadeOut.playing == true and Tooltip:GetOwner() == nil)
local B = panelChild()
callLog = {}
Tooltip:Show(B, "B text")
local sawHide = false
for _, entry in ipairs(callLog) do if entry == "frame:Hide" then sawHide = true end end
check("re-target stops the fade-out (OnFinished cannot hide the new tip)",
    tip._fadeOut.playing == false and callLog[1] == "fadeOut:Stop")
check("re-target never hides the frame", sawHide == false and tip.shown == true)
check("owner re-targeted to B", Tooltip:GetOwner() == B and Tooltip:IsOwned(A) == false)
check("content replaced", shownLines(tip)[1].text == "B text" and #shownLines(tip) == 1)

---------------------------------------------------------------------------
-- Owner guard + instant hide
---------------------------------------------------------------------------
Tooltip:Hide(false, A)
check("Hide(owner) ignores a non-owner leave", tip.shown == true and tip._fadeOut.playing == false and Tooltip:GetOwner() == B)
Tooltip:Hide(true, B)
check("Hide(true) hides immediately, no fade-out", tip.shown == false and tip._fadeOut.playing == false and tip.scale == 1)
check("instant hide clears owner", Tooltip:GetOwner() == nil and Tooltip:IsShown() == false)
callLog = {}
Tooltip:Hide(true)
check("Hide on a hidden tip is a no-op", #callLog == 0)

---------------------------------------------------------------------------
-- Gate
---------------------------------------------------------------------------
QUI.db.profile.general.showOptionTooltips = false
local playsIn = tip._fadeIn.playCount
check("gate off -> Show returns false and nothing shows",
    Tooltip:Show(A, "gated") == false and tip.shown == false and tip._fadeIn.playCount == playsIn)
check("IsEnabled reflects the gate", Tooltip:IsEnabled() == false)
QUI.db.profile.general.showOptionTooltips = true
check("IsEnabled true again", Tooltip:IsEnabled() == true)

---------------------------------------------------------------------------
-- Content functions
---------------------------------------------------------------------------
local ok = Tooltip:Show(A, function(builder, anchor)
    builder:AddTitle("Fn title")
    builder:AddLine("line one", 0.5, 0.5, 0.5)
    builder:SetText("via SetText")
    check("content fn receives the anchor", anchor == A)
    return "returned body"
end)
lines = shownLines(tip)
check("function content: builder lines + returned string",
    ok and #lines == 4 and lines[1].text == "Fn title" and lines[2].text == "line one"
    and lines[3].text == "via SetText" and lines[4].text == "returned body")
check("caller colours preserved", lines[2].color[1] == 0.5 and lines[2].color[4] == 1)
Tooltip:Hide(true)

check("erroring content fn suppresses the tooltip",
    Tooltip:Show(A, function() error("secret value") end) == false and tip.shown == false)
check("empty content suppresses the tooltip", Tooltip:Show(A, function() end) == false and tip.shown == false)
check("nil anchor rejected", Tooltip:Show(nil, "x") == false)

---------------------------------------------------------------------------
-- Anchor presets + aliases + scale
---------------------------------------------------------------------------
Tooltip:Show(A, "x", { anchor = "BELOW" })
check("BELOW preset", tip.points[1][1] == "TOP" and tip.points[1][3] == "BOTTOM" and tip.points[1][5] == -4)
Tooltip:Show(A, "x", { anchor = "ANCHOR_RIGHT" })
check("GameTooltip ANCHOR_RIGHT alias -> RIGHT", tip.points[1][1] == "LEFT" and tip.points[1][3] == "RIGHT" and tip.points[1][4] == 4)
Tooltip:Show(A, "x", { anchor = "left" })
check("case-insensitive LEFT", tip.points[1][1] == "RIGHT" and tip.points[1][3] == "LEFT")
Tooltip:Show(A, "x", { anchor = "CURSOR" })
check("CURSOR preset anchors to UIParent at cursor / scale",
    tip.points[1][1] == "BOTTOM" and tip.points[1][2] == UIParent and tip.points[1][4] == 400 / 0.8)
Tooltip:Show(A, "x", { anchor = "bogus" })
check("unknown preset falls back to TOP", tip.points[1][1] == "BOTTOM" and tip.points[1][3] == "TOP")
---------------------------------------------------------------------------
-- Frame level tracks the anchor (popups on TOOLTIP strata, e.g. the CDM
-- override panel at level 500, must not draw over the tip)
---------------------------------------------------------------------------
Tooltip:Show(A, "x")
check("low anchor keeps base level 200", tip.level == 200, tip.level)
local highAnchor = NewFrame(panel)
highAnchor.level = 503
Tooltip:Show(highAnchor, "x")
check("high anchor lifts tip above it", tip.level == 523, tip.level)
Tooltip:Show(A, "x")
check("level drops back for low anchor", tip.level == 200, tip.level)
Tooltip:Hide(true)

local outside = NewFrame(UIParent)
Tooltip:Show(outside, "x")
check("non-panel anchor keeps scale 1", tip.scale == 1)
Tooltip:Show(outside, "x", { scale = 1.5 })
check("opts.scale override", tip.scale == 1.5)
check("IsPanelAnchor", Tooltip:IsPanelAnchor(A) == true and Tooltip:IsPanelAnchor(outside) == false)
Tooltip:Hide(true)

---------------------------------------------------------------------------
-- Screen clamp
---------------------------------------------------------------------------
tip.geometry = { left = -10, right = 90, top = 300, bottom = 250 }
Tooltip:Show(A, "x")
check("clamps a left overflow back on screen", tip.points[1][4] == 10 and tip.points[1][5] == 4)
tip.geometry = { left = 100, right = 200, top = 1200, bottom = 1150 }
Tooltip:Show(A, "x")
check("clamps a top overflow (screen height / scale)", tip.points[1][5] == 4 + (800 / 0.8 - 1200))
tip.geometry = { left = SECRET, right = 200, top = 300, bottom = 250 }
Tooltip:Show(A, "x")
check("secret geometry skips the clamp without erroring", tip.shown == true and tip.points[1][4] == 0)
tip.geometry = { left = 100, right = 200, top = 300, bottom = 250 }

---------------------------------------------------------------------------
-- Secret measurements fall back
---------------------------------------------------------------------------
for _, fs in ipairs(tip._fontStrings) do fs.stringWidth = SECRET; fs.stringHeight = SECRET end
check("secret string metrics fall back to fixed sizes",
    Tooltip:Show(A, "x") == true and tip.w == 260 and tip.h == 14 + 16)
for _, fs in ipairs(tip._fontStrings) do fs.stringWidth = 80; fs.stringHeight = 12 end

---------------------------------------------------------------------------
-- Width cap + wrap
---------------------------------------------------------------------------
tip._fontStrings[1].stringWidth = 900
Tooltip:Show(A, "long")
check("width capped at maxWidth", tip.w == 260 and tip._fontStrings[1].width == 260 - 16)
Tooltip:Show(A, "long", { maxWidth = 120 })
check("opts.maxWidth honoured", tip.w == 120)
tip._fontStrings[1].stringWidth = 80
Tooltip:Hide(true)

---------------------------------------------------------------------------
-- Re-tint via accent listener
---------------------------------------------------------------------------
Tooltip:Show(A, "body", { title = "T" })
C.accentText = { 0.9, 0.1, 0.1, 1 }
C.bg = { 0.2, 0.2, 0.2, 0.5 }
accentListeners[1]()
check("Retint recolours title from accentText", shownLines(tip)[1].color[1] == 0.9)
check("Retint refreshes bg", tip.bgTexture.color[1] == 0.2 and tip.bgTexture.color[4] == 0.5)
Tooltip:Hide(true)

if fails > 0 then
    print(("FAIL options_tooltip_service_test (%d)"):format(fails))
    os.exit(1)
end
print("PASS options_tooltip_service_test")
