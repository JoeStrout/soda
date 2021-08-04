//
//  SodaIntrinsics.cpp
//  This module adds all the MiniScript APIs that users use to interface with Soda
//	to create games.  That includes defining intrinsic classes like Display, Sound,
//	file, etc.
//
//  Created by Joe Strout on 7/29/21.
//

#include "SodaIntrinsics.h"
#include "SdlGlue.h"
#include "SdlAudio.h"
#include "MiniScript/String.h"
#include "MiniScript/UnicodeUtil.h"
#include "MiniScript/UnitTest.h"
#include "MiniScript/SimpleVector.h"
#include "MiniScript/List.h"
#include "MiniScript/Dictionary.h"
#include "MiniScript/MiniscriptParser.h"
#include "MiniScript/MiniscriptInterpreter.h"
#include "OstreamSupport.h"
#include "MiniScript/SplitJoin.h"

using namespace MiniScript;

Value spriteList = ValueList();
Value white("#FFFFFF");

static IntrinsicResult intrinsic_sdltest(Context *context, IntrinsicResult partialResult) {
	SdlGlue::DoSdlTest();
	return IntrinsicResult::Null;
}

static IntrinsicResult intrinsic_sprites(Context *context, IntrinsicResult partialResult) {
	return IntrinsicResult(spriteList);
}

//--------------------------------------------------------------------------------
// Image class
//--------------------------------------------------------------------------------
ValueDict imageClass;
static Intrinsic *i_image_getImage = NULL;

static IntrinsicResult intrinsic_imageClass(Context *context, IntrinsicResult partialResult) {
	return IntrinsicResult(imageClass);
}

static IntrinsicResult intrinsic_image_getImage(Context *context, IntrinsicResult partialResult) {
	Value self = context->GetVar("self");
	Value left = context->GetVar("left");
	Value bottom = context->GetVar("bottom");
	Value width = context->GetVar("width");
	Value height = context->GetVar("height");
	return IntrinsicResult(SdlGlue::GetSubImage(self, left.IntValue(), bottom.IntValue(), width.IntValue(), height.IntValue()));
}

//--------------------------------------------------------------------------------
// key module
//--------------------------------------------------------------------------------
static Intrinsic *i_key_pressed = NULL;

static IntrinsicResult intrinsic_keyModule(Context *context, IntrinsicResult partialResult) {
	static ValueDict keyModule;
	
	if (keyModule.Count() == 0) {
		keyModule.SetValue("pressed", i_key_pressed->GetFunc());
	}
	
	return IntrinsicResult(keyModule);
}

static IntrinsicResult intrinsic_key_pressed(Context *context, IntrinsicResult partialResult) {
	Value keyName = context->GetVar("keyName");
	if (keyName.IsNull()) return IntrinsicResult::Null;
	return IntrinsicResult(SdlGlue::IsKeyPressed(keyName.ToString()));
}

//--------------------------------------------------------------------------------
// mouse module
//--------------------------------------------------------------------------------

static Intrinsic *i_mouse_button = NULL;
static Intrinsic *i_mouse_x = NULL;
static Intrinsic *i_mouse_y = NULL;

static IntrinsicResult intrinsic_mouseModule(Context *context, IntrinsicResult partialResult) {
	static ValueDict mouseModule;
	
	if (mouseModule.Count() == 0) {
		mouseModule.SetValue("button", i_mouse_button->GetFunc());
		mouseModule.SetValue("x", i_mouse_x->GetFunc());
		mouseModule.SetValue("y", i_mouse_y->GetFunc());
	}
	
	return IntrinsicResult(mouseModule);
}

static IntrinsicResult intrinsic_mouse_button(Context *context, IntrinsicResult partialResult) {
	Value which = context->GetVar("which");
	if (which.IsNull()) return IntrinsicResult::Null;
	return IntrinsicResult(SdlGlue::IsMouseButtonPressed((int)which.IntValue()));
}

static IntrinsicResult intrinsic_mouse_x(Context *context, IntrinsicResult partialResult) {
	return IntrinsicResult(SdlGlue::GetMouseX());
}

static IntrinsicResult intrinsic_mouse_y(Context *context, IntrinsicResult partialResult) {
	return IntrinsicResult(SdlGlue::GetMouseY());
}

//--------------------------------------------------------------------------------
// Sound class
//--------------------------------------------------------------------------------
ValueDict soundClass;
static Intrinsic *i_sound_play = NULL;
static Intrinsic *i_sound_stop = NULL;
static Intrinsic *i_sound_stopAll = NULL;

static IntrinsicResult intrinsic_soundClass(Context *context, IntrinsicResult partialResult) {
	return IntrinsicResult(soundClass);
}

static IntrinsicResult intrinsic_sound_play(Context *context, IntrinsicResult partialResult) {
	Value self = context->GetVar("self");
	double volume = context->GetVar("volume").DoubleValue();
	double pan = context->GetVar("pan").DoubleValue();
	double speed = context->GetVar("speed").DoubleValue();
	SdlGlue::PlaySound(self, volume, pan, speed);
	return IntrinsicResult::Null;
}

static IntrinsicResult intrinsic_sound_stop(Context *context, IntrinsicResult partialResult) {
	Value self = context->GetVar("self");
	SdlGlue::StopSound(self);
	return IntrinsicResult::Null;
}

