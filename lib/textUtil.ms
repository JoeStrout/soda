// Text Utilities (related to displaying text on the Mini Micro screen).

// (Note that importing this module imports stringUtil, and therefore adds
// some methods directly to the string type.)

import "stringUtil"
import "mathUtil"
max = @mathUtil.max; min = @mathUtil.min

// Print without a carriage return (i.e. moving to the next line).
printNoCR = function(s)
	print s, ""
end function

// Draw a button with the given caption at the cursor position.
drawButton = function(caption)
	text.inverse = not text.inverse
	print char(57856) + caption + char(57857), ""
	text.inverse = not text.inverse
end function

// Print the given string, wrapped on word breaks (spaces) to
// fit in the given width.  Subsequent lines begin at the same
// text.column as the current text.column value.
// Parameters:
//		s: string to print
//		width: character limit per line; if null, goes to edge of screen
//		maxLines: maximum lines to print; or if null, no limit
// Returns: remaining (unprinted) portion of string, or null
printWrap = function(s, width=null, maxLines=null)
	left = text.column
	if width == null then width = 67 - left
	lineCount = 0
	while s
		text.column = left
		if s.len <= width then
			print s
			return null
		end if
		foundCut = false
		for i in range(width, 0, -1)
			if s[i] == " " then
				print s[:i]
				s = s[i+1:]
				foundCut = true
				break
			end if
		end for
		if not foundCut then
			// Couldn't find a space to cut on...
			// so, out of desperation, just cut at width
			print s[:width]
			s = s[width:]
		end if
		lineCount = lineCount + 1
		if maxLines and lineCount == maxLines then return s
	end while
end function

// Get the text column for a given screen pixel X coordinate.
textCol = function(pixelX)
	return floor((pixelX-5)/14)
end function

// Get the text row for a given screen pixel Y coordinate.
textRow = function(pixelY)
	return floor((pixelY-6)/24)
end function

// Print a string starting at the given column and row.
// Also, if you use this to print to row 0, it avoids the usual scrolling.
printAt = function(column, row, s)
	text.row = row
	text.column = column
	if row == 0 then
		// avoid scrolling when printing to the bottom row
		print s, ""
	else
		print s
	end if
end function

// Print a string centered on the given column and row.
printCenteredAt = function(column, row, s)
	printAt column - s.len/2, row, s
end function

// clearToEOL: Clear from the current cursor position to the end of the line
// (by filling the rest of the line with spaces, or whatever character you specify).
// Also applies default foreground and background colors.
clearToEOL = function(character=" ")
	cols = range(text.column, 67)
	text.setCell cols, text.row, character
	text.setCellColor cols, text.row, text.color
	text.setCellBackColor cols, text.row, text.backColor
end function

// clearRow: Clear the entirety of the given row by filling it with spaces
// (or whatever character you specify).
// Also applies default foreground and background colors.
clearRow = function(row=null, character=" ")
	if row == null then row = text.row
	if not row isa list then row = [row]
	allCols = range(0, 67)
	for r in row
		text.setCell allCols, r, character
		text.setCellColor allCols, r, text.color
		text.setCellBackColor allCols, r, text.backColor
	end for
end function

// clearRect: clear a rectangular area of the screen by filling it with spaces
// (or whatever character you specify).
// Also applies default foreground and background colors.
clearRect = function(left=0, bottom=0, width=68, height=25, character=" ")
	for r in range(bottom, bottom+height-1)
		for c in range(left, left+width-1)
			text.setCell c, r, character
			text.setCellColor c, r, text.color
			text.setCellBackColor c, r, text.backColor
		end for
	end for
end function

// buttonLeft and buttonRight: combines the inverse toggles with
// the button cap glyphs.  Print these before or after a button caption.
buttonLeft = char(134) + char(57856)
buttonRight = char(57857) + char(135)

// button function: returns a complete printable button with the given
// caption, optionally padded to some caption length.
button = function(caption, minCaptionLength=0)
	if caption.len < minCaptionLength then
		pad = minCaptionLength - caption.len
		caption = " " * floor(pad/2) + caption + " " * ceil(pad/2)
	end if
	return buttonLeft + caption + buttonRight
