local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local ns, skin = env.ns, env.SkinBase
env.profile.general.skinTabard = true
local newFrame = env.NewFrame
env.NewFrame = function(...)
    local frame = newFrame(...)
    frame.RegisterForWidgetSet = false
    return frame
end
_G.CreateFromMixins = function(...)
    local result = {}
    for _, mixin in ipairs({...}) do for key, value in pairs(mixin) do result[key] = value end end
    return result
end
_G.RegisterPlayerInteraction = function() end
_G.Enum = {PlayerInteractionType = {GuildTabardVendor = 1, PersonalTabardVendor = 2}}
_G.SOUNDKIT = {}
_G.PlaySound = function() end
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_SharedXML/Mainline/ModelControlButtonMixin.lua"))()
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/TabardModelControlButtonMixin.lua"))()
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/TabardFrame.lua"))()
local frame = env.NewFrame("Frame", "TabardFrame")
_G.TabardFrame = frame
frame:SetFrameLevel(3)
frame.decoration = frame:CreateTexture()
frame.CreateMaskTexture = function(self)
    local mask = self:CreateTexture()
    mask.kind = "MaskTexture"
    return mask
end
_G.TabardFramePortrait = frame:CreateTexture()
local masks = 0
function _G.TabardFramePortrait:AddMaskTexture() masks = masks + 1 end
for _, suffix in ipairs({"TopRight", "TopLeft", "BottomRight", "BottomLeft"}) do
    _G["TabardFrameEmblem" .. suffix] = frame:CreateTexture()
