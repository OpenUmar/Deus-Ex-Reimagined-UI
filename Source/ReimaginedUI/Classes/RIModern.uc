//=============================================================================
// RIModern
// The Modern ("digitized") style kit as static helpers, in screen pixels.
// Same layouts as Sleek; only frames, cells, buttons and HUD slots change:
// chamfered panels (top right and bottom left cut) with a gold edge, a soft
// outer line, an inner keyline, scanlines, corner pips and crosshair ticks,
// an optional title tab; cells with corner brackets; chamfered buttons; and
// Human Revolution style HUD slots (cut corner holding the number, a count
// pill bottom left). Diagonals and corner fills are built from 1 px steps,
// so no textures are needed. Colours follow the active theme (RIUtil.Col).
//=============================================================================
class RIModern extends Object
	abstract;

// Snap to a screen pixel (half a UI unit at 1080p: the engine's UI units are
// two screen pixels each, so whole-unit snapping doubled every line)
static final function float P(float V)
{
	return float(int(V * 2.0 + 0.5)) * 0.5;
}

static final function bool On()
{
	return Class'RIRootWindow'.default.ScreenStyle == 2;
}

static final function Color C(float R, float G, float B, float a)
{
	return Class'RIUtil'.static.Col(R * a, G * a, B * a);
}

static final function Color Gold(float a)  { return C(242, 211, 107, a); }
static final function Color Edge(float a)  { return C(230, 195, 117, a); }
static final function Color Keyl(float a)  { return C(92, 76, 34, a); }
static final function Color Txt(float a)   { return C(255, 241, 194, a); }
static final function Color Lbl(float a)   { return C(156, 134, 72, a); }

// ----------------------------------------------------------------------
// Primitives
// ----------------------------------------------------------------------

// Every piece of a Modern shape (edges, cuts, fills, corner caps) sits on
// the same screen-pixel grid, snapped edge by edge, so the parts of one
// outline meet exactly and move as one piece (in the 3D tilt, where tiles
// aren't rounded, unsnapped edges sat half a pixel off the snapped cuts and
// shimmered against them)
static final function Blk(GC gc, float X, float Y, float W, float H, Color Col)
{
	local float x0, y0, x1, y1;

	if ((W <= 0) || (H <= 0))
		return;
	x0 = P(X);
	y0 = P(Y);
	x1 = P(X + W);
	y1 = P(Y + H);
	if (x1 <= x0)
		x1 = x0 + 0.5;
	if (y1 <= y0)
		y1 = y0 + 0.5;
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Col);
	Class'RIText'.static.Fill(gc, x0, y0, x1 - x0, y1 - y0);
}

static final function Darken(GC gc, float X, float Y, float W, float H)
{
	local float x0, y0, x1, y1;

	x0 = P(X);
	y0 = P(Y);
	x1 = P(X + W);
	y1 = P(Y + H);
	if ((x1 <= x0) || (y1 <= y0))
		return;
	gc.SetStyle(DSTY_Modulated);
	Class'RIText'.static.Tex(gc, x0, y0, x1 - x0, y1 - y0, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dark');
}

// One piece of a shape: Mode 0 darkens, 1 adds Col
static final function Piece(GC gc, int Mode, float X, float Y, float W, float H, Color Col)
{
	local float x0, y0, x1, y1;

	x0 = P(X);
	y0 = P(Y);
	x1 = P(X + W);
	y1 = P(Y + H);
	if ((x1 <= x0) || (y1 <= y0))
		return;
	if (Mode == 0)
		Darken(gc, x0, y0, x1 - x0, y1 - y0);
	else
		Blk(gc, x0, y0, x1 - x0, y1 - y0, Col);
}

// Right triangle in the square X,Y,K: Lower = the half below the "\"
// diagonal (lower left), else the half above it (upper right)
static final function Tri(GC gc, int Mode, float X, float Y, float K, bool bLower, Color Col)
{
	local int i, n;
	local float x0, y0;

	n = int(K * 2.0 + 0.5);          // in screen pixels
	if (n <= 0)
		return;
	x0 = P(X);
	y0 = P(Y);
	// one screen-pixel column at a time (no overlaps, no gaps)
	for (i = 0; i < n; i++)
	{
		if (bLower)
			Piece(gc, Mode, x0 + i * 0.5, y0 + i * 0.5, 0.5, (n - i) * 0.5, Col);
		else if (i > 0)
			Piece(gc, Mode, x0 + i * 0.5, y0, 0.5, i * 0.5, Col);
	}
}

// 45 degree line L long from X,Y: Dir 1 runs right and down, -1 right and up
static final function Diag(GC gc, float X, float Y, float L, float T, int Dir, Color Col)
{
	local int i, n;
	local float x0, y0, tk;

	n = int(L * 2.0 + 0.5);          // one screen pixel per step
	if (n <= 0)
		return;
	tk = FMax(0.5, P(T));
	x0 = P(X);
	y0 = P(Y - T * 0.5);
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Col);
	for (i = 0; i < n; i++)
	{
		if (Dir > 0)
			Class'RIText'.static.Fill(gc, x0 + i * 0.5, y0 + i * 0.5, 0.5, tk);
		else
			Class'RIText'.static.Fill(gc, x0 + i * 0.5, y0 - (i + 1) * 0.5, 0.5, tk);
	}
}

