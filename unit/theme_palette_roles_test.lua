-- tests/unit/theme_palette_roles_test.lua
-- Run: luajit tests/unit/theme_palette_roles_test.lua
--
-- Palette contract (UI polish, Phase 1): core/theme.lua is the single owner of
-- GUI.Colors. It carries the white/alpha state ladder (disabled .30, tabNormal
-- .55, tabHover .85, tabSelectedText 1), the accent-derived roles
-- (selectedWash, scrollThumb, accentText) and the scrollbar roles, and
-- GUI:ApplyAccentColor recomputes every derived role. accentText is the accent
-- lightened toward white until its relative luminance reaches
-- GUI.ACCENT_TEXT_MIN_LUMINANCE, so a dark custom accent stays readable as
-- text. Persistent chrome that outlives the options panel rebuild subscribes
-- via GUI:OnAccentChanged and is notified from GUI:RefreshAccentColor.

local function readFile(path)
    local fh = assert(io.open(path, "rb"), "failed to open " .. path)
    local text = fh:read("*a")
    fh:close()
    return text
end

local function near(a, b, eps)
    return math.abs(a - b) <= (eps or 1e-6)
end

-------------------------------------------------------------------------------
-- Part A: source contract — one palette literal, dead duplicates gone
-------------------------------------------------------------------------------
local theme = readFile("core/theme.lua")
local shell = readFile("core/gui_shell.lua")
local framework = readFile("QUI_Options/framework.lua")

local function colorLiteralKeys(body)
    local blockStart = body:find("GUI.Colors = GUI.Colors or {", 1, true)
    if not blockStart then return {} end
    local blockEnd = assert(body:find("\n}", blockStart, true))
    local keys = {}
    for key in body:sub(blockStart, blockEnd):gmatch("\n%s%s%s%s(%w+)%s*=%s*{") do
        keys[key] = true
    end
    return keys
end

local themeKeys = colorLiteralKeys(theme)
for _, role in ipairs({
    "accent", "accentFaint", "accentGlow", "tabSelected", "tabSelectedText",
    "tabNormal", "tabHover", "text", "textBright", "textMuted", "textDim",
    "sectionLabel", "disabled", "disabledBg", "selectedWash", "accentText",
    "scrollThumb", "scrollTrack", "borderAccent",
}) do
    assert(themeKeys[role], "core/theme.lua palette literal must define role: " .. role)
end

assert(not shell:find("GUI.Colors = GUI.Colors or {", 1, true),
    "core/gui_shell.lua must reference the theme palette, not redefine it")
assert(next(colorLiteralKeys(framework)) == nil,
    "QUI_Options/framework.lua must not define palette roles (theme.lua owns them)")
assert(not framework:find("function GUI:ApplyAccentColor", 1, true),
    "framework.lua must not shadow GUI:ApplyAccentColor (theme.lua owns accent derivation)")
assert(select(2, theme:gsub("function GUI:ApplyAccentColor%(r, g, b%)", "")) == 1,
    "core/theme.lua must define GUI:ApplyAccentColor exactly once")

-- consumers wired to the roles (R5 / S2)
assert(framework:find("self:NotifyAccentChanged()", 1, true),
    "GUI:RefreshAccentColor must notify accent listeners")
assert(not framework:find("SetColorTexture(0.204, 0.827, 0.6, 0.04)", 1, true)
    and not framework:find("SetColorTexture(0.204, 0.827, 0.6, 0.08)", 1, true),
    "dropdown pool fills must come from live palette tokens, not Classic Mint literals")
assert(framework:find("C.selectedWash", 1, true),
    "dropdown selected fill must use selectedWash")
assert(not readFile("QUI_Options/shared.lua"):find("0.35, 0.45, 0.5, 0.8", 1, true),
    "shared.lua scrollbar thumb must use scrollThumb, not the slate literal")
for _, needle in ipairs({
    "SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.5)",
    "SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.7)",
}) do
    assert(not framework:find(needle, 1, true),
        "framework.lua scrollbar thumbs must use scrollThumb: " .. needle)
end
local uikit = readFile("core/uikit.lua")
do
    local s = assert(uikit:find("function SkinBase.SkinTrimScrollBar", 1, true))
    local e = assert(uikit:find("\nend\n", s, true))
    local body = uikit:sub(s, e)
    assert(not body:find("GetSkinBarColor", 1, true),
        "SkinTrimScrollBar must not fall back to the skin bar/border colour")
    assert(body:find("scrollThumb", 1, true),
        "SkinTrimScrollBar fallback must be the scrollThumb role")
end

-------------------------------------------------------------------------------
-- Part B: behaviour — load core/theme.lua headlessly
-------------------------------------------------------------------------------
local ns = {}
local safeCalls = 0
ns.SafeCall = function(_, fn, ...)
    safeCalls = safeCalls + 1
    local ok, err = pcall(fn, ...)
    return ok, err
end
_G.QUI = nil
assert(loadfile("core/theme.lua"))("QUI", ns)
local GUI = assert(_G.QUI and _G.QUI.GUI, "theme.lua must create QUI.GUI")
local C = assert(GUI.Colors, "theme.lua must create GUI.Colors")

