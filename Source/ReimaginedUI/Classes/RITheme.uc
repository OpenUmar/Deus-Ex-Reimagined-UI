//=============================================================================
// RITheme
// Lets AE's colour themes recolour the rebuilt screens, as they recolour
// AE's own: the menus follow the Menu theme, the persona screens (Inventory,
// Health, Augs, Skills, Journal...), the HUD and dialogue follow the HUD
// theme. The title card keeps the original gold.
//
// Every colour the rebuilt UI makes goes through RIUtil.Col. While a themed
// window draws (Mode set at the start of its DrawWindow), Col passes the
// palette's own colours through Map: the hue turns to the theme's, the
// strength of colour scales with the theme's, and lightness is kept, so the
// layout's light and dark relationships survive any theme. Colours outside
// the palette's hue band (health reds and greens, white icon tints, AE's aug
// colours) are left alone.
//
// The GMDX defaults (Menu: MJ12, HUD: Amber) and AE's "Default" leave the
// designed palette exactly as it is.
//=============================================================================
class RITheme extends Object
	abstract;

var bool  bGoldMenus;        // a menu screen that belongs to the game (Augmentique's Outfit Settings): its blue turns gold
var int   Mode;              // 0 none, 1 menu palette (blue), 2 persona palette (gold), 3 main menu (blue, never Vanilla+)
var bool  bMenuOn, bHudOn;   // a non-default theme is selected
var float MenuHue, MenuSat, HudHue, HudSat;
var float Refreshed;

// Palette bases: hue (degrees) and saturation of the designed colours
const MENU_HUE = 235.0;
const MENU_SAT = 0.62;
const HUD_HUE  = 42.0;
const HUD_SAT  = 0.6;

static function SetMode(int M)
{
	default.Mode = M;
	default.bGoldMenus = False;
}

// Read both themes (cheap; called from the root's Tick a few times a second)
static function Refresh(DeusExPlayer P)
{
	local ColorTheme T;
	local float H, Sa;

	if ((P == None) || (P.ThemeManager == None))
	{
		default.bMenuOn = False;
		default.bHudOn = False;
		return;
	}
	T = P.ThemeManager.GetCurrentMenuColorTheme();
	default.bMenuOn = False;
	if ((T != None) && (T.GetThemeName() != "MJ12") && (T.GetThemeName() != "Default"))
	{
		KeyOf(T, H, Sa);
		default.MenuHue = H;
		default.MenuSat = Sa;
		default.bMenuOn = True;
	}
	T = P.ThemeManager.GetCurrentHUDColorTheme();
	default.bHudOn = False;
	if ((T != None) && (T.GetThemeName() != "Amber") && (T.GetThemeName() != "Default"))
	{
		KeyOf(T, H, Sa);
		default.HudHue = H;
		default.HudSat = Sa;
		default.bHudOn = True;
	}
}

// The theme's character: hue and saturation of its most colourful entry
static function KeyOf(ColorTheme T, out float H, out float Sa)
{
	local int i;
	local Color C;
	local float h1, s1, v1, best;

	H = 0;
	Sa = 0;
	best = -1;
	for (i = 0; i < T.GetColorCount(); i++)
	{
		C = T.GetColor(i);
		ToHSV(C.R, C.G, C.B, h1, s1, v1);
		if (s1 * v1 > best)
		{
			best = s1 * v1;
			H = h1;
			Sa = s1;
		}
	}
}

static function ToHSV(float R, float G, float B, out float H, out float Sa, out float V)
{
	local float mx, mn, d;

	R /= 255.0;
	G /= 255.0;
	B /= 255.0;
	mx = FMax(R, FMax(G, B));
	mn = FMin(R, FMin(G, B));
	d = mx - mn;
	V = mx;
	if (mx <= 0)
		Sa = 0;
	else
		Sa = d / mx;
	if (d <= 0)
		H = 0;
	else if (mx == R)
		H = 60.0 * ((G - B) / d);
	else if (mx == G)
		H = 60.0 * ((B - R) / d + 2.0);
	else
		H = 60.0 * ((R - G) / d + 4.0);
	if (H < 0)
		H += 360.0;
}

static function Color FromHSV(float H, float Sa, float V)
{
	local Color C;
	local float c1, x1, m, r1, g1, b1, hh;

	while (H < 0)
		H += 360.0;
	while (H >= 360.0)
		H -= 360.0;
	Sa = FClamp(Sa, 0, 1);
	V = FClamp(V, 0, 1);
	c1 = V * Sa;
	hh = H / 60.0;
	x1 = c1 * (1.0 - Abs((hh - 2.0 * int(hh / 2.0)) - 1.0));
	m = V - c1;
	if (hh < 1)      { r1 = c1; g1 = x1; b1 = 0; }
	else if (hh < 2) { r1 = x1; g1 = c1; b1 = 0; }
	else if (hh < 3) { r1 = 0; g1 = c1; b1 = x1; }
	else if (hh < 4) { r1 = 0; g1 = x1; b1 = c1; }
	else if (hh < 5) { r1 = x1; g1 = 0; b1 = c1; }
	else             { r1 = c1; g1 = 0; b1 = x1; }
	C.R = byte(FClamp((r1 + m) * 255.0 + 0.5, 0, 255));
	C.G = byte(FClamp((g1 + m) * 255.0 + 0.5, 0, 255));
	C.B = byte(FClamp((b1 + m) * 255.0 + 0.5, 0, 255));
	C.A = 255;
	return C;
}

// Recolour one palette colour for the active window's theme
static function Color Map(Color C)
{
	local float H, Sa, V;

	if ((default.Mode == 1) || (default.Mode == 3))
	{
		// Vanilla+: the menus' blue palette turns to the HUD's gold (or the
		// HUD theme's colour), so the menus match the in-game screens
		if ((default.Mode == 1) && (Class'RIVP'.static.InMenus() || default.bGoldMenus))
		{
			ToHSV(C.R, C.G, C.B, H, Sa, V);
			if ((Sa < 0.08) || (H < 185) || (H > 255))
				return C;
			if (default.bHudOn)
				return FromHSV(default.HudHue + (H - MENU_HUE) * 0.2, FMin(1, Sa * 1.15 * default.HudSat / HUD_SAT), V);
			return FromHSV(HUD_HUE + (H - MENU_HUE) * 0.2, FMin(1, Sa * 1.15), V);
		}
		if (!default.bMenuOn)
			return C;
		ToHSV(C.R, C.G, C.B, H, Sa, V);
		if ((Sa < 0.12) || (H < 185) || (H > 255))
			return C;
		return FromHSV(default.MenuHue + (H - MENU_HUE), Sa * default.MenuSat / MENU_SAT, V);
	}
	if (default.Mode == 2)
	{
		if (!default.bHudOn)
			return C;
		ToHSV(C.R, C.G, C.B, H, Sa, V);
		if ((Sa < 0.15) || (H < 34) || (H > 58))
			return C;
		return FromHSV(default.HudHue + (H - HUD_HUE), Sa * default.HudSat / HUD_SAT, V);
	}
	return C;
}

defaultproperties
{
}
