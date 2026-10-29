local ViewmodelAnimations = {}

type Group = "base" | "movement" | "action"

type Policy = {
	looped: boolean,
	priority: Enum.AnimationPriority,
	group: Group,
}

type Clip = {
	track: AnimationTrack,
	animation: Animation,
	policy: Policy,
	fadingOut: boolean,
}

local POLICY: { [string]: Policy } = {
	Idle = { looped = true, priority = Enum.AnimationPriority.Idle, group = "base" },
	Walk = { looped = true, priority = Enum.AnimationPriority.Movement, group = "movement" },
	Sprint = { looped = true, priority = Enum.AnimationPriority.Movement, group = "movement" },
	Equip = { looped = false, priority = Enum.AnimationPriority.Action, group = "action" },
	Fire = { looped = false, priority = Enum.AnimationPriority.Action2, group = "action" },
	Reload = { looped = false, priority = Enum.AnimationPriority.Action3, group = "action" },
	Slide = { looped = false, priority = Enum.AnimationPriority.Action4, group = "action" },
}

local DEFAULT_FADE = 0.1
local DEFAULT_SPEED = 1

export type ViewmodelAnimations = {
	play: (self: ViewmodelAnimations, name: string, fadeTime: number?, speed: number?) -> (),
	stop: (self: ViewmodelAnimations, name: string, fadeTime: number?) -> (),
	isPlaying: (self: ViewmodelAnimations, name: string) -> boolean,
	destroy: (self: ViewmodelAnimations) -> (),
}

function ViewmodelAnimations.new(animator: Animator, ids: { [string]: any }): ViewmodelAnimations
	local clips: { [string]: Clip } = {}
	local known: { [string]: boolean } = {}
	local warned: { [string]: boolean } = {}
	local skipped: { string } = {}

	for name, id in pairs(ids) do
		known[name] = true
		local policy = POLICY[name]
		if policy == nil or type(id) ~= "string" or id == "" or id == "rbxassetid://0" then
			table.insert(skipped, name)
		else
			local animation = Instance.new("Animation")
			animation.Name = name
			animation.AnimationId = id
			animation.Parent = animator
			local track = animator:LoadAnimation(animation)
			track.Looped = policy.looped
			track.Priority = policy.priority
			clips[name] = {
				track = track,
				animation = animation,
				policy = policy,
				fadingOut = false,
			}
		end
	end

	table.sort(skipped)
	if #skipped > 0 then
		warn(`ViewmodelAnimations: skipped {table.concat(skipped, ", ")}`)
	end

	local api = {} :: ViewmodelAnimations

	function api:play(name: string, fadeTime: number?, speed: number?)
		local clip = clips[name]
		if clip == nil then
			if not known[name] and not warned[name] then
				warned[name] = true
				warn(`ViewmodelAnimations: unknown {name}`)
			end
			return
		end
		if fadeTime == nil then
			fadeTime = DEFAULT_FADE
		end
		if speed == nil then
			speed = DEFAULT_SPEED
		end
		if clip.policy.looped and clip.track.IsPlaying and not clip.fadingOut then
			return
		end
		if clip.policy.group ~= "base" then
			for otherName, other in pairs(clips) do
				if otherName ~= name and other.policy.group == clip.policy.group and other.track.IsPlaying then
					other.fadingOut = true
					other.track:Stop(fadeTime)
				end
			end
		end
		clip.fadingOut = false
		clip.track:Play(fadeTime, 1, speed)
	end

	function api:stop(name: string, fadeTime: number?)
		local clip = clips[name]
		if clip == nil or clip.fadingOut or not clip.track.IsPlaying then
			return
		end
		if fadeTime == nil then
			fadeTime = DEFAULT_FADE
		end
		clip.fadingOut = true
		clip.track:Stop(fadeTime)
	end

	function api:isPlaying(name: string): boolean
		local clip = clips[name]
		return clip ~= nil and clip.track.IsPlaying
	end

	function api:destroy()
		for _, clip in pairs(clips) do
			clip.track:Stop(0)
			clip.track:Destroy()
			clip.animation:Destroy()
		end
		table.clear(clips)
	end

	return api
end

return ViewmodelAnimations
