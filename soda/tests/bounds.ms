// Various tests of the Bounds class.

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

print "Checks:   " + checkCount
print "Failures: " + failCount

while not key.pressed("escape"); end while

