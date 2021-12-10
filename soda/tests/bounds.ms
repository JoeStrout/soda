// Various tests of the Bounds class.

fileInFolder = function(folderName, fileName)
	if not file.exists(folderName) then
		print "Folder """ + folderName + """ not found."
		exit
	end if
	return file.child(folderName, fileName)
end function

checkCount = 0
failCount = 0

assert = function(cond)
	outer.checkCount = checkCount + 1
	if cond then return
	outer.failCount = failCount + 1
	print "Assertion failed."
	// (ToDo: get stackTrace function working, so we can show where!)
end function

b1 = new Bounds
b1.x = 200
b1.y = 50
b1.width = 70
// (default height = 100)

assert b1.contains(234, 99)
assert not b1.contains(236, 99)
assert not b1.contains(234, 102)

b2 = new Bounds
b2.x = 150
b2.y = 50
b2.width = 35
assert b1.overlaps(b2)
assert b2.overlaps(b1)
b2.y = 160
assert not b1.overlaps(b2)
assert not b2.overlaps(b1)

print "Checks:   " + checkCount
print "Failures: " + failCount
print

sp1 = new Sprite
sp1.image = file.loadImage(fileInFolder("images", "SquareThin.png"))
sprites.push sp1
sp1.bounds = new Bounds
sp1.bounds.width = sp1.image.width
sp1.bounds.height = sp1.image.height

sp2 = new Sprite
sp2.image = sp1.image
sp2.x = 300
sp2.y = 200
sp2.rotation = 30
sprites.push sp2

sp2.bounds = new Bounds
sp2.bounds.width = sp2.image.width
sp2.bounds.height = sp2.image.height
sp2.bounds.x = sp2.x
sp2.bounds.y = sp2.y
sp2.bounds.rotation = sp2.rotation

print "Use axis inputs to move, Q/E to rotate."
speed = 20
while not key.pressed("escape")
	sp1.x = sp1.x + speed * key.axis("Horizontal")
	sp1.y = sp1.y + speed * key.axis("Vertical")
	if key.pressed("q") then sp1.rotation = sp1.rotation - 5
	if key.pressed("e") then sp1.rotation = sp1.rotation + 5
	
	sp1.bounds.x = sp1.x
	sp1.bounds.y = sp1.y
	sp1.bounds.rotation = sp1.rotation
	
	if sp1.bounds.overlaps(sp2.bounds) then
		sp1.tint = "#FF0000"
	else
		sp1.tint = "#FFFFFF"
	end if
	if sp2.bounds.overlaps(sp1.bounds) then
		sp2.tint = "#00FF00"
	else
		sp2.tint = "#FFFFFF"
	end if
	
	wait 0.01
end while

