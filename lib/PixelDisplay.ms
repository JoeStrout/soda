// PixelDisplay: a retained-mode pixel drawing surface,
// compatible with the Mini Micro PixelDisplay API.
// Backed by a raylib RenderTexture.

import "importUtil"
ensureImport ["color", "Display", "ScreenFont", "Image"]


rl = raylib

PixelDisplay = new Display
PixelDisplay.mode = displayMode.pixel
PixelDisplay.color = [255, 255, 255, 255]
freeze PixelDisplay.color	// (shared by every instance that hasn't set its own)
PixelDisplay.scale = 1
PixelDisplay.scrollX = 0
PixelDisplay.scrollY = 0
PixelDisplay.width = 960
PixelDisplay.height = 640
PixelDisplay._renderTex = null
PixelDisplay._clip = null  // [left, bottom, width, height] in display coords, or null
// While a pixel cache exists, it, not the texture, is the display's content:
// setPixel writes only to it, and _flushPix uploads it when it's needed.
PixelDisplay._pixCache = null  // RawData copy of _renderTex (RGBA, bottom row first), or null
PixelDisplay._pixDirty = false  // true if _pixCache has writes the texture lacks
PixelDisplay._batchDepth = 0  // > 0 while beginBatch/endBatch keep the GPU bracket open
PixelDisplay._batchAlphaBlend = false  // the blend mode beginBatch set up, while batching
PixelDisplay._batchBlendOverridden = false  // true if a mismatched call temporarily changed it

PixelDisplay._ensureTex = function
	"Create this display's render texture, if it does not already exist."
	if self._renderTex == null then
		self._renderTex = autoUnload(rl.LoadRenderTexture(self.width, self.height))
	end if
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
// Actually issue the blend-mode calls for one drawing call.
PixelDisplay._setBlendMode = function(alphaBlend)
	"Set up custom-blend (replace) or alpha-blend mode, per alphaBlend."
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

PixelDisplay._beginDraw = function(alphaBlend = false)
	"Begin drawing to the render texture, in replace mode or (optionally) alpha blend mode."
	if self._pixCache != null then self._dropPixCache
	if self._renderTex == null then self._ensureTex
	// Inside a beginBatch/endBatch bracket, the framebuffer is already bound
	// and the blend mode already set (both stay in effect until endBatch):
	// a draw call sandwiched between BeginTextureMode/EndTextureMode *or*
	// BeginBlendMode/EndBlendMode forces an implicit render-batch flush, so
	// either bracket closing between draws is expensive, not just the
	// framebuffer rebind alone. Skip both per call while batching, as long
	// as this call's alphaBlend matches what the batch set up; a mismatched
	// call (mixing e.g. print's alpha blend into a non-alpha batch) falls
	// back to setting blend mode just for itself, for correctness.
	if self._batchDepth == 0 then
		rl.BeginTextureMode self._renderTex
	else if alphaBlend != self._batchAlphaBlend then
		self._setBlendMode alphaBlend
		self._batchBlendOverridden = true
	end if
	if self._clip != null then
		c = self._clip
		rl.BeginScissorMode c[0], self.height - c[1] - c[3], c[2], c[3]
	end if
	if self._batchDepth == 0 then self._setBlendMode alphaBlend
end function

// Anything that draws to _renderTex must call this (_beginDraw does).
PixelDisplay._dropPixCache = function
	"Upload any pending pixel cache writes, then discard the cache."
	if self._pixCache == null then return
	self._flushPix
	self._pixCache = null
end function

// Upload the pixel cache's writes.  This is a texture upload, not a draw, so
// it is safe mid-frame (render calls it) with no texture-mode bracket.
// A time-sliced script may be suspended inside setPixel, but it marks the
// cache dirty only after writing to it, so a write is never left unflagged.
PixelDisplay._flushPix = function
	"Upload pending writes in the pixel cache to the render texture."
	if not self._pixDirty then return
	self._pixDirty = false
	t = self._renderTex.texture
	rl.rlUpdateTexture t.id, 0, 0, t.width, t.height, t.format, self._pixCache
