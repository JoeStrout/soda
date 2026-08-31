// TextDisplay: a grid of character cells, each with its own foreground and
// background color, drawn with the Mini Micro screen font.
//
// Possible future features:
//
//   * Support selection of different screen fonts.
//   * Support scrolling.

import "importUtil"
ensureImport ["Display", "ScreenFont", "color" ]

rl = raylib

// List factory -- we don't import listUtil here because that
// would silently alter the `list` map, which the user may or
// may not want.
_list_init = function(size, initialValue)
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

// TextDisplay loads a font texture as soon as this module loads, so (unlike
// most Display subclasses) it needs a live GL context up front.  Normally
// soda.ms has already created the window by the time this runs; this guard
// just makes the module (and its self-tests) work standalone too.
if not rl.IsWindowReady then rl.InitWindow 960, 640

// Control characters interpreted by `put`.
BEEP = 7
BACKSPACE = 8
TAB = 9
LF = 10
CR = 13
INVERSE_ON = 134
INVERSE_OFF = 135

globals.TextDisplayCell = {}
TextDisplayCell.character = " "
TextDisplayCell.color = "#FFFFFF"
TextDisplayCell.backColor = "#000000"
TextDisplayCell.inverse = false		// used for the hardware cursor

TextDisplayCell.Make = function(fore, back)
	noob = new TextDisplayCell
	noob.character = " "
	noob.color = fore
	noob.backColor = back
	noob.inverse = false
	return noob
end function

TextDisplay = new Display
TextDisplay.mode = displayMode.text

TextDisplay.visible = true

TextDisplay.columns = 68
TextDisplay.rows = 26
TextDisplay.colSpacing = 14		// pixels between the left edges of adjacent columns
TextDisplay.rowSpacing = 24		// pixels between the top edges of adjacent rows
TextDisplay.offsetX = 0			// pixels from the left edge of the screen to column 0
TextDisplay.offsetY = 0			// pixels from the TOP edge of the screen to the top row

TextDisplay.column = 0			// cursor column, 0 to columns-1
TextDisplay.row = 0				// cursor row, 0 (bottom) to rows-1 (top)

TextDisplay.cursorShown = false
TextDisplay.cursorOnTime = 0.7
TextDisplay.cursorOffTime = 0.3
TextDisplay._cursorBlinking = false		// true while in the "off" half of a blink
TextDisplay._cursorTime = 0
// Note that actual blinking is driven by the console, not by the display itself.
// We'll return to this and might end up removing some of the above bookkeeping
// when we get to that point.

// The color, backColor and inverse used by subsequent print/put calls.
// (raylib's GREEN, matching the C++ default.)
TextDisplay.color = "#00E430"
TextDisplay.backColor = color.clear
TextDisplay.inverse = false
TextDisplay.delimiter = char(13)	// printed after every `print`, by default

TextDisplay.font = null			// a ScreenFont
TextDisplay._cells = null		// _cells[row][col] -> TextDisplayCell

// Bumped by every scroll.  Anything holding a screen position across a write
// (the console's input line, for one) can diff this to see how far its own
// coordinates have moved.  Cheaper and less fragile than a callback.
TextDisplay.scrollCount = 0

TextDisplay.Make = function
	noob = new TextDisplay
	noob.setSize noob.columns, noob.rows
	return noob
end function

// Resize the character grid.  Discards the current contents and homes
// the cursor.
TextDisplay.setSize = function(newCols, newRows)
	self.columns = newCols
	self.rows = newRows
	self._cells = _list_init(newRows, null)
	for row in range(0, newRows - 1, 1)
		cellRow = _list_init(newCols, null)
		for col in range(0, newCols - 1, 1)
			cellRow[col] = TextDisplayCell.Make(self.color, self.backColor)
		end for
		self._cells[row] = cellRow
	end for
	self.column = 0
	self.row = 0
	self.updateOffsets
end function

// Center the grid on the screen, splitting the leftover pixels evenly.  Note
// that this centers on Display's screen rect, not on the window: under a host
// with a bezel those differ, and the bezel's insets need not be symmetrical.
TextDisplay.updateOffsets = function
	self.offsetX = floor((Display.screenWidth - self.columns * self.colSpacing) / 2)
	self.offsetY = floor((Display.screenHeight - self.rows * self.rowSpacing) / 2)
end function

