// Soda class representing a Sound (sound effect, music stream, or a
// sound synthesized at runtime via Sound.init).

rl = raylib

_playingSounds = []

Sound = {}
Sound._sound = null  // raylib Sound
Sound._music = null  // raylib MusicStream
Sound.loop = false
Sound.isPlaying = false

// Synthesis parameters (see Sound.init).  A duration of null means this
// is not a synthesized sound.
Sound.duration = null
Sound.freq = 440
Sound.envelope = 1
Sound.waveform = null
Sound.fadeIn = 0.01
Sound.fadeOut = 0.01
Sound.mixes = null	// list of [sound, level] pairs (see Sound.mix)

// Sound.sampleRate: sample rate (in Hz) used for synthesized sounds.
// This matches Mini Micro; raylib resamples to the device rate as needed.
Sound.sampleRate = 10464

// Wrap an existing raylib Sound or MusicStream map as a Sound instance.
Sound.FromRaylibMusicStream = function(rMusicStream)
	result = new Sound
	result._music = rMusicStream
	return result
end function

Sound.FromRaylibSound = function(rSound)
	result = new Sound
	result._sound = rSound
	return result
end function

Sound.play = function(volume=1, pan=0, speed=1)
	if not self._ensureSound then return
	if self._music then
		rl.SetMusicVolume self._music, volume
		rl.SetMusicPan self._music, (pan + 1) / 2
		rl.SetMusicPitch self._music, speed
		self._music.looping = self.loop
		rl.PlayMusicStream self._music
	else
		rl.SetSoundVolume self._sound, volume
		rl.SetSoundPan self._sound, (pan + 1) / 2
		rl.SetSoundPitch self._sound, speed
		rl.PlaySound self._sound
	end if
	if not self.isPlaying then
		self.isPlaying = true
		_playingSounds.push self
	end if
end function

Sound.adjust = function(volume=1, pan=0, speed=1)
	if self._sound == null and self._music == null then return
	if self._music then
		rl.SetMusicVolume self._music, volume
		rl.SetMusicPan self._music, (pan + 1) / 2
		rl.SetMusicPitch self._music, speed
		self._music.looping = self.loop
	else
		rl.SetSoundVolume self._sound, volume
		rl.SetSoundPan self._sound, (pan + 1) / 2
		rl.SetSoundPitch self._sound, speed
	end if
end function


Sound.stop = function
	if self._music == null and self._sound == null then return
	if self._music then
		rl.StopMusicStream self._music
	else
		rl.StopSound self._sound
	end if
	self.isPlaying = false
	for i in range(_playingSounds.len-1, 0, -1)
		if refEquals(_playingSounds[i], self) then _playingSounds.remove i
	end for
end function

Sound.update = function
	if not self.isPlaying then return
	if self._music then
		rl.UpdateMusicStream self._music
	else if self.loop and not rl.IsSoundPlaying(self._sound) then
		rl.PlaySound self._sound
	end if
end function

Sound.UpdateAll = function
	for snd in _playingSounds
		snd.update
	end for
end function

Sound.unload = function
	if self._music then rl.UnloadMusicStream(self._music)
	self._music = null
	if self._sound then rl.UnloadSound(self._sound)
	self._sound = null
end function

Sound.StopAll = function
	for snd in _playingSounds
		snd.stop
	end for
	outer._playingSounds = []
end function
Sound.stopAll = @Sound.StopAll // (for backwards compatibility)

//----------------------------------------------------------------------
// Sound synthesis.  This closely follows Mini Micro's SoundSupport.cs,
// so that a sound built here matches the same sound built there.

// Built-in waveforms, for use with the `waveform` parameter of Sound.init.
// Each represents one cycle of the wave, as values from -1 to 1.

// Sound.sineWave: a smooth, pure tone.
Sound.sineWave = []
for i in range(0, 127, 1)
	Sound.sineWave.push sin(2 * pi * i / 128)
