// This test is very similar to bounds.ms, except that instead of
// manually updating a Bounds object for each sprite, we give each
// sprite a localBounds, and then test the automatically-updated
// worldBounds.

checkCount = 0
failCount = 0

assert = function(cond)
	outer.checkCount = checkCount + 1
	if cond then return
	outer.failCount = failCount + 1
	print "Assertion failed."
	// (ToDo: get stackTrace function working, so we can show where!)
end function

sp1 = new Sprite
sp1.image = file.loadImage("images/SquareThin.png")
sprites.push sp1
sp1.localBounds = new Bounds
sp1.localBounds.width = sp1.image.width
sp1.localBounds3height = sp1.image.height

sp2 = new Sprite
sp2.image = sp1.image
sp2.x = 300
sp2.y = 200
sp2.rotation = 30
sprites.push sp2
sp2.localBounds = new Bounds
sp2.localBounds.width = sp2.image.width
sp2.localBounds.height = sp2.image.height

assert sp1.worldBounds != null
print "sp1.worldBounds: " + sp1.worldBounds
w = sp1.image.width; h = sp1.image.height
assert sp1.worldBounds.width == w
assert sp1.worldBounds.height == h

assert sp2.worldBounds.x == sp2.x
assert sp2.worldBounds.y == sp2.y
assert sp2.worldBounds.rotation == sp2.rotation

sp1.x = 100

assert sp1.contains(131, 31)
assert not sp1.contains(132, 31)
assert not sp1.contains(131, 32)


print "Checks:   " + checkCount
print "Failures: " + failCount
print


print "Use axis inputs to move, Q/E to rotate."
speed = 20
while not key.pressed("escape")
	sp1.x = sp1.x + speed * key.axis("Horizontal")
	sp1.y = sp1.y + speed * key.axis("Vertical")
	if key.pressed("q") then sp1.rotation = sp1.rotation - 5
	if key.pressed("e") then sp1.rotation = sp1.rotation + 5

	sp1.scale = 1 + 0.5 * sp1.contains(mouse)
	sp2.scale = 1 + 0.5 * sp2.contains(mouse)

	if sp1.overlaps(sp2) then
		sp1.tint = "#FF0000"
	else
		sp1.tint = "#FFFFFF"
	end if
	if sp2.overlaps(sp1) then
		sp2.tint = "#00FF00"
	else
		sp2.tint = "#FFFFFF"
	end if
	
	yield
end while

