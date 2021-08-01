//
//  SdlAudio.cpp
//	This module forms the interface between SDL and the rest of Soda specifically
//	for audio support.
//
//  Created by Joe Strout on 8/1/21.
//

#include "SdlAudio.h"
#include <SDL2/SDL.h>
#include <stdlib.h>

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
	
	static AudioClip Load(const char *path);
};

class AudioSource {
public:
	AudioClip *clip;
	float volume;		// 0 (silent) to 1 (full volume)
	float pan;			// -1 (full left) to 0 (balanced) to 1 (full right)
	double speed;		// 1 == normal speed; 0.5 == half speed; etc.
	double time;		// how far (in seconds) we are into the sound
	
	AudioSource(AudioClip *clip, float volume=1, float pan=0) : clip(clip), volume(volume), pan(pan), time(0), speed(1) {}
	
	void SampleToBuffer(float *buffer, int frameCount);
};

// Private data
static SDL_AudioDeviceID deviceId = 0;
static SDL_AudioSpec audioSpec;
static AudioClip testClip;
static AudioSource testSource(NULL);
static double sampledTime = 0;

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
		printf("Opened audio output with device ID %d\n", deviceId);
		printf("freq: %d  channels: %d  samples: %d\n", audioSpec.freq, audioSpec.channels, audioSpec.samples);
		
		testClip = AudioClip::Load("sounds/pickup.WAV");
		testSource = AudioSource(&testClip);
		testSource.speed = 0.25f;
		SDL_PauseAudioDevice(deviceId, 0);
	}
}

void ShutdownAudio() {
	SDL_CloseAudioDevice(deviceId);
}

//--------------------------------------------------------------------------------
// Private method implementations
//--------------------------------------------------------------------------------

bool logged = false;

static void AudioCallback(void* userdata, Uint8* buffer, int bufferSize) {
	// Here we mix and generate some samples for the buffer!
	if (!logged) {
		printf("Got callback with bufferSize %d\n", bufferSize);
		logged = true;
	}
	SDL_memset(buffer, 0, bufferSize);
	float *samples = (float*)buffer;
	int sampleCount = bufferSize / sizeof(float);
	int frameCount = bufferSize / (sizeof(float) * audioSpec.channels);
	
	// Sample our currently playing audio sources.
	testSource.SampleToBuffer(samples, frameCount);

/*
 float *dstSample = samples;
	int startFrame = sampledTime * audioSpec.freq;
	float *srcSample = ((float*)testClip.data) + startFrame * audioSpec.channels;
	float *srcSampleEnd = (float*)(testClip.data + testClip.dataLen);
	for (int i=0; i<sampleCount; i++) {
		if (srcSample >= srcSampleEnd) *dstSample++ = 0;
		else *dstSample++ = *srcSample++;
	}
*/
	sampledTime += (double)frameCount / audioSpec.freq;
	if (sampledTime > 2) {		// HACK for testing -- start over every few seconds
		testSource.time = 0;
		//testSource.speed *= 2;
		testSource.pan = (double)rand() / RAND_MAX * 2 - 1;
		sampledTime = 0;
		printf("Restarting sound with speed %lf and pan %f\n", testSource.speed, testSource.pan);
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

AudioClip AudioClip::Load(const char *path) {
	AudioClip result;
	if (SDL_LoadWAV(path, &result.spec, &result.data, &result.dataLen) == NULL) {
		printf("Unable to load WAV file %s: %s\n", path, SDL_GetError());
		return result;
	}
	printf("Loaded WAV with freq: %d  channels: %d  samples: %d  format: %d  bytes: %d\n",
		   result.spec.freq, result.spec.channels, result.spec.samples, result.spec.format, result.dataLen);
	// Now let's convert that to our mix format.
	SDL_AudioCVT cvt;
	SDL_BuildAudioCVT(&cvt, result.spec.format, result.spec.channels, result.spec.freq,
					  audioSpec.format, audioSpec.channels, audioSpec.freq);
	if (cvt.needed) {
		cvt.len = result.dataLen;
		cvt.buf = (Uint8*)SDL_malloc(cvt.len * cvt.len_mult);
		SDL_memcpy(cvt.buf, result.data, result.dataLen);
		SDL_ConvertAudio(&cvt);
		printf("After conversion, we have %d bytes in format %d with %d channels\n", cvt.len_cvt, cvt.dst_format, audioSpec.channels);
		SDL_FreeWAV(result.data);
		result.data = cvt.buf;
		result.dataLen = cvt.len_cvt;
		result.spec.format = cvt.dst_format;
		result.spec.channels = audioSpec.channels;
		result.spec.freq = audioSpec.freq;
	}
	int bytesPerFrame = sizeof(float) * result.spec.channels;
	result.frameCount = result.dataLen / bytesPerFrame;
	result.length = (double)result.frameCount / result.spec.freq;
	printf("Sound length: %lf seconds, or %d frames\n", result.length, result.frameCount);
	return result;
}

void AudioSource::SampleToBuffer(float *buffer, int frameCount) {
	if (clip == NULL || time > clip->length) return;
	double dt = speed / audioSpec.freq;
	float *clipSamples = (float*)clip->data;
	
	for (int i=0; i < frameCount; i++) {
		double frameIndex = clip->spec.freq * time;
		time += dt;
		long frameIndexBase = (long)frameIndex;
		if (frameIndexBase >= clip->frameCount) break;
		double frac = frameIndex - frameIndexBase;
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

