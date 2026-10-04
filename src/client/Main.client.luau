local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Money = require(Shared:WaitForChild("Money"))

local Client = script.Parent
local State = require(Client:WaitForChild("State"))
local UI = Client:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Toasts = require(UI:WaitForChild("Toasts"))
local Util = require(UI:WaitForChild("Util"))
local Pages = UI:WaitForChild("Pages")

pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)

local gui = Util.create("ScreenGui", {
	Name = "TCGTycoon",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
})

Util.frame({
	BackgroundColor3 = Theme.Background,
	Size = UDim2.fromScale(1, 1),
	Parent = gui,
}, {
	Util.create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(36, 40, 60), Color3.fromRGB(16, 17, 22)),
		Rotation = 90,
	}),
})

local main = Util.frame({
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(Theme.DesignSize.X, Theme.DesignSize.Y),
	Parent = gui,
})
Util.autoScale(main)

-- Top bar
local topBar = Util.frame({
	Size = UDim2.new(1, 0, 0, 60),
	Parent = main,
}, { Util.corner(14), Util.stroke(Theme.Stroke) })
Util.label({
	Text = "🃏 TCG TYCOON",
	Font = Theme.FontDisplay,
	TextSize = 32,
	Position = UDim2.fromOffset(18, 0),
	Size = UDim2.new(0, 400, 1, 0),
	Parent = topBar,
})
local pills = Util.frame({
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(600, 40),
	Parent = topBar,
}, { Util.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Right) })

local function pill(order: number, color: Color3, width: number)
	local frame = Util.frame({
		LayoutOrder = order,
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(width, 40),
		Parent = pills,
	}, { Util.corner(20) })
	return Util.label({
		Font = Theme.FontDisplay,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	})
end
local repLabel = pill(1, Color3.fromRGB(176, 120, 20), 150)
local cashLabel = pill(2, Theme.Green, 200)

-- Navigation + content
local nav = Util.frame({
	Position = UDim2.fromOffset(0, 70),
	Size = UDim2.new(0, 170, 1, -70),
	Parent = main,
}, { Util.corner(14), Util.stroke(Theme.Stroke), Util.padding(10), Util.list(nil, 8) })

local content = Util.frame({
	Position = UDim2.fromOffset(180, 70),
	Size = UDim2.new(1, -180, 1, -70),
	Parent = main,
}, { Util.corner(14), Util.stroke(Theme.Stroke), Util.padding(16) })

local loading = Util.label({
	Text = "Loading your collection...",
	Font = Theme.FontDisplay,
	TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 10,
	Parent = content,
})

local PAGES = {
	{ id = "Packs", label = "📦 Packs" },
	{ id = "Collection", label = "🗂️ Collection" },
	{ id = "Grading", label = "🔍 Grading" },
	{ id = "Store", label = "🏪 Store" },
	{ id = "Online", label = "🌐 Online" },
	{ id = "Shows", label = "🎪 Shows" },
}

local pages = {}
local navButtons = {}
local current = nil

local function selectPage(id: string)
	current = id
	for pageId, page in pages do
		page.frame.Visible = pageId == id
		Util.setColor(navButtons[pageId], if pageId == id then Theme.Blue else Theme.PanelLight)
	end
	pages[id].refresh("open")
end

for i, info in PAGES do
	local page = require(Pages:WaitForChild(info.id)).new(content)
	page.frame.Visible = false
	pages[info.id] = page
	navButtons[info.id] = Util.button({
		LayoutOrder = i,
		Text = info.label,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = Theme.PanelLight,
		Size = UDim2.new(1, 0, 0, 52),
		Parent = nav,
	}, { Util.padding(0, 14) })
	navButtons[info.id].Activated:Connect(function()
		selectPage(info.id)
	end)
end

local function updateTopBar()
	local data = State.data
	if not data then
		return
	end
	cashLabel.Text = Money.format(data.cash)
	repLabel.Text = `⭐ {data.reputation}`
end

-- Coalesce bursts of updates into one redraw per frame.
local pendingRefresh = false
State.changed:Connect(function()
	if pendingRefresh then
		return
	end
	pendingRefresh = true
	task.defer(function()
		pendingRefresh = false
		if State.data then
			loading.Visible = false
		end
		updateTopBar()
		if current then
			pages[current].refresh("data")
		end
	end)
end)

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify").OnClientEvent:Connect(function(text, kind)
	Toasts.show(text, kind)
end)

local tickElapsed = 0
RunService.Heartbeat:Connect(function(dt)
	tickElapsed += dt
	if tickElapsed < 0.25 then
		return
	end
	tickElapsed = 0
	local page = current and pages[current]
	if page and page.tick then
		page.tick()
	end
end)

selectPage("Packs")
if State.data then
	loading.Visible = false
	updateTopBar()
end
