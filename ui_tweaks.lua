-- localfixes: мелкие улучшения интерфейсов модов (18.10, просьба пользователя «переделать интерфейсы модов — более
-- удобные для пользователя»).
-- 1) Образец описания EID в Mod Config Menu (вкладки EID «Вид» и др.: EID показывает демо-описание, чтобы видеть
--    шрифт, прозрачность, положение) рисовался прямо поверх списка модов MCM — буквы на буквах, не прочитать. Под
--    образцом — тёмная подложка по размеру описания (только пока открыт MCM и показывается именно образец;
--    в забеге EID — как был).
local mod = LOCALFIXES.Mod
local M = {}

local fill
local function fillSprite()
	if fill == nil then
		fill = Sprite()
		fill:Load("gfx/ui/localfixes/keycap.anm2", true)   -- tools/gen_keycap.py: кадр «Fill» — белый пиксель
		if fill:IsLoaded() then fill:SetFrame("Fill", 0) else fill = false end
	end
	return fill or nil
end

local BACK = Color(0.10, 0.08, 0.08, 0.82)

local function drawBacking(desc)
	local f = fillSprite()
	if not (f and EID.getTextPosition) then return end
	local pos = EID:getTextPosition()
	local s = EID.Scale or 1
	local tw = EID.Config["TextboxWidth"] or 130
	local lines = 1 + ((desc.Transformation and desc.Transformation ~= "") and 1 or 0)   -- имя, превращение
	for part in ((desc.Description or "") .. "#"):gmatch("(.-)#") do
		if part ~= "" then
			local ok, t = pcall(EID.fitTextToWidth, EID, EID:replaceShortMarkupStrings(part), tw, EID.BreakUtf8Chars)
			lines = lines + (ok and type(t) == "table" and #t or 1)
		end
	end
	local lh = EID.Config["LineHeight"] or 11
	f.Color = BACK
	f.Scale = Vector(tw * s + 30, lines * lh * s + 12)
	f:Render(Vector(pos.X - 8, pos.Y - 7))
end

function M.hookEID()
	if not (EID and EID.printDescription) or EID.__localfixesBacking then return end
	EID.__localfixesBacking = true
	-- 2) образец EID по-русски: имя у EID берётся английским (displayPermanentText ставит английское «Demo Object
	--    Name»), а в русском «Демо траснформация» — опечатка
	local ru = EID.descriptions and EID.descriptions["ru"] and EID.descriptions["ru"].MCM
	if ru then
		ru.DemoObjectTransformation = "Демо-превращение"
		local en = EID.descriptions["en_us"] and EID.descriptions["en_us"].MCM
		if en and Options and Options.Language == "ru" then en.DemoObjectName = "Демо-предмет" end
	end
	local orig = EID.printDescription
	EID.printDescription = function(self, desc, cachedID)
		if type(desc) == "table" and desc.ModName == "~~EID-MCM-DEMO~~" and ModConfigMenu and ModConfigMenu.IsVisible then
			pcall(drawBacking, desc)
		end
		return orig(self, desc, cachedID)
	end
end

-- EID грузится после localfixes — перехват, когда все моды загружены
if ModCallbacks.MC_POST_MODS_LOADED then
	mod:AddCallback(ModCallbacks.MC_POST_MODS_LOADED, function() pcall(M.hookEID) end)
end
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function() pcall(M.hookEID) end)

return M
