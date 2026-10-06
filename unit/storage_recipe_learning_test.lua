local current = { bags = {}, bankTabs = {} }
local alt = { recipeLearning = { [100] = { status = "known", checkedAt = 1 } } }
local warband = { tabs = {} }
local ns = { Storage = { Store = {
    IsReady = function() return true end,
    GetCurrentCharacter = function() return current end,
    GetCurrentCharacterKey = function() return "player" end,
    GetWarband = function() return warband end,
} } }
geterrorhandler = function() return function(err) error(err) end end
time = function() return 42 end
Enum = {
    ItemClass = { Recipe = 9 },
    ItemRecipeSubclass = { Book = 0, Tailoring = 2, Cooking = 5, FirstAid = 7 },
    Profession = { Tailoring = 7, Cooking = 5, FirstAid = 0 },
    BankType = { Character = 0, Account = 2 },
    TooltipDataLineType = { ItemName = 22, UsageRequirement = 43, ItemSpellTriggerLearn = 38, LearnableSpell = 6, NestedBlock = 19 },
    TooltipDataUsageRequirementType = { NotAlreadyKnown = 14, Skill = 2 },
}
_G.ITEM_SPELL_KNOWN = "Already known"
C_Item = { GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, id == 100 and 9 or 2 end }
assert(loadfile("core/storage/bus.lua"))("QUI", ns)
assert(loadfile("core/storage/recipe_learning.lua"))("QUI", ns)
local learning = ns.Storage.RecipeLearning
local learn = { type = 38, spellID = 500 }
local preview = { type = 19 }
local header = { type = 22, leftText = "Pattern" }
local red = { type = 43, leftText = "Requires skill", leftColor = { r = 1, g = 0.1, b = 0.1 } }
local canLearn = { lines = { header, learn, preview, red } }
assert(learning.GetStatus(100, canLearn, true) == "canLearn", "crafted output red must not block learning")
assert(current.recipeLearning[100].checkedAt == 42)
assert(learning.GetStatus(100, { lines = { header, { leftText = _G.ITEM_SPELL_KNOWN }, learn } }, true) == "known", "known need not be red")
assert(learning.GetStatus(100, { lines = { header, learn, { leftText = _G.ITEM_SPELL_KNOWN } } }, true) == "known", "late known marker must not become canLearn")
assert(learning.GetStatus(100, { lines = { header, learn, preview, { type = 43, requirementType = 14, usable = false } } }, true) == "known", "exact known markers survive preview cutoff")
assert(learning.GetStatus(100, { lines = { header, { type = 43, requirementType = 14, usable = false }, learn } }, false) == "known", "structured known")
assert(learning.GetStatus(100, { lines = { header, { type = 43, usable = false }, learn } }, true) == "cannotLearn", "structured unmet requirement")
assert(learning.GetStatus(100, { lines = { header, learn, red, preview } }, true) == "cannotLearn", "recipe requirements after Use line still apply")
assert(learning.GetStatus(100, { lines = { header, learn, { type = 19 }, red } }, true) == "canLearn", "nested output cannot block learning")
assert(learning.GetStatus(100, { lines = { header, learn, header, red } }, true) == "canLearn", "second item header starts crafted output")
assert(learning.GetStatus(100, { lines = { header, red, learn } }, true) == "cannotLearn")
assert(learning.GetStatus(100, { lines = { header, { type = 6, spellID = 500 }, red } }, true) == "cannotLearn",
    "LearnableSpell must not hide the recipe's own profession requirement")
assert(learning.GetStatus(100, { lines = { header, { type = 6, usable = false } } }, true) == "cannotLearn",
    "an unusable learn line must not be mistaken for a crafted preview")
