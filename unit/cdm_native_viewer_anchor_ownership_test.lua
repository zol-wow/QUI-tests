local function loadMethod(path, name)
    local f = assert(io.open(path, 'rb'))
    local source = f:read('*a')
    f:close()
    local first = assert(source:find('function ' .. name .. '(', 1, true))
    local last = assert(source:find('\nend', first, true))
    assert(loadstring(source:sub(first, last + 3), '@' .. path))()
end
local systemPath = 'tests/framexml/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSystemTemplates.lua'
_G.EditModeSystemMixin = {}
for _, name in ipairs({'SetPointOverride', 'ClearAllPointsOverride', 'SetSnappedToFrame', 'ClearFrameSnap', 'AddSnappedFrame', 'RemoveSnappedFrame'}) do
    loadMethod(systemPath, 'EditModeSystemMixin:' .. name)
end
_G.EditModeManagerFrameMixin = {}
loadMethod('tests/framexml/Interface/AddOns/Blizzard_EditMode/Shared/EditModeManager.lua', 'EditModeManagerFrameMixin:OnEditModeSystemAnchorChanged')
EditModeManagerFrame = setmetatable({}, {__index = _G.EditModeManagerFrameMixin})
UIParent = {}
local inCombat = false
InCombatLockdown = function() return inCombat end
local ns = {CDMCatalog = {IsCooldownViewerReady = function() return true end}}
LibStub = function() end
assert(loadfile('core/utils.lua'))('QUI', ns)
assert(loadfile('QUI_CDM/cdm/cdm_reanchor_hooks.lua'))('QUI_CDM', ns)
assert(loadfile('QUI_CDM/cdm/cdm_blizzard_buffbar_suppression.lua'))('QUI_CDM', ns)
local function viewer()
    local anchor = setmetatable({snappedFrames = {}}, {__index = _G.EditModeSystemMixin})
    local v = setmetatable({points = {}, snappedToFrame = anchor, alpha = 1}, {__index = _G.EditModeSystemMixin})
    anchor.snappedFrames[v] = true
    v.ClearAllPointsBase = function(self) self.points = {} end
    v.SetPointBase = function(self, ...) self.points[#self.points + 1] = {...} end
    v.ClearAllPoints = v.ClearAllPointsOverride
    v.SetPoint = v.SetPointOverride
    v.GetNumPoints = function(self) return #self.points end
    v.GetPoint = function(self, i) return unpack(self.points[i]) end
    v.SetAlpha = function(self, alpha) self.alpha = alpha end
    return v, anchor
end
local function assertOwnership(frame, anchor, label)
    assert(EditModeManagerFrame.editModeSystemAnchorDirty == nil, label .. ' must not dirty Blizzard Edit Mode')
    assert(frame.snappedToFrame == anchor and anchor.snappedFrames[frame] == true,
        label .. ' must preserve Blizzard snap bookkeeping')
end
local function assertPoints(frame, expected, label)
    assert(#frame.points == #expected, label .. ' must preserve the expected point count')
    for i = 1, #expected do
        for j = 1, 5 do
            assert(frame.points[i][j] == expected[i][j], label .. ' has incorrect anchor geometry')
        end
    end
end
local v, anchor = viewer()
local hk = ns.CDMReanchorHooks.New({})
local container = {}
hk._glueGetContainer = function() return container end
assert(hk:_GlueViewer({viewer = v, key = 'essential'}))
assert(EditModeManagerFrame.editModeSystemAnchorDirty == nil, 'QUI viewer glue must not dirty Blizzard Edit Mode through its Lua override')
assert(v.snappedToFrame == anchor and anchor.snappedFrames[v] == true, 'QUI viewer glue must preserve native snap bookkeeping')
assert(#v.points == 2, 'glue still places two points')
assertPoints(v, {
    {'TOPLEFT', container, 'TOPLEFT', 0, 0},
    {'BOTTOMRIGHT', container, 'BOTTOMRIGHT', 0, 0},
}, 'viewer glue')

EditModeManagerFrame.editModeSystemAnchorDirty = nil
local bar, barAnchor = viewer()
assert(ns.CDMBlizzardBuffBarSuppressor:Suppress(bar))
assert(EditModeManagerFrame.editModeSystemAnchorDirty == nil, 'QUI BuffBar parking must not dirty Blizzard Edit Mode through its Lua override')
assert(bar.snappedToFrame == barAnchor and barAnchor.snappedFrames[bar] == true, 'QUI BuffBar parking must preserve native snap bookkeeping')
assert(#bar.points == 1 and bar.points[1][5] == -10000, 'suppression still parks the bar')
ns.CDMBlizzardBuffBarSuppressor:Restore(bar)
assert(EditModeManagerFrame.editModeSystemAnchorDirty == nil, 'QUI BuffBar restore must not dirty Blizzard Edit Mode')
assert(bar.snappedToFrame == barAnchor and barAnchor.snappedFrames[bar] == true, 'QUI BuffBar restore must preserve native snap bookkeeping')
assert(#bar.points == 1 and bar.points[1][1] == 'CENTER', 'restoring an empty original anchor uses the fallback geometry')

local restored, restoredAnchor = viewer()
restored.points = {{'TOPLEFT', restoredAnchor, 'BOTTOMLEFT', 10, -20}}
assert(ns.CDMBlizzardBuffBarSuppressor:Suppress(restored))
ns.CDMBlizzardBuffBarSuppressor:Restore(restored)
assert(EditModeManagerFrame.editModeSystemAnchorDirty == nil, 'restoring saved points must not dirty Blizzard Edit Mode')
assert(restored.snappedToFrame == restoredAnchor and restoredAnchor.snappedFrames[restored] == true, 'restoring saved points must preserve native snap bookkeeping')
assert(#restored.points == 1 and restored.points[1][2] == restoredAnchor and restored.points[1][4] == 10 and restored.points[1][5] == -20, 'saved anchor geometry must be restored')

local combatViewer, combatAnchor = viewer()
local combatEntry = {viewer = combatViewer, key = 'utility'}
local originalGluePoints = {{'CENTER', combatAnchor, 'CENTER', 27, -35}}
combatViewer.points = originalGluePoints
hk._glueCanWrite = function() return not inCombat end
hk._glueEntries = {combatEntry}
inCombat = true
assert(hk:_GlueViewer(combatEntry) == false, 'combat must defer viewer glue')
hk:ReassertViewerGlue()
assert(combatViewer.points == originalGluePoints, 'combat glue must not clear native anchors')
assertOwnership(combatViewer, combatAnchor, 'deferred viewer glue')
inCombat = false
hk:ReassertViewerGlue()
assert(combatEntry.applied == true, 'viewer glue must recover when combat ends')
assertPoints(combatViewer, {
    {'TOPLEFT', container, 'TOPLEFT', 0, 0},
    {'BOTTOMRIGHT', container, 'BOTTOMRIGHT', 0, 0},
}, 'viewer glue after combat')
assertOwnership(combatViewer, combatAnchor, 'viewer glue after combat')

local combatBar, combatBarAnchor = viewer()
local originalBarPoints = {
    {'TOPLEFT', combatBarAnchor, 'BOTTOMLEFT', 10, -20},
    {'BOTTOMRIGHT', combatBarAnchor, 'BOTTOMRIGHT', 25, -45},
}
combatBar.points = originalBarPoints
local suppressor = ns.CDMBlizzardBuffBarSuppressor
inCombat = true
assert(suppressor:Suppress(combatBar), 'combat suppression must still hide the native bar')
assert(combatBar.alpha == 0 and combatBar.points == originalBarPoints,
    'combat suppression must alpha-hide without changing anchors')
suppressor:FlushPendingRestore()
assert(combatBar.points == originalBarPoints, 'combat flush must leave native anchors untouched')
assertOwnership(combatBar, combatBarAnchor, 'deferred bar parking')
inCombat = false
suppressor:FlushPendingRestore()
assertPoints(combatBar, {{'TOPLEFT', UIParent, 'BOTTOMLEFT', 0, -10000}}, 'bar parking after combat')
assertOwnership(combatBar, combatBarAnchor, 'bar parking after combat')
inCombat = true
suppressor:Restore(combatBar)
assert(combatBar.alpha == 1, 'combat restoration must release alpha suppression')
assertPoints(combatBar, {{'TOPLEFT', UIParent, 'BOTTOMLEFT', 0, -10000}}, 'deferred bar restoration')
assertOwnership(combatBar, combatBarAnchor, 'deferred bar restoration')
inCombat = false
suppressor:FlushPendingRestore()
assertPoints(combatBar, originalBarPoints, 'bar restoration after combat')
assertOwnership(combatBar, combatBarAnchor, 'bar restoration after combat')

local nativeViewer, nativeAnchor = viewer()
nativeViewer:ClearAllPoints()
assert(nativeViewer.snappedToFrame == nil and nativeAnchor.snappedFrames[nativeViewer] == nil,
    'native ClearAllPoints override must exercise real Blizzard snap writes')
nativeViewer:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
assert(EditModeManagerFrame.editModeSystemAnchorDirty == true,
    'native SetPoint override must exercise the real Blizzard manager write')
nativeViewer:SetPoint('CENTER', nativeAnchor, 'CENTER', 0, 0)
assert(nativeViewer.snappedToFrame == nativeAnchor and nativeAnchor.snappedFrames[nativeViewer] == true,
    'native SetPoint override must retain its normal snap registration behavior')
print('OK: cdm_native_viewer_anchor_ownership_test')
