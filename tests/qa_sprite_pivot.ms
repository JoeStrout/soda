// qa_sprite_pivot.ms -- Sprite.pivot positions, rotates, and scales the sprite
// around the given fraction of its image, and worldBounds/corners agree.
import "soda"
import "qa"
rl = raylib
// This test draws with raylib directly, so first close any PixelDisplay
// drawing bracket (left open in replace blend mode, e.g. by drawing to gfx).
PixelDisplay._closeBracket
img = Image.create(20, 10, color.red)	// 20 wide, 10 tall
W = Display.screenWidth; H = Display.screenHeight
rt = rl.LoadRenderTexture(W, H)
d = SpriteDisplay.Make

mk = function(pivot=null)
	s = new Sprite
	s.image = img; s.x = 50; s.y = 50
	if pivot != null then s.pivot = pivot
	return s
end function

// Render the sprite, then check that each of the `red` points is covered
// and each of the `black` points is not (display coordinates, y up).
check = function(name, s, red, black)
	d.sprites = [s]
	rl.BeginTextureMode rt
	rl.ClearBackground "#000000FF"
	d.render
	rl.EndTextureMode
	im = rl.LoadImageFromTexture(rt.texture)
	rl.ImageFlipVertical im
	for p in red
		qa.assertEqual rl.GetImageColor(im, p[0], H - 1 - p[1]).r, 255, name + " red at " + p
	end for
	for p in black
		qa.assertEqual rl.GetImageColor(im, p[0], H - 1 - p[1]).r, 0, name + " black at " + p
	end for
	rl.UnloadImage im
	print "  OK: " + name
end function

roundPts = function(pts)
	result = []
	for p in pts
		result.push [round(p[0], 3), round(p[1], 3)]
	end for
	return result
end function

qa.assertEqual Sprite.pivot, [0.5, 0.5], "default pivot"

// Drawing (image spans 20x10 around its pivot)
check "default pivot", mk, [[50,50], [59,54], [41,46]], [[61,50], [50,56]]
check "pivot [0,0]", mk([0,0]), [[51,51], [69,59]], [[49,49], [51,61], [71,51]]
check "pivot [1,1]", mk([1,1]), [[31,41], [49,49]], [[51,51], [29,45]]
s = mk([0,0]); s.rotation = 90
check "pivot [0,0], rotated 90", s, [[45,65], [41,51]], [[55,55], [45,45]]
s = mk([0,0]); s.scale = 2
check "pivot [0,0], scale 2", s, [[85,65], [51,51]], [[95,55], [85,75]]
s = mk([0,0]); s.scale = [-1, 1]
check "pivot [0,0], flipped X", s, [[35,55]], [[55,55]]
s = mk([0,0]); s.scale = [1, -1]
check "pivot [0,0], flipped Y", s, [[65,45]], [[65,55]]
s = mk([0,0]); s.srcRect = [0, 0, 10, 10]
check "pivot [0,0] with srcRect", s, [[59,59]], [[65,55], [45,45]]
s = mk([0,0]); s.setUVs [[0,0], [1,0], [1,1], [0,1]]
check "pivot [0,0], warped path", s, [[51,51], [69,59]], [[49,49], [71,51]]
s = mk([0,0]); s.setUVs [[0,0], [1,0], [1,1], [0,1]]; s.rotation = 90
check "pivot [0,0], warped path, rotated 90", s, [[45,65]], [[55,55]]

// Corners
s = mk
qa.assertEqual roundPts(s.corners), [[40,45], [60,45], [60,55], [40,55]], "default corners"
s = mk([0,0])
qa.assertEqual roundPts(s.corners), [[50,50], [70,50], [70,60], [50,60]], "pivot [0,0] corners"
s = mk([0,0]); s.rotation = 90
qa.assertEqual roundPts(s.corners), [[50,50], [50,70], [40,70], [40,50]], "pivot [0,0] rotated corners"
s = mk([0.25, 0.75]); s.rotation = 30; s.scale = [2, 3]
s.setCorners s.corners
qa.assertEqual roundPts(s.localCorners), [[-5,-7.5], [15,-7.5], [15,2.5], [-5,2.5]], "setCorners round trip"

s = mk([0,0]); s.localCorners = [[0,0], [20,0], [20,10], [0,10]]
s.pivot = [1,1]	// localCorners are pivot-relative, so changing the pivot doesn't move them
qa.assertEqual roundPts(s.corners), [[50,50], [70,50], [70,60], [50,60]], "explicit localCorners"
print "  OK: corners"

// World bounds
s = mk; s.addBounds
b = s.worldBounds
qa.assertEqual [b.x, b.y, b.width, b.height], [50, 50, 20, 10], "default worldBounds"
s = mk([0,0]); s.addBounds
b = s.worldBounds
qa.assertEqual [b.x, b.y, b.width, b.height], [60, 55, 20, 10], "pivot [0,0] worldBounds"
qa.assertEqual s.contains(69, 59), true, "pivot [0,0] contains"
qa.assertEqual s.contains(49, 49), false, "pivot [0,0] excludes"
s.rotation = 90; s.scale = 2
b = s.worldBounds
qa.assertEqual [round(b.x, 3), round(b.y, 3), b.width, b.height, b.rotation],
	[40, 70, 40, 20, 90], "pivot [0,0] rotated, scaled worldBounds"
qa.assertEqual s.contains(35, 85), true, "rotated/scaled contains"
qa.assertEqual s.contains(55, 55), false, "rotated/scaled excludes"
s = mk([0,0]); s.addBounds
qa.assertEqual [s.localBounds.x, s.localBounds.y], [10, 5], "addBounds is pivot-relative"
s.scale = [-1, -2]
b = s.worldBounds
qa.assertEqual [b.x, b.y, b.width, b.height], [40, 40, 20, 20], "flipped worldBounds"
qa.assertEqual s.contains(35, 35), true, "flipped contains"
qa.assertEqual s.contains(55, 55), false, "flipped excludes"
s = mk([0,0]); s.localBounds = new Bounds; s.localBounds.width = 4; s.localBounds.height = 4
b = s.worldBounds
qa.assertEqual [b.x, b.y], [50, 50], "localBounds at 0,0 is centered on the pivot"
print "  OK: worldBounds"

print "ALL PASSED"
exit
