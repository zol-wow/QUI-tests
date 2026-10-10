local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinCommunities = true
_G.CommunitiesFrame = env.NewFrame("Frame")
local frame = _G.CommunitiesFrame
frame.TitleText = frame:CreateFontString()
frame.GetTitleText = function(owner) return owner.TitleText end
frame.SetTitle = function(owner, title)
    owner.TitleText:SetText(title)
    owner.TitleText:SetTextColor(1, 0.82, 0)
end
frame.PortraitContainer = env.NewFrame("Frame", nil, frame)
frame.PortraitOverlay = env.NewFrame("Frame", nil, frame)
frame.MaximizeMinimizeFrame = env.NewFrame("Frame", nil, frame)
local sizing = frame.MaximizeMinimizeFrame
sizing.MaximizeButton = env.NewFrame("Button", nil, sizing)
sizing.MinimizeButton = env.NewFrame("Button", nil, sizing)
sizing.MaximizeButton.DisabledTexture = false
sizing.MinimizeButton.DisabledTexture = false
for _, button in ipairs({ sizing.MaximizeButton, sizing.MinimizeButton }) do
    local createFontString = button.CreateFontString
    button.CreateFontString = function(self, ...)
        local text = createFontString(self, ...)
        local setFont, setText = text.SetFont, text.SetText
        local hasFont = false
        text.SetFont = function(owner, ...)
            hasFont = true
            return setFont(owner, ...)
        end
        text.SetText = function(owner, ...)
            assert(hasFont, "resize glyph must have a font before receiving text")
            return setText(owner, ...)
        end
        return text
    end
end

frame.CommunitiesList = env.NewFrame("Frame", nil, frame)
frame.CommunitiesList.ScrollBox = env.NewFrame("Frame", nil, frame.CommunitiesList)
local scrollBox = frame.CommunitiesList.ScrollBox
local navigationRow = env.NewFrame("Button", nil, scrollBox)
navigationRow.Name = navigationRow:CreateFontString()
navigationRow.Selection = navigationRow:CreateTexture()
navigationRow.Selection:SetShown(true)
function scrollBox:HasView() return true end
function scrollBox:ForEachFrame(callback) callback(navigationRow) end
_G.ScrollUtil = { AddAcquiredFrameCallback = function(owner, callback) owner.acquired = callback end }
frame.CommunitiesList.Bg = frame.CommunitiesList:CreateTexture()
frame.CommunitiesList.Bg:SetAtlas("bluemenu-main")
frame.CommunitiesList.FilligreeOverlay = env.NewFrame("Frame", nil, frame.CommunitiesList)
frame.CommunitiesList.FilligreeOverlay.Border = frame.CommunitiesList.FilligreeOverlay:CreateTexture()
frame.GuildFinderFrame = env.NewFrame("Frame", nil, frame)
local finder = frame.GuildFinderFrame
finder.DisabledFrame = false
finder.InsetFrame = env.NewFrame("Frame", nil, finder)
finder.InsetFrame.GuildDescription = finder.InsetFrame:CreateFontString()
finder.InsetFrame.GuildDescription:SetTextColor(1, 0.82, 0)
finder.InsetFrame.ErrorDescription = finder.InsetFrame:CreateFontString()
finder.InsetFrame.ErrorDescription:SetTextColor(1, 0, 0)
finder.OptionsList = env.NewFrame("Frame", nil, finder)
local options = finder.OptionsList
options.ClubFilterDropdown = env.NewFrame("DropdownButton", nil, options)
options.ClubFilterDropdown.DisabledTexture = false
options.ClubFilterDropdown.Label = options.ClubFilterDropdown:CreateFontString()
options.ClubFilterDropdown.Label:SetTextColor(1, 0.82, 0)
options.SearchBox = env.NewFrame("EditBox", nil, options)
options.SearchBox.searchIcon = options.SearchBox:CreateTexture()
options.Search = env.NewFrame("Button", nil, options)
options.Search.DisabledTexture = false
options.Search.Text = options.Search:CreateFontString()
local search = function() end
options.Search:SetScript("OnClick", search)
finder.ClubFinderSearchTab = env.NewFrame("CheckButton", nil, finder)
local tab = finder.ClubFinderSearchTab
tab.DisabledTexture = false
tab.Icon = tab:CreateTexture()
tab.Icon:SetAtlas("communities-search")
env.SkinBase.OnAddOnLoaded = function(_, callback) callback() end
assert(loadfile(os.getenv("QUI_SOCIAL_SOURCE") or "modules/skinning/frames/social.lua"))("QUI", env.ns)
env.RunTimers()
assert(navigationRow.Selection:IsShown(), "styling must preserve Blizzard's selected community row")
local selectedBorder = env.BorderColor(env.SkinBase.GetBackdrop(navigationRow))
local _, _, _, accentAlpha = env.SkinBase.GetSkinColors()
assert(selectedBorder[4] == accentAlpha, "selected community rows must retain their accent border after acquisition")
navigationRow.Selection:SetShown(false)
local unselectedBorder = env.BorderColor(env.SkinBase.GetBackdrop(navigationRow))
assert(unselectedBorder[4] ~= selectedBorder[4], "native deselection must clear the community row accent")
navigationRow.Selection:SetShown(true)
assert(env.BorderColor(env.SkinBase.GetBackdrop(navigationRow))[4] == selectedBorder[4],
    "native selection must restore the community row accent")
