// ScreenFont: the Mini Micro screen font -- a texture holding a 16x16 grid
// of glyphs, plus the special Unicode-to-grid-position mappings that let
// Mini Micro show arrows, card suits, dice faces, etc.
//
// This is a port of ScreenFont.cpp/ScreenFont.h from the MiniMicro2 (C++)
// project.  As there, glyphs are drawn through a small shader that reads the
// texture's alpha channel as a mask and mixes between a background and a
// foreground color; that way one white-on-transparent font sheet can render
// any fore/back color combination, including a solid background behind the
// glyph.  If the shader can't be compiled, we fall back to drawing a
// background rectangle and then the glyph tinted with the fore color.

import "importUtil"
ensureImport ["color"]

rl = raylib

ScreenFont = {}
ScreenFont.texture = null
ScreenFont.charWidth = 0
ScreenFont.charHeight = 0

// The shader (and its uniform locations) is shared by all ScreenFont
// instances, mirroring the static members of the C++ class.  It lives at
// module scope rather than on the ScreenFont map so that `new ScreenFont`
// instances can't accidentally shadow it.
_shader = null
_foreColorLoc = -1
_backColorLoc = -1
_shaderTried = false

// Cache of the colors last pushed into the shader's uniforms.  GL keeps
// uniform values in the shader program itself, so re-setting an unchanged
// one is pure overhead -- and at ~1800 cells per frame, that adds up.
_lastFore = null
_lastBack = null

// Fragment shader source, in two flavors: GLSL 330 (desktop GL 3.3) and
// GLSL 100 (OpenGL ES 2 / web).  We let raylib supply the vertex shader,
// since the one the C++ version ships is identical to raylib's default.
_fragShader330 = [
"#version 330",
"in vec2 fragTexCoord;",
"in vec4 fragColor;",
"uniform sampler2D texture0;",
"uniform vec4 colDiffuse;",
"uniform vec4 foreColor;",
"uniform vec4 backColor;",
"out vec4 finalColor;",
"void main()",
"{",
"    vec4 texelColor = texture(texture0, fragTexCoord);",
"    float mask = texelColor.a;",
"    finalColor = mix(backColor, foreColor, mask);",
"}"].join(char(10))

_fragShader100 = [
"#version 100",
"precision mediump float;",
"varying vec2 fragTexCoord;",
"varying vec4 fragColor;",
"uniform sampler2D texture0;",
"uniform vec4 colDiffuse;",
"uniform vec4 foreColor;",
"uniform vec4 backColor;",
"void main()",
"{",
"    vec4 texelColor = texture2D(texture0, fragTexCoord);",
"    float mask = texelColor.a;",
"    gl_FragColor = mix(backColor, foreColor, mask);",
"}"].join(char(10))

// Internal: try one fragment shader source.  Returns true if it compiled
// *and* actually exposes our custom uniforms.  (raylib quietly hands back
// the default shader when compilation fails, so checking the uniform
// location is the reliable test.)
_tryShaderSource = function(fragSrc)
	shader = rl.LoadShaderFromMemory("", fragSrc)
	if shader == null then return false
	foreLoc = rl.GetShaderLocation(shader, "foreColor")
	backLoc = rl.GetShaderLocation(shader, "backColor")
	if foreLoc < 0 or backLoc < 0 then
		rl.UnloadShader shader
		return false
	end if
	outer._shader = shader
	outer._foreColorLoc = foreLoc
	outer._backColorLoc = backLoc
	return true
end function

// Load the shared shader.  Called automatically the first time a character
// is drawn, but you may call it earlier if you prefer.  Returns true on
// success.  (Corresponds to ScreenFont::LoadShader in the C++ version,
// except that the source is built in rather than read from files.)
ScreenFont.loadShader = function
	if _shader != null then rl.UnloadShader _shader
	outer._shader = null
	outer._foreColorLoc = -1
	outer._backColorLoc = -1
	outer._shaderTried = true
	outer._lastFore = null		// (uniform cache; see _setColorUniform below)
	outer._lastBack = null
	if _tryShaderSource(_fragShader330) then return true
	if _tryShaderSource(_fragShader100) then return true
	return false
end function

ScreenFont.unloadShader = function
	if _shader == null then return
	rl.UnloadShader _shader
	outer._shader = null
	outer._foreColorLoc = -1
	outer._backColorLoc = -1
	outer._shaderTried = false
	outer._lastFore = null
	outer._lastBack = null
end function

ScreenFont.shaderLoaded = function
	return _shader != null
end function

