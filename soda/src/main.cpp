//
//  main.cpp
//  soda
//
//  Created by Joe Strout on 7/29/21.
//

#include <iostream>
#include <SDL2/SDL.h>
#include <SDL2/SDL_thread.h>
#include <stdio.h>
#include <iostream>
#include <fstream>
#include "MiniScript/SimpleString.h"
#include "MiniScript/UnicodeUtil.h"
#include "MiniScript/UnitTest.h"
#include "MiniScript/SimpleVector.h"
#include "MiniScript/List.h"
#include "MiniScript/Dictionary.h"
#include "MiniScript/MiniscriptParser.h"
#include "MiniScript/MiniscriptInterpreter.h"
#include "OstreamSupport.h"
#include "MiniScript/SplitJoin.h"
#include "ShellIntrinsics.h"
#include "SodaIntrinsics.h"
#include "SdlGlue.h"

using namespace MiniScript;

bool printHeaderInfo = true;

static bool dumpTAC = false;

static void Print(String s) {
	std::cout << s.c_str() << std::endl;
	SdlGlue::Print(s);
}

static void PrintErr(String s) {
	std::cerr << s.c_str() << std::endl;
	SdlGlue::Print(s);
}

static int ReturnErr(String s, int errCode = -1) {
	PrintErr(s);
	return errCode;
}

static void PrintHeaderInfo() {
	if (!printHeaderInfo) return;
	std::cout << "MiniScript " << std::endl
	<< MiniScript::hostName << " v" << MiniScript::hostVersion
	<< "; language v" << VERSION;
#if(DEBUG)
	std::cout << " (DEBUG)";
#endif
//	std::cout << std::endl;
	std::cout <<  " (" << __DATE__ << ")" << std::endl;
	printHeaderInfo = false;	// (print this stuff only once)
}

static void PrintHelp(String cmdPath) {
	Print(String("usage: ") + cmdPath + " [option] ... [-c cmd | file | -]");
	Print("Options and arguments:");
	Print("-c cmd : program passed in as String (terminates option list)");
	Print("-h     : print this help message and exit (also -? or --help)");
	Print("file   : program read from script file");
	Print("-      : program read from stdin (default; interactive mode if a tty)");
}

void ConfigInterpreter(Interpreter &interp) {
	interp.standardOutput = &Print;
	interp.errorOutput = &PrintErr;
	interp.implicitOutput = &Print;
}

static SimpleVector<String> userInput;
static SDL_mutex* userInputMutex = nullptr;
static bool interpreterBusy = false;

static int ReplThread(void *interpreter) {
	Interpreter *interp = (Interpreter*)interpreter;
	
	// Run a thread to process the terminal input.  But note that it's not safe
	// to do many SDL things (like resizing the window) from a secondary thread.
	// So, we'll just put the user input onto the given vector, and let the
	// main thread pull it off and process it.  (We only need to be careful about
	// locking that vector when we modify it.)
	while (true) {
		if (!interp->Done()) {
			SDL_Delay(100);
			continue;
		}

		const char *prompt = (interp->NeedMoreInput() ? ">>> " : "> ");
		#if useEditline
			char *buf;
			buf = readline(prompt);
			if (buf == NULL) return 0;
			String input(buf);
			SDL_LockMutex(userInputMutex);
			userInput.push_back(input);
			SDL_UnlockMutex(userInputMutex);
			free(buf);
			SDL_Delay(100);	// (gives main thread a chance to feed this to the REPL, so we can show the right prompt)
		#else
			// Standard C++ I/O:
			char buf[1024];
			std::cout << prompt;
			if (not std::cin.getline(buf, sizeof(buf))) {
				std::cout << std::endl;
				return 0;
			}
			String input(buf);
			SDL_LockMutex(userInputMutex);
			userInput.push_back(input);
			SDL_UnlockMutex(userInputMutex);
		#endif
		
		if (exitASAP) {
			// Note: do NOT call SdlGlue::Shutdown here;
			// this thread is only responsible for handling terminal input.
			// The SDL shutdown will be done on the main thread, in DoREPL.
			return exitResult;
		}
	}
	return 0;
}

