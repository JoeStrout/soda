// PixelDisplay: a retained-mode pixel drawing surface,
// compatible with the Mini Micro PixelDisplay API.
// Backed by a raylib RenderTexture.

import "importUtil"
ensureImport ["color", "Display"]

colorToList = @color.toList
colorFromList = @color.fromList

rl = raylib

PixelDisplay = new Display
PixelDisplay.mode = displayMode.pixel
PixelDisplay.color = [255, 255, 255, 255]
PixelDisplay.scale = 1
PixelDisplay.scrollX = 0
PixelDisplay.scrollY = 0
PixelDisplay.width = 960
PixelDisplay.height = 640
PixelDisplay._renderTex = null
PixelDisplay._clip = null  // [left, bottom, width, height] in display coords, or null

PixelDisplay.Make = function
	return new PixelDisplay
end function

// Begin drawing to the render texture in "replace" blend mode,
// so that drawn colors fully overwrite the destination (matching
// Mini Micro behavior, where alpha < 255 does not blend).
PixelDisplay._beginDraw = function(alphaBlend = false)
	rl.BeginTextureMode self._renderTex
	if self._clip != null then
		c = self._clip
		rl.BeginScissorMode c[0], self.height - c[1] - c[3], c[2], c[3]
	end if
	if alphaBlend then
//		rl.BeginBlendMode 5				// BLEND_ALPHA_PREMULTIPLY
		// Use normal color blending for RGB, but MAX mode for alpha,
		// so that we don't punch holes in the pixel layer.
		rl.rlSetBlendFactorsSeparate 770, 771, 0, 1, 32774, 32776
		rl.BeginBlendMode 7
	else
		rl.rlSetBlendFactors 1, 0, 32774    // GL_ONE, GL_ZERO, GL_FUNC_ADD
		rl.BeginBlendMode 6                 // BLEND_CUSTOM
	end if
end function

PixelDisplay._endDraw = function
	rl.EndBlendMode
	if self._clip != null then rl.EndScissorMode
	rl.EndTextureMode
end function

// Create a new PixelDisplay with the given size.
PixelDisplay.Make = function(width=960, height=640, color="#00000000")
	result = new self
	result.width = width
	result.height = height
	result._renderTex = rl.LoadRenderTexture(width, height)
	result.fillRect 0, 0, width, height, color
	return result
end function


// Clear the display.  Optionally change the size and/or clear color.
PixelDisplay.clear = function(color=null, width=960, height=640)
	if width != self.width or height != self.height then
		if self._renderTex != null then rl.UnloadRenderTexture self._renderTex
		self.width = width
		self.height = height
		self._renderTex = rl.LoadRenderTexture(width, height)
	end if
	if color == null then color = [0, 0, 0, 0]
	self.fillRect 0, 0, width, height, color
end function

// Set a single pixel.  Uses self.color if color is not specified.
PixelDisplay.setPixel = function(x, y, color=null)
	if color == null then color = self.color
	color = colorToList(color)
	self._beginDraw
	rl.DrawPixel x+0.5, self.height - 1 - y + 0.5, color
	self._endDraw
end function

// Get the color of a pixel, as a hex string (e.g. "#FF0000FF").
// NOTE: this is rather expensive.  If you are going to do it a lot,
// instead call getImage on the display, then get pixels of that.
PixelDisplay.pixel = function(x, y)
	img = rl.LoadImageFromTexture(self._renderTex.texture)
	c = rl.GetImageColor(img, x, y)
	rl.UnloadImage img
	return colorFromList(c)
end function

// Draw a straight line.
PixelDisplay.line = function(x1=0, y1=0, x2=960, y2=640, color, penSize=1)
	if color == null then color = self.color
	color = colorToList(color)
	self._beginDraw
	h = 0.5  // offset to properly address pixel coordinates
	rl.DrawLineEx([x1+h, self.height-y1-h], [x2+h, self.height-y2-h], penSize, color)
	self._endDraw
end function

// Draw a axis-aligned rectangle outline on the pixel display.
PixelDisplay.drawRect = function(left=0, bottom=0, width=100, height=100, color=null)
	if color == null then color = self.color
	color = colorToList(color)
	self._beginDraw
	rl.DrawRectangleLines left, self.height - bottom - height, width, height, color
	self._endDraw
end function

// Fill an axis-aligned rectangle on the pixel display.
PixelDisplay.fillRect = function(left=0, bottom=0, width=100, height=100, color=null)
	if color == null then color = self.color
	color = colorToList(color)
	self._beginDraw
	rl.DrawRectangle left, self.height - bottom - height, width, height, color
	self._endDraw
end function

// Draw a axis-aligned ellipse outline on the pixel display.
PixelDisplay.drawEllipse = function(left=0, bottom=0, width=100, height=100, color=null)
	if color == null then color = self.color
	color = colorToList(color)
	self._beginDraw
	wOver2 = floor(width/2)
	rl.DrawEllipseLines floor(left) + wOver2, self.height - floor(bottom) - ceil(height/2),
	   wOver2, floor(height/2), color
	self._endDraw
end function

// Fill an axis-aligned ellipse on the pixel display.
PixelDisplay.fillEllipse = function(left=0, bottom=0, width=100, height=100, color=null)
	if color == null then color = self.color
	color = colorToList(color)
	self._beginDraw
	wOver2 = floor(width/2)
	rl.DrawEllipse floor(left) + wOver2, self.height - bottom - ceil(height/2),
	   wOver2, floor(height/2), color
	self._endDraw
