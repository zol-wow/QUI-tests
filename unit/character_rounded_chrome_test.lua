local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.SetGates(true, true)
local cf = env.BuildCharacterFrame()
local flyout = env.Chrome.CreateSettingsFlyout(cf, {
    title = "Character",
    provider = function(ctx)
        local row = env.NewFrame("Frame", nil, ctx.scrollChild)
        row:SetHeight(48)
        local width
        row.Layout = function(_, value) width = value end
        local y = ctx.PlaceRow(row, ctx.y)
        assert(width and width > 0, "settings rows must receive available layout width")
        assert(y == ctx.y - 48, "settings placement must respect actual control height")
        return y
    end,
})
assert(flyout.panel._quiRoundedSurface, "settings panel must use rounded chrome")
flyout.trigger.scripts.OnClick(flyout.trigger)
local panel = flyout.panel
panel:SetBackdropColor(.2, .3, .4, .8)
local color = panel._quiRoundedSurface.background.color
assert(color[1] == .2 and color[4] == .8, "rounded surfaces must follow live backdrop color changes")
local bar = env.NewFrame("StatusBar")
local texture = bar:CreateTexture()
bar.CreateMaskTexture = bar.CreateTexture
local attached
local attachmentCount = 0
texture.AddMaskTexture = function(_, mask) attached = mask; attachmentCount = attachmentCount + 1 end
env.SkinBase.RoundBarTexture(bar, texture)
assert(attached and attached == env.SkinBase.GetFrameData(bar, "roundedBarMask"), "bar fill must share the owner clip mask")
local first = attached
env.SkinBase.RoundBarTexture(bar, texture)
assert(attached == first, "reused rows must reuse their bar mask")
assert(attachmentCount == 1, "refreshing an existing fill must not reattach the same native mask")
local replacement = bar:CreateTexture()
local replacementCount = 0
replacement.AddMaskTexture = function(_, mask)
    assert(mask == first, "a replacement fill must use the existing owner mask")
    replacementCount = replacementCount + 1
end
env.SkinBase.RoundBarTexture(bar, replacement)
env.SkinBase.RoundBarTexture(bar, replacement)
assert(replacementCount == 1, "a replacement fill needs one native mask attachment")
env.SkinBase.RoundBarTexture(bar, texture)
assert(attachmentCount == 1, "switching back to the original fill must preserve its attachment")
print("OK: character_rounded_chrome_test")
