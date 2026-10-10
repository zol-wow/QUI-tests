local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinDressUp = true
local function Frame(kind, parent)
    local frame = env.NewFrame(kind or "Frame", nil, parent)
    setmetatable(frame, {__index = function(_, key)
        if key:match("^Get") or key:match("^Set[A-Z]") then return function() end end
    end})
    return frame
end
local frame = Frame()
_G.DressUpFrame = frame
frame.CustomSetDetailsPanel = Frame(nil, frame)
frame.SetSelectionPanel = Frame(nil, frame)
frame.TitleText = frame:CreateFontString()
frame.GetTitleText = function(owner) return owner.TitleText end
frame.SetTitle = function(owner, title)
    owner.TitleText:SetText(title)
    owner.TitleText:SetTextColor(1, 0.8, 0, 1)
end
frame.MaximizeMinimizeFrame = Frame(nil, frame)
local maxMin = frame.MaximizeMinimizeFrame
maxMin.MaximizeButton = Frame("Button", maxMin)
maxMin.MinimizeButton = Frame("Button", maxMin)
frame.ToggleCustomSetDetailsButton = Frame("Button", frame)
local actions = {}
for _, button in ipairs({maxMin.MaximizeButton, maxMin.MinimizeButton, frame.ToggleCustomSetDetailsButton}) do
    actions[button] = function() end
    button:SetScript("OnClick", actions[button])
end
env.SkinBase.OnAddOnLoaded = function(_, callback) callback() end
assert(loadfile(os.getenv("QUI_MISC_SOURCE") or "modules/skinning/frames/misc_frames.lua"))("QUI", env.ns)
for button, action in pairs(actions) do
    assert(env.SkinBase.GetBackdrop(button), "Dressing Room header buttons need QUI surfaces")
    local text = env.SkinBase.GetFrameData(button, "qDressUpGlyph")
    assert(text and text:GetText() ~= "", "stripped header controls need visible action glyphs")
    assert(button:GetScript("OnClick") == action, "Dressing Room controls must retain native actions")
end
frame:SetTitle("Dressing Room")
local r, g, b = frame.TitleText:GetTextColor()
assert(r == 1 and g == 1 and b == 1, "refreshed Dressing Room title must use neutral text")
print("OK: dressup_header_controls_test")
