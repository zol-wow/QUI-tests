local function forbidden() error("native aura state must not be queried by CDM") end
C_UnitAuras = setmetatable({}, { __index = forbidden })
AuraUtil = setmetatable({}, { __index = forbidden })
local inCombat, secretAuras = false, false
function InCombatLockdown() return inCombat end
function issecretvalue() return false end
C_Secrets = { ShouldAurasBeSecret = function() return secretAuras end }
local containers, buttons = {}, {}
local function Frame(parent)
    local frame = { parent = parent, shown = true, points = {}, attributes = {} }
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function frame:SetAllPoints(target) self.allPoints = target end
    function frame:SetSize(w, h) self.width, self.height = w, h end
    function frame:SetWidth(w) self.width = w end
    function frame:SetHeight(h) self.height = h end
    function frame:SetColorTexture(...) self.color = { ... } end
    function frame:SetVertexColor(...) self.vertexColor = { ... } end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:SetTexture(texture) self.texture = texture end
    function frame:SetAtlas(atlas) self.atlas = atlas end
    function frame:SetTexCoord(...) self.texCoord = { ... } end
    function frame:SetBlendMode(mode) self.blendMode = mode end
    function frame:SetAttribute(key, value) self.attributes[key] = value end
    function frame:GetAttribute(key) return self.attributes[key] end
    function frame:RegisterForClicks(...) self.clicks = { ... } end
    function frame:GetAnimationGroups() return unpack(self.animationGroups or {}) end
    function frame:GetChildren() end
    function frame:CreateAnimationGroup()
        self.animationGroups = self.animationGroups or {}
        local group = { animations = {}, SetScript = forbidden, HookScript = forbidden }
        function group:Stop() self.playing = false end
        function group:RemoveAnimations() self.animations = {} end
        function group:SetLooping(looping) self.looping = looping end
        function group:Play(reverse, offset) self.playing, self.reverse, self.offset = true, reverse, offset end
        function group:CreateAnimation(kind)
            local anim = { kind = kind, controls = {}, SetScript = forbidden, HookScript = forbidden }
            self.animations[#self.animations + 1] = anim
            function anim:SetTarget(target) self.target = target end
            function anim:SetDuration(duration) self.duration = duration end
            function anim:SetCurveType(curve) self.curve = curve end
            function anim:SetFlipBookRows(rows) self.rows = rows end
            function anim:SetFlipBookColumns(columns) self.columns = columns end
            function anim:SetFlipBookFrames(frames) self.frames = frames end
            function anim:SetFlipBookFrameWidth(width) self.frameWidth = width end
            function anim:SetFlipBookFrameHeight(height) self.frameHeight = height end
            function anim:CreateControlPoint(_, _, order)
                local point = {}
                self.controls[order] = point
                function point:SetOffset(x, y) self.x, self.y = x, y end
                return point
            end
            return anim
        end
        self.animationGroups[#self.animationGroups + 1] = group
        return group
    end
    function frame:SetFrameLevel(level) self.level = level end
    function frame:GetFrameLevel() return self.level or 1 end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:CreateTexture() return Frame(self) end
    function frame:EnableMouse(enabled) self.mouse = enabled end
    function frame:SetMouseClickEnabled(enabled) self.click = enabled end
    function frame:SetMouseMotionEnabled(enabled) self.motion = enabled end
    frame.IsShown, frame.IsVisible, frame.SetScript, frame.HookScript = forbidden, forbidden, forbidden, forbidden
    return frame
end
function CreateFrame(kind, _, parent, template)
    local frame = Frame(parent)
    frame.template = template
    if kind == "AuraContainer" then
        containers[#containers + 1] = frame
        frame.slots, frame.groups = {}, {}
        function frame:SetUnit(unit) self.unit = unit end
        function frame:SetEnabled(enabled) self.enabled = enabled end
        function frame:AddAuraSlot(key, filter, options)
            local button = Frame(self)
            button.key, button.filter, button.options = key, filter, options
            self.slots[key] = button
            buttons[#buttons + 1] = button
            options.initializeFrame(button)
            button.shown = false
            return button
        end
        function frame:SetAuraSlotFilterString(key, filter) self.slots[key].filter = filter end
        function frame:SetAuraSlotCandidateFilters(key, filters) self.slots[key].options.candidateFilters = filters end
        function frame:HasAuraGroup(key) return self.groups[key] ~= nil end
        function frame:AddAuraGroup(key, filter, options)
            self.groups[key] = self:AddAuraSlot(key, filter, options)
        end
    end
    return frame
end
local ns = {
    Helpers = {},
    Addon = { db = { profile = { ncdm = {}, customGlow = {} } }, AuraSkin = {
        WireButton = function(button, profile) button.profile = profile end,
        Configure = function(container, profile, groups)
            container._quiProfile, container.configuredGroups = profile, groups
        end,
    } },
    CDMSpellData = { IsSelfAuraSpell = function() end },
    CDMSources = {
        QueryInventoryItemID = function(_, slot) return slot == 13 and 9000 or 9001 end,
        GetItemAuraSpellIDs = function(itemID)
            if itemID == 9000 then return { 11000, 11001 } end
            if itemID == 9001 then return { 12000 } end
            return {}
        end,
    },
    _OwnedGlows = { ResolveGlowForEntry = function()
        return { glowType = "Proc Glow", color = { 0.9, 0.8, 0.7, 1 }, frequency = 0.25 }
    end },
    _OwnedSwipe = { GetSettings = function() return { showCooldownIconAuraPhase = true } end },
    AuraGlue = setmetatable({}, { __index = forbidden }),
}
assert(loadfile("QUI_CDM/cdm/cdm_layout.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_managed_aura_mirrors.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_custom_aura_runs.lua"))("QUI", ns)
local Runs = ns.CDMCustomAuraRuns
local owner, icon = Frame(), Frame()
icon._spellEntry = { type = "spell", id = 1307927, kind = "aura", _useManagedAura = true,
    _managedAuraRoute = "player:HELPFUL", viewerType = "custom" }
icon.clickButton = Frame(icon)
icon.clickButton:SetAttribute("type", "spell")
icon.clickButton:SetAttribute("spell", 1307927)
local row = { size = 30, padding = 2 }
local plan = { metrics = { iconWidth = 30 }, placements = { { icon = icon, rowConfig = row, x = 0, y = 0 } } }
local settings = { containerType = "customBar", row1 = { iconCount = 1 },
    entries = { icon._spellEntry }, activeGlowEnabled = true, activeGlowColor = { 0.2, 0.3, 0.4, 0.5 },
    activeGlowThickness = 3, clickableIcons = true }
assert(Runs.Apply(owner, settings, plan, { icon }, false, "custom"))
local button = buttons[1]
assert(containers[1].unit == "player" and button.filter == "HELPFUL")
assert(button.options.candidateFilters.includeSpellIDs[1307927])
assert(icon.shown and icon._quiManagedAuraProxy == nil and icon._customAuraOverlayPrepared)
assert(button.motion == true and button.click == true)
assert(button.options.templateNames[1] == "SecureActionButtonTemplate")
assert(button:GetAttribute("type") == "spell" and button:GetAttribute("spell") == 1307927)
assert(button.clicks[1] == "AnyUp" and button.clicks[2] == "AnyDown")
assert(button.profile.pandemicGlow and #button._quiCDMNativeGlow == 24)
local nativeGlow = button._quiCDMNativeGlow[1]
assert(nativeGlow.texture.height == 3 and nativeGlow.texture.vertexColor[4] == 0.5)
assert(nativeGlow.group.looping == "REPEAT" and nativeGlow.group.playing)
assert(button._quiCDMNativeEffectHost.template == "AnimateWhileShownTemplate")
assert(nativeGlow.group.animations[1].target == nativeGlow.texture)
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_SharedXML/AnimationTemplates.lua"))()
_G.AnimateWhileShownMixin.StopAnims(button._quiCDMNativeEffectHost)
assert(not nativeGlow.group.playing)
_G.AnimateWhileShownMixin.PlayAnims(button._quiCDMNativeEffectHost)
assert(nativeGlow.group.playing, "trusted Blizzard OnShow restarts native glow after aura loss/reapplication")
assert(nativeGlow.group.animations[1].kind == "Path" and nativeGlow.group.animations[1].duration == 4)
local procGlow = button._quiCDMNativeProcGlow[1]
assert(procGlow.texture.alpha == 0 and procGlow.group.playing)
Runs.SetNativeProcGlow(icon, true)
assert(procGlow.texture.alpha == 1 and nativeGlow.texture.alpha == 1)
Runs.SetNativeProcGlow(icon, false)
assert(procGlow.texture.alpha == 0 and nativeGlow.texture.alpha == 1,
    "clean proc state must control its native layer independently of active-aura glow")
button.shown = true
assert(button.parent.shown and icon.shown, "native aura and inactive base have independent visibility")
button.shown = false
assert(icon.shown, "aura loss must leave the configured inactive placeholder")
settings.activeGlowEnabled = false
assert(Runs.Apply(owner, settings, plan, { icon }, false, "custom"))
assert(nativeGlow.texture.alpha == 0 and not nativeGlow.group.playing, "disabling active glow stops native animations")
settings.activeGlowEnabled = true
settings.spellOverrides = { [1307927] = { glowEnabled = false } }
assert(Runs.Apply(owner, settings, plan, { icon }, false, "custom"))
assert(nativeGlow.texture.alpha == 0, "per-entry glow suppression must override active glow")
settings.spellOverrides[1307927] = { glowColor = { 0.7, 0.6, 0.5, 0.4 } }
settings.activeGlowType, settings.activeGlowFrequency = "Proc Glow", 0.5
assert(Runs.Apply(owner, settings, plan, { icon }, false, "custom"))
assert(nativeGlow.texture.vertexColor[1] == 0.7 and nativeGlow.texture.vertexColor[4] == 0.4)
assert(nativeGlow.texture.atlas == "UI-HUD-ActionBar-Proc-Loop-Flipbook")
assert(nativeGlow.group.animations[1].kind == "FlipBook" and nativeGlow.group.animations[1].duration == 0.5)
assert(nativeGlow.group.animations[1].frames == 30 and nativeGlow.group.animations[1].rows == 6)
settings.activeGlowType, settings.activeGlowScale, settings.activeGlowLines = "Autocast Shine", 2, 4
assert(Runs.Apply(owner, settings, plan, { icon }, false, "custom"))
assert(nativeGlow.texture.width == 14 and nativeGlow.texture.blendMode == "ADD")
assert(button._quiCDMNativeGlow[16].group.playing and not button._quiCDMNativeGlow[17].group.playing)
icon.clickButton:SetAttribute("type", "macro")
icon.clickButton:SetAttribute("spell", nil)
icon.clickButton:SetAttribute("macro", "Voidstep")
assert(Runs.Apply(owner, settings, plan, { icon }, false, "custom"))
assert(button:GetAttribute("type") == "macro" and button:GetAttribute("macro") == "Voidstep")
assert(button:GetAttribute("spell") == nil, "native click refresh must clear stale spell attributes")
icon:Hide()
assert(button.click and button.parent.shown, "active native click must survive hiding inactive base")
icon:Show()
settings.activeGlowEnabled = false
local clickRendererFile = assert(io.open("QUI_CDM/cdm/cdm_icon_renderer.lua", "r"))
local clickRendererSource = clickRendererFile:read("*a")
clickRendererFile:close()
local clickBody = assert(clickRendererSource:match(
    "UpdateIconSecureAttributes = function%b()(.-)\nend\n\nfunction CDMIcons.UpdateSecureClickOverlay"))
local prepareChunk = assert(loadstring("return function(icon, entry, viewerType)" .. clickBody .. "\nend"))
local macroForSpell
setfenv(prepareChunk, setmetatable({
    GetTrackerSettings = function() return settings end,
    EnsureClickButton = function(base) return base.clickButton end,
    ClearClickButtonAttributes = function(base)
        for _, key in ipairs({ "type", "spell", "item", "macro" }) do base:SetAttribute(key, nil) end
    end,
    FindMacroForSpell = function() return macroForSpell end,
    GetItemIDForEntry = function(entry) return entry.id end,
    Sources = {
        QueryItemNameByID = function(id) return id == 9000 and "Usable Trinket" end,
        QuerySpellInfo = function() return { name = "Venomcursed Haste" } end,
    },
}, { __index = _G }))
local prepare = prepareChunk()
prepare(icon, { type = "spell", spellID = 1307927 }, "custom")
Runs.ConfigureNativeClick(button, icon.clickButton)
assert(button:GetAttribute("type") == "spell" and button:GetAttribute("spell") == "Venomcursed Haste")
macroForSpell = "Venom Macro"
prepare(icon, { type = "spell", spellID = 1307927 }, "custom")
Runs.ConfigureNativeClick(button, icon.clickButton)
assert(button:GetAttribute("type") == "macro" and button:GetAttribute("macro") == "Venom Macro")
prepare(icon, { type = "item", id = 9000 }, "custom")
Runs.ConfigureNativeClick(button, icon.clickButton)
assert(button:GetAttribute("type") == "item" and button:GetAttribute("item") == "Usable Trinket")
settings.clickableIcons = false
prepare(icon, { type = "item", id = 9000 }, "custom")
Runs.ConfigureNativeClick(button, icon.clickButton)
assert(button:GetAttribute("type") == nil and not button.click, "disabling clicks must clear native cast bindings")
settings.clickableIcons = true
for _, field in ipairs({ "dynamicLayout", "showOnlyWhenActive", "showOnlyOnCooldown", "showOnlyInCombat", "hideNonUsable" }) do
    settings[field] = true
    assert(Runs.Apply(owner, settings, plan, { icon }, false, "custom"), field .. " must retain native aura tracking")
    settings[field] = nil
end
local candidates = ns.CDMManagedAuraMirrors.ResolveCandidateIDs({ type = "trinket", id = 13 })
assert(#candidates == 2 and candidates[1] == 11000 and candidates[2] == 11001)
for _, id in ipairs(candidates) do assert(id ~= 13 and id ~= 9000, "slot/item IDs are not aura spell IDs") end
icon._spellEntry = { type = "item", id = 9000, kind = "cooldown", _isCustomEntry = true }
settings.entries, settings.iconDisplayMode = { icon._spellEntry }, "always"
assert(Runs.Apply(owner, settings, plan, { icon }, false, "custom"), "item cooldowns must retain native aura overlays")
local count = #buttons
inCombat = true
assert(Runs.Apply(owner, settings, nil, nil, true, "custom"))
assert(#buttons == count, "combat updates cannot create native buttons")
inCombat, secretAuras = false, true
assert(Runs.Apply(owner, settings, nil, nil, false, "custom"))
assert(#buttons == count, "out-of-combat aura restrictions also prevent native restyling")
secretAuras = false
local icons, placements = {}, {}
local rows = { { size = 30, padding = 2 }, { size = 24, padding = 3 } }
for i = 1, 4 do
    local entry = { id = 1307926 + i, kind = "aura", _useManagedAura = true, _managedAuraRoute = "player:HELPFUL" }
    icons[i] = Frame()
    icons[i]._spellEntry = entry
    placements[i] = { icon = icons[i], rowConfig = rows[i < 3 and 1 or 2], x = (i % 2) * 32, y = i < 3 and 0 or -35 }
end
local multi = { containerType = "customBar", dynamicLayout = true, showOnlyWhenActive = true,
    row1 = { iconCount = 2 }, row2 = { iconCount = 2 }, activeGlowEnabled = false }
local multiOwner = Frame()
assert(Runs.Apply(multiOwner, multi, { placements = placements }, icons, false, "custom"))
assert(#multiOwner._quiCDMAuraRunRecords == 2, "native dynamic runs must split at configured row boundaries")
assert(#multiOwner._quiCDMAuraRunRecords[1].groups == 2 and #multiOwner._quiCDMAuraRunRecords[2].groups == 2)
assert(multiOwner._quiCDMAuraRunRecords[2].container.points[1][2] == multiOwner,
    "each configured row must anchor independently")
multi.layoutDirection = "VERTICAL"
assert(Runs.Apply(multiOwner, multi, { placements = placements }, icons, false, "custom"))
assert(multiOwner._quiCDMAuraRunRecords[1].profile.grow == "DOWN")
local rendererFile = assert(io.open("QUI_CDM/cdm/cdm_icon_renderer.lua", "r"))
local rendererSource = rendererFile:read("*a")
rendererFile:close()
local visibilitySource = assert(rendererSource:match(
    "local function UpdateCooldownContainerVisibility%b()(.-)\nend"))
local hiddenOverride = true
local visibilityChunk = assert(loadstring(
    "return function(icon, entry, containerDB, editMode, inCombat)" .. visibilitySource .. "\nend"))
setfenv(visibilityChunk, setmetatable({
    GetIconSpellOverride = function() return { hidden = hiddenOverride } end,
    SyncCooldownBling = function() end,
}, { __index = _G }))
local updateVisibility = visibilityChunk()
local placeholder = Frame()
placeholder.IsShown = function(self) return self.shown end
local managedEntry = { _useManagedAura = true }
updateVisibility(placeholder, managedEntry, { iconDisplayMode = "always" }, false, false)
assert(placeholder.shown == false, "hidden override must beat managed always-visible placeholder")
hiddenOverride = false
updateVisibility(placeholder, managedEntry, { iconDisplayMode = "always" }, false, false)
assert(placeholder.shown == true, "clearing hidden override restores the inactive placeholder")
updateVisibility(placeholder, managedEntry, { iconDisplayMode = "active" }, false, false)
assert(placeholder.shown == false, "active-only mode must leave visibility to the native aura")
placeholder._quiManagedAuraProxy = true
updateVisibility(placeholder, managedEntry, { iconDisplayMode = "always" }, false, false)
assert(placeholder.shown == false, "packed native runs must never show the base placeholder")

print("OK: cdm_custom_aura_native_slots_test")
