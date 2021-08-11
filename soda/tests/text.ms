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

while key.pressed("return") or key.pressed("enter")
	yield
end while

print "And now the screen is clear.  :)"
while not key.pressed("escape"); yield; end while


