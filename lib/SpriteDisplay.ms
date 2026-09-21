import "importUtil"
ensureImport ["Display", "Image"]

globals.Bounds = {}
Bounds.x = 0
Bounds.y = 0
Bounds.width = 0
Bounds.height = 0
Bounds.rotation = 0

Bounds.corners = function
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
	if x isa map then
		y = x.y
		x = x.x
	else if x isa list then
		y = x[1]
		x = x[0]
	end if
	dx = x - self.x
	dy = y - self.y
	cosR = cos(-self.rotation * pi / 180)
	sinR = sin(-self.rotation * pi / 180)
	localX = dx * cosR - dy * sinR
	localY = dx * sinR + dy * cosR
	hw = self.width / 2
	hh = self.height / 2
	return abs(localX) <= hw and abs(localY) <= hh
end function

Bounds.overlaps = function(b)
	cornersA = self.corners
	cornersB = b.corners
	axes = []
	for corners in [cornersA, cornersB]
		for i in [0, 1]
			j = i + 1
			edgeX = corners[j][0] - corners[i][0]
			edgeY = corners[j][1] - corners[i][1]
			axes.push [-edgeY, edgeX]
		end for
	end for
	for axis in axes
		minA = axis[0] * cornersA[0][0] + axis[1] * cornersA[0][1]
		maxA = minA
		for i in range(1, 3)
			proj = axis[0] * cornersA[i][0] + axis[1] * cornersA[i][1]
			if proj < minA then minA = proj
			if proj > maxA then maxA = proj
		end for
		minB = axis[0] * cornersB[0][0] + axis[1] * cornersB[0][1]
		maxB = minB
		for i in range(1, 3)
			proj = axis[0] * cornersB[i][0] + axis[1] * cornersB[i][1]
			if proj < minB then minB = proj
			if proj > maxB then maxB = proj
		end for
		if maxA < minB or maxB < minA then return false
	end for
	return true
end function

globals.Sprite = {}
Sprite.x = 0
Sprite.y = 0
Sprite.rotation = 0
Sprite.scale = 1
Sprite.image = null
Sprite.srcRect = null    // optional: [left, top, width, height] in image
Sprite.tint = raylib.WHITE
Sprite.localBounds = null


// Auto-create a localBounds from our image or srcRect,
// optionally inset.  Inset may be given as separate X and Y
// values, or as a single number to apply to both, or as an
// [x,y] list, or an {"x":x, "y":y} map.
Sprite.addBounds = function(insetX=0, insetY=null)
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
	if self.scale isa list then return [self.scale[0], self.scale[1]]
	return [self.scale, self.scale]
end function

Sprite._localCorners = function
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
	if self._uvs == null then return [[0,0], [1,0], [1,1], [0,1]]
	result = []
	for uv in self._uvs
		result.push [uv[0], uv[1]]
	end for
	return result
end function

Sprite.setUVs = function(uvs)
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

// The warped quad is drawn with a fragment shader that does the
// projective divide per pixel, since rlgl's vertex format has only a
// vec2 texcoord and so cannot carry homogeneous UVs.  Built lazily, and
// shared by every Sprite, so a program that never warps one never makes it.
Sprite._shader = null
Sprite._shaderLoc = -1
Sprite._shaderFailed = false

