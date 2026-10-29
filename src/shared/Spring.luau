local Spring = {}
Spring.__index = Spring

function Spring.new(initial: Vector3, speed: number, damper: number)
	return setmetatable({
		position = initial,
		velocity = Vector3.zero,
		target = initial,
		speed = speed,
		damper = damper,
	}, Spring)
end

function Spring:setTarget(target: Vector3)
	self.target = target
end

function Spring:impulse(velocity: Vector3)
	self.velocity += velocity
end

function Spring:update(dt: number): Vector3
	local n = math.ceil(dt / (1 / 240))
	if n < 1 then
		return self.position
	end
	local h = dt / n
	local speed = self.speed
	for _ = 1, n do
		local acceleration = (self.target - self.position) * (speed * speed) - self.velocity * (2 * self.damper * speed)
		self.velocity += acceleration * h
		self.position += self.velocity * h
	end
	return self.position
end

return Spring
