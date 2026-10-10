local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local file = assert(io.open(os.getenv("QUI_JOURNALS_SOURCE") or "modules/skinning/frames/journals.lua"))
local source = file:read("*a"); file:close()
local first = assert(source:find("local function GetSpellBookFrame(", 1, true))
local last = assert(source:find("local function SkinSpellRows(", first, true))
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn StyleSpellBookControls"))
setfenv(chunk, setmetatable({ SkinBase = env.SkinBase }, { __index = _G }))
local apply = chunk()
local root = env.NewFrame("Frame")
local book = env.NewFrame("Frame", nil, root)
root.SpellBookFrame = book
local rotation = env.NewFrame("Frame", nil, book)
book.AssistedCombatRotationSpellFrame = rotation
rotation.Divider = rotation:CreateTexture()
rotation.Button = env.NewFrame("Button", nil, rotation)
rotation.Button:SetSize(33, 33)
rotation.Button.Icon = rotation.Button:CreateTexture()
rotation.Button.Icon:SetTexture("native-assistant-spell")
rotation.Button.Border = rotation.Button:CreateTexture()
rotation.Button.BlackCover = rotation.Button:CreateTexture()
rotation.Label = rotation:CreateFontString()
rotation.Label:SetText("Single-Button|nAssistant")
local naturalWidth = 180
rotation.Label:SetWidth(80)
rotation.Label.GetStringWidth = function(self)
    local width = self:GetWidth()
    return width > 0 and math.min(width, naturalWidth) or naturalWidth
end
rotation.Label.GetUnboundedStringWidth = function(self)
    return self:GetText():find("|n", 1, true) and 80 or naturalWidth
end
rotation.Label.SetWordWrap = function(self, value) self.wrap = value end
rotation.Label.SetMaxLines = function(self, value) self.lines = value end
local nativeClick = function() end
rotation.Button:SetScript("OnClick", nativeClick)
rotation.UpdateDisplay = function(self)
    self.Label:SetText("Single-Button|nAssistant")
    self.Label:ClearAllPoints()
    self.Label:SetWidth(80)
    self.Button.Border:SetAlpha(1)
end
apply(root)
rotation:UpdateDisplay()
assert(rotation.Label:GetText() == "Single-Button Assistant",
    "native multiline caption must become one complete line")
assert(rotation.Label:GetWidth() >= naturalWidth
    and rotation.Label.wrap == false and rotation.Label.lines == 1,
    "native display updates must leave the assistant caption readable in one line")
assert(rotation:GetWidth() >= rotation.Label:GetWidth() + rotation.Button:GetWidth() + 16,
    "assistant header must reserve room for the full caption and icon")
assert(rotation.Divider:GetAlpha() == 0 and rotation.Button.Border:GetAlpha() == 0,
    "assistant header must remove native divider and gold frame")
assert(rotation.Button.BlackCover:GetAlpha() == 1
    and rotation.Button.Icon.texture == "native-assistant-spell"
    and rotation.Button:GetScript("OnClick") == nativeClick,
    "assistant spell artwork, usability overlay and native action stay intact")
print("OK: spellbook_assistant_header_test")