TextDisplay.setCellSpacing = function(colSp, rowSp)
	self.colSpacing = colSp
	self.rowSpacing = rowSp
	self.updateOffsets
end function

// Load a font texture (a 16x16 grid of glyphs) for this display to use.
// Returns true on success.
TextDisplay.loadFont = function(fontTexturePath)
	f = new ScreenFont
	if not f.load(fontTexturePath) then return false
	self.font = f
	return true
end function

//----------------------------------------------------------------------
// Cell access.  These take x (column) and y (row), matching the Mini Micro
// TextDisplay API.  Note that _cellAt, and everything ported directly from
// the C++, takes (row, col) instead.  ToDo: clean up that mess and make
// everything (including setCursor) take (col, row).
//----------------------------------------------------------------------

// Get the cell map at the given row and column, or null if out of range.
TextDisplay._cellAt = function(row, col)
	if row < 0 or row >= self.rows or col < 0 or col >= self.columns then return null
	return self._cells[row][col]
end function

TextDisplay.cell = function(x, y)
	c = self._cellAt(y, x)
	if c == null then return null
	return c.character
end function

TextDisplay.setCell = function(x, y, character)
	if x isa number and y isa number then
		// fast path
		c = self._cellAt(y, x)
		if c != null then c.character = character
	else
		// flexible path
		if not x isa list then x = [x]
		if not y isa list then y = [y]
		for _y in y
			for _x in x
				c = self._cellAt(_y, _x)
				if c != null then c.character = character
			end for
		end for
	end if
end function

TextDisplay.cellColor = function(x, y)
	c = self._cellAt(y, x)
	if c == null then return null
	return c.color
end function

TextDisplay.setCellColor = function(x, y, foreColor)
	c = self._cellAt(y, x)
	if c != null then c.color = foreColor
end function

TextDisplay.cellBackColor = function(x, y)
	c = self._cellAt(y, x)
	if c == null then return null
	return c.backColor
end function

TextDisplay.setCellBackColor = function(x, y, backColor)
	if x isa list then cols = x else cols = [x]
	if y isa list then rows = y else rows = [y]
	for _y in rows
		for _x in cols
			c = self._cellAt(_y, _x)
			if c != null then c.backColor = backColor
		end for
	end for
end function

// Store a character (with colors) at the given row and column.  Colors
// default to the display's current color/backColor; if inverse is on, the
// two are swapped as they go into the cell.
TextDisplay._set = function(row, col, character, foreColor=null, backColor=null)
	if foreColor == null then foreColor = self.color
	if backColor == null then backColor = self.backColor
	c = self._cellAt(row, col)
	if c == null then return
	c.character = character
	if self.inverse then
		c.color = backColor
		c.backColor = foreColor
	else
		c.color = foreColor
		c.backColor = backColor
	end if
end function

//----------------------------------------------------------------------
// Filling and clearing
//----------------------------------------------------------------------

// Fill one row with the given character, in the current colors.
TextDisplay.fillRow = function(row, character=" ")
	if row < 0 or row >= self.rows then return
	cellRow = self._cells[row]
	for col in range(0, self.columns - 1, 1)
		c = cellRow[col]
		c.character = character
		c.color = self.color
		c.backColor = self.backColor
		c.inverse = self.inverse
	end for
	self._cursorSavedColor = null	// the cursor's cell went with it
end function

TextDisplay.clearRow = function(row)
	self.fillRow row, " "
end function

// Fill the whole grid with the given character, in the current colors.
TextDisplay.fill = function(character=" ")
	for row in range(0, self.rows - 1, 1)
		self.fillRow row, character
	end for
end function

// Fill the grid with spaces and hide the cursor.  Note that this does not
// move the cursor; see the note at the top of this file.
TextDisplay.clear = function
	self.fill " "
	self.cursorShown = false
end function

//----------------------------------------------------------------------
// Printing and cursor movement
//----------------------------------------------------------------------

// Print a string, followed by the delimiter (which defaults to
// self.delimiter, i.e. a carriage return).  Pass "" for no delimiter.
TextDisplay.print = function(s="", delimiter=null)
	if delimiter == null then delimiter = self.delimiter
	if s == null then s = ""
	if not s isa string then s = str(s)
	self._hideCursorVisual
	for c in s
		self.put c
	end for
	for c in delimiter
		self.put c
	end for
end function

