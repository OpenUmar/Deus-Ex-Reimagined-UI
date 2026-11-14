//=============================================================================
// RIDeathScreen
// The death screen as a real (modal) window, so its buttons take the mouse as
// well as the keyboard. RIRootWindow opens it by itself a moment after the
// player dies and acts on the choice in BoxOptionSelected:
//   0  last checkpoint        (Enter / Space on the first button)
//   1  restart mission        (R)
//   2  load game              (L)
//   3  main menu              (Escape)
// Drawn in the selected UI style: Sleek gold, or the Vanilla+ frame and
// chamfered buttons. Built on RIMessageBox for its input handling.
//=============================================================================
class RIDeathScreen extends RIMessageBox;

var string LocStr;
var float  TitleY, CY;

function SetDeath(string Title, string Location, string A, string B, string C, string D)
{
	TitleStr = Title;
	LocStr = Location;
	SetCustomButtons(A, B, C, D);
}

function UpdateFrame(float deltaSeconds)
{
	local int b;
	local float btnW, btnH, gap, y;

	Age += deltaSeconds;
	HideParts();

	UIS = GetRootWindow().height / 1080.0;
	CY = height * 0.42;
	TitleY = CY - 110 * UIS;
	btnW = 380 * UIS;
	btnH = 44 * UIS;
	gap = 12 * UIS;
	y = CY + 14 * UIS;

	// The panel round the buttons (Vanilla+ frames it)
	PW = btnW + 60 * UIS;
	PX = Class'RIText'.static.Snap((width - PW) * 0.5);
	PY = Class'RIText'.static.Snap(y - 22 * UIS);
	PH = NumB * btnH + (NumB - 1) * gap + 44 * UIS;

	for (b = 0; b < NumB; b++)
	{
		BX[b] = Class'RIText'.static.Snap((width - btnW) * 0.5);
		BY[b] = Class'RIText'.static.Snap(y);
		BW[b] = btnW;
		BH[b] = btnH;
		y += btnH + gap;

		if ((b == FocusB) || (b == HoverB))
			BHot[b] = FMin(1.0, BHot[b] + deltaSeconds * 10.0);
		else
			BHot[b] = FMax(0.0, BHot[b] - deltaSeconds * 6.0);
	}
}

event bool VirtualKeyPressed(EInputKey key, bool bRepeat)
{
	if (bRepeat)
		return True;
	if (key == IK_R)
	{
		Choose(1);
		return True;
	}
	if (key == IK_L)
	{
		Choose(2);
		return True;
	}
	return Super.VirtualKeyPressed(key, bRepeat);
}

event DrawWindow(GC gc)
{
	local float a, ba, hot;
	local int b;
	local Color Edge, Txt;
	local string K;

	UpdateFrame(FrameDelta());
	a = Class'RIUtil'.static.Phase(Age, 0.0, 0.5);
	gc.EnableSmoothing(True);
	Class'RITheme'.static.SetMode(2);

	Class'RISkin'.static.DrawDim(gc, 0, 0, width, height, 0.55 * a);
	Class'RISkin'.static.DrawDim(gc, 0, CY - 140 * UIS, width, 410 * UIS, 0.35 * a);

	if (Class'RIVP'.static.On())
	{
		Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', 0, TitleY, width, 60 * UIS, TitleStr, Class'RIVP'.static.Txt(a), 1, 0.95);
		if (LocStr != "")
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', 0, CY - 46 * UIS, width, 20 * UIS, Caps(LocStr), Class'RIVP'.static.Lbl(a), 1, 0.62);
		Class'RIVP'.static.Dim(gc, PX + 4 * UIS, PY + 4 * UIS, PW - 8 * UIS, PH - 8 * UIS);
		Class'RIVP'.static.Frame(gc, PX, PY, PW, PH, 16 * UIS, a);
	}
	else
	{
		Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', 0, TitleY, width, 60 * UIS, TitleStr, Class'RIUtil'.static.Col(255 * a, 241 * a, 194 * a), 1, 0.95);
		if (LocStr != "")
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', 0, CY - 46 * UIS, width, 20 * UIS, Caps(LocStr), Class'RIUtil'.static.Col(168 * a, 143 * a, 78 * a), 1, 0.62);
		Class'RISkin'.static.FillC(gc, width * 0.5 - 220 * UIS, CY - 16 * UIS, 440 * UIS, 1.5 * UIS, Class'RIUtil'.static.Col(126 * a, 105 * a, 50 * a));
	}

	for (b = 0; b < NumB; b++)
	{
		ba  = a * Class'RIUtil'.static.Phase(Age, 0.1 + b * 0.06, 0.3);
		hot = BHot[b];
		if (b == FocusB)
			hot = 1.0;
		if (b == 0)
			K = "ENTER";
		else if (b == 1)
			K = "R";
		else if (b == 2)
			K = "L";
		else
			K = "ESC";

		if (Class'RIVP'.static.On())
		{
			Class'RIVP'.static.Btn(gc, BX[b], BY[b], BW[b], BH[b], hot > 0.5, ba);
			if (hot > 0.5)
				Txt = Class'RIUtil'.static.Col(255 * ba, 241 * ba, 194 * ba);
			else
				Txt = Class'RIVP'.static.Acc(ba);
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', BX[b] + 18 * UIS, BY[b], BW[b] - 36 * UIS, BH[b], Caps(Class'RIText'.static.Clean(BLabel[b])), Txt, 0, 0.54);
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', BX[b], BY[b], BW[b] - 30 * UIS, BH[b], K, Class'RIVP'.static.Lbl(ba), 2, 0.5);
		}
		else
		{
			gc.SetStyle(DSTY_Translucent);
			gc.SetTileColor(Class'RIUtil'.static.Col(70 * hot * ba, 58 * hot * ba, 26 * hot * ba));
			Class'RIText'.static.Tex(gc, BX[b], BY[b], BW[b], BH[b], 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');
			Edge = Class'RIUtil'.static.Col((126 + 100 * hot) * ba, (105 + 90 * hot) * ba, (50 + 60 * hot) * ba);
			Txt  = Class'RIUtil'.static.Col((230 + 25 * hot) * ba, (195 + 46 * hot) * ba, (117 + 77 * hot) * ba);
			Class'RIText'.static.Box(gc, BX[b], BY[b], BW[b], BH[b], Edge);
			if (b == FocusB)
			{
				gc.SetStyle(DSTY_Translucent);
				gc.SetTileColor(Class'RIUtil'.static.Col(242 * ba, 211 * ba, 107 * ba));
				Class'RIText'.static.Fill(gc, BX[b], BY[b], 1.5, BH[b]);
			}
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', BX[b] + 18 * UIS, BY[b], BW[b] - 36 * UIS, BH[b], Caps(Class'RIText'.static.Clean(BLabel[b])), Txt, 0, 0.54);
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', BX[b], BY[b], BW[b] - 18 * UIS, BH[b], K, Class'RIUtil'.static.Col(168 * ba, 143 * ba, 78 * ba), 2, 0.5);
		}
	}
	Class'RITheme'.static.SetMode(0);
}

defaultproperties
{
}
