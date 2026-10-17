local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local Skin = env.SkinBase
local file = assert(io.open(arg[1] or "modules/skinning/frames/character.lua"))
local source = file:read("*a")
file:close()
local start = assert(source:find("local function SkinToggleCollapseButton(", 1, true))
local finish = assert(source:find("local function SkinReputationEntry", start, true))
local chunk = assert(loadstring(source:sub(start, finish - 1) .. "\nreturn SkinToggleCollapseButton"))
setfenv(chunk, setmetatable({ SkinBase = Skin }, { __index = _G }))
local style = chunk()
for _, kind in ipairs({ "Reputation", "Currency" }) do
    local collapsed = true
    local button = env.NewFrame("Button")
    setmetatable(button, { __index = function(_, key)
        if key:match("^Get") or key:match("^Set[A-Z]") then return function() end end
    end })
    local header = { IsCollapsed = function() return collapsed end }
    button.GetHeader = function() return header end
    local normal = button:CreateTexture()
    local pushed = button:CreateTexture()
    button.GetNormalTexture = function() return normal end
    button.GetPushedTexture = function() return pushed end
    button.RefreshIcon = function(self)
        self:GetNormalTexture():SetAtlas(collapsed and "campaign_headericon_closed" or "campaign_headericon_open")
    end
    button:SetScript("OnClick", function(self) collapsed = not collapsed; self:RefreshIcon() end)
    local click = button:GetScript("OnClick")
    style(button)
    local glyph = Skin.GetFrameData(button, "characterCollapseGlyph")
    assert(glyph and glyph:GetText() == "+", kind .. " collapsed control must use the QUI plus glyph")
    assert(Skin.GetBackdrop(button)._quiRoundedSurface, kind .. " control must use shared rounded chrome")
    assert(button:GetScript("OnClick") == click, "native click handler must remain intact")
    button:Fire("OnClick")
    assert(glyph:GetText() == "−", "expanded state must update after native RefreshIcon")
    assert(normal.alpha == 0, "native atlas must remain hidden after native refresh")
    style(button)
    assert(Skin.GetFrameData(button, "characterCollapseGlyph") == glyph, "recycled rows must reuse the control")
    button:Fire("OnClick")
    assert(glyph:GetText() == "+", "collapsed state must return after another click")
end
print("OK: character_collapse_controls_test")