end function

PixelDisplay._endDraw = function
	"End drawing to the render texture, restoring blend, scissor, and texture mode."
	if self._batchDepth == 0 then
		rl.EndBlendMode
	else if self._batchBlendOverridden then
		// Restore the batch's own blend mode rather than ending it, so the
		// next call in the batch finds it as beginBatch left it.
		self._setBlendMode self._batchAlphaBlend
		self._batchBlendOverridden = false
	end if
	if self._clip != null then rl.EndScissorMode
	if self._batchDepth == 0 then rl.EndTextureMode
end function

// Keep the render texture's GPU brackets (BeginTextureMode/EndTextureMode
// *and* BeginBlendMode/EndBlendMode) open across multiple drawing calls.
// Either bracket closing between two draw calls forces an implicit
// render-batch flush -- measured as the dominant cost in a loop of many
// small draws (e.g. setPixel): batching both turns a ~0.098 ms/call loop
// into one that amortizes to a few µs/call for large N (see FINDINGS.md,
// S-P1). Calls nest: only the outermost beginBatch/endBatch pair actually
// opens and closes the brackets. Must be balanced with endBatch -- an
// unclosed batch leaves the display's framebuffer bound, which breaks
// rendering (its own and everything drawn afterward) until endBatch is
// called.
//
// alphaBlend picks which blend mode the whole batch uses; a call inside the
// batch whose own alphaBlend differs (e.g. mixing print's alpha blend into
// a non-alpha batch) still works, just at that one call's normal per-call
// cost (see _beginDraw/_endDraw).
//
// Widens the time-slicing hazard _beginDraw's own comment describes (a host
// that can suspend the script between statements must skip a frame while a
// bracket is open) to the whole batch, not just one call -- an explicit,
// bounded-by-the-caller widening of a risk that already exists per call.
PixelDisplay.beginBatch = function(alphaBlend = false)
	"Open a GPU draw bracket that stays open across calls until endBatch. Nests."
	if self._batchDepth == 0 then
		if self._pixCache != null then self._dropPixCache
		if self._renderTex == null then self._ensureTex
		rl.BeginTextureMode self._renderTex
		self._setBlendMode alphaBlend
		self._batchAlphaBlend = alphaBlend
		self._batchBlendOverridden = false
	end if
	self._batchDepth = self._batchDepth + 1
end function

PixelDisplay.endBatch = function
	"Close a GPU draw bracket opened by beginBatch."
	if self._batchDepth <= 0 then return
	self._batchDepth = self._batchDepth - 1
	if self._batchDepth == 0 then
		rl.EndBlendMode
		rl.EndTextureMode
	end if
end function

// Create a new PixelDisplay with the given size.
PixelDisplay.Make = function(width=960, height=640, color="#00000000")
	"Create a new PixelDisplay of the given size, filled with the given color."
	result = new self
	result.width = width
	result.height = height
	result.fillRect 0, 0, width, height, color
	return result
end function


// Clear the display.  Optionally change the size and/or clear color.
PixelDisplay.clear = function(color=null, width=null, height=null)
	"Clear the display to the given color, optionally resizing it."
	// Default to the display's current size: clear should never resize it
	// as a side effect of just changing the color, unlike the old hardcoded
	// 960x640 default, which silently snapped any custom-sized display back
	// to the Mini Micro screen's own size.
	if width == null then width = self.width
	if height == null then height = self.height
	// Everything is about to be overwritten (or resized), so don't flush.
	self._pixCache = null
	self._pixDirty = false
	if width != self.width or height != self.height then
		if self._renderTex != null then rl.UnloadRenderTexture self._renderTex
		self.width = width
		self.height = height
		self._renderTex = autoUnload(rl.LoadRenderTexture(width, height))
	end if
	if color == null then color = [0, 0, 0, 0]
	self.fillRect 0, 0, width, height, color