// Create a new ScreenFont, optionally loading a font texture right away.
ScreenFont.Make = function(texturePath=null)
	noob = new ScreenFont
	if texturePath != null then noob.load texturePath
	return noob
end function

// Load a font texture.  It should be a 16x16 grid of glyphs, white (or any
// color) on transparent; only the alpha channel is used.  Returns true on
// success.
ScreenFont.load = function(texturePath)
	if self.texture != null then
		rl.UnloadTexture self.texture
		self.texture = null
	end if
	tex = rl.LoadTexture(texturePath)
	if tex == null then
		self.charWidth = 0
		self.charHeight = 0
		return false
	end if
	rl.SetTextureFilter tex, rl.TEXTURE_FILTER_POINT
	self.texture = tex
	self.charWidth = floor(tex.width / 16)
	self.charHeight = floor(tex.height / 16)
	return true
end function

ScreenFont.isLoaded = function
	return self.texture != null
end function

// Map from a Unicode code point to a position (0-255) in the 16x16 font grid.
// Most of the non-ASCII range is not present in the sheet, so only the
// specific characters listed here are mapped; anything else becomes the
// "unknown character" glyph at position 21.
// (MiniScript has no hex literals, so the code points are given in decimal
// with the hex form in the comment.)
ScreenFont._specialPositions = {
	57856: 130,		// U+E200 button caps
	57857: 131,		// U+E201
	57872: 140,		// U+E210 stick figure
	57873: 141,		// U+E211
	57874: 142,		// U+E212
	57875: 143,		// U+E213
	57888: 150,		// U+E220 tree
	8226: 158,		// U+2022 bullet
	8230: 135,		// U+2026 ellipsis
	960: 159,		// U+03C0 Pi
	964: 160,		// U+03C4 Tau
	8592: 17,		// U+2190 left arrow
	8593: 19,		// U+2191 up arrow
	8594: 18,		// U+2192 right arrow
	8595: 20,		// U+2193 down arrow
	9744: 132,		// U+2610 empty box
	9745: 133,		// U+2611 box with checkmark
	9746: 134,		// U+2612 box with X
	9824: 136,		// U+2660 spade
	9827: 137,		// U+2663 club
	9829: 138,		// U+2665 heart
	9830: 139,		// U+2666 diamond
	9856: 144,		// U+2680 dice faces
	9857: 145,		// U+2681
	9858: 146,		// U+2682
	9859: 147,		// U+2683
	9860: 148,		// U+2684
	9861: 149,		// U+2685
	161: 161,		// upside-down exclamation
	169: 169,		// copyright symbol
	172: 172,		// CR symbol
	174: 174,		// registered symbol
	176: 176,		// degree symbol
	181: 181 }		// micro

ScreenFont.UNKNOWN_CHAR_POS = 21

ScreenFont.fontPosition = function(unicode)
	// ASCII and the Roman accented characters map straight through.
	if unicode <= 127 or (unicode >= 191 and unicode <= 255) then return unicode
	if self._specialPositions.hasIndex(unicode) then return self._specialPositions[unicode]
	return ScreenFont.UNKNOWN_CHAR_POS
end function

// Source rectangle in the font texture for the given code point.
ScreenFont.srcRect = function(unicode)
	fontPos = self.fontPosition(unicode)
	charRow = floor(fontPos / 16)
	charCol = fontPos % 16
	return [charCol * self.charWidth, charRow * self.charHeight,
	   self.charWidth, self.charHeight]
end function

// Internal: push an [r,g,b,a] color into a vec4 uniform, normalized to 0-1.
_setColorUniform = function(loc, rgba)
	rl.SetShaderValue _shader, loc,
	   [rgba[0]/255, rgba[1]/255, rgba[2]/255, rgba[3]/255], rl.SHADER_UNIFORM_VEC4
end function

// Draw one character.  x,y give the top-left corner of the character cell,
// in raylib screen coordinates (y increasing downward).
ScreenFont.drawChar = function(unicode, x, y, foreColor, backColor)
	if self.texture == null then return
	if not _shaderTried then self.loadShader

	src = self.srcRect(unicode)
	dest = [x, y, self.charWidth, self.charHeight]

	if _shader != null then
		fore = color.toList(foreColor)
		back = color.toList(backColor)
		rl.BeginShaderMode _shader
		if fore != _lastFore then
			_setColorUniform _foreColorLoc, fore
			outer._lastFore = fore
		end if
		if back != _lastBack then
			_setColorUniform _backColorLoc, back
			outer._lastBack = back
		end if
		rl.DrawTexturePro self.texture, src, dest, [0, 0], 0, [255, 255, 255, 255]
		rl.EndShaderMode
	else
		// Fallback: draw the background, then the glyph tinted with the
		// fore color.
		back = color.toList(backColor)
		if back[3] > 0 then rl.DrawRectangle x, y, self.charWidth, self.charHeight, back
		rl.DrawTexturePro self.texture, src, dest, [0, 0], 0, color.toList(foreColor)
	end if
