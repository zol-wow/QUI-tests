local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinKeystoneFrame = true
env.ns.Helpers.SetFrameBackdropBorderColor = function(frame, ...) frame:SetBackdropBorderColor(...) end
env.ns.Helpers.SetFrameBackdropColor = function(frame, ...) frame:SetBackdropColor(...) end
_G.ChallengesKeystoneFrame = env.NewFrame("Frame")
local frame = _G.ChallengesKeystoneFrame
frame.Reset = function() end
frame.OnKeystoneSlotted = function() end
frame.StartButton = env.NewFrame("Button", nil, frame)
frame.KeystoneSlot = env.NewFrame("Button", nil, frame)
local start = function() end
frame.StartButton:SetScript("OnClick", start)
local affix = env.NewFrame("Frame", nil, frame)
affix.Portrait = affix:CreateTexture()
affix.Portrait:SetTexture("affix-art")
frame.Affixes = { affix }
env.SkinBase.OnAddOnLoaded = function(_, fn) fn() end
assert(loadfile(os.getenv("QUI_KEYSTONE_SOURCE") or "modules/skinning/gameplay/keystone.lua"))("QUI", env.ns)
assert(env.SkinBase.GetBackdrop(frame)._quiRoundedSurface, "keystone shell must match rounded QUI windows")
assert(env.SkinBase.GetFrameData(frame.StartButton, "backdrop")._quiRoundedSurface,
    "keystone start action must match rounded QUI controls")
assert(env.SkinBase.GetFrameData(frame.KeystoneSlot, "border")._quiRoundedSurface,
    "keystone slot must match rounded QUI icon controls")
frame:OnKeystoneSlotted()
assert(env.SkinBase.GetFrameData(affix, "border")._quiRoundedSurface,
    "newly acquired affixes must match rounded QUI icons")
assert(frame.StartButton:GetScript("OnClick") == start and affix.Portrait:GetAlpha() == 1,
    "keystone styling must preserve native action and semantic art")
print("OK: keystone_rounded_controls_test")
