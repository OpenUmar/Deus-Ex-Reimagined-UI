//=============================================================================
// RISubs
// Subtitle drawing shared by the bark display and the first-person
// conversation window: centred lines, word-wrapped, each over its own soft
// dark backing (no box), the speaker's name small and gold above or before.
//=============================================================================
class RISubs extends Object
	abstract;

var string ColKey;     // whose colour the lines of the next DrawSub take (set round the call)

// ----------------------------------------------------------------------
// Speaker colours (Settings > Interface > Speaker colours: off, names,
// names and lines). The player always one colour; everyone else one of
// eight picked from their name, so a person keeps theirs all game.
// ----------------------------------------------------------------------

static function int ColMode()
{
	return Class'RIRootWindow'.default.SubColors;
}

static function Color SpeakerCol(string Who, bool bPlayer, float a)
{
	local int i, h;
	local string U;

	if (bPlayer)
		return Class'RIUtil'.static.Raw(185 * a, 225 * a, 255 * a);
	U = Caps(Who);
	h = 7;
	for (i = 0; i < Len(U); i++)
		h = (h * 31 + Asc(Mid(U, i, 1))) % 8191;
	switch (h % 8)
	{
		case 0: return Class'RIUtil'.static.Raw(255 * a, 196 * a, 110 * a);
		case 1: return Class'RIUtil'.static.Raw(120 * a, 170 * a, 255 * a);
		case 2: return Class'RIUtil'.static.Raw(150 * a, 230 * a, 140 * a);
		case 3: return Class'RIUtil'.static.Raw(245 * a, 150 * a, 205 * a);
		case 4: return Class'RIUtil'.static.Raw(200 * a, 165 * a, 255 * a);
		case 5: return Class'RIUtil'.static.Raw(255 * a, 232 * a, 130 * a);
		case 6: return Class'RIUtil'.static.Raw(120 * a, 230 * a, 215 * a);
	}
	return Class'RIUtil'.static.Raw(255 * a, 155 * a, 125 * a);
}

// A speaker's name: their colour, or Def with colours off
static function Color NameCol(string Who, bool bPlayer, float a, Color Def)
{
	if ((ColMode() >= 1) && (Who != ""))
		return SpeakerCol(Who, bPlayer, a);
	return Def;
}

// A line: tinted toward the speaker's colour with "names and lines" on
static function Color LineCol(string Who, bool bPlayer, float a, Color Def)
{
	if ((ColMode() >= 2) && (Who != ""))
		return Class'RIUtil'.static.Mix(SpeakerCol(Who, bPlayer, a), Class'RIUtil'.static.Raw(255 * a, 255 * a, 255 * a), 0.45);
	return Def;
}

// Word-wrap T into lines no wider than W; returns the count (max 8)
static function int Wrap(Class<RIFont> F, float Scale, string T, float W, out string L0, out string L1,
	out string L2, out string L3, out string L4, out string L5, out string L6, out string L7)
{
	local string Rest, Word, Line, Try;
	local int p, n;

	L0 = ""; L1 = ""; L2 = ""; L3 = ""; L4 = ""; L5 = ""; L6 = ""; L7 = "";
	Rest = T;
	Line = "";
	n = 0;
	while ((Rest != "") && (n < 8))
	{
		p = InStr(Rest, " ");
		if (p < 0)
		{
			Word = Rest;
			Rest = "";
		}
		else
		{
			Word = Left(Rest, p);
			Rest = Mid(Rest, p + 1);
		}
		if (Line == "")
			Try = Word;
		else
			Try = Line @ Word;
		if ((Line != "") && (Class'RIText'.static.Width(F, Try, Scale) > W))
		{
			SetLine(n, Line, L0, L1, L2, L3, L4, L5, L6, L7);
			n++;
			Line = Word;
		}
		else
			Line = Try;
	}
	if ((Line != "") && (n < 8))
	{
		SetLine(n, Line, L0, L1, L2, L3, L4, L5, L6, L7);
		n++;
	}
	return n;
}

