//
//  SdlAudio.cpp
//	This module forms the interface between SDL and the rest of Soda specifically
//	for audio support.
//
//  Created by Joe Strout on 8/1/21.
//

#include "SdlAudio.h"
#include <SDL2/SDL.h>
#
namespace SdlGlue {

// Helper classes
class AudioClip {
public:
	SDL_AudioSpec spec;
	Uint8 *data;
	Uint32 dataLen;

	AudioClip() : data(NULL), dataLen(0) { SDL_zero(spec); }

	void ReleaseData() {
		SDL_FreeWAV(data);
		data = NULL;
		dataLen = 0;
	}
	
	bool isValid() { return data != NULL && dataLen > 0; }
	
	static AudioClip Load(const char *path);
};

// Private data
static SDL_AudioDeviceID deviceId = 0;
static SDL_AudioSpec audioSpec;
static AudioClip testClip;
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
	float *samples = (float*)buffer;
	int sampleCount = bufferSize / sizeof(float);
	int frameCount = bufferSize / (sizeof(float) * audioSpec.channels);
	
	// Let's play our clip.  Since it's already been converted to the same format,
	// frequency, and number of channels as our output, we can literally just
	// copy it in.  But we'll do it in a loop anyway, so that we can consider
	// doing things like left/right pan or speed changes.
	float *dstSample = samples;
	int startFrame = sampledTime * audioSpec.freq;
	float *srcSample = ((float*)testClip.data) + startFrame * audioSpec.channels;
	float *srcSampleEnd = (float*)(testClip.data + testClip.dataLen);
	for (int i=0; i<sampleCount; i++) {
		if (srcSample >= srcSampleEnd) *dstSample++ = 0;
		else *dstSample++ = *srcSample++;
	}
	
	sampledTime += (double)frameCount / audioSpec.freq;
	if (sampledTime > 5) sampledTime = 0;	// HACK for testing -- start over every 5 seconds
	
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
		printf("After conversion, we have %d bytes in format %d\n", cvt.len_cvt, cvt.dst_format);
		SDL_FreeWAV(result.data);
		result.data = cvt.buf;
		result.dataLen = cvt.len_cvt;
	}
	return result;
}


}	// end of: namespace SdlGlue

