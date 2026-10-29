local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GunConfig = require(ReplicatedStorage:WaitForChild("GunConfig"))
local Spring = require(ReplicatedStorage:WaitForChild("Spring"))
local ViewmodelRig = require(script.Parent:WaitForChild("ViewmodelRig"))

local player = Players.LocalPlayer

local rig: Model? = nil
local cfg = nil
local sway = nil
local character: Model? = nil
local diedConnection: RBXScriptConnection? = nil
local bobTime = 0
local lastRotation: CFrame? = nil

local function destroyRig()
	if rig ~= nil then
		rig:Destroy()
		rig = nil
	end
end

local function hideCharacter(model: Model)
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.LocalTransparencyModifier = 1
		end
	end
end

local function equip(gunName: string)
	destroyRig()
	cfg = GunConfig.get(gunName)
	rig = ViewmodelRig.build(gunName)
	rig.Parent = workspace.CurrentCamera
	sway = Spring.new(Vector3.zero, cfg.Sway.Speed, cfg.Sway.Damper)
	bobTime = 0
	lastRotation = nil
end

local function update(dt: number)
	local cam = workspace.CurrentCamera
	if rig == nil or cfg == nil or sway == nil or cam == nil or character == nil then
		return
	end
	hideCharacter(character)

	local speed = 0
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.WalkSpeed ~= 0 then
		speed = root.AssemblyLinearVelocity.Magnitude / humanoid.WalkSpeed
	end
	bobTime += dt * cfg.Bob.Speed
	local bobCF = CFrame.new(Vector3.yAxis * math.sin(bobTime) * cfg.Bob.Amount * speed)

	local rotation = cam.CFrame.Rotation
	if lastRotation ~= nil then
		local pitch, yaw, roll = lastRotation:ToObjectSpace(rotation):ToOrientation()
		sway:impulse(-Vector3.new(pitch, yaw, roll) * cfg.Sway.Amount)
	end
	lastRotation = rotation
	local offset = sway:update(dt)
	local swayCF = CFrame.fromOrientation(offset.X, offset.Y, offset.Z)

	rig:PivotTo(cam.CFrame * bobCF * swayCF)
end

local function onDied()
	if diedConnection ~= nil then
		diedConnection:Disconnect()
		diedConnection = nil
	end
	destroyRig()
	sway = nil
	cfg = nil
	character = nil
	lastRotation = nil
end

local function onCharacter(model: Model)
	if diedConnection ~= nil then
		diedConnection:Disconnect()
		diedConnection = nil
	end
	character = model
	hideCharacter(model)
	local humanoid = model:WaitForChild("Humanoid") :: Humanoid
	diedConnection = humanoid.Died:Connect(onDied)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	equip(GunConfig.list()[1])
end

player.CameraMode = Enum.CameraMode.LockFirstPerson
player.CharacterAdded:Connect(onCharacter)
if player.Character ~= nil then
	onCharacter(player.Character)
end

RunService:BindToRenderStep("Viewmodel", Enum.RenderPriority.Camera.Value + 1, update)

local equipCall = Instance.new("BindableFunction")
equipCall.Name = "equip"
equipCall.Parent = script
function equipCall.OnInvoke(gunName: string)
	equip(gunName)
end
