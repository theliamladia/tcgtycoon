local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Config.Cards)
local Economy = require(Shared.Config.Economy)
local Money = require(Shared.Money)

local Client = script:FindFirstAncestor("Client")
local State = require(Client.State)
local UI = Client.UI
local CardTile = require(UI.CardTile)
local Grid = require(UI.Grid)
local Modals = require(UI.Modals)
local Theme = require(UI.Theme)
local Toasts = require(UI.Toasts)
local Util = require(UI.Util)

local Page = {}

local FILTERS = {
	{ id = "all", name = "All" },
	{ id = "raw", name = "Raw" },
	{ id = "graded", name = "Graded" },
	{ id = "busy", name = "Listed / Away" },
}

local SORTS = {
	{ id = "value", name = "Value" },
	{ id = "rarity", name = "Rarity" },
	{ id = "newest", name = "Newest" },
}

local function matches(card, filter: string): boolean
	if filter == "raw" then
		return card.location == "inventory" and not card.grade
	elseif filter == "graded" then
		return card.grade ~= nil
	elseif filter == "busy" then
		return card.location ~= "inventory"
	end
	return true
end

local function uidNumber(card): number
	return tonumber(card.uid:sub(2)) or 0
end

local function sortCards(list, sort: string)
	local values = {}
	for _, card in list do
		values[card] = State.value(card)
	end
	table.sort(list, function(a, b)
		if sort == "rarity" then
			local ra = Cards.Rarities[Cards.ById[a.cardId].rarity].order
			local rb = Cards.Rarities[Cards.ById[b.cardId].rarity].order
			if ra ~= rb then
				return ra > rb
			end
		elseif sort == "newest" then
			return uidNumber(a) > uidNumber(b)
		end
		if values[a] ~= values[b] then
			return values[a] > values[b]
		end
		return a.uid < b.uid
	end)
	return list
end

function Page.new(parent: Instance)
	local frame = Util.frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = parent })
	local _, subtitle = Util.header(frame, "🗂️ Collection", "")

	local filter, sort = "all", "value"
	local grid
	local filterButtons, sortButtons = {}, {}

	local toolbar = Util.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 36),
		Parent = frame,
	}, { Util.list(Enum.FillDirection.Horizontal, 6) })

	local function paintToggles()
		for id, button in filterButtons do
			Util.setColor(button, if id == filter then Theme.Blue else Theme.PanelLighter)
		end
		for id, button in sortButtons do
			Util.setColor(button, if id == sort then Theme.Purple else Theme.PanelLighter)
		end
	end

	local refresh

	for i, f in FILTERS do
		filterButtons[f.id] = Util.button({
			LayoutOrder = i,
			Text = f.name,
			TextSize = 15,
			Size = UDim2.fromOffset(if f.id == "busy" then 130 else 80, 36),
			Parent = toolbar,
			OnClick = function()
				filter = f.id
				grid.page = 1
				refresh()
			end,
		})
	end
	Util.label({
		LayoutOrder = 10,
		Text = "Sort:",
		Font = Theme.FontBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(52, 36),
		Parent = toolbar,
	})
	for i, s in SORTS do
		sortButtons[s.id] = Util.button({
			LayoutOrder = 10 + i,
			Text = s.name,
			TextSize = 15,
			Size = UDim2.fromOffset(80, 36),
			Parent = toolbar,
			OnClick = function()
				sort = s.id
				refresh()
			end,
		})
	end

	Util.button({
		Text = "💵 Bulk Sell Commons",
		TextSize = 15,
		BackgroundColor3 = Theme.Red,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 66),
		Size = UDim2.fromOffset(190, 36),
		Parent = frame,
		OnClick = function()
			local bulk = State.cards(function(card)
				local rarity = Cards.ById[card.cardId].rarity
				return card.location == "inventory"
					and not card.grade
					and (rarity == "Common" or rarity == "Uncommon")
			end)
			if #bulk == 0 then
				Toasts.show("No raw Commons or Uncommons to sell", "error")
				return
			end
			local total = 0
			local uids = {}
			for _, card in bulk do
				total += Money.round(State.value(card) * Economy.DealerRate)
				table.insert(uids, card.uid)
			end
			Modals.confirm(
				"Bulk Sell",
				`Sell {#bulk} raw Common & Uncommon cards to the dealer for about {Money.format(total)}?`,
				"Sell",
				function()
					local ok, err = State.action("QuickSell", uids)
					if not ok then
						Toasts.show(err, "error")
					end
				end
			)
		end,
	})

	grid = Grid.new(frame, {
		position = UDim2.fromOffset(0, 112),
		size = UDim2.new(1, 0, 1, -112),
		pageSize = 42,
		emptyText = "No cards here. Rip some packs!",
	})

	function refresh()
		local data = State.data
		if not data then
			return
		end
		paintToggles()
		local total, discovered, dexSize = 0, 0, 0
		for _ in data.cards do
			total += 1
		end
		for _ in data.discovered do
			discovered += 1
		end
		for _ in Cards.ById do
			dexSize += 1
		end
		subtitle.Text = `{total}/{Economy.MaxCards} cards · Discovered {discovered}/{dexSize} · Click a card to sell or grade it`

		local list = sortCards(
			State.cards(function(card)
				return matches(card, filter)
			end),
			sort
		)
		grid:setItems(list, function(card)
			return CardTile.new(card, {
				onClick = function()
					Modals.card(card)
				end,
			})
		end)
	end

	return { frame = frame, refresh = refresh }
end

return Page
