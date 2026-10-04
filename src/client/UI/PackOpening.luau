-- Full-screen pack reveal. Click anywhere to skip the animation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Config.Cards)
local Money = require(Shared.Money)

local Client = script:FindFirstAncestor("Client")
local State = require(Client.State)
local CardTile = require(script.Parent.CardTile)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local PackOpening = {}

local TILE_SCALE = 1.25
local STAGE_SIZE = Vector2.new(1100, 560)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

function PackOpening.play(pack, pulled: { any }, onOpenAnother: () -> ())
	local gui = Util.create("ScreenGui", {
		Name = "PackOpening",
		DisplayOrder = 30,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	local skip = false
	local overlay = Util.create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(8, 8, 14),
		BackgroundTransparency = 0.1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	overlay.Activated:Connect(function()
		skip = true
	end)

	local stage = Util.frame({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(STAGE_SIZE.X, STAGE_SIZE.Y),
		Parent = gui,
	})
	Util.autoScale(stage, STAGE_SIZE)

	Util.label({
		Text = pack.name,
		Font = Theme.FontDisplay,
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 50),
		Parent = stage,
	})
	local hint = Util.label({
		Text = "Click to skip",
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = stage,
	})

	local slotWidth = CardTile.Size.X * TILE_SCALE
	local slotHeight = CardTile.Size.Y * TILE_SCALE
	local row = Util.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 110),
		Size = UDim2.new(1, 0, 0, slotHeight + 60),
		Parent = stage,
	}, {
		Util.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local slots = {}
	for i in pulled do
		local slot = Util.frame({
			LayoutOrder = i,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(slotWidth, slotHeight + 40),
			Parent = row,
		})
		local back = CardTile.back()
		back.AnchorPoint = Vector2.new(0.5, 1)
		back.Position = UDim2.fromScale(0.5, 1)
		back.Parent = slot
		local backScale = Util.create("UIScale", { Scale = TILE_SCALE, Parent = back })
		slots[i] = { slot = slot, back = back, backScale = backScale }
	end

	local function reveal(i: number)
		local entry = slots[i]
		local card = pulled[i]
		local def = Cards.ById[card.cardId]
		local rarity = Cards.Rarities[def.rarity]

		local shrink = Util.tween(entry.backScale, if skip then 0.01 else 0.12, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		shrink.Completed:Wait()
		entry.back:Destroy()

		if rarity.order >= 4 then
			local glow = Util.frame({
				BackgroundColor3 = rarity.color,
				BackgroundTransparency = 0.55,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, 10),
				Size = UDim2.fromOffset(slotWidth + 20, slotHeight + 20),
				Parent = entry.slot,
			}, { Util.corner(18) })
			Util.tween(glow, 0.8, { BackgroundTransparency = 0.8 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			Util.label({
				Text = rarity.name:upper() .. "!",
				Font = Theme.FontDisplay,
				TextSize = 20,
				TextColor3 = rarity.color,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 24),
				Parent = entry.slot,
			})
		end

		local tile = CardTile.new(card)
		tile.AnchorPoint = Vector2.new(0.5, 1)
		tile.Position = UDim2.fromScale(0.5, 1)
		tile.Parent = entry.slot
		local scale = Util.create("UIScale", { Scale = 0, Parent = tile })
		Util.tween(scale, if skip then 0.01 else 0.3, { Scale = TILE_SCALE }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end

	task.spawn(function()
		if not skip then
			task.wait(0.4)
		end
		for i, card in pulled do
			local rarity = Cards.Rarities[Cards.ById[card.cardId].rarity]
			if not skip then
				-- Build suspense before a big hit.
				task.wait(if rarity.order >= 4 then 0.9 else 0.3)
			end
			reveal(i)
		end
		if not gui.Parent then
			return
		end
		hint.Visible = false

		local total, best = 0, pulled[1]
		for _, card in pulled do
			total += State.value(card)
			if State.value(card) > State.value(best) then
				best = card
			end
		end
		Util.label({
			Text = `Pack value: {Money.format(total)}  ·  Best pull: {Cards.ById[best.cardId].name}`,
			Font = Theme.FontBold,
			TextSize = 20,
			TextColor3 = if total >= pack.price then Theme.Green else Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 430),
			Size = UDim2.new(1, 0, 0, 28),
			Parent = stage,
		})

		local buttons = Util.frame({
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(STAGE_SIZE.X / 2, 474),
			Size = UDim2.fromOffset(440, 52),
			Parent = stage,
		}, { Util.list(Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center) })
		Util.button({
			Text = "Collect",
			BackgroundColor3 = Theme.Blue,
			Size = UDim2.fromOffset(200, 52),
			TextSize = 22,
			Parent = buttons,
			OnClick = function()
				gui:Destroy()
			end,
		})
		Util.button({
			LayoutOrder = 1,
			Text = `Open Another ({Money.format(pack.price)})`,
			Size = UDim2.fromOffset(220, 52),
			TextSize = 18,
			Parent = buttons,
			OnClick = function()
				gui:Destroy()
				onOpenAnother()
			end,
		})
	end)
end

return PackOpening
