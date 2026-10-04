local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Util = {}

function Util.create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Util.corner(radius: number?)
	return Util.create("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Util.stroke(color: Color3?, thickness: number?)
	return Util.create("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Util.padding(all: number, horizontal: number?)
	local h = UDim.new(0, horizontal or all)
	local v = UDim.new(0, all)
	return Util.create("UIPadding", { PaddingTop = v, PaddingBottom = v, PaddingLeft = h, PaddingRight = h })
end

function Util.list(direction: Enum.FillDirection?, padding: number?, hAlign: Enum.HorizontalAlignment?)
	return Util.create("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

local function merge(defaults: { [string]: any }, props: { [string]: any }?)
	for key, value in props or {} do
		defaults[key] = value
	end
	return defaults
end

function Util.label(props: { [string]: any }?, children: { Instance }?)
	return Util.create(
		"TextLabel",
		merge({
			BackgroundTransparency = 1,
			Font = Theme.Font,
			TextColor3 = Theme.Text,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 20),
		}, props),
		children
	)
end

function Util.frame(props: { [string]: any }?, children: { Instance }?)
	return Util.create(
		"Frame",
		merge({ BackgroundColor3 = Theme.Panel, BorderSizePixel = 0 }, props),
		children
	)
end

function Util.tween(inst: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

-- Roblox-style chunky button. Pass `OnClick` in props.
function Util.button(props: { [string]: any }, children: { Instance }?)
	local onClick = props.OnClick
	props.OnClick = nil
	local color = props.BackgroundColor3 or Theme.Green

	local button = Util.create(
		"TextButton",
		merge({
			BackgroundColor3 = color,
			AutoButtonColor = false,
			Font = Theme.FontDisplay,
			TextColor3 = Theme.Text,
			TextSize = 18,
			Size = UDim2.new(0, 140, 0, 40),
		}, props),
		children
	)
	Util.corner(10).Parent = button
	local scale = Util.create("UIScale", { Parent = button })
	button:SetAttribute("BaseColor", color)

	local function base(): Color3
		return button:GetAttribute("BaseColor")
	end
	button.MouseEnter:Connect(function()
		if button.Active then
			Util.tween(button, 0.12, { BackgroundColor3 = base():Lerp(Color3.new(1, 1, 1), 0.15) })
		end
	end)
	button.MouseLeave:Connect(function()
		Util.tween(button, 0.12, { BackgroundColor3 = base() })
		Util.tween(scale, 0.1, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		if button.Active then
			Util.tween(scale, 0.08, { Scale = 0.95 })
		end
	end)
	button.MouseButton1Up:Connect(function()
		Util.tween(scale, 0.1, { Scale = 1 })
	end)
	button.Activated:Connect(function()
		if button.Active and onClick then
			onClick()
		end
	end)
	return button
end

function Util.setColor(button: TextButton, color: Color3)
	button:SetAttribute("BaseColor", color)
	button.BackgroundColor3 = color
end

function Util.setEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = false
	button.BackgroundTransparency = if enabled then 0 else 0.55
	button.TextTransparency = if enabled then 0 else 0.4
end

-- Removes everything except layout helpers (UIListLayout, UIPadding...).
function Util.clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Keeps a fixed-size design scaled to fit the current screen.
function Util.autoScale(target: GuiObject, designSize: Vector2?)
	local size = designSize or Theme.DesignSize
	local scale = Util.create("UIScale", { Parent = target })
	local camera = workspace.CurrentCamera
	local function update()
		local viewport = camera.ViewportSize
		scale.Scale = math.clamp(math.min(viewport.X / (size.X + 40), viewport.Y / (size.Y + 40)), 0.45, 1.25)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
	return scale
end

-- Page title + subtitle. Returns the subtitle label so pages can update it.
function Util.header(parent: Instance, title: string, subtitle: string)
	local titleLabel = Util.label({
		Name = "Title",
		Text = title,
		Font = Theme.FontDisplay,
		TextSize = 30,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = parent,
	})
	local subtitleLabel = Util.label({
		Name = "Subtitle",
		Text = subtitle,
		TextColor3 = Theme.SubText,
		TextSize = 15,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = parent,
	})
	return titleLabel, subtitleLabel
end

-- A rounded stat box: big value with a caption. Returns the value label.
function Util.statBox(parent: Instance, caption: string, props: { [string]: any }?)
	local box = Util.frame(merge({ BackgroundColor3 = Theme.PanelLight, Size = UDim2.fromOffset(180, 64) }, props), {
		Util.corner(10),
		Util.padding(8, 12),
	})
	box.Parent = parent
	Util.label({
		Text = caption,
		TextSize = 13,
		TextColor3 = Theme.SubText,
		Size = UDim2.new(1, 0, 0, 16),
		Parent = box,
	})
	return Util.label({
		Font = Theme.FontDisplay,
		TextSize = 22,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 26),
		Parent = box,
	})
end

function Util.formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 60 then
		return string.format("%d:%02d", seconds // 60, seconds % 60)
	end
	return `{seconds}s`
end

return Util