end function

// Cell: a little class that represents the complete contents (including
// colors) of a particular row and column on a text display.
Cell = {}
Cell.character = ""
Cell.color = ""
Cell.backColor = ""
Cell.get = function(column, row)
	result = new Cell
	result.character = text.cell(column, row)
	result.color = text.cellColor(column, row)
	result.backColor = text.cellBackColor(column, row)
	return result
end function
Cell.apply = function(column, row)
	text.setCell column, row, self.character
	text.setCellColor column, row, self.color
	text.setCellBackColor column, row, self.backColor
end function

// getContent: Get the entire content of the text display as a 2D array
// of Cell objects in [row][col] order.
// (You can then restore this later with setContent.)
getContent = function
	rows = []
	for row in range(0, 25)
		cols = []
		for col in range(0, 67)
			cols.push Cell.get(col, row)
		end for
		rows.push cols
	end for
	return rows
end function

// setContent: restore the content of the text display with the given
// 2D array of Cell objects in [row][col] order.
setContent = function(data)
	row = 0
	for dataRow in data
		col = 0
		for c in dataRow
			c.apply col, row
			col = col + 1
			if col > 67 then break
		end for
		row = row + 1
		if row > 25 then break
	end for
end function

// getState: get the content of the screen as well as the text
// colors and cursor position.  Use with setState (below).
getState = function
	result = {}
	result.text = getContent
	result.color = text.color
	result.backColor = text.backColor
	result.delimiter = text.delimiter
	result.row = text.row; result.column = text.column
	return result
end function

// setState: set the screen content, text colors, and cursor position
// (as obtained from getState).
setState = function(state)
	setContent state.text
	text.color = state.color
	text.backColor = state.backColor
	text.delimiter = state.delimiter
	text.row = state.row
	text.column = state.column
end function

// Dialog class: used to define a simple message dialog,
// with title, message, and 1-3 buttons.  Create a new Dialog,
// with Dialog.make, assign all its other properties as desired,
// then call .show on it.  The return value is the button that
// was clicked by the user.
Dialog = {}
Dialog.title = "Alert"
Dialog.message = "Your message here."
Dialog.width = 34
Dialog.backColor = "#AAAACC"
Dialog.titleColor = "#CCCCFF"
Dialog.textColor = "#444444"
DialogButton = {}
DialogButton.caption = "Button"
DialogButton.visible = false
DialogButton.key = ""  // shortcut key
DialogButton.width = function; return self.caption.len + 2; end function
DialogButton.x = 20
DialogButton.y = 10
DialogButton.draw = function
	c = text.backColor
	text.row = self.y; text.column = self.x; print buttonLeft, ""
	text.backColor = color.black
	print self.caption, ""
	text.backColor = c
	print buttonRight, ""
end function
DialogButton.contains = function(pt)
	return textRow(pt.y) == self.y and 
	   textCol(pt.x) >= self.x and textCol(pt.x) < self.x + self.width
end function
DialogButton.trackHit = function
	c = text.cellBackColor(self.x, self.y)
	while mouse.button
		text.color = c
		if self.contains(mouse) then text.color = color.lerp(c, color.black)
		self.draw
		yield
	end while
	if text.color == c then return false
	text.color = c
	self.draw
	return true
end function

Dialog.make = function(title="", message="Your message here.")
	dlog = new Dialog
	dlog.title = title
	dlog.message = message
	dlog.okBtn = new DialogButton
	dlog.okBtn.caption = "OK"
	dlog.okBtn.visible = true
	dlog.okBtn.key = char(10)  // (return key)
	dlog.altBtn = new DialogButton
	dlog.cancelBtn = new DialogButton
	dlog.cancelBtn.caption = "Cancel"
	dlog.cancelBtn.key = char(27)
	if title.len > dlog.width then dlog.width = title.len
	dlog.msgLines = message.wrap(dlog.width-4)
	dlog.height = dlog.msgLines.len + 4
	return dlog
