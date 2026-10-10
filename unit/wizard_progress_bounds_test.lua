local path=os.getenv('QUI_WIZARD_SOURCE') or 'core/settings/content/auras_wizard_page.lua'
local f=assert(io.open(path));local source=f:read('*a');f:close()
local first=assert(source:find('    local railRow = CreateFrame',1,true))
local last=assert(source:find('    y = y + 24 + 16',first,true))
local block=source:sub(first,last-1)
for _,steps in ipairs({{'role','surfaces','review'},{'role','surfaces','partyAuras','placeHoTs','review'}}) do
 for current=1,#steps do
  local buttons={};local row
  local GUI={CreateButton=function(_,parent,text,width,height,callback,style)
   assert(parent.width and parent.width>=#steps*122,'Progress row must have bounds before child buttons are created')
   local b={text=text,width=width,height=height,callback=callback,style=style,SetPoint=function(self,_,p,_,x) self.x=x;self.parent=p end}
   buttons[#buttons+1]=b;return b
  end}
  local rerender=0
  local ctx={state={wizardStep=current},RerenderSection=function(_,id) assert(id=='settings');rerender=rerender+1 end}
  local env=setmetatable({GUI=GUI,ctx=ctx,steps=steps,STEP_LABELS={role='Role',surfaces='Surfaces',partyAuras='Party auras',placeHoTs='Place HoTs',review='Review'},host={},section={id='settings'},y=0,CreateFrame=function()
   row={SetPoint=function() end,SetHeight=function(self,h) self.height=h end,SetWidth=function(self,w) self.width=w end};return row
  end},{__index=_G})
  local run=assert(loadstring(block));setfenv(run,env);run()
  assert(#buttons==#steps and row.height==24)
  for i,b in ipairs(buttons) do
   assert(b.x==(i-1)*122 and b.width==116 and b.height==24)
   assert((b.style=='primary')==(i==current))
  end
  local target=current==1 and #steps or 1;buttons[target].callback();assert(ctx.state.wizardStep==target and rerender==1)
 end
end
print('Wizard progress bounds: 3 and 5 steps, all active states passed')
local addFirst=assert(source:find('    local addRow = CreateFrame',1,true))
local addLast=assert(source:find('    local input = CreateFrame',addFirst,true))
local row={SetPoint=function(self,point,relative,relativePoint) self[point]={relative,relativePoint} end,SetHeight=function(self,h) self.height=h end}
local host={}
local env=setmetatable({CreateFrame=function() return row end,host=host,y=48},{__index=_G})
local run=assert(loadstring(source:sub(addFirst,addLast-1)));setfenv(run,env);run()
assert(row.TOPLEFT and row.RIGHT and row.RIGHT[1]==host,'HoT add row must span its host before child controls are created')
assert(row.height==24)
print('Wizard HoT input row bounds passed')