static int DoREPL() {
	
	SdlGlue::Setup();
	
	Interpreter interp;
	ConfigInterpreter(interp);
	
	userInputMutex = SDL_CreateMutex();
	SDL_Thread* thread = SDL_CreateThread(ReplThread, "ReplThread", (void*)(&interp));
	
	while (!exitASAP) {
		// Service SDL
		SdlGlue::Service();
		if (SdlGlue::quit) {
			exitASAP = true;
			SDL_DetachThread(thread);
			thread = NULL;
		}
		
		if (!interp.Done()) {
			// Still processing some previous input.  Keep working!
			try {
				interp.RunUntilDone(0.1);
			} catch (MiniscriptException& mse) {
				std::cerr << "Runtime Exception: " << mse.message << std::endl;
				interp.vm->Stop();
			}
		} else {
			// Grab input from the user, if any....
			String inp;
			SDL_LockMutex(userInputMutex);
			if (userInput.size() > 0) {
				inp = userInput[0];
				userInput.deleteIdx(0);
			}
				SDL_UnlockMutex(userInputMutex);
			// and feed it to the REPL
			if (!inp.empty()) {
				interpreterBusy = true;
				try {
					interp.REPL(inp, 0.1);
				} catch (MiniscriptException& mse) {
					std::cerr << "Runtime Exception: " << mse.message << std::endl;
					interp.vm->Stop();
				}
				interpreterBusy = false;
			}
		}
	}
	SdlGlue::Shutdown();
	int threadResult;
	SDL_WaitThread(thread, &threadResult);
	SDL_DestroyMutex(userInputMutex); userInputMutex = nullptr;
	return exitResult;
}

static int DoCommand(String cmd) {
	Interpreter interp;
	ConfigInterpreter(interp);
	interp.Reset(cmd);
	interp.Compile();
	
//	std::cout << cmd << std::endl;
	
	if (dumpTAC) {
		Context *c = interp.vm->GetGlobalContext();
		for (long i=0; i<c->code.Count(); i++) {
			std::cout << i << ". " << c->code[i].ToString() << std::endl;
		}
	}

	SdlGlue::Setup();

	while (!interp.Done() && !SdlGlue::quit) {
		SdlGlue::Service();
		try {
			interp.RunUntilDone(0.01, true);
		} catch (MiniscriptException& mse) {
			std::cerr << "Runtime Exception: " << mse.message << std::endl;
			interp.vm->Stop();
			exitResult = -1;
			break;
		}
	}

	SdlGlue::Shutdown();
	return exitResult;
}

static int DoScriptFile(String path) {
	// Read the file
	List<String> source;
	std::ifstream infile(path.c_str());
	if (!infile.is_open()) {
		std::cerr << "Error opening file: " << path.c_str() << std::endl;
		return -1;
	}
	char buf[1024];
	while (infile.getline(buf, sizeof(buf))) {
		source.Add(buf);
	}
	//Print(String("Read ") + String::Format(source.Count()) + (source.Count() == 1 ? " line" : " lines") + " from: " + path);

	// Comment out the first line, if it's a hashbang
	if (source.Count() > 0 and source[0].StartsWith("#!")) source[0] = "// " + source[0];
	
	// Concatenate and execute the code.
	return DoCommand(Join("\n", source));
}

static List<String> testOutput;
static void PrintToTestOutput(String s) {
	testOutput.Add(s);
}

static void DoOneIntegrationTest(List<String> sourceLines, long sourceLineNum,
				 List<String> expectedOutput, long outputLineNum) {
//	std::cout << "Running test starting at line " << sourceLineNum << std::endl;
	
	Interpreter miniscript(sourceLines);
	miniscript.standardOutput = &PrintToTestOutput;
	miniscript.errorOutput = &PrintToTestOutput;
	miniscript.implicitOutput = &PrintToTestOutput;
	testOutput.Clear();
	miniscript.RunUntilDone(60, false);
	
	long minLen = expectedOutput.Count() < testOutput.Count() ? expectedOutput.Count() : testOutput.Count();
	for (long i = 0; i < minLen; i++) {
		if (testOutput[i] != expectedOutput[i]) {
			Print("TEST FAILED AT LINE " + String::Format(outputLineNum + i)
			+ "\n  EXPECTED: " + expectedOutput[i]
			+ "\n    ACTUAL: " + testOutput[i]);
		}
	}
	if (expectedOutput.Count() > testOutput.Count()) {
		Print("TEST FAILED: MISSING OUTPUT AT LINE " + String::Format(outputLineNum + testOutput.Count()));
		for (long i = testOutput.Count(); i < expectedOutput.Count(); i++) {
			Print("  MISSING: " + expectedOutput[i]);
		}
	} else if (testOutput.Count() > expectedOutput.Count()) {
		Print("TEST FAILED: EXTRA OUTPUT AT LINE " + String::Format(outputLineNum + expectedOutput.Count()));
		for (long i = expectedOutput.Count(); i < testOutput.Count(); i++) {
			Print("  EXTRA: " + testOutput[i]);
		}
	}
}

