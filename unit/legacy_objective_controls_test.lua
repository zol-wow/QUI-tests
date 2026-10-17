local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinLegacySystem = true
ns.Helpers.GetSkinBarColor = function() return .8,.1,.1,1 end
_G.CreateFromMixins = function(base) return base or {} end
_G.AchievementTemplateMixin = {}
_G.WHITE_FONT_COLOR = {GetRGBA = function() return 1,1,1,1 end}
_G.GRAY_FONT_COLOR = {GetRGBA = function() return .5,.5,.5,1 end}
_G.EVALUATION_TREE_FLAG_PROGRESS_BAR = 1
_G.bit = {band = function(a, b) return a == b and b or 0 end}
_G.Clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
_G.GENERIC_FRACTION_STRING_WITH_SPACING = "%d / %d"
assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_LegacySystem/Blizzard_LegacyChallengeButton.lua"))()
local root = env.NewFrame("Frame"); root.CloseButton = false; root.Tabs = {}; root.Pages = {}
_G.LegacySystemFrame = root
local objectives = env.NewFrame("Frame", nil, root); objectives.RegisterForWidgetSet = false
_G.LegacyChallengeObjectives = objectives
for key, method in pairs(_G.LegacyChallengeObjectivesMixin) do objectives[key] = method end
local active, spare, made = {}, {}, 0
local pool = {}; objectives.criteriaPool = pool
function pool:EnumerateActive() return pairs(active) end
function pool:ReleaseAll()
    for row in pairs(active) do row:Hide(); active[row] = nil; spare[#spare + 1] = row end
end
function pool:Acquire()
    local row = table.remove(spare)
    if not row then
        made = made + 1
        row = env.NewFrame("Frame", nil, objectives); row.RegisterForWidgetSet = false; row:SetSize(180,30)
        row.Background = row:CreateTexture(); row.Background:SetAtlas("Legacy-Challenge-Cards-Bar")
        function row:CreateMaskTexture() return env.NewTexture(self, "MaskTexture") end
        function row.Background:AddMaskTexture(mask) self.mask = mask end
        row.ProgressBarBackground = row:CreateTexture(); row.ProgressBarBackground:SetAtlas("Legacy-Progressbar-BG")
        row.Check = row:CreateTexture(); row.Check:SetAtlas("worldquest-tracker-checkmark"); row.Check:SetAlpha(.4)
        row.Name = row:CreateFontString()
        for key, method in pairs(_G.LegacyChallengeCriteriaMixin) do row[key] = method end
        local bar = env.NewFrame("StatusBar", nil, row); row.ProgressBar = bar; bar.RegisterForWidgetSet = false
        bar:SetSize(180,16); bar:SetPoint("TOPLEFT", row.ProgressBarBackground, "TOPLEFT", 0,0)
        local fill = bar:CreateTexture(); fill:SetAtlas("Legacy-Progressbar-Fill")
        function bar:CreateMaskTexture() return env.NewTexture(self, "MaskTexture") end
        function fill:AddMaskTexture(mask) self.mask = mask end
        function bar:SetStatusBarTexture(path) fill:SetTexture(path) end
        function bar:GetStatusBarTexture() return fill end
        function bar:SetStatusBarColor(...) self.barColor = {...} end
        function bar:SetMinMaxValues(lo, hi) self.range = {lo, hi} end
        function bar:SetValue(v) self.value = v end
        bar.ProgressBarFrame = bar:CreateTexture(); bar.ProgressBarFrame:SetAtlas("Legacy-Progressbar-Frame")
        bar.Text = bar:CreateFontString()
        function bar.Text:SetFormattedText(pattern, ...) self:SetText(string.format(pattern,...)) end
    end
    active[row] = true; return row
end
local data = {{"First criterion", false, 0, 0, 1}}
_G.GetAchievementNumCriteria = function() return #data end
_G.GetAchievementCriteriaInfo = function(_, i)
    local d = data[i]; return d[1], 0, d[2], d[4], d[5], nil, d[3]
end
objectives:Display(1, 400)
local first = next(active)
local callbacks, registry = {}, {}
skin.OnAddOnLoaded = function(addon, fn) callbacks[addon] = fn end
ns.Registry = {Register = function(_, key, entry) registry[key] = entry end}
local originalHook = _G.hooksecurefunc
_G.hooksecurefunc = function(target, method, callback)
    if target == objectives and method == "Display" then
        local display = target[method]
        target[method] = function(...) local height = display(...); callback(...); return height end
    else originalHook(target, method, callback) end
end
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI", ns)
callbacks.Blizzard_LegacySystem()
local backdrop = first.ProgressBar
assert(backdrop and backdrop._quiRoundedSurface and first.Background.color and first.Background.mask
    and first.ProgressBar:GetStatusBarTexture().mask,
    "legacy criteria must receive rounded neutral row/progress chrome")
assert(first.Name.textColor[1] == .5 and first.Name:GetText() == "First criterion" and not first.Check:IsShown()
    and not first.ProgressBar:IsShown(), "native incomplete text/check/progress visibility must remain")
data = {{"Counted", false, 1, 12, 10}}
local height = objectives:Display(1, 400)
assert(height == 30 and next(active) == first and made == 1 and first.ProgressBar.value == 10
    and first.ProgressBar.range[2] == 10 and first.ProgressBar.Text:GetText() == "12 / 10",
    "native pooled lone-progress layout, clamping and fraction must remain")
assert(first.points[1][1] == "TOPLEFT" and first.points[2][1] == "TOPRIGHT"
    and first.ProgressBarBackground:IsShown() and first.ProgressBarBackground:GetAlpha() == 0
    and first.ProgressBar.ProgressBarFrame:GetAlpha() == 0 and not first.Name:IsShown(),
    "native full-width counted criteria must retain visibility/layout while decoration is suppressed")
first:Init("Complete", true, 0, 1, 1)
assert(first.Check:IsShown() and first.Check.atlas == "worldquest-tracker-checkmark" and first.Check:GetAlpha() == .4
    and first.Name.textColor[1] == 1 and not first.ProgressBar:IsShown(),
    "native completion check and colors must survive direct criteria reuse")
registry.skinLegacySystem.refresh()
assert(first.ProgressBar == backdrop and first.ProgressBar:GetHeight() == 16
    and first.Name:GetText() == "Complete", "theme must retain cached surface, native geometry and criterion text")
data = {{"A", false, 0, 0, 1}, {"B", true, 0, 0, 1}}
assert(objectives:Display(1, 400) == 30 and made == 2, "native two-column layout must remain one row")
for row in pairs(active) do assert(row:GetWidth() == 175 and row.ProgressBar._quiRoundedSurface) end
data = {}; assert(objectives:Display(1, 400) == 0 and not next(active), "native empty criteria must release all rows")
env.profile.general.skinLegacySystem = false; data = {{"Disabled",false,1,1,2}}
objectives:Display(1,400)
local disabled = next(active); disabled.Name:SetFont("Native", 12, "")
disabled:Init("Disabled", false, 1, 1, 2)
assert(disabled.Name.font == "Native", "disabled native criteria must stop font overrides")
env.profile.general.skinLegacySystem = true
root.IsForbidden = function() return true end
disabled.Name:SetFont("Forbidden", 12, ""); disabled:Init("Forbidden", false, 0, 0, 1)
assert(disabled.Name.font == "Forbidden", "forbidden root must stop native criterion overrides")
root.IsForbidden = function() return false end
objectives.IsForbidden = function() return true end
disabled.Name:SetFont("Owner", 12, ""); registry.skinLegacySystem.refresh()
disabled:Init("Owner", false, 0, 0, 1)
assert(disabled.Name.font == "Owner", "forbidden objective owner must exclude active row refresh/init")
objectives.IsForbidden = function() return false end
disabled.parent = _G.UIParent; disabled.Name:SetFont("Borrowed", 12, "")
disabled:Init("Borrowed", false, 0, 0, 1)
assert(disabled.Name.font == "Borrowed", "criteria borrowed outside their native owner must retain presentation")
print("Legacy native objective row/progress controls passed")
