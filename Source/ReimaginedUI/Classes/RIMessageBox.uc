//=============================================================================
// RIMessageBox
// Replaces AE's message box (every "Are you sure?" / confirm / notice).
// AE's logic is kept: results go to the same notify window, Y / N / Enter /
// Escape behave as before. AE's widgets are hidden and the box is drawn
// natively: dimmed screen, a centred panel that rises in, Michroma title,
// wrapped Exo 2 message and animated buttons (mouse or arrow keys).
// RIMenuSettings also uses it for Apply / Discard / Stay.
//=============================================================================
class RIMessageBox extends MenuUIMessageBoxWindow;

var string TitleStr, MsgStr;
var float  Age, UIS;

var int    NumB;
var string BLabel[3];
var int    BResult[3];
var float  BX[3], BY[3], BW[3], BH[3], BHot[3];
var int    FocusB, HoverB;
var bool   bCustom;

var float  PX, PY, PW, PH, Pad, MsgH;
var float  LastClock;
var bool   bReady;

event InitWindow()
{
	Super.InitWindow();
	SetWindowAlignments(HALIGN_Full, VALIGN_Full);
	SetSelectability(True);
	HoverB = -1;
	// No Tick: AE opens some boxes from inside its own Tick, and a ticking
	// window created mid-tick trips the engine (ExtRoot initCount assert).
	// Animation is driven from DrawWindow with the root's clock instead.
}

event WindowReady()
{
	Super.WindowReady();
	// Only flag readiness here. WindowReady runs INSIDE the engine's ready pass
	// (XRootWindow::InitializeWindows, called from PostRender), which walks the
	// visible tree once. Hiding or focusing here fires AE events that can SHOW
	// a window behind the walk; it is then counted but never readied, and the
	// engine stops with "initCount == 0". All hiding happens later, outside it.
	bReady = True;
}

// AE's own box widgets; hidden as soon as they exist (see RIPanel.HideScreenParts)
function HideParts()
{
	local Window C;

	for (C = GetTopChild(); C != None; C = C.GetLowerSibling())
		if (C.IsVisible(False))
			C.Hide();
}

function SetTitle(String newTitle)
{
	TitleStr = newTitle;
	Super.SetTitle(newTitle);
}

function SetMessageText(String msgText)
{
	MsgStr = msgText;
	Super.SetMessageText(msgText);
}

function SetMode(int newMode)
{
	Super.SetMode(newMode);

	if (!bCustom)
	{
		if (newMode == 0)
		{
			NumB = 2;
			BLabel[0] = btnLabelYes;  BResult[0] = 0;
			BLabel[1] = btnLabelNo;   BResult[1] = 1;
		}
		else
		{
			NumB = 1;
			BLabel[0] = btnLabelOK;   BResult[0] = 0;
		}
	}
	FocusB = 0;
	SetWindowAlignments(HALIGN_Full, VALIGN_Full);
	HideParts();                // before the first frame: no flash of AE's box
	SetFocusWindow(Self);
}

// Three labelled choices; results 0, 1, 2. Escape picks the third.
function SetCustomButtons(string A, string B, string C)
{
	bCustom = True;
	NumB = 3;
	BLabel[0] = A;  BResult[0] = 0;
	BLabel[1] = B;  BResult[1] = 1;
	BLabel[2] = C;  BResult[2] = 2;
	FocusB = 0;
}

function Choose(int b)
{
	if ((b < 0) || (b >= NumB))
		return;
	PlaySound(Sound'DeusExSounds.UserInterface.Menu_Press', 0.25);
	PostResult(BResult[b]);
}

// ----------------------------------------------------------------------
// Layout and update
// ----------------------------------------------------------------------

function UpdateFrame(float deltaSeconds)
{
	local int b;
	local float x, total, a;

	Age += deltaSeconds;
	HideParts();

	UIS = GetRootWindow().height / 1080.0;
	Pad = 34 * UIS;
	PW  = FMin(width - 80 * UIS, 700 * UIS);
	MsgH = Class'RIText'.static.DrawWrapped(None, Class'RIFontBody', 0, 0, PW - Pad * 2, MsgStr,
		Class'RIUtil'.static.Col(0, 0, 0), 1.0, 1.4);
	PH = Pad + 30 * UIS + 26 * UIS + MsgH + 30 * UIS + 44 * UIS + Pad;

	a = Class'RIUtil'.static.Phase(Age, 0.0, 0.25);
	PX = Class'RIText'.static.Snap((width - PW) * 0.5);
	PY = Class'RIText'.static.Snap((height - PH) * 0.5 + (1.0 - a) * 18 * UIS);

	// Buttons right-aligned along the bottom, first (primary) on the left
	total = 0;
	for (b = 0; b < NumB; b++)
	{
		BW[b] = FMax(130 * UIS, Class'RIText'.static.Width(Class'RIFontHead', Caps(BLabel[b]), 0.56) + 56 * UIS);
		total += BW[b];
	}
	total += (NumB - 1) * 12 * UIS;
	x = PX + PW - Pad - total;
	for (b = 0; b < NumB; b++)
	{
		BX[b] = x;
		BY[b] = PY + PH - Pad - 44 * UIS;
		BH[b] = 44 * UIS;
		x += BW[b] + 12 * UIS;

		if ((b == FocusB) || (b == HoverB))
			BHot[b] = FMin(1.0, BHot[b] + deltaSeconds * 10.0);
		else
			BHot[b] = FMax(0.0, BHot[b] - deltaSeconds * 6.0);
	}
}

