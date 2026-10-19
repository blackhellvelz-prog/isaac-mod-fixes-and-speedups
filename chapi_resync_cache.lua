-- Кэш Custom Health API (CHAPI) в пределах кадра — производительность.
--
-- CHAPI (общая библиотека Fiend Folio / Furtherance / Repentance Plus …) подменяет 64 метода игрока. Геттеры
-- здоровья (player:GetHearts(), GetSoulHearts(), GetEffectiveMaxHearts() …) каждый раз делают полную
-- пересинхронизацию (CustomHealthAPI.Helper.ResyncHealthOfPlayer) и пересчитывают здоровье из своих масок:
-- ~45–50 мкс против 0,16 мкс у оригинала. Моды зовут их тысячи раз в секунду (замеры мостом 17.10:
-- пересинхронизаций ~2500/с = 114 мс/с; GetSoulHearts через API 45 мкс даже при пропущенной пересинхронизации).
--
-- Оба шага зависят только от состояния здоровья. «Отпечаток» состояния: оригинальные (не подменённые) значения
-- сердец, лимит, Greed's Gullet, тип игрока и здоровья, нулевые эффекты Reverse Sun / Reverse Empress / Spirit
-- Shackles, заряды Alabaster Box, флаги и накладки CHAPI, номер кадра и счётчик «поколений», который растёт при
-- любом вызове изменяющих функций CHAPI (Library.Add*/Set*/Remove* …, подменённые AddHearts, TakeDamage,
-- ChangePlayerType, Revive, AddCollectible, EvaluateItems …). Пока отпечаток тот же, что при прошлом вызове в
-- этом кадре, — пересинхронизация пропускается, а геттер отдаёт прошлый результат. Пока стоят флаги урона CHAPI —
-- всегда полный путь. Вложенные вызовы (изнутри самой пересинхронизации) — всегда полный путь.
LOCALFIXES = LOCALFIXES or {}

local installed = false

local GETTERS = {
	"GetHearts", "GetMaxHearts", "GetSoulHearts", "GetBlackHearts", "GetBoneHearts", "GetGoldenHearts",
	"GetEternalHearts", "GetRottenHearts", "GetBrokenHearts", "GetEffectiveMaxHearts", "GetHeartLimit",
	"GetGreedsGulletHearts", "HasFullHearts", "HasFullHeartsAndSoulHearts", "IsBlackHeart", "IsBoneHeart",
	"CanPickBlackHearts", "CanPickBoneHearts", "CanPickGoldenHearts", "CanPickRedHearts", "CanPickRottenHearts",
	"CanPickSoulHearts",
}
-- Не трогаем: чистые проверки предметов/брелоков (дешёвые) и отрисовку.
local PASSTHROUGH = {
	HasCollectible = true, GetCollectibleNum = true, GetNumCollectibles = true, HasTrinket = true,
	HasGoldenTrinket = true, GetTrinketMultiplier = true, GetTotalTrinketMultiplier = true, GetEffects = true,
	AnyPlayerTypeHasCollectible = true, AnyPlayerTypeHasTrinket = true, AnyoneHasCollectible = true,
	AnyoneHasTrinket = true, FirstCollectibleOwner = true, FirstTrinketOwner = true, GetRandomCollectibleOwner = true,
	GetRandomTrinketOwner = true, IsCollectibleBlocked = true, IsTrinketBlocked = true, RenderHUD = true,
}

