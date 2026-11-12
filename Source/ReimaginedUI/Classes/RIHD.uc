//=============================================================================
// RIHD
// Vanilla+ texture swap: finds the 4x Real-ESRGAN remaster of an original UI
// texture in RIVanillaHD.u (built by Build_RIVanillaHD.cmd) and draws it at the
// original's size. Names mirror the originals:
//   DeusExUI.<Group>.<Name>  ->  RIVanillaHD.<Group>.<Name>
//   GMDXUI.<Group>.<Name>    ->  RIVanillaHD.GMDX_<Group>.<Name>
// Anything without a remaster (or with the package missing) falls back to the
// original, so a partial package is safe.
//=============================================================================
class RIHD extends Object
	abstract;

var Texture CacheSrc[640];
var Texture CacheHD[640];
var int CacheCount;
var bool bNoPackage;

// The remaster of T, or T itself when there is none
static final function Texture HD(Texture T)
{
	local int i;
	local string P, Grp, Nm;
	local Texture H;

	if (T == None)
		return None;
	if (Class'RIRootWindow'.default.bNoHDTextures)
		return T;
	for (i = 0; i < default.CacheCount; i++)
		if (default.CacheSrc[i] == T)
			return default.CacheHD[i];

	P = string(T);
	H = None;
	if (!default.bNoPackage)
	{
		if (Left(P, 9) ~= "DeusExUI.")
			H = Texture(DynamicLoadObject("RIVanillaHD." $ Mid(P, 9), class'Texture', true));
		else if (Left(P, 7) ~= "GMDXUI.")
		{
			Grp = Mid(P, 7);
			Nm = Mid(Grp, InStr(Grp, ".") + 1);
			Grp = Left(Grp, InStr(Grp, "."));
			H = Texture(DynamicLoadObject("RIVanillaHD.GMDX_" $ Grp $ "." $ Nm, class'Texture', true));
		}
		if ((H == None) && (default.CacheCount == 0)
			&& (DynamicLoadObject("RIVanillaHD.RIVanillaHD", class'Class', true) == None))
			default.bNoPackage = true;
	}
	if (H == None)
		H = T;
	// Screen backgrounds, borders and data vault images are unloaded by AE
	// when their screen closes: never keep a reference to them
	if ((default.CacheCount < 640) && (InStr(P, "Background") < 0) && (InStr(P, "Border") < 0)
		&& (InStr(P, "UserInterface.Image") < 0))
	{
		default.CacheSrc[default.CacheCount] = T;
		default.CacheHD[default.CacheCount] = H;
		default.CacheCount++;
	}
	return H;
}

// Forget every cached texture (before a map change, so nothing stale is held)
static final function Reset()
{
	local int i;

	for (i = 0; i < 640; i++)
	{
		default.CacheSrc[i] = None;
		default.CacheHD[i] = None;
	}
	default.CacheCount = 0;
	default.bNoPackage = False;
}

// Drop-in for gc.DrawTexture(x, y, w, h, tx, ty, T): same texel coordinates in
// the original's space, drawn from the remaster
static final function Draw(GC gc, float X, float Y, float W, float H, float TX, float TY, Texture T)
{
	local Texture R;
	local float K;

	R = HD(T);
	if ((R == T) || (T.USize == 0))
	{
		gc.DrawTexture(X, Y, W, H, TX, TY, T);
		return;
	}
	K = float(R.USize) / float(T.USize);
	gc.DrawStretchedTexture(X, Y, W, H, TX * K, TY * K, W * K, H * K, R);
}

// Drop-in for gc.DrawStretchedTexture(...) with source coords in the original's space
static final function DrawStretched(GC gc, float X, float Y, float W, float H, float SX, float SY, float SW, float SH, Texture T)
{
	local Texture R;
	local float K;

	R = HD(T);
	K = 1.0;
	if ((R != T) && (T.USize > 0))
		K = float(R.USize) / float(T.USize);
	gc.DrawStretchedTexture(X, Y, W, H, SX * K, SY * K, SW * K, SH * K, R);
}

// DrawStretched on exact screen pixels (RINative): neighbouring pieces of a
// frame meet edge to edge instead of overlapping (the engine's own call rounds
// to whole UI units, and overlaps of additive pieces show as bright seams)
static final function DrawExact(GC gc, float X, float Y, float W, float H, float SX, float SY, float SW, float SH, Texture T)
{
	local Texture R;
	local float K;

	R = HD(T);
	K = 1.0;
	if ((R != T) && (T.USize > 0))
		K = float(R.USize) / float(T.USize);
	Class'RIVP'.static.TileR(gc, X, Y, W, H, SX * K, SY * K, SW * K, SH * K, R);
}

defaultproperties
{
}
