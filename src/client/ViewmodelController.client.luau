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
local aimSpring = nil
local sprintSpring = nil
local character: Model? = nil
local diedConnection: RBXScriptConnection? = nil
local bobTime = 0
local lastRotation: CFrame? = nil
local anims = nil
local firePart: BasePart? = nil
local grip: BasePart? = nil
local recoilState = nil
local mouseHeld = false
local pressEdge = false
local AIR_LIMIT = 0.2
local slide = {
	active = false,
	dir = Vector3.zero,
	startedAt = 0,
	airAt = nil,
	speed = 0,
	lastEnd = -math.huge,
	sprintBroken = false,
}
local slidePress = false
local slideSpring = nil
local lastSlideRoll = 0
local slideTrackPlayed = false

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

local function restoreFov()
	local cam = workspace.CurrentCamera
	if cam ~= nil and cfg ~= nil then
		cam.FieldOfView = cfg.HipFov
	end
end

local function newRecoil(profile)
	return {
		cam = Spring.new(Vector3.zero, profile.CamSpeed, profile.CamDamper),
		vmPos = Spring.new(Vector3.zero, profile.VmSpeed, profile.VmDamper),
		vmRot = Spring.new(Vector3.zero, profile.VmSpeed, profile.VmDamper),
		fov = Spring.new(Vector3.zero, profile.FovSpeed, profile.FovDamper),
		lastCam = Vector3.zero,
		lastShot = -math.huge,
		profile = profile,
	}
end

local function applyCameraDelta(state, camera, desired: Vector3)
	if camera == nil then
		return
	end
	local delta = desired - state.lastCam
	if delta.X ~= 0 or delta.Y ~= 0 then
		camera.CFrame *= CFrame.Angles(math.rad(delta.X), math.rad(delta.Y), 0)
	end
	state.lastCam = desired
end

local function settleRecoil()
	if recoilState == nil then
		return
	end
	applyCameraDelta(recoilState, workspace.CurrentCamera, Vector3.zero)
	lastRotation = nil
	recoilState = nil
end

local function stepRecoil(dt: number, aimAlpha: number, trigger: boolean, blocked: boolean, camera)
	local state = recoilState
	local fired = false
	if trigger and not blocked then
		local profile = state.profile
		local now = os.clock()
		local interval = 60 / profile.FireRate
		local since = now - state.lastShot
		if since >= interval then
			local mult = 1 - (1 - profile.AdsKickMult) * aimAlpha
			if since > profile.FirstShotResetTime then
				mult *= profile.FirstShotMult
			end
			local yaw = (math.random() * 2 - 1) * profile.CamKickYaw
			local roll = (math.random() * 2 - 1) * profile.VmKickRoll
			state.cam:impulse(Vector3.new(profile.CamKickPitch, yaw, 0) * mult * profile.CamSpeed)
			state.vmPos:impulse(Vector3.new(0, profile.VmKickUp, profile.VmKickBack) * mult * profile.VmSpeed)
			state.vmRot:impulse(Vector3.new(profile.VmKickPitch, 0, roll) * mult * profile.VmSpeed)
			state.fov:impulse(Vector3.new(profile.FovPunch, 0, 0) * profile.FovSpeed)
			if since > interval * 2 then
				state.lastShot = now
			else
				state.lastShot += interval
			end
			fired = true
		end
	end
	local camPos = state.cam:update(dt)
	local vmPos = state.vmPos:update(dt)
	local vmRot = state.vmRot:update(dt)
	applyCameraDelta(state, camera, camPos)
	local vmOffset = CFrame.new(vmPos) * CFrame.Angles(math.rad(vmRot.X), math.rad(vmRot.Y), math.rad(vmRot.Z))
	local fovAdd = state.fov:update(dt).X
	return vmOffset, fovAdd, fired
end

local function freshSlide()
	return {
		active = false,
		dir = Vector3.zero,
		startedAt = 0,
		airAt = nil,
		speed = 0,
		lastEnd = -math.huge,
		sprintBroken = false,
	}
end

local function stopSlide(now: number)
	if not slide.active then
		return
	end
	slide.active = false
	slide.dir = Vector3.zero
	slide.speed = 0
	slide.airAt = nil
	slide.lastEnd = now
	slide.sprintBroken = true
end

