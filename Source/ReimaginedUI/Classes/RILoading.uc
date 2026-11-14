//=============================================================================
// RILoading
// The loading screens (design: "Loading screens" row on the canvas), drawn
// by the root window over everything, from the level's own state:
//   level change   LOADING, the destination when the engine knows it, a tip
//   loading a save the same, titled for the save (a menu is open)
//   first launch   the title, STARTING (the startup / intro maps)
//   saving         a small chip, bottom right; the game stays visible
//   preparing      PREPARING AREA and the new area's name (precaching)
//   paused         PAUSED (Pause key, no menu open)
// The engine draws a single frame for loading and saving, then stops until
// the map is in, so these are designed as still frames; the wheel turns
// whenever frames keep coming (paused, preparing). The console's own
// LOADING / SAVING / PAUSED text is blanked by the root window.
// Colours follow the HUD theme (see RITheme).
//=============================================================================
class RILoading extends Object
	abstract;

var localized string LoadingLabel, LoadingSaveLabel, StartingLabel, SavingLabel, PreparingLabel;
var localized string PausedLabel, PausedHint, TipLabel, MissionLabel, BrandLabel, TitleLabel, EditionLabel;
var localized string Tips[12];
var int NumTips;
var int TipIndex;          // default.TipIndex: picked once per load
var float LastLoadTime;

static function Color C(float R, float G, float B, optional float a)
{
	if (a == 0)
		a = 1;
	return Class'RIUtil'.static.Col(R * a, G * a, B * a);
}

// Returns True if it drew (so the caller can skip other overlays)
static function bool Draw(GC gc, DeusExPlayer P, float W, float H, int WinCount, string CurMap, float T)
{
	local bool bWas, bDrew;

	// (The old font atlases rendered garbled here. With the plugin's textures
	// now kept alive across map changes, its text is safe on these screens.)
	bDrew = DrawIn(gc, P, W, H, WinCount, CurMap, T);
	return bDrew;
}

static function bool DrawIn(GC gc, DeusExPlayer P, float W, float H, int WinCount, string CurMap, float T)
{
	local LevelInfo L;
	local int act;
	local float S;

	if ((P == None) || (P.Level == None))
		return False;
	L = P.Level;
	act = int(L.LevelAction);
	S = H / 1080.0;
	Class'RITheme'.static.SetMode(2);
	gc.EnableSmoothing(True);

	if (act == 1)
	{
		if (IsStartupMap(CurMap) && (L.NextURL == ""))
			DrawStartup(gc, W, H, S, T);
		else
			DrawLoading(gc, P, W, H, S, T, WinCount > 0);
		return True;
	}
	if (act == 2)
	{
		DrawSaving(gc, P, W, H, S, T);
		return True;
	}
	if (act == 4)
	{
		DrawPreparing(gc, P, W, H, S, T);
		return True;
	}
	if ((L.Pauser != "") && (WinCount <= 0) && !P.bShowMenu)
	{
		DrawPaused(gc, W, H, S, T);
		return True;
	}
	return False;
}

static function bool IsStartupMap(string M)
{
	M = Caps(M);
	return (M == "") || (M == "ENTRY") || (M == "DX") || (M == "DXONLY") || (InStr(M, "INTRO") >= 0);
}

// Soft darkening: n stacked dim layers, heaviest toward the bottom
static function Darken(GC gc, float W, float H, float Amount, float Bottom)
{
	local int i;

	Class'RISkin'.static.DrawDim(gc, 0, 0, W, H, Amount);
	for (i = 1; i <= 6; i++)
		Class'RISkin'.static.DrawDim(gc, 0, H * (1.0 - i * 0.08), W, H * i * 0.08, Bottom / 6.0);
}

// The wheel: twelve marks round a circle, brightest at the head, turning with time
static function Wheel(GC gc, float CX, float CY, float R, float S, float T)
{
	local int i, head;
	local float ang, f, d;

	head = int(T * 12.0) % 12;
	d = 3.2 * S;
	for (i = 0; i < 12; i++)
	{
		ang = (i / 12.0) * 6.2831853 - 1.5707963;
		f = ((i - head + 12) % 12) / 12.0;     // 0 at the head, toward 1 behind it
		f = 1.0 - f;
		Class'RISkin'.static.FillC(gc, CX + Cos(ang) * R - d * 0.5, CY + Sin(ang) * R - d * 0.5, d, d,
			C(70 + 172 * f, 58 + 153 * f, 26 + 81 * f));
	}
}

static function string Tip()
{
	local int n;

	n = 0;
	while ((n < 12) && (default.Tips[n] != ""))
		n++;
	if (n == 0)
		return "";
	return default.Tips[Clamp(default.TipIndex, 0, n - 1) % n];
}

static function PickTip()
{
	default.TipIndex = Rand(12);
}

