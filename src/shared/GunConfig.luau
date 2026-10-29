local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunConfig = {}

GunConfig.Defaults = {
	Model = "",
	Order = 99,
	AnimationIds = {
		Idle = "rbxassetid://0",
		Walk = "rbxassetid://0",
		AdsIn = "rbxassetid://0",
		AdsStatic = "rbxassetid://0",
		Sprint = "rbxassetid://0",
		Equip = "rbxassetid://0",
		Fire = "rbxassetid://0",
		Reload = "rbxassetid://0",
		Slide = "rbxassetid://0",
	},
	Sounds = {
		Fire = "",
		Reload = {},
	},
	HipFov = 70,
	AdsFov = 50,
	AdsSpeed = 16,
	AdsInTime = 0.3,
	AimOffset = CFrame.identity,
	HipOffset = CFrame.identity,
	Bob = {
		Amount = 0.25,
		Speed = 8,
	},
	Sway = {
		Amount = 1,
		Speed = 6,
		Damper = 0.85,
	},
	Recoil = {
		CamSpeed = 22,
		CamDamper = 0.85,
		CamKickPitch = 1.2,
		CamKickYaw = 0.35,
		VmSpeed = 28,
		VmDamper = 0.7,
		VmKickBack = 0.18,
		VmKickUp = 0.03,
		VmKickPitch = 4,
		VmKickRoll = 2.5,
		FirstShotMult = 1.6,
		FirstShotResetTime = 0.25,
		FovPunch = 1.5,
		FovSpeed = 30,
		FovDamper = 0.8,
		AdsKickMult = 0.5,
		FireRate = 600,
	},
	SprintOffset = CFrame.identity,
	Slide = {},
}

local cache = {}

local function merge(base, over)
	local result = {}
	for key, value in pairs(base) do
		if type(value) == "table" then
			result[key] = merge(value, {})
		else
			result[key] = value
		end
	end
	for key, value in pairs(over) do
		if type(value) == "table" and type(result[key]) == "table" then
			result[key] = merge(result[key], value)
		elseif type(value) == "table" then
			result[key] = merge(value, {})
		else
			result[key] = value
		end
	end
	return result
end

local function configModule(gunName: string): ModuleScript
	local guns = ReplicatedStorage:FindFirstChild("Guns")
	if guns == nil then
		error("GunConfig: ReplicatedStorage.Guns is missing")
	end
	for _, child in ipairs(guns:GetChildren()) do
		if child.Name == gunName and child:IsA("ModuleScript") then
			return child
		end
	end
	error(`GunConfig: no ModuleScript named {gunName}`)
end

function GunConfig.get(gunName: string)
	local hit = cache[gunName]
	if hit ~= nil then
		return hit
	end
	local entry = require(configModule(gunName))
	for key in pairs(entry) do
		if GunConfig.Defaults[key] == nil then
			warn(`GunConfig: unknown key "{key}" for {gunName}`)
		end
	end
	local merged = merge(GunConfig.Defaults, entry)
	cache[gunName] = merged
	return merged
end

function GunConfig.list(): { string }
	local names = {}
	local guns = ReplicatedStorage:FindFirstChild("Guns")
	if guns ~= nil then
		for _, child in ipairs(guns:GetChildren()) do
			if child:IsA("ModuleScript") then
				table.insert(names, child.Name)
			end
		end
	end
	table.sort(names, function(a, b)
		local orderA = GunConfig.get(a).Order
		local orderB = GunConfig.get(b).Order
		if orderA ~= orderB then
			return orderA < orderB
		end
		return a < b
	end)
	return names
end

return GunConfig
