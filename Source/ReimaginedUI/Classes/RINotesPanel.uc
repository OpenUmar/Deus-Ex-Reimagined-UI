//=============================================================================
// RINotesPanel
// AE's code-notes panel (beside keypads, and later computer logins) drawn
// natively in the Sleek gold: a titled panel of note cards in Exo 2, the
// hovered card lit with an accent bar. Same notes as AE picks (the relevant
// ones, or all of them in Hardcore / No Keypad Cheese), same autofill: click
// a card, or Space for the hovered (else first) one. The mouse wheel scrolls.
// AE's riveted box, scrollbar and edit widgets are never created.
//=============================================================================
class RINotesPanel extends HUDKeypadNotesWindow;

const MAXSHOWN = 64;

var DeusExNote Shown[64];
var int   NumShown;
var int   FirstCard;           // top card when scrolled
var int   HoverCard;
var float CardY[64], CardH[64];
var int   LastCard;            // last card drawn whole
var float MouseX, MouseY;

var localized string NotesTitle, CountLabel, HintAutofill, HintScroll, HintSpace;

event InitWindow()
{
	// skip AE's InitWindow: its riveted background box isn't wanted
	Super(HUDBaseWindow).InitWindow();
	HoverCard = -1;
}

function Resize(float NewW, float NewH)
{
	SetSize(NewW, NewH);
}

// AE builds its scroll list here; this panel just gathers the same notes
function CreateNotesList()
{
	local DeusExNote N;
	local int i;

	NumShown = 0;
	if ((player.bHardcoreMode && !player.bGMDXDebug) || (player.iNoKeypadCheese > 0))
	{
		for (N = player.FirstNote; (N != None) && (NumShown < MAXSHOWN); N = N.next)
			if (!N.bHidden)
				Shown[NumShown++] = N;
	}
	else
	{
		for (i = 0; (i < NotesCount) && (NumShown < MAXSHOWN); i++)
			if ((Notes[i] != None) && !Notes[i].bHidden)
				Shown[NumShown++] = Notes[i];
	}
	if (NumShown > 0)
		currentNote = Shown[0];
}

function float UIS()
{
	return GetRootWindow().height / 1080.0;
}

function bool CanFill(DeusExNote N)
{
	return (N != None) && player.bAutofillPasswords && Class'CodeUtils'.static.CanAutofill(N);
}

function int CardAt(float px, float py)
{
	local int i;

	for (i = FirstCard; i <= LastCard; i++)
		if ((i >= 0) && (i < NumShown) && (py >= CardY[i]) && (py < CardY[i] + CardH[i]) && (px >= 30 * UIS()) && (px < width - 30 * UIS()))
			return i;
	return -1;
}

function Scroll(int d)
{
	FirstCard = Clamp(FirstCard + d, 0, Max(0, NumShown - 1));
	HoverCard = CardAt(MouseX, MouseY);
}

event MouseMoved(float newX, float newY)
{
	MouseX = newX;
	MouseY = newY;
	HoverCard = CardAt(newX, newY);
}

event MouseLeftWindow()
{
	HoverCard = -1;
}

event bool MouseButtonPressed(float pointX, float pointY, EInputKey button, int numClicks)
{
	local int k;

	if (button == IK_MouseWheelUp)
	{
		Scroll(-1);
		return True;
	}
	if (button == IK_MouseWheelDown)
	{
		Scroll(1);
		return True;
	}
	if (button == IK_LeftMouse)
	{
		k = CardAt(pointX, pointY);
		if (k >= 0)
		{
			currentNote = Shown[k];
			if (CanFill(currentNote))
				PlaySound(Sound'DeusExSounds.UserInterface.Menu_Press', 0.25);
			AutofillCurrentNote();
		}
		return True;
	}
	return False;
}

event bool VirtualKeyPressed(EInputKey key, bool bRepeat)
{
	if (key == IK_MouseWheelUp)
	{
		Scroll(-1);
		return True;
	}
	if (key == IK_MouseWheelDown)
	{
		Scroll(1);
		return True;
	}
	if (key == IK_Space)
	{
		if (HoverCard >= 0)
			currentNote = Shown[HoverCard];
		AutofillCurrentNote();
		return True;
	}
	return Super.VirtualKeyPressed(key, bRepeat);
}