void RunIntegrationTests(String path) {
	std::ifstream infile(path.c_str());

	List<String> sourceLines;
	List<String> expectedOutput;
	long testLineNum = 0;
	long outputLineNum = 0;
	
	char buf[1024];
	String line;
	long lineNum = 0;
	bool inOutputSection = false;
	while (infile.good()) {
		infile.getline(buf, sizeof(buf));
		lineNum++;
		line = buf;

		if (line.StartsWith("====")) {
			if (sourceLines.Count() > 0 && sourceLines[0][0] < 0x80) {
				DoOneIntegrationTest(sourceLines, testLineNum, expectedOutput, outputLineNum);
			}
			sourceLines.Clear();
			expectedOutput.Clear();
			testLineNum = lineNum + 1;
			inOutputSection = false;
		} else if (line.StartsWith("----")) {
			expectedOutput.Clear();
			inOutputSection = true;
			outputLineNum = lineNum + 1;
		} else if (inOutputSection) {
			expectedOutput.Add(line);
		} else {
			sourceLines.Add(line);
		}
	}
	if (sourceLines.Count() > 0) {
		DoOneIntegrationTest(sourceLines, testLineNum, expectedOutput, outputLineNum);
	}
	Print("\nIntegration tests complete.\n");
}

void PrepareShellArgs(int argc, const char* argv[], int startingAt) {
	ValueList args;
	for (int i=startingAt; i<argc; i++) {
		args.Add(String(argv[i]));
	}
	shellArgs = args;
}

int main(int argc, const char * argv[]) {
	
#if(DEBUG)
	std::cout << "StringStorage instances at start (from static keywords, etc.): " << StringStorage::instanceCount << std::endl;
	std::cout << "total RefCountedStorage instances at start (from static keywords, etc.): " << RefCountedStorage::instanceCount << std::endl;
#endif

	UnitTest::RunAllTests();

#if(DEBUG)
	std::cout << "StringStorage instances left: " << StringStorage::instanceCount << std::endl;
	std::cout << "total RefCountedStorage instances left (includes 2 Unicode case maps): " << RefCountedStorage::instanceCount << std::endl;
#endif
	
	MiniScript::hostVersion = 0.01;
#if _WIN32 || _WIN64
	MiniScript::hostName = "Soda (Windows)";
#elif defined(__APPLE__) || defined(__FreeBSD__)
	MiniScript::hostName = "Soda (Unix)";
#else
	MiniScript::hostName = "Soda (Linux)";
#endif
	MiniScript::hostInfo = "https://github.com/JoeStrout/soda";
	
	AddShellIntrinsics();
	AddSodaIntrinsics();
	
	for (int i=1; i<argc; i++) {
		String arg = argv[i];
		if (arg == "-h" or arg == "-?" or arg == "--help") {
			PrintHeaderInfo();
			PrintHelp(argv[0]);
			return 0;
		} else if (arg == "-q") {
			printHeaderInfo = false;
		} else if (arg == "-c") {
			i++;
			if (i >= argc) return ReturnErr("Command expected after -c option");
			String cmd = argv[i];
			return DoCommand(cmd);
		} else if (arg == "--dumpTAC") {
			dumpTAC = true;
		} else if (arg == "--itest") {
			PrintHeaderInfo();
			i++;
			if (i >= argc) return ReturnErr("Path to test suite expected after --itest option");
			RunIntegrationTests(argv[i]);
			return 0;
		} else if (arg == "-") {
			PrintHeaderInfo();
			PrepareShellArgs(argc, argv, i);
			return DoREPL();
		} else if (not arg.StartsWith("-")) {
			PrepareShellArgs(argc, argv, i);
			return DoScriptFile(arg);
		} else {
			PrintHeaderInfo();
			return ReturnErr(String("Unknown option: ") + arg);
		}
	}
	
	// If we get to here, then we exhausted all our options without actually doing
	// anything.  So, by default, drop into the REPL.
	PrintHeaderInfo();
	PrepareShellArgs(argc, argv, 1);
	return DoREPL();
}