end
_G.TabardFrameNameText, _G.TabardFrameGreetingText = frame:CreateFontString(), frame:CreateFontString()
_G.TabardFrameCustomizationFrame = env.NewFrame("Frame", nil, frame)
_G.TabardFrameCustomizationFrame.border = _G.TabardFrameCustomizationFrame:CreateTexture()
local buttons = {}
local function button(name, parent, click)
    local widget = env.NewFrame("Button", name, parent)
    _G[name] = widget
    widget.DisabledTexture = false
    widget:SetScript("OnClick", click)
    widget.nativeClick = click
    function widget:Enable() self.enabled = true end
    function widget:Disable() self.enabled = false end
    buttons[#buttons + 1] = widget
    return widget
end
for index = 1, 5 do
    local prefix = "TabardFrameCustomization" .. index
    local row = env.NewFrame("Frame", prefix, _G.TabardFrameCustomizationFrame)
    _G[prefix] = row
    row:SetFrameLevel(6)
    row:SetSize(164, 20)
    row:SetID(index)
    row.art = row:CreateTexture()
    _G[prefix .. "Text"] = row:CreateFontString()
    _G[prefix .. "Text"]:SetText("Native choice " .. index)
    button(prefix .. "LeftButton", row, function(self) _G.TabardCustomization_Left(self:GetParent():GetID()) end):SetSize(32, 32)
    button(prefix .. "RightButton", row, function(self) _G.TabardCustomization_Right(self:GetParent():GetID()) end):SetSize(32, 32)
end
local guild, rank, saveable, owned = true, 0, true, 1
local model = env.NewFrame("TabardModel", "TabardModel", frame)
_G.TabardModel = model
model.rotation, model.cycles, model.saves = 0, {}, 0
function model:IsGuildTabard() return guild end
function model:CanSaveTabardNow() return saveable end
function model:InitializeTabardColors() self.initialized = (self.initialized or 0) + 1 end
function model:CycleVariation(index, delta) self.cycles[#self.cycles + 1] = {index, delta} end
function model:GetUpperEmblemTexture(texture) texture:SetTexture("native-upper-emblem") end
function model:GetLowerEmblemTexture(texture) texture:SetTexture("native-lower-emblem") end
function model:SetRotation(rotation) self.appliedRotation = rotation end
function model:Save() self.saves = self.saves + 1 end
for _, side in ipairs({"Left", "Right"}) do
    local widget = button("TabardCharacterModelRotate" .. side .. "Button", model, _G.TabardModelControlRotateButtonMixin.OnClick)
    widget.rotateDirection = side:lower()
    _G.TabardModelControlRotateButtonMixin.OnLoad(widget)
    widget:SetSize(35, 35)
end
_G.TabardCharacterModelRotateLeftButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 33)
for _, name in ipairs({"TabardFrameCostFrame", "TabardFrameMoneyBg", "TabardFrameMoneyInset",
    "TabardFrameCostMoneyFrame", "TabardFrameMoneyFrame"}) do
    local panel = env.NewFrame("Frame", name, frame)
    _G[name] = panel
    panel.art = panel:CreateTexture()
    panel.quantity = panel:CreateFontString()
    panel.quantity:SetText("Native money")
end
button("TabardFrameAcceptButton", frame, function() model:Save() end)
button("TabardFrameCancelButton", frame, function() end)
_G.GetGuildInfo = function() if rank ~= nil then return "Native guild", "Native rank", rank end end
_G.C_Item.GetItemCount = function() return owned end
_G.TABARDVENDORNOGUILDGREETING, _G.TABARDVENDORGREETING = "Guild unavailable", "Guild greeting"
_G.PERSONALTABARDVENDORUNOWNEDGREETING, _G.PERSONALTABARDVENDORGREETING = "Personal unowned", "Personal greeting"
_G.MoneyFrame_SetMaxDisplayWidth = function(panel, width) panel.maximum = width end
local costs = 0
_G.MoneyFrame_Update = function(name, amount) costs = costs + 1; _G[name].quantity:SetText(tostring(amount)) end
_G.GetTabardCreationCost = function() return 12345 end
_G.SetPortraitTexture = function(texture) texture:SetTexture("native-npc") end
_G.UnitName = function() return "Native vendor" end
_G.ShowUIPanel = function(panel) panel:Show() end
_G.CloseTabardCreation = function() error("styling must not close a valid native tabard window") end
_G.TabardFrame_OnLoad(frame)
local callback, refresh
skin.OnAddOnLoaded = function(name, fn) if name == "Blizzard_UIPanels_Game" then callback = fn end end
ns.Registry = {Register = function(_, key, entry) if key == "skinTabard" then refresh = entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI", ns)
callback()
assert(skin.IsStyled(_G.TabardFrameCustomization1LeftButton), "all native customization arrows must be skinned")
assert(frame.decoration:GetAlpha() == 0 and _G.TabardFrameCustomizationFrame.border:GetAlpha() == 0,
    "native outer/customization decoration must be suppressed")
for index = 1, 5 do
    local prefix = "TabardFrameCustomization" .. index
    local row = _G[prefix]
    assert(skin.GetBackdrop(row)._quiRoundedSurface.radius == 4 and skin.GetBackdrop(row):GetFrameLevel() < row:GetFrameLevel(),
        "customization row must use a rounded shell behind its label")
    assert(_G[prefix .. "Text"]:GetText() == "Native choice " .. index and _G[prefix .. "Text"].width == 116,
        "native label must gain contained space without changing content")
    for _, side in ipairs({"Left", "Right"}) do
        local widget = _G[prefix .. side .. "Button"]
        assert(widget:GetHeight() <= row:GetHeight() and widget:GetWidth() == 20, "arrow hit targets must fit inside each row")
        assert(widget:GetScript("OnClick") == widget.nativeClick, "native customization handler must survive")
        widget:Fire("OnClick")
        local cycle = model.cycles[#model.cycles]
        assert(cycle[1] == index and cycle[2] == (side == "Left" and -1 or 1), "native variation identity/direction must survive")
    end
end
local left, right = _G.TabardCharacterModelRotateLeftButton, _G.TabardCharacterModelRotateRightButton
assert(left:GetWidth() == 24 and right:GetWidth() == 24 and right.points[1][4] == 4
    and left.points[1][4] == 14, "rotation controls must keep their baseline with a positive gap")
left:Fire("OnClick")
assert(model.appliedRotation == 0.03, "native left model rotation must survive")
right:Fire("OnClick")
assert(model.appliedRotation == 0, "native right model rotation must survive")
for _, state in ipairs({{true, false, true, 1}, {true, 1, true, 1}, {true, 0, false, 1},
    {true, 0, true, 1}, {false, 0, true, 0}, {false, 0, false, 1}}) do
    guild, rank, saveable, owned = state[1], state[2] ~= false and state[2] or nil, state[3], state[4]
    _G.TabardFrame_Open()
    local eligible = not guild or rank == 0
    assert(_G.TabardFrameAcceptButton:IsEnabled() == (eligible and saveable), "native guild/vendor save eligibility must survive")
    assert(_G.TabardFrameCostFrame:IsShown() == guild and _G.TabardFrameMoneyBg:IsShown() == guild,
        "native guild/personal cost-panel visibility must survive")
    local greeting = guild and (eligible and "Guild greeting" or "Guild unavailable")
        or (owned == 0 and "Personal unowned" or "Personal greeting")
    assert(_G.TabardFrameGreetingText:GetText() == greeting, "native vendor greeting must survive")
end
for _, suffix in ipairs({"TopRight", "TopLeft", "BottomRight", "BottomLeft"}) do
    local emblem = _G["TabardFrameEmblem" .. suffix]
    assert(emblem:GetAlpha() == 0.4 and emblem.texture:find("native", 1, true), "native emblem content/alpha must survive")
end
local backdrop = skin.GetBackdrop(_G.TabardFrameMoneyBg)
backdrop._quiBorderR = -1
refresh()
assert(backdrop._quiBorderR ~= -1 and skin.GetBackdrop(_G.TabardFrameMoneyBg) == backdrop
    and not skin.GetBackdrop(_G.TabardFrameMoneyInset), "refresh must reuse one money outline without a nested duplicate")
assert(masks == 1 and model.saves == 0 and #model.cycles == 10 and costs == 4
    and _G.TabardFrameMoneyFrame.maximum == 160 and _G.TabardFrameMoneyFrame.quantity:GetText() == "Native money",
    "styling must retain native money limits/text and avoid saving, extra costs or extra variation changes")
print("OK: tabard_surfaces_test")
