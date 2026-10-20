local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinAlerts = true
local skin = env.SkinBase
for _, method in ipairs({"SetFrameBackdropColor","SetFrameBackdropBorderColor"}) do
    env.ns.Helpers[method] = function(frame, ...) frame[method == "SetFrameBackdropColor" and "SetBackdropColor" or "SetBackdropBorderColor"](frame, ...) end
end
_G.SOUNDKIT = {HOUSING_ITEM_ACQUIRED = 1,HOUSING_ENDEAVORS_TASK_COMPLETE_TOAST = 2}
_G.PlaySound = function() end
_G.Enum = {HousingItemToastType = {Room = 1,Fixture = 2,Customization = 3}}
local file = assert(io.open("tests/framexml/Interface/AddOns/Blizzard_FrameXML/Mainline/AlertFrameSystems.lua"))
local native = file:read("*a");file:close()
local first = assert(native:find("function HousingItemEarnedAlertFrameSystem_SetUp",1,true))
assert(loadstring(native:sub(first)))()
local function animation()
    return {playing = false,starts = 0,stops = 0,
        Play = function(self) self.playing = true;self.starts = self.starts + 1 end,
        Restart = function(self) self.playing = true;self.starts = self.starts + 1 end,
        Stop = function(self) self.playing = false;self.stops = self.stops + 1 end}
end
local function alert(housing)
    local f = env.NewFrame("Button")
    f:SetSize(304,105)
    f.Icon = housing and f:CreateTexture() or nil
    f.Banner = not housing and f:CreateTexture() or nil
    f.Checkmark = not housing and f:CreateTexture() or nil
    if f.Banner then f.Banner:SetTexture("native-flag");f.Checkmark:SetTexture("native-check") end
    f.decorations = {}
    for _, key in ipairs({"Background","Glow","Sparkles","LightRays","LightRays2","LeafTL","LeafL","LeafBL","LeafTR","LeafBR","Divider","Border"}) do
        local t = f:CreateTexture();t:SetTexture("native-"..key);t:SetSize(274,83);t:SetPoint("CENTER",f,"CENTER",0,0)
        f[key] = t;f.decorations[#f.decorations+1] = t
    end
    local duplicateBorder = f:CreateTexture();duplicateBorder:SetTexture("native-outer-border");duplicateBorder:SetSize(274,83);duplicateBorder:SetPoint("CENTER",f,"CENTER",0,0);f.decorations[#f.decorations+1] = duplicateBorder
    f.caption = f:CreateFontString();f.caption:SetText(housing and "You Collected" or "Endeavor Task Completed")
    if housing then f.CollectedLabel = f.caption;f.DecorName = f:CreateFontString()
    else f.CompletedLabel = f.caption;f.TaskName = f:CreateFontString() end
    f.nameText = f.DecorName or f.TaskName;f.nameText:SetTextColor(0.1,1,0.3,1)
    for _, key in ipairs({"glowAnimIn","sparklesAnimIn","lightRaysAnimIn","animIn","waitAndAnimOut"}) do f[key] = animation() end
    f.animIn:Play();f.waitAndAnimOut:Play()
    local art = f.Icon or f.Banner
    art:SetSize(35,35);art:SetPoint("CENTER",f.Background,"CENTER",0,0)
    function f:CreateMaskTexture() local mask = self:CreateTexture();mask.kind = "MaskTexture";return mask end
    function art:AddMaskTexture(mask) self.roundedMask = mask end
    f.nativeClick = function() end;f:SetScript("OnClick",f.nativeClick)
    return f
end
local housing, task = alert(true),alert(false)
_G.HousingItemEarnedAlertFrameSystem = {setUpFunction = _G.HousingItemEarnedAlertFrameSystem_SetUp,
    alertFramePool = {EnumerateActive = function() return next,{[housing] = true} end}}
_G.InitiativeTaskCompleteAlertFrameSystem = {setUpFunction = _G.InitiativeTaskCompleteAlertFrameSystem_SetUp,
    alertFramePool = {EnumerateActive = function() return next,{[task] = true} end}}
assert(loadfile(os.getenv("QUI_ALERTS_SOURCE") or "modules/skinning/notifications/alerts.lua"))("QUI",env.ns)
env.ns.Addon.Alerts:HookAlertSystems()
local variants = {
    {itemName = "Existing named decor",itemType = 1,icon = "native-item-art"},
    {itemName = "Room preview",itemType = 1},
    {itemName = "Fixture preview",itemType = 2},
    {itemName = "Customization preview",itemType = 3},
}
for index, data in ipairs(variants) do
    _G.HousingItemEarnedAlertFrameSystem.setUpFunction(housing,data)
    _G.InitiativeTaskCompleteAlertFrameSystem.setUpFunction(task,"Task "..index)
    env.RunTimers()
    assert(housing.DecorName:GetText() == data.itemName and task.TaskName:GetText() == "Task "..index,"native names and pooled updates must survive")
    if data.icon then assert(housing.Icon.texture == data.icon,"native supplied item art must survive")
    else assert(housing.Icon.texture:find(index == 2 and "ArtisanalRooms" or index == 3 and "GenericFixture" or "GenericCustomization",1,true),"native type-specific fallback must survive") end
    for _, f in ipairs({housing,task}) do
        local bd = skin.GetFrameData(f,"backdrop")
        assert(bd and bd._quiRoundedSurface.radius == 8,"housing and endeavor alerts must have the shared rounded QUI shell")
        for _, t in ipairs(f.decorations) do
            assert(t:GetAlpha() == 0 and t.texture == "","native decoration, including duplicate border keys, must be removed")
            assert(t:GetWidth() == 274 and t:GetHeight() == 83 and t:GetPoint(1) == "CENTER","native invisible layout anchors must retain geometry")
        end
        for _, key in ipairs({"glowAnimIn","sparklesAnimIn","lightRaysAnimIn"}) do assert(not f[key].playing,"only decorative animations must stop after native setup") end
        assert(f.animIn.playing and f.waitAndAnimOut.playing,"native show/timeout lifecycle must remain intact")
        assert(f:GetWidth() == 304 and f:GetHeight() == 105 and f:GetScript("OnClick") == f.nativeClick,"native frame geometry and handlers must survive")
        local art = f.Icon or f.Banner
        assert(art:GetWidth() == 35 and art:GetPoint(1) == "CENTER","native semantic icon placement and size must survive")
        assert(f.caption.textColor[3] > 0.9 and f.nameText.textColor[2] == 1 and f.nameText.textColor[1] == 0.1,"shared caption styling must preserve semantic name colors")
    end
    assert(task.Banner.texture == "native-flag" and task.Checkmark.texture == "native-check","native task banner and checkmark must remain")
end
local bd = skin.GetFrameData(housing,"backdrop")
bd._quiBorderR = 0.123
_G.QUI_RefreshAlertColors()
local r = skin.GetWindowColors(env.profile.general,"alerts")
assert(bd._quiBorderR == r,"new Housing systems must participate in the existing theme refresh")
assert(housing.glowAnimIn.starts == 4 and housing.glowAnimIn.stops == 4 and task.glowAnimIn.starts == 4,"setup hooks must not recursively replay native animations")
print("OK: alerts_housing_surfaces_test")
