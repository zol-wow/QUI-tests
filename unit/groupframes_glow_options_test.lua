local ns = {}
assert(loadfile("core/group_frame_chrome.lua"))("QUI", ns)
local C = ns.QUI_GroupFrameChrome
local function Widget()
    local w = {groups = {}, width = 200, height = 40}
    function w:GetWidth() return self.width end
    function w:GetHeight() return self.height end
    function w:SetShown(v) self.shown = v end
    function w:SetPoint(...) self.point = {...} end
    function w:ClearAllPoints() self.point = nil end
    function w:SetAllPoints(v) self.allPoints=v end
    function w:SetTexture(v) self.texture=v end
    function w:SetColorTexture(...) self.color={...} end
    function w:SetVertexColor(r,g,b,a) self.vertex={r,g,b,a or 1}; self.alpha=a or 1 end
    function w:SetTexCoord(...) self.coords={...} end
    function w:SetSize(x,y) self.width,self.height=x,y end
    function w:SetBlendMode(v) self.blend=v end
    function w:SetGradient(...) self.gradient={...} end
    function w:Hide() self.shown=false end
    function w:Show() self.shown=true end
    function w:SetHeight(v) self.height=v end
    function w:SetWidth(v) self.width=v end
    function w:AddMaskTexture(v) self.mask=v end
    function w:CreateTexture() return Widget() end
    function w:CreateMaskTexture() return Widget() end

    function w:SetAlpha(a) self.alpha = a; if self.vertex then self.vertex[4]=a end end
    function w:SetScript() error("glow animation must remain scriptless") end
    function w:CreateAnimationGroup()
        local group = {animations = {}}
        function group:SetLooping(v) self.loop = v end
        function group:Play() self.playing = true; self.plays = (self.plays or 0) + 1 end
        function group:Stop() self.playing = false end
        function group:CreateAnimation(kind)
            assert(kind == "Alpha" or kind == "Path")
            local anim = {kind = kind, points = {}}
            function anim:SetCurveType(v) self.curve = v end
            function anim:CreateControlPoint()
                local point = {}
                function point:SetOrder(v) self.order = v end
                function point:SetOffset(x,y) self.x,self.y = x,y end
                self.points[#self.points+1] = point
                return point
            end
            for _, key in ipairs({"Target", "Order", "FromAlpha", "ToAlpha", "Duration", "StartDelay", "EndDelay", "Smoothing"}) do
                anim["Set" .. key] = function(self, v) self[key] = v end
            end
            group.animations[#group.animations + 1] = anim
            return anim
        end
        w.groups[#w.groups + 1] = group
        return group
    end
    return w
end
local owner, art = Widget(), {}
for _, key in ipairs({"glowTop", "glowTopRight", "glowRight", "glowBottomRight", "glowBottom", "glowBottomLeft", "glowLeft", "glowTopLeft"}) do art[key] = Widget() end

assert(type(C.ConfigureCleanseGlowAnimation) == "function", "shared glow animation controls are required")
C.ConfigureCleanseGlowAnimation(owner, art, {})
assert(#owner.groups == 0 and owner.alpha == 1, "legacy profiles remain static")
local config = {enabled = true, animation = "PULSE", animationDuration = 2}
C.ConfigureCleanseGlowAnimation(owner, art, config, 0.8)
local pulse = owner.groups[1]
assert(pulse.playing and pulse.loop == "REPEAT" and #pulse.animations == 2)
assert(pulse.animations[1].FromAlpha == 0.8 and math.abs(pulse.animations[1].ToAlpha - 0.28) < 0.0001)
assert(pulse.animations[1].Duration == 1 and pulse.animations[2].Order == 2)
C.ConfigureCleanseGlowAnimation(owner, art, config, 0.8)
assert(pulse.plays == 1, "refresh must not restart a running animation")
config.animation = "MOVING"
C.ConfigureCleanseGlowAnimation(owner, art, config, 0.8)
assert(not pulse.playing and owner.alpha == 0.8)
local state = owner._quiGlowAnimation
assert(state.travel and state.travel.playing and state.path and state.path.kind == "Path",
    "moving highlight must translate one localized spark instead of flashing whole edges")
assert(state.path.Target == art.glowMask and state.path.Duration == 2 and state.path.curve == "NONE")
assert(#state.path.points == 49 and art.movingHighlights)
assert(#state.travel.animations == 1, "one perimeter path must drive movement; no per-piece alpha animations")
assert(art._quiGlowBaseStrength == 0.35)
for _, key in ipairs(C.GLOW_PARTS) do assert(art[key].alpha == 1) end
assert(art.glowMask.point[4] == -4 and art.glowMask.point[5] == 4, "moving light must follow the glow's outer edge")
for _, key in ipairs(C.GLOW_PARTS) do
    local highlight=art.movingHighlights[key]
    assert(highlight.mask==art.glowMask and highlight.allPoints==art[key] and highlight.shown,
        "moving light must be clipped to exactly the same edge/corner geometry as the base glow")
end

local first, last = state.path.points[1], state.path.points[49]
assert(first.x == 0 and first.y == 0 and last.x == 0 and last.y == 0, "loop must close without a position jump")
for index = 2, #state.path.points do
    local p, q = state.path.points[index-1], state.path.points[index]
    assert((p.x == q.x or p.y == q.y), "path must follow the rectangle without cutting across corners")
    assert(p.x >= 0 and p.x <= 208 and p.y <= 0 and p.y >= -48)
end
local plays = state.travel.plays
C.ConfigureCleanseGlowAnimation(owner, art, config, 0.8)
assert(state.travel.plays == plays, "ordinary refresh must not restart the path")
owner.width = 300
C.ConfigureCleanseGlowAnimation(owner, art, config, 0.8)
assert(#state.path.points == 49 and state.width == 308 and state.travel.plays == plays + 1,
    "resizing must update the same path, without leaking points or groups")
config.animation = "NONE"
C.ConfigureCleanseGlowAnimation(owner, art, config)
for _, key in ipairs(C.GLOW_PARTS) do assert(art[key].alpha == 1) end
assert(not state.travel.playing and not art.movingHighlights.glowTop.shown, "static mode must stop and hide the moving highlight")
config.animation = "PULSE"
C.ConfigureCleanseGlowAnimation(owner, art, config)
config.enabled = false
C.ConfigureCleanseGlowAnimation(owner, art, config)
assert(not pulse.playing, "disabled glow must stop native animation timelines")
local legacy = {color = {0.1, 1, 0.1, 0.6}}
assert(C.GetCleanseGlowColor(legacy, "Bleed") == legacy.color)
assert(C.GetCleanseGlowOpacity(legacy) == 0.6, "old saved color alpha remains effective")
legacy.opacity = 0.45
assert(C.GetCleanseGlowOpacity(legacy) == 0.45, "new opacity setting overrides legacy color alpha")
local typed = {colorMode = "TYPE", colors = {Bleed = {0.9, 0.2, 0.1, 1}}}
assert(C.GetCleanseGlowColor(typed, "Enrage") == typed.colors.Bleed)
local map = C.GetCleanseGlowColorMap(typed)
for _, key in ipairs({"Magic", "Curse", "Disease", "Poison", "Bleed"}) do assert(map[key], key) end
assert(map.Bleed == typed.colors.Bleed and map.Poison[2] == 0.6)
-- Drive real glow construction: moving pieces must use the same tint and
-- corner UVs, rather than just sharing a similarly sized frame rectangle.
_G.CreateColor=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end
local rendered, renderArt = Widget(), {}
for _, appearance in ipairs({{0.45,1},{0,1},{nil,1},{1,0.65}}) do
    local glow, pieces = Widget(), {}
    C.StyleCleanseGlowArt(glow, pieces, glow, {0.3,0.5,0.8,0.7}, appearance[1])
    for _, mode in ipairs({"NONE","PULSE","MOVING","NONE","MOVING","PULSE"}) do
        C.ConfigureCleanseGlowAnimation(glow, pieces, {enabled=true,animation=mode}, appearance[2])
        local expected=appearance[1] or 0.7
        for _, key in ipairs(C.GLOW_PARTS) do
            assert(pieces[key].alpha==expected and pieces[key].vertex[4]==expected,
                mode.." must preserve configured texture opacity on every glow edge and corner")
            if mode=="MOVING" then
                assert(pieces.movingHighlights[key].alpha==expected,
                    "moving highlights must preserve the same configured opacity as the base")
            end
        end
        assert(glow.alpha==appearance[2],"texture opacity must not change the animation owner's opacity")
    end
end
C.StyleCleanseGlowArt(rendered, renderArt, rendered, {0.3, 0.5, 0.8, 0.7})
C.ConfigureCleanseGlowAnimation(rendered, renderArt, {enabled=true,animation="MOVING"})
for _, key in ipairs(C.GLOW_PARTS) do
    local base, moving = renderArt[key], renderArt.movingHighlights[key]
    assert(moving.allPoints==base and moving.mask==renderArt.glowMask)
    assert(not base.gradient and not moving.gradient, "all edge and corner pieces must use asset alpha and vertex tint")
    assert(moving.texture == base.texture)
    for channel=1,3 do
        assert(math.abs(base.vertex[channel] - moving.vertex[channel]*0.35)<0.00001,
            "all base pieces must have the same dim tint without independent animations")
    end
    assert(base.vertex[4] == moving.vertex[4])
    if base.coords then
        for index,value in ipairs(base.coords) do assert(moving.coords[index]==value, "corner flips must match the static outline") end
    end
end
C.ConfigureCleanseGlowAnimation(rendered, renderArt, {enabled=true,animation="NONE"})
assert(renderArt._quiGlowBaseStrength==1)
assert(renderArt.glowTop.vertex[1]==0.3 and renderArt.glowTopLeft.vertex[1]==0.3,
    "leaving Moving must restore the same full tint on sides and corners")
local dimMap=C.GetCleanseGlowColorMap(typed,0.35)
assert(math.abs(dimMap.Magic[3]-0.35)<0.00001 and typed.colors.Bleed[1]==0.9,
    "native type maps must dim base tint without modifying configured colors")
local file=assert(io.open("assets/group_frame_glow_spark.tga","rb"))
local data=file:read("*a"); file:close()
local peak=0
for index=22,#data,4 do peak=math.max(peak,data:byte(index)) end
assert(peak>150 and 0.35+peak/255<=1, "moving mask must not overbrighten the baseline at corners")
print("OK: groupframes_glow_options_test")
