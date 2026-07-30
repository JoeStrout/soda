// This is the main include file for "Soda", i.e., all the 
// classes and modules which mimic the Mini Micro API.
// In your main program, include this, just once.
// It should automatically set everything up for you.
// Then, call soda.update from the main loop (at the 
// point where you want it to render).

// Identify ourselves in the `version` map, so that code shared between Soda
// and other hosts built on this library (Mini Micro, notably) can tell them
// apart with version.hostName.  The built-in map is frozen, so we shadow it
// with a global carrying the same keys -- unless the host application already
// did exactly that, in which case its identity wins.
if not globals.hasIndex("version") then
	globals.version = version + {"hostName": "Soda"}
end if

raylib.SetTraceLogLevel raylib.LOG_WARNING
if not raylib.IsWindowReady then
	raylib.InitWindow 960, 640  // create the window
end if

import "importUtil"

ensureImport ["color", "Image", "Sound", "Display", "SolidColorDisplay", "PixelDisplay",
  "SpriteDisplay", "TileDisplay", "TextDisplay", "mouse", "key"]

Display.Initialize

// window: query and control the application window.
// Mini Micro exposes window.width/height/fullScreen as assignable properties,
// but MiniScript 2 has no assignment hook, so the setters are methods here.
globals.window = {}
window.title = "raylib-miniscript"

window.width = function
	return raylib.GetScreenWidth
end function

window.height = function
	return raylib.GetScreenHeight
end function

window.fullScreen = function
	return raylib.IsWindowFullscreen
end function

window.setSize = function(w=960, h=640)
	raylib.SetWindowSize w, h
end function

window.setTitle = function(title="")
	raylib.SetWindowTitle title
	self.title = title
end function

// Raylib only offers a toggle, so compare with the current state first.
window.setFullScreen = function(full=true)
	if (full != 0) == (raylib.IsWindowFullscreen != 0) then return
	raylib.ToggleFullscreen
end function

// updateCallbacks: a list of methods to call on every frame.  This includes standard
// Soda update methods, but you may add your own methods to ensure they are invoked
// at update time as well.
updateCallbacks = [
	@mouse.update,
	@key.update,
	@Sound.UpdateAll,
]

update = function(beginEndRaylibDrawing = true)
	if beginEndRaylibDrawing then raylib.BeginDrawing
	Display.RenderAll
	if beginEndRaylibDrawing then raylib.EndDrawing
	for f in updateCallbacks
		f
	end for
end function

// Override (actually, shadow) the `yield` intrinsic to do our standard
// update, so that a tight yield loop does not lock up the app.
globals.yield = function
	outer.update
	intrinsics.yield
end function

// And similar for `wait`.
globals.wait = function(duration=1)
	endTime = time + duration
	while time < endTime
		intrinsics.yield
		outer.update
	end while
end function
