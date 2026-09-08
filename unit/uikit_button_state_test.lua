-- tests/unit/uikit_button_state_test.lua
-- UIKit.CreateButton state model (core/uikit.lua, UI polish Phase 4 / R4):
-- one `state` table (enabled/hovered/pressed/selected/variant), one
-- RefreshVisualState() mapping state -> border / fill / text, public
-- SetEnabled(enabled, reason) / SetSelected / SetVariant, native
-- Enable()/Disable() round trip through the OnEnable/OnDisable hooks, a
-- disabled button that KEEPS its hit target (clicks swallowed by the engine,
-- never EnableMouse(false)) and surfaces `reason` through the tooltip
-- routing, and one accent listener re-tinting every primary/selected button.
-- Run: luajit tests/unit/uikit_button_state_test.lua
-- luacheck: globals CreateFrame QUI GameTooltip

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
local function rgba(t, r, g, b, a)
    return type(t) == "table" and near(t[1], r) and near(t[2], g) and near(t[3], b) and (a == nil or near(t[4], a))
end
local function fmt(t)
    if type(t) ~= "table" then return tostring(t) end
    return ("{%s,%s,%s,%s}"):format(tostring(t[1]), tostring(t[2]), tostring(t[3]), tostring(t[4]))
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
    function fs:SetPoint(p, x, y) self.point = { p, x, y } end
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
    return fs
end

