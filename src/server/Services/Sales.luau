-- Finalises a sale from any channel: removes the card, pays the player,
-- grants reputation and tells them about it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Money = require(ReplicatedStorage.Shared.Money)
local Valuation = require(ReplicatedStorage.Shared.Valuation)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local Sales = {}

function Sales.validPrice(price: any): boolean
	return Money.isValid(price) and price >= Economy.MinPrice and price <= Economy.MaxPrice
end

function Sales.complete(player: Player, data, card, price: number, feeRate: number, channel: string): number
	local fee = Money.round(price * feeRate)
	local net = Money.round(price - fee)

	data.cards[card.uid] = nil
	data.cash = Money.round(data.cash + net)
	data.reputation += Economy.ReputationForSale(price)
	data.stats.cardsSold += 1
	data.stats.totalEarned = Money.round(data.stats.totalEarned + net)
	data.stats.bestSale = math.max(data.stats.bestSale, price)
	DataService.markDirty(player)

	local def = Cards.ById[card.cardId]
	local name = if def then def.name else "a card"
	local label = if card.grade then `{name} ({Valuation.describe(card)})` else name
	Remotes.notify(player, `{channel}: sold {label} for {Money.format(net)}`, "sale")
	return net
end

return Sales
