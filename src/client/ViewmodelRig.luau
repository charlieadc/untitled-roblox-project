local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GunConfig = require(ReplicatedStorage:WaitForChild("GunConfig"))
local ViewmodelRig = {}
local RIGHT_ARM_NAME = "Right Arm"
local ARMS = {
	{ name = "Left Arm", offset = CFrame.new(1.2, 0.05, -0.45) },
	{ name = RIGHT_ARM_NAME, offset = CFrame.new(1.5, 0, 0) },
}
local GUN_PARTS = {
	{ "AimPart", CFrame.new(0, 0, -1), false },
	{ "FirePart", CFrame.new(0, 0, -2), false },
	{ "Mag", CFrame.new(0, -0.5, 0), true },
	{ "Bolt", CFrame.new(0, 0.2, -0.3), true },
}
local function note(report: { string }?, piece: string)
	if report ~= nil then
		table.insert(report, piece)
	end
end
local function makeBlock(name: string, at: CFrame): Part
	local block = Instance.new("Part")
	block.Name = name
	block.Size = Vector3.new(1, 1, 1)
	block.CFrame = at
	block.Anchored = false
	return block
end
local function findTemplate(folderName: string, modelName: string): Model?
	local folder = if modelName ~= "" then ReplicatedStorage:FindFirstChild(folderName) else nil
	local child = if folder ~= nil then folder:FindFirstChild(modelName) else nil
	if child ~= nil and child:IsA("Model") then
		return child
	end
	return nil
end
local function childPart(parent: Instance, name: string): BasePart?
	local child = parent:FindFirstChild(name)
	if child ~= nil and child:IsA("BasePart") then
		return child
	end
	return nil
end
local function slot(parent: Instance, name: string, at: CFrame, report: { string }?): (BasePart, boolean)
	local existing = childPart(parent, name)
	if existing ~= nil then
		return existing, false
	end
	local block = makeBlock(name, at)
	block.Parent = parent
	note(report, name)
	return block, true
end
local function link(className: string, parent: Instance, part0: BasePart, part1: BasePart)
	local joint = Instance.new(className)
	joint.Name = part1.Name
	joint.Part0 = part0
	joint.Part1 = part1
	if className == "Motor6D" then
		joint.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
		joint.C1 = CFrame.identity
	end
	joint.Parent = parent
end
local function beginModel(
	folderName: string,
	modelName: string,
	label: string,
	missing: { string }
): (Model, { string }?)
	local template = findTemplate(folderName, modelName)
	if template ~= nil then
		return template:Clone(), missing
	end
	local model = Instance.new("Model")
	model.Name = modelName
	table.insert(missing, label)
	return model, nil
end
local function findGripMotor(rig: Model): Motor6D?
	for _, desc in ipairs(rig:GetDescendants()) do
		if desc:IsA("Motor6D") and desc.Name == "Grip" then
			return desc
		end
	end
	return nil
end
local function ensureArms(missing: { string }): Model
	local rig, report = beginModel("Viewmodels", "Arms", "arms", missing)
	local hrp, createdRoot = slot(rig, "HumanoidRootPart", CFrame.identity, report)
	if createdRoot then
		hrp.Anchored = true
		hrp.Transparency = 1
	end
	if rig.PrimaryPart == nil then
		rig.PrimaryPart = hrp
	end
	for _, arm in ARMS do
		local limb, created = slot(rig, arm.name, hrp.CFrame * arm.offset, report)
		if created then
			link("Motor6D", hrp, hrp, limb)
		end
	end
	if rig:FindFirstChildWhichIsA("Animator", true) == nil then
		local controller = rig:FindFirstChildWhichIsA("AnimationController", true)
		if controller == nil then
			controller = Instance.new("AnimationController")
			controller.Parent = rig
			note(report, "AnimationController")
		end
		Instance.new("Animator").Parent = controller
		note(report, "Animator")
	end
	return rig
end
local function ensureGun(modelName: string, missing: { string }): Model
	local gun, report = beginModel("GunModels", modelName, "gun", missing)
	local grip = slot(gun, "Grip", CFrame.identity, report)
	if gun.PrimaryPart == nil then
		gun.PrimaryPart = grip
	end
	for _, spec in GUN_PARTS do
		local part, created = slot(gun, spec[1], grip.CFrame * spec[2], report)
		if created then
			link(if spec[3] then "Motor6D" else "WeldConstraint", grip, grip, part)
		end
	end
	return gun
end
local function barrelC1(grip: BasePart, aim: BasePart, fire: BasePart, attachment: Attachment): CFrame
	local localForward = grip.CFrame:VectorToObjectSpace((fire.Position - aim.Position).Unit)
	local upHint = if math.abs(localForward:Dot(Vector3.yAxis)) > 0.999 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(Vector3.zero, localForward, upHint) * (attachment.CFrame - attachment.CFrame.Position)
