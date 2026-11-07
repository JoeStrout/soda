
clear = "#00000000"
black = "#000000"
white = "#FFFFFF"
gray = "#808080"
silver = "#C0C0C0"
maroon = "#800000"
red = "#FF0000"
olive = "#808000"
yellow = "#FFFF00"
orange = "#FF8000"
green = "#008000"
lime = "#00FF00"
teal = "#008080"
aqua = "#00FFFF"
navy = "#000080"
blue = "#0000FF"
purple = "#800080"
fuchsia = "#FF00FF"
brown = "#996633"
pink = "#FF8080"


// Convert a hex digit character to its numeric value (0-15).
hexDigitVal = function(c)
	"Return the numeric value (0-15) of a single hex digit character."
	code = c.code
	if code >= 48 and code <= 57 then return code - 48
	if code >= 65 and code <= 70 then return code - 55
	if code >= 97 and code <= 102 then return code - 87
	return 0
end function

// Convert a Mini Micro color string ("#RRGGBB" or "#RRGGBBAA")
// to a numeric [r, g, b, a] list.
toList = function(s)
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

// Two-digit hex for every byte value, so fromList is a lookup per channel
// (it is on the hot path of PixelDisplay.pixel, among other places).
_makeHexBytes = function
	"Return a list of two-digit hex strings for every byte value 0-255."
	digits = "0123456789ABCDEF"
	result = []
	for i in range(0, 255)
		result.push digits[floor(i / 16)] + digits[i % 16]
	end for
	return result
end function
_hexByte = _makeHexBytes
freeze _hexByte

// Clamp a channel value to 0-255, as Mini Micro does (an index into the hex
// table would otherwise crash above 255 and silently wrap below 0).
_clamp = function(v)
	if v < 0 then return 0
	if v > 255 then return 255
	return v
end function

// Convert a numeric [r, g, b, a] list or map to a color string.
fromList = function(rgbaList)
	"Convert an [r, g, b, a] list (or r/g/b/a map) to a color string."
	hb = _hexByte
	if rgbaList isa map then
		c = rgbaList
		return "#" + hb[_clamp(c.r)] + hb[_clamp(c.g)] + hb[_clamp(c.b)] + hb[_clamp(c.a)]
	end if
	s = ["#"]
	for value in rgbaList
		if value < 0 or value > 255 then value = _clamp(value)
		s.push hb[value]
	end for
	return s.join("")
end function

rgba = function(r, g, b, a=255)
	"Return a #RRGGBBAA color string from the given red, green, blue, and alpha (0-255)."
	if r < 0 or r > 255 or g < 0 or g > 255 or b < 0 or b > 255 or a < 0 or a > 255 then
		r = _clamp(r); g = _clamp(g); b = _clamp(b); a = _clamp(a)
	end if
	return "#" + _hexByte[r] + _hexByte[g] + _hexByte[b] + _hexByte[a]
end function

// rgb: same as rgba, but with alpha defaulting to fully opaque (255).
rgb = function(r, g, b)
	"Return a #RRGGBB color string from the given red, green, and blue (0-255)."
	if r < 0 or r > 255 or g < 0 or g > 255 or b < 0 or b > 255 then
		r = _clamp(r); g = _clamp(g); b = _clamp(b)
	end if
	return "#" + _hexByte[r] + _hexByte[g] + _hexByte[b]
end function

// Interpolate between two colors: t <= 0 gives c1, t >= 1 gives c2, and
// anything between mixes them.  t defaults to halfway, as in Mini Micro 1.
lerp = function(c1, c2, t=0.5)
	"Return a color interpolated between c1 and c2 by t (0-1)."
	return fromList(raylib.ColorLerp(c1, c2, t))
end function
