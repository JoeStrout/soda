// Soda class representing a Sound (sound effect or music stream).
// Note that we currently support only loaded sounds, not synthesized ones.

rl = raylib

_playingSounds = []

Sound = {}
Sound._sound = null  // raylib Sound
Sound._music = null  // raylib MusicStream
Sound.loop = false
Sound.isPlaying = false

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
