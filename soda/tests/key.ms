// Soda test!

sp = {"x":150, "y":200}
sprites.push sp
speed = 10
while true
	if key.pressed("left") then sp.x = sp.x - speed
	if key.pressed("right") then sp.x = sp.x + speed
	if key.pressed("down") then sp.y = sp.y - speed
	if key.pressed("up") then sp.y = sp.y + speed
	wait 0.01
end while