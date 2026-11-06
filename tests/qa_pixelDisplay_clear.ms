// qa_pixelDisplay_clear.ms -- regression test for a bug fix: PixelDisplay.clear
// used to default width/height to 960/640 (the Mini Micro screen's own size)
// instead of the display's current size, so a bare `d.clear` or `d.clear(color)`
// on any custom-sized PixelDisplay silently resized (and blanked) it.
import "soda"
import "qa"

print "=== clear() with no arguments preserves the display's current size ==="
d = PixelDisplay.Make(100, 50)
d.clear
qa.assertEqual d.width, 100, "clear() with no args should not change width"
qa.assertEqual d.height, 50, "clear() with no args should not change height"

print "=== clear(color) with no size preserves the display's current size ==="
d2 = PixelDisplay.Make(120, 70)
d2.clear "#FF0000FF"
qa.assertEqual d2.width, 120, "clear(color) with no size should not change width"
qa.assertEqual d2.height, 70, "clear(color) with no size should not change height"
qa.assertEqual d2.pixel(0, 0), "#FF0000FF", "clear(color) should still clear to the given color"

print "=== clear(color, width, height) still resizes when explicitly asked ==="
d3 = PixelDisplay.Make(50, 50)
d3.clear "#00FF00FF", 200, 80
qa.assertEqual d3.width, 200, "explicit width should still resize"
qa.assertEqual d3.height, 80, "explicit height should still resize"
qa.assertEqual d3.pixel(0, 0), "#00FF00FF", "resized clear should still clear to the given color"

print "=== clear() on a default-sized (960x640) display still works ==="
d4 = PixelDisplay.Make
d4.clear
qa.assertEqual d4.width, 960, "default-sized display should stay 960 wide after clear()"
qa.assertEqual d4.height, 640, "default-sized display should stay 640 tall after clear()"

print "ALL PASSED"
exit
