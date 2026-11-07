import "importUtil"
ensureImport ["Display", "Image"]

globals.Bounds = {}
Bounds.x = 0
Bounds.y = 0
Bounds.width = 0
Bounds.height = 0
Bounds.rotation = 0

Bounds.corners = function
	"Return the four corners of this (possibly rotated) rectangle, as [x,y] lists."
	hw = self.width / 2
	hh = self.height / 2
	cosR = cos(self.rotation * pi / 180)
	sinR = sin(self.rotation * pi / 180)
	result = []
	for p in [[-hw, -hh], [hw, -hh], [hw, hh], [-hw, hh]]
		rx = p[0] * cosR - p[1] * sinR + self.x
		ry = p[0] * sinR + p[1] * cosR + self.y
		result.push [rx, ry]
	end for
	return result
end function

Bounds.contains = function(x, y)
	"Return whether the given point (x,y, [x,y], or x/y map) is within these bounds."
	if x isa map then
		y = x.y
		x = x.x
	else if x isa list then
		y = x[1]
		x = x[0]
	end if
	dx = x - self.x
	dy = y - self.y
	hw = self.width / 2
	hh = self.height / 2
	if self.rotation == 0 then return abs(dx) <= hw and abs(dy) <= hh
	cosR = cos(-self.rotation * pi / 180)
	sinR = sin(-self.rotation * pi / 180)
	localX = dx * cosR - dy * sinR
	localY = dx * sinR + dy * cosR
	return abs(localX) <= hw and abs(localY) <= hh
end function

Bounds.overlaps = function(b)
	"Return whether these bounds overlap the given Bounds."
	// Separating-axis test for two rotated rectangles.  Each rectangle
	// contributes two axes (its own edge normals); on each axis the boxes are
	// separated if the distance between centers exceeds the sum of their
	// projected half-extents.  Touching edges count as overlapping.
	dx = b.x - self.x
	dy = b.y - self.y
	hwA = self.width / 2
	hhA = self.height / 2
	hwB = b.width / 2
	hhB = b.height / 2
	if self.rotation == 0 and b.rotation == 0 then
		return abs(dx) <= hwA + hwB and abs(dy) <= hhA + hhB
	end if
	radA = self.rotation * pi / 180
	radB = b.rotation * pi / 180
	cosA = cos(radA); sinA = sin(radA)
	cosB = cos(radB); sinB = sin(radB)
	// |cos| and |sin| of the angle between the two boxes
	c = abs(cosA * cosB + sinA * sinB)
	s = abs(sinA * cosB - cosA * sinB)
	// A's axes: x' = (cosA, sinA), y' = (-sinA, cosA)
	if abs(dx * cosA + dy * sinA) > hwA + hwB * c + hhB * s then return false
	if abs(dy * cosA - dx * sinA) > hhA + hwB * s + hhB * c then return false
	// B's axes
	if abs(dx * cosB + dy * sinB) > hwB + hwA * c + hhA * s then return false
	if abs(dy * cosB - dx * sinB) > hhB + hwA * s + hhA * c then return false
	return true
end function

globals.Sprite = {}
Sprite.x = 0
Sprite.y = 0
Sprite.rotation = 0
Sprite.scale = 1
Sprite.image = null
Sprite.srcRect = null    // optional: [left, top, width, height] in image
Sprite.tint = [255, 255, 255, 255]  // (a list: raylib.WHITE is a map, which costs ~175 ns more per draw call to convert)
Sprite.localBounds = null


// Auto-create a localBounds from our image or srcRect,
// optionally inset.  Inset may be given as separate X and Y
// values, or as a single number to apply to both, or as an
// [x,y] list, or an {"x":x, "y":y} map.
Sprite.addBounds = function(insetX=0, insetY=null)
	"Set localBounds to fit this sprite's image or srcRect, optionally inset."
	if not self.image.texture and not self.srcRect then
		print "Sprite.addBounds: neither image.texture nor srcRect defined"
		exit
	end if
	if insetX isa list then
		insetY = insetX[1]
		insetX = insetX[0]
	else if insetX isa map then
		insetY = insetX.y
		insetX = insetX.x
	else if insetY == null then
		insetY = insetX
	end if
	self.localBounds = new Bounds
	if self.srcRect then
		self.localBounds.width = self.srcRect[2] - insetX*2
		self.localBounds.height = self.srcRect[3] - insetY*2
	else
		self.localBounds.width = self.image.texture.width - insetX*2
		self.localBounds.height = self.image.texture.height - insetY*2
	end if
