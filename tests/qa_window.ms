// qa_window.ms -- window property round-trips, fullScreen toggle logic (with the
// raylib toggle stubbed so no real full-screen switch happens), double import.
import "soda"
import "qa"
rl = raylib

w0 = window.width; h0 = window.height
window.width = w0 + 40
qa.assertEqual window.width, w0 + 40, "width round-trip"
qa.assertEqual window.height, h0, "height unchanged by width="
window.height = h0 + 30
qa.assertEqual window.height, h0 + 30, "height round-trip"
qa.assertEqual window.width, w0 + 40, "width unchanged by height="
window.width = w0; window.height = h0
qa.assertEqual window.width, w0, "width restored"
print "  OK: width/height"

window.title = "qa window title"
qa.assertEqual window.title, "qa window title", "title round-trip"
window.title = "raylib-miniscript"
print "  OK: title"

// fullScreen: stub the raylib state so nothing really toggles
state = {"fs": 0, "toggles": 0}
realIs = @rl.IsWindowFullscreen
realToggle = @rl.ToggleFullscreen
rl.IsWindowFullscreen = function(); return state.fs; end function
rl.ToggleFullscreen = function(); state.fs = 1 - state.fs; state.toggles = state.toggles + 1; end function
window.fullScreen = 1
qa.assertEqual state.fs, 1, "fullScreen = 1 enters"
window.fullScreen = 1
qa.assertEqual state.fs, 1, "fullScreen = 1 twice stays full"
qa.assertEqual state.toggles, 1, "no second toggle"
window.fullScreen = 0
qa.assertEqual state.fs, 0, "fullScreen = 0 leaves"
window.fullScreen = 0
qa.assertEqual state.toggles, 2, "fullScreen = 0 twice: no extra toggle"
window.fullScreen = true
qa.assertEqual state.fs, 1, "fullScreen = true"
rl.IsWindowFullscreen = @realIs
rl.ToggleFullscreen = @realToggle
print "  OK: fullScreen"

// second import must not break `version`
v1 = version.hostName
import "soda"
qa.assertEqual version.hostName, v1, "version.hostName after re-import"
qa.assertEqual version.hostName, "Soda", "hostName is Soda"
print "  OK: version shadow"
print "ALL PASSED"
exit
