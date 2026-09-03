-- tests/unit/shopping_tooltip_compare_header_skinning_test.lua
-- Run: lua tests/unit/shopping_tooltip_compare_header_skinning_test.lua

local function readFile(path)
    local fh = assert(io.open(path, "rb"), "failed to open " .. path)
    local text = fh:read("*a")
    fh:close()
    return text
end

local function assertContains(text, needle, reason)
    assert(text:find(needle, 1, true), reason)
end

local source = readFile("modules/skinning/system/tooltips.lua")

assertContains(
    source,
    "local SkinBase = ns.SkinBase",
    "tooltip skinning must use SkinBase for shopping tooltip compare headers")

assertContains(
    source,
    "local function StyleShoppingCompareHeader(header, sr, sg, sb, sa, bgr, bgg, bgb, bga)",
    "shopping tooltip compare headers must have a dedicated styler")

assertContains(
    source,
    "SkinBase.StripTextures(header)",
    "shopping tooltip compare headers must strip Blizzard's tooltip-compare-label texture")

assertContains(
    source,
    "SkinBase.CreateBackdrop(header, sr, sg, sb, sa, bgr, bgg, bgb, 0.92)",
    "shopping tooltip compare headers must create QUI tab chrome")

assertContains(
    source,
    "SkinBase.SetPixelInsetPoints(bd, header, 3, 3, 3, 0)",
    "shopping tooltip compare headers must use the same bottom-merging tab inset as other tabs")

-- Border colour is not a text colour: a black or hidden custom border must not
-- produce an invisible label, so the header goes through the luminance-floored
-- SkinBase.GetSkinTextAccent() (border tint when readable, white otherwise).
assertContains(
    source,
    "tr, tg, tb = SkinBase.GetSkinTextAccent()",
    "shopping tooltip compare header labels must resolve their colour via GetSkinTextAccent")

assertContains(
    source,
    "header.Label:SetTextColor(tr, tg, tb, 1)",
    "shopping tooltip compare header labels must use the luminance-floored text accent")

assert(not source:find("header.Label:SetTextColor(sr, sg, sb, 1)", 1, true),
    "shopping tooltip compare header labels must not use the raw border colour as text")

assertContains(
    source,
    "StyleShoppingCompareHeader(tooltip.CompareHeader, sr, sg, sb, sa, bgr, bgg, bgb, bga)",
    "tooltip chrome application must style the shopping compare header when present")

print("OK: shopping_tooltip_compare_header_skinning_test")
