import "importUtil"
ensureImport ["Display", "color", "qa"]

// List factories -- we don't import listUtil here because that
// would silently alter the `list` map, which the user may or
// may not want.
_list_init = function(size, initialValue)
	"Return a new list of the given size, filled with initialValue."
	if @initialValue isa funcRef then
		result = []
		for i in range(1, size)
			result.push initialValue
		end for
		return result
	else
		return [initialValue] * size
	end if
end function

// init2d: build a 2D array, composed as a list of lists.
// (Note that the math functions here in listUtil probably do not do what
// you would want for a 2D array of numbers; if you want to do matrix math,
// use matrixUtil instead.)
_list_init2d = function(rows, columns, initialValue)
	"Return a new 2D array (list of row lists), filled with initialValue."
	result = []
	for a in range(1, rows)
		result.push _list_init(columns, @initialValue)
	end for
	return result
end function


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
	"Create and return a new TileDisplay with a 10x10 grid."
	td = new self
	td.extent = [10, 10]
	return td
end function

// Returned frozen: mutating it would not resize the grid.  To resize,
// assign a new extent (see below).
TileDisplay.extent = function
	"Return the grid size as a frozen [columns, rows] list."
	result = [self._cols, self._rows]
	freeze result
	return result
end function

// Assigning to .extent resizes the grid, discarding its contents.  As in
// Mini Micro, the value may be [columns, rows], an {"x","y"} map, or a
// single number for a square grid; anything else is ignored.
TileDisplay.MAX_CELLS = 4000000	// largest grid .extent will allocate
TileDisplay["extent="] = function(value)
	"Resize the grid to [columns, rows] (or x/y map, or number), clearing it."
	if value isa number then
		columns = value
		rows = value
	else if value isa list and value.len > 1 then
		columns = value[0]
		rows = value[1]
	else if value isa map and value.hasIndex("x") and value.hasIndex("y") then
		columns = value.x
		rows = value.y
	else
		return
	end if
	if not (columns isa number) or not (rows isa number) then return
	columns = round(columns)
	rows = round(rows)
	if columns <= 0 or rows <= 0 or columns * rows > TileDisplay.MAX_CELLS then return
	if columns == self._cols and rows == self._rows then return
	self._cols = columns
	self._rows = rows
	self._idx = _list_init2d(rows, columns, null)
	self._tint = _list_init2d(rows, columns, null)
	self._xform = _list_init2d(rows, columns, 0)
end function

TileDisplay.clear = function(toIndex=null)
	"Set every cell to the given tile index, removing all tints and transforms."
	for row in range(0, self._rows - 1, 1)
		for col in range(0, self._cols - 1, 1)
			self._idx[row][col] = toIndex
			self._tint[row][col] = null
			self._xform[row][col] = 0
		end for
	end for
end function

TileDisplay.cell = function(x, y)
	"Return the tile index at column x, row y (null if empty or out of range)."
	if 0 <= x < self._cols and 0 <= y < self._rows then	return self._idx[y][x]
	return null
end function

TileDisplay.setCell = function(x, y, idx)
	"Set the tile index at column x, row y (either may be a list)."
	if x isa number and y isa number then
		self._idx[y][x] = idx
	else
		if x isa number then cols = [x] else cols = x
		if y isa number then rows = [y] else rows = y
		for y in rows
			for x in cols
				self._idx[y][x] = idx
			end for
		end for
	end if
end function

TileDisplay.cellTint = function(x, y)
	"Return the tint color at column x, row y (null if none)."
	if 0 <= x < self._cols and 0 <= y < self._rows then	return self._tint[y][x]
	return null
end function

TileDisplay.setCellTint = function(x, y, c)
	"Set the tint color at column x, row y (either may be a list)."
	if x isa number and y isa number then
		self._tint[y][x] = c
	else
		if x isa number then cols = [x] else cols = x
		if y isa number then rows = [y] else rows = y
		for y in rows
			for x in cols
				self._tint[y][x] = c
			end for
		end for
	end if
end function

TileDisplay.cellTransform = function(x, y)
	"Return the transform (0-7) at column x, row y."
	if 0 <= x < self._cols and 0 <= y < self._rows then	return self._xform[y][x]
	return null
end function

TileDisplay.setCellTransform = function(x, y, t)
	"Set the transform at column x, row y: 0-3 rotate by 90s, 4-7 also flip."
	if x isa number and y isa number then
		self._xform[y][x] = t
	else
		if x isa number then cols = [x] else cols = x
		if y isa number then rows = [y] else rows = y
		for y in rows
			for x in cols
				self._xform[y][x] = t
			end for
		end for
	end if
end function

// Internal: source rect into tileSet for a given tile index.
// Tile-set indexing is top-left to bottom-right -- the one
// documented exception to Mini Micro's usual bottom-up convention.
TileDisplay._srcRectFor = function(idx)
	"Return the source rect within the tile set for the given tile index."
	s = self.tileSetTileSize
	if s isa list then
		tw = s[0]; th = s[1]
	else
		tw = s; th = tw
	end if
	tilesPerRow = floor(self.tileSet.width / tw)
	col = idx % tilesPerRow
	row = floor(idx / tilesPerRow)
	return [col * tw, row * th, tw, th]
end function