end function

Dialog.top = function; return 11 + ceil(self.height/2); end function
Dialog.bottom = function; return 12 - floor(self.height/2); end function
Dialog.left = function; return 34 - floor(self.width/2); end function
Dialog.right = function; return 33 + ceil(self.width/2); end function

// Helper function to draw the dialog and return the button instances.
// Most user code will not call this directly; call Dialog.show instead.
Dialog.draw = function	
	rows = range(self.bottom, self.top)
	cols = range(self.left, self.right)
	
	text.delimiter = char(13)
	x = 34 - self.width/2
	
	// draw title
	text.color = self.textColor
	text.backColor = self.titleColor
	spacesNeeded = self.width - self.title.len
	text.row = rows[-1] + 1; text.column = cols[0]
	print " " * floor(spacesNeeded/2) + self.title + " " * ceil(spacesNeeded/2)
	
	// draw box and content
	text.setCell cols, rows, " "
	text.setCellBackColor cols, rows, self.backColor
	self.drawContent cols, rows
	text.color = self.textColor
	text.backColor = self.backColor
	
	// draw buttons
	btnRow = rows[1]
	btnX = cols[-1] - 1
	buttons = [self.okBtn, self.altBtn, self.cancelBtn]
	for btn in buttons
		if not btn.visible then continue
		text.color = "#CCCCCC"  // (button color)
		if btn.key == char(10) then text.color = "#EEEEFF"
		btn.x = btnX - btn.width
		if btn == self.cancelBtn then btn.x = x + 2
		btn.y = btnRow
		btn.draw
		btnX = btn.x - 2
	end for
	return buttons
end function

// Another internal helper function used to draw the content of the dialog,
// given the range of rows and columns.
Dialog.drawContent = function(cols, rows)
	text.color = self.textColor
	text.backColor = self.backColor
	text.row = rows[-2]
	for line in self.msgLines
		text.column = cols[2]; print line
	end for
end function

// Methods that subclasses can override to do special event processing.
// Return true if event handled, false or null otherwise.  To close
// the dialog, set self.done = true.
Dialog.handleMouse = null
Dialog.handleKey = function(k); end function
Dialog.handleMouseWheel = function(axisValue); end function
Dialog.cleanup = null

// Main entry point: call this to show your dialog, and get back a reference
// to the button that was pressed.
Dialog.show = function(timeout=null)
	priorState = getState
	
	// draw the dialog, and get back the list of visible buttons
	buttons = self.draw
	
	// now wait until we get a key shortcut or a valid click on a button,
	// or (optionally) time out
	btnHit = null
	startTime = time
	self.done = false
	while not btnHit and not self.done
		if mouse.button and not self.handleMouse then
			for btn in buttons
				if not btn.visible or not btn.contains(mouse) then continue
				if btn.trackHit then
					btnHit = btn
					break
				end if
			end for
		end if
		k = null
		if key.available then k = key.get
		if key.pressed("page up") then
			while key.pressed("page up"); yield; end while
			k = char(21)  // control-U
		end if
		if key.pressed("page down") then
			while key.pressed("page down"); yield; end while
			k = char(4)  // control-D
		end if		
		if k != null then
			if self.handleKey(k) then continue
			if k.code == 3 or k.code == 13 then k = char(10)
			for btn in buttons
				if btn.visible and btn.key == k then
					btnHit = btn
					break
				end if
			end for
		end if
		if timeout != null and time > startTime + timeout then break
		wheelValue = key.axis("Mouse ScrollWheel")
		if wheelValue then self.handleMouseWheel(wheelValue)
		yield
	end while
	
	setState priorState	
	self.cleanup
	return btnHit
end function

