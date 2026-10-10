local Harness = dofile("tests/helpers/character_chrome_harness.lua")
for _, enhanced in ipairs({ false, true }) do
    local h = Harness.Build()
    h.ns.Client = { isForever = true }
    h.SetGates(true, enhanced)
    if arg[1] then assert(loadfile(arg[1]))("QUI", h.ns) end
    local frame = h.BuildCharacterFrame()
    frame:SetSize(631, 484)
    frame.ModeTabs = h.NewFrame("Frame", nil, frame)
    frame.ModeTabs.Tabs = {}
    for i = 1, 6 do
        local tab = h.NewFrame("Frame", nil, frame.ModeTabs)
        tab:SetID(i)
        tab:SetSize(64, 64)
        tab:SetPoint("TOPLEFT", i == 1 and frame.ModeTabs or frame.ModeTabs.Tabs[i - 1], i == 1 and "TOPLEFT" or "BOTTOMLEFT", 0, -2)
        tab.Icon = tab:CreateTexture(nil, "ARTWORK")
        tab:SetScript("OnMouseUp", function() frame.selectedTab = i end)
        frame.ModeTabs.Tabs[i] = tab
    end
    ReputationFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -20)
    TokenFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -20)
    local chrome = h.ns.CharacterChrome
    local shell = chrome.SetExtended(true)
    assert(shell.allPoints == frame and #shell.points == 0,
        "Forever shell must follow its native width, including collapsed sidebar")
    assert(not ReputationFrame.allPoints and not TokenFrame.allPoints,
        "Forever detail panes must keep native parent anchors")
    for _, width in ipairs({ 631, 398, 631 }) do
        frame:SetWidth(width)
        chrome.SetExtended(false)
        chrome.StyleTabs()
        chrome.RefreshTheme()
        h.RunTimers()
        assert(shell.allPoints == frame and #shell.points == 0, "shell must remain attached through refresh")
        for i, tab in ipairs(frame.ModeTabs.Tabs) do
            assert(tab:GetWidth() == 64 and tab:GetHeight() == 64, "native side tab dimensions must survive")
            assert(#tab.points == 1 and tab.points[1][1] == "TOPLEFT", "native vertical tab anchors must survive")
            assert(tab.points[1][3] == (i == 1 and "TOPLEFT" or "BOTTOMLEFT"), "tabs must stay vertical")
            assert(tab.Icon:GetAlpha() == 1, "native icons must remain visible")
            assert(h.SkinBase.GetBackdrop(tab):GetAlpha() == 1, "side tab chrome must remain visible with enhancement")
            tab:Fire("OnMouseUp", "LeftButton", true)
            assert(frame.selectedTab == i, "native click handler must remain intact")
        end
    end
end
print("OK: Forever Character geometry preserves native vertical tabs and expanding shell")
