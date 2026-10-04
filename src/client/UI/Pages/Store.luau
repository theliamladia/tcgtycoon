local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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

function Page.new(parent: Instance)
	local frame = Util.frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = parent })
	local title = Util.header(
		frame,
		"🏪 Your Store",
		`Stock your shelves and walk-in customers buy cards priced under {math.floor(Economy.Store.Tolerance * 100)}% of value. No fees.`
	)

	local stats = Util.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 64),
		Parent = frame,
	}, { Util.list(Enum.FillDirection.Horizontal, 10) })
	local shelves = Util.statBox(stats, "Shelf space", { LayoutOrder = 1, Size = UDim2.fromOffset(150, 64) })
	local traffic = Util.statBox(stats, "Foot traffic", { LayoutOrder = 2, Size = UDim2.fromOffset(150, 64) })
	local sold = Util.statBox(stats, "Cards sold (all)", { LayoutOrder = 3, Size = UDim2.fromOffset(150, 64) })
	local earned = Util.statBox(stats, "Total earned", { LayoutOrder = 4, Size = UDim2.fromOffset(170, 64) })

	local upgrade = Util.button({
		Text = "Upgrade",
		TextSize = 15,
		BackgroundColor3 = Theme.Gold,
		TextColor3 = Color3.new(0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 66),
		Size = UDim2.fromOffset(300, 64),
		Parent = frame,
		OnClick = function()
			local ok, err = State.action("UpgradeStore")
			if not ok then
				Toasts.show(err, "error")
			end
		end,
	})

	Util.button({
		Text = "📥 Stock Shelves",
		TextSize = 17,
		BackgroundColor3 = Theme.Blue,
		Position = UDim2.fromOffset(0, 142),
		Size = UDim2.fromOffset(200, 40),
		Parent = frame,
		OnClick = function()
			local data = State.data
			if not data then
				return
			end
			local level = Economy.Store.Levels[data.storeLevel]
			Modals.listFlow({
				title = "Stock your shelves",
				action = "ListStore",
				max = level.slots - #State.cardsAt("store"),
				verb = "Stocked",
			})
		end,
	})
	Util.label({
		Text = "Click a listed card to change or remove it.",
		TextColor3 = Theme.SubText,
		TextSize = 14,
		Position = UDim2.fromOffset(214, 152),
		Size = UDim2.fromOffset(400, 20),
		Parent = frame,
	})

	local grid = Grid.new(frame, {
		position = UDim2.fromOffset(0, 192),
		size = UDim2.new(1, 0, 1, -192),
		emptyText = "Your shelves are empty. Stock them to start selling!",
	})

	local function refresh()
		local data = State.data
		if not data then
			return
		end
		local level = Economy.Store.Levels[data.storeLevel]
		local listed = State.sortByValue(State.cardsAt("store"))
		title.Text = `🏪 {level.name}  (Lv {data.storeLevel})`
		shelves.Text = `{#listed} / {level.slots}`
		traffic.Text = `{math.floor(level.traffic * 100)}%`
		sold.Text = tostring(data.stats.cardsSold)
		earned.Text = Money.format(data.stats.totalEarned)

		local nextLevel = Economy.Store.Levels[data.storeLevel + 1]
		if nextLevel then
			upgrade.Text = `⬆ {nextLevel.name}\n{nextLevel.slots} slots · {Money.format(nextLevel.cost)}`
			Util.setEnabled(upgrade, data.cash >= nextLevel.cost)
		else
			upgrade.Text = "Fully upgraded!"
			Util.setEnabled(upgrade, false)
		end

		grid:setItems(listed, function(card)
			return CardTile.new(card, {
				showPrice = true,
				onClick = function()
					Modals.card(card)
				end,
			})
		end)
	end

	return { frame = frame, refresh = refresh }
end

return Page
