// Gamepad diagnostic: talks directly to raylib, bypassing lib/key.ms, to work
// out whether a problem is in Soda's layer or underneath it.
// Run with:  ./soda tests/gamepadDiag.ms      (Esc or Q to quit)

import "soda"
clear

rl = raylib

print "--- constants (any 'null' here is the bug) ---"
print "GAMEPAD_BUTTON_RIGHT_FACE_DOWN = " + rl.GAMEPAD_BUTTON_RIGHT_FACE_DOWN
print "GAMEPAD_BUTTON_LEFT_FACE_UP    = " + rl.GAMEPAD_BUTTON_LEFT_FACE_UP
print "GAMEPAD_AXIS_LEFT_X            = " + rl.GAMEPAD_AXIS_LEFT_X
print "GAMEPAD_AXIS_LEFT_Y            = " + rl.GAMEPAD_AXIS_LEFT_Y

print
print "--- gamepad slots ---"
for i in range(0, 3)
	avail = rl.IsGamepadAvailable(i)
	line = "  slot " + i + ": available = " + avail
	if avail then
		line = line + ", name = " + rl.GetGamepadName(i) +
		  ", axisCount = " + rl.GetGamepadAxisCount(i)
	end if
	print line
end for

print
print "Now press buttons / move sticks.  Reporting raw raylib state on change."
print "(Esc or Q to quit.)"

lastReport = ""
while true
	yield
	if rl.IsKeyPressed(rl.KEY_ESCAPE) or rl.IsKeyPressed(rl.KEY_Q) then break

	report = []
	// GetGamepadButtonPressed reports the most recent button, independent of
	// any per-slot loop, so it tells us if raylib sees the pad at all.
	lastBtn = rl.GetGamepadButtonPressed
	if lastBtn > 0 then report.push "GetGamepadButtonPressed=" + lastBtn

	for i in range(0, 3)
		if not rl.IsGamepadAvailable(i) then continue
		for b in range(0, 17)
			if rl.IsGamepadButtonDown(i, b) then report.push "pad" + i + ".button" + b
		end for
		for a in range(0, 5)
			v = rl.GetGamepadAxisMovement(i, a)
			if abs(v) > 0.2 then report.push "pad" + i + ".axis" + a + "=" + round(v, 2)
		end for
	end for

	line = report.join(" ")
	if line != lastReport then
		if line != "" then print line
		lastReport = line
	end if
end while

print "done"
exit
