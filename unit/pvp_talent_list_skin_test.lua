local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin = env.SkinBase
local function frame(kind, parent)
    local f = env.NewFrame(kind or "Frame", nil, parent)
    f.RegisterForWidgetSet = false; f.DisabledTexture = false
    return f
end
local owner = frame(); owner.TalentsFrame = frame(nil, owner)
local list = frame(nil, owner.TalentsFrame); owner.TalentsFrame.PvPTalentList = list
list.ScrollBox = frame(nil, list)
list.Top=list:CreateTexture(); list.Middle=list:CreateTexture(); list.Bottom=list:CreateTexture()
local row=frame("Button",list.ScrollBox)
row.Icon=row:CreateTexture(); row.Icon.SetDesaturated=function(self,v) self.desaturated=v end
row.CreateMaskTexture=row.CreateTexture; row.Icon.AddMaskTexture=function(self,m) self.mask=m end
row.Name=row:CreateFontString(); row.New=row:CreateFontString(); row.NewGlow=row:CreateTexture()
for _,key in ipairs({"Border","Selected","SelectedOtherCheck","Highlight"}) do row[key]=row:CreateTexture() end
function row:GetHighlightTexture() return self.Highlight end
local nativeClick=function() error("PvP talent selection invoked") end
row:SetScript("OnClick",nativeClick)
local info={ unlocked=true, name="Existing talent", icon="native-talent-icon" }
_G.C_SpecializationInfo={ GetPvpTalentInfo=function() return info end, IsPvpTalentLocked=function() return false end }
local function color(r,g,b) return {GetRGB=function() return r,g,b end} end
_G.DISABLED_FONT_COLOR=color(.5,.5,.5); _G.YELLOW_FONT_COLOR=color(1,1,0); _G.HIGHLIGHT_FONT_COLOR=color(1,1,1)
_G.GameTooltip={ GetOwner=function() return nil end }
local nativeFile=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_PlayerSpells/PvPTalents/Blizzard_PvPTalentListTemplates.lua"))
local native=nativeFile:read("*a");nativeFile:close()
_G.PvPTalentListButtonMixin={}
assert(loadstring(assert(native:match("(function PvPTalentListButtonMixin:Update%(%).-\nend)\n\nfunction"))))()
row.Update=_G.PvPTalentListButtonMixin.Update
row.selectedHere=true; row.selectedOther=false; row.talentID=1; row:Update()
local acquired
_G.ScrollUtil.AddAcquiredFrameCallback=function(_,callback) acquired=callback end
_G.C_Timer.After=function(_,callback) callback() end
function list.ScrollBox:ForEachFrame(fn) fn(row) end
function list.ScrollBox:HasView() return true end
local file=assert(io.open(os.getenv("QUI_JOURNALS_SOURCE") or "modules/skinning/frames/journals.lua"))
local source=file:read("*a");file:close()
local first=assert(source:find("local function StylePvPTalentRow(",1,true))
local last=assert(source:find("local function StylePlayerSpellsControls(",first,true))
local chunk=assert(loadstring(source:sub(first,last-1).."\nreturn StylePvPTalentList"))
setfenv(chunk,setmetatable({SkinBase=skin,IsSettingEnabled=function() return true end},{__index=_G}))
local apply=chunk()
apply(owner)
assert(skin.GetBackdrop(list)._quiRoundedSurface.radius==6 and list.Top:GetAlpha()==0,
    "PvP flyout must replace native backdrop with rounded QUI chrome")
assert(row.Icon:GetAlpha()==1 and row.Icon.texture=="native-talent-icon" and row.Icon.mask,
    "talent identity and rounded icon must remain visible")
assert(row.Selected:GetAlpha()==0 and row.Highlight:GetAlpha()==0,
    "native selection and hover artwork must not bleed through")
assert(row.Name.textColor[1]==1 and row.Name.textColor[2]==1 and row:GetAlpha()==1,
    "selected current talent must retain native yellow text and opacity")
local backdrop=skin.GetBackdrop(row)
local accent=skin.GetChromePalette().accent
local function sameColor(a,b) return a[1]==b[1] and a[2]==b[2] and a[3]==b[3] and a[4]==b[4] end
assert(sameColor(skin.GetFrameData(row,"windowColor"),accent),"selected talent must retain accented border after hover leave")
row.selectedHere=false;row.selectedOther=true;row:Update()
assert(row:GetAlpha()==.4 and row.Name.textColor[2]==1 and not row.disallowNormalClicks,
    "talent used in another slot must retain native dimming and state")
assert(not sameColor(skin.GetFrameData(row,"windowColor"),accent),"pooled row must clear former selected border")
info.unlocked=false;row.selectedOther=false;row:Update()
assert(row.disallowNormalClicks and row.Icon.desaturated and row.Name.textColor[1]==.5,
    "native unavailable talent state must survive styling")
info.unlocked=true;info.dependenciesUnmet=true;row:Update()
assert(row.Icon.vertex[1]==.9 and row.Icon.vertex[2]==0,
    "unmet dependency icon color must remain semantic")
acquired(nil,row);list:Fire("OnShow");apply(owner)
assert(skin.GetBackdrop(row)==backdrop and row:GetScript("OnClick")==nativeClick,
    "pooling/reopen/theme must reuse chrome without replacing selection handler")
print("PvP talent flyout passed")
