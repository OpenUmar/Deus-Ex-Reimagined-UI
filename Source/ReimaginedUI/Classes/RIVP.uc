//=============================================================================
// RIVP
// The Vanilla+ kit as static helpers, in screen pixels, for windows that
// don't extend RIPersonaView (HUD, dialogue, subtitles, InfoLink, menus).
// Colours go through RIUtil.Col, so they follow the active theme.
//=============================================================================
class RIVP extends Object
	abstract;

static final function bool On()
{
	return Class'RIRootWindow'.default.ScreenStyle == 1;
}

static final function Color C(float R, float G, float B, float a)
{
	return Class'RIUtil'.static.Col(R * a, G * a, B * a);
}

static final function Color Txt(float a)  { return C(240, 222, 178, a); }
static final function Color Lbl(float a)  { return C(170, 145, 90, a); }
static final function Color Acc(float a)  { return C(230, 195, 117, a); }
static final function Color Edge(float a) { return C(150, 126, 62, a); }

// Vanilla+ for menu widgets: everywhere except the main menu itself
static final function bool InMenus()
{
	return False;      // Vanilla+ is for the HUD, dialogue and in-game screens only
}

// A texture piece on exact screen pixels: both edges snapped, so pieces that
// share an edge abut with no overlap (no bright seams on additive frames)
static final function TileR(GC gc, float X, float Y, float W, float H, float U, float V, float UL, float VL, Texture T)
{
	local float x0, y0, x1, y1;

	if ((T == None) || (W <= 0) || (H <= 0))
		return;
	x0 = Class'RIText'.static.Snap(X);
	y0 = Class'RIText'.static.Snap(Y);
	x1 = Class'RIText'.static.Snap(X + W);
	y1 = Class'RIText'.static.Snap(Y + H);
	if ((x1 <= x0) || (y1 <= y0))
		return;
	// Ctrl+F10 then Ctrl+F8 (atlas text) turns every native draw off, to test without the plugin
	if (Class'RIText'.default.bAtlasText)
	{
		gc.DrawStretchedTexture(x0, y0, x1 - x0, y1 - y0, U, V, UL, VL, T);
		return;
	}
	Class'RINative'.static.RINativeDrawTile(gc, T, x0, y0, x1 - x0, y1 - y0, U, V, UL, VL);
}

// Opaque black (for panels that must hide the world behind them)
static final function Black(GC gc, float X, float Y, float W, float H)
{
	gc.SetStyle(DSTY_Normal);
	gc.SetTileColor(Class'RIUtil'.static.Raw(255, 255, 255));
	gc.DrawStretchedTexture(X, Y, W, H, 0, 0, 1, 1, Texture'ReimaginedUI.UI.RI_Clear');
}

// Darken what's behind (modulated), for HUD panels over the world
static final function Dim(GC gc, float X, float Y, float W, float H)
{
	gc.SetStyle(DSTY_Modulated);
	gc.DrawStretchedTexture(X, Y, W, H, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dark');
}

// Rounded 9-slice frame; K is the corner size in pixels
static final function Frame(GC gc, float X, float Y, float W, float H, float K, float a)
{
	if ((W <= 2 * K) || (H <= 2 * K))
		K = FMin(W, H) * 0.5;
	Class'RISkin'.static.FillC(gc, X + K * 0.2, Y + K * 0.2, W - K * 0.4, H - K * 0.4, C(46, 39, 20, a));
	Edges(gc, X, Y, W, H, K, a);
	DXAround(gc, X, Y, W, H, K / 16.0, a);
}

// The original Deus Ex HUD window border (HUDWindowBorder_*, 4x HD when
// available), tiled round X,Y,W,H at scale K and tinted to the theme. Vanilla+
// draws it round every frame so the screens keep the game's own trim.
static final function DXBorder(GC gc, float X, float Y, float W, float H, float K, float a)
{
	local Texture TL, TR, BL, BR, L, R, T, B;
	local float cw, ch, cw2, ch2, e, p, step;

	TL = Texture'DeusExUI.UserInterface.HUDWindowBorder_TL';
	TR = Texture'DeusExUI.UserInterface.HUDWindowBorder_TR';
	BL = Texture'DeusExUI.UserInterface.HUDWindowBorder_BL';
	BR = Texture'DeusExUI.UserInterface.HUDWindowBorder_BR';
	L  = Texture'DeusExUI.UserInterface.HUDWindowBorder_Left';
	R  = Texture'DeusExUI.UserInterface.HUDWindowBorder_Right';
	T  = Texture'DeusExUI.UserInterface.HUDWindowBorder_Top';
	B  = Texture'DeusExUI.UserInterface.HUDWindowBorder_Bottom';
	cw = TL.USize * K;
	ch = TL.VSize * K;
	cw2 = BR.USize * K;
	ch2 = BR.VSize * K;
	if ((cw + cw2 > W) || (ch + ch2 > H))
		return;
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C(210, 178, 108, a));
	Class'RIHD'.static.DrawExact(gc, X, Y, cw, ch, 0, 0, TL.USize, TL.VSize, TL);
	Class'RIHD'.static.DrawExact(gc, X + W - TR.USize * K, Y, TR.USize * K, TR.VSize * K, 0, 0, TR.USize, TR.VSize, TR);
	Class'RIHD'.static.DrawExact(gc, X, Y + H - BL.VSize * K, BL.USize * K, BL.VSize * K, 0, 0, BL.USize, BL.VSize, BL);
	Class'RIHD'.static.DrawExact(gc, X + W - cw2, Y + H - ch2, cw2, ch2, 0, 0, BR.USize, BR.VSize, BR);

	// edges tiled at their own size (stretching would smear the detail)
	step = T.USize * K;
	e = X + W - TR.USize * K;
	for (p = X + cw; (p < e) && (step > 0); p += step)
		Class'RIHD'.static.DrawExact(gc, p, Y, FMin(step, e - p), T.VSize * K, 0, 0, FMin(T.USize, (e - p) / K), T.VSize, T);
	step = B.USize * K;
	e = X + W - cw2;
	for (p = X + BL.USize * K; (p < e) && (step > 0); p += step)
		Class'RIHD'.static.DrawExact(gc, p, Y + H - B.VSize * K, FMin(step, e - p), B.VSize * K, 0, 0, FMin(B.USize, (e - p) / K), B.VSize, B);
	step = L.VSize * K;
	e = Y + H - BL.VSize * K;
	for (p = Y + ch; (p < e) && (step > 0); p += step)
		Class'RIHD'.static.DrawExact(gc, X, p, L.USize * K, FMin(step, e - p), 0, 0, L.USize, FMin(L.VSize, (e - p) / K), L);
	step = R.VSize * K;
	e = Y + H - ch2;
	for (p = Y + TR.VSize * K; (p < e) && (step > 0); p += step)
		Class'RIHD'.static.DrawExact(gc, X + W - R.USize * K, p, R.USize * K, FMin(step, e - p), 0, 0, R.USize, FMin(R.VSize, (e - p) / K), R);
}

