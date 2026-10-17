local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local file = assert(io.open(os.getenv("QUI_JOURNALS_SOURCE") or "modules/skinning/frames/journals.lua"))
local source = file:read("*a")
file:close()
local first = assert(source:find("local function StyleSpecializationContent(", 1, true), "individual Specialization styling is required")
local last = assert(source:find("local function SkinPlayerSpellsText(", first, true))
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn StylePlayerSpellsControls"))
setfenv(chunk, setmetatable({ SkinBase = env.SkinBase }, { __index = _G }))
local apply = chunk()
C_Timer = { After = function(_, fn) fn() end }
local frame = env.NewFrame("Frame")
frame.TalentsFrame = env.NewFrame("Frame", nil, frame)
local talents = frame.TalentsFrame
talents.BottomBar = talents:CreateTexture()
talents.ApplyButton = env.NewFrame("Button", nil, talents)
talents.ApplyButton.DisabledTexture = false
talents.SearchBox = env.NewFrame("EditBox", nil, talents)
talents.LoadSystem = { Dropdown = env.NewFrame("Button", nil, talents) }
talents.LoadSystem.Dropdown.DisabledTexture = false
local nativeApply = function() end
talents.ApplyButton:SetScript("OnClick", nativeApply)
frame.SpecFrame = env.NewFrame("Frame", nil, frame)
local spec = frame.SpecFrame
spec.Background = spec:CreateTexture()
local content = env.NewFrame("Frame", nil, spec)
content.CreateMaskTexture = content.CreateTexture
content.SpecImage = content:CreateTexture()
content.SpecImage.AddMaskTexture = function(self, mask) self.mask = mask end
content.SpecImageBorderOn = content:CreateTexture()
content.ActivatedBackFrames = { content:CreateTexture() }
content.ActivateButton = env.NewFrame("Button", nil, content)
content.ActivateButton.DisabledTexture = false
local nativeActivate = function() end
content.ActivateButton:SetScript("OnClick", nativeActivate)
content.UpdateActiveGlow = function(self, active)
    self.isInGlowState = active
    self.SpecImageBorderOn:SetAlpha(1)
    self.ActivatedBackFrames[1]:SetAlpha(1)
end
spec.SpecContentFramePool = { EnumerateActive = function()
    local nextFrame = content
    return function() local result = nextFrame; nextFrame = nil; return result end
end }
apply(frame)
assert(env.SkinBase.GetBackdrop(talents.ApplyButton)._quiRoundedSurface, "Talents Apply must use QUI control chrome")
assert(env.SkinBase.GetBackdrop(talents.LoadSystem.Dropdown)._quiRoundedSurface, "Talents loadout dropdown must use QUI chrome")
assert(talents.BottomBar:GetAlpha() == 0, "Talents footer must suppress native beveled art")
assert(env.SkinBase.GetBackdrop(content)._quiRoundedSurface.radius == 6, "Specialization must use rounded panels")
content:UpdateActiveGlow(true)
assert(content.SpecImageBorderOn:GetAlpha() == 0 and content.ActivatedBackFrames[1]:GetAlpha() == 0, "active spec refresh must not restore gold native chrome")
assert(content.SpecImage:GetAlpha() == 1, "Specialization must retain identifying art")
assert(content.ActivateButton:GetScript("OnClick") == nativeActivate, "Specialization action must remain native")
assert(talents.ApplyButton:GetScript("OnClick") == nativeApply, "Talents Apply action must remain native")
print("OK: player_spells_inner_controls_test")

frame.MaximizeMinimizeButton = env.NewFrame("Frame", nil, frame)
local resize = frame.MaximizeMinimizeButton
for _, key in ipairs({ "MaximizeButton", "MinimizeButton" }) do
    resize[key] = env.NewFrame("Button", nil, resize)
    resize[key].DisabledTexture = false
    resize[key].Art = resize[key]:CreateTexture()
    resize[key]:SetScript("OnClick", nativeApply)
end
frame.UpdateSize = function()
    resize.MaximizeButton.Art:SetAlpha(1)
    resize.MinimizeButton.Art:SetAlpha(1)
end
apply(frame)
frame:UpdateSize()
for _, key in ipairs({ "MaximizeButton", "MinimizeButton" }) do
    local button = resize[key]
    assert(button.Art:GetAlpha() == 0, "native resize updates must retain neutral control chrome")
    assert(button:GetScript("OnClick") == nativeApply, "native resize actions must remain intact")
    assert(env.SkinBase.GetFrameData(button, "qPlayerSpellsResizeGlyph"):GetText() == (key == "MaximizeButton" and "+" or "-"),
        "both native resize states require a visible glyph")
end

frame.UpdateSize = nil
resize.MaximizeButton:SetScript("OnClick", function(self)
    self.NewResizeArt = self:CreateTexture()
end)
resize.MaximizeButton:Fire("OnClick")
assert(resize.MaximizeButton.NewResizeArt:GetAlpha() == 0,
    "PTR resize clicks must refresh chrome even when UpdateSize is unavailable")
