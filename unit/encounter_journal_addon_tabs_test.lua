-- Delve Companion adds EncounterJournal.DelvesTab after Suggested Content and
-- re-anchors Dungeons onto it from its own OnShow hook. QUI's docked footer
-- must keep that tab in the strip, or Dungeons is docked on top of it.
local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinEncounterJournal = true
_G.C_AddOns = { IsAddOnLoaded = function() return true, true end }

local frame = env.NewFrame("Frame")
_G.EncounterJournal = frame
frame.selectedTab = 4

local function NewTab(key, id)
    local tab = env.NewFrame("Button", nil, frame)
    tab:SetID(id)
    tab:SetText(key)
    tab.DisabledTexture = false
    tab:Show()
    frame[key] = tab
    return tab
end

for id, key in ipairs({
    "JourneysTab", "MonthlyActivitiesTab", "suggestTab", "dungeonsTab",
    "raidsTab", "LootJournalTab", "TutorialsTab",
}) do
    NewTab(key, id)
end

-- Delve Companion creates its tab and hooks OnShow synchronously on the
-- journal's ADDON_LOADED; QUI skins a frame later, so both exist first.
local delves = NewTab("DelvesTab", 8)
frame:HookScript("OnShow", function(self)
    local function SetTabAnchor(tab, relativeTo)
        tab:ClearAllPoints()
        tab:SetPoint("LEFT", relativeTo, "RIGHT", 3, 0)
    end
    SetTabAnchor(self.DelvesTab, self.suggestTab)
    SetTabAnchor(self.dungeonsTab, self.DelvesTab)
    SetTabAnchor(self.raidsTab, self.dungeonsTab)
    SetTabAnchor(self.TutorialsTab, self.raidsTab)
end)

assert(loadfile(os.getenv("QUI_JOURNALS_SOURCE") or "modules/skinning/frames/journals.lua"))("QUI", env.ns)

local ORDER = {
    "JourneysTab", "MonthlyActivitiesTab", "suggestTab", "DelvesTab",
    "dungeonsTab", "raidsTab", "LootJournalTab", "TutorialsTab",
}

local function AssertDockedStrip(context)
    for i = 2, #ORDER do
        local tab, previous = frame[ORDER[i]], frame[ORDER[i - 1]]
        local point, relative, relativePoint = tab:GetPoint()
        assert(point == "TOPLEFT" and relative == previous and relativePoint == "TOPRIGHT",
            context .. ": " .. ORDER[i] .. " must dock after " .. ORDER[i - 1])
    end
end

AssertDockedStrip("initial skin")
assert(env.SkinBase.GetFrameData(delves, "tabWindowJoin"), "the add-on Delves tab must join the footer like native tabs")

frame:Fire("OnShow")
AssertDockedStrip("after Delve Companion re-anchors on show")

frame.dungeonsTab:Fire("OnClick")
AssertDockedStrip("after selecting Dungeons")

print("OK: encounter_journal_addon_tabs_test")
