// Soda test!

sp = new Sprite
sp.image = file.loadImage("images/soda-128.png")
sprites.push sp
dx = 3
dy = 2
while true
	sp.x = sp.x + dx
	sp.y = sp.y + dy
	if (sp.x > 960 and dx > 0) or (sp.x < 0 and dx < 0) then dx = -dx
	if (sp.y > 640 and dy > 0) or (sp.y < 0 and dy < 0) then dy = -dy
	wait 0.01
end while