end
local function joinGun(rig: Model, gun: Model)
	local right = childPart(rig, RIGHT_ARM_NAME) :: BasePart
	local grip = childPart(gun, "Grip") :: BasePart
	local motor = findGripMotor(rig)
	gun.Parent = rig
	if motor ~= nil then
		motor.Part0 = right
		motor.Part1 = grip
		return
	end
	local attachment = right:FindFirstChild("GripAttachment") :: Attachment?
	if attachment == nil then
		attachment = Instance.new("Attachment")
		attachment.Name = "GripAttachment"
		attachment.Parent = right
	end
	local created = Instance.new("Motor6D")
	created.Name = "Grip"
	created.Part0 = right
	created.Part1 = grip
	created.C0 = attachment.CFrame
	created.C1 =
		barrelC1(grip, childPart(gun, "AimPart") :: BasePart, childPart(gun, "FirePart") :: BasePart, attachment)
	created.Parent = right
end
function ViewmodelRig.build(gunName: string): Model
	local missing = {}
	local rig = ensureArms(missing)
	joinGun(rig, ensureGun(GunConfig.get(gunName).Model, missing))
	if #missing > 0 then
		warn(`ViewmodelRig: missing {table.concat(missing, ", ")}`)
	end
	for _, desc in ipairs(rig:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.CanQuery = false
			desc.CanTouch = false
			desc.Massless = true
			desc.CastShadow = false
		elseif desc:IsA("Humanoid") then
			desc.EvaluateStateMachine = false
			desc.RequiresNeck = false
			desc.BreakJointsOnDeath = false
		end
	end
	return rig
end
local function gunOf(rig: Model): Model?
	for _, child in ipairs(rig:GetChildren()) do
		if child:IsA("Model") and childPart(child, "Grip") ~= nil then
			return child
		end
	end
	return nil
end
local function motorProblem(partParent: Instance, motorParent: Instance, name: string, part0: BasePart): string?
	local part = childPart(partParent, name)
	if part == nil then
		return `{name} is missing`
	end
	local joint = motorParent:FindFirstChild(name)
	if joint == nil or not joint:IsA("Motor6D") or joint.Part0 ~= part0 or joint.Part1 ~= part then
		return `{name} motor is missing`
	end
	return nil
end
function ViewmodelRig.validate(rig: Model): (boolean, string?)
	local hrp = childPart(rig, "HumanoidRootPart")
	if hrp == nil or rig.PrimaryPart ~= hrp then
		return false, "PrimaryPart is not HumanoidRootPart"
	end
	if not hrp.Anchored or hrp.CanCollide then
		return false, "HumanoidRootPart must be anchored and non-colliding"
	end
	local gun = gunOf(rig)
	if gun == nil then
		return false, "gun is missing"
	end
	local grip = childPart(gun, "Grip")
	if grip == nil or gun.PrimaryPart ~= grip then
		return false, "Grip is not the gun PrimaryPart"
	end
	for _, arm in ARMS do
		local problem = motorProblem(rig, hrp, arm.name, hrp)
		if problem ~= nil then
			return false, problem
		end
	end
	for _, name in { "Mag", "Bolt" } do
		local problem = motorProblem(gun, grip, name, grip)
		if problem ~= nil then
			return false, problem
		end
	end
	for _, name in { "AimPart", "FirePart" } do
		if childPart(gun, name) == nil then
			return false, `{name} is missing`
		end
	end
	if rig:FindFirstChildWhichIsA("Animator", true) == nil then
		return false, "Animator is missing"
	end
	local right = childPart(rig, RIGHT_ARM_NAME) :: BasePart
	local gripMotor = findGripMotor(rig)
	if gripMotor == nil or gripMotor.Part0 ~= right or gripMotor.Part1 ~= grip then
		return false, "Grip motor is missing"
	end
	local joined = {}
	for _, joint in ipairs(grip:GetChildren()) do
		if (joint:IsA("WeldConstraint") or joint:IsA("Motor6D")) and joint.Part1 ~= nil then
			joined[joint.Part1] = true
		end
	end
	for _, desc in ipairs(rig:GetDescendants()) do
		if desc:IsA("LuaSourceContainer") then
			return false, `{desc.Name} is a script`
		end
		if desc:IsA("BasePart") and desc ~= hrp and desc.Anchored then
			return false, `{desc.Name} is anchored`
		end
		if desc:IsA("BasePart") and desc.Parent == gun and desc ~= grip and not joined[desc] then
			return false, `{desc.Name} is not joined to Grip`
		end
	end
	return true, nil
end
function ViewmodelRig.sightCFrame(rig: Model): CFrame
	local gun = gunOf(rig) :: Model
	return CFrame.lookAt(gun.AimPart.Position, gun.FirePart.Position, gun.Grip.CFrame.UpVector)
end
return ViewmodelRig
