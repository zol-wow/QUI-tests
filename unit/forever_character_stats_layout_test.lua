local Harness = assert(loadfile("tests/helpers/character_chrome_harness.lua"))()
local file = assert(io.open(arg[1] or "modules/skinning/character_pane/character.lua", "r"))
local source = file:read("*a")
file:close()
local function slice(first, after)
    local start = assert(source:find(first, 1, true))
    local finish = assert(source:find(after, start + #first, true))
    return source:sub(start, finish - 1)
end

for _, forever in ipairs({ true, false }) do
    local harness = Harness.Build()
    local character = harness.BuildCharacterFrame()
    character.RightPaneHost = harness.NewFrame("Frame", nil, character)
    local native = harness.NewFrame("Frame", nil, character.RightPaneHost)
    native:SetFrameLevel(500)
    local world = setmetatable({
        ns = { Client = { isForever = forever } },
        EMPTY = {},
        GetSettings = function() return {} end,
        GetChrome = function() return { GetNativeStatsPane = function() return native end } end,
        Helpers = { IsSecretValue = function() return false end },
        ScheduleUpdate = function() end,
    }, { __index = _G })
    local chunk = assert(loadstring("local statsPanel, CreateStatsPanel\n"
        .. slice("CreateStatsPanel = function(parent, unit)", "local trackedFontStrings =")
        .. slice("local function PositionStatsPanelForLayout()", "local function GetPlayerAverageItemLevels()")
        .. slice("local function FinalizeStatsPanelLayout(", "local function MaskNativeStatsPane()")
        .. "\nreturn function() PositionStatsPanelForLayout(); return statsPanel end, FinalizeStatsPanelLayout"))
    setfenv(chunk, world)
    local position, finalize = chunk()
    local panel = position()
    if forever then
        assert(panel:GetParent() == character.RightPaneHost, "Forever stats must follow the native sidebar visibility")
        local top, bottom = panel.points[1], panel.points[2]
        assert(top[1] == "TOPLEFT" and top[2] == native and top[3] == "TOPLEFT" and top[4] == 5,
            "Forever stats must align inside the native stats viewport")
        assert(bottom[1] == "BOTTOMRIGHT" and bottom[2] == native and bottom[4] == -5,
            "Forever stats must use both native viewport edges rather than Retail's outside offset")
        assert(panel:GetFrameLevel() > native:GetFrameLevel(), "QUI stats must render above native pooled rows")
        local row = harness.NewFrame("Frame", nil, panel.scrollChild)
        panel.scrollChild.statRowPool = { row }
        for _, width in ipairs({ 210, 178 }) do
            panel.scrollFrame:Fire("OnSizeChanged", width, 300)
            assert(panel.scrollChild:GetWidth() == width, "scroll content must fill the current viewport")
            assert(row:GetWidth() == width - 10, "existing rows must resize with their viewport")
        end
    else
        assert(panel:GetParent() == character and panel:GetWidth() == 160, "Retail stats dimensions must be retained")
        assert(panel.points[1][1] == "TOPRIGHT" and panel.points[1][4] == 42,
            "Retail stats placement must be retained")
    end
    finalize(panel, panel.scrollChild, -400)
    assert(panel.scale == (forever and 1 or 0.92), "Forever must retain native scale through refresh")
    assert(panel.scrollChild:GetHeight() == 420, "scroll content must include every visible row")
    assert(position() == panel, "reopening must reuse the existing stats panel")
end
print("OK forever_character_stats_layout_test")
