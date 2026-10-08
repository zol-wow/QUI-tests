local file=assert(io.open(os.getenv("QUI_BUILDERS_SOURCE") or "core/settings_builders.lua"))
local source=file:read("*a");file:close()
local block=assert(source:match("(local function ApplyDualColumnLayout%(section%).-)\nlocal function ApplyDualColumnLayoutWhenReady"))
local function Node(parent)
 local n={children={},points={},shown=true,width=1000,height=28}
 if parent then parent.children[#parent.children+1]=n end
 function n:GetChildren() return unpack(self.children) end
 function n:GetWidth() return self.width end
 function n:GetHeight() return self.height end
 function n:IsShown() return self.shown end
 function n:Show() self.shown=true end
 function n:Hide() self.shown=false end
 function n:SetPoint(...) self.points[#self.points+1]={...} end
 function n:ClearAllPoints() self.points={} end
 function n:SetHeight(h) self.height=h end
 function n:SetWidth(w) self.width=w end
 function n:SetAllPoints() end
 function n:SetColorTexture() end
 function n:CreateTexture() return Node() end
 return n
end
local ns = {}
assert(loadfile("core/settings_layout_shared.lua"))("QUI", ns)
local env=setmetatable({ns=ns,CreateFrame=function(_,_,p) return Node(p) end,
 GetInitialLayoutY=function(item) return item.y end,GetDualColumnRowHeight=function() return 28 end,
 dualColumnSequence=0,CARD_ROW_HEIGHT=28},{__index=_G})
local load=assert(loadstring(block.."\nreturn ApplyDualColumnLayout"));setfenv(load,env);local apply=load()
local function Check(count,compact,expected)
 local body=Node();local last
 for i=1,count do
  last=Node(body);last.y=-i*32;last.label={}
  if compact then last.track={GetWidth=function() return 26 end} end
 end
 apply({_body=body})
 assert(last.points[1][2]._divider.shown,"a singleton must retain its column-ending divider")
 local p=last.points[2]
 assert(p[3]==expected,"unmatched provider setting must end at its column boundary")
 if expected=="LEFT" then assert(p[4]==(body.width+4)/3-12,"unmatched compact setting retains three-column width") end
end
Check(1,false,"CENTER")
Check(3,false,"CENTER")
Check(4,true,"LEFT")
print("OK: options_provider_column_bounds_test")
