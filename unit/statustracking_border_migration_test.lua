-- Legacy border preferences retain their intent when the shared controls replace them.
local ns = { IsSkinningEnabled = function() return false end }
assert(loadfile('modules/skinning/frames/statustracking.lua'))('QUI', ns)
local migrate = assert(ns.MigrateStatusTrackingBorderSettings, 'migration must be available with skinning disabled')
local fresh = {}
migrate(fresh)
assert(fresh.statusTrackingBarsBorderColorSource == 'inherit')
local color = {.1,.2,.3,.4}
local custom = {statusTrackingBarsBorderOverride=true,statusTrackingBarsBorderColor=color,statusTrackingBarsShowBorder=false}
migrate(custom)
assert(custom.statusTrackingBarsBorderColorSource == 'custom' and custom.statusTrackingBarsBorderColor == color)
assert(custom.statusTrackingBarsHideBorder == true and custom.statusTrackingBarsShowBorder ~= false)
custom.statusTrackingBarsHideBorder = false
migrate(custom)
assert(custom.statusTrackingBarsHideBorder == false, 'legacy visibility must not re-hide after the user enables the border')
local class = {statusTrackingBarsBorderOverride=true,statusTrackingBarsBorderUseClassColor=true}
migrate(class)
assert(class.statusTrackingBarsBorderColorSource == 'class')
local inherited = {statusTrackingBarsBorderOverride=false,statusTrackingBarsBorderUseClassColor=true,statusTrackingBarsHideBorder=true}
migrate(inherited)
assert(inherited.statusTrackingBarsBorderColorSource == 'inherit' and inherited.statusTrackingBarsHideBorder == true)
local canonical = {statusTrackingBarsBorderColorSource='theme',statusTrackingBarsBorderOverride=true,statusTrackingBarsBorderUseClassColor=true}
migrate(canonical)
assert(canonical.statusTrackingBarsBorderColorSource == 'theme', 'canonical source must win over legacy fields')
print('Status Tracking border migration passed')
