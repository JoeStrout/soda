import "importUtil"
ensureImport ["Display"]

button = function(which=0)
	return raylib.IsMouseButtonDown(which)
end function

visible = function
	return true
end function

locked = function
	return false
end function

x = 0
y = 0

// Report the pointer in screen coordinates: the same space the displays draw
// in, bottom-up, with the origin at the bottom-left of Display's screen rect.
// Under a host that insets the screen in a bezel, that is not the window
// origin, and using raw window coordinates would offset every click.
update = function
	outer.x = raylib.GetMouseX - Display.screenLeft
	outer.y = Display.screenTop + Display.screenHeight - raylib.GetMouseY
end function

