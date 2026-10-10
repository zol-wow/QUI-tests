local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinProfessions = true
local file = assert(io.open(os.getenv("QUI_PROFESSIONS_SOURCE") or "modules/skinning/frames/professions.lua"))
local source = file:read("*a"); file:close()
local first = assert(source:find("local function StyleProfessionNeutralText(", 1, true) or source:find("local function StyleProfessionTopControls(", 1, true))
local last = assert(source:find("local function SkinProfessions(", first, true))
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn StyleProfessionTopControls"))
setfenv(chunk, setmetatable({ SkinBase = env.SkinBase, IsEnabled = function() return true end }, { __index = _G }))
local apply = chunk()
local function Frame(kind, parent)
    local frame = env.NewFrame(kind or "Frame", nil, parent)
    setmetatable(frame, { __index = function(_, key)
        if key:match("^Get") or key:match("^Set[A-Z]") then return function() end end
    end })
    return frame
end
local root = Frame()
root.TitleText = root:CreateFontString()
root.GetTitleText = function(self) return self.TitleText end
root.SetTitleFormatted = function(self, text) self.TitleText:SetText(text); self.TitleText:SetTextColor(1, 0.82, 0) end
root.SetTitle = function(self, text) self:SetTitleFormatted(text) end
root.MaximizeMinimize = { MaximizeButton = Frame("Button", root), MinimizeButton = Frame("Button", root) }
local page = Frame("Frame", root)
root.CraftingPage = page
page.TutorialButton = Frame("Button", page)
page.LinkButton = Frame("Button", page)
page.LinkButton.Icon = page.LinkButton:CreateTexture()
local action = function() end
local equipment = Frame("ItemButton", page)
equipment.icon = equipment:CreateTexture()
equipment.icon:SetTexture("native-profession-tool")
equipment.Normal = equipment:CreateTexture()
equipment.GetNormalTexture = function(self) return self.Normal end
equipment.IconBorder = equipment:CreateTexture()
equipment.IconBorder.GetVertexColor = function() return .2, .6, 1, 1 end
equipment.IconUpgradeTexture = equipment:CreateTexture()
equipment:SetScript("OnClick", action)
page.InventorySlots = { equipment }
page.TutorialButton:SetScript("OnClick", action)
page.LinkButton:SetScript("OnMouseUp", action)
root.MaximizeMinimize.MinimizeButton:SetScript("OnClick", action)
local form = Frame("Frame", page)
page.SchematicForm = form
form.NineSlice = Frame("Frame", form)
form.NineSlice.TopEdge = form.NineSlice:CreateTexture()
form.Background = form:CreateTexture()
form.Reagents = { Label = form:CreateFontString() }
form.RequiredTools = form:CreateFontString()
form.RequiredTools:SetTextColor(1, 0.1, 0.1)
form.Init = function(self)
    self.NineSlice.TopEdge:SetAlpha(1)
    self.NineSlice:Show()
    self.NineSlice:SetAlpha(1)
    self.Background:SetAlpha(1)
    self.Reagents.Label:SetTextColor(1, 0.82, 0)
end
page.RecipeList = { FilterDropdown = { Text = page:CreateFontString() } }
page.RankBar = Frame("Frame", page)
page.RankBar:SetSize(453, 18)
page.RankBar.Fill = page.RankBar:CreateTexture()
page.RankBar.Rank = Frame("Frame", page.RankBar)
page.RankBar.ExpansionDropdownButton = Frame("Button", page.RankBar)
page.RankBar.ExpansionDropdownButton.Texture = page.RankBar.ExpansionDropdownButton:CreateTexture()
page.RankBar.ExpansionDropdownButton:SetScript("OnMouseUp", action)

root.SpecPage = { TreeView = { TreeDescription = root:CreateFontString() } }
form.Details = Frame("Frame", form)
form.Details.CraftingChoicesContainer = {
    FinishingReagentSlotContainer = { Label = form:CreateFontString() },
    ConcentrateContainer = { Label = form:CreateFontString() },
}
form.AllocateBestQualityCheckbox = Frame("CheckButton", form)
local allocate = function() end
form.AllocateBestQualityCheckbox:SetScript("OnClick", allocate)
root.OrdersPage = { BrowseFrame = {
    RecipeList = { FilterDropdown = { Text = root:CreateFontString() }, NoResultsText = root:CreateFontString() },
    OrderList = { ResultsText = root:CreateFontString() },
} }
local view = Frame("Frame", root)
root.OrdersPage.OrderView = view
view.OrderInfo = Frame("Frame", view)
view.OrderInfo.BackButton = Frame("Button", view.OrderInfo)
view.OrderInfo.StartOrderButton = Frame("Button", view.OrderInfo)
view.OrderInfo.StartOrderButton:SetScript("OnClick", action)
view.OrderInfo.PostedByTitle = view.OrderInfo:CreateFontString()
view.OrderInfo.NoteBox = Frame("Frame", view.OrderInfo)
view.OrderInfo.NoteBox.Background = Frame("Frame", view.OrderInfo.NoteBox)
view.OrderInfo.NoteBox.Background.Border = view.OrderInfo.NoteBox.Background:CreateTexture()
view.OrderInfo.NoteBox.NoteTitle = view.OrderInfo.NoteBox:CreateFontString()
view.OrderDetails = { SchematicForm = form }
view.RankBar = Frame("Frame", view)
view.RankBar.ExpansionDropdownButton = Frame("Button", view.RankBar)
view.RankBar.ExpansionDropdownButton.DisabledTexture = false
form.Details.BackgroundTop = form.Details:CreateTexture()
apply(root)
assert(env.SkinBase.GetBackdrop(view.OrderInfo.BackButton)._quiRoundedSurface,
    "actual nested order navigation must use rounded native controls")
