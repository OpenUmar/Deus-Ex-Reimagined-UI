//=============================================================================
// RIUtil
// Colour and easing helpers shared by the Reimagined UI windows.
//=============================================================================
class RIUtil extends Object
	abstract;

// ----------------------------------------------------------------------
// Properties by name. Each base mod adds its own settings and fields (AE's
// bHardCoreMode, bShowMarkers, ...). Reading them by name compiles against
// any DeusEx.u: on a base without the property the text is empty, so a
// flag reads False and a number reads 0.
// ----------------------------------------------------------------------

static final function bool PHas(Object O, string N)
{
	return (O != None) && (O.GetPropertyText(N) != "");
}

static final function string PStr(Object O, string N)
{
	if (O == None)
		return "";
	return O.GetPropertyText(N);
}

static final function bool PBool(Object O, string N)
{
	if (O == None)
		return False;
	return O.GetPropertyText(N) ~= "True";
}

static final function int PInt(Object O, string N)
{
	if (O == None)
		return 0;
	return int(O.GetPropertyText(N));
}

static final function PSetBool(Object O, string N, bool B)
{
	if (PHas(O, N))
		O.SetPropertyText(N, string(B));
}

// Flips a flag and returns its new value
static final function bool PToggle(Object O, string N)
{
	PSetBool(O, N, !PBool(O, N));
	return PBool(O, N);
}

// Play time as hh:mm:ss (AE's Health screen format)
static final function string ClockTime(int Seconds)
{
	return Two(Seconds / 3600) $ ":" $ Two((Seconds / 60) % 60) $ ":" $ Two(Seconds % 60);
}

static final function string Two(int N)
{
	if (N < 10)
		return "0" $ string(N);
	return string(N);
}

static final function Color Col(float R, float G, float B)
{
	local Color C;

	C.R = byte(FClamp(R, 0, 255));
	C.G = byte(FClamp(G, 0, 255));
	C.B = byte(FClamp(B, 0, 255));
	C.A = 255;
	if (Class'RITheme'.default.Mode != 0)
		return Class'RITheme'.static.Map(C);
	return C;
}

// A colour exactly as given (no theme), for mixing colours already made
static final function Color Raw(float R, float G, float B)
{
	local Color C;

	C.R = byte(FClamp(R, 0, 255));
	C.G = byte(FClamp(G, 0, 255));
	C.B = byte(FClamp(B, 0, 255));
	C.A = 255;
	return C;
}

// Scale a colour toward black (used to fade translucent and tinted layers)
static final function Color Scale(Color C, float K)
{
	return Raw(C.R * K, C.G * K, C.B * K);
}

static final function Color Mix(Color A, Color B, float T)
{
	return Raw(A.R + (B.R - A.R) * T, A.G + (B.G - A.G) * T, A.B + (B.B - A.B) * T);
}

// Cubic ease-out: fast start, soft landing
static final function float EaseOut(float T)
{
	T = 1.0 - FClamp(T, 0, 1);
	return 1.0 - T * T * T;
}

// Progress of an animation that starts at Delay and lasts Duration, eased
static final function float Phase(float Time, float Delay, float Duration)
{
	return EaseOut((Time - Delay) / Duration);
}

defaultproperties
{
}
