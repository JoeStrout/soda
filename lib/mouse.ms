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

update = function
	outer.x = raylib.GetMouseX
	outer.y = raylib.GetScreenHeight - raylib.GetMouseY
end function