local function stepSlide(
	humanoid: Humanoid,
	root: BasePart?,
	sprintHeld: boolean,
	moving: boolean,
	aiming: boolean,
	trigger: boolean,
	now: number
): string
	if not sprintHeld then
		slide.sprintBroken = false
	end
	if slide.active then
		local elapsed = now - slide.startedAt
		slide.speed = cfg.Slide.StartSpeed * math.exp(-cfg.Slide.Decay * elapsed)
		if humanoid.FloorMaterial == Enum.Material.Air then
			if slide.airAt == nil then
				slide.airAt = now
			end
		else
			slide.airAt = nil
		end
		local stop = slide.speed < cfg.Slide.EndSpeed
			or elapsed > cfg.Slide.MaxDuration
			or humanoid.Jump
			or UserInputService:IsKeyDown(Enum.KeyCode.Space)
			or (slide.airAt ~= nil and now - slide.airAt > AIR_LIMIT)
		if not stop then
			if root == nil then
				stop = true
			else
				local exclude = { humanoid.Parent }
				if rig ~= nil then
					table.insert(exclude, rig)
				end
				for _, child in ipairs(workspace:GetChildren()) do
					if child:IsA("Tool") then
						table.insert(exclude, child)
					end
				end
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = exclude
				local hit = workspace:Raycast(root.Position, slide.dir * cfg.Slide.WallCheckDistance, params)
				if hit ~= nil then
					stop = true
				end
			end
		end
		if stop then
			stopSlide(now)
		end
	end
	if
		not slide.active
		and slidePress
		and sprintHeld
		and moving
		and not aiming
		and not trigger
		and not slide.sprintBroken
		and humanoid.FloorMaterial ~= Enum.Material.Air
		and now - slide.lastEnd >= cfg.Slide.Cooldown
	then
		local move = humanoid.MoveDirection
		local flat = Vector3.new(move.X, 0, move.Z)
		if flat.Magnitude >= 1e-3 then
			slide.dir = flat.Unit
			slide.startedAt = now
			slide.airAt = nil
			slide.speed = cfg.Slide.StartSpeed
			slide.active = true
		end
	end
	if slide.active and root ~= nil and root:IsA("BasePart") then
		humanoid:Move(slide.dir, false)
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(slide.dir.X * slide.speed, velocity.Y, slide.dir.Z * slide.speed)
	end
	if slide.active then
		return "slide"
	elseif sprintHeld and moving and not aiming and not trigger and not slide.sprintBroken then
		return "sprint"
	else
		return "walk"
	end
end

local function applySlideCamera(humanoid: Humanoid?, camera: Camera?, alpha: number)
	if humanoid ~= nil and cfg ~= nil then
		humanoid.CameraOffset = Vector3.new(0, -cfg.Slide.CameraDrop * alpha, 0)
	end
	if camera == nil or cfg == nil then
		return
	end
	local desired = cfg.Slide.CameraTilt * alpha
	local delta = desired - lastSlideRoll
	if delta ~= 0 then
		camera.CFrame *= CFrame.Angles(0, 0, math.rad(delta))
	end
	lastSlideRoll = desired
end

local function equip(gunName: string)
	mouseHeld = false
	pressEdge = false
	if slide.active then
		stopSlide(os.clock())
	end
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	applySlideCamera(humanoid, workspace.CurrentCamera, 0)
	settleRecoil()
	destroyRig()
	cfg = GunConfig.get(gunName)
	rig = ViewmodelRig.build(gunName)
	rig.Parent = workspace.CurrentCamera
	sway = Spring.new(Vector3.zero, cfg.Sway.Speed, cfg.Sway.Damper)
	aimSpring = Spring.new(Vector3.zero, cfg.AdsSpeed, 1)
	sprintSpring = Spring.new(Vector3.zero, cfg.SprintBlendSpeed, cfg.SprintBlendDamper)
	slideSpring = Spring.new(Vector3.zero, cfg.Slide.SpringSpeed, cfg.Slide.SpringDamper)
	slideTrackPlayed = false
	recoilState = newRecoil(cfg.Recoil)
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
	restoreFov()
end