static function SetLine(int n, string V, out string L0, out string L1, out string L2, out string L3,
	out string L4, out string L5, out string L6, out string L7)
{
	switch (n)
	{
		case 0: L0 = V; break;
		case 1: L1 = V; break;
		case 2: L2 = V; break;
		case 3: L3 = V; break;
		case 4: L4 = V; break;
		case 5: L5 = V; break;
		case 6: L6 = V; break;
		case 7: L7 = V; break;
	}
}

static function string GetLine(int n, string L0, string L1, string L2, string L3, string L4, string L5, string L6, string L7)
{
	switch (n)
	{
		case 0: return L0;
		case 1: return L1;
		case 2: return L2;
		case 3: return L3;
		case 4: return L4;
		case 5: return L5;
		case 6: return L6;
	}
	return L7;
}

// One subtitle: optional name above, then the wrapped text, all centred in
// X..X+W from Y. Returns the height used. a = fade (0..1).
// Settings > Interface > Subtitle size: text and spacing together
static function float DrawSub(GC gc, float X, float Y, float W, float K, string Speaker, string T,
	bool bPlayer, float a)
{
	local float q, r;

	q = Class'RIRootWindow'.static.SubK();
	Class'RIText'.default.TextMul = q;
	r = DrawSubIn(gc, X, Y, W, K * q, Speaker, T, bPlayer, a);
	Class'RIText'.default.TextMul = 1.0;
	return r;
}

static function float SubHeightIn(float W, float K, string Speaker, string T)
{
	local float q, r;

	q = Class'RIRootWindow'.static.SubK();
	Class'RIText'.default.TextMul = q;
	r = SubHeightIn(W, K * q, Speaker, T);
	Class'RIText'.default.TextMul = 1.0;
	return r;
}

static function float DrawSubIn(GC gc, float X, float Y, float W, float K, string Speaker, string T,
	bool bPlayer, float a)
{
	local string L0, L1, L2, L3, L4, L5, L6, L7, Ln;
	local int n, i;
	local float lh, y0, tw, mw;

	if (a <= 0.01)
		return 0;
	lh = 30 * K;
	mw = FMin(W, 1000 * K);
	n = Wrap(Class'RIFontBody', 0.82, T, mw - 40 * K, L0, L1, L2, L3, L4, L5, L6, L7);
	y0 = Y;
	if (Class'RIVP'.static.On())
		return DrawVPSub(gc, X, Y, W, K, Speaker, T, bPlayer, a);
	if (Speaker != "")
	{
		tw = Class'RIText'.static.Width(Class'RIFontSmall', Caps(Speaker), 0.62);
		Class'RISkin'.static.DrawDim(gc, X + (W - tw) * 0.5 - 14 * K, y0, tw + 28 * K, 24 * K, 0.35 * a);
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, y0, W, 24 * K, Caps(Speaker),
			NameCol(Speaker, bPlayer, a, Class'RIUtil'.static.Col(242 * a, 211 * a, 107 * a)), 1, 0.62);
		y0 += 26 * K;
	}
	for (i = 0; i < n; i++)
	{
		Ln = GetLine(i, L0, L1, L2, L3, L4, L5, L6, L7);
		tw = Class'RIText'.static.Width(Class'RIFontBody', Ln, 0.82);
		Class'RISkin'.static.DrawDim(gc, X + (W - tw) * 0.5 - 18 * K, y0, tw + 36 * K, lh, 0.45 * a);
		if (bPlayer)
			Class'RIText'.static.DrawIn(gc, Class'RIFontBody', X, y0, W, lh, Ln,
				LineCol(default.ColKey, True, a, Class'RIUtil'.static.Col(255 * a, 241 * a, 194 * a)), 1, 0.82);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontBody', X, y0, W, lh, Ln,
				LineCol(default.ColKey, False, a, Class'RIUtil'.static.Col(236 * a, 214 * a, 160 * a)), 1, 0.82);
		y0 += lh;
	}
	return y0 - Y;
}

