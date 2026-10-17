local loader = dofile("tests/helpers/load_storage_data.lua")

local function LoadEnums(path)
    local bagIndex = {}
    APIDocumentation = { AddDocumentationTable = function(_, doc)
        for _, field in ipairs(doc.Tables[1].Fields) do bagIndex[field.Name] = field.EnumValue end
    end }
    dofile(path .. "/BagIndexConstantsDocumentation.lua")
    Enum = { BagIndex = bagIndex, BankType = { Character = 0, Account = 2 } }
end

for _, path in ipairs({ "tests/api-docs/blizzard", "tests/clients/forever/api-docs/blizzard" }) do
    LoadEnums(path)
    loader.InstallBaseStubs()
    C_Bank.FetchPurchasedBankTabData = function(bankType)
        return bankType == Enum.BankType.Account and { { ID = 15, name = "First" } } or {}
    end
    C_Bank.FetchBankLockedReason = function() return nil end
    C_Bank.FetchDepositedMoney = function() return 100 end
    C_Container.GetContainerNumSlots = function(id) return id == 15 and 1 or 0 end
    C_Container.GetContainerItemInfo = function(id)
        return id == 15 and { itemID = 123, stackCount = 4, quality = 1, iconFileID = 1 } or nil
    end
    C_Container.GetContainerNumFreeSlots = function() return 0, 0 end
    C_Item.GetItemFamily = function() return 0 end
    local ns = loader.LoadAll(nil, "summaries.lua")
    local store, scan, summaries = ns.Storage.Store, ns.Storage.ScanBank, ns.Storage.Summaries
    local character = { details = { money = 200 }, bags = {}, bankTabs = { [6] = {} },
        mail = {}, equipped = {}, currencies = { [1] = 10 }, auctions = {}, professions = {} }
    local alt = { details = {}, bags = {}, bankTabs = { [6] = {} },
        mail = {}, equipped = {}, currencies = {}, auctions = {} }
    local guilds = { Guild = { tabs = { [1] = {} }, money = 300 } }
    local currency, bags, mail, professions = character.currencies, character.bags, character.mail, character.professions
    QUI_StorageDB = { version = 2, characters = { ["Testchar-TestRealm"] = character, Alt = alt },
        guilds = guilds, warband = { money = 100, tabs = {
            [12] = { size = 1, slots = { { itemID = 123, count = 4 } } },
            [16] = { size = 1, slots = { { itemID = 456, count = 2 } } },
        } } }
    store.Initialize()
    summaries.SeedOwners()
    scan.RefreshTabMetadata()
    scan.MarkAllDirty()
    assert(scan.Drain())
    local tabs = store.GetWarband().tabs
    assert(not tabs[12] and not tabs[16], "legacy bank IDs must not survive a scan under the new topology")
    assert(summaries.GetCounts(123)[":warband"].warband == 4, "legacy tab must not duplicate freshly scanned items")
    assert(next(character.bankTabs) == nil and next(alt.bankTabs) == nil,
        "unstamped character bank snapshots must be invalidated for every character")
    assert(QUI_StorageDB.characters["Testchar-TestRealm"] == character and QUI_StorageDB.guilds == guilds)
    assert(character.details.money == 200 and character.currencies == currency and character.bags == bags
        and character.mail == mail and character.professions == professions and store.GetWarband().money == 100,
        "bank migration must preserve unrelated saved data")
    local stamp = assert(QUI_StorageDB.bankTopology)
    assert(stamp.character and stamp.account)
    character.bankTabs[6] = { marker = "current character" }
    alt.bankTabs[6] = { marker = "current alt" }
    local charTabs, altTabs = character.bankTabs, alt.bankTabs
    store.Initialize()
    assert(character.bankTabs == charTabs and alt.bankTabs == altTabs and store.GetWarband().tabs == tabs,
        "initializing unchanged topology must preserve current snapshots")
    local bagIndex = Enum.BagIndex
    bagIndex.CharacterBankTab_1, bagIndex.CharacterBankTab_2 = bagIndex.CharacterBankTab_2, bagIndex.CharacterBankTab_1
    store.Initialize()
    assert(next(character.bankTabs) == nil and next(alt.bankTabs) == nil and store.GetWarband().tabs == tabs,
        "swapping character tab IDs must invalidate character snapshots and leave account snapshots intact")
    character.bankTabs[6] = { marker = "after character migration" }
    charTabs = character.bankTabs
    Enum.BagIndex.AccountBankTab_10 = 25
    store.Initialize()
    assert(character.bankTabs == charTabs and next(store.GetWarband().tabs) == nil,
        "changed account topology must leave character snapshots intact")
    local newer = { version = store.SCHEMA_VERSION + 1, characters = { marker = true },
        bankTopology = { character = "old", account = "old" }, warband = { tabs = { [12] = {} } } }
    QUI_StorageDB = newer
    store.Initialize()
    assert(not store.IsReady() and newer.characters.marker and newer.warband.tabs[12]
        and newer.bankTopology.account == "old" and newer.bankTopology.character == "old",
        "future-schema data must remain untouched")
    QUI_StorageDB = { version = 2, warband = { tabs = { [16] = { marker = "ambiguous legacy ID" } } } }
    store.Initialize()
    assert(next(store.GetWarband().tabs) == nil,
        "unstamped caches with only IDs shared by old and new layouts must be invalidated once")
end

local ns = {}
Enum = nil
assert(loadfile("core/storage/store.lua"))("QUI", ns)
QUI_StorageDB = { version = 2, characters = { Alt = { bankTabs = { [6] = {} } } }, warband = { tabs = { [12] = {} } } }
ns.Storage.Store.Initialize()
assert(QUI_StorageDB.characters.Alt.bankTabs[6] and QUI_StorageDB.warband.tabs[12]
    and QUI_StorageDB.bankTopology == nil, "unavailable enum topology must not invalidate snapshots")
print("OK: bank topology migration preserves current snapshots and removes legacy duplicate counts")
