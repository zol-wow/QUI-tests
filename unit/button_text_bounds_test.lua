local ns={}; assert(loadfile(os.getenv('QUI_LAYOUT_SOURCE') or 'core/settings_layout_shared.lua'))('QUI',ns)
local frame={top=80}
function frame:SetScript(_,fn) self.update=fn end
function frame:GetTop() return self.top end
function frame:Hide() self.hidden=true end
function frame:Show() self.hidden=false; self.shown=true end
local parent={GetTop=function() return 100 end}
local text={GetTop=function(self) return self.top end}
local repaired=false
ns.QUI_SettingsLayoutShared.VerifyInitialBounds(frame,parent,function() repaired=true;text.top=80 end,text)
frame.update(frame); assert(not repaired,'recovery must wait for the initial native layout')
frame.update(frame)
assert(repaired and frame.shown,'a positioned button with unpositioned text must repair its text bounds')
assert(not frame.update,'initial recovery must stop after verification')
print('OK: button_text_bounds_test')
