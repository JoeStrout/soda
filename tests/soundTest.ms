// Test runtime sound synthesis (Sound.init and the built-in waveforms).

import "soda"

sounds = []

addSound = function(name, snd)
	sounds.push {"name": name, "sound": snd}
end function

pew = new Sound
pew.init 0.3, [8000, 100], [1, 0]
addSound "pew (sawtooth sweep)", pew

hit = new Sound
hit.init 1, 100, [1, 0], Sound.noiseWave
addSound "hit (noise)", hit

for wf in [["sine", Sound.sineWave], ["square", Sound.squareWave],
           ["triangle", Sound.triangleWave], ["sawtooth", Sound.sawtoothWave]]
	snd = new Sound
	snd.init 0.5, noteFreq(69), [0, 1, 1, 0], wf[1]
	addSound wf[0] + " wave, A440", snd
end for

// A little arpeggio, using noteFreq and a stepped frequency table.
arp = new Sound
arp.init 0.8, [noteFreq(60), noteFreq(64), noteFreq(67), noteFreq(72)],
   [1, 1, 0], Sound.squareWave
addSound "arpeggio (stepped freq)", arp

// Two tones mixed together, with the second one delayed by its envelope.
daDing = new Sound
daDing.init 0.5, noteFreq(72), [1, 1, 0]
dd2 = new Sound
dd2.init 0.5, noteFreq(84), [0]*40 + range(1, 0, -0.01)
daDing.mix dd2
addSound "da-ding (mixed)", daDing

text.clear
print "Sound synthesis test."
print "Press 1-" + sounds.len + " to play a sound; Esc to quit."
print
for i in sounds.indexes
	print "  " + (i+1) + ". " + sounds[i].name
end for

while true
	yield
	if not key.available then continue
	k = key.get
	if k == char(27) then break
	idx = k.val - 1
	if idx >= 0 and idx < sounds.len then
		print "Playing: " + sounds[idx].name
		sounds[idx].sound.play
	end if
end while

Sound.stopAll
