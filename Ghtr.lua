local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Camera = Workspace.CurrentCamera

-- ================== КЛЮЧ ==================
local function generateKey()
	local seed = math.floor(os.time() / (5 * 60 * 60)) % 100000
	return string.format("%05d", (seed * 37 + 12345) % 100000)
end
local VALID_KEY = generateKey()

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HelperFarmGUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local keyFrame = Instance.new("Frame")
keyFrame.Size = UDim2.new(0, 260, 0, 150)
keyFrame.Position = UDim2.new(0.5, -130, 0.5, -75)
keyFrame.BackgroundColor3 = Color3.fromRGB(13, 20, 45)
keyFrame.BorderSizePixel = 0
keyFrame.Parent = screenGui
Instance.new("UICorner", keyFrame).CornerRadius = UDim.new(0, 8)

local keyTitle = Instance.new("TextLabel")
keyTitle.Size = UDim2.new(1, 0, 0, 24)
keyTitle.Position = UDim2.new(0, 0, 0, 8)
keyTitle.BackgroundTransparency = 1
keyTitle.Text = "Введите ключ"
keyTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
keyTitle.Font = Enum.Font.GothamBold
keyTitle.TextSize = 16
keyTitle.Parent = keyFrame

local keyDisplay = Instance.new("TextLabel")
keyDisplay.Size = UDim2.new(1, -30, 0, 20)
keyDisplay.Position = UDim2.new(0, 15, 0, 34)
keyDisplay.BackgroundTransparency = 1
keyDisplay.Text = "Текущий ключ: " .. VALID_KEY
keyDisplay.TextColor3 = Color3.fromRGB(180, 200, 255)
keyDisplay.Font = Enum.Font.Gotham
keyDisplay.TextSize = 12
keyDisplay.TextXAlignment = Enum.TextXAlignment.Left
keyDisplay.Parent = keyFrame

local keyInput = Instance.new("TextBox")
keyInput.Size = UDim2.new(1, -30, 0, 28)
keyInput.Position = UDim2.new(0, 15, 0, 60)
keyInput.BackgroundColor3 = Color3.fromRGB(30, 40, 70)
keyInput.BorderSizePixel = 0
keyInput.PlaceholderText = "Ключ..."
keyInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
keyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
keyInput.Font = Enum.Font.Gotham
keyInput.TextSize = 14
keyInput.Parent = keyFrame
Instance.new("UICorner", keyInput).CornerRadius = UDim.new(0, 4)

local keyError = Instance.new("TextLabel")
keyError.Size = UDim2.new(1, 0, 0, 16)
keyError.Position = UDim2.new(0, 0, 0, 92)
keyError.BackgroundTransparency = 1
keyError.Text = ""
keyError.TextColor3 = Color3.fromRGB(255, 80, 80)
keyError.Font = Enum.Font.Gotham
keyError.TextSize = 11
keyError.TextWrapped = true
keyError.Parent = keyFrame

local keyButton = Instance.new("TextButton")
keyButton.Size = UDim2.new(0, 70, 0, 24)
keyButton.Position = UDim2.new(0.5, -35, 0, 112)
keyButton.BackgroundColor3 = Color3.fromRGB(50, 100, 220)
keyButton.BorderSizePixel = 0
keyButton.Text = "OK"
keyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
keyButton.Font = Enum.Font.GothamBold
keyButton.TextSize = 14
keyButton.Parent = keyFrame
Instance.new("UICorner", keyButton).CornerRadius = UDim.new(0, 4)

local mainFrame = nil

keyButton.MouseButton1Click:Connect(function()
	if keyInput.Text ~= VALID_KEY then
		keyError.Text = "Неверный ключ!"
		return
	end
	if type(createMainMenu) ~= "function" then
		keyError.Text = "Ошибка: меню не загружено"
		warn("[Helper Farm] createMainMenu is nil")
		return
	end
	local ok, err = pcall(createMainMenu)
	if ok then
		keyFrame:Destroy()
	else
		keyError.Text = "Ошибка: " .. tostring(err):sub(1, 80)
		warn("[Helper Farm] " .. tostring(err))
		print(debug.traceback())
	end
end)

-- ================== ЛОГИКА ТРАНСПОРТА ==================
local driving = false
local activeCar = nil
local carSeat = nil
local carSpeed = 0
local carVertical = 0
local activeVehicleCanFly = false
local activeRotors = {}

local CAR_MAX_SPEED = 90
local CAR_ACCEL = 45
local CAR_TURN_SPEED = 2.2
local FLY_MAX_SPEED = 70
local FLY_ACCEL = 35
local FLY_VERTICAL_SPEED = 45

local selectedVehicleType = "car"

local carBtnForward = false
local carBtnBackward = false
local carBtnLeft = false
local carBtnRight = false
local carBtnVertUp = false
local carBtnVertDown = false

local carControlsGui = Instance.new("Frame")
carControlsGui.Name = "CarControls"
carControlsGui.Size = UDim2.new(1, 0, 1, 0)
carControlsGui.BackgroundTransparency = 1
carControlsGui.Visible = false
carControlsGui.ZIndex = 50
carControlsGui.Parent = screenGui

local function makeCarBtn(text, position, size)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, size, 0, size)
	btn.Position = position
	btn.BackgroundColor3 = Color3.fromRGB(50, 100, 220)
	btn.BackgroundTransparency = 0.25
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = math.floor(size * 0.4)
	btn.AutoButtonColor = false
	btn.ZIndex = 51
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, size / 2)
	btn.Parent = carControlsGui
	return btn
end

local carBtnUp = makeCarBtn("▲", UDim2.new(0, 30, 1, -220), 70)
local carBtnDown = makeCarBtn("▼", UDim2.new(0, 30, 1, -140), 70)
local carBtnLeft = makeCarBtn("◄", UDim2.new(0, 110, 1, -180), 70)
local carBtnRight = makeCarBtn("►", UDim2.new(1, -180, 1, -180), 70)
local carBtnVertUp = makeCarBtn("▲", UDim2.new(1, -180, 1, -280), 60)
local carBtnVertDown = makeCarBtn("▼", UDim2.new(1, -180, 1, -210), 60)
carBtnVertUp.Visible = false
carBtnVertDown.Visible = false

local carExitBtn = Instance.new("TextButton")
carExitBtn.Size = UDim2.new(0, 90, 0, 40)
carExitBtn.Position = UDim2.new(1, -110, 1, -100)
carExitBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
carExitBtn.BackgroundTransparency = 0.15
carExitBtn.BorderSizePixel = 0
carExitBtn.Text = "ВЫЙТИ"
carExitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
carExitBtn.Font = Enum.Font.GothamBold
carExitBtn.TextSize = 13
carExitBtn.AutoButtonColor = false
carExitBtn.ZIndex = 51
Instance.new("UICorner", carExitBtn).CornerRadius = UDim.new(0, 8)
carExitBtn.Parent = carControlsGui

local function bindHoldButton(btn, setter)
	local baseColor = Color3.fromRGB(50, 100, 220)
	local pressColor = Color3.fromRGB(90, 160, 255)
	local function setState(state)
		if setter then setter(state) end
		btn.BackgroundColor3 = state and pressColor or baseColor
	end
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setState(true)
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setState(false)
		end
	end)
	btn.MouseLeave:Connect(function()
		if btn.BackgroundColor3 == pressColor then setState(false) end
	end)
end

bindHoldButton(carBtnUp, function(v) carBtnForward = v end)
bindHoldButton(carBtnDown, function(v) carBtnBackward = v end)
bindHoldButton(carBtnLeft, function(v) carBtnLeft = v end)
bindHoldButton(carBtnRight, function(v) carBtnRight = v end)
bindHoldButton(carBtnVertUp, function(v) carBtnVertUp = v end)
bindHoldButton(carBtnVertDown, function(v) carBtnVertDown = v end)

