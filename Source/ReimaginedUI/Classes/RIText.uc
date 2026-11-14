//=============================================================================
// RIText
// Draws text from the baked font atlases at full screen resolution.
// The engine scales all UI 2x at 1080p (one UI unit = two screen pixels), so
// glyphs baked at 2x and drawn at half size land 1:1 on screen pixels: crisp,
// anti-aliased text instead of pixel-doubled bitmap fonts.
//=============================================================================
class RIText extends ExtensionObject
	abstract;

const PX = 0.5;     // UI units per atlas pixel

// Text is drawn by RINative.dll (rasterised at the exact screen pixel size,
// pixel-aligned, kerned). The baked atlases remain as a fallback; the debug
// overlay's Ctrl+F8 switches between the two for comparison.
var bool bAtlasText;
var float TextMul;     // set round a whole part of the UI (HUD size, subtitle size); 0 = 1
// 3D panels: while b3D is set (between Begin3D and End3D) every texture
// drawn through Tex / TexAt / Pat goes through the plugin, which draws it in
// perspective; otherwise they are exactly the GC's own calls
var bool b3D;
var int  Native3D;     // the plugin can do 3D: 0 not checked yet, 1 yes, 2 no (an older RINative.dll)

static final function float M()
{
	if (default.TextMul <= 0)
		return 1.0;
	return default.TextMul;
}

// Each RIFont maps to an embedded font and its size / letter spacing in UI
// units (half the atlas pixel values, as the atlases were baked at 2x)
static function NativeFont(Class<RIFont> F, out int Id, out float Size, out float Spacing)
{
	if (F == Class'RIFontTitle')      { Id = 0; Size = 20.0; Spacing = 1.5; }
	else if (F == Class'RIFontHead')  { Id = 0; Size = 12.0; Spacing = 1.0; }
	else if (F == Class'RIFontSmall') { Id = 2; Size = 9.0;  Spacing = 0.5; }
	else                              { Id = 1; Size = 12.0; Spacing = 0.0; }
}

// Round to the nearest screen pixel (half a UI unit) so text never shimmers
static final function float Snap(float V)
{
	return float(int(V * 2.0 + 0.5)) * 0.5;
}

static final function int Glyph(string S, int i)
{
	local int c;

	c = Asc(Mid(S, i, 1)) - 32;
	if ((c < 0) || (c > 94))
		c = 31;      // '?' for anything outside printable ASCII
	return c;
}

static function float Width(Class<RIFont> F, string S, optional float Scale)
{
	local int i, Id;
	local float w, Size, Spacing;

	if (Scale == 0)
		Scale = 1;
	if (!default.bAtlasText)
	{
		NativeFont(F, Id, Size, Spacing);
		return Class'RINative'.static.RINativeTextWidth(Id, Size * Scale * M(), Spacing * Scale * M(), S);
	}
	for (i = 0; i < Len(S); i++)
		w += F.static.GetAdv(Glyph(S, i));
	return w * PX * Scale;
}

static function float LineHeight(Class<RIFont> F, optional float Scale)
{
	local int Id;
	local float Size, Spacing;

	if (Scale == 0)
		Scale = 1;
	if (!default.bAtlasText)
	{
		NativeFont(F, Id, Size, Spacing);
		return Class'RINative'.static.RINativeAscent(Id, Size * Scale * M()) + Class'RINative'.static.RINativeDescent(Id, Size * Scale * M());
	}
	return (F.default.Ascent + F.default.Descent) * PX * Scale;
}

// Draw with the top of the line at Y
static function Draw(GC gc, Class<RIFont> F, float X, float Y, string S, Color C, optional float Scale)
{
	local int i, g, Id;
	local float k, pen, base, Size, Spacing;

	if (Scale == 0)
		Scale = 1;
	if (!default.bAtlasText)
	{
		NativeFont(F, Id, Size, Spacing);
		Class'RINative'.static.RINativeDrawText(gc, Id, X, Y, S, C, Size * Scale * M(), Spacing * Scale * M());
		return;
	}
	k = PX * Scale;
	base = Snap(Y + F.default.Ascent * k);
	pen = Snap(X);

	gc.EnableSmoothing(True);
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C);

	for (i = 0; i < Len(S); i++)
	{
		g = Glyph(S, i);
		if (F.static.GetGW(g) > 0)
			gc.DrawStretchedTexture(
				Snap(pen + F.static.GetGXO(g) * k), base + F.static.GetGYO(g) * k,
				F.static.GetGW(g) * k, F.static.GetGH(g) * k,
				F.static.GetGX(g), F.static.GetGY(g), F.static.GetGW(g), F.static.GetGH(g),
				F.default.Atlas);
		pen += F.static.GetAdv(g) * k;
	}
}

