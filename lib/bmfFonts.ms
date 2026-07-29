// This module defines a Font class which can read fonts in BMF format
// version 1.1 or 1.2.  Reference: https://bmf.php5.cz/index.php?page=format
//
// Example of basic usage:
//	 f = Font.load(fontFilePath)
//	 w = f.width("Hello world!")
//   f.print "Hello world!", 480 - w/2, 320

// CharData class, storing data about just one character in a particular font.
CharData = {}
CharData._name = "bmfFonts.CharData";

// Helper function to load one character into the given
// charData map.  Return the next data position after
// the character has been read (i.e., position of next char).
CharData.load = function(data, pos)
	self.width = data.byte(pos)
	self.height = data.byte(pos+1)
	self.relX = data.sbyte(pos+2)
	self.relY = data.sbyte(pos+3)
	self.shift = data.sbyte(pos+4)
	self.colors = []
	self.image = null
	pos = pos + 5
	bytes = self.width * self.height
//	print "For " + self.charCode + " (" + char(self.charCode) + ") " + self.width+"x"+self.height + " char at " + pos + ", expecting " + bytes + " bytes of data"
	if pos + bytes > data.len then
		print "ERROR: unexpected end of data"
		return pos + bytes
	end if
	if bytes then
		for i in range(0, bytes-1)
			self.colors.push data.byte(pos+i)
		end for
	end if
	return pos + bytes
end function

hexStrToInt = {}
for i in range(0,255); hexStrToInt[hex2(i)] = i; end for

// Find the colors array from our image and the given palette map,
// which maps each usable color to an index (1 to number of colors).
// Note that an index of 0 always means "don't draw" (transparent).
// Also, this function has no effect if self.image is null.
CharData.findColorsFromImage = function(paletteMap, alphaBits)
	if not self.image then return
	self.colors = []
	for bitmapY in range(self.height - 1)
		for bitmapX in range(0, self.width - 1)
			c = self.image.pixel(bitmapX, bitmapY)
			alpha = c[-2:]; c = c[:-2]
			if paletteMap.hasIndex(c) then
				colorIdx = paletteMap[c]
			else
				colorIdx = 0
			end if
			if alphaBits == 8 then
				// when alphaBits is 8, ignore the actual color
				// and just store the alpha instead.
				colorIdx = hexStrToInt[alpha]
			else if alphaBits == 0 then
				// and when it's 0, still skip (use index 0 for) any transparent pixel
				if alpha == "00" then colorIdx = 0
			end if
			self.colors.push colorIdx
		end for
	end for
end function

// Write the data for this character out to a binary stream (defined
// in Font.save, below).  This is a helper method for Font.save.
CharData.save = function(stream, paletteMap, alphaBits)
	stream.writeByte self.width
	stream.writeByte self.height
	stream.writeByte self.relX
	stream.writeByte self.relY
	stream.writeByte self.shift
	if self.width or self.height then
		self.findColorsFromImage paletteMap, alphaBits
		for c in self.colors
			stream.writeByte c
		end for
	end if
end function

// Font class, storing all data about a particular font.
Font = {}
Font._name = "bmfFonts.Font";
Font.data = null	// raw data from file
Font.chars = null   // key: character; value: charData map
Font.kernMap = null  // key: char1; value: map from char2->kern
Font.setKern = function(c1, c2, kern)
	if self.kernMap == null then self.kernMap = {}
	if not self.kernMap.hasIndex(c1) then self.kernMap[c1] = {}
	self.kernMap[c1][c2] = kern
end function
Font.kern = function(c1, c2)
	if self.kernMap == null then return 0
	if not self.kernMap.hasIndex(c1) then return 0
	km = self.kernMap[c1]
	if not km.hasIndex(c2) then return 0
	return km[c2]
end function