end function

// --- Corners and UVs -------------------------------------------------
// A sprite normally draws as an upright rectangle, but you can set its
// four corners (and/or texture coordinates) independently to warp it.
// Corner order is [bottom-left, bottom-right, top-right, top-left],
// matching Mini Micro 1; uv (0,0) is the bottom-left of the image.

Sprite.localCorners = null	// if set, 4 [x,y] points in local (unscaled, unrotated) space
Sprite._uvs = null			// if set, 4 [u,v] points
Sprite._hexDigits = "0123456789ABCDEF"

Sprite._scaleXY = function
	"Return this sprite's scale as an [x, y] list."
	if self.scale isa list then return [self.scale[0], self.scale[1]]
	return [self.scale, self.scale]
end function

Sprite._localCorners = function
	"Return this sprite's four corners in local (unscaled, unrotated) coordinates."
	if self.localCorners then return self.localCorners
	if self.srcRect then
		hw = self.srcRect[2] / 2
		hh = self.srcRect[3] / 2
	else
		if self.image == null then return null
		hw = self.image.width / 2
		hh = self.image.height / 2
	end if
	return [[-hw,-hh], [hw,-hh], [hw,hh], [-hw,hh]]
end function

// Corners in world (display) coordinates, i.e. with scale, rotation,
// and position applied.  Returns null if we have nothing to draw yet.
Sprite.corners = function
	"Return this sprite's four corners in display coordinates, or null if no image."
	lc = self._localCorners
	if lc == null then return null
	s = self._scaleXY
	radians = self.rotation * pi / 180
	cosR = cos(radians); sinR = sin(radians)
	result = []
	for p in lc
		px = p[0] * s[0]
		py = p[1] * s[1]
		result.push [self.x + px * cosR - py * sinR,
		             self.y + py * cosR + px * sinR]
	end for
	return result
end function

// Set the corners, in world coordinates; they are stored relative to
// our position/rotation/scale, so moving the sprite moves them too.
Sprite.setCorners = function(points)
	"Warp this sprite by setting its four corners, in display coordinates."
	if not (points isa list) or points.len != 4 then
		print "Sprite.setCorners requires a list of exactly 4 [x,y] points"
		return
	end if
	s = self._scaleXY
	if s[0] == 0 or s[1] == 0 then return
	radians = -self.rotation * pi / 180
	cosR = cos(radians); sinR = sin(radians)
	result = []
	for pt in points
		dx = pt[0] - self.x
		dy = pt[1] - self.y
		result.push [(dx * cosR - dy * sinR) / s[0],
		             (dy * cosR + dx * sinR) / s[1]]
	end for
	self.localCorners = result
end function

Sprite.uvs = function
	"Return the texture coordinates at the four corners, as [u,v] lists."
	if self._uvs == null then return [[0,0], [1,0], [1,1], [0,1]]
	result = []
	for uv in self._uvs
		result.push [uv[0], uv[1]]
	end for
	return result
end function

Sprite.setUVs = function(uvs)
	"Set the texture coordinates at the four corners, as [u,v] lists."
	if not (uvs isa list) or uvs.len != 4 then
		print "Sprite.setUVs requires a list of exactly 4 [u,v] points"
		return
	end if
	result = []
	for uv in uvs
		result.push [uv[0], uv[1]]
	end for
	self._uvs = result
end function

Sprite._tintRGBA = function
	"Return this sprite's tint as an [r, g, b, a] list."
	t = self.tint
	if t == null then return [255, 255, 255, 255]
	if t isa list then
		if t.len > 3 then return t
		return [t[0], t[1], t[2], 255]
	end if
	if t isa map then return [t.r, t.g, t.b, t.a]
	// an HTML-style color string, as accepted everywhere else
	if not (t isa string) or t.len < 7 or t[0] != "#" then return [255, 255, 255, 255]
	result = [255, 255, 255, 255]
	for i in [0, 1, 2, 3]
		if t.len < 3 + i*2 then break
		hi = self._hexDigits.indexOf(t[1 + i*2].upper)
		lo = self._hexDigits.indexOf(t[2 + i*2].upper)
		if hi == null or lo == null then return [255, 255, 255, 255]
		result[i] = hi * 16 + lo
	end for
	return result
