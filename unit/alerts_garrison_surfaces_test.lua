local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinAlerts = true
env.ns.Helpers.SetFrameBackdropBorderColor = function(frame, ...) frame:SetBackdropBorderColor(...) end
env.ns.Helpers.SetFrameBackdropColor = function(frame, ...) frame:SetBackdropColor(...) end
_G.Enum = {ItemQuality = {Uncommon = 2, Rare = 3, Epic = 4}}
_G.ColorManager = {GetAtlasDataForGarrisonFollowerQuality = function(quality)
    return ({[2] = "Uncommon", [3] = "Rare", [4] = "Epic"})[quality]
end}
_G.C_Item.GetItemQualityColor = function(quality)
    if quality == 2 then return 0.12, 1, 0 end
    if quality == 3 then return 0, 0.44, 0.87 end
    return 0.64, 0.21, 0.93
end
local systems = {}
for _, name in ipairs({
    "GarrisonBuildingAlertSystem", "GarrisonMissionAlertSystem", "GarrisonShipMissionAlertSystem",
    "GarrisonRandomMissionAlertSystem", "GarrisonFollowerAlertSystem",
    "GarrisonShipFollowerAlertSystem", "GarrisonTalentAlertSystem",
}) do
    local active = {}
    local system = {
        setUpFunction = function(owner, quality)
            owner.Background:SetAtlas("Garr_MissionToast")
            owner.Background:SetAlpha(1)
            owner.Background:Show()
            if owner.FollowerBG then
                local suffix = _G.ColorManager.GetAtlasDataForGarrisonFollowerQuality(quality)
                owner.FollowerBG:SetAtlas(suffix and "Garr_FollowerToast-" .. suffix or "unknown-follower")
                owner.FollowerBG:SetAlpha(1)
                owner.FollowerBG:SetShown(suffix ~= nil)
            end
        end,
        alertFramePool = {EnumerateActive = function() return next, active end},
    }
    _G[name] = system
    systems[#systems + 1] = {name = name, system = system, active = active}
end
assert(loadfile(os.getenv("QUI_ALERTS_SOURCE") or "modules/skinning/notifications/alerts.lua"))("QUI", env.ns)
env.ns.Addon.Alerts:HookAlertSystems()
local function Texture(frame, key, atlas)
    local texture = frame:CreateTexture()
    frame[key] = texture
    texture:SetAtlas(atlas)
    function texture:GetAtlas() return self.atlas end
    return texture
end
for _, entry in ipairs(systems) do
    local frame = env.NewFrame("Button")
    frame:SetSize(317, 82)
    Texture(frame, "Background", "Garr_MissionToast")
    Texture(frame, "glow", "native-glow")
    Texture(frame, "shine", "native-shine")
    local semantic
    if entry.name == "GarrisonBuildingAlertSystem" or entry.name == "GarrisonTalentAlertSystem" then
        semantic = Texture(frame, "Icon", "native-icon")
    elseif entry.name == "GarrisonFollowerAlertSystem" then
        frame.PortraitFrame = env.NewFrame("Frame", nil, frame)
        semantic = Texture(frame.PortraitFrame, "Portrait", "native-follower-portrait")
        Texture(frame, "FollowerBG", "Garr_FollowerToast-Epic")
    elseif entry.name == "GarrisonShipFollowerAlertSystem" then
        semantic = Texture(frame, "Portrait", "native-ship-art")
        Texture(frame, "FollowerBG", "Garr_FollowerToast-Epic")
    else
        semantic = Texture(frame, "MissionType", "GarrMission_MissionIcon-Combat")
        frame.EncounterIcon = env.NewFrame("Frame", nil, frame)
        Texture(frame.EncounterIcon, "Portrait", "native-encounter-art")
        Texture(frame.EncounterIcon, "RareOverlay", "native-rare-dragon")
        Texture(frame.EncounterIcon, "EliteOverlay", "native-elite-dragon")
        Texture(frame, "IconBG", "Garr_MissionToast-IconBG")
    end
    local nativeAtlas = semantic.atlas
    frame.Title = frame:CreateFontString()
    frame.Title:SetTextColor(1, 0.82, 0, 1)
    frame.Name = frame:CreateFontString()
    frame.Name:SetText("|cffa335eeNative follower or mission|r")
    frame.Rare = frame:CreateFontString()
    frame.Rare:SetTextColor(0.098, 0.537, 0.969, 1)
    local nativeClick = function() end
    frame:SetScript("OnClick", nativeClick)
    entry.active[frame] = true
    for _, quality in ipairs({2, 4, 3, 99}) do
        entry.system.setUpFunction(frame, quality)
        env.RunTimers()
        local bd = env.SkinBase.GetFrameData(frame, "backdrop")
        assert(bd and bd._quiRoundedSurface, entry.name .. " needs a shell even without Icon")
        assert(bd.points[1][2] == frame and bd.points[2][2] == frame, "shell must span native frame rather than icon-only width")
        bd:SetBackdropBorderColor(1, 0, 0, 1)
        _G.QUI_RefreshAlertColors()
        if frame.FollowerBG and quality ~= 99 then
            local r, g, b = _G.C_Item.GetItemQualityColor(quality)
            assert(bd._quiBorderR == r and bd._quiBorderG == g and bd._quiBorderB == b, "follower quality must survive refresh without a hyperlink")
        else
            assert(bd._quiBorderR == env.colors[1] and bd._quiBorderB == env.colors[3], "nonfollower or unknown quality must use theme border")
        end
        assert(frame.Background:GetAlpha() == 0 and frame.glow:GetAlpha() == 0, "restored Garrison toast decoration must stay suppressed")
        assert(semantic:GetAlpha() == 1 and semantic.atlas == nativeAtlas, "identifying mission/follower/ship art must survive")
        assert(frame.Title.textColor[3] > 0.9 and frame.Rare.textColor[3] == 0.969, "heading must be neutral while rare mission label stays semantic")
        assert(frame.Name:GetText() == "|cffa335eeNative follower or mission|r" and frame:GetScript("OnClick") == nativeClick, "native name formatting and navigation must survive")
        if frame.EncounterIcon then
            assert(frame.EncounterIcon.RareOverlay:GetAlpha() == 1 and frame.EncounterIcon.EliteOverlay:GetAlpha() == 1, "encounter rarity overlays must survive")
        end
    end
end
print("OK: alerts_garrison_surfaces_test")
