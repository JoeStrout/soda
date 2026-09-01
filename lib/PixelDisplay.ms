// PixelDisplay: a retained-mode pixel drawing surface,
// compatible with the Mini Micro PixelDisplay API.
// Backed by a raylib RenderTexture.

import "importUtil"
ensureImport ["color", "Display", "ScreenFont", "Image"]

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
//
// Note that this binds a framebuffer, and a host that time-slices the script
// can suspend it between any two statements -- including between here and
// _endDraw.  Anything such a host draws in that window lands in this render
// texture, so its frame loop must check raylib.rlGetActiveFramebuffer and skip
// the frame when a bracket is open.  (Mini Micro 2's main.ms does; Soda, which
// runs the script to completion each frame, never sees the case.)
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


// Convert a list of polygon points -- each either an [x,y] list or a map
// with "x" and "y" keys -- into display coordinates (y flipped).
PixelDisplay._polyPoints = function(points)
	result = []
	for pt in points
		if pt isa map then
			result.push [pt.x, self.height - pt.y]
		else
			result.push [pt[0], self.height - pt[1]]
		end if
	end for
	return result
end function

// Twice the signed area of a polygon (positive if counter-clockwise).
_signedArea2 = function(pts)
	sum = 0
	prev = pts[-1]
	for p in pts
		sum = sum + prev[0] * p[1] - p[0] * prev[1]
		prev = p
	end for
	return sum
end function

_pointInTri = function(p, a, b, c)
	d1 = (p[0]-b[0]) * (a[1]-b[1]) - (a[0]-b[0]) * (p[1]-b[1])
	d2 = (p[0]-c[0]) * (b[1]-c[1]) - (b[0]-c[0]) * (p[1]-c[1])
	d3 = (p[0]-a[0]) * (c[1]-a[1]) - (c[0]-a[0]) * (p[1]-a[1])
	return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))
end function

// Cross product at corner i, times sgn: positive means a convex corner.
_cornerCross = function(v, i, sgn)
	a = v[i - 1]
	b = v[i]
	c = v[(i + 1) % v.len]
	return sgn * ((b[0]-a[0]) * (c[1]-a[1]) - (c[0]-a[0]) * (b[1]-a[1]))
end function

// Ear-clipping triangulation of a simple (but possibly concave) polygon.
// Returns a list of [a,b,c] point triples.
_triangulate = function(pts)
	// Drop repeated points: a zero-area corner is never an ear, and would
	// otherwise stall the clipping (callers duplicate endpoints readily).
	v = []
	for p in pts
		if v and abs(p[0] - v[-1][0]) < 1e-9 and abs(p[1] - v[-1][1]) < 1e-9 then continue
		v.push p
	end for
	while v.len > 1 and abs(v[0][0] - v[-1][0]) < 1e-9 and abs(v[0][1] - v[-1][1]) < 1e-9
		v.pop
	end while
	if v.len < 3 then return []

	// Drop collinear corners.  A zero cross reads as reflex below, so such a
	// corner can never be clipped, yet it still counts as a blocker -- and a
	// polygon with several points along one ray (a visibility fan, say) then
	// has no ear at all, falling back to overlapping triangles.  A collinear
	// corner adds nothing to the shape, so remove it up front.  Removing one
	// can make a neighbor collinear in turn, hence the repeat.
	changed = true
	while changed and v.len > 3
		changed = false
		i = 0
		while i < v.len
			a = v[i-1]; b = v[i]; c = v[(i+1) % v.len]
			if abs((b[0]-a[0]) * (c[1]-a[1]) - (c[0]-a[0]) * (b[1]-a[1])) < 1e-9 then
				v.remove i
				changed = true
			else
				i = i + 1
			end if
		end while
	end while
	if v.len < 3 then return []

	sgn = 1
	if _signedArea2(v) < 0 then sgn = -1

	// Corner convexity, maintained incrementally: clipping a vertex changes
	// only its two neighbors, so we never rescan the whole polygon.
	cross = []
	for i in range(0, v.len - 1)
		cross.push _cornerCross(v, i, sgn)
	end for

	tris = []
	while v.len > 2
		n = v.len
		earIdx = -1
		bestIdx = 0
		bestCross = 0
		for i in range(0, n - 1)
			if cross[i] <= 0 then continue		// reflex corner
			if cross[i] > bestCross then
				bestCross = cross[i]
				bestIdx = i
			end if
			iNext = (i + 1) % n
			a = v[i - 1]
			b = v[i]
			c = v[iNext]
			minX = a[0]; maxX = a[0]; minY = a[1]; maxY = a[1]
			for q in [b, c]
				if q[0] < minX then minX = q[0] else if q[0] > maxX then maxX = q[0]
				if q[1] < minY then minY = q[1] else if q[1] > maxY then maxY = q[1]
			end for
			isEar = true
			// Only a reflex vertex can poke into a candidate ear.
			for j in range(0, n - 1)
				if cross[j] > 0 or j == i or j == iNext or j == (i + n - 1) % n then continue
				q = v[j]
				if q[0] < minX or q[0] > maxX or q[1] < minY or q[1] > maxY then continue
				if _pointInTri(q, a, b, c) then
					isEar = false
					break
				end if
			end for
			if isEar then
				earIdx = i
				break
			end if
		end for
		// No ear at all means the input isn't a simple polygon; clip the
		// sharpest corner anyway, so we always terminate having covered it.
		if earIdx < 0 then earIdx = bestIdx
		tris.push [v[earIdx - 1], v[earIdx], v[(earIdx + 1) % n]]
		v.remove earIdx
		cross.remove earIdx
		if v.len > 2 then
			k = earIdx % v.len
			cross[k] = _cornerCross(v, k, sgn)
			cross[k - 1] = _cornerCross(v, k - 1, sgn)
		end if
	end while
	return tris