// The DX border placed so its line runs just outside the frame X,Y,W,H (the
// art's line sits about 9 px down, 6 in from the left, 3 from the right and
// 6 up from the bottom of its pieces)
static final function DXAround(GC gc, float X, float Y, float W, float H, float K, float a)
{
	DXBorder(gc, X - 9 * K, Y - 12 * K, W + 15 * K, H + 21 * K, K, a);
}

// Just the frame's edges, no fill
static final function Edges(GC gc, float X, float Y, float W, float H, float K, float a)
{
	local Texture T;

	if ((W <= 2 * K) || (H <= 2 * K))
		K = FMin(W, H) * 0.5;
	T = Texture'ReimaginedUI.VPlus.VPK_Frame';
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C(230, 195, 117, a));
	TileR(gc, X, Y, K, K, 0.5, 0.5, 15.5, 15.5, T);
	TileR(gc, X + K, Y, W - 2 * K, K, 16, 0.5, 32, 15.5, T);
	TileR(gc, X + W - K, Y, K, K, 48, 0.5, 15.5, 15.5, T);
	TileR(gc, X, Y + K, K, H - 2 * K, 0.5, 16, 15.5, 32, T);
	TileR(gc, X + W - K, Y + K, K, H - 2 * K, 48, 16, 15.5, 32, T);
	TileR(gc, X, Y + H - K, K, K, 0.5, 48, 15.5, 15.5, T);
	TileR(gc, X + K, Y + H - K, W - 2 * K, K, 16, 48, 32, 15.5, T);
	TileR(gc, X + W - K, Y + H - K, K, K, 48, 48, 15.5, 15.5, T);
}

// HUD panels: the world darkened behind (no tinted fill, so it stays see-
// through and dark), a slim gold edge
static final function Panel(GC gc, float X, float Y, float W, float H, float K, float a)
{
	Dim(gc, X + K * 0.25, Y + K * 0.25, W - K * 0.5, H - K * 0.5);
	Class'RISkin'.static.FillC(gc, X + K * 0.25, Y + K * 0.25, W - K * 0.5, H - K * 0.5, C(10, 8, 3, a));
	Edges(gc, X, Y, W, H, K, 0.7 * a);
}

// Chamfered button
static final function Btn(GC gc, float X, float Y, float W, float H, bool bLit, float a)
{
	local float lw, rw;
	local Texture T;

	lw = 8 * H / 32;
	rw = 24 * H / 32;
	// square-ish cells (HUD slots): shrink the caps so the middle survives
	if (lw + rw > W * 0.6)
	{
		lw *= W * 0.6 / (lw + rw + 0.001);
		rw = lw * 3;
	}
	if (bLit)
		T = Texture'ReimaginedUI.VPlus.VPK_BtnLit';
	else
		T = Texture'ReimaginedUI.VPlus.VPK_Btn';
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C(230, 195, 117, a));
	TileR(gc, X, Y, lw, H, 0.5, 0.5, 7.5, 31, T);
	TileR(gc, X + lw, Y, W - lw - rw, H, 8, 0.5, 32, 31, T);
	TileR(gc, X + W - rw, Y, rw, H, 40, 0.5, 23.5, 31, T);
}

// Header tab (diagonal right end)
static final function Hdr(GC gc, float X, float Y, float W, float H, float a)
{
	local float lw, rw;
	local Texture T;

	lw = 16 * H / 32;
	rw = 48 * H / 32;
	T = Texture'ReimaginedUI.VPlus.VPK_Hdr';
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C(230, 195, 117, a));
	TileR(gc, X, Y, lw, H, 0.5, 0.5, 15.5, 31, T);
	TileR(gc, X + lw, Y, W - lw - rw, H, 16, 0.5, 64, 31, T);
	TileR(gc, X + W - rw, Y, rw, H, 80, 0.5, 47.5, 31, T);
}

static final function Inset(GC gc, float X, float Y, float W, float H, float a)
{
	Class'RIText'.static.Box(gc, X, Y, W, H, C(170, 143, 70, a));
}

defaultproperties
{
}
