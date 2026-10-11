local file=assert(io.open('QUI_Options/framework.lua'));local source=file:read('*a');file:close()
local first=assert(source:find('function GUI:RenderSubPageTabs(',1,true))
local last=assert(source:find('function GUI:RenderSectionNav(',first,true))
local function Frame()
 local f={shown=true}
 return setmetatable(f,{__index=function(_,key)
  if key=='IsShown' then return function(self)return self.shown end end
  if key=='Hide' then return function(self)self.shown=false end end
  if key=='Show' then return function(self)self.shown=true end end
  return function()end
 end})
end
local counts={}
local gui={GetTileNavigationPages=function()end,Tooltip={Hide=function()end},RecordSettingsPerformance=function()end}
local env=setmetatable({GUI=gui,CreateFrame=Frame,ns={L=setmetatable({},{__index=function(_,key)return key end})},
 installRegisterSection=function(body)body._sections={} end,StartSettingsPerformance=function()end},{__index=_G})
local chunk=assert(loadstring(source:sub(first,last-1)));setfenv(chunk,env);chunk()
local pages={{id='one',noScroll=true,sectionNav=true},{id='two',noScroll=true,sectionNav=true},{id='three',noScroll=true,sectionNav=true}}
local tile={id='test',config={subPages=pages}}
gui:RenderSubPageTabs(tile,Frame(),pages,function(page)counts[page.id]=(counts[page.id]or 0)+1 end,nil,3)
assert(counts.three==1 and counts.one==nil and counts.two==nil,'initial direct navigation must build only its requested body')
assert(tile._subPageBodies[1]==nil and tile._subPageBodies[2]==nil)
tile._subPageSelect(1);assert(counts.one==1 and counts.two==nil)
tile._subPageSelect(3);assert(counts.three==1,'cached revisits must preserve the original body')
tile._subPageSelect(3);assert(counts.three==1,'selecting current body must not rebuild it')
local firstBody=tile._subPageBodies[1]
local hides=0;firstBody.Hide=function(self)hides=hides+1;self.shown=false end
tile._subPageSelect(1);local before=hides;tile._subPageSelect(1)
assert(hides==before,'current body must not be hidden and reshown during navigation')
print('OK: options_lazy_body_test')
