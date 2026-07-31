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

Sprite.update = null	// define your own update method if needed

Sprite.draw = function(offsetX=0, offsetY=0)
	if self.image == null then return
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

SpriteDisplay.render = function
	for sp in self.sprites
		sp.draw self.scrollX, self.scrollY
	end for
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
