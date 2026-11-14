//=============================================================================
// RICrosshair
// AE's crosshair (same show / hide and friend / foe colour) as a modern
// customisable crosshair, set up in Settings > Interface > Crosshair:
// presets; the outer shape (cross, the original game's bracket reticle,
// circle, brackets, chevron, none) and the inner mark at the centre (none,
// dot, plus, the original game's cross, ring) with its size; colour, length,
// gap, thickness, outline, T-shape, dynamic spread, rifle scopes. Sizes are
// screen pixels at 1080p. Everything is drawn on exact pixels and an even
// number of pixels wide round the exact screen centre, so it's centred.
// Dynamic spread shows the weapon's real spread: the game's own scatter for
// the held weapon (RIBase.ShotSpread: instant-hit and projectile rules, scope
// and laser) projected through the current field of view, so the arms sit
// where the shots can land, zoomed or not. It replaces the game's separate
// bracket reticle (see RIAugDisplay). The window covers the whole HUD and
// finds the exact screen centre itself (the HUD places a crosshair window
// half a unit off centre). With the HUD on Classic it draws AE's CrossSquare.
//=============================================================================
class RICrosshair extends Crosshair;

var globalconfig int   XPreset;      // 0 custom, then the presets (RIChoiceXPreset)
var globalconfig int   XShape;       // outer: 0 cross, 1 original reticle, 2 circle, 3 brackets, 4 chevron, 5 none
var globalconfig int   XInner;       // inner: 0 none, 1 dot, 2 plus, 3 original cross, 4 ring
var globalconfig float XInnerSize;   // the inner mark's size (pixels at 1080p)
var globalconfig int   XColor;       // 0 the game's friend / foe colour, then fixed colours
var globalconfig float XLen, XGap, XThick;
var globalconfig bool  XOutline, XTShape, XDynamic, XInScope;
var globalconfig bool  XDot;         // (replaced by XInner; kept so old rows still compile)

var Color CrossCol;
var float Spread;              // eased spread, UI units

event InitWindow()
{
	Super.InitWindow();
	SetBackground(None);
	bTickEnabled = True;
}

function SetCrosshairColor(color newColor)
{
	CrossCol = newColor;
	Super.SetCrosshairColor(newColor);
}

// The scope hides the crosshair (AE every tick); with "show in rifle scopes"
// on it stays (not through binoculars)
function SetCrosshair(bool bShow)
{
	local DeusExPlayer P;

	if (!bShow && RIOn() && default.XInScope && Class'RIUtil'.static.Scoped(Self) && !Binocs())
	{
		P = DeusExPlayer(GetRootWindow().parentPawn);
		if ((P != None) && P.bCrosshairVisible)
			bShow = True;
	}
	Super.SetCrosshair(bShow);
}

function bool Binocs()
{
	local DeusExRootWindow R;

	R = DeusExRootWindow(GetRootWindow());
	return (R != None) && (R.scopeView != None) && R.scopeView.bBinocs;
}

event ParentRequestedPreferredSize(bool bWidthSpecified, out float preferredWidth,
                                   bool bHeightSpecified, out float preferredHeight)
{
	preferredWidth = 16;
	preferredHeight = 16;
	if (RIOn() && (GetParent() != None))
	{
		preferredWidth = GetParent().width;
		preferredHeight = GetParent().height;
	}
}

function bool RIOn()
{
	return (RIDeusExHUD(GetParent()) != None) && RIDeusExHUD(GetParent()).bRI;
}

// The held weapon's real spread on screen, in UI units from the centre:
// the tangent of its scatter angle over the tangent of half the view's FOV,
// times half the screen's width
function float WantSpread()
{
	local DeusExPlayer P;
	local float fov, t, hw;

	P = DeusExPlayer(GetRootWindow().parentPawn);
	if ((P == None) || (DeusExWeapon(P.Weapon) == None))
		return 0;
	t = Class'RIBase'.static.ShotSpread(DeusExWeapon(P.Weapon));
	if (t <= 0)
		return 0;
	fov = P.FOVAngle;
	if ((fov < 1) || (fov > 170))
		fov = 90;
	hw = width * 0.5;
	if (GetParent() != None)
		hw = GetParent().width * 0.5;
	return FMin(t / Tan(fov * Pi / 360.0) * hw, height * 0.45);
}

