// qa_color_clamp.ms -- color.rgb/rgba/fromList clamp out-of-range channels to
// 0-255 (as Mini Micro does) instead of crashing (>255) or wrapping (<0).
import "color"
import "qa"
qa.assertEqual color.rgb(256, 0, 0), "#FF0000", "rgb 256"
qa.assertEqual color.rgb(1020, 300, 99999), "#FFFFFF", "rgb huge"
qa.assertEqual color.rgb(-1, -500, 0), "#000000", "rgb negative"
qa.assertEqual color.rgba(0, 0, 0, -50), "#00000000", "rgba negative alpha"
qa.assertEqual color.rgba(10, 20, 30, 400), "#0A141EFF", "rgba big alpha"
qa.assertEqual color.fromList([300, -4, 16, 255]), "#FF0010FF", "fromList list"
qa.assertEqual color.fromList({"r": 300, "g": -4, "b": 16, "a": 999}), "#FF0010FF", "fromList map"
// in-range values unchanged
qa.assertEqual color.rgb(0, 128, 255), "#0080FF", "rgb in range"
qa.assertEqual color.rgba(1, 2, 3, 4), "#01020304", "rgba in range"
qa.assertEqual color.fromList([1, 2, 3, 4]), "#01020304", "fromList in range"
print "ALL PASSED"
exit