end function

// Set a single pixel.  Uses self.color if color is not specified.
// With a pixel cache, writes go only to the cache, so code that alternates
// pixel and setPixel (a flood fill) costs no GPU work per pixel at all.
PixelDisplay.setPixel = function(x, y, color=null)
	"Set the pixel at x, y to the given color (or self.color)."
	if color == null then color = self.color
	d = self._pixCache
	// The cache handles only the cases where we know exactly which pixel the
	// GPU would set; anything else drops it and draws.
	if d != null and self._clip == null and x == floor(x) and y == floor(y) then
		if x < 0 or y < 0 or x >= self.width or y >= self.height then return
		d.setInt (y * self.width + x) * 4, rl.ColorToInt(color)
		self._pixDirty = true
		return
	end if
	self._beginDraw
	rl.DrawPixel x+0.5, self.height - 1 - y + 0.5, color
	self._endDraw
end function

// Color strings by the signed 0xRRGGBBAA int that the cache holds; capped,
// since an image may hold any number of distinct colors.
_hexByte = color._hexByte
_intHex = {}
_intToHex = function(v)
	"Convert a signed 0xRRGGBBAA int to a #RRGGBBAA string, caching the result."
	if _intHex.len >= 4096 then outer._intHex = {} // (reset cache)
	u = v
	if u < 0 then u += 4294967296
	s = "#" + _hexByte[floor(u / 16777216)] + _hexByte[floor(u / 65536) % 256] +
	  _hexByte[floor(u / 256) % 256] + _hexByte[u % 256]
	_intHex[v] = s
	return s
end function

// Get the color of a pixel, as a hex string (e.g. "#FF0000FF").
// The first call after any drawing other than setPixel reads the whole
// texture back from the GPU; later calls read from that copy.
PixelDisplay.pixel = function(x, y)
	"Return the color of the pixel at x, y as a #RRGGBBAA string."
	d = self._pixCache
	if d == null then
		self._ensureTex
		t = self._renderTex.texture
		// (Render texture rows are bottom-up, so cache row y is display row y.)
		d = rl.rlReadTexturePixels(t.id, t.width, t.height, t.format)
		d.littleEndian = 0		// so each pixel reads as 0xRRGGBBAA
		self._pixCache = d
	end if
	if x < 0 or y < 0 or x >= self.width or y >= self.height then return "#00000000"
	v = d.int((floor(y) * self.width + floor(x)) * 4)
	if _intHex.hasIndex(v) then s = _intHex[v] else s = _intToHex(v)
	return s
end function

// Draw a straight line.
PixelDisplay.line = function(x1=0, y1=0, x2=960, y2=640, color, penSize=1)
	"Draw a straight line from x1, y1 to x2, y2."
	if color == null then color = self.color
	self._beginDraw
	h = 0.5  // offset to properly address pixel coordinates
	rl.DrawLineEx([x1+h, self.height-y1-h], [x2+h, self.height-y2-h], penSize, color)
	self._endDraw
end function

// Draw a axis-aligned rectangle outline on the pixel display.
// A thick pen is centered on the rect's bounds, as in Mini Micro 1.
PixelDisplay.drawRect = function(left=0, bottom=0, width=100, height=100, color=null, penSize=1)
	"Draw the outline of an axis-aligned rectangle."
	if width == 0 or height == 0 then return
	if color == null then color = self.color
	self._beginDraw
	if penSize <= 1 then
		rl.DrawRectangleLines left, self.height - bottom - height, width, height, color
	else
		hw = penSize / 2
		rec = [left - hw, self.height - bottom - height - hw, width + penSize, height + penSize]
		rl.DrawRectangleLinesEx rec, penSize, color
	end if
	self._endDraw
end function

