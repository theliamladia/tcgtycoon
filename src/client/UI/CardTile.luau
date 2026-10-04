-- Renders a single card. Tiles are 130x182; scale them with a UIScale.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Config.Cards)
local Grading = require(Shared.Config.Grading)
local Money = require(Shared.Money)
local Valuation = require(Shared.Valuation)

local Client = script:FindFirstAncestor("Client")
local State = require(Client.State)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local CardTile = {}

CardTile.Size = Vector2.new(130, 182)

local LOCATION_TEXT = {
	grading = "AT PGS",
	store = "IN STORE",
	online = "ONLINE",
	show = "AT SHOW",
}

local HOLO = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 160)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 230, 120)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 200)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(120, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 130, 255)),
})

function CardTile.rarityColor(cardId: string): Color3
	local def = Cards.ById[cardId]
	return if def then Cards.Rarities[def.rarity].color else Theme.SubText
end

function CardTile.new(card, options: { onClick: (() -> ())?, showPrice: boolean? }?)
	local opts = options or {}
	local def = Cards.ById[card.cardId]
	local rarity = Cards.Rarities[def.rarity]
	local set = Cards.SetsById[def.setId]
	local isHolo = rarity.order >= 4

	local tile = Util.create("TextButton", {
		Name = card.uid,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(CardTile.Size.X, CardTile.Size.Y),
		BackgroundColor3 = Theme.PanelLight,
	}, {
		Util.corner(10),
		Util.create("UIStroke", {
			Name = "Border",
			Color = rarity.color,
			Thickness = if card.grade then 3 else 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})

	tile:SetAttribute("CardId", card.cardId)

	Util.label({
		Text = def.name,
		Font = Theme.FontBold,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 16),
		Parent = tile,
	})

	-- Card art: set-coloured panel with the creature's initial.
	local art = Util.frame({
		BackgroundColor3 = set.color,
		Position = UDim2.fromOffset(8, 26),
		Size = UDim2.new(1, -16, 0, 78),
		Parent = tile,
	}, {
		Util.corner(6),
		Util.label({
			Text = def.name:sub(1, 1),
			Font = Theme.FontDisplay,
			TextSize = 48,
			TextTransparency = 0.15,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		}),
	})
	if isHolo then
		Util.create("UIGradient", { Color = HOLO, Rotation = 35, Parent = art })
	else
		Util.create("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(160, 160, 160)),
			Rotation = 90,
			Parent = art,
		})
	end

	Util.label({
		Text = rarity.name,
		Font = Theme.FontBold,
		TextSize = 11,
		TextColor3 = rarity.color,
		Position = UDim2.fromOffset(8, 108),
		Size = UDim2.new(1, -16, 0, 14),
		Parent = tile,
	})

	Util.label({
		Text = if card.grade then `{Grading.CompanyName} {card.grade}` else Valuation.condition(card.condition).label,
		Font = Theme.Font,
		TextSize = 11,
		TextColor3 = Theme.SubText,
		Position = UDim2.fromOffset(8, 123),
		Size = UDim2.new(1, -16, 0, 14),
		Parent = tile,
	})

	local priceText = Money.format(State.value(card))
	if opts.showPrice and card.price then
		priceText = `Asking {Money.format(card.price)}`
	end
	Util.label({
		Name = "Price",
		Text = priceText,
		Font = Theme.FontBold,
		TextSize = 13,
		TextColor3 = Theme.Green,
		Position = UDim2.fromOffset(8, 139),
		Size = UDim2.new(1, -16, 0, 16),
		Parent = tile,
	})

	if card.grade then
		local slab = Util.frame({
			BackgroundColor3 = if card.grade == 10 then Theme.Gold else Theme.Red,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 30),
			Size = UDim2.fromOffset(34, 22),
			Parent = tile,
		}, { Util.corner(6) })
		Util.label({
			Text = tostring(card.grade),
			Font = Theme.FontDisplay,
			TextSize = 16,
			TextColor3 = if card.grade == 10 then Color3.new(0, 0, 0) else Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			Parent = slab,
		})
	end

	local location = LOCATION_TEXT[card.location]
	if location then
		local badge = Util.frame({
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.25,
			Position = UDim2.new(0, 6, 1, -24),
			Size = UDim2.new(1, -12, 0, 18),
			Parent = tile,
		}, { Util.corner(5) })
		Util.label({
			Text = location,
			Font = Theme.FontBold,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			Parent = badge,
		})
	end

	Util.label({
		Name = "Check",
		Visible = false,
		Text = "✓",
		Font = Theme.FontDisplay,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Green,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(28, 28),
		ZIndex = 5,
		Parent = tile,
	}, { Util.corner(14) })

	tile.MouseEnter:Connect(function()
		Util.tween(tile, 0.1, { BackgroundColor3 = Theme.PanelLighter })
	end)
	tile.MouseLeave:Connect(function()
		Util.tween(tile, 0.1, { BackgroundColor3 = Theme.PanelLight })
	end)
	if opts.onClick then
		tile.Activated:Connect(opts.onClick)
	end
	return tile
end

-- A plain card back, used before a card is revealed.
function CardTile.back()
	local back = Util.frame({
		Size = UDim2.fromOffset(CardTile.Size.X, CardTile.Size.Y),
		BackgroundColor3 = Color3.fromRGB(40, 60, 140),
	}, {
		Util.corner(10),
		Util.stroke(Color3.fromRGB(230, 230, 255), 3),
		Util.create("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(90, 120, 255), Color3.fromRGB(30, 30, 90)),
			Rotation = 45,
		}),
		Util.label({
			Text = "TCG",
			Font = Theme.FontDisplay,
			TextSize = 34,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		}),
	})
	return back
end

function CardTile.setSelected(tile: GuiObject, selected: boolean)
	local check = tile:FindFirstChild("Check") :: GuiObject?
	if check then
		check.Visible = selected
	end
	local border = tile:FindFirstChild("Border") :: UIStroke?
	if border then
		border.Thickness = if selected then 4 else 2
		border.Color = if selected then Theme.Green else CardTile.rarityColor(tile:GetAttribute("CardId") or "")
	end
end

return CardTile
