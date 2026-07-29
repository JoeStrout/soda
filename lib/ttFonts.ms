// This module adds a TTFont class, representing a TrueType font rendered
// with Raylib, with an API meant to mimic bmfFonts.Font.  That makes them
// mostly interchangeable to user code.

rl = raylib

import "miscUtil"
ensureImport "stringUtil"

Emoji = {}
Emoji.image = null	  // image to draw
Emoji.ascent = null   // pixels between baseline and top of image; defaults to image height
Emoji.applyColor = false  // if true, tint with text color; if false, don't

Emoji.release = function
	if self.image then self.image.release
	self.image = null
end function

Emoji.Make = function(imageOrPath, ascent=null)
	noob = new self
	if imageOrPath isa string then imageOrPath = file.loadImage(imageOrPath)
	if not imageOrPath isa Image then
		print "Invalid image/path in Emoji.Make"
		print stackTrace
		exit
	end if
	noob.image = imageOrPath
	if ascent then noob.ascent = ascent else noob.ascent = noob.image.height
	return noob
end function

TTFont = {}
TTFont._font = null  // Raylib font
TTFont._size = 0	 // loaded point size
TTFont.ascent = 0    // font ascent (best estimate)

TTFont.emoji = {}  // key: character or string; value: Emoji object

TTFont.Load = function(path, size=24)
	// ToDo: provide a way to load more (non-ASCII) characters, perhaps
	// the standard Mini Micro character set?
	font = new TTFont
	font._font = rl.LoadFontEx(path, size)
	font._size = size
	if not font._font or not rl.IsFontValid(font._font) then
		print "ERROR: TTFont: unable to load font at " + path
		font._font = null
		exit
	end if
	info = rl.GetGlyphInfo(font._font, "M".code)
	font.ascent = size - info.offsetY
	
	// silly measures for compatibility with BMFFont:
	font.sizeOver = -font.ascent
	font.sizeUnder = size - font.ascent
	font.lineHeight = size
	
	return font
end function

TTFont.unload = function
	if self._font then
		rl.UnloadFont(self._font)
		self._font = null
	end if
	for emoji in self.emoji.values
		if emoji.image then emoji.image.release
	end for		
end function

// Render (draw) the given character to gfx, and return how
// far to shift the cursor.
TTFont.printChar = function(c, x=480, y=320, scale=1, tint="#FFFFFF")
	rl.BeginTextureMode gfx._renderTex
	// Use normal color blending for RGB, but MAX mode for alpha,
	// so that our font rendering doesn't punch holes in the pixel layer.
	rl.rlSetBlendFactorsSeparate 770, 771, 0, 1, 32774, 32776
	rl.BeginBlendMode 7
	
	if self.emoji.hasIndex(c) then
		emoji = self.emoji[c]
		tex = emoji.image.texture
		rl.SetTextureFilter tex, rl.TEXTURE_FILTER_POINT
		src = [0, 0, emoji.image.width, emoji.image.height]
		dest = [x, gfx.height - y - emoji.ascent,
		  emoji.image.width * scale, emoji.image.height * scale]
		if emoji.applyColor then c = tint else c = rl.WHITE
		rl.DrawTexturePro tex, src, dest, [0, 0], 0, c
	else
		rl.DrawTextCodepoint self._font, c.code, [x, gfx.height - y - self.ascent * scale], self._size * scale, tint
	end if
	
	rl.EndBlendMode
	rl.EndTextureMode
	info = rl.GetGlyphInfo(self._font, c.code)
	return info.advanceX
end function

// Given a string, split into a list of plain strings and Emoji.
TTFont._splitIntoParts = function(s)
	if not s or not self.emoji then return [s]
	result = []
	startIdx = 0
	endIdx = startIdx
	emojiKeys = self.emoji.indexes
	while endIdx < s.len
		for emk in emojiKeys
			if s[endIdx:endIdx + emk.len] == emk then
				// found an emoji!  Grab the string up to that point...
				if endIdx > startIdx then
					result.push s[startIdx:endIdx]
				end if
				// then grab the Emoji object
				result.push self.emoji[emk]
				// and advance past the emoji
				startIdx = endIdx + emk.len
				endIdx = startIdx - 1
				break
			end if
		end for
		endIdx += 1
	end while
	// Grab last part of string
	if startIdx < s.len then result.push s[startIdx:]
	return result