event Tick(float deltaSeconds)
{
	if (!RIOn())
		return;
	// the window follows the HUD's size (it was laid out at 16 x 16 before)
	if ((GetParent() != None) && ((width != GetParent().width) || (height != GetParent().height)))
		AskParentForReconfigure();
	Spread += (WantSpread() - Spread) * FMin(1.0, deltaSeconds * 14.0);
}

event DrawWindow(GC gc)
{
	local float cx, cy;

	if (!RIOn())
	{
		gc.SetStyle(DSTY_Masked);
		gc.SetTileColor(CrossCol);
		gc.DrawTexture((width - 16) * 0.5, (height - 16) * 0.5, 16, 16, 0, 0, Texture'CrossSquare');
		return;
	}
	// scopes: only with "show in rifle scopes" on; never through binoculars
	if (Class'RIUtil'.static.Scoped(Self) && (!default.XInScope || Binocs()))
		return;
	// the exact centre of the HUD, in this window's coordinates
	cx = width * 0.5;
	cy = height * 0.5;
	if (GetParent() != None)
		ConvertCoordinates(GetParent(), GetParent().width * 0.5, GetParent().height * 0.5, Self, cx, cy);
	DrawCross(gc, cx, cy, 1.0, CrossCol, Spread);
}

// ----------------------------------------------------------------------
// The crosshair itself (also the settings page's preview). K scales it
// (1 = in game); GameCol is the friend / foe colour; Sp the spread (units).
// Outlines are all drawn first (pass 0), then the colour (pass 1).
// ----------------------------------------------------------------------

static function DrawCross(GC gc, float cx, float cy, float K, Color GameCol, float Sp)
{
	local float t, len, gap, r, n, k2;
	local int pass;
	local Color C;

	C = XCol(GameCol);
	// thickness: whole UI units (even pixels), so strokes straddle the centre
	t = FMax(1, float(int(default.XThick * 0.5 + 0.5))) * K;
	len = default.XLen * 0.5 * K;
	gap = default.XGap * 0.5 * K;
	if (!default.XDynamic)
		Sp = 0;
	r = gap + Sp * K;
	r = float(int(r * 2 + 0.5)) * 0.5;            // on the pixel grid, same both sides
	n = FMax(1, float(int(default.XInnerSize * 0.5 + 0.5))) * K;
	cx = Class'RIText'.static.Snap(cx);
	cy = Class'RIText'.static.Snap(cy);

	for (pass = 0; pass < 2; pass++)
	{
		if ((pass == 0) && !default.XOutline)
			continue;

		// outer: the spread
		switch (default.XShape)
		{
			case 0:
				if (len > 0)
				{
					XStroke(gc, cx - r - len, cy - t * 0.5, len, t, C, pass, K);
					XStroke(gc, cx + r, cy - t * 0.5, len, t, C, pass, K);
					XStroke(gc, cx - t * 0.5, cy + r, t, len, C, pass, K);
					if (!default.XTShape)
						XStroke(gc, cx - t * 0.5, cy - r - len, t, len, C, pass, K);
				}
				break;
			case 1:
				// stem as long as Length (at least the line's own thickness),
				// the cap across its end the original's fixed width
				OldReticle(gc, cx, cy, r + 4 * K, FMax(t, len), 3 * K, t, C, pass, K);
				break;
			case 2:
				Ring(gc, cx, cy, FMax(r, t * 2), t, C, pass, K);
				break;
			case 3:
				Corners(gc, cx, cy, FMax(r, t), FMax(len, t * 2), t, C, pass, K);
				break;
			case 4:
				Seg(gc, cx, cy + r, cx - len * 0.75, cy + r + len * 0.75, t, C, pass, K);
				Seg(gc, cx, cy + r, cx + len * 0.75, cy + r + len * 0.75, t, C, pass, K);
				break;
		}

		// inner: the mark at the centre
		switch (default.XInner)
		{
			case 1:
				XStroke(gc, cx - n * 0.5, cy - n * 0.5, n, n, C, pass, K);
				break;
			case 2:
				XStroke(gc, cx - n, cy - t * 0.5, n * 2, t, C, pass, K);
				XStroke(gc, cx - t * 0.5, cy - n, t, n * 2, C, pass, K);
				break;
			case 3:
				// the game's own cross (the HD texture is centred: its arms
				// span texels 28-35 of 64), on exact pixels; size 8 = as the game
				if (pass == 1)
				{
					k2 = default.XInnerSize / 8.0 * K;
					gc.SetStyle(DSTY_Masked);
					gc.SetTileColor(C);
					Class'RIHD'.static.DrawExact(gc, cx - 8 * k2, cy - 8 * k2, 16 * k2, 16 * k2, 0, 0, 16, 16, Texture'CrossSquare');
				}
				break;
			case 4:
				Ring(gc, cx, cy, FMax(n, t * 1.5), t, C, pass, K);
				break;
		}
	}
}

