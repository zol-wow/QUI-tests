-- Runtime fixture with an engine-owned aura slot and restricted-art writes.
-- It verifies the addon boundary, not Blizzard's rendering implementation.
return function(options)
    options = options or {}
    local H = { now = 10, combat = false, secretAuras = false, frames = {}, timers = {},
        cooldowns = {}, sounds = {}, speech = {}, auraSounds = {}, classID = 5, specID = 257,
        units = { player = { name = "Priest", guid = "p", role = "HEALER" },
            party1 = { name = "Mage", guid = "m", role = "DAMAGER" },
            party2 = { name = "Healer", guid = "h", role = "HEALER" } } }
    local methods = {}
    local function writable(self)
        assert(not (H.secretAuras and self.auraSubtree), "addon wrote restricted aura artwork")
    end
    local function Node(kind, parent)
        local node = setmetatable({ kind = kind, parent = parent, children = {}, scripts = {}, events = {},
            shown = true, width = 48, height = 48, level = 1, points = {},
            auraSubtree = kind == "AuraButton" or parent and parent.auraSubtree }, { __index = methods })
        if parent then parent.children[#parent.children + 1] = node end
        H.frames[#H.frames + 1] = node
        return node
    end
    function methods:SetSize(w, h) writable(self); assert(type(w) == "number" and type(h) == "number"); self.width, self.height = w, h end
    function methods:SetWidth(w) writable(self); self.width = w end
    function methods:SetHeight(h) writable(self); self.height = h end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height end
    function methods:GetCenter() return 500, 400 end
    function methods:GetObjectType() return self.kind end
    function methods:GetFrameLevel() return self.level end
    function methods:GetChildren() return unpack(self.children) end
    function methods:GetAttribute(key) return self[key] end
    function methods:IsForbidden() return false end
    function methods:SetScript(key, fn) writable(self); self.scripts[key] = fn end
    function methods:HookScript(key, fn) self:SetScript(key, fn) end
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:RegisterUnitEvent(event, unit) self.events[event] = unit end
    function methods:UnregisterEvent(event) self.events[event] = nil end
    function methods:SetPoint(...) writable(self); self.points[#self.points + 1] = { ... } end
    function methods:ClearAllPoints() writable(self); self.points = {} end
    function methods:SetAllPoints(target) writable(self); self.anchor = target end
    function methods:SetFont(font, size, flags)
        writable(self)
        self.font, self.fontSize, self.fontFlags = font, size, flags
        return true
    end
    function methods:SetText(text)
        writable(self)
        assert(self.kind ~= "FontString" or self.font, "FontString:SetText(): Font not set")
        self.text = text
    end
    function methods:SetAlpha(alpha) writable(self); self.alpha = alpha end
    function methods:Show() writable(self); self.shown = true end
    function methods:Hide() writable(self); self.shown = false end
    function methods:SetShown(value) writable(self); self.shown = value end
    function methods:IsShown() return self.shown end
    function methods:CreateTexture() return Node("Texture", self) end
    function methods:CreateFontString() return Node("FontString", self) end
    function methods:CreateAnimationGroup() return Node("AnimationGroup", self) end
    function methods:CreateAnimation(kind) return Node(kind, self) end
    function methods:SetEnabled(value) self.enabled = value end
    function methods:SetUnit(unit) if self.enabled then self.boundUnit = unit end end
    function methods:SetAuraSlotCandidateFilters(_, filters) self.filters = filters end
    function methods:AddAuraSlot(_, _, options)
        assert(not H.combat, "new slot during combat")
        self.filters = options.candidateFilters
        self.slot = Node("AuraButton", self)
        options.initializeFrame(self.slot)
        return self.slot
    end
    function methods:SetDurationText(text) writable(self); self.durationText = text end
    function methods:ClearDurationText() writable(self); self.durationText = nil end
    function methods:SetDurationBar(bar) writable(self); self.durationBar = bar end
    function methods:ClearDurationBar() writable(self); self.durationBar = nil end
    function methods:SetCooldownFromDurationObject(duration) writable(self); self.duration = duration end
    for _, method in ipairs({ "SetFrameLevel", "SetFrameStrata", "SetMovable", "SetClampedToScreen", "SetMinMaxValues", "SetValue",
        "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "EnableMouse", "SetTexCoord", "SetTexture", "SetAtlas",
        "SetDesaturated", "SetVertexColor", "SetColorTexture", "SetJustifyH", "SetTextColor", "SetDrawEdge", "SetLooping",
        "SetFromAlpha", "SetToAlpha", "SetDuration", "SetOffset", "SetScale", "SetDegrees", "SetFlipBookRows",
        "SetFlipBookColumns", "SetFlipBookFrames", "SetStatusBarTexture", "SetStatusBarColor", "Play", "Stop", "Clear" }) do
        methods[method] = function(self) writable(self) end
    end
    _G.UIParent = Node("Frame")
    _G.CreateFrame = function(kind, _, parent) return Node(kind, parent) end
    _G.GetTime = function() return H.now end
    _G.InCombatLockdown = function() return H.combat end
    _G.C_Secrets = { ShouldAurasBeSecret = function() return H.secretAuras end }
    _G.C_RestrictedActions = { IsAddOnRestrictionActive = function(kind)
        return kind == Enum.AddOnRestrictionType.Combat and H.combat or H.encounter == true
    end }
    local function Unit(unit) return H.units[unit == "focus" and H.focus or unit] end
    _G.UnitExists = function(unit) return Unit(unit) ~= nil end
    _G.UnitName = function(unit) local u = Unit(unit); return u and u.name, "Realm" end
    _G.UnitGUID = function(unit) local u = Unit(unit); return u and u.guid end
    _G.UnitClass = function() return "Priest", "PRIEST", H.classID end
    _G.UnitGroupRolesAssigned = function(unit) local u = Unit(unit); return u and u.role or "NONE" end
    _G.UnitIsUnit = function(a, b) return Unit(a) ~= nil and Unit(a) == Unit(b) end
    _G.UnitCanAssist = function(_, unit) local u = Unit(unit); return u ~= nil and u.friendly ~= false end
    _G.UnitIsPlayer = function(unit) local u = Unit(unit); return u ~= nil and u.isPlayer ~= false end
    _G.GetNormalizedRealmName = function() return "Realm" end
    _G.GetNumSubgroupMembers = function() return H.grouped == false and 0 or 2 end
    _G.GetNumGroupMembers = function() return 3 end
    _G.IsInGroup = function() return H.grouped ~= false end
    _G.IsInRaid = function() return H.raid == true end
    _G.IsInInstance = function() return H.instance ~= "none", H.instance or "party" end
    _G.C_Spell = {
        GetSpellInfo = function(id) return { name = "Spell " .. id, iconID = id } end,
        GetSpellTexture = function(id) return id end,
        GetSpellCooldown = function(id) return H.cooldowns[id] or { isActive = false, isEnabled = true, startTime = 0, duration = 0 } end,
        GetSpellCharges = function() return H.charges end,
        GetOverrideSpell = function(id) return H.override and H.override[id] or id end,
        GetSpellCooldownDuration = function() return { EvaluateRemainingDuration = function() return 0 end } end,
    }
    _G.C_SpellBook = { IsSpellKnown = function() return true end }
    _G.C_AddOns = { IsAddOnLoaded = function() return true end, LoadAddOn = function() end }
    _G.C_CurveUtil = { CreateCurve = function() return { SetType = function() end, AddPoint = function() end } end }
    _G.Enum = { LuaCurveType = { Step = 1 }, StatusBarTimerDirection = { RemainingTime = 1 },
        UnitAuraSoundTrigger = { Added = 0 },
        AddOnRestrictionType = { Combat = 0, Encounter = 1 } }
    _G.C_Timer = { NewTicker = function(_, fn)
        local timer = { callback = fn, Cancel = function(self) self.cancelled = true end }
        H.timers[#H.timers + 1] = timer
        return timer
    end }
    _G.PlaySoundFile = function(sound) H.sounds[#H.sounds + 1] = sound end
    _G.C_VoiceChat = { GetTtsVoices = function() return { { voiceID = 1, name = "Voice One" }, { voiceID = 2, name = "Voice Two" } } end,
        -- Match VoiceChatDocumentation: voiceID, text, rate, volume, overlap.
        -- There is no destination enum or destination argument in retail.
        SpeakText = function(voice, text, rate, volume, overlap)
            assert(type(voice) == "number" and type(text) == "string")
            assert(type(rate) == "number" and type(volume) == "number")
            assert(overlap == nil or type(overlap) == "boolean", "SpeakText overlap must be a boolean")
            H.voice, H.speechRate, H.speechVolume = voice, rate, volume
            H.speech[#H.speech + 1] = text
        end }
    _G.C_UnitAuras = {
        AddAuraSound = function(_, info)
            assert(not H.combat and not H.encounter, "aura sound registration is combat/encounter restricted")
            if H.blockSound then return nil end
            H.auraSounds[#H.auraSounds + 1] = info
            return #H.auraSounds
        end,
        RemoveAuraSound = function(id) H.auraSounds[id].removed = true end,
    }
    _G.LibStub = function() return setmetatable({}, { __index = function() return function() end end }) end
    local ns = { Helpers = { GetCurrentSpecID = function() return H.specID end,
        ApplyFontWithFallback = function(text, font, size, flags) return text:SetFont(font, size, flags) end,
        GetGeneralFont = function() return "font" end, GetCore = function() return { db = { profile = H.profile } } end },
        Registry = { Register = function(_, _, spec) H.profileRefresh = spec.refresh end },
        WhenLoggedIn = function(fn)
            H.login = fn
            if H.loggedIn then fn() end
        end }
    (dofile("tests/helpers/locale.lua"))(ns)
    H.db = { enabled = true, reminders = {} }
    H.profile = { spellReminders = H.db, frameAnchoring = {} }
    H.resolvers = {}
    ns.QUI_LayoutMode = {
        elements = {},
        RegisterElement = function(self, def) self.elements[def.key] = def end,
        UnregisterElement = function(self, key) self.elements[key] = nil end,
    }
    _G.QUI_RegisterFrameResolver = function(key, info) H.resolvers[key] = info.resolver end
    _G.QUI_UnregisterFrameResolver = function(key) H.resolvers[key] = nil end
    _G.QUI_HasFrameAnchor = function(key) return H.profile.frameAnchoring[key] ~= nil end
    _G.QUI_ApplyFrameAnchor = function(key)
        local frame = assert(H.resolvers[key], "register the resolver before applying its anchor")()
        local anchor = H.profile.frameAnchoring[key]
        frame:SetPoint("CENTER", UIParent, "CENTER", anchor.offsetX, anchor.offsetY)
    end
    ns.Helpers.GetModuleDB = function() return H.db end
    local cell = Node("Button", UIParent)
    cell.unit = "party1"
    H.cell = cell
    ns.QUI_GroupFrames = { unitFrameMap = { party1 = { cell } } }
    H.ns = ns
    function H.LoadRuntime()
        _G.QUI = _G.QUI or {}
        _G.QUI._ns = ns
        local addonNS = {}
        assert(loadfile("QUI_Reminders/bootstrap.lua"))("QUI_Reminders", addonNS)
        -- Follow the real module manifest, including its final initialization
        -- step, so tests catch ordering failures during load after login.
        for line in io.lines("QUI_Reminders/QUI_Reminders.toc") do
            local file = line:match("^(spell_reminders\\[%w_]+%.lua)$")
            if file then
                assert(loadfile("QUI_Reminders/" .. file:gsub("\\", "/")))("QUI_Reminders", addonNS)
            end
        end
        H.R, H.T = ns.SpellReminders, ns.SpellReminderTracking
    end
    function H.emit(event, ...)
        local listeners = {}
        for _, frame in ipairs(H.frames) do
            if frame.events[event] then listeners[#listeners + 1] = frame end
        end
        for _, frame in ipairs(listeners) do frame.scripts.OnEvent(frame, event, ...) end
    end
    if not options.deferRuntime then H.LoadRuntime() end
    return H
end
