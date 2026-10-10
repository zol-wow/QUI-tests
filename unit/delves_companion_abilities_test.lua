local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local file = assert(io.open(os.getenv("QUI_DELVES_SOURCE") or "modules/skinning/frames/delves.lua"))
local source = file:read("*a"); file:close()
local first = assert(source:find("local function StyleDelvesAbilities(", 1, true))
local last = assert(source:find("local function SkinDelvesCompanion(", first, true))
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn StyleDelvesAbilities"))
setfenv(chunk, setmetatable({ SkinBase = env.SkinBase }, { __index = _G }))
local apply = chunk()
local frame = env.NewFrame("Frame")
frame.TitleText = frame:CreateFontString()
frame.GetTitleText = function(self) return self.TitleText end
frame.CompanionAbilityListBackground = frame:CreateTexture()
frame.DelvesCompanionRoleDropdown = env.NewFrame("Button", nil, frame)
frame.DelvesCompanionRoleDropdown.DisabledTexture = false
local page = env.NewFrame("Frame", nil, frame)
frame.DelvesCompanionAbilityListPagingControls = page
local native = function() end
for _, key in ipairs({ "PrevPageButton", "NextPageButton" }) do
    page[key] = env.NewFrame("Button", nil, page)
    page[key].DisabledTexture = false
    page[key]:SetScript("OnClick", native)
end
local ability = env.NewFrame("Frame", nil, frame)
ability.Name = ability:CreateFontString()
ability.Icon = ability:CreateTexture()
ability.Icon:SetTexture("companion-spell")
ability.Icon.AddMaskTexture = function() end
ability.CreateMaskTexture = ability.CreateTexture
frame.buttons = { ability }
frame.UpdatePaginatedButtonDisplay = function()
    ability.Name:SetTextColor(1, .82, 0)
    frame.CompanionAbilityListBackground:SetAlpha(1)
end
apply(frame)
ability.locked = true
frame:UpdatePaginatedButtonDisplay()
assert(select(1, ability.Name:GetTextColor()) == .55, "locked abilities must retain disabled semantics after paging")
ability.locked = false
frame:UpdatePaginatedButtonDisplay()
assert(select(1, ability.Name:GetTextColor()) == .9, "unlocked ability names must use neutral readable text")
assert(frame.CompanionAbilityListBackground:GetAlpha() == 0 and ability.Icon.texture == "companion-spell",
    "abilities must hide the native background and retain spell artwork")
assert(page.NextPageButton:GetScript("OnClick") == native, "native companion paging must remain intact")
assert(env.SkinBase.GetBackdrop(frame.DelvesCompanionRoleDropdown), "role filter must have QUI chrome")
print("OK: delves_companion_abilities_test")