// Fill an axis-aligned rectangle on the pixel display.
PixelDisplay.fillRect = function(left=0, bottom=0, width=100, height=100, color=null)
	"Fill an axis-aligned rectangle."
	if color == null then color = self.color
	self._beginDraw
	rl.DrawRectangle left, self.height - bottom - height, width, height, color
	self._endDraw
end function

// Draw a axis-aligned ellipse outline on the pixel display.
// A thick pen is centered on the ellipse's bounds, as in Mini Micro 1.
PixelDisplay.drawEllipse = function(left=0, bottom=0, width=100, height=100, color=null, penSize=1)
	"Draw the outline of an ellipse within the given rectangle."
	if width == 0 or height == 0 then return
	if color == null then color = self.color
	self._beginDraw
	if penSize <= 1 then
		wOver2 = floor(width/2)
		rl.DrawEllipseLines floor(left) + wOver2, self.height - floor(bottom) - ceil(height/2),
		   wOver2, floor(height/2), color
	else
		// raylib has no thick ellipse, so strip a ring between two ellipses.
		cx = left + width/2
		cy = self.height - bottom - height/2
		hw = penSize / 2
		outerX = width/2 + hw; outerY = height/2 + hw
		innerX = width/2 - hw; innerY = height/2 - hw
		if innerX < 0 then innerX = 0
		if innerY < 0 then innerY = 0
		segments = ceil(outerX + outerY)
		if segments < 36 then segments = 36
		pts = []
		for i in range(0, segments)
			a = 2 * pi * i / segments
			c = cos(a); s = sin(a)
			pts.push [cx + outerX * c, cy + outerY * s]
			pts.push [cx + innerX * c, cy + innerY * s]
		end for
		rl.rlDisableBackfaceCulling
		rl.DrawTriangleStrip pts, color
		rl.rlDrawRenderBatchActive
		rl.rlEnableBackfaceCulling
	end if
	self._endDraw
end function

// Fill an axis-aligned ellipse on the pixel display.
PixelDisplay.fillEllipse = function(left=0, bottom=0, width=100, height=100, color=null)
	"Fill an ellipse within the given rectangle."
	if color == null then color = self.color
	self._beginDraw
	wOver2 = floor(width/2)
	rl.DrawEllipse floor(left) + wOver2, self.height - bottom - ceil(height/2),
	   wOver2, floor(height/2), color
	self._endDraw
end function


// Convert a list of polygon points -- each either an [x,y] list or a map
// with "x" and "y" keys -- into display coordinates (y flipped).
PixelDisplay._polyPoints = function(points)
	"Convert polygon points ([x,y] lists or x/y maps) to [x,y] lists with y flipped."
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
	"Return twice the signed area of a polygon (positive if counter-clockwise)."
	sum = 0
	prev = pts[-1]
	for p in pts
		sum = sum + prev[0] * p[1] - p[0] * prev[1]
		prev = p
	end for
	return sum
end function

_pointInTri = function(p, a, b, c)
	"Return whether point p lies within (or on the edge of) triangle a, b, c."
	d1 = (p[0]-b[0]) * (a[1]-b[1]) - (a[0]-b[0]) * (p[1]-b[1])
	d2 = (p[0]-c[0]) * (b[1]-c[1]) - (b[0]-c[0]) * (p[1]-c[1])
	d3 = (p[0]-a[0]) * (c[1]-a[1]) - (c[0]-a[0]) * (p[1]-a[1])
	return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))
end function

// Cross product at corner i, times sgn: positive means a convex corner.
_cornerCross = function(v, i, sgn)
	"Return the cross product at corner i of polygon v, times sgn (positive if convex)."
	a = v[i - 1]
	b = v[i]
	c = v[(i + 1) % v.len]
	return sgn * ((b[0]-a[0]) * (c[1]-a[1]) - (c[0]-a[0]) * (b[1]-a[1]))
end function

