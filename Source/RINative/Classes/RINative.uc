//=============================================================================
// RINative
// Script face of RINative.dll, the Reimagined UI's native support library.
// Version / Ping confirm the DLL is loaded; the text functions draw crisp,
// pixel-exact text at any resolution.
//=============================================================================
class RINative extends Object
	native
	noexport;     // the C++ side is maintained by hand (Native\Src); UCC writes no header

// Names are prefixed: the engine finds natives by (case-insensitive) name
native static final function string RINativeVersion();
native static final function int RINativePing(int X);     // returns X * 2 + 1

// Native text (see Native\Src\RIText.cpp). Fonts: 0 Michroma, 1 Exo 2 Medium,
// 2 Exo 2 SemiBold. Size is the em size and Spacing the extra letter spacing,
// both in UI units; X, Y is the top of the line. Draw returns the width.
native static final function float RINativeDrawText(GC gc, int Font, float X, float Y, string Text, color Col, float Size, float Spacing);
native static final function float RINativeTextWidth(int Font, float Size, float Spacing, string Text);
native static final function float RINativeAscent(int Font, float Size);
native static final function float RINativeDescent(int Font, float Size);

// Like GC.DrawStretchedTexture, but edges land on exact screen pixels (the
// engine's own call rounds to whole UI units: 2 pixels at 1080p). Uses the
// GC's current style and tile colour.
native static final function RINativeDrawTile(GC gc, Texture Tex, float X, float Y, float W, float H, float U, float V, float UL, float VL);

// 3D panels (RINative 0.4): until RINativeClear3D, every RINative tile and
// glyph drawn on this GC is drawn as part of a card turned Yaw degrees about
// the vertical line x = HingeX, seen in perspective from an eye Dist in front
// of (EyeX, EyeY). UI units in the GC's window. Positive Yaw pushes the
// card's right side away, negative its left side. Returns False (and stays
// flat) for Yaw 0 or a bad distance. Project3D gives where a card point lands.
native static final function bool RINativeSet3D(GC gc, float HingeX, float EyeX, float EyeY, float Dist, float Yaw);
native static final function RINativeClear3D();
native static final function RINativeProject3D(GC gc, float X, float Y, out float OX, out float OY);

defaultproperties
{
}
