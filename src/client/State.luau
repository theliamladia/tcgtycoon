-- Client-side mirror of the player's data and the market, plus a helper
-- for calling server actions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Valuation = require(Shared:WaitForChild("Valuation"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local State = {}

State.data = nil
State.trends = {} :: { [string]: number }

local changedEvent = Instance.new("BindableEvent")
State.changed = changedEvent.Event

Remotes:WaitForChild("Sync").OnClientEvent:Connect(function(data)
	State.data = data
	changedEvent:Fire("data")
end)

Remotes:WaitForChild("Market").OnClientEvent:Connect(function(trends)
	State.trends = trends
	changedEvent:Fire("market")
end)

local actionRemote = Remotes:WaitForChild("Action") :: RemoteFunction

function State.action(name: string, ...): (boolean, any)
	local ok, success, result = pcall(actionRemote.InvokeServer, actionRemote, name, ...)
	if not ok then
		return false, "Connection problem"
	end
	return success, result
end

function State.value(card): number
	return Valuation.value(card, State.trends)
end

function State.trend(cardId: string): number
	return State.trends[cardId] or 1
end

function State.cards(filter: ((any) -> boolean)?): { any }
	local list = {}
	if not State.data then
		return list
	end
	for _, card in State.data.cards do
		if not filter or filter(card) then
			table.insert(list, card)
		end
	end
	return list
end

function State.cardsAt(location: string): { any }
	return State.cards(function(card)
		return card.location == location
	end)
end

function State.sortByValue(list: { any })
	table.sort(list, function(a, b)
		local va, vb = State.value(a), State.value(b)
		if va == vb then
			return a.uid < b.uid
		end
		return va > vb
	end)
	return list
end

task.spawn(function()
	State.action("RequestSync")
	local ok, trends = State.action("GetMarket")
	if ok then
		State.trends = trends
		changedEvent:Fire("market")
	end
end)

return State
