//=============================================================================
// RIConView
// Third-person conversations (ConWindowActive), drawn to the Dialogue
// artboard: the speaker and line centred in the lower band, replies as
// numbered rows, credits top right. AE's ConWindowActive keeps running the
// conversation (letterbox, camera, timing, choices, items received); its
// speech text and choice buttons are hidden and drawn here instead, and
// clicks / keys are passed on to it exactly as AE expects them.
//=============================================================================
class RIConView extends Window;

var ConWindowActive Con;
var float Age, LineAge, ChoiceAge;
var float S;
var bool  bReady;
var int   Sel;
var int   LastNumChoices;
var string LastLine;

// Reply rows from the last frame (for the mouse)
var float RowX, RowY[10], RowW, RowH;
var int   NumRows;
var int   HoverRow;

var bool bBandsCleared;
var bool bBarsLatched;     // Conversation Bars as set when this conversation began
var bool bCursorForMenu;    // the cursor was shown for the pause menu

// Received (box 0) / Given (box 1): AE's boxes are hidden as soon as they
// appear; what they hold is copied here (12 items each, flattened) and shown
// for as long as AE would have shown it
var Texture BoxIcon[24];
var string  BoxLabel[24];
var int     BoxQty[24];
var byte    BoxDeclined[24];
var int     BoxNum[2];
var string  BoxTitle[2];
var float   BoxAge[2];
var float   BoxLife[2];

var localized string CreditsLabel;

event InitWindow()
{
	Super.InitWindow();
	SetSelectability(True);
	bTickEnabled = True;
	HoverRow = -1;
}

function AttachTo(ConWindowActive NewCon)
{
	Con = NewCon;
	bBarsLatched = Class'RIRootWindow'.default.bConBars;
	SetConfiguration(0, 0, Con.width, Con.height);
	HideConParts();
	ClearBands();
}

// No black letterbox. AE sizes its bands from these two fractions and
// squeezes the 3D view to fit between them; at zero the view stays full
// screen, so nothing has to be undone each frame (which caused a stutter).
// This view draws the text in the same area the lower band used to take.
// Cinematics keep AE's letterbox.
function ClearBands()
{
	if (Bars() || bBandsCleared)
		return;
	bBandsCleared = True;
	Con.lowerFinalHeightPercent = 0;
	Con.upperFinalHeightPercent = 0;
	if (Con.lowerConWindow != None)
		Con.lowerConWindow.SetBackground(None);
	if (Con.upperConWindow != None)
		Con.upperConWindow.SetBackground(None);
	Con.CalculateWindowSizes();
}

// Conversation Bars switched in Settings mid-conversation: the bands and
// the layout are changed over together, at once. Off: the bands go to zero
// (ClearBands). On: the game's own band sizes come back, the bars shown fully
// open, and the sizes recalculated, so the text has its lower bar to sit in.
function ApplyBarsSetting()
{
	if (Con.bForcePlay || (bBarsLatched == Class'RIRootWindow'.default.bConBars))
		return;
	bBarsLatched = Class'RIRootWindow'.default.bConBars;
	if (bBarsLatched)
	{
		Con.lowerFinalHeightPercent = Con.default.lowerFinalHeightPercent;
		Con.upperFinalHeightPercent = Con.default.upperFinalHeightPercent;
		Con.currentWindowPos = 1.0;
		if (Con.upperConWindow != None)
			Con.upperConWindow.SetBackground(Con.conTexture);
		bBandsCleared = False;
		Con.CalculateWindowSizes();
	}
	// off: ClearBands (called right after) zeroes them, now that Bars() says no
}

// The black letterbox stays: cinematics, or Settings > Interface > Conversation Bars
function bool Bars()
{
	return Con.bForcePlay || bBarsLatched;
}

// The lower letterbox bar, as the game's CalculateWindowSizes places it.
// Cinematics: the lower bar is as tall as the upper one on every base (the
// cinematic height formula differs between bases, so it's read off the
// upper bar, which stays visible and is kept in place). Conversations with
// bars on: the bar slides up with currentWindowPos.
function BarBand(out float BY, out float BH, out float A)
{
	if (Con.bForcePlay)
	{
		BH = 0;
		if (Con.upperConWindow != None)
			BH = Con.upperConWindow.height;
		BY = height - BH;
		A = 1;
		return;
	}
	BH = int(height * Con.lowerFinalHeightPercent);
	BY = int(height - BH * Con.currentWindowPos);
	BH = height - BY;
	A = FClamp(Con.currentWindowPos, 0, 1);
}