TileDisplay._tileGeometry = function(x, y, idx)
	"Return the source rect, dest rect, origin, and rotation for drawing one cell."
	if idx == null then return null
	srcRect = self._srcRectFor(idx)
	t = self._xform[y][x]
	flipH = t >= 4
	rotation = (t % 4) * 90
	if flipH then srcRect = [srcRect[0], srcRect[1], -srcRect[2], srcRect[3]]

	if self.cellSize isa list then
		xsize = self.cellSize[0]; ysize = self.cellSize[1]
	else
		xsize = self.cellSize; ysize = xsize
	end if
	if self.overlap isa list then
		xover = self.overlap[0]; yover = self.overlap[1]
	else
		xover = self.overlap; yover = xover
	end if
	xspacing = xsize - xover
	yspacing = ysize - yover
	ox = self.oddRowOffset * xsize * (y % 2)
	oy = self.oddColOffset * ysize * (x % 2)
	worldX = x * xspacing + ox - self.scrollX
	worldY = y * yspacing + oy - self.scrollY

	screenX = worldX + xsize * 0.5
	screenY = Display.screenHeight - worldY - ysize * 0.5
	destRect = [screenX, screenY, xsize, ysize]
	origin = [xsize * 0.5, ysize * 0.5]
	return {"srcRect": srcRect, "destRect": destRect, "origin": origin, "rotation": rotation}
end function

TileDisplay.render = function
	"Draw all non-empty cells to the screen."
	if self.tileSet == null then return
	// Only visit cells that could land on screen.  The window is padded
	// generously (rotation, stagger offsets, non-square cells) so culling
	// never drops a visible tile; it merely skips the vast off-screen bulk.
	x0 = 0; x1 = self._cols - 1; y0 = 0; y1 = self._rows - 1
	if self.cellSize isa list then
		xsize = self.cellSize[0]; ysize = self.cellSize[1]
	else
		xsize = self.cellSize; ysize = xsize
	end if
	if self.overlap isa list then
		xover = self.overlap[0]; yover = self.overlap[1]
	else
		xover = self.overlap; yover = xover
	end if
	xspacing = xsize - xover
	yspacing = ysize - yover
	if xspacing > 0 and yspacing > 0 then
		pad = 2 * xsize
		if ysize > xsize then pad = 2 * ysize
		padX = pad + abs(self.oddRowOffset) * xsize
		padY = pad + abs(self.oddColOffset) * ysize
		// cell x occupies world X from x*xspacing - scrollX (plus offset); visible if in (-pad, W+pad)
		v = floor((self.scrollX - padX) / xspacing)
		if v > x0 then x0 = v
		v = ceil((self.scrollX + Display.screenWidth + padX) / xspacing)
		if v < x1 then x1 = v
		// world Y runs bottom-up from the screen bottom
		v = floor((self.scrollY - padY) / yspacing)
		if v > y0 then y0 = v
		v = ceil((self.scrollY + Display.screenHeight + padY) / yspacing)
		if v < y1 then y1 = v
	end if
	// Everything below is loop-invariant; the per-cell work is then just
	// arithmetic plus one draw call (this inlines _tileGeometry, which
	// allocates a map and several lists per tile).
	tex = self.tileSet.texture
	if self.tileSetTileSize isa list then
		tw = self.tileSetTileSize[0]; th = self.tileSetTileSize[1]
	else
		tw = self.tileSetTileSize; th = tw
	end if
	tilesPerRow = floor(self.tileSet.width / tw)
	origin = [xsize * 0.5, ysize * 0.5]
	rowOff = self.oddRowOffset * xsize
	colOff = self.oddColOffset * ysize
	halfX = xsize * 0.5
	halfY = ysize * 0.5
	screenH = Display.screenHeight
	scrollX = self.scrollX
	scrollY = self.scrollY
	white = color.white
	idxGrid = self._idx
	tintGrid = self._tint
	xformGrid = self._xform
	DrawTexturePro = @raylib.DrawTexturePro
	for y in range(y0, y1, 1)
		idxRow = idxGrid[y]
		tintRow = tintGrid[y]
		xformRow = xformGrid[y]
		rowX = rowOff * (y % 2) - scrollX
		rowY = y * yspacing - scrollY
		for x in range(x0, x1, 1)
			idx = idxRow[x]
			if idx == null then continue
			t = xformRow[x]
			srcRow = floor(idx / tilesPerRow)
			if t >= 4 then
				src = [(idx - srcRow * tilesPerRow) * tw, srcRow * th, -tw, th]
				rot = (t % 4) * 90
			else
				src = [(idx - srcRow * tilesPerRow) * tw, srcRow * th, tw, th]
				rot = (t % 4) * 90
			end if
			tint = tintRow[x]
			if tint == null then tint = white
			DrawTexturePro tex, src, [x * xspacing + rowX + halfX, screenH - (rowY + colOff * (x % 2)) - halfY, xsize, ysize], origin, rot, tint
		end for
	end for
end function

if locals == globals then
	print "== Pure logic tests (no rendering needed) =="

	print "assigning .extent allocates a grid of the right shape"
	td = TileDisplay.Make
	td.extent = [5, 3]
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
		"Scroll a TileDisplay so its top-left tile lands at the given screen position."
		spacing = td.cellSize - td.overlap
		td.scrollX = -left
		td.scrollY = top + td.cellSize - Display.screenHeight + (td._rows - 1) * spacing
	end function

	caption = function(text, top)
		"Print a caption on the text display at about the given pixel row."
		TextDisplay.row = floor(top / (TextDisplay.charH + TextDisplay.padY))
		TextDisplay.column = 0
		TextDisplay.color = color.white
		TextDisplay.backColor = color.clear
		TextDisplay.print text, ""
	end function

	// ToDo: rework this test to use some image standard with the Soda distro
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
	palette.extent = [tilesPerRow, tileRows]
	for i in range(0, tileCount - 1, 1)
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
	tintDemo.extent = [tintColors.len, 1]
	for i in range(0, tintColors.len - 1, 1)
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
	transformDemo.extent = [15, 1]
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
	overlapDemo.extent = [8, 1]
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
	staggerDemo.extent = [6, 4]
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