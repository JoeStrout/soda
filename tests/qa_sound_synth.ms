// The synthesis loop inlines _lookupLUT; check it matches a reference
// implementation (the original, un-inlined loop) across waveform/envelope/freq forms.
import "qa"
import "soda"

lut = function(samples, t)
	if samples isa number then return samples
	if samples.len == 1 or t <= 0 then return samples[0]
	if t >= 1 then return samples[-1]
	if samples.len == 2 then return samples[0] + (samples[1] - samples[0]) * t
	iw = 1 / (samples.len - 1)
	i = floor(t / iw)
	f = t / iw - i
	return samples[i] + (samples[i+1] - samples[i]) * f
end function
waveLen = function(freq, fracDone, duration)
	f = lut(freq, fracDone)
	if f <= 0 then return duration
	return 1 / f
end function
reference = function(snd, rate, level)
	dur = snd.duration
	n = round(rate * dur)
	out = [0] * n
	ws = 0; wl = waveLen(snd.freq, 0, dur); fos = dur - snd.fadeOut
	for i in range(0, n-1)
		t = i / rate; fd = t / dur
		wt = (t - ws) / wl
		if wt >= 1 then
			ws += wl; wl = waveLen(snd.freq, fd, dur); wt -= 1
		end if
		v = lut(snd.waveform, wt) * lut(snd.envelope, fd) * level
		if t < snd.fadeIn then v *= t / snd.fadeIn
		if t > fos then v *= (dur - t) / snd.fadeOut
		out[i] = v
	end for
	return out
end function

waves = [Sound.sineWave, Sound.squareWave, Sound.triangleWave, Sound.sawtoothWave, [0.5], 0.3, Sound.noiseWave(7, 50)]
envs = [1, [1, 0], [1, 1, 0], [0, 1, 0.5, 0.2, 0], [0.7], 0.5]
freqs = [440, [200, 800], noteFreq(60), [0, 300, 100], 0]
bad = 0; count = 0
for w in waves
	for e in envs
		for f in freqs
			s = new Sound
			s.init 0.15, f, e, w
			got = s._buildSamples
			exp = reference(s, s.sampleRate, 1)
			qa.assert got.len == exp.len, "length"
			for i in range(0, got.len - 1)
				if abs(got[i] - exp[i]) > 1e-9 then bad = bad + 1
			end for
			count = count + 1
		end for
	end for
end for
qa.assert bad == 0, bad + " samples differ from reference over " + count + " configs"

// mixes
a = new Sound; a.init 0.2, 330, [1, 0]
b = new Sound; b.init 0.3, 550, 1, Sound.squareWave
a.mix b, 0.5
got = a._buildSamples
qa.assert got.len == round(a.sampleRate * 0.3), "mixed length"
print "ALL PASSED"
exit
