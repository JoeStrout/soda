//
//  SdlAudio.cpp
//	This module forms the interface between SDL and the rest of Soda specifically
//	for audio support.
//
//  Created by Joe Strout on 8/1/21.
//

#include "SdlUtils.h"
#include "SdlGlue.h"
#include "SdlAudio.h"
#include <stdlib.h>
#include "SodaIntrinsics.h"

using namespace MiniScript;

namespace SdlGlue {

// Helper classes
class AudioClip {
public:
	SDL_AudioSpec spec;
	Uint8 *data;
	Uint32 dataLen;
	int frameCount;		// length of the sound, in frames (i.e. units of sampling frequency)
	double length;		// length of the sound, in seconds
	
	AudioClip() : data(NULL), dataLen(0) { SDL_zero(spec); }

	void ReleaseData() {
		SDL_FreeWAV(data);
		data = NULL;
		dataLen = 0;
	}
	
	bool isValid() { return data != NULL && dataLen > 0; }
	
	static AudioClip* Load(const char *path);
};

// SoundStorage: wraps and reference-counts an AudioClip;
// used as the _handle of a Sound object in MiniScript.
class SoundStorage : public RefCountedStorage {
public:
	SoundStorage(AudioClip *clip) : clip(clip) {}
	
	virtual ~SoundStorage() {
		if (clip) clip->ReleaseData();
		delete clip;
	}
	
	AudioClip *clip;
};

class AudioSource {
public:
	SoundStorage *sound;
	float volume;		// 0 (silent) to 1 (full volume)
	float pan;			// -1 (full left) to 0 (balanced) to 1 (full right)
	double speed;		// 1 == normal speed; 0.5 == half speed; etc.
	bool looping;		// if true, repeat sound until stopped

	double time;		// how far (in seconds) we are into the sound
	bool done;			// set to true when we're done playing
	
	AudioSource(SoundStorage *sound, float volume=1, float pan=0, double speed=1)
	: sound(sound), volume(volume), pan(pan), time(0), speed(speed), done(false) {
		if (sound != NULL) sound->retain();
	}
	
	~AudioSource() { if (sound != NULL) sound->release(); }
	
