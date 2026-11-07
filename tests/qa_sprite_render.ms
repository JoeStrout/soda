// qa_sprite_render.ms -- SpriteDisplay.render pixel regression test.
// Renders a fixed scene (plain, rotated, flipped, tinted, srcRect, warped-quad
// sprites interleaved with plain ones, nested lists) into an offscreen
// texture and compares it with tests/qa_sprite_render_ref.png.
// Usage (from tests/): <host> qa_sprite_render.ms [record]
//   "record" regenerates the reference image (do this only against code
//   known to render correctly).
import "soda"
import "qa"
rl = raylib

W = Display.screenWidth; H = Display.screenHeight
refPath = "qa_sprite_render_ref.png"

// 16x16 image with a distinct color at every pixel, so UV/orientation errors show
img = Image.create(16, 16, color.clear)
for y in range(0, 15)
	for x in range(0, 15)
		img.setPixel x, y, color.rgba(x*16, y*16, 128 + (x+y)*4, 255)
	end for
end for

mk = function(x, y)
	s = new Sprite
	s.image = img
	s.x = x; s.y = y
	return s
end function

list1 = []
list1.push mk(40, 40)
s = mk(100, 40); s.rotation = 30; list1.push s
s = mk(160, 40); s.scale = [2, -1]; list1.push s
s = mk(220, 40); s.scale = 2.5; s.tint = "#FF8080FF"; list1.push s
s = mk(280, 40); s.srcRect = [4, 4, 8, 8]; s.scale = 3; list1.push s
// warped quads, interleaved with plain sprites to check draw order
s = mk(60, 140); s.setUVs [[0,0],[1,0],[1,1],[0,1]]; s.scale = 2; list1.push s
s = mk(100, 140); list1.push s    // plain, between two quads
s = mk(140, 140); s.setUVs [[1,0],[1,1],[0,1],[0,0]]; s.scale = 2; list1.push s
s = mk(200, 140); s.setCorners [[170,110],[230,125],[225,175],[175,160]]; list1.push s
s = mk(280, 140); s.setCorners [[255,115],[305,115],[320,170],[250,170]]
s.setUVs [[0,0],[1,0],[1,1],[0,1]]; s.tint = [255,255,128,255]; list1.push s
nested = [[mk(60, 240)], [mk(120, 240)]]
nested[0][0].rotation = 45
s = mk(180, 240); s.setUVs [[0,0.5],[0.5,0.5],[0.5,1],[0,1]]; s.rotation = 20; s.scale = [3, 2]; nested[1].push s
s = mk(240, 240); s.setUVs [[0,0],[1,0],[1,1],[0,1]]; s.tint = "#80FF80C0"; s.scale = 2; nested.push s

d = SpriteDisplay.Make
d.sprites = [list1, nested]

rt = rl.LoadRenderTexture(W, H)
rl.BeginTextureMode rt
rl.ClearBackground "#203040FF"
d.render
rl.EndTextureMode
got = rl.LoadImageFromTexture(rt.texture)
rl.ImageFlipVertical got

if shellArgs.len > 1 and shellArgs[1] == "record" then
	rl.ExportImage got, refPath
	print "Recorded " + refPath
	exit
end if

ref = rl.LoadImage(refPath)
// Warped quads sample at slightly different float positions depending on how
// the homogeneous texcoords are computed, which flips single pixels on texel
// boundaries by one texel.  Compare 8x8 block means instead of single pixels:
// that ignores boundary jitter but still catches a wrong UV orientation,
// shift, tint, draw order, or a missing sprite.
bad = 0
for by in range(0, H/8 - 1)
	for bx in range(0, W/8 - 1)
		sa = [0,0,0,0]; sb = [0,0,0,0]
		for y in range(by*8, by*8 + 7)
			for x in range(bx*8, bx*8 + 7)
				a = rl.GetImageColor(got, x, y); b = rl.GetImageColor(ref, x, y)
				sa[0] = sa[0] + a.r; sa[1] = sa[1] + a.g; sa[2] = sa[2] + a.b; sa[3] = sa[3] + a.a
				sb[0] = sb[0] + b.r; sb[1] = sb[1] + b.g; sb[2] = sb[2] + b.b; sb[3] = sb[3] + b.a
			end for
		end for
		for k in range(0, 3)
			if abs(sa[k] - sb[k]) / 64 > 6 then bad = bad + 1; break
		end for
	end for
end for
qa.assertEqual bad, 0, "8x8 blocks differing from reference"
print "ALL PASSED"
exit
