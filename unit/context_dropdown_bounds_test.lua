local path=os.getenv('QUI_SURFACE_SOURCE') or 'core/settings/full_surface.lua'
local file=assert(io.open(path)); local source=file:read('*a'); file:close()
local body=assert(source:match('(function FullSurface.BuildContextDropdownRow.-)\nfunction FullSurface.CreateTabStrip'))
local function frame(parent)
 local f={parent=parent,width=0,points={},scripts={}}
 function f:SetHeight(h) self.height=h end
 function f:SetPoint(...) self.points[#self.points+1]={...} end
 function f:ClearAllPoints() self.points={} end
 function f:SetWidth(w) self.width=w end
 function f:GetWidth() return self.width end
 function f:GetTop() return self.top end
 function f:HookScript(event,fn) local prior=self.scripts[event]; self.scripts[event]=function(...) if prior then prior(...) end; fn(...) end end
 return f
end
local repair
local ns={L={},QUI_SettingsLayoutShared={VerifyInitialBounds=function(row,parent,fn) repair=function() fn(row) end end}}
local surface={}
local env=setmetatable({FullSurface=surface,ns=ns,CreateFrame=function(_,_,parent) return frame(parent) end},{__index=_G})
local chunk=assert(loadstring(body,'context-row')); setfenv(chunk,env); chunk()
local parent=frame();parent.width=900
local gui={CreateFormDropdown=function(_,p) return frame(p) end}
local result=surface.BuildContextDropdownRow(parent,{gui=gui,label='Type'})
assert(repair,'context selector must recover missing native bounds through the shared verifier')
repair()
assert(result.row.width==884 and #result.row.points==1,'recovered context row must use an explicit available width')
parent.width=700;parent.scripts.OnSizeChanged()
assert(result.row.width==684,'recovered context selector must follow parent resizing')
print('OK: context_dropdown_bounds_test')

assert(result.dropdown:GetWidth()==380,'context selector must stay compact on wide pages')
parent.width=300;parent.scripts.OnSizeChanged()
assert(result.dropdown:GetWidth()==284,'compact selector must fit narrow pages')
