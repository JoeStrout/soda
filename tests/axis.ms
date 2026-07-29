// Test app for key.axis

import "soda"

fileInFolder = function(folderName, fileName)
	folderPath = file.child("assets", folderName)
	if not file.exists(folderPath) then
		print "Folder """ + folderPath + """ not found."
		exit
	end if
	filePath = file.child(folderPath, fileName)
	if not file.exists(filePath) then
		print "File """ + filePath + """ not found."
		exit
	end if
	return filePath
end function

print "key.axis and key.pressed Test"
print "Use WASD, arrow keys, or gamepad inputs."
print "See the ball move accordingly."

Ball = new Sprite
Ball.image = file.loadImage(fileInFolder("images", "soda-128.png"))
display(4).sprites.push Ball

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
	
	if key.pressed("space") then print display(4).sprites
	
	yield
end while
