// qa_screenfont_draw.ms -- ScreenFont.drawChar must produce mix(back, fore, glyphMask)
// pixels on all paths: the batched fast path (opaque fore, opaque/clear back)
// and the shader path (translucent colors).
import "soda"
import "qa"
rl = raylib

font = TextDisplay.font
sheet = file.loadImage("lib/ScreenFont.png")
w = font.charWidth; h = font.charHeight
rt = rl.LoadRenderTexture(w * 2, h)

drawAndRead = function(ch, fore, back, bg)
	rl.BeginTextureMode rt
	rl.ClearBackground bg
	font.drawChar ch.code, 0, 0, fore, back
	rl.EndTextureMode
	img = rl.LoadImageFromTexture(rt.texture)
	rl.ImageFlipVertical img
	return img
end function

maskAt = function(code, px, py)
	r = font.srcRect(code)
	// sheet is Soda Image (bottom-up); use raylib image directly
	c = rl.GetImageColor(sheet._img, r[0] + px, r[1] + py)
	return c.a > 127
end function

check = function(name, fore, back, bg)
	img = drawAndRead("A", fore, back, bg)
	f = color.toList(fore); b = color.toList(back); g = color.toList(bg)
	bad = 0
	for py in range(0, h - 1)
		for px in range(0, w - 1)
			got = rl.GetImageColor(img, px, py)
			got = [got.r, got.g, got.b, got.a]
			if maskAt(65, px, py) then exp = f else exp = b
			// composite exp over bg (alpha blend)
			a = exp[3] / 255
			want = [round(exp[0]*a + g[0]*(1-a)), round(exp[1]*a + g[1]*(1-a)), round(exp[2]*a + g[2]*(1-a))]
			for k in range(0, 2)
				if abs(got[k] - want[k]) > 2 then bad = bad + 1; break
			end for
		end for
	end for
	qa.assertEqual bad, 0, name + ": mismatching pixels"
	print "  OK: " + name
	rl.UnloadImage img
end function

check "opaque fore, opaque back", "#FF0000FF", "#0000FFFF", "#00FF00FF"
check "opaque fore, clear back", "#FF0000FF", "#00000000", "#00FF00FF"
check "opaque fore, translucent back (shader path)", "#FF0000FF", "#0000FF80", "#00FF00FF"
check "translucent fore, opaque back (shader path)", "#FF000080", "#0000FFFF", "#00FF00FF"
print "ALL PASSED"
exit
