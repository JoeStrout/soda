// Bouncy-balls sprite demo.

bounceSnd = file.loadSound("sounds/bongo.wav")

Ball = new Sprite
Ball.image = file.loadImage("images/soda-128.png")
Ball.scale = 0.5
Ball.vx = 0
Ball.vy = 0
Ball.vrot = 0
Ball.update = function()
	self.vy = self.vy - 1
	self.x = self.x + self.vx
	self.y = self.y + self.vy
	self.rotation = self.rotation + self.vrot * sign(self.vx)
	if self.x < 30 or self.x > 930 then self.vx = -self.vx
	if self.y < 30 and self.vy < 0 then
		// bounce!
		self.y = 30
		self.vy = -self.vy
		vol = self.vy / 20; if vol > 1 then vol = 1
		pan = (self.x - 480)/480
		speed = 0.9 + 0.2*rnd
		bounceSnd.play vol, pan, speed
	end if
end function
	
for i in range(5)
	b = new Ball
	b.x = 30 + 900*rnd
	b.y = 320 + 320*rnd
	b.vx = 20 * (rnd - 0.5)
	b.vrot = 30 * rnd
	//print "created ball at " + b.x + ", " + b.y
	sprites.push b
end for

while true
	for ball in sprites
		ball.update
	end for
	yield
end while