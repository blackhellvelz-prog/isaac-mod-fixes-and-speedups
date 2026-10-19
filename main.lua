-- Mod Fixes & Speedups — правки совместимости и ускорение популярных модов (автор blackhellvelz): быстрый json.decode,
-- указатель «имя предмета → номер», кэш Custom Health API, старые глобальные
-- имена Fiend Folio для IPECAC и др., правки ошибок IPECAC, Fiend Folio, Lost and Forgotten, Reshaken, Mod Translator,
-- Encyclopedia. Только перехват во время игры: файлы других модов не меняются. Мод Мастерской собирается
-- tools/build_workshop.py. Имя начинается с двух пробелов: Lua модов грузится по алфавиту имени, этот — одним из первых.
LOCALFIXES = LOCALFIXES or {}
if LOCALFIXES.AllInOne then
	Isaac.DebugString("[Mod Fixes] пропуск: стоит общая сборка localfixes")
	return
end
local mod = RegisterMod("  Mod Fixes & Speedups", 1)
LOCALFIXES.Mod = mod

local function load(name)
	local ok, r = pcall(include, name)
	if not ok then Isaac.DebugString("[Mod Fixes] " .. name .. ": " .. tostring(r)) end
	return ok and r or nil
end

-- быстрый json.decode общего модуля require("json") — до загрузки остальных модов
do
	local ok, json = pcall(require, "json")
	local install = load("json_fast")
	if ok and type(install) == "function" and install(json) then
		Isaac.DebugString("[Mod Fixes] json.decode: быстрый декодер установлен")
	end
end

-- Поиск предмета по имени: Isaac.GetItemIdByName перебирает весь список (~0,3 мс на вызов, в модах их тысячи).
-- Указатель «имя → номер» растёт вместе с игрой (предметы модов дописываются перед каждым ответом); чего в нём нет,
-- имена с повторами и ванильные предметы при неанглийском языке — ищет движок, как было; ничего не запоминается.
do
	local rawItem = Isaac.GetItemIdByName
	local english = false
	pcall(function() english = Options.Language == "en" end)
	if rawItem then
		local ic = Isaac.GetItemConfig()
		local index, lowerOf, amb = {}, {}, {}
		local function add(i, cfg)
			local name = cfg.Name
			if type(name) ~= "string" or name == "" then return end
			if index[name] ~= nil then amb[name] = true end
			index[name] = i
			local l = name:lower()
			local other = lowerOf[l]
			if other ~= nil and other ~= name then amb[name] = true; amb[other] = true end
			lowerOf[l] = name
		end
		local scanned = CollectibleType.NUM_COLLECTIBLES - 1
		if english then
			for i = 1, scanned do
				local cfg = ic:GetCollectible(i)
				if cfg then add(i, cfg) end
			end
		end
		local function extend()
			while true do
				local cfg = ic:GetCollectible(scanned + 1)
				if not cfg then return end
				scanned = scanned + 1
				add(scanned, cfg)
			end
		end
		local hit, miss = 0, 0
		Isaac.GetItemIdByName = function(name, ...)
			if type(name) == "string" and select("#", ...) == 0 then
				extend()
				local id = index[name]
				if id ~= nil and not amb[name] then
					hit = hit + 1
					return id
				end
				miss = miss + 1
			end
			return rawItem(name, ...)
		end
		LOCALFIXES.ReportItemIndex = function()
			local n = 0
			for _ in pairs(amb) do n = n + 1 end
			Isaac.DebugString(string.format("[Mod Fixes] указатель предметов: из указателя %d, движком %d, номеров %d, повторов %d",
				hit, miss, scanned, n))
		end
	end
end

load("ff_legacy_globals")               -- старые глобальные имена Fiend Folio для кода совместимости IPECAC и др.
load("chapi_resync_cache")              -- кэш пересинхронизации Custom Health API
load("ipecac_plague_banner")            -- Книга казней IPECAC: заглушка модуля превращений
LOCALFIXES.Mod = mod
load("compat_runtime")                  -- правки совместимости модов во время игры
LOCALFIXES.Mod = mod
load("ui_tweaks")                       -- удобства интерфейсов модов (образец EID в Mod Config Menu)
LOCALFIXES.Mod = mod
pcall(include, "moses_b_hair")          -- Порченый Моисей IPECAC: седые волосы (файл есть, только если выложена его графика)

local ffApplied = false
local function applyFF()
	if ffApplied or not LOCALFIXES.ApplyFFLegacy then return end
	ffApplied = LOCALFIXES.ApplyFFLegacy(false) > 0
end
local function cacheOn()
	if LOCALFIXES.InstallCHAPIResyncCache then pcall(LOCALFIXES.InstallCHAPIResyncCache) end
end

if ModCallbacks.MC_POST_MODS_LOADED then
	mod:AddCallback(ModCallbacks.MC_POST_MODS_LOADED, function()
		if LOCALFIXES.ReportItemIndex then LOCALFIXES.ReportItemIndex() end
		pcall(applyFF)
		cacheOn()
	end)
end
-- подстраховка: в начале забега раньше всех (IPECAC заполняет свои таблицы в MC_POST_GAME_STARTED)
mod:AddPriorityCallback(ModCallbacks.MC_POST_GAME_STARTED, CallbackPriority.IMPORTANT, function()
	pcall(applyFF)
	cacheOn()
	if LOCALFIXES.ClearCHAPICache then LOCALFIXES.ClearCHAPICache() end
end)
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function()
	if LOCALFIXES.ClearCHAPICache then LOCALFIXES.ClearCHAPICache() end
end)