// Font.load: Main entry point for reading a font from disk.
// Call this on the Font class itself (i.e. not an instance).
// Pass in the path to the font file; get back a new Font object.
Font.load = function(path)
	data = file.loadRaw(path)
	if data == null then return null
	
	f = new  Font
	f.data = data
	f.chars = {}
	data.littleEndian = true
	vers = data.byte(4)
	f.version = floor(vers/16) + 0.1 * (vers % 16)
	f.lineHeight = data.sbyte(5)
	f.sizeOver = data.sbyte(6)
	f.sizeUnder = data.sbyte(7)
	f.addSpace = data.sbyte(8)
	f.sizeInner = data.sbyte(9)
	f.usedColors = data.byte(10)
	f.highestUsedColor = data.byte(11)
	f.alphaBits = 0
	f.numPalettes = 1
	if f.version >= 1.2 then
		f.alphaBits = data.byte(12)
		f.numPalettes = data.byte(13) + 1
	end if
	palSize = data.byte(16)
	f.palette = []
	for i in range(0, palSize-1)
		f.palette.push color.rgb(data.byte(17+i*3)*4, data.byte(18+i*3)*4, data.byte(19+i*3)*4)
	end for
	titleLen = data.byte(17+palSize*3)
	f.title = data.utf8(18+palSize*3, titleLen)
	//print f.title
	pos = 18 + palSize*3 + titleLen
	
	// Read ASCII characters
	numAsciiChars = data.short(pos)
	pos = pos + 2
	
	for i in range(1, numAsciiChars, 1)
		// Read one character
		p0 = pos
		charData = new CharData
		charData.charCode = data.byte(pos)
		pos = pos + 1
		pos = charData.load(data, pos)
		
		f.chars[char(charData.charCode)] = charData
	end for
	if f.version < 1.2 or pos >= data.len then return f
	
	// Read non-ASCII characters
	numOtherChars = data.uint(pos)
	pos = pos + 4
	for i in range(1, numOtherChars, 1)
		// Read one character
		charData = new CharData
		charData.charCode = data.uint(pos)
		pos = pos + 4
		pos = charData.load(data, pos)
		
		f.chars[char(charData.charCode)] = charData
	end for
	
	// Read kerning info
	if pos >= data.len then return f
	kernCount = data.ushort(pos)
	//print kernCount + " kerning pairs"
	if kernCount > 0 then
		pos = pos + 2
		for i in range(1, kernCount, 1)
			c1 = data.uint(pos)
			c2 = data.uint(pos+4)
			k = data.short(pos+8)
			f.setKern char(c1), char(c2), k
			pos = pos + 10
		end for
	end if
	return f
end function

// Font.save: Save this font to disk, in either version 1.1
// or version 1.2 format (depending on self.version).  Note
// that this method ignores self.data, and creates new data
// from the current font attributes and character data.
Font.save = function(path)
	// We'll need a little BinaryStream class wrapping a RawData,
	// to make it easier.  This just expands the RawData buffer as we go.
	BinaryStream = {}
	BinaryStream.littleEndian = true
	BinaryStream.buffer = null
	BinaryStream.pos = 0
	BinaryStream.ensure = function(bytesNeeded=4)
		if self.buffer == null then
			self.buffer = new RawData
			self.buffer.resize 256
			self.buffer.littleEndian = self.littleEndian
		end if		
		while self.pos + bytesNeeded > self.buffer.len
			self.buffer.resize(self.buffer.len * 2)
		end while
	end function
	BinaryStream.writeByte = function(byteVal)
		self.ensure 1
		self.buffer.setByte self.pos, byteVal
		self.pos = self.pos + 1
	end function
	BinaryStream.writeSbyte = function(sbyteVal)
		self.ensure 1
		self.buffer.setSbyte self.pos, sbyteVal
		self.pos = self.pos + 1
	end function
	BinaryStream.writeUshort = function(ushortVal)
		self.ensure 2
		self.buffer.setUshort self.pos, ushortVal
		self.pos = self.pos + 2
	end function
	BinaryStream.writeUint = function(uintVal)
		self.ensure 4
		self.buffer.setUint self.pos, uintVal
		self.pos = self.pos + 4
	end function
	BinaryStream.writeUtf8 = function(utf8Str)
		// It's hard to know how many bytes to ensure.  But most UTF-8
		// characters require 3 bytes or less, so this is probably safe:
		self.ensure utf8Str.len*3
		bytesUsed = self.buffer.setUtf8(self.pos, utf8Str)
		self.pos = self.pos + bytesUsed
		return bytesUsed
	end function
	BinaryStream.writeLenPrefixedString = function(s)
		if s.len > 255 then s = s[:255]
		self.ensure s.len*3 + 1
		bytesUsed = self.buffer.setUtf8(self.pos + 1, s)
		self.buffer.setByte(self.pos, bytesUsed)
		self.pos = self.pos + bytesUsed + 1
	end function
	
	// Gather statistics we will need later.
	lowCharCount = 0
	highCharCount = 0
	for c in self.chars.indexes
		if c.code < 256 then lowCharCount = lowCharCount + 1 else highCharCount = highCharCount + 1
	end for
	if not self.hasIndex("usedColors") then self.usedColors = self.palette.len
	if not self.hasIndex("highestUsedColor") then self.highestUsedColor = self.palette.len
	
