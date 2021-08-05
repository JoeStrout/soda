// Test app for key.axis

Ball = new Sprite
Ball.image = file.loadImage("images/soda-128.png")
sprites.push Ball

while true
	Ball.x = 480 + 400 * key.axis("Horizontal")	// or key.axis("JoyAxis1"), etc.
	Ball.y = 320 + 240 * key.axis("Vertical")
	yield
end while
