local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)

local Client = script:FindFirstAncestor("Client")
local State = require(Client.State)
local UI = Client.UI
local CardTile = require(UI.CardTile)
local Grid = require(UI.Grid)
local Modals = require(UI.Modals)
local Theme = require(UI.Theme)
local Util = require(UI.Util)

local Page = {}

local config = Economy.Online

function Page.new(parent: Instance)
	local frame = Util.frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = parent })
	local _, subtitle = Util.header(frame, "🌐 Online Marketplace", "")
	subtitle.Text = string.format(
		"%d%% seller fee. Buyers shop around and won't pay over %d%% of value. Graded slabs sell %d%% faster.",
		config.FeeRate * 100,
		config.Tolerance * 100,
		(config.GradedBonus - 1) * 100
	)

	local count = Util.label({
		Font = Theme.FontBold,
		TextSize = 18,
		Position = UDim2.fromOffset(216, 74),
		Size = UDim2.fromOffset(300, 24),
		Parent = frame,
	})
	Util.button({
		Text = "➕ Create Listings",
		TextSize = 17,
		BackgroundColor3 = Theme.Purple,
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.fromOffset(200, 40),
		Parent = frame,
		OnClick = function()
			Modals.listFlow({
				title = "List cards online",
				action = "ListOnline",
				max = config.MaxListings - #State.cardsAt("online"),
				feeRate = config.FeeRate,
				verb = "Listed",
			})
		end,
	})

	local grid = Grid.new(frame, {
		position = UDim2.fromOffset(0, 118),
		size = UDim2.new(1, 0, 1, -118),
		emptyText = "No active listings.",
	})

	local function refresh()
		if not State.data then
			return
		end
		local listed = State.sortByValue(State.cardsAt("online"))
		count.Text = `{#listed} / {config.MaxListings} listings`
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