end for

// Sound.squareWave: a buzzy, old-school "chip tone" sound.
Sound.squareWave = [1]*64 + [-1]*64

// Sound.triangleWave: a clean sound, almost like a sine wave.
Sound.triangleWave = [1, -1, 1]

// Sound.sawtoothWave: a slightly buzzy, retro tone.
Sound.sawtoothWave = [1, -1]

// Sound.noiseWave: returns a list of random values, approximating white
// noise.  Uses its own generator, so it does not disturb the sequence of
// numbers produced by `rnd`.
Sound.noiseWave = function(seed=42, samples=509)
	result = []
	state = floor(abs(seed)) % 4294967296
	for i in range(0, samples-1, 1)
		// Numerical Recipes' "quick and dirty" 32-bit LCG.
		state = (state * 1664525 + 1013904223) % 4294967296
		result.push state / 2147483648 - 1
	end for
	return result
end function

// Look up a value in a linear interpolating look-up table.  Samples are
// assumed to be uniformly spaced between t=0 and t=1.  A plain number
// (rather than a list) is treated as a constant.
_lookupLUT = function(samples, t)
	if samples isa number then return samples
	if samples.len == 1 or t <= 0 then return samples[0]
	if t >= 1 then return samples[-1]
	if samples.len == 2 then return samples[0] + (samples[1] - samples[0]) * t
	intervalWidth = 1 / (samples.len - 1)
	i = floor(t / intervalWidth)
	f = t / intervalWidth - i
	return samples[i] + (samples[i+1] - samples[i]) * f
end function

// noteFreq: return the frequency (in Hz) of the given MIDI note number.
// Middle C is note 60; A above middle C (note 69) is 440 Hz.
// See https://newt.phys.unsw.edu.au/jw/notes.html
globals.noteFreq = function(note=60)
	return 2 ^ ((note - 69) / 12) * 440
end function

// Sound.init: synthesize a sound from various parameters, including look-up
// tables that represent one cycle of the waveform and the volume envelope.
// Call this on a new Sound object, or to reset a previous one.
//	duration (number): length of the sound, in seconds
//	freq (number or list): repeats of the waveform per second, over the duration
//	envelope (number or list): volume (0 to 1) over the duration of the sound
//	waveform (list): wave value (-1 to 1) over one cycle
// Example:
//	pew = new Sound
//	pew.init 0.3, [8000, 100], [1, 0]
//	pew.play
// Example:
//	hitSnd = new Sound
//	hitSnd.init 1, 100, [1, 0], Sound.noiseWave
//	hitSnd.play
// Note that the samples are not actually generated until the sound is first
// played.  If you change duration, freq, envelope, waveform, fadeIn, fadeOut,
// or sampleRate afterwards, call `unload` to force it to be regenerated.
Sound.init = function(duration=1, freq=440, envelope=null, waveform=null)
	if self.isPlaying then self.stop
	self.unload
	self.duration = duration
	self.freq = freq
	if envelope == null then envelope = 1
	self.envelope = envelope
	if waveform == null then waveform = Sound.sawtoothWave
	self.waveform = waveform
	self.fadeIn = 0.01
	self.fadeOut = 0.01
	self.mixes = null
	return self
end function

// Sound.mix: mix another synthesized sound into this one, producing a more
// complex sound.  Mixing the same sound in twice just updates its level.
//	sound (Sound): other sound (already prepared with init) to mix in
//	level (number): volume of the mixed-in sound, relative to this one
// Example:
//	daDing = new Sound
//	daDing.init 0.5, noteFreq(72), [1, 1, 0]
//	dd2 = new Sound
//	dd2.init 0.5, noteFreq(84), [0]*40 + range(1, 0, -0.01)
//	daDing.mix dd2
//	daDing.play
Sound.mix = function(sound, level=1)
	if self.isPlaying then self.stop
	self.unload
	if self.mixes == null then self.mixes = []
	for m in self.mixes
		if refEquals(m[0], sound) then
			m[1] = level
			return self
		end if
	end for
	self.mixes.push [sound, level]
	return self
