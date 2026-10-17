-- tests/helpers/character_chrome_harness.lua
-- Headless harness for the Character window chrome owner. Builds a fresh
-- WoW widget stub set + a stub `ns`, then loads the REAL core/safecall.lua,
-- core/uikit.lua and modules/skinning/frames/character_chrome.lua (and,
-- optionally, modules/skinning/frames/character.lua) so tests drive the
-- production code paths rather than re-implementing them.
--
-- Every Build() call re-stubs the globals, so a test can exercise all four
-- ownership combinations by building one env per combination.
-- luacheck: globals CreateFrame C_Timer hooksecurefunc InCombatLockdown GetCursorPosition
-- luacheck: globals IsMouseButtonDown CreateColor STANDARD_TEXT_FONT UIParent C_Item ScrollUtil QUI
local Harness = {}

local unpack = table.unpack or unpack

local function CreateStateTable()
    local tbl = setmetatable({}, { __mode = "k" })
    local function get(key)
        local s = tbl[key]
        if not s then s = {}; tbl[key] = s end
        return s
    end
    return tbl, get
end

-- Unknown widget METHODS are tolerated (no-op returning nil) so the stub
-- stays small; the methods tests assert on are implemented explicitly
-- below. Property-shaped keys (Border, Text, NineSlice, icon ...) stay nil so
-- production `if frame.Border then` guards behave like a real widget.
local METHOD_PREFIX = { "Set", "Get", "Is", "Enable", "Disable", "Register", "Unregister",
    "Clear", "Raise", "Lower", "Adjust", "Can", "Has", "Show", "Hide", "Start", "Stop", "Click" }
