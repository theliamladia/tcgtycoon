-- A paged, scrolling grid of card tiles.

local CardTile = require(script.Parent.CardTile)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local Grid = {}
Grid.__index = Grid

function Grid.new(parent: Instance, props: { position: UDim2, size: UDim2, pageSize: number?, emptyText: string? })
	local self = setmetatable({}, Grid)
	self.page = 1
	self.pageSize = props.pageSize or 48
	self.items = {}

	self.frame = Util.frame({
		BackgroundTransparency = 1,
		Position = props.position,
		Size = props.size,
		Parent = parent,
	})

	self.scroll = Util.create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -44),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Stroke,
		Parent = self.frame,
	}, {
		Util.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CardTile.Size.X, CardTile.Size.Y),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Util.padding(4),
	})

	self.empty = Util.label({
		Text = props.emptyText or "Nothing here yet.",
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromScale(0, 0.4),
		Size = UDim2.new(1, 0, 0, 40),
		Visible = false,
		Parent = self.frame,
	})

	self.footer = Util.frame({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(360, 36),
		Parent = self.frame,
	})
	Util.button({
		Text = "◀ Prev",
		TextSize = 16,
		BackgroundColor3 = Theme.PanelLighter,
		Size = UDim2.fromOffset(100, 36),
		Parent = self.footer,
		OnClick = function()
			self.page -= 1
			self:draw()
		end,
	})
	self.pageLabel = Util.label({
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.FontBold,
		Position = UDim2.fromOffset(100, 0),
		Size = UDim2.new(1, -200, 1, 0),
		Parent = self.footer,
	})
	Util.button({
		Text = "Next ▶",
		TextSize = 16,
		BackgroundColor3 = Theme.PanelLighter,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(100, 36),
		Parent = self.footer,
		OnClick = function()
			self.page += 1
			self:draw()
		end,
	})
	return self
end

function Grid:setItems(items: { any }, render: (any) -> GuiObject)
	self.items = items
	self.render = render
	self:draw()
end

function Grid:draw()
	Util.clear(self.scroll)
	local count = #self.items
	local pages = math.max(1, math.ceil(count / self.pageSize))
	self.page = math.clamp(self.page, 1, pages)
	local first = (self.page - 1) * self.pageSize + 1
	for i = first, math.min(count, first + self.pageSize - 1) do
		local tile = self.render(self.items[i])
		tile.LayoutOrder = i
		tile.Parent = self.scroll
	end
	self.footer.Visible = pages > 1
	self.pageLabel.Text = `Page {self.page} / {pages}`
	self.empty.Visible = count == 0
end

return Grid
