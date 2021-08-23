// Soda test!

sp = new Sprite
sp.image = file.loadImage("images/soda-128.png")
sprites.push sp
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
	wait 0.01
end while