local frames = {}
local function NewFrame(kind, parent)
    local f = {
        kind = kind, parent = parent, scripts = {}, hooks = {}, textures = {},
        enabled = true, shown = true, alpha = 1, width = 0, height = 0, level = 1, mouse = true,
        mouseCalls = {},
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
    -- Engine semantics: a disabled Button never dispatches OnClick.
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
    function f:SetAlpha(a) self.alpha = a end
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
    function f:SetFrameLevel(l) self.level = l end
    function f:GetFrameLevel() return self.level end
    function f:SetFrameStrata(s) self.strata = s end
    function f:GetFrameStrata() return self.strata or "MEDIUM" end
    function f:EnableMouse(v) self.mouse = v; self.mouseCalls[#self.mouseCalls + 1] = v end
    function f:GetEffectiveScale() return 1 end
    function f:CreateTexture() local t = NewTexture(self); self.textures[#self.textures + 1] = t; return t end
    function f:CreateFontString() return NewFontString(self) end
    function f:CreateMaskTexture() return NewTexture(self) end
    frames[#frames + 1] = f
    return f
end

function CreateFrame(kind, _, parent) return NewFrame(kind, parent) end

---------------------------------------------------------------------------
-- Addon namespace + theme / tooltip service stubs
---------------------------------------------------------------------------
local ns = {
    Helpers = {
        CHROME = { BORDER_PX = 1, BG_FALLBACK = { 0.05, 0.05, 0.05, 0.95 }, BORDER_FALLBACK = { 0, 0, 0, 1 }, BUTTON_BOOST = 0.07, SCROLLROW_BOOST = 0.03, DEPTH = { PANEL = { boost = 0, alpha = 0.95 }, SUBPANEL = { boost = 0.04, alpha = 0.85 }, ROW = { boost = 0.07, alpha = 0.75 } } },
        CreateStateTable = function() return setmetatable({}, { __mode = "k" }) end,
        SafeToNumber = function(value, fallback) return tonumber(value) or fallback end,
        IsSecretValue = function() return false end,
    },
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
    tipLog[#tipLog + 1] = { op = "hide", owner = owner, instant = instant }
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

local accentListeners = {}
QUI = {
    GUI = {
        Colors = {
            accent = { 0.2, 0.8, 0.6, 1 },
            text = { 1, 1, 1, 1 },
            textDim = { 1, 1, 1, 0.6 },
            disabled = { 1, 1, 1, 0.30 },
            disabledBg = { 1, 1, 1, 0.04 },
            selectedWash = { 0.2, 0.8, 0.6, 0.10 },
        },
        Tooltip = Tooltip,
        OnAccentChanged = function(_, fn) accentListeners[#accentListeners + 1] = fn; return true end,
    },
}

GameTooltip = { calls = {} }
function GameTooltip:SetOwner(owner, anchor) self.owner = owner; self.calls[#self.calls + 1] = { "SetOwner", anchor } end
function GameTooltip:SetText(text) self.text = text; self.calls[#self.calls + 1] = { "SetText", text } end
function GameTooltip:AddLine(text) self.calls[#self.calls + 1] = { "AddLine", text } end
function GameTooltip:Show() self.shown = true end
function GameTooltip:Hide() self.shown = false; self.owner = nil end
function GameTooltip:IsOwned(frame) return self.owner == frame end

assert(loadfile("core/safecall.lua"))("QUI", ns)
assert(loadfile("core/uikit.lua"))("QUI", ns)
local UIKit = ns.UIKit

-- Border lines are the first four textures BuildEdgeTextures creates on the
-- button; they share one colour.
local function borderColor(button) return button.textures[1].color end

---------------------------------------------------------------------------
-- Construction + public API
---------------------------------------------------------------------------
local clicks = 0
local button = UIKit.CreateButton(panel, { text = "Apply", onClick = function() clicks = clicks + 1 end })
check("button exposes state table",
    type(button.state) == "table" and button.state.enabled == true and button.state.hovered == false
    and button.state.pressed == false and button.state.selected == false and button.state.variant == "ghost")
check("public API present",
    type(button.SetEnabled) == "function" and type(button.SetSelected) == "function"
    and type(button.SetVariant) == "function" and type(button.GetDisabledReason) == "function"
    and type(button.RefreshVisualState) == "function" and type(button.IsSelected) == "function"
    and type(button.GetVariant) == "function")
check("motion scripts kept while disabled (hit target)", button.motionWhileDisabled == true)
check("legacy fields kept (text, _hoverBg, SetText, SetBorderColor, SetFieldBorderColor)",
    button.text ~= nil and button._hoverBg ~= nil and type(button.SetText) == "function"
    and type(button.SetBorderColor) == "function" and button.SetFieldBorderColor == button.SetBorderColor)

---------------------------------------------------------------------------
-- Ghost ladder: idle .85 / hover 1 / pressed fill +.04
---------------------------------------------------------------------------
check("ghost idle: white .85 text, no fill, white .2 border",
    rgba(button.text.color, 1, 1, 1, 0.85) and button._hoverBg.shown == false
    and rgba(borderColor(button), 1, 1, 1, 0.2),
    fmt(button.text.color) .. " fill=" .. tostring(button._hoverBg.shown) .. " border=" .. fmt(borderColor(button)))

button:Fire("OnEnter")
check("ghost hover: text 1.0, white .06 fill shown, border .35",
    button.state.hovered == true and rgba(button.text.color, 1, 1, 1, 1)
    and button._hoverBg.shown == true and rgba(button._hoverBg.color, 1, 1, 1, 0.06)
    and rgba(borderColor(button), 1, 1, 1, 0.35),
    fmt(button.text.color) .. " fill=" .. fmt(button._hoverBg.color))

button:Fire("OnMouseDown")
check("ghost pressed: fill +.04 (.10), label nudged 1px down",
    button.state.pressed == true and rgba(button._hoverBg.color, 1, 1, 1, 0.10)
    and button.text.point[3] == -1, fmt(button._hoverBg.color))
button:Fire("OnMouseUp")
check("mouse up: fill back to .06, label at 0",
    button.state.pressed == false and rgba(button._hoverBg.color, 1, 1, 1, 0.06) and button.text.point[3] == 0)
button:Fire("OnMouseDown")
button:Fire("OnLeave")
check("leave clears hovered AND pressed, fill hidden, text .85",
    button.state.hovered == false and button.state.pressed == false
    and button._hoverBg.shown == false and rgba(button.text.color, 1, 1, 1, 0.85))

check("click fires onClick while enabled", button:Click() == true and clicks == 1)

---------------------------------------------------------------------------
-- SetEnabled(false, reason): disabled tokens, hit target kept, reason tooltip
---------------------------------------------------------------------------
button:SetEnabled(false, "Requires the module to be enabled")
check("disabled: state + native IsEnabled agree", button.state.enabled == false and button:IsEnabled() == false)
check("disabled: text = disabled token (white .30)", rgba(button.text.color, 1, 1, 1, 0.30), fmt(button.text.color))
check("disabled: disabledBg fill shown (white .04)",
    button._hoverBg.shown == true and rgba(button._hoverBg.color, 1, 1, 1, 0.04), fmt(button._hoverBg.color))
check("disabled: border alpha halved (.2 -> .1)", rgba(borderColor(button), 1, 1, 1, 0.10), fmt(borderColor(button)))
check("disabled keeps its hit target (EnableMouse(false) never called)", button.mouse == true and #button.mouseCalls == 0)
check("disabled: click swallowed by the engine", button:Click() == false and clicks == 1)
check("GetDisabledReason returns the reason", button:GetDisabledReason() == "Requires the module to be enabled")

tipLog = {}
button:Fire("OnEnter")
check("disabled hover: no hover treatment (fill stays disabledBg, text .30)",
    rgba(button._hoverBg.color, 1, 1, 1, 0.04) and rgba(button.text.color, 1, 1, 1, 0.30))
check("disabled hover shows the reason through GUI.Tooltip (panel anchor)",
    #tipLog == 1 and tipLog[1].op == "show" and tipLog[1].anchor == button
    and tipLog[1].body == "Requires the module to be enabled",
    tipLog[1] and (tipLog[1].op .. ":" .. tostring(tipLog[1].body)) or "no tooltip call")
button:Fire("OnLeave")
check("leave hides the reason tooltip (owner-guarded)",
    #tipLog == 2 and tipLog[2].op == "hide" and tipLog[2].owner == button)

button:Fire("OnMouseDown")
check("disabled: OnMouseDown does not set pressed", button.state.pressed == false and button.text.point[3] == 0)
button:Fire("OnMouseUp")

-- reason as a function (resolved lazily at hover time)
local dynamicReason = "Needs A"
button:SetEnabled(false, function() return dynamicReason end)
dynamicReason = "Needs B"
tipLog = {}
button:Fire("OnEnter")
check("function reason resolved at hover", tipLog[1] and tipLog[1].body == "Needs B", tipLog[1] and tipLog[1].body)
button:Fire("OnLeave")

-- disabled without reason: no tooltip
button:SetEnabled(false)
tipLog = {}
button:Fire("OnEnter")
check("disabled without reason: no tooltip, GetDisabledReason nil", #tipLog == 0 and button:GetDisabledReason() == nil)
button:Fire("OnLeave")
check("no stray hide when nothing was shown", #tipLog == 0)

button:SetEnabled(true)
check("re-enabled: state, native, text .85, no fill, border .2, reason cleared",
    button.state.enabled == true and button:IsEnabled() == true and rgba(button.text.color, 1, 1, 1, 0.85)
    and button._hoverBg.shown == false and rgba(borderColor(button), 1, 1, 1, 0.2)
    and button:GetDisabledReason() == nil)
check("re-enabled: click fires again", button:Click() == true and clicks == 2)

---------------------------------------------------------------------------
-- Native Disable()/Enable() round trip through the OnDisable/OnEnable hooks
---------------------------------------------------------------------------
button:Disable()
check("native Disable(): state follows, disabled visuals",
    button.state.enabled == false and rgba(button.text.color, 1, 1, 1, 0.30) and button._hoverBg.shown == true)
button:Enable()
check("native Enable(): state follows, ghost idle restored",
    button.state.enabled == true and rgba(button.text.color, 1, 1, 1, 0.85) and button._hoverBg.shown == false)

---------------------------------------------------------------------------
-- Selected: selectedWash fill + accent border, white 1 text
---------------------------------------------------------------------------
button:SetSelected(true)
check("selected: accent-tinted wash fill at selectedWash alpha (.10)",
    button.state.selected == true and button:IsSelected() == true
    and button._hoverBg.shown == true and rgba(button._hoverBg.color, 0.2, 0.8, 0.6, 0.10), fmt(button._hoverBg.color))
check("selected: accent border .8, white 1 text",
    rgba(borderColor(button), 0.2, 0.8, 0.6, 0.8) and rgba(button.text.color, 1, 1, 1, 1), fmt(borderColor(button)))
button:Fire("OnEnter")
check("selected hover: accent border 1", rgba(borderColor(button), 0.2, 0.8, 0.6, 1))
button:Fire("OnLeave")
button:SetEnabled(false)
check("selected+disabled: disabled treatment wins (text .30, disabledBg)",
    rgba(button.text.color, 1, 1, 1, 0.30) and rgba(button._hoverBg.color, 1, 1, 1, 0.04))
button:SetEnabled(true)
button:SetSelected(false)
check("deselected: ghost idle", button._hoverBg.shown == false and rgba(button.text.color, 1, 1, 1, 0.85))

---------------------------------------------------------------------------
-- Variants: primary (accent border/fill, white text), destructive (red)
---------------------------------------------------------------------------
button:SetVariant("primary")
check("primary idle: accent border .5, accent fill .12, white 1 text",
    button:GetVariant() == "primary"
    and rgba(borderColor(button), 0.2, 0.8, 0.6, 0.5)
    and button._hoverBg.shown == true and rgba(button._hoverBg.color, 0.2, 0.8, 0.6, 0.12)
    and rgba(button.text.color, 1, 1, 1, 1),
    fmt(borderColor(button)) .. " fill=" .. fmt(button._hoverBg.color) .. " text=" .. fmt(button.text.color))
button:Fire("OnEnter")
check("primary hover: border 1, fill .20", rgba(borderColor(button), 0.2, 0.8, 0.6, 1) and rgba(button._hoverBg.color, 0.2, 0.8, 0.6, 0.20))
button:Fire("OnMouseDown")
check("primary pressed: fill .24", rgba(button._hoverBg.color, 0.2, 0.8, 0.6, 0.24), fmt(button._hoverBg.color))
button:Fire("OnMouseUp")
button:Fire("OnLeave")
button:SetEnabled(false, "nope")
check("primary disabled: accent border .25, disabledBg fill, text .30",
    rgba(borderColor(button), 0.2, 0.8, 0.6, 0.25) and rgba(button._hoverBg.color, 1, 1, 1, 0.04)
    and rgba(button.text.color, 1, 1, 1, 0.30), fmt(borderColor(button)))
button:SetEnabled(true)

button:SetVariant("destructive")
check("destructive: red border .5 + red fill, white text",
    rgba(borderColor(button), 0.85, 0.30, 0.30, 0.5) and rgba(button._hoverBg.color, 0.85, 0.30, 0.30, 0.12)
    and rgba(button.text.color, 1, 1, 1, 1), fmt(borderColor(button)))
button:SetVariant("ghost")
check("back to ghost: white border .2, no fill", rgba(borderColor(button), 1, 1, 1, 0.2) and button._hoverBg.shown == false)

local created = UIKit.CreateButton(panel, { text = "Go", variant = "primary" })
check("opts.variant honoured at creation", created:GetVariant() == "primary" and rgba(borderColor(created), 0.2, 0.8, 0.6, 0.5))

---------------------------------------------------------------------------
-- Accent re-tint: ONE listener for all buttons, primary/selected follow
---------------------------------------------------------------------------
check("exactly one accent listener registered for all buttons", #accentListeners == 1, tostring(#accentListeners))
button:SetSelected(true)
QUI.GUI.Colors.accent[1], QUI.GUI.Colors.accent[2], QUI.GUI.Colors.accent[3] = 0.9, 0.1, 0.5
for _, fn in ipairs(accentListeners) do fn() end
check("primary button re-tinted on accent change", rgba(borderColor(created), 0.9, 0.1, 0.5, 0.5), fmt(borderColor(created)))
check("selected ghost re-tinted on accent change",
    rgba(borderColor(button), 0.9, 0.1, 0.5, 0.8) and rgba(button._hoverBg.color, 0.9, 0.1, 0.5, 0.10), fmt(borderColor(button)))
QUI.GUI.Colors.accent[1], QUI.GUI.Colors.accent[2], QUI.GUI.Colors.accent[3] = 0.2, 0.8, 0.6
for _, fn in ipairs(accentListeners) do fn() end
button:SetSelected(false)

---------------------------------------------------------------------------
-- SetBorderColor override (ghost danger tint) survives refreshes
---------------------------------------------------------------------------
button:SetBorderColor(0.95, 0.45, 0.45, 1)
check("border override applied", rgba(borderColor(button), 0.95, 0.45, 0.45, 1))
button:Fire("OnEnter"); button:Fire("OnLeave")
check("border override survives hover refresh", rgba(borderColor(button), 0.95, 0.45, 0.45, 1), fmt(borderColor(button)))
button:SetEnabled(false)
check("border override halved when disabled", rgba(borderColor(button), 0.95, 0.45, 0.45, 0.5), fmt(borderColor(button)))
button:SetEnabled(true)

---------------------------------------------------------------------------
-- opts.tooltip + reason: reason wins while disabled; GameTooltip fallback
-- when the button is not under the options panel
---------------------------------------------------------------------------
local tipped = UIKit.CreateButton(panel, { text = "Tip", tooltip = "Normal help" })
tipLog = {}
tipped:Fire("OnEnter")
check("opts.tooltip shows through the service when enabled", tipLog[1] and tipLog[1].body == "Normal help")
tipped:Fire("OnLeave")
tipped:SetEnabled(false, "Locked")
tipLog = {}
tipped:Fire("OnEnter")
check("disabled: reason shown last (wins over opts.tooltip)",
    #tipLog >= 1 and tipLog[#tipLog].op == "show" and tipLog[#tipLog].body == "Locked",
    tipLog[#tipLog] and tostring(tipLog[#tipLog].body))
tipped:Fire("OnLeave")
check("leave hides once for the owner", tipLog[#tipLog].op == "hide" and tipLog[#tipLog].owner == tipped)

local orphanParent = NewFrame("Frame", nil)
local orphan = UIKit.CreateButton(orphanParent, { text = "World" })
orphan:SetEnabled(false, "Not in combat")
GameTooltip.calls = {}
orphan:Fire("OnEnter")
local sawReason = false
for _, c in ipairs(GameTooltip.calls) do if c[1] == "SetText" and c[2] == "Not in combat" then sawReason = true end end
check("outside the panel the reason routes to GameTooltip", sawReason and GameTooltip.shown == true)
orphan:Fire("OnLeave")
check("GameTooltip hidden on leave", GameTooltip.shown == false)

if failures > 0 then
    print(("FAILED: %d check(s)"):format(failures))
    os.exit(1)
end
print("OK: uikit_button_state_test")