assert(env.SkinBase.GetBackdrop(view.RankBar.ExpansionDropdownButton)._quiRoundedSurface,
    "order expansion selector must skin the native ExpansionDropdownButton")
assert(view.OrderInfo.StartOrderButton:GetScript("OnClick") == action,
    "order-start action must remain native")
assert(form.Details.BackgroundTop:GetAlpha() == 0
    and view.OrderInfo.NoteBox.Background.Border:GetAlpha() == 0,
    "nested order details and note decoration must be removed")
root:SetTitle("Alchemy")
assert(root.TitleText:GetText() == "Alchemy" and select(2, root.TitleText:GetTextColor()) == 1,
    "native profession titles must remain white")
form:Init()
assert(form.NineSlice:GetAlpha() == 0 and not form.NineSlice:IsShown() and form.Background:GetAlpha() == 0,
    "native schematic initialization must not restore the inner gold border or background")
assert(select(2, form.Reagents.Label:GetTextColor()) == 0.9
    and select(2, form.RequiredTools:GetTextColor()) == 0.1,
    "neutral reagent headings must preserve semantic requirement errors")
page.RecipeList.FilterDropdown.Text:SetTextColor(1, 0.82, 0)
root.SpecPage.TreeView.TreeDescription:SetTextColor(1, 0.82, 0)
assert(select(2, page.RecipeList.FilterDropdown.Text:GetTextColor()) == 0.9
    and select(2, root.SpecPage.TreeView.TreeDescription:GetTextColor()) == 0.9,
    "native filter and specialization refreshes must retain neutral text")
assert(page.TutorialButton:GetWidth() == 22 and page.TutorialButton.points[1][1] == "TOPLEFT",
    "crafting help must fit the header")
assert(page.TutorialButton:GetScript("OnClick") == action
    and page.LinkButton:GetScript("OnMouseUp") == action
    and root.MaximizeMinimize.MinimizeButton:GetScript("OnClick") == action,
    "help link and resize handlers must remain native")
assert(page.LinkButton.Icon:GetAlpha() == 0
    and env.SkinBase.GetFrameData(page.LinkButton, "qProfessionControlGlyph"):GetText() == "L",
    "link control must use neutral chrome and a visible label")
print("OK: professions_crafting_chrome_test")


local browse = root.OrdersPage.BrowseFrame
for _, label in ipairs({ browse.RecipeList.FilterDropdown.Text, browse.RecipeList.NoResultsText, browse.OrderList.ResultsText,
    form.Details.CraftingChoicesContainer.FinishingReagentSlotContainer.Label,
    form.Details.CraftingChoicesContainer.ConcentrateContainer.Label }) do
    label:SetTextColor(1, .82, 0)
    assert(select(2, label:GetTextColor()) == .9, "orders and crafting choices must retain neutral labels after refresh")
end
assert(form.AllocateBestQualityCheckbox:GetScript("OnClick") == allocate, "quality allocation behavior remains native")

assert(equipment.Normal:GetAlpha() == 0 and equipment.IconBorder:GetAlpha() == 0,
    "profession equipment must suppress native slot decoration")
assert(equipment.icon.texture == "native-profession-tool"
    and equipment.IconUpgradeTexture:GetAlpha() == 1 and equipment:GetScript("OnClick") == action,
    "profession equipment art, upgrade indicators and native action stay intact")
local equipmentBorder = env.SkinBase.GetFrameData(equipment.icon, "iconBorder")
assert(equipmentBorder._quiRoundedSurface.radius == 4,
    "profession equipment must use rounded quality borders")

apply(root)
assert(page.RankBar:GetWidth() == 425 and page.RankBar.Fill:GetHeight() == 22 - 2 * env.SkinBase.GetPixelSize(page.RankBar, 1),
    "rank fill must fit inside the inset bar without repeated shrinking")
local point, relative, relativePoint, x, y = page.RankBar.ExpansionDropdownButton:GetPoint()
assert(point == "LEFT" and relative == page.RankBar and relativePoint == "RIGHT" and x == 4 and y == 0,
    "expansion button must sit beside the bar with clear spacing")
assert(page.RankBar.ExpansionDropdownButton.Texture:GetAlpha() == 0
    and page.RankBar.ExpansionDropdownButton:GetScript("OnMouseUp") == action,
    "native arrow artwork must stay suppressed without losing the menu handler")

local linkPoint, linkRelative, linkRelativePoint, linkX = page.LinkButton:GetPoint()
assert(linkPoint == "LEFT" and linkRelative == page.RankBar.ExpansionDropdownButton
    and linkRelativePoint == "RIGHT" and linkX == 8,
    "link action must stay clear of the expansion button")
