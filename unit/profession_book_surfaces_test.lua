local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinProfessions = true
env.ns.Helpers.GetSkinBarColor = function() return 0.8, 0.1, 0.2, 1 end
local function Frame(kind, name, parent)
    local frame = env.NewFrame(kind or "Frame", name, parent)
    setmetatable(frame, { __index = function(_, key)
        if key:match("^Get") or key:match("^Set[A-Z]") then return function() end end
    end })
    return frame
end
local book = Frame("Frame", "ProfessionsBookFrame")
_G.ProfessionsBookFrame = book
book.TitleText = book:CreateFontString()
book.GetTitleText = function(owner) return owner.TitleText end
book.MainHelpButton = Frame("Button", nil, book)
local helpAction = function() end
book.MainHelpButton:SetScript("OnClick", helpAction)
_G.ProfessionsBookPage1 = book:CreateTexture()
_G.ProfessionsBookPage2 = book:CreateTexture()
local row = Frame("Frame", "PrimaryProfession1", book)
_G.PrimaryProfession1 = row
row.icon = row:CreateTexture()
for _, key in ipairs({ "professionName", "specialization", "missingHeader", "rank", "missingText" }) do
    row[key] = row:CreateFontString()
end
row.statusBar = Frame("StatusBar", "PrimaryProfession1StatusBar", row)
row.statusBar.rankText = row.statusBar:CreateFontString()
local spell = Frame("CheckButton", "PrimaryProfession1SpellButtonBottom", row)
row.SpellButton1 = spell
spell.IconTexture = spell:CreateTexture()
spell.CreateMaskTexture = function(owner) return owner:CreateTexture() end
spell.IconTexture.AddMaskTexture = function(owner, mask) owner.mask = mask end
spell.spellString = spell:CreateFontString()
spell.subSpellString = spell:CreateFontString()
_G.PrimaryProfession1SpellButtonBottomNameFrame = spell:CreateTexture()
local nativeSpell = function() end
spell:SetScript("OnClick", nativeSpell)
row.UnlearnButton = Frame("Button", nil, row)
local nativeUnlearn = function() end
row.UnlearnButton:SetScript("OnClick", nativeUnlearn)
_G.ProfessionsBookFrame_Update = function()
    row.professionName:SetTextColor(1, 0.82, 0)
    _G.ProfessionsBookPage1:SetAlpha(1)
end
env.SkinBase.OnAddOnLoaded = function(_, callback) callback() end
assert(loadfile(os.getenv("QUI_PROFESSIONS_SOURCE") or "modules/skinning/frames/professions.lua"))("QUI", env.ns)
assert(env.SkinBase.GetBackdrop(book), "Profession Book must share the QUI window shell")
assert(env.SkinBase.GetBackdrop(row)._quiRoundedSurface, "profession cards must render rounded inner surfaces")
assert(_G.ProfessionsBookPage1:GetAlpha() == 0 and _G.ProfessionsBookPage2:GetAlpha() == 0,
    "native parchment must stay suppressed")
assert(_G.PrimaryProfession1SpellButtonBottomNameFrame:GetAlpha() == 0,
    "spell labels must not retain native parchment")
assert(spell.IconTexture:GetAlpha() == 1 and env.SkinBase.GetFrameData(spell.IconTexture, "roundedIconMask"),
    "profession spell artwork must remain visible inside rounded controls")
assert(spell:GetScript("OnClick") == nativeSpell and row.UnlearnButton:GetScript("OnClick") == nativeUnlearn,
    "spell and unlearn handlers must remain native")
assert(book.MainHelpButton:GetScript("OnClick") == helpAction
    and env.SkinBase.GetFrameData(book.MainHelpButton, "qProfessionBookHelpGlyph"):GetText() == "?",
    "help must keep its native action and a readable replacement glyph")
_G.ProfessionsBookFrame_Update()
local r, g, b = row.professionName:GetTextColor()
assert(r == 1 and g == 1 and b == 1 and _G.ProfessionsBookPage1:GetAlpha() == 0,
    "native profession updates must retain neutral headings and suppressed parchment")
local cardPoints = env.SkinBase.GetBackdrop(row).points
assert(cardPoints[2][1] == "BOTTOMRIGHT" and cardPoints[2][5] == -6 and cardPoints[1][5] == 4,
    "profession cards must include bottom padding around native progress bars")
assert(book.MainHelpButton:GetWidth() == 22 and book.MainHelpButton.points[1][1] == "TOPRIGHT",
    "Book help must be a compact integrated header control")
print("OK: profession_book_surfaces_test")
