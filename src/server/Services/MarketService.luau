-- Server-wide market trends. Each card drifts around 1.0 with occasional
-- spikes, so the same card is worth more or less depending on timing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Remotes = require(script.Parent.Remotes)

local MarketService = {}

local rng = Random.new()
local trends: { [string]: number } = {}

for id in Cards.ById do
	trends[id] = 1
end

local function gaussian(): number
	local u1 = math.max(rng:NextNumber(), 1e-9)
	local u2 = rng:NextNumber()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

local function round(x: number): number
	return math.floor(x * 1000 + 0.5) / 1000
end

local function step()
	local config = Economy.Market
	for id, trend in trends do
		trend += (1 - trend) * config.Reversion + gaussian() * config.Volatility
		trends[id] = round(math.clamp(trend, config.MinTrend, config.MaxTrend))
	end

	if rng:NextNumber() < config.SpikeChance then
		local ids = {}
		for id in trends do
			table.insert(ids, id)
		end
		local id = ids[rng:NextInteger(1, #ids)]
		trends[id] = round(math.clamp(trends[id] * 1.5, config.MinTrend, config.MaxTrend))
		local name = Cards.ById[id].name
		for _, player in Players:GetPlayers() do
			Remotes.notify(player, `📈 {name} is trending! Prices are up.`, "trend")
		end
	end

	Remotes.Market:FireAllClients(trends)
end

function MarketService.trends(): { [string]: number }
	return trends
end

function MarketService.init()
	Players.PlayerAdded:Connect(function(player)
		Remotes.Market:FireClient(player, trends)
	end)

	Remotes.register("GetMarket", function()
		return true, trends
	end)

	task.spawn(function()
		while true do
			task.wait(Economy.Market.UpdateInterval)
			step()
		end
	end)
end

return MarketService