static IntrinsicResult intrinsic_sound_stopAll(Context *context, IntrinsicResult partialResult) {
	SdlGlue::StopAllSounds();
	return IntrinsicResult::Null;
}

//--------------------------------------------------------------------------------
// Sprite class
//--------------------------------------------------------------------------------

static IntrinsicResult intrinsic_spriteClass(Context *context, IntrinsicResult partialResult) {
	static ValueDict spriteClass;
	
	if (spriteClass.Count() == 0) {
		spriteClass.SetValue("image", Value::null);
		spriteClass.SetValue("x", Value::zero);
		spriteClass.SetValue("y", Value::zero);
		spriteClass.SetValue("scale", Value::one);
		spriteClass.SetValue("rotation", Value::zero);
		spriteClass.SetValue("tint", white);
	}
	
	return IntrinsicResult(spriteClass);
}



//--------------------------------------------------------------------------------
// file module additions
//--------------------------------------------------------------------------------

static Intrinsic *i_file_loadImage = NULL;
static Intrinsic *i_file_loadSound = NULL;
static Intrinsic *i_file_loadFont = NULL;

static IntrinsicResult intrinsic_file_loadImage(Context *context, IntrinsicResult partialResult) {
	Value path = context->GetVar("path");
	return IntrinsicResult(SdlGlue::LoadImage(path.ToString()));
}

static IntrinsicResult intrinsic_file_loadSound(Context *context, IntrinsicResult partialResult) {
	Value path = context->GetVar("path");
	return IntrinsicResult(SdlGlue::LoadSound(path.ToString()));
}


//--------------------------------------------------------------------------------
void AddSodaIntrinsics() {
	printf("Adding Soda intrinsics\n");
	Intrinsic *f;

	f = Intrinsic::Create("sdltest");	// ToDo: remove this
	f->code = &intrinsic_sdltest;

	f = Intrinsic::Create("sprites");	// ToDo: put this in a SpriteDisplay
	f->code = &intrinsic_sprites;

	i_image_getImage = Intrinsic::Create("");
	i_image_getImage->AddParam("left", Value::zero);
	i_image_getImage->AddParam("bottom", Value::zero);
	i_image_getImage->AddParam("width", Value(-1));
	i_image_getImage->AddParam("height", Value(-1));
	i_image_getImage->code = &intrinsic_image_getImage;

	f = Intrinsic::Create("Image");
	f->code = &intrinsic_imageClass;
	imageClass.SetValue("width", Value::zero);
	imageClass.SetValue("height", Value::zero);
	imageClass.SetValue("getImage", i_image_getImage->GetFunc());

	Intrinsic *fileIntrinsic = Intrinsic::GetByName("file");
	if (fileIntrinsic == NULL) {
		printf("ERROR: fileModule not found.\nAddSodaIntrinsics must be called after AddShellIntrinsics.\n");
	} else {
		IntrinsicResult result;
		ValueDict fileModule = fileIntrinsic->code(NULL, result).Result().GetDict();
		
		i_file_loadImage = Intrinsic::Create("");
		i_file_loadImage->AddParam("path", Value::emptyString);
		i_file_loadImage->code = &intrinsic_file_loadImage;
		fileModule.SetValue("loadImage", i_file_loadImage->GetFunc());
		
		i_file_loadSound = Intrinsic::Create("");
		i_file_loadSound->AddParam("path", Value::emptyString);
		i_file_loadSound->code = &intrinsic_file_loadSound;
		fileModule.SetValue("loadSound", i_file_loadSound->GetFunc());
	}
	
	f = Intrinsic::Create("Sprite");
	f->code = &intrinsic_spriteClass;

	i_sound_play = Intrinsic::Create("");
	i_sound_play->AddParam("volume", Value::one);
	i_sound_play->AddParam("pan", Value::zero);
	i_sound_play->AddParam("speed", Value::one);
	i_sound_play->code = &intrinsic_sound_play;

	i_sound_stop = Intrinsic::Create("");
	i_sound_stop->code = &intrinsic_sound_stop;

	i_sound_stopAll = Intrinsic::Create("");
	i_sound_stopAll->code = &intrinsic_sound_stopAll;

	f = Intrinsic::Create("Sound");
	f->code = &intrinsic_soundClass;
	soundClass.SetValue("_handle", Value::null);
	soundClass.SetValue("loop", Value::zero);
	soundClass.SetValue("play", i_sound_play->GetFunc());
	soundClass.SetValue("stop", i_sound_stop->GetFunc());
	soundClass.SetValue("stopAll", i_sound_stopAll->GetFunc());

	f = Intrinsic::Create("key");
	f->code = &intrinsic_keyModule;

	i_key_pressed = Intrinsic::Create("");
	i_key_pressed->AddParam("keyName");
	i_key_pressed->code = &intrinsic_key_pressed;
	
	f = Intrinsic::Create("mouse");
	f->code = &intrinsic_mouseModule;
	
	i_mouse_button = Intrinsic::Create("");
	i_mouse_button->AddParam("which", Value::zero);
	i_mouse_button->code = &intrinsic_mouse_button;
	
	i_mouse_x = Intrinsic::Create("");
	i_mouse_x->code = &intrinsic_mouse_x;
	
	i_mouse_y = Intrinsic::Create("");
	i_mouse_y->code = &intrinsic_mouse_y;
}