// Ear-clipping triangulation of a simple (but possibly concave) polygon.
// Returns a list of [a,b,c] point triples.
_triangulate = function(pts)
	"Split a simple (possibly concave) polygon into a list of [a,b,c] triangles."
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
	// reflexCount (also maintained incrementally alongside cross) tracks how
	// many current corners are reflex: a convex polygon has none, and no
	// reflex vertex anywhere means no candidate ear can possibly be blocked,
	// so the O(n) "does any reflex vertex poke into this ear" scan below can
	// be skipped outright. Without this, every candidate-ear check scanned
	// all n current vertices even when none of them were reflex, making
	// triangulation of an n-gon with few or no reflex corners (e.g. any
	// convex polygon) cost O(n^2) instead of O(n).
	cross = []
	reflexCount = 0
	for i in range(0, v.len - 1)
		cross.push _cornerCross(v, i, sgn)
		if cross[i] <= 0 then reflexCount = reflexCount + 1
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
			isEar = true
			// Only a reflex vertex can poke into a candidate ear.
			if reflexCount > 0 then
				minX = a[0]; maxX = a[0]; minY = a[1]; maxY = a[1]
				for q in [b, c]
					if q[0] < minX then minX = q[0] else if q[0] > maxX then maxX = q[0]
					if q[1] < minY then minY = q[1] else if q[1] > maxY then maxY = q[1]
				end for
				for j in range(0, n - 1)
					if cross[j] > 0 or j == i or j == iNext or j == (i + n - 1) % n then continue
					q = v[j]
					if q[0] < minX or q[0] > maxX or q[1] < minY or q[1] > maxY then continue
					if _pointInTri(q, a, b, c) then
						isEar = false
						break
					end if
				end for
			end if
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
			km1 = k - 1
			wasReflexK = cross[k] <= 0
			wasReflexKm1 = cross[km1] <= 0
			cross[k] = _cornerCross(v, k, sgn)
			cross[km1] = _cornerCross(v, km1, sgn)
			if wasReflexK != (cross[k] <= 0) then
				if wasReflexK then reflexCount = reflexCount - 1 else reflexCount = reflexCount + 1
			end if
			if wasReflexKm1 != (cross[km1] <= 0) then
				if wasReflexKm1 then reflexCount = reflexCount - 1 else reflexCount = reflexCount + 1
			end if
		end if
	end while
	return tris
end function

// Draw a polygon outline.  Points may be [x,y] lists or maps with x and y.
PixelDisplay.drawPoly = function(points, color=null, penSize=1)
	"Draw the outline of a polygon given as [x,y] lists or maps with x and y."
	if points == null or points.len < 2 then return
	if color == null then color = self.color
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
	"Fill a polygon given as [x,y] lists or maps with x and y."
	if points == null or points.len < 3 then return
	if color == null then color = self.color
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
freeze PixelDisplay._fontFiles
freeze PixelDisplay._fontKerning

PixelDisplay._loadFont = function(fontName="normal")
	"Return the ScreenFont of the given size name, loading it if needed."
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
	"Draw a string with its bottom-left corner at x, y, using a built-in font."
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
	"Return a rectangular region of the display as a new Image."
	if self._renderTex == null then self._ensureTex
	self._flushPix
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
	return Image.FromRaylibImage(autoUnload(subImg))
end function

PixelDisplay._drawTexture = function(tex, left, bottom, width=null, height=null, srcLeft=0, srcBottom=0, srcWidth=null, srcHeight=null, tint="#FFFFFF")
	"Draw part of a raylib texture into the given rectangle, with alpha blending."
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
	"Draw an Image (or part of one) into the given rectangle, optionally tinted."
	// Reuse img's own cached GPU texture (Image.texture) rather than
	// uploading and freeing a fresh one every call: LoadTextureFromImage/
	// UnloadTexture are themselves costly (not just the draw call), so
	// repeated drawImage calls on the same Image used to pay for a new
	// upload each time even though the pixel data never changed.
	tex = img.texture
	rl.SetTextureFilter tex, rl.TEXTURE_FILTER_POINT
	self._drawTexture tex, left, bottom, width, height, srcLeft, srcBottom, srcWidth, srcHeight, tint
