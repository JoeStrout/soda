// Testing mouse position and mouse buttons.

// Soda test!

Subclass = new Sprite
Subclass.scale = 0.5
Subclass.tint = "#008800"
Subclass.image = file.loadImage("images/soda-128.png")

sp = new Subclass
sp.x = 150; sp.y = 200
sprites.push sp
speed = 10
while true
	sp.x = mouse.x
	sp.y = mouse.y
	if mouse.button then
		sp.tint = "#00FF00"
	else if mouse.button(1) then
		sp.tint = "#FF00FF"
	else
		sp.tint = "#FFFFFF"
	end if
	yield
end while