// FileDialog: a Dialog subclass specialized for picking a folder or file.
// It's a three-column layout: the middle column (1) always contains the
// selection; column 0 is the directory containing the selection (or "root");
// and column 2 is a preview of the contents of the selected file/directory.
FileDialog = new Dialog
FileDialog.width = 50
FileDialog.listTextColor = "#AAAAFF"
FileDialog.listBackColor = "#222222"
FileDialog.curDirBackColor = "#444466"
FileDialog.selTextColor = "#000044"
FileDialog.selBackColor = "#FFFF00"
FileDialog.dirIndColor = color.lerp(FileDialog.listTextColor, FileDialog.listBackColor, 0.5)
FileDialog.directoryIcon = "/"
FileDialog.playingSound = null
FileDialog.origDisp0 = null
FileDialog.selection = ""
FileDialog.make = function(title="Select file", width=null)
	dlog = Dialog.make(title)
	dlog.__isa = FileDialog
	dlog.okBtn.caption = "Select"
	dlog.height = 18
	dlog.cancelBtn.visible = true
	dir = file.curdir
	if file.children(file.curdir) == null then dir = "/sys"
	dlog.directory = dir - "/"
	files = file.children(dir)
	if files then dlog.selection = file.child(dir, files[0])
	dlog.files = []
	if width != null then dlog.width = width
	dlog.colWidth = []
	dlog.colWidth.push floor((dlog.width-4)/3)
	dlog.colWidth.push dlog.colWidth[0]
	dlog.colWidth.push dlog.width - 6 - dlog.colWidth[0]*2
	dlog.colLeft = [dlog.left+2]
	dlog.colLeft.push dlog.colLeft[0] + 1 + dlog.colWidth[0]
	dlog.colLeft.push dlog.colLeft[1] + 1 + dlog.colWidth[1]
	dlog.files = FileDialog.getFileInfoForDir(dlog.directory)
	dlog.scroll = [0,0,0]	// (number of rows scrolled off the top, per column)
	dlog.selIdx = 0
	return dlog
end function

FileDialog.select = function(path)
	self.stopPreview
	self.selection = path
	dir = file.parent(path)
	changedDir = false
	if dir != self.directory then
		self.directory = dir
		self.drawCurDir
		self.drawParentDir
		self.files = FileDialog.getFileInfoForDir(self.directory)
		changedDir = true
	end if
	for i in self.files.indexes
		if self.files[i].path == path then
			self.selIdx = i
			break
		end if
	end for
	if changedDir then self.scrollIntoView 1, self.files, self.selIdx
end function

FileDialog.getFileInfoForDir = function(dir)
	files = file.children(dir)
	if not files then return []
	for i in range(files.len - 1)
		files[i] = file.info(file.child(dir, files[i]))
		if files[i] == null then
			files.remove i
		else
			files[i].name = file.name(files[i].path)
		end if
	end for
	files.sort "name"
	return files
end function	

FileDialog.highlightedInCol0 = function
	f = self.files
	for i in f.indexes
		if f[i].isDirectory and self.selection.startsWith(f[i].path+"/") then
			return i
		end if
	end for
end function

FileDialog.highlightedInColumn = function(colNum)
	if colNum == 0 then return self.highlightedInCol0
	if colNum == 1 then return self.selIdx
	return 0
end function

FileDialog.scrollIntoView = function(colNum, files, selectedIndex, padding=2)
	posInView = selectedIndex - self.scroll[colNum]
	if posInView < padding then
		self.scroll[colNum] = max(0, selectedIndex - padding)
		return
	end if
	if files == null then files = self.files
	rows = self.height - 5
	if posInView > rows - padding then
		self.scroll[colNum] = selectedIndex - rows + padding
	end if
end function

