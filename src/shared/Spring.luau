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
	dt = math.min(dt, 1 / 30)
	local speed = self.speed
	local acceleration = (self.target - self.position) * (speed * speed) - self.velocity * (2 * self.damper * speed)
	self.velocity += acceleration * dt
	self.position += self.velocity * dt
	return self.position
end

return Spring