local function assertRole(name, r, g, b, a)
    local role = assert(C[name], "missing palette role: " .. name)
    assert(near(role[1], r) and near(role[2], g) and near(role[3], b) and near(role[4], a),
        string.format("%s = {%.3f, %.3f, %.3f, %.3f}, expected {%.3f, %.3f, %.3f, %.3f}",
            name, role[1], role[2], role[3], role[4], r, g, b, a))
end

assertRole("disabled", 1, 1, 1, 0.30)
assertRole("disabledBg", 1, 1, 1, 0.04)
assertRole("tabNormal", 1, 1, 1, 0.55)
assertRole("tabHover", 1, 1, 1, 0.85)
assertRole("tabSelectedText", 1, 1, 1, 1)
assertRole("selectedWash", 0.204, 0.827, 0.6, 0.10)
assertRole("scrollThumb", 0.204, 0.827, 0.6, 0.6)
assertRole("scrollTrack", 1, 1, 1, 0.02)
assertRole("accentFaint", 0.204, 0.827, 0.6, 0.07)
-- Classic Mint is already above the floor, so accentText == accent.
assertRole("accentText", 0.204, 0.827, 0.6, 1)

assert(type(GUI.GetRelativeLuminance) == "function", "GUI:GetRelativeLuminance missing")
assert(near(GUI:GetRelativeLuminance(1, 1, 1), 1) and near(GUI:GetRelativeLuminance(0, 0, 0), 0),
    "relative luminance must be 0 for black and 1 for white")
local FLOOR = assert(GUI.ACCENT_TEXT_MIN_LUMINANCE, "GUI.ACCENT_TEXT_MIN_LUMINANCE missing")
assert(near(FLOOR, 0.45), "accentText luminance floor must be 0.45")

-- Dark accent (navy): every derived role follows the hue, keeps its own alpha,
-- and accentText is lifted to the luminance floor along the accent->white ray.
local dr, dg, db = 0.05, 0.05, 0.25
assert(GUI:GetRelativeLuminance(dr, dg, db) < FLOOR, "test accent must start below the floor")
GUI:ApplyAccentColor(dr, dg, db)
assertRole("accent", dr, dg, db, 1)
assertRole("selectedWash", dr, dg, db, 0.10)
assertRole("scrollThumb", dr, dg, db, 0.6)
assertRole("accentFaint", dr, dg, db, 0.07)
assertRole("accentGlow", dr, dg, db, 0.06)
assertRole("tabSelected", dr, dg, db, 1)
assertRole("borderAccent", dr, dg, db, 1)
local at = C.accentText
local lum = GUI:GetRelativeLuminance(at[1], at[2], at[3])
assert(lum >= FLOOR - 1e-4,
    string.format("accentText luminance %.4f must reach the floor %.2f", lum, FLOOR))
assert(lum < FLOOR + 0.02,
    string.format("accentText should stop just above the floor, got %.4f", lum))
-- on the ray toward white: the lift t is the same on every channel
local t1 = (at[1] - dr) / (1 - dr)
local t3 = (at[3] - db) / (1 - db)
assert(near(t1, t3, 1e-4), "accentText must lerp uniformly toward white")
assert(near(at[4], 1), "accentText alpha must stay 1")

-- Accent already above the floor (Classic Mint, L~0.50): accentText == accent.
GUI:ApplyAccentColor(0.204, 0.827, 0.6)
assertRole("accentText", 0.204, 0.827, 0.6, 1)
-- Just below the floor (Amber, L~0.44): lifted only slightly, hue preserved.
GUI:ApplyAccentColor(0.961, 0.620, 0.043)
local amber = C.accentText
assert(amber[1] > 0.961 and amber[1] < 0.98 and amber[2] > 0.620 and amber[2] < 0.66,
    "accentText for Amber must be a small lift toward white")
assert(GUI:GetRelativeLuminance(amber[1], amber[2], amber[3]) >= FLOOR - 1e-4,
    "Amber accentText must reach the floor")

-- Listener registry.
local seen, order = 0, {}
local function listenerA(colors) seen = seen + 1; order[#order + 1] = "A"; assert(colors == C) end
local function listenerB() order[#order + 1] = "B" end
assert(GUI:OnAccentChanged(listenerA) == true, "first registration must succeed")
assert(GUI:OnAccentChanged(listenerA) == false, "duplicate registration must be ignored")
GUI:OnAccentChanged(function() error("boom") end)
GUI:OnAccentChanged(listenerB)
assert(GUI:OnAccentChanged("nope") == false, "non-function must be rejected")
local dispatched = GUI:NotifyAccentChanged()
assert(dispatched == 3, "expected 3 listeners dispatched, got " .. tostring(dispatched))
assert(seen == 1, "listenerA must fire exactly once per notify")
assert(order[1] == "A" and order[2] == "B",
    "an erroring listener must not stop later listeners (SafeCall bulkhead)")
assert(safeCalls == 3, "listeners must be dispatched through ns.SafeCall")
assert(GUI:OffAccentChanged(listenerA) == true and GUI:OffAccentChanged(listenerA) == false,
    "OffAccentChanged must remove exactly once")
GUI:NotifyAccentChanged()
assert(seen == 1, "removed listener must not fire")

print("PASS theme_palette_roles_test")