// Write a single character at the cursor, interpreting the handful of
// control codes Mini Micro understands.
TextDisplay.put = function(character)
	code = character.code
	if code == CR or code == LF then
		self.nextLine
	else if code == TAB then
		// Advance to the next multiple of 4, blanking as we go.
		while true
			self._set self.row, self.column, " "
			self.advance
			if self.column % 4 == 0 then break
		end while
	else if code == BEEP then
		// Nothing for now; a sound could be triggered here.
	else if code == BACKSPACE then
		self.backup
	else if code == INVERSE_ON then
		self.inverse = true
	else if code == INVERSE_OFF then
		self.inverse = false
	else
		self._set self.row, self.column, character
		self.advance
	end if
end function

// Move the cursor one column right, wrapping to the next line at the edge.
TextDisplay.advance = function
	self.column += 1
	if self.column >= self.columns then self.nextLine
end function

// Move the cursor one column left, wrapping back to the end of the line
// above (i.e. the next higher row index).  Stops at the top-left corner.
TextDisplay.backup = function
	self._hideCursorVisual
	self.column -= 1
	if self.column < 0 then
		if self.row >= self.rows - 1 then
			self.column = 0
			return
		end if
		self.row += 1
		self.column = self.columns - 1
	end if
end function

// Move the cursor to the start of the next line down, scrolling if we've
// run off the bottom.
TextDisplay.nextLine = function
	self.row -= 1
	while self.row < 0
		self.scroll
	end while
	self.column = 0
end function

// Scroll the contents up one row, clearing the bottom row.
TextDisplay.scroll = function
	// Rotate the row lists rather than copying cell by cell; row 0 is about
	// to be overwritten wholesale by clearRow anyway, so its cells can be
	// recycled as the new top row.
	recycled = self._cells[self.rows - 1]
	for row in range(self.rows - 1, 1, -1)
		self._cells[row] = self._cells[row - 1]
	end for
	self._cells[0] = recycled

	if self.row < self.rows - 1 then self.row += 1
	self.clearRow 0
	self.scrollCount += 1
end function

// Move the cursor, clamping to the grid.  (Assigning to .row and .column
// directly works too, but skips the clamping and the cursor bookkeeping.)
TextDisplay.setCursor = function(row=null, col=null)
	wasShown = self.cursorShown
	if self.cursorShown then self.hideCursor

	if col != null then
		self.column = col
		if self.column < 0 then
			self.column = 0
		else if self.column >= self.columns then
			self.column = self.columns - 1
		end if
	end if
	
	if row != null then
		self.row = row
		if self.row < 0 then self.row = 0
		if self.row >= self.rows then self.row = self.rows - 1
	end if

	if wasShown then self.showCursor
end function

//----------------------------------------------------------------------
// Hardware cursor
//----------------------------------------------------------------------

// The cursor is a cell drawn inverted, so the block takes its color from the
// *cell* -- which was set when that cell was last written, and so is stale the
// moment self.color changes.  (Classic symptom: type at a fresh prompt and the
// cursor is still the color the screen was cleared in.)  So the cell's color is
// forced to the current one while the cursor sits on it, and put back after.
//
// Mini Micro 1 does the same fix in TextDisplay.ShowCursor, but guesses the
// original back by lerping toward the background; that is right only for the
// faded autocomplete text it was written for, and rewrites the colors of
// anything else the cursor passes over.  Remembering is cheaper and exact.
TextDisplay._cursorSavedColor = null

// Internal: invert the cell the cursor is on, without changing the "cursor is
// on" state.  Used by the blink, which is driven by the console.
TextDisplay._showCursorVisual = function
	c = self._cellAt(self.row, self.column)
	if c == null then return
	// Keyed on the save rather than on c.inverse: the console inverts cells for
	// its selection too, so "already inverted" does not mean "already saved".
	if self._cursorSavedColor == null then self._cursorSavedColor = c.color
	c.color = self.color
	c.inverse = true
end function

// Internal: un-invert it again.  Used before anything that moves the cursor or
// writes to the screen.
TextDisplay._hideCursorVisual = function
	if not self.cursorShown then return
	c = self._cellAt(self.row, self.column)
	if c == null then return
	if c.inverse and self._cursorSavedColor != null then c.color = self._cursorSavedColor
	self._cursorSavedColor = null
	c.inverse = false
end function

TextDisplay.hideCursor = function
	self._hideCursorVisual
	self._cursorTime = 0
	self.cursorShown = false
