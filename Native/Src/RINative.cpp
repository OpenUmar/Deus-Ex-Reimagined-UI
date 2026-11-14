/*=============================================================================
	RINative.cpp: native support for the Reimagined UI add-on.
	Native functions are looked up by name, and the engine's name table is
	case-insensitive and keeps the first spelling it saw: a common name like
	"Version" may come back as "version" and miss the export. So every native
	function here gets a unique RINative prefix.

	Stage 1: proof of life. A tiny native class whose functions UnrealScript
	can call, to confirm this DLL loads beside GMDX AE and SecondRevision.
=============================================================================*/

#define RINATIVE_API DLL_EXPORT
#include "Engine.h"
#include "Extension.h"

// RIText.cpp
FLOAT RINativeTextWidthUI( INT Font, FLOAT SizeUI, FLOAT SpacingUI, const TCHAR* Text );
FLOAT RINativeAscentUI( INT Font, FLOAT SizeUI );
FLOAT RINativeDescentUI( INT Font, FLOAT SizeUI );
void RINativeDrawTileUI( XGC* gc, UTexture* Tex, FLOAT X, FLOAT Y, FLOAT W, FLOAT H, FLOAT U, FLOAT V, FLOAT UL, FLOAT VL );
FLOAT RINativeDrawTextUI( XGC* gc, INT Font, FLOAT X, FLOAT Y, const TCHAR* Text, FColor Col, FLOAT SizeUI, FLOAT SpacingUI );
UBOOL RINativeSet3DUI( XGC* gc, FLOAT HingeUI, FLOAT EyeXUI, FLOAT EyeYUI, FLOAT DistUI, FLOAT YawDeg );
void RINativeClear3DUI();
void RINativeProject3DUI( XGC* gc, FLOAT X, FLOAT Y, FLOAT* OX, FLOAT* OY );

class RINATIVE_API URINative : public UObject
{
public:
	DECLARE_CLASS(URINative, UObject, 0)
	NO_DEFAULT_CONSTRUCTOR(URINative)

	DECLARE_FUNCTION(execRINativeVersion)
	DECLARE_FUNCTION(execRINativePing)
	DECLARE_FUNCTION(execRINativeDrawText)
	DECLARE_FUNCTION(execRINativeTextWidth)
	DECLARE_FUNCTION(execRINativeAscent)
	DECLARE_FUNCTION(execRINativeDescent)
	DECLARE_FUNCTION(execRINativeDrawTile)
	DECLARE_FUNCTION(execRINativeSet3D)
	DECLARE_FUNCTION(execRINativeClear3D)
	DECLARE_FUNCTION(execRINativeProject3D)
};

IMPLEMENT_PACKAGE(RINative);
IMPLEMENT_CLASS(URINative);

// static native function string RINativeVersion();
void URINative::execRINativeVersion( FFrame& Stack, RESULT_DECL )
{
	P_FINISH;
	*(FString*)Result = TEXT("RINative 0.4");
}
IMPLEMENT_FUNCTION( URINative, -1, execRINativeVersion );

// static native function int RINativePing(int X);  returns X * 2 + 1
void URINative::execRINativePing( FFrame& Stack, RESULT_DECL )
{
	P_GET_INT(X);
	P_FINISH;
	*(INT*)Result = X * 2 + 1;
}
IMPLEMENT_FUNCTION( URINative, -1, execRINativePing );

// static native function float RINativeDrawText(GC gc, int Font, float X, float Y,
//                                                string Text, color Col, float Size, float Spacing);
void URINative::execRINativeDrawText( FFrame& Stack, RESULT_DECL )
{
	P_GET_OBJECT(XGC, gc);
	P_GET_INT(Font);
	P_GET_FLOAT(X);
	P_GET_FLOAT(Y);
	P_GET_STR(Text);
	P_GET_STRUCT(FColor, Col);
	P_GET_FLOAT(Size);
	P_GET_FLOAT(Spacing);
	P_FINISH;
	*(FLOAT*)Result = RINativeDrawTextUI( gc, Font, X, Y, *Text, Col, Size, Spacing );
}
IMPLEMENT_FUNCTION( URINative, -1, execRINativeDrawText );

