local function Frame(parent)
    local frame = { parent = parent, shown = true, parentChanges = 0 }
    function frame:GetParent() return self.parent end
    function frame:SetParent(value)
        self.parent = value
        self.parentChanges = self.parentChanges + 1
    end
    function frame:SetScript(event, fn) self[event] = fn end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsVisible()
        return self.shown and (not self.parent or self.parent:IsVisible())
    end
    return frame
end

for _, containerType in ipairs({ "cooldown", "auraBar" }) do
    local ticker, acquisitions, configurations = nil, 0, 0
    _G.CreateFrame = function(_, _, parent)
        ticker = Frame(parent)
        return ticker
    end
    _G.QUI_GetCDMContainerDB = function()
        return { containerType = containerType, ownedSpells = { { spellID = 123 } } }
    end
    local function Acquire(parent)
        acquisitions = acquisitions + 1
        local frame = Frame(parent)
        frame.style = { font = "Quazii", color = "class" }
        return frame
    end
    local ns = {
        CDMIconFactory = {
            AcquireForPreview = Acquire,
            ReleaseForPreview = function(icon) icon:Hide(); icon:SetParent(nil) end,
        },
        CDMBars = {
            CreateForPreview = Acquire,
            ConfigureBar = function() configurations = configurations + 1 end,
        },
    }
    assert(loadfile("QUI_CDM/cdm/settings/composer_preview_driver.lua"))("QUI", ns)
    local driver = ns.CDMComposerPreview
    local first, second = Frame(), Frame()
    driver.Build(first)
    driver.Refresh("essential")
    local specimen = assert(driver.GetContentFrames()[1])
    local initialTicker, tickHandler, style = ticker, ticker.OnUpdate, specimen.style
    assert(specimen:GetParent() == first and specimen:IsVisible())

    driver.Build(first)
    assert(specimen.parentChanges == 0 and ticker == initialTicker and ticker.OnUpdate == tickHandler,
        "same-host builds must preserve cached specimens and ticker effects")
    first:Hide()
    driver.Build(second)
    assert(driver.GetContentFrames()[1] == specimen and acquisitions == 1,
        "switching hosts must reuse the existing specimen")
    assert(specimen:GetParent() == second and specimen:IsVisible(),
        containerType .. " specimen must move out of the hidden prior host")
    assert(ticker == initialTicker and ticker.OnUpdate == tickHandler and ticker:GetParent() == second,
        "host switches must preserve the animation ticker and its handler")
    assert(specimen.style == style and configurations == (containerType == "auraBar" and 1 or 0),
        "host switches must preserve specimen style and configuration")

    first:Show()
    second:Hide()
    driver.Build(first)
    assert(specimen:GetParent() == first and specimen:IsVisible() and acquisitions == 1,
        "returning to a prior host must restore its retained specimen")
    driver.Teardown()
    driver.Build(first)
    driver.Refresh("essential")
    assert(driver.GetContentFrames()[1]:GetParent() == first
        and driver.GetContentFrames()[1]:IsVisible(),
        "teardown and rearm must still reacquire a visible specimen")
end

print("OK: cdm_composer_preview_host_switch_test")
