local function read(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local function noop() end
local function forbidden() error("native geometry is secret") end
local secret = setmetatable({}, { __add = forbidden, __sub = forbidden, __mul = forbidden })
function CreateFrame(_, _, parent)
    return {
        parent = parent,
        SetAllPoints = function(self, target) self.anchor = target end,
        GetSize = function() return secret, secret end,
        ClearAllPoints = noop, SetPoint = noop, SetAlpha = noop,
    }
end

local ns = {}
assert(loadfile(arg[1] or "QUI_CDM/cdm/cdm_reanchor.lua"))("QUI", ns)
local bridge = ns.CDMReanchor.New()
ns._cdmBoot = { bridge = bridge }
local source = read(arg[2] or "QUI_CDM/cdm/cdm_containers.lua")
local first = assert(source:find("local _reanchorGlowOverlays =", 1, true))
local last = assert(source:find("ns._CDMEnsureReanchorGlowOverlay = EnsureReanchorGlowOverlay", first, true))
local chunk = source:sub(first, last - 1)
local ensure = assert(loadstring("local ns = ...\n" .. chunk .. "\nreturn EnsureReanchorGlowOverlay"))(ns)
local frame, container = CreateFrame(), CreateFrame()
bridge:OverlayRect(frame, container, "CENTER", -24, 18, "CENTER", 24, -18)
local overlay = assert(ensure(frame))
assert(overlay.parent == frame and overlay.anchor == frame,
    "glow must follow native icon position and visibility")
local size = assert(overlay._quiGlowSize, "native glow must use the layout rectangle instead of secret GetSize")
assert(size.width == 48 and size.height == 36, "glow must match the non-square layout rectangle")
local centered = CreateFrame()
bridge:OverlayRect(frame, centered, "LEFT", 3, 14, "LEFT", 65, -14)
assert(ensure(frame) == overlay and overlay._quiGlowSize == size,
    "a running glow must keep its shared dimensions when moved into a centered aura row")
assert(size.width == 62 and size.height == 28, "running glow dimensions must track resized placements")
bridge:Sink(frame, true)
bridge:OverlayRect(frame, container, "CENTER", -20, 20, "CENTER", 20, -20)
assert(ensure(frame) == overlay and size.width == 40 and size.height == 40,
    "a reused native frame must replace its previous spell's layout dimensions")
assert(ensure(CreateFrame()) == nil, "an unpositioned frame must not start a glow with secret geometry")
print("OK: cdm_reanchor_glow_size_test")
