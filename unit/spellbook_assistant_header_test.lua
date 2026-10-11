local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local file = assert(io.open(os.getenv("QUI_JOURNALS_SOURCE") or "modules/skinning/frames/journals.lua"))
local source = file:read("*a"); file:close()
local first = assert(source:find("local pendingPlayerSpellsStyles", 1, true)
    or source:find("local function GetSpellBookFrame(", 1, true))
local last = assert(source:find("local function SkinSpellRows(", first, true))
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn StyleSpellBookControls"))
setfenv(chunk, setmetatable({ SkinBase = env.SkinBase, IsSettingEnabled = function() return true end }, { __index = _G }))
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
local preview = env.NewFrame("Frame", nil, book)
book.SearchPreviewContainer = preview
for _, key in ipairs({ "Background", "BorderAnchor", "BotRightCorner", "BottomBorder", "LeftBorder", "RightBorder" }) do
    preview[key] = preview:CreateTexture(); preview[key]:SetTexture("native-search-chrome")
end
local result = env.NewFrame("Button", nil, preview)
result.Icon = result:CreateTexture(); result.Icon:SetTexture("native-spell"); result.Icon.desaturated = true
result.IconFrame = result:CreateTexture(); result.HighlightTexture = result:CreateTexture()
result.Name = result:CreateFontString(); result.Name:SetText("Frost Strike")
local normal = result:CreateTexture(); result.normalTexture = normal
local pushed = result:CreateTexture(); result.pushedTexture = pushed; result.GetPushedTexture = function(self) return self.pushedTexture end
local selected = 0; local selectResult = function() selected = selected + 1 end
result:SetScript("OnClick", selectResult)
preview.ScrollBox = { EnumerateFrames = function() local seen = false; return function() if not seen then seen = true; return 1, result end end end }
preview.UpdateResultsDisplay = function() normal:SetAlpha(1); pushed:SetAlpha(1) end
local nativeFile = assert(io.open("tests/framexml/Interface/AddOns/Blizzard_PlayerSpells/SpellBook/Blizzard_SpellBookFrame.lua"))
local nativeSource = nativeFile:read("*a"); nativeFile:close()
local nativeStart = assert(nativeSource:find("local SEARCH_BOX_MAX_WIDTH", 1, true))
local nativeEnd = assert(nativeSource:find("-- Expects a PlayerSpellsUtil", nativeStart, true))
local nativeMixin = {}
local nativeChunk = assert(loadstring(nativeSource:sub(nativeStart, nativeEnd - 1)))
setfenv(nativeChunk, setmetatable({ SpellBookFrameMixin = nativeMixin }, { __index = _G }))
nativeChunk()
book.CategoryTabSystem = env.NewFrame("Frame", nil, book)
book.CategoryTabSystem.GetRight = function() return 1027 end
book.SearchBox = env.NewFrame("EditBox", nil, book)
book.SearchBox:SetWidth(300)
book.SearchBox.GetRight = function() return 1242 end
book.SearchBox.GetLeft = function(self) return self:GetRight() - self:GetWidth() end
book.ResizeSearchBox = nativeMixin.ResizeSearchBox
apply(root)
assert(book.SearchBox:GetLeft() >= book.CategoryTabSystem:GetRight() + 10,
    "styled header must rerun native search sizing so category tabs cannot cover search input")
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
preview:UpdateResultsDisplay()
assert(preview.Background:GetAlpha() == 0 and preview.BorderAnchor:GetAlpha() == 0,
    "search suggestion container must suppress native brown chrome")
assert(normal:GetAlpha() == 0 and pushed:GetAlpha() == 0 and result.IconFrame:GetAlpha() == 0,
    "reused search results must suppress native row art")
assert(result.Icon.texture == "native-spell" and result.Icon.desaturated == true
    and result:GetScript("OnClick") == selectResult and result.Name:GetText() == "Frost Strike",
    "search styling preserves spell icon desaturation labels and selection")
result:GetScript("OnClick")(result); assert(selected == 1)
local combat = true
_G.InCombatLockdown = function() return combat end
local protected = true
rotation.IsProtected = function() return protected end
local previousWidth = rotation:GetWidth()
naturalWidth = 220
book.SearchBox.IsProtected = function() return true end
local nativeWidth = rotation.SetWidth
rotation.SetWidth = function(self, width)
    assert(not combat or not protected, "ADDON_ACTION_BLOCKED: protected assistant Frame:SetWidth in combat")
    nativeWidth(self, width)
end
local resizeSearch = book.ResizeSearchBox
book.ResizeSearchBox = function(self)
    assert(not combat, "protected spellbook search resize must wait for combat end")
    resizeSearch(self)
end
for i=1,3 do
    rotation:UpdateDisplay()
    normal:SetAlpha(1); pushed:SetAlpha(1); result.IconFrame:SetAlpha(1)
    apply(root)
    assert(rotation.Label:GetText()=="Single-Button Assistant",
        "assistant caption skin must refresh immediately during combat")
    assert(rotation.Button.Border:GetAlpha()==0 and rotation.Divider:GetAlpha()==0,
        "QUI assistant chrome must remain active during combat")
    assert(normal:GetAlpha()==0 and pushed:GetAlpha()==0 and result.IconFrame:GetAlpha()==0,
        "search-result skin must refresh immediately during combat")
end
assert(rotation:GetWidth()==previousWidth, "protected ancestor geometry must remain unchanged during combat")
protected=false
naturalWidth=240
rotation:UpdateDisplay()
assert(rotation:GetWidth()>=naturalWidth+49, "unprotected frame geometry must remain live during combat")
protected=true
naturalWidth=260
rotation:UpdateDisplay()
local combatEvent
for _, widget in ipairs(env.frames) do
    if widget:GetScript("OnEvent") then
        assert(not combatEvent, "combat styling must coalesce into one event listener")
        combatEvent = widget
    end
end
assert(combatEvent, "combat changes must queue a catch-up repaint")
combatEvent:GetScript("OnEvent")(combatEvent, "PLAYER_REGEN_ENABLED")
assert(rotation.Label:GetText()=="Single-Button Assistant", "combat event must retain already refreshed visual skin")
combat=false
combatEvent:GetScript("OnEvent")(combatEvent, "PLAYER_REGEN_ENABLED")
assert(rotation.Label:GetText()=="Single-Button Assistant" and rotation:GetWidth()>=naturalWidth+49,
    "native combat updates must regain the skinned caption and width after combat")
assert(rotation.Button:GetScript("OnClick")==nativeClick, "combat deferral must preserve secure spell action")
print("OK: spellbook_assistant_header_test")