// The outline of a box with the top right and bottom left cut by K, T thick
static final function Outline(GC gc, float X, float Y, float W, float H, float K, float T, Color Col)
{
	Blk(gc, X, Y, W - K, T, Col);                                  // top
	Diag(gc, X + W - K, Y + T * 0.5, K, T, 1, Col);                 // top right cut
	Blk(gc, X + W - T, Y + K, T, H - K, Col);                      // right
	Blk(gc, X + K, Y + H - T, W - K - T, T, Col);                  // bottom
	Diag(gc, X, Y + H - K + T * 0.5, K, T, 1, Col);                 // bottom left cut
	Blk(gc, X, Y + T, T, H - K - T, Col);                          // left
}

// Fill (Mode 0 darken, 1 add Col) of the same cut box
static final function Body(GC gc, int Mode, float X, float Y, float W, float H, float K, Color Col)
{
	if (K * 2 > FMin(W, H))
		K = FMin(W, H) * 0.5;
	Piece(gc, Mode, X, Y, W - K, K, Col);
	Tri(gc, Mode, X + W - K, Y, K, True, Col);
	Piece(gc, Mode, X, Y + K, W, H - 2 * K, Col);
	Tri(gc, Mode, X, Y + H - K, K, False, Col);
	Piece(gc, Mode, X + K, Y + H - K, W - K, K, Col);
}

// Fill of a box with only the top right cut
static final function BodyTR(GC gc, int Mode, float X, float Y, float W, float H, float K, Color Col)
{
	if (K > FMin(W, H))
		K = FMin(W, H);
	Piece(gc, Mode, X, Y, W - K, K, Col);
	Tri(gc, Mode, X + W - K, Y, K, True, Col);
	Piece(gc, Mode, X, Y + K, W, H - K, Col);
}

static final function Scan(GC gc, float X, float Y, float W, float H)
{
	if ((W <= 0) || (H <= 0))
		return;
	gc.SetStyle(DSTY_Modulated);
	Class'RIText'.static.Pat(gc, P(X), P(Y), P(X + W) - P(X), P(Y + H) - P(Y), 0, 0, Texture'ReimaginedUI.UI.RI_Scan');
}

static final function Pip(GC gc, float X, float Y, float Z, Color Col)
{
	Blk(gc, X - Z * 0.5, Y - Z * 0.5, Z, Z, Col);
}

static final function TickMark(GC gc, float X, float Y, float Z, Color Col)
{
	Blk(gc, X - Z, Y, Z * 2, 0.5, Col);
	Blk(gc, X, Y - Z, 0.5, Z * 2, Col);
}

// ----------------------------------------------------------------------
// Panels
// ----------------------------------------------------------------------

