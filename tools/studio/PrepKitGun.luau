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
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Parent = model
		end
	end
	clone:Destroy()
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
			if desc ~= grip then
				local joint =
					Instance.new(if desc.Name == "Mag" or desc.Name == "Bolt" then "Motor6D" else "WeldConstraint")
				joint.Name = desc.Name
				joint.Part0 = grip
				joint.Part1 = desc
				if joint:IsA("Motor6D") then
					joint.C0 = grip.CFrame:ToObjectSpace(desc.CFrame)
					joint.C1 = CFrame.identity
				end
				joint.Parent = grip
			end
		elseif
			desc:IsA("LuaSourceContainer")
			or desc:IsA("RemoteEvent")
			or desc:IsA("RemoteFunction")
			or desc:IsA("JointInstance")
			or desc:IsA("WeldConstraint")
		then
			desc:Destroy()
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
