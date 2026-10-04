local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local Toasts = {}

local COLORS = {
	info = Theme.Blue,
	sale = Theme.Green,
	error = Theme.Red,
	gem = Theme.Gold,
	trend = Theme.Orange,
}

local MAX_VISIBLE = 5

local gui = Util.create("ScreenGui", {
	Name = "Toasts",
	DisplayOrder = 100,
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
})

local container = Util.frame({
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.new(0.9, 0, 0, 400),
	Parent = gui,
}, {
	Util.create("UISizeConstraint", { MaxSize = Vector2.new(440, 400) }),
	Util.create("UIListLayout", {
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local order = 0

function Toasts.show(text: string, kind: string?)
	order += 1
	local toast = Util.frame({
		LayoutOrder = order,
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = container,
	}, {
		Util.corner(10),
		Util.stroke(COLORS[kind or "info"] or Theme.Blue, 2),
		Util.padding(10, 14),
	})
	local label = Util.label({
		Text = text,
		Font = Theme.FontBold,
		TextSize = 15,
		TextTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = toast,
	})
	Util.tween(toast, 0.2, { BackgroundTransparency = 0.05 })
	Util.tween(label, 0.2, { TextTransparency = 0 })

	local toasts = {}
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - MAX_VISIBLE do
		toasts[i]:Destroy()
	end

	task.delay(3.5, function()
		if toast.Parent then
			Util.tween(toast, 0.3, { BackgroundTransparency = 1 })
			Util.tween(label, 0.3, { TextTransparency = 1 })
			local stroke = toast:FindFirstChildOfClass("UIStroke")
			if stroke then
				Util.tween(stroke, 0.3, { Transparency = 1 })
			end
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

return Toasts
