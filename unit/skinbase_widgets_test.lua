-- tests/unit/skinbase_widgets_test.lua
-- Run: lua tests/unit/skinbase_widgets_test.lua
-- luacheck: globals CreateFrame C_Timer hooksecurefunc PanelTemplates_GetSelectedTab PanelTemplates_SetTab PanelTemplates_TabResize ScrollUtil

local hookedScripts = {}
local unpack = table.unpack or unpack

local function NewTexture()
    local t = { alpha = 1 }
    function t:SetAlpha(a) self.alpha = a end
    function t:SetTexture(f) self.file = f end
    function t:SetColorTexture(r, g, b, a) self.colorTexture = { r, g, b, a } end
    function t:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
    function t:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
    function t:SetText(text) self.text = text end
    function t:SetFont(font, size, flags) self.font, self.fontSize, self.fontFlags = font, size, flags end
    function t:ClearAllPoints() self.points = {} end
    function t:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
    function t:SetHeight(h) self.height = h end
    function t:SetWidth(w) self.width = w end
    function t:SetSize(w, h) self.width, self.height = w, h end
    function t:SetRotation(rotation) self.rotation = rotation end
    function t:GetWidth() return self.width or 0 end
    function t:GetStringWidth() return self.stringWidth or 0 end
    function t:IsTruncated() return self.width and self.width > 0 and self.width < self:GetStringWidth() end
    function t:Show() self.visible = true end
    function t:Hide() self.visible = false end
    function t:IsShown() return self.visible end
    function t:IsObjectType(objType) return objType == "Texture" end
    return t
end