// "02_NYC_BatteryPark?..." -> mission "02", place "NYC Battery Park"
static function ParseMap(string URL, out string Mission, out string Place)
{
	local int i;
	local string M, Ch, Prev, Out;

	M = URL;
	i = InStr(M, "?");
	if (i >= 0)
		M = Left(M, i);
	i = InStr(M, "#");
	if (i >= 0)
		M = Left(M, i);
	if (Right(Caps(M), 3) == ".DX")
		M = Left(M, Len(M) - 3);
	Mission = "";
	Place = "";
	if (M == "")
		return;
	i = 0;
	while ((i < Len(M)) && (Mid(M, i, 1) >= "0") && (Mid(M, i, 1) <= "9"))
		i++;
	if (i > 0)
	{
		Mission = Left(M, i);
		M = Mid(M, i);
	}
	Out = "";
	Prev = "";
	for (i = 0; i < Len(M); i++)
	{
		Ch = Mid(M, i, 1);
		if (Ch == "_")
			Ch = " ";
		else if ((Ch >= "A") && (Ch <= "Z") && (Prev >= "a") && (Prev <= "z"))
			Out = Out $ " ";
		Out = Out $ Ch;
		Prev = Ch;
	}
	while (Left(Out, 1) == " ")
		Out = Mid(Out, 1);
	Place = Out;
}

// ----------------------------------------------------------------------

static function DrawLoading(GC gc, DeusExPlayer P, float W, float H, float S, float T, bool bFromMenu)
{
	local string Mission, Place, Tp;
	local float x, y, tw;

	if (P.Level.TimeSeconds - default.LastLoadTime > 2.0)
		PickTip();
	default.LastLoadTime = P.Level.TimeSeconds;

	// opaque: the engine doesn't redraw while loading, so the last frame
	// (whatever it was) would otherwise show through
	Class'RIVP'.static.Black(gc, 0, 0, W, H);
	Class'RISkin'.static.FillC(gc, 0, 0, W, H, C(8, 7, 5));
	x = 120 * S;
	ParseMap(P.Level.NextURL, Mission, Place);

	// Destination (when the engine has it), bottom left
	y = H - 150 * S;
	if (Place != "")
	{
		Class'RIText'.static.Draw(gc, Class'RIFontTitle', x, y - 70 * S, Caps(Place), C(255, 241, 194), 0.62);
		if (Mission != "")
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y - 104 * S, Caps(default.MissionLabel) @ Mission, C(168, 143, 78), 0.66);
	}
	else if (bFromMenu)
		Class'RIText'.static.Draw(gc, Class'RIFontTitle', x, y - 70 * S, Caps(default.LoadingSaveLabel), C(255, 241, 194), 0.5);

	// LOADING line with the wheel
	y = H - 96 * S;
	Wheel(gc, x + 11 * S, y + 9 * S, 10 * S, S, T);
	Class'RIText'.static.Draw(gc, Class'RIFontHead', x + 34 * S, y - 2 * S, Caps(default.LoadingLabel), C(242, 211, 107), 0.6);
	tw = Class'RIText'.static.Width(Class'RIFontHead', Caps(default.LoadingLabel), 0.6);
	Class'RISkin'.static.FillC(gc, x + 58 * S + tw, y + 9 * S, W - 240 * S - tw - 58 * S - 180 * S, 1, C(126, 105, 50));
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', W - 120 * S - 170 * S, y, 170 * S, 20 * S, Caps(default.BrandLabel), C(110, 94, 50), 2, 0.5);

	// Tip, bottom right
	Tp = Tip();
	if (Tp != "")
	{
		x = W - 120 * S - 520 * S;
		y = H - 150 * S - 120 * S;
		Class'RISkin'.static.DrawDim(gc, x, y, 520 * S, 110 * S, 0.5);
		Class'RISkin'.static.FillC(gc, x, y, 2 * S, 110 * S, C(242, 211, 107));
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x + 22 * S, y + 16 * S, Caps(default.TipLabel), C(168, 143, 78), 0.56);
		Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x + 22 * S, y + 40 * S, 476 * S, Tp, C(230, 195, 117), 0.7, 1.35);
	}
}

static function DrawStartup(GC gc, float W, float H, float S, float T)
{
	local float cy;

	Class'RIVP'.static.Black(gc, 0, 0, W, H);
	Class'RISkin'.static.FillC(gc, 0, 0, W, H, C(6, 5, 4));
	cy = H * 0.5;
	Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', 0, cy - 90 * S, W, 50 * S, default.TitleLabel, C(255, 241, 194), 1, 0.7);
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', 0, cy - 30 * S, W, 20 * S, Caps(default.EditionLabel), C(168, 143, 78), 1, 0.56);
	Class'RISkin'.static.FillC(gc, W * 0.5 - 180 * S, cy + 6 * S, 360 * S, 1, C(126, 105, 50));
	Wheel(gc, W * 0.5 - 62 * S, cy + 38 * S, 9 * S, S, T);
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', W * 0.5 - 40 * S, cy + 30 * S, Caps(default.StartingLabel), C(242, 211, 107), 0.6);
}

