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
	Util.header(
		frame,
		"🎪 Card Shows",
		"Book a table, bring your best cards and sell to the crowd. Big shows pay extra for graded slabs."
	)

	-- Show list (when not at a show)
	local listing = Util.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 1, -70),
		Parent = frame,
	}, { Util.list(Enum.FillDirection.Horizontal, 12) })

	local function book(show)
		Modals.pickCards({
			title = `Pack your box for {show.name}`,
			max = show.maxCards,
			confirmText = "Next: Pricing",
			filter = function()
				return true
			end,
		}, function(cards)
			Modals.chooseMarkup({
				title = "Set your show prices",
				subtitle = `Totals include the {math.floor((show.gradedBonus - 1) * 100 + 0.5)}% premium buyers here pay for graded cards. Table fee: {Money.format(
					show.fee
				)}.`,
				cards = cards,
				getValue = function(card)
					return State.value(card) * (if card.grade then show.gradedBonus else 1)
				end,
			}, function(markup)
				local uids = {}
				for _, card in cards do
					table.insert(uids, card.uid)
				end
				local ok, err = State.action("StartShow", show.id, uids, markup)
				if ok then
					Toasts.show(`🎪 Doors are open at {show.name}!`, "gem")
				else
					Toasts.show(err, "error")
				end
			end)
		end)
	end

	local bookButtons = {}
	for i, show in Economy.Shows.List do
		local box = Util.frame({
			LayoutOrder = i,
			BackgroundColor3 = Theme.PanelLight,
			Size = UDim2.fromOffset(314, 330),
			Parent = listing,
		}, { Util.corner(14), Util.padding(14), Util.list(nil, 6) })
		Util.label({
			LayoutOrder = 1,
			Text = show.name,
			Font = Theme.FontDisplay,
			TextSize = 24,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = box,
		})
		local lines = {
			`🎟️ Table fee: <b>{Money.format(show.fee)}</b>`,
			`⏱️ Duration: <b>{Util.formatTime(show.duration)}</b>`,
			`🗃️ Bring up to <b>{show.maxCards}</b> cards`,
			`👥 Crowd: <b>{math.floor(show.buyerChance * 100)}%</b> busy`,
			`💸 Buyers pay up to <b>{math.floor(show.tolerance * 100 + 0.5)}%</b> of value`,
			`💎 Graded slabs <b>+{math.floor((show.gradedBonus - 1) * 100 + 0.5)}%</b>`,
			`⭐ Requires <b>{show.reputation}</b> reputation`,
		}
		for j, line in lines do
			Util.label({
				LayoutOrder = 1 + j,
				Text = line,
				RichText = true,
				TextSize = 15,
				Size = UDim2.new(1, 0, 0, 22),
				Parent = box,
			})
		end
		bookButtons[show.id] = Util.button({
			LayoutOrder = 20,
			Text = "Book a Table",
			Size = UDim2.new(1, 0, 0, 46),
			Parent = box,
			OnClick = function()
				book(show)
			end,
		})
	end

	-- Active show
	local active = Util.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 1, -70),
		Visible = false,
		Parent = frame,
	})
	local activeTitle = Util.label({
		Font = Theme.FontDisplay,
		TextSize = 24,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = active,
	})
	local statsRow = Util.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 64),
		Parent = active,
	}, { Util.list(Enum.FillDirection.Horizontal, 10) })
	local timeLeft = Util.statBox(statsRow, "Time left", { LayoutOrder = 1 })
	local soldCount = Util.statBox(statsRow, "Cards sold", { LayoutOrder = 2 })
	local earnedLabel = Util.statBox(statsRow, "Earned", { LayoutOrder = 3 })
	local onTable = Util.statBox(statsRow, "Still on the table", { LayoutOrder = 4 })
	local grid = Grid.new(active, {
		position = UDim2.fromOffset(0, 112),
		size = UDim2.new(1, 0, 1, -112),
		emptyText = "Sold out! 🎉 Unsold cards come home when the show ends.",
	})

	local function refresh()
		local data = State.data
		if not data then
			return
		end
		local show = data.show
		listing.Visible = show == nil
		active.Visible = show ~= nil
		if show then
			local def = Economy.ShowsById[show.id]
			activeTitle.Text = `At {def.name} · priced at {math.floor(show.markup * 100 + 0.5)}% of value`
			soldCount.Text = tostring(show.sold)
			earnedLabel.Text = Money.format(show.earned)
			local remaining = State.sortByValue(State.cardsAt("show"))
			onTable.Text = tostring(#remaining)
			grid:setItems(remaining, function(card)
				return CardTile.new(card, { showPrice = true })
			end)
		else
			for _, def in Economy.Shows.List do
				local button = bookButtons[def.id]
				if data.reputation < def.reputation then
					button.Text = `🔒 Needs {def.reputation} Rep`
					Util.setColor(button, Theme.PanelLighter)
					Util.setEnabled(button, false)
				else
					button.Text = "Book a Table"
					Util.setColor(button, Theme.Green)
					Util.setEnabled(button, data.cash >= def.fee)
				end
			end
		end
	end

	local function tick()
		local show = State.data and State.data.show
		if show then
			timeLeft.Text = Util.formatTime(show.endsAt - workspace:GetServerTimeNow())
		end
	end

	return { frame = frame, refresh = refresh, tick = tick }
end

return Page