// Pass 0: the dark outline (one pixel round); pass 1: the colour
static function XStroke(GC gc, float X, float Y, float W, float H, Color C, int Pass, float K)
{
	local float o;

	gc.SetStyle(DSTY_Normal);
	if (Pass == 0)
	{
		o = 0.5 * K;
		gc.SetTileColor(Class'RIUtil'.static.Raw(8, 8, 8));
		Class'RIText'.static.Fill(gc, X - o, Y - o, W + o * 2, H + o * 2);
		return;
	}
	gc.SetTileColor(C);
	Class'RIText'.static.Fill(gc, X, Y, W, H);
}

// A line from (X1,Y1) to (X2,Y2), T thick: small squares along it
static function Seg(GC gc, float X1, float Y1, float X2, float Y2, float T, Color C, int Pass, float K)
{
	local int i, n;
	local float d, f;

	d = Sqrt((X2 - X1) * (X2 - X1) + (Y2 - Y1) * (Y2 - Y1));
	n = Clamp(int(d / (T * 0.5)) + 1, 2, 200);
	for (i = 0; i <= n; i++)
	{
		f = float(i) / float(n);
		XStroke(gc, X1 + (X2 - X1) * f - T * 0.5, Y1 + (Y2 - Y1) * f - T * 0.5, T, T, C, Pass, K);
	}
}

// A circle of radius R, T thick
static function Ring(GC gc, float cx, float cy, float R, float T, Color C, int Pass, float K)
{
	local int i, n;
	local float a;

	n = Clamp(int(R * 6.2832 / (T * 0.5)), 16, 240);
	for (i = 0; i < n; i++)
	{
		a = float(i) / float(n) * 6.2832;
		XStroke(gc, cx + Cos(a) * R - T * 0.5, cy + Sin(a) * R - T * 0.5, T, T, C, Pass, K);
	}
}

// Four corner brackets round the centre at distance R, arms L long
static function Corners(GC gc, float cx, float cy, float R, float L, float T, Color C, int Pass, float K)
{
	local int i;
	local float dx, dy, x, y;

	for (i = 0; i < 4; i++)
	{
		dx = 1;
		dy = 1;
		if ((i == 1) || (i == 3))
			dx = -1;
		if (i >= 2)
			dy = -1;
		x = cx + dx * R;
		y = cy + dy * R;
		// horizontal arm toward the centre line, vertical arm likewise
		if (dx > 0)
			XStroke(gc, x - L, y - T * 0.5, L, T, C, Pass, K);
		else
			XStroke(gc, x, y - T * 0.5, L, T, C, Pass, K);
		if (dy > 0)
			XStroke(gc, x - T * 0.5, y - L, T, L, C, Pass, K);
		else
			XStroke(gc, x - T * 0.5, y, T, L, C, Pass, K);
	}
}