static function DrawSaving(GC gc, DeusExPlayer P, float W, float H, float S, float T)
{
	local float x, y, cw;
	local DeusExLevelInfo Info;
	local string Loc;

	Info = P.GetLevelInfo();
	if (Info != None)
		Loc = Info.MissionLocation;
	cw = 300 * S;
	x = W - 56 * S - cw;
	y = H - 250 * S;
	Class'RISkin'.static.DrawDim(gc, x, y, cw, 60 * S, 0.3);
	Class'RISkin'.static.DrawDim(gc, x + cw * 0.4, y, cw * 0.6, 60 * S, 0.35);
	Class'RISkin'.static.FillC(gc, x + cw - 2 * S, y, 2 * S, 60 * S, C(242, 211, 107));
	Wheel(gc, x + 30 * S, y + 30 * S, 10 * S, S, T);
	Class'RIText'.static.Draw(gc, Class'RIFontHead', x + 56 * S, y + 10 * S, Caps(default.SavingLabel), C(255, 241, 194), 0.52);
	if (Loc != "")
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x + 56 * S, y + 34 * S, Class'RIText'.static.Fit(Class'RIFontSmall', Loc, cw - 70 * S, 0.56), C(168, 143, 78), 0.56);
}

static function DrawPreparing(GC gc, DeusExPlayer P, float W, float H, float S, float T)
{
	local float cy, tw;
	local DeusExLevelInfo Info;
	local string Loc;

	Info = P.GetLevelInfo();
	if (Info != None)
		Loc = Info.MissionLocation;
	// Opaque: while precaching the engine doesn't redraw the world, so
	// whatever was on screen before (the loading frame) would show through
	Class'RIVP'.static.Black(gc, 0, 0, W, H);
	Class'RISkin'.static.FillC(gc, 0, 0, W, H, C(8, 7, 5));
	cy = H * 0.5;
	tw = Class'RIText'.static.Width(Class'RIFontHead', Caps(default.PreparingLabel), 0.56);
	Wheel(gc, (W - tw) * 0.5 - 24 * S, cy - 20 * S, 9 * S, S, T);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', 0, cy - 34 * S, W, 28 * S, Caps(default.PreparingLabel), C(242, 211, 107), 1, 0.56);
	Class'RISkin'.static.FillC(gc, W * 0.5 - 320 * S, cy + 4 * S, 640 * S, 1, C(126, 105, 50));
	if (Loc != "")
		Class'RIText'.static.DrawIn(gc, Class'RIFontBody', 0, cy + 14 * S, W, 28 * S, Loc, C(168, 143, 78), 1, 0.74);
}

static function DrawPaused(GC gc, float W, float H, float S, float T)
{
	local float cy;

	Class'RISkin'.static.DrawDim(gc, 0, 0, W, H, 0.45);
	cy = H * 0.5;
	Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', 0, cy - 46 * S, W, 44 * S, Caps(default.PausedLabel), C(255, 241, 194), 1, 0.6);
	Class'RISkin'.static.FillC(gc, W * 0.5 - 140 * S, cy + 6 * S, 280 * S, 1, C(126, 105, 50));
	Class'RIText'.static.DrawIn(gc, Class'RIFontBody', 0, cy + 16 * S, W, 26 * S, default.PausedHint, C(168, 143, 78), 1, 0.72);
}

defaultproperties
{
     LoadingLabel="Loading"
     LoadingSaveLabel="Loading saved game"
     StartingLabel="Starting"
     SavingLabel="Saving"
     PreparingLabel="Preparing area"
     PausedLabel="Paused"
     PausedHint="Press Pause to resume"
     TipLabel="Tip"
     MissionLabel="Mission"
     BrandLabel="Reimagined UI"
     TitleLabel="DEUS EX"
     EditionLabel="Deus Ex  //  Reimagined UI"
     Tips(0)="Lockpicks open mechanical locks. Multitools bypass electronic security such as keypads, cameras and turrets."
     Tips(1)="Read books and datacubes: many hold door codes and passwords, which are saved to your notes."
     Tips(2)="Crouching and walking make far less noise than running."
     Tips(3)="Upgrade canisters raise an augmentation's level. Bioelectric cells restore its energy."
     Tips(4)="A higher Medicine skill makes every medkit heal more."
     Tips(5)="Look for vents, ladders and side doors: there is usually more than one way in."
     Tips(6)="Turrets and cameras can be turned against their owners from a security terminal."
     Tips(7)="Heavy objects can be stacked to reach high ledges."
     Tips(8)="Talking to people first can open doors that would otherwise need force."
     Tips(9)="Thrown objects make noise that can draw a guard away from his post."
     Tips(10)="The Health screen shows each body part. Heal the head and torso first: if either fails, so do you."
     Tips(11)="Keep an eye on your bioelectric energy: active augmentations drain it steadily."
}
