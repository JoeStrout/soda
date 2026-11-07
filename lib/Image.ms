// Image: a pixel buffer compatible with the Mini Micro Image class.
// Backed by a raylib Image (CPU-side pixel data).
//
// Internally, pixel data is stored in raylib orientation (y=0 at top).
// All public methods use Mini Micro orientation (y=0 at bottom).

// Auto-batched PixelDisplay drawing may still reference a texture we are
// about to free: close its bracket (flushing the draws) first.
_flushBatch = function
	if globals.hasIndex("PixelDisplay") and PixelDisplay.hasIndex("_closeOpen") then PixelDisplay._closeOpen
end function

rl = raylib

// --- Color utility functions ---

hexDigitVal = function(c)
	"Return the numeric value (0-15) of a single hex digit character."
	code = c.code
	if code >= 48 and code <= 57 then return code - 48
	if code >= 65 and code <= 70 then return code - 55
	if code >= 97 and code <= 102 then return code - 87
	return 0
end function

colorToRGBA = function(s)
	"Convert a color string (#RRGGBB or #RRGGBBAA) to an [r, g, b, a] list."
	if s isa list then return s
	if not s isa string or s.len < 7 or s[0] != "#" then return [255, 255, 255, 255]
	r = hexDigitVal(s[1]) * 16 + hexDigitVal(s[2])
	g = hexDigitVal(s[3]) * 16 + hexDigitVal(s[4])
	b = hexDigitVal(s[5]) * 16 + hexDigitVal(s[6])
	if s.len >= 9 then
		a = hexDigitVal(s[7]) * 16 + hexDigitVal(s[8])
	else
		a = 255
	end if
	return [r, g, b, a]
end function

_hexDigits = "0123456789ABCDEF"
rgbaToColor = function(c)
	"Convert a map with r, g, b, a fields to a #RRGGBBAA color string."
	s = "#"
	s = s + _hexDigits[floor(c.r / 16)] + _hexDigits[c.r % 16]
	s = s + _hexDigits[floor(c.g / 16)] + _hexDigits[c.g % 16]
	s = s + _hexDigits[floor(c.b / 16)] + _hexDigits[c.b % 16]
	s = s + _hexDigits[floor(c.a / 16)] + _hexDigits[c.a % 16]
	return s
end function

// --- Image class ---

// An Image owns its raylib Image and Texture, and flags them with autoUnload,
// so they are freed when the Image is garbage-collected, as in Mini Micro.
// (release frees them sooner, if you know you are done.)
Image = {}
Image._img = null	// raylib Image map
Image._tex = null	// cached raylib Texture
Image.width = 0
Image.height = 0

// Create a new Image filled with the given color.
Image.create = function(width, height, color="#00000000")
	"Create a new Image of the given size, filled with the given color."
	result = new self
	result._img = autoUnload(rl.GenImageColor(width, height, colorToRGBA(color)))
	result.width = width
	result.height = height
	return result
end function

// Wrap an existing raylib Image map as an Image instance.  This does not take
// ownership: the caller still unloads rImg, unless it calls autoUnload on it.
Image.FromRaylibImage = function(rImg)
	"Wrap an existing raylib Image map as an Image, without taking ownership of it."
	result = new self
	result._img = rImg
	result.width = rImg.width
	result.height = rImg.height
	return result
end function

Image.release = function
	"Free this image's raylib Image and Texture now, rather than waiting for GC."
	if self._img != null then
		rl.UnloadImage(self._img)
		self._img = null
	end if
	if self._tex != null then
		_flushBatch
		rl.UnloadTexture(self._tex)
		self._tex = null
	end if
end function

// Get a Raylib Texture (and cache for future use)
Image.texture = function
	"Return a raylib Texture for this image, creating and caching it if needed."
	if self._tex == null then
		self._tex = autoUnload(raylib.LoadTextureFromImage(self._img))
	end if
	return self._tex
end function

// Get the color of a pixel as a "#RRGGBBAA" string.
Image.pixel = function(x, y)
	"Return the color of the pixel at x, y as a #RRGGBBAA string."
	ry = self.height - 1 - y
	c = rl.GetImageColor(self._img, x, ry)
	return rgbaToColor(c)
end function

// Set the color of a pixel.
Image.setPixel = function(x, y, color)
	"Set the color of the pixel at x, y."
	ry = self.height - 1 - y
	rl.ImageDrawPixel self._img, x, ry, colorToRGBA(color)
	if self._tex then self._invalidateTexture
end function

// Extract a rectangular sub-region as a new Image.
Image.getImage = function(left=0, bottom=0, width, height)
	"Return a rectangular sub-region of this image as a new Image."
	if width == null then width = self.width - left
	if height == null then height = self.height - bottom
	ry = self.height - bottom - height
	subImg = rl.ImageFromImage(self._img, [left, ry, width, height])
	return Image.FromRaylibImage(autoUnload(subImg))
end function

// Flip the image in place.
// vertical=true flips top/bottom; vertical=false (default) flips left/right.
Image.flip = function(vertical=false)
	"Flip the image in place, left/right by default or top/bottom if vertical."
	if vertical then
		rl.ImageFlipVertical self._img
	else
		rl.ImageFlipHorizontal self._img
	end if
	if self._tex then self._invalidateTexture
end function

// Rotate the image in place, counter-clockwise, in 90-degree increments.
Image.rotate = function(degrees=90)
	"Rotate the image in place counter-clockwise, in 90-degree increments."
	degrees = degrees % 360
	if degrees < 0 then degrees = degrees + 360
	if degrees == 90 then
		rl.ImageRotateCCW self._img
	else if degrees == 180 then
		rl.ImageRotateCCW self._img
		rl.ImageRotateCCW self._img
	else if degrees == 270 then
		rl.ImageRotateCW self._img
	end if
	self.width = self._img.width
	self.height = self._img.height
	if self._tex then self._invalidateTexture
end function

// Reliably releases texture and sets the texture cache so that the draw call works properly
Image._invalidateTexture = function
	"Release the cached texture so it is rebuilt from the pixel data on next use."
	if self._tex then
		_flushBatch
		rl.UnloadTexture(self._tex)
		self._tex = null
	end if
end function

// Add a load method to the global file module.
file.loadImage = function(path)
	"Load an image file from the given path and return it as an Image."
	rImg = rl.LoadImage(path)
	if rImg == null then
		print "file.loadImage: could not load " + path
		return null
	end if
	result = Image.FromRaylibImage(autoUnload(rImg))
	result.path = path
	return result
end function

file.saveImage = function(path, image, quality=80)
	"Save an Image to the given path; return null on success, or an error message."
	// NOTE: we currently ignore the `quality` parameter, because Raylib's
	// ExportImage API does not use it (it always saves JPEGs at 90% quality).
	// ToDo: revisit this when Raylib is fixed, or we add our own custom API
	// in raylib-miniscript that accepts a quality parameter.  See:
	// https://github.com/raysan5/raylib/issues/6369
	if image == null or not image isa Image then
		return "file.saveImage: invalid image"
	end if
	success = rl.ExportImage(image._img, path)
	if not success then return "file.saveImage: could not save " + path
	return null
end function

return Image
