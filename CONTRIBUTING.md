# Contributing to Soda

Contributions are very welcome.  See TODO.md for a prioritized wish list.

## Code Overview

Most of the Soda API is defined in the **SodaIntrinsics** (.h/.cpp) module.  Soda also uses the shell-related intrinsics from the command-line version of MiniScript, which remain in the **ShellIntrinsics** module.

**SodaIntrinsics** does very little heavy lifting; mostly it's just defining all the built-in classes and functions Soda users use to make their game.  The "guts" of that work is all in the **SdlGlue** namespace, which is currently divided between **SdlGlue.h/.cpp** and **SdlAudio** (just because the audio support is rather complex, and so was split off into its own file).  These two modules are where all the SDL code goes.

## Coding Standards

In general, try to follow the formatting and style of the existing code.  A few notes in particular:

1. Curly braces use the **compact** layout: an opening brace always goes at the end of the line.  A closing brace goes on a line by itself unless followed by `else`, in which case the `else` goes on the same line.  Example:

```cpp
void SomeFunc(int arg) {
	if (arg > 41) {
		do(stuff);
	} else {
		do(otherStuff);
	}
}
```

2. In the case of a **single-line if**, i.e. one where you omit the curly braces, the consequent statement *must* be on the same line as the `if`.

**RIGHT:**
```cpp
if (arg < 0) return NULL;
``` 

**WRONG:**
```cpp
if (arg < 0)
	return NULL;
```

If the line is too long to comfortably fit it all on one line, then use curly braces and make it three lines.  Never, ever put the consequence on the next line without curly braces.  Ever.
