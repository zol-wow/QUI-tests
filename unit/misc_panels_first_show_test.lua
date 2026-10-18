local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
_G.InCombatLockdown = function() return true end
assert(loadfile("core/uikit.lua"))("QUI", env.ns)
env.SkinBase = env.ns.SkinBase
local skin, settings = env.SkinBase, env.profile.general
local panels = {
    DressUpFrame = "skinDressUp",
    TradeFrame = "skinTrade",
    TabardFrame = "skinTabard",
    GuildRegistrarFrame = "skinGuildRegistrar",
    PetitionFrame = "skinGuildRegistrar",
}
local refresh, callbacks, styled, nativeShows = {}, {}, {}, {}
env.ns.Registry = { Register = function(_, key, entry) refresh[key] = entry.refresh end }
skin.OnAddOnLoaded = function(name, callback) callbacks[name] = callback end
local skinWindow = skin.SkinWindow
skin.SkinWindow = function(frame, ...)
    styled[frame] = (styled[frame] or 0) + 1
    assert(nativeShows[frame] or frame == _G.GuildRegistrarFrame,
        "first-show skinning must follow the native OnShow")
    return skinWindow(frame, ...)
end
for name, key in pairs(panels) do
    settings[key] = true
    local frame = env.NewFrame("Frame", name)
    _G[name] = frame
    frame:Hide()
    frame:SetScript("OnShow", function(self) nativeShows[self] = true end)
end
_G.DressUpFrame.CustomSetDetailsPanel = env.NewFrame("Frame", nil, _G.DressUpFrame)
_G.DressUpFrame.SetSelectionPanel = env.NewFrame("Frame", nil, _G.DressUpFrame)
assert(loadfile(os.getenv("QUI_MISC_SOURCE") or "modules/skinning/frames/misc_frames.lua"))("QUI", env.ns)
local loadPanels = callbacks.Blizzard_UIPanels_Game
loadPanels()
loadPanels()
assert(not next(styled), "hidden UIPanels must not initialize skins at startup")
for name, key in pairs(panels) do
    local frame = _G[name]
    assert(#frame.hooks.OnShow == 1, "repeat loads must deduplicate first-show hooks")
    local pending = skin.GetFrameData(frame, "deferredUntilShown").pending
    local count = 0
    for _ in pairs(pending) do count = count + 1 end
    assert(count == 1, "repeat loads must reuse one pending callback per panel")
    refresh[key]()
end
assert(not next(styled), "theme refresh must not initialize hidden panels")
_G.GuildRegistrarFrame.shown = true
loadPanels()
assert(styled[_G.GuildRegistrarFrame] == 1, "already shown panels must initialize immediately")
assert(not styled[_G.PetitionFrame], "opening one guild panel must not skin the other")
settings.skinDressUp = false
_G.DressUpFrame:Show()
assert(not styled[_G.DressUpFrame], "first show must recheck the current setting")
settings.skinDressUp = true
refresh.skinDressUp()
assert(styled[_G.DressUpFrame] == 1, "enabling a shown panel must initialize through registry refresh")
settings.skinGuildRegistrar = false
_G.PetitionFrame:Show()
assert(not styled[_G.PetitionFrame], "a disabled petition must remain unskinned on show")
_G.PetitionFrame:Hide()
settings.skinGuildRegistrar = true
refresh.skinPetition()
assert(not styled[_G.PetitionFrame], "enabling a hidden petition must rearm without initialization")
for name in pairs(panels) do
    local frame = _G[name]
    frame:Show()
    assert(styled[frame] == 1 and skin.IsSkinned(frame), "first show must complete that panel's skin")
    frame:Hide()
    frame:Show()
    assert(styled[frame] == 1, "subsequent shows must retain the initialized skin")
end
for name in pairs(panels) do
    local frame = env.NewFrame("Frame", name)
    _G[name] = frame
    nativeShows[frame] = true
    if name == "DressUpFrame" then
        frame.CustomSetDetailsPanel = env.NewFrame("Frame", nil, frame)
        frame.SetSelectionPanel = env.NewFrame("Frame", nil, frame)
    end
    frame.Bg = frame:CreateTexture()
    frame.Bg:SetTexture("native-background")
    frame.CloseButton = env.NewFrame("Button", nil, frame)
    frame.CloseButton.DisabledTexture = false
    frame.CloseButton:SetScript("OnClick", function() error("skinning must not invoke native close actions") end)
    frame.IsProtected = function() return true end
    for _, method in ipairs({ "SetSize", "SetWidth", "SetHeight", "SetScale", "ClearAllPoints", "SetPoint",
        "SetAllPoints", "SetParent", "SetAttribute", "Show", "Hide", "SetShown" }) do
        frame[method] = function() error("combat skinning must preserve native root " .. method) end
    end
end
loadPanels()
for name in pairs(panels) do
    local frame = _G[name]
    assert(skin.IsSkinned(frame) and skin.GetBackdrop(frame), name .. ": visible combat reload must apply its skin")
    assert(skin.GetFrameData(frame.CloseButton, "closeStyled"), name .. ": combat reload must style close control")
    assert(frame.Bg:GetAlpha() == 0 or not frame.Bg:IsShown(), name .. ": combat reload must suppress native art")
    local backdrop = skin.GetBackdrop(frame)
    loadPanels()
    assert(styled[frame] == 1 and skin.GetBackdrop(frame) == backdrop,
        name .. ": repeated combat loads must reuse the initialized skin")
end
print("PASS misc_panels_first_show_test")
