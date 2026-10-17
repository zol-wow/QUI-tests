local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local ns, skin = env.ns, env.SkinBase
env.profile.general.skinSocket = true
_G.UIPanelWindows = {}
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_ItemSocketingUI/Blizzard_ItemSocketingUI.lua"))()
local frame = env.NewFrame("Frame", "ItemSocketingFrame")
_G.ItemSocketingFrame = frame
frame:SetFrameLevel(5)
local parchment = frame:CreateTexture()
parchment:SetTexture("native-parchment")
frame.caption = frame:CreateFontString()
frame.caption:SetText("Socket Item")
frame.ScrollFrame = env.NewFrame("ScrollFrame", nil, frame)
frame.ScrollFrame.ScrollBar = env.NewFrame("Slider", nil, frame.ScrollFrame)
frame.ScrollFrame.ScrollBar.ThumbTexture = frame.ScrollFrame.ScrollBar:CreateTexture()
local container = env.NewFrame("Frame", nil, frame)
frame.SocketingContainer = container
for key, value in pairs(_G.GenericItemSocketingFrameMixin) do container[key] = value end
container.SocketFrames = {}
container.ApplySocketsButton = env.NewFrame("Button", nil, container)
local apply = container.ApplySocketsButton
apply.DisabledTexture = false
apply.Text = apply:CreateFontString()
apply.Text:SetText("Apply")
local accepted = 0
local nativeClick = function() accepted = accepted + 1 end
apply.onClickHandler = nativeClick
function apply:Disable() self.enabled = false end
function apply:Enable() self.enabled = true end
local maskCount = 0
for index = 1, 3 do
    local socket = env.NewFrame("Button", nil, container)
    socket:SetID(index)
    socket:SetFrameLevel(6)
    container.SocketFrames[index], container["Socket" .. index] = socket, socket
    socket.Icon, socket.Background = socket:CreateTexture(), socket:CreateTexture()
    socket.LeftFiligree, socket.RightFiligree = socket:CreateTexture(), socket:CreateTexture()
    socket.outerRing = socket:CreateTexture()
    socket.highlightTexture = socket:CreateTexture()
    socket.CreateMaskTexture = function(self)
        local mask = self:CreateTexture()
        mask.kind = "MaskTexture"
        return mask
    end
    function socket.Icon:AddMaskTexture() maskCount = maskCount + 1 end
    socket.BracketFrame = env.NewFrame("Frame", nil, socket)
    local bracket = socket.BracketFrame
    bracket.ClosedBracket, bracket.OpenBracket = bracket:CreateTexture(), bracket:CreateTexture()
    bracket.ColorText = bracket:CreateFontString()
    socket.Shine = {Start = function(self, ...) self.color = {...} end, Stop = function(self) self.color = nil end}
    for key, value in pairs(_G.GenericSocketButtonMixin) do socket[key] = value end
    socket:SetScript("OnClick", socket.OnClick)
    socket:SetScript("OnReceiveDrag", socket.OnReceiveDrag)
    socket:SetScript("OnDragStart", socket.OnDragStart)
    function socket:Disable() self.enabled = false end
    function socket:Enable() self.enabled = true end
end
local count, proposed = 3, true
_G.C_ItemSocketInfo = {
    GetSocketItemRefundable = function() return false end,
    GetSocketItemBoundTradeable = function() return false end,
    GetNumSockets = function() return count end,
    GetNewSocketInfo = function(index) if proposed then return "new", 100 + index, true end end,
    GetExistingSocketInfo = function(index) return "old", 200 + index, true end,
    GetSocketTypes = function(index) return ({"Red", "Blue", "Meta"})[index] end,
}
_G.CVarCallbackRegistry = {GetCVarValueBool = function() return true end}
_G.strupper = string.upper
_G.RED_GEM, _G.BLUE_GEM, _G.META_GEM = "Red", "Blue", "Meta"
_G.SetupTextureKitOnFrame = function(kit, texture, pattern) texture:SetAtlas(string.format(pattern, kit)) end
_G.TextureKitConstants = {DoNotSetVisibility = false, UseAtlasSize = true}
_G.SetItemButtonTexture = function(socket, texture) socket.Icon:SetTexture(texture) end
_G.PlaySound = function() end
_G.SOUNDKIT = {MAP_PING = 1}
local callback, refresh
skin.OnAddOnLoaded = function(name, fn) if name == "Blizzard_ItemSocketingUI" then callback = fn end end
ns.Registry = {Register = function(_, key, entry) if key == "skinSocket" then refresh = entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI", ns)
callback()
assert(skin.IsStyled(apply), "native nested Apply action must be skinned")
assert(parchment:GetAlpha() == 0 and frame.caption:GetText() == "Socket Item", "parchment must be removed without changing caption")
assert(frame.ScrollFrame.ScrollBar.ThumbTexture.color, "native description scrollbar must receive visible styling")
for _, state in ipairs({{3, true}, {2, false}, {1, true}, {3, false}}) do
    count, proposed = state[1], state[2]
    container:Update()
    for index, socket in ipairs(container.SocketFrames) do
        assert(socket:IsShown() == (index <= count), "native socket count visibility must survive")
        local backdrop = skin.GetBackdrop(socket)
        assert(backdrop and backdrop._quiRoundedSurface.radius == 4 and backdrop:GetFrameLevel() < socket:GetFrameLevel(),
            "socket chrome must be rounded behind semantic art")
        assert(socket.outerRing:GetAlpha() == 0 and socket.LeftFiligree:GetAlpha() == 0
            and socket.RightFiligree:GetAlpha() == 0, "native decoration must stay suppressed on reuse")
        assert(skin.GetFrameData(socket.Icon, "roundedIconMask"):GetAlpha() == 1, "reuse must retain mask visibility")
        assert(socket.Background:GetAlpha() == 1 and socket.highlightTexture:GetAlpha() == 1,
            "socket-type art and native interaction highlight must survive")
        assert(socket:GetScript("OnClick") == _G.GenericSocketButtonMixin.OnClick
            and socket:GetScript("OnReceiveDrag") == _G.GenericSocketButtonMixin.OnReceiveDrag
            and socket:GetScript("OnDragStart") == _G.GenericSocketButtonMixin.OnDragStart,
            "native socket interaction handlers must survive")
        if index <= count then
            assert(socket.Icon.texture == (proposed and 100 or 200) + index, "native gem art must survive")
            assert(socket.BracketFrame.OpenBracket:IsShown() == proposed
                and socket.BracketFrame.ClosedBracket:IsShown() == not proposed
                and socket.BracketFrame.ColorText:IsShown() and socket.Shine.color,
                "native replacement/type/colorblind/shine states must survive")
        end
    end
    assert(apply:IsEnabled() == proposed, "native Apply enabled state must survive")
end
container:OnEvent("SOCKET_INFO_ACCEPT")
assert(not apply:IsEnabled() and container.isSocketing, "native in-progress state must survive")
container:OnEvent("SOCKET_INFO_SUCCESS")
assert(not container.isSocketing and container.Socket1:IsEnabled(), "native success lifecycle must survive")
local backdrop = skin.GetBackdrop(container.Socket1)
backdrop._quiBorderR = -1
refresh()
assert(backdrop._quiBorderR ~= -1 and maskCount == 3, "theme refresh must reuse socket surfaces and masks")
assert(apply.onClickHandler == nativeClick and accepted == 0, "styling must retain Apply handler without applying gems")
print("OK: item_socketing_surfaces_test")
