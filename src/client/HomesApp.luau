--[[
	HomesApp.luau
	The 🏠 Homes app on your laptop: a real-estate app ("HomeFinder") where
	you browse homes, see 3D photos of them, buy one and move in.

	Phone.client.luau calls HomesApp.create(parent) once and gets back a
	window it can show and hide. The server side is src/server/Homes.luau,
	and the list of homes and prices is src/shared/HomeConfig.luau.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local HomeConfig = require(Shared:WaitForChild("HomeConfig"))

local player = Players.LocalPlayer

local HomesApp = {}

-- Colors: a bright, friendly "real estate website" look
local WHITE = Color3.new(1, 1, 1)
local PAGE = Color3.fromRGB(244, 246, 250)
local CARD = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(30, 34, 45)
local INK_DIM = Color3.fromRGB(110, 118, 135)
local BRAND = Color3.fromRGB(230, 80, 60)
local GREEN = Color3.fromRGB(40, 170, 90)
local BLUE = Color3.fromRGB(50, 120, 230)
local GOLD = Color3.fromRGB(235, 170, 30)
local SKY_TOP = Color3.fromRGB(120, 190, 255)
local SKY_BOTTOM = Color3.fromRGB(215, 238, 255)

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
	props.TextColor3 = props.TextColor3 or INK
	props.TextScaled = false
	props.TextSize = props.TextSize or 16
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local function getCash(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	return if cash then cash.Value else 0
end

local function priceText(home): string
	return if home.Price == 0 then "FREE" else Format.money(home.Price)
end

local function infoText(home): string
	local floors = if home.Storeys == 1 then "1 storey" else home.Storeys .. " storeys"
	local beds = if home.Bedrooms == 0 then "camp bed" elseif home.Bedrooms == 1 then "1 bed" else home.Bedrooms .. " beds"
	return floors .. "  ·  " .. beds
end

-- A 3D "photo" of a home: a ViewportFrame with a copy of the preview model.
-- Returns the frame and a function that turns the camera to an angle.
local function photo(parent: Instance, homeId: string, props)
	-- The sky is a separate frame behind the 3D view, so the gradient
	-- doesn't tint the house itself
	props.BackgroundColor3 = WHITE
	props.BorderSizePixel = 0
	props.Parent = parent
	local sky = make("Frame", props, {
		make("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(SKY_TOP, SKY_BOTTOM),
		}),
	})
	local viewport = make("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.fromRGB(255, 248, 235),
		LightDirection = Vector3.new(-1, -2, -1),
		ZIndex = props.ZIndex,
		Parent = sky,
	})
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local center = Vector3.zero
	local distance = 100
	local function setAngle(angle: number)
		local direction = Vector3.new(math.sin(angle), 0.55, math.cos(angle)).Unit
		camera.CFrame = CFrame.lookAt(center + direction * distance, center)
	end

	task.spawn(function()
		local previews = ReplicatedStorage:WaitForChild("HomePreviews")
		local source = previews:WaitForChild(homeId)
		local model = source:Clone()
		model.Parent = viewport
		-- Frame the house itself (not the whole lawn): everything above the grass
		local boxCFrame, boxSize = model:GetBoundingBox()
		center = boxCFrame.Position + Vector3.new(0, boxSize.Y * 0.1, 0)
		distance = math.max(boxSize.X * 0.55, boxSize.Y * 1.2, 40) * 1.6
		setAngle(0.55)
	end)

	return viewport, setAngle
end

function HomesApp.create(parent: Instance)
	local current = HomeConfig.StartingHome
	local owned: { [string]: boolean } = { [HomeConfig.StartingHome] = true }
	local selected = HomeConfig.StartingHome
	local busy = false

	local window = make("Frame", {
		Name = "HomesApp",
		Position = UDim2.fromOffset(150, 20),
		Size = UDim2.new(1, -170, 1, -80),
		BackgroundColor3 = PAGE,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	}, { corner(12) })

	-- Top bar, like a website header
	local header = make("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = WHITE,
		ZIndex = 5,
		Parent = window,
	})
	make("Frame", {
		Position = UDim2.new(0, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Color3.fromRGB(225, 228, 236),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = header,
	})
	text({
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.fromOffset(200, 52),
		TextSize = 24,
		TextColor3 = BRAND,
		Font = Enum.Font.FredokaOne,
		Text = "🏡 HomeFinder",
		ZIndex = 5,
		Parent = header,
	})
	text({
		Position = UDim2.fromOffset(200, 0),
		Size = UDim2.fromOffset(240, 52),
		TextSize = 14,
		TextColor3 = INK_DIM,
		Font = Enum.Font.GothamMedium,
		Text = "Homes for sale near you",
		ZIndex = 5,
		Parent = header,
	})
	local cashLabel = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 0),
		Size = UDim2.fromOffset(220, 52),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = GREEN,
		TextSize = 18,
		Text = "💵 $0",
		ZIndex = 5,
		Parent = header,
	})

	-- Listings down the left
	local list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.new(0, 300, 1, -76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = INK_DIM,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 5,
		Parent = window,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		make("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})

	-- The big listing page on the right
	local detail = make("Frame", {
		Position = UDim2.fromOffset(324, 64),
		Size = UDim2.new(1, -336, 1, -76),
		BackgroundColor3 = CARD,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = window,
	}, { corner(12) })

	local cards = {}
	local refreshDetail

	local function badgeFor(home): (string, Color3)
		if home.Id == current then
			return "🏠 YOU LIVE HERE", BLUE
		elseif owned[home.Id] then
			return "✔ OWNED", GREEN
		elseif home.Price == 0 then
			return "FREE", GREEN
		end
		return "FOR SALE", BRAND
	end

	for _, home in HomeConfig.Homes do
		local card = make("TextButton", {
			Size = UDim2.new(1, 0, 0, 96),
			BackgroundColor3 = CARD,
			AutoButtonColor = true,
			Text = "",
			LayoutOrder = home.Order,
			ZIndex = 5,
			Parent = list,
		}, { corner(10) })
		local stroke = make("UIStroke", {
			Color = BRAND,
			Thickness = 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = card,
		})
		photo(card, home.Id, {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(120, 80),
			ZIndex = 6,
		})
		local badge = text({
			Position = UDim2.fromOffset(138, 8),
			Size = UDim2.new(1, -146, 0, 16),
			TextSize = 11,
			Text = "",
			ZIndex = 6,
			Parent = card,
		})
		text({
			Position = UDim2.fromOffset(138, 26),
			Size = UDim2.new(1, -146, 0, 20),
			TextSize = 15,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = home.Name,
			ZIndex = 6,
			Parent = card,
		})
		text({
			Position = UDim2.fromOffset(138, 48),
			Size = UDim2.new(1, -146, 0, 20),
			TextSize = 17,
			TextColor3 = if home.Price == 0 then GREEN else INK,
			Text = priceText(home),
			ZIndex = 6,
			Parent = card,
		})
		text({
			Position = UDim2.fromOffset(138, 70),
			Size = UDim2.new(1, -146, 0, 16),
			TextSize = 12,
			Font = Enum.Font.GothamMedium,
			TextColor3 = INK_DIM,
			Text = infoText(home),
			ZIndex = 6,
			Parent = card,
		})
		card.Activated:Connect(function()
			selected = home.Id
			refreshDetail()
		end)
		cards[home.Id] = { Badge = badge, Stroke = stroke }
	end

	-- Detail page contents (rebuilt each time you pick a home)
	local spinning: ((number) -> ())? = nil
	local spinAngle = 0.55
	local actionButton: TextButton? = nil
	local messageLabel: TextLabel? = nil

	local function refreshCards()
		cashLabel.Text = "💵 " .. Format.money(getCash())
		for id, card in cards do
			local home = HomeConfig.HomesById[id]
			local badgeText, badgeColor = badgeFor(home)
			card.Badge.Text = badgeText
			card.Badge.TextColor3 = badgeColor
			card.Stroke.Thickness = if id == selected then 3 else 0
		end
	end

	local function updateButton()
		local button = actionButton
		if not button then
			return
		end
		local home = HomeConfig.HomesById[selected]
		if home.Id == current then
			button.Text = "🏠 You live here"
			button.BackgroundColor3 = Color3.fromRGB(170, 176, 190)
		elseif owned[home.Id] then
			button.Text = "🚚 Move in (free)"
			button.BackgroundColor3 = BLUE
		elseif getCash() >= home.Price then
			button.Text = "🔑 Buy for " .. priceText(home)
			button.BackgroundColor3 = GREEN
		else
			button.Text = "🔒 Need " .. Format.money(home.Price - getCash()) .. " more"
			button.BackgroundColor3 = Color3.fromRGB(170, 176, 190)
		end
	end

	local function ask(action: string)
		if busy then
			return
		end
		local home = HomeConfig.HomesById[selected]
		if action == "buy" and not owned[home.Id] and getCash() < home.Price then
			return
		end
		busy = true
		local ok, result = pcall(function()
			local remote = ReplicatedStorage:WaitForChild("HomeRequest") :: RemoteFunction
			return remote:InvokeServer(action, home.Id)
		end)
		busy = false
		if ok and type(result) == "table" then
			if result.Current then
				current = result.Current
			end
			if result.Owned then
				owned = result.Owned
			end
			if messageLabel then
				messageLabel.Text = if result.Ok then "🎉 Welcome home!" else (result.Message or "")
				messageLabel.TextColor3 = if result.Ok then GREEN else BRAND
			end
		elseif messageLabel then
			messageLabel.Text = "Couldn't reach the server, try again."
			messageLabel.TextColor3 = BRAND
		end
		refreshCards()
		updateButton()
	end

	refreshDetail = function()
		for _, child in detail:GetChildren() do
			if not child:IsA("UICorner") then
				child:Destroy()
			end
		end
		local home = HomeConfig.HomesById[selected]
		local _, setAngle = photo(detail, home.Id, {
			Size = UDim2.new(1, 0, 0.55, 0),
			ZIndex = 6,
		})
		spinning = setAngle
		spinAngle = 0.55

		local info = make("Frame", {
			Position = UDim2.new(0, 18, 0.55, 10),
			Size = UDim2.new(1, -36, 0.45, -20),
			BackgroundTransparency = 1,
			ZIndex = 6,
			Parent = detail,
		})
		text({
			Size = UDim2.new(1, -230, 0, 28),
			TextSize = 24,
			Text = home.Name,
			ZIndex = 6,
			Parent = info,
		})
		text({
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.new(1, -230, 0, 28),
			TextSize = 22,
			TextColor3 = if home.Price == 0 then GREEN else BRAND,
			Text = priceText(home),
			ZIndex = 6,
			Parent = info,
		})
		text({
			Position = UDim2.fromOffset(0, 62),
			Size = UDim2.new(1, -230, 0, 18),
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			TextColor3 = INK_DIM,
			Text = "🛏 " .. infoText(home),
			ZIndex = 6,
			Parent = info,
		})
		text({
			Position = UDim2.fromOffset(0, 88),
			Size = UDim2.new(1, 0, 1, -88),
			TextSize = 15,
			Font = Enum.Font.Gotham,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = home.Blurb,
			ZIndex = 6,
			Parent = info,
		})
		local button = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 4),
			Size = UDim2.fromOffset(210, 48),
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			TextColor3 = WHITE,
			AutoButtonColor = true,
			Text = "",
			ZIndex = 6,
			Parent = info,
		}, { corner(10) })
		messageLabel = text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 56),
			Size = UDim2.fromOffset(210, 18),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Enum.Font.GothamMedium,
			Text = "",
			ZIndex = 6,
			Parent = info,
		})
		button.Activated:Connect(function()
			if home.Id == current then
				return
			end
			ask(if owned[home.Id] then "move" else "buy")
		end)
		actionButton = button
		refreshCards()
		updateButton()
	end

	-- Slowly turn the big photo while the app is open
	RunService.RenderStepped:Connect(function(dt)
		if window.Visible and spinning then
			spinAngle += dt * 0.25
			spinning(spinAngle)
		end
	end)

	-- Keep the cash and buttons fresh
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats")
		local cash = leaderstats:WaitForChild("Cash")
		cash.Changed:Connect(function()
			if window.Visible then
				refreshCards()
				updateButton()
			end
		end)
	end)

	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.Visible then
			return
		end
		refreshCards()
		updateButton()
		task.spawn(function()
			local ok, result = pcall(function()
				local remote = ReplicatedStorage:WaitForChild("HomeRequest") :: RemoteFunction
				return remote:InvokeServer("list")
			end)
			if ok and type(result) == "table" and result.Current then
				current = result.Current
				owned = result.Owned or owned
				refreshCards()
				updateButton()
			end
		end)
	end)

	refreshDetail()
	return window
end

return HomesApp
