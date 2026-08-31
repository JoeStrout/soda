import "importUtil"
ensureImport ["color"]

globals.displayMode = {
  "off": 0,
  "solidColor": 1,
  "text": 2,
  "pixel": 3,
  "tile": 4,
  "sprite": 5 }

displayMode.str = function(modeNum)
	return displayMode.indexOf(modeNum)
end function

Display = {}
Display.mode = 0
Display.index = null
Display.render = null

// The screen: the region of the window that displays draw into.  Here that is
// the whole window, but a host that frames the screen in a bezel (Mini Micro)
// overrides all four of these with the rect inside it, and translates its
// rendering by screenLeft/screenTop to match.  Displays must size and position
// themselves against these rather than asking raylib for the window size, or
// they will disagree about where the screen is: some are anchored to the bottom
// and some are centered, and a bezel's insets are not symmetrical.
//
// screenLeft/screenTop are in raylib window coordinates (y down from the top);
// width and height are functions here so they track a resized window, but a
// host with a fixed screen size can just as well overwrite them with numbers.
Display.screenLeft = 0
Display.screenTop = 0

Display.screenWidth = function
	return raylib.GetScreenWidth
end function

Display.screenHeight = function
	return raylib.GetScreenHeight
end function

// _installed: an internal list of the displays currently associated
// with each slot.  For slot s, Display._installed[s][0] is the currently
// active display; any others in the Display._installed[s] list are
// associated with that slot, but currently inactive.
Display._installed = [null] * 8

Display.NewDisplayOfMode = function(mode)
	if mode == displayMode.off then return new Display
	if mode == displayMode.solidColor then return SolidColorDisplay.Make
	if mode == displayMode.pixel then return PixelDisplay.Make
	if mode == displayMode.tile then return TileDisplay.Make
	if mode == displayMode.sprite then return SpriteDisplay.Make
	if mode == displayMode.text then return TextDisplay.Make
	print "Not implemented yet: display mode " + mode
	exit
end function

Display.FindOrMakeDisplay = function(slotNum, mode)
	disps = Display._installed[slotNum]
	for d in disps
		if d.mode == mode then return d
	end for
	d = Display.NewDisplayOfMode(mode)
	disps.push d
	d.index = slotNum
	return d
end function

// Set the display mode (i.e. Display subclass) active in the slot
// of this display.  Notice that this does not transmogrify or
// mutate the current display; it just changes what object is
// active in this slot.
Display.setMode = function(newMode)
	if self.index == null or self.index < 0 or self.index > 7 then
		print "Error: Display.setMode called on display with no valid index"
		print stackTrace
		exit
	end if
	d = Display.FindOrMakeDisplay(self.index, newMode)
	disps = Display._installed[self.index]
	for i in disps.indexes
		if refEquals(disps[i], d) then
			disps.remove i
			break
		end if
	end for
	disps.insert 0, d
end function

// Install this display into the given slot (0-7).  Optionally,
// make it the currently active mode.  If asActiveMode is false,
// then the previous mode will be maintained and the newly
// installed display will be immediately visible ONLY if it happens
// to match the previous mode.
Display.install = function(slotNum, asActiveMode=true)
	if slotNum == self.index and not asActiveMode then return // already in this slot
	disps = Display._installed[slotNum]
	curMode = disps[slotNum].mode
	for i in disps.indexes
		if disps[i].mode == self.mode then
			disps[i].remove i
			disps[i].index = null
			break
		end if
	end for
	if asActiveMode or curMode == self.mode then
		disps.insert 0, self
	else
		disps.push self
	end if
	self.index = slotNum
end function

// Get the display currently installed in the given slot.
globals.display = function(index)
	return Display._installed[index][0]
end function

// "Protect" certain map keys as things that user code should
// never assign to on specific display instances; they should
// only be set on the class.
Display._protectedKeys = ["mode"]
_checkGuardedKeys = function
	for slot in range(0, 7)
		for d in Display._installed[slot]
			for k in d.__isa._protectedKeys
				if not d.hasIndex(k) then continue
				msg = "Assigning to display(" + slot + ")." + k + 
				  " has no effect in Mini Micro 2."
				if k == "mode" then msg += "  Use display(" + slot +
				  ").setMode instead."
				display(0).setMode displayMode.text
				display(0).textColor = color.red
				display(0).backColor = "#000000AA"
				display(0).clear
				display(0).print msg
				d.remove k				
			end for
		end for
	end for
end function

// Initialize all our displays (and eight display slots).
Display.Initialize = function
	for slot in range(0,7)
		Display._installed[slot] = []
		for mode in [0, 3]
			Display.FindOrMakeDisplay slot, mode
		end for
	end for
	outer.clear
end function

clear = function
	modes = [0, 0, 0, 2, 5, 3, 0, 1]
	for i in range(0, 7)
		display(i).setMode modes[i]
	end for
	display(3).clear
	display(4).clear
	display(5).clear
	display(7).color = "#000000FF"
	globals.gfx = display(5)
	globals.text = display(3)
end function

globals.clear = @clear

Display.RenderAll = function
	_checkGuardedKeys
	for slot in range(7, 0)
		Display._installed[slot][0].render
	end for
end function

return Display
