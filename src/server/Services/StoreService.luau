-- Your own card shop: limited shelf space, steady walk-in customers, no fees.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Money = require(ReplicatedStorage.Shared.Money)
local Valuation = require(ReplicatedStorage.Shared.Valuation)
local DataService = require(script.Parent.DataService)
local MarketService = require(script.Parent.MarketService)
local Remotes = require(script.Parent.Remotes)
local Sales = require(script.Parent.Sales)

local StoreService = {}

local rng = Random.new()

local function tick(player: Player, data)
	local level = Economy.Store.Levels[data.storeLevel] or Economy.Store.Levels[1]
	if rng:NextNumber() >= level.traffic then
		return
	end
	local shelf = {}
	for _, card in data.cards do
		if card.location == "store" then
			table.insert(shelf, card)
		end
	end
	if #shelf == 0 then
		return
	end
	local card = shelf[rng:NextInteger(1, #shelf)]
	local value = Valuation.value(card, MarketService.trends())
	local demand = Valuation.demand(card.price / value, Economy.Store.Tolerance)
	if rng:NextNumber() < demand * Economy.Store.BuyChance then
		Sales.complete(player, data, card, card.price, 0, "🏪 Store")
	end
end

function StoreService.init()
	Remotes.register("ListStore", function(player, uid, price)
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
		local level = Economy.Store.Levels[data.storeLevel]
		if DataService.countAt(data, "store") >= level.slots then
			return false, "Your shelves are full. Upgrade your store!"
		end
		card.location = "store"
		card.price = Money.round(price)
		DataService.markDirty(player)
		return true
	end)

	Remotes.register("Unlist", function(player, uid)
		local data = DataService.get(player)
		if not data then
			return false, "Still loading your save..."
		end
		local card = type(uid) == "string" and data.cards[uid]
		if not card or (card.location ~= "store" and card.location ~= "online") then
			return false, "That card isn't listed"
		end
		card.location = "inventory"
		card.price = nil
		DataService.markDirty(player)
		return true
	end)

	Remotes.register("UpgradeStore", function(player)
		local data = DataService.get(player)
		if not data then
			return false, "Still loading your save..."
		end
		local nextLevel = Economy.Store.Levels[data.storeLevel + 1]
		if not nextLevel then
			return false, "Your store is fully upgraded"
		end
		if data.cash < nextLevel.cost then
			return false, "Not enough cash"
		end
		data.cash = Money.round(data.cash - nextLevel.cost)
		data.storeLevel += 1
		DataService.markDirty(player)
		Remotes.notify(player, `🏪 Upgraded to {nextLevel.name}!`, "gem")
		return true
	end)

	task.spawn(function()
		while true do
			task.wait(Economy.Store.TickInterval)
			for player, data in DataService.getAll() do
				tick(player, data)
			end
		end
	end)
end

return StoreService
