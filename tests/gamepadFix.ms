// Test whether supplying a macOS gamepad mapping wakes up an unmapped pad.
//
// GLFW only reports gamepad state for devices it has an SDL-style mapping for,
// and it ignores mappings whose "platform:" field doesn't match the current OS.
// The "USB,2-axis 8-button gamepad" (vendor 0x0583, product 0x2060) has an
// entry in GLFW's built-in table, but tagged platform:Windows only.
//
// Reference: https://github.com/JoeStrout/raylib-miniscript/issues/17

import "soda"
clear

rl = raylib

// GLFW discards a mapping outright if it references ANY element the device
// doesn't have (findValidMapping in glfw/src/input.c).  Per its HID descriptor
// this pad has exactly 2 axes (a0, a1) and 8 buttons (b0-b7) and no hat, so the
// stock "Retro Controller" entry -- which reaches for b8 and b9 -- is rejected.
// This version stays inside what the hardware actually reports.
//
// The GUID is built by GLFW from vendor 0x0583, product 0x2060, version 0x0100
// as byte pairs, low byte first (cocoa_joystick.m:175).
//
// The D-pad on this pad IS the two axes, which is why Mini Micro shows it as
// JoyAxis1/JoyAxis2; mapping it both ways gives us stick and dpad readings.
mappings = "03000000830500006020000000010000,USB 2-axis 8-button gamepad," +
  "leftx:a0,lefty:a1,dpleft:-a0,dpright:+a0,dpup:-a1,dpdown:+a1," +
  "a:b0,b:b1,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5," +
  "back:b6,start:b7,platform:Mac OS X,"

ok = rl.SetGamepadMappings(mappings)
print "SetGamepadMappings returned: " + ok + "  (1 just means 'parsed', not 'accepted')"
print

for i in range(0, 3)
	if rl.IsGamepadAvailable(i) then print "slot " + i + ": " + rl.GetGamepadName(i)
end for

print
print "Press buttons / move the D-pad.  Esc or Q to quit."

lastReport = ""
while true
	yield
	if rl.IsKeyPressed(rl.KEY_ESCAPE) or rl.IsKeyPressed(rl.KEY_Q) then break

	report = []
	for i in range(0, 3)
		if not rl.IsGamepadAvailable(i) then continue
		for b in range(0, 17)
			if rl.IsGamepadButtonDown(i, b) then report.push "button" + b
		end for
		for a in range(0, 3)
			v = rl.GetGamepadAxisMovement(i, a)
			if abs(v) > 0.2 then report.push "axis" + a + "=" + round(v, 2)
		end for
	end for

	// Also show what Soda's own layer makes of it.
	h = key.axis("Horizontal")
	v = key.axis("Vertical")
	if h or v then report.push "[soda H=" + h + " V=" + v + "]"

	line = report.join(" ")
	if line != lastReport then
		if line != "" then print line
		lastReport = line
	end if
end while

print "done"
exit
