-- localfixes: исправления совместимости модов во время игры — из папки нашего мода, без правки чужих файлов (правило
-- «Подписался — и работает», 18.10: «Учти что моды которые мы делаем должны быть «Подписаться в Workshop» и работает
-- сразу / Без танцев с бубнами»).
local mod = LOCALFIXES.Mod
local C = {}

-- 1. Вылет при старте «Жадности» / «Жадности+» за Лилит (18.10: «У меня сейчас игра вылетела когда я попытался за
-- Лилит Greedier запустить»). Цепочка по log.txt (стек Lua перед «Caught exception, writing minidump»):
--   Fiend Folio на MC_PRE_LEVEL_INIT очищает врождённые предметы (ffscripts/connor/utilities/misc_functions.lua:
--   player:ClearInnateItemGroup("FF_LEVEL")) → игра пересчитывает фамильяров (Инкуб Лилит) → MC_PRE_ENTITY_SPAWN →
--   библиотека TSIL мода TBoI Reshaken (loi_milkshake, POST_NEW_ROOM_EARLY) проверяет «новая ли комната» и ставит
--   стену по номеру клетки, а комнаты ещё нет (в «Жадности» этаж на старте забега уже не нулевой, кадр 0) →
--   Room:GetGridPosition падает в коде игры.
-- Пока идёт начало уровня, TSIL.GridEntities.SpawnGridEntity ничего не ставит: TSIL пишет в лог «Failed to spawn a new
-- wall» и считает комнату прежней, а проверка повторяется на MC_POST_NEW_ROOM, когда комната уже есть. TSIL общий для
-- модов и защищён от перезаписи по версиям — подмена идёт в его внутренней таблице (__PROXY), заново на каждом
-- уровне (если другой мод загрузил свою версию TSIL позже).
local inLevelInit = false
local function guardTSIL()
	local T = rawget(_G, "TSIL")
	if type(T) ~= "table" then return end
	local okG, ge = pcall(function() return T.GridEntities end)
	if not okG or type(ge) ~= "table" then return end
	local proxy = rawget(ge, "__PROXY")
	if type(proxy) ~= "table" then return end
	local f = rawget(proxy, "SpawnGridEntity")
	if type(f) ~= "function" or f == C.tsilGuard then return end
	local guarded = function(...)
		if inLevelInit then return nil end
		return f(...)
	end
	rawset(proxy, "SpawnGridEntity", guarded)
	C.tsilGuard = guarded
end
mod:AddPriorityCallback(ModCallbacks.MC_PRE_LEVEL_INIT, -100000, function()
	inLevelInit = true
	guardTSIL()
end)
mod:AddPriorityCallback(ModCallbacks.MC_PRE_LEVEL_INIT, 100000, function() inLevelInit = false end)
-- Тот же корень и у других модов со своей копией проверки «новая комната» (Alt Path Greed Mode — встроенный
-- isaacscript-common: PostNewRoomEarly на PRE_ENTITY_SPAWN, тоже ставит стену). Общий предохранитель: в начале уровня на
-- нулевом кадре забега (комнаты ещё нет) наш самый ранний PRE_ENTITY_SPAWN возвращает игре те же тип, вариант, подтип
-- и зерно — сущность (фамильяр) появляется как обычно, а цепочка колбэков на этом кончается (REPENTOGON: первый
-- непустой ответ останавливает остальные), и проверки «новой комнаты» не запускаются; на MC_POST_NEW_ROOM они идут как
-- обычно.
-- То же при продолжении сохранённого забега (19.10, вылет при загрузке забега Скелетного Изверга FF: его
-- skeletalfiend.lua:25 на инициализации игрока делает Isaac.Spawn → TSIL NewRoomEarly → SpawnGridEntity →
-- Room:GetGridPosition, «Caught exception»): загрузка идёт без MC_PRE_LEVEL_INIT, кадр 0, комнаты ещё нет. Поэтому
-- предохранитель стоит и до первой комнаты после запуска игры или выхода в меню (roomReady).
local roomReady = false
mod:AddPriorityCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, -1000000000, function(_, t, v, st, _, _, _, seed)
	if (inLevelInit or not roomReady) and Game():GetFrameCount() == 0 then
		return { t, v, st, seed }
	end
end)
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function() inLevelInit = false end)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function() inLevelInit = false roomReady = true end)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function() roomReady = false end)