end function

// Solve for the 3x3 homography H taking local quad coordinates to
// texture coordinates: uv = (H * [x,y,1]) / z.  Eight unknowns (h22 is
// fixed at 1), so eight equations from the four corner correspondences,
// by Gaussian elimination with partial pivoting.  Returns the eight
// coefficients, or null if the quad is degenerate.
Sprite._solveHomography = function(pts, uvs)
	"Solve for the projective transform taking four local points to four UVs."
	a = []
	b = []
	for i in [0, 1, 2, 3]
		x = pts[i][0]; y = pts[i][1]
		u = uvs[i][0]; v = uvs[i][1]
		a.push [x, y, 1, 0, 0, 0, -u*x, -u*y]; b.push u
		a.push [0, 0, 0, x, y, 1, -v*x, -v*y]; b.push v
	end for
	for col in range(0, 7)
		best = col
		if col < 7 then
			for r in range(col+1, 7)
				if abs(a[r][col]) > abs(a[best][col]) then best = r
			end for
		end if
		if abs(a[best][col]) < 1e-12 then return null
		tmp = a[col]; a[col] = a[best]; a[best] = tmp
		tmp = b[col]; b[col] = b[best]; b[best] = tmp
		pivot = a[col]
		pv = pivot[col]
		for r in range(0, 7)
			if r == col then continue
			row = a[r]
			f = row[col] / pv
			if f == 0 then continue
			for c in range(col, 7)
				row[c] = row[c] - f * pivot[c]
			end for
			b[r] = b[r] - f * b[col]
		end for
	end for
	result = []
	for i in range(0, 7)
		result.push b[i] / a[i][i]
	end for
	return result
end function

// The warped quad is drawn with a small shader pair that does the
// projective divide per pixel, since rlgl's vertex format has only a
// vec2 texcoord and so cannot carry homogeneous UVs.  The homogeneous
// texture coordinate (u*w, v*w, w) is computed per vertex on the CPU: u*w and
// v*w travel in the texcoord, and w travels in the vertex position's (unused)
// z.  All three are affine in screen space, so the rasterizer interpolates
// them exactly and the fragment shader divides.  Because nothing varies per
// sprite except vertex data, any number of consecutive warped sprites can
// share one shader bracket (see Sprite._beginQuadBatch), instead of paying a
// batch flush -- hundreds of microseconds -- for every sprite.
// Built lazily, and shared by every Sprite, so a program that never warps
// one never makes it.
Sprite._shader = null
Sprite._shaderFailed = false
Sprite._batching = false	// true while a shader bracket is open around a run of warped sprites

Sprite._ensureShader = function
	"Return the shared warped-quad shader, building it if needed (null on failure)."
	if Sprite._shader != null then return Sprite._shader
	if Sprite._shaderFailed then return null
	ver = raylib.rlGetVersion
	if ver == raylib.RL_OPENGL_ES_20 then
		vs = ["#version 100",
		"precision highp float;",
		"attribute vec3 vertexPosition;",
		"attribute vec2 vertexTexCoord;",
		"attribute vec4 vertexColor;",
		"uniform mat4 mvp;",
		"varying vec2 fragTexCoord;",
		"varying float fragW;",
		"varying vec4 fragColor;",
		"void main() {",
		"    fragTexCoord = vertexTexCoord;",
		"    fragW = vertexPosition.z;",
		"    fragColor = vertexColor;",
		"    gl_Position = mvp * vec4(vertexPosition.xy, 0.0, 1.0);",
		"}"]
		fs = ["#version 100",
		"precision highp float;",	// screen-scale texcoords band badly at mediump
		"varying vec2 fragTexCoord;",
		"varying float fragW;",
		"varying vec4 fragColor;",
		"uniform sampler2D texture0;",
		"uniform vec4 colDiffuse;",
		"void main() {",
		"    gl_FragColor = texture2D(texture0, fragTexCoord / fragW) * colDiffuse * fragColor;",
		"}"]
	else
		vs = ["#version 330",
		"in vec3 vertexPosition;",
		"in vec2 vertexTexCoord;",
		"in vec4 vertexColor;",
		"uniform mat4 mvp;",
		"out vec2 fragTexCoord;",
		"out float fragW;",
		"out vec4 fragColor;",
		"void main() {",
		"    fragTexCoord = vertexTexCoord;",
		"    fragW = vertexPosition.z;",
		"    fragColor = vertexColor;",
		"    gl_Position = mvp * vec4(vertexPosition.xy, 0.0, 1.0);",
		"}"]
		fs = ["#version 330",
		"in vec2 fragTexCoord;",
		"in float fragW;",
		"in vec4 fragColor;",
		"uniform sampler2D texture0;",
		"uniform vec4 colDiffuse;",
		"out vec4 finalColor;",
		"void main() {",
		"    finalColor = texture(texture0, fragTexCoord / fragW) * colDiffuse * fragColor;",
		"}"]
	end if
	sh = raylib.LoadShaderFromMemory(vs.join(char(10)), fs.join(char(10)))
	if sh == null then
		Sprite._shaderFailed = true
		print "Sprite: warped-quad shader failed to compile"
		return null
	end if
	Sprite._shader = sh
	return sh
