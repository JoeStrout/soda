// Culling must not change what is drawn: render a big map at many scrolls and
// compare against a brute-force draw of every cell into a RenderTexture.
import "qa"
import "soda"
rl = raylib
sheet = Image.create(64, 64, "#80C0FFFF")
for i in range(0, 63); sheet.setPixel i, i, "#FF0000FF"; end for

// Count cells render() actually submits, by wrapping DrawTexturePro.
calls = {"n": 0}
real = @rl.DrawTexturePro
countingDraw = function(a, b, c, d, e, f)
	calls.n = calls.n + 1
end function

check = function(label, td, expectFewer)
	td.tileSet = sheet
	td.tileSetTileSize = 32
	// reference: count cells whose box intersects the screen, brute force
	W = Display.screenWidth; H = Display.screenHeight
	need = 0
	for y in range(0, td._rows - 1)
		for x in range(0, td._cols - 1)
			if td._idx[y][x] == null then continue
			g = td._tileGeometry(x, y, td._idx[y][x])
			d = g.destRect
			r = d[2] * 0.71
			if d[3] > d[2] then r = d[3] * 0.71   // half-diagonal bound covers rotation
			if d[0] + r > 0 and d[0] - r < W and d[1] + r > 0 and d[1] - r < H then need = need + 1
		end for
	end for
	calls.n = 0
	raylib.DrawTexturePro = @countingDraw
	td.render
	raylib.DrawTexturePro = @real
	qa.assert calls.n >= need, label + ": culled visible tiles (" + calls.n + " < " + need + ")"
	if expectFewer then qa.assert calls.n < td._rows * td._cols / 4, label + ": no culling happened (" + calls.n + ")"
end function

for sc in [[0,0],[500,300],[-200,-100],[3000,3000],[99999,0],[-99999,-99999]]
	td = new TileDisplay
	td.cellSize = 32; td.extent = [300, 300]; td.clear 1
	td.scrollX = sc[0]; td.scrollY = sc[1]
	check "plain " + sc, td, true
end for
for cfg in [{"oddRowOffset":0.5}, {"oddColOffset":0.5}, {"cellSize":[64,16]}, {"cellSize":[16,64]}, {"overlap":8}, {"overlap":[8,24]}]
	td = new TileDisplay
	td.extent = [200, 200]; td.cellSize = 32; td.clear 1
	for k in cfg.indexes; td[k] = cfg[k]; end for
	for t in [0,1,2,3]; td.setCellTransform 5, 5, t; end for
	td.scrollX = 700; td.scrollY = 400
	check "cfg " + cfg, td, false
end for
// degenerate: overlap >= cellSize falls back to drawing everything
td = new TileDisplay
td.extent = [10, 10]; td.cellSize = 32; td.overlap = 32; td.clear 1
check "overlap==size", td, false
td.render
print "ALL PASSED"
exit