// The digitized frame. S is the UI scale (pixels per 1080p pixel). With a
// Title, a tab sits on the top left (the outline steps down past it) and
// the body starts TabH below Y. bBig adds the ruler, the dashed accent
// and the pip row used on full screen frames.
static final function Frame(GC gc, float X, float Y, float W, float H, float S, float a, optional string Title, optional bool bBig)
{
	local float K, th, tw, by, i, Z;
	local int j;

	// the whole frame on the pixel grid first: every part below is measured
	// from these, so they all land on the same pixels
	X = P(X);
	Y = P(Y);
	W = P(W);
	H = P(H);

	if (bBig)
		K = 28 * S;
	else
		K = 16 * S;
	if (Title != "")
	{
		if (bBig)
			th = 34 * S;
		else
			th = 22 * S;
		tw = Class'RIText'.static.Width(Class'RIFontHead', Caps(Title), 0.5) + 44 * S;
	}
	th = P(th);
	tw = P(tw);
	by = Y + th;
	if (K * 2 > FMin(W, H - th))
		K = FMin(W, H - th) * 0.5;
	K = P(K);

	// fill: the world darkened, scanlines, a faint warm lift
	Body(gc, 0, X, by, W, H - th, K, C(0, 0, 0, 0));
	Scan(gc, X + K, by + K, W - 2 * K, H - th - 2 * K);
	Body(gc, 1, X, by, W, H - th, K, C(8, 7, 5, a));
	if (Title != "")
	{
		Darken(gc, X, Y, tw, th);
		Tri(gc, 0, X + tw, Y, th, True, C(0, 0, 0, 0));
		Blk(gc, X, Y, tw, th, C(39, 34, 17, a));
		Tri(gc, 1, X + tw, Y, th, True, C(39, 34, 17, a));
	}

	// soft outer line, then the edge
	Outline(gc, X - 0.5, by - 0.5, W + 1, H - th + 1, K + 0.5, 0.5, C(84, 72, 37, a));
	Outline(gc, X, by, W, H - th, K, FMax(0.5, P(1.25 * S)), Edge(0.85 * a));
	if (Title != "")
	{
		// the tab's own edge: top, slanted end, and the left side above the body
		Blk(gc, X, Y, tw, FMax(0.5, P(1.25 * S)), Edge(0.85 * a));
		Diag(gc, X + tw, Y + 0.5, th, FMax(0.5, P(1.25 * S)), 1, Edge(0.85 * a));
		Blk(gc, X, Y, FMax(0.5, P(1.25 * S)), th, Edge(0.85 * a));
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', X + 22 * S, Y, tw, th, Caps(Title), Txt(a), 0, 0.5);
	}
	// inner keyline
	Outline(gc, X + 5 * S, by + 5 * S, W - 10 * S, H - th - 10 * S, FMax(0.5, K - 3 * S), 0.5, Keyl(0.8 * a));
	// heavier gold on the two cuts
	Diag(gc, X + W - K, by + 0.5, K, FMax(1.0, P(2.5 * S)), 1, Gold(a));
	Diag(gc, X, by + H - th - K + 0.5, K, FMax(1.0, P(2.5 * S)), 1, Gold(a));
	// corner caps: part of the outline, a solid square in its own colour,
	// flush with its outer edges (the two square corners, and where each cut
	// meets a straight side), drawn on the same grid as the rest of it
	Z = P(5 * S);
	Blk(gc, X, by, Z, Z, Edge(0.85 * a));                              // top left
	Blk(gc, X + W - Z, Y + H - Z, Z, Z, Edge(0.85 * a));               // bottom right
	Blk(gc, X + W - Z, P(by + K), Z, Z, Edge(0.85 * a));               // under the top right cut
	Blk(gc, X, P(Y + H - K) - Z, Z, Z, Edge(0.85 * a));                // above the bottom left cut
	// crosshair ticks off two corners
	TickMark(gc, X - 8 * S, Y + H + 8 * S, 5 * S, Keyl(a));
	TickMark(gc, X + W + 8 * S, by - 8 * S, 5 * S, Keyl(a));
	if (bBig)
	{
		// dashed accent along the top, short of the cut
		for (i = 0; i < 180 * S; i += 18 * S)
			Blk(gc, X + W - K - 210 * S + i, by - 1 * S, FMin(14 * S, 180 * S - i), 3 * S, Gold(a));
		// ruler inside the right edge
		for (j = 0; j <= 14; j++)
		{
			if (j % 5 == 0)
				Blk(gc, X + W - 17 * S, by + 68 * S + j * 10 * S, 8 * S, 0.5, Edge(a));
			else
				Blk(gc, X + W - 13 * S, by + 68 * S + j * 10 * S, 4 * S, 0.5, Keyl(a));
		}
		// pip row along the bottom
		for (j = 0; j < 6; j++)
		{
			if (j < 4)
				Blk(gc, X + 176 * S + j * 16 * S, Y + H - 15 * S, 12 * S, 4 * S, Gold(a));
			else
				Blk(gc, X + 176 * S + j * 16 * S, Y + H - 15 * S, 12 * S, 4 * S, C(46, 38, 18, a));
		}
	}
}