end function

// Open a shader bracket that stays open across consecutive warped sprites
// (SpriteDisplay.render does this).  Returns false if the shader is unavailable.
Sprite._beginQuadBatch = function
	"Begin a shared shader bracket for a run of warped sprites."
	if Sprite._batching then return true
	shader = Sprite._ensureShader
	if shader == null then return false
	raylib.BeginShaderMode shader
	Sprite._batching = true
	return true
end function

Sprite._endQuadBatch = function
	"End the shared shader bracket, if one is open."
	if not Sprite._batching then return
	raylib.EndShaderMode
	Sprite._batching = false
end function

// Cache of the solved homography, keyed on what it was solved from.
Sprite._homography = null
Sprite._hCorners = null
Sprite._hUVs = null

// Draw as an arbitrary textured quad.  Each vertex carries its *local*
// quad coordinate as the texcoord rather than a UV: local-to-screen is
// affine, so the rasterizer interpolates it exactly, and the shader then
// applies the local-to-UV homography and divides.  That is exact per
// pixel, with four vertices and no subdivision.
Sprite._drawQuad = function(offsetX, offsetY)
	"Draw this sprite as an arbitrary (warped) textured quad."
	lc = self._localCorners
	if lc == null then return
	pts = self.corners
	h = Display.screenHeight
	p = []
	for c in pts
		p.push [c[0] + offsetX, h - c[1] - offsetY]
	end for

	tex = self.image.texture
	if self.srcRect then sr = self.srcRect else sr = [0, 0, self.image.width, self.image.height]
	uvs = self.uvs
	// Mini Micro UVs are bottom-up over srcRect; raylib's are top-down over the texture.
	tuv = []
	for uv in uvs
		tuv.push [(sr[0] + uv[0] * sr[2]) / tex.width,
		          (sr[1] + (1 - uv[1]) * sr[3]) / tex.height]
	end for

	if self._homography == null or self._hCorners != lc or self._hUVs != tuv then
		self._homography = self._solveHomography(lc, tuv)
		self._hCorners = lc
		self._hUVs = tuv
	end if
	m = self._homography
	if m == null then return	// degenerate quad; nothing sensible to draw

	own = not Sprite._batching	// not inside a SpriteDisplay run: bracket just this sprite
	if own then
		shader = Sprite._ensureShader
		if shader == null then return
	end if
	rgba = self._tintRGBA
	// homogeneous texcoord at each vertex: H * [x, y, 1]
	hu = []; hv = []; hw = []
	for c in lc
		x = c[0]; y = c[1]
		hu.push m[0]*x + m[1]*y + m[2]
		hv.push m[3]*x + m[4]*y + m[5]
		hw.push m[6]*x + m[7]*y + 1
	end for
	if own then raylib.BeginShaderMode shader
	raylib.rlSetTexture tex.id
	raylib.rlBegin raylib.RL_QUADS
	raylib.rlColor4ub rgba[0], rgba[1], rgba[2], rgba[3]
	raylib.rlNormal3f 0, 0, 1
	// wound as raylib does: top-left, bottom-left, bottom-right, top-right
	for i in [3, 0, 1, 2]
		raylib.rlTexCoord2f hu[i], hv[i]
		raylib.rlVertex3f p[i][0], p[i][1], hw[i]
	end for
	raylib.rlEnd
	raylib.rlSetTexture 0
	if own then raylib.EndShaderMode
