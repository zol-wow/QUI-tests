-- tests/unit/auctionhouse_craftingorders_font_test.lua
-- Run: lua tests/unit/auctionhouse_craftingorders_font_test.lua
--
-- Regression guard: the Auction House and Crafting Orders skins must apply the
-- global QUI font to their key labels (tabs, category buttons, search box,
-- action buttons) via the shared SkinBase font plumbing. Backgrounds/borders
-- already track the theme; this pins the text-font/color wiring so it can't
-- silently regress. Dense list rows / money frames are intentionally left on
-- Blizzard fonts and are NOT asserted here.

local function readFile(path)
    local fh = assert(io.open(path, "rb"), "failed to open " .. path)
    local text = fh:read("*a")
    fh:close()
    return text
end

local function assertContains(text, needle, reason)
    assert(text:find(needle, 1, true), reason)
end

---------------------------------------------------------------------------
-- Auction House
---------------------------------------------------------------------------
local ah = readFile("modules/skinning/frames/auctionhouse.lua")

assertContains(ah, "SkinTabGroup(AuctionHouseFrame.Tabs, AuctionHouseFrame, { font = true, resizeToText = true })",
    "AH tabs must opt in to the global QUI font")
assertContains(ah, "SkinEditBox(searchBar.SearchBox, { font = true })",
    "AH search box must use the global QUI font")
assertContains(ah, "local AH_CATEGORY_TEXT_COLOR",
    "AH category buttons must use a muted idle text color instead of hover-bright text")
-- The idle colour is handed to SkinCategoryButton as `textColor`; the state
-- colour is owned by RefreshCategorySelected. A trailing colour-carrying
-- ApplyButtonFontObjects used to overwrite the SELECTED row back to idle on
-- every rebind (R2), so it must stay colour-free.
assertContains(ah, "textColor = AH_CATEGORY_TEXT_COLOR",
    "AH category buttons must pass the muted idle colour to SkinCategoryButton")
assertContains(ah, "selectedTextColor = AH_CATEGORY_SELECTED_TEXT_COLOR",
    "AH category buttons must pass a bright selected colour to SkinCategoryButton")
assertContains(ah, "SkinBase.ApplyButtonFontObjects(button)\n",
    "AH category buttons must reapply the QUI font face (colour-free) on every Blizzard rebind")
assert(not ah:find("ApplyButtonFontObjects(button, { color = AH_CATEGORY_TEXT_COLOR })", 1, true),
    "AH category rebind must not overwrite the selected row's text colour with the idle colour")
local styleRowStart = assert(ah:find("local function StyleCategoryRow(button)", 1, true))
local styleRowBody = ah:sub(styleRowStart, (ah:find("\n    end\n", styleRowStart, true)))
local fontAt = assert(styleRowBody:find("SkinBase.ApplyButtonFontObjects(button)", 1, true))
local refreshAt = assert(styleRowBody:find("SkinBase.RefreshCategorySelected(button)", 1, true))
assert(fontAt < refreshAt, "AH category state colour must be applied AFTER the font-face reapply")
assertContains(ah, "SkinButton(commoditiesSell.PostButton, { font = true })",
    "AH action buttons must use the global QUI font")
assertContains(ah, "SkinQuantityInputFrame(commoditiesSell.QuantityInput)",
    "AH commodity sell quantity controls must skin the Max button as well as the input")
assertContains(ah, "SkinQuantityInputFrame(itemSell.QuantityInput)",
    "AH item sell quantity controls must skin the Max button as well as the input")
assertContains(ah, "SkinBase.SkinButton(quantityInput.MaxButton, { font = true })",
    "AH sell Max button must use button font-object skinning")
assertContains(ah, "RefreshQuantityInputFrame(commoditiesSell.QuantityInput)",
    "AH commodity sell Max button must refresh on live theme changes")
assertContains(ah, "RefreshQuantityInputFrame(itemSell.QuantityInput)",
    "AH item sell Max button must refresh on live theme changes")
assertContains(ah, "SkinBase.RefreshWidget(quantityInput.MaxButton)",
    "AH sell Max button must reapply colors and font objects on refresh")

---------------------------------------------------------------------------
-- Crafting Orders
---------------------------------------------------------------------------
local co = readFile("modules/skinning/frames/craftingorders.lua")

assertContains(co, "SkinTabGroup(tabs, frame, { font = true, resizeToText = true })",
    "CO tabs must opt in to the global QUI font")
assertContains(co, "SkinEditBox(searchBar.SearchBox, { font = true })",
    "CO search box must use the global QUI font")
assertContains(co, "SkinBase.SkinFontString(button.Text)",
    "CO category buttons must reapply the QUI font on rebind")
assertContains(co, "SkinButton(form.BackButton, { font = true })",
    "CO action buttons must use the global QUI font")

print("OK: auctionhouse_craftingorders_font_test")