// Draw inside a box: HAlign 0 = left, 1 = centre, 2 = right; always centred vertically
static function DrawIn(GC gc, Class<RIFont> F, float X, float Y, float W, float H,
                       string S, Color C, int HAlign, optional float Scale)
{
	local float tw, tx;

	tw = Width(F, S, Scale);
	tx = X;
	if (HAlign == 1)
		tx = X + (W - tw) * 0.5;
	else if (HAlign == 2)
		tx = X + W - tw;

	Draw(gc, F, tx, Y + (H - LineHeight(F, Scale)) * 0.5, S, C, Scale);
}

// ----------------------------------------------------------------------
// 3D panels (the HUD's side panels turned toward the eye, as in Human
// Revolution / Mankind Divided). Side -1 is a panel on the left half of the
// screen, hinged on the screen's left edge; +1 on the right half, hinged on
// the right edge. The inner side recedes, so a panel never grows off the
// screen. Everything drawn with RIText (text, fills, lines) and with Tex /
// TexAt / Pat until End3D is tilted; windows the game draws itself aren't.
// ----------------------------------------------------------------------

static final function bool Can3D()
{
	local string V;

	if (default.Native3D == 0)
	{
		V = Class'RINative'.static.RINativeVersion();
		default.Native3D = 2;
		if ((Left(V, 9) == "RINative ") && (float(Mid(V, 9)) >= 0.4))
			default.Native3D = 1;
	}
	return (default.Native3D == 1) && !default.bAtlasText;
}

static function bool Begin3D(Window W, GC gc, int Side, float Yaw)
{
	local Window R;
	local float hx, hy, ex, ey;

	End3D();
	if ((W == None) || (gc == None) || (Side == 0) || (Yaw <= 0) || !Can3D())
		return False;
	R = W.GetRootWindow();
	if ((R == None) || (R.width <= 0) || (R.height <= 0))
		return False;
	// the hinge (a screen edge) and the eye (screen centre), in W's coordinates
	if (Side < 0)
		W.ConvertCoordinates(R, 0, 0, W, hx, hy);
	else
		W.ConvertCoordinates(R, R.width, 0, W, hx, hy);
	W.ConvertCoordinates(R, R.width * 0.5, R.height * 0.5, W, ex, ey);
	if (Side > 0)
		Yaw = -Yaw;
	default.b3D = Class'RINative'.static.RINativeSet3D(gc, hx, ex, ey, R.height * 1.15, Yaw);
	return default.b3D;
}

static function End3D()
{
	if (!default.b3D)
		return;
	Class'RINative'.static.RINativeClear3D();
	default.b3D = False;
}

// gc.DrawStretchedTexture, tilted while a 3D panel is open
static function Tex(GC gc, float X, float Y, float W, float H, float U, float V, float UL, float VL, Texture T)
{
	if (default.b3D)
	{
		if ((T != None) && (W > 0) && (H > 0))
			Class'RINative'.static.RINativeDrawTile(gc, T, X, Y, W, H, U, V, UL, VL);
	}
	else
		gc.DrawStretchedTexture(X, Y, W, H, U, V, UL, VL, T);
}

// gc.DrawTexture (one texel per UI unit), tilted while a 3D panel is open
static function TexAt(GC gc, float X, float Y, float W, float H, float U, float V, Texture T)
{
	if (default.b3D)
	{
		if ((T != None) && (W > 0) && (H > 0))
			Class'RINative'.static.RINativeDrawTile(gc, T, X, Y, W, H, U, V, W, H);
	}
	else
		gc.DrawTexture(X, Y, W, H, U, V, T);
}