-- 2. Перечисления, затёртые модами при загрузке (19.10, перенос в мод для Мастерской; на этом ПК то же делали правки
-- файлов IPECAC — apply_fixes fix_tearflags и EDITS 57/58): IPECAC объявляет глобальные TearFlags своей таблицей (без
-- 13 флагов Rep+), LaserVariant — урезанной ({BRIMSTONE = 1, …}: нет THICK_RED и др.), Achievement — своим классом
-- (перечисление REPENTOGON пропадает; сам IPECAC класс нигде не создаёт). Модам, загруженным после него, и нашему коду
-- достаются nil. После загрузки всех модов значения игры и REPENTOGON (enum_data.lua — tools/gen_enum_data.py из их
-- enums.lua) кладутся поверх; ключи, которых у игры нет (свои у мода), остаются.
local function TEARFLAG(x)
	return x >= 64 and BitSet128(0, 1 << (x - 64)) or BitSet128(1 << x, 0)
end
-- данные — при загрузке модуля: include находит файл мода только во время загрузки мода (из колбэка — нет)
local okE, ENUM_DATA = pcall(include, "enum_data")
if not okE or type(ENUM_DATA) ~= "table" then ENUM_DATA = nil end
function C.restoreEnums()
	local E = ENUM_DATA
	if not E then return 0 end
	local n = 0
	local TF = rawget(_G, "TearFlags")
	if type(TF) == "table" and BitSet128 then
		for k, bit in pairs(E.tear or {}) do               -- значение игры — всегда (у мода номер бита мог быть старый),
			if TF[k] == nil then n = n + 1 end               -- в счёт — недостающие ключи
			TF[k] = TEARFLAG(bit)
		end
		if TF.TEAR_NORMAL == nil then TF.TEAR_NORMAL = BitSet128(0, 0) n = n + 1 end
		for a, k in pairs(E.alias or {}) do
			if TF[a] == nil and TF[k] ~= nil then TF[a] = TF[k] n = n + 1 end
		end
	end
	local LV = rawget(_G, "LaserVariant")
	if type(LV) == "table" then
		for k, v in pairs(E.laser or {}) do
			if LV[k] == nil then n = n + 1 end
			LV[k] = v
		end
	end
	local A = rawget(_G, "Achievement")
	if E.ach and (type(A) ~= "table" or A.MAGDALENE == nil) then   -- класс IPECAC вместо перечисления — вернуть перечисление
		local t = {}
		for k, v in pairs(E.ach) do t[k] = v end
		rawset(_G, "Achievement", t)
		n = n + 1
	end
	return n
end
-- 3. IPECAC: Lil Larry заперт навсегда (его колбэк подменяет предмет, пока не открыт, а открытие у мода не срабатывает;
-- на этом ПК — EDITS 54). Колбэк — метод таблицы мода, снимается штатно. Can of Beans (EDITS 53) — локальная функция
-- мода, снаружи не снять — только этот ПК.
function C.unlockIpecac()
	local M = rawget(_G, "IpecacMod")
	if type(M) == "table" and type(M.LilLarryLock) == "function" and M.RemoveCallback then
		pcall(M.RemoveCallback, M, ModCallbacks.MC_POST_GET_COLLECTIBLE, M.LilLarryLock)
		return true
	end
	return false
end
-- 4. IPECAC: на старте забега совместимость с FF (Misc/Mod Compatibility/fiend_folio.lua:319) кладёт «какашки Bowel
-- Movement» в IpecacCM.BowelMovementDips, а таблицы у мода нет — ошибка и красная плашка «IpecacMod is causing errors!»
-- (19.10, найдено проверкой чистой установки; на этом ПК — EDITS 59). Таблица создаётся до его колбэка.
function C.ipecacDips()
	local I = rawget(_G, "IpecacCM")
	if type(I) == "table" and I.BowelMovementDips == nil then
		I.BowelMovementDips = {}
		return true
	end
	return false
