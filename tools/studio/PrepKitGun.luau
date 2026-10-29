local function countEffects(root: Instance): (number, number)
	local sounds = 0
	local emitters = 0
	for _, desc in ipairs(root:GetDescendants()) do
		if desc:IsA("Sound") then
			sounds += 1
		elseif desc:IsA("ParticleEmitter") then
			emitters += 1
		end
	end
	return sounds, emitters
end

local function destroyOfClass(root: Instance, className: string)
	local doomed = {}
	for _, desc in ipairs(root:GetDescendants()) do
		if desc:IsA(className) then
			table.insert(doomed, desc)
		end
	end
	for _, desc in ipairs(doomed) do
		desc:Destroy()
	end
end

local function prepKitGun(toolName: string): Model
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local studioWorkspace = game:GetService("Workspace")
	local tool = studioWorkspace:FindFirstChild(toolName)
	if tool == nil or not tool:IsA("Tool") then
		error(`PrepKitGun: Workspace.{toolName} Tool is missing`)
	end

	local soundsBefore, emittersBefore = countEffects(tool)
	local clone = tool:Clone()
	local model = Instance.new("Model")
	model.Name = toolName

	local parts = {}
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("BasePart") then
			table.insert(parts, desc)
		end
	end
	for _, part in ipairs(parts) do
		part.Parent = model
	end
	clone:Destroy()

	destroyOfClass(model, "LuaSourceContainer")
	destroyOfClass(model, "RemoteEvent")
	destroyOfClass(model, "RemoteFunction")
	destroyOfClass(model, "JointInstance")
	destroyOfClass(model, "WeldConstraint")

	local grip = model:FindFirstChild("Grip")
	if grip == nil or not grip:IsA("BasePart") then
		error(`PrepKitGun: {toolName} has no Grip part`)
	end
	model.PrimaryPart = grip

	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = false
			desc.CanCollide = false
			desc.CanQuery = false
			desc.CanTouch = false
			desc.Massless = true
		end
	end

	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child ~= grip then
			if child.Name == "Mag" or child.Name == "Bolt" then
				local motor = Instance.new("Motor6D")
				motor.Name = child.Name
				motor.Part0 = grip
				motor.Part1 = child
				motor.C0 = grip.CFrame:ToObjectSpace(child.CFrame)
				motor.C1 = CFrame.identity
				motor.Parent = grip
			else
				local weld = Instance.new("WeldConstraint")
				weld.Name = child.Name
				weld.Part0 = grip
				weld.Part1 = child
				weld.Parent = grip
			end
		end
	end

	local gunModels = replicatedStorage:FindFirstChild("GunModels")
	if gunModels == nil then
		gunModels = Instance.new("Folder")
		gunModels.Name = "GunModels"
		gunModels.Parent = replicatedStorage
	end
	local existing = gunModels:FindFirstChild(toolName)
	if existing ~= nil then
		existing:Destroy()
	end
	model.Parent = gunModels

	local soundsAfter, emittersAfter = countEffects(model)
	print(`PrepKitGun: {toolName} sounds {soundsBefore} -> {soundsAfter}, emitters {emittersBefore} -> {emittersAfter}`)
	return model
end

return prepKitGun
