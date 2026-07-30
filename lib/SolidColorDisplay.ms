SolidColorDisplay = new Display
SolidColorDisplay.mode = displayMode.solidColor
SolidColorDisplay.color = "#000000FF"

SolidColorDisplay.render = function
	raylib.DrawRectangle 0, 0, 960, 640, color.toList(self.color)
end function

SolidColorDisplay.Make = function
	return new SolidColorDisplay
end function

return SolidColorDisplay
