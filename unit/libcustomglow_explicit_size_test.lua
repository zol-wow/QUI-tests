local secrets = dofile("tests/helpers/secret_sentinel.lua")
secrets.InstallSecretStub()
local secret = secrets.MakeSecretSentinel()
local secretReads = 0
local methods = {}
local function object(parent)
    return setmetatable({ parent = parent, points = {}, scripts = {}, shown = false, alpha = 1,
        width = 0, height = 0, masks = {} }, { __index = methods })
end
local function noop() end
for _, name in ipairs({ "SetTexture", "SetTexCoord", "SetVertexColor", "SetDesaturated", "SetColorTexture",
    "SetDrawLayer", "SetBlendMode", "SetAtlas", "SetChildKey", "SetOrder", "SetDuration",
    "SetScale", "SetStartDelay", "SetFromAlpha", "SetToAlpha", "SetLooping",
    "SetToFinalAlpha", "SetFlipBookRows", "SetFlipBookColumns", "SetFlipBookFrames",
    "SetFlipBookFrameWidth", "SetFlipBookFrameHeight" }) do methods[name] = noop end
function methods:GetParent() return self.parent end
function methods:SetParent(parent) self.parent = parent end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:SetSize(width, height)
    assert(type(width) == "number" and type(height) == "number", "size must be public")
    self.width, self.height = width, height
end
function methods:SetPoint(point, relative, relativePoint, x, y)
    self.points[point] = { relative = relative or self.parent, point = relativePoint or point,
        x = x or 0, y = y or 0 }
end
function methods:ClearAllPoints() self.points = {} end
function methods:SetAllPoints(relative)
    self:SetPoint("TOPLEFT", relative, "TOPLEFT")
    self:SetPoint("BOTTOMRIGHT", relative, "BOTTOMRIGHT")
end
local function anchorsSecret(frame)
    if frame.secret then return true end
    for _, point in pairs(frame.points) do
        if point.relative and anchorsSecret(point.relative) then return true end
    end
    return false
end
function methods:GetSize()
    if anchorsSecret(self) then
        secretReads = secretReads + 1
        return secret, secret
    end
    local tl, br = self.points.TOPLEFT, self.points.BOTTOMRIGHT
    if tl and br and tl.relative == br.relative then
        local width, height = tl.relative:GetSize()
        return width + br.x - tl.x, height + tl.y - br.y
    end
    return self.width, self.height
end
function methods:SetFrameLevel(level) self.level = level end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:GetAlpha() return self.alpha end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown end
function methods:Show()
    if self.shown then return end
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    if not self.shown then return end
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:CreateTexture() return object(self) end
function methods:CreateMaskTexture() return object(self) end
function methods:CreateAnimationGroup() return object(self) end
function methods:CreateAnimation() return object(self) end
function methods:Play()
    self.playing = true
    if self.scripts.OnPlay then self.scripts.OnPlay(self) end
end
function methods:Stop()
    self.playing = false
    if self.scripts.OnStop then self.scripts.OnStop(self) end
