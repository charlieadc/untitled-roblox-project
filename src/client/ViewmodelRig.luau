local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gunConfigModule = ReplicatedStorage:FindFirstChild("GunConfig")
if gunConfigModule == nil or not gunConfigModule:IsA("ModuleScript") then
	error("ViewmodelRig: ReplicatedStorage.GunConfig is missing")
end

local GunConfig = require(gunConfigModule)

local ViewmodelRig = {}

local function note(report: { string }?, piece: string)
	if report ~= nil then
		table.insert(report, piece)
	end
end

local function makeBlock(name: string): Part
	local block = Instance.new("Part")
	block.Name = name
	block.Size = Vector3.new(1, 1, 1)
	block.Anchored = false
	block.CanCollide = false
	block.CanQuery = false
	block.CanTouch = false
	block.Massless = true
	return block
end

local function findTemplate(folderName: string, modelName: string): Model?
	if modelName == "" then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	if folder == nil then
		return nil
	end
	local child = folder:FindFirstChild(modelName)
	if child ~= nil and child:IsA("Model") then
		return child
	end
	return nil
end

local function directPart(parent: Instance, name: string): BasePart?
	local child = parent:FindFirstChild(name)
	if child ~= nil and child:IsA("BasePart") then
		return child
	end
	return nil
end

local function ensurePart(parent: Instance, name: string, at: CFrame, report: { string }?): BasePart
	local existing = directPart(parent, name)
	if existing ~= nil then
		return existing
	end
	local block = makeBlock(name)
	block.CFrame = at
	block.Parent = parent
	note(report, name)
	return block
end

local function findMotor(root: Instance, name: string): Motor6D?
	for _, desc in ipairs(root:GetDescendants()) do
		if desc:IsA("Motor6D") and desc.Name == name then
			return desc
		end
	end
	return nil
end

local function ensureMotor(
	root: Instance,
	parent: Instance,
	name: string,
	part0: BasePart,
	part1: BasePart,
	report: { string }?
)
	local motor = findMotor(root, name)
	if motor ~= nil and motor.Part0 == part0 and motor.Part1 == part1 then
		return
	end
	if motor == nil then
		motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Parent = parent
	end
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	motor.C1 = CFrame.identity
	note(report, `{name} motor`)
end

local function joined(root: Instance, grip: BasePart, part: BasePart): boolean
	if part == grip then
		return true
	end
	for _, desc in ipairs(root:GetDescendants()) do
		if desc:IsA("WeldConstraint") or desc:IsA("Motor6D") then
			local a = desc.Part0
			local b = desc.Part1
			if (a == grip and b == part) or (a == part and b == grip) then
				return true
			end
		end
	end
	return false
end

local function ensureWeld(root: Instance, grip: BasePart, part: BasePart, report: { string }?)
	if part == grip or joined(root, grip, part) then
		return
	end
	local weld = Instance.new("WeldConstraint")
	weld.Name = part.Name
	weld.Part0 = grip
	weld.Part1 = part
	weld.Parent = grip
	note(report, `weld {part.Name}`)
end

local function ensureArms(missing: { string }): Model
	local template = findTemplate("Viewmodels", "Arms")
	local rig: Model
	local report: { string }? = missing
	if template == nil then
		rig = Instance.new("Model")
		rig.Name = "Arms"
		table.insert(missing, "arms")
		report = nil
	else
		rig = template:Clone()
	end

	local createdRoot = directPart(rig, "HumanoidRootPart") == nil
	local hrp = ensurePart(rig, "HumanoidRootPart", CFrame.identity, report)
	if createdRoot then
		hrp.Anchored = true
		hrp.CanCollide = false
		hrp.Transparency = 1
	end
	if rig.PrimaryPart == nil then
		rig.PrimaryPart = hrp
		note(report, "PrimaryPart")
	end

	local function limb(name: string, offset: CFrame): BasePart
		local part = ensurePart(rig, name, hrp.CFrame * offset, report)
		ensureMotor(rig, hrp, name, hrp, part, report)
		return part
	end

	limb("LeftArm", CFrame.new(-1.5, 0, 0))
	local right = limb("RightArm", CFrame.new(1.5, 0, 0))

	local attachment = right:FindFirstChild("GripAttachment")
	if attachment == nil or not attachment:IsA("Attachment") then
		attachment = Instance.new("Attachment")
		attachment.Name = "GripAttachment"
		attachment.Parent = right
		note(report, "GripAttachment")
	end

	local controller = rig:FindFirstChildWhichIsA("AnimationController", true)
	if controller == nil then
		controller = Instance.new("AnimationController")
		controller.Parent = rig
		note(report, "AnimationController")
	end
	if controller:FindFirstChildWhichIsA("Animator", true) == nil then
		local animator = Instance.new("Animator")
		animator.Parent = controller
		note(report, "Animator")
	end

	return rig
