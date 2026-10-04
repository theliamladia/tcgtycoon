local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Config.Cards)
local Packs = require(Shared.Config.Packs)
local Money = require(Shared.Money)

local Client = script:FindFirstAncestor("Client")
local State = require(Client.State)
local UI = Client.UI
local PackOpening = require(UI.PackOpening)
local Theme = require(UI.Theme)
local Toasts = require(UI.Toasts)
local Util = require(UI.Util)

local Page = {}

local function oddsText(weights): string
	local total = 0
	for _, w in weights do
		total += w
	end
	local parts = {}
	for _, rarity in { "HoloRare", "UltraRare", "SecretRare" } do
		local w = weights[rarity]
		if w then
			local pct = w / total * 100
			local text = if pct >= 10 then string.format("%d%%", pct) else string.format("%.1f%%", pct)
			table.insert(parts, `{Cards.Rarities[rarity].name} {text}`)
		end
	end
	return table.concat(parts, " · ")
end

function Page.new(parent: Instance)
	local frame = Util.frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = parent })
	Util.header(frame, "📦 Pack Shop", "Rip packs to build your collection. The last card is always Rare or better.")

	local scroll = Util.create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 1, -70),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = frame,
	}, {
		Util.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(228, 300),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local buttons = {}
	local busy = false

	local function buy(pack)
		if busy then
			return
		end
		busy = true
		local ok, result = State.action("BuyPack", pack.id)
		busy = false
		if not ok then
			Toasts.show(result, "error")
			return
		end
		PackOpening.play(pack, result, function()
			buy(pack)
		end)
	end

	for i, pack in Packs.List do
		local set = pack.setId and Cards.SetsById[pack.setId]
		local color = pack.color or (set and set.color) or Theme.PanelLighter
		local tile = Util.frame({
			LayoutOrder = i,
			BackgroundColor3 = Theme.PanelLight,
			Parent = scroll,
		}, { Util.corner(14), Util.stroke(color, 2) })

		local art = Util.frame({
			BackgroundColor3 = color,
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, 130),
			Parent = tile,
		}, {
			Util.corner(10),
			Util.create("UIGradient", {
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 110)),
				Rotation = 60,
			}),
		})
		Util.label({
			Text = pack.name:upper(),
			Font = Theme.FontDisplay,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.6,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -16, 1, -24),
			Parent = art,
		})
		Util.label({
			Text = `{pack.cardsPerPack} CARDS`,
			Font = Theme.FontBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -6),
			Size = UDim2.new(1, 0, 0, 16),
			Parent = art,
		})

		Util.label({
			Text = if set then `Set: {set.name}` else "Any set · Holo Rare or better",
			Font = Theme.FontBold,
			TextSize = 14,
			Position = UDim2.fromOffset(12, 148),
			Size = UDim2.new(1, -24, 0, 18),
			Parent = tile,
		})
		Util.label({
			Text = `Hit odds: {oddsText(pack.hitWeights)}`,
			TextSize = 12,
			TextColor3 = Theme.SubText,
			Position = UDim2.fromOffset(12, 170),
			Size = UDim2.new(1, -24, 0, 50),
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = tile,
		})

		buttons[pack.id] = Util.button({
			Text = "",
			TextSize = 20,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.new(1, -24, 0, 48),
			Parent = tile,
			OnClick = function()
				buy(pack)
			end,
		})
	end

	local function refresh()
		local data = State.data
		if not data then
			return
		end
		for _, pack in Packs.List do
			local button = buttons[pack.id]
			if data.reputation < pack.reputation then
				button.Text = `🔒 Needs {pack.reputation} Rep`
				Util.setColor(button, Theme.PanelLighter)
				Util.setEnabled(button, false)
			else
				button.Text = `Rip for {Money.format(pack.price)}`
				Util.setColor(button, Theme.Green)
				Util.setEnabled(button, data.cash >= pack.price)
			end
		end
	end

	return { frame = frame, refresh = refresh }
end

return Page