// Vanilla+: no box. Each line over its own soft shadow, the speaker small
// and gold above it with a short gold rule under the name
static function float DrawVPSub(GC gc, float X, float Y, float W, float K, string Speaker, string T, bool bPlayer, float a)
{
	local int i, n;
	local float lh, tw, y0;
	local string Ln, L0, L1, L2, L3, L4, L5, L6, L7;

	n = Wrap(Class'RIFontBody', 0.82, T, FMin(W, 1000 * K) - 40 * K, L0, L1, L2, L3, L4, L5, L6, L7);
	lh = 30 * K;
	y0 = Y;
	if (Speaker != "")
	{
		tw = Class'RIText'.static.Width(Class'RIFontSmall', Caps(Speaker), 0.58);
		Class'RISkin'.static.DrawDim(gc, X + (W - tw) * 0.5 - 16 * K, y0, tw + 32 * K, 26 * K, 0.3 * a);
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, y0, W, 20 * K, Caps(Speaker), NameCol(Speaker, bPlayer, a, Class'RIVP'.static.Acc(a)), 1, 0.58);
		Class'RISkin'.static.FillC(gc, X + W * 0.5 - 14 * K, y0 + 21 * K, 28 * K, 1.5 * K, Class'RIVP'.static.Edge(a));
		y0 += 28 * K;
	}
	for (i = 0; i < n; i++)
	{
		Ln = GetLine(i, L0, L1, L2, L3, L4, L5, L6, L7);
		tw = Class'RIText'.static.Width(Class'RIFontBody', Ln, 0.82);
		Class'RISkin'.static.DrawDim(gc, X + (W - tw) * 0.5 - 22 * K, y0, tw + 44 * K, lh, 0.42 * a);
		if (bPlayer)
			Class'RIText'.static.DrawIn(gc, Class'RIFontBody', X, y0, W, lh, Ln, LineCol(default.ColKey, True, a, Class'RIUtil'.static.Col(255 * a, 241 * a, 194 * a)), 1, 0.82);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontBody', X, y0, W, lh, Ln, LineCol(default.ColKey, False, a, Class'RIVP'.static.Txt(a)), 1, 0.82);
		y0 += lh;
	}
	return y0 - Y;
}

// Height DrawSub will use (for preferred sizes)
static function float SubHeight(float W, float K, string Speaker, string T)
{
	local string L0, L1, L2, L3, L4, L5, L6, L7;
	local int n;

	n = Wrap(Class'RIFontBody', 0.82, T, FMin(W, 1000 * K) - 40 * K, L0, L1, L2, L3, L4, L5, L6, L7);
	if (Class'RIVP'.static.On())
	{
		if (Speaker != "")
			return 28 * K + n * 30 * K;
		return n * 30 * K;
	}
	if (Speaker != "")
		return 26 * K + n * 30 * K;
	return n * 30 * K;
}

// ----------------------------------------------------------------------
// Item toasts (Received / Given), right-aligned at RightX: icon, name and
// quantity, each row over its own soft shadow that fades toward the middle
// of the screen. Returns the row height.
// ----------------------------------------------------------------------