end function

// Draw a polygon outline.  Points may be [x,y] lists or maps with x and y.
PixelDisplay.drawPoly = function(points, color=null, penSize=1)
	if points == null or points.len < 2 then return
	if color == null then color = self.color
	color = colorToList(color)
	pts = self._polyPoints(points)
	self._beginDraw
	h = 0.5
	prev = pts[-1]
	for pt in pts
		rl.DrawLineEx([prev[0]+h, prev[1]-h], [pt[0]+h, pt[1]-h], penSize, color)
		prev = pt
	end for
	self._endDraw
end function

// Fill a polygon.  Points may be [x,y] lists or maps with x and y.
PixelDisplay.fillPoly = function(points, color=null)
	if points == null or points.len < 3 then return
	if color == null then color = self.color
	color = colorToList(color)
	tris = _triangulate(self._polyPoints(points))
	self._beginDraw
	rl.rlDisableBackfaceCulling		// so triangle winding doesn't matter
	for t in tris
		rl.DrawTriangle t[0], t[1], t[2], color
	end for
	rl.rlDrawRenderBatchActive		// flush before restoring culling state
	rl.rlEnableBackfaceCulling
	self._endDraw
end function

// Print a string using the Mini Micro screen font.  Compatible with the
// Mini Micro PixelDisplay.print API:
// https://miniscript.org/wiki/PixelDisplay.print
// ToDo: support custom fonts.
PixelDisplay._fonts = {}		// ScreenFonts by name, shared by all PixelDisplays

PixelDisplay._fontFiles = {"small": "ScreenFontSmall", "medium": "ScreenFontMedium",
   "normal": "ScreenFont", "large": "ScreenFontLarge"}

// Overlap between adjacent glyph cells; column spacing is charWidth - kerning,
// i.e. 8, 11, 14, and 20 pixels for the four sizes.
PixelDisplay._fontKerning = {"small": 2, "medium": 2, "normal": 2, "large": 4}

PixelDisplay._loadFont = function(fontName="normal")
	if not PixelDisplay._fontFiles.hasIndex(fontName) then fontName = "normal"
	if PixelDisplay._fonts.hasIndex(fontName) then return PixelDisplay._fonts[fontName]
	if version.hostName == "Mini Micro" then
		dir = "/hw/images/"
	else
		dir = "lib/"
	end if
	font = ScreenFont.Make(dir + PixelDisplay._fontFiles[fontName] + ".png")
	if font.isLoaded then
		font.kerning = PixelDisplay._fontKerning[fontName]
	else if fontName != "normal" then
		// Not every host ships the alternate sizes; fall back to normal.
		font = PixelDisplay._loadFont("normal")
	end if
	PixelDisplay._fonts[fontName] = font
	return font
end function