end

local function ensureGun(modelName: string, missing: { string }): Model
	local template = findTemplate("GunModels", modelName)
	local gun: Model
	local report: { string }? = missing
	if template == nil then
		gun = Instance.new("Model")
		if modelName == "" then
			gun.Name = "Gun"
		else
			gun.Name = modelName
		end
		table.insert(missing, "gun")
		report = nil
	else
		gun = template:Clone()
	end

	local grip = ensurePart(gun, "Grip", CFrame.identity, report)
	if gun.PrimaryPart == nil then
		gun.PrimaryPart = grip
		note(report, "gun PrimaryPart")
	end

	local function partAt(name: string, offset: CFrame): BasePart
		return ensurePart(gun, name, grip.CFrame * offset, report)
	end

	partAt("AimPart", CFrame.new(0, 0, -1))
	partAt("FirePart", CFrame.new(0, 0, -2))
	local mag = partAt("Mag", CFrame.new(0, -0.5, 0))
	local bolt = partAt("Bolt", CFrame.new(0, 0.2, -0.3))
	ensureMotor(gun, grip, "Mag", grip, mag, report)
	ensureMotor(gun, grip, "Bolt", grip, bolt, report)

	for _, child in ipairs(gun:GetChildren()) do
		if child:IsA("BasePart") and child ~= grip and child ~= mag and child ~= bolt then
			ensureWeld(gun, grip, child, report)
		end
	end

	return gun
end

local function barrelC1(grip: BasePart, aim: BasePart, fire: BasePart, attachment: Attachment): CFrame
	local delta = fire.Position - aim.Position
	local localForward = Vector3.new(0, 0, -1)
	if delta.Magnitude >= 1e-4 then
		localForward = grip.CFrame:VectorToObjectSpace(delta.Unit)
	end
	local upHint = Vector3.yAxis
	if math.abs(localForward:Dot(upHint)) > 0.999 then
		upHint = Vector3.xAxis
	end
	local gunLook = CFrame.lookAt(Vector3.zero, localForward, upHint)
	local attachmentCFrame = attachment.CFrame
	local attachmentRotation = attachmentCFrame - attachmentCFrame.Position
	return gunLook * attachmentRotation
end

local function joinGun(rig: Model, gun: Model)
	local right = directPart(rig, "RightArm")
	local grip = directPart(gun, "Grip")
	local aim = directPart(gun, "AimPart")
	local fire = directPart(gun, "FirePart")
	if right == nil or grip == nil or aim == nil or fire == nil then
		error("ViewmodelRig: cannot join the gun")
	end
	local attachment = right:FindFirstChild("GripAttachment")
	if attachment == nil or not attachment:IsA("Attachment") then
		error("ViewmodelRig: GripAttachment is missing")
	end

	gun.Parent = rig
	local previous = right:FindFirstChild("Grip")
	if previous ~= nil and previous:IsA("Motor6D") then
		previous:Destroy()
	end
	local motor = Instance.new("Motor6D")
	motor.Name = "Grip"
	motor.Part0 = right
	motor.Part1 = grip
	motor.C0 = attachment.CFrame
	motor.C1 = barrelC1(grip, aim, fire, attachment)
	motor.Parent = right
end

function ViewmodelRig.build(gunName: string): Model
	local missing = {}
	local modelName = GunConfig.get(gunName).Model
	local rig = ensureArms(missing)
	local gun = ensureGun(modelName, missing)
	joinGun(rig, gun)
	if #missing > 0 then
		warn(`ViewmodelRig: missing {table.concat(missing, ", ")}`)
	end
	return rig
end

local function gunModelOf(rig: Model): Model?
	for _, child in ipairs(rig:GetChildren()) do
		if child:IsA("Model") then
			local grip = directPart(child, "Grip")
			if grip ~= nil then
				return child
			end
		end
	end
	return nil
