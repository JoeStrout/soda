// qa_pixelDisplay_drawImage.ms -- regression test for the S-P2 prototype fix:
// PixelDisplay.drawImage/patternFill now reuse Image's own cached GPU
// texture (Image.texture) instead of uploading and freeing a fresh one on
// every call.
import "soda"
import "qa"

print "=== drawImage draws correctly from a freshly-created Image ==="
img = Image.create(4, 4, "#FF0000FF")
d = PixelDisplay.Make
d.drawImage img, 10, 10
qa.assertEqual d.pixel(10, 13), "#FF0000FF", "drawImage should draw the image's color"
qa.assertEqual d.pixel(13, 10), "#FF0000FF", "drawImage should cover the full image extent"

print "=== drawImage reuses the same cached texture across repeated calls ==="
d2 = PixelDisplay.Make
for i in range(1, 5)
	d2.drawImage img, i, i
end for
qa.assertEqual d2.pixel(5, 5), "#FF0000FF", "repeated drawImage calls on the same Image should each draw correctly"
qa.assert img._tex != null, "Image.texture should have cached a texture after being drawn"

print "=== drawImage still reflects pixel edits made after an earlier draw ==="
img2 = Image.create(2, 2, "#0000FFFF")
d3 = PixelDisplay.Make
d3.drawImage img2, 0, 0  // caches img2's texture
img2.setPixel 0, 0, "#00FF00FF"  // should invalidate the cached texture
d3.drawImage img2, 10, 0
qa.assertEqual d3.pixel(10, 0), "#00FF00FF", "drawImage should pick up pixel edits via texture invalidation"

print "=== patternFill tiles correctly and doesn't leak REPEAT wrap mode ==="
tile = Image.create(2, 2, "#FFFF00FF")
d4 = PixelDisplay.Make
d4.patternFill tile, 0, 0, 8, 8
for pt in [[0,0], [2,2], [4,4], [6,6], [7,7]]
	qa.assertEqual d4.pixel(pt[0], pt[1]), "#FFFF00FF", "patternFill should tile pixel " + pt
end for
// Now draw the same (now-cached) tile Image normally; it should be clamped,
// not repeated, confirming patternFill restored the wrap mode afterward.
d4.drawImage tile, 20, 20
qa.assertEqual d4.pixel(20, 21), "#FFFF00FF", "drawImage after patternFill should still draw the plain image once"

print "=== drawImage and patternFill on the same Image produce identical pixels to the pre-fix (per-call upload) approach ==="
rl = raylib
refImg = Image.create(5, 5, "#AA55FFFF")
dRef = PixelDisplay.Make
tex = rl.LoadTextureFromImage(refImg._img)
rl.SetTextureFilter tex, rl.TEXTURE_FILTER_POINT
dRef._drawTexture tex, 3, 3, null, null, 0, 0, null, null, "#FFFFFF"
rl.UnloadTexture tex

dNew = PixelDisplay.Make
dNew.drawImage refImg, 3, 3

for pt in [[3,3], [4,4], [7,7], [5,5]]
	qa.assertEqual dNew.pixel(pt[0], pt[1]), dRef.pixel(pt[0], pt[1]), "pixel " + pt + " should match between cached-texture and manual-upload drawing"
end for

print "ALL PASSED"
exit