assert(frame.CommunitiesList.Bg:GetAlpha() == 0, "community navigation must suppress native decorative backgrounds")
assert(env.SkinBase.GetBackdrop(finder.InsetFrame)._quiRoundedSurface, "finder content must use rounded QUI chrome")
assert(env.SkinBase.GetBackdrop(options.ClubFilterDropdown)._quiRoundedSurface, "finder filters must use rounded QUI chrome")
assert(env.SkinBase.GetBackdrop(options.Search)._quiRoundedSurface, "finder search action must use rounded QUI chrome")
assert(options.Search:GetScript("OnClick") == search, "finder search must remain Blizzard-owned")
assert(options.SearchBox.searchIcon:GetAlpha() == 1 and tab.Icon:GetAlpha() == 1, "search magnifier and tab icon must remain visible")
tab:SetChecked(true)
assert(env.SkinBase.GetFrameData(tab, "tabUnderline"):IsShown(), "checked community tabs must show the selected line")
tab:SetChecked(false)
assert(not env.SkinBase.GetFrameData(tab, "tabUnderline"):IsShown(), "cleared community tabs must hide the selected line")
frame.PortraitContainer:SetAlpha(1)
frame.PortraitOverlay:SetAlpha(1)
assert(frame.PortraitContainer:GetAlpha() == 0 and frame.PortraitOverlay:GetAlpha() == 0,
    "native portrait refresh must not restore detached Communities chrome")
assert(env.SkinBase.GetFrameData(sizing.MaximizeButton, "qCommunitySizingGlyph"):GetText() == "+",
    "Communities resize action must retain a visible semantic glyph")
local left, top = tab.Icon.texCoord[1], tab.Icon.texCoord[3]
assert(left == 0.08 and top == 0.08, "finder icons must crop baked native borders")
assert(env.SkinBase.GetBackdrop(tab):GetFrameLevel() < tab:GetFrameLevel(),
    "finder tab background must remain below its icon and selected line")
frame:SetTitle("Guild & Communities")
local r, g, b = frame.TitleText:GetTextColor()
assert(r == 1 and g == 1 and b == 1, "native title updates must retain neutral heading color")
r, g, b = finder.InsetFrame.GuildDescription:GetTextColor()
assert(r == 0.85 and g == 0.85 and b == 0.85, "finder descriptions must use neutral readable text")
r, g, b = finder.InsetFrame.ErrorDescription:GetTextColor()
assert(r == 1 and g == 0 and b == 0, "finder errors must retain semantic red")
r, g, b = options.ClubFilterDropdown.Label:GetTextColor()
assert(r == 0.9 and g == 0.9 and b == 0.9, "finder dropdown headings must match QUI controls")
env.RunTimers()
for _ = 1, 3 do
    frame:Hide()
    frame:Show()
end
assert(#env.timers == 0, "reopening Communities must not enqueue new permanent row callbacks")
print("OK: communities_inner_controls_test")