// Where AE's bands would have been (fractions of the screen)
function float LowerFrac()
{
	return Con.default.lowerFinalHeightPercent;
}

function float UpperFrac()
{
	return Con.default.upperFinalHeightPercent;
}

event WindowReady()
{
	Super.WindowReady();
	bReady = True;
}

// AE's speech text, credits text and choice buttons stay alive but hidden
function HideConParts()
{
	local int i;

	if (Con == None)
		return;
	// AE builds a new speech window and new reply buttons inside its lower
	// band for every line; they drew for a frame before being hidden (the
	// old boxes flickering). Hidden as a whole, nothing in it ever draws;
	// the cinematic black bar it painted is drawn in DrawWindow instead.
	if ((Con.lowerConWindow != None) && Con.lowerConWindow.IsVisible(False))
		Con.lowerConWindow.Hide();
	if ((Con.winSpeech != None) && Con.winSpeech.IsVisible(False))
		Con.winSpeech.Hide();
	for (i = 0; i < Con.numChoices; i++)
		if ((Con.conChoices[i] != None) && Con.conChoices[i].IsVisible(False))
			Con.conChoices[i].Hide();
	Class'RIBase'.static.HideConExtras(Con);
}

// ----------------------------------------------------------------------
// Text helpers
// ----------------------------------------------------------------------

// AE joins appended lines with carriage returns; RIText wraps on "|n"
static function string Lines(string T)
{
	local string R;
	local int i, c;

	R = "";
	for (i = 0; i < Len(T); i++)
	{
		c = Asc(Mid(T, i, 1));
		// a line break is CR, LF or CR LF (AE's item text uses bare LF)
		if (c == 13)
			R = R $ "|n";
		else if (c == 10)
		{
			if ((i == 0) || (Asc(Mid(T, i - 1, 1)) != 13))
				R = R $ "|n";
		}
		else
			R = R $ Mid(T, i, 1);
	}
	return R;
}

// "1. Text" / "~ Text" -> "Text"
static function string ChoiceText(string T)
{
	local int p;

	if (Left(T, 1) == "~")
		T = Mid(T, 1);
	else
	{
		p = InStr(T, ". ");
		if ((p > 0) && (p <= 2) && (int(Left(T, p)) > 0 || Left(T, p) == "0"))
			T = Mid(T, p + 2);
	}
	while (Left(T, 1) == " ")
		T = Mid(T, 1);
	return T;
}

function string Speaker()
{
	local string N;

	if ((Con.winSpeech == None) || (Con.winSpeech.txtName == None))
		return "";
	N = Con.winSpeech.txtName.GetText();
	if (Right(N, 2) == ": ")
		N = Left(N, Len(N) - 2);
	return N;
}

// The line on screen is the player's own
function bool PlayerSpeaking()
{
	return (Con != None) && (Con.conPlay != None) && (DeusExPlayer(Con.conPlay.currentSpeaker) != None);
}

function string SpeechLine()
{
	if ((Con.winSpeech == None) || (Con.winSpeech.txtSpeech == None))
		return "";
	return Lines(Con.winSpeech.txtSpeech.GetText());
}

// ----------------------------------------------------------------------
// Input: replies with Up / Down / Enter; everything else goes to AE
// ----------------------------------------------------------------------

function bool Choosing()
{
	return (Con != None) && (Con.numChoices > 0) && !Con.bForcePlay;
}

function PickChoice(int i)
{
	if ((i < 0) || (i >= Con.numChoices) || (Con.conChoices[i] == None))
		return;
	PlaySound(Sound'Menu_Press', 0.25);
	Con.ButtonActivated(Con.conChoices[i]);
}

