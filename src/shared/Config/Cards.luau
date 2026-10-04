-- Card sets, rarities and base market values.
-- `value` is the market price of a raw Near Mint copy before trends.

local Cards = {}

Cards.RarityOrder = { "Common", "Uncommon", "Rare", "HoloRare", "UltraRare", "SecretRare" }

Cards.Rarities = {
	Common = { name = "Common", order = 1, color = Color3.fromRGB(176, 180, 190) },
	Uncommon = { name = "Uncommon", order = 2, color = Color3.fromRGB(88, 204, 112) },
	Rare = { name = "Rare", order = 3, color = Color3.fromRGB(64, 156, 255) },
	HoloRare = { name = "Holo Rare", order = 4, color = Color3.fromRGB(176, 98, 255) },
	UltraRare = { name = "Ultra Rare", order = 5, color = Color3.fromRGB(255, 196, 46) },
	SecretRare = { name = "Secret Rare", order = 6, color = Color3.fromRGB(255, 72, 120) },
}

Cards.Sets = {
	{
		id = "genesis",
		name = "Genesis",
		color = Color3.fromRGB(232, 98, 52),
		cards = {
			{ id = "gen_emberpup", name = "Emberpup", rarity = "Common", value = 0.15 },
			{ id = "gen_pebblet", name = "Pebblet", rarity = "Common", value = 0.12 },
			{ id = "gen_driftfin", name = "Driftfin", rarity = "Common", value = 0.14 },
			{ id = "gen_sproutling", name = "Sproutling", rarity = "Common", value = 0.12 },
			{ id = "gen_zapkit", name = "Zapkit", rarity = "Common", value = 0.18 },
			{ id = "gen_mossback", name = "Mossback", rarity = "Uncommon", value = 0.35 },
			{ id = "gen_cindertail", name = "Cindertail", rarity = "Uncommon", value = 0.45 },
			{ id = "gen_tidecaller", name = "Tidecaller", rarity = "Uncommon", value = 0.40 },
			{ id = "gen_voltwing", name = "Voltwing", rarity = "Rare", value = 1.50 },
			{ id = "gen_stonejaw", name = "Stonejaw", rarity = "Rare", value = 1.25 },
			{ id = "gen_blazewyrm", name = "Blazewyrm", rarity = "HoloRare", value = 8 },
			{ id = "gen_leviathorn", name = "Leviathorn", rarity = "HoloRare", value = 6.5 },
			{ id = "gen_thunderox", name = "Thunderox", rarity = "UltraRare", value = 40 },
			{ id = "gen_dragon", name = "Genesis Dragon", rarity = "SecretRare", value = 250 },
		},
	},
	{
		id = "shadowrift",
		name = "Shadow Rift",
		color = Color3.fromRGB(122, 74, 214),
		cards = {
			{ id = "sr_gloomrat", name = "Gloomrat", rarity = "Common", value = 0.40 },
			{ id = "sr_duskmoth", name = "Duskmoth", rarity = "Common", value = 0.35 },
			{ id = "sr_hexling", name = "Hexling", rarity = "Common", value = 0.45 },
			{ id = "sr_shadepup", name = "Shadepup", rarity = "Common", value = 0.50 },
			{ id = "sr_murkfish", name = "Murkfish", rarity = "Common", value = 0.35 },
			{ id = "sr_wraithhound", name = "Wraithhound", rarity = "Uncommon", value = 1.10 },
			{ id = "sr_nightbloom", name = "Nightbloom", rarity = "Uncommon", value = 1.25 },
			{ id = "sr_cryptkeeper", name = "Cryptkeeper", rarity = "Uncommon", value = 1.40 },
			{ id = "sr_voidstalker", name = "Voidstalker", rarity = "Rare", value = 4.50 },
			{ id = "sr_eclipseowl", name = "Eclipse Owl", rarity = "Rare", value = 4 },
			{ id = "sr_phantomking", name = "Phantom King", rarity = "HoloRare", value = 24 },
			{ id = "sr_abyssserpent", name = "Abyss Serpent", rarity = "HoloRare", value = 20 },
			{ id = "sr_rifttitan", name = "Rift Titan", rarity = "UltraRare", value = 120 },
			{ id = "sr_umbraempress", name = "Umbra Empress", rarity = "SecretRare", value = 750 },
		},
	},
	{
		id = "celestial",
		name = "Celestial Crown",
		color = Color3.fromRGB(46, 170, 230),
		cards = {
			{ id = "cc_starling", name = "Starling", rarity = "Common", value = 1.00 },
			{ id = "cc_cometcub", name = "Comet Cub", rarity = "Common", value = 0.90 },
			{ id = "cc_lunarhare", name = "Lunar Hare", rarity = "Common", value = 1.10 },
			{ id = "cc_nebulafox", name = "Nebula Fox", rarity = "Common", value = 1.25 },
			{ id = "cc_sunpetal", name = "Sunpetal", rarity = "Common", value = 0.90 },
			{ id = "cc_aurorastag", name = "Aurora Stag", rarity = "Uncommon", value = 2.75 },
			{ id = "cc_meteorgolem", name = "Meteorite Golem", rarity = "Uncommon", value = 3 },
			{ id = "cc_orbitjelly", name = "Orbit Jelly", rarity = "Uncommon", value = 3.50 },
			{ id = "cc_solarlion", name = "Solar Lion", rarity = "Rare", value = 11 },
			{ id = "cc_galaxywhale", name = "Galaxy Whale", rarity = "Rare", value = 10 },
			{ id = "cc_astralphoenix", name = "Astral Phoenix", rarity = "HoloRare", value = 60 },
			{ id = "cc_cosmicseraph", name = "Cosmic Seraph", rarity = "HoloRare", value = 50 },
			{ id = "cc_sovereign", name = "Celestial Sovereign", rarity = "UltraRare", value = 300 },
			{ id = "cc_eternity", name = "Crown of Eternity", rarity = "SecretRare", value = 1900 },
		},
	},
}

-- Lookup tables built from the definitions above.
Cards.ById = {}
Cards.SetsById = {}
Cards.BySetRarity = {}

for _, set in Cards.Sets do
	Cards.SetsById[set.id] = set
	local byRarity = {}
	Cards.BySetRarity[set.id] = byRarity
	for _, card in set.cards do
		card.setId = set.id
		Cards.ById[card.id] = card
		byRarity[card.rarity] = byRarity[card.rarity] or {}
		table.insert(byRarity[card.rarity], card.id)
	end
end

return Cards
