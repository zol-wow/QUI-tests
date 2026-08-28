-- tests/unit/skinning_protected_defer_lifecycle_test.lua
-- Run: lua tests/unit/skinning_protected_defer_lifecycle_test.lua
--
-- Guard the protected-frame defers in ObjectiveTracker and OverrideActionBar.
-- C_Timer.After is only AllowedWhenUntainted in local API docs, so fixed
-- "wait long enough" delays must be replaced by the relevant Blizzard lifecycle
-- plus a named next-frame escape from the protected call stack.

local function readFile(path)
    local fh = assert(io.open(path, "rb"), "failed to open " .. path)
    local text = fh:read("*a")
    fh:close()
    return text
end

local function assertContains(text, needle, reason)
    assert(text:find(needle, 1, true), reason)
end

local function assertAbsent(text, needle, reason)
    assert(not text:find(needle, 1, true), reason)
end

local timerDocs = readFile("tests/framexml/Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua")
assertContains(timerDocs, 'Name = "After"', "local API docs must describe C_Timer.After")
assertContains(timerDocs, 'SecretArguments = "AllowedWhenUntainted"',
    "C_Timer.After must be treated as an untainted scheduling API, not a taint escape")

local dirtyMixin = readFile("tests/framexml/Interface/AddOns/Blizzard_SharedXML/MixinUtil.lua")
assertContains(dirtyMixin, "RunNextFrame(self.dirtyCallback);",
    "ObjectiveTracker dirty layout is already a next-frame lifecycle in local FrameXML")

local objectiveFrameXML = readFile("tests/framexml/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerContainer.lua")
assertContains(objectiveFrameXML, "function ObjectiveTrackerContainerMixin:Update(dirtyUpdate)",
    "ObjectiveTracker container Update is the owner lifecycle for post-layout anchoring")
assertContains(objectiveFrameXML, "function ObjectiveTrackerContainerMixin:UpdateHeight()",
    "ObjectiveTracker height is owned by the container lifecycle")

local overrideFrameXML = readFile("tests/framexml/Interface/AddOns/Blizzard_OverrideActionBar/OverrideActionBar.lua")
assertContains(overrideFrameXML, "function OverrideActionBarMixin:UpdateSkin()",
    "OverrideActionBar UpdateSkin is the owner lifecycle before QUI reskins")
assertContains(overrideFrameXML, "self:Setup(C_ActionBar.GetOverrideBarSkin(), C_ActionBar.GetOverrideBarIndex());",
    "OverrideActionBar UpdateSkin must be treated as a Blizzard reset point")
assertContains(overrideFrameXML, "self.HasExit, self.HasPitch = select(6, ...);",
    "OverrideActionBar must derive exit visibility from Blizzard's vehicle event")
assertContains(overrideFrameXML, "self.leaveFrame:Show();",
    "OverrideActionBar must show its leave frame when Blizzard reports an exit")

local overrideFrameXMLLayout = readFile("tests/framexml/Interface/AddOns/Blizzard_OverrideActionBar/OverrideActionBar.xml")
assertContains(overrideFrameXMLLayout, '<Frame name="$parentLeaveFrame" parentKey="leaveFrame" useParentLevel="true">',
    "OverrideActionBar must expose its Blizzard-owned leave frame")
assertContains(overrideFrameXMLLayout, '<Button name="$parentLeaveButton" parentKey="LeaveButton">',
    "OverrideActionBar leave button must remain a child of the Blizzard-owned leave frame")

local actionBarController = readFile("tests/framexml/Interface/AddOns/Blizzard_ActionBarController/ActionBarController.lua")
assertContains(actionBarController, "OverrideActionBar:UpdateSkin();",
    "ActionBarController must drive OverrideActionBar through UpdateSkin")
assertContains(actionBarController, "ValidateActionBarTransition();",
    "OverrideActionBar show/animation follows the controller lifecycle")

local objectiveSource = readFile("modules/skinning/gameplay/objectivetracker.lua")
assertAbsent(objectiveSource, "C_Timer.After(0.15",
    "ObjectiveTracker protected post-layout updates must not use a fixed 0.15s delay")
assertContains(objectiveSource, "local function DeferObjectiveTrackerPostLayoutUpdate()",
    "ObjectiveTracker must use a named post-layout defer helper")
assertAbsent(objectiveSource, 'hooksecurefunc(TrackerFrame, "Update"',
    "ObjectiveTracker cosmetics must not attach to Blizzard's owner update lifecycle")
assertAbsent(objectiveSource, 'TrackerFrame:HookScript("OnSizeChanged"',
    "ObjectiveTracker cosmetics must not enter Blizzard's dirty resize lifecycle")

local overrideSource = readFile("modules/skinning/frames/overrideactionbar.lua")
assertAbsent(overrideSource, "C_Timer.After(0.15",
    "OverrideActionBar protected post-update skinning must not use a fixed 0.15s delay")
assertContains(overrideSource, "local function DeferOverrideActionBarPostUpdate()",
    "OverrideActionBar must use a named post-UpdateSkin defer helper")
assertContains(overrideSource, 'hooksecurefunc(bar, "UpdateSkin"',
    "OverrideActionBar must anchor reskinning to Blizzard's UpdateSkin lifecycle")
assertContains(overrideSource, "FrameXML OverrideActionBarMixin:UpdateSkin resets skin, size, actionpage, buttons, and status bars",
    "OverrideActionBar defer helper must document the FrameXML lifecycle reason")
assertAbsent(overrideSource, "if not bar or SkinBase.IsSkinned(bar) then return end",
    "OverrideActionBar UpdateSkin can reset an already-skinned bar, so post-update reskinning must stay idempotent")
assertAbsent(overrideSource, "MicroMenu",
    "OverrideActionBar skinning must leave the native MicroMenu lifecycle and layout state Blizzard-owned")
assertAbsent(overrideSource, "bar.leaveFrame:SetAlpha(",
    "OverrideActionBar skinning must not hide the Blizzard-owned leave button through its parent alpha")
assertAbsent(overrideSource, "bar.LeaveButton:Show()",
    "OverrideActionBar skinning must leave exit availability and visibility Blizzard-owned")

print("OK: skinning_protected_defer_lifecycle_test")
