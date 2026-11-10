/*=============================================================================
	RIEntry.cpp: DLL entry without a C runtime.
	The engine's native-class registration lives in static initialisers
	(UClass objects, GRegisterNative calls). Normally the C runtime runs them;
	this DLL is built without one, so the entry point walks the initialiser
	table itself, then hands over to the package's DllMain.
=============================================================================*/

typedef void (__cdecl *RIInitFn)(void);

#pragma section(".CRT$XCA", read)
#pragma section(".CRT$XCZ", read)
__declspec(allocate(".CRT$XCA")) RIInitFn RI_xc_a = 0;
__declspec(allocate(".CRT$XCZ")) RIInitFn RI_xc_z = 0;

extern "C" int __stdcall DllMain(void* hInstance, unsigned long Reason, void* Reserved);

extern "C" int __stdcall RIDllEntry(void* hInstance, unsigned long Reason, void* Reserved)
{
	if (Reason == 1)    // DLL_PROCESS_ATTACH
		for (RIInitFn* f = &RI_xc_a + 1; f < &RI_xc_z; ++f)
			if (*f)
				(*f)();
	return DllMain(hInstance, Reason, Reserved);
}

// Static destructors: the engine owns object lifetime and the process is
// exiting anyway, so destructor registration is a no-op (an msvcrt atexit
// would run them after this DLL has been unloaded).
extern "C" int __cdecl atexit(void (__cdecl *)(void)) { return 0; }

// Required by the compiler whenever floating point is used without a CRT.
extern "C" int _fltused = 0;
