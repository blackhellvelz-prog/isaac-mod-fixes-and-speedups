-- localfixes/ipecac_plague_banner.lua — Книга казней IPECAC (Порченый Моисей) без падений (18.10; слово пользователя
-- о Порченом Моисее: «Доделать его»). Каждая из 10 казней (Items/book_of_plagues.lua) начинается вызовом
-- _transformationsAPI.PlayTransformAnimation("gfx/ui/PlagueOf…Streak.png", 0) — это модуль превращений самого IPECAC
-- (Misc/transformations.lua), который автор не подключил, а картинок-полос казней в моде нет. Вызов падал («attempt to
-- index a nil value (global '_transformationsAPI')»), и казнь обрывалась: саранчи нет, первенцы не гибнут, тьмы нет…
-- Здесь — заглушка, только если модуля нет: PlayTransformAnimation показывает название казни обычным баннером игры
-- (HUD:ShowItemText), по-русски при русском языке; SaveData — пустые истории превращений (их читает
-- Misc/honey_creep.lua — без них падал и он). Если модуль превращений когда-нибудь подключат — он заменит заглушку.
local NAMES = {
	Blood = { "Plague of Blood", "Казнь кровью" },
	Frogs = { "Plague of Frogs", "Нашествие жаб" },
	Lice = { "Plague of Lice", "Нашествие мошек" },
	Flies = { "Plague of Flies", "Пёсьи мухи" },
	Pestilence = { "Plague of Pestilence", "Мор скота" },
	Boils = { "Plague of Boils", "Язвы и нарывы" },
	Thunderstorm = { "Plague of Hail", "Гром и град" },
	Locusts = { "Plague of Locusts", "Саранча" },
	Darkness = { "Plague of Darkness", "Тьма египетская" },
	TheFirstBorn = { "Death of the Firstborn", "Смерть первенцев" },
}

if _transformationsAPI == nil then
	_transformationsAPI = { localfixesStub = true }
end
local api = _transformationsAPI
api.SaveData = api.SaveData or {}
api.SaveData.playersTransformationHistory = api.SaveData.playersTransformationHistory or {}
api.SaveData.playersItemHistory = api.SaveData.playersItemHistory or {}

if api.PlayTransformAnimation == nil then
	function api.PlayTransformAnimation(path)
		local key = type(path) == "string" and path:match("PlagueOf(%w+)Streak") or nil
		local n = key and NAMES[key]
		if not n then return end
		local ru = Options and Options.Language == "ru"
		pcall(function()
			Game():GetHUD():ShowItemText(ru and n[2] or n[1], ru and "Книга казней" or "Book of Plagues")
		end)
	end
end
