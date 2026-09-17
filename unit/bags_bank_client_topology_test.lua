local loader = dofile("tests/helpers/load_bags_data.lua")

for _, client in ipairs({
    { path = "tests/api-docs/blizzard", charLast = 11, accountFirst = 12, accountLast = 16 },
    { path = "tests/clients/forever/api-docs/blizzard", charLast = 14, accountFirst = 15, accountLast = 23 },
}) do
    local bagIndex = {}
    APIDocumentation = { AddDocumentationTable = function(_, doc)
        for _, field in ipairs(doc.Tables[1].Fields) do bagIndex[field.Name] = field.EnumValue end
    end }
    dofile(client.path .. "/BagIndexConstantsDocumentation.lua")
    Enum = { BagIndex = bagIndex, BankType = { Character = 0, Account = 2 } }
    loader.InstallBaseStubs()
    C_Container.GetContainerNumSlots = function() return 1 end
    C_Container.GetContainerItemInfo = function(bagID)
        return { itemID = 1000 + bagID, stackCount = 1, quality = 1, iconFileID = 1 }
    end
    C_Container.GetContainerNumFreeSlots = function() return 0, 0 end
    C_Bank.FetchBankLockedReason = function() return nil end
    C_Bank.FetchDepositedMoney = function() return 0 end
    C_Bank.FetchPurchasedBankTabData = function(bankType)
        if bankType == Enum.BankType.Character then
            return { { ID = 6, name = "First" }, { ID = client.charLast, name = "Last" } }
        end
        return { { ID = client.accountFirst, name = "First" }, { ID = client.accountLast, name = "Last" } }
    end
    C_Item.GetItemFamily = function() return 0 end
    CursorHasItem = function() return false end

    local ns = loader.LoadAll(nil, "scan_bank.lua")
    ns.Helpers = { CreateDBGetter = function() return function() return {} end end }
    (dofile("tests/helpers/locale.lua"))(ns)
    QUI_StorageDB = nil
    ns.Storage.Store.Initialize()
    ns.Storage.Store.EnsureCurrentCharacter()
    local scan = ns.Storage.ScanBank
    assert(scan.IsCharTab(client.charLast) and not scan.IsWarbandTab(client.charLast))
    assert(scan.IsWarbandTab(client.accountFirst) and not scan.IsCharTab(client.accountFirst))
    assert(scan.IsWarbandTab(client.accountLast) and not scan.IsWarbandTab(client.accountLast + 1))
    scan.RefreshTabMetadata()
    scan.MarkDirty(client.charLast)
    scan.MarkDirty(client.accountLast)
    assert(scan.Drain())
    local character = ns.Storage.Store.GetCurrentCharacter()
    local account = ns.Storage.Store.GetWarband()
    assert(character.bankTabs[client.charLast].slots[1].itemID == 1000 + client.charLast)
    assert(account.tabs[client.accountLast].slots[1].itemID == 1000 + client.accountLast)
    assert(account.tabs[client.charLast] == nil and character.bankTabs[client.accountLast] == nil)
    scan.MarkAllDirty()
    assert(scan.Drain())

    ns.Bags.Chassis = { MakeScheduleRefresh = function() return function() end end }
    assert(loadfile("QUI_Bags/bags/views/bank_window.lua"))("QUI", ns)
    local window = ns.Bags.BankWindow
    local tabs = window.BuildTabList(character, account)
    assert(#tabs == 6 and tabs[2].bagID == 6 and tabs[3].bagID == client.charLast)
    assert(tabs[5].bagID == client.accountFirst and tabs[6].bagID == client.accountLast)
    assert(window.BankTypeForBagID(client.charLast) == Enum.BankType.Character)
    assert(window.BankTypeForBagID(client.accountFirst) == Enum.BankType.Account)

    local planned
    ns.Bags.SortPlanner = { Plan = function(containers) planned = containers; return {} end }
    assert(loadfile("QUI_Bags/bags/ops/shared.lua"))("QUI", ns)
    assert(loadfile("QUI_Bags/bags/ops/sort_executor.lua"))("QUI", ns)
    assert(ns.Bags.SortExecutor.Start("characterBank"))
    assert(#planned == client.charLast - 5 and planned[1].bagID == 6
        and planned[#planned].bagID == client.charLast)
    assert(ns.Bags.SortExecutor.Start("warbandBank"))
    assert(#planned == client.accountLast - client.accountFirst + 1
        and planned[1].bagID == client.accountFirst and planned[#planned].bagID == client.accountLast)
    assert(not ns.Bags.SortExecutor.Start("warbandBank", nil, { tabID = client.charLast }))
    assert(ns.Bags.SortExecutor.Start("warbandBank", nil, { tabID = client.accountLast }))
    assert(#planned == 1 and planned[1].bagID == client.accountLast)
end

print("OK: bank scan, cached tabs, and sort scopes match both documented client enums")
