local function read(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end

local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin = env.SkinBase
local source = read(os.getenv("QUI_JOURNALS_SOURCE") or "modules/skinning/frames/journals.lua")
local first = assert(source:find("local pendingPlayerSpellsStyles", 1, true))
local last = assert(source:find("local function SkinPlayerSpellsText(", first, true))
local chunk = assert(loadstring(source:sub(first, last - 1)
    .. "\nreturn StyleSpellBookControls, StylePlayerSpellsControls"))
setfenv(chunk, setmetatable({ SkinBase = skin, IsSettingEnabled = function() return true end }, { __index = _G }))
local styleBook, styleFrame = chunk()
local root = env.NewFrame("Frame")
root.SpellBookFrame = env.NewFrame("Frame", nil, root)
local dropdown = env.NewFrame("DropdownButton", nil, root.SpellBookFrame)
dropdown.DisabledTexture = false
root.SpellBookFrame.SettingsDropdown = dropdown
local nativeRoot = "tests/clients/forever/framexml/Interface/AddOns/Blizzard_SharedXML/Mainline/"
local xml = read(nativeRoot .. "SharedUIPanelTemplates.xml")
local template = assert(xml:match('(<DropdownButton name="UIPanelArrowDropdownButtonTemplate".-</DropdownButton>)'))
local width, height = template:match('<Size x="(%d+)" y="(%d+)"')
dropdown:SetSize(tonumber(width), tonumber(height))
dropdown.Icon = dropdown:CreateTexture()
dropdown.Icon:SetAtlas("common-dropdown-a-button")
local click = function() end
dropdown:SetScript("OnMouseDown", click)
dropdown.menuGenerator = click
root.MaximizeMinimizeButton = env.NewFrame("Frame", nil, root)
local resize = root.MaximizeMinimizeButton
local native = read(nativeRoot .. "SharedUIPanelTemplates.lua")
local mixin = {}
local loadSize = assert(loadstring(assert(native:match("(function MaximizeMinimizeButtonFrameMixin:OnLoad%(%).-\nend)"))))
setfenv(loadSize, { MaximizeMinimizeButtonFrameMixin = mixin })
loadSize()
mixin.OnLoad(resize)
for _, key in ipairs({ "MaximizeButton", "MinimizeButton" }) do
    local button = env.NewFrame("Button", nil, resize)
    resize[key] = button
    button.DisabledTexture = false
    button:SetAllPoints(resize)
    button:SetScript("OnClick", click)
end

styleBook(root)
assert(skin.GetBackdrop(dropdown), "spellbook settings dropdown must receive QUI chrome")
assert(dropdown.Icon:GetAlpha() == 0, "native dropdown artwork must be hidden")
local caret = assert(skin.GetFrameData(dropdown, "dropdownCaret"), "dropdown needs a QUI caret")
skin.SetChevronCaretExpanded(caret, true)
local point, relative, relativePoint, x, y = caret:GetPoint()
assert(point == "CENTER" and relative == dropdown and relativePoint == "CENTER" and x == 0 and y == 0,
    "narrow dropdown caret must stay centered when its layout refreshes")
assert(dropdown:GetWidth() == tonumber(width) and dropdown:GetHeight() == tonumber(height)
    and dropdown:GetScript("OnMouseDown") == click and dropdown.menuGenerator == click,
    "dropdown geometry and native menu behavior must remain intact")

styleFrame(root)
for _, key in ipairs({ "MaximizeButton", "MinimizeButton" }) do
    local button = resize[key]
    assert(not skin.GetBackdrop(button), "resize header glyph must not have a box protruding above the window")
    local glyph = assert(skin.GetFrameData(button, "closeLabel"))
    assert(glyph:GetText() == (key == "MaximizeButton" and "+" or "-"),
        "both resize states must keep their identifying glyph")
    assert(button.allPoints == resize and button:GetScript("OnClick") == click
        and resize:GetWidth() == 24 and resize:GetHeight() == 24,
        "resize styling must preserve native dimensions, anchors and click handlers")
end
styleBook(root)
styleFrame(root)
assert(skin.GetFrameData(dropdown, "dropdownCaret") == caret, "refresh must reuse the caret")
print("OK: spellbook header dropdown and resize chrome")
