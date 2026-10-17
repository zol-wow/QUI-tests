local ns = { QUI_GroupFrameChrome = {
    DimensionMode = function(count, context) return context == "party" and "party" or count <= 15 and "small" or count <= 25 and "medium" or "large" end,
    FrameDimensions = function(_, mode)
        local widths = { party = 180, small = 120, medium = 90, large = 60 }
        return widths[mode], 40
    end,
} }
assert(loadfile(arg[1] or "QUI_GroupFrames/groupframes/settings/group_frames_preview_driver.lua"))("QUI_GroupFrames", ns)
local D = ns.QUI_GroupFramesPreview
local db = { party = { layout = {} }, raid = { layout = {} }, testMode = { raidCount = 25 } }
D._GetGFDB = function() return db end
local root = { SetSize = function() end }
D._EnsureRoot = function() return root end
D._CreateMockFrame = function(parent)
    return { parent = parent, GetParent = function(self) return self.parent end,
        SetParent = function(self, p) self.parent = p end,
        SetSize = function(self, w, h) self.w, self.h = w, h end,
        ClearAllPoints = function() end, SetPoint = function() end,
        Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end }
end
D._ApplyFrameSettings = function() end
local options = { single = true, tier = "small", raidCount = 20, scenario = 1 }
D._state.host = { _quiGroupPreviewOptions = options }
D.Refresh("raid")
assert(#D._state.frames == 1, "inline preview must render exactly one specimen")
for _, tier in ipairs({"small", "medium", "large"}) do
    options.tier = tier
    D.Refresh("raid")
    assert(D._state.frames[1].w == ns.QUI_GroupFrameChrome.FrameDimensions(nil, tier), "single raid specimen must follow the selected dimension tier")
end
for scenario = 1, 5 do
    options.scenario = scenario
    D.Refresh("party")
    local m = D._state.frames[1]._previewMember
    assert((m._sampleThreat == true) == (scenario == 2))
    assert((m._sampleDispel == "Magic") == (scenario == 3))
    assert((m._sampleOOR == true) == (scenario == 4))
    assert((m._sampleTargetedSpells == 2) == (scenario == 5))
end
options.single = false
for count = 5, 40, 5 do
    options.raidCount = count
    D.Refresh("raid")
    assert(#D._state.frames == count, "full raid must use the session preview count")
end
options.single = true
D.Refresh("party")
for i = 2, #D._state.framePool do assert(not D._state.framePool[i].shown, "returning to single must hide pooled group frames") end
assert(db.testMode.raidCount == 25, "preview controls must not mutate saved test mode")
D._state.host = {}
D.Refresh("raid")
assert(#D._state.frames == 25, "legacy Auras preview must retain its existing count")
print("groupframes_inline_preview_test: ok")
