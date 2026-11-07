// qa_color_fromList.ms -- regression test: color.fromList used `s.append`,
// which lists don't have, so any list argument crashed with
// "Key Not Found: 'append' not found in map". Only the map form worked.
import "soda"
import "qa"

qa.assertEqual color.fromList([255, 128, 64, 255]), "#FF8040FF", "fromList(list) should build #RRGGBBAA"
qa.assertEqual color.fromList([0, 0, 0, 0]), "#00000000", "fromList of all zeros"
qa.assertEqual color.fromList({"r": 1, "g": 2, "b": 3, "a": 4}), "#01020304", "fromList(map) still works"

// Round trip for every named color and a batch of pseudo-random colors.
for name in ["black", "white", "red", "lime", "navy", "orange", "brown", "pink", "clear"]
	c = color[name]
	qa.assertEqual color.toList(c), color.toList(color.fromList(color.toList(c))), "round trip of " + name
	qa.assertEqual color.fromList(color.toList(c)), color.fromList(color.toList(color.fromList(color.toList(c)))), "stable round trip of " + name
end for
seed = 12345
for i in range(1, 200)
	l = []
	for k in range(1, 4)
		seed = (seed * 1103515245 + 12345) % 2147483648
		l.push floor(seed / 65536) % 256
	end for
	s = color.fromList(l)
	qa.assertEqual color.toList(s), l, "round trip of " + l
end for
print "ALL PASSED"
exit