end
-- 5. Fiend Folio: «Fix for CO-OP» (ffscripts/players/briend_bounty/heat.lua) держит сам объект игрока до следующего
-- кадра; Epiphany при выборе двери потускневшего и консольный restart пересоздают игрока — отложенная проверка зовёт
-- GetPlayerType у удалённого, движок падает (18.10, «Caught exception, writing minidump»; на этом ПК — EDITS 0).
-- Колбэк — метод таблицы мода: снимаем его и ставим тот же, но с безопасной ссылкой EntityPtr.
function C.ffHeat()
	local F = rawget(_G, "FiendFolio")
	if type(F) ~= "table" or type(F.GetBountyHeatLate) ~= "function" or type(F.scheduleForUpdate) ~= "function"
		or C.ffHeatFn then return false end
	pcall(F.RemoveCallback, F, ModCallbacks.MC_POST_PLAYER_INIT, F.GetBountyHeatLate)
	C.ffHeatFn = function(_, player)
		local ptr = EntityPtr(player)
		F.scheduleForUpdate(function()
			local p = ptr.Ref and ptr.Ref:ToPlayer()
			if p and F.PLAYER and p:GetPlayerType() == F.PLAYER.BRIEND and F.savedata and F.savedata.run
				and not F.savedata.run.briendHeat then
				F:GetBountyHeat()
			end
		end, 0, ModCallbacks.MC_POST_UPDATE, true)
	end
	F:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, C.ffHeatFn, PlayerVariant.PLAYER)
	return true
end

-- 6. «Пауза» в меню DSS (на этом ПК — EDITS 1): ядро DSS «замораживает» игру предметом «Пауза» — обычное ядро на каждый
-- кадр, ядро Encyclopedia (главное) — на каждую строку меню, ~11 раз за кадр; каждое использование будит MC_USE_ITEM и
-- пересчёт характеристик всех модов (18.10: ~860 мс Lua в секунду, 6 FPS). «Пауза» держит врагов, пока игрок не
-- выстрелит, а в меню стрелять нельзя — хватает одного раза на открытие меню и потом раза в 5 с. Только бесшумные
-- (USE_NOANIM) — так «Паузу» зовут меню; предмет в руках игрока — как был.
local pauseAt, pauseSeen
mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, function(_, _, _, _, flags)
	if not flags or flags & UseFlag.USE_NOANIM == 0 then return end
	local f = Isaac.GetFrameCount()
	local fresh = not pauseSeen or f - pauseSeen > 2 or f < pauseSeen       -- меню только что открыли
	pauseSeen = f
	if not fresh and pauseAt and f >= pauseAt and f - pauseAt < 300 then return true end
	pauseAt = f
end, CollectibleType.COLLECTIBLE_PAUSE)

-- 7. Lost and Forgotten (на этом ПК — EDITS 3): огонёк вне забега за Робота ронял MC_FAMILIAR_INIT — таблица огоньков
-- Робота WispItemsInitSeeds есть только у Робота (18.10, плашка «Lost and Forgotten is causing errors!»). Его код зовёт
-- LNF.GetLastData() через глобальную таблицу — обёртка дописывает пустую таблицу (Робот свою заводит сам).
function C.lnfWisps()
	local L = rawget(_G, "LNF")
	if type(L) ~= "table" or type(L.GetLastData) ~= "function" or L.GetLastData == C.lnfFn then return false end
	local orig = L.GetLastData
	C.lnfFn = function(...)
		local t = orig(...)
		if type(t) == "table" and t.WispItemsInitSeeds == nil then t.WispItemsInitSeeds = {} end
		return t
	end
	L.GetLastData = C.lnfFn
	return true
end

-- 8. TSIL (библиотека TBoI Reshaken; на этом ПК — EDITS 50–52): очередь обновлений игрока на старте забега зовёт
-- колбэки TSIL с игроком, которого уже нет (nil), — разбор необязательных параметров роняет вызов. Пропускаем вызов
-- колбэка TSIL, если первый параметр передан, но пуст. Функция лежит во внутренней таблице TSIL (__PROXY) — как в п. 1,
-- заново на каждом уровне (другой мод мог загрузить свою версию TSIL позже).
local function guardTSILTrigger()
	local T = rawget(_G, "TSIL")
	local proxy = type(T) == "table" and rawget(T, "__PROXY")
	if type(proxy) ~= "table" then return false end
	local f = rawget(proxy, "__TriggerCustomCallback")
	if type(f) ~= "function" or f == C.tsilTrigger then return false end
	C.tsilTrigger = function(callback, ...)
		if select("#", ...) >= 1 and (...) == nil then return nil end
		return f(callback, ...)
	end
	rawset(proxy, "__TriggerCustomCallback", C.tsilTrigger)
	return true
end
C.guardTSILTrigger = guardTSILTrigger
mod:AddPriorityCallback(ModCallbacks.MC_PRE_LEVEL_INIT, -100000, function() guardTSILTrigger() end)

