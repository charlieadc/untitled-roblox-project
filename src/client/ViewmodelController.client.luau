local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GunConfig = require(ReplicatedStorage:WaitForChild("GunConfig"))
local Spring = require(ReplicatedStorage:WaitForChild("Spring"))
local ViewmodelRig = require(script.Parent:WaitForChild("ViewmodelRig"))
local ViewmodelAnimations = require(script.Parent:WaitForChild("ViewmodelAnimations"))

local player = Players.LocalPlayer

local rig: Model? = nil
local cfg = nil
local sway = nil
local character: Model? = nil
local diedConnection: RBXScriptConnection? = nil
local bobTime = 0
local lastRotation: CFrame? = nil
local anims = nil
local firePart: BasePart? = nil
local grip: BasePart? = nil

local function partNamed(model: Model, name: string): BasePart?
	for _, desc in ipairs(model:GetDescendants()) do
		if desc.Name == name and desc:IsA("BasePart") then
			return desc
		end
	end
	return nil
end

local function playSound(root: Instance, name: any)
	if type(name) ~= "string" or name == "" then
		return
	end
	for _, desc in ipairs(root:GetDescendants()) do
		if desc.Name == name and desc:IsA("Sound") then
			desc:Play()
			return
		end
	end
end

local function destroyRig()
	if anims ~= nil then
		anims:destroy()
		anims = nil
	end
	firePart = nil
	grip = nil
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
	local animator = rig:FindFirstChildWhichIsA("Animator", true)
	if animator ~= nil then
		anims = ViewmodelAnimations.new(animator :: Animator, cfg.AnimationIds)
		anims:play("Equip")
		anims:play("Idle")
	end
	firePart = partNamed(rig, "FirePart")
	grip = partNamed(rig, "Grip")
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
	if anims ~= nil then
		if speed > 0 then
			anims:play("Walk")
		else
			anims:stop("Walk")
		end
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

local function onInput(input: InputObject, processed: boolean)
	if processed or anims == nil or rig == nil or cfg == nil then
		return
	end
	local fire = input.UserInputType == Enum.UserInputType.MouseButton1
	local reload = input.KeyCode == Enum.KeyCode.R
	if not fire and not reload then
		return
	end
	if anims:isPlaying("Reload") then
		return
	end
	if fire then
		anims:play("Fire")
		if firePart ~= nil then
			playSound(firePart, cfg.Sounds.Fire)
			for _, desc in ipairs(firePart:GetDescendants()) do
				if desc:IsA("ParticleEmitter") then
					desc:Emit(1)
				end
			end
		end
		return
	end
	anims:play("Reload")
	if grip ~= nil then
		for _, name in ipairs(cfg.Sounds.Reload) do
			playSound(grip, name)
		end
	end
end

RunService:BindToRenderStep("Viewmodel", Enum.RenderPriority.Camera.Value + 1, update)

UserInputService.InputBegan:Connect(onInput)

local equipCall = Instance.new("BindableFunction")
equipCall.Name = "equip"
equipCall.Parent = script
function equipCall.OnInvoke(gunName: string)
	equip(gunName)
end