assert(learning.GetStatus(100, nil, true) == nil)
assert(learning.GetStatus(100, { lines = {} }, true) == nil)
assert(learning.GetStatus(100, { lines = { header } }, true) == nil, "incomplete tooltip is unknown")
local lineTypes = Enum.TooltipDataLineType
Enum.TooltipDataLineType = {}
assert(learning.GetStatus(100, { lines = { { leftText = "Loading" } } }, true) == nil, "missing enums cannot match missing row type")
Enum.TooltipDataLineType = lineTypes
assert(learning.GetStatus(100, canLearn, false) == nil, "template alone cannot prove eligibility")
assert(learning.GetStatus(200, canLearn, true) == nil, "nonrecipe ignored")
local subclass = 2
_G.C_Item.GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, id == 100 and 9 or 2, subclass end
_G.C_TradeSkillUI = { GetProfessionSkillLineID = function(profession)
    return profession == Enum.Profession.Tailoring and 197 or 185
end }
local skillLine = 171
_G.GetProfessions = function() return nil, 4, nil, nil, 5 end
_G.GetProfessionInfo = function(index) return nil, nil, nil, nil, nil, nil, index == 4 and skillLine or 185 end
assert(learning.GetStatus(100, { lines = { header, learn } }, true) == "cannotLearn",
    "a non-tailor must not be told they can learn a tailoring pattern even when its tooltip omits restrictions")
assert(current.recipeLearning[100].status == "cannotLearn", "wrong profession must replace an eligible snapshot")
skillLine = 197
assert(learning.GetStatus(100, { lines = { header, learn } }, true) == "canLearn",
    "a matching second primary profession must survive an empty first slot")
subclass = 5
assert(learning.GetStatus(100, { lines = { header, learn } }, true) == "canLearn", "secondary Cooking is a valid profession")
subclass = 0
assert(learning.GetStatus(100, { lines = { header, learn } }, true) == "canLearn", "books must not be mapped to an unrelated profession")
subclass = 7
assert(learning.GetStatus(100, { lines = { header, learn } }, true) == "canLearn", "legacy First Aid recipes need their actual tooltip requirements")
subclass = 0
ns.Storage.Store.IsReady = function() return false end
local previous = current.recipeLearning[100]
learning.GetStatus(100, { lines = { header, { leftText = _G.ITEM_SPELL_KNOWN }, learn } }, true)
assert(current.recipeLearning[100] == previous, "forward-version read-only storage must not be mutated")
ns.Storage.Store.IsReady = function() return true end
assert(alt.recipeLearning[100].status == "known", "another character's snapshot preserved")

local seen, requested = {}, 0
local notified = 0
ns.Storage.Bus.Subscribe("RecipeLearningChanged", function() notified = notified + 1 end)
ns.Storage.RequestDrain = function() requested = requested + 1 end
C_Bank = { CanViewBank = function(bankType) return bankType == 2 end }
local live = { [0] = { [1] = { itemID = 100 }, [2] = { itemID = 200 } }, [12] = { [1] = { itemID = 100 } } }
C_Container = { GetContainerItemInfo = function(bag, slot) return live[bag] and live[bag][slot] end }
C_TooltipInfo = { GetBagItem = function(bag, slot)
    seen[#seen + 1] = bag .. ":" .. slot
    return canLearn
end }
current.bags[0] = { slots = { [1] = { itemID = 100 }, [2] = { itemID = 100 } } }
current.bankTabs[6] = { slots = { [1] = { itemID = 100 } } }
warband.tabs[12] = { slots = { [1] = { itemID = 100 } } }
ns.Storage.Bus.Publish("BagsChanged", "player", {})
assert(requested == 0 and learning.Drain() == false, "dress-only notification ignored")
ns.Storage.Bus.Publish("BagsChanged", "alt", { 0 })
assert(requested == 0, "stale alt notification ignored")
ns.Storage.Bus.Publish("BagsChanged", "player", { 0 })
assert(requested == 1 and learning.Drain() == true)
assert(#seen == 2, "only fresh matching items in accessible live containers scanned")
assert(seen[1] == "0:1" and seen[2] == "12:1", "closed character bank not probed")
assert(current.recipeLearning[100].status == "canLearn")
assert(notified == 1, "drain publishes changed status once")
assert(learning.Drain() == false, "dirty cleared")
learning.MarkAllDirty()
learning.Drain()
assert(notified == 1, "same status does not publish again")
canLearn = { lines = { header, learn, { leftText = _G.ITEM_SPELL_KNOWN }, preview } }
learning.MarkAllDirty()
learning.Drain()
assert(current.recipeLearning[100].status == "known" and notified == 2, "learning refreshes cached status and publishes")
print("OK: storage_recipe_learning_test")