// Seconds since the last draw, from the root window's clock
function float FrameDelta()
{
	local float Now, dt;

	if (RIRootWindow(GetRootWindow()) == None)
		return 0.016;
	Now = RIRootWindow(GetRootWindow()).BackdropTime;
	dt = 0;
	if (LastClock > 0)
		dt = FClamp(Now - LastClock, 0, 0.1);
	LastClock = Now;
	return dt;
}

function int BtnAt(float X, float Y)
{
	local int b;

	for (b = 0; b < NumB; b++)
		if ((X >= BX[b]) && (X <= BX[b] + BW[b]) && (Y >= BY[b]) && (Y <= BY[b] + BH[b]))
			return b;
	return -1;
}

// ----------------------------------------------------------------------
// Input (the box is modal: it swallows every click)
// ----------------------------------------------------------------------

event MouseMoved(float newX, float newY)
{
	HoverB = BtnAt(newX, newY);
	if (HoverB >= 0)
		FocusB = HoverB;
}

event bool MouseButtonPressed(float pointX, float pointY, EInputKey button, int numClicks)
{
	local int b;

	if (button == IK_LeftMouse)
	{
		b = BtnAt(pointX, pointY);
		if (b >= 0)
			Choose(b);
	}
	return True;
}

event bool MouseButtonReleased(float pointX, float pointY, EInputKey button, int numClicks)
{
	return True;
}

event bool VirtualKeyPressed(EInputKey key, bool bRepeat)
{
	// (if/else rather than switch + break: UCC can't compile a break inside an if)
	if ((key == IK_Left) || (key == IK_Up))
	{
		if (NumB > 0)
			FocusB = (FocusB + NumB - 1) % NumB;
		return True;
	}

	if ((key == IK_Right) || (key == IK_Down) || (key == IK_Tab))
	{
		if (NumB > 0)
			FocusB = (FocusB + 1) % NumB;
		return True;
	}

	// The first button keeps AE's own Enter handling (it may wait for key release)
	if (((key == IK_Enter) || (key == IK_Space)) && ((FocusB != 0) || bCustom))
	{
		Choose(FocusB);
		return True;
	}

	if ((key == IK_Escape) && bCustom)
	{
		Choose(2);
		return True;
	}

	return Super.VirtualKeyPressed(key, bRepeat);
}

// ----------------------------------------------------------------------
// Drawing
// ----------------------------------------------------------------------