function LOCALFIXES.InstallCHAPIResyncCache()
	if installed then return true end
	local CHAPI = CustomHealthAPI
	if type(CHAPI) ~= "table" or type(CHAPI.Helper) ~= "table" or type(CHAPI.Helper.ResyncHealthOfPlayer) ~= "function"
		or type(CHAPI.PersistentData) ~= "table" or type(CHAPI.PersistentData.OverriddenFunctions) ~= "table"
		or type(CHAPI.Helper.HookFunctions) ~= "table" then
		Isaac.DebugString("[LocalFixes] CHAPI cache: CustomHealthAPI not found, skipped")
		return false
	end
	local H, o, HF = CHAPI.Helper, CHAPI.PersistentData.OverriddenFunctions, CHAPI.Helper.HookFunctions
	for _, name in ipairs({ "GetMaxHearts", "GetHearts", "GetSoulHearts", "GetBlackHearts", "GetBoneHearts",
		"GetGoldenHearts", "GetEternalHearts", "GetRottenHearts", "GetBrokenHearts", "GetEffectiveMaxHearts",
		"GetHeartLimit", "GetEffects", "HasCollectible" }) do
		if type(o[name]) ~= "function" then
			Isaac.DebugString("[LocalFixes] CHAPI cache: no original " .. name .. ", skipped")
			return false
		end
	end
	local origResync = H.ResyncHealthOfPlayer
	local getGullet = o.GetGreedsGulletHearts
	local NULL_SUN, NULL_EMPRESS = NullItemID.ID_REVERSE_SUN, NullItemID.ID_REVERSE_EMPRESS
	local NULL_SHACKLES = NullItemID.ID_SPIRIT_SHACKLES_DISABLED
	local ALABASTER = CollectibleType.COLLECTIBLE_ALABASTER_BOX
	local GetFrameCount, GetPtrHash = Isaac.GetFrameCount, GetPtrHash

	-- Поколение: растёт при любом изменении через CHAPI.
	local gen = 0
	local tracked = 0
	local function bump(tbl, k, v)
		tbl[k] = function(...)
			gen = gen + 1
			return v(...)
		end
		tracked = tracked + 1
	end
	for k, v in pairs(CHAPI.Library) do
		if type(v) == "function" and (k:match("^Add") or k:match("^Set") or k:match("^Remove") or k:match("^Clear")
			or k:match("^Reset") or k:match("^Increment") or k:match("^Decrement") or k:match("^Change")
			or k:match("^Override") or k:match("^Register") or k:match("^Unregister") or k:match("^Try")) then
			bump(CHAPI.Library, k, v)
		end
	end
	local isGetter = {}
	for _, n in ipairs(GETTERS) do isGetter[n] = true end
	for k, v in pairs(HF) do
		if type(v) == "function" and not isGetter[k] and not PASSTHROUGH[k] then
			bump(HF, k, v) -- AddHearts, TakeDamage*, ChangePlayerType, Revive, AddCollectible, EvaluateItems …
		end
	end

	local scratch = {}
	local N = 27
	-- «Медленная» часть отпечатка (вызовы через прослойку движка ~0,5 мкс каждый: тип игрока и здоровья, эффекты,
	-- подчинённый игрок, Alabaster Box) меняется редко — считаем её раз за кадр на игрока и заново после любого
	-- изменения через CHAPI (поколение). Быстрая часть (оригинальные значения сердец, накладки, флаги) — каждый раз.
	local slowCache = {}
	local function slowPart(p, frame)
		local key = GetPtrHash(p)
		local sc = slowCache[key]
		if sc and sc.frame == frame and sc.gen == gen then return sc end
		if not sc then
			sc = {}
			slowCache[key] = sc
		end
		local eff = o.GetEffects(p)
		sc.frame, sc.gen = frame, gen
		sc.ptype = p:GetPlayerType()
		sc.htype = p:GetHealthType()
		sc.sun = eff:HasNullEffect(NULL_SUN) and 1 or 0
		sc.empress = eff:HasNullEffect(NULL_EMPRESS) and 1 or 0
		sc.shackles = eff:GetNullEffectNum(NULL_SHACKLES)
		if o.HasCollectible(p, ALABASTER) then
			sc.alabaster = p:GetActiveCharge(0) + p:GetActiveCharge(1) * 100 + p:GetActiveCharge(2) * 10000 + 1
		else
			sc.alabaster = 0
		end
		sc.sub = p:GetSubPlayer() and 1 or 0
		return sc
	end
	local function fill(p, frame)
		local sd = H.GetSavedata and H.GetSavedata(p) or nil
		local od = H.GetOtherData and H.GetOtherData(p) or nil
		local sc = slowPart(p, frame)
		local overlaySum, overlayCount = 0, 0
		if sd and type(sd.Overlays) == "table" then
			for _, v in pairs(sd.Overlays) do
				if type(v) == "number" then overlaySum = overlaySum + v end
				overlayCount = overlayCount + 1
			end
		end
		local s = scratch
		s[1] = gen
		s[2] = sc.ptype
		s[3] = sc.htype
		s[4] = o.GetMaxHearts(p)
		s[5] = o.GetHearts(p)
		s[6] = o.GetSoulHearts(p)
		s[7] = o.GetBlackHearts(p)
		s[8] = o.GetBoneHearts(p)
		s[9] = o.GetGoldenHearts(p)
		s[10] = o.GetEternalHearts(p)
		s[11] = o.GetRottenHearts(p)
		s[12] = o.GetBrokenHearts(p)
		s[13] = o.GetEffectiveMaxHearts(p)
		-- GetHeartLimit в отпечаток не берём: у REPENTOGON он вызывает MC_PLAYER_GET_HEART_LIMIT всех модов (17,7 мкс).
		-- Лимит меняется вместе с предметами/персонажем — это ловят поколение (AddCollectible, EvaluateItems), тип
		-- игрока и сердца; иначе кэш отстаёт не больше чем на кадр.
		s[14] = 0
		s[15] = getGullet and getGullet(p) or 0
		s[16] = sc.sun
		s[17] = sc.empress
		s[18] = sc.shackles
		s[19] = sc.alabaster
		s[20] = overlaySum
		s[21] = overlayCount
		s[22] = (sd and sd.HasReverseSun) and 1 or 0
		s[23] = (sd and type(sd.ReverseEmpressHPToRemove) == "table") and #sd.ReverseEmpressHPToRemove or 0
		s[24] = sc.sub
		-- флаги урона CHAPI: пока они стоят — всегда полный путь
		s[25] = (od and (od.InDamageCallback ~= nil or od.DoNotUpdateBasegameHealthState ~= nil)) and 1 or 0
		s[26] = (sd and (sd.InDamageCallback ~= nil or sd.DoNotUpdateBasegameHealthState ~= nil)) and 1 or 0
		s[27] = frame
	end
	local function same(c)
		for i = 1, N do
			if c[i] ~= scratch[i] then return false end
		end
		return true
	end
	local function store(c)
		for i = 1, N do c[i] = scratch[i] end
	end
	local function preventing()
		local pd = CHAPI.PersistentData
		return pd.PreventResyncing == true or (type(pd.PreventResyncing) == "number" and pd.PreventResyncing > 0)
	end

	local depth = 0 -- >0: идёт полная пересинхронизация или полный геттер — вложенное всегда полным путём
	local stats = { rh = 0, rm = 0, gh = 0, gm = 0 }

	-- 1) Пересинхронизация
	local rcache = {}
	H.ResyncHealthOfPlayer = function(player, isSubPlayer)
		if depth > 0 or not player or preventing() then
			depth = depth + 1
			origResync(player, isSubPlayer)
			depth = depth - 1
			return
		end
		local key = GetPtrHash(player)
		local frame = GetFrameCount()
		local c = rcache[key]
		fill(player, frame)
		if c and scratch[25] == 0 and scratch[26] == 0 and same(c) then
			stats.rh = stats.rh + 1
			return
		end
		stats.rm = stats.rm + 1
		depth = depth + 1
		origResync(player, isSubPlayer)
		depth = depth - 1
		fill(player, frame) -- отпечаток после (пересинхронизация сама могла поправить здоровье)
		if not c then
			c = {}
			rcache[key] = c
		end
		store(c)
	end

	-- 2) Геттеры здоровья
	local gcache = {} -- [функция][хэш игрока * 64 + аргумент] = {отпечаток…, r = результат} (без строк — без мусора)
	for _, name in ipairs(GETTERS) do
		local f = HF[name]
		if type(f) == "function" then
			local byName = {}
			gcache[name] = byName
			HF[name] = function(player, a, ...)
				if depth > 0 or preventing() or select("#", ...) > 0 or type(player) ~= "userdata"
					or (a ~= nil and math.type(a) ~= "integer") or (a ~= nil and (a < 0 or a > 63)) then
					depth = depth + 1
					local r1, r2 = f(player, a, ...)
					depth = depth - 1
					return r1, r2
				end
				local frame = GetFrameCount()
				local key = GetPtrHash(player) * 64 + (a or 0)
				local c = byName[key]
				fill(player, frame)
				if c and scratch[25] == 0 and scratch[26] == 0 and same(c) then
					stats.gh = stats.gh + 1
					return c.r
				end
				stats.gm = stats.gm + 1
				depth = depth + 1
				local r = f(player, a)
				depth = depth - 1
				fill(player, frame) -- после вызова (геттер мог пересинхронизировать здоровье)
				if not c then
					c = {}
					byName[key] = c
				end
				store(c)
				c.r = r
				return r
			end
		end
	end

	-- Новый этаж/забег — чистим кэши (ключи — хэши указателей сущностей).
	LOCALFIXES.ClearCHAPICache = function()
		for k in pairs(rcache) do rcache[k] = nil end
		for k in pairs(slowCache) do slowCache[k] = nil end
		for _, byName in pairs(gcache) do
			for k in pairs(byName) do byName[k] = nil end
		end
	end

	installed = true
	LOCALFIXES.CHAPIResyncStats = function() return stats.rh, stats.rm, stats.gh, stats.gm end
	Isaac.DebugString("[LocalFixes] CHAPI cache installed (" .. tracked .. " mutators tracked)")
	return true
end