end function


// Draw a polygon outline from a list of [x,y] points.
PixelDisplay.drawPoly = function(points, color=null, penSize=1)
	if points == null or points.len < 2 then return
	if color == null then color = self.color
	color = colorToList(color)
	self._beginDraw
	h = 0.5
	prev = points[-1]
	for pt in points
		rl.DrawLineEx([prev[0]+h, self.height-prev[1]+h], [pt[0]+h, self.height-pt[1]+h], penSize, color)
		prev = pt
	end for
	self._endDraw
end function

// Print a string using a built-in font.  Compatible with the Mini Micro
// PixelDisplay.print API: https://miniscript.org/wiki/PixelDisplay.print
PixelDisplay._fontSizes = {"small":14, "medium":20, "normal":24, "large":32}

PixelDisplay.print = function(str="", x=0, y=0, color=null, fontName="normal")
	if color == null then color = self.color
	color = colorToList(color)
	fontSize = self._fontSizes.normal
	if self._fontSizes.hasIndex(fontName) then fontSize = self._fontSizes[fontName]
	font = rl.GetFontDefault
	measured = rl.MeasureTextEx(font, str, fontSize, 1)
	self._beginDraw true  // (alpha blend, so anti-aliased glyph edges don't punch holes)
	rl.DrawTextEx font, str, [x, self.height - y - measured.y], fontSize, 1, color
	self._endDraw
end function

// Get a rectangular region of the display as an Image.
// Requires the Image module.
PixelDisplay.getImage = function(left=0, bottom=0, width, height)
	fullImg = rl.LoadImageFromTexture(self._renderTex.texture)
	// Render texture data is vertically flipped; flip it so y=0 is at the
	// top, matching the Image class's internal convention.
	rl.ImageFlipVertical fullImg
	if width == null then width = self.width
	if height == null then height = self.height
	if left == 0 and bottom == 0 and width == self.width and height == self.height then
		subImg = fullImg
	else
		ry = self.height - bottom - height
		subImg = rl.ImageFromImage(fullImg, [left, ry, width, height])
		rl.UnloadImage fullImg
	end if
	return Image.FromRaylibImage(subImg)
end function

PixelDisplay._drawTexture = function(tex, left, bottom, width=null, height=null, srcLeft=0, srcBottom=0, srcWidth=null, srcHeight=null)
	if width == null then width = tex.width
	if height == null then height = tex.height
	if srcWidth == null then srcWidth = tex.width
	if srcHeight == null then srcHeight = tex.height
	if width <= 0 or height <= 0 or srcWidth <= 0 or srcHeight <= 0 then return
	// Source rect in texture coords (y=0 at top).
	srcY = tex.height - srcBottom - srcHeight
	src = [srcLeft, srcY, srcWidth, srcHeight]
	dest = [left, self.height - bottom - height, width, height]

	self._beginDraw true  // (alpha blend)
	rl.DrawTexturePro tex, src, dest, [0, 0], 0, [255, 255, 255, 255]
	self._endDraw
end function

// Draw an Image onto this PixelDisplay.
PixelDisplay.drawImage = function(img, left, bottom, width=null, height=null, srcLeft=0, srcBottom=0, srcWidth=null, srcHeight=null)
	tex = rl.LoadTextureFromImage(img._img)
	rl.SetTextureFilter tex, rl.TEXTURE_FILTER_POINT
	self._drawTexture tex, left, bottom, width, height, srcLeft, srcBottom, srcWidth, srcHeight
	rl.UnloadTexture tex
end function

// Use the image to tile the given destination rect, repeating as many
// times as needed.  Useful for repeated patterns.
PixelDisplay.patternFill = function(img, left, bottom, width=null, height=null, srcLeft=0, srcBottom=0)
	tex = rl.LoadTextureFromImage(img._img)
	rl.SetTextureWrap tex, rl.TEXTURE_WRAP_REPEAT
	rl.SetTextureFilter tex, rl.TEXTURE_FILTER_POINT
	self._drawTexture tex, left, bottom, width, height, srcLeft, srcBottom, width, height
	rl.UnloadTexture tex
end function

// Limit drawing to a rectangular region.  Coordinates use the same
// bottom-up system as other PixelDisplay methods.  Call clearClip to restore.
PixelDisplay.setClip = function(left, bottom, width, height)
	self._clip = [left, bottom, width, height]
end function

// Remove any clip region set by setClip.
PixelDisplay.clearClip = function
	self._clip = null
end function


// Draw this PixelDisplay to the screen (call during BeginDrawing/EndDrawing).
// Uses negative source height to flip the render texture vertically.
// Drawing functions flip Y coords so content is upside-down in the texture;
// this flip corrects it, giving us Mini Micro's bottom-up coordinate system.
PixelDisplay.render = function
	src = [0, 0, self.width, -self.height]
	w = self.width * self.scale
	h = self.height * self.scale
	top = rl.GetScreenHeight - h
	dest = [-self.scrollX, top + self.scrollY, w, h]
	rl.DrawTexturePro self._renderTex.texture, src, dest, [0, 0], 0, [255, 255, 255, 255]
end function

return PixelDisplay
