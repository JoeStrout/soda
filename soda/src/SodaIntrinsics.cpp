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

static IntrinsicResult intrinsic_file_loadImage(Context *context, IntrinsicResult partialResult) {
	Value path = context->GetVar("path");
	return IntrinsicResult(SdlGlue::LoadImage(path.ToString()));
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
void AddSodaIntrinsics() {
	printf("Adding Soda intrinsics\n");
	Intrinsic *f;

	f = Intrinsic::Create("sdltest");	// ToDo: remove this
	f->code = &intrinsic_sdltest;

	f = Intrinsic::Create("sprites");	// ToDo: put this in a SpriteDisplay
	f->code = &intrinsic_sprites;

	f = Intrinsic::Create("loadImage");	// ToDo: put this in a file module
	f->AddParam("path", Value::emptyString);
	f->code = &intrinsic_file_loadImage;
	
	f = Intrinsic::Create("Sprite");
	f->code = &intrinsic_spriteClass;

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