//	print "Saving version " +self.version + " file with " + highCharCount + " high chars"
	
	paletteMap = {}  // key: color (sans alpha); value: color index + 1
	for i in self.palette.indexes
		paletteMap[self.palette[i]] = i + 1
	end for
	
	// Now we can use that to write out our BMF data.
	data = new BinaryStream
	data.littleEndian = true
	
	// magic header
	data.writeUint 450225889
	
	// version
	if self.version <= 1.1 then
		data.writeByte 17  // 0x11
	else
		data.writeByte 18  // 0x12
	end if
	
	// various font attributes
	data.writeByte self.lineHeight
	data.writeSbyte self.sizeOver
	data.writeSbyte self.sizeUnder
	data.writeSbyte self.addSpace
	data.writeSbyte self.sizeInner
	data.writeByte self.usedColors
	data.writeByte self.highestUsedColor
	if self.version > 1.1 then
		data.writeByte self.alphaBits
		data.writeByte self.numPalettes - 1
	else
		data.pos = data.pos + 2
	end if
	data.pos = data.pos + 2
	data.writeByte self.palette.len
	for p in self.palette
		pl = color.toList(p)
		data.writeByte pl[0]/4		// red (0-63)
		data.writeByte pl[1]/4		// green
		data.writeByte pl[2]/4		// blue
	end for
	data.writeLenPrefixedString(self.title)
	print "Writing " + lowCharCount + " low chars"
	data.writeUshort lowCharCount
	
	// write out the low characters (Unicode < 256) first
	for c in self.chars.indexes
		if c.code > 255 then continue
		p0 = data.pos
		data.writeByte c.code
		self.chars[c].save data, paletteMap, self.alphaBits
		//print "Wrote " + c.code + " (" + c + ") with " + (data.pos-p0) + " bytes at " + p0
	end for
	
	if self.version > 1.1 then
		// write the high characters (Unicode > 255) next
		data.writeUint highCharCount
		for c in self.chars.indexes
			if c.code < 256 then continue
			data.writeUint c.code
			self.chars[c].save data, paletteMap, self.alphaBits
		end for
		
		// write the kern map
		kernCount = 0
		if self.kernMap then
			for submap in self.kernMap.values
				kernCount = kernCount + submap.len
			end for
			data.writeUshort kernCount
			print "Writing " + kernCount + " kern entries"
			for k1 in self.kernMap.keys
				k1Map = self.kernMap[k1]
				for k2 in k1Map.keys
					data.writeUint k1.code
					data.writeUint k2.code
					data.writeShort k1Map[k2]
				end for
			end for
		else
			data.writeUshort kernCount
		end if
	end if
	
	// Finally, write this to a file.
	print "Saving " + data.pos + " bytes of data to " + path
	data.buffer.resize data.pos
	err = file.saveRaw(path, data.buffer)
	return err
end function

// Get the character data for the given character
// Return null if not found.  (But if we fail to find
// a lowercase letter, automatically look for upper case.)
Font.charData = function(c)	
	if self.chars.hasIndex(c) then return self.chars[c]
	c = c.upper
	if self.chars.hasIndex(c) then return self.chars[c]
	return null	
