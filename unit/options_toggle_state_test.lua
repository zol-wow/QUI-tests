-- tests/unit/options_toggle_state_test.lua
-- Options form-control state model (UI polish Phase 4 / R7 + R10):
--   * pill toggle (QUI_Options/framework.lua BuildPillToggle) and square
--     checkbox (CreateFormCheckboxOriginal / CreateFormSquareCheckbox) share
--     SetEnabled(enabled, reason): control muted to .30, label to .45, the
--     row container is NEVER SetAlpha'd, the hit target stays (engine
--     swallows clicks), `reason` surfaces on hover through GUI.Tooltip;
--   * setting rows (QUI_Options/shared.lua BuildSettingRow /
--     SetSettingRowEnabled) forward `reason` (explicit, or the row's
--     disabledReason / disabledReasonFn) and leave the description alone;
--   * the pill animates knob + track with UIKit.AnimateValue (90 ms) and a
--     click mid-flight retargets from the current progress (no snap).
-- The framework / shared blocks are extracted between their BEGIN/END
-- markers and run against the REAL core/uikit.lua with a fake OnUpdate clock.
-- Run: luajit tests/unit/options_toggle_state_test.lua
-- luacheck: globals CreateFrame QUI

local failures = 0
local function check(name, ok, detail)
    if ok then
        print(("  ok  %s"):format(name))
    else
        failures = failures + 1
        print(("FAIL  %s  %s"):format(name, detail or ""))
    end
end
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6 end

local function readAll(path)
    local f = assert(io.open(path, "rb"))
    local d = f:read("*a"); f:close()
    return (d:gsub("\r\n", "\n"))
end
local function extract(src, beginMarker, endMarker)
    local s = assert(src:find(beginMarker, 1, true), "missing " .. beginMarker)
    local e = assert(src:find(endMarker, s, true), "missing " .. endMarker)
    return src:sub(s, e - 1)
end

---------------------------------------------------------------------------
-- Frame stubs
---------------------------------------------------------------------------
local function NewTexture(owner)
    local t = { owner = owner, shown = true, alpha = 1, width = 0, height = 0 }
    function t:SetAllPoints() end
    function t:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function t:SetTexture(path) self.texture = path end
    function t:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a } end
    function t:SetDesaturated() end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    function t:IsShown() return self.shown end
    function t:SetAlpha(a) self.alpha = a end
    function t:ClearAllPoints() self.points = {} end
    function t:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
    function t:SetHeight(h) self.height = h end
    function t:SetWidth(w) self.width = w end
    function t:SetSize(w, h) self.width, self.height = w, h end
    function t:GetWidth() return self.width end
    function t:GetHeight() return self.height end
    function t:SetSnapToPixelGrid() end
    function t:SetTexelSnappingBias() end
    function t:AddMaskTexture() end
    return t
end

local function NewFontString(owner)
    local fs = { owner = owner, text = "" }
    function fs:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
    function fs:SetText(s) self.text = s end
    function fs:GetText() return self.text end
    function fs:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
    function fs:SetFont(path, size, flags) self.font = { path, size, flags } end
    function fs:SetTextColor(r, g, b, a) self.color = { r, g, b, a } end
    function fs:GetStringWidth() return 40 end
    function fs:SetJustifyH() end
    function fs:SetWidth() end
    function fs:SetWordWrap() end
    function fs:SetNonSpaceWrap() end
    function fs:GetObjectType() return "FontString" end
    function fs:GetParent() return self.owner end
    return fs
end