FileDialog.drawFiles = function(colNum=1, files=null)
	if files == null then files = self.files
	width = self.colWidth[colNum]
	text.row = self.top - 2
	rows = self.height - 5
	highlightedIdx = self.highlightedInColumn(colNum)	
	scroll = self.scroll[colNum]
	
	for row in range(0, rows-1)
		idx = scroll + row
		hilight = false; selected = false; isDir = false; s = ""
		if files and idx < files.len then
			f = files[idx]
			s = f.name
			isDir = f.isDirectory
			if self.selection.startsWith(f.path) then hilight = true
			if colNum == 1 and idx == self.selIdx then selected = true
		end if
		s = s.pad(width)
		if selected then
			text.color = self.selTextColor
			text.backColor = self.selBackColor
		else
			text.color = self.listTextColor
			text.backColor = self.curDirBackColor * hilight + self.listBackColor * (not hilight)
		end if
		text.column = self.colLeft[colNum]; print s, ""
		if isDir then
			text.color = self.dirIndColor
			print char(8) + self.directoryIcon
			text.color = self.listTextColor
		else
			print
		end if
	end for
end function

FileDialog.drawParentDir = function
	if self.directory == "/" then
		text.row = self.top - 2
		text.column = self.colLeft[0]
		text.color = self.listTextColor
		text.backColor = self.listBackColor
		print "(disks)".pad(self.colWidth[0]-1), ""
		text.color = self.dirIndColor; print self.directoryIcon
		for row in range(1, self.height-6)
			text.column = self.colLeft[0]; print " " * self.colWidth[0]
		end for
	else
		files = FileDialog.getFileInfoForDir(file.parent(self.directory))
		self.drawFiles 0, files
	end if
end function

FileDialog.drawPreviewText = function(lines)
	text.color = self.listTextColor
	text.backColor = self.listBackColor
	text.row = self.top - 2
	TAB = char(9)
	for row in range(0, self.height-6)
		text.column = self.colLeft[2]
		if row < lines.len then s = lines[row].replace(TAB, "  ") else s = ""
		print s.pad(self.colWidth[2])
	end for	
end function

FileDialog.drawPreview = function
	if not (0 <= self.selIdx < self.files.len) then
		self.drawPreviewText []
		return
	end if
	f = self.files[self.selIdx]
	if f.isDirectory then
		self.drawFiles 2, FileDialog.getFileInfoForDir(f.path)
		return
	end if
	n = f.name
	if n.endsWith(".ms") or n.endsWith(".txt") or n.endsWith(".md") or
	  n.endsWith(".json") or n.endsWith(".grfon") then
		inp = file.open(f.path)
		lines = []
		for i in range(0, self.height-6)
			line = inp.readLine; if line == null then break
			lines.push line
		end for
		inp.close
		self.drawPreviewText lines
		return
	end if
	if n.endsWith(".wav") or n.endsWith(".ogg") then
		snd = file.loadSound(f.path)
		if snd != null then
			snd.play
			self.playingSound = snd
			self.drawPreviewText ["Sound", "", "duration:", str(snd.duration)]
			return
		end if
	end if
	if n.endsWith(".jpg") or n.endsWith(".jpeg") or n.endsWith(".png") then
		self.drawPreviewText []
		pic = file.loadImage(f.path)
		if pic != null then
			self.origDisp0 = display(0)
			if val(version.host) < 2.0 then disp = new PixelDisplay else disp = PixelDisplay.Make
			disp.clear color.clear
			disp.install 0
			x = (self.colLeft[2] + self.colWidth[2]/2)*14.05
			y = (self.top-2 - (self.height-6)/2) * 25
			w = self.colWidth[2] * 14
			h = (self.height-6) * 24
			scaleH = w/pic.width; scaleV = h/pic.height
			if scaleH < scaleV then scale = scaleH else scale = scaleV
			disp.drawImage pic, x-pic.width*scale/2, y-pic.height*scale/2,
			  pic.width*scale, pic.height*scale
		end if
		return
	end if
	self.drawPreviewText []
end function

FileDialog.stopPreview = function
	if self.playingSound then
		self.playingSound.stop
		self.playingSound = null
	end if	
	if self.origDisp0 then
		intrinsics.print "Installing: " + self.origDisp0
		self.origDisp0.install 0
		if self.origDisp0.mode == 0 then display(0).mode = 0 // (work-around for MM1.x)
		self.origDisp0 = null
	end if
end function
FileDialog.cleanup = @FileDialog.stopPreview

