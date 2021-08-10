// Testing the window module, which lets you move/resize/full-screen the window.

Ball = new Sprite
Ball.image = file.loadImage("images/soda-128.png")
sprites.push Ball

while true
	dw = key.axis("Horizontal") * 10
	if dw != 0 then window.width = window.width + dw
	dh = key.axis("Vertical") * 10
	if dh != 0 then window.height = window.height + dh
	if key.pressed("space") then
		while key.pressed("space"); yield; end while	// (wait for key-up)
		window.fullScreen = not window.fullScreen
	end if
	
	if key.pressed("r") then window.backColor = "#FF8888"
	if key.pressed("g") then window.backColor = "#88FF88"
	if key.pressed("b") then window.backColor = "#8888FF"		
	
	Ball.x = window.width
	Ball.y = window.height
	
	yield
end while