local frames = {}
local function NewFrame(kind, parent)
    local f = {
        kind = kind, parent = parent, scripts = {}, hooks = {}, textures = {},
        enabled = true, shown = true, alpha = 1, width = 0, height = 0, level = 1, mouse = true,
        alphaCalls = 0,
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
    function f:Click()
        if not self.enabled then return false end
        self:Fire("OnClick", "LeftButton")
        return true
    end
    function f:Enable() self.enabled = true; self:Fire("OnEnable") end
    function f:Disable() self.enabled = false; self:Fire("OnDisable") end
    function f:IsEnabled() return self.enabled end
    function f:SetMotionScriptsWhileDisabled(v) self.motionWhileDisabled = v end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetAlpha(a) self.alpha = a; self.alphaCalls = self.alphaCalls + 1 end
    function f:GetAlpha() return self.alpha end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetWidth(w) self.width = w end
    function f:SetHeight(h) self.height = h end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
    function f:ClearAllPoints() self.points = {} end
    function f:GetParent() return self.parent end
    function f:SetParent(p) self.parent = p end
    function f:GetChildren() return nil end
    function f:SetFrameLevel(l) self.level = l end
    function f:GetFrameLevel() return self.level end
    function f:SetFrameStrata(s) self.strata = s end
    function f:GetFrameStrata() return self.strata or "MEDIUM" end
    function f:EnableMouse(v) self.mouse = v end
    function f:GetEffectiveScale() return 1 end
    function f:CreateTexture() local t = NewTexture(self); self.textures[#self.textures + 1] = t; return t end
    function f:CreateFontString() return NewFontString(self) end
    function f:CreateMaskTexture() return NewTexture(self) end
    frames[#frames + 1] = f
    return f
end
function CreateFrame(kind, _, parent) return NewFrame(kind, parent) end

---------------------------------------------------------------------------
-- Namespace, theme, tooltip service
---------------------------------------------------------------------------
local ns = {
    Helpers = {
        AssetPath = "Interface\\AddOns\\QUI\\assets\\",
        CHROME = { BORDER_PX = 1, BG_FALLBACK = { 0.05, 0.05, 0.05, 0.95 }, BORDER_FALLBACK = { 0, 0, 0, 1 }, BUTTON_BOOST = 0.07, SCROLLROW_BOOST = 0.03, DEPTH = { PANEL = { boost = 0, alpha = 0.95 }, SUBPANEL = { boost = 0.04, alpha = 0.85 }, ROW = { boost = 0.07, alpha = 0.75 } } },
        CreateStateTable = function() return setmetatable({}, { __mode = "k" }) end,
        SafeToNumber = function(value, fallback) return tonumber(value) or fallback end,
        IsSecretValue = function() return false end,
        ApplyFontWithFallback = function(fs, path, size, flags) fs:SetFont(path, size, flags) end,
        GetGeneralFont = function() return "Fonts\\FRIZQT__.TTF" end,
        GetGeneralFontOutline = function() return "" end,
    },
    QUI_Options = {},
}
local core = {}
function core:GetPixelSize() return 1 end
function core:Pixels(v) return v end
function ns.Helpers.GetCore() return core end

local panel = NewFrame("Frame", nil)
local tipLog = {}
local Tooltip = { owner = nil }
function Tooltip:Show(anchor, body, opts)
    self.owner = anchor
    tipLog[#tipLog + 1] = { op = "show", anchor = anchor, body = body, title = opts and opts.title }
    return true
end
function Tooltip:Hide(instant, owner)
    tipLog[#tipLog + 1] = { op = "hide", owner = owner }
    if owner == nil or owner == self.owner then self.owner = nil end
end
function Tooltip:IsPanelAnchor(frame)
    local p = frame
    while p do
        if p == panel then return true end
        p = p.parent
    end
    return false
end
function Tooltip:IsOwned(frame) return self.owner == frame end

local C = {
    accent = { 0.2, 0.8, 0.6, 1 },
    accentHover = { 0.3, 0.9, 0.7, 1 },
    bg = { 0.05, 0.07, 0.09, 1 },
    text = { 1, 1, 1, 1 },
    textMuted = { 1, 1, 1, 0.45 },
    toggleOff = { 1, 1, 1, 0.12 },
    toggleThumb = { 1, 1, 1, 1 },
    disabled = { 1, 1, 1, 0.30 },
    disabledBg = { 1, 1, 1, 0.04 },
}
local GUI = {
    Colors = C,
    Tooltip = Tooltip,
    MainFrame = panel,
    OnAccentChanged = function() return true end,
    HasGeneratedSearchCache = function() return true end,
    GetFontPath = function() return "Fonts\\FRIZQT__.TTF" end,
}
QUI = { GUI = GUI }

assert(loadfile("core/safecall.lua"))("QUI", ns)
assert(loadfile("core/uikit.lua"))("QUI", ns)
local UIKit = ns.UIKit

---------------------------------------------------------------------------
-- Extract the framework blocks and run them with the module-local helpers
-- they close over supplied as parameters.
---------------------------------------------------------------------------
local fw = readAll("QUI_Options/framework.lua")
local muteBlock = extract(fw, "-- BEGIN widget disabled mute", "-- END widget disabled mute")
local pillBlock = extract(fw, "-- BEGIN pill toggle", "-- END pill toggle")
local squareBlock = extract(fw, "-- BEGIN square checkbox", "-- END square checkbox")

local FORM_ROW_HEIGHT = 26
local function SetFont(fs, size, flags, color)
    fs:SetFont("F", size, flags)
    if color then fs:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
end
local function noop() end
local function BindWidgetMethod(_, fn) return function(_, ...) return fn(...) end end

local loader = loadstring or load
local params = "ns, GUI, C, UIKit, CreateFrame, FORM_ROW_HEIGHT, SetFont, ApplyWidgetSyncContext, "
    .. "MaybeUpdatePinnedWidgetValue, BroadcastToSiblings, MaybeAutoNotifyProviderSync, BindWidgetMethod, "
    .. "RegisterWidgetInstance, MaybeBindPinnedWidget, RegisterSearchSettingWidgetForBinding, AttachFormWidgetTooltip"
local source = "return function(" .. params .. ")\n"
    .. muteBlock .. "\n" .. pillBlock .. "\n" .. squareBlock .. "\nreturn BuildPillToggle\nend"
local chunk = assert(loader(source, "framework toggles"))
local BuildPillToggle = chunk()(ns, GUI, C, UIKit, CreateFrame, FORM_ROW_HEIGHT, SetFont, noop,
    noop, noop, noop, BindWidgetMethod, noop, noop, noop, noop)
check("pill builder + square checkbox extracted", type(BuildPillToggle) == "function"
    and type(GUI.CreateFormCheckboxOriginal) == "function" and type(GUI.ApplyWidgetDisabledMute) == "function")

local function findDriver()
    for _, f in ipairs(frames) do
        if f.kind == "Frame" and f.parent == nil and f ~= panel and f.scripts.OnUpdate then return f end
    end
end
local function pump(dt, times)
    local driver = findDriver()
    if not driver then return end
    for _ = 1, (times or 1) do
        if not driver.scripts.OnUpdate then return end
        driver.scripts.OnUpdate(driver, dt)
    end
end
local function knobX(toggle) return toggle.knob.points[#toggle.knob.points][4] end

---------------------------------------------------------------------------
-- Pill toggle: animation retargets mid-flight
---------------------------------------------------------------------------
local db = { on = false }
local pill = BuildPillToggle(panel, "Enable thing", "on", db, nil, nil, false)
local toggle = pill.track
check("pill starts painted at the OFF endpoint (knob at LEFT+2, toggleOff track)",
    near(knobX(toggle), 2) and near(toggle.track.color[4], 0.12) and pill.GetToggleProgress() == 0,
    tostring(knobX(toggle)))
check("pill keeps motion scripts while disabled", toggle.motionWhileDisabled == true)

check("click flips the db value", toggle:Click() == true and db.on == true)
check("click does not snap: progress still 0 right after the click", pill.GetToggleProgress() == 0)
pump(0.03)
check("after 30 ms of a 90 ms transition progress is 1/3, knob lerped (2 -> 14)",
    near(pill.GetToggleProgress(), 1 / 3) and near(knobX(toggle), 2 + 12 / 3), tostring(knobX(toggle)))
check("track colour lerps toggleOff -> accent",
    near(toggle.track.color[1], 1 + (0.2 - 1) / 3) and near(toggle.track.color[4], 0.12 + (1 - 0.12) / 3))
pump(0.03)
check("progress 2/3", near(pill.GetToggleProgress(), 2 / 3))

-- click again mid-flight: retarget toward OFF from 2/3, no snap
check("second click mid-flight flips db back", toggle:Click() == true and db.on == false)
check("retarget keeps the current progress (2/3), no snap", near(pill.GetToggleProgress(), 2 / 3), tostring(pill.GetToggleProgress()))
pump(0.03)
check("reverses at constant speed: 2/3 -> 1/3 after 30 ms", near(pill.GetToggleProgress(), 1 / 3), tostring(pill.GetToggleProgress()))
pump(0.03)
check("lands exactly on OFF", pill.GetToggleProgress() == 0 and near(knobX(toggle), 2) and near(toggle.track.color[4], 0.12))
pump(0.03)
check("driver idle after landing (no OnUpdate)", findDriver() == nil or findDriver().scripts.OnUpdate == nil)

toggle:Click()
pump(0.09, 2)
check("full transition lands on ON (knob at 14, accent track)",
    pill.GetToggleProgress() == 1 and near(knobX(toggle), 14) and near(toggle.track.color[1], 0.2), tostring(knobX(toggle)))

pill.Refresh()
check("Refresh is instant (no animation queued)", pill.GetToggleProgress() == 1 and (findDriver() == nil or findDriver().scripts.OnUpdate == nil))

---------------------------------------------------------------------------
-- Pill toggle: SetEnabled(enabled, reason)
---------------------------------------------------------------------------
local label = pill.label
pill:SetEnabled(false, "Requires Foo")
check("pill disabled: control .30, label .45, container NOT SetAlpha'd",
    near(toggle.alpha, 0.3) and near(label.color[4], 0.45) and pill.alpha == 1 and pill.alphaCalls == 0,
    ("toggle=%s label=%s container=%s calls=%d"):format(tostring(toggle.alpha), tostring(label.color[4]), tostring(pill.alpha), pill.alphaCalls))
check("pill disabled: native Disable, hit target kept", toggle.enabled == false and toggle.mouse == true)
check("pill disabled: click swallowed, db untouched", toggle:Click() == false and db.on == true)
check("pill GetDisabledReason", pill:GetDisabledReason() == "Requires Foo")
tipLog = {}
toggle:Fire("OnEnter")
check("pill disabled hover shows the reason (title = label)",
    tipLog[1] and tipLog[1].op == "show" and tipLog[1].anchor == toggle and tipLog[1].body == "Requires Foo" and tipLog[1].title == "Enable thing",
    tipLog[1] and tostring(tipLog[1].body))
toggle:Fire("OnLeave")
check("pill leave hides the reason", tipLog[2] and tipLog[2].op == "hide" and tipLog[2].owner == toggle)
pill:SetEnabled(true)
check("pill re-enabled: alpha 1, label 1, click works",
    toggle.alpha == 1 and near(label.color[4], 1) and toggle:Click() == true and db.on == false and pill:GetDisabledReason() == nil)
tipLog = {}
toggle:Fire("OnEnter"); toggle:Fire("OnLeave")
check("enabled hover shows no reason tooltip", #tipLog == 0)

---------------------------------------------------------------------------
-- Square checkbox: same contract
---------------------------------------------------------------------------
local sdb = { sq = true }
local square = GUI:CreateFormCheckboxOriginal(panel, "Square thing", "sq", sdb)
local box = square.box
check("square checkbox exposes SetEnabled/GetDisabledReason", type(square.SetEnabled) == "function" and type(square.GetDisabledReason) == "function")
check("square keeps motion scripts while disabled", box.motionWhileDisabled == true)
square:SetEnabled(false, "Requires Bar")
check("square disabled: control .30, label .45, container NOT SetAlpha'd",
    near(box.alpha, 0.3) and near(square.label.color[4], 0.45) and square.alpha == 1 and square.alphaCalls == 0,
    ("box=%s label=%s"):format(tostring(box.alpha), tostring(square.label.color[4])))
check("square disabled: native Disable, hit target kept, click swallowed",
    box.enabled == false and box.mouse == true and box:Click() == false and sdb.sq == true)
check("square GetDisabledReason", square:GetDisabledReason() == "Requires Bar" and box:GetDisabledReason() == "Requires Bar")
tipLog = {}
box:Fire("OnEnter")
check("square disabled hover shows the reason via the service", tipLog[1] and tipLog[1].op == "show" and tipLog[1].body == "Requires Bar",
    tipLog[1] and tostring(tipLog[1].body))
box:Fire("OnLeave")
check("square leave hides", tipLog[2] and tipLog[2].op == "hide" and tipLog[2].owner == box)
square:SetEnabled(true)
check("square re-enabled: click toggles", box.alpha == 1 and box:Click() == true and sdb.sq == false and near(square.label.color[4], 1))
box:Disable()
check("square native Disable() mutes the control", near(box.alpha, 0.3) and box:Click() == false)
box:Enable()
check("square native Enable() restores", box.alpha == 1)

check("honest square alias exists when framework defines it (source check)",
    fw:find("function GUI:CreateFormSquareCheckbox(", 1, true) ~= nil
    and fw:find("function GUI:CreateFormToggle(", 1, true) ~= nil)

---------------------------------------------------------------------------
-- Setting rows (shared.lua): forward reason, description untouched
---------------------------------------------------------------------------
local shared = readAll("QUI_Options/shared.lua")
local rowBlock = extract(shared, "-- BEGIN setting row state", "-- END setting row state")
local rowChunk = assert(loader("return function(ns, QUI, Helpers, CreateFrame)\n" .. rowBlock .. "\nreturn BuildSettingRow, SetSettingRowEnabled\nend", "shared rows"))
local BuildSettingRow = rowChunk()(ns, QUI, ns.Helpers, CreateFrame)
check("BuildSettingRow extracted", type(BuildSettingRow) == "function" and ns.QUI_Options.SetSettingRowEnabled ~= nil)

local function SpyWidget()
    local w = NewFrame("Frame", nil)
    w.calls = {}
    function w:SetEnabled(enabled, reason) self.calls[#self.calls + 1] = { enabled, reason } end
    return w
end

local spy = SpyWidget()
local row = BuildSettingRow(panel, "Row label", spy, "Row description", { disabledReason = "Needs X" })
local descAlpha = row._desc.color[4]
row:SetEnabled(false)
check("row forwards its disabledReason to the widget", spy.calls[1][1] == false and spy.calls[1][2] == "Needs X",
    tostring(spy.calls[1] and spy.calls[1][2]))
check("row disabled: label .45, description alpha unchanged, row not SetAlpha'd",
    near(row._label.color[4], 0.45) and near(row._desc.color[4], descAlpha) and row.alphaCalls == 0,
    ("label=%s desc=%s"):format(tostring(row._label.color[4]), tostring(row._desc.color[4])))
check("row GetDisabledReason", row:GetDisabledReason() == "Needs X")
row:SetEnabled(false, "Explicit reason")
check("explicit reason overrides the row default", spy.calls[2][2] == "Explicit reason" and row:GetDisabledReason() == "Explicit reason")
row:SetEnabled(true)
check("re-enable forwards true, clears reason, label alpha 1",
    spy.calls[3][1] == true and row:GetDisabledReason() == nil and near(row._label.color[4], 1))

local fnSpy = SpyWidget()
local fnRow = BuildSettingRow(panel, "Fn row", fnSpy, nil, { disabledReasonFn = function() return "Computed" end })
fnRow:SetEnabled(false)
check("disabledReasonFn forwarded as a function and resolved by GetDisabledReason",
    type(fnSpy.calls[1][2]) == "function" and fnRow:GetDisabledReason() == "Computed")

local legacySpy = SpyWidget()
local legacyRow = BuildSettingRow(panel, "Legacy", legacySpy)
legacyRow:SetEnabled(false)
check("rows without opts keep working (reason nil)", legacySpy.calls[1][1] == false and legacySpy.calls[1][2] == nil)

-- real pill inside a row: the control mutes, the row container does not
local rdb = { v = true }
local rowPill = BuildPillToggle(panel, nil, "v", rdb, nil, nil, false)
local pillRow = BuildSettingRow(panel, "Pill row", rowPill, "desc", { disabledReason = "Needs Y" })
pillRow:SetEnabled(false)
check("row -> pill: control .30, pill container and row untouched",
    near(rowPill.track.alpha, 0.3) and rowPill.alpha == 1 and pillRow.alpha == 1 and rowPill:GetDisabledReason() == "Needs Y")

-- widgets without SetEnabled: control-only mute, never the row
local plain = NewFrame("Frame", nil)
plain.SetEnabled = nil
local plainRow = BuildSettingRow(panel, "Plain", plain)
plainRow:SetEnabled(false)
check("fallback for SetEnabled-less widgets mutes the control (.3) only", near(plain.alpha, 0.3) and plainRow.alpha == 1)

if failures > 0 then
    print(("FAILED: %d check(s)"):format(failures))
    os.exit(1)
end
print("OK: options_toggle_state_test")