end function

// Print the given string to gfx at the given location.
TTFont.print = function(s, x=20, y=320, scale=1, tint="#FFFFFF")
	if not s then return
	gfx._beginDraw
	// Use normal color blending for RGB, but MAX mode for alpha,
	// so that our font rendering doesn't punch holes in the pixel layer.
	rl.rlSetBlendFactorsSeparate 770, 771, 0, 1, 32774, 32776
	rl.BeginBlendMode 7
	size = self._size * scale
	
	for part in self._splitIntoParts(s)
		if part isa Emoji then
			tex = part.image.texture
			rl.SetTextureFilter tex, rl.TEXTURE_FILTER_POINT
			src = [0, 0, part.image.width, part.image.height]
			dest = [x, gfx.height - y - part.ascent,
			  part.image.width * scale, part.image.height * scale]
			rl.DrawTexturePro tex, src, dest, [0, 0], 0, [255, 255, 255, 255]
			x += round(dest[2])	
		else
			rl.DrawTextEx self._font, part, 
			  [x, gfx.height - y - self.ascent * scale], size, 0, tint
			x += rl.MeasureTextEx(self._font, part, size, 0).x		
		end if
	end for

	rl.EndBlendMode
	gfx._endDraw
end function

// Print the given string to gfx, centered horizontally on the given x.
TTFont.printCentered = function(s, x=480, y=320, scale=1, tint="#FFFFFF")
	self.print s, x - self.width(s, scale)/2, y, scale, tint
end function

// Print the given string to gfx, right-aligned on x.
TTFont.printRight = function(s, x=940, y=320, scale=1, tint="#FFFFFF")
	self.print s, x - self.width(s, scale), y, scale, tint
end function

// Return the width of the given string in this font.
TTFont.width = function(s, scale=1)
	width = 0
	for part in self._splitIntoParts(s)
		if part isa Emoji then
			width += round(part.image.width * scale)	
		else
			width += rl.MeasureTextEx(self._font, part, self._size * scale, 0).x		
		end if
	end for
	return width
end function

// Return the number of characters of the given string that
// fit a given width.
TTFont.lenToFit = function(s, width=100)
	if not s or not (s isa string) then return 0
	if self.width(s) <= width then return s.len
	lo = 1
	hi = s.len
	while lo + 1 < hi
		mid = floor((lo + hi) / 2)
		if self.width(s[:mid]) <= width then
			lo = mid
		else
			hi = mid
		end if
	end while
	return lo
end function

// Wrap a long text into multiple lines, breaking on words,
// as needed to fit within the given width.  Return a list of strings.
TTFont.wrapLines = function(s="", width=550)
	if not s then return [""]
	result = []

	EOL = char(10)
	result = []
	if s.indexOf(EOL) != null then 
		// handle paragraphs via recursion
		for paragraph in s.split(EOL)
			result += self.wrapLines(paragraph, width)
		end for
		return result
	end if

	while true
		lenToFit = self.lenToFit(s, width)
		if lenToFit+1 >= s.len then
			result.push s
			break
		end if
		while lenToFit > 1
			c = s[lenToFit]
			if c <= " " then break
			lenToFit -= 1
		end while
		if lenToFit == 1 then lenToFit = self.lenToFit(s, width)
		result.push s[:lenToFit]
		s = s[lenToFit:].trimLeft
	end while
	return result
end function

TTFont.printWrapped = function(s="", x, y, wrapWidth, tint="#FFFFFF")
	lines = self.wrapLines(s, wrapWidth)
	for line in lines
		self.print line, x, y, 1, tint
		y = y - self.lineHeight
	end for
	return y
end function

if locals == globals then
	import "soda"
	
	f = TTFont.Load("fonts/NotoSerif-Regular.ttf")
	print "f._font: " + f._font
	x = 20; y = 0
	//for x in range(-600, 600, 100)
		x += f.printChar("A", x, y)
		x += f.printChar("b", x, y)
		x += f.printChar("c", x, y)
	//end for

	f.print "Hello world!", 400, 200
	w = f.width("Hello world!")
	gfx.line 400, 200, 400+w, 200, color.yellow
	f.print "Width of that was: " + w, 400, 150

	while true
		yield
		raylib.BeginDrawing
		soda.update
		raylib.EndDrawing		
	end while
	
end if