local feature,relayout,route
local ns={Settings={SurfaceFeatures={Register=function(_,f)feature=f end}}}
local function Frame(parent)
 return {parent=parent,height=0,SetPoint=function()end,SetHeight=function(self,h)self.height=h end,
 GetHeight=function(self)return self.height end}
end
_G.CreateFrame=function(_,_,parent)return Frame(parent)end
local height=300
ns.QUI_LayoutMode_Utils={
 BuildPositionCollapsible=function(host,_,_,_,callback)route=host;relayout=callback end,
 BuildOpenFullSettingsLink=function()end,
 StandardRelayout=function(host)host:SetHeight(height)end,
}
assert(loadfile("QUI_GroupFrames/groupframes/settings/group_frames.lua"))("QUI",ns)
local host=Frame();host._quiCompactLayout=true;host._quiLayoutGeneration=1
assert(feature.render.layout(host,{providerKey="partyFrames"})==300)
assert(route._quiCompactLayout, "nested Group Frames controls must inherit compact Layout Mode spacing")
height=120;relayout()
assert(host:GetHeight()==120, "settled Group Frames layout must update the settings host height")
host._quiLayoutGeneration=2;height=600;relayout()
assert(host:GetHeight()==120, "retired Group Frames callback must not resize the next provider")
print("OK: group frames layout height propagation")