event DrawWindow(GC gc)
{
	local float a, ba, hot, y;
	local int b;
	local Color Edge, Fill, Txt;

	UpdateFrame(FrameDelta());

	a = Class'RIUtil'.static.Phase(Age, 0.0, 0.25);
	gc.EnableSmoothing(True);
	if (Class'RIVP'.static.InMenus())
	{
		DrawVP(gc, a);
		return;
	}

	// Dim everything behind
	Class'RISkin'.static.DrawDim(gc, 0, 0, width, height, 0.7 * a);
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(4 * a, 5 * a, 18 * a));
	Class'RIText'.static.Fill(gc, 0, 0, width, height);

	// Panel: darkened, navy wash, glow at the top, hairline border
	Class'RISkin'.static.DrawDim(gc, PX, PY, PW, PH, a);
	Class'RISkin'.static.DrawDim(gc, PX, PY, PW, PH, 0.6 * a);
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(12 * a, 14 * a, 48 * a));
	Class'RIText'.static.Fill(gc, PX, PY, PW, PH);
	gc.SetTileColor(Class'RIUtil'.static.Col(26 * a, 28 * a, 84 * a));
	gc.DrawStretchedTexture(PX, PY, PW, 70 * UIS, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');

	Class'RIText'.static.Box(gc, PX, PY, PW, PH, Class'RIUtil'.static.Col(110 * a, 116 * a, 214 * a));
	Class'RIText'.static.Box(gc, PX - 3 * UIS, PY - 3 * UIS, PW + 6 * UIS, PH + 6 * UIS, Class'RIUtil'.static.Col(26 * a, 28 * a, 84 * a));
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(205 * a, 210 * a, 255 * a));
	Class'RIText'.static.Fill(gc, PX, PY, 70 * UIS * a, 1.5);

	// Title
	y = PY + Pad;
	Class'RIText'.static.Draw(gc, Class'RIFontHead', PX + Pad, y, Caps(Class'RIText'.static.Clean(TitleStr)),
		Class'RIUtil'.static.Col(240 * a, 242 * a, 255 * a), 0.72);
	y += 30 * UIS;
	Class'RIText'.static.HLine(gc, PX + Pad, y + 8 * UIS, PW - Pad * 2, Class'RIUtil'.static.Col(44 * a, 48 * a, 128 * a));
	y += 26 * UIS;

	// Message
	Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', PX + Pad, y, PW - Pad * 2, MsgStr,
		Class'RIUtil'.static.Col(190 * a, 196 * a, 240 * a), 1.0, 1.4);

	// Buttons
	for (b = 0; b < NumB; b++)
	{
		ba  = a * Class'RIUtil'.static.Phase(Age, 0.08 + b * 0.05, 0.25);
		hot = BHot[b];

		if (b == 0)
		{
			Fill = Class'RIUtil'.static.Col((40 + 34 * hot) * ba, (44 + 34 * hot) * ba, (140 + 70 * hot) * ba);
			Edge = Class'RIUtil'.static.Col(190 * ba, 196 * ba, 255 * ba);
			Txt  = Class'RIUtil'.static.Col(255 * ba, 255 * ba, 255 * ba);
		}
		else
		{
			Fill = Class'RIUtil'.static.Col(30 * hot * ba, 32 * hot * ba, 96 * hot * ba);
			Edge = Class'RIUtil'.static.Col((70 + 100 * hot) * ba, (74 + 100 * hot) * ba, (170 + 80 * hot) * ba);
			Txt  = Class'RIUtil'.static.Col((186 + 69 * hot) * ba, (190 + 65 * hot) * ba, (236 + 19 * hot) * ba);
		}

		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(Fill);
		gc.DrawStretchedTexture(BX[b], BY[b], BW[b], BH[b], 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');
		Class'RIText'.static.Box(gc, BX[b], BY[b], BW[b], BH[b], Edge);

		// Keyboard focus: accent bar on the left edge
		if (b == FocusB)
		{
			gc.SetStyle(DSTY_Translucent);
			gc.SetTileColor(Class'RIUtil'.static.Col(220 * ba, 224 * ba, 255 * ba));
			Class'RIText'.static.Fill(gc, BX[b], BY[b], 1.5, BH[b]);
		}
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', BX[b], BY[b], BW[b], BH[b],
			Caps(Class'RIText'.static.Clean(BLabel[b])), Txt, 1, 0.56);
	}
}

// Vanilla+: the gold frame, a header tab for the title, chamfered buttons
function DrawVP(GC gc, float a)
{
	local float y, ba, tw;
	local int b;

	Class'RISkin'.static.DrawDim(gc, 0, 0, width, height, 0.7 * a);
	Class'RIVP'.static.Black(gc, PX + 4 * UIS, PY + 4 * UIS, PW - 8 * UIS, PH - 8 * UIS);
	Class'RIVP'.static.Frame(gc, PX, PY, PW, PH, 16 * UIS, a);

	y = PY + Pad;
	tw = FMin(PW - Pad * 2, Class'RIText'.static.Width(Class'RIFontHead', Caps(Class'RIText'.static.Clean(TitleStr)), 0.6) + 90 * UIS);
	Class'RIVP'.static.Hdr(gc, PX + Pad - 12 * UIS, y - 4 * UIS, tw, 34 * UIS, a);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', PX + Pad + 4 * UIS, y - 4 * UIS, tw - 50 * UIS, 34 * UIS,
		Caps(Class'RIText'.static.Clean(TitleStr)), Class'RIVP'.static.Txt(a), 0, 0.6);
	y += 30 * UIS + 26 * UIS;
	Class'RIVP'.static.Inset(gc, PX + Pad - 10 * UIS, y - 10 * UIS, PW - Pad * 2 + 20 * UIS, MsgH + 20 * UIS, 0.7 * a);
	Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', PX + Pad, y, PW - Pad * 2, MsgStr,
		Class'RIVP'.static.Txt(a), 1.0, 1.4);

	for (b = 0; b < NumB; b++)
	{
		ba = a * Class'RIUtil'.static.Phase(Age, 0.08 + b * 0.05, 0.25);
		Class'RIVP'.static.Btn(gc, BX[b], BY[b], BW[b], BH[b], (BHot[b] > 0.5) || (b == FocusB), ba);
		if ((BHot[b] > 0.5) || (b == FocusB))
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', BX[b], BY[b], BW[b] - 16 * UIS, BH[b],
				Caps(Class'RIText'.static.Clean(BLabel[b])), Class'RIUtil'.static.Col(255 * ba, 241 * ba, 194 * ba), 1, 0.54);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', BX[b], BY[b], BW[b] - 16 * UIS, BH[b],
				Caps(Class'RIText'.static.Clean(BLabel[b])), Class'RIVP'.static.Acc(ba), 1, 0.54);
	}
}

defaultproperties
{
}
