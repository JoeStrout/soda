// qa_sound_stopall.ms -- regression test for PERF_TEST_PLAN.md §4.9's
// BUG-03: Sound.StopAll (lib/Sound.ms) iterates `for snd in _playingSounds`
// while each `snd.stop` call removes an element from that same list, so it
// skips every other sound. The skipped sounds' raylib resources are never
// actually stopped (isPlaying stays true), even though the list itself ends
// up empty (StopAll unconditionally resets _playingSounds = [] at the end).
//
// Before the fix: at least one of 4 playing sounds still reports
// isPlaying == true after StopAll. After the fix: all report false.
import "soda"
import "qa"

snds = []
for i in range(1,4)
	s = new Sound
	s.init 0.2, 300 + i*50
	snds.push s
end for

for s in snds
	s.play
end for

for i in range(1, snds.len)
	qa.assert snds[i-1].isPlaying, "snd" + i + " should be playing before StopAll"
end for

Sound.StopAll

for i in range(1, snds.len)
	qa.assert not snds[i-1].isPlaying, "snd" + i + " should not be playing after StopAll (was it skipped by the forward-iteration-while-removing bug?)"
end for

print "ALL PASSED"
exit
