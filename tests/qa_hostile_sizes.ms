// Oversized or invalid grid/sample counts must be rejected quickly, not loop for ages.
import "qa"
import "soda"

td = new TextDisplay
td.setSize 10, 4
td.setSize 1e9, 2
td.setSize 2, 1e9
td.setSize -1, 5
td.setSize null, 5
td.setSize "abc", 5
qa.assertEqual td._cells.len, 4, "rejected setSize must leave the grid unchanged"
qa.assertEqual td.columns, 10
td.setSize 12, 5
qa.assertEqual td._cells.len, 5

tile = new TileDisplay
tile.extent = [5, 3]
tile.extent = [1e9, 2]
tile.extent = 1e9
tile.extent = [1e5, 1e5]
qa.assertEqual tile.extent, [5, 3], "rejected extent must be ignored"

qa.assertEqual Sound.noiseWave(1, 100).len, 100
qa.assertEqual Sound.noiseWave(1, 1e9).len, 0
qa.assertEqual Sound.noiseWave(null, 10).len, 0
qa.assertEqual Sound.noiseWave("abc", 10).len, 0
print "ALL PASSED"