FileDialog.drawContent = function(cols, rows)
	self.drawCurDir
	self.drawParentDir		// leftmost column
	self.drawFiles			// center column
	self.drawPreview
end function

FileDialog.drawCurDir = function
	text.color = self.textColor; text.backColor = self.backColor
	text.row = self.top - 1; text.column = self.left + 2
	print self.directory.pad(self.width-4)
end function

FileDialog.selectIdx = function(newSelIdx, padding=6)
	if not self.files then
		self.selIdx = -1
		return
	end if
	self.selIdx = newSelIdx % self.files.len
	if self.selIdx < 0 then self.selIdx += self.files.len
	self.scrollIntoView 1, self.files, self.selIdx, padding
	self.select self.files[self.selIdx].path
	self.drawFiles
	self.drawPreview
	return true
end function

FileDialog.handleKey = function(k)
	self.stopPreview
	kcode = k.code
	count = self.files.len
	rows = self.height - 6
	if kcode == 19 then return self.selectIdx(self.selIdx-1)	// up-arrow
	if kcode == 20 then return self.selectIdx(self.selIdx+1)	// down-arrow
	if kcode == 1 then return self.selectIdx(0)					// Home
	if kcode == 5 then return self.selectIdx(count-1)			// End
	if kcode == 21 then return self.selectIdx(
			mathUtil.clamp(self.selIdx - rows, 0, count-1))		// Page Up
	if kcode == 4 then return self.selectIdx(
			mathUtil.clamp(self.selIdx + rows, 0, count-1))		// Page Down
	if kcode == 10 or kcode == 3 or kcode == 18 then	// return or right-arrow
		if not (0 <= self.selIdx < self.files.len) then return false
		info = self.files[self.selIdx]
		if not info.isDirectory then return false
		files = file.children(info.path)
		if files then self.select file.child(info.path, files[0])
		self.drawFiles
		self.drawPreview
		return true
	else if kcode == 17 then							// left-arrow
		parent = file.parent(self.selection)
		if parent == "/" then return true
		self.select self.directory
		self.drawFiles
		self.drawPreview
		return true
	end if
	for i in self.files.indexes
		if self.files[i].name[0].lower == k then return self.selectIdx(i)
	end for
end function

FileDialog.handleMouse = function
	row = textRow(mouse.y)
	if row > self.top-2 or row < self.top-2 - (self.height-6) then return false
	col = textCol(mouse.x)
	if col >= self.colLeft[0] and col < self.colLeft[0]+self.colWidth[0] then
		hitColumn = 0		// parent directory column
		files = FileDialog.getFileInfoForDir(file.parent(self.directory))
	else if col >= self.colLeft[1] and col < self.colLeft[1]+self.colWidth[1] then
		hitColumn = 1		// selection column
		files = self.files
	else if col >= self.colLeft[2] and col < self.colLeft[2]+self.colWidth[2] then
		hitColumn = 2		// preview column
		files = FileDialog.getFileInfoForDir(self.selection)
		if not files then return false
	else
		return false
	end if
	hitIdx = self.top - 2 - row + self.scroll[hitColumn]
	if not files or hitIdx >= files.len then return false

	self.select files[hitIdx].path
	self.drawFiles
	self.drawPreview
	while mouse.button; yield; end while
	return true
end function

FileDialog.handleMouseWheel = function(axisValue)
	if axisValue > 0 then
		self.selectIdx(self.selIdx-1)
	else
		self.selectIdx(self.selIdx+1)
	end if
	wait 0.1  // pause a little between scrolls
end function

if locals == globals then
	d = Dialog.make("Message Test", 
	"Hello world!  This is a test of the nifty text-based Dialog system.")
	d.altBtn.visible = true
	d.altBtn.key = "b"
	d.altBtn.caption = "FileDialog"
	d.cancelBtn.visible = true
	btnHit = d.show
	print "You hit: " + btnHit.caption
	if btnHit == d.altBtn then
		d = FileDialog.make
		hit = d.show
		if hit == d.okBtn then print "You selected: " + d.selection	
	end if
end if