end function

// Use the image to tile the given destination rect, repeating as many
// times as needed.  Useful for repeated patterns.
PixelDisplay.patternFill = function(img, left, bottom, width=null, height=null, srcLeft=0, srcBottom=0)
	"Fill the given rectangle by tiling the given Image repeatedly."
	tex = img.texture
	rl.SetTextureWrap tex, rl.TEXTURE_WRAP_REPEAT
	rl.SetTextureFilter tex, rl.TEXTURE_FILTER_POINT
	self._drawTexture tex, left, bottom, width, height, srcLeft, srcBottom, width, height
	// Restore the default wrap mode so a later drawImage call using this
	// same cached texture doesn't inherit REPEAT.
	rl.SetTextureWrap tex, rl.TEXTURE_WRAP_CLAMP
end function

// Limit drawing to a rectangular region.  Coordinates use the same
// bottom-up system as other PixelDisplay methods.  Call clearClip to restore.
PixelDisplay.setClip = function(left, bottom, width, height)
	"Limit all subsequent drawing to the given rectangle."
	self._clip = [left, bottom, width, height]
end function

// Remove any clip region set by setClip.
PixelDisplay.clearClip = function
	"Remove any clip rectangle set by setClip."
	self._clip = null
end function


// Draw this PixelDisplay to the screen (call during BeginDrawing/EndDrawing).
// Uses negative source height to flip the render texture vertically.
// Drawing functions flip Y coords so content is upside-down in the texture;
// this flip corrects it, giving us Mini Micro's bottom-up coordinate system.
PixelDisplay.render = function
	"Draw this display to the screen, applying scale and scroll."
	if self._renderTex == null then return
	if self._pixDirty then self._flushPix
	src = [0, 0, self.width, -self.height]
	w = self.width * self.scale
	h = self.height * self.scale
	top = Display.screenHeight - h
	dest = [-self.scrollX, top + self.scrollY, w, h]
	rl.DrawTexturePro self._renderTex.texture, src, dest, [0, 0], 0, [255, 255, 255, 255]
end function

// Unit tests.  These cover the pure geometry helpers only -- nothing here
// touches raylib -- so they can be run headlessly:  tests/triangulate.ms
PixelDisplay.runUnitTests = function
	"Run unit tests on the polygon geometry helpers; return the number of failures."
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

	// Convex n-gons: reflexCount (the S-P5 perf fix) stays 0 for every one
	// of these, for the whole triangulation.
	for n in [3, 7, 13]
		pts = []
		for i in range(0, n - 1)
			a = 2 * pi * i / n
			pts.push [50 * cos(a), 50 * sin(a)]
		end for
		cases.push [pts, "convex " + n + "-gon"]
	end for

	// Star-shaped polygons: half the corners are reflex, so reflexCount
	// stays well above 0 for the whole triangulation -- exercises the
	// non-fast-path branch the S-P5 fix leaves unchanged.
	for n in [3, 5, 8]
		pts = []
		for i in range(0, 2 * n - 1)
			a = pi * i / n
			r = 50
			if i % 2 == 1 then r = 20
			pts.push [r * cos(a), r * sin(a)]
		end for
		cases.push [pts, "star with " + n + " points"]
	end for

	// Comb shape: several reflex corners (one per notch) that get resolved
	// into convex ones over the course of clipping -- reflexCount drops
	// from several down to 0 partway through, exercising the incremental
	// bookkeeping across that transition.
	cases.push [[[0,0], [10,0], [10,30], [20,30], [20,0], [30,0], [30,30],
	  [40,30], [40,0], [50,0], [50,40], [0,40]], "comb shape"]

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
