SolidColorDisplay = new Display
SolidColorDisplay.mode = displayMode.solidColor
SolidColorDisplay.color = "#000000FF"

SolidColorDisplay.Make = function(color="#000000FF")
	result = new self
	result.color = color
	return result
end function

// Fill the whole screen with our color.  This is a rectangle rather than
// ClearBackground so that a translucent color blends over the displays below
// it, and so that it covers only the screen, not a host's bezel around it.
SolidColorDisplay.render = function
	raylib.DrawRectangle self.screenLeft, self.screenTop,
	  self.screenWidth, self.screenHeight, color.toList(self.color)
end function

return SolidColorDisplay
