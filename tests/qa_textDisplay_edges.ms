// qa_textDisplay_edges.ms -- PERF_TEST_PLAN.md §4.5 bug probes for TextDisplay.
import "soda"
import "qa"

row = function(td, r)
	s = ""
	for c in range(0, td.columns - 1)
		s = s + td.cell(c, r)
	end for
	return s
end function

print "=== print with delimiter """" does not advance the line ==="
t = TextDisplay.Make
t.row = 25
t.print "ab", ""
t.print "cd", ""
qa.assertEqual t.row, 25, "no delimiter: stays on row 25"
qa.assertEqual row(t, 25)[:4], "abcd", "text is contiguous"

print "=== default delimiter moves to next line ==="
t = TextDisplay.Make
t.row = 25
t.print "x"
qa.assertEqual t.row, 24, "row decremented"
qa.assertEqual t.column, 0, "column reset"

print "=== row= / column= clamp ==="
t = TextDisplay.Make
t.row = 999; qa.assertEqual t.row, 25, "row clamps high"
t.row = -5; qa.assertEqual t.row, 0, "row clamps low"
t.column = 999; qa.assertEqual t.column, 67, "column clamps high"
t.column = -5; qa.assertEqual t.column, 0, "column clamps low"

print "=== scroll with 1 row ==="
t = TextDisplay.Make
t.setSize 10, 1
t.print "hello"
t.print "world"
qa.assertEqual t.rows, 1, "still one row"
qa.assertEqual row(t, 0)[:5], "     ", "after scrolling the single row is blank (nothing left behind)"

print "=== scroll keeps rows distinct objects (no aliasing) ==="
t = TextDisplay.Make
t.setSize 5, 3
for i in range(1, 7); t.print "L" + i; end for
t.setCell 0, 0, "Z"
qa.assertEqual t.cell(0, 1) != "Z", true, "editing one row must not change another"
seen = {}
for r in range(0, 2)
	qa.assert not seen.hasIndex(t._cells[r]), "row list is aliased"
	seen[t._cells[r]] = true
end for

print "=== unicode outside the font maps to the unknown glyph, no crash ==="
t = TextDisplay.Make
t.row = 25
t.print char(20013) + char(128512) + "A"
qa.assertEqual t.cell(2, 25), "A", "later characters still land correctly"

print "=== out-of-range setCell / cell ==="
t = TextDisplay.Make
t.setCell -1, 0, "x"; t.setCell 68, 0, "x"; t.setCell 0, 26, "x"
qa.assertEqual t.cell(-1, 0), null, "cell out of range is null"

print "=== cursor show/hide restores the cell ==="
t = TextDisplay.Make
t.row = 25
t.print "abc", ""
t.row = 25; t.column = 1
oldColor = t.cellColor(1, 25)
t.showCursor
qa.assert t._cellAt(25, 1).inverse, "cursor inverts its cell"
t.hideCursor
qa.assert not t._cellAt(25, 1).inverse, "hideCursor un-inverts"
qa.assertEqual t.cellColor(1, 25), oldColor, "color restored"

print "=== tab and backspace ==="
t = TextDisplay.Make
t.row = 25
t.print "a" + char(9) + "b", ""
qa.assertEqual t.column, 5, "tab advances to column 4, then b -> 5"
t.put char(8)
qa.assertEqual t.column, 4, "backspace moves left"

print "ALL PASSED"
exit
