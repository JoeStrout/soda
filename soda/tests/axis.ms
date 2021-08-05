// Test app for key.axis

Ball = new Sprite
Ball.image = file.loadImage("images/soda-128.png")
sprites.push Ball

while true
	Ball.x = 480 + 400 * key.axis("Horizontal")	// or key.axis("JoyAxis1"), etc.
	Ball.y = 320 + 240 * key.axis("Vertical")
	
	if key.pressed("joystick button 0") then Ball.x = Ball.x + 50;	// "A" button
	if key.pressed("joystick button 1") then Ball.y = Ball.y - 50;	// "B" button
	if key.pressed("joystick button 2") then Ball.y = Ball.y + 50;	// "X" button
	if key.pressed("joystick button 3") then Ball.x = Ball.x - 50;	// "Y" button

	for btn in range(0, 20)
		if key.pressed("joystick button " + btn) then print "joystick button " + btn
	end for
	
	yield
end while
