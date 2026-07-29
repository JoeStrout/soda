// Soda test!

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
dx = 3
dy = 2
while true
	sp.x += dx
	sp.y += dy
	if (sp.x > 960 and dx > 0) or (sp.x < 0 and dx < 0) then dx = -dx
	if (sp.y > 640 and dy > 0) or (sp.y < 0 and dy < 0) then dy = -dy
	yield // or: wait 0.01
end while
