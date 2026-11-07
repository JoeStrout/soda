// qa_bounds_overlaps.ms -- Bounds.overlaps / Bounds.contains must agree with the
// original corner-projection SAT implementation (kept here as the reference).
import "soda"
import "qa"

refOverlaps = function(a, b)
	cornersA = a.corners
	cornersB = b.corners
	axes = []
	for corners in [cornersA, cornersB]
		for i in [0, 1]
			j = i + 1
			axes.push [-(corners[j][1] - corners[i][1]), corners[j][0] - corners[i][0]]
		end for
	end for
	for axis in axes
		minA = axis[0] * cornersA[0][0] + axis[1] * cornersA[0][1]
		maxA = minA
		for i in range(1, 3)
			proj = axis[0] * cornersA[i][0] + axis[1] * cornersA[i][1]
			if proj < minA then minA = proj
			if proj > maxA then maxA = proj
		end for
		minB = axis[0] * cornersB[0][0] + axis[1] * cornersB[0][1]
		maxB = minB
		for i in range(1, 3)
			proj = axis[0] * cornersB[i][0] + axis[1] * cornersB[i][1]
			if proj < minB then minB = proj
			if proj > maxB then maxB = proj
		end for
		if maxA < minB or maxB < minA then return false
	end for
	return true
end function

refContains = function(bnds, x, y)
	dx = x - bnds.x
	dy = y - bnds.y
	cosR = cos(-bnds.rotation * pi / 180)
	sinR = sin(-bnds.rotation * pi / 180)
	localX = dx * cosR - dy * sinR
	localY = dx * sinR + dy * cosR
	return abs(localX) <= bnds.width / 2 and abs(localY) <= bnds.height / 2
end function

mk = function(x, y, w, h, rot)
	b = new Bounds
	b.x = x; b.y = y; b.width = w; b.height = h; b.rotation = rot
	return b
end function

checks = 0
check = function(name, a, b)
	outer.checks = checks + 1
	qa.assertEqual a.overlaps(b), refOverlaps(a, b), name + " overlaps(a,b)"
	qa.assertEqual b.overlaps(a), refOverlaps(b, a), name + " overlaps(b,a)"
end function

// exact edge cases (unrotated, so edge contact is exact in both)
a = mk(0, 0, 10, 10, 0)
check "touching right", a, mk(10, 0, 10, 10, 0)
check "touching top", a, mk(0, 10, 10, 10, 0)
check "touching corner", a, mk(10, 10, 10, 10, 0)
check "just apart", a, mk(10.001, 0, 10, 10, 0)
check "inside", a, mk(1, 1, 2, 2, 0)
check "containing", a, mk(0, 0, 100, 100, 0)
check "identical", a, mk(0, 0, 10, 10, 0)
check "far", a, mk(500, -300, 10, 10, 0)
// rotated edge cases
check "diamond vs box, apart", a, mk(12, 0, 10, 10, 45)
check "diamond vs box, overlap", a, mk(9, 0, 10, 10, 45)
check "diamond corner gap", a, mk(7, 7, 4, 4, 45)
check "rotated 90 same", a, mk(0, 0, 10, 10, 90)
check "rotated long thin cross", mk(0, 0, 100, 2, 0), mk(0, 0, 2, 100, 33)
check "rotated both, apart", mk(0, 0, 20, 5, 30), mk(40, 0, 20, 5, -30)
check "A rotated, B inside", mk(0, 0, 50, 10, 70), mk(5, 5, 1, 1, 0)

// random cases
seed = rnd(12345)
n = 0
for i in range(1, 3000)
	a = mk(rnd*100, rnd*100, 1 + rnd*60, 1 + rnd*60, floor(rnd*360))
	if rnd < 0.2 then a.rotation = 0
	b = mk(rnd*100, rnd*100, 1 + rnd*60, 1 + rnd*60, floor(rnd*360))
	if rnd < 0.2 then b.rotation = 0
	qa.assertEqual a.overlaps(b), refOverlaps(a, b), "random #" + i + " overlaps"
	px = rnd*100 - 20; py = rnd*100 - 20
	qa.assertEqual a.contains(px, py), refContains(a, px, py), "random #" + i + " contains"
	qa.assertEqual a.contains([px, py]), refContains(a, px, py), "random #" + i + " contains list"
	if refOverlaps(a, b) then n = n + 1
end for
print "  random overlaps true in " + n + " of 3000 (should be a healthy mix)"
qa.assert n > 300 and n < 2700, "random cases should include both outcomes"

// Sprite-level
s1 = new Sprite; s1.localBounds = mk(0, 0, 10, 10, 0); s1.x = 0; s1.y = 0
s2 = new Sprite; s2.localBounds = mk(0, 0, 10, 10, 0); s2.x = 9; s2.y = 0
qa.assertEqual s1.overlaps(s2), true, "sprite overlaps"
s2.x = 11
qa.assertEqual s1.overlaps(s2), false, "sprite apart"
s2.scale = 3; s2.x = 14
qa.assertEqual s1.overlaps(s2), true, "scaled sprite reaches"
qa.assertEqual s1.contains(4, 4), true, "sprite contains"
qa.assertEqual s1.contains(6, 0), false, "sprite not contains"
print "ALL PASSED"
exit
