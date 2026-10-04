-- Tunable numbers for the economy and selling channels.

local Economy = {}

Economy.StartingCash = 50
Economy.MaxCards = 400
Economy.MinPrice = 0.01
Economy.MaxPrice = 10_000_000

-- Selling directly to the bulk dealer. Instant, but no reputation.
Economy.DealerRate = 0.5

-- Reputation earned from a sale through the store, online or at a show.
function Economy.ReputationForSale(price: number): number
	return 1 + math.floor(price / 20)
end

Economy.Store = {
	TickInterval = 4,
	BuyChance = 0.55,
	Tolerance = 1.5, -- buyers walk away at 150% of market value
	Levels = {
		{ name = "Folding Table", slots = 4, traffic = 0.35, cost = 0 },
		{ name = "Corner Shop", slots = 6, traffic = 0.45, cost = 250 },
		{ name = "Hobby Store", slots = 9, traffic = 0.55, cost = 1_000 },
		{ name = "Card Emporium", slots = 12, traffic = 0.65, cost = 4_000 },
		{ name = "Collector's Gallery", slots = 16, traffic = 0.75, cost = 12_000 },
		{ name = "Flagship Megastore", slots = 24, traffic = 0.9, cost = 40_000 },
	},
}

Economy.Online = {
	TickInterval = 5,
	BaseChance = 0.06,
	Tolerance = 1.3, -- online buyers compare prices, so they're pickier
	FeeRate = 0.12,
	GradedBonus = 1.25,
	MaxListings = 30,
}

Economy.Shows = {
	TickInterval = 2,
	BuyChance = 0.5,
	MinMarkup = 0.8,
	MaxMarkup = 2,
	List = {
		{
			id = "meetup",
			name = "Local Card Meetup",
			fee = 25,
			duration = 60,
			maxCards = 8,
			buyerChance = 0.55,
			tolerance = 1.45,
			gradedBonus = 1.1,
			reputation = 0,
		},
		{
			id = "expo",
			name = "Regional Card Expo",
			fee = 250,
			duration = 90,
			maxCards = 16,
			buyerChance = 0.7,
			tolerance = 1.6,
			gradedBonus = 1.25,
			reputation = 150,
		},
		{
			id = "worlds",
			name = "World Collectors Show",
			fee = 2_000,
			duration = 120,
			maxCards = 30,
			buyerChance = 0.85,
			tolerance = 1.8,
			gradedBonus = 1.5,
			reputation = 600,
		},
	},
}

Economy.ShowsById = {}
for _, show in Economy.Shows.List do
	Economy.ShowsById[show.id] = show
end

Economy.Market = {
	UpdateInterval = 45,
	MinTrend = 0.6,
	MaxTrend = 1.8,
	Reversion = 0.1,
	Volatility = 0.06,
	SpikeChance = 0.08,
}

return Economy
