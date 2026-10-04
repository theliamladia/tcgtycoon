local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Config.Cards)
local Grading = require(Shared.Config.Grading)
local Money = require(Shared.Money)

local Client = script:FindFirstAncestor("Client")
local State = require(Client.State)
local UI = Client.UI
local Modals = require(UI.Modals)
local Theme = require(UI.Theme)
local Toasts = require(UI.Toasts)
local Util = require(UI.Util)

local Page = {}

function Page.new(parent: Instance)
	local frame = Util.frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = parent })
	Util.header(
		frame,
		`🔍 {Grading.CompanyName} Grading`,
		"Send raw cards in for a grade. A Gem Mint 10 is worth 6x, but a low grade can lose value."
	)

	-- Tier cards
	local tiers = Util.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 110),
		Parent = frame,
	}, { Util.list(Enum.FillDirection.Horizontal, 12) })

	local function sendCards(tier)
		local data = State.data
		if not data then
			return
		end
		local free = Grading.MaxInQueue - #State.cardsAt("grading")
		if free <= 0 then
			Toasts.show("Your grading queue is full", "error")
			return
		end
		Modals.pickCards({
			title = `Send to {tier.name} grading ({Money.format(tier.fee)} each)`,
			max = free,
			confirmText = "Send to PGS",
			filter = function(card)
				return not card.grade
			end,
		}, function(cards)
			local sent = 0
			local lastError = nil
			for _, card in cards do
				local ok, err = State.action("Grade", card.uid, tier.id)
				if ok then
					sent += 1
				else
					lastError = err
				end
				task.wait(0.06)
			end
			if sent > 0 then
				Toasts.show(`Sent {sent} card(s) to {Grading.CompanyName}`, "info")
			end
			if lastError then
				Toasts.show(lastError, "error")
			end
		end)
	end

	for i, tier in Grading.Tiers do
		local box = Util.frame({
			LayoutOrder = i,
			BackgroundColor3 = Theme.PanelLight,
			Size = UDim2.fromOffset(314, 110),
			Parent = tiers,
		}, { Util.corner(12), Util.padding(12) })
		Util.label({
			Text = `{tier.name} Service`,
			Font = Theme.FontDisplay,
			TextSize = 22,
			Size = UDim2.new(1, 0, 0, 26),
			Parent = box,
		})
		Util.label({
			Text = `{Money.format(tier.fee)} per card · {Util.formatTime(tier.duration)} turnaround`,
			TextColor3 = Theme.SubText,
			TextSize = 14,
			Position = UDim2.fromOffset(0, 28),
			Parent = box,
		})
		Util.button({
			Text = "Send Cards",
			TextSize = 16,
			BackgroundColor3 = Theme.Orange,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 38),
			Parent = box,
			OnClick = function()
				sendCards(tier)
			end,
		})
	end

	-- Queue
	local queueTitle = Util.label({
		Text = "Grading Queue",
		Font = Theme.FontDisplay,
		TextSize = 22,
		Position = UDim2.fromOffset(0, 190),
		Size = UDim2.new(0, 620, 0, 26),
		Parent = frame,
	})
	local queue = Util.create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 222),
		Size = UDim2.new(0, 620, 1, -222),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = frame,
	}, { Util.list(nil, 8) })
	local emptyLabel = Util.label({
		Text = "Nothing at PGS right now.",
		TextColor3 = Theme.SubText,
		Position = UDim2.fromOffset(0, 226),
		Size = UDim2.new(0, 620, 0, 24),
		Parent = frame,
	})

	-- Grade scale
	local scale = Util.frame({
		BackgroundColor3 = Theme.PanelLight,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 190),
		Size = UDim2.new(0, 330, 1, -190),
		Parent = frame,
	}, { Util.corner(12), Util.padding(12), Util.list(nil, 4) })
	Util.label({
		LayoutOrder = 0,
		Text = "Grade → Value",
		Font = Theme.FontDisplay,
		TextSize = 20,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = scale,
	})
	for grade = 10, 1, -1 do
		local info = Grading.Grades[grade]
		Util.label({
			LayoutOrder = 11 - grade,
			Text = `<b>{grade}</b>  {info.label}  <font color="#9aa3b5">×{info.multiplier}</font>`,
			RichText = true,
			TextSize = 15,
			TextColor3 = if grade == 10 then Theme.Gold else Theme.Text,
			Size = UDim2.new(1, 0, 0, 20),
			Parent = scale,
		})
	end
	Util.label({
		LayoutOrder = 20,
		Text = "Raw: Mint ×1.2 · NM ×1 · EX ×0.8 · Played ×0.55 · Damaged ×0.3",
		TextSize = 12,
		TextColor3 = Theme.SubText,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = scale,
	})

	local rows = {}

	local function refresh()
		if not State.data then
			return
		end
		Util.clear(queue)
		table.clear(rows)
		local list = State.cardsAt("grading")
		table.sort(list, function(a, b)
			return (a.gradeDoneAt or 0) < (b.gradeDoneAt or 0)
		end)
		queueTitle.Text = `Grading Queue ({#list}/{Grading.MaxInQueue})`
		emptyLabel.Visible = #list == 0
		for i, card in list do
			local def = Cards.ById[card.cardId]
			local tier = Grading.TiersById[card.gradeTier] or Grading.Tiers[1]
			local row = Util.frame({
				LayoutOrder = i,
				BackgroundColor3 = Theme.PanelLight,
				Size = UDim2.new(1, -10, 0, 56),
				Parent = queue,
			}, { Util.corner(10) })
			Util.label({
				Text = `{def.name} <font color="#9aa3b5">· {tier.name}</font>`,
				RichText = true,
				Font = Theme.FontBold,
				Position = UDim2.fromOffset(12, 8),
				Size = UDim2.new(1, -110, 0, 18),
				Parent = row,
			})
			local timeLabel = Util.label({
				Font = Theme.FontBold,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 8),
				Size = UDim2.fromOffset(90, 18),
				Parent = row,
			})
			local bar = Util.frame({
				BackgroundColor3 = Theme.Background,
				Position = UDim2.fromOffset(12, 34),
				Size = UDim2.new(1, -24, 0, 10),
				Parent = row,
			}, { Util.corner(5) })
			local fill = Util.frame({
				BackgroundColor3 = Theme.Orange,
				Size = UDim2.fromScale(0, 1),
				Parent = bar,
			}, { Util.corner(5) })
			table.insert(rows, { card = card, duration = tier.duration, fill = fill, time = timeLabel })
		end
	end

	local function tick()
		local now = workspace:GetServerTimeNow()
		for _, row in rows do
			local remaining = (row.card.gradeDoneAt or now) - now
			row.fill.Size = UDim2.fromScale(math.clamp(1 - remaining / row.duration, 0, 1), 1)
			row.time.Text = if remaining > 0 then Util.formatTime(remaining) else "Grading..."
		end
	end

	return { frame = frame, refresh = refresh, tick = tick }
end

return Page
