-- Popup windows: card details, card picker, markup chooser, confirm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Config.Cards)
local Economy = require(Shared.Config.Economy)
local Grading = require(Shared.Config.Grading)
local Money = require(Shared.Money)
local Valuation = require(Shared.Valuation)

local Client = script:FindFirstAncestor("Client")
local State = require(Client.State)
local CardTile = require(script.Parent.CardTile)
local Grid = require(script.Parent.Grid)
local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local Util = require(script.Parent.Util)

local Modals = {}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local depth = 0

function Modals.open(title: string, size: Vector2)
	depth += 1
	local gui = Util.create("ScreenGui", {
		Name = "Modal",
		DisplayOrder = 20 + depth,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	local function close()
		if gui.Parent then
			gui:Destroy()
			depth -= 1
		end
	end

	Util.create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	}).Activated:Connect(close)

	local panel = Util.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		Parent = gui,
	}, { Util.corner(16), Util.stroke(Theme.Stroke, 2) })
	Util.autoScale(panel, size)

	Util.label({
		Text = title,
		Font = Theme.FontDisplay,
		TextSize = 26,
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -80, 0, 32),
		Parent = panel,
	})
	Util.button({
		Text = "X",
		BackgroundColor3 = Theme.Red,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 12),
		Size = UDim2.fromOffset(36, 36),
		Parent = panel,
		OnClick = close,
	})

	local content = Util.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 1, -76),
		Parent = panel,
	})
	return content, close
end

local function parsePrice(text: string): number?
	local value = tonumber((text:gsub("[%$,%s]", "")))
	if value and Money.isValid(value) and value >= Economy.MinPrice then
		return Money.round(value)
	end
	return nil
end

local function run(close: () -> (), name: string, ...)
	local ok, result = State.action(name, ...)
	if ok then
		close()
	else
		Toasts.show(result or "Something went wrong", "error")
	end
	return ok, result
end

