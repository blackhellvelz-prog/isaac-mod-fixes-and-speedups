-- Порченый Моисей (IPECAC): седые волосы своим костюмом (content/costumes2.xml этого мода; кожа, волосы, портрет и
-- надпись — ресурсы мода по путям из players.xml IPECAC, tools/gen_moses_b.py). Без IPECAC — ничего не делает.
-- Кладётся в мод Мастерской вместе с перерисованной графикой (группа moses_b в tools/build_workshop.py).
local mod = LOCALFIXES.Mod
local HAIR = "gfx/characters/character_moses_b_hair.anm2"

local function hair(_, player)
	local pt = Isaac.GetPlayerTypeByName("Moses", true)
	if not pt or pt < 0 or player:GetPlayerType() ~= pt then return end
	local d = player:GetData()
	if d.lfMosesHair then return end
	local id = Isaac.GetCostumeIdByPath(HAIR)
	if id and id >= 0 then
		player:AddNullCostume(id)
		d.lfMosesHair = true
	end
end
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, hair)
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function()   -- продолжение забега: костюм заново
	for i = 0, Game():GetNumPlayers() - 1 do hair(nil, Isaac.GetPlayer(i)) end
end)