end function

Sprite.update = null	// define your own update method if needed

Sprite.draw = function(offsetX=0, offsetY=0)
	"Draw this sprite to the screen, shifted by the given offset."
	image = self.image
	if image == null then return
	if self.localCorners or self._uvs then
		self._drawQuad offsetX, offsetY
		return
	end if
	// (written without helper lists or copies: this runs once per sprite per frame)
	sr = self.srcRect
	if sr then
		srcX = sr[0]; srcY = sr[1]; srcW = sr[2]; srcH = sr[3]
	else
		srcX = 0; srcY = 0; srcW = image.width; srcH = image.height
	end if
	sc = self.scale
	if sc isa list then
		scaleX = sc[0]; scaleY = sc[1]
	else
		scaleX = sc; scaleY = sc
	end if
	destWidth = srcW * abs(scaleX)
	destHeight = srcH * abs(scaleY)
	if scaleX < 0 then srcW = -srcW
	if scaleY < 0 then srcH = -srcH
	raylib.DrawTexturePro image.texture, [srcX, srcY, srcW, srcH],
		[self.x + offsetX, Display.screenHeight - self.y - offsetY, destWidth, destHeight],
		[destWidth * 0.5, destHeight * 0.5], -self.rotation, self.tint
end function

Sprite.worldBounds = function
	"Return this sprite's localBounds transformed to display coordinates."
	lb = self.localBounds
	if lb == null then return null
	b = new Bounds
	if self.scale isa list then
		sx = self.scale[0]
		sy = self.scale[1]
	else
		sx = self.scale
		sy = sx
	end if
	b.x = self.x + lb.x * sx
	b.y = self.y + lb.y * sy
	b.width = lb.width * sx
	b.height = lb.height * sy
	b.rotation = self.rotation + lb.rotation
	return b
end function

Sprite.contains = function(x, y)
	"Return whether the given point is within this sprite's bounds."
	if self.localBounds == null then return false
	return self.worldBounds.contains(x, y)
end function

Sprite.overlaps = function(other)
	"Return whether this sprite's bounds overlap another Sprite or Bounds."
	if other isa Sprite then other = other.worldBounds
	return self.worldBounds.overlaps(other)
end function

SpriteDisplay = new Display
SpriteDisplay.mode = 5
SpriteDisplay.scrollX = 0
SpriteDisplay.scrollY = 0
SpriteDisplay.sprites = null

SpriteDisplay.Make = function
	"Create and return a new, empty SpriteDisplay."
	sp = new self
	sp.clear
	return sp
end function

SpriteDisplay.clear = function
	"Remove all sprites and reset the scroll position."
	self.sprites = []
	self.scrollX = 0
	self.scrollY = 0
end function

SpriteDisplay._renderSprites = function(spriteList)
	"Draw each sprite in the given list, recursing into any nested lists."
	for sp in spriteList
		if sp isa list then
			self._renderSprites sp
			continue
		end if
		// Consecutive warped sprites share one shader bracket; any other
		// sprite closes it first, so draw order is unchanged.
		if sp isa Sprite and sp.image != null and (sp.localCorners or sp._uvs) then
			if not Sprite._batching then Sprite._beginQuadBatch
		else if Sprite._batching then
			Sprite._endQuadBatch
		end if
		sp.draw -self.scrollX, -self.scrollY
	end for
end function

SpriteDisplay.render = function
	"Draw all sprites in this display to the screen."
	Sprite._endQuadBatch
	self._renderSprites self.sprites
	Sprite._endQuadBatch
end function

testBounds = function
	"Interactive test: highlight a rotated Bounds when the mouse is inside it."
	import "soda"
	
	b = new Bounds
	b.x = 280
	b.y = 400
	b.width = 200
	b.height = 100
	b.rotation = 45
	while true	
		if b.contains(mouse) then
			gfx.drawPoly b.corners, color.yellow
		else
			gfx.drawPoly b.corners, color.gray
		end if
		yield
	end while
end function

if locals == globals then
	testBounds
else
	return SpriteDisplay
end if