end function

TextDisplay.showCursor = function
	self._showCursorVisual
	self._cursorTime = 0
	self.cursorShown = true
end function


//----------------------------------------------------------------------
// Rendering
//----------------------------------------------------------------------

TextDisplay.render = function
	if not self.visible then return
	if self.font == null or not self.font.isLoaded then return

	clearColor = color.clear
	for row in range(0, self.rows - 1, 1)
		cellRow = self._cells[row]
		// Row 0 is the bottom row, but raylib's y grows downward.
		y = self.offsetY + (self.rows - 1 - row) * self.rowSpacing
		for col in range(0, self.columns - 1, 1)
			c = cellRow[col]
			ch = c.character
			if c.inverse then
				fore = c.backColor
				back = c.color
			else
				fore = c.color
				back = c.backColor
			end if
			if ch == "" then ch = " "
			// A blank glyph over a fully transparent background draws
			// nothing at all, so skip it.  (Purely an optimization, but an
			// important one: most cells on a typical screen are empty.)
			if ch == " " and back == clearColor then continue
			self.font.drawChar ch.code, self.offsetX + col * self.colSpacing, y, fore, back
		end for
	end for
end function

// All TextDisplays share one font texture by default; loadFont on a
// particular display gives that display its own.
if version.hostName == "Mini Micro" then
	TextDisplay.font = ScreenFont.Make("/hw/images/ScreenFont.png")
else
	TextDisplay.font = ScreenFont.Make("lib/ScreenFont.png")
end if