local function update(dt: number)
	local cam = workspace.CurrentCamera
	if
		rig == nil
		or cfg == nil
		or sway == nil
		or aimSpring == nil
		or sprintSpring == nil
		or slideSpring == nil
		or cam == nil
		or character == nil
		or recoilState == nil
	then
		slidePress = false
		return
	end
	hideCharacter(character)

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local aiming = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
		mouseHeld = false
	end
	local trigger = pressEdge or mouseHeld
	local now = os.clock()
	local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0
	local rootPart = if root ~= nil and root:IsA("BasePart") then root else nil
	local mode = "walk"
	if humanoid ~= nil then
		mode = stepSlide(humanoid, rootPart, shift, moving, aiming, trigger, now)
	end
	slidePress = false
	if humanoid ~= nil then
		humanoid.WalkSpeed = if mode == "slide"
			then slide.speed
			elseif mode == "sprint" then cfg.SprintSpeed
			else cfg.WalkSpeed
	end
	local speed = 0
	if root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.WalkSpeed ~= 0 then
		speed = root.AssemblyLinearVelocity.Magnitude / humanoid.WalkSpeed
	end
	local sprintClip = false
	local slideClip = false
	if anims ~= nil then
		if mode == "slide" then
			if not slideTrackPlayed then
				anims:play("Slide")
				slideTrackPlayed = true
			end
			slideClip = anims:isPlaying("Slide")
		else
			anims:stop("Slide")
			slideTrackPlayed = false
		end
		local sprinting = mode == "sprint"
		if sprinting then
			anims:play("Sprint")
			sprintClip = anims:isPlaying("Sprint")
		else
			anims:stop("Sprint")
		end
		if not sprintClip and mode ~= "slide" and speed > 0 then
			anims:play("Walk")
		else
			anims:stop("Walk")
		end
	end
	bobTime += dt * cfg.Bob.Speed
	aimSpring:setTarget(if aiming then Vector3.xAxis else Vector3.zero)
	local a = aimSpring:update(dt).X
	local aimScale = 1 - 0.8 * a
	sprintSpring:setTarget(if mode == "sprint" and not sprintClip then Vector3.xAxis else Vector3.zero)
	local s = sprintSpring:update(dt).X
	slideSpring:setTarget(if mode == "slide" then Vector3.xAxis else Vector3.zero)
	local slideS = slideSpring:update(dt).X
	local bobMult = 1 + (cfg.Bob.SprintMult - 1) * s
	local bobCF = CFrame.new(Vector3.yAxis * math.sin(bobTime) * cfg.Bob.Amount * bobMult * speed * aimScale)

	local rotation = cam.CFrame.Rotation
	if lastRotation ~= nil then
		local pitch, yaw, roll = lastRotation:ToObjectSpace(rotation):ToOrientation()
		sway:impulse(-Vector3.new(pitch, yaw, roll) * cfg.Sway.Amount)
	end
	local blocked = anims ~= nil and anims:isPlaying("Reload")
	local vmOffset, fovAdd, fired = stepRecoil(dt, a, trigger, blocked, cam)
	pressEdge = false
	applySlideCamera(humanoid, cam, slideS)
	lastRotation = cam.CFrame.Rotation
	local offset = sway:update(dt)
	local swayCF = CFrame.fromOrientation(offset.X * aimScale, offset.Y * aimScale, offset.Z * aimScale)

	local sprintPose = if sprintClip then 0 else s
	local slidePose = if slideClip then 0 else slideS
	local hipCF = bobCF * swayCF * cfg.HipOffset:Lerp(cfg.SprintOffset, sprintPose):Lerp(cfg.Slide.Offset, slidePose)
	local hrp = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	local sight = ViewmodelRig.sightCFrame(rig)
	local aimCF = (hrp.CFrame:ToObjectSpace(sight) * cfg.AimOffset):Inverse()
	rig:PivotTo(cam.CFrame * vmOffset * hipCF:Lerp(aimCF, a))
	cam.FieldOfView = cfg.HipFov + (cfg.AdsFov - cfg.HipFov) * a + fovAdd
	if fired and anims ~= nil then
		anims:play("Fire")
		if firePart ~= nil then
			playSound(firePart, cfg.Sounds.Fire)
			for _, desc in ipairs(firePart:GetDescendants()) do
				if desc:IsA("ParticleEmitter") then
					desc:Emit(1)
				end
			end
		end
	end
end

local function onDied()
	if diedConnection ~= nil then
		diedConnection:Disconnect()
		diedConnection = nil
	end
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	applySlideCamera(humanoid, workspace.CurrentCamera, 0)
	slide = freshSlide()
	slideSpring = nil
	slideTrackPlayed = false
	slidePress = false
	settleRecoil()
	restoreFov()
	destroyRig()
	sway = nil
	aimSpring = nil
	sprintSpring = nil
	cfg = nil
	character = nil
	lastRotation = nil
	mouseHeld = false
	pressEdge = false
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
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if not processed then
			mouseHeld = true
			pressEdge = true
		end
		return
	end
	if processed or anims == nil or rig == nil or cfg == nil then
		return
	end
	if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl then
		slidePress = true
		return
	end
	if input.KeyCode ~= Enum.KeyCode.R then
		return
	end
	if anims:isPlaying("Reload") then
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