function Modals.card(card)
	local def = Cards.ById[card.cardId]
	local rarity = Cards.Rarities[def.rarity]
	local set = Cards.SetsById[def.setId]
	local content, close = Modals.open(def.name, Vector2.new(640, 470))

	local tile = CardTile.new(card)
	tile.Position = UDim2.fromOffset(0, 0)
	tile.Parent = content
	Util.create("UIScale", { Scale = 1.5, Parent = tile })

	local info = Util.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(215, 0),
		Size = UDim2.new(1, -215, 1, 0),
		Parent = content,
	}, { Util.list(nil, 8) })

	local value = State.value(card)
	local trend = State.trend(card.cardId)
	local trendPct = math.floor((trend - 1) * 100 + 0.5)
	local trendText = if trendPct > 0
		then `<font color="#3fdc8a">▲ {trendPct}%</font>`
		elseif trendPct < 0 then `<font color="#ff6060">▼ {-trendPct}%</font>`
		else "steady"

	Util.label({
		LayoutOrder = 1,
		Text = `{set.name} · <font color="#{rarity.color:ToHex()}">{rarity.name}</font>`,
		RichText = true,
		TextColor3 = Theme.SubText,
		Parent = info,
	})
	Util.label({
		LayoutOrder = 2,
		Text = `Condition: <b>{Valuation.describe(card)}</b>`,
		RichText = true,
		Parent = info,
	})
	Util.label({
		LayoutOrder = 3,
		Text = `Market value: <b>{Money.format(value)}</b>  ({trendText})`,
		RichText = true,
		Parent = info,
	})

	local order = 10
	local function nextOrder()
		order += 1
		return order
	end

	if card.location == "grading" then
		local remaining = (card.gradeDoneAt or 0) - workspace:GetServerTimeNow()
		Util.label({
			LayoutOrder = nextOrder(),
			Text = `At {Grading.CompanyName} for grading. Back in about {Util.formatTime(remaining)}.`,
			TextColor3 = Theme.Gold,
			Size = UDim2.new(1, 0, 0, 40),
			Parent = info,
		})
		return
	elseif card.location == "show" then
		Util.label({
			LayoutOrder = nextOrder(),
			Text = `On your show table for {Money.format(card.price or 0)}.`,
			TextColor3 = Theme.Gold,
			Parent = info,
		})
		return
	elseif card.location == "store" or card.location == "online" then
		Util.label({
			LayoutOrder = nextOrder(),
			Text = `Listed {if card.location == "store" then "in your store" else "online"} for {Money.format(card.price or 0)}`,
			TextColor3 = Theme.Gold,
			Parent = info,
		})
		Util.button({
			LayoutOrder = nextOrder(),
			Text = "Remove Listing",
			BackgroundColor3 = Theme.Red,
			Size = UDim2.fromOffset(200, 42),
			Parent = info,
			OnClick = function()
				run(close, "Unlist", card.uid)
			end,
		})
		return
	end

	-- In inventory: pricing, listing, grading and quick sell.
	local priceRow = Util.frame({
		LayoutOrder = nextOrder(),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = info,
	}, { Util.list(Enum.FillDirection.Horizontal, 6) })
	local priceBox = Util.create("TextBox", {
		Text = string.format("%.2f", value),
		PlaceholderText = "Price",
		ClearTextOnFocus = false,
		Font = Theme.FontBold,
		TextSize = 18,
		TextColor3 = Theme.Text,
		BackgroundColor3 = Theme.Background,
		Size = UDim2.fromOffset(120, 36),
		Parent = priceRow,
	}, { Util.corner(8), Util.stroke() })
	for i, pct in { 0.9, 1, 1.25 } do
		Util.button({
			LayoutOrder = i,
			Text = `{math.floor(pct * 100)}%`,
			TextSize = 15,
			BackgroundColor3 = Theme.PanelLighter,
			Size = UDim2.fromOffset(62, 36),
			Parent = priceRow,
			OnClick = function()
				priceBox.Text = string.format("%.2f", Money.round(value * pct))
			end,
		})
	end

	local feeLabel = Util.label({
		LayoutOrder = nextOrder(),
		TextSize = 13,
		TextColor3 = Theme.SubText,
		Parent = info,
	})
	local function updateFee()
		local price = parsePrice(priceBox.Text)
		feeLabel.Text = if price
			then `Online fee {math.floor(Economy.Online.FeeRate * 100)}% · you'd get {Money.format(
				price * (1 - Economy.Online.FeeRate)
			)}`
			else "Enter a price"
	end
	priceBox:GetPropertyChangedSignal("Text"):Connect(updateFee)
	updateFee()

	local listRow = Util.frame({
		LayoutOrder = nextOrder(),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 42),
		Parent = info,
	}, { Util.list(Enum.FillDirection.Horizontal, 8) })
	local function listWith(action: string)
		return function()
			local price = parsePrice(priceBox.Text)
			if not price then
				Toasts.show("Enter a valid price", "error")
				return
			end
			if run(close, action, card.uid, price) then
				Toasts.show(`Listed {def.name} for {Money.format(price)}`, "info")
			end
		end
	end
	Util.button({
		Text = "🏪 List in Store",
		TextSize = 16,
		BackgroundColor3 = Theme.Blue,
		Size = UDim2.fromOffset(180, 42),
		Parent = listRow,
		OnClick = listWith("ListStore"),
	})
	Util.button({
		LayoutOrder = 1,
		Text = "🌐 List Online",
		TextSize = 16,
		BackgroundColor3 = Theme.Purple,
		Size = UDim2.fromOffset(180, 42),
		Parent = listRow,
		OnClick = listWith("ListOnline"),
	})

	if not card.grade then
		Util.label({
			LayoutOrder = nextOrder(),
			Text = `Send to {Grading.CompanyName} for grading:`,
			Font = Theme.FontBold,
			Parent = info,
		})
		local gradeRow = Util.frame({
			LayoutOrder = nextOrder(),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 48),
			Parent = info,
		}, { Util.list(Enum.FillDirection.Horizontal, 6) })
		for i, tier in Grading.Tiers do
			Util.button({
				LayoutOrder = i,
				Text = `{tier.name}\n{Money.format(tier.fee)} · {Util.formatTime(tier.duration)}`,
				TextSize = 14,
				BackgroundColor3 = Theme.Orange,
				Size = UDim2.fromOffset(120, 48),
				Parent = gradeRow,
				OnClick = function()
					if run(close, "Grade", card.uid, tier.id) then
						Toasts.show(`Sent {def.name} to {Grading.CompanyName}`, "info")
					end
				end,
			})
		end
	end

	local dealerPrice = Money.round(value * Economy.DealerRate)
	Util.button({
		LayoutOrder = nextOrder(),
		Text = `💵 Quick Sell to Dealer ({Money.format(dealerPrice)})`,
		TextSize = 15,
		BackgroundColor3 = Theme.Red,
		Size = UDim2.fromOffset(368, 40),
		Parent = info,
		OnClick = function()
			run(close, "QuickSell", { card.uid })
		end,
	})
end

