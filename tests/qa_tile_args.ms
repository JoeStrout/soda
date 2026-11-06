// render() inlines _tileGeometry; verify the draw args match it exactly.
import "qa"
import "soda"
sheet = Image.create(128, 64, "#80C0FFFF")
log = []
real = @raylib.DrawTexturePro
rec = function(tex, src, dest, origin, rot, tint)
	log.push [src, dest, origin, rot, tint]
end function
cfgs = [{}, {"oddRowOffset":0.5}, {"oddColOffset":0.5, "overlap":6}, {"cellSize":[40,24], "tileSetTileSize":[32,16]}]
for cfg in cfgs
	td = new TileDisplay
	td.tileSet = sheet; td.tileSetTileSize = 32; td.cellSize = 32
	for k in cfg.indexes; td[k] = cfg[k]; end for
	td.extent = [8, 6]
	for y in range(0,5); for x in range(0,7)
		if (x*3+y) % 5 == 0 then continue
		td.setCell x, y, (x+y*2) % 8
		td.setCellTransform x, y, (x*y) % 8
		if x == 2 then td.setCellTint x, y, "#FF000080"
	end for; end for
	td.scrollX = 10; td.scrollY = 5
	log = []
	raylib.DrawTexturePro = @rec
	td.render
	raylib.DrawTexturePro = @real
	i = 0
	for y in range(0,5); for x in range(0,7)
		idx = td.cell(x, y)
		if idx == null then continue
		g = td._tileGeometry(x, y, idx)
		e = log[i]; i = i + 1
		qa.assert e[0] == g.srcRect and e[1] == g.destRect and e[2] == g.origin and e[3] == g.rotation, "mismatch " + cfg + " at " + x + "," + y + ": " + e + " vs " + g
		tint = td.cellTint(x, y)
		if tint == null then tint = color.white
		qa.assert e[4] == tint, "tint mismatch"
	end for; end for
	qa.assert i == log.len, "count " + i + " vs " + log.len + " for " + cfg
end for
print "ALL PASSED"
exit