// The original game's accuracy reticle: four stems pointing in to the
// centre from distance R, L long, each with a cap W wide across its outer end
static function OldReticle(GC gc, float cx, float cy, float R, float L, float W, float T, Color C, int Pass, float K)
{
	XStroke(gc, cx - T * 0.5, cy - R, T, L, C, Pass, K);
	XStroke(gc, cx - W * 0.5, cy - R - T * 0.5, W, T, C, Pass, K);
	XStroke(gc, cx - T * 0.5, cy + R - L, T, L, C, Pass, K);
	XStroke(gc, cx - W * 0.5, cy + R - T * 0.5, W, T, C, Pass, K);
	XStroke(gc, cx - R, cy - T * 0.5, L, T, C, Pass, K);
	XStroke(gc, cx - R - T * 0.5, cy - W * 0.5, T, W, C, Pass, K);
	XStroke(gc, cx + R - L, cy - T * 0.5, L, T, C, Pass, K);
	XStroke(gc, cx + R - T * 0.5, cy - W * 0.5, T, W, C, Pass, K);
}

static function Color XCol(Color GameCol)
{
	switch (default.XColor)
	{
		case 1: return Class'RIUtil'.static.Raw(255, 255, 255);
		case 2: return Class'RIUtil'.static.Raw(80, 255, 80);
		case 3: return Class'RIUtil'.static.Raw(255, 230, 60);
		case 4: return Class'RIUtil'.static.Raw(60, 230, 255);
		case 5: return Class'RIUtil'.static.Raw(255, 70, 70);
		case 6: return Class'RIUtil'.static.Raw(255, 90, 255);
	}
	return GameCol;
}

// ----------------------------------------------------------------------
// Settings (Settings > Interface > Crosshair)
// ----------------------------------------------------------------------

// All of a preset's values at once (inside a switch a statement can't begin
// "default.", it reads as the default: label, hence this setter)
static function SetAll(int Shape, float L, float G, float T, int Inner, float IS, bool bTS, bool bDyn)
{
	default.XShape = Shape;
	default.XLen = L;
	default.XGap = G;
	default.XThick = T;
	default.XInner = Inner;
	default.XInnerSize = IS;
	default.XTShape = bTS;
	default.XDynamic = bDyn;
	default.XOutline = True;
}

static function ApplyPreset(int P)
{
	switch (P)
	{
		case 1:  SetAll(1, 12, 4, 2,  1, 2, False, True);  break;    // Default: the original reticle, a dot
		case 2:  SetAll(1, 6, 10, 2,  3, 8, False, True);  break;    // Classic: the original cross and reticle
		case 3:  SetAll(0, 6,  2, 2,  0, 2, False, True);  break;    // Tight
		case 4:  SetAll(5, 0,  0, 2,  1, 4, False, False); break;    // Dot
		case 5:  SetAll(0, 10, 5, 2,  0, 2, True,  True);  break;    // T-shape
		case 6:  SetAll(0, 16, 10, 2, 1, 2, False, True);  break;    // Large
		case 7:  SetAll(2, 10, 10, 2, 1, 2, False, True);  break;    // Circle
		case 8:  SetAll(3, 6, 10, 2,  1, 2, False, True);  break;    // Brackets
		case 9:  SetAll(4, 10, 2, 2,  0, 2, False, False); break;    // Chevron
		case 10: SetAll(0, 4,  3, 2,  1, 2, False, True);  break;    // Micro
		case 11: SetAll(5, 0,  0, 2,  2, 8, False, False); break;    // Plus
		case 12: SetAll(5, 0,  0, 2,  4, 8, False, False); break;    // Ring
	}
	default.XPreset = P;
	StaticSaveConfig();
}

// Any hand change: the preset becomes Custom
static function Changed()
{
	default.XPreset = 0;
	StaticSaveConfig();
}

// Reload every row of the settings page W sits on (after a preset, so the
// rows show its values; after a change, so Preset shows Custom)
static function RefreshPage(Window W)
{
	while ((W != None) && (MenuUIScreenWindow(W) == None))
		W = W.GetParent();
	if (W != None)
		MenuUIScreenWindow(W).LoadSettings();
}

defaultproperties
{
     CrossCol=(R=255,G=255,B=255)
     XPreset=1
     XShape=1
     XInner=1
     XInnerSize=2.000000
     XColor=0
     XLen=12.000000
     XGap=4.000000
     XThick=2.000000
     XDot=True
     XOutline=True
     XTShape=False
     XDynamic=True
     XInScope=True
}
