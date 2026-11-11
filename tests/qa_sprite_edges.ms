// qa_sprite_edges.ms -- odd-but-legal Sprite settings must render without error
// and with sensible output (checked at the sprite's center pixel).
import "soda"
import "qa"
rl = raylib
img = Image.create(16, 16, color.red)
W = Display.screenWidth; H = Display.screenHeight
rt = rl.LoadRenderTexture(W, H)
d = SpriteDisplay.Make

mk = function
	s = new Sprite
	s.image = img; s.x = 50; s.y = 50
	return s
end function

centerRed = function(sprites)
	d.sprites = sprites
	rl.BeginTextureMode rt
	rl.ClearBackground "#000000FF"
	d.render
	rl.EndTextureMode
	im = rl.LoadImageFromTexture(rt.texture)
	rl.ImageFlipVertical im
	c = rl.GetImageColor(im, 50, H - 50)
	rl.UnloadImage im
	return c.r
end function

check = function(name, s, expectRed)
	qa.assertEqual centerRed([s]), expectRed, name
	print "  OK: " + name
end function

s = mk; s.scale = 0; check "scale 0 draws nothing", s, 0
s = mk; s.scale = [0, 2]; check "scale [0,2] draws nothing", s, 0
s = mk; s.scale = -2; check "negative scale flips", s, 255
s = mk; s.scale = [2, -3]; check "list scale with flip", s, 255
s = mk; s.srcRect = [100, 100, 16, 16]; check "srcRect outside image", s, 255
s = mk; s.srcRect = [-8, -8, 16, 16]; check "srcRect partly negative", s, 255
s = mk; s.image = null; check "null image skipped", s, 0
s = mk; s.tint = null; check "null tint", s, 255
s = mk; s.tint = "bogus"; check "bogus tint", s, 255
s = mk; s.setUVs [[0,0],[0,0],[0,0],[0,0]]; check "degenerate uvs", s, 0
s = mk; s.setCorners [[0,0],[0,0],[0,0],[0,0]]; check "degenerate corners", s, 0
s = mk; s.scale = 0; s.setUVs [[0,0],[1,0],[1,1],[0,1]]; check "warped sprite, scale 0", s, 0
s = mk; s.scale = 0; s.setCorners [[0,0],[10,0],[10,10],[0,10]]   // must not crash
s = mk
qa.assertEqual centerRed([s, s]), 255, "same sprite twice in one display"
d2 = SpriteDisplay.Make; d2.sprites = [s]
d.sprites = [s]
rl.BeginTextureMode rt
d.render; d2.render
rl.EndTextureMode
print "  OK: sprite in two displays"
// an empty/nested-empty list and a non-Sprite object with its own draw
o = {}; o.draw = function(x, y); outer.drew = true; end function
drew = false
d.sprites = [o, [], [[]]]
rl.BeginTextureMode rt
d.render
rl.EndTextureMode
qa.assertEqual drew, true, "custom draw object is called"
print "ALL PASSED"
exit