// gc.DrawPattern (the texture repeated), tilted while a 3D panel is open
static function Pat(GC gc, float X, float Y, float W, float H, float OX, float OY, Texture T)
{
	if (default.b3D)
	{
		if ((T != None) && (W > 0) && (H > 0))
			Class'RINative'.static.RINativeDrawTile(gc, T, X, Y, W, H, OX, OY, W, H);
	}
	else
		gc.DrawPattern(X, Y, W, H, OX, OY, T);
}

// ----------------------------------------------------------------------
// Hairlines: half a UI unit = one screen pixel at 1080p
// ----------------------------------------------------------------------

static function HLine(GC gc, float X, float Y, float W, Color C)
{
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C);
	Fill(gc, X, Y, W, PX);
}

// Solid rectangle on exact screen pixels (the engine's own tile call rounds
// to whole UI units, two pixels at 1080p, so hairlines would jump about).
// Uses the GC's current style and colour.
static function Fill(GC gc, float X, float Y, float W, float H)
{
	if (default.bAtlasText)
		gc.DrawStretchedTexture(Snap(X), Snap(Y), FMax(PX, Snap(W)), FMax(PX, Snap(H)), 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_White');
	else
		Class'RINative'.static.RINativeDrawTile(gc, Texture'ReimaginedUI.UI.RI_White', X, Y, W, H, 0, 0, 16, 16);
}

static function VLine(GC gc, float X, float Y, float H, Color C)
{
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C);
	Fill(gc, X, Y, PX, H);
}

static function Box(GC gc, float X, float Y, float W, float H, Color C)
{
	HLine(gc, X, Y, W, C);
	HLine(gc, X, Y + H - PX, W, C);
	VLine(gc, X, Y, H, C);
	VLine(gc, X + W - PX, Y, H, C);
}

// ----------------------------------------------------------------------
// Text helpers
// ----------------------------------------------------------------------

// Remove AE's "|&" accelerator markers
static function string Clean(string S)
{
	local int p;

	p = InStr(S, "|&");
	while (p >= 0)
	{
		S = Left(S, p) $ Mid(S, p + 2);
		p = InStr(S, "|&");
	}
	return S;
}

// Shorten to fit W, ending in "..."
static function string Fit(Class<RIFont> F, string S, float W, optional float Scale)
{
	if (Width(F, S, Scale) <= W)
		return S;
	while ((Len(S) > 1) && (Width(F, S $ "...", Scale) > W))
		S = Left(S, Len(S) - 1);
	return S $ "...";
}

// Word-wrapped text; "|n" starts a new line. Returns the height used.
// Pass gc = None to measure only.
static function float DrawWrapped(GC gc, Class<RIFont> F, float X, float Y, float W, string S, Color C,
                                  optional float Scale, optional float LineGap)
{
	local string Para, Rest, Line, Word;
	local int p;
	local float lh, yy;
	local bool bMore;

	if (Scale == 0)
		Scale = 1;
	if (LineGap == 0)
		LineGap = 1.3;
	lh = LineHeight(F, Scale) * LineGap;
	yy = Y;
	Rest = S;
	bMore = True;

	while (bMore)
	{
		p = InStr(Rest, "|n");
		if (p >= 0)
		{
			Para = Left(Rest, p);
			Rest = Mid(Rest, p + 2);
		}
		else
		{
			Para = Rest;
			Rest = "";
			bMore = False;
		}

		Line = "";
		while (Para != "")
		{
			p = InStr(Para, " ");
			if (p >= 0)
			{
				Word = Left(Para, p);
				Para = Mid(Para, p + 1);
			}
			else
			{
				Word = Para;
				Para = "";
			}
			if (Word == "")
				continue;

			if (Line == "")
				Line = Word;
			else if (Width(F, Line $ " " $ Word, Scale) <= W)
				Line = Line $ " " $ Word;
			else
			{
				if (gc != None)
					Draw(gc, F, X, yy, Line, C, Scale);
				yy += lh;
				Line = Word;
			}
		}
		if ((gc != None) && (Line != ""))
			Draw(gc, F, X, yy, Line, C, Scale);
		yy += lh;
	}
	return yy - Y;
}

defaultproperties
{
}