local function NewFrame(parent)
    local f = { parent = parent, textures = {}, fontStrings = {}, points = {}, frameLevel = 4, scripts = {}, enabled = true }
    function f:CreateTexture() local t = NewTexture(); self.textures[#self.textures + 1] = t; return t end
    function f:CreateFontString() local t = NewTexture(); self.fontStrings[#self.fontStrings + 1] = t; return t end
    function f:SetAllPoints() self.allPoints = true end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetFrameLevel(l) self.frameLevel = l end
    function f:GetFrameLevel() return self.frameLevel end
    function f:EnableMouse(e) self.mouseEnabled = e end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:SetWidth(w) self.width = w end
    function f:GetWidth() return self.width or 0 end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:GetRegions() return unpack(self.textures) end
    function f:GetNumRegions() return #self.textures end
    function f:GetHighlightTexture() self.highlight = self.highlight or NewTexture(); return self.highlight end
    function f:GetPushedTexture() self.pushed = self.pushed or NewTexture(); return self.pushed end
    function f:GetNormalTexture() self.normal = self.normal or NewTexture(); return self.normal end
    function f:GetDisabledTexture() self.disabled = self.disabled or NewTexture(); return self.disabled end
    function f:GetFontString() self.fontString = self.fontString or NewTexture(); return self.fontString end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:HookScript(event, fn) self.scripts[event] = fn; hookedScripts[#hookedScripts + 1] = { f = self, event = event, fn = fn } end
    function f:SetFont(font, size, flags) self.font, self.fontSize, self.fontFlags = font, size, flags end
    function f:GetFont() return self.font, self.fontSize or 13, self.fontFlags end
    function f:SetFontObject(fontObject) self.fontObject = fontObject end
    function f:SetNormalFontObject(fontObject) self.normalFontObject = fontObject end
    function f:SetHighlightFontObject(fontObject) self.highlightFontObject = fontObject end
    function f:SetDisabledFontObject(fontObject) self.disabledFontObject = fontObject end
    function f:IsEnabled() return self.enabled end
    return f
end

function CreateFrame(_, _, parent) return NewFrame(parent) end
C_Timer = { After = function(_, fn) fn() end }
function hooksecurefunc(target, method, hook)
    if type(target) == "string" then
        local original = _G[target]
        local callback = method
        _G[target] = function(...)
            local results = { original(...) }
            callback(...)
            return unpack(results)
        end
        return
    end
    if type(target) ~= "table" or method ~= "SetTabSelected" then return end
    local original = target[method]
    target[method] = function(self, ...)
        original(self, ...)
        hook(self, ...)
    end
end
function PanelTemplates_GetSelectedTab(frame) return frame.selectedTab end
function PanelTemplates_SetTab() end
_G.PanelTemplates_SelectTab = function(tab) tab:SetDisabledFontObject("GameFontHighlightSmall") end
_G.PanelTemplates_DeselectTab = function(tab) tab:SetDisabledFontObject("GameFontHighlightSmall") end
_G.PanelTemplates_SetDisabledTabState = function(tab) tab:SetDisabledFontObject("GameFontDisableSmall") end
function PanelTemplates_TabResize(tab, padding, _, minWidth, maxWidth)
    tab.Text:SetWidth(0)
    local textWidth = tab.Text:GetStringWidth()
    local width = textWidth + 20 + (padding or 0)
    if maxWidth and width > maxWidth then
        width = maxWidth
    elseif minWidth and width < minWidth then
        width = minWidth
    end
    tab.Text:SetWidth(width - 20 - (padding or 0))
    tab:SetWidth(width)
end

local skinColors = { 0.6, 0.7, 0.8, 1, 0.1, 0.2, 0.3, 0.9 }
local applyGlobalFontToBlizzard = true

local ns = {
    -- core/uikit.lua now routes its pcall guards through ns.SafeCall
    -- (Task 45d); mirror the ns-mock stub precedent used across the suite.
    SafeCall = function(_policy, fn, ...) return pcall(fn, ...) end,
    SafeCallMethod = function(_policy, obj, name, ...) return pcall(function(...) return obj[name](obj, ...) end, ...) end,
    SafeCallMethodIfPresent = function(_policy, obj, name, ...) if obj == nil then return nil end local okP, m = pcall(function() return obj[name] end) if not okP then return false end if m == nil then return nil end return pcall(m, obj, ...) end,
    Helpers = {
        CHROME = { BORDER_PX = 1, BG_FALLBACK = { 0.05, 0.05, 0.05, 0.95 }, BORDER_FALLBACK = { 0, 0, 0, 1 }, BUTTON_BOOST = 0.07, SCROLLROW_BOOST = 0.03, DEPTH = { PANEL = { boost = 0, alpha = 0.95 }, SUBPANEL = { boost = 0.04, alpha = 0.85 }, ROW = { boost = 0.07, alpha = 0.75 } } },
        CreateStateTable = function()
            local tbl = setmetatable({}, { __mode = "k" })
            local function get(key)
                local s = tbl[key]
                if not s then s = {}; tbl[key] = s end
                return s
            end
            return tbl, get
        end,
        GetCore = function()
            return {
                GetPixelSize = function() return 0.5 end,
                db = { profile = { general = { applyGlobalFontToBlizzard = applyGlobalFontToBlizzard } } },
            }
        end,
        SafeToNumber = function(v, d) return tonumber(v) or d end,
        GetSkinBorderColor = function() return skinColors[1], skinColors[2], skinColors[3], skinColors[4] end,
        GetSkinBgColorWithOverride = function() return skinColors[5], skinColors[6], skinColors[7], skinColors[8] end,
        GetSkinBarColor = function() return 0.5, 0.5, 0.5, 1 end,
        GetGeneralFont = function() return "Interface\\QUIFont.ttf" end,
        GetGeneralFontOutline = function() return "OUTLINE" end,
    },
    UIKit = { RegisterScaleRefresh = function() end },
}

_G.CreateFont = function(name)
    local font = { name = name }
    function font:SetFont(path, size, flags) self.path, self.size, self.flags = path, size, flags end
    function font:SetFontObject(object) self.object = object end
    function font:SetTextColor(r, g, b, a) self.color = { r, g, b, a } end
    return font
end

assert(loadfile("core/uikit.lua"))("QUI", ns)
local SkinBase = ns.SkinBase

local nativeClose = NewFrame()
nativeClose.Border = NewTexture()
SkinBase.SkinCloseButton(nativeClose)
local nativeCloseLabel = SkinBase.GetFrameData(nativeClose, "closeLabel")
assert(nativeClose.Border.alpha == 0, "SkinCloseButton must hide the native border")
assert(nativeClose:GetNormalTexture().alpha == 0 and nativeClose:GetPushedTexture().alpha == 0
    and nativeClose:GetHighlightTexture().alpha == 0 and nativeClose:GetDisabledTexture().alpha == 0,
    "SkinCloseButton must hide every native state texture")
assert(nativeCloseLabel.text == "X", "SkinCloseButton must use the Bags text X")
assert(SkinBase.GetBackdrop(nativeClose) == nil, "SkinCloseButton must remain borderless")
assert(#nativeClose.textures == 0, "SkinCloseButton must not create background or border textures")
nativeClose.scripts.OnEnter(nativeClose)
assert(nativeCloseLabel.textColor[1] == 0.204 and nativeCloseLabel.textColor[2] == 0.827,
    "SkinCloseButton hover must color only the X")
nativeClose.scripts.OnLeave(nativeClose)
assert(nativeCloseLabel.textColor[1] == 1 and nativeCloseLabel.textColor[4] == 0.8,
    "SkinCloseButton leave must restore the borderless X color")
SkinBase.SkinCloseButton(nativeClose, { fontSize = 11 })
assert(#nativeClose.fontStrings == 1 and nativeCloseLabel.fontSize == 11,
    "SkinCloseButton must update its existing X label when refreshed")

local chromeClose = NewFrame()
SkinBase.SkinChromeCloseButton(chromeClose)
assert(SkinBase.GetFrameData(chromeClose, "closeLabel").text == "X" and SkinBase.GetBackdrop(chromeClose) == nil,
    "SkinChromeCloseButton compatibility must use the borderless standard")

local createdClose = SkinBase.CreateCloseButton(NewFrame(), { size = 20, onClick = function() end })
assert(createdClose.width == 20 and createdClose.height == 20 and createdClose.text.text == "X",
    "CreateCloseButton must create the borderless Bags-style X")
assert(#createdClose.textures == 0 and SkinBase.GetBackdrop(createdClose) == nil,
    "CreateCloseButton must not create background or border textures")

-- SkinButton: backdrop with button boost, hides named + state textures, tags kind, idempotent
local button = NewFrame()
button.Left, button.Right, button.Middle, button.Center = NewTexture(), NewTexture(), NewTexture(), NewTexture()
SkinBase.SkinButton(button)
assert(SkinBase.GetBackdrop(button), "SkinButton must create a backdrop")
assert(button.Left.alpha == 0, "SkinButton must hide named Left texture")
assert(button:GetNormalTexture().alpha == 0, "SkinButton must hide normal texture")
assert(button:GetDisabledTexture().alpha == 0, "SkinButton must hide disabled texture")
assert(SkinBase.GetFrameData(button, "skinKind") == "button", "SkinButton must tag skinKind")
assert(SkinBase.IsStyled(button), "SkinButton must mark styled")
local bd = SkinBase.GetBackdrop(button)
assert(math.abs(bd._quiBgR - (0.1 + 0.07)) < 1e-9, "SkinButton must apply the button bg boost")

local stateButton = NewFrame()
stateButton.Left, stateButton.Right, stateButton.Middle = NewTexture(), NewTexture(), NewTexture()
stateButton.enabled = false
SkinBase.SkinButton(stateButton, { fontColor = { 1, 0.82, 0, 1 }, disabledFontColor = { 1, 1, 1, 1 } })
assert(stateButton:GetFontString().textColor[1] == 1 and stateButton:GetFontString().textColor[2] == 1,
    "disabled skinned button must honor its explicit disabled text color")
stateButton.Left.alpha = 1
stateButton.enabled = true
stateButton.scripts.OnEnable(stateButton)
assert(stateButton.Left.alpha == 0, "OnEnable must re-suppress UIPanelButton slice art")
assert(math.abs(stateButton:GetFontString().textColor[2] - 0.82) < 1e-9,
    "OnEnable must restore active text color")
stateButton.enabled = false
stateButton.scripts.OnDisable(stateButton)
assert(stateButton:GetFontString().textColor[1] == 1 and stateButton:GetFontString().textColor[2] == 1,
    "OnDisable must restore the explicit disabled text color")

local defaultStateButton = NewFrame()
defaultStateButton.enabled = false
SkinBase.SkinButton(defaultStateButton)
assert(defaultStateButton:GetFontString().textColor[1] == 0.5,
    "disabled default button text must use the disabled color")
defaultStateButton.enabled = true
defaultStateButton.scripts.OnEnable(defaultStateButton)
assert(defaultStateButton:GetFontString().textColor[1] == 1
    and defaultStateButton:GetFontString().textColor[2] == 1
    and defaultStateButton:GetFontString().textColor[3] == 1,
    "enabled default button text must deterministically restore QUI white")

applyGlobalFontToBlizzard = false
local nativeGoldButton = NewFrame()
nativeGoldButton:GetFontString():SetTextColor(1, 0.82, 0, 1)
SkinBase.SkinButton(nativeGoldButton)
assert(nativeGoldButton:GetFontString().textColor[1] == 1
    and nativeGoldButton:GetFontString().textColor[2] == 1
    and nativeGoldButton:GetFontString().textColor[3] == 1,
    "SkinButton must replace native gold text even when Blizzard font replacement is disabled")
applyGlobalFontToBlizzard = true

-- SkinButton{strip=true} strips textures instead of hiding named regions
local stripBtn = NewFrame()
stripBtn.textures = { NewTexture() }
SkinBase.SkinButton(stripBtn, { strip = true })
assert(stripBtn.textures[1].alpha == 0, "SkinButton{strip=true} must StripTextures")

-- SkinEditBox
local edit = NewFrame()
edit.textures = { NewTexture() }
SkinBase.SkinEditBox(edit)
assert(SkinBase.GetFrameData(edit, "skinKind") == "editbox", "SkinEditBox must tag editbox kind")
assert(edit.textures[1].alpha == 0, "SkinEditBox must strip textures")
assert(edit.font == "Interface\\QUIFont.ttf", "SkinEditBox must apply the global font by default")
assert(SkinBase.GetFrameData(edit, "skinFont") == true, "SkinEditBox must opt into font refresh by default")

local editOptOut = NewFrame()
SkinBase.SkinEditBox(editOptOut, { font = false })
assert(editOptOut.font == nil, "SkinEditBox{font=false} must preserve the native editbox font")

-- SkinScrollRow: row boost + alpha-multiplied border
local row = NewFrame()
row.textures = { NewTexture() }
SkinBase.SkinScrollRow(row)
assert(SkinBase.GetFrameData(row, "skinKind") == "row", "SkinScrollRow must tag row kind")
local rowSc = SkinBase.GetFrameData(row, "skinColor")
assert(math.abs(rowSc[4] - (1 * 0.5)) < 1e-9, "SkinScrollRow must halve the border alpha")

-- SkinDropdown options
local ddArrow = NewFrame()
ddArrow.Arrow = NewTexture()
ddArrow.NormalTexture = NewTexture()
SkinBase.SkinDropdown(ddArrow, { skinArrow = true, insetY = 2 })
assert(ddArrow.Arrow.alpha == 0, "SkinDropdown{skinArrow} must hide the native arrow art")
assert(ddArrow.NormalTexture.alpha == 0, "SkinDropdown{skinArrow} must hide NormalTexture")
local ddCaret = SkinBase.GetFrameData(ddArrow, "dropdownCaret")
assert(ddCaret and ddCaret.line1 and ddCaret.line2
    and ddCaret.line1.colorTexture[1] == 1 and ddCaret.line1.colorTexture[4] == 0.8,
    "SkinDropdown{skinArrow} must replace native art with the QUI chevron")
assert(SkinBase.GetFrameData(ddArrow, "skinKind") == "dropdown", "SkinDropdown must tag dropdown kind")

local ddFilter = NewFrame()
ddFilter.textures = { NewTexture() }
SkinBase.SkinDropdown(ddFilter, { noStrip = true, belowChildren = true })
assert(ddFilter.textures[1].alpha == 1, "SkinDropdown{noStrip} must NOT strip child textures")
local ddBd = SkinBase.GetBackdrop(ddFilter)
assert(ddBd:GetFrameLevel() == math.max(0, ddFilter:GetFrameLevel() - 1),
    "SkinDropdown{belowChildren} must drop the backdrop frame level below the dropdown")

-- SkinListContainer hides NineSlice + ScrollBar.Background and styles rows via the scroll hook
local styledRows = {}
local list = NewFrame()
list.NineSlice = NewFrame()
list.ScrollBar = NewFrame(); list.ScrollBar.Background = NewTexture()
list.ScrollBox = NewFrame()
function list.ScrollBox:ForEachFrame(cb) cb(NewFrame()) end
-- Provide ScrollUtil so HookScrollBoxAcquired runs
ScrollUtil = { AddAcquiredFrameCallback = function() end }
SkinBase.SkinListContainer(list, function(r) styledRows[#styledRows + 1] = r end)
assert(list.NineSlice.shown == nil or list.NineSlice.shown == false, "SkinListContainer must hide NineSlice")
assert(list.ScrollBar.Background.alpha == 0, "SkinListContainer must route the scrollbar through the canonical SkinTrimScrollBar (alpha-0 background, not a bare Hide)")
assert(#styledRows == 1, "SkinListContainer must style pooled rows via the scroll hook")

-- SkinListContainer is idempotent (second call is a no-op)
SkinBase.SkinListContainer(list, function(r) styledRows[#styledRows + 1] = r end)
assert(#styledRows == 1, "SkinListContainer must be idempotent (no re-styling on repeat call)")

-- HookScrollBoxAcquired composes callbacks registered by different helpers.
local callbackOrder = {}
local callbackScrollBox = NewFrame()
function callbackScrollBox:ForEachFrame(cb) cb("existing") end
local acquiredCallback
local timerQueue = {}
local nextTimer = 1
C_Timer = { After = function(_, fn) timerQueue[#timerQueue + 1] = fn end }
local function FlushTimers()
    while nextTimer <= #timerQueue do
        local fn = timerQueue[nextTimer]
        nextTimer = nextTimer + 1
        fn()
    end
end
ScrollUtil = {
    AddAcquiredFrameCallback = function(_, callback)
        acquiredCallback = callback
    end,
}
SkinBase.HookScrollBoxAcquired(callbackScrollBox, function(frame)
    callbackOrder[#callbackOrder + 1] = "first:" .. frame
end)
SkinBase.HookScrollBoxAcquired(callbackScrollBox, function(frame)
    callbackOrder[#callbackOrder + 1] = "second:" .. frame
end)
assert(type(acquiredCallback) == "function", "HookScrollBoxAcquired must install a native acquired callback")
assert(#callbackOrder == 0, "HookScrollBoxAcquired must defer the existing-row pass")
FlushTimers()
assert(table.concat(callbackOrder, ",") == "first:existing,second:existing",
    "HookScrollBoxAcquired must run every registered callback for existing rows")
acquiredCallback(nil, "acquired")
assert(table.concat(callbackOrder, ",") == "first:existing,second:existing",
    "generic HookScrollBoxAcquired callbacks must defer acquired rows")
FlushTimers()
assert(table.concat(callbackOrder, ",") == "first:existing,second:existing,first:acquired,second:acquired",
    "HookScrollBoxAcquired must run every registered callback for acquired rows after the defer")

-- HookScrollBoxRowFonts opts into sync acquisition because it only touches
-- per-instance FontStrings and must run before the pooled row's first paint.
local savedSkinFrameText = SkinBase.SkinFrameText
local savedLockFrameTextObjects = SkinBase.LockFrameTextObjects
local rowFontOrder = {}
SkinBase.SkinFrameText = function(frame)
    rowFontOrder[#rowFontOrder + 1] = "skin:" .. frame.name
end
SkinBase.LockFrameTextObjects = function(frame, depth)
    rowFontOrder[#rowFontOrder + 1] = "lock:" .. frame.name .. ":" .. depth
end
timerQueue = {}
nextTimer = 1
local rowFontAcquiredCallback
local rowFontScrollBox = NewFrame()
function rowFontScrollBox:ForEachFrame() end
ScrollUtil = {
    AddAcquiredFrameCallback = function(_, callback)
        rowFontAcquiredCallback = callback
    end,
}
SkinBase.HookScrollBoxRowFonts(rowFontScrollBox, 2)
rowFontAcquiredCallback(nil, { name = "rowFontAcquired" })
assert(table.concat(rowFontOrder, ",") == "skin:rowFontAcquired,lock:rowFontAcquired:2",
    "HookScrollBoxRowFonts must lock acquired row text synchronously")
SkinBase.SkinFrameText = savedSkinFrameText
SkinBase.LockFrameTextObjects = savedLockFrameTextObjects
C_Timer = { After = function(_, fn) fn() end }

-- RefreshWidget recolors by kind and updates stored skinColor
skinColors = { 0.9, 0.8, 0.7, 1, 0.4, 0.5, 0.6, 0.95 }

-- button branch
SkinBase.RefreshWidget(button)
local newSc = SkinBase.GetFrameData(button, "skinColor")
assert(newSc[1] == 0.9, "RefreshWidget must update stored skinColor for later hovers")
local rbd = SkinBase.GetBackdrop(button)
assert(math.abs(rbd._quiBorderR - 0.9) < 1e-9, "RefreshWidget must recolor the button border")
assert(math.abs(rbd._quiBgR - (0.4 + 0.07)) < 1e-9, "RefreshWidget must recolor the button bg with boost")

-- editbox branch (uses full background alpha, no boost)
SkinBase.RefreshWidget(edit)
local ebd = SkinBase.GetBackdrop(edit)
assert(math.abs(ebd._quiBgR - 0.4) < 1e-9, "RefreshWidget editbox must recolor bg with no boost")
assert(math.abs(ebd._quiBgA - 0.95) < 1e-9, "RefreshWidget editbox must apply the background alpha (bga)")
assert(math.abs(ebd._quiBorderR - 0.9) < 1e-9, "RefreshWidget editbox must recolor the border")

-- row branch (row boost, halved border alpha, fixed bg alpha)
SkinBase.RefreshWidget(row)
local rowBd = SkinBase.GetBackdrop(row)
assert(math.abs(rowBd._quiBgR - (0.4 + 0.03)) < 1e-9, "RefreshWidget row must recolor bg with row boost")
assert(math.abs(rowBd._quiBgA - 0.6) < 1e-9, "RefreshWidget row must keep the row bg alpha")
assert(math.abs(rowBd._quiBorderA - (1 * 0.5)) < 1e-9, "RefreshWidget row must keep the halved border alpha")
local rowSc2 = SkinBase.GetFrameData(row, "skinColor")
assert(math.abs(rowSc2[4] - 0.5) < 1e-9, "RefreshWidget row must re-store the halved-alpha skinColor")

-- dropdown branch (button boost, stored bgColor)
SkinBase.RefreshWidget(ddArrow)
local ddBd2 = SkinBase.GetBackdrop(ddArrow)
assert(math.abs(ddBd2._quiBgR - (0.4 + 0.07)) < 1e-9, "RefreshWidget dropdown must recolor bg with button boost")
assert(math.abs(ddBd2._quiBorderR - 0.9) < 1e-9, "RefreshWidget dropdown must recolor the border")


-- Tab selection detection: TabSystem GetSelectedTab vs tab.tabID
local tabA = NewFrame()
local tabB = NewFrame()
tabA.tabID, tabB.tabID = 1, 2
local owner = NewFrame()
owner.TabSystem = NewFrame()
owner.TabSystem.tabs = { tabA, tabB }
function owner.TabSystem:GetSelectedTab() return 1 end
function owner.TabSystem:SetTab() end

SkinBase.SkinTabGroup({ tabA, tabB }, owner, { hover = true })
assert(SkinBase.IsStyled(tabA), "SkinTabGroup must skin each tab")
assert(SkinBase.GetFrameData(tabA, "qTabHoverHooked"), "hover tabs must be hover-hooked")

-- Selected tab (tabID 1) gets full border alpha; unselected gets dimmed border
local bdA = SkinBase.GetBackdrop(tabA)
local bdB = SkinBase.GetBackdrop(tabB)
assert(bdA._quiBorderA == 1, "selected tab must use full border alpha")
assert(math.abs(bdB._quiBorderA - (1 * 0.6)) < 1e-9, "unselected tab must use dimmed border alpha")

-- Hover actually runs: enter brightens the border, leave restores the
-- dimmed unselected state (tabB stored skinColor = {0.9,0.8,0.7,1}).
tabB.scripts.OnEnter(tabB)
assert(math.abs(bdB._quiBorderB - math.min(0.7 * 1.3, 1)) < 1e-9, "tab hover enter must brighten the border")
tabB.scripts.OnLeave(tabB)
assert(math.abs(bdB._quiBorderA - (1 * 0.6)) < 1e-9, "tab hover leave must restore the dimmed unselected border")

-- RefreshTabGroup re-stores colors and re-applies selected state
skinColors = { 0.2, 0.3, 0.4, 1, 0.05, 0.06, 0.07, 0.9 }
SkinBase.RefreshTabGroup({ tabA, tabB }, owner)
local scA = SkinBase.GetFrameData(tabA, "skinColor")
assert(scA[1] == 0.2, "RefreshTabGroup must re-store tab skinColor")
assert(SkinBase.GetBackdrop(tabA)._quiBorderR == 0.2, "RefreshTabGroup must recolor selected tab border")

local anonymousA = NewFrame()
local anonymousB = NewFrame()
local anonymousC = NewFrame()
anonymousA.Text, anonymousB.Text, anonymousC.Text = NewTexture(), NewTexture(), NewTexture()
anonymousA.Left, anonymousA.Right = NewTexture(), NewTexture()
anonymousB.Left, anonymousB.Right = NewTexture(), NewTexture()
anonymousC.Left, anonymousC.Right = NewTexture(), NewTexture()
anonymousA.Text.stringWidth, anonymousB.Text.stringWidth, anonymousC.Text.stringWidth = 60, 110, 200
anonymousA:SetWidth(70)
anonymousB:SetWidth(70)
anonymousC:SetWidth(70)
local anonymousOwner = NewFrame()
anonymousOwner.Tabs = { anonymousA, anonymousB, anonymousC }
anonymousOwner.selectedTab = 1
anonymousOwner.tabPadding = 6
anonymousOwner.minTabWidth = 120
anonymousOwner.maxTabWidth = 150
local function ResizeAnonymousTab(self)
    PanelTemplates_TabResize(self, anonymousOwner.tabPadding, nil,
        anonymousOwner.minTabWidth, anonymousOwner.maxTabWidth)
end
anonymousA.OnShow, anonymousB.OnShow, anonymousC.OnShow = ResizeAnonymousTab, ResizeAnonymousTab, ResizeAnonymousTab
SkinBase.SkinTabGroup(anonymousOwner.Tabs, anonymousOwner, { resizeToText = true })
local anonymousBdA = SkinBase.GetBackdrop(anonymousA)
local anonymousBdB = SkinBase.GetBackdrop(anonymousB)
assert(anonymousA:GetWidth() == 120 and anonymousB:GetWidth() == 136 and anonymousC:GetWidth() == 150,
    "text-fit PanelTabs must replay Blizzard's native min/max sizing after the QUI font is applied")
assert(not anonymousA.Text:IsTruncated() and not anonymousB.Text:IsTruncated() and anonymousC.Text:IsTruncated(),
    "text-fit PanelTabs must preserve Blizzard's native maximum width")
assert(anonymousBdA._quiBorderA == 1 and math.abs(anonymousBdB._quiBorderA - 0.6) < 1e-9,
    "ID-less PanelTabs must use the owner's selected array index")
-- Palette ladder: white text, state by alpha (selected 1.0 / unselected 0.55).
assert(anonymousA.Text.textColor[1] == 1 and anonymousA.Text.textColor[4] == 1
    and anonymousB.Text.textColor[1] == 1 and math.abs(anonymousB.Text.textColor[4] - 0.55) < 1e-9,
    "selected and inactive PanelTabs must use distinct text alphas (white 1.0 vs white 0.55)")
anonymousOwner.selectedTab = 2
anonymousB.scripts.OnClick(anonymousB)
assert(math.abs(anonymousBdA._quiBorderA - 0.6) < 1e-9 and anonymousBdB._quiBorderA == 1,
    "ID-less PanelTabs must repaint when selection changes")
assert(math.abs(anonymousA.Text.textColor[4] - 0.55) < 1e-9 and anonymousB.Text.textColor[4] == 1,
    "PanelTab text alphas must follow the selected tab")
anonymousC.isDisabled = 1
_G.PanelTemplates_SetDisabledTabState(anonymousC)
assert(type(anonymousC.disabledFontObject) == "table"
    and anonymousC.disabledFontObject.name:find("QUIButtonFontObject", 1, true),
    "disabled PanelTabs must reassert the QUI font after Blizzard resets it")
assert(anonymousC.Text.textColor[1] == 1 and math.abs(anonymousC.Text.textColor[4] - 0.30) < 1e-9,
    "disabled + unselected PanelTabs must drop to the disabled rung (white 0.30)")
anonymousC.isDisabled = nil
anonymousOwner.selectedTab = 3
_G.PanelTemplates_SelectTab(anonymousC)
assert(type(anonymousC.disabledFontObject) == "table" and anonymousC.Text.textColor[4] == 1,
    "selected PanelTabs must restore the QUI selected font state (white 1.0)")

local artTab = NewFrame()
artTab.Text = NewTexture()
artTab.Left, artTab.Right = NewTexture(), NewTexture()
function artTab:SetTabSelected(selected) self.isSelected = selected end
function artTab:UpdateTabWidth() self.widthUpdates = (self.widthUpdates or 0) + 1 end
artTab:SetTabSelected(true)
SkinBase.SkinTab(artTab, NewFrame())
local artBd = SkinBase.GetBackdrop(artTab)
assert(artBd._quiBorderA == 1 and artTab.Text.textColor[4] == 1,
    "Art-template tabs must read their native isSelected state")
assert(artTab.widthUpdates > 0, "TabSystem tabs must be remeasured after their font is applied")
local widthUpdatesBeforeSelection = artTab.widthUpdates
artTab:SetTabSelected(false)
assert(artTab.widthUpdates > widthUpdatesBeforeSelection,
    "TabSystem tabs must be remeasured after their selected state changes")
assert(math.abs(artBd._quiBorderA - 0.6) < 1e-9 and math.abs(artTab.Text.textColor[4] - 0.55) < 1e-9,
    "Art-template tabs must repaint after SetTabSelected")

-- SkinTab (single tab, pooled-tab use) skins + hover-hooks
local poolTab = NewFrame()
poolTab.tabID = 1
SkinBase.SkinTab(poolTab, owner, { hover = true })
assert(SkinBase.IsStyled(poolTab), "SkinTab must skin the tab")
assert(SkinBase.GetFrameData(poolTab, "qTabHoverHooked"), "SkinTab{hover} must hover-hook")

print("OK: skinbase_widgets_test")
