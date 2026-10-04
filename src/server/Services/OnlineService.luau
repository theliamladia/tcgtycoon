-- Online marketplace: lots of listings and a global audience, but buyers
-- are price-savvy and the platform takes a cut.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Money = require(ReplicatedStorage.Shared.Money)
local Valuation = require(ReplicatedStorage.Shared.Valuation)
local DataService = require(script.Parent.DataService)
local MarketService = require(script.Parent.MarketService)
local Remotes = require(script.Parent.Remotes)
local Sales = require(script.Parent.Sales)

local OnlineService = {}

local rng = Random.new()
local config = Economy.Online

local function tick(player: Player, data)
	local trends = MarketService.trends()
	local sold = {}
	for _, card in data.cards do
		if card.location == "online" then
			local value = Valuation.value(card, trends)
			local chance = config.BaseChance * Valuation.demand(card.price / value, config.Tolerance)
			if card.grade then
				chance *= config.GradedBonus
			end
			if rng:NextNumber() < chance then
				table.insert(sold, card)
			end
		end
	end
	for _, card in sold do
		Sales.complete(player, data, card, card.price, config.FeeRate, "🌐 Online")
	end
end

function OnlineService.init()
	Remotes.register("ListOnline", function(player, uid, price)
		local data = DataService.get(player)
		if not data then
			return false, "Still loading your save..."
		end
		local card = type(uid) == "string" and data.cards[uid]
		if not card or card.location ~= "inventory" then
			return false, "That card isn't available"
		end
		if not Sales.validPrice(price) then
			return false, "Invalid price"
		end
		if DataService.countAt(data, "online") >= config.MaxListings then
			return false, `You can only have {config.MaxListings} online listings`
		end
		card.location = "online"
		card.price = Money.round(price)
		DataService.markDirty(player)
		return true
	end)

	task.spawn(function()
		while true do
			task.wait(config.TickInterval)
			for player, data in DataService.getAll() do
				tick(player, data)
			end
		end
	end)
end

return OnlineService
