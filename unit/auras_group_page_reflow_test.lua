local frames = {}

local function NewFrame()
    local frame = { height = 0, hooks = {}, points = {} }

    function frame:SetPoint(...)
        self.points[#self.points + 1] = { ... }
    end

    function frame:SetHeight(height)
        local changed = self.height ~= height
        self.height = height
        if changed then
            for _, hook in ipairs(self.hooks.OnSizeChanged or {}) do
                hook(self, 0, height)
            end
        end
    end

    function frame:GetHeight()
        return self.height
    end

    function frame:HookScript(script, hook)
        self.hooks[script] = self.hooks[script] or {}
        self.hooks[script][#self.hooks[script] + 1] = hook
    end

    return frame
end

CreateFrame = function()
    local frame = NewFrame()
    frames[#frames + 1] = frame
    return frame
end

QUI = {
    GUI = {
        Colors = {},
        CreateLabel = function()
            return NewFrame()
        end,
    },
}

local feature
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Settings = {
        Registry = {
            RegisterFeature = function(_, definition)
                feature = definition
            end,
        },
        Schema = {
            Feature = function(definition) return definition end,
            Section = function(definition) return definition end,
        },
        FullSurface = {
            BuildContextDropdownRow = function()
                local row = NewFrame()
                row:SetHeight(30)
                return { row = row, dropdownDB = { _contextMode = "party" } }
            end,
        },
    },
    QUI_GroupFramesSettingsModel = {
        GetContextOptions = function() return {} end,
    },
    QUI_GroupFramesSettingsSurface = {
        GetContextMode = function() return "party" end,
        ShowPreviewOn = function() end,
    },
}

local auraRenders, dispelRenders = 0, 0
ns.QUI_GroupFramesSettingsSchema = {
    RenderAurasTab = function(host)
        auraRenders = auraRenders + 1
        host:SetHeight(200)
        return 200
    end,
    RenderDispelTab = function(host)
        dispelRenders = dispelRenders + 1
        host:SetHeight(100)
        return 100
    end,
}

assert(loadfile("core/settings/content/auras_group_page.lua"))("QUI", ns)

local section = assert(feature.sections[1])
local host = NewFrame()
local resizeCalls = {}
local ctx = {
    host = host,
    runtime = { sectionHeights = {} },
    ResizeSection = function(_, id, height)
        resizeCalls[#resizeCalls + 1] = { id = id, height = height }
    end,
}

local initialHeight = section.build(host, ctx, section)
local editorHost, dispelHost, hintHost = frames[1], frames[2], frames[3]

assert(initialHeight == 480, "initial page height should include every stacked surface")
assert(#resizeCalls == 0, "initial render should return its height without resizing an unmounted section")
assert(dispelHost.points[1][2] == editorHost and dispelHost.points[1][3] == "BOTTOMLEFT",
    "dispel settings must anchor below the aura editor")
assert(hintHost.points[1][2] == dispelHost and hintHost.points[1][3] == "BOTTOMLEFT",
    "dispel hints must anchor below the dispel settings")

ctx.runtime.sectionHeights.settings = initialHeight
editorHost:SetHeight(350)

assert(host:GetHeight() == 630, "expanded aura settings must grow the outer Auras page")
assert(#resizeCalls == 1 and resizeCalls[1].id == "settings" and resizeCalls[1].height == 630,
    "expanded aura settings must resize the mounted outer section")
assert(auraRenders == 1 and dispelRenders == 1,
    "expansion must reflow existing sections without rendering duplicates")

print("OK: auras_group_page_reflow_test")
