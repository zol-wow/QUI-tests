-- tests/unit/options_full_surface_cached_tabs_test.lua
-- Run: lua tests/unit/options_full_surface_cached_tabs_test.lua
-- luacheck: globals CreateFrame

local function NewFrame()
    local frame = {
        children = {},
        regions = {},
        scripts = {},
        shown = true,
    }

    function frame:SetPoint(...)
        self.points = self.points or {}
        self.points[#self.points + 1] = { ... }
    end
    function frame:GetParent() return self.parent end
    function frame:SetAllPoints() end
    function frame:SetHeight(height)
        local changed = self.height ~= height
        self.height = height
        if changed and self.scripts.OnSizeChanged then
            self.scripts.OnSizeChanged(self, 0, height)
        end
    end
    function frame:GetHeight() return self.height or 0 end
    function frame:SetScript(script, handler) self.scripts[script] = handler end
    function frame:HookScript(script, handler)
        local previous = self.scripts[script]
        self.scripts[script] = function(...)
            if previous then previous(...) end
            handler(...)
        end
    end
    function frame:GetChildren() return unpack(self.children) end
    function frame:GetRegions() return unpack(self.regions) end
    function frame:Hide() self.shown = false end
    function frame:Show() self.shown = true end

    return frame
end

function CreateFrame(_, _, parent)
    local frame = NewFrame()
    frame.parent = parent
    if parent and parent.children then
        parent.children[#parent.children + 1] = frame
    end
    return frame
end

local ns = { L = setmetatable({}, { __index = function(_, key) return key end }) }
assert(loadfile(os.getenv("QUI_SURFACE_SOURCE") or "core/settings/full_surface.lua"))("QUI", ns)

local FullSurface = assert(ns.Settings and ns.Settings.FullSurface)

local body = NewFrame()
local state = { activeTab = "general" }
local tabClicks = {}
local renderCounts = {}
local clearCounts = {}

local function ClearFrame(frame)
    clearCounts[frame] = (clearCounts[frame] or 0) + 1
end

local function CreateTabStrip()
    local strip = NewFrame()
    local function Paint(_, _, onClick)
        tabClicks.general = function() onClick("general") end
        tabClicks.text = function() onClick("text") end
    end
    return strip, Paint
end

FullSurface.BuildScrollTabBody(body, {
    cacheTabBodies = true,
    state = state,
    clearFrame = ClearFrame,
    createTabStrip = CreateTabStrip,
    getTabs = function()
        return {
            { key = "general", label = "General" },
            { key = "text", label = "Text" },
        }
    end,
    getActiveTab = function()
        return state.activeTab
    end,
    setActiveTab = function(tabKey)
        state.activeTab = tabKey
    end,
    render = function()
        renderCounts[state.activeTab] = (renderCounts[state.activeTab] or 0) + 1
    end,
})

assert(renderCounts.general == 1, "initial active tab should render once")

tabClicks.text()
assert(renderCounts.text == 1, "new tab should render on first visit")

tabClicks.general()
assert(renderCounts.general == 1, "cached tab should not rerender when revisited")

state.repaintTabs()
assert(renderCounts.general == 2, "explicit repaint should refresh the active cached tab")

local multiBody = NewFrame()
local multiState = { activeTab = "entries" }
local multiClicks = {}
local multiRenderCounts = {}

local function CreateMultiTabStrip()
    local strip = NewFrame()
    local function Paint(_, _, onClick)
        multiClicks.entries = function() onClick("entries") end
        multiClicks.effects = function() onClick("effects") end
    end
    return strip, Paint
end

FullSurface.BuildMultiHostTabBody(multiBody, {
    cacheTabBodies = true,
    state = multiState,
    clearFrame = ClearFrame,
    createTabStrip = CreateMultiTabStrip,
    hosts = {
        composer = { kind = "plain", clearFrame = ClearFrame },
        scroll = { kind = "plain", clearFrame = ClearFrame },
    },
    defaultHostKey = "scroll",
    resolveHostKey = function(activeTab)
        return activeTab == "entries" and "composer" or "scroll"
    end,
    getTabs = function()
        return {
            { key = "entries", label = "Entries" },
            { key = "effects", label = "Effects" },
        }
    end,
    getActiveTab = function()
        return multiState.activeTab
    end,
    setActiveTab = function(tabKey)
        multiState.activeTab = tabKey
    end,
    render = function(_, activeTab)
        multiRenderCounts[activeTab] = (multiRenderCounts[activeTab] or 0) + 1
    end,
})

assert(multiRenderCounts.entries == 1, "initial multi-host tab should render once")

multiClicks.effects()
assert(multiRenderCounts.effects == 1, "new multi-host tab should render on first visit")

multiClicks.entries()
assert(multiRenderCounts.entries == 1, "cached multi-host tab should not rerender when revisited")

multiState.repaintTabs()
assert(multiRenderCounts.entries == 2, "explicit repaint should refresh the active cached multi-host tab")

local variantBody = NewFrame()
local variantState = { activeTab = "frame", selected = "enemyNPC" }
local variantClicks = {}
local variantRenders = {}
local PER_TYPE = { frame = true }

local function CreateVariantTabStrip()
    local strip = NewFrame()
    local function Paint(_, _, onClick)
        variantClicks.frame = function() onClick("frame") end
        variantClicks.general = function() onClick("general") end
    end
    return strip, Paint
end

FullSurface.BuildScrollTabBody(variantBody, {
    cacheTabBodies = true,
    state = variantState,
    clearFrame = ClearFrame,
    createTabStrip = CreateVariantTabStrip,
    resolveVariantKey = function(tabKey)
        if not PER_TYPE[tabKey] then return nil end
        return variantState.selected
    end,
    getTabs = function()
        return {
            { key = "frame", label = "Frame" },
            { key = "general", label = "General" },
        }
    end,
    getActiveTab = function() return variantState.activeTab end,
    setActiveTab = function(tabKey) variantState.activeTab = tabKey end,
    render = function()
        local key = variantState.activeTab .. "/" .. variantState.selected
        variantRenders[key] = (variantRenders[key] or 0) + 1
    end,
})

assert(variantRenders["frame/enemyNPC"] == 1, "the initial per-type tab should render once")

variantState.selected = "bossElite"
variantState.repaintTabs(false)
assert(variantRenders["frame/bossElite"] == 1, "a new type must build its own cached body")

variantState.selected = "enemyNPC"
variantState.repaintTabs(false)
assert(variantRenders["frame/enemyNPC"] == 1,
    "switching back to a built type must reuse its cached body, not tear it down and rebuild")

variantState.selected = "bossElite"
variantState.repaintTabs(false)
assert(variantRenders["frame/bossElite"] == 1, "every previously built type stays cached")

variantState.invalidateTabBodies()
variantState.repaintTabs(false)
assert(variantRenders["frame/bossElite"] == 2, "an explicit invalidate must still reach every variant")
variantState.selected = "enemyNPC"
variantState.repaintTabs(false)
assert(variantRenders["frame/enemyNPC"] == 2, "an explicit invalidate must reach the variants of every type")

variantClicks.general()
variantState.selected = "bossElite"
variantState.repaintTabs(false)
assert(variantRenders["general/bossElite"] == nil and variantRenders["general/enemyNPC"] == 1,
    "a tab that is not per-type must share one cached body across every type")

local refreshCount = 0
_G.QUI = { GUI = {} }
function _G.QUI.GUI:RegisterTileSurfacePages(owner, descriptor)
    local frame = owner
    while frame do
        if frame._quiOptionsTile then
            frame._quiOptionsTile._surfacePages = descriptor
            return true
        end
        frame = frame:GetParent()
    end
    return false
end
function _G.QUI.GUI:RefreshTileSurfacePages()
    refreshCount = refreshCount + 1
end

for _, builder in ipairs({ FullSurface.BuildScrollTabBody, FullSurface.BuildMultiHostTabBody }) do
    for _, cached in ipairs({ true, false }) do
        for _, contextualTop in ipairs({ false, -38 }) do
        local tile = {}
        local page = NewFrame()
        page._quiOptionsTile = tile
        local owner = CreateFrame("Frame", nil, CreateFrame("Frame", nil, page))
        local active = "general"
        local definitions = {
            { key = "general", label = "General" },
            { key = "text", label = "Text", disabled = true },
        }
        local counts, changes = {}, 0
        local result = builder(owner, {
            cacheTabBodies = cached,
            clearFrame = ClearFrame,
            tabTopOffset = contextualTop or nil,
            createTabStrip = function()
                return NewFrame(), function() end
            end,
            getTabs = function() return definitions end,
            getActiveTab = function() return active end,
            setActiveTab = function(key) active = key end,
            onTabChanged = function() changes = changes + 1 end,
            hosts = { general = { kind = "plain" }, text = { kind = "plain" } },
            defaultHostKey = "general",
            resolveHostKey = function(key) return key end,
            render = function()
                counts[active] = (counts[active] or 0) + 1
            end,
        })
        local navigation = assert(tile._surfacePages)
        assert(result.tabStrip == nil, "mounted surface must expose pages through navigation without duplicated tabs")
        assert(navigation.getTabs() == definitions and navigation.getActiveTab() == "general")
        assert(counts.general == 1 and refreshCount > 0)
        assert(navigation.selectTab("text") == false and counts.text == nil,
            "disabled flyout pages must not render")
        assert(navigation.selectTab("missing") == false and active == "general",
            "unknown flyout page keys must not change selection")
        assert(navigation.selectTab("general") == false and counts.general == 1,
            "selecting the current page must preserve its editor")
        definitions[2].disabled = false
        assert(navigation.selectTab("text") == true and counts.text == 1 and changes == 1)
        assert(navigation.selectTab("general") == true)
        assert(counts.general == (cached and 1 or 2),
            "flyout navigation must preserve cached-body behavior")
        definitions[2] = nil
        assert(navigation.selectTab("text") == false,
            "flyout selection must recheck current page availability")
        result.InvalidateCachedTabBodies()
        result.RepaintTabs()
        result.RenderActive(false)
        assert(counts.general == (cached and 2 or 3),
            "mounted surfaces must retain explicit invalidation")
        local container = result.scrollWrap or owner.children[1]
        local anchor = assert(container.points and container.points[1])
        assert(anchor[1] == "TOPLEFT" and anchor[2] == owner and anchor[3] == "TOPLEFT"
            and anchor[4] == 8 and anchor[5] == (contextualTop and contextualTop - 8 or 0),
            "content must retain context selector spacing without reserving hidden tabs")
        end
    end

    local stripBuilds = 0
    local standalone = builder(NewFrame(), {
        clearFrame = ClearFrame,
        createTabStrip = function()
            stripBuilds = stripBuilds + 1
            return NewFrame(), function() end
        end,
        hosts = { plain = { kind = "plain" } },
        defaultHostKey = "plain",
    })
    assert(standalone.tabStrip ~= nil and stripBuilds == 1,
        "standalone surfaces must retain their own tab strips even when main navigation is loaded")
end

local dropdownState
function _G.QUI.GUI:CreateFormDropdown(parent, _, _, key, db)
    local dropdown = CreateFrame("Frame", nil, parent)
    dropdownState = { key = key, db = db }
    return dropdown
end

local preview = NewFrame()
preview:SetHeight(180)
local previewBlock = assert(FullSurface.BuildDropdownPreviewBlock(preview, {
    selectedValue = "target",
    previewFillAlpha = 0,
}))
assert(preview._quiPreviewHost == previewBlock.previewHost
    and preview._quiPreviewHeader == previewBlock.headerRow)
assert(FullSurface.SetInlinePreviewCollapsed(preview, true))
assert(preview.height == 46 and not previewBlock.previewHost.shown and previewBlock.headerRow.shown,
    "collapsing an inline preview must preserve its selector row")
assert(dropdownState.db[dropdownState.key] == "target",
    "collapsing an inline preview must preserve the selected object")
preview:SetHeight(270)
assert(preview.height == 46, "external autoheight writes must not reopen a collapsed preview")
assert(not FullSurface.SetInlinePreviewCollapsed(preview, true),
    "repeating collapse must not overwrite the latest requested expanded height")
assert(FullSurface.SetInlinePreviewCollapsed(preview, false))
assert(preview.height == 270 and previewBlock.previewHost.shown and previewBlock.headerRow.shown)
assert(dropdownState.db[dropdownState.key] == "target")
preview:SetHeight(220)
assert(preview.height == 220, "expanded previews must continue accepting measured autoheight")
FullSurface.SetInlinePreviewCollapsed(preview, true)
FullSurface.SetInlinePreviewCollapsed(preview, false)
assert(preview.height == 220, "a new collapse cycle must retain the latest measured height")

local containerPreview = NewFrame()
containerPreview:SetHeight(230)
local leftControls = CreateFrame("Frame", nil, containerPreview)
leftControls:SetHeight(50)
FullSurface.BuildDropdownPreviewBlock(containerPreview, { previewFillAlpha = 0 })
FullSurface.SetInlinePreviewCollapsed(containerPreview, true)
assert(containerPreview.height == 66 and leftControls.shown,
    "CDM's taller loadout controls must survive preview collapse")

local simplePreview = NewFrame()
simplePreview:SetHeight(120)
FullSurface.SetInlinePreviewCollapsed(simplePreview, true)
assert(simplePreview.height == 1 and not simplePreview.shown)
simplePreview:SetHeight(150)
assert(simplePreview.height == 1)
FullSurface.SetInlinePreviewCollapsed(simplePreview, false)
assert(simplePreview.height == 150 and simplePreview.shown,
    "a preview without selector chrome must hide and restore its entire reservation")

print("OK: options_full_surface_cached_tabs_test")
