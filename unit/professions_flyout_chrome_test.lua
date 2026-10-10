local sourcePath = os.getenv("QUI_PROFESSIONS_SOURCE") or "modules/skinning/frames/professions.lua"
local file = assert(io.open(sourcePath))
local source = file:read("*a"); file:close()
local first = assert(source:find("local function StyleProfessionFlyout(", 1, true), "profession flyout skin missing")
local last = assert(source:find("local function StyleProfessionRankBar(", first, true))
local enabled = true
local function Label() return { native = true } end
local click = function() end
local flyout = { Text = Label(), UndoItem = { Text = Label() }, HideUnownedCheckbox = { text = Label(), OnClick = click, checked = true }, ScrollBar = {}, item = { icon = "native-reagent", quality = "rare", count = 12, OnClick = click }, shown = true, width = 200 }
function flyout:SetBackdrop(value) self.nativeBackdrop = value end
local calls = 0
local skin = {
 StripTextures = function(f) f.stripped = true end,
 KillNineSlice = function() end,
 GetWindowColors = function() return .5, .4, .3, 1 end,
 GetDepthColor = function() return .1, .2, .3, .4 end,
 CreateBackdrop = function(f, sr, sg, sb, sa, r, g, b, a) f.chrome = { a = a }; calls = calls + 1 end,
 SkinCheckBox = function(c) c.skinned = true end,
 SkinTrimScrollBar = function(s) s.skinned = true end,
 GetBackdrop = function() return nil end,
 GetFrameData = function(f, k) return f[k] end,
 SetFrameData = function(f, k, v) f[k] = v end,
}
local mixin = {}
function mixin:InitializeContents() self.nativeBackdrop = "blizzard"; self.Text.native = true; self.HideUnownedCheckbox.text.native = true end
function mixin:Init() self:InitializeContents() end
local globals = { OpenProfessionsItemFlyout = function(_, _, behavior) behavior.flyout = flyout; flyout:Init() end }
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn StyleProfessionFlyout, HookProfessionFlyout"))
setfenv(chunk, setmetatable({ SkinBase = skin, IsEnabled = function() return enabled end, StyleProfessionNeutralText = function(l) if l then l.native = false end end, _G = globals, hooksecurefunc = function(t, key, cb) if type(t) == "string" then cb = key; key = t; t = globals end; local original = t[key]; t[key] = function(...) original(...); cb(...) end end }, { __index = _G }))
local apply, hook = chunk()
flyout.Init = mixin.Init
flyout.InitializeContents = mixin.InitializeContents
hook(); hook()
globals.OpenProfessionsItemFlyout({}, {}, {})
assert(flyout.nativeBackdrop == nil and flyout.chrome.a == 1, "flyout retains native translucent backdrop")
assert(not flyout.Text.native and not flyout.HideUnownedCheckbox.text.native, "flyout labels retain native chrome")
assert(flyout.HideUnownedCheckbox.skinned and flyout.ScrollBar.skinned)
assert(flyout.HideUnownedCheckbox.OnClick == click and flyout.HideUnownedCheckbox.checked, "native filter behavior changed")
assert(flyout.item.icon == "native-reagent" and flyout.item.quality == "rare" and flyout.item.count == 12 and flyout.item.OnClick == click)
local before = calls
flyout:InitializeContents()
assert(calls == before + 1 and flyout.nativeBackdrop == nil, "reused flyout loses styling or hooks repeat")
assert(flyout.shown and flyout.width == 200, "native sizing or visibility changed")
enabled = false
flyout:InitializeContents()
assert(flyout.nativeBackdrop == "blizzard" and calls == before + 1, "disabled profession skin modifies flyout")
print("profession flyout chrome and native behavior pass")