	void SampleToBuffer(float *buffer, int frameCount);
};


// Private data
static SDL_AudioDeviceID deviceId = 0;
static SDL_AudioSpec audioSpec;
SimpleVector<AudioSource*> playingSounds;

// Forward declarations
static void AudioCallback(void* userdata, Uint8* buffer, int bufferSize);

//--------------------------------------------------------------------------------
// Public method implementations
//--------------------------------------------------------------------------------

void SetupAudio() {
	
	SDL_AudioSpec desiredSpec;
	SDL_zero(desiredSpec);
	desiredSpec.freq = 22050;
	desiredSpec.samples = 1024;
	desiredSpec.format = AUDIO_F32SYS;
	desiredSpec.channels = 2;
	desiredSpec.callback = AudioCallback;
	
	deviceId = SDL_OpenAudioDevice(NULL, 0, &desiredSpec, &audioSpec,
	   SDL_AUDIO_ALLOW_SAMPLES_CHANGE | SDL_AUDIO_ALLOW_CHANNELS_CHANGE | SDL_AUDIO_ALLOW_FREQUENCY_CHANGE);
	if (deviceId == 0) {
		printf("Unable to open audio output; error = %s\n", SDL_GetError());
	} else {
		//printf("Opened audio output with device ID %d\n", deviceId);
		//printf("freq: %d  channels: %d  samples: %d\n", audioSpec.freq, audioSpec.channels, audioSpec.samples);
		
		SDL_PauseAudioDevice(deviceId, 0);
	}
}

void ShutdownAudio() {
	SDL_CloseAudioDevice(deviceId);
}


Value LoadSound(MiniScript::String path) {
	AudioClip* clip = AudioClip::Load(path.c_str());
	if (clip == NULL) return Value::null;
	
	ValueDict inst;
	inst.SetValue(Value::magicIsA, soundClass);
	inst.SetValue(magicHandle, Value::NewHandle(new SoundStorage(clip)));
	inst.SetValue("duration", clip->length);
	
	return inst;
}

void PlaySound(MiniScript::Value sound, double volume, double pan, double speed) {
	if (sound.IsNull() || sound.type != ValueType::Map) return;
	MiniScript::Value clipH = sound.Lookup(magicHandle);
	SoundStorage *clipStorage = NULL;
	if (clipH.type == ValueType::Handle) {
		// ToDo: how do we be sure the data is specifically a SoundStorage?
		// Do we need to enable RTTI, or use some common base class?
		clipStorage = ((SoundStorage*)(clipH.data.ref));
	}
	if (clipStorage == NULL || clipStorage->clip == NULL) return;
	
	AudioSource *src = new AudioSource(clipStorage, volume, pan, speed);
	src->looping = sound.Lookup("loop").BoolValue() > 0;
	playingSounds.push_back(src);
}

void StopSound(MiniScript::Value sound) {
	// Stop the oldest sound we find using the same clip storage as the given sound.
	if (sound.IsNull() || sound.type != ValueType::Map) return;
	MiniScript::Value clipH = sound.Lookup(magicHandle);
	SoundStorage *clipStorage = NULL;
	if (clipH.type == ValueType::Handle) {
		// ToDo: how do we be sure the data is specifically a SoundStorage?
		// Do we need to enable RTTI, or use some common base class?
		clipStorage = ((SoundStorage*)(clipH.data.ref));
	}
	if (clipStorage == NULL || clipStorage->clip == NULL) return;
	for (long i=playingSounds.size() - 1; i >= 0; i--) {
		if (playingSounds[i]->sound == clipStorage) {
			delete playingSounds[i];
			playingSounds.deleteIdx(i);
			return;
		}
	}
}

void StopAllSounds() {
	// Stop all playing sounds.
	VecReverseIterate(i, playingSounds) {
		delete playingSounds[i];
	}
	playingSounds.deleteAll();
}

//--------------------------------------------------------------------------------
// Private method implementations
//--------------------------------------------------------------------------------

static void AudioCallback(void* userdata, Uint8* buffer, int bufferSize) {
	// Here we mix and generate some samples for the buffer!
	SDL_memset(buffer, 0, bufferSize);
	float *samples = (float*)buffer;
	int frameCount = bufferSize / (sizeof(float) * audioSpec.channels);
	
	// Sample our currently playing audio sources.
	VecReverseIterate(i, playingSounds) {
		playingSounds[i]->SampleToBuffer(samples, frameCount);
		if (playingSounds[i]->done) {
			delete playingSounds[i];
			playingSounds.deleteIdx(i);
		}
	}
	
	/*
	// Generate roughly a middle-C tone (261.626 Hz) square wave.
	double toneFreq = 261.625549;		// cycles/sec
	int framesPerCycle = audioSpec.freq / toneFreq;
	int halfCycle = framesPerCycle / 2;
	int frameInThisCycle = 0;
	float *outp = samples;
	for (int i=0; i<frameCount; i++) {
		float audioLevel = (frameInThisCycle > halfCycle ? 0.5 : -0.5);
		for (int channel=0; channel < audioSpec.channels; channel++) {
			*outp++ = audioLevel;
		}
		frameInThisCycle++;
		if (frameInThisCycle > framesPerCycle) frameInThisCycle = 0;
	}
	 
	*/
}

AudioClip* AudioClip::Load(const char *path) {
	AudioClip* result = new AudioClip();
	if (SDL_LoadWAV(path, &result->spec, &result->data, &result->dataLen) == NULL) {
		printf("Unable to load WAV file %s: %s\n", path, SDL_GetError());
		delete result;
		return NULL;
	}
	//printf("Loaded WAV with freq: %d  channels: %d  samples: %d  format: %d  bytes: %d\n",
	//	   result->spec.freq, result->spec.channels, result->spec.samples, result->spec.format, result->dataLen);
	// Now let's convert that to our mix format.
	// For frequency, we'll use whichever is less of the original and our mix frequency.
	double freq = (result->spec.freq < audioSpec.freq ? result->spec.freq : audioSpec.freq);
	SDL_AudioCVT cvt;
	SDL_BuildAudioCVT(&cvt, result->spec.format, result->spec.channels, result->spec.freq,
					  audioSpec.format, audioSpec.channels, freq);
	if (cvt.needed) {
		cvt.len = result->dataLen;
		cvt.buf = (Uint8*)SDL_malloc(cvt.len * cvt.len_mult);
		SDL_memcpy(cvt.buf, result->data, result->dataLen);
		SDL_ConvertAudio(&cvt);
		//printf("After conversion, we have %d bytes in format %d with %d channels, freq %lf\n", cvt.len_cvt, cvt.dst_format, audioSpec.channels, freq);
		SDL_FreeWAV(result->data);
		result->data = cvt.buf;
		result->dataLen = cvt.len_cvt;
		result->spec.format = cvt.dst_format;
		result->spec.channels = audioSpec.channels;
		result->spec.freq = freq;
	}
	int bytesPerFrame = sizeof(float) * result->spec.channels;
	result->frameCount = result->dataLen / bytesPerFrame;
	result->length = (double)result->frameCount / result->spec.freq;
	//printf("Sound length: %lf seconds, or %d frames\n", result->length, result->frameCount);
	return result;
}


void AudioSource::SampleToBuffer(float *buffer, int frameCount) {
	if (sound == NULL) return;
	AudioClip *clip = sound->clip;
	if (clip == NULL || time > clip->length) return;
	double dt = speed / audioSpec.freq;
	float *clipSamples = (float*)clip->data;
	
	for (int i=0; i < frameCount; i++) {
		double frameIndex = clip->spec.freq * time;
		time += dt;
		long frameIndexBase = (long)frameIndex;
		double frac = frameIndex - frameIndexBase;
		if (frameIndexBase >= clip->frameCount) {
			if (looping) {
				time -= clip->length;
				frameIndexBase -= clip->frameCount;
			} else {
				done = true;
				break;
			}
		}
		for (int channel=0; channel < audioSpec.channels; channel++) {
			// first, sample our data at time t (which in general will mean interpolating
			// between two samples at nearby times).
			float sampleValue = 0;
			if (frac < 0.001) {
				// Happy day!  We've hit an even sample, and can skip any interpolation.
				sampleValue = clipSamples[frameIndexBase * clip->spec.channels + channel];
			} else {
				float sample0 = clipSamples[frameIndexBase * clip->spec.channels + channel];
				float sample1 = clipSamples[(frameIndexBase+1) * clip->spec.channels + channel];
				sampleValue = sample0 * (1-frac) + sample1 * frac;
			}
			// Then apply volume, pan, etc.
			sampleValue *= volume;
			if (audioSpec.channels > 1 && pan != 0) {
				// Um.  The following math makes great sense and gives us good stereo pan.
				// But it also cuts the volume in half...
				if (channel == 0) sampleValue *= 0.5 - pan*0.5;
				else sampleValue *= 0.5 + pan*0.5;
			} else {
				// ...So if we're not using pan, just cut the volume in half.  This makes
				// mixing sounds without clipping easier anyway.
				sampleValue *= 0.5;
			}
			*buffer++ += sampleValue;
		}
	}
}

}	// end of: namespace SdlGlue