end function

// Add a new character to this font.  Parameters are as follows:
//	c: character (string) to add
//	image: image of the character glyph
//	relX, relY: where to draw this image relative to the baseline cursor
//  shift: how much to move the baseline cursor after drawing;
//		if null, this defaults to image.width
Font.addChar = function(c, image, relX=0, relY=0, shift=null)
	if shift == null then shift = image.width
	cd = new CharData
	cd.charCode = c.code
	cd.image = image
	cd.width = image.width; cd.height = image.height
	cd.relX = relX; cd.relY = relY
	cd.shift = shift
	self.chars[c] = cd
end function

// Render the given character into any drawing context 'g'
// which has setPixel method.  This includes both Image
// and PixelDisplay.  Note that for character 'c' you can
// either pass in a string (the character), or a CharData object.
// (Most users will use print or printChar, below.)
Font.renderChar = function(c, g, destX=0, destY=0)
	if c isa string then d = self.charData(c) else d = c
	if d == null then return null
	clrRange = 2^(8 - self.alphaBits)
	alphaScale = 255/(2^self.alphaBits - 1)
	baseColor = self.palette[0]
	if d.width and d.height then
		i = 0
		for bitmapY in range(d.height - 1)
			for bitmapX in range(0, d.width - 1)
				c = d.colors[i]
				i = i + 1
				if not c then continue
				if self.alphaBits == 8 then
					a = floor(c / clrRange) * alphaScale
					pixelColor = baseColor + hex2(a)
				else if self.alphaBits > 0 then
					// ToDo: handle this case.
					// Seems like we should be looking in self.palette
					// with the remaining bits of c, rather than using
					// baseColor.				
				else
					pixelColor = self.palette[c-1]
				end if
				g.setPixel destX + bitmapX, destY + bitmapY, pixelColor
			end for
		end for		
	end if
end function

// Make and return an Image of the given character.
Font.makeCharImage = function(c)
	d = self.charData(c)
	if d == null then return null
	img = Image.create(d.width, d.height, color.clear)
	self.renderChar d, img
	return img
end function

// Get an Image that represents the given character.
// This method uses a cache, so is faster after the first call.
Font.getCharImage = function(c)
	d = self.charData(c)
	if d == null then return null
	if d.image == null then d.image = self.makeCharImage(c)
	return d.image
end function

// Render (draw) the given character to gfx, and return how
// far to shift the cursor.  This uses the image cache, so
// it gets faster after the first drawing of each character.
Font.printChar = function(c, x=480, y=320, scale=1, tint="#FFFFFF")
	d = self.charData(str(c))
	if d == null then return 0
	if d.image == null and d.width > 0 then d.image = self.makeCharImage(c)
	x = x + d.relX
	if d.image != null then
		if scale == 1 then
			y = y - self.sizeOver - self.sizeUnder - d.relY - d.image.height
			gfx.drawImage d.image, x, y, d.image.width, d.image.height,
			  0, 0, d.image.width, d.image.height, tint
		else
			y = y + scale * (-self.sizeOver - self.sizeUnder - d.relY - d.image.height)
			gfx.drawImage d.image, x, y, d.image.width*scale, d.image.height*scale,
			  0, 0, d.image.width, d.image.height, tint
		end if
	end if
	return d.shift * scale
end function

// Print the given string to gfx at the given location.
Font.print = function(s, x=20, y=320, scale=1, tint="#FFFFFF")
	s = str(s)
	lastc = ""
	for c in s
		x = x + self.kern(lastc, c) * scale
		x = x + self.printChar(c, x, y, scale, tint) + self.addSpace * scale
		lastc = c
	end for
end function

// Print the given string to gfx, centered horizontally on the given x.
Font.printCentered = function(s, x=480, y=320, scale=1, tint="#FFFFFF")
	s = str(s)
	self.print s, x - self.width(s, scale)/2, y, scale, tint
end function