// Grid cell: hairline edge, scanlines, brackets on two corners
static final function Cell(GC gc, float X, float Y, float W, float H, float S, bool bSel, float a)
{
	local float b;

	b = 7 * S;
	if (bSel)
	{
		Blk(gc, X, Y, W, H, C(28, 23, 11, a));
		Class'RIText'.static.Box(gc, X, Y, W, H, Edge(a));
		Blk(gc, X - 0.5, Y - 0.5, b, 0.5, Txt(a));
		Blk(gc, X - 0.5, Y - 0.5, 0.5, b, Txt(a));
		Blk(gc, X + W - b + 0.5, Y + H, b, 0.5, Txt(a));
		Blk(gc, X + W, Y + H - b + 0.5, 0.5, b, Txt(a));
	}
	else
	{
		Darken(gc, X, Y, W, H);
		Scan(gc, X, Y, W, H);
		Class'RIText'.static.Box(gc, X, Y, W, H, C(42, 35, 16, a));
		Blk(gc, X - 0.5, Y - 0.5, b, 0.5, C(140, 119, 64, a));
		Blk(gc, X - 0.5, Y - 0.5, 0.5, b, C(140, 119, 64, a));
		Blk(gc, X + W - b + 0.5, Y + H, b, 0.5, C(140, 119, 64, a));
		Blk(gc, X + W, Y + H - b + 0.5, 0.5, b, C(140, 119, 64, a));
	}
}

// Chamfered button (top right cut); the main action gets a gold underline
static final function Btn(GC gc, float X, float Y, float W, float H, float S, string L, bool bLive, bool bHot, bool bPrimary, float a)
{
	local float K;
	local Color E, T;

	K = FMin(12 * S, H * 0.4);
	if (!bLive)
	{
		E = C(58, 48, 22, a);
		T = C(110, 94, 50, a);
	}
	else if (bPrimary || bHot)
	{
		E = Gold(a);
		T = Txt(a);
	}
	else
	{
		E = C(140, 119, 64, a);
		T = Edge(a);
	}
	BodyTR(gc, 0, X, Y, W, H, K, C(0, 0, 0, 0));
	if (bLive && (bPrimary || bHot))
		BodyTR(gc, 1, X, Y, W, H, K, C(32, 27, 13, a));
	OutlineTR(gc, X, Y, W, H, K, 0.5, E);
	if (bLive && bPrimary)
		Blk(gc, X + 1, Y + H - 3 * S, W - 2, 2 * S, Gold(a));
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', X, Y, W, H, Caps(L), T, 1, 0.5);
}

// Outline with only the top right corner cut
static final function OutlineTR(GC gc, float X, float Y, float W, float H, float K, float T, Color Col)
{
	Blk(gc, X, Y, W - K, T, Col);
	Diag(gc, X + W - K, Y + T * 0.5, K, T, 1, Col);
	Blk(gc, X + W - T, Y + K, T, H - K, Col);
	Blk(gc, X, Y + H - T, W - T, T, Col);
	Blk(gc, X, Y + T, T, H - 2 * T, Col);
}

