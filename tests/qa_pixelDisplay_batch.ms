// qa_pixelDisplay_batch.ms -- regression test for PixelDisplay.beginBatch/
// endBatch (the S-P1 prototype fix: amortize BeginTextureMode/EndTextureMode
// across consecutive draws instead of paying it every call).
import "soda"
import "qa"

print "=== Existing geometry unit tests still pass ==="
failures = PixelDisplay.runUnitTests
qa.assertEqual failures, 0, "PixelDisplay.runUnitTests should report zero failures"

print "=== beginBatch/endBatch draws the same pixels as unbatched calls ==="
dUnbatched = PixelDisplay.Make
dUnbatched.setPixel 5, 5, "#FF0000FF"
dUnbatched.fillRect 10, 10, 4, 4, "#00FF00FF"
dUnbatched.line 0, 0, 20, 20, "#0000FFFF"

dBatched = PixelDisplay.Make
dBatched.beginBatch
dBatched.setPixel 5, 5, "#FF0000FF"
dBatched.fillRect 10, 10, 4, 4, "#00FF00FF"
dBatched.line 0, 0, 20, 20, "#0000FFFF"
dBatched.endBatch

for pt in [[5,5], [10,10], [12,12], [0,0], [20,20], [3,3], [50,50]]
	a = dUnbatched.pixel(pt[0], pt[1])
	b = dBatched.pixel(pt[0], pt[1])
	qa.assertEqual b, a, "pixel " + pt + " should match between batched and unbatched drawing"
end for

print "=== endBatch with no matching beginBatch is a harmless no-op ==="
dNoop = PixelDisplay.Make
dNoop.endBatch  // should not throw, should not leave anything in a bad state
dNoop.setPixel 1, 1, "#FFFFFFFF"
qa.assertEqual dNoop.pixel(1, 1), "#FFFFFFFF", "a stray endBatch should not break subsequent drawing"

print "=== beginBatch/endBatch nest correctly (inner endBatch doesn't close early) ==="
dNested = PixelDisplay.Make
dNested.beginBatch
dNested.beginBatch
dNested.setPixel 2, 2, "#AABBCCFF"
dNested.endBatch
// Still "inside" the outer batch here -- drawing should still work.
dNested.setPixel 3, 3, "#DDEEFFFF"
dNested.endBatch
qa.assertEqual dNested.pixel(2, 2), "#AABBCCFF", "pixel drawn between nested begin/endBatch should stick"
qa.assertEqual dNested.pixel(3, 3), "#DDEEFFFF", "pixel drawn after the inner endBatch (still in outer batch) should stick"

print "ALL PASSED"
exit