if locals == globals then
	ensureImport "qa"
	import "soda"

	td = TextDisplay.Make

	print "== Pure logic tests (no rendering needed) =="

	print "setSize allocates a grid of the right shape and homes the cursor"
	td.setSize 10, 4
	qa.assertEqual td._cells.len, 4, "grid should have 4 rows"
	qa.assertEqual td._cells[0].len, 10, "grid should have 10 columns"
	qa.assertEqual td.row, 0, "setSize should reset row to 0"
	qa.assertEqual td.column, 0, "setSize should reset column to 0"
	qa.assertEqual td.cell(0, 0), " ", "new cells should hold a space"

	print "setCell / cell round-trip, in (x, y) = (column, row) order"
	td.setCell 3, 2, "Q"
	qa.assertEqual td.cell(3, 2), "Q", "setCell then cell should return 'Q'"
	qa.assertEqual td.cell(0, 0), " ", "untouched cells should remain blank"
	qa.assertEqual td.cell(99, 0), null, "out-of-range cell should return null"

	print "setCellColor / setCellBackColor round-trip"
	td.setCellColor 1, 1, color.red
	td.setCellBackColor 1, 1, color.blue
	qa.assertEqual td.cellColor(1, 1), color.red, "cell color should round-trip"
	qa.assertEqual td.cellBackColor(1, 1), color.blue, "cell backColor should round-trip"

	print "_set applies the current colors, and swaps them when inverse is on"
	td.setSize 10, 4
	td.color = color.yellow
	td.backColor = color.navy
	td.inverse = false
	td._set 0, 0, "A"
	qa.assertEqual td.cellColor(0, 0), color.yellow, "cell color should be the fore color"
	qa.assertEqual td.cellBackColor(0, 0), color.navy, "cell backColor should be the back color"
	td.inverse = true
	td._set 0, 1, "B"
	qa.assertEqual td.cellColor(1, 0), color.navy, "inverse should swap the cell's colors"
	qa.assertEqual td.cellBackColor(1, 0), color.yellow, "inverse should swap the cell's colors"
	td.inverse = false

	print "put writes at the cursor and advances the column"
	td.setSize 10, 4
	td.setCursor 2, 5
	td.put "H"
	td.put "i"
	qa.assertEqual td.cell(5, 2), "H", "first char should land at the starting column"
	qa.assertEqual td.cell(6, 2), "i", "second char should land one column over"
	qa.assertEqual td.column, 7, "column should have advanced past the text"
	qa.assertEqual td.row, 2, "row should be unchanged"

	print "advance wraps to the next line at the right edge"
	td.setSize 10, 4
	td.setCursor 2, 9
	td.advance
	qa.assertEqual td.column, 0, "advancing off the right edge should wrap to column 0"
	qa.assertEqual td.row, 1, "...and drop to the next row down (one lower index)"

	print "nextLine moves down a row, since row 0 is the bottom"
	td.setSize 10, 4
	td.setCursor 3, 4
	td.nextLine
	qa.assertEqual td.row, 2, "nextLine should decrement the row"
	qa.assertEqual td.column, 0, "nextLine should return to column 0"

	print "nextLine from the bottom row scrolls instead of going negative"
	td.setSize 10, 4
	td.setCell 0, 0, "B"		// bottom row
	td.setCell 0, 1, "M"		// one up from the bottom
	td.setCursor 0, 3
	td.nextLine
	qa.assertEqual td.row, 0, "cursor should stay pinned to the bottom row"
	qa.assertEqual td.column, 0, "cursor should be at column 0"
	qa.assertEqual td.cell(0, 1), "B", "old bottom row should have moved up one"
	qa.assertEqual td.cell(0, 2), "M", "the row above it should have moved up too"
	qa.assertEqual td.cell(0, 0), " ", "the new bottom row should be blank"

	print "scroll moves every row up one and clears row 0"
	td.setSize 10, 4
	for r in range(0, 3)
		td.setCell 0, r, str(r)
	end for
	td.setCursor 3, 0		// already at the top, so scroll shouldn't move the cursor
	td.scroll
	qa.assertEqual td.row, 3, "cursor at the top row should not move on scroll"
	qa.assertEqual td.cell(0, 3), "2", "row 2 should have become row 3"
	qa.assertEqual td.cell(0, 2), "1", "row 1 should have become row 2"
	qa.assertEqual td.cell(0, 1), "0", "row 0 should have become row 1"
	qa.assertEqual td.cell(0, 0), " ", "row 0 should have been cleared"

	print "backup steps left, and wraps to the end of the line above"
	td.setSize 10, 4
	td.setCursor 1, 3
	td.backup
	qa.assertEqual td.column, 2, "backup should decrement the column"
	qa.assertEqual td.row, 1, "backup within a line should not change the row"
	td.setCursor 1, 0
	td.backup
	qa.assertEqual td.row, 2, "backing up past column 0 should go up a row"
	qa.assertEqual td.column, 9, "...to the last column"
	td.setCursor 3, 0		// top-left corner: nowhere left to go
	td.backup
	qa.assertEqual td.row, 3, "backup at the top-left corner should stay put"
	qa.assertEqual td.column, 0, "backup at the top-left corner should stay put"

	print "print appends the delimiter (a carriage return) by default"
	td.setSize 10, 4
	td.setCursor 3, 0
	td.print "Hi"
	qa.assertEqual td.cell(0, 3), "H", "text should print at the cursor"
	qa.assertEqual td.cell(1, 3), "i", "text should print at the cursor"
	qa.assertEqual td.row, 2, "the default delimiter should start a new line"
	qa.assertEqual td.column, 0, "the default delimiter should return to column 0"
	td.print "no delim", ""
	qa.assertEqual td.row, 2, "an empty delimiter should leave the row alone"
	qa.assertEqual td.column, 8, "an empty delimiter should leave the column past the text"

	print "put handles tab, backspace, and the inverse on/off control codes"
	td.setSize 12, 4
	td.setCursor 3, 1
	td.put char(9)
	qa.assertEqual td.column, 4, "tab should advance to the next multiple of 4"
	qa.assertEqual td.cell(1, 3), " ", "tab should blank the cells it passes over"
	td.setCursor 3, 4
	td.put char(9)
	qa.assertEqual td.column, 8, "tab from a multiple of 4 should advance a full 4"
	td.setCursor 3, 5
	td.put char(8)
	qa.assertEqual td.column, 4, "backspace should back the cursor up"
	td.inverse = false
	td.put char(134)
	qa.assert td.inverse, "char 134 should turn inverse on"
	qa.assertEqual td.column, 4, "control codes should not advance the cursor"
	td.put char(135)
	qa.assert not td.inverse, "char 135 should turn inverse off"

	print "clear fills with spaces and hides the cursor, but leaves the cursor put"
	td.setSize 10, 4
	td.color = color.lime
	td.backColor = color.clear
	td.print "text to be wiped", ""
	td.setCursor 2, 5
	td.showCursor
	qa.assert td.cursorShown, "showCursor should set cursorShown"
	td.clear
	qa.assertEqual td.cell(0, 0), " ", "clear should blank every cell"
	qa.assert not td.cursorShown, "clear should hide the cursor"
	qa.assertEqual td.row, 2, "clear should leave the cursor row alone"
	qa.assertEqual td.column, 5, "clear should leave the cursor column alone"

	print "setCursor clamps to the grid"
	td.setSize 10, 4
	td.setCursor -5, -5
	qa.assertEqual td.row, 0, "negative row should clamp to 0"
	qa.assertEqual td.column, 0, "negative column should clamp to 0"
	td.setCursor 99, 99
	qa.assertEqual td.row, 3, "too-large row should clamp to rows-1"
	qa.assertEqual td.column, 9, "too-large column should clamp to columns-1"

	print "showCursor / hideCursor invert the cell under the cursor"
	td.setSize 10, 4
	td.setCursor 1, 2
	td.showCursor
	qa.assert td._cellAt(1, 2).inverse, "showCursor should invert the cell"
	td.hideCursor
	qa.assert not td._cellAt(1, 2).inverse, "hideCursor should un-invert the cell"
	qa.assert not td.cursorShown, "hideCursor should clear cursorShown"

	print "the cursor takes the current color, and gives the cell's back"
	td.setSize 10, 4
	td.color = color.yellow
	td.setCursor 1, 2
	td._set 1, 2, "x"				// a cell written while the color is yellow
	td.color = color.orange			// ...and now the color changes under it
	td.showCursor
	qa.assertEqual td._cellAt(1, 2).color, color.orange,
	  "the cursor should be the current color, not the color the cell was written in"
	td.hideCursor
	qa.assertEqual td._cellAt(1, 2).color, color.yellow,
	  "hiding the cursor should give the cell its own color back"

	print "the shared font loaded"
	qa.assert TextDisplay.font != null and TextDisplay.font.isLoaded, "ScreenFont.png should load"
	qa.assertEqual TextDisplay.font.charWidth, 16, "screen font glyphs are 16 px wide"
	qa.assertEqual TextDisplay.font.charHeight, 24, "screen font glyphs are 24 px tall"

	print "All TextDisplay tests passed!"

	print "== Visual test (look at the app window) =="
	t = display(3)		// soda's Display.Initialize puts a TextDisplay in slot 3
	t.clear
	t.setCursor t.rows - 1, 0
	t.color = color.white
	t.backColor = color.clear
	t.inverse = false

	t.print "TextDisplay visual test"
	t.print "-----------------------"
	t.print ""

	t.print "Text colors: ", ""
	for c in [["red", color.red], ["orange", color.orange], ["yellow", color.yellow],
	   ["lime", color.lime], ["aqua", color.aqua], ["blue", color.blue],
	   ["purple", color.purple], ["pink", color.pink]]
		t.color = c[1]
		t.print c[0] + " ", ""
	end for
	t.color = color.white
	t.print ""

	t.print "Background colors: ", ""
	for c in [["navy", color.navy], ["maroon", color.maroon], ["teal", color.teal],
	   ["olive", color.olive]]
		t.backColor = c[1]
		t.print " " + c[0] + " ", ""
		t.backColor = color.clear
		t.print " ", ""
	end for
	t.print ""

	t.print "Inverse: normal ", ""
	t.backColor = color.black		// inverse swaps color <-> backColor
	t.put char(134)
	t.print " INVERTED ", ""
	t.put char(135)
	t.backColor = color.clear
	t.print " normal again", ""
	t.print ""

	t.print "Tabs:", ""
	t.put char(9)
	t.print "col 8", ""
	t.put char(9)
	t.print "col 16"
	t.print ""

	t.color = color.yellow
	t.print "Wrapping (this line runs past the right edge, so it wraps to the next row):"
	t.print "0123456789" * 8
	t.color = color.white
	t.print ""

	t.print "Special glyphs: " + char(8592) + char(8593) + char(8594) + char(8595) +
	   " " + char(9824) + char(9827) + char(9829) + char(9830) +
	   " " + char(960) + char(964) + " " + char(9856) + char(9857) + char(9858) +
	   " " + char(9744) + char(9745) + char(9746) + " unknown: " + char(20013)
	t.print ""

	t.color = color.lime
	t.print "All TextDisplay tests passed!  (Solid cursor below.)"
	t.showCursor

	while not rl.WindowShouldClose
		yield
	end while
	exit
else
	return TextDisplay
end if
