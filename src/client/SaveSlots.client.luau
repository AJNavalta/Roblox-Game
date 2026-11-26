--[[
	SaveSlots.client.luau
	The "choose a save" screen. It pops up when you join: pick one of your
	3 save files (or start a new game in an empty one). The little 💾 button
	under the cash bar opens it again so you can switch saves any time.

	The server side is the "Save slots" part of src/server/Main.server.luau.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))

local saveRequest = ReplicatedStorage:WaitForChild("SaveRequest") :: RemoteFunction
local player = Players.LocalPlayer

local SLOT_COUNT = 3
local SLOT_COLORS = {
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(240, 100, 160),
}

local function make(className: string, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function corner(radius: number)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function text(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextSize = props.TextSize or 16
	return make("TextLabel", props)
end

local gui = make("ScreenGui", {
	Name = "SaveSlots",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 5, -- above everything else
	Parent = player:WaitForChild("PlayerGui"),
})

-- The 💾 button under the cash bar
local reopen = make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 50),
	Size = UDim2.fromOffset(120, 24),
	BackgroundColor3 = Color3.fromRGB(20, 22, 30),
	BackgroundTransparency = 0.2,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "💾 Saves",
	Visible = false,
	Parent = gui,
}, { corner(12) })

-- The big screen
local overlay = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(10, 12, 20),
	BackgroundTransparency = 0.25,
	Visible = true,
	Parent = gui,
})

local window = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(640, 360),
	BackgroundColor3 = Color3.fromRGB(28, 30, 42),
	Parent = overlay,
}, {
	corner(18),
	make("UIStroke", { Color = Color3.fromRGB(255, 200, 40), Thickness = 3 }),
	make("UISizeConstraint", { MaxSize = Vector2.new(640, 360) }),
})
-- Shrink to fit small screens (phones)
local scale = make("UIScale", { Parent = window })
local function fit()
	local viewport = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.min(1, (viewport.X - 24) / 640, (viewport.Y - 24) / 360)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
fit()

text({
	Position = UDim2.fromOffset(0, 18),
	Size = UDim2.new(1, 0, 0, 36),
	Font = Enum.Font.FredokaOne,
	TextSize = 32,
	TextColor3 = Color3.fromRGB(255, 220, 90),
	Text = "💰 Choose your save",
	Parent = window,
})
local subtitle = text({
	Position = UDim2.fromOffset(0, 56),
	Size = UDim2.new(1, 0, 0, 20),
	Font = Enum.Font.GothamMedium,
	TextSize = 14,
	TextColor3 = Color3.fromRGB(180, 185, 205),
	Text = "Loading your saves...",
	Parent = window,
})

local row = make("Frame", {
	Position = UDim2.fromOffset(20, 92),
	Size = UDim2.new(1, -40, 0, 210),
	BackgroundTransparency = 1,
	Parent = window,
}, {
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 14),
	}),
})

local closeButton = make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(140, 32),
	BackgroundColor3 = Color3.fromRGB(70, 74, 92),
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Keep playing",
	Visible = false,
	Parent = window,
}, { corner(10) })

local currentSlot: number? = nil
local busy = false
local cards = {}

local function setOpen(open: boolean)
	overlay.Visible = open
	reopen.Visible = not open and currentSlot ~= nil
end

local refresh

local function choose(slot: number)
	if busy then
		return
	end
	busy = true
	subtitle.Text = if currentSlot then "Saving your game and loading save " .. slot .. "..." else "Loading save " .. slot .. "..."
	local ok, result = pcall(function()
		return saveRequest:InvokeServer("choose", slot)
	end)
	busy = false
	if ok and type(result) == "table" and result.Ok then
		currentSlot = result.Current
		reopen.Text = "💾 Save " .. tostring(currentSlot)
		setOpen(false)
	else
		subtitle.Text = if ok and type(result) == "table" and result.Message then result.Message else "Couldn't load that save, try again."
	end
end

for slot = 1, SLOT_COUNT do
	local card = make("TextButton", {
		Size = UDim2.fromOffset(186, 210),
		BackgroundColor3 = Color3.fromRGB(40, 43, 58),
		AutoButtonColor = true,
		Text = "",
		LayoutOrder = slot,
		Parent = row,
	}, { corner(14) })
	local stroke = make("UIStroke", { Color = SLOT_COLORS[slot], Thickness = 2, Parent = card })
	make("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = SLOT_COLORS[slot],
		Parent = card,
	}, { corner(14) })
	text({
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 20,
		TextColor3 = Color3.fromRGB(25, 25, 30),
		Text = "💾 Save " .. slot,
		Parent = card,
	})
	local cash = text({
		Position = UDim2.fromOffset(10, 56),
		Size = UDim2.new(1, -20, 0, 30),
		TextSize = 24,
		TextColor3 = Color3.fromRGB(120, 255, 140),
		Text = "",
		Parent = card,
	})
	local details = text({
		Position = UDim2.fromOffset(10, 90),
		Size = UDim2.new(1, -20, 0, 70),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(200, 205, 220),
		Text = "",
		Parent = card,
	})
	local action = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, 30),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(60, 180, 90),
		TextSize = 15,
		Text = "",
		Parent = card,
	})
	corner(8).Parent = action
	card.Activated:Connect(function()
		choose(slot)
	end)
	cards[slot] = { Cash = cash, Details = details, Action = action, Stroke = stroke }
end

refresh = function()
	local ok, result = pcall(function()
		return saveRequest:InvokeServer("list")
	end)
	if not ok or type(result) ~= "table" then
		subtitle.Text = "Couldn't reach the server. Pick a save to try again."
		return
	end
	currentSlot = result.Current
	subtitle.Text = if result.Saving
		then "Each save is a whole separate game. Pick one to play!"
		else "Saving is off in this test, so saves start fresh each time."
	for slot = 1, SLOT_COUNT do
		local card = cards[slot]
		local summary = result.Slots and result.Slots[slot]
		card.Stroke.Thickness = if slot == currentSlot then 4 else 2
		if summary then
			card.Cash.Text = Format.money(summary.Cash)
			card.Details.Text = ("🍋 %s\n🏠 %s\n📦 %d items bought"):format(summary.Stage, summary.Home, summary.Items)
			card.Action.Text = if slot == currentSlot then "▶ Playing now" else "▶ Play"
			card.Action.BackgroundColor3 = if slot == currentSlot then Color3.fromRGB(90, 95, 115) else Color3.fromRGB(60, 180, 90)
		else
			card.Cash.Text = "Empty"
			card.Details.Text = "Start a brand new empire from a lemonade stand."
			card.Action.Text = "✨ New game"
			card.Action.BackgroundColor3 = Color3.fromRGB(70, 140, 255)
		end
	end
	closeButton.Visible = currentSlot ~= nil
end

reopen.Activated:Connect(function()
	setOpen(true)
	task.spawn(refresh)
end)
closeButton.Activated:Connect(function()
	if currentSlot then
		setOpen(false)
	end
end)

refresh()