end function

// Collect this sound and everything mixed into it (recursively) as a list of
// {sound, level} maps.  Levels multiply down the chain, as in Mini Micro.
Sound._gatherDefs = function(defs, level=1)
	if defs.len > 16 then return	// enough is enough already
	defs.push {"sound": self, "level": level}
	if self.mixes == null then return
	for m in self.mixes
		m[0]._gatherDefs defs, level * m[1]
	end for
end function

// Compute the raw samples (-1 to 1) of this sound, including anything
// mixed into it.  Levels are normalized so the total stays within range.
Sound._buildSamples = function
	defs = []
	self._gatherDefs defs
	rate = self.sampleRate
	maxDur = 0
	totalLevel = 0
	for d in defs
		dur = d.sound.duration
		if dur != null and dur > maxDur then maxDur = dur
		totalLevel += d.level
	end for
	sampleCount = round(rate * maxDur)
	if sampleCount < 1 or totalLevel <= 0 then return []

	result = [0] * sampleCount
	for d in defs
		d.sound._addSamples result, rate, d.level / totalLevel
	end for
	return result
end function

// Add this sound's own samples (ignoring its mixes) into the given buffer,
// scaled by the given level.
Sound._addSamples = function(result, rate, level)
	dur = self.duration
	if dur == null or dur <= 0 then return
	sampleCount = round(rate * dur)
	if sampleCount > result.len then sampleCount = result.len
	if sampleCount < 1 then return
	waveform = self.waveform
	envelope = self.envelope
	freq = self.freq
	fadeIn = self.fadeIn
	fadeOut = self.fadeOut
	fadeOutStart = dur - fadeOut

	waveStart = 0
	waveLength = _waveLength(freq, 0, dur)
	for i in range(0, sampleCount-1, 1)
		t = i / rate
		fracDone = t / dur
		wavet = (t - waveStart) / waveLength
		if wavet >= 1 then
			// Start a new wave!
			waveStart += waveLength
			waveLength = _waveLength(freq, fracDone, dur)
			wavet -= 1
		end if
		v = _lookupLUT(waveform, wavet) * _lookupLUT(envelope, fracDone) * level
		if t < fadeIn then v *= t / fadeIn
		if t > fadeOutStart then v *= (dur - t) / fadeOut
		result[i] = result[i] + v
	end for
end function

// Duration (in seconds) of one cycle of the wave, at the given point in time.
_waveLength = function(freq, fracDone, duration)
	f = _lookupLUT(freq, fracDone)
	if f <= 0 then return duration
	return 1 / f
end function

// Generate the raylib sound for a synthesized Sound.
Sound._synthesize = function
	samples = self._buildSamples
	if not samples then return null
	wave = rl.CreateWave(samples.len, self.sampleRate, 32, 1, samples)
	if wave == null then return null
	snd = rl.LoadSoundFromWave(wave)
	rl.UnloadWave wave
	if snd == null or not rl.IsSoundValid(snd) then return null
	return snd
end function

// Make sure we have something to play, synthesizing it if needed.
// Returns whether we now have a sound (or music stream) in hand.
Sound._ensureSound = function
	if self._sound == null and self._music == null then
		self._sound = self._synthesize
	end if
	return self._sound != null or self._music != null
end function

file.loadSound = function(path, asMusicStream=null)
	if asMusicStream == null then
		asMusicStream = (path[-4] == ".ogg" or path[-4] == ".mp3")
	end if
	if asMusicStream then
		result = Sound.FromRaylibMusicStream(rl.LoadMusicStream(path))
	else
		result = Sound.FromRaylibSound(rl.LoadSound(path))
	end if
	return result
end function

return Sound
