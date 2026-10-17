local f=assert(io.open(os.getenv("QUI_FRAMEWORK_SOURCE") or "QUI_Options/framework.lua"))
local source=f:read("*a");f:close()
local place=assert(source:match("    local function PlaceToggle%(%)\n(.-)\n    end\n    PlaceToggle%(%)"),"standalone toggles need responsive placement")
local width=1000
local anchors={}
local toggle={ClearAllPoints=function() anchors={} end,SetPoint=function(_,...) anchors={...} end}
local container={GetWidth=function() return width end}
local env=setmetatable({toggle=toggle,container=container,label="Enable",togglePoint="RIGHT"},{__index=_G})
local apply=assert(loadstring(place,"toggle-placement"));setfenv(apply,env)
apply();assert(anchors[1]=="LEFT" and anchors[4]==452,"wide standalone toggles must end at the first column")
width=480;apply();assert(anchors[1]=="RIGHT","narrow standalone toggles must fit their available width")
env.label=nil;width=1000;env.togglePoint="LEFT";apply();assert(anchors[1]=="LEFT" and anchors[4]==0,"unlabeled card toggles retain their compact control bounds")
local block=assert(source:match("    local SLIDER_TRACK_WIDTH.-(    local SLIDER_TRACK_HEIGHT.-)\n    local trackBg"))
local slider={SetSize=function(_,w,h) anchors.size={w,h} end,SetPoint=function() end,SetOrientation=function() end,SetHitRectInsets=function(_,...) anchors.hit={...} end}
env.CreateFrame=function() return slider end;env.SLIDER_TRACK_WIDTH=120;env.sliderLeftOffset=0
local build=assert(loadstring(block,"slider-target"));setfenv(build,env);build()
assert(anchors.hit[1]<=-7 and anchors.hit[2]<=-7 and anchors.hit[3]<=-12 and anchors.hit[4]<=-12,"slider endpoints need generous hit areas clear of numeric controls")
print("OK: options_control_usability_test")