event DrawWindow(GC gc)
{
	local float s, ts, w, h, cx, cw, yy, bottom, pad, th, sc;
	local int i;
	local bool bHot, bMore;
	local string T, H2;
	local Color cEdge;

	Class'RITheme'.static.SetMode(2);
	s  = UIS();
	ts = s * 2.0;
	w  = width;
	h  = height;
	sc = 0.74 * ts;

	// --- panel (as the keypad's)
	gc.SetStyle(DSTY_Modulated);
	gc.DrawStretchedTexture(-60 * s, -60 * s, w + 120 * s, h + 120 * s, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_ShadeC');
	Class'RIVP'.static.Dim(gc, 0, 0, w, h);
	Class'RIVP'.static.Dim(gc, 0, 0, w, h);
	Class'RISkin'.static.FillC(gc, 0, 0, w, h, Class'RIUtil'.static.Col(12, 10, 4));
	Class'RIText'.static.Box(gc, 0, 0, w, h, Class'RIUtil'.static.Col(126, 105, 50));
	Class'RISkin'.static.FillC(gc, 0, 0, 120 * s, 3 * s, Class'RIVP'.static.Acc(1));

	Class'RIText'.static.Draw(gc, Class'RIFontHead', 30 * s, 26 * s, Caps(NotesTitle), Class'RIUtil'.static.Col(255, 241, 194), 0.62 * ts);
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', 0, 24 * s, w - 30 * s, 20 * s,
		NumShown $ " " $ CountLabel, Class'RIVP'.static.Lbl(1), 2, 0.8 * ts);

	// --- cards
	cx = 30 * s;
	cw = w - 60 * s;
	pad = 14 * s;
	yy = 62 * s;
	bottom = h - 52 * s;
	LastCard = FirstCard - 1;
	bMore = False;
	for (i = FirstCard; i < NumShown; i++)
	{
		T = Class'RIText'.static.Clean(Shown[i].text);
		th = Class'RIText'.static.DrawWrapped(None, Class'RIFontBody', 0, 0, cw - pad * 2 - 6 * s, T, Class'RIUtil'.static.Col(0, 0, 0), sc, 1.35);
		CardY[i] = yy;
		CardH[i] = th + pad * 2 - 4 * s;
		if ((yy + CardH[i] > bottom) && (i > FirstCard))
		{
			bMore = True;
			break;
		}
		bHot = (i == HoverCard);
		Class'RIVP'.static.Dim(gc, cx, yy, cw, CardH[i]);
		if (bHot)
			Class'RISkin'.static.FillC(gc, cx, yy, cw, CardH[i], Class'RIUtil'.static.Col(30, 25, 11));
		else
			Class'RISkin'.static.FillC(gc, cx, yy, cw, CardH[i], Class'RIUtil'.static.Col(16, 13, 6));
		if (bHot)
			cEdge = Class'RIUtil'.static.Col(200, 168, 96);
		else
			cEdge = Class'RIUtil'.static.Col(70, 58, 28);
		Class'RIText'.static.Box(gc, cx, yy, cw, CardH[i], cEdge);
		// accent bar down the left edge: gold on the hovered card, and on any
		// card that can autofill this lock
		if (bHot)
			Class'RISkin'.static.FillC(gc, cx, yy, 3 * s, CardH[i], Class'RIVP'.static.Acc(1));
		else if (CanFill(Shown[i]))
			Class'RISkin'.static.FillC(gc, cx, yy, 3 * s, CardH[i], Class'RIUtil'.static.Col(126, 105, 50));
		Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', cx + pad + 6 * s, yy + pad - 4 * s, cw - pad * 2 - 6 * s, T,
			Class'RIUtil'.static.Col(240, 222, 178), sc, 1.35);
		LastCard = i;
		yy += CardH[i] + 10 * s;
	}

	// --- footer hints
	H2 = "";
	if (player.bAutofillPasswords)
		H2 = HintAutofill $ "     " $ HintSpace;
	if (bMore || (FirstCard > 0))
	{
		if (H2 != "")
			H2 = H2 $ "     ";
		H2 = H2 $ HintScroll;
	}
	if (H2 != "")
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', 0, h - 38 * s, w, 22 * s, H2, Class'RIVP'.static.Lbl(0.85), 1, 0.72 * ts);
	if (bMore)
		Class'RISkin'.static.FillC(gc, cx, bottom + 4 * s, cw, 2 * s, Class'RIUtil'.static.Col(70, 58, 28));
}

defaultproperties
{
     NotesTitle="Code Notes"
     CountLabel="NOTES"
     HintAutofill="CLICK  AUTOFILL"
     HintSpace="SPACE  AUTOFILL HOVERED"
     HintScroll="WHEEL  SCROLL"
}
