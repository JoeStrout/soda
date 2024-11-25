// Line-drawing test
gfx.color = "#00FF00"
for x in range(0, window.width, 9)
	gfx.line x, 0, window.width - x, window.height
end for
for y in range(0, window.height, 9)
	gfx.line 0, y, window.width, window.height - y, "#4444FF"
end for

while not key.pressed("escape") and not key.pressed("space")
	yield
end while