event bool VirtualKeyPressed(EInputKey key, bool bRepeat)
{
	local int n;

	if (Con == None)
		return False;
	// Escape pauses (the original skipped the line; Enter / Space still do).
	// The pause menu pauses the level and RIRootWindow holds the speech, so
	// the conversation waits exactly where it was. Cinematics keep Escape to skip.
	if ((key == IK_Escape) && !Con.bForcePlay)
	{
		if (!bRepeat && (Con.player != None) && (DeusExRootWindow(GetRootWindow()).GetTopWindow() == None))
			Con.player.ShowMainMenu();
		return True;
	}
	if (Choosing())
	{
		// 1-9 and 0 pick that reply directly
		n = ReplyKey(key);
		if ((n >= 0) && (n <= 9) && !bRepeat)
		{
			if (n < Con.numChoices)
			{
				Sel = n;
				PickChoice(n);
			}
			return True;
		}
		if ((key == IK_Up) || (key == IK_MouseWheelUp))
		{
			Sel = Max(0, Sel - 1);
			PlaySound(Sound'Menu_Focus', 0.2);
			return True;
		}
		if ((key == IK_Down) || (key == IK_MouseWheelDown))
		{
			Sel = Min(Con.numChoices - 1, Sel + 1);
			PlaySound(Sound'Menu_Focus', 0.2);
			return True;
		}
		if (((key == IK_Enter) || (key == IK_Space)) && !bRepeat)
		{
			PickChoice(Sel);
			return True;
		}
	}
	return Con.VirtualKeyPressed(key, bRepeat);
}

// 1-9 and 0 -> reply 0-9, anything else -1 (enum values can't be cast to int)
function int ReplyKey(EInputKey key)
{
	if (key == IK_1) return 0;
	if (key == IK_2) return 1;
	if (key == IK_3) return 2;
	if (key == IK_4) return 3;
	if (key == IK_5) return 4;
	if (key == IK_6) return 5;
	if (key == IK_7) return 6;
	if (key == IK_8) return 7;
	if (key == IK_9) return 8;
	if (key == IK_0) return 9;
	return -1;
}

function int RowAt(float X, float Y)
{
	local int i;

	for (i = 0; i < NumRows; i++)
		if ((X >= RowX) && (X < RowX + RowW) && (Y >= RowY[i]) && (Y < RowY[i] + RowH))
			return i;
	return -1;
}

event MouseMoved(float newX, float newY)
{
	local int r;

	r = RowAt(newX, newY);
	if ((r != -1) && (r != HoverRow))
	{
		Sel = r;
		PlaySound(Sound'Menu_Focus', 0.15);
	}
	HoverRow = r;
}

event bool MouseButtonPressed(float pointX, float pointY, EInputKey button, int numClicks)
{
	return True;
}

event bool MouseButtonReleased(float pointX, float pointY, EInputKey button, int numClicks)
{
	local int r;

	if (Con == None)
		return False;
	if (Choosing())
	{
		r = RowAt(pointX, pointY);
		if (r >= 0)
			PickChoice(r);
		return True;
	}
	// No choices: a click advances the conversation (AE's behaviour)
	return Con.MouseButtonReleased(pointX, pointY, button, numClicks);
}

event Tick(float deltaSeconds)
{
	local string L;

	Age += deltaSeconds;
	LineAge += deltaSeconds;
	ChoiceAge += deltaSeconds;
	if (Con == None)
		return;

	if ((width != Con.width) || (height != Con.height))
		SetConfiguration(0, 0, Con.width, Con.height);
	HideConParts();
	ApplyBarsSetting();
	ClearBands();
	CaptureBox(Con.winReceived, 0);
	CaptureBox(Class'RIBase'.static.ConTaken(Con), 1);
	BoxAge[0] += deltaSeconds;
	BoxAge[1] += deltaSeconds;

	// the conversation hides the cursor while lines play; the pause menu needs it
	if (DeusExRootWindow(GetRootWindow()).GetTopWindow() != None)
	{
		GetRootWindow().ShowCursor(True);
		bCursorForMenu = True;
	}
	else if (bCursorForMenu)
	{
		bCursorForMenu = False;
		GetRootWindow().ShowCursor(Choosing());
	}

	if (bReady && Con.IsVisible() && (GetRootWindow().GetFocusWindow() != Self)
		&& (DeusExRootWindow(GetRootWindow()).GetTopWindow() == None))
		SetFocusWindow(Self);

	L = SpeechLine();
	if (L != LastLine)
	{
		LastLine = L;
		LineAge = 0;
	}
	if (Con.numChoices != LastNumChoices)
	{
		LastNumChoices = Con.numChoices;
		ChoiceAge = 0;
		Sel = 0;
	}
	Sel = Clamp(Sel, 0, Max(0, Con.numChoices - 1));
}

