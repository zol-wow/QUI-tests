local Harness = dofile("tests/helpers/character_chrome_harness.lua")
local file = assert(io.open(arg[1] or "modules/skinning/character_pane/character.lua"))
local source = file:read("*a")
file:close()

local function slice(first, after)
    local start = assert(source:find(first, 1, true), first)
    local finish = assert(source:find(after, start + #first, true), after)
    return source:sub(start, finish - 1)
end

local helpers = slice("    local function AdjustForNonCharacterTab()", "    if ReputationFrame then")
local onShowStart = assert(source:find('    CharacterFrame:HookScript("OnShow", function()', 1, true))
local onShowEnd = assert(source:find("\n    end)", onShowStart, true)) + #"\n    end)"
local onShow = source:sub(onShowStart, onShowEnd)
helpers = helpers:gsub(onShow:gsub("([^%w])", "%%%1"), "")
local hooks = slice("    if ReputationFrame then", "    if PaperDollFrame then\n        PaperDollFrame:HookScript")

for _, forever in ipairs({ false, true }) do
    for _, skinOn in ipairs({ false, true }) do
        for _, enabled in ipairs({ false, true }) do
            local h = Harness.Build()
            h.ns.Client = { isForever = forever }
            h.SetGates(skinOn, enabled)
            local character = h.BuildCharacterFrame()
            character:SetSize(540, 424)
            character.Background = h.NewFrame("Frame", nil, character)
            character:SetScale(0.9)
            character.CloseButton:SetPoint("TOPRIGHT", character, "TOPRIGHT", -5, -5)
            for i = 1, 3 do
                _G["CharacterFrameTab" .. i] = h.NewFrame("Button", nil, character)
                _G["CharacterFrameTab" .. i]:SetPoint("TOPLEFT", character, "BOTTOMLEFT", i, -2)
            end
            h.Chrome.Initialize()
            local background = h.Chrome.GetShell()
            local cleanupCalls = 0
            local world = setmetatable({
                ns = h.ns, chrome = h.Chrome, customBg = background,
                CharacterFrame = character, slotOverlays = {}, frameState = {}, EMPTY = {},
                GetSettings = function() return { enabled = enabled, panelScale = 1.2 } end,
                SetCharacterFrameScale = function(scale) character:SetScale(scale) end,
                RestoreCharacterPanePopouts = function() cleanupCalls = cleanupCalls + 1 end,
                IsSkinningHandlingBackground = function() return skinOn end,
                InCombatLockdown = function() return true end,
            }, { __index = _G })
            local loader = assert(loadstring(slice("local function AnchorCharacterFrameBottomTabs(", "local charCombatFrame")
                .. helpers .. onShow .. hooks))
            setfenv(loader, world)
            loader()

            PaperDollFrame:Hide()
            character:Fire("OnShow")
            h.RunTimers()
            background = h.Chrome.GetShell()
            if enabled then
                assert(background and background:IsShown(), "opening a non-character tab first must create its shared shell")
                assert(character.scale == 1.30 * 1.2, "opening a non-character tab first must apply the enhancement scale")
            end

            for _, pane in ipairs({ ReputationFrame, TokenFrame, ReputationFrame }) do
                character:SetWidth(forever and 631 or 400)
                pane:Fire("OnShow")
                if enabled then
                    assert(background:IsShown(), "switching tabs must preserve the shell before the window reopens")
                    assert(character.scale == 1.30 * 1.2, "switching tabs must preserve scale before the window reopens")
                    assert(character.CloseButton:IsShown()
                        and h.SkinBase.GetFrameData(character.CloseButton, "closeLabel"):GetText() == "X",
                        "enhanced tabs must retain their visible close X")
                end
                character:Fire("OnShow")
                h.RunTimers()
                if enabled then
                    assert(background:IsShown(), "enhanced Reputation/Currency must keep their shared shell with frame skinning off")
                    assert(character.scale == 1.30 * 1.2, "opening and reopening non-character tabs must preserve the enhancement scale")
                    assert(not character.NineSlice:IsShown(), "enhanced tabs must not restore a smaller native shell")
                    if not forever then
                        local bounds = { background:GetPoint(2) }
                        local close = { character.CloseButton:GetPoint(1) }
                        assert(bounds[4] == 595 and bounds[5] == -82, "all enhanced tabs must keep the full shared window bounds")
                        assert(close[2] == character and close[3] == "TOPLEFT" and close[4] < bounds[4],
                            "the close X must remain inside the visible shell")
                        assert(pane.allPoints == background, "Reputation/Currency must fill the visible shared shell")
                    else
                        assert(background.allPoints == character, "Forever must retain its native window bounds")
                        local close = { character.CloseButton:GetPoint(1) }
                        assert(close[3] == "TOPRIGHT" and close[4] == -5, "Forever close X must stay at its native right edge")
                    end
                else
                    assert(character.scale == 0.9, "disabled Character Pane must not rescale native or chrome-only tabs")
                    assert(cleanupCalls == 0, "disabled Character Pane must not run enhancement tab cleanup")
                    local close = { character.CloseButton:GetPoint(1) }
                    assert(close[3] == "TOPRIGHT" and close[4] == -5, "disabled Character Pane must leave the native close X inside the frame")
                    local tab = { CharacterFrameTab1:GetPoint(1) }
                    assert(tab[5] == -2, "disabled Character Pane must leave native bottom-tab anchors intact")
                end
            end
        end
    end
end
print("OK: character_disabled_tab_lifecycle_test")
