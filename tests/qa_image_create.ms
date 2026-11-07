// Tests for Image.create argument checking.
import "qa"
import "soda"

img = Image.create(8, 4, "#112233FF")
qa.assertEqual img.width, 8
qa.assertEqual img.height, 4
qa.assertEqual img.pixel(0, 0), "#112233FF"

// zero-sized images are still allowed
z = Image.create(0, 0)
qa.assert z != null, "0 x 0 image should be created"

// sizes that cannot be allocated must not crash the host
qa.assertEqual Image.create(1e9, 2), null
qa.assertEqual Image.create(2, 1e9), null
qa.assertEqual Image.create(1e5, 1e5), null
qa.assertEqual Image.create(-1, 5), null
qa.assertEqual Image.create(null, 5), null
qa.assertEqual Image.create("abc", 5), null

print "ALL PASSED"
exit