// AE's "Received" / "Given" boxes: when AE shows one, copy what it holds
// and hide it (its own look and position clash with this layout)
function CaptureBox(HUDReceivedDisplay R, int B)
{
	local int i, n, c, Qty;
	local string T, Lbl;
	local Texture Ic;
	local byte bDecl;

	if ((R == None) || !R.IsVisible(False))
		return;
	n = 0;
	c = Class'RIBase'.static.ReceivedCount(R);
	for (i = 0; (i < c) && (n < 12); i++)
	{
		if (!Class'RIBase'.static.ReceivedItem(R, i, Ic, Lbl, Qty, bDecl))
			continue;
		BoxIcon[B * 12 + n] = Ic;
		BoxLabel[B * 12 + n] = Lbl;
		BoxQty[B * 12 + n] = Max(1, Qty);
		BoxDeclined[B * 12 + n] = bDecl;
		n++;
	}
	if (n == 0)
		return;
	BoxNum[B] = n;
	T = "";
	if (R.txtReceived != None)
		T = R.txtReceived.GetText();
	if (Right(T, 1) == ":")
		T = Left(T, Len(T) - 1);
	if (T == "")
	{
		if (B == 0)
			T = "Received";
		else
			T = "Given";
	}
	BoxTitle[B] = Caps(T);
	BoxAge[B] = 0;
	BoxLife[B] = FMax(2.0, R.displayLength);
	R.Hide();
}

// ----------------------------------------------------------------------
// Drawing
// ----------------------------------------------------------------------

function Color C3(float R, float G, float B, float a)
{
	return Class'RIUtil'.static.Col(R * a, G * a, B * a);
}

// The original game's gold (sampled from AE's screens)
function Color Amber(float a)      { return C3(230, 195, 117, a); }
function Color AmberHi(float a)    { return C3(255, 232, 150, a); }
function Color AmberDim(float a)   { return C3(126, 105, 50, a); }
function Color WarmText(float a)   { return C3(245, 236, 214, a); }

function AmberRow(GC gc, float X, float Y, float W, float H, float a)
{
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C3(70, 58, 26, a));
	gc.DrawStretchedTexture(X, Y, W, H, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');
	Class'RIText'.static.Box(gc, X, Y, W, H, C3(200, 170, 96, a));
	Class'RISkin'.static.FillC(gc, X, Y, 1.5, H, AmberHi(a));
}