end function

// Free the font texture.
ScreenFont.unload = function
	if self.texture == null then return
	rl.UnloadTexture self.texture
	self.texture = null
	self.charWidth = 0
	self.charHeight = 0
end function

if locals == globals then
	ensureImport "qa"
	if not rl.IsWindowReady then rl.InitWindow 960, 640

	print "== ScreenFont tests =="

	font = ScreenFont.Make("assets/lib/font/ScreenFont.png")
	qa.assert font.isLoaded, "ScreenFont.png should load"
	qa.assertEqual font.charWidth, 16, "ScreenFont.png is 256 wide, so glyphs are 16 wide"
	qa.assertEqual font.charHeight, 24, "ScreenFont.png is 384 tall, so glyphs are 24 tall"

	print "fontPosition passes ASCII straight through"
	qa.assertEqual font.fontPosition("A".code), 65, "'A' should map to position 65"
	qa.assertEqual font.fontPosition(" ".code), 32, "space should map to position 32"
	qa.assertEqual font.fontPosition(0), 0, "code 0 should map to position 0"
	qa.assertEqual font.fontPosition(127), 127, "code 127 should map to position 127"

	print "fontPosition passes the Roman accented range (191-255) straight through"
	qa.assertEqual font.fontPosition(191), 191, "191 should map to itself"
	qa.assertEqual font.fontPosition(255), 255, "255 should map to itself"

	print "fontPosition maps the special characters"
	qa.assertEqual font.fontPosition(8592), 17, "left arrow should map to 17"
	qa.assertEqual font.fontPosition(8593), 19, "up arrow should map to 19"
	qa.assertEqual font.fontPosition(8594), 18, "right arrow should map to 18"
	qa.assertEqual font.fontPosition(8595), 20, "down arrow should map to 20"
	qa.assertEqual font.fontPosition(960), 159, "pi should map to 159"
	qa.assertEqual font.fontPosition(9829), 138, "heart should map to 138"
	qa.assertEqual font.fontPosition(57888), 150, "tree should map to 150"

	print "fontPosition passes the hand-picked Latin-1 symbols straight through"
	for c in [161, 169, 172, 174, 176, 181]
		qa.assertEqual font.fontPosition(c), c, "code " + c + " should map to itself"
	end for

	print "fontPosition falls back to the unknown-character glyph"
	qa.assertEqual font.fontPosition(20013), 21, "an unmapped CJK char should map to 21"
	qa.assertEqual font.fontPosition(128), 21, "an unmapped code just past ASCII should map to 21"

	print "srcRect indexes the 16x16 grid left-to-right, top-to-bottom"
	qa.assertEqual font.srcRect(0), [0, 0, 16, 24], "position 0 should be the top-left glyph"
	qa.assertEqual font.srcRect("A".code), [16, 96, 16, 24], "'A' (65) should be grid cell (1,4)"
	qa.assertEqual font.srcRect(8592), [16, 24, 16, 24], "left arrow (17) should be grid cell (1,1)"

	print "the shader compiles for this GL backend"
	qa.assert ScreenFont.loadShader, "loadShader should succeed"
	qa.assert ScreenFont.shaderLoaded, "shaderLoaded should be true afterward"

	print "All ScreenFont tests passed!"

	print "== Visual test (look at the app window) =="
	demo = "ScreenFont: ABCdef 0123 " + char(8592) + char(8593) + char(8594) +
	   char(8595) + " " + char(9824) + char(9827) + char(9829) + char(9830) +
	   " " + char(960) + char(964) + " " + char(9856) + char(9857) + char(9858)
	while not rl.WindowShouldClose
		rl.BeginDrawing
		rl.ClearBackground color.toList(color.black)
		x = 8
		for ch in demo
			font.drawChar ch.code, x, 100, color.lime, color.clear
			x += 16
		end for
		x = 8
		for ch in demo
			font.drawChar ch.code, x, 140, color.black, color.orange
			x += 16
		end for
		rl.EndDrawing
	end while
	exit
else
	return ScreenFont
end if
