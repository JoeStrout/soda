// key.pressed test

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

sp = new Sprite
sp.image = file.loadImage(fileInFolder("images", "soda-128.png"))
display(4).sprites.push sp
speed = 10
while true
	if key.pressed("left") then sp.x = sp.x - speed
	if key.pressed("right") then sp.x = sp.x + speed
	if key.pressed("down") then sp.y = sp.y - speed
	if key.pressed("up") then sp.y = sp.y + speed
	if key.pressed("left cmd") then sp.x = 0
	if key.pressed("right cmd") then sp.x = 960
	if key.pressed("mouse 0") then sp.y = 0
	if key.pressed("mouse 1") then sp.y = 640
	if key.pressed("tab") then print display(4).sprites
	wait 0.01
end while
