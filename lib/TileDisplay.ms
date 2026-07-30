import "importUtil"
ensureImport ["Display", "color", "listUtil", "qa"]

TileDisplay = new Display
TileDisplay.mode = displayMode.tile

TileDisplay.tileSet = null          // Image to draw tiles from
TileDisplay.tileSetTileSize = 64    // pixels, size of each tile *within* tileSet
TileDisplay.cellSize = 64           // pixels, size of each cell on screen
TileDisplay.overlap = 0             // pixels of overlap between adjacent cells
TileDisplay.oddRowOffset = 0        // fraction of cellSize; 0.5 for hex rows
TileDisplay.oddColOffset = 0        // fraction of cellSize; 0.5 for hex columns
TileDisplay.scrollX = 0
TileDisplay.scrollY = 0

TileDisplay._cols = 0
TileDisplay._rows = 0
TileDisplay._idx = null     // grid[row][col] -> tile index, or null (empty)
TileDisplay._tint = null    // grid[row][col] -> color, or null (no tint)
TileDisplay._xform = null   // grid[row][col] -> transform 0-7

TileDisplay.Make = function
	td = new TileDisplay
	td.setExtent 10, 10
	return td
end function

// Resize the grid.  This is the explicit stand-in for Mini Micro's
// "assigning to .extent resizes the grid" trick, which relies on
// native property interception we don't have available here.
TileDisplay.setExtent = function(columns, rows)
	self._cols = columns
	self._rows = rows
	self._idx = list.init2d(rows, columns, null)
	self._tint = list.init2d(rows, columns, null)
	self._xform = list.init2d(rows, columns, 0)
end function

TileDisplay.extent = function
	return [self._cols, self._rows]
end function

TileDisplay.clear = function(toIndex=null)
	for row in range(0, self._rows - 1)
		for col in range(0, self._cols - 1)
			self._idx[row][col] = toIndex
			self._tint[row][col] = null
			self._xform[row][col] = 0
		end for
	end for
end function

TileDisplay.cell = function(x, y)
	return self._idx[y][x]
end function

TileDisplay.setCell = function(x, y, idx)
	self._idx[y][x] = idx
end function

TileDisplay.cellTint = function(x, y)
	return self._tint[y][x]
end function

TileDisplay.setCellTint = function(x, y, c)
	self._tint[y][x] = c
end function

TileDisplay.cellTransform = function(x, y)
	return self._xform[y][x]
end function

TileDisplay.setCellTransform = function(x, y, t)
	self._xform[y][x] = t
end function

// Internal: source rect into tileSet for a given tile index.
// Tile-set indexing is top-left to bottom-right -- the one
// documented exception to Mini Micro's usual bottom-up convention.
TileDisplay._srcRectFor = function(idx)
	tilesPerRow = floor(self.tileSet.width / self.tileSetTileSize)
	col = idx % tilesPerRow
	row = floor(idx / tilesPerRow)
	s = self.tileSetTileSize
	return [col * s, row * s, s, s]
end function

TileDisplay._tileGeometry = function(x, y, idx)
	srcRect = self._srcRectFor(idx)
	t = self._xform[y][x]
	flipH = t >= 4
	rotation = (t % 4) * 90
	if flipH then srcRect = [srcRect[0], srcRect[1], -srcRect[2], srcRect[3]]

	spacing = self.cellSize - self.overlap
	ox = self.oddColOffset * self.cellSize * (y % 2)
	oy = self.oddRowOffset * self.cellSize * (x % 2)
	worldX = x * spacing + ox - self.scrollX
	worldY = y * spacing + oy - self.scrollY

	screenX = worldX + self.cellSize * 0.5
	screenY = raylib.GetScreenHeight - worldY - self.cellSize * 0.5
	destRect = [screenX, screenY, self.cellSize, self.cellSize]
	origin = [self.cellSize * 0.5, self.cellSize * 0.5]
	return {"srcRect": srcRect, "destRect": destRect, "origin": origin, "rotation": rotation}
end function

