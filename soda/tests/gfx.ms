// Test functionality of the default PixelDisplay (gfx).

colors = [
"#00000000", "#000000", "#FFFFFF", "#808080", 
"#C0C0C0", "#800000", "#FF0000", "#808000", 
"#FFFF00", "#FF8000", "#008000", "#00FF00", 
"#008080", "#00FFFF", "#000080", "#0000FF", 
"#800080", "#FF00FF", "#996633", "#FF8080"]

gfx.clear

while true
	left = floor(rnd * 800)
	width = floor(rnd * (960 - left))
	bottom = floor(rnd * 500)
	height = floor(rnd * (640 - bottom))
	c = colors[rnd * colors.len]
	if rnd < 0.5 then
		gfx.fillRect left, bottom, width, height, c
	else
		gfx.fillEllipse left, bottom, width, height, c
	end if
	yield
end while