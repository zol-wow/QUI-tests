local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin = env.SkinBase
local NewFrame = env.NewFrame
env.NewFrame = function(...)
    local frame = NewFrame(...)
    frame.DisabledTexture = false
    return frame
end
local function Rounded(frame, radius, alpha)
    local backdrop = skin.GetBackdrop(frame)
    assert(backdrop and backdrop._quiRoundedSurface, "shared skin helpers must render rounded chrome")
    local surface = backdrop._quiRoundedSurface
    assert(surface.radius == radius, "shared chrome must use the requested radius")
    assert(surface.background.color[4] == alpha, "rounding must preserve fill opacity")
    return backdrop, surface
end
local button = env.NewFrame("Button")
skin.SkinButton(button, {font = false})
local backdrop, surface = Rounded(button, 5, 1)
local click = function() end
button:SetScript("OnClick", click)
button:Fire("OnEnter")
assert(button:GetScript("OnClick") == click, "hover styling must preserve click ownership")
button:Fire("OnLeave")
local count = #env.textures
skin.SkinButton(button)
assert(#env.textures == count, "repeated skinning must reuse surfaces")
env.colors[5] = .15
skin.RefreshWidget(button)
assert(surface.background.color[1] > .15, "theme refresh must update rounded fill")
local edit = env.NewFrame("EditBox")
skin.SkinEditBox(edit, {font = false, bgAlpha = .7})
Rounded(edit, 4, .7)
local row = env.NewFrame("Button")
skin.SkinScrollRow(row)
Rounded(row, 4, .6)
local dropdown = env.NewFrame("Button")
skin.SkinDropdown(dropdown, {noStrip = true})
Rounded(dropdown, 5, 1)
local tab = env.NewFrame("Button")
skin.SkinTabButton(tab, {font = false})
Rounded(tab, 5, .9)
local window = env.NewFrame("Frame")
skin.SkinWindow(window)
Rounded(window, 8, .95)
local template = env.NewFrame("Frame")
skin.SkinButtonFrameTemplate(template)
Rounded(template, 8, .95)
local custom = env.NewFrame("Button")
skin.SkinButton(custom, {font = false, radius = 3})
Rounded(custom, 3, 1)
local category = env.NewFrame("Button")
category.SelectedTexture = category:CreateTexture()
skin.SkinCategoryButton(category, {font = false})
Rounded(category, 5, .75)
category.SelectedTexture:Hide()
skin.RefreshCategorySelected(category)
Rounded(category, 5, .7)
local raw = env.NewFrame("Frame")
skin.CreateBackdrop(raw)
assert(not skin.GetBackdrop(raw)._quiRoundedSurface, "raw pixel backdrops must retain explicit opt-in")
local bar = env.NewFrame("StatusBar")
bar:SetSize(250, 20)
bar.CreateMaskTexture = bar.CreateTexture
local fill = bar:CreateTexture()
local mask
fill.AddMaskTexture = function(_, value) mask = value end
bar.GetStatusBarTexture = function() return fill end
bar.SetValue = function() error("skinning must not change bar values") end
skin.SkinStatusBar(bar, { color = { .3, .7, .5, 1 } })
local barBackdrop, barSurface = Rounded(bar, 6, .95)
assert(mask == skin.GetFrameData(bar, "roundedBarMask"), "status bar fill must be clipped with its rounded chrome")
skin.SetBackdropColors(barBackdrop, { 1, 1, 1, 1 }, { 0, 0, 0, 0 })
assert(barSurface.background.color[4] == 0 and barSurface.border.top.color[4] == 1,
    "curved borders must preserve independent background opacity")
barBackdrop:SetSize(80, 8)
barSurface:Refresh()
assert(barSurface.resolvedRadius <= 4, "short bars must clamp rounded corners to fit their height")
assert(backdrop.mouse == false, "rounded backing must not intercept mouse input")
print("OK: skinning_shared_rounded_controls_test")