event DrawWindow(GC gc)
{
	local float a, bandY, bandH, y, h, w, x, tw, ca, ra, cx;
	local int i, n;
	local string L, Who, T;
	local Window Low, Up;

	Class'RITheme'.static.SetMode(2);   // dialogue follows the HUD theme

	NumRows = 0;
	if (Con == None)
		return;
	S = height / 1080.0;
	gc.EnableSmoothing(True);

	Low = Con.lowerConWindow;
	Up  = Con.upperConWindow;
	if (Low == None)
		return;
	if (Bars())
	{
		// Cinematic (or bars switched on): the letterbox, text in its lower
		// bar. The lower bar window is hidden (see HideConParts) and a hidden
		// window is never repositioned, so its place is worked out here the
		// way the game does it.
		BarBand(bandY, bandH, a);
		if (bandH <= 1)
			return;
		Class'RIVP'.static.Black(gc, 0, bandY, width, bandH);
	}
	else
	{
		bandH = int(height * LowerFrac());
		bandY = height - bandH;
		a = FClamp(Con.currentWindowPos, 0, 1);
		if (a <= 0.01)
			return;
	}

	// Lower band: see-through, darkened towards the bottom so text reads
	gc.SetStyle(DSTY_Modulated);
	gc.DrawStretchedTexture(0, bandY - 120 * S, width, bandH + 120 * S, 0, 2, 8, 252, Texture'ReimaginedUI.UI.RI_FadeV');
	gc.DrawStretchedTexture(0, bandY, width, bandH, 0, 2, 8, 252, Texture'ReimaginedUI.UI.RI_FadeV');


	// Upper band: credits on the right
	if ((Up != None) && !Con.bForcePlay && (Con.player != None))
	{
		T = string(Con.player.Credits);
		tw = Class'RIText'.static.Width(Class'RIFontHead', T, 0.62);
		cx = width - 96 * S - tw;
		y = FMax(18 * S, (height * UpperFrac() - 40 * S) * 0.5);
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', cx, y, tw, 40 * S, T, AmberHi(a), 0, 0.62);
		L = Caps(CreditsLabel);
		tw = Class'RIText'.static.Width(Class'RIFontSmall', L, 0.75);
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', cx - 14 * S - tw, y, tw, 40 * S, L, Amber(a), 0, 0.75);
	}

	DrawReceived(gc, bandY, a);

	if (Choosing())
	{
		// Replies: numbered rows, centred, 960 wide
		n = Con.numChoices;
		RowW = FMin(960 * S, width - 120 * S);
		RowX = (width - RowW) * 0.5;
		RowH = 54 * S;
		h = n * RowH + (n - 1) * 8 * S;
		y = bandY + FMax(16 * S, (bandH - h) * 0.5);
		if (y + h > height - 12 * S)
		{
			RowH = FMax(36 * S, (height - 24 * S - bandY - (n - 1) * 6 * S) / n);
			y = bandY + 12 * S;
		}
		for (i = 0; i < n; i++)
		{
			if (Con.conChoices[i] == None)
				continue;
			ra = a * Class'RIUtil'.static.Phase(ChoiceAge, 0.04 * i, 0.25);
			RowY[i] = y;
			NumRows = i + 1;
			if (i == Sel)
				AmberRow(gc, RowX, y, RowW, RowH, ra);
			// Number in a box
			if (i == Sel)
			{
				Class'RISkin'.static.Box2(gc, RowX + 20 * S, y + (RowH - 30 * S) * 0.5, 30 * S, 30 * S, AmberHi(ra));
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', RowX + 20 * S, y + (RowH - 30 * S) * 0.5, 30 * S, 30 * S,
					Mid("1234567890", i, 1), AmberHi(ra), 1, 0.7);
			}
			else
			{
				Class'RISkin'.static.Box2(gc, RowX + 20 * S, y + (RowH - 30 * S) * 0.5, 30 * S, 30 * S, AmberDim(ra));
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', RowX + 20 * S, y + (RowH - 30 * S) * 0.5, 30 * S, 30 * S,
					Mid("1234567890", i, 1), Amber(ra), 1, 0.7);
			}
			T = ChoiceText(Con.conChoices[i].GetText());
			T = Class'RIText'.static.Fit(Class'RIFontBody', T, RowW - 90 * S, 0.84);
			if (i == Sel)
				Class'RIText'.static.DrawIn(gc, Class'RIFontBody', RowX + 68 * S + (1 - ra) * 10 * S, y, RowW - 90 * S, RowH, T, WarmText(ra), 0, 0.84);
			else
				Class'RIText'.static.DrawIn(gc, Class'RIFontBody', RowX + 68 * S + (1 - ra) * 10 * S, y, RowW - 90 * S, RowH, T, C3(220, 196, 140, ra), 0, 0.84);
			y += RowH + 8 * S;
		}
		return;
	}

	// Speaker and line, centred
	Who = Speaker();
	L = LastLine;
	if (L == "")
		return;
	ca = a * Class'RIUtil'.static.Phase(LineAge, 0.0, 0.18);
	w = FMin(1440 * S, width - 160 * S);
	x = (width - w) * 0.5;
	h = Class'RIText'.static.DrawWrapped(None, Class'RIFontBody', 0, 0, w, L, C3(0, 0, 0, 0), 1.0, 1.4);
	y = bandY + FMax(14 * S, (bandH - h - 34 * S) * 0.5);
	if (Who != "")
	{
		tw = Class'RIText'.static.Width(Class'RIFontSmall', Caps(Who), 0.8);
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', (width - tw) * 0.5, y, Caps(Who), Class'RISubs'.static.NameCol(Who, PlayerSpeaking(), ca, Amber(ca)), 0.8);
		y += 34 * S;
	}
	DrawCentered(gc, x, y + (1 - ca) * 6 * S, w, L, Class'RISubs'.static.LineCol(Who, PlayerSpeaking(), ca, WarmText(ca)));
}

