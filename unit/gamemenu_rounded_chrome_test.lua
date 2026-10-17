local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local settings = env.profile.general
settings.skinGameMenu = true
settings.addQUIButton, settings.addEditModeButton = false, false
_G.GameMenuFrame = env.NewFrame("Frame")
GameMenuFrame.InitButtons = function() end
local button = env.NewFrame("Button", nil, GameMenuFrame)
button.Text = button:CreateFontString()
GameMenuFrame.buttonPool = {EnumerateActive = function() return pairs({[button] = true}) end}
assert(loadfile(os.getenv("QUI_MENU_SOURCE") or "modules/skinning/system/gamemenu.lua"))("QUI", env.ns)
GameMenuFrame:InitButtons()
assert(_G.QUIGameMenuBg._quiRoundedSurface, "game menu shell must use the shared rounded renderer")
local inset = button.children[1]
assert(inset and inset._quiRoundedSurface, "pooled game menu buttons must use rounded chrome")
assert(inset._quiRoundedSurface.background.color[4] == 1, "button fill must remain opaque")
local count = #env.textures
GameMenuFrame:InitButtons()
assert(#env.textures == count, "reopening must reuse rounded textures")
env.colors[5] = .15
_G.QUI_RefreshGameMenuColors()
assert(_G.QUIGameMenuBg._quiRoundedSurface.background.color[1] == .15, "theme refresh must update the rounded shell")
print("OK: gamemenu_rounded_chrome_test")