-- ================== ПОСТРОЙКА ТРАНСПОРТА ==================
local function buildVehicle(vehicleType)
	local char = player.Character
	if not char then return nil, "Персонаж не найден" end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return nil, "Нет HumanoidRootPart" end

	local lookFlat = root.CFrame.LookVector
	lookFlat = Vector3.new(lookFlat.X, 0, lookFlat.Z)
	if lookFlat.Magnitude < 0.01 then
		lookFlat = Vector3.new(0, 0, -1)
	else
		lookFlat = lookFlat.Unit
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {char}

	local spawnPos = root.Position + lookFlat * 14
	local rayResult = Workspace:Raycast(spawnPos + Vector3.new(0, 6, 0), Vector3.new(0, -80, 0), rayParams)
	local groundY = rayResult and rayResult.Position.Y or (root.Position.Y - 3)

	local baseCF = CFrame.lookAt(
		Vector3.new(spawnPos.X, groundY, spawnPos.Z),
		Vector3.new(spawnPos.X, groundY, spawnPos.Z) + lookFlat
	)

	local car = Instance.new("Model")
	car.Name = "Vehicle_" .. vehicleType .. "_" .. tostring(math.floor(tick() * 1000))

	local rotors = {}

	local function mkPart(props)
		local p = Instance.new("Part")
		p.Name = props.name or "Part"
		p.Size = props.size or Vector3.new(1, 1, 1)
		p.Color = props.color or Color3.fromRGB(150, 150, 150)
		p.Material = props.material or Enum.Material.Plastic
		p.Shape = props.shape or Enum.PartType.Block
		p.Transparency = props.transparency or 0
		p.CanCollide = false
		p.Anchored = true
		p.CanQuery = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = baseCF * CFrame.new(props.offset or Vector3.new(0, 0, 0))
		p.Parent = car
		return p
	end

	local chassis, seat

	if vehicleType == "car" then
		chassis = mkPart({name="Chassis", size=Vector3.new(6,1.5,12), color=Color3.fromRGB(200,40,40), material=Enum.Material.Metal, offset=Vector3.new(0,1.5,0)})
		mkPart({name="Cabin", size=Vector3.new(5.5,1.8,6), color=Color3.fromRGB(180,30,30), material=Enum.Material.Metal, offset=Vector3.new(0,3.2,0.5)})
		mkPart({name="Windshield", size=Vector3.new(5.3,1.4,0.15), color=Color3.fromRGB(120,200,255), material=Enum.Material.Glass, transparency=0.4, offset=Vector3.new(0,3.2,-2.5)})
		for _, wp in ipairs({
			{Vector3.new(-3.2,1.1,-3.8),"FL"},{Vector3.new(3.2,1.1,-3.8),"FR"},
			{Vector3.new(-3.2,1.1,3.8),"BL"},{Vector3.new(3.2,1.1,3.8),"BR"},
		}) do
			mkPart({name=wp[2], size=Vector3.new(1,2.2,2.2), color=Color3.fromRGB(20,20,20), material=Enum.Material.Rubber, shape=Enum.PartType.Cylinder, offset=wp[1]})
		end
		mkPart({name="HL1", size=Vector3.new(0.9,0.9,0.9), color=Color3.fromRGB(255,240,150), material=Enum.Material.Neon, shape=Enum.PartType.Ball, offset=Vector3.new(-2,1.7,-5.9)})
		mkPart({name="HL2", size=Vector3.new(0.9,0.9,0.9), color=Color3.fromRGB(255,240,150), material=Enum.Material.Neon, shape=Enum.PartType.Ball, offset=Vector3.new(2,1.7,-5.9)})
		seat = mkPart({name="SeatPoint", size=Vector3.new(2,0.4,2), color=Color3.fromRGB(30,30,30), transparency=1, offset=Vector3.new(0,2.8,-0.5)})

	elseif vehicleType == "gelik" then
		chassis = mkPart({name="Chassis", size=Vector3.new(6,2,12), color=Color3.fromRGB(25,25,25), material=Enum.Material.Metal, offset=Vector3.new(0,1.7,0)})
		mkPart({name="Cabin", size=Vector3.new(5.8,2.2,7), color=Color3.fromRGB(15,15,15), material=Enum.Material.Metal, offset=Vector3.new(0,3.8,0.5)})
		mkPart({name="Windshield", size=Vector3.new(5.5,1.7,0.15), color=Color3.fromRGB(100,180,220), material=Enum.Material.Glass, transparency=0.35, offset=Vector3.new(0,3.9,-3)})
		mkPart({name="RearGlass", size=Vector3.new(5.5,1.7,0.15), color=Color3.fromRGB(100,180,220), material=Enum.Material.Glass, transparency=0.35, offset=Vector3.new(0,3.9,4)})
		mkPart({name="RoofLight1", size=Vector3.new(0.5,0.5,0.5), color=Color3.fromRGB(255,240,150), material=Enum.Material.Neon, shape=Enum.PartType.Ball, offset=Vector3.new(-1.5,5.1,-2)})
		mkPart({name="RoofLight2", size=Vector3.new(0.5,0.5,0.5), color=Color3.fromRGB(255,240,150), material=Enum.Material.Neon, shape=Enum.PartType.Ball, offset=Vector3.new(1.5,5.1,-2)})
		for _, wp in ipairs({
			{Vector3.new(-3.2,1.2,-4),"FL"},{Vector3.new(3.2,1.2,-4),"FR"},
			{Vector3.new(-3.2,1.2,4),"BL"},{Vector3.new(3.2,1.2,4),"BR"},
		}) do
			mkPart({name=wp[2], size=Vector3.new(1.2,2.4,2.4), color=Color3.fromRGB(15,15,15), material=Enum.Material.Rubber, shape=Enum.PartType.Cylinder, offset=wp[1]})
		end
		seat = mkPart({name="SeatPoint", size=Vector3.new(2,0.4,2), color=Color3.fromRGB(30,30,30), transparency=1, offset=Vector3.new(0,3.4,-0.5)})

	elseif vehicleType == "truck" then
		chassis = mkPart({name="Chassis", size=Vector3.new(7,1.6,18), color=Color3.fromRGB(40,80,180), material=Enum.Material.Metal, offset=Vector3.new(0,1.7,0)})
		mkPart({name="Cabin", size=Vector3.new(6.8,2.6,6), color=Color3.fromRGB(30,60,160), material=Enum.Material.Metal, offset=Vector3.new(0,4,-5)})
		mkPart({name="Windshield", size=Vector3.new(6.5,2,0.15), color=Color3.fromRGB(120,200,255), material=Enum.Material.Glass, transparency=0.4, offset=Vector3.new(0,4.2,-8)})
		mkPart({name="Cargo", size=Vector3.new(6.8,3,10), color=Color3.fromRGB(180,180,180), material=Enum.Material.Metal, offset=Vector3.new(0,3.6,3.5)})
		mkPart({name="CargoTop", size=Vector3.new(7,0.3,10.2), color=Color3.fromRGB(200,200,200), material=Enum.Material.Metal, offset=Vector3.new(0,5.2,3.5)})
		for _, wp in ipairs({
			{Vector3.new(-3.7,1.3,-6),"FL"},{Vector3.new(3.7,1.3,-6),"FR"},
			{Vector3.new(-3.7,1.3,2),"ML"},{Vector3.new(3.7,1.3,2),"MR"},
			{Vector3.new(-3.7,1.3,7),"BL"},{Vector3.new(3.7,1.3,7),"BR"},
		}) do
			mkPart({name=wp[2], size=Vector3.new(1.2,2.6,2.6), color=Color3.fromRGB(20,20,20), material=Enum.Material.Rubber, shape=Enum.PartType.Cylinder, offset=wp[1]})
		end
		mkPart({name="HL1", size=Vector3.new(1,1,1), color=Color3.fromRGB(255,240,150), material=Enum.Material.Neon, shape=Enum.PartType.Ball, offset=Vector3.new(-2.5,1.8,-9)})
		mkPart({name="HL2", size=Vector3.new(1,1,1), color=Color3.fromRGB(255,240,150), material=Enum.Material.Neon, shape=Enum.PartType.Ball, offset=Vector3.new(2.5,1.8,-9)})
		seat = mkPart({name="SeatPoint", size=Vector3.new(2,0.4,2), color=Color3.fromRGB(30,30,30), transparency=1, offset=Vector3.new(0,3.5,-5)})

	elseif vehicleType == "tank" then
		chassis = mkPart({name="Chassis", size=Vector3.new(7,2,14), color=Color3.fromRGB(60,80,50), material=Enum.Material.Metal, offset=Vector3.new(0,1.8,0)})
		mkPart({name="TrackL", size=Vector3.new(1.2,2.4,14), color=Color3.fromRGB(20,20,20), material=Enum.Material.Rubber, offset=Vector3.new(-3.7,1.2,0)})
		mkPart({name="TrackR", size=Vector3.new(1.2,2.4,14), color=Color3.fromRGB(20,20,20), material=Enum.Material.Rubber, offset=Vector3.new(3.7,1.2,0)})
		mkPart({name="Turret", size=Vector3.new(5,1.8,5), color=Color3.fromRGB(50,70,40), material=Enum.Material.Metal, offset=Vector3.new(0,4,0)})
		mkPart({name="Barrel", size=Vector3.new(0.6,0.6,7), color=Color3.fromRGB(40,50,30), material=Enum.Material.Metal, offset=Vector3.new(0,4,-5.5)})
		mkPart({name="HatchL", size=Vector3.new(1.8,0.2,1.8), color=Color3.fromRGB(40,50,30), material=Enum.Material.Metal, offset=Vector3.new(0,5,1)})
		seat = mkPart({name="SeatPoint", size=Vector3.new(2,0.4,2), color=Color3.fromRGB(30,30,30), transparency=1, offset=Vector3.new(0,3.3,1)})

	elseif vehicleType == "helicopter" then
		chassis = mkPart({name="Chassis", size=Vector3.new(4.5,2.5,7), color=Color3.fromRGB(50,90,180), material=Enum.Material.Metal, offset=Vector3.new(0,3,0)})
		mkPart({name="Cabin", size=Vector3.new(4.3,2,3), color=Color3.fromRGB(120,180,255), material=Enum.Material.Glass, transparency=0.35, offset=Vector3.new(0,3.2,-3.5)})
		mkPart({name="Tail", size=Vector3.new(1.2,1.2,7), color=Color3.fromRGB(40,80,170), material=Enum.Material.Metal, offset=Vector3.new(0,3.5,7)})
		mkPart({name="TailFin", size=Vector3.new(0.3,2.5,2), color=Color3.fromRGB(40,80,170), material=Enum.Material.Metal, offset=Vector3.new(0,4.5,10)})
		mkPart({name="SkidL", size=Vector3.new(0.4,0.4,6), color=Color3.fromRGB(40,40,40), material=Enum.Material.Metal, offset=Vector3.new(-2,1.5,0)})
		mkPart({name="SkidR", size=Vector3.new(0.4,0.4,6), color=Color3.fromRGB(40,40,40), material=Enum.Material.Metal, offset=Vector3.new(2,1.5,0)})
		mkPart({name="SkidLegL1", size=Vector3.new(0.4,1.2,0.4), color=Color3.fromRGB(40,40,40), material=Enum.Material.Metal, offset=Vector3.new(-2,2.1,-2)})
		mkPart({name="SkidLegR1", size=Vector3.new(0.4,1.2,0.4), color=Color3.fromRGB(40,40,40), material=Enum.Material.Metal, offset=Vector3.new(2,2.1,-2)})
		mkPart({name="SkidLegL2", size=Vector3.new(0.4,1.2,0.4), color=Color3.fromRGB(40,40,40), material=Enum.Material.Metal, offset=Vector3.new(-2,2.1,2)})
		mkPart({name="SkidLegR2", size=Vector3.new(0.4,1.2,0.4), color=Color3.fromRGB(40,40,40), material=Enum.Material.Metal, offset=Vector3.new(2,2.1,2)})
		mkPart({name="RotorPole", size=Vector3.new(0.4,0.5,0.4), color=Color3.fromRGB(30,30,30), material=Enum.Material.Metal, offset=Vector3.new(0,4.5,0)})
		local mainRotor = mkPart({name="MainRotor", size=Vector3.new(14,0.15,0.6), color=Color3.fromRGB(40,40,40), material=Enum.Material.Metal, offset=Vector3.new(0,4.9,0)})
		local tailRotor = mkPart({name="TailRotor", size=Vector3.new(3,0.15,0.4), color=Color3.fromRGB(40,40,40), material=Enum.Material.Metal, offset=Vector3.new(0,4.5,10.4)})
		tailRotor.CFrame = baseCF * CFrame.new(0, 4.5, 10.4) * CFrame.Angles(0, 0, math.rad(90))
		table.insert(rotors, {part = mainRotor, axis = "y", speed = 25})
		table.insert(rotors, {part = tailRotor, axis = "x", speed = 40})
		seat = mkPart({name="SeatPoint", size=Vector3.new(2,0.4,2), color=Color3.fromRGB(30,30,30), transparency=1, offset=Vector3.new(0,3.5,0)})

	elseif vehicleType == "plane" then
		chassis = mkPart({name="Chassis", size=Vector3.new(3,2,16), color=Color3.fromRGB(220,220,220), material=Enum.Material.Metal, offset=Vector3.new(0,3,0)})
		mkPart({name="Nose", size=Vector3.new(2.5,2,3), color=Color3.fromRGB(200,200,200), material=Enum.Material.Metal, offset=Vector3.new(0,3,-8.5)})
		mkPart({name="Cockpit", size=Vector3.new(2.5,1.5,3), color=Color3.fromRGB(120,200,255), material=Enum.Material.Glass, transparency=0.35, offset=Vector3.new(0,4.3,-4)})
		mkPart({name="WingMain", size=Vector3.new(18,0.4,3), color=Color3.fromRGB(200,200,200), material=Enum.Material.Metal, offset=Vector3.new(0,3,0)})
		mkPart({name="WingTipL", size=Vector3.new(0.4,1.5,2), color=Color3.fromRGB(220,60,60), material=Enum.Material.Metal, offset=Vector3.new(-9,3.5,0.5)})
		mkPart({name="WingTipR", size=Vector3.new(0.4,1.5,2), color=Color3.fromRGB(220,60,60), material=Enum.Material.Metal, offset=Vector3.new(9,3.5,0.5)})
		mkPart({name="TailWing", size=Vector3.new(7,0.3,2), color=Color3.fromRGB(200,200,200), material=Enum.Material.Metal, offset=Vector3.new(0,3.5,7.5)})
		mkPart({name="TailFin", size=Vector3.new(0.3,3,2), color=Color3.fromRGB(200,200,200), material=Enum.Material.Metal, offset=Vector3.new(0,4.5,7.5)})
		mkPart({name="EngineL", size=Vector3.new(2,1.5,4), color=Color3.fromRGB(80,80,80), material=Enum.Material.Metal, offset=Vector3.new(-4,2.2,0)})
		mkPart({name="EngineR", size=Vector3.new(2,1.5,4), color=Color3.fromRGB(80,80,80), material=Enum.Material.Metal, offset=Vector3.new(4,2.2,0)})
		local propL = mkPart({name="PropL", size=Vector3.new(0.3,4,0.3), color=Color3.fromRGB(30,30,30), material=Enum.Material.Metal, offset=Vector3.new(-4,2.2,-2.2)})
		local propR = mkPart({name="PropR", size=Vector3.new(0.3,4,0.3), color=Color3.fromRGB(30,30,30), material=Enum.Material.Metal, offset=Vector3.new(4,2.2,-2.2)})
		table.insert(rotors, {part = propL, axis = "z", speed = 50})
		table.insert(rotors, {part = propR, axis = "z", speed = 50})
		seat = mkPart({name="SeatPoint", size=Vector3.new(2,0.4,2), color=Color3.fromRGB(30,30,30), transparency=1, offset=Vector3.new(0,3.5,-0.5)})
	end

	car.PrimaryPart = chassis
	car.Parent = Workspace

	local canFly = (vehicleType == "helicopter" or vehicleType == "plane")
	return car, seat, canFly, rotors
end

local function forceSitPlayer(car, seat)
	local char = player.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return false end

	hum.Sit = true
	hum.PlatformStand = false
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.UseJumpPower = true

	hrp.CFrame = seat.CFrame * CFrame.new(0, 1.2, 0)
	return true
end

local function enterCar(car, seat, canFly, rotors)
	if driving then return end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp) then return false end

	pcall(function()
		char:PivotTo(car:GetPivot() * CFrame.new(0, 3, 0))
	end)
	task.wait(0.05)

	driving = true
	activeCar = car
	carSeat = seat
	carSpeed = 0
	carVertical = 0
	activeVehicleCanFly = canFly or false
	activeRotors = rotors or {}

	forceSitPlayer(car, seat)

	carControlsGui.Visible = true
	carBtnVertUp.Visible = activeVehicleCanFly
	carBtnVertDown.Visible = activeVehicleCanFly
	return true
end

local function exitCar()
	if not driving then return end

	driving = false
	activeCar = nil
	carSeat = nil
	carSpeed = 0
	carVertical = 0
	activeVehicleCanFly = false
	activeRotors = {}

	carControlsGui.Visible = false
	carBtnVertUp.Visible = false
	carBtnVertDown.Visible = false
	carBtnForward, carBtnBackward, carBtnLeft, carBtnRight = false, false, false, false
	carBtnVertUp, carBtnVertDown = false, false

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")

	if hum then
		hum.Sit = false
		hum.PlatformStand = false
		hum.WalkSpeed = 16
		hum.UseJumpPower = true
		hum.JumpPower = 50
	end

	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = hrp.CFrame + Vector3.new(0, 2, 0)
	end
end

carExitBtn.MouseButton1Click:Connect(function() exitCar() end)

