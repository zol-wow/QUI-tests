local env = dofile("tools/_addon_env.lua")
local ns = env.LoadCore()
local H = ns.Helpers

assert(H.FoldUTF8("AbC") == "abc", "ascii fold")
assert(H.FoldUTF8("МОСКВА") == "москва", "cyrillic A-P fold")
assert(H.FoldUTF8("РЫБА") == "рыба", "cyrillic R-Ya fold crosses lead byte")
assert(H.FoldUTF8("Ёлка") == "ёлка", "io fold")
assert(H.FoldUTF8("Зелёная Роща") == "зелёная роща", "mixed cyrillic fold")
assert(H.FoldUTF8("ÀÉÎÕÜ") == "àéîõü", "latin-1 fold")
assert(H.FoldUTF8("ØSE") == "øse", "latin-1 upper tail fold")
assert(H.FoldUTF8("Œuvre") == "œuvre", "oe ligature fold")
assert(H.FoldUTF8("3×4") == "3×4", "multiplication sign untouched")
assert(H.FoldUTF8("日本語テキスト") == "日本語テキスト", "cjk untouched")
assert(H.FoldUTF8("한국어") == "한국어", "hangul untouched")
assert(H.FoldUTF8(nil) == "", "nil folds to empty")
assert(H.UpperUTF8("москва") == "МОСКВА", "cyrillic upper")
assert(H.UpperUTF8("рыба") == "РЫБА", "cyrillic upper crosses lead byte")
assert(H.UpperUTF8("ёлка") == "ЁЛКА", "io upper")
assert(H.UpperUTF8("àéîõü") == "ÀÉÎÕÜ", "latin-1 upper")
assert(H.UpperUTF8("œuvre") == "ŒUVRE", "oe ligature upper")
assert(H.UpperUTF8("straße") == "STRAßE", "sharp s deliberately not uppercased")

assert(H.FoldSearchUTF8("МОСКВА") == "москва", "older clients retain existing folding")
assert(H.FoldSearchUTF8(nil) == "", "nil search folds to empty")
assert(H.FoldSearchUTF8(123) == "123", "non-string search retains conversion")

local calls = 0
C_Intl = {
    FoldCase = function(text)
        calls = calls + 1
        assert(type(text) == "string", "native folding receives public strings only")
        if text == "Straße" or text == "STRASSE" then return "strasse" end
        if text == "ΟΣ" or text == "ος" then return "οσ" end
        if text == "" then return "" end
        return nil
    end,
}
assert(H.FoldSearchUTF8("Straße") == "strasse", "native search supports expanding folds")
assert(H.FoldSearchUTF8("ΟΣ") == H.FoldSearchUTF8("ος"), "native search handles Greek sigma forms")
assert(H.FoldSearchUTF8("") == "", "native empty result remains valid")
assert(H.FoldSearchUTF8("МОСКВА") == "москва", "native no-result falls back")
assert(H.FoldSearchUTF8(nil) == "", "native route keeps nil input handling")
assert(H.FoldSearchUTF8(123) == "123", "native route keeps non-string handling")
assert(H.FoldUTF8("Straße") == "straße", "identity folding does not expand sharp s")
assert(H.FoldUTF8("Straße") ~= H.FoldUTF8("STRASSE"), "distinct character identities remain distinct")
assert(H.UpperUTF8("straße") == "STRAßE", "native search leaves uppercasing unchanged")

local secret = env.MakeSecret()
local beforeSecret = calls
assert(rawequal(H.FoldSearchUTF8(secret), secret), "secret search input passes through")
assert(calls == beforeSecret, "secret input never reaches native folding")

assert(loadfile("QUI_Bags/bags/search/compiler.lua"))("QUI", ns)
assert(ns.Bags.Search.Compile("STRASSE")({ name = "Straße" }), "bag search uses native folding on query and item")

C_Intl = {}
assert(H.FoldSearchUTF8("МОСКВА") == "москва", "missing native method falls back")
C_Intl = nil

print("ok utf8 fold/upper/native search")