// ----------------------------------------------------------------------
// HUD slots (belt, augs): Human Revolution style
// ----------------------------------------------------------------------

// A slot X,Y,W,H. State: 0 empty, 1 filled, 2 selected / active.
// The top right is cut; Num sits in the corner. Count, if any, goes in a
// pill on the bottom left (gold when selected).
// A slot in the Mankind Divided manner: a file-folder tab rising on the
// top right (a 45 degree step up from the body) holds the number; the
// selected slot gets a bright gold edge and a gold glow behind the icon; a
// count pill sits bottom left. State: 0 empty, 1 filled, 2 selected.
// Returns the top of the body (below the tab), for placing the icon.
static final function float Slot(GC gc, float X, float Y, float W, float H, float S, int State, string Num, string Count, optional bool bWarn)
{
	local float th, tx, T, ph, pw;
	local Color E;

	X = P(X);
	Y = P(Y);
	W = P(W);
	H = P(H);
	th = P(FMax(2.5, H * 0.18));
	tx = X + P(W * 0.46);

	// backing: deep and dark, as the game's; tab and body as one shape,
	// each part darkened the same number of times (the body was darkened
	// twice and the tab once, so the tab showed lighter, with a light
	// square and a gap where its pieces met)
	Piece(gc, 0, X, Y + th, W, H - th, C(0, 0, 0, 0));
	Piece(gc, 0, X, Y + th, W, H - th, C(0, 0, 0, 0));
	TriLR(gc, 0, tx, Y, th, C(0, 0, 0, 0));
	TriLR(gc, 0, tx, Y, th, C(0, 0, 0, 0));
	Piece(gc, 0, tx + th, Y, X + W - tx - th, th, C(0, 0, 0, 0));
	Piece(gc, 0, tx + th, Y, X + W - tx - th, th, C(0, 0, 0, 0));
	// the tab gets the same fill as the body (it read as a black hole)
	if (bWarn)
	{
		Piece(gc, 1, X, Y + th, W, H - th, C(52, 14, 8, 1));
		TriLR(gc, 1, tx, Y, th, C(52, 14, 8, 1));
		Piece(gc, 1, tx + th, Y, X + W - tx - th, th, C(52, 14, 8, 1));
	}
	else
	{
		Piece(gc, 1, X, Y + th, W, H - th, C(16, 14, 10, 1));
		TriLR(gc, 1, tx, Y, th, C(16, 14, 10, 1));
		Piece(gc, 1, tx + th, Y, X + W - tx - th, th, C(16, 14, 10, 1));
	}
	if (State == 2)
	{
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(C(150, 100, 18, 1));
		Class'RIText'.static.Tex(gc, X + W * 0.06, Y + th + (H - th) * 0.02, W * 0.88, (H - th) * 0.9, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_GlowC');
		gc.SetTileColor(C(90, 58, 10, 1));
		Class'RIText'.static.Tex(gc, X + W * 0.2, Y + th + (H - th) * 0.15, W * 0.6, (H - th) * 0.6, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_GlowC');
	}

	if (State == 2)
	{
		E = C(238, 178, 60, 1);
		T = FMax(1.0, P(2 * S));
	}
	else
	{
		if (bWarn)
			E = C(200, 92, 40, 1);
		else if (State == 1)
			E = C(150, 120, 62, 1);
		else
			E = C(98, 82, 46, 1);
		T = 0.5;
	}
	Blk(gc, X, Y + th, T, H - th, E);                       // left
	Blk(gc, X, Y + th, tx - X + 0.5, T, E);                   // body top
	Diag(gc, tx, Y + th + T * 0.5, th, T, -1, E);           // the step up
	Blk(gc, tx + th, Y, X + W - tx - th, T, E);             // tab top
	Blk(gc, X + W - T, Y, T, H, E);                         // right
	Blk(gc, X, Y + H - T, W, T, E);                         // bottom

	if (Num != "")
	{
		if (State == 2)
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', tx + th, Y + 1, X + W - tx - th - 5 * S, th + 6 * S, Num, C(255, 246, 225, 1), 2, 0.46);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', tx + th, Y + 1, X + W - tx - th - 5 * S, th + 6 * S, Num, C(170, 160, 140, 1), 2, 0.46);
	}
	if (Count != "")
	{
		ph = P(FMax(4.5, H * 0.15));
		pw = P(FMax(W * 0.44, Class'RIText'.static.Width(Class'RIFontSmall', Count, 0.42) + 12 * S));
		if (State == 2)
		{
			Blk(gc, X + T + 0.5, Y + H - T - ph - 0.5, pw, ph, C(236, 168, 36, 1));
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X + T + 6 * S, Y + H - T - ph - 1, pw - 6 * S, ph, Count, C(255, 250, 236, 1), 0, 0.42);
		}
		else
		{
			Blk(gc, X + T + 0.5, Y + H - T - ph - 0.5, pw, ph, C(132, 100, 34, 1));
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X + T + 6 * S, Y + H - T - ph - 1, pw - 6 * S, ph, Count, C(214, 196, 150, 1), 0, 0.42);
		}
	}
	return Y + th;
}

