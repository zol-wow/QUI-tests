local baseline = arg[1]
arg = {}
local file = assert(io.open("tests/unit/options_inline_preview_mounting_test.lua", "rb"))
local source = file:read("*a")
file:close()
local finish = assert(source:find("ns.QUI_Options.CreateScrollableContent =", 1, true))
local ns = assert(loadstring(source:sub(1, finish - 1) .. "\nreturn ns"))()
if baseline then assert(loadfile(baseline))("QUI", ns) end
local F = ns.Settings.FullSurface
local parent = CreateFrame("Frame", nil, UIParent)
parent:SetSize(700, 190)
parent._quiPreviewCollapsedHeight = 38
local host = CreateFrame("Frame", nil, parent)
host:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -42)
host:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -14, 12)
parent._quiPreviewHost = host
parent._quiPreviewChromeHeight = 54
F.ConfigureInlinePreview(parent, function() return 285 end)
for _, height in ipairs({190, 285}) do
    parent:SetHeight(height)
    F.SetInlinePreviewCollapsed(parent, true)
    parent._height = 38.00030517578
    parent:GetScript("OnSizeChanged")(parent, 700, parent._height)
    F.SetInlinePreviewCollapsed(parent, false)
    assert(math.abs(parent:GetHeight() - height) < 0.5,
        "fractional folded height must not replace the expanded preview height")
    assert(host:IsShown(), "unfolding must restore the preview host")
end
print("options_preview_fractional_collapse_test: ok")
