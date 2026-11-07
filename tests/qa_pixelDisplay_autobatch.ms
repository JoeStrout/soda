// qa_pixelDisplay_autobatch.ms -- unbatched PixelDisplay calls leave their GPU
// bracket open; every other consumer of the GPU must close it first.
import "soda"
import "qa"
qa.assertEqual PixelDisplay.autoBatch, false, "auto-batching must be opt-in"
mode = true
if shellArgs.len > 1 and shellArgs[1] == "off" then mode = false  // (run both ways)
PixelDisplay.autoBatch = mode
rl = raylib

a = PixelDisplay.Make
b = PixelDisplay.Make
print "=== alternating displays ==="
for i in range(0, 9)
	a.fillRect i*4, 0, 4, 4, "#FF0000FF"
	b.fillRect i*4, 0, 4, 4, "#00FF00FF"
end for
qa.assertEqual a.pixel(5, 1), "#FF0000FF", "a"
qa.assertEqual b.pixel(5, 1), "#00FF00FF", "b"
qa.assertEqual a.pixel(5, 10), "#00000000", "a untouched"

print "=== mixed replace / alpha blend ==="
a.fillRect 0, 20, 8, 8, "#FFFFFFFF"
a.print "A", 0, 20, "#000000FF"
a.fillRect 20, 20, 8, 8, "#0000FFFF"
qa.assertEqual a.pixel(22, 22), "#0000FFFF", "replace after alpha"

print "=== readback after draw (pixel/getImage) ==="
a.fillRect 40, 40, 4, 4, "#123456FF"
img = a.getImage(40, 40, 4, 4)
qa.assertEqual img.pixel(1, 1), "#123456FF", "getImage sees latest draw"

print "=== freeing an Image after drawing it ==="
im = Image.create(4, 4, "#ABCDEFFF")
a.drawImage im, 60, 60
im.setPixel 0, 0, "#000000FF"  // invalidates + frees cached texture
im.release
qa.assertEqual a.pixel(61, 61), "#ABCDEFFF", "draw survives texture free"

print "=== clip ==="
a.setClip 100, 100, 4, 4
a.fillRect 98, 98, 10, 10, "#FFFF00FF"
a.clearClip
qa.assertEqual a.pixel(101, 101), "#FFFF00FF", "inside clip"
qa.assertEqual a.pixel(106, 106), "#00000000", "outside clip"

print "=== resize via clear while open ==="
a.fillRect 0, 0, 2, 2, "#FFFFFFFF"
a.clear "#00000000", 100, 100
qa.assertEqual a.width, 100, "resized"
a.fillRect 0, 0, 2, 2, "#FFFFFFFF"
qa.assertEqual a.pixel(1, 1), "#FFFFFFFF", "draw after resize"

print "=== bracket closed before frame render ==="
a.fillRect 0, 0, 2, 2, "#FFFFFFFF"
soda.update
qa.assert rl.rlGetActiveFramebuffer == 0, "no framebuffer left bound after update"

print "ALL PASSED"
exit
