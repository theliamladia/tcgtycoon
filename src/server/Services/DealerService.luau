-- The bulk dealer buys anything instantly at a discount. No reputation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Money = require(ReplicatedStorage.Shared.Money)
local Valuation = require(ReplicatedStorage.Shared.Valuation)
local DataService = require(script.Parent.DataService)
local MarketService = require(script.Parent.MarketService)
local Remotes = require(script.Parent.Remotes)

local DealerService = {}

function DealerService.init()
	Remotes.register("QuickSell", function(player, uids)
		local data = DataService.get(player)
		if not data then
			return false, "Still loading your save..."
		end
		if type(uids) ~= "table" or #uids == 0 or #uids > Economy.MaxCards then
			return false, "Invalid request"
		end

		local trends = MarketService.trends()
		local total = 0
		local count = 0
		for _, uid in uids do
			local card = type(uid) == "string" and data.cards[uid]
			if card and card.location == "inventory" then
				total += Money.round(Valuation.value(card, trends) * Economy.DealerRate)
				data.cards[uid] = nil
				count += 1
			end
		end
		if count == 0 then
			return false, "Nothing to sell"
		end

		total = Money.round(total)
		data.cash = Money.round(data.cash + total)
		data.stats.totalEarned = Money.round(data.stats.totalEarned + total)
		DataService.markDirty(player)
		Remotes.notify(player, `💵 Dealer bought {count} card(s) for {Money.format(total)}`, "sale")
		return true, total
	end)
end

return DealerService
