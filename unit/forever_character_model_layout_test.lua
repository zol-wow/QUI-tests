local Harness = dofile("tests/helpers/character_chrome_harness.lua")
local file = assert(io.open(arg[1] or "modules/skinning/character_pane/character.lua"))
local source = file:read("*a")
file:close()
local first = assert(source:find("local function PositionModelScene()", 1, true))
local last = assert(source:find("local function PositionStatsPanelForLayout()", first, true))
local chunk = source:sub(first, last - 1) .. "\nreturn PositionModelScene"
for _, forever in ipairs({ true, false }) do
    local h = Harness.Build()
    local character = h.BuildCharacterFrame()
    local left = h.NewFrame("Frame", nil, character)
    left:SetSize(398, 464)
    local strip = h.NewFrame("Frame", nil, left)
    local scene = h.NewFrame("Frame", nil, character)
    -- Native Camelot model anchors use the fixed left pane and its top strip.
    scene:SetPoint("TOPLEFT", strip, "BOTTOMLEFT")
    scene:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT")
    scene:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT")
    scene:SetFrameLevel(50)
    local env = setmetatable({ ns = { Client = { isForever = forever } }, CharacterFrame = character,
        CharacterModelScene = scene, GetSettings = function() return {} end }, { __index = _G })
    local loader = assert(loadstring(chunk))
    setfenv(loader, env)
    local position = loader()
    for _, width in ipairs({ 631, 398, 631 }) do
        character:SetWidth(width)
        position()
        if forever then
            assert(#scene.points == 3 and scene.points[1][2] == strip and scene.points[3][2] == left,
                "Forever model must keep native left-pane anchors when details collapse")
            assert(scene:GetFrameLevel() == 2, "model must stay below enhanced equipment chrome")
        else
            assert(#scene.points == 2 and scene.points[1][2] == character and scene.points[2][4] == -204,
                "Retail model layout must remain unchanged")
            assert(scene:GetFrameLevel() == 2, "Retail model layering must remain unchanged")
        end
    end
end
print("OK: forever_character_model_layout_test")