end

function ViewmodelRig.validate(rig: Model): (boolean, string?)
	for _, desc in ipairs(rig:GetDescendants()) do
		if desc:IsA("LuaSourceContainer") then
			return false, `{desc.Name} is a script`
		end
	end

	local hrp = directPart(rig, "HumanoidRootPart")
	if hrp == nil or rig.PrimaryPart ~= hrp then
		return false, "PrimaryPart is not HumanoidRootPart"
	end
	if not hrp.Anchored or hrp.CanCollide or hrp.Transparency ~= 1 then
		return false, "HumanoidRootPart must be anchored, invisible, and non-colliding"
	end

	local function limbProblem(name: string): string?
		local part = directPart(rig, name)
		if part == nil then
			return `{name} is missing`
		end
		if part.CanCollide or part.CanQuery or part.CanTouch then
			return `{name} must ignore collision`
		end
		local motor = hrp:FindFirstChild(name)
		if motor == nil or not motor:IsA("Motor6D") or motor.Part0 ~= hrp or motor.Part1 ~= part then
			return `{name} motor is missing`
		end
		return nil
	end

	local leftProblem = limbProblem("LeftArm")
	if leftProblem ~= nil then
		return false, leftProblem
	end
	local rightProblem = limbProblem("RightArm")
	if rightProblem ~= nil then
		return false, rightProblem
	end

	local right = directPart(rig, "RightArm")
	if right == nil then
		return false, "RightArm is missing"
	end
	local attachment = right:FindFirstChild("GripAttachment")
	if attachment == nil or not attachment:IsA("Attachment") then
		return false, "GripAttachment is missing"
	end

	local controller = rig:FindFirstChildWhichIsA("AnimationController", true)
	if controller == nil then
		return false, "AnimationController is missing"
	end
	if controller:FindFirstChildWhichIsA("Animator", true) == nil then
		return false, "Animator is missing"
	end

	local gun = gunModelOf(rig)
	if gun == nil then
		return false, "gun is missing"
	end
	local grip = directPart(gun, "Grip")
	if grip == nil or gun.PrimaryPart ~= grip then
		return false, "Grip is not the gun PrimaryPart"
	end
	if directPart(gun, "AimPart") == nil then
		return false, "AimPart is missing"
	end
	if directPart(gun, "FirePart") == nil then
		return false, "FirePart is missing"
	end

	local function motorProblem(name: string): string?
		local part = directPart(gun, name)
		if part == nil then
			return `{name} is missing`
		end
		local motor = findMotor(gun, name)
		if motor == nil or motor.Part0 ~= grip or motor.Part1 ~= part then
			return `{name} motor is missing`
		end
		return nil
	end

	local magProblem = motorProblem("Mag")
	if magProblem ~= nil then
		return false, magProblem
	end
	local boltProblem = motorProblem("Bolt")
	if boltProblem ~= nil then
		return false, boltProblem
	end

	for _, desc in ipairs(rig:GetDescendants()) do
		if desc:IsA("BasePart") and desc ~= hrp and desc.Anchored then
			return false, `{desc.Name} is anchored`
		end
	end

	for _, desc in ipairs(gun:GetDescendants()) do
		if desc:IsA("BasePart") and not joined(gun, grip, desc) then
			return false, `{desc.Name} is not joined to Grip`
		end
	end

	local gripMotor = right:FindFirstChild("Grip")
	if gripMotor == nil or not gripMotor:IsA("Motor6D") or gripMotor.Part0 ~= right or gripMotor.Part1 ~= grip then
		return false, "Grip motor is missing"
	end

	return true, nil
end

function ViewmodelRig.sightCFrame(rig: Model): CFrame
	local gun = gunModelOf(rig)
	local aim = if gun ~= nil then directPart(gun, "AimPart") else nil
	local fire = if gun ~= nil then directPart(gun, "FirePart") else nil
	local grip = if gun ~= nil then directPart(gun, "Grip") else nil
	if aim == nil or fire == nil or grip == nil then
		error("ViewmodelRig: sight parts are missing")
	end
	return CFrame.lookAt(aim.Position, fire.Position, grip.CFrame.UpVector)
end

return ViewmodelRig
