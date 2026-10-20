local sourceRoot = os.getenv("QUI_CDM_TEST_SOURCE_ROOT") or "."
local ns = {}

local function ReadSource(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local function Hook(owner, name, callback)
    local original = assert(owner[name], name)
    owner[name] = function(...)
        local result = original(...)
        callback(...)
        return result
    end
end

hooksecurefunc = Hook
issecretvalue = function() return false end
UIParent = {}

for _, name in ipairs({ "cdm_reanchor", "cdm_reanchor_wiring", "cdm_reanchor_runtime", "cdm_reanchor_hooks" }) do
    assert(loadfile(sourceRoot .. "/QUI_CDM/cdm/" .. name .. ".lua"))("QUI", ns)
end

local native = ReadSource("tests/framexml/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua")
CooldownViewerMixin = {}
for _, name in ipairs({ "OnCooldownDataChanged", "RefreshData" }) do
    local start = assert(native:find("function CooldownViewerMixin:" .. name .. "(", 1, true))
    local finish = assert(native:find("\nfunction ", start + 1, true))
    assert(loadstring(native:sub(start, finish - 1)))()
end

local containerSource = ReadSource(sourceRoot .. "/QUI_CDM/cdm/cdm_containers.lua")
local policyStart = assert(containerSource:find("local hk = ns.CDMReanchorHooks.New({", 1, true))
local policySource = containerSource:sub(policyStart)
local function ReadPolicyFunction(name)
    local expression = assert(policySource:match(name .. " = (function%(key%) return.- end),"))
    return assert(loadstring("return " .. expression))()
end
local ignoredReasons = assert(loadstring("return " .. assert(policySource:match("ignoreIndexReasons = (%b{})"))))()

local raw = {
    ClearAllPoints = function(frame) frame.points = {} end,
    SetPoint = function(frame, ...) frame.points[#frame.points + 1] = { ... } end,
    SetAlpha = function(frame, alpha) frame.alpha = alpha end,
}

local function Entry(id)
    return { source = "blizzardCDM", spellID = id }
end

for _, keys in ipairs({
    { "essential", "essential" },
    { "utility", "utility" },
    { "essential", "utility" },
    { "utility", "essential" },
}) do
    local nativeViewerKey, containerKey = unpack(keys)
    local frames = {}
    for index, id in ipairs({ 100, 200 }) do
        local frame = { cooldownID = id, layoutIndex = index, alpha = 1, points = {} }
        frame.GetCooldownID = function(self) return self.cooldownID end
        frame.GetSpellID = function(self) return self.cooldownID end
        frame.OnCooldownIDSet = function() end
        frame.SetCooldownID = function(self, value)
            self.cooldownID = value
            self:OnCooldownIDSet()
        end
        frame.SetPoint = raw.SetPoint
        frames[index] = frame
    end

    local viewer = { ids = { 100, 200 } }
    viewer.itemFramePool = {
        GetNumActive = function() return #frames end,
        EnumerateActive = function()
            local index = 0
            return function()
                index = index + 1
                return frames[index]
            end
        end,
    }
    viewer.GetItemFrames = function() return frames end
    viewer.GetCooldownIDs = function(self) return self.ids end
    viewer.GetItemCount = function(_, ids) return #ids end
    viewer.RefreshData = CooldownViewerMixin.RefreshData
    viewer.OnCooldownDataChanged = CooldownViewerMixin.OnCooldownDataChanged
    local nativeDataChanged = viewer.OnCooldownDataChanged
    viewer.RefreshLayout = function() error("same-count native updates must not rebuild the viewer layout") end

    local bridge = ns.CDMReanchor.New({ raw = raw, resolveIdentity = function(frame) return frame.cooldownID end })
    local wiring = ns.CDMReanchorWiring.New({
        bridge = bridge,
        getViewersForKey = function() return { viewer } end,
        resolveEntryCooldownID = function(entry) return entry.spellID end,
    })
    local curated = { Entry(100), Entry(200) }
    local container = {}
    local runtime = ns.CDMReanchorRuntime.New({
        bridge = bridge,
        wiring = wiring,
        getContainer = function(key) return key == containerKey and container or nil end,
        getSettings = function() return { enabled = true } end,
        getCurated = function() return curated end,
        buildLayout = function(_, entries)
            local placements = {}
            for index, entry in ipairs(entries) do
                placements[index] = { icon = entry, x = index * 32, y = 0, w = 30, h = 30 }
            end
            return { placements = placements }
        end,
    })

    local pending, refreshes = {}, 0
    local hooks = ns.CDMReanchorHooks.New({
        keys = { "essential", "utility" },
        refresh = function(key)
            if key == containerKey then refreshes = refreshes + 1 end
            runtime:RefreshContainer(key)
        end,
        schedule = function(callback) pending[#pending + 1] = callback end,
        shouldTrackActiveState = ReadPolicyFunction("shouldTrackActiveState"),
        shouldTrackCooldownID = ReadPolicyFunction("shouldTrackCooldownID"),
        ignoreIndexReasons = ignoredReasons,
    })
    hooks:InstallViewerHooks(function(key) return key == nativeViewerKey and viewer or nil end)
    hooks:InstallViewerHooks(function() return viewer end)

    local indexTimers, settingsCallback = {}, nil
    CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
    C_Timer = { After = function(_, callback) indexTimers[#indexTimers + 1] = callback end }
    EventRegistry = { RegisterCallback = function(_, event, callback)
        assert(event == "CooldownViewerSettings.OnDataChanged")
        settingsCallback = callback
    end }
    assert(loadfile(sourceRoot .. "/QUI_CDM/cdm/cdm_index.lua"))("QUI", ns)
    hooks:InstallIndexSubscription(ns.CDMIndex)

    local function Flush()
        local timers = indexTimers
        indexTimers = {}
        for _, callback in ipairs(timers) do callback() end
        local scheduled = pending
        pending = {}
        for _, callback in ipairs(scheduled) do callback() end
        assert(#pending == 0 and #indexTimers == 0, "refresh must settle without a scheduling loop")
    end

    local function UpdateNative(id)
        viewer.ids = { id, 200 }
        nativeDataChanged(viewer)
        settingsCallback()
    end

    local function AssertVisible(id)
        assert(frames[1].cooldownID == id, "native data must contain the destination spec identity")
        assert(frames[1].alpha == 1 and not bridge:GetData(frames[1]).sunk,
            nativeViewerKey .. " native -> " .. containerKey
                .. ": identity replacement must restore the sunk icon without moving a spell")
        assert(frames[2].alpha == 1, "shared ability must remain visible")
        assert(#frames[1].points == 2 and frames[1].points[1][2] == container,
            "restored icon must return to its configured container")
        assert(runtime:GetEntryForFrame(frames[1]).spellID == id, "feature registry must follow the new identity")
        assert(#runtime:GetReanchoredFrames(containerKey) == 2, "both native icons must be reclaimed")
    end

    assert(runtime:RefreshContainer(containerKey) == 2)
    UpdateNative(100)
    Flush()
    assert(refreshes == 0, "hook installation must seed existing identities without requesting a rebuild")
    for _, id in ipairs({ 300, 100, 300 }) do
        curated = { Entry(id), Entry(200) }
        assert(runtime:RefreshContainer(containerKey) == 1, "profile restore precedes native identity replacement")
        assert(frames[1].alpha == 0 and frames[2].alpha == 1, "only the obsolete spec ability is sunk")
        local before = refreshes
        UpdateNative(id)
        assert(refreshes == before, "native callbacks must defer reanchoring until the native update finishes")
        Flush()
        AssertVisible(id)
        assert(refreshes == before + 1, "each settled identity change must refresh once")
    end

    local before = refreshes
    for _ = 1, 100 do UpdateNative(300) end
    Flush()
    assert(refreshes == before, "unchanged native identities must not rebuild CDM on settings notifications")
    AssertVisible(300)

    curated = { Entry(500), Entry(200) }
    assert(runtime:RefreshContainer(containerKey) == 1)
    UpdateNative(400)
    UpdateNative(500)
    assert(refreshes == before, "multiple native identity updates must remain deferred")
    Flush()
    AssertVisible(500)
    assert(refreshes == before + 1, "multiple identity replacements in one tick must coalesce")

    before = refreshes
    local secretID = {}
    issecretvalue = function(value) return value == secretID end
    UpdateNative(secretID)
    assert(#pending == 0, "secret identities must not be compared, cached, or schedule a rebuild")
    UpdateNative(500)
    Flush()
    assert(refreshes == before, "an unreadable identity must preserve the last readable assignment")
    issecretvalue = function() return false end

    viewer.ids = { 200, 500 }
    nativeDataChanged(viewer)
    Flush()
    assert(refreshes == before + 1, "swapping assignments between existing frames must refresh once")
    assert(runtime:GetEntryForFrame(frames[1]).spellID == 200
        and runtime:GetEntryForFrame(frames[2]).spellID == 500,
        "unchanged spell membership must still update each frame's assigned entry")
    assert(frames[1].points[1][4] == 49 and frames[2].points[1][4] == 17,
        "reassigned frames must retain the configured spell order")
end

print("PASS: cdm_spec_native_identity_refresh_test")