end
function methods:IsPlaying() return self.playing == true end
function methods:GetNumMaskTextures() return #self.masks end
function methods:GetMaskTexture(index) return self.masks[index] end
function methods:AddMaskTexture(mask) self.masks[#self.masks + 1] = mask end
function methods:RemoveMaskTexture(mask)
    for i = #self.masks, 1, -1 do
        if self.masks[i] == mask then table.remove(self.masks, i) end
    end
end
local function pool(parent, reset)
    local inactive = {}
    return {
        Acquire = function()
            local item = table.remove(inactive)
            if item then return item, false end
            return object(parent), true
        end,
        Release = function(self, item)
            reset(self, item)
            inactive[#inactive + 1] = item
        end,
    }
end
UIParent = object()
UIParent.shown = true
CreateFramePool = function(_, parent, _, reset) return pool(parent, reset) end
CreateTexturePool = function(parent, _, _, _, reset) return pool(parent, reset) end
AnimateTexCoords = noop
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
min, tinsert, tremove = math.min, table.insert, table.remove
local lib = {}
LibStub = setmetatable({ NewLibrary = function() return lib end }, { __call = function() end })
dofile(arg[1] or "libs/LibCustomGlow-1.0/LibCustomGlow-1.0.lua")
local checks = 0
local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 0.000001, label .. ": expected " .. expected .. ", got " .. actual)
    checks = checks + 1
end
local function host(explicit)
    local frame = object(UIParent)
    frame:SetSize(48, 36)
    frame:Show()
    if explicit then
        frame.secret = true
        frame._quiGlowSize = { width = 48, height = 36 }
    end
    return frame
end
local color = { 0.8, 0.2, 0.2, 1 }
local button = host(true)
lib.ButtonGlow_Start(button, color, 1)
local glow = assert(button._ButtonGlow)
near(glow.width, 48 * 1.4, "button start width")
near(glow.spark.width, 48 * 1.4, "button animation width")
near(glow.innerGlow.height, 36 * 0.7, "button animation height")
glow.animIn.scripts.OnFinished(glow.animIn)
near(glow.outerGlow.width, 48 * 1.4, "button animation completion")
button._quiGlowSize.width, button._quiGlowSize.height = 60, 40
glow.animIn.scripts.OnPlay(glow.animIn)
near(glow.spark.width, 60 + 48 * 0.4, "button resize preserves anchor padding")
glow.animIn.scripts.OnFinished(glow.animIn)
near(glow.outerGlow.height, 40 + 36 * 0.4, "button finish reads resized geometry")
lib.ButtonGlow_Start(button, color, 1)
assert(button._ButtonGlow == glow, "button reused")
near(glow.width, 84, "button reuse width")
near(glow.ants.height, 40 * 1.4 * 0.85, "button reuse ants")
glow.animOut:Play()
lib.ButtonGlow_Start(button, color, 1)
assert(glow.animIn:IsPlaying() and not glow.animOut:IsPlaying(), "button fade interrupted")
near(glow.spark.width, 84, "button restart animation")
lib.ButtonGlow_Stop(button)
assert(button._ButtonGlow == nil, "button released")
local plainButton = host(false)
lib.ButtonGlow_Start(plainButton, color, 1)
assert(plainButton._ButtonGlow == glow, "button pool reused")
near(glow.width, 48 * 1.4, "button pool clears explicit size")
near(glow.spark.height, 36 * 1.4, "plain animation reads actual size")

local pixel = host(true)
lib.PixelGlow_Start(pixel, color, 8, 0.5, nil, 2, 3, 4, true, "test")
local pixelGlow = assert(pixel._PixelGlowtest)
near(pixelGlow.info.width, 48 + 6 - 0.05, "pixel offset width")
near(pixelGlow.info.height, 36 + 8, "pixel offset height")
pixel._quiGlowSize.width, pixel._quiGlowSize.height = 60, 40
pixelGlow.scripts.OnUpdate(pixelGlow, 0.1)
near(pixelGlow.info.width, 60 + 6 - 0.05, "pixel mutable width")
near(pixelGlow.info.height, 48, "pixel mutable height")
lib.PixelGlow_Start(pixel, color, 8, 0.5, nil, 2, 1, 2, true, "test")
assert(pixel._PixelGlowtest == pixelGlow, "pixel reused")
near(pixelGlow.info.width, 60 + 2 - 0.05, "pixel reuse offsets")
lib.PixelGlow_Stop(pixel, "test")
local plainPixel = host(false)
lib.PixelGlow_Start(plainPixel, color, 8, 0.5, nil, 2, 0, 0, true, "plain")
assert(plainPixel._PixelGlowplain == pixelGlow, "pixel pool reused")
near(pixelGlow.info.width, 48 - 0.05, "pixel pool clears explicit size")

local autocast = host(true)
lib.AutoCastGlow_Start(autocast, color, 4, 0.5, 1, 2, 3, "test")
local autoGlow = assert(autocast._AutoCastGlowtest)
near(autoGlow.info.width, 48 + 4 - 0.05, "autocast offset width")
near(autoGlow.info.height, 42, "autocast offset height")
autocast._quiGlowSize.width, autocast._quiGlowSize.height = 60, 40
autoGlow.scripts.OnUpdate(autoGlow, 0.1)
near(autoGlow.info.width, 60 + 4 - 0.05, "autocast mutable width")
lib.AutoCastGlow_Start(autocast, color, 4, 0.5, 1, 0, 0, "test")
assert(autocast._AutoCastGlowtest == autoGlow, "autocast reused")
near(autoGlow.info.height, 40, "autocast reuse offsets")
lib.AutoCastGlow_Stop(autocast, "test")
local plainAuto = host(false)
lib.AutoCastGlow_Start(plainAuto, color, 4, 0.5, 1, 0, 0, "plain")
assert(plainAuto._AutoCastGlowplain == autoGlow, "autocast pool reused")
near(autoGlow.info.height, 36, "autocast pool clears explicit size")

local proc = host(true)
local options = { key = "test", color = color, xOffset = 3, yOffset = 4, startAnim = true }
lib.ProcGlow_Start(proc, options)
local procGlow = assert(proc._ProcGlowtest)
near(procGlow.ProcStart.width, (48 * 1.4 + 6) / 42 * 150 / 1.4, "proc start width")
near(procGlow.ProcStart.height, (36 * 1.4 + 8) / 42 * 150 / 1.4, "proc start height")
proc._quiGlowSize.width, proc._quiGlowSize.height = 60, 40
procGlow:Hide()
procGlow:Show()
near(procGlow.ProcStart.width, (60 + 48 * 0.4 + 6) / 42 * 150 / 1.4,
    "proc show preserves anchor padding")
procGlow:Hide()
lib.ProcGlow_Start(proc, options)
assert(proc._ProcGlowtest == procGlow, "proc reused")
near(procGlow.ProcStart.width, (60 * 1.4 + 6) / 42 * 150 / 1.4, "proc mutable width")
lib.ProcGlow_Stop(proc, "test")
local plainProc = host(false)
lib.ProcGlow_Start(plainProc, { key = "plain", color = color, startAnim = true })
assert(plainProc._ProcGlowplain == procGlow, "proc pool reused")
near(procGlow.ProcStart.width, 48 / 42 * 150, "proc pool clears explicit size")
assert(secretReads == 0, "explicit geometry never reads secret dimensions")
print("libcustomglow_explicit_size_test: " .. checks .. " geometry checks passed")
