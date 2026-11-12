//=============================================================================
// RIFont
// Base class for the baked TrueType fonts (Michroma, Exo 2). Each subclass
// holds one atlas texture plus per-glyph metrics for ASCII 32..126, generated
// by fontgen/atlas.py. Drawn by RIText.
//=============================================================================
class RIFont extends Object
	abstract;

var Texture Atlas;
var int     Ascent, Descent;     // atlas pixels
var int     GX[95], GY[95];      // glyph position in the atlas
var int     GW[95], GH[95];      // glyph size (0 = nothing to draw, e.g. space)
var int     GXO[95], GYO[95];    // offset from the pen position / baseline
var float   Adv[95];             // pen advance

// Accessors: UnrealScript can't reach arrays this large through a class
// context (Font.default.Adv[i] fails to compile), so callers use these.
static final function float GetAdv(int g) { return default.Adv[g]; }
static final function int   GetGX(int g)  { return default.GX[g]; }
static final function int   GetGY(int g)  { return default.GY[g]; }
static final function int   GetGW(int g)  { return default.GW[g]; }
static final function int   GetGH(int g)  { return default.GH[g]; }
static final function int   GetGXO(int g) { return default.GXO[g]; }
static final function int   GetGYO(int g) { return default.GYO[g]; }

defaultproperties
{
}