static function float ToastRow(GC gc, float RightX, float Y, float K, Texture Icon, string Label, int Qty,
	bool bDeclined, float a, optional bool bInBox)
{
	local float iw, ih, rh, lw, qw, rowW, x0;
	local string Q;

	iw = 42 * K;
	ih = 37 * K;
	rh = ih + 10 * K;
	Label = Caps(Label);
	Q = "x" $ string(Max(1, Qty));
	lw = Class'RIText'.static.Width(Class'RIFontBody', Label, 0.76);
	qw = Class'RIText'.static.Width(Class'RIFontHead', Q, 0.52);
	rowW = 14 * K + iw + 14 * K + lw + 14 * K + qw + 16 * K;
	x0 = RightX - rowW;
	if (bInBox)
	{
		// drawn inside ToastBox's frame: no panel of its own
	}
	else if (Class'RIVP'.static.On())
	{
		Class'RIVP'.static.Panel(gc, x0, Y, rowW, rh - 4 * K, 8 * K, a);
	}
	else
	{
		Class'RISkin'.static.DrawDim(gc, x0 - 140 * K, Y, rowW + 160 * K, rh - 4 * K, 0.18 * a);
		Class'RISkin'.static.DrawDim(gc, x0 - 50 * K, Y, rowW + 70 * K, rh - 4 * K, 0.25 * a);
		Class'RISkin'.static.DrawDim(gc, x0, Y + 2 * K, rowW + 20 * K, rh - 8 * K, 0.3 * a);
	}
	if (Icon != None)
	{
		gc.SetStyle(DSTY_Masked);
		if (bDeclined)
			gc.SetTileColor(Class'RIUtil'.static.Raw(90 * a, 90 * a, 90 * a));
		else
			gc.SetTileColor(Class'RIUtil'.static.Raw(255 * a, 255 * a, 255 * a));
		// AE item icons sit in the top-left 42 x 37 of their texture
		Class'RIHD'.static.DrawStretched(gc, x0 + 14 * K, Y + (rh - 4 * K - ih) * 0.5, iw, ih, 0, 0, FMin(42, Icon.USize), FMin(37, Icon.VSize), Icon);
	}
	if (bDeclined)
		Class'RIText'.static.DrawIn(gc, Class'RIFontBody', x0 + 28 * K + iw, Y, lw + 4 * K, ih + 6 * K, Label,
			Class'RIUtil'.static.Col(150 * a, 132 * a, 92 * a), 0, 0.76);
	else
		Class'RIText'.static.DrawIn(gc, Class'RIFontBody', x0 + 28 * K + iw, Y, lw + 4 * K, ih + 6 * K, Label,
			Class'RIUtil'.static.Col(236 * a, 214 * a, 160 * a), 0, 0.76);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x0 + 42 * K + iw + lw, Y, qw + 4 * K, ih + 6 * K, Q,
		Class'RIUtil'.static.Col(242 * a, 211 * a, 107 * a), 0, 0.52);
	return rh;
}

// Width of one ToastRow (the same sum ToastRow makes)
static function float ToastRowW(float K, string Label, int Qty)
{
	local float lw, qw;

	lw = Class'RIText'.static.Width(Class'RIFontBody', Caps(Label), 0.76);
	qw = Class'RIText'.static.Width(Class'RIFontHead', "x" $ string(Max(1, Qty)), 0.52);
	return 14 * K + 42 * K + 14 * K + lw + 14 * K + qw + 16 * K;
}

// Width ToastBox will use for this title and widest row
static function float ToastBoxW(float K, string Title, float RowsW)
{
	local float w;

	w = FMax(RowsW, Class'RIText'.static.Width(Class'RIFontSmall', Caps(Title), 0.66) + 40 * K) + 12 * K;
	return FMax(w, 260 * K);
}

static function float ToastBoxH(float K, int Rows)
{
	return 46 * K + Rows * 47 * K + 6 * K;
}

// Vanilla+: one box holding the whole list (it grows a row per item as
// more come in), right edge at RightX: the game darkened behind, the
// mechanical frame with the original DX trim, the title over a rule.
// RowsW is the widest row. Returns the left edge for the rows; they start
// at Top + 46 * K.
static function float ToastBox(GC gc, float RightX, float Top, float K, string Title, float RowsW, int Rows, float a)
{
	local float w, h, x0;

	Title = Caps(Title);
	w = ToastBoxW(K, Title, RowsW);
	h = ToastBoxH(K, Rows);
	x0 = RightX - w;
	Class'RIVP'.static.Dim(gc, x0 + 3 * K, Top + 3 * K, w - 6 * K, h - 6 * K);
	Class'RIVP'.static.Frame(gc, x0, Top, w, h, 12 * K, a);
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x0 + 20 * K, Top + 12 * K, Title,
		Class'RIUtil'.static.Col(242 * a, 211 * a, 107 * a), 0.66);
	Class'RIText'.static.HLine(gc, x0 + 20 * K, Top + 38 * K, w - 40 * K, Class'RIUtil'.static.Col(126 * a, 105 * a, 50 * a));
	return x0 + 6 * K;
}

static function ToastTitle(GC gc, float RightX, float Y, float K, string Title, float a)
{
	local float tw;

	tw = Class'RIText'.static.Width(Class'RIFontSmall', Caps(Title), 0.66);
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', RightX - tw - 16 * K, Y, Caps(Title),
		Class'RIUtil'.static.Col(242 * a, 211 * a, 107 * a), 0.66);
}

defaultproperties
{
}