// Print the given string to gfx, right-aligned on x.
Font.printRight = function(s, x=940, y=320, scale=1, tint="#FFFFFF")
	s = str(s)
	self.print s, x - self.width(s, scale), y, scale, tint
end function

Font.printJustified = function(s, x, y, width=500, scale=1, tint="#FFFFFF")
    words = s.split
    w = 0
    for word in words; w += self.width(word, scale); end for
    ew = width - w // ("extra width")
    ewPerWord = floor(ew/(words.len-1))
    for i in words.indexes
        self.print words[i], x, y, scale, tint
        if i == words.len-2 then ewPerWord = ew
        x += self.width(words[i], scale) + ewPerWord
        ew -= ewPerWord
    end for
end function

// Return the width of the given string in this font.
Font.width = function(s, scale=1)
	s = str(s)
	sum = 0
	lastc = ""
	for c in s
		d = self.charData(c)
		if d == null then continue
		sum = sum + (d.shift + self.addSpace + self.kern(lastc, c)) * scale
		lastc = c
	end for
	return sum
end function

// Return the number of characters of the given string that
// fit a given width.
Font.lenToFit = function(s, width=100)
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

boxesSample = [
"┌─┬┐  ╔═╦╗  ╓─╥╖  ╒═╤╕",
"│ ││  ║ ║║  ║ ║║  │ ││",
"├─┼┤  ╠═╬╣  ╟─╫╢  ╞═╪╡",
"└─┴┘  ╚═╩╝  ╙─╨╜  ╘═╧╛",
"┌───────────────────┐",
"│  ╔═══╗ Some Text  │▒",
"│  ╚═╦═╝ in the box │▒",
"╞═╤══╩══╤═══════════╡▒",
"│ ├──┬──┤           │▒",
"│ └──┴──┘           │▒",
"└───────────────────┘▒",
" ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒",
]

// Demo program: find the fonts directory, then load and display
// every font found therein.
demo = function()
	clear; text.row = 10
	
	fontsFolder = "fonts"
	if not file.exists(fontsFolder) then fontsFolder = "/usr/fonts"
	if not file.exists(fontsFolder) then fontsFolder = "/sys/fonts"
	if not file.exists(fontsFolder) then
		print "Unable to locate fonts folder."
		return
	end if
	
	y = 640
	lastFont = null
	fontFiles = file.children(fontsFolder)
	fontFiles.sort
	for fontFile in fontFiles
		if fontFile[-4:] != ".bmf" then continue
		f = Font.load(file.child(fontsFolder, fontFile))
		if f == null then	continue
		if y - f.lineHeight < 0 then
			dy = f.lineHeight + 4
			gfx.drawImage gfx.getImage(0, 0, 960, 640-dy), 0, dy
			gfx.fillRect 0, 0, 960, dy, color.black
			y = y + dy
		end if
		f.print fontFile + ": " + f.title, 10, y + f.sizeOver
		y = y - f.lineHeight - 4
		lastFont = f
	end for
	text.row = 0
	
	boxes = []
	for c in range(9472, 9727)
		boxes.push char(c)
	end for
	
	for fontFile in ["fonts/minimicro-mono-boxes-12.bmf", "fonts/minimicro-mono-boxes-16.bmf", "fonts/minimicro-mono-boxes-20.bmf"]
		fnt = Font.load(fontFile)
		if fnt == null then continue
		input "[Press Return]"
		clear
		print fontFile
		charsPerLine = floor(960 / fnt.chars.A.width / 2)
		y = 550
		for i in range(0, boxes.len, charsPerLine)
			line = boxes[i : i + charsPerLine].join(" ")
			y -= (fnt.chars.A.height + 10)
			fnt.print line, 0, y, 1, color.rgb(rnd*250, rnd*250, rnd*250)
		end for
		y -= 50
		clr = color.rgb(100+rnd*150, 100+rnd*150, 100+rnd*250)
		for i in boxesSample.indexes
			fnt.print boxesSample[i], 100, y - i * fnt.chars.A.height, 1, clr
		end for
	end for
end function

if locals == globals then demo