PixelDisplay.print = function(str="", x=0, y=0, color=null, fontName="normal")
	if color == null then color = self.color
	font = PixelDisplay._loadFont(fontName)
	if not font.isLoaded then return
	str = str + ""
	// y is the bottom of the text; raylib's y grows downward.
	destY = self.height - y - font.charHeight
	back = "#00000000"
	colSpacing = font.charWidth - font.kerning
	self._beginDraw true  // (alpha blend, so glyph edges don't punch holes)
	for ch in str
		if ch != " " then font.drawChar ch.code, x, destY, color, back
		x = x + colSpacing
	end for
	self._endDraw
end function

// Get a rectangular region of the display as an Image.
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

PixelDisplay._drawTexture = function(tex, left, bottom, width=null, height=null, srcLeft=0, srcBottom=0, srcWidth=null, srcHeight=null, tint="#FFFFFF")
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
	rl.DrawTexturePro tex, src, dest, [0, 0], 0, tint
	self._endDraw
end function

// Draw an Image onto this PixelDisplay.
PixelDisplay.drawImage = function(img, left, bottom, width=null, height=null, srcLeft=0, srcBottom=0, srcWidth=null, srcHeight=null, tint="#FFFFFF")
	tex = rl.LoadTextureFromImage(img._img)
	rl.SetTextureFilter tex, rl.TEXTURE_FILTER_POINT
	self._drawTexture tex, left, bottom, width, height, srcLeft, srcBottom, srcWidth, srcHeight, tint
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
	top = Display.screenHeight - h
	dest = [-self.scrollX, top + self.scrollY, w, h]
	if self._renderTex == null then
		print "NULL _renderTex!"
		print self
	end if
	rl.DrawTexturePro self._renderTex.texture, src, dest, [0, 0], 0, [255, 255, 255, 255]
end function

// Unit tests.  These cover the pure geometry helpers only -- nothing here
// touches raylib -- so they can be run headlessly:  tests/triangulate.ms
PixelDisplay.runUnitTests = function
	print "Unit testing: PixelDisplay"
	errorCount = 0

	// A correct triangulation covers the polygon exactly: the triangles add
	// up to its area, with no gap and no overlap.
	cases = [
	  [[[0,0], [60,0], [60,60], [0,60]], "square"],
	  // Concave, so ear clipping has to skip the reflex corner.
	  [[[0,0], [60,0], [60,20], [20,20], [20,60], [0,60]], "L-shape"],
	  // Winding shouldn't matter.
	  [[[0,60], [20,60], [20,20], [60,20], [60,0], [0,0]], "L-shape reversed"],
	  // Extra points along a straight edge must not stop the clipper from
	  // finding an ear.
	  [[[0,0], [20,0], [40,0], [60,0], [60,60], [30,60], [0,60]], "collinear edge points"],
	  // Regression, from /sys/demo/2dVis: the square is traced, revisits its
	  // first point, and trails a zero-area spike out to (80,590).  Before
	  // collinear corners were dropped, no ear was found and the fallback
	  // emitted triangles covering four times the real area.
	  [[[120,390], [120,330], [180,330], [180,390], [120,390], [80,590]],
	    "2dVis fan with a zero-area spike"]]

	for c in cases
		pts = c[0]
		expected = abs(_signedArea2(pts)) / 2
		got = 0
		for t in _triangulate(pts)
			got = got + abs((t[1][0]-t[0][0]) * (t[2][1]-t[0][1]) -
			                (t[2][0]-t[0][0]) * (t[1][1]-t[0][1])) / 2
		end for
		if abs(got - expected) > 0.001 * expected + 1e-9 then
			print "Unit test failure (" + c[1] + "): polygon area " + expected +
			  ", triangles cover " + got
			errorCount = errorCount + 1
		end if
	end for

	// A convex quad is exactly two triangles.
	n = _triangulate([[0,0], [60,0], [60,60], [0,60]]).len
	if n != 2 then
		print "Unit test failure (square triangle count): expected 2, got " + n
		errorCount = errorCount + 1
	end if

	// Degenerate inputs yield no triangles rather than an error.
	for bad in [[[0,0], [10,10]], [[5,5], [5,5], [5,5]]]
		n = _triangulate(bad).len
		if n != 0 then
			print "Unit test failure (degenerate input): expected 0 triangles, got " + n
			errorCount = errorCount + 1
		end if
	end for

	if errorCount == 0 then
		print "All tests passed.  Woot!"
	else
		print errorCount + " error" + "s" * (errorCount != 1) + " found."
	end if
	return errorCount
end function

return PixelDisplay
