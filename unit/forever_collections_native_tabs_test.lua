local Harness = dofile("tests/helpers/character_chrome_harness.lua")
local function Read(path)
    local f = assert(io.open(path, "rb")); local source = f:read("*a"); f:close(); return source
end
local source = Read(arg[1] or "modules/skinning/frames/journals.lua")
local first = assert(source:find("local function SkinCollections()", 1, true))
local last = assert(source:find("local function RefreshCollections()", first, true))
local body = source:sub(first, last - 1) .. "\nreturn SkinCollections"
for _, forever in ipairs({ true, false }) do
    local h = Harness.Build()
    h.SetGates(true, true)
    h.ns.Client = { isForever = forever }
    local frame = h.NewFrame("Frame", "CollectionsJournal")
    _G.CollectionsJournal = frame
    frame:SetSize(702, 600)
    frame.TabContainer = h.NewFrame("Frame", nil, frame)
    frame.TabContainer.Tabs = {}
    for i = 1, 5 do
        local tab = h.NewFrame("Button", nil, frame.TabContainer)
        tab:SetID(i)
        tab:SetSize(64, 64)
        tab:Show()
        tab:SetPoint("TOPLEFT", i == 1 and frame.TabContainer or frame.TabContainer.Tabs[i - 1],
            i == 1 and "TOPLEFT" or "BOTTOMLEFT", 0, i == 1 and -60 or -2)
        tab.Icon = tab:CreateTexture(nil, "ARTWORK")
        tab.Icon:SetTexture("native-collection-icon-" .. i)
        tab:SetScript("OnMouseUp", function() frame.selectedTab = i end)
        frame.TabContainer.Tabs[i] = tab
    end
    local env = setmetatable({ ns = h.ns, SkinBase = h.SkinBase,
        IsSettingEnabled = function() return true end,
        HookCollectionsText = function() end, StyleCollectionsControls = function() end }, { __index = _G })
    local chunk = assert(loadstring(body)); setfenv(chunk, env); local skin = chunk()
    skin(); frame:Fire("OnShow"); h.RunTimers()
    for i, tab in ipairs(frame.TabContainer.Tabs) do
        if forever then
            assert(tab:GetWidth() == 64 and tab:GetHeight() == 64, "Forever must preserve native icon-tab dimensions")
            local p = tab.points[1]
            assert(#tab.points == 1 and p[1] == "TOPLEFT", "Forever tabs must not be docked below the window")
            assert(p[2] == (i == 1 and frame.TabContainer or frame.TabContainer.Tabs[i - 1]), "native side-tab parent must remain")
            assert(p[3] == (i == 1 and "TOPLEFT" or "BOTTOMLEFT"), "native vertical chain must remain")
        elseif i == 1 then
            assert(tab.points[1][1] == "TOPLEFT" and tab.points[1][3] == "BOTTOMLEFT", "Retail must retain its bottom-tab layout")
        end
        assert(tab.Icon:GetAlpha() == 1 and tab.Icon.texture == "native-collection-icon-" .. i, "native item art must remain")
        tab:Fire("OnMouseUp", "LeftButton", true)
        assert(frame.selectedTab == i, "native click handler must remain")
    end
end
print("OK: Collections keeps Forever side tabs and Retail bottom tabs with native art and clicks")