TileDisplay.render = function
	if self.tileSet == null then return
	for y in range(0, self._rows - 1)
		for x in range(0, self._cols - 1)
			idx = self._idx[y][x]
			if idx == null then continue
			g = self._tileGeometry(x, y, idx)
			tint = self._tint[y][x]
			if tint == null then tint = color.white
			raylib.DrawTexturePro self.tileSet.texture, g.srcRect, g.destRect, g.origin, g.rotation, tint
		end for
	end for
end function

if locals == globals then
	print "== Pure logic tests (no rendering needed) =="

	print "setExtent allocates a grid of the right shape"
	td = TileDisplay.Make
	td.setExtent 5, 3
	ext = td.extent
	qa.assert ext[0] == 5 and ext[1] == 3, "extent should report [5,3]"
	qa.assert td.cell(4, 2) == null, "new grid should be empty"

	print "setCell / cell round-trip"
	td.setCell 2, 1, 7
	qa.assert td.cell(2, 1) == 7, "setCell then cell should return 7"
	qa.assert td.cell(0, 0) == null, "untouched cells should remain null"

	print "clear with a fill index sets every cell"
	td.clear 9
	qa.assert td.cell(0, 0) == 9 and td.cell(4, 2) == 9, "clear(9) should fill the whole grid"

	print "setCellTint / cellTint round-trip"
	td.setCellTint 1, 1, color.red
	qa.assert td.cellTint(1, 1) == color.red, "tint should round-trip"
	qa.assert td.cellTint(0, 0) == null, "untouched cells have no tint"

	print "setCellTransform / cellTransform round-trip, full 0-7 range"
	for t in range(0, 7)
		td.setCellTransform 0, 0, t
		qa.assert td.cellTransform(0, 0) == t, "transform " + t + " should round-trip"
	end for

	print "_srcRectFor indexes left-to-right, top-to-bottom"
	td.tileSet = {"width": 256}   // fake stand-in, just needs .width
	td.tileSetTileSize = 64
	r0 = td._srcRectFor(0)
	r1 = td._srcRectFor(1)
	r4 = td._srcRectFor(4)   // second row, since 256/64 = 4 tiles per row
	qa.assert r0 == [0, 0, 64, 64], "tile 0 should be top-left"
	qa.assert r1 == [64, 0, 64, 64], "tile 1 should be next column, same row"
	qa.assert r4 == [0, 64, 64, 64], "tile 4 should wrap to the next row"

	print "_tileGeometry: rotation values 0-3 don't flip, 4-7 do"
	td.cellSize = 64
	td.overlap = 0
	td.setCell 0, 0, 0
	for t in range(0, 7)
		td.setCellTransform 0, 0, t
		g = td._tileGeometry(0, 0, 0)
		expectedRotation = (t % 4) * 90
		qa.assert g.rotation == expectedRotation, "transform " + t + " rotation should be " + expectedRotation
		expectedFlip = t >= 4
		actualFlip = g.srcRect[2] < 0
		qa.assert actualFlip == expectedFlip, "transform " + t + " flip mismatch"
	end for

	print "All pure-logic tests passed!"

	print "== Visual test (look at the app window) =="
	import "soda"

	// Position a TileDisplay's grid so its top-left tile's top-left corner
	// lands at the given screen pixel (top-down).  TileDisplay itself works
	// in Mini Micro's bottom-up world space (row 0 = bottom, y = 0 at the
	// screen bottom), so this converts once instead of hand-tuning
	// scrollX/scrollY by trial and error for every panel below.
	positionPanel = function(td, left, top)
		spacing = td.cellSize - td.overlap
		td.scrollX = -left
		td.scrollY = top + td.cellSize - raylib.GetScreenHeight + (td._rows - 1) * spacing
	end function

	caption = function(text, top)
		TextDisplay.row = floor(top / (TextDisplay.charH + TextDisplay.padY))
		TextDisplay.column = 0
		TextDisplay.color = color.white
		TextDisplay.backColor = color.clear
		TextDisplay.print text, ""
	end function

	tileset = file.loadImage("assets/lib/tiles/GrassLand/Terrain/Grassland_Terrain_47Tiles.png")
	tileSize = 16
	tilesPerRow = floor(tileset.width / tileSize)          // 12
	tileRows = floor(tileset.height / tileSize)             // 4
	tileCount = tilesPerRow * tileRows                      // 48 (47 used)
	demoTile = 0   // top-left corner tile: grass edge top+left, clearly asymmetric

	TextDisplay.clear
	TextDisplay.color = color.white
	TextDisplay.print "TileDisplay visual test"
	TextDisplay.print "------------------------"

	// Panel 1: every tile in the sheet, laid out in its native grid, so
	// each one is visible and its index is confirmed by _srcRectFor.
	caption "Tile palette (all " + tileCount + " slots, " + tilesPerRow + " x " + tileRows + "):", 30
	palette = TileDisplay.Make
	palette.tileSet = tileset
	palette.tileSetTileSize = tileSize
	palette.cellSize = 32
	palette.setExtent tilesPerRow, tileRows
	for i in range(0, tileCount - 1)
		palette.setCell i % tilesPerRow, floor(i / tilesPerRow), i
	end for
	positionPanel palette, 0, 40

	// Panel 2: same tile repeated with setCellTint set to each palette color.
	caption "Tint demo (setCellTint):", 178
	tintColors = [color.red, color.orange, color.yellow, color.lime, color.aqua,
	  color.blue, color.purple, color.pink, color.white]
	tintDemo = TileDisplay.Make
	tintDemo.tileSet = tileset
	tintDemo.tileSetTileSize = tileSize
	tintDemo.cellSize = 32
	tintDemo.setExtent tintColors.len, 1
	for i in range(0, tintColors.len - 1)
		tintDemo.setCell i, 0, demoTile
		tintDemo.setCellTint i, 0, tintColors[i]
	end for
	positionPanel tintDemo, 0, 188

	// Panel 3: all 8 transforms (0-3 = rotate 0/90/180/270, 4-7 = same + flip)
	// side by side, so a wrong flip/rotation is obvious by eye.  demoTile is
	// a seamless autotile piece, so adjacent copies blend into one another
	// with no gap; leave an empty column between each so every rotation
	// reads as its own isolated tile instead of melting into the next.
	caption "Transform demo (setCellTransform 0-7: rotate, then 4-7 also flip):", 230
	transformDemo = TileDisplay.Make
	transformDemo.tileSet = tileset
	transformDemo.tileSetTileSize = tileSize
	transformDemo.cellSize = 32
	transformDemo.setExtent 15, 1
	for t in range(0, 7)
		transformDemo.setCell t * 2, 0, demoTile
		transformDemo.setCellTransform t * 2, 0, t
	end for
	positionPanel transformDemo, 0, 240

	// Panel 4: overlap should pull cells closer together (interleaving),
	// not just gap them further apart.
	caption "Overlap demo (overlap=16, half the 32px cell):", 282
	overlapDemo = TileDisplay.Make
	overlapDemo.tileSet = tileset
	overlapDemo.tileSetTileSize = tileSize
	overlapDemo.cellSize = 32
	overlapDemo.overlap = 16
	overlapDemo.setExtent 8, 1
	for i in range(0, 7)
		overlapDemo.setCell i, 0, demoTile
	end for
	positionPanel overlapDemo, 0, 292

	// Panel 5: oddColOffset staggers alternating rows sideways, for a
	// hex-like layout.
	caption "Stagger demo (oddColOffset=0.5, hex-like):", 334
	staggerDemo = TileDisplay.Make
	staggerDemo.tileSet = tileset
	staggerDemo.tileSetTileSize = tileSize
	staggerDemo.cellSize = 32
	staggerDemo.oddColOffset = 0.5
	staggerDemo.setExtent 6, 4
	for y in range(0, 3)
		for x in range(0, 5)
			staggerDemo.setCell x, y, demoTile
		end for
	end for
	positionPanel staggerDemo, 0, 344

	caption "All TileDisplay tests passed!", 482

	while not raylib.WindowShouldClose
		raylib.BeginDrawing
		raylib.ClearBackground color.toList(color.black)
		palette.render
		tintDemo.render
		transformDemo.render
		overlapDemo.render
		staggerDemo.render
		TextDisplay.render
		raylib.EndDrawing
	end while
	exit
else
	return TileDisplay
end if