-- ================== ЛУП УПРАВЛЕНИЯ ==================
local carDriveConnection = RunService.Heartbeat:Connect(function(dt)
	if not driving or not activeCar or not activeCar.Parent then
		if driving then exitCar() end
		return
	end

	local seat = carSeat
	if not seat or not seat.Parent then exitCar(); return end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp) then exitCar(); return end

	for _, r in ipairs(activeRotors) do
		if r.part and r.part.Parent then
			local ang = math.rad(r.speed * 360 * dt)
			if r.axis == "y" then
				r.part.CFrame = r.part.CFrame * CFrame.Angles(0, ang, 0)
			elseif r.axis == "x" then
				r.part.CFrame = r.part.CFrame * CFrame.Angles(ang, 0, 0)
			elseif r.axis == "z" then
				r.part.CFrame = r.part.CFrame * CFrame.Angles(0, 0, ang)
			end
		end
	end

	local throttle = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or carBtnForward then throttle = 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or carBtnBackward then throttle = -1 end

	local turn = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or carBtnLeft then turn = 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or carBtnRight then turn = -1 end

	local vertical = 0
	if activeVehicleCanFly then
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) or carBtnVertUp then vertical = 1 end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) or carBtnVertDown then vertical = -1 end
	end

	local maxSpeed = activeVehicleCanFly and FLY_MAX_SPEED or CAR_MAX_SPEED
	local accel = activeVehicleCanFly and FLY_ACCEL or CAR_ACCEL

	if throttle ~= 0 then
		carSpeed = carSpeed + throttle * accel * dt
	else
		carSpeed = carSpeed * (1 - 3.5 * dt)
		if math.abs(carSpeed) < 0.3 then carSpeed = 0 end
	end
	carSpeed = math.clamp(carSpeed, -maxSpeed * 0.4, maxSpeed)

	local turnAmount = 0
	if activeVehicleCanFly then
		turnAmount = turn * CAR_TURN_SPEED * dt * 0.9
	else
		if math.abs(carSpeed) > 1 then
			turnAmount = turn * CAR_TURN_SPEED * dt * (carSpeed > 0 and 1 or -1)
		end
	end

	local pivot = activeCar:GetPivot()
	pivot = pivot * CFrame.Angles(0, turnAmount, 0)
	pivot = pivot + pivot.LookVector * carSpeed * dt

	if activeVehicleCanFly and vertical ~= 0 then
		pivot = pivot + Vector3.new(0, vertical * FLY_VERTICAL_SPEED * dt, 0)
	end

	activeCar:PivotTo(pivot)

	hrp.CFrame = seat.CFrame * CFrame.new(0, 1.2, 0)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if driving and input.KeyCode == Enum.KeyCode.E then
		exitCar()
	end
end)