Sprite._ensureShader = function
	if Sprite._shader != null then return Sprite._shader
	if Sprite._shaderFailed then return null
	ver = raylib.rlGetVersion
	if ver == raylib.RL_OPENGL_ES_20 then
		src = ["#version 100",
		"precision highp float;",	// screen-scale texcoords band badly at mediump
		"varying vec2 fragTexCoord;",
		"varying vec4 fragColor;",
		"uniform sampler2D texture0;",
		"uniform vec4 colDiffuse;",
		"uniform mat4 uH;",
		"void main() {",
		"    vec3 h = (uH * vec4(fragTexCoord, 1.0, 0.0)).xyz;",
		"    gl_FragColor = texture2D(texture0, h.xy / h.z) * colDiffuse * fragColor;",
		"}"]
	else
		src = ["#version 330",
		"in vec2 fragTexCoord;",
		"in vec4 fragColor;",
		"uniform sampler2D texture0;",
		"uniform vec4 colDiffuse;",
		"uniform mat4 uH;",
		"out vec4 finalColor;",
		"void main() {",
		"    vec3 h = (uH * vec4(fragTexCoord, 1.0, 0.0)).xyz;",
		"    finalColor = texture(texture0, h.xy / h.z) * colDiffuse * fragColor;",
		"}"]
	end if
	sh = raylib.LoadShaderFromMemory("", src.join(char(10)))
	if sh == null then
		Sprite._shaderFailed = true
		print "Sprite: warped-quad shader failed to compile"
		return null
	end if
	Sprite._shader = sh
	Sprite._shaderLoc = raylib.GetShaderLocation(sh, "uH")
	return sh
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

	shader = self._ensureShader
	if shader == null then return
	rgba = self._tintRGBA
	raylib.BeginShaderMode shader
	raylib.SetShaderValueMatrix shader, Sprite._shaderLoc,
		[[m[0], m[1], m[2], 0],
		 [m[3], m[4], m[5], 0],
		 [m[6], m[7], 1,    0],
		 [0,    0,    0,    1]]
	raylib.rlSetTexture tex.id
	raylib.rlBegin raylib.RL_QUADS
	raylib.rlColor4ub rgba[0], rgba[1], rgba[2], rgba[3]
	raylib.rlNormal3f 0, 0, 1
	// wound as raylib does: top-left, bottom-left, bottom-right, top-right
	for i in [3, 0, 1, 2]
		raylib.rlTexCoord2f lc[i][0], lc[i][1]
		raylib.rlVertex2f p[i][0], p[i][1]
	end for
	raylib.rlEnd
	raylib.rlSetTexture 0
	raylib.EndShaderMode
end function

Sprite.update = null	// define your own update method if needed

Sprite.draw = function(offsetX=0, offsetY=0)
	if self.image == null then return
	if self.localCorners or self._uvs then
		self._drawQuad offsetX, offsetY
		return
	end if
	if self.srcRect then
		srcRect = self.srcRect
	else
		srcRect = [0, 0, self.image.width, self.image.height]
	end if
	if self.scale isa list then
		destWidth = srcRect[2] * self.scale[0]
		destHeight = srcRect[3] * self.scale[1]
	else
		destWidth = srcRect[2] * self.scale
		destHeight = srcRect[3] * self.scale
	end if
	h = Display.screenHeight
	destRect = [self.x + offsetX, h - self.y - offsetY, destWidth, destHeight]
	origin = [destWidth * 0.5, destHeight * 0.5]
	raylib.DrawTexturePro self.image.texture, srcRect, destRect,
		origin, -self.rotation, self.tint
end function

Sprite.worldBounds = function
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
	if self.localBounds == null then return false
	return self.worldBounds.contains(x, y)
end function

Sprite.overlaps = function(other)
	if other isa Sprite then other = other.worldBounds
	return self.worldBounds.overlaps(other)
end function

SpriteDisplay = new Display
SpriteDisplay.mode = 5
SpriteDisplay.scrollX = 0
SpriteDisplay.scrollY = 0
SpriteDisplay.sprites = null

SpriteDisplay.Make = function
	sp = new SpriteDisplay
	sp.clear
	return sp
end function

SpriteDisplay.clear = function
	self.sprites = []
	self.scrollX = 0
	self.scrollY = 0
end function

SpriteDisplay._renderSprites = function(spriteList)
	for sp in spriteList
		if sp isa list then self._renderSprites sp else sp.draw self.scrollX, self.scrollY
	end for
end function

SpriteDisplay.render = function
	self._renderSprites self.sprites
end function

testBounds = function
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
