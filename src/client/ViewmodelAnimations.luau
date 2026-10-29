local ViewmodelAnimations = {}

type Clip = {
	priority: Enum.AnimationPriority,
	looped: boolean,
}

local CLIP: { [string]: Clip } = {
	Idle = { priority = Enum.AnimationPriority.Idle, looped = true },
	Walk = { priority = Enum.AnimationPriority.Movement, looped = true },
	Sprint = { priority = Enum.AnimationPriority.Movement, looped = true },
	AdsStatic = { priority = Enum.AnimationPriority.Movement, looped = true },
	Equip = { priority = Enum.AnimationPriority.Action, looped = false },
	SprintIn = { priority = Enum.AnimationPriority.Action, looped = false },
	SprintOut = { priority = Enum.AnimationPriority.Action, looped = false },
	Slide = { priority = Enum.AnimationPriority.Action, looped = true },
	Fire = { priority = Enum.AnimationPriority.Action2, looped = false },
	Reload = { priority = Enum.AnimationPriority.Action3, looped = false },
	ReloadEmpty = { priority = Enum.AnimationPriority.Action3, looped = false },
}

function ViewmodelAnimations.new(animator: Animator, ids: { [string]: any })
	local tracks: { [string]: AnimationTrack } = {}
	local skipped = {}
	for name, id in pairs(ids) do
		local clip = CLIP[name]
		if clip == nil or type(id) ~= "string" or id == "" or id == "rbxassetid://0" then
			table.insert(skipped, name)
		else
			local animation = Instance.new("Animation")
			animation.Name = name
			animation.AnimationId = id
			animation.Parent = animator
			local track = animator:LoadAnimation(animation)
			track.Priority = clip.priority
			track.Looped = clip.looped
			tracks[name] = track
		end
	end
	table.sort(skipped)
	if #skipped > 0 then
		warn(`ViewmodelAnimations: skipped {table.concat(skipped, ", ")}`)
	end
	local api = {}
	function api:play(name: string, fadeTime: number?, speed: number?)
		local track = tracks[name]
		if track ~= nil and not (track.Looped and track.IsPlaying) then
			track:Play(if fadeTime ~= nil then fadeTime else 0.1, 1, if speed ~= nil then speed else 1)
		end
	end
	function api:stop(name: string, fadeTime: number?)
		local track = tracks[name]
		if track ~= nil and track.IsPlaying then
			track:Stop(if fadeTime ~= nil then fadeTime else 0)
		end
	end
	function api:isPlaying(name: string): boolean
		local track = tracks[name]
		return track ~= nil and track.IsPlaying
	end
	function api:destroy()
		for _, track in pairs(tracks) do
			track:Stop(0)
			track:Destroy()
		end
		table.clear(tracks)
	end
	return api
end

return ViewmodelAnimations