-- 9. Знаки, которых нет в шрифте ядер DSS (a-z, A-Z, цифры, ' " : / . , ! ? [ ] ( ) $ + - % _ = ^ < > и пробел): ядро на
-- каждый такой знак КАЖДЫЙ кадр пишет «Invalid character» в консоль и лог (журналы Epiphany со стрелками «→» — сотни
-- строк и рывки; «*» в статьях Repentance Plus и описании Тридцати сребреников). На этом ПК ядра поправлены
-- (apply_fixes: UTF-8, кириллица, перевод) и «*» заменены в файлах (EDITS 46–49); у ядер без правки (Мастерская) —
-- строки меню DSS, журналов изменений и статей энциклопедии чистятся на месте: «*» — «x» (умножение) или «-»
-- (маркер списка), «;» — «,», «→» — «->», кавычки и тире — близкие знаки. Кириллицу не трогаем.
local DSS_MB = { ["→"] = "->", ["←"] = "<-", ["—"] = "-", ["–"] = "-", ["…"] = "...", ["«"] = '"', ["»"] = '"',
	["“"] = '"', ["”"] = '"', ["„"] = '"', ["’"] = "'", ["‘"] = "'", ["×"] = "x", ["•"] = "-", ["№"] = "no.",
	["é"] = "e", ["è"] = "e", ["ê"] = "e", ["á"] = "a", ["à"] = "a", ["ö"] = "o", ["ü"] = "u", ["ñ"] = "n",
	["°"] = " deg", ["½"] = "1/2", ["²"] = "2", ["³"] = "3", ["±"] = "+-", ["≥"] = ">=", ["≤"] = "<=",
	["\194\160"] = " " }
local DSS_ASCII = { [";"] = ",", ["&"] = "+", ["#"] = "no.", ["@"] = "a", ["~"] = "-", ["|"] = "/", ["{"] = "(",
	["}"] = ")", ["`"] = "'", ["\\"] = "/", ["\t"] = " " }
local function dssClean(s)
	if not s:find("[^%w '\":/%.,!%?%[%]%(%)%$%+%-%%_=%^<>]") then return s end
	s = s:gsub("[\194-\244][\128-\191]+", function(c) return DSS_MB[c] end)
	s = s:gsub("^(%s*)%*+%s*", "%1- ")
	s = s:gsub("(%d)%s*%*%s*(%d)", "%1 x %2"):gsub(" %* ", " x "):gsub("%*", "")
	s = s:gsub("[;&#@~|{}`\\\t]", DSS_ASCII)
	return s
end
C.dssClean = dssClean
local STR_KEYS = { str = true, title = true }
local ENCY_KEYS = { str = true, title = true, Name = true, Desc = true, Title = true }
local function cleanTree(t, keys, seen, depth)
	if depth > 10 or seen[t] then return 0 end
	seen[t] = true
	local n = 0
	for k, v in pairs(t) do
		local tv = type(v)
		if tv == "string" then
			if keys[k] then
				local c = dssClean(v)
				if c ~= v then t[k] = c n = n + 1 end
			end
		elseif tv == "table" then
			if k == "strset" then
				for i, x in ipairs(v) do
					if type(x) == "string" then
						local c = dssClean(x)
						if c ~= x then v[i] = c n = n + 1 end
					end
				end
			else
				n = n + cleanTree(v, keys, seen, depth + 1)
			end
		end
	end
	return n
end
function C.cleanDSS()
	if rawget(_G, "LOCALFIXES_DSS_CYR") then return 0 end      -- ядра этого ПК — со своей правкой
	local n, seen = 0, {}
	local D = rawget(_G, "DeadSeaScrollsMenu")
	if type(D) == "table" then
		for _, m in pairs(type(D.Menus) == "table" and D.Menus or {}) do
			if type(m) == "table" and type(m.Directory) == "table" then n = n + cleanTree(m.Directory, STR_KEYS, seen, 0) end
		end
		if type(D.Changelogs) == "table" then n = n + cleanTree(D.Changelogs, STR_KEYS, seen, 0) end
		if type(D.ChangelogItems) == "table" then n = n + cleanTree(D.ChangelogItems, STR_KEYS, seen, 0) end
	end
	local E = rawget(_G, "Encyclopedia")
	if type(E) == "table" then
		for _, k in ipairs({ "itemsTable", "trinketsTable", "pocketitemsTable", "characters_aTable", "characters_bTable" }) do
			if type(E[k]) == "table" then n = n + cleanTree(E[k], ENCY_KEYS, seen, 0) end
		end
	end
	return n
end
-- меню собираются и при открытии — раз на каждое открытие DSS
local dssWasOpen = false
mod:AddCallback(ModCallbacks.MC_POST_RENDER, function()
	local D = rawget(_G, "DeadSeaScrollsMenu")
	local open = type(D) == "table" and type(D.IsOpen) == "function" and D.IsOpen() or false
	if open and not dssWasOpen then pcall(C.cleanDSS) end
	dssWasOpen = open
end)

-- 10. Mod Translator, перевод Reshaken (на этом ПК — EDITS 66): в его translations/reshaken.lua «пасхалка» —
-- math.random(0, 10) == 0 → K["Spirit of Conductivity"], а ключ в таблице — «Spirit Of Conductivity»: в 1 запуске из
-- 11 ошибка обрывает весь перевод (Reshaken и все следующие моды) и даёт плашку «mod translator is causing errors!».
-- Его колбэк старта забега обёрнут: на время его работы такой бросок не выпадает нулём (вне колбэка — как обычно).
function C.mtReshaken()
	if C.mtFn then return false end
	local okC, list = pcall(Isaac.GetCallbacks, ModCallbacks.MC_POST_GAME_STARTED)
	if not okC or type(list) ~= "table" then return false end
	for _, e in ipairs(list) do
		local M = e.Mod
		if type(M) == "table" and M.Name == "mod translator" and type(e.Function) == "function" then
			local fn, prio = e.Function, e.Priority or 0
			M:RemoveCallback(ModCallbacks.MC_POST_GAME_STARTED, fn)
			C.mtFn = function(...)
				local rnd = math.random
				math.random = function(...)
					local r = rnd(...)
					if r == 0 and select("#", ...) == 2 then
						local a, b = ...
						if a == 0 and b == 10 then r = rnd(1, 10) end
					end
					return r
				end
				local ok, err = pcall(fn, ...)
				math.random = rnd
				if M.IsLoadedd then M:RemoveCallback(ModCallbacks.MC_POST_GAME_STARTED, C.mtFn) end
				if not ok then error(err, 0) end
			end
			M:AddPriorityCallback(ModCallbacks.MC_POST_GAME_STARTED, prio, C.mtFn)
			return true
		end
	end
	return false
end

-- 11. Lost and Forgotten: Lost.GetCursedPickupMod / GetCursedRunesMod берут «curse = LNF:Data().Curse or 0», но
-- сравнивают порог с самим полем — пока его нет (самое начало забега: Эдем получает случайные вещи, срабатывает
-- MC_PRE_ENTITY_SPAWN замены пикапов) — «attempt to compare nil with number» (19.10, автотест «все персонажи ×
-- режимы»: Эдем, обычный режим). Функции зовутся через глобальную таблицу Lost — обёртка на время вызова подставляет
-- поле, равное 0 (как их собственное «or 0»), и убирает его обратно.
function C.lnfCurse()
	local Lo, L = rawget(_G, "Lost"), rawget(_G, "LNF")
	if type(Lo) ~= "table" or type(L) ~= "table" or type(L.Data) ~= "function" or C.lnfCurseDone then return false end
	local n = 0
	for _, name in ipairs({ "GetCursedPickupMod", "GetCursedRunesMod" }) do
		local orig = Lo[name]
		if type(orig) == "function" then
			Lo[name] = function(...)
				local okD, d = pcall(L.Data, L)
				local fill = okD and type(d) == "table" and d.Curse == nil
				if fill then d.Curse = 0 end
				local ok, r = pcall(orig, ...)
				if fill then d.Curse = nil end
				if not ok then error(r, 0) end
				return r
			end
			n = n + 1
		end
	end
	C.lnfCurseDone = n > 0
	return C.lnfCurseDone
end

-- 12. Epiphany, Потускневший Эдем в «Жадности» и «Жадности+»: таблица пулов Epiphany в режиме «Жадности» пропускает
-- обычные пулы, а разброс Эдема (eden.lua GenerateItem) берёт пулы из своих «архетипов» — PoolsToItems[пул] = nil, ошибка
-- в MC_POST_UPDATE на каждом разбросе (19.10, автотест «все персонажи × режимы»; стек: pool_table.lua:201
-- GetItemsFromPools ← eden.lua:434). Метод зовётся через общую таблицу Epiphany.PoolTableHelper — обёртка оставляет
-- только пулы, что есть в текущем режиме; не осталось ни одного — все пулы режима (как у Epiphany при «Хаосе»); таблиц
-- ещё нет (первый кадр забега) — пустой список (Эдем оставит прежний предмет).
function C.epEdenPools()
	local E = rawget(_G, "Epiphany")
	local P = type(E) == "table" and E.PoolTableHelper
	if type(P) ~= "table" or type(P.GetItemsFromPools) ~= "function" or C.epPoolsDone then return false end
	local orig = P.GetItemsFromPools
	P.GetItemsFromPools = function(self, filter, ...)
		local map = self.PoolsToItems
		if type(map) ~= "table" then return {} end
		local n = select("#", ...)
		if n == 0 then return orig(self, filter) end
		local keep = {}
		for i = 1, n do
			local id = select(i, ...)
			if id ~= nil and type(map[id]) == "table" then keep[#keep + 1] = id end
		end
		if #keep == 0 then return orig(self, filter) end
		return orig(self, filter, table.unpack(keep))
	end
	C.epPoolsDone = true
	return true
end

-- 13. IPECAC: обход клеток комнаты во время загрузки модов — зависание (на этом ПК — EDITS, правка main.lua IPECAC;
-- 19.10 в чистой установке загрузка снова встала на IPECAC). IpecacMod.UpdateGriendtityLog подписан и на свой колбэк
-- «POST_MOD_LOAD», который IPECAC запускает в конце своего main.lua (Isaac.RunCallbackWithParam): комнаты ещё нет,
-- room:GetGridSize() — мусор памяти (бывают сотни миллионов), цикл room:GetGridEntity(i) крутится минутами. Наш колбэк
-- на тот же «POST_MOD_LOAD» стоит раньше (этот мод грузится раньше IPECAC и с приоритетом -100000) и подменяет в
-- записи IPECAC функцию на обёртку: вне забега обход пропускается. REPENTOGON берёт функцию из записи в момент вызова.
-- В забеге (новая комната, старт, предметы) — как было.
mod:AddPriorityCallback("POST_MOD_LOAD", -100000, function()
	local M = rawget(_G, "IpecacMod")
	local f = type(M) == "table" and rawget(M, "UpdateGriendtityLog")
	if type(f) ~= "function" then return end
	for _, cb in ipairs(Isaac.GetCallbacks("POST_MOD_LOAD") or {}) do
		if cb.Function == f then
			cb.Function = function(...)
				if not Isaac.IsInGame() then return end
				return f(...)
			end
			C.ipecacGrid = true
		end
	end
end, "IPECAC Community Mod")

mod:AddPriorityCallback(ModCallbacks.MC_POST_GAME_STARTED, -100000, function() C.ipecacDips() end)
mod:AddPriorityCallback(ModCallbacks.MC_POST_GAME_STARTED, 100000, function()
	guardTSILTrigger()
	pcall(C.cleanDSS)
end)
local function afterAllMods()
	C.ipecacDips()
	local n = C.restoreEnums()
	local larry = C.unlockIpecac()
	local heat, lnf, tsil, mt = C.ffHeat(), C.lnfWisps(), guardTSILTrigger(), C.mtReshaken()
	local lnfCurse, epPools = C.lnfCurse(), C.epEdenPools()
	local okD, dss = pcall(C.cleanDSS)
	Isaac.DebugString(("[localfixes] совместимость: перечислений возвращено %d, замок Lil Larry снят: %s, FF heat: %s, "
		.. "LnF огоньки: %s, LnF проклятие: %s, Эдем Epiphany: %s, TSIL: %s, Mod Translator: %s, строк DSS очищено: %s, "
		.. "IPECAC обход клеток при загрузке: %s"):format(n,
		tostring(larry), tostring(heat), tostring(lnf), tostring(lnfCurse), tostring(epPools), tostring(tsil), tostring(mt),
		tostring(dss), tostring(C.ipecacGrid or false)))
end
if ModCallbacks.MC_POST_MODS_LOADED then
	mod:AddCallback(ModCallbacks.MC_POST_MODS_LOADED, afterAllMods)
else
	afterAllMods()
end

LOCALFIXES.CompatRuntime = C
return C
