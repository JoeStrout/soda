
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
	code = c.code
	if code >= 48 and code <= 57 then return code - 48
	if code >= 65 and code <= 70 then return code - 55
	if code >= 97 and code <= 102 then return code - 87
	return 0
end function

// Convert a Mini Micro color string ("#RRGGBB" or "#RRGGBBAA")
// to a numeric [r, g, b, a] list.
toList = function(s)
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

// Convert a numeric [r, g, b, a] list or map to a color string.
_hexDigits = "0123456789ABCDEF"
fromList = function(rgbaList)
	s = "#"
	if rgbaList isa map then
		c = rgbaList
		s += _hexDigits[floor(c.r / 16)] + _hexDigits[c.r % 16]
		s += _hexDigits[floor(c.g / 16)] + _hexDigits[c.g % 16]
		s += _hexDigits[floor(c.b / 16)] + _hexDigits[c.b % 16]
		s += _hexDigits[floor(c.a / 16)] + _hexDigits[c.a % 16]
	else
		for value in rgbaList
			s += _hexDigits[floor(value / 16)] + _hexDigits[value % 16]
		end for
	end if
	return s
end function

rgba = function(r, g, b, a=255)
	return "#" +
	  _hexDigits[floor(r /16)] + _hexDigits[r % 16] +
	  _hexDigits[floor(g /16)] + _hexDigits[g % 16] +
	  _hexDigits[floor(b /16)] + _hexDigits[b % 16] +
	  _hexDigits[floor(a /16)] + _hexDigits[a % 16]
end function

// rgb: same as rgba, but with alpha defaulting to fully opaque (255).
rgb = @rgba

lerp = function(c1, c2, t)
	return fromList(raylib.ColorLerp(c1, c2, t))
end function
