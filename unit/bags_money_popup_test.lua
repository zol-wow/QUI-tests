local loader = dofile("tests/helpers/load_bags_data.lua")
loader.InstallBaseStubs()

_G.ACCEPT = "Accept"
_G.CANCEL = "Cancel"
_G.StaticPopupDialogs = {}
_G.StaticPopup_Hide = function() end

local shown
_G.StaticPopup_Show = function(key)
    shown = key
end

local resetFrame
_G.MoneyInputFrame_GetCopper = function(frame)
    return frame.amount
end
_G.MoneyInputFrame_ResetMoney = function(frame)
    resetFrame = frame
end

local ns = loader.LoadAll()
ns.Helpers = {}
(dofile("tests/helpers/locale.lua"))(ns)
assert(loadfile("QUI_Bags/bags/views/chassis.lua"))("QUI", ns)

local accepted
ns.Bags.Chassis.ShowMoneyPopup("QUI_TEST_MONEY", "deposit", function(depositing, amount)
    accepted = { depositing = depositing, amount = amount }
end)

assert(shown == "QUI_TEST_MONEY", "money popup must be shown")
local popup = assert(StaticPopupDialogs.QUI_TEST_MONEY, "money popup definition required")
assert(popup.hasMoneyInputFrame and not popup.hasEditBox,
    "money popup must expose gold, silver, and copper fields")

local moneyFrame = { amount = 10203 }
local dialog = { MoneyInputFrame = moneyFrame }
popup.OnAccept(dialog)
assert(accepted.depositing and accepted.amount == 10203,
    "money popup must preserve the exact copper total")

local hidden = false
function dialog.Hide()
    hidden = true
end
function moneyFrame.GetParent()
    return dialog
end
local box = {}
function box.GetParent()
    return moneyFrame
end
moneyFrame.amount = 40506
popup.EditBoxOnEnterPressed(box)
assert(accepted.amount == 40506 and hidden,
    "enter from any denomination field must submit and close the popup")

popup.OnHide(dialog)
assert(resetFrame == moneyFrame, "money popup must reset its denomination fields")

accepted = nil
ns.Bags.Chassis.ShowMoneyPopup("QUI_TEST_MONEY", "withdraw", function(depositing, amount)
    accepted = { depositing = depositing, amount = amount }
end)
popup = StaticPopupDialogs.QUI_TEST_MONEY
moneyFrame.amount = 70809
popup.OnAccept(dialog)
assert(not accepted.depositing and accepted.amount == 70809,
    "withdrawals must preserve the exact copper total")

print("OK: bags_money_popup_test")