// Received / Given, stacked above the text band: a small amber heading,
// then one line per item (icon, name, x qty). No box or shadow.
function DrawReceived(GC gc, float BandTop, float a)
{
	local float y;

	// Same side as in play: the left, a third of the way down
	y = 340 * S;
	y = DrawItemBox(gc, 0, y, a);
	y = DrawItemBox(gc, 1, y, a);
}

function float DrawItemBox(GC gc, int B, float Top, float a)
{
	local int i, k;
	local float ba, y, bw, bx;

	if ((BoxNum[B] <= 0) || (BoxAge[B] > BoxLife[B]))
		return Top;
	ba = a * FClamp(BoxAge[B] / 0.15, 0, 1) * FClamp((BoxLife[B] - BoxAge[B]) / 0.5, 0, 1);
	if (ba <= 0.01)
		return Top;

	// Vanilla+: one framed box, a row per item (as in play)
	if (Class'RIVP'.static.On())
	{
		bw = 0;
		for (i = 0; i < BoxNum[B]; i++)
			bw = FMax(bw, Class'RISubs'.static.ToastRowW(S, BoxLabel[B * 12 + i], BoxQty[B * 12 + i]));
		bx = Class'RISubs'.static.ToastBox(gc, 40 * S + Class'RISubs'.static.ToastBoxW(S, BoxTitle[B], bw), Top, S, BoxTitle[B], bw, BoxNum[B], ba);
		y = Top + 46 * S;
		for (i = 0; i < BoxNum[B]; i++)
		{
			k = B * 12 + i;
			y += Class'RISubs'.static.ToastRow(gc, bx + Class'RISubs'.static.ToastRowW(S, BoxLabel[k], BoxQty[k]), y, S, BoxIcon[k], BoxLabel[k], BoxQty[k], BoxDeclined[k] != 0, ba, True);
		}
		return Top + Class'RISubs'.static.ToastBoxH(S, BoxNum[B]) + 24 * S;
	}

	// Icon, name and quantity per row, on the left over a soft shadow
	y = Top;
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', 54 * S, y, BoxTitle[B], Class'RIUtil'.static.Col(242 * ba, 211 * ba, 107 * ba), 0.66);
	y += 30 * S;
	for (i = 0; i < BoxNum[B]; i++)
	{
		k = B * 12 + i;
		y += Class'RISubs'.static.ToastRow(gc, 40 * S + Class'RISubs'.static.ToastRowW(S, BoxLabel[k], BoxQty[k]), y, S, BoxIcon[k], BoxLabel[k], BoxQty[k], BoxDeclined[k] != 0, ba);
	}
	return y + 16 * S;
}

// Shadow without hard edges: thin darkening layers stacked, each a bit
// smaller, so it's darkest behind the text and fades out on every side
function SoftShadow(GC gc, float Y, float H, float W, float a)
{
	local int i;
	local float inX, inY;

	for (i = 0; i < 9; i++)
	{
		inX = i * W * 0.07;
		inY = i * 6 * S;
		if (H - inY * 2 <= 2)
			break;
		Class'RISkin'.static.DrawDim(gc, 0, Y - 28 * S + inY, W - inX, H + 56 * S - inY * 2, 0.11 * a);
	}
}

// Word-wrapped, each line centred
function DrawCentered(GC gc, float X, float Y, float W, string T, Color C)
{
	local string Para, Rest, Line, Word, Try;
	local int p;
	local float lh, tw;
	local bool bMore;

	lh = Class'RIText'.static.LineHeight(Class'RIFontBody', 1.0) * 1.4;
	Rest = T;
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
			if (Line == "")
				Try = Word;
			else
				Try = Line @ Word;
			if ((Line != "") && (Class'RIText'.static.Width(Class'RIFontBody', Try, 1.0) > W))
			{
				tw = Class'RIText'.static.Width(Class'RIFontBody', Line, 1.0);
				Class'RIText'.static.Draw(gc, Class'RIFontBody', X + (W - tw) * 0.5, Y, Line, C, 1.0);
				Y += lh;
				Line = Word;
			}
			else
				Line = Try;
		}
		if (Line != "")
		{
			tw = Class'RIText'.static.Width(Class'RIFontBody', Line, 1.0);
			Class'RIText'.static.Draw(gc, Class'RIFontBody', X + (W - tw) * 0.5, Y, Line, C, 1.0);
		}
		Y += lh;
	}
}

defaultproperties
{
     CreditsLabel="Credits"
}
