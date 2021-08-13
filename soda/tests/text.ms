// Tests of Soda's built-in text display.

print "Hello world!"
print "This text is printed with the `print` command."
tab = char(9)
print "A" + tab + "B" + tab + "C"
print
print "Press Return to clear the screen."

while not key.pressed("return") and not key.pressed("enter")
	yield
end while

clear

trows = text.rows
tcols = text.columns

while key.pressed("return") or key.pressed("enter")
	dw = key.axis("Horizontal") * 10
	if dw != 0 then window.width = window.width + dw
	dh = key.axis("Vertical") * 10
	if dh != 0 then window.height = window.height + dh
	if key.pressed("space") then
		while key.pressed("space"); yield; end while	// (wait for key-up)
		window.fullScreen = not window.fullScreen
	end if

	if text.columns != tcols or text.rows != trows then
		trows = text.rows; tcols = text.columns
		print "Text display: " + tcols + " x " + trows
	end if

	yield
end while

print "And now the screen is clear.  :)"
while not key.pressed("escape"); yield; end while


