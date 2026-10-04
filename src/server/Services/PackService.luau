local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Packs = require(ReplicatedStorage.Shared.Config.Packs)
local Money = require(ReplicatedStorage.Shared.Money)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local PackService = {}

local rng = Random.new()

local function pickRarity(weights: { [string]: number }): string
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = rng:NextNumber() * total
	-- Walk rarities in a fixed order so results don't depend on table order.
	local last = "Common"
	for _, rarity in Cards.RarityOrder do
		local weight = weights[rarity]
		if weight then
			last = rarity
			roll -= weight
			if roll <= 0 then
				return rarity
			end
		end
	end
	return last
end

-- Hidden 1-100 condition score. Most cards come out clean, a few are dinged.
local function rollCondition(): number
	if rng:NextNumber() < 0.05 then
		return rng:NextInteger(10, 39)
	end
	return math.floor(40 + 60 * rng:NextNumber() ^ 0.6 + 0.5)
end

local function pickCard(setId: string?, rarity: string): string
	if not setId then
		-- Multi-set packs: pick a set that actually has this rarity.
		local candidates = {}
		for _, set in Cards.Sets do
			if Cards.BySetRarity[set.id][rarity] then
				table.insert(candidates, set.id)
			end
		end
		setId = if #candidates > 0 then candidates[rng:NextInteger(1, #candidates)] else Cards.Sets[1].id
	end
	local byRarity = Cards.BySetRarity[setId :: string]
	local pool = byRarity[rarity] or byRarity.Common or byRarity.Rare
	return pool[rng:NextInteger(1, #pool)]
end

function PackService.init()
	Remotes.register("BuyPack", function(player, packId)
		local data = DataService.get(player)
		if not data then
			return false, "Still loading your save..."
		end
		local pack = Packs.ById[packId]
		if not pack then
			return false, "Unknown pack"
		end
		if data.reputation < pack.reputation then
			return false, `Requires {pack.reputation} reputation`
		end
		if data.cash < pack.price then
			return false, "Not enough cash"
		end
		if DataService.countCards(data) + pack.cardsPerPack > Economy.MaxCards then
			return false, "Your collection is full! Sell some cards first."
		end

		data.cash = Money.round(data.cash - pack.price)
		local pulled = {}
		for slot = 1, pack.cardsPerPack do
			local weights = if slot == pack.cardsPerPack then pack.hitWeights else pack.slotWeights
			local cardId = pickCard(pack.setId, pickRarity(weights))
			table.insert(pulled, DataService.newCard(data, cardId, rollCondition()))
		end
		data.stats.packsOpened += 1
		DataService.markDirty(player)
		return true, pulled
	end)
end

return PackService