local function LooksLikeMethod(key)
    for _, prefix in ipairs(METHOD_PREFIX) do
        if key:sub(1, #prefix) == prefix then return true end
    end
    return false
end
local function Permissive(tbl)
    return setmetatable(tbl, {
        __index = function(_, key)
            if type(key) == "string" and LooksLikeMethod(key) then
                return function() return nil end
            end
            return nil
        end,
    })
end

function Harness.Build(opts)
    opts = opts or {}
    local env = { frames = {}, textures = {}, timers = {}, accentListeners = {}, createCount = 0 }

    local function NewTexture(parent, kind, layer)
        local t = { kind = kind or "Texture", parent = parent, layer = layer, alpha = 1, shown = true, points = {} }
        function t:SetAllPoints() self.allPoints = true end
        function t:SetPoint(...) self.points[#self.points + 1] = { ... } end
        function t:ClearAllPoints() self.points = {} end
        function t:GetPoint(i) local p = self.points[i or 1]; if p then return unpack(p) end end
        function t:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
        function t:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a } end
        function t:SetTexture(tex) self.texture = tex end
        function t:SetAtlas(atlas) self.atlas = atlas end
        function t:SetTexCoord(...) self.texCoord = { ... } end
        function t:SetAlpha(a) self.alpha = a end
        function t:GetAlpha() return self.alpha end
        function t:Show() self.shown = true end
        function t:Hide() self.shown = false end
        function t:IsShown() return self.shown end
        function t:SetShown(v) self.shown = v and true or false end
        function t:SetSize(w, h) self.width, self.height = w, h end
        function t:SetWidth(w) self.width = w end
        function t:SetHeight(h) self.height = h end
        function t:GetWidth() return self.width or 0 end
        function t:GetHeight() return self.height or 0 end
        function t:SetGradient(orientation, a, b) self.gradient = { orientation, a, b } end
        function t:IsObjectType(objType) return objType == self.kind end
        function t:GetObjectType() return self.kind end
        function t:GetParent() return self.parent end
        function t:SetFont(path, size, flags) self.font, self.fontSize, self.fontFlags = path, size, flags end
        function t:GetFont() return self.font, self.fontSize or 12, self.fontFlags end
        function t:SetText(text) self.text = text end
        function t:GetText() return self.text end
        function t:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
        function t:GetTextColor() if self.textColor then return unpack(self.textColor) end end
        function t:SetJustifyH(j) self.justifyH = j end
        function t:GetStringWidth() return 40 end
        env.textures[#env.textures + 1] = t
        return Permissive(t)
    end

    local function NewFrame(kind, name, parent, template)
        local f = {
            kind = kind or "Frame", name = name, parent = parent, template = template,
            scripts = {}, hooks = {}, shown = true, alpha = 1, level = 1, strata = "MEDIUM",
            width = 100, height = 100, points = {}, regions = {}, children = {}, id = 0,
            offset = 0, range = 0, backdropCalls = {}, enabled = true,
        }
        function f:SetScript(script, fn) self.scripts[script] = fn end
        function f:GetScript(script) return self.scripts[script] end
        function f:HookScript(script, fn)
            self.hooks[script] = self.hooks[script] or {}
            table.insert(self.hooks[script], fn)
        end
        function f:Fire(script, ...)
            if self.scripts[script] then self.scripts[script](self, ...) end
            for _, h in ipairs(self.hooks[script] or {}) do h(self, ...) end
        end
        function f:Show()
            local was = self.shown
            self.shown = true
            if not was then self:Fire("OnShow") end
        end
        function f:Hide()
            local was = self.shown
            self.shown = false
            if was then self:Fire("OnHide") end
        end
        function f:IsShown() return self.shown end
        function f:SetShown(v) if v then self:Show() else self:Hide() end end
        function f:SetAlpha(a) self.alpha = a end
        function f:GetAlpha() return self.alpha end
        function f:EnableMouse(v) self.mouse = v end
        function f:EnableMouseWheel(v) self.wheel = v end
        function f:SetMovable(v) self.movable = v end
        function f:RegisterForDrag() end
        function f:SetFrameStrata(s) self.strata = s end
        function f:GetFrameStrata() return self.strata end
        function f:SetFrameLevel(l) self.level = l end
        function f:GetFrameLevel() return self.level end
        function f:SetSize(w, h) self.width, self.height = w, h end
        function f:SetWidth(w) self.width = w end
        function f:SetHeight(h) self.height = h end
        function f:GetWidth() return self.width end
        function f:GetHeight() return self.height end
        function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
        function f:ClearAllPoints() self.points = {} end
        function f:SetAllPoints(target) self.allPoints = target or true end
        function f:GetPoint(i) local p = self.points[i or 1]; if p then return unpack(p) end end
        function f:GetNumPoints() return #self.points end
        function f:GetTop() return 200 end
        function f:GetBottom() return 100 end
        function f:GetEffectiveScale() return 1 end
        function f:GetScale() return 1 end
        function f:SetScale(s) self.scale = s end
        function f:CreateTexture(_, layer) local t = NewTexture(self, "Texture", layer); self.regions[#self.regions + 1] = t; return t end
        function f:CreateFontString(_, layer) local t = NewTexture(self, "FontString", layer); self.regions[#self.regions + 1] = t; return t end
        function f:GetRegions() return unpack(self.regions) end
        function f:GetNumRegions() return #self.regions end
        function f:GetChildren() return unpack(self.children) end
        function f:SetParent(p) self.parent = p end
        function f:GetParent() return self.parent end
        function f:SetID(v) self.id = v end
        function f:GetID() return self.id end
        function f:GetName() return self.name end
        function f:IsObjectType(objType) return objType == self.kind end
        function f:GetObjectType() return self.kind end
        function f:IsForbidden() return false end
        function f:SetBackdrop(info) self.backdropCalls[#self.backdropCalls + 1] = info; self.backdrop = info end
        function f:GetBackdrop() return self.backdrop end
        -- uikit's manual (4-texture) backdrop replaces these with setters
        -- that persist into _quiBg*/_quiBorder*; mirror that shape so
        -- env.BgColor/env.BorderColor read one place either way.
        function f:SetBackdropColor(r, g, b, a) self._quiBgR, self._quiBgG, self._quiBgB, self._quiBgA = r, g, b, a end
        function f:SetBackdropBorderColor(r, g, b, a) self._quiBorderR, self._quiBorderG, self._quiBorderB, self._quiBorderA = r, g, b, a end
        function f:GetNormalTexture() return self.normalTexture end
        function f:GetHighlightTexture() return self.highlightTexture end
        function f:GetPushedTexture() return nil end
        function f:GetDisabledTexture() return nil end
        function f:GetFontString() return self.Text end
        function f:IsEnabled() return self.enabled end
        function f:SetVerticalScroll(v) self.offset = v; self:Fire("OnVerticalScroll", v) end
        function f:GetVerticalScroll() return self.offset end
        function f:GetVerticalScrollRange() return self.range end
        function f:SetRange(r) self.range = r; self:Fire("OnScrollRangeChanged", 0, r) end
        function f:SetScrollChild(c) self.scrollChild = c end
        function f:GetScrollChild() return self.scrollChild end
        function f:StartMoving() self.moving = true end
        function f:StopMovingOrSizing() self.moving = false end
        function f:IsMouseOver() return false end
        function f:SetText(text) self.text = text end
        function f:GetText() return self.text end
        if parent and type(parent) == "table" and parent.children then
            parent.children[#parent.children + 1] = f
        end
        env.frames[#env.frames + 1] = f
        env.createCount = env.createCount + 1
        return Permissive(f)
    end

    env.NewTexture = NewTexture
    env.NewFrame = NewFrame

    -- Applied backdrop colours (nil until a backdrop colour was written).
    function env.BgColor(frame)
        if not frame or frame._quiBgR == nil then return nil end
        return { frame._quiBgR, frame._quiBgG, frame._quiBgB, frame._quiBgA }
    end
    function env.BorderColor(frame)
        if not frame or frame._quiBorderR == nil then return nil end
        return { frame._quiBorderR, frame._quiBorderG, frame._quiBorderB, frame._quiBorderA }
    end

    _G.CreateFrame = function(kind, name, parent, template)
        local frame = NewFrame(kind, name, parent, template)
        if name then _G[name] = frame end
        return frame
    end
    _G.C_Timer = { After = function(_, fn) env.timers[#env.timers + 1] = fn end }
    function env.RunTimers()
        local queue = env.timers
        env.timers = {}
        for _, fn in ipairs(queue) do fn() end
    end
    _G.hooksecurefunc = function(a, b, c)
        if type(a) == "string" then
            local name, fn = a, b
            local orig = _G[name]
            _G[name] = function(...)
                if orig then orig(...) end
                fn(...)
            end
            return
        end
        local tbl, name, fn = a, b, c
        local orig = tbl[name]
        tbl[name] = function(...)
            if orig then orig(...) end
            fn(...)
        end
    end
    _G.InCombatLockdown = function() return false end
    _G.GetCursorPosition = function() return 0, 0 end
    _G.IsMouseButtonDown = function() return false end
    _G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
    _G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    _G.C_Item = { GetItemQualityColor = function() return 1, 1, 1 end }
    _G.ScrollUtil = { AddAcquiredFrameCallback = function() end }
    _G.UIParent = NewFrame("Frame", "UIParent")

    env.profile = {
        general = { skinCharacterFrame = true },
        character = { enabled = true },
        skinning = {},
    }
    -- sr, sg, sb, sa, bgr, bgg, bgb, bga. Border is bright enough to be the
    -- text accent (luminance >= 0.35) so accent assertions can compare to it.
    env.colors = { 0.2, 0.8, 0.6, 1, 0.05, 0.06, 0.08, 0.95 }

    local core = { db = { profile = env.profile } }
    function core:GetPixelSize() return 1 end
    function core:Pixels(v) return v end
    function core:PixelRound(v) return v end
    function core:SetPixelPerfectSize(frame, w, h) frame:SetSize(w, h) end
    function core:SetPixelPerfectPoint(frame, ...) frame:SetPoint(...) end
    env.core = core

    local ns = {
        Addon = core,
        L = setmetatable({}, { __index = function(_, key) return key end }),
    }
    ns.Helpers = {
        CHROME = {
            BORDER_PX = 1, BG_FALLBACK = { 0.05, 0.05, 0.05, 0.95 }, BORDER_FALLBACK = { 0, 0, 0, 1 },
            BUTTON_BOOST = 0.07, SCROLLROW_BOOST = 0.03,
            DEPTH = { PANEL = { boost = 0, alpha = 0.95 }, SUBPANEL = { boost = 0.04, alpha = 0.85 }, ROW = { boost = 0.07, alpha = 0.75 } },
        },
        CreateStateTable = CreateStateTable,
        SafeToNumber = function(v, d) return tonumber(v) or d end,
        IsSecretValue = function() return false end,
        GetCore = function() return core end,
        GetProfile = function() return env.profile end,
        GetModuleDB = function(name) return env.profile[name] end,
        GetGeneralFont = function() return "QUIFont.ttf" end,
        GetGeneralFontOutline = function() return "" end,
        GetSkinBorderColor = function() return env.colors[1], env.colors[2], env.colors[3], env.colors[4] end,
        GetSkinAccentColor = function() return env.colors[1], env.colors[2], env.colors[3], env.colors[4] end,
        GetSkinBgColor = function() return env.colors[5], env.colors[6], env.colors[7], env.colors[8] end,
        GetSkinBgColorWithOverride = function() return env.colors[5], env.colors[6], env.colors[7], env.colors[8] end,
        CreateSkinColorGetter = function()
            return function() return unpack(env.colors) end
        end,
    }

    _G.QUI = {
        db = { profile = env.profile },
        GUI = {
            Colors = {
                bg = { 0.051, 0.067, 0.09, 0.97 },
                bgContent = { 1, 1, 1, 0.02 },
                accent = { 0.2, 0.8, 0.6, 1 },
                accentText = { 0.2, 0.8, 0.6, 1 },
                tabSelectedText = { 1, 1, 1, 1 },
                tabNormal = { 1, 1, 1, 0.55 },
                tabHover = { 1, 1, 1, 0.85 },
                disabled = { 1, 1, 1, 0.30 },
                selectedWash = { 0.2, 0.8, 0.6, 0.10 },
                scrollThumb = { 0.2, 0.8, 0.6, 0.6 },
                scrollTrack = { 1, 1, 1, 0.02 },
            },
            OnAccentChanged = function(_, fn) env.accentListeners[#env.accentListeners + 1] = fn end,
            EnsureWidgetAPI = function(self) return self end,
            HasWidgetAPI = function() return env.widgetAPI ~= false end,
        },
    }

    assert(loadfile("core/safecall.lua"))("QUI", ns)
    assert(loadfile("core/uikit.lua"))("QUI", ns)
    assert(loadfile("modules/skinning/frames/character_chrome.lua"))("QUI", ns)
    if opts.loadFrameSkin then
        assert(loadfile("modules/skinning/frames/character.lua"))("QUI", ns)
    end

    env.ns = ns
    env.Chrome = ns.CharacterChrome
    env.SkinBase = ns.SkinBase
    env.UIKit = ns.UIKit

    function env.SetGates(skinOn, enhancementOn)
        env.profile.general.skinCharacterFrame = skinOn
        env.profile.character.enabled = enhancementOn
    end

    -- A minimal Blizzard CharacterFrame with the children the chrome owner
    -- touches (nine slices, close button, slots, stats pane, sidebar decor).
    function env.BuildCharacterFrame()
        local function Named(kind, name, parent)
            local frame = NewFrame(kind, name, parent)
            _G[name] = frame
            return frame
        end
        local cf = Named("Frame", "CharacterFrame")
        cf.NineSlice = NewFrame("Frame", nil, cf)
        cf.CloseButton = NewFrame("Button", nil, cf)
        _G.CharacterFramePortrait = NewTexture(cf)
        _G.CharacterFrameBg = NewTexture(cf)
        _G.CharacterFrameInset = NewFrame("Frame", nil, cf)
        _G.CharacterFrameInset.NineSlice = NewFrame("Frame", nil, _G.CharacterFrameInset)
        _G.CharacterFrameInsetRight = NewFrame("Frame", nil, cf)
        _G.CharacterFrameInsetRight.NineSlice = NewFrame("Frame", nil, _G.CharacterFrameInsetRight)
        Named("Frame", "PaperDollFrame", cf)
        Named("Frame", "ReputationFrame", cf)
        Named("Frame", "TokenFrame", cf)
        local sidebar = Named("Frame", "PaperDollSidebarTabs", cf)
        sidebar.DecorLeft = NewTexture(sidebar)
        sidebar.DecorRight = NewTexture(sidebar)

        for _, slotName in ipairs({ "CharacterHeadSlot", "CharacterChestSlot", "CharacterMainHandSlot" }) do
            local slot = Named("Button", slotName, cf)
            slot.icon = NewTexture(slot)
            slot.IconBorder = NewTexture(slot)
            _G[slotName .. "Frame"] = NewTexture(cf)
        end

        local stats = Named("Frame", "CharacterStatsPane", cf)
        stats.ClassBackground = NewTexture(stats)
        local function Category()
            local cat = NewFrame("Frame", nil, stats)
            cat.Background = NewTexture(cat)
            cat.Title = NewTexture(cat, "FontString")
            return cat
        end
        stats.ItemLevelCategory = Category()
        stats.AttributesCategory = Category()
        stats.EnhancementsCategory = Category()
        stats.ItemLevelFrame = NewFrame("Frame", nil, stats)
        stats.ItemLevelFrame.Background = NewTexture(stats.ItemLevelFrame)
        stats.ItemLevelFrame.Value = NewTexture(stats.ItemLevelFrame, "FontString")
        local activeRows = {}
        stats.statsFramePool = {
            EnumerateActive = function() return pairs(activeRows) end,
            Acquire = function()
                local row = NewFrame("Frame", nil, stats)
                row.Background = NewTexture(row)
                row.Label = NewTexture(row, "FontString")
                row.Value = NewTexture(row, "FontString")
                activeRows[row] = true
                return row
            end,
        }
        _G.PaperDollFrame_SetLabelAndText = function(statFrame, label, text)
            statFrame.Label:SetText(label)
            statFrame.Value:SetText(text)
        end
        return cf
    end

    return env
end

return Harness
