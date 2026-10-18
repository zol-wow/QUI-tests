local harness = dofile("tests/helpers/character_chrome_harness.lua").Build()
local function read(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end

local source = read(os.getenv("QUI_OBJECTIVE_SOURCE") or "modules/skinning/gameplay/objectivetracker.lua")
local first = source:find("local function ApplyTrackerTextFont(", 1, true)
    or assert(source:find("local function StyleLine(", 1, true))
local last = assert(source:find("local LCG", first, true))
local applyFirst = assert(source:find("local function ApplyFontStyles(", last, true))
local applyLast = assert(source:find("RefreshTrackerContent = function()", applyFirst, true))
local blockFirst = assert(source:find("local function ApplyBlockSkinning(", last, true))
local blockLast = assert(source:find("local trackerModules", blockFirst, true))
local code = source:sub(first, last - 1) .. source:sub(applyFirst, applyLast - 1)
    .. source:sub(blockFirst, blockLast - 1)
    .. "\nreturn ApplyFontStyles, EnsureTrackerTextHooks, ApplyBlockSkinning"

local function mix(...)
    local result = {}
    for i = 1, select("#", ...) do
        for key, value in pairs(select(i, ...)) do result[key] = value end
    end
    return result
end

local function font(parent)
    local text = parent:CreateFontString()
    text:SetFont("Blizzard.ttf", 10, "")
    text:SetWidth(180)
    text.fontObject = {}
    function text:GetFontObject() return self.fontObject end
    function text:SetMaxLines(count) self.maxLines = count end
    function text:GetStringHeight()
        local rows = math.ceil(#(self:GetText() or "") * self.fontSize * 0.55 / self:GetWidth())
        if self.maxLines and self.maxLines > 0 then rows = math.min(rows, self.maxLines) end
        return rows * self.fontSize
    end
    function text:GetHeight() return self.height and self.height > 0 and self.height or self:GetStringHeight() end
    return text
end

local function run(corpus)
    local settings = {
        skinObjectiveTracker = true,
        objectiveTrackerTitleFontSize = 18,
        objectiveTrackerTextFontSize = 18,
    }
    local data, hooks, errors, dirtyCallbacks = {}, {}, {}, {}
    local names = { "ProfessionsRecipeTracker", "QuestObjectiveTracker", "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker" }
    local sandbox = setmetatable({
        CreateFromMixins = mix,
        RunNextFrame = function(callback) dirtyCallbacks[#dirtyCallbacks + 1] = callback end,
        ObjectiveTrackerSlidingMixin = {},
        EnumUtil = { MakeEnum = function(...)
            local result = {}
            for i, name in ipairs({ ... }) do result[name] = i end
            return result
        end },
        OBJECTIVE_TRACKER_COLOR = { Normal = { r = 1, g = 1, b = 1 }, Header = { r = 1, g = 1, b = 1 } },
        OBJECTIVE_DASH_STYLE_SHOW = 1,
        QUEST_DASH = "-",
        GetSettings = function() return settings end,
        GetFontPath = function() return "QUIFont.ttf" end,
        GetFontFlags = function() return "" end,
        CJKFont = function(text, path, size, flags) text:SetFont(path, size, flags) end,
        SafeSetTextColor = function() end,
        StyleLineIcon = function() end,
        CreateDeferredStyleQueue = function() return function() end end,
        Helpers = { SafeNumberOrNil = function(value) return type(value) == "number" and value or nil end },
        ns = { SafeCall = function(_, fn, ...)
            local ok, message = pcall(fn, ...)
            if not ok then errors[#errors + 1] = message end
            return ok, message
        end },
        SkinBase = {
            GetFrameData = function(frame, key) return data[frame] and data[frame][key] end,
            SetFrameData = function(frame, key, value)
                data[frame] = data[frame] or {}
                data[frame][key] = value
            end,
        },
        trackerModules = names,
        WIDGET_POOL_TRACKER_NAMES = { ScenarioObjectiveTracker = true, UIWidgetObjectiveTracker = true },
        hooksecurefunc = function(target, method, callback)
            hooks[target] = hooks[target] or {}
            hooks[target][method] = (hooks[target][method] or 0) + 1
            local original = target[method]
            target[method] = function(...)
                local results = { original(...) }
                callback(...)
                return unpack(results)
            end
        end,
    }, { __index = _G })
    sandbox._G = sandbox
    function sandbox.IsWidgetPoolTracker(module)
        return module == sandbox.ScenarioObjectiveTracker or module == sandbox.UIWidgetObjectiveTracker
    end
    function sandbox.IsWidgetPoolBlock(block) return block and sandbox.IsWidgetPoolTracker(block.parentModule) end
    local function execute(text)
        local chunk = assert(loadstring(text))
        setfenv(chunk, sandbox)
        return chunk()
    end
    local path = corpus .. "/Interface/AddOns/Blizzard_ObjectiveTracker/"
    execute(read(path .. "Blizzard_ObjectiveTrackerBlock.lua"))
    execute(read(path .. "Blizzard_ObjectiveTrackerModule.lua"))
    local mixins = read(corpus .. "/Interface/AddOns/Blizzard_SharedXML/MixinUtil.lua")
    execute("DirtiableMixin = {}\n"
        .. assert(mixins:match("function DirtiableMixin:SetDirtyMethod%(method%).-\nend")) .. "\n"
        .. assert(mixins:match("function DirtiableMixin:MarkDirty%(%).-\nend")))
    local container = mix(sandbox.DirtiableMixin, { IsCollapsed = function() return false end })
    container:SetDirtyMethod(function() error("cosmetic refresh must not dispatch native scenario layout") end)
    local apply, ensure, skinBlock = execute(code)
    sandbox.ObjectiveTrackerManager = {
        AcquireFrame = function(_, owner, template)
            local frame = harness.NewFrame("Frame", nil, owner, template)
            if template:find("Line") then
                frame.Text, frame.Dash = font(frame), font(frame)
            else
                for key, value in pairs(sandbox.ObjectiveTrackerBlockMixin) do frame[key] = value end
                frame.HeaderText = font(frame)
            end
            return frame, true
        end,
        ReleaseFrame = function(_, frame) frame:Hide() end,
    }
    for _, name in ipairs(names) do
        local module = harness.NewFrame("Frame")
        for key, value in pairs(sandbox.ObjectiveTrackerModuleMixin) do module[key] = value end
        module.ContentsFrame = harness.NewFrame("Frame", nil, module)
        module.parentContainer = container
        module:OnLoad()
        sandbox[name] = module
    end
    local function style()
        apply(0)
    end
    local function layout(module, limit, extraLine)
        module:BeginLayout()
        module.availableHeight = limit or 1000
        local firstBlock = module:GetBlock(1)
        firstBlock:SetHeader("Formidable Flask of the Dawn's Brilliant Light")
        firstBlock:AddObjective(1, "Collect the exceptionally long named reagents needed for this recipe")
        firstBlock:AddObjective(2, "Gather the remaining crystals")
        if extraLine then firstBlock:AddObjective(3, string.rep("Long objective ", 12), nil, true) end
        assert(module:LayoutBlock(firstBlock), "first recipe must fit")
        local secondBlock = module:GetBlock(2, "AlternateBlockTemplate")
        secondBlock:SetHeader("Next recipe")
        secondBlock:AddObjective(1, "Remaining materials")
        local fits = module:LayoutBlock(secondBlock)
        return firstBlock, secondBlock, fits
    end
    local function assertMeasured(block)
        local extent = block.HeaderText:GetStringHeight()
        for _, line in pairs(block.usedLines) do
            if line.used then
                assert(line:GetHeight() >= line.Text:GetStringHeight(), "wrapped objective text overflows its native row")
                extent = extent + line:GetHeight() + block.parentModule.lineSpacing
            end
        end
        assert(block:GetHeight() >= extent,
            "long recipe text overruns next recipe: block height " .. block:GetHeight() .. " < rendered extent " .. extent)
    end

    local recipes, quests = sandbox.ProfessionsRecipeTracker, sandbox.QuestObjectiveTracker
    layout(recipes)
    layout(quests)
    style()
    assert(#dirtyCallbacks == 0 and not container.dirty,
        "font refresh must not queue the shared native update that reaches ShouldShowMawBuffs from QUI")
    for _, module in ipairs({ recipes, quests }) do
        assert(module.firstBlock.HeaderText.fontSize == 10,
            "existing typography must keep its measured size until native layout runs")
        assertMeasured(module.firstBlock)
    end
    assert(ensure, "tracker acquisition styling hook is required")
    for _, name in ipairs(names) do ensure(sandbox[name]); ensure(sandbox[name]) end
    for _, module in ipairs({ recipes, quests }) do
        assert(hooks[module].GetBlock == 1, "repeated skinning must install one acquisition hook")
        local fresh = module:GetBlock(3)
        fresh:SetHeader("A freshly tracked recipe with a long wrapped title")
        fresh:AddObjective(1, "An entirely new objective with several long words to collect")
        assert(module:LayoutBlock(fresh), "newly tracked recipe must fit")
        assert(fresh.HeaderText.fontSize == 18 and fresh.usedLines[1].Text.fontSize == 18,
            "new blocks must receive typography before Blizzard measures their first layout")
        assertMeasured(fresh)
        local firstBlock, secondBlock = layout(module, nil, true)
        assertMeasured(firstBlock)
        assertMeasured(secondBlock)
        assert(firstBlock.usedLines[3].Text:GetStringHeight() > 36, "full-height objective must actually wrap beyond two lines")
        assert(firstBlock.usedLines[3].Dash.fontSize == 18, "fresh dash typography must match its line")
        assert(secondBlock.HeaderText.fontSize == 18, "alternate templates must style before native header measurement")
        local oldHeight = firstBlock:GetHeight()
        settings.objectiveTrackerTitleFontSize, settings.objectiveTrackerTextFontSize = 9, 9
        style()
        firstBlock:Show()
        skinBlock(module, firstBlock)
        assert(not module:IsDirty() and #dirtyCallbacks == 0, "font reduction must wait for native layout")
        assert(firstBlock.HeaderText.fontSize == 18 and firstBlock:GetHeight() == oldHeight,
            "settings refresh must preserve typography and geometry together until native layout")
        firstBlock = layout(module, nil, true)
        assertMeasured(firstBlock)
        assert(firstBlock:GetHeight() < oldHeight, "smaller typography must shrink native block geometry")
        style()
        assert(not module:IsDirty(), "unchanged fonts must not create a refresh loop")
        settings.objectiveTrackerTitleFontSize, settings.objectiveTrackerTextFontSize = 18, 18
        local firstHeight = layout(module):GetHeight()
        local _, _, fits = layout(module, module.headerHeight + firstHeight - module.fromHeaderOffsetY)
        assert(not fits and module.hasSkippedBlocks, "native height limit must reject the overflowing next recipe")
    end
    for _, name in ipairs({ "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker" }) do
        local module = sandbox[name]
        assert(not hooks[module], "fixed widget modules must not acquire typography hooks")
        local block = recipes.firstBlock
        block.parentModule = module
        local line = block:GetLine(name)
        assert(line.Text.font == "Blizzard.ttf", "pooled block reassigned to widgets must retain native typography")
        block.parentModule = recipes
    end
    assert(#errors == 0, table.concat(errors, "\n"))
    local setFont = sandbox.CJKFont
    sandbox.CJKFont = function() error("font application failed") end
    recipes:BeginLayout()
    local existing = recipes.usedBlocks[recipes.blockTemplate][1]
    existing.HeaderText:SetFont("Blizzard.ttf", 10, "")
    local block = recipes:GetBlock(1)
    assert(block == existing, "failed header styling must not abort native block acquisition")
    block:SetHeader("Native header survives")
    local line = block:AddObjective("failed-style", "Native objective survives")
    assert(line.Text:GetText() == "Native objective survives" and block.height > 0,
        "failed early styling must not abort native objective text or measurement")
    recipes.availableHeight = 1000
    assert(recipes:LayoutBlock(block), "failed early styling must not abort native block layout")
    assert(#errors == 2, "both header and line font failures must be caught independently")
    sandbox.CJKFont = function(text, _, size, flags) setFont(text, "ResolvedFallback.ttf", size, flags) end
    style()
    layout(recipes)
    assertMeasured(recipes.firstBlock)
    style()
    assert(not recipes:IsDirty(), "stable fallback font must not perpetually invalidate native layout")
    local nextFontObject = {}
    sandbox.CJKFont = function(text) text.fontObject = nextFontObject end
    style()
    assert(not recipes:IsDirty() and #dirtyCallbacks == 0,
        "font-object changes must not force native layout from QUI")
    layout(recipes)
    assert(recipes.firstBlock.HeaderText:GetFontObject() == nextFontObject,
        "native layout must apply font-object changes even when the primary alphabet font tuple is unchanged")
    style()
    assert(not recipes:IsDirty(), "stable fallback font object must not perpetually invalidate native layout")
end

run("tests/framexml")
run("tests/clients/forever/framexml")
print("OK: objective_tracker_text_layout_test")