-- ================== МЕНЮ ==================
function createMainMenu()
	mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, 340, 0, 380)
	mainFrame.Position = UDim2.new(0.5, -170, 0.5, -190)
	mainFrame.BackgroundColor3 = Color3.fromRGB(13, 20, 45)
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = screenGui
	Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 36)
	topBar.BackgroundColor3 = Color3.fromRGB(25, 40, 80)
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 2
	Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)
	topBar.Parent = mainFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0, 100, 1, 0)
	titleLabel.Position = UDim2.new(0, 12, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Helper farm"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 15
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 3
	titleLabel.Parent = topBar

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.new(1, -180, 1, 0)
	statsLabel.Position = UDim2.new(0, 115, 0, 0)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = "FPS: -- | Ping: -- ms"
	statsLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 11
	statsLabel.TextXAlignment = Enum.TextXAlignment.Right
	statsLabel.ZIndex = 3
	statsLabel.Parent = topBar

	local fpsCount, fpsAccum = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		fpsCount = fpsCount + 1
		fpsAccum = fpsAccum + dt
		if fpsAccum >= 1 then
			local fps = math.floor(fpsCount / fpsAccum + 0.5)
			fpsCount, fpsAccum = 0, 0
			local ping = 0
			pcall(function() ping = math.floor(player:GetNetworkPing() * 1000 + 0.5) end)
			statsLabel.Text = string.format("FPS: %d | Ping: %d ms", fps, ping)
		end
	end)

	local minimizeButton = Instance.new("TextButton")
	minimizeButton.Size = UDim2.new(0, 22, 0, 22)
	minimizeButton.Position = UDim2.new(1, -54, 0, 7)
	minimizeButton.BackgroundColor3 = Color3.fromRGB(100, 140, 220)
	minimizeButton.BorderSizePixel = 0
	minimizeButton.Text = "—"
	minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	minimizeButton.Font = Enum.Font.GothamBold
	minimizeButton.TextSize = 12
	minimizeButton.ZIndex = 3
	Instance.new("UICorner", minimizeButton).CornerRadius = UDim.new(0, 5)
	minimizeButton.Parent = topBar

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 22, 0, 22)
	closeButton.Position = UDim2.new(1, -30, 0, 7)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 12
	closeButton.ZIndex = 3
	Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 5)
	closeButton.Parent = topBar
	closeButton.MouseButton1Click:Connect(function() mainFrame.Visible = false end)

	local dragBottom = Instance.new("Frame")
	dragBottom.Size = UDim2.new(1, -16, 0, 32)
	dragBottom.Position = UDim2.new(0, 8, 1, -38)
	dragBottom.BackgroundTransparency = 1
	dragBottom.ZIndex = 2
	dragBottom.Parent = mainFrame

	local dragLeft = Instance.new("Frame")
	dragLeft.Size = UDim2.new(0, 16, 1, -76)
	dragLeft.Position = UDim2.new(0, 0, 0, 38)
	dragLeft.BackgroundTransparency = 1
	dragLeft.ZIndex = 2
	dragLeft.Parent = mainFrame

	local dragRight = Instance.new("Frame")
	dragRight.Size = UDim2.new(0, 16, 1, -76)
	dragRight.Position = UDim2.new(1, -16, 0, 38)
	dragRight.BackgroundTransparency = 1
	dragRight.ZIndex = 2
	dragRight.Parent = mainFrame

	local isDragging = false
	local dragStartPos, frameStartPos

	for _, zone in ipairs({topBar, dragBottom, dragLeft, dragRight}) do
		zone.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				isDragging = true
				dragStartPos = input.Position
				frameStartPos = mainFrame.Position
			end
		end)
	end

	UserInputService.InputChanged:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStartPos
			mainFrame.Position = UDim2.new(
				frameStartPos.X.Scale, frameStartPos.X.Offset + delta.X,
				frameStartPos.Y.Scale, frameStartPos.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = false
		end
	end)

	local tabBar = Instance.new("Frame")
	tabBar.Size = UDim2.new(0, 80, 1, -10)
	tabBar.Position = UDim2.new(0, 5, 0, 40)
	tabBar.BackgroundTransparency = 1
	tabBar.ZIndex = 2
	tabBar.Parent = mainFrame

	local function makeTab(text, y, size)
		local t = Instance.new("TextButton")
		t.Size = UDim2.new(1, 0, 0, 24)
		t.Position = UDim2.new(0, 0, 0, y)
		t.BackgroundColor3 = Color3.fromRGB(60, 90, 170)
		t.BorderSizePixel = 0
		t.Text = text
		t.TextColor3 = Color3.fromRGB(255, 255, 255)
		t.Font = Enum.Font.GothamBold
		t.TextSize = size or 12
		t.ZIndex = 3
		Instance.new("UICorner", t).CornerRadius = UDim.new(0, 4)
		t.Parent = tabBar
		return t
	end

	local mainTab = makeTab("Main", 0, 12)
	local soonTab = makeTab("soon", 26, 12)
	local teleportTab = makeTab("Teleport", 52, 11)
	local transportTab = makeTab("Transport", 78, 10)

	local function makeContent()
		local f = Instance.new("Frame")
		f.Size = UDim2.new(1, -100, 1, -50)
		f.Position = UDim2.new(0, 90, 0, 40)
		f.BackgroundTransparency = 1
		f.Visible = false
		f.ZIndex = 2
		f.Parent = mainFrame
		return f
	end

	local mainTabContent = makeContent()
	mainTabContent.Visible = true
	local soonTabContent = makeContent()
	local teleportTabContent = makeContent()
	local transportTabContent = makeContent()

	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollingFrame.BackgroundTransparency = 1
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.ScrollBarThickness = 3
	scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(50, 100, 220)
	scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollingFrame.ZIndex = 3
	scrollingFrame.Parent = mainTabContent

	-- SOON TAB
	local soonTitle = Instance.new("TextLabel")
	soonTitle.Size = UDim2.new(1, 0, 0, 24)
	soonTitle.Position = UDim2.new(0, 0, 0, 10)
	soonTitle.BackgroundTransparency = 1
	soonTitle.Text = "Inf Jump"
	soonTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	soonTitle.Font = Enum.Font.GothamSemibold
	soonTitle.TextSize = 14
	soonTitle.TextXAlignment = Enum.TextXAlignment.Left
	soonTitle.ZIndex = 3
	soonTitle.Parent = soonTabContent

	local infJumpToggleGroup = Instance.new("Frame")
	infJumpToggleGroup.Size = UDim2.new(1, 0, 0, 34)
	infJumpToggleGroup.Position = UDim2.new(0, 0, 0, 40)
	infJumpToggleGroup.BackgroundTransparency = 1
	infJumpToggleGroup.ZIndex = 3
	infJumpToggleGroup.Parent = soonTabContent

	local infJumpLabel = Instance.new("TextLabel")
	infJumpLabel.Size = UDim2.new(1, -46, 0, 14)
	infJumpLabel.BackgroundTransparency = 1
	infJumpLabel.Text = "Inf Jump"
	infJumpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	infJumpLabel.Font = Enum.Font.GothamSemibold
	infJumpLabel.TextSize = 12
	infJumpLabel.TextXAlignment = Enum.TextXAlignment.Left
	infJumpLabel.ZIndex = 3
	infJumpLabel.Parent = infJumpToggleGroup

	local infJumpDesc = Instance.new("TextLabel")
	infJumpDesc.Size = UDim2.new(1, -46, 0, 11)
	infJumpDesc.Position = UDim2.new(0, 0, 0, 14)
	infJumpDesc.BackgroundTransparency = 1
	infJumpDesc.Text = "Бесконечный прыжок"
	infJumpDesc.TextColor3 = Color3.fromRGB(180, 180, 180)
	infJumpDesc.Font = Enum.Font.Gotham
	infJumpDesc.TextSize = 9
	infJumpDesc.TextXAlignment = Enum.TextXAlignment.Left
	infJumpDesc.ZIndex = 3
	infJumpDesc.Parent = infJumpToggleGroup

	local infJumpToggleBox = Instance.new("Frame")
	infJumpToggleBox.Size = UDim2.new(0, 32, 0, 18)
	infJumpToggleBox.Position = UDim2.new(1, -38, 0, 7)
	infJumpToggleBox.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	infJumpToggleBox.BorderSizePixel = 0
	infJumpToggleBox.ZIndex = 3
	Instance.new("UICorner", infJumpToggleBox).CornerRadius = UDim.new(0, 9)
	infJumpToggleBox.Parent = infJumpToggleGroup

	local infJumpIndicator = Instance.new("Frame")
	infJumpIndicator.Size = UDim2.new(0, 12, 0, 12)
	infJumpIndicator.Position = UDim2.new(0, 3, 0, 3)
	infJumpIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	infJumpIndicator.BorderSizePixel = 0
	infJumpIndicator.ZIndex = 4
	Instance.new("UICorner", infJumpIndicator).CornerRadius = UDim.new(0, 6)
	infJumpIndicator.Parent = infJumpToggleBox

	local infJumpToggleButton = Instance.new("TextButton")
	infJumpToggleButton.Size = UDim2.new(1, 0, 1, 0)
	infJumpToggleButton.BackgroundTransparency = 1
	infJumpToggleButton.Text = ""
	infJumpToggleButton.ZIndex = 5
	infJumpToggleButton.Parent = infJumpToggleBox

	local mobileJumpButton = Instance.new("TextButton")
	mobileJumpButton.Size = UDim2.new(0, 80, 0, 80)
	mobileJumpButton.Position = UDim2.new(0.5, -40, 1, -110)
	mobileJumpButton.BackgroundColor3 = Color3.fromRGB(50, 100, 220)
	mobileJumpButton.BackgroundTransparency = 0.3
	mobileJumpButton.BorderSizePixel = 0
	mobileJumpButton.Text = "JUMP"
	mobileJumpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	mobileJumpButton.Font = Enum.Font.GothamBold
	mobileJumpButton.TextSize = 18
	mobileJumpButton.Visible = false
	mobileJumpButton.ZIndex = 10
	Instance.new("UICorner", mobileJumpButton).CornerRadius = UDim.new(1, 0)
	mobileJumpButton.Parent = screenGui

	local infJumpEnabled = false
	local function performJump()
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local root = char.HumanoidRootPart
			root.Velocity = Vector3.new(root.Velocity.X, 50, root.Velocity.Z)
		end
	end

	infJumpToggleButton.MouseButton1Click:Connect(function()
		infJumpEnabled = not infJumpEnabled
		infJumpToggleBox.BackgroundColor3 = infJumpEnabled and Color3.fromRGB(50, 100, 220) or Color3.fromRGB(60, 60, 80)
		infJumpIndicator.Position = infJumpEnabled and UDim2.new(1, -15, 0, 3) or UDim2.new(0, 3, 0, 3)
		mobileJumpButton.Visible = infJumpEnabled
	end)

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.Space and infJumpEnabled then performJump() end
	end)

	mobileJumpButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and infJumpEnabled then performJump() end
	end)

	-- TELEPORT TAB
	local gpsLabel = Instance.new("TextLabel")
	gpsLabel.Size = UDim2.new(0, 200, 0, 40)
	gpsLabel.Position = UDim2.new(0, 10, 1, -50)
	gpsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	gpsLabel.BackgroundTransparency = 0.5
	gpsLabel.BorderSizePixel = 0
	gpsLabel.Text = "GPS выкл"
	gpsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	gpsLabel.Font = Enum.Font.Gotham
	gpsLabel.TextSize = 14
	gpsLabel.Visible = false
	gpsLabel.ZIndex = 10
	gpsLabel.Parent = screenGui

	local gpsConnection

	local coordInputsFrame = Instance.new("Frame")
	coordInputsFrame.Size = UDim2.new(1, 0, 0, 90)
	coordInputsFrame.Position = UDim2.new(0, 0, 0, 60)
	coordInputsFrame.BackgroundTransparency = 1
	coordInputsFrame.ZIndex = 3
	coordInputsFrame.Parent = teleportTabContent

	local function makeCoordRow(labelText, y, placeholder)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0, 30, 0, 20)
		lbl.Position = UDim2.new(0, 0, 0, y)
		lbl.BackgroundTransparency = 1
		lbl.Text = labelText
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 12
		lbl.ZIndex = 3
		lbl.Parent = coordInputsFrame

		local inp = Instance.new("TextBox")
		inp.Size = UDim2.new(1, -40, 0, 20)
		inp.Position = UDim2.new(0, 35, 0, y)
		inp.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
		inp.BorderSizePixel = 0
		inp.PlaceholderText = placeholder
		inp.TextColor3 = Color3.fromRGB(255, 255, 255)
		inp.Font = Enum.Font.Gotham
		inp.TextSize = 12
		inp.ZIndex = 3
		Instance.new("UICorner", inp).CornerRadius = UDim.new(0, 4)
		inp.Parent = coordInputsFrame
		return inp
	end

	local xInput = makeCoordRow("X:", 0, "132")
	local yInput = makeCoordRow("Y:", 25, "533")
	local zInput = makeCoordRow("Z:", 50, "905")

	local teleportButton = Instance.new("TextButton")
	teleportButton.Size = UDim2.new(1, 0, 0, 30)
	teleportButton.Position = UDim2.new(0, 0, 0, 160)
	teleportButton.BackgroundColor3 = Color3.fromRGB(50, 100, 220)
	teleportButton.BorderSizePixel = 0
	teleportButton.Text = "Teleport"
	teleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	teleportButton.Font = Enum.Font.GothamBold
	teleportButton.TextSize = 14
	teleportButton.ZIndex = 3
	Instance.new("UICorner", teleportButton).CornerRadius = UDim.new(0, 4)
	teleportButton.Parent = teleportTabContent

	teleportButton.MouseButton1Click:Connect(function()
		local x, y, z = tonumber(xInput.Text), tonumber(yInput.Text), tonumber(zInput.Text)
		if x and y and z then
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				char:PivotTo(CFrame.new(x, y, z))
			end
		end
	end)

	local gpsToggleGroup = Instance.new("Frame")
	gpsToggleGroup.Size = UDim2.new(1, 0, 0, 34)
	gpsToggleGroup.BackgroundTransparency = 1
	gpsToggleGroup.ZIndex = 3
	gpsToggleGroup.Parent = teleportTabContent

	local gpsToggleLabel = Instance.new("TextLabel")
	gpsToggleLabel.Size = UDim2.new(1, -46, 0, 14)
	gpsToggleLabel.BackgroundTransparency = 1
	gpsToggleLabel.Text = "GPS"
	gpsToggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	gpsToggleLabel.Font = Enum.Font.GothamSemibold
	gpsToggleLabel.TextSize = 12
	gpsToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
	gpsToggleLabel.ZIndex = 3
	gpsToggleLabel.Parent = gpsToggleGroup

	local gpsToggleBox = Instance.new("Frame")
	gpsToggleBox.Size = UDim2.new(0, 32, 0, 18)
	gpsToggleBox.Position = UDim2.new(1, -38, 0, 7)
	gpsToggleBox.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	gpsToggleBox.BorderSizePixel = 0
	gpsToggleBox.ZIndex = 3
	Instance.new("UICorner", gpsToggleBox).CornerRadius = UDim.new(0, 9)
	gpsToggleBox.Parent = gpsToggleGroup

	local gpsIndicator = Instance.new("Frame")
	gpsIndicator.Size = UDim2.new(0, 12, 0, 12)
	gpsIndicator.Position = UDim2.new(0, 3, 0, 3)
	gpsIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	gpsIndicator.BorderSizePixel = 0
	gpsIndicator.ZIndex = 4
	Instance.new("UICorner", gpsIndicator).CornerRadius = UDim.new(0, 6)
	gpsIndicator.Parent = gpsToggleBox

	local gpsToggleButton = Instance.new("TextButton")
	gpsToggleButton.Size = UDim2.new(1, 0, 1, 0)
	gpsToggleButton.BackgroundTransparency = 1
	gpsToggleButton.Text = ""
	gpsToggleButton.ZIndex = 5
	gpsToggleButton.Parent = gpsToggleBox

	gpsToggleButton.MouseButton1Click:Connect(function()
		if gpsConnection then
			gpsConnection:Disconnect()
			gpsConnection = nil
			gpsToggleBox.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
			gpsIndicator.Position = UDim2.new(0, 3, 0, 3)
			gpsLabel.Visible = false
		else
			gpsToggleBox.BackgroundColor3 = Color3.fromRGB(50, 100, 220)
			gpsIndicator.Position = UDim2.new(1, -15, 0, 3)
			gpsLabel.Visible = true
			gpsConnection = RunService.Heartbeat:Connect(function()
				local char = player.Character
				if char and char:FindFirstChild("HumanoidRootPart") then
					local pos = char.HumanoidRootPart.Position
					gpsLabel.Text = string.format("X: %d  Y: %d  Z: %d", math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z))
				end
			end)
		end
	end)

	-- ================== TRANSPORT TAB ==================
	local transportTitle = Instance.new("TextLabel")
	transportTitle.Size = UDim2.new(1, 0, 0, 18)
	transportTitle.BackgroundTransparency = 1
	transportTitle.Text = "Транспорт"
	transportTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	transportTitle.Font = Enum.Font.GothamBold
	transportTitle.TextSize = 14
	transportTitle.TextXAlignment = Enum.TextXAlignment.Left
	transportTitle.ZIndex = 3
	transportTitle.Parent = transportTabContent

	local exitCarBtn2 = Instance.new("TextButton")
	exitCarBtn2.Size = UDim2.new(0, 78, 0, 22)
	exitCarBtn2.Position = UDim2.new(1, -78, 0, -2)
	exitCarBtn2.BackgroundColor3 = Color3.fromRGB(160, 50, 60)
	exitCarBtn2.BorderSizePixel = 0
	exitCarBtn2.Text = "Выйти (E)"
	exitCarBtn2.TextColor3 = Color3.fromRGB(255, 255, 255)
	exitCarBtn2.Font = Enum.Font.GothamBold
	exitCarBtn2.TextSize = 10
	exitCarBtn2.ZIndex = 4
	Instance.new("UICorner", exitCarBtn2).CornerRadius = UDim.new(0, 6)
	exitCarBtn2.Parent = transportTabContent

	exitCarBtn2.MouseButton1Click:Connect(function()
		if driving then exitCar() end
	end)

	-- Векторные иконки
	local function drawCarIcon(parent, color)
		local f = Instance.new("Frame")
		f.Size = UDim2.new(1, -20, 0, 20)
		f.Position = UDim2.new(0, 10, 0.5, -10)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.ZIndex = 5
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 3)
		f.Parent = parent

		local cabin = Instance.new("Frame")
		cabin.Size = UDim2.new(0.55, 0, 0.5, 0)
		cabin.Position = UDim2.new(0.2, 0, -0.45, 0)
		cabin.BackgroundColor3 = color
		cabin.BorderSizePixel = 0
		cabin.ZIndex = 5
		Instance.new("UICorner", cabin).CornerRadius = UDim.new(0, 2)
		cabin.Parent = f
	end

	local function drawGelikIcon(parent, color)
		local f = Instance.new("Frame")
		f.Size = UDim2.new(1, -20, 0, 22)
		f.Position = UDim2.new(0, 10, 0.5, -11)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.ZIndex = 5
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 2)
		f.Parent = parent

		local cabin = Instance.new("Frame")
		cabin.Size = UDim2.new(0.7, 0, 0.6, 0)
		cabin.Position = UDim2.new(0.15, 0, -0.55, 0)
		cabin.BackgroundColor3 = color
		cabin.BorderSizePixel = 0
		cabin.ZIndex = 5
		Instance.new("UICorner", cabin).CornerRadius = UDim.new(0, 2)
		cabin.Parent = f
	end

	local function drawTruckIcon(parent, color)
		local f = Instance.new("Frame")
		f.Size = UDim2.new(1, -20, 0, 18)
		f.Position = UDim2.new(0, 10, 0.5, -6)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.ZIndex = 5
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 2)
		f.Parent = parent

		local cabin = Instance.new("Frame")
		cabin.Size = UDim2.new(0.28, 0, 0.7, 0)
		cabin.Position = UDim2.new(0, 0, -0.65, 0)
		cabin.BackgroundColor3 = color
		cabin.BorderSizePixel = 0
		cabin.ZIndex = 5
		Instance.new("UICorner", cabin).CornerRadius = UDim.new(0, 2)
		cabin.Parent = f
	end

	local function drawTankIcon(parent, color)
		local base = Instance.new("Frame")
		base.Size = UDim2.new(1, -20, 0, 14)
		base.Position = UDim2.new(0, 10, 0.5, -2)
		base.BackgroundColor3 = color
		base.BorderSizePixel = 0
		base.ZIndex = 5
		Instance.new("UICorner", base).CornerRadius = UDim.new(0, 2)
		base.Parent = parent

		local turret = Instance.new("Frame")
		turret.Size = UDim2.new(0.45, 0, 0.45, 0)
		turret.Position = UDim2.new(0.2, 0, -0.55, 0)
		turret.BackgroundColor3 = color
		turret.BorderSizePixel = 0
		turret.ZIndex = 5
		Instance.new("UICorner", turret).CornerRadius = UDim.new(0, 2)
		turret.Parent = base

		local barrel = Instance.new("Frame")
		barrel.Size = UDim2.new(0.55, 0, 0.25, 0)
		barrel.Position = UDim2.new(1, 0, 0.35, 0)
		barrel.BackgroundColor3 = color
		barrel.BorderSizePixel = 0
		barrel.ZIndex = 6
		Instance.new("UICorner", barrel).CornerRadius = UDim.new(0, 1)
		barrel.Parent = turret
	end

	local function drawHeliIcon(parent, color)
		local body = Instance.new("Frame")
		body.Size = UDim2.new(0.7, 0, 0, 18)
		body.Position = UDim2.new(0.15, 0, 0.5, -4)
		body.BackgroundColor3 = color
		body.BorderSizePixel = 0
		body.ZIndex = 5
		Instance.new("UICorner", body).CornerRadius = UDim.new(0, 4)
		body.Parent = parent

		local tail = Instance.new("Frame")
		tail.Size = UDim2.new(0.3, 0, 0, 4)
		tail.Position = UDim2.new(0.7, 0, 0.5, 0)
		tail.BackgroundColor3 = color
		tail.BorderSizePixel = 0
		tail.ZIndex = 5
		Instance.new("UICorner", tail).CornerRadius = UDim.new(0, 1)
		tail.Parent = parent

		local rotor = Instance.new("Frame")
		rotor.Size = UDim2.new(0.85, 0, 0, 2)
		rotor.Position = UDim2.new(0.075, 0, 0.5, -16)
		rotor.BackgroundColor3 = color
		rotor.BorderSizePixel = 0
		rotor.ZIndex = 5
		Instance.new("UICorner", rotor).CornerRadius = UDim.new(1, 0)
		rotor.Parent = parent

		local pole = Instance.new("Frame")
		pole.Size = UDim2.new(0, 2, 0, 8)
		pole.Position = UDim2.new(0.5, -1, 0.5, -10)
		pole.BackgroundColor3 = color
		pole.BorderSizePixel = 0
		pole.ZIndex = 5
		pole.Parent = parent
	end

	local function drawPlaneIcon(parent, color)
		local body = Instance.new("Frame")
		body.Size = UDim2.new(0.7, 0, 0, 8)
		body.Position = UDim2.new(0.15, 0, 0.5, -4)
		body.BackgroundColor3 = color
		body.BorderSizePixel = 0
		body.ZIndex = 5
		Instance.new("UICorner", body).CornerRadius = UDim.new(1, 0)
		body.Parent = parent

		local wing = Instance.new("Frame")
		wing.Size = UDim2.new(0.9, 0, 0, 4)
		wing.Position = UDim2.new(0.05, 0, 0.5, 1)
		wing.BackgroundColor3 = color
		wing.BorderSizePixel = 0
		wing.ZIndex = 5
		Instance.new("UICorner", wing).CornerRadius = UDim.new(0, 1)
		wing.Parent = parent

		local tailWing = Instance.new("Frame")
		tailWing.Size = UDim2.new(0, 2, 0, 12)
		tailWing.Position = UDim2.new(0.78, 0, 0.5, -6)
		tailWing.BackgroundColor3 = color
		tailWing.BorderSizePixel = 0
		tailWing.ZIndex = 5
		tailWing.Parent = parent
	end

	local VEHICLE_LIST = {
		{key="car",        label="Car",   desc="Быстрая легковушка", grad1=Color3.fromRGB(220, 70, 80),  grad2=Color3.fromRGB(140, 30, 40),   canFly=false, draw=drawCarIcon},
		{key="gelik",      label="Gelik", desc="Чёрный внедорожник", grad1=Color3.fromRGB(60, 65, 80),   grad2=Color3.fromRGB(20, 22, 30),    canFly=false, draw=drawGelikIcon},
		{key="truck",      label="Truck", desc="Тяжёлый грузовик",   grad1=Color3.fromRGB(90, 140, 220), grad2=Color3.fromRGB(40, 70, 160),   canFly=false, draw=drawTruckIcon},
		{key="tank",       label="Tank",  desc="Бронированный танк", grad1=Color3.fromRGB(120, 160, 100),grad2=Color3.fromRGB(60, 90, 50),    canFly=false, draw=drawTankIcon},
		{key="helicopter", label="Heli",  desc="Вертолёт (летает)",  grad1=Color3.fromRGB(100, 170, 240),grad2=Color3.fromRGB(40, 90, 180),   canFly=true,  draw=drawHeliIcon},
		{key="plane",      label="Plane", desc="Самолёт (летает)",   grad1=Color3.fromRGB(230, 230, 240),grad2=Color3.fromRGB(150, 160, 190), canFly=true,  draw=drawPlaneIcon},
	}

	local cards = {}

	-- Forward declare locals that updateInfoPanel will use
	local infoAccent, infoName, infoDesc, infoTag
	local selectedInfo

	local function updateCardStyles()
		for key, data in pairs(cards) do
			local isSelected = (key == selectedVehicleType)
			TweenService:Create(data.outerStroke, TweenInfo.new(0.2), {
				Color = isSelected and data.v.grad1 or Color3.fromRGB(45, 60, 100),
				Thickness = isSelected and 2 or 1,
				Transparency = isSelected and 0 or 0.55,
			}):Play()
			TweenService:Create(data.checkBg, TweenInfo.new(0.2), {
				BackgroundTransparency = isSelected and 0 or 1,
			}):Play()
			TweenService:Create(data.checkMark, TweenInfo.new(0.2), {
				TextTransparency = isSelected and 0 or 1,
			}):Play()
			TweenService:Create(data.nameLabel, TweenInfo.new(0.2), {
				TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 175, 220),
			}):Play()
			TweenService:Create(data.iconFrame, TweenInfo.new(0.2), {
				BackgroundTransparency = isSelected and 0.7 or 0.9,
			}):Play()
		end
	end

	local function updateInfoPanel()
		for _, v in ipairs(VEHICLE_LIST) do
			if v.key == selectedVehicleType then
				selectedInfo = v
				break
			end
		end
		if not selectedInfo or not infoAccent then return end

		TweenService:Create(infoAccent, TweenInfo.new(0.25), {
			BackgroundColor3 = selectedInfo.grad1,
		}):Play()

		infoName.Text = selectedInfo.label
		infoDesc.Text = selectedInfo.desc
		if selectedInfo.canFly then
			infoTag.Text = "ЛЕТАЕТ"
			infoTag.BackgroundColor3 = Color3.fromRGB(70, 190, 120)
		else
			infoTag.Text = "НАЗЕМНЫЙ"
			infoTag.BackgroundColor3 = Color3.fromRGB(70, 120, 200)
		end
	end

	local gridFrame = Instance.new("Frame")
	gridFrame.Size = UDim2.new(1, 0, 0, 160)
	gridFrame.Position = UDim2.new(0, 0, 0, 24)
	gridFrame.BackgroundTransparency = 1
	gridFrame.ZIndex = 3
	gridFrame.Parent = transportTabContent

	local CARD_W = 79
	local CARD_H = 76
	local GAP = 4

	for i, v in ipairs(VEHICLE_LIST) do
		local col = (i - 1) % 2
		local row = math.floor((i - 1) / 2)

		local card = Instance.new("TextButton")
		card.Size = UDim2.new(0, CARD_W, 0, CARD_H)
		card.Position = UDim2.new(0, col * (CARD_W + GAP), 0, row * (CARD_H + GAP))
		card.BackgroundColor3 = Color3.fromRGB(20, 28, 50)
		card.BorderSizePixel = 0
		card.Text = ""
		card.AutoButtonColor = false
		card.ZIndex = 3
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
		card.Parent = gridFrame

		local cardGrad = Instance.new("UIGradient")
		cardGrad.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, v.grad1),
			ColorSequenceKeypoint.new(1, v.grad2),
		}
		cardGrad.Rotation = 135
		cardGrad.Transparency = NumberSequence.new{
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 0.88),
		}
		cardGrad.Parent = card

		local outerStroke = Instance.new("UIStroke")
		outerStroke.Color = Color3.fromRGB(45, 60, 100)
		outerStroke.Thickness = 1
		outerStroke.Transparency = 0.55
		outerStroke.Parent = card

		local iconFrame = Instance.new("Frame")
		iconFrame.Size = UDim2.new(1, -12, 0, 40)
		iconFrame.Position = UDim2.new(0, 6, 0, 4)
		iconFrame.BackgroundColor3 = Color3.fromRGB(10, 15, 30)
		iconFrame.BackgroundTransparency = 0.9
		iconFrame.BorderSizePixel = 0
		iconFrame.ZIndex = 4
		Instance.new("UICorner", iconFrame).CornerRadius = UDim.new(0, 6)
		iconFrame.Parent = card

		v.draw(iconFrame, Color3.fromRGB(230, 240, 255))

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0, 18)
		nameLabel.Position = UDim2.new(0, 0, 1, -22)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = v.label
		nameLabel.TextColor3 = Color3.fromRGB(150, 175, 220)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 11
		nameLabel.ZIndex = 5
		nameLabel.Parent = card

		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 6, 0, 6)
		dot.Position = UDim2.new(1, -11, 0, 5)
		dot.BackgroundColor3 = v.canFly and Color3.fromRGB(90, 230, 140) or Color3.fromRGB(90, 140, 220)
		dot.BorderSizePixel = 0
		dot.ZIndex = 6
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
		dot.Parent = card

		local checkBg = Instance.new("Frame")
		checkBg.Size = UDim2.new(0, 18, 0, 18)
		checkBg.Position = UDim2.new(0, 4, 0, 4)
		checkBg.BackgroundColor3 = v.grad1
		checkBg.BackgroundTransparency = 1
		checkBg.BorderSizePixel = 0
		checkBg.ZIndex = 7
		Instance.new("UICorner", checkBg).CornerRadius = UDim.new(1, 0)
		checkBg.Parent = card

		local checkMark = Instance.new("TextLabel")
		checkMark.Size = UDim2.new(1, 0, 1, 0)
		checkMark.BackgroundTransparency = 1
		checkMark.Text = "✓"
		checkMark.TextColor3 = Color3.fromRGB(255, 255, 255)
		checkMark.Font = Enum.Font.GothamBold
		checkMark.TextSize = 12
		checkMark.TextTransparency = 1
		checkMark.ZIndex = 8
		checkMark.Parent = checkBg

		cards[v.key] = {
			frame = card,
			outerStroke = outerStroke,
			nameLabel = nameLabel,
			iconFrame = iconFrame,
			checkBg = checkBg,
			checkMark = checkMark,
			v = v,
		}

		card.MouseEnter:Connect(function()
			if selectedVehicleType ~= v.key then
				TweenService:Create(card, TweenInfo.new(0.15), {
					BackgroundColor3 = Color3.fromRGB(30, 42, 72),
				}):Play()
			end
		end)
		card.MouseLeave:Connect(function()
			if selectedVehicleType ~= v.key then
				TweenService:Create(card, TweenInfo.new(0.15), {
					BackgroundColor3 = Color3.fromRGB(20, 28, 50),
				}):Play()
			end
		end)

		card.MouseButton1Click:Connect(function()
			selectedVehicleType = v.key
			updateCardStyles()
			updateInfoPanel()

			local pulse = Instance.new("Frame")
			pulse.Size = UDim2.new(1, 0, 1, 0)
			pulse.BackgroundColor3 = v.grad1
			pulse.BackgroundTransparency = 0.7
			pulse.BorderSizePixel = 0
			pulse.ZIndex = 20
			Instance.new("UICorner", pulse).CornerRadius = UDim.new(0, 10)
			pulse.Parent = card
			TweenService:Create(pulse, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 12, 1, 12),
				Position = UDim2.new(0, -6, 0, -6),
			}):Play()
			task.delay(0.45, function() pulse:Destroy() end)
		end)
	end

	-- Инфо-панель
	local infoPanel = Instance.new("Frame")
	infoPanel.Size = UDim2.new(1, 0, 0, 56)
	infoPanel.Position = UDim2.new(0, 0, 0, 190)
	infoPanel.BackgroundColor3 = Color3.fromRGB(16, 22, 44)
	infoPanel.BorderSizePixel = 0
	infoPanel.ZIndex = 3
	Instance.new("UICorner", infoPanel).CornerRadius = UDim.new(0, 10)
	infoPanel.Parent = transportTabContent

	local infoStroke = Instance.new("UIStroke")
	infoStroke.Color = Color3.fromRGB(45, 70, 130)
	infoStroke.Thickness = 1
	infoStroke.Transparency = 0.5
	infoStroke.Parent = infoPanel

	infoAccent = Instance.new("Frame")
	infoAccent.Size = UDim2.new(0, 4, 1, -12)
	infoAccent.Position = UDim2.new(0, 6, 0, 6)
	infoAccent.BackgroundColor3 = Color3.fromRGB(220, 70, 80)
	infoAccent.BorderSizePixel = 0
	infoAccent.ZIndex = 4
	Instance.new("UICorner", infoAccent).CornerRadius = UDim.new(0, 2)
	infoAccent.Parent = infoPanel

	infoName = Instance.new("TextLabel")
	infoName.Size = UDim2.new(1, -90, 0, 18)
	infoName.Position = UDim2.new(0, 18, 0, 10)
	infoName.BackgroundTransparency = 1
	infoName.Text = "Car"
	infoName.TextColor3 = Color3.fromRGB(255, 255, 255)
	infoName.Font = Enum.Font.GothamBold
	infoName.TextSize = 14
	infoName.TextXAlignment = Enum.TextXAlignment.Left
	infoName.ZIndex = 4
	infoName.Parent = infoPanel

	infoDesc = Instance.new("TextLabel")
	infoDesc.Size = UDim2.new(1, -90, 0, 14)
	infoDesc.Position = UDim2.new(0, 18, 0, 30)
	infoDesc.BackgroundTransparency = 1
	infoDesc.Text = "Быстрая легковушка"
	infoDesc.TextColor3 = Color3.fromRGB(140, 165, 210)
	infoDesc.Font = Enum.Font.Gotham
	infoDesc.TextSize = 10
	infoDesc.TextXAlignment = Enum.TextXAlignment.Left
	infoDesc.ZIndex = 4
	infoDesc.Parent = infoPanel

	infoTag = Instance.new("TextLabel")
	infoTag.Size = UDim2.new(0, 62, 0, 16)
	infoTag.Position = UDim2.new(1, -68, 0, 8)
	infoTag.BackgroundColor3 = Color3.fromRGB(70, 120, 200)
	infoTag.BorderSizePixel = 0
	infoTag.Text = "НАЗЕМНЫЙ"
	infoTag.TextColor3 = Color3.fromRGB(255, 255, 255)
	infoTag.Font = Enum.Font.GothamBold
	infoTag.TextSize = 8
	infoTag.ZIndex = 4
	Instance.new("UICorner", infoTag).CornerRadius = UDim.new(0, 4)
	infoTag.Parent = infoPanel

	-- Кнопка спавна
	local spawnCustomCarBtn = Instance.new("TextButton")
	spawnCustomCarBtn.Size = UDim2.new(1, 0, 0, 42)
	spawnCustomCarBtn.Position = UDim2.new(0, 0, 0, 254)
	spawnCustomCarBtn.BackgroundColor3 = Color3.fromRGB(45, 100, 220)
	spawnCustomCarBtn.BorderSizePixel = 0
	spawnCustomCarBtn.Text = "ЗАСПАВНИТЬ"
	spawnCustomCarBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	spawnCustomCarBtn.Font = Enum.Font.GothamBold
	spawnCustomCarBtn.TextSize = 14
	spawnCustomCarBtn.AutoButtonColor = false
	spawnCustomCarBtn.ZIndex = 3
	Instance.new("UICorner", spawnCustomCarBtn).CornerRadius = UDim.new(0, 10)
	spawnCustomCarBtn.Parent = transportTabContent

	local btnGradient = Instance.new("UIGradient")
	btnGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 140, 250)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 80, 200)),
	}
	btnGradient.Rotation = 90
	btnGradient.Parent = spawnCustomCarBtn

	local spawnStroke = Instance.new("UIStroke")
	spawnStroke.Color = Color3.fromRGB(140, 190, 255)
	spawnStroke.Thickness = 1
	spawnStroke.Transparency = 0.55
	spawnStroke.Parent = spawnCustomCarBtn

	spawnCustomCarBtn.MouseEnter:Connect(function()
		TweenService:Create(spawnStroke, TweenInfo.new(0.15), {
			Transparency = 0.15,
			Thickness = 2,
		}):Play()
	end)
	spawnCustomCarBtn.MouseLeave:Connect(function()
		TweenService:Create(spawnStroke, TweenInfo.new(0.15), {
			Transparency = 0.55,
			Thickness = 1,
		}):Play()
	end)

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, 0, 0, 60)
	statusLabel.Position = UDim2.new(0, 0, 0, 300)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "W/S — газ/назад    A/D — поворот\nSpace/Shift — вверх/вниз (для летающих)\nE — выйти"
	statusLabel.TextColor3 = Color3.fromRGB(130, 155, 200)
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 9
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusLabel.TextWrapped = true
	statusLabel.ZIndex = 3
	statusLabel.Parent = transportTabContent

	updateCardStyles()
	updateInfoPanel()

	spawnCustomCarBtn.MouseButton1Click:Connect(function()
		if driving then
			statusLabel.Text = "Уже за рулём. Нажми E чтобы выйти."
			statusLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
			return
		end

		statusLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
		statusLabel.Text = "Создаём " .. (selectedInfo and selectedInfo.label or "транспорт") .. "..."

		local ok, car, seat, canFly, rotors = pcall(buildVehicle, selectedVehicleType)
		if not ok then
			statusLabel.Text = "Ошибка: " .. tostring(car)
			statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
			warn("[Vehicle] " .. tostring(car))
			return
		end
		if not car then
			statusLabel.Text = tostring(seat or "неизвестная ошибка")
			statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
			return
		end

		local entered = enterCar(car, seat, canFly, rotors)
		if entered then
			statusLabel.Text = (selectedInfo and selectedInfo.label or "Транспорт") .. " готов!\nW/S — газ, A/D — руль" .. (canFly and "\nSpace/Shift — вверх/вниз" or "") .. "\nE — выйти"
			statusLabel.TextColor3 = Color3.fromRGB(120, 255, 140)
		else
			statusLabel.Text = "Транспорт создан, но сесть не удалось."
			statusLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
		end
	end)

	-- ПЕРЕКЛЮЧЕНИЕ ВКЛАДОК
	local currentTab = "Main"
	local tabColors = { Main = mainTab, soon = soonTab, Teleport = teleportTab, Transport = transportTab }
	local tabContents = { Main = mainTabContent, soon = soonTabContent, Teleport = teleportTabContent, Transport = transportTabContent }

	local function showTab(tabName)
		currentTab = tabName
		for _, btn in pairs(tabColors) do btn.BackgroundColor3 = Color3.fromRGB(60, 90, 170) end
		for _, c in pairs(tabContents) do c.Visible = false end
		tabColors[tabName].BackgroundColor3 = Color3.fromRGB(50, 100, 220)
		tabContents[tabName].Visible = true
	end

	mainTab.MouseButton1Click:Connect(function() showTab("Main") end)
	soonTab.MouseButton1Click:Connect(function() showTab("soon") end)
	teleportTab.MouseButton1Click:Connect(function() showTab("Teleport") end)
	transportTab.MouseButton1Click:Connect(function() showTab("Transport") end)

	-- СОСТОЯНИЕ
	local currentSpeed = 16
	local currentJump = 50
	local flyEnabled = false
	local flySpeed = 50
	local bodyVelocity, bodyGyro, flyConnection
	local btnForward, btnBackward, btnUp, btnDown
	local forwardPressed, backwardPressed, upPressed, downPressed = false, false, false, false
	local noclipEnabled = false

	-- ФАБРИКИ
	local function createSlider(name, desc, minVal, maxVal, defaultVal, positionY, parent)
		local group = Instance.new("Frame")
		group.Size = UDim2.new(1, 0, 0, 40)
		group.Position = UDim2.new(0, 0, 0, positionY)
		group.BackgroundTransparency = 1
		group.ZIndex = 3
		group.Parent = parent

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0, 14)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = name
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.Font = Enum.Font.GothamSemibold
		nameLabel.TextSize = 12
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.ZIndex = 3
		nameLabel.Parent = group

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, 0, 0, 11)
		descLabel.Position = UDim2.new(0, 0, 0, 14)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = desc
		descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextSize = 9
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.ZIndex = 3
		descLabel.Parent = group

		local track = Instance.new("Frame")
		track.Size = UDim2.new(1, -44, 0, 6)
		track.Position = UDim2.new(0, 0, 0, 28)
		track.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
		track.BorderSizePixel = 0
		track.ZIndex = 3
		Instance.new("UICorner", track).CornerRadius = UDim.new(0, 3)
		track.Parent = group

		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = Color3.fromRGB(50, 100, 220)
		fill.BorderSizePixel = 0
		fill.ZIndex = 4
		Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)
		fill.Parent = track

		local thumb = Instance.new("Frame")
		thumb.Size = UDim2.new(0, 12, 0, 12)
		thumb.AnchorPoint = Vector2.new(0.5, 0.5)
		thumb.Position = UDim2.new(0, 0, 0.5, 0)
		thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		thumb.BorderSizePixel = 0
		thumb.ZIndex = 5
		Instance.new("UICorner", thumb).CornerRadius = UDim.new(0, 6)
		thumb.Parent = track

		local sliderButton = Instance.new("TextButton")
		sliderButton.Size = UDim2.new(1, 0, 1, 0)
		sliderButton.BackgroundTransparency = 1
		sliderButton.Text = ""
		sliderButton.ZIndex = 6
		sliderButton.Parent = track

		local valueLabel = Instance.new("TextLabel")
		valueLabel.Size = UDim2.new(0, 38, 0, 14)
		valueLabel.Position = UDim2.new(1, -38, 0, 28)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Text = tostring(defaultVal)
		valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		valueLabel.Font = Enum.Font.GothamBold
		valueLabel.TextSize = 11
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.ZIndex = 3
		valueLabel.Parent = group

		local currentValue = defaultVal
		local dragCallback = nil
		local sliderDragging = false

		local function updateVisual()
			local fraction = (currentValue - minVal) / (maxVal - minVal)
			fill.Size = UDim2.new(fraction, 0, 1, 0)
			thumb.Position = UDim2.new(fraction, 0, 0.5, 0)
			valueLabel.Text = tostring(currentValue)
		end
		updateVisual()

		local function computeValue(inputX)
			local trackWidth = track.AbsoluteSize.X
			if trackWidth <= 0 then return end
			local relX = inputX - track.AbsolutePosition.X
			local fraction = math.clamp(relX / trackWidth, 0, 1)
			currentValue = math.clamp(math.floor(minVal + fraction * (maxVal - minVal) + 0.5), minVal, maxVal)
			updateVisual()
			if dragCallback then dragCallback(currentValue) end
		end

		sliderButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				sliderDragging = true
				computeValue(input.Position.X)
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if sliderDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				computeValue(input.Position.X)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				sliderDragging = false
			end
		end)

		return {
			GetValue = function() return currentValue end,
			SetValue = function(val) currentValue = val; updateVisual() end,
			OnDrag = function(cb) dragCallback = cb end
		}
	end

	local function createToggle(name, desc, positionY, parent)
		local group = Instance.new("Frame")
		group.Size = UDim2.new(1, 0, 0, 34)
		group.Position = UDim2.new(0, 0, 0, positionY)
		group.BackgroundTransparency = 1
		group.ZIndex = 3
		group.Parent = parent

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -46, 0, 14)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = name
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.Font = Enum.Font.GothamSemibold
		nameLabel.TextSize = 12
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.ZIndex = 3
		nameLabel.Parent = group

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -46, 0, 11)
		descLabel.Position = UDim2.new(0, 0, 0, 14)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = desc
		descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextSize = 9
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.ZIndex = 3
		descLabel.Parent = group

		local toggleBox = Instance.new("Frame")
		toggleBox.Size = UDim2.new(0, 32, 0, 18)
		toggleBox.Position = UDim2.new(1, -38, 0, 7)
		toggleBox.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		toggleBox.BorderSizePixel = 0
		toggleBox.ZIndex = 3
		Instance.new("UICorner", toggleBox).CornerRadius = UDim.new(0, 9)
		toggleBox.Parent = group

		local indicator = Instance.new("Frame")
		indicator.Size = UDim2.new(0, 12, 0, 12)
		indicator.Position = UDim2.new(0, 3, 0, 3)
		indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		indicator.BorderSizePixel = 0
		indicator.ZIndex = 4
		Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 6)
		indicator.Parent = toggleBox

		local toggleButton = Instance.new("TextButton")
		toggleButton.Size = UDim2.new(1, 0, 1, 0)
		toggleButton.BackgroundTransparency = 1
		toggleButton.Text = ""
		toggleButton.ZIndex = 5
		toggleButton.Parent = toggleBox

		local enabled = false
		local toggleCallback = nil

		local function updateVisual()
			toggleBox.BackgroundColor3 = enabled and Color3.fromRGB(50, 100, 220) or Color3.fromRGB(60, 60, 80)
			indicator.Position = enabled and UDim2.new(1, -15, 0, 3) or UDim2.new(0, 3, 0, 3)
		end
		updateVisual()

		toggleButton.MouseButton1Click:Connect(function()
			enabled = not enabled
			updateVisual()
			if toggleCallback then toggleCallback(enabled) end
		end)

		return {
			Group = group,
			IsEnabled = function() return enabled end,
			SetEnabled = function(val) enabled = val; updateVisual() end,
			OnToggle = function(cb) toggleCallback = cb end
		}
	end

	-- MAIN TAB
	local speedSlider = createSlider("Speed Changer", "Скорость бега (16-300)", 16, 300, 16, 0, scrollingFrame)
	speedSlider.OnDrag(function(val)
		currentSpeed = val
		local char = player.Character
		if char and char:FindFirstChild("Humanoid") then char.Humanoid.WalkSpeed = val end
		if flyToggle.IsEnabled() then flyToggle.SetEnabled(false) stopFly() end
	end)

	local jumpSlider = createSlider("Jump Power", "Высота прыжка (1-999)", 1, 999, 50, 40, scrollingFrame)
	jumpSlider.OnDrag(function(val)
		currentJump = val
		local char = player.Character
		if char and char:FindFirstChild("Humanoid") then
			char.Humanoid.UseJumpPower = true
			char.Humanoid.JumpPower = val
		end
	end)

	local flyGroup = Instance.new("Frame")
	flyGroup.Size = UDim2.new(1, 0, 0, 74)
	flyGroup.Position = UDim2.new(0, 0, 0, 80)
	flyGroup.BackgroundTransparency = 1
	flyGroup.ZIndex = 3
	flyGroup.Parent = scrollingFrame

	local flyToggle = createToggle("Fly", "WASD/Space/Shift или кнопки", 0, flyGroup)
	local flySpeedSlider = createSlider("Fly Speed", "Скорость (0-9999)", 0, 9999, 50, 34, flyGroup)

	flyToggle.OnToggle(function(on)
		flyEnabled = on
		if on then startFly() else stopFly() end
	end)
	flySpeedSlider.OnDrag(function(val) flySpeed = val end)

	local noclipToggle = createToggle("Noclip", "Прохождение сквозь стены", 154, scrollingFrame)
	noclipToggle.OnToggle(function(on)
		noclipEnabled = on
		local char = player.Character
		if char then
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = not on end
			end
		end
		if on and not flyToggle.IsEnabled() then
			flyToggle.SetEnabled(true)
			startFly()
		end
	end)

	-- ESP
	local espSettings = {
		color = Color3.fromRGB(50, 100, 220),
		showTracer = false,
		showSkeleton = false,
		showHealth = true,
	}

	local espFrames = {}
	local espConnection
	local espPlayerAddedConn
	local espPlayerRemovingConn

	local R15_BONES = {
		{"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
		{"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
		{"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
		{"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
		{"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
	}
	local R6_BONES = {
		{"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
		{"Torso", "Left Leg"}, {"Torso", "Right Leg"},
	}
	local MAX_SKELETON_LINES = #R15_BONES

	local function setLine(line, p1, p2, color)
		local delta = p2 - p1
		local len = delta.Magnitude
		if len < 2 then line.Visible = false; return end
		line.Size = UDim2.new(0, len, 0, 1)
		line.Position = UDim2.new(0, p1.X, 0, p1.Y)
		line.BackgroundColor3 = color
		line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		line.Visible = true
	end

	local function createESPFrame(targetPlayer)
		if espFrames[targetPlayer] then return end

		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.ZIndex = 15
		frame.Parent = screenGui

		local stroke = Instance.new("UIStroke")
		stroke.Color = espSettings.color
		stroke.Thickness = 2
		stroke.Parent = frame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0, 20)
		nameLabel.Position = UDim2.new(0, 0, -1, -20)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = targetPlayer.Name
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.TextStrokeTransparency = 0
		nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		nameLabel.ZIndex = 16
		nameLabel.Parent = frame

		local healthBarBg = Instance.new("Frame")
		healthBarBg.Size = UDim2.new(0, 4, 1, 0)
		healthBarBg.Position = UDim2.new(0, -8, 0, 0)
		healthBarBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		healthBarBg.BorderSizePixel = 0
		healthBarBg.Visible = false
		healthBarBg.ZIndex = 15
		Instance.new("UICorner", healthBarBg).CornerRadius = UDim.new(0, 2)
		healthBarBg.Parent = frame

		local healthBarFill = Instance.new("Frame")
		healthBarFill.Size = UDim2.new(1, 0, 1, 0)
		healthBarFill.Position = UDim2.new(0, 0, 1, 0)
		healthBarFill.AnchorPoint = Vector2.new(0, 1)
		healthBarFill.BackgroundColor3 = Color3.fromRGB(50, 220, 80)
		healthBarFill.BorderSizePixel = 0
		healthBarFill.ZIndex = 16
		Instance.new("UICorner", healthBarFill).CornerRadius = UDim.new(0, 2)
		healthBarFill.Parent = healthBarBg

		local healthText = Instance.new("TextLabel")
		healthText.Size = UDim2.new(0, 30, 0, 12)
		healthText.Position = UDim2.new(0, -34, 1, 0)
		healthText.AnchorPoint = Vector2.new(0, 1)
		healthText.BackgroundTransparency = 1
		healthText.Text = "100"
		healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
		healthText.Font = Enum.Font.GothamBold
		healthText.TextSize = 10
		healthText.TextStrokeTransparency = 0
		healthText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		healthText.TextXAlignment = Enum.TextXAlignment.Right
		healthText.Visible = false
		healthText.ZIndex = 16
		healthText.Parent = frame

		local tracer = Instance.new("Frame")
		tracer.BackgroundColor3 = espSettings.color
		tracer.BorderSizePixel = 0
		tracer.Visible = false
		tracer.AnchorPoint = Vector2.new(0, 0.5)
		tracer.ZIndex = 14
		tracer.Parent = screenGui

		local skeletonLines = {}
		for i = 1, MAX_SKELETON_LINES do
			local line = Instance.new("Frame")
			line.BackgroundColor3 = espSettings.color
			line.BorderSizePixel = 0
			line.Visible = false
			line.AnchorPoint = Vector2.new(0, 0.5)
			line.ZIndex = 14
			line.Parent = screenGui
			skeletonLines[i] = line
		end

		espFrames[targetPlayer] = {
			frame = frame, stroke = stroke, nameLabel = nameLabel,
			healthBarBg = healthBarBg, healthBarFill = healthBarFill, healthText = healthText,
			tracer = tracer, skeletonLines = skeletonLines,
		}
	end

	local function removeESPFrame(targetPlayer)
		local data = espFrames[targetPlayer]
		if data then
			data.frame:Destroy()
			data.tracer:Destroy()
			for _, l in ipairs(data.skeletonLines) do l:Destroy() end
			espFrames[targetPlayer] = nil
		end
	end

	local function updateESPFrame(targetPlayer)
		local data = espFrames[targetPlayer]
		if not data then return end

		local character = targetPlayer.Character
		if not character then
			data.frame.Visible = false; data.tracer.Visible = false
			for _, l in ipairs(data.skeletonLines) do l.Visible = false end
			return
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		local head = character:FindFirstChild("Head")
		local humanoid = character:FindFirstChild("Humanoid")
		if not (rootPart and head and humanoid and humanoid.Health > 0) then
			data.frame.Visible = false; data.tracer.Visible = false
			for _, l in ipairs(data.skeletonLines) do l.Visible = false end
			return
		end

		local screenPosRoot, onScreenRoot = Camera:WorldToViewportPoint(rootPart.Position)
		local screenPosHead, onScreenHead = Camera:WorldToViewportPoint(head.Position)
		if not (onScreenRoot and onScreenHead and screenPosRoot.Z > 0 and screenPosHead.Z > 0) then
			data.frame.Visible = false; data.tracer.Visible = false
			for _, l in ipairs(data.skeletonLines) do l.Visible = false end
			return
		end

		local distance = (Camera.CFrame.Position - rootPart.Position).Magnitude
		local naturalHeight = math.abs(screenPosRoot.Y - screenPosHead.Y)
		local padding = math.clamp(10 + distance * 0.02, 10, 25)
		local minHeight = math.clamp(50 + distance * 0.10, 50, 110)
		local height = math.max(naturalHeight + padding * 2, minHeight)
		local width = math.max(height * 0.5, 32)

		local centerX = (screenPosHead.X + screenPosRoot.X) / 2
		local centerY = (screenPosHead.Y + screenPosRoot.Y) / 2
		local topY = centerY - height / 2

		data.frame.Position = UDim2.new(0, centerX - width/2, 0, topY)
		data.frame.Size = UDim2.new(0, width, 0, height)
		data.frame.Visible = true
		data.nameLabel.Text = targetPlayer.Name
		data.stroke.Color = espSettings.color

		if espSettings.showHealth then
			data.healthBarBg.Visible = true
			data.healthText.Visible = true
			local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
			data.healthBarFill.Size = UDim2.new(1, 0, ratio, 0)
			if ratio > 0.66 then
				data.healthBarFill.BackgroundColor3 = Color3.fromRGB(50, 220, 80)
			elseif ratio > 0.33 then
				data.healthBarFill.BackgroundColor3 = Color3.fromRGB(230, 200, 60)
			else
				data.healthBarFill.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
			end
			data.healthText.Text = tostring(math.floor(humanoid.Health))
		else
			data.healthBarBg.Visible = false
			data.healthText.Visible = false
		end

		if espSettings.showTracer then
			local origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - 2)
			local targetPt = Vector2.new(screenPosHead.X, screenPosHead.Y + 8)
			setLine(data.tracer, origin, targetPt, espSettings.color)
		else
			data.tracer.Visible = false
		end

		if espSettings.showSkeleton then
			local bones = character:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
			for i = 1, #data.skeletonLines do
				local line = data.skeletonLines[i]
				local bone = bones[i]
				if bone then
					local p1Part = character:FindFirstChild(bone[1])
					local p2Part = character:FindFirstChild(bone[2])
					if p1Part and p2Part then
						local sp1, on1 = Camera:WorldToViewportPoint(p1Part.Position)
						local sp2, on2 = Camera:WorldToViewportPoint(p2Part.Position)
						if on1 and on2 and sp1.Z > 0 and sp2.Z > 0 then
							setLine(line, Vector2.new(sp1.X, sp1.Y), Vector2.new(sp2.X, sp2.Y), espSettings.color)
						else
							line.Visible = false
						end
					else
						line.Visible = false
					end
				else
					line.Visible = false
				end
			end
		else
			for _, l in ipairs(data.skeletonLines) do l.Visible = false end
		end
	end

	local espToggle = createToggle("ESP", "Отображение игроков через стены", 188, scrollingFrame)

	for _, child in ipairs(espToggle.Group:GetChildren()) do
		if child:IsA("TextLabel") then
			child.Size = UDim2.new(1, -76, 0, child.Size.Y.Offset)
		end
	end

	local espSettingsBtn = Instance.new("TextButton")
	espSettingsBtn.Size = UDim2.new(0, 20, 0, 20)
	espSettingsBtn.Position = UDim2.new(1, -64, 0, 7)
	espSettingsBtn.BackgroundColor3 = Color3.fromRGB(80, 110, 180)
	espSettingsBtn.BorderSizePixel = 0
	espSettingsBtn.Text = "*"
	espSettingsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	espSettingsBtn.Font = Enum.Font.GothamBold
	espSettingsBtn.TextSize = 14
	espSettingsBtn.ZIndex = 6
	Instance.new("UICorner", espSettingsBtn).CornerRadius = UDim.new(0, 4)
	espSettingsBtn.Parent = espToggle.Group

	local settingsPanel = Instance.new("Frame")
	settingsPanel.Size = UDim2.new(0, 210, 0, 208)
	settingsPanel.Position = UDim2.new(0, 85, 0, 155)
	settingsPanel.BackgroundColor3 = Color3.fromRGB(18, 26, 55)
	settingsPanel.BorderSizePixel = 0
	settingsPanel.Visible = false
	settingsPanel.ZIndex = 30
	Instance.new("UICorner", settingsPanel).CornerRadius = UDim.new(0, 8)
	settingsPanel.Parent = mainFrame

	local settingsStroke = Instance.new("UIStroke")
	settingsStroke.Color = Color3.fromRGB(50, 100, 220)
	settingsStroke.Thickness = 1
	settingsStroke.Parent = settingsPanel

	local settingsTitle = Instance.new("TextLabel")
	settingsTitle.Size = UDim2.new(1, -20, 0, 22)
	settingsTitle.Position = UDim2.new(0, 10, 0, 6)
	settingsTitle.BackgroundTransparency = 1
	settingsTitle.Text = "ESP Settings"
	settingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	settingsTitle.Font = Enum.Font.GothamBold
	settingsTitle.TextSize = 13
	settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
	settingsTitle.ZIndex = 31
	settingsTitle.Parent = settingsPanel

	local settingsClose = Instance.new("TextButton")
	settingsClose.Size = UDim2.new(0, 18, 0, 18)
	settingsClose.Position = UDim2.new(1, -24, 0, 8)
	settingsClose.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	settingsClose.BorderSizePixel = 0
	settingsClose.Text = "X"
	settingsClose.TextColor3 = Color3.fromRGB(255, 255, 255)
	settingsClose.Font = Enum.Font.GothamBold
	settingsClose.TextSize = 10
	settingsClose.ZIndex = 32
	Instance.new("UICorner", settingsClose).CornerRadius = UDim.new(0, 4)
	settingsClose.Parent = settingsPanel
	settingsClose.MouseButton1Click:Connect(function() settingsPanel.Visible = false end)

	local function makeMiniToggle(label, y)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -20, 0, 22)
		row.Position = UDim2.new(0, 10, 0, y)
		row.BackgroundTransparency = 1
		row.ZIndex = 31
		row.Parent = settingsPanel

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -46, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = Color3.fromRGB(230, 230, 240)
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 12
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.ZIndex = 32
		lbl.Parent = row

		local box = Instance.new("Frame")
		box.Size = UDim2.new(0, 28, 0, 16)
		box.Position = UDim2.new(1, -32, 0.5, -8)
		box.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		box.BorderSizePixel = 0
		box.ZIndex = 32
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
		box.Parent = row

		local ind = Instance.new("Frame")
		ind.Size = UDim2.new(0, 10, 0, 10)
		ind.Position = UDim2.new(0, 3, 0, 3)
		ind.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		ind.BorderSizePixel = 0
		ind.ZIndex = 33
		Instance.new("UICorner", ind).CornerRadius = UDim.new(0, 5)
		ind.Parent = box

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.ZIndex = 34
		btn.Parent = box

		return {
			Button = btn,
			SetState = function(state)
				if state then
					box.BackgroundColor3 = Color3.fromRGB(50, 100, 220)
					ind.Position = UDim2.new(1, -13, 0, 3)
				else
					box.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
					ind.Position = UDim2.new(0, 3, 0, 3)
				end
			end
		}
	end

	local tracerToggle = makeMiniToggle("Tracer line", 32)
	local skeletonToggle = makeMiniToggle("Skeleton", 58)
	local healthToggle = makeMiniToggle("Health bar", 84)

	local colorTitle = Instance.new("TextLabel")
	colorTitle.Size = UDim2.new(1, -20, 0, 14)
	colorTitle.Position = UDim2.new(0, 10, 0, 110)
	colorTitle.BackgroundTransparency = 1
	colorTitle.Text = "Box Color"
	colorTitle.TextColor3 = Color3.fromRGB(230, 230, 240)
	colorTitle.Font = Enum.Font.Gotham
	colorTitle.TextSize = 11
	colorTitle.TextXAlignment = Enum.TextXAlignment.Left
	colorTitle.ZIndex = 31
	colorTitle.Parent = settingsPanel

	local colorRow = Instance.new("Frame")
	colorRow.Size = UDim2.new(1, -20, 0, 28)
	colorRow.Position = UDim2.new(0, 10, 0, 128)
	colorRow.BackgroundTransparency = 1
	colorRow.ZIndex = 31
	colorRow.Parent = settingsPanel

	local colorOptions = {
		Color3.fromRGB(50, 100, 220), Color3.fromRGB(220, 50, 50), Color3.fromRGB(50, 220, 80),
		Color3.fromRGB(230, 200, 60), Color3.fromRGB(180, 50, 220), Color3.fromRGB(255, 255, 255),
	}

	local function applyColorToAll(col)
		espSettings.color = col
		for _, data in pairs(espFrames) do
			data.stroke.Color = col
			data.tracer.BackgroundColor3 = col
			for _, l in ipairs(data.skeletonLines) do l.BackgroundColor3 = col end
		end
	end

	for i, col in ipairs(colorOptions) do
		local swatch = Instance.new("TextButton")
		swatch.Size = UDim2.new(0, 24, 0, 24)
		swatch.Position = UDim2.new(0, (i - 1) * 27, 0, 2)
		swatch.BackgroundColor3 = col
		swatch.BorderSizePixel = 0
		swatch.Text = ""
		swatch.ZIndex = 32
		Instance.new("UICorner", swatch).CornerRadius = UDim.new(0, 4)
		swatch.Parent = colorRow
		swatch.MouseButton1Click:Connect(function() applyColorToAll(col) end)
	end

	local settingsHint = Instance.new("TextLabel")
	settingsHint.Size = UDim2.new(1, -20, 0, 24)
	settingsHint.Position = UDim2.new(0, 10, 1, -28)
	settingsHint.BackgroundTransparency = 1
	settingsHint.Text = "Изменения применяются сразу"
	settingsHint.TextColor3 = Color3.fromRGB(150, 170, 210)
	settingsHint.Font = Enum.Font.Gotham
	settingsHint.TextSize = 10
	settingsHint.TextXAlignment = Enum.TextXAlignment.Left
	settingsHint.TextYAlignment = Enum.TextYAlignment.Center
	settingsHint.ZIndex = 31
	settingsHint.Parent = settingsPanel

	tracerToggle.SetState(espSettings.showTracer)
	skeletonToggle.SetState(espSettings.showSkeleton)
	healthToggle.SetState(espSettings.showHealth)

	tracerToggle.Button.MouseButton1Click:Connect(function()
		espSettings.showTracer = not espSettings.showTracer
		tracerToggle.SetState(espSettings.showTracer)
		if not espSettings.showTracer then
			for _, data in pairs(espFrames) do data.tracer.Visible = false end
		end
	end)

	skeletonToggle.Button.MouseButton1Click:Connect(function()
		espSettings.showSkeleton = not espSettings.showSkeleton
		skeletonToggle.SetState(espSettings.showSkeleton)
		if not espSettings.showSkeleton then
			for _, data in pairs(espFrames) do
				for _, l in ipairs(data.skeletonLines) do l.Visible = false end
			end
		end
	end)

	healthToggle.Button.MouseButton1Click:Connect(function()
		espSettings.showHealth = not espSettings.showHealth
		healthToggle.SetState(espSettings.showHealth)
	end)

	espSettingsBtn.MouseButton1Click:Connect(function()
		settingsPanel.Visible = not settingsPanel.Visible
	end)

	local originalShowTab = showTab
	showTab = function(tabName)
		settingsPanel.Visible = false
		originalShowTab(tabName)
	end

	espToggle.OnToggle(function(on)
		if on then
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= player then createESPFrame(p) end
			end
			espPlayerAddedConn = Players.PlayerAdded:Connect(function(p) if p ~= player then createESPFrame(p) end end)
			espPlayerRemovingConn = Players.PlayerRemoving:Connect(removeESPFrame)
			if espConnection then espConnection:Disconnect() end
			espConnection = RunService.Heartbeat:Connect(function()
				for targetPlayer in pairs(espFrames) do updateESPFrame(targetPlayer) end
			end)
		else
			settingsPanel.Visible = false
			if espConnection then espConnection:Disconnect(); espConnection = nil end
			if espPlayerAddedConn then espPlayerAddedConn:Disconnect(); espPlayerAddedConn = nil end
			if espPlayerRemovingConn then espPlayerRemovingConn:Disconnect(); espPlayerRemovingConn = nil end
			for targetPlayer in pairs(espFrames) do removeESPFrame(targetPlayer) end
			espFrames = {}
		end
	end)

	-- FREEZE
	local freezeToggle = createToggle("Freeze Player", "Заморозить/разморозить", 222, scrollingFrame)
	local freezeEnabled = false
	freezeToggle.OnToggle(function(on)
		freezeEnabled = on
		local char = player.Character
		if char then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				if on then
					if flyEnabled then flyToggle.SetEnabled(false); stopFly() end
					root.Anchored = true
					root.Velocity = Vector3.zero
				else
					root.Anchored = false
				end
			end
		end
	end)

	-- TELEPORT TO PLAYER
	local teleportSection = Instance.new("Frame")
	teleportSection.Size = UDim2.new(1, 0, 0, 90)
	teleportSection.Position = UDim2.new(0, 0, 0, 256)
	teleportSection.BackgroundTransparency = 1
	teleportSection.ZIndex = 3
	teleportSection.Parent = scrollingFrame

	local teleportTitle = Instance.new("TextLabel")
	teleportTitle.Size = UDim2.new(1, 0, 0, 14)
	teleportTitle.BackgroundTransparency = 1
	teleportTitle.Text = "Teleport to Player"
	teleportTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	teleportTitle.Font = Enum.Font.GothamSemibold
	teleportTitle.TextSize = 12
	teleportTitle.TextXAlignment = Enum.TextXAlignment.Left
	teleportTitle.ZIndex = 3
	teleportTitle.Parent = teleportSection

	local playersList = Instance.new("ScrollingFrame")
	playersList.Size = UDim2.new(1, 0, 0, 72)
	playersList.Position = UDim2.new(0, 0, 0, 16)
	playersList.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	playersList.BorderSizePixel = 0
	playersList.ScrollBarThickness = 2
	playersList.ScrollBarImageColor3 = Color3.fromRGB(50, 100, 220)
	playersList.ZIndex = 3
	Instance.new("UICorner", playersList).CornerRadius = UDim.new(0, 4)
	playersList.Parent = teleportSection

	local playerListLayout = Instance.new("UIListLayout")
	playerListLayout.Padding = UDim.new(0, 2)
	playerListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	playerListLayout.SortOrder = Enum.SortOrder.Name
	playerListLayout.Parent = playersList

	local function refreshPlayerList()
		for _, c in ipairs(playersList:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		local players = Players:GetPlayers()
		table.sort(players, function(a, b) return a.Name < b.Name end)
		local cnt = 0
		for _, p in ipairs(players) do
			if p ~= player then
				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, -4, 0, 22)
				btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
				btn.BorderSizePixel = 0
				btn.Text = p.Name
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				btn.Font = Enum.Font.Gotham
				btn.TextSize = 11
				btn.ZIndex = 4
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
				btn.MouseButton1Click:Connect(function()
					local tp = Players:FindFirstChild(p.Name)
					if tp and tp.Character and tp.Character:FindFirstChild("HumanoidRootPart") then
						local mc = player.Character
						if mc and mc:FindFirstChild("HumanoidRootPart") then
							mc:PivotTo(tp.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0))
						end
					end
				end)
				btn.Parent = playersList
				cnt = cnt + 1
			end
		end
		playersList.CanvasSize = UDim2.new(0, 0, 0, cnt * 24 + 6)
	end
	refreshPlayerList()
	Players.PlayerAdded:Connect(function(p) if p ~= player then refreshPlayerList() end end)
	Players.PlayerRemoving:Connect(refreshPlayerList)

	scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, teleportSection.Position.Y.Offset + teleportSection.Size.Y.Offset + 10)

	-- DESTROY
	local destroyButton = Instance.new("TextButton")
	destroyButton.Size = UDim2.new(0, 120, 0, 28)
	destroyButton.Position = UDim2.new(0.5, -60, 1, -34)
	destroyButton.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
	destroyButton.BorderSizePixel = 0
	destroyButton.Text = "Destroy GUI"
	destroyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	destroyButton.Font = Enum.Font.GothamBold
	destroyButton.TextSize = 13
	destroyButton.ZIndex = 3
	Instance.new("UICorner", destroyButton).CornerRadius = UDim.new(0, 6)
	destroyButton.Parent = mainFrame
	destroyButton.MouseButton1Click:Connect(function()
		if espConnection then espConnection:Disconnect() end
		if carDriveConnection then carDriveConnection:Disconnect() end
		screenGui:Destroy()
	end)

	-- СВОРАЧИВАНИЕ
	local isMinimized = false
	minimizeButton.MouseButton1Click:Connect(function()
		if not isMinimized then
			isMinimized = true
			minimizeButton.Text = "+"
			tabBar.Visible = false
			mainTabContent.Visible = false
			soonTabContent.Visible = false
			teleportTabContent.Visible = false
			transportTabContent.Visible = false
			dragBottom.Visible = false
			dragLeft.Visible = false
			dragRight.Visible = false
			destroyButton.Visible = false
			settingsPanel.Visible = false
			TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 340, 0, 36)
			}):Play()
		else
			isMinimized = false
			minimizeButton.Text = "—"
			tabBar.Visible = true
			dragBottom.Visible = true
			dragLeft.Visible = true
			dragRight.Visible = true
			destroyButton.Visible = true
			showTab(currentTab)
			TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 340, 0, 380)
			}):Play()
		end
	end)

	mainFrame.Size = UDim2.new(0, 0, 0, 0)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.BackgroundTransparency = 1
	mainFrame.Visible = true
	TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 340, 0, 380),
		Position = UDim2.new(0.5, -170, 0.5, -190),
		BackgroundTransparency = 0
	}):Play()

	local function toggleMenu()
		if mainFrame.Visible then
			local t = TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 0, 0, 0),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				BackgroundTransparency = 1
			})
			t:Play()
			t.Completed:Connect(function() mainFrame.Visible = false end)
		else
			mainFrame.Visible = true
			TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 340, 0, 380),
				Position = UDim2.new(0.5, -170, 0.5, -190),
				BackgroundTransparency = 0
			}):Play()
		end
	end
	UserInputService.InputBegan:Connect(function(input, gpe)
		if input.KeyCode == Enum.KeyCode.Insert and not gpe then toggleMenu() end
	end)

	-- RESPAWN
	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		if hum then
			hum.WalkSpeed = currentSpeed
			hum.UseJumpPower = true
			hum.JumpPower = currentJump
		end
		if noclipEnabled then
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = false end
			end
		end
		if flyEnabled then stopFly(); flyEnabled = true; startFly() end
		if freezeEnabled then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then root.Anchored = true; root.Velocity = Vector3.zero end
		end
	end)

	if player.Character then
		local char = player.Character
		local hum = char:FindFirstChild("Humanoid")
		if hum then hum.WalkSpeed = currentSpeed; hum.UseJumpPower = true; hum.JumpPower = currentJump end
	end

	-- FLY
	function createMobileControls()
		local function mkBtn(text, pos, size)
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(0, 60, 0, 60)
			b.Position = pos
			b.BackgroundColor3 = Color3.fromRGB(50, 100, 220)
			b.BackgroundTransparency = 0.4
			b.BorderSizePixel = 0
			b.Text = text
			b.TextColor3 = Color3.fromRGB(255, 255, 255)
			b.Font = Enum.Font.GothamBold
			b.TextSize = size
			b.Visible = false
			Instance.new("UICorner", b).CornerRadius = UDim.new(0, 30)
			b.Parent = screenGui
			return b
		end

		btnForward = mkBtn("W", UDim2.new(0, 20, 1, -140), 20)
		btnBackward = mkBtn("S", UDim2.new(0, 90, 1, -140), 20)
		btnUp = mkBtn("UP", UDim2.new(1, -90, 1, -140), 16)
		btnDown = mkBtn("DN", UDim2.new(1, -160, 1, -140), 16)

		local function bindHold(btn, flagName)
			btn.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch then
					if flagName == "f" then forwardPressed = true
					elseif flagName == "b" then backwardPressed = true
					elseif flagName == "u" then upPressed = true
					elseif flagName == "d" then downPressed = true end
				end
			end)
			btn.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch then
					if flagName == "f" then forwardPressed = false
					elseif flagName == "b" then backwardPressed = false
					elseif flagName == "u" then upPressed = false
					elseif flagName == "d" then downPressed = false end
				end
			end)
		end
		bindHold(btnForward, "f")
		bindHold(btnBackward, "b")
		bindHold(btnUp, "u")
		bindHold(btnDown, "d")
	end

	function createFlyParts(char)
		local root = char:WaitForChild("HumanoidRootPart")
		if bodyVelocity then bodyVelocity:Destroy() end
		if bodyGyro then bodyGyro:Destroy() end
		bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bodyVelocity.Velocity = Vector3.zero
		bodyVelocity.Parent = root
		bodyGyro = Instance.new("BodyGyro")
		bodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
		bodyGyro.CFrame = root.CFrame
		bodyGyro.Parent = root
	end

	function startFly()
		if flyConnection then return end
		createMobileControls()
		local char = player.Character
		if char then createFlyParts(char) end
		btnForward.Visible = true
		btnBackward.Visible = true
		btnUp.Visible = true
		btnDown.Visible = true

		flyConnection = RunService.Heartbeat:Connect(function()
			if not flyEnabled then return end
			local char = player.Character
			if not char then return end
			local root = char:FindFirstChild("HumanoidRootPart")
			if not root then return end
			if not bodyVelocity or not bodyVelocity.Parent then createFlyParts(char) end
			if not bodyGyro or not bodyGyro.Parent then createFlyParts(char) end

			if noclipEnabled then
				for _, p in ipairs(char:GetDescendants()) do
					if p:IsA("BasePart") then p.CanCollide = false end
				end
			end

			local moveDir = Vector3.zero
			local cam = Camera.CFrame
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += cam.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= cam.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= cam.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += cam.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0,1,0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then moveDir -= Vector3.new(0,1,0) end
			if forwardPressed then moveDir += cam.LookVector end
			if backwardPressed then moveDir -= cam.LookVector end
			if upPressed then moveDir += Vector3.new(0,1,0) end
			if downPressed then moveDir -= Vector3.new(0,1,0) end

			if bodyVelocity then
				bodyVelocity.Velocity = moveDir.Magnitude > 0 and moveDir.Unit * flySpeed or Vector3.zero
			end
			if bodyGyro then
				bodyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + cam.LookVector)
			end
		end)
	end

	function stopFly()
		if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
		if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
		if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
		local char = player.Character
		if char and char:FindFirstChild("Humanoid") then char.Humanoid.PlatformStand = false end
		if btnForward then
			btnForward.Visible = false
			btnBackward.Visible = false
			btnUp.Visible = false
			btnDown.Visible = false
			forwardPressed, backwardPressed, upPressed, downPressed = false, false, false, false
		end
	end
end