// static native function float RINativeTextWidth(int Font, float Size, float Spacing, string Text);
void URINative::execRINativeTextWidth( FFrame& Stack, RESULT_DECL )
{
	P_GET_INT(Font);
	P_GET_FLOAT(Size);
	P_GET_FLOAT(Spacing);
	P_GET_STR(Text);
	P_FINISH;
	*(FLOAT*)Result = RINativeTextWidthUI( Font, Size, Spacing, *Text );
}
IMPLEMENT_FUNCTION( URINative, -1, execRINativeTextWidth );

// static native function float RINativeAscent(int Font, float Size);
void URINative::execRINativeAscent( FFrame& Stack, RESULT_DECL )
{
	P_GET_INT(Font);
	P_GET_FLOAT(Size);
	P_FINISH;
	*(FLOAT*)Result = RINativeAscentUI( Font, Size );
}
IMPLEMENT_FUNCTION( URINative, -1, execRINativeAscent );

// static native function float RINativeDescent(int Font, float Size);
void URINative::execRINativeDescent( FFrame& Stack, RESULT_DECL )
{
	P_GET_INT(Font);
	P_GET_FLOAT(Size);
	P_FINISH;
	*(FLOAT*)Result = RINativeDescentUI( Font, Size );
}
IMPLEMENT_FUNCTION( URINative, -1, execRINativeDescent );

// static native function RINativeDrawTile(GC gc, Texture Tex, float X, float Y, float W, float H,
//                                         float U, float V, float UL, float VL);
// Like GC.DrawStretchedTexture but placed on exact screen pixels.
void URINative::execRINativeDrawTile( FFrame& Stack, RESULT_DECL )
{
	P_GET_OBJECT(XGC, gc);
	P_GET_OBJECT(UTexture, Tex);
	P_GET_FLOAT(X);
	P_GET_FLOAT(Y);
	P_GET_FLOAT(W);
	P_GET_FLOAT(H);
	P_GET_FLOAT(U);
	P_GET_FLOAT(V);
	P_GET_FLOAT(UL);
	P_GET_FLOAT(VL);
	P_FINISH;
	RINativeDrawTileUI( gc, Tex, X, Y, W, H, U, V, UL, VL );
}
IMPLEMENT_FUNCTION( URINative, -1, execRINativeDrawTile );

// static native function bool RINativeSet3D(GC gc, float HingeX, float EyeX, float EyeY, float Dist, float Yaw);
// Until RINativeClear3D, every RINative tile and glyph drawn on this GC is
// drawn as part of a card turned Yaw degrees about the vertical line
// x = HingeX, seen from an eye Dist in front of (EyeX, EyeY). UI units in the
// GC's window. Returns False (and stays flat) for Yaw 0 or a bad distance.
void URINative::execRINativeSet3D( FFrame& Stack, RESULT_DECL )
{
	P_GET_OBJECT(XGC, gc);
	P_GET_FLOAT(HingeX);
	P_GET_FLOAT(EyeX);
	P_GET_FLOAT(EyeY);
	P_GET_FLOAT(Dist);
	P_GET_FLOAT(Yaw);
	P_FINISH;
	*(UBOOL*)Result = RINativeSet3DUI( gc, HingeX, EyeX, EyeY, Dist, Yaw );
}
IMPLEMENT_FUNCTION( URINative, -1, execRINativeSet3D );

// static native function RINativeClear3D();
void URINative::execRINativeClear3D( FFrame& Stack, RESULT_DECL )
{
	P_FINISH;
	RINativeClear3DUI();
}
IMPLEMENT_FUNCTION( URINative, -1, execRINativeClear3D );

// static native function RINativeProject3D(GC gc, float X, float Y, out float OX, out float OY);
void URINative::execRINativeProject3D( FFrame& Stack, RESULT_DECL )
{
	P_GET_OBJECT(XGC, gc);
	P_GET_FLOAT(X);
	P_GET_FLOAT(Y);
	P_GET_FLOAT_REF(OX);
	P_GET_FLOAT_REF(OY);
	P_FINISH;
	RINativeProject3DUI( gc, X, Y, OX, OY );
}
IMPLEMENT_FUNCTION( URINative, -1, execRINativeProject3D );
