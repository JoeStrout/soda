// Testing the window module, which lets you move/resize/full-screen the window.

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

Ball = new Sprite
Ball.image = file.loadImage(fileInFolder("images", "soda-128.png"))
display(4).sprites.push Ball
bg = display(7)

while true
	dw = key.axis("Horizontal") * 10
	if dw != 0 then window.setSize(window.width + dw, window.height)
	dh = key.axis("Vertical") * 10
	if dh != 0 then window.setSize(window.width, window.height + dh)
	if key.pressed("space") then
		while key.pressed("space"); yield; end while	// (wait for key-up)
		window.setFullScreen not window.fullScreen
	end if
	
	if key.pressed("r") then bg.color = "#FF8888"
	if key.pressed("g") then bg.color = "#88FF88"
	if key.pressed("b") then bg.color = "#8888FF"		
	
	Ball.x = window.width
	Ball.y = window.height
	
	yield
end while
