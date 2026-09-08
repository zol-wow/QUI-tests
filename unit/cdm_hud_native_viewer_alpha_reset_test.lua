local function read(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local alphaByFrame, writesByFrame, forbidden, hooks = {}, {}, {}, {}
local function setAlpha(frame, alpha)
    alphaByFrame[frame] = alpha
    writesByFrame[frame] = (writesByFrame[frame] or 0) + 1
end
local function makeFrame()
    local frame = {
        SetAlpha = setAlpha,
        GetAlpha = function(self) return alphaByFrame[self] end,
        IsForbidden = function(self) return forbidden[self] == true end,
        SetScript = function() end,
    }
    alphaByFrame[frame] = 1
    return frame
end
_G.CreateFrame = makeFrame
_G.hooksecurefunc = function(frame, method, callback)
    hooks[frame] = (hooks[frame] or 0) + 1
    local original = assert(frame[method])
    frame[method] = function(...)
        original(...)
        callback(...)
    end
end
_G.EventRegistry = { RegisterCallback = function() end }
_G.UIParent = { IsShown = function() return true end }
_G.BottomManagedFrameContainer = nil
_G.RightManagedFrameContainer = nil
local now = 0
_G.GetTime = function() return now end
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_ManagedFrameSystem/Shared/ManagedFrameSystem.lua"))()
local managedFrameMixin = assert(_G.ManagedFrameContainerMixin)

local profile = { ncdm = { enabled = true } }
local ns = {
    Addon = { db = { profile = profile } },
    Helpers = { CreateStateTable = function() return setmetatable({}, { __mode = "k" }) end },
}
local source = read("QUI_CDM/cdm/hud_visibility.lua")
local stop = assert(source:find("local function IsAddonOwnedCDMMouseoverFrame", 1, true))
local applyAlpha, createController = assert(loadstring(source:sub(1, stop - 1)
    .. "\nreturn ApplyReanchorViewerAlpha, CreateVisibilityController"))("QUI", ns)
local viewers = { essential = makeFrame(), utility = makeFrame(), buff = makeFrame() }
local nativeManager = { showingFrames = {} }
for _, viewer in pairs(viewers) do nativeManager.showingFrames[viewer] = true end
local unmanaged = makeFrame()
nativeManager.showingFrames[unmanaged] = true

applyAlpha(0)
for _, viewer in pairs(viewers) do
    assert(alphaByFrame[viewer] == 1 and not hooks[viewer],
        "cold login must not hook or suppress native viewers before boot wiring exists")
end
ns._cdmBoot = { wiring = { GetViewerForKey = function(_, key) return viewers[key] end } }
applyAlpha(0)
managedFrameMixin.AnimInManagedFrames(nativeManager)
for key, viewer in pairs(viewers) do
    assert(alphaByFrame[viewer] == 0,
        key .. " native managed-frame alpha reset must not reveal hidden QUI cooldown icons")
end
assert(alphaByFrame[unmanaged] == 1 and not hooks[unmanaged],
    "native frames outside CDM wiring must retain Blizzard visibility")

local owned = makeFrame()
local controller = createController({
    getFrames = function() return { owned } end,
    getSettings = function() return { fadeDuration = 1 } end,
    applyAlpha = function(frames, alpha)
        for _, frame in ipairs(frames) do setAlpha(frame, alpha) end
    end,
    onAlpha = applyAlpha,
})
applyAlpha(1)
controller:StartFade(0)
now = 0.5
controller:Tick(controller.fadeFrame)
managedFrameMixin.AnimInManagedFrames(nativeManager)
for _, viewer in pairs(viewers) do
    assert(alphaByFrame[viewer] == 0.5, "native reset must preserve the current fade opacity")
    assert(hooks[viewer] == 1, "repeated fades must install only one alpha guard")
end
now = 1
controller:Tick(controller.fadeFrame)
managedFrameMixin.AnimInManagedFrames(nativeManager)
assert(alphaByFrame[viewers.essential] == 0, "completed fade must remain hidden after native reset")

local secretAlpha = setmetatable({}, { __eq = function() error("secret alpha comparison") end })
applyAlpha(secretAlpha)
managedFrameMixin.AnimInManagedFrames(nativeManager)
assert(rawequal(alphaByFrame[viewers.buff], secretAlpha),
    "health-curve opacity must pass through without comparison or replacement")

profile.ncdm.enabled = false
applyAlpha(0)
for _, viewer in pairs(viewers) do
    assert(alphaByFrame[viewer] == 1, "disabling CDM must restore native viewer opacity")
    local before = writesByFrame[viewer]
    viewer:SetAlpha(0.25)
    assert(alphaByFrame[viewer] == 0.25 and writesByFrame[viewer] == before + 1,
        "disabled CDM must release native alpha enforcement")
end

profile.ncdm.enabled = true
applyAlpha(0.4)
local viewer = viewers.utility
local before = writesByFrame[viewer]
viewer:SetAlpha(1)
assert(alphaByFrame[viewer] == 0.4 and writesByFrame[viewer] == before + 2,
    "native reset must use one raw correction without recursive SetAlpha calls")
forbidden[viewer] = true
before = writesByFrame[viewer]
applyAlpha(0)
assert(writesByFrame[viewer] == before, "HUD update must skip a forbidden native viewer")
viewer:SetAlpha(0.75)
assert(alphaByFrame[viewer] == 0.75 and writesByFrame[viewer] == before + 1,
    "installed guard must skip viewers that became forbidden")

ns._cdmBoot = nil
viewer = viewers.essential
before = writesByFrame[viewer]
viewer:SetAlpha(0.6)
assert(alphaByFrame[viewer] == 0.6 and writesByFrame[viewer] == before + 1,
    "runtime teardown must release previously installed native alpha guards")

print("OK: cdm_hud_native_viewer_alpha_reset_test")
