SolidColorDisplay = new Display
SolidColorDisplay.mode = displayMode.solidColor
SolidColorDisplay.color = "#000000FF"
SolidColorDisplay.width = 960
SolidColorDisplay.height = 640

SolidColorDisplay.Make = function(width=960, height=640, color="#000000FF")
	result = new SolidColorDisplay
	result.width = width
	result.height = height
	result.color = color
	return result
end function

SolidColorDisplay.render = function
	raylib.DrawRectangle 0, 0, self.width, self.height, color.toList(self.color)
end function

return SolidColorDisplay
