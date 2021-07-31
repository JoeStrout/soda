// Bouncy-balls sprite demo.

Ball = new Sprite
Ball.image = loadImage("images/soda-128.png")
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
	if self.y < 30 then self.vy = abs(self.vy)
end function
	
for i in range(5)
	b = new Ball
	b.x = 960*rnd
	b.y = 400 + 200*rnd
	b.vx = 20 * (rnd - 0.5)
	b.vrot = 30 * rnd
	sprites.push b
end for

while true
	for ball in sprites
		ball.update
	end for
	wait 0.01
end while