-- Card shows: pay for a table, bring a box of cards, and sell to a crowd
-- for a limited time. Bigger shows pay more for graded slabs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Money = require(ReplicatedStorage.Shared.Money)
local Valuation = require(ReplicatedStorage.Shared.Valuation)
local DataService = require(script.Parent.DataService)
local MarketService = require(script.Parent.MarketService)
local Remotes = require(script.Parent.Remotes)
local Sales = require(script.Parent.Sales)

local ShowService = {}

local rng = Random.new()

local function endShow(player: Player, data)
	local show = data.show
	local def = Economy.ShowsById[show.id]
	local returned = 0
	for _, card in data.cards do
		if card.location == "show" then
			card.location = "inventory"
			card.price = nil
			returned += 1
		end
	end
	data.show = nil
	DataService.markDirty(player)
	Remotes.notify(
		player,
		`🎪 {def.name} is over! Sold {show.sold} for {Money.format(show.earned)}. {returned} cards came home.`,
		"gem"
	)
end

local function tick(player: Player, data)
	local show = data.show
	if workspace:GetServerTimeNow() >= show.endsAt then
		endShow(player, data)
		return
	end
	local def = Economy.ShowsById[show.id]
	if rng:NextNumber() >= def.buyerChance then
		return
	end
	local onTable = {}
	for _, card in data.cards do
		if card.location == "show" then
			table.insert(onTable, card)
		end
	end
	if #onTable == 0 then
		return
	end
	local card = onTable[rng:NextInteger(1, #onTable)]
	local value = Valuation.value(card, MarketService.trends())
	if card.grade then
		value *= def.gradedBonus
	end
	local demand = Valuation.demand(card.price / value, def.tolerance)
	if rng:NextNumber() < demand * Economy.Shows.BuyChance then
		local price = card.price
		local net = Sales.complete(player, data, card, price, 0, "🎪 Show")
		show.sold += 1
		show.earned = Money.round(show.earned + net)
	end
end

function ShowService.init()
	Remotes.register("StartShow", function(player, showId, uids, markup)
		local data = DataService.get(player)
		if not data then
			return false, "Still loading your save..."
		end
		local def = Economy.ShowsById[showId]
		if not def then
			return false, "Unknown show"
		end
		if data.show then
			return false, "You're already at a show"
		end
		if data.reputation < def.reputation then
			return false, `Requires {def.reputation} reputation`
		end
		if data.cash < def.fee then
			return false, "Not enough cash for the table fee"
		end
		if not Money.isValid(markup) or markup < Economy.Shows.MinMarkup or markup > Economy.Shows.MaxMarkup then
			return false, "Invalid markup"
		end
		if type(uids) ~= "table" or #uids == 0 or #uids > def.maxCards then
			return false, `Bring between 1 and {def.maxCards} cards`
		end

		local cards = {}
		local seen = {}
		for _, uid in uids do
			local card = type(uid) == "string" and data.cards[uid]
			if not card or card.location ~= "inventory" or seen[uid] then
				return false, "Some of those cards aren't available"
			end
			seen[uid] = true
			table.insert(cards, card)
		end

		local trends = MarketService.trends()
		data.cash = Money.round(data.cash - def.fee)
		for _, card in cards do
			card.location = "show"
			card.price = Money.round(math.max(Economy.MinPrice, Valuation.value(card, trends) * markup))
		end
		data.show = {
			id = def.id,
			endsAt = workspace:GetServerTimeNow() + def.duration,
			markup = markup,
			sold = 0,
			earned = 0,
		}
		DataService.markDirty(player)
		return true
	end)

	task.spawn(function()
		while true do
			task.wait(Economy.Shows.TickInterval)
			for player, data in DataService.getAll() do
				if data.show then
					tick(player, data)
				end
			end
		end
	end)
end

return ShowService
