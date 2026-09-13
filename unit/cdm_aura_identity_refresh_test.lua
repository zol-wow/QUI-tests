local function noop() end
function CreateFromMixins(...)
    local result = {}
    for i = 1, select("#", ...) do
        for key, value in pairs(select(i, ...) or {}) do result[key] = value end
    end
    return result
end
bit = { lshift = function(value, shift) return value * 2 ^ shift end }
function Flags_CreateMask(...)
    local result = 0
    for i = 1, select("#", ...) do result = result + select(i, ...) end
    return result
end
function Flags_CreateMaskFromTable(values)
    local result = 0
    for _, value in pairs(values) do result = result + value end
    return result
end
function InCombatLockdown() return false end
function issecretvalue() return false end

local native = "tests/framexml/Interface/AddOns/Blizzard_AuraContainer/"
assert(loadfile(native .. "Blizzard_AuraContainer.lua"))()
assert(loadfile(native .. "Blizzard_ManagedAuraContainer.lua"))()

local current = { target = 10, focus = 20, player = 30 }
local containers = {}
local function Frame()
    return {
        SetSize = noop, ClearAllPoints = noop, SetPoint = noop, SetAllPoints = noop,
        Show = noop, Hide = noop, SetFrameLevel = noop, EnableMouse = noop,
        SetMouseClickEnabled = noop, SetMouseMotionEnabled = noop,
        GetFrameLevel = function() return 1 end,
    }
end
function CreateFrame(kind)
    local frame = Frame()
    if kind ~= "AuraContainer" then return frame end
    for key, value in pairs(_G.ManagedAuraContainerPrivateMixin) do frame[key] = value end
    frame.slots, frame.aurasByInstanceID, frame.auraParseFilters = {}, {}, {}
    frame.UpdateEventRegistrations, frame.RefreshItemEnchantments = noop, noop
    frame.itemEnchantmentManager = {ClearActiveItemEnchantments = noop}
    frame.ProcessItemEnchantmentRefreshResult = noop
    frame.MarkDirty = function(self) self.dirty = true end
    frame.auraGroupManager = { ClearAllAuras = noop }
    frame.auraSlotManager = {
        ClearAuraSlotCandidates = function()
            for _, slot in pairs(frame.slots) do slot.auraInstanceID = nil end
        end,
        ProcessParsedAura = function(_, slot, _, aura)
            if slot.options.candidateFilters.includeSpellIDs[aura.spellId] then
                slot.auraInstanceID = aura.auraInstanceID
            end
        end,
    }
    frame.GetAuraSources = function()
        return {{
            GetAllAuraInstanceIDs = function(_, unit) return {current[unit]}, true end,
            GetAuraDataByAuraInstanceID = function(_, _, id)
                return {auraInstanceID = id, spellId = 257284}
            end,
            ApplySourceMetadata = noop,
        }}
    end
    function frame:AddAuraSlot(key, filter, options)
        local slot = Frame()
        slot.options = options
        self.slots[key] = slot
        self.auraParseFilters[#self.auraParseFilters + 1] = {
            filterString = filter,
            registrants = {{manager = self.auraSlotManager, consumer = slot}},
        }
        options.initializeFrame(slot)
        self:UpdateAllAuras()
        return slot
    end
    function frame:SetAuraSlotFilterString() end
    function frame:SetAuraSlotCandidateFilters(key, filters)
        self.slots[key].options.candidateFilters = filters
        self:UpdateAllAuras()
    end
    function frame:Flush()
        if self.dirty then self:ParseAllAuras(); self.dirty = false end
    end
    containers[#containers + 1] = frame
    return frame
end

local ns = {}
assert(loadfile("QUI_CDM/cdm/cdm_managed_aura_mirrors.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_custom_aura_runs.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_icon_runtime_refresh.lua"))("QUI", ns)
local settings = {containerType = "customBar", row1 = {iconCount = 1}}
for _, unit in ipairs({"target", "focus", "player"}) do
    local icon = Frame()
    icon._spellEntry = {
        id = 257284, type = "spell", kind = "aura", auraUnit = unit,
        auraFilter = "HARMFUL", _useManagedAura = true, _managedAuraRoute = unit .. ":HARMFUL",
    }
    assert(ns.CDMCustomAuraRuns.Apply(Frame(), settings, {
        placements = {{icon = icon, rowConfig = {size = 30}, x = 0, y = 0}},
    }, nil, false, "custom"))
end
local rangeRefreshes = 0
local controller = ns.CDMIconRuntimeRefresh.Create({
    refreshCustomAuraTargets = ns.CDMCustomAuraRuns.RefreshTargets,
    updateAllIconRanges = function() rangeRefreshes = rangeRefreshes + 1 end,
})
local failures = 0
for _, container in ipairs(containers) do container:Flush() end
for _, case in ipairs({{"target", "PLAYER_TARGET_CHANGED"}, {"focus", "PLAYER_FOCUS_CHANGED"}}) do
    local unit, event = unpack(case)
    local expected = current[unit] + 1
    current[unit] = expected
    local previousRangeRefreshes = rangeRefreshes
    controller:Handle(event)
    if unit == "focus" then
        assert(rangeRefreshes == previousRangeRefreshes, "focus changes must not refresh target-based icon ranges")
    else
        assert(rangeRefreshes == previousRangeRefreshes + 1, "target changes must retain icon range refreshes")
    end
    for _, container in ipairs(containers) do
        if container:GetUnit() == unit then
            container:Flush()
            local _, slot = next(container.slots)
            if slot.auraInstanceID ~= expected then
                failures = failures + 1
                print("FAIL " .. event .. ": native slot retained old unit aura " .. tostring(slot.auraInstanceID))
            end
        else
            assert(not container.dirty, "identity refresh must leave unrelated units untouched")
        end
    end
end
assert(failures == 0, tostring(failures) .. " identity refresh failures")
print("OK cdm_aura_identity_refresh_test")
