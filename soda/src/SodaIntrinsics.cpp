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

static IntrinsicResult intrinsic_sdltest(Context *context, IntrinsicResult partialResult) {
	SdlGlue::DoSdlTest();
	return IntrinsicResult::Null;
}

static IntrinsicResult intrinsic_sprites(Context *context, IntrinsicResult partialResult) {
	return IntrinsicResult(spriteList);
}


void AddSodaIntrinsics() {
	printf("Adding Soda intrinsics\n");
	Intrinsic *f;

	f = Intrinsic::Create("sdltest");
	f->code = &intrinsic_sdltest;

	f = Intrinsic::Create("sprites");
	f->code = &intrinsic_sprites;

}
