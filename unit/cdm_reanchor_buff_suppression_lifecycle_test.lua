local ns = {}
local native = {
    BaseLayoutMixin = {},
    CooldownViewerMixin = {},
    CooldownViewerItemMixin = {},
}
setmetatable(native, { __index = _G })

local function LoadNativeMethod(path, name)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find("function " .. name .. "(", 1, true))
    local last = assert(source:find("\nend", first, true))
    local chunk = assert(loadstring(source:sub(first, last + 3)))
    setfenv(chunk, native)
    chunk()
end

local viewerSource = "tests/framexml/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua"
local layoutSource = "tests/framexml/Interface/AddOns/Blizzard_SharedXML/LayoutFrame.lua"
LoadNativeMethod(layoutSource, "BaseLayoutMixin:AddLayoutChildren")
LoadNativeMethod(layoutSource, "BaseLayoutMixin:GetLayoutChildren")
LoadNativeMethod(viewerSource, "CooldownViewerMixin:GetItemContainerFrame")
LoadNativeMethod(viewerSource, "CooldownViewerMixin:GetItemFrames")
LoadNativeMethod(viewerSource, "CooldownViewerItemMixin:IsActive")

local function Hook(target, method, callback)
    local original = assert(target[method])
    target[method] = function(...)
        original(...)
        callback(...)
    end
end

for _, name in ipairs({ "cdm_reanchor.lua", "cdm_reanchor_wiring.lua", "cdm_reanchor_runtime.lua" }) do
    assert(loadfile("QUI_CDM/cdm/" .. name))("QUI", ns)
end

local function MakeRuntime(curated, settings, identityReadable)
    local frame = {
        alpha = 1,
        isActive = true,
        layoutIndex = 1,
        includeAsLayoutChildWhenHidden = true,
        pointWrites = 0,
    }
    function frame:IsShown() return true end
    frame.IsActive = native.CooldownViewerItemMixin.IsActive
    function frame:GetCooldownID() if identityReadable ~= false then return 123 end end
    function frame:GetSpellID() if identityReadable ~= false then return 456 end end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:ClearAllPoints() self.pointWrites = self.pointWrites + 1 end
    function frame:SetPoint() self.pointWrites = self.pointWrites + 1 end
    function frame:Hide() error("suppression must not hide native lifecycle frames") end
    function frame:Show() error("suppression must not show native lifecycle frames") end
    function frame:SetParent() error("suppression must not reparent native lifecycle frames") end

    local viewer = {
        GetItemContainerFrame = native.CooldownViewerMixin.GetItemContainerFrame,
        GetItemFrames = native.CooldownViewerMixin.GetItemFrames,
        GetLayoutChildren = native.BaseLayoutMixin.GetLayoutChildren,
        AddLayoutChildren = native.BaseLayoutMixin.AddLayoutChildren,
    }
    function viewer:GetChildren() return frame end
    function viewer:GetRegions() end
    function viewer:GetAdditionalRegions() end
    function viewer:IgnoreLayoutIndex() return false end

    local bridge = ns.CDMReanchor.New({
        raw = {
            SetAlpha = frame.SetAlpha,
            ClearAllPoints = frame.ClearAllPoints,
            SetPoint = frame.SetPoint,
        },
        hooksecurefunc = Hook,
    })
    local wiring = ns.CDMReanchorWiring.New({
        bridge = bridge,
        getViewerForKey = function() return viewer end,
    })
    local container = {}
    local runtime = ns.CDMReanchorRuntime.New({
        bridge = bridge,
        wiring = wiring,
        getContainer = function() return container end,
        getSettings = function() return settings end,
        getCurated = function() return curated end,
        frameIsActive = function(item) return item:IsActive() end,
        buildLayout = function(_, entries)
            local placements = {}
            for i, entry in ipairs(entries) do
                placements[i] = { icon = entry, x = 0, y = 0, w = 40, h = 40 }
            end
            return { placements = placements }
        end,
    })
    return runtime, frame, viewer, bridge
end

local settings = { iconDisplayMode = "active" }
local curated = {}
local runtime, frame, viewer, bridge = MakeRuntime(curated, settings)
assert(runtime:RefreshContainer("buff") == 0)
assert(frame.alpha == 0, "a known native buff absent from QUI's saved list must stay suppressed after reload")
assert(frame.pointWrites == 0, "unclaimed buff suppression preserves native anchors")
assert(frame:IsActive() and #viewer:GetItemFrames() == 1,
    "alpha suppression preserves native activity and layout enumeration")

curated[1] = { type = "spell", id = 456, spellID = 456, source = "blizzardCDM", isAura = true }
assert(runtime:RefreshContainer("buff") == 1)
assert(frame.alpha == 1 and bridge:IsClaimed(frame),
    "the actual spell mapper and reanchor runtime reclaim a suppressed buff")
local claimedPointWrites = frame.pointWrites
curated[1] = nil
assert(runtime:RefreshContainer("buff") == 0)
assert(frame.alpha == 0 and not bridge:IsClaimed(frame), "removing a claimed buff suppresses it")
assert(frame.pointWrites == claimedPointWrites, "releasing a buff claim preserves native anchors")

runtime, frame = MakeRuntime({}, settings, false)
assert(runtime:RefreshContainer("buff") == 0 and frame.alpha == 1,
    "an unidentified native buff retains its existing transient exemption")

runtime, frame, viewer = MakeRuntime({}, { enabled = false }, false)
assert(runtime:RefreshContainer("buff") == 0 and frame.alpha == 0,
    "an explicitly disabled buff container suppresses even unidentified native children")
assert(frame.pointWrites == 0 and frame:IsActive() and #viewer:GetItemFrames() == 1,
    "disabled buff suppression leaves the native lifecycle intact")

print("OK: cdm_reanchor_buff_suppression_lifecycle_test")
