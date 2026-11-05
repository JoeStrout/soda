import "importUtil"
ensureImport ["Display"]

button = function(which=0)
	"Return whether the given mouse button (0 = left, 1 = right, 2 = middle) is down."
	return raylib.IsMouseButtonDown(which)
end function

// visible and locked are properties, as in Mini Micro: read them, or assign
// to them.  Raylib can't tell us whether the cursor is locked, so we track
// both states ourselves.  Locking also hides the cursor (raylib's
// DisableCursor does that), so the cursor shows only when visible was not
// set false AND it is not locked.
_visible = true
_locked = false

visible = function
	"Return whether the mouse cursor is shown (false if hidden or locked)."
	return self._visible and not self._locked
end function

locals["visible="] = function(value)
	"Show or hide the mouse cursor."
	self._visible = (value != 0)
	if self._locked then return		// stays hidden while locked, either way
	if self._visible then raylib.ShowCursor else raylib.HideCursor
end function

locked = function
	"Return whether the mouse cursor is locked (hidden, and held in the window)."
	return self._locked
end function

locals["locked="] = function(value)
	"Lock or unlock the mouse cursor; while locked, read movement via key.axis."
	value = (value != 0)
	if value == self._locked then return
	self._locked = value
	if value then
		raylib.DisableCursor
	else
		raylib.EnableCursor		// (which also shows the cursor...)
		if not self._visible then raylib.HideCursor	// (...so re-hide it if needed)
	end if
end function

x = 0
y = 0

// Report the pointer in screen coordinates: the same space the displays draw
// in, bottom-up, with the origin at the bottom-left of Display's screen rect.
// Under a host that insets the screen in a bezel, that is not the window
// origin, and using raw window coordinates would offset every click.
update = function
	"Update mouse.x and mouse.y from the pointer position, in screen coordinates."
	outer.x = raylib.GetMouseX - Display.screenLeft
	outer.y = Display.screenTop + Display.screenHeight - raylib.GetMouseY
end function

