-- Booster packs. The last card of every pack is the "hit" slot and uses
-- `hitWeights`; every other slot uses `slotWeights`. `setId = nil` pulls
-- each card from a random set.

local Packs = {}

local STANDARD_SLOT = { Common = 70, Uncommon = 25, Rare = 5 }
local STANDARD_HIT = { Rare = 85, HoloRare = 12, UltraRare = 2.6, SecretRare = 0.4 }

Packs.List = {
	{
		id = "genesis_booster",
		name = "Genesis Booster",
		setId = "genesis",
		price = 4,
		cardsPerPack = 5,
		reputation = 0,
		slotWeights = STANDARD_SLOT,
		hitWeights = STANDARD_HIT,
	},
	{
		id = "shadowrift_booster",
		name = "Shadow Rift Booster",
		setId = "shadowrift",
		price = 12,
		cardsPerPack = 5,
		reputation = 40,
		slotWeights = STANDARD_SLOT,
		hitWeights = STANDARD_HIT,
	},
	{
		id = "celestial_booster",
		name = "Celestial Crown Booster",
		setId = "celestial",
		price = 30,
		cardsPerPack = 5,
		reputation = 200,
		slotWeights = STANDARD_SLOT,
		hitWeights = STANDARD_HIT,
	},
	{
		id = "mystery_vault",
		name = "Mystery Vault Pack",
		setId = nil,
		price = 250,
		cardsPerPack = 3,
		reputation = 800,
		color = Color3.fromRGB(40, 40, 48),
		slotWeights = { HoloRare = 70, UltraRare = 25, SecretRare = 5 },
		hitWeights = { HoloRare = 70, UltraRare = 25, SecretRare = 5 },
	},
}

Packs.ById = {}
for _, pack in Packs.List do
	Packs.ById[pack.id] = pack
end

return Packs