// Lower right half of the square X,Y,K (below the "/" diagonal)
static final function TriLR(GC gc, int Mode, float X, float Y, float K, Color Col)
{
	local int i, n;
	local float x0, y0;

	n = int(K * 2.0 + 0.5);
	if (n <= 0)
		return;
	x0 = P(X);
	y0 = P(Y);
	for (i = 0; i < n; i++)
		Piece(gc, Mode, x0 + i * 0.5, y0 + (n - i - 1) * 0.5, 0.5, (i + 1) * 0.5, Col);
}

// Segmented bar (vitals): N blocks, filled up to f
static final function Segs(GC gc, float X, float Y, float W, float H, int N, float f, Color On, Color Off)
{
	local int i, k;
	local float bw;

	bw = (W - (N - 1) * 1.0) / N;
	k = int(FClamp(f, 0, 1) * N + 0.5);
	for (i = 0; i < N; i++)
	{
		if (i < k)
			Blk(gc, X + i * (bw + 1.0), Y, bw, H, On);
		else
			Blk(gc, X + i * (bw + 1.0), Y, bw, H, Off);
	}
}

// A small key cap: a cut corner, the key in the HUD font, gold when lit
static final function KeyCap(GC gc, float X, float Y, float W, float H, float S, string Key, bool bLit)
{
	local float K;

	X = P(X);
	Y = P(Y);
	W = P(W);
	H = P(H);
	K = P(6 * S);
	BodyTR(gc, 0, X, Y, W, H, K, C(0, 0, 0, 0));
	if (bLit)
	{
		BodyTR(gc, 1, X, Y, W, H, K, C(60, 42, 10, 1));
		OutlineTR(gc, X, Y, W, H, K, 0.5, C(238, 178, 60, 1));
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, Y, W, H, Key, C(255, 246, 225, 1), 1, 0.44);
	}
	else
	{
		OutlineTR(gc, X, Y, W, H, K, 0.5, C(110, 92, 52, 1));
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, Y, W, H, Key, C(170, 160, 140, 1), 1, 0.44);
	}
}

// Four corner brackets round X,Y,W,H, L long, 1 px
static final function Brackets(GC gc, float X, float Y, float W, float H, float L, Color Col)
{
	X = P(X);
	Y = P(Y);
	W = P(W);
	H = P(H);
	Blk(gc, X, Y, L, 0.5, Col);
	Blk(gc, X, Y, 0.5, L, Col);
	Blk(gc, X + W - L, Y, L, 0.5, Col);
	Blk(gc, X + W - 0.5, Y, 0.5, L, Col);
	Blk(gc, X, Y + H - 0.5, L, 0.5, Col);
	Blk(gc, X, Y + H - L, 0.5, L, Col);
	Blk(gc, X + W - L, Y + H - 0.5, L, 0.5, Col);
	Blk(gc, X + W - 0.5, Y + H - L, 0.5, L, Col);
}

defaultproperties
{
}
