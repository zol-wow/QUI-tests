local function Read(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local corpus = "tests/clients/forever/framexml/Interface/AddOns/"
assert(Read(corpus .. "Blizzard_GroupFinder/Blizzard_GroupFinder.toc"):find("## ExcludeLoadGameType: camelot", 1, true))
assert(Read(corpus .. "Blizzard_GroupFinder_VanillaStyle/Mainline/WhoList.xml"):find('name="LFGWhoListFrame"', 1, true))
assert(Read(corpus .. "Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.xml"):find('parentKey="BookPage"', 1, true))
assert(Read(corpus .. "Blizzard_Collections/Shared/Blizzard_Collections.xml"):find('parentKey="TabContainer"', 1, true))
assert(Read(corpus .. "Blizzard_LegacySystem/Blizzard_LegacySystem.toc"):find("## AllowLoadGameType: camelot", 1, true))

local callbacks, registry, data, calls = {}, {}, {}, {}
local settings = { skinInstanceFrames = true, skinProfessions = true, skinCollections = true, skinLegacySystem = true }
local SkinBase = {}
local function Record(method, frame)
    if frame then
        calls[frame] = calls[frame] or {}
        calls[frame][method] = (calls[frame][method] or 0) + 1
    end
end
for _, method in ipairs({ "SkinWindow", "SkinCloseButton", "SkinButton", "SkinDropdown", "SkinEditBox",
    "SkinTrimScrollBar", "HookScrollBoxRowFonts", "SkinFrameText", "ApplyButtonFontObjectsDeep",
    "HidePortraitFrameChrome", "StripTextures", "CreateBackdrop", "RefreshFrameBackdropColors", "RefreshWidget",
    "SkinButtonFrameTemplate", "ApplyButtonFontObjects", "SkinTab", "LockFrameTextObjects" }) do
    SkinBase[method] = function(frame) Record(method, frame) end
end
SkinBase.SkinTabGroup = function(tabs, owner)
    for _, tab in ipairs(tabs or {}) do Record("SkinTab", tab); tab.owner = owner end
end
SkinBase.SkinWindow = function(frame, options)
    Record("SkinWindow", frame)
    if options and options.tabs then SkinBase.SkinTabGroup(options.tabs, frame) end
end
SkinBase.RefreshTabGroup = function(tabs)
    for _, tab in ipairs(tabs or {}) do Record("RefreshTab", tab) end
end
SkinBase.CollectNumberedTabs = function(prefix, count)
    local tabs = {}
    for i = 1, count do
        local tab = _G[prefix .. "Tab" .. i]
        if tab then tabs[#tabs + 1] = tab end
    end
    return tabs
end
SkinBase.IsSkinned = function(frame) return data[frame] and data[frame].skinned end
SkinBase.MarkSkinned = function(frame) data[frame] = data[frame] or {}; data[frame].skinned = true end
SkinBase.GetFrameData = function(frame, key) return data[frame] and data[frame][key] end
SkinBase.SetFrameData = function(frame, key, value) data[frame] = data[frame] or {}; data[frame][key] = value end
SkinBase.GetSkinColors = function() return 1, 1, 1, 1, 0, 0, 0, 1 end
SkinBase.GetBackdrop = function() end
SkinBase.OnAddOnLoaded = function(addon, callback) callbacks[addon] = callback end
local ns = {
    Helpers = { GetCore = function() return { db = { profile = { general = settings } } } end },
    Registry = { Register = function(_, key, entry) registry[key] = entry end },
}
ns.SkinBase = SkinBase

local function Load(module)
    local path = "modules/skinning/frames/" .. module .. ".lua"
    if arg and arg[1] == module then path = assert(arg[2]) end
    assert(loadfile(path))("QUI", ns)
end
local function Called(frame, method)
    return frame and calls[frame] and calls[frame][method] or 0
end
local function Tab(id)
    return {
        GetID = function() return id end,
        SetChecked = function(self, checked) self.checked = checked end,
    }
end
local function Page()
    return { ScrollBox = {}, ScrollBar = {}, SetShown = function(self, shown) self.shown = shown end }
end
_G.PVEFrame = nil
_G.LFGParentFrame = { ListingTab = Tab(1), BrowsingTab = Tab(2), WhoListingTab = Tab(3) }
_G.LFGParentFrameCloseButton = {}
_G.LFGListingFrame = Page()
_G.LFGListingFrame.PostButton = {}
_G.LFGListingFrame.ActivityView = { ScrollBox = {}, ScrollBar = {}, PlayStyleDropdown = {} }
_G.LFGBrowseFrame = Page()
_G.LFGBrowseFrame.CategoryDropdown = {}
_G.LFGWhoListFrame = Page()
_G.LFGWhoListFrame.EditBox = {}
Load("instanceframes")
assert(callbacks.Blizzard_GroupFinder_VanillaStyle, "Forever Group Finder addon must have a skin lifecycle")
settings.skinInstanceFrames = false
callbacks.Blizzard_GroupFinder_VanillaStyle()
assert(not SkinBase.IsSkinned(_G.LFGParentFrame), "disabled group finder must remain native")
settings.skinInstanceFrames = true
callbacks.Blizzard_GroupFinder_VanillaStyle()
assert(SkinBase.IsSkinned(_G.LFGParentFrame), "actual Forever Group Finder must skin without PVEFrame")
assert(Called(_G.LFGParentFrameCloseButton, "SkinCloseButton") == 1)
assert(Called(_G.LFGParentFrame.WhoListingTab, "SkinTab") == 1)
assert(Called(_G.LFGWhoListFrame.EditBox, "SkinEditBox") == 1, "Who search uses actual _G.LFGWhoListFrame")
assert(Called(_G.LFGListingFrame.ActivityView.ScrollBox, "HookScrollBoxRowFonts") == 1)
registry.skinInstanceFrames.refresh()
assert(Called(_G.LFGParentFrame, "RefreshFrameBackdropColors") == 1, "theme refresh cannot require Retail PVEFrame")
assert(Called(_G.LFGBrowseFrame.CategoryDropdown, "RefreshWidget") == 1)
callbacks.Blizzard_GroupFinder_VanillaStyle()
assert(Called(_G.LFGParentFrame, "SkinWindow") == 1, "lifecycle must be idempotent")

_G.ProfessionsMixin = {}
assert(loadfile(corpus .. "Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.lua"))()
_G.InputUtil = { IsGamepadUIEnabled = function() return false end }
_G.ProfessionsFrame = { ProfessionsOverviewTab = Tab(1), rightProfessionTabs = { Tab(2), Tab(3) }, BookPage = Page() }
Load("professions")
callbacks.Blizzard_Professions()
assert(Called(_G.ProfessionsFrame.ProfessionsOverviewTab, "SkinTab") == 1, "Forever overview side tab must skin")
assert(Called(_G.ProfessionsFrame.rightProfessionTabs[2], "SkinTab") == 1, "Forever profession side tabs must skin")
assert(Called(_G.ProfessionsFrame.BookPage, "SkinFrameText") == 1, "embedded professions book must receive font treatment")
_G.ProfessionsMixin.RightTabSelected(_G.ProfessionsFrame, _G.ProfessionsFrame.rightProfessionTabs[2])
assert(_G.ProfessionsFrame.rightProfessionTabs[2].checked and not _G.ProfessionsFrame.ProfessionsOverviewTab.checked)
registry.skinProfessions.refresh()
assert(Called(_G.ProfessionsFrame.rightProfessionTabs[2], "RefreshTab") == 1)

_G.CollectionsJournal = { TabContainer = { Tabs = { Tab(1), Tab(2), Tab(3), Tab(4), Tab(5) } } }
Load("journals")
callbacks.Blizzard_Collections()
assert(Called(_G.CollectionsJournal.TabContainer.Tabs[5], "SkinTab") == 1, "native collection tab array must be authoritative")
registry.skinCollections.refresh()
assert(Called(_G.CollectionsJournal.TabContainer.Tabs[5], "RefreshTab") == 1)

_G.LegacySystemFrame = {
    Tabs = { Tab(1), Tab(2), Tab(3) },
    RewardTrackPage = Page(),
    ChallengesPage = { CategoryList = { ScrollBox = {}, ScrollBar = {}, SearchBox = {}, FilterDropdown = {} }, DetailPane = Page() },
    TreePage = { LegacyTreeTraitPanel = { ApplyButton = {}, SearchBox = {} } },
}
local rewardHook, talentCallback
_G.hooksecurefunc = function(target, method, callback)
    assert(target == _G.LegacySystemFrame.RewardTrackPage and method == "SetupRewardTrack")
    rewardHook = callback
end
_G.LegacySystemFrame.RewardTrackPage.SetupRewardTrack = function() end
_G.TalentFrameBaseMixin = { Event = { TalentButtonAcquired = "TalentButtonAcquired" } }
_G.LegacySystemFrame.TreePage.LegacyTreeTraitPanel.RegisterCallback = function(_, event, callback)
    assert(event == TalentFrameBaseMixin.Event.TalentButtonAcquired)
    talentCallback = callback
end
_G.LegacySystemFrame.Pages = { _G.LegacySystemFrame.RewardTrackPage, Page(), Page() }
_G.CreateFromMixins = function() return {} end
assert(loadfile(corpus .. "Blizzard_LegacySystem/Blizzard_LegacySystem.lua"))()
Load("misc_frames")
assert(callbacks.Blizzard_LegacySystem, "Forever Legacy System addon must have a skin lifecycle")
settings.skinLegacySystem = false
callbacks.Blizzard_LegacySystem()
assert(not SkinBase.IsSkinned(_G.LegacySystemFrame), "disabled Legacy System must remain native")
settings.skinLegacySystem = true
callbacks.Blizzard_LegacySystem()
assert(SkinBase.IsSkinned(_G.LegacySystemFrame))
assert(Called(_G.LegacySystemFrame.Tabs[3], "SkinTab") == 1)
assert(Called(_G.LegacySystemFrame.ChallengesPage.DetailPane.ScrollBox, "HookScrollBoxRowFonts") == 1)
assert(Called(_G.LegacySystemFrame.TreePage.LegacyTreeTraitPanel.ApplyButton, "SkinButton") == 1)
assert(Called(_G.LegacySystemFrame.RewardTrackPage, "SkinFrameText") == 1)
rewardHook(_G.LegacySystemFrame.RewardTrackPage)
assert(Called(_G.LegacySystemFrame.RewardTrackPage, "SkinFrameText") == 2, "rebuilt reward cards need fresh font coverage")
local talent = {}
talentCallback(nil, talent)
assert(Called(talent, "LockFrameTextObjects") == 1, "future talent node text must retain the QUI font")
_G.LegacySystemFrameMixin.SelectPage(_G.LegacySystemFrame, 3)
assert(_G.LegacySystemFrame.Tabs[3].checked and not _G.LegacySystemFrame.Tabs[1].checked)
assert(_G.LegacySystemFrame.Pages[3].shown and not _G.LegacySystemFrame.Pages[1].shown, "native page visibility must remain functional")
registry.skinLegacySystem.refresh()
assert(Called(_G.LegacySystemFrame.ChallengesPage.CategoryList.FilterDropdown, "RefreshWidget") == 1)
assert(Called(_G.LegacySystemFrame.Tabs[3], "RefreshTab") == 1)
print("OK: forever_skinning_native_panels_test")