-- Lets the player pick several cards. `filter` decides which cards show.
function Modals.pickCards(
	options: { title: string, filter: (any) -> boolean, max: number, confirmText: string? },
	onConfirm: ({ any }) -> ()
)
	local content, close = Modals.open(options.title, Vector2.new(1000, 640))
	local selected: { [string]: any } = {}
	local count = 0

	local cards = State.sortByValue(State.cards(function(card)
		return card.location == "inventory" and options.filter(card)
	end))

	local status = Util.label({
		Font = Theme.FontBold,
		Size = UDim2.new(0, 300, 0, 40),
		Parent = content,
	})
	local confirm
	local function updateStatus()
		local total = 0
		for _, card in selected do
			total += State.value(card)
		end
		status.Text = `Selected {count}/{options.max} · worth {Money.format(total)}`
		Util.setEnabled(confirm, count > 0)
	end

	local grid
	local function toggle(card, tile)
		if selected[card.uid] then
			selected[card.uid] = nil
			count -= 1
		elseif count < options.max then
			selected[card.uid] = card
			count += 1
		else
			Toasts.show(`You can only pick {options.max}`, "error")
			return
		end
		CardTile.setSelected(tile, selected[card.uid] ~= nil)
		updateStatus()
	end

	local toolbar = Util.frame({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(560, 40),
		Parent = content,
	}, { Util.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right) })
	Util.button({
		LayoutOrder = 1,
		Text = "Select Best",
		TextSize = 16,
		BackgroundColor3 = Theme.Blue,
		Size = UDim2.fromOffset(140, 40),
		Parent = toolbar,
		OnClick = function()
			table.clear(selected)
			count = 0
			for i = 1, math.min(options.max, #cards) do
				selected[cards[i].uid] = cards[i]
				count += 1
			end
			grid:draw()
			updateStatus()
		end,
	})
	Util.button({
		LayoutOrder = 2,
		Text = "Clear",
		TextSize = 16,
		BackgroundColor3 = Theme.PanelLighter,
		Size = UDim2.fromOffset(100, 40),
		Parent = toolbar,
		OnClick = function()
			table.clear(selected)
			count = 0
			grid:draw()
			updateStatus()
		end,
	})
	confirm = Util.button({
		LayoutOrder = 3,
		Text = options.confirmText or "Confirm",
		TextSize = 16,
		Size = UDim2.fromOffset(160, 40),
		Parent = toolbar,
		OnClick = function()
			local list = {}
			for _, card in selected do
				table.insert(list, card)
			end
			if #list > 0 then
				close()
				onConfirm(State.sortByValue(list))
			end
		end,
	})

	grid = Grid.new(content, {
		position = UDim2.fromOffset(0, 50),
		size = UDim2.new(1, 0, 1, -50),
		pageSize = 42,
		emptyText = "No eligible cards in your inventory.",
	})
	grid:setItems(cards, function(card)
		local tile
		tile = CardTile.new(card, {
			onClick = function()
				toggle(card, tile)
			end,
		})
		CardTile.setSelected(tile, selected[card.uid] ~= nil)
		return tile
	end)
	updateStatus()
end

-- Choose a price multiplier for a batch of cards.
function Modals.chooseMarkup(
	options: { title: string, subtitle: string, cards: { any }, feeRate: number?, getValue: ((any) -> number)? },
	onChoose: (number) -> ()
)
	local content, close = Modals.open(options.title, Vector2.new(560, 340))
	local getValue = options.getValue or State.value
	local base = 0
	for _, card in options.cards do
		base += getValue(card)
	end

	Util.label({
		Text = options.subtitle,
		TextColor3 = Theme.SubText,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = content,
	})
	local holder = Util.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		Parent = content,
	}, {
		Util.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(164, 82),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, markup in { 0.9, 1, 1.1, 1.25, 1.4, 1.6 } do
		local total = base * markup * (1 - (options.feeRate or 0))
		local color = if markup < 1 then Theme.Green elseif markup <= 1.1 then Theme.Blue else Theme.Orange
		Util.button({
			LayoutOrder = i,
			Text = `{math.floor(markup * 100 + 0.5)}% of value\n{Money.format(total)}`,
			TextSize = 17,
			BackgroundColor3 = color,
			Parent = holder,
			OnClick = function()
				close()
				onChoose(markup)
			end,
		})
	end
end

function Modals.confirm(title: string, message: string, confirmText: string, onConfirm: () -> ())
	local content, close = Modals.open(title, Vector2.new(460, 240))
	Util.label({
		Text = message,
		TextColor3 = Theme.SubText,
		Size = UDim2.new(1, 0, 0, 80),
		Parent = content,
	})
	Util.button({
		Text = confirmText,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(160, 44),
		Parent = content,
		OnClick = function()
			close()
			onConfirm()
		end,
	})
	Util.button({
		Text = "Cancel",
		BackgroundColor3 = Theme.PanelLighter,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(120, 44),
		Parent = content,
		OnClick = close,
	})
end

-- Pick cards, pick a markup, then call `action(uid, price)` for each one.
function Modals.listFlow(options: { title: string, action: string, max: number, feeRate: number?, verb: string })
	if options.max <= 0 then
		Toasts.show("No free slots", "error")
		return
	end
	Modals.pickCards({
		title = options.title,
		max = options.max,
		confirmText = "Next: Pricing",
		filter = function()
			return true
		end,
	}, function(cards)
		Modals.chooseMarkup({
			title = "Set your prices",
			subtitle = `Price each card relative to its market value. Higher prices sell slower.`,
			cards = cards,
			feeRate = options.feeRate,
		}, function(markup)
			local listed = 0
			local lastError = nil
			for _, card in cards do
				local price = math.max(Economy.MinPrice, Money.round(State.value(card) * markup))
				local ok, err = State.action(options.action, card.uid, price)
				if ok then
					listed += 1
				else
					lastError = err
				end
				task.wait(0.06)
			end
			if listed > 0 then
				Toasts.show(`{options.verb} {listed} card(s)`, "info")
			end
			if lastError then
				Toasts.show(lastError, "error")
			end
		end)
	end)
end

return Modals
