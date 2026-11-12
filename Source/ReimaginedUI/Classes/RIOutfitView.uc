//=============================================================================
// RIOutfitView
// Inventory > Outfit, rebuilt in the original gold over Augmentique's outfit
// screen (Augmentique.PersonaScreenOutfits). Augmentique stays in charge:
// its list, buttons and checkboxes are kept (shrunk out of sight) and this
// page reads them and presses them, so equipping, customising, the camera
// and the settings all run Augmentique's own code. Its 3D preview
// (a ViewportWindow) is kept live and framed in the middle of the page.
// Augmentique isn't referenced by class: its widgets are found by type, in
// the order Augmentique creates them.
//=============================================================================
class RIOutfitView extends RIPersonaView;

const HOT_ROW      = 100;   // + list index
const HOT_EQUIP    = 50;
const HOT_EDIT     = 51;
const HOT_CAMERA   = 52;
const HOT_SETTINGS = 53;
const HOT_ACC      = 54;
const HOT_DESC     = 55;
const HOT_PREV     = 300;   // + part row
const HOT_NEXT     = 330;   // + part row

var Window      Client, Viewport;
var ListWindow  OutList;
var Window      BtnSettings, BtnCamera, BtnEdit, BtnEquip;
var ToggleWindow ChkAcc, ChkDesc;
var TextWindow  TxtName, TxtDesc, TxtVariant;
var Window      VarPrev, VarNext;
var Window      SlotPrev[24], SlotNext[24];
var TextWindow  SlotTxt[24];
var int         NumSlots;
var bool        bFound;

// Part rows shown this frame (customise mode): their < and > buttons
var Window      RowPrev[25], RowNext[25];
var int         NumRows;

var float DescAge;
var float ListScroll, ListScrollTarget, ListMax, ListTop, ListBottom, ListRight;
var float PVX, PVY, PVW, PVH;     // preview rectangle (UI units)

var localized string OutfitsTitle, PartsTitle, AccLabel, DescLabel, NoneLabel, WearingLabel, HintText, NoAugmentiqueLabel;

function ScreenAttached()
{
	ActiveTab = TAB_OUTFIT;
	FindWidgets();
}

// ----------------------------------------------------------------------
// Augmentique's widgets, in creation order (see its CreateControls)
// ----------------------------------------------------------------------

function FindWidgets()
{
	local Window C, B;
	local Window Q[2];
	local int nq, nb;
	local string L;

	Client = Screen.winClient;
	if (Client == None)
		return;
	nq = 0;
	for (C = Client.GetBottomChild(); C != None; C = C.GetHigherSibling())
	{
		if (ViewportWindow(C) != None)
			Viewport = C;
		else if ((ScrollAreaWindow(C) != None) && (ScrollAreaWindow(C).clipWindow != None))
			OutList = ListWindow(ScrollAreaWindow(C).clipWindow.GetBottomChild());
		else if (PersonaButtonBarWindow(C) != None)
		{
			// Settings, Change View, Customize, Equip (Augmentique's order)
			nb = 0;
			// (the bar's filler window sits below the buttons: skip it)
			for (B = C.GetBottomChild(); B != None; B = B.GetHigherSibling())
			{
				if (ButtonWindow(B) == None)
					continue;
				if (nb == 0)
					BtnSettings = B;
				else if (nb == 1)
					BtnCamera = B;
				else if (nb == 2)
					BtnEdit = B;
				else if (nb == 3)
					BtnEquip = B;
				nb++;
			}
		}
		else if (ToggleWindow(C) != None)
		{
			if (ChkAcc == None)
				ChkAcc = ToggleWindow(C);
			else
				ChkDesc = ToggleWindow(C);
		}
		else if (PersonaBorderButtonWindow(C) != None)
		{
			if (nq < 2)
				Q[nq++] = C;
		}
		else if (TextWindow(C) != None)
		{
			if (nq == 2)
			{
				L = PersonaBorderButtonWindow(Q[0]).buttonText;
				if (L == "<")
				{
					// A body slot: <, >, label
					if (NumSlots < 24)
					{
						SlotPrev[NumSlots] = Q[0];
						SlotNext[NumSlots] = Q[1];
						SlotTxt[NumSlots] = TextWindow(C);
						NumSlots++;
					}
				}
				else
				{
					// The model variant: >, <, label
					VarNext = Q[0];
					VarPrev = Q[1];
					TxtVariant = TextWindow(C);
				}
				nq = 0;
			}
			else if (TxtName == None)
				TxtName = TextWindow(C);
			else
				TxtDesc = TextWindow(C);
		}
	}
	bFound = (Viewport != None) && (OutList != None) && (BtnEquip != None);
}

// Keep Augmentique's own widgets out of sight (shrunk, not hidden, so their
// "shown" state stays readable), its frame hidden, and the preview placed
function PageTick(float deltaSeconds)
{
	local Window C;

	DescAge += deltaSeconds;
	ListScrollTarget = FClamp(ListScrollTarget, 0, FMax(0, ListMax));
	ListScroll += (ListScrollTarget - ListScroll) * FMin(1.0, deltaSeconds * 14.0);
	if (Client == None)
		return;

	for (C = Screen.GetTopChild(); C != None; C = C.GetLowerSibling())
		if ((C != Self) && (C != Client) && C.IsVisible(False))
			C.Hide();
	for (C = Client.GetTopChild(); C != None; C = C.GetLowerSibling())
		if ((C != Viewport) && ((C.width > 0) || (C.height > 0)))
			C.SetSize(0, 0);

	if ((PVW > 0) && ((Client.x != PVX + x) || (Client.y != PVY + y) || (Client.width != PVW) || (Client.height != PVH)))
	{
		Client.SetConfiguration(PVX + x, PVY + y, PVW, PVH);
		ClearClientArt();
	}
	if ((Viewport != None) && ((Viewport.x != 0) || (Viewport.y != 0) || (Viewport.width != Client.width) || (Viewport.height != Client.height)))
		Viewport.SetConfiguration(0, 0, Client.width, Client.height);
}

function ClearClientArt()
{
	local int i;

	if (PersonaClientBaseWindow(Client) != None)
		for (i = 0; i < 6; i++)
			PersonaClientBaseWindow(Client).SetClientTexture(i, None);
}

// ----------------------------------------------------------------------
// Acting through Augmentique
// ----------------------------------------------------------------------

function bool Live(Window B)
{
	return (B != None) && B.IsSensitive() && B.IsVisible(False);
}

function Press(Window B)
{
	if (!Live(B))
		return;
	PlaySound(Sound'Menu_Press', 0.25);
	Screen.ButtonActivated(B);
}

function SelectIndex(int i)
{
	local int rowId;

	if ((OutList == None) || (i < 0) || (i >= OutList.GetNumRows()))
		return;
	rowId = OutList.IndexToRowId(i);
	OutList.SelectRow(rowId, True);
	Screen.ListSelectionChanged(OutList, 1, rowId);
	DescAge = 0;
}

function int SelIndex()
{
	local int i;

	if (OutList == None)
		return -1;
	for (i = 0; i < OutList.GetNumRows(); i++)
		if (OutList.IsRowSelected(OutList.IndexToRowId(i)))
			return i;
	return -1;
}

function Toggle(ToggleWindow T)
{
	if ((T == None) || !T.IsVisible(False))
		return;
	T.ChangeToggle();
	Screen.ToggleChanged(T, T.GetToggle());
	PlaySound(Sound'Menu_Press', 0.25);
}

function string BtnLabel(Window B, string Fallback)
{
	local string T;

	if (PersonaBorderButtonWindow(B) == None)
		return Fallback;
	T = Class'RIText'.static.Clean(PersonaBorderButtonWindow(B).buttonText);
	if (T == "")
		T = Fallback;
	return T;
}

function PageClick(int Id, EInputKey button, int numClicks)
{
	if (button != IK_LeftMouse)
		return;
	if ((Id >= HOT_ROW) && (Id < HOT_ROW + 128))
	{
		if ((numClicks >= 2) && (SelIndex() == Id - HOT_ROW))
			Press(BtnEquip);
		else
		{
			SelectIndex(Id - HOT_ROW);
			PlaySound(Sound'Menu_Press', 0.2);
		}
	}
	else if (Id == HOT_EQUIP)
		Press(BtnEquip);
	else if (Id == HOT_EDIT)
		Press(BtnEdit);
	else if (Id == HOT_CAMERA)
		Press(BtnCamera);
	else if (Id == HOT_SETTINGS)
		Press(BtnSettings);
	else if (Id == HOT_ACC)
		Toggle(ChkAcc);
	else if (Id == HOT_DESC)
		Toggle(ChkDesc);
	else if ((Id >= HOT_PREV) && (Id < HOT_PREV + 25))
		Press(RowPrev[Id - HOT_PREV]);
	else if ((Id >= HOT_NEXT) && (Id < HOT_NEXT + 25))
		Press(RowNext[Id - HOT_NEXT]);
}

function bool PageKey(EInputKey key, bool bRepeat)
{
	if (key == IK_MouseWheelUp)
	{
		ListScrollTarget -= 90 * S;
		return True;
	}
	if (key == IK_MouseWheelDown)
	{
		ListScrollTarget += 90 * S;
		return True;
	}
	if ((key == IK_Up) && (OutList != None))
	{
		SelectIndex(Max(0, SelIndex() - 1));
		return True;
	}
	if ((key == IK_Down) && (OutList != None))
	{
		SelectIndex(Min(OutList.GetNumRows() - 1, SelIndex() + 1));
		return True;
	}
	if ((key == IK_Enter) && !bRepeat)
	{
		Press(BtnEquip);
		return True;
	}
	return False;
}

// ----------------------------------------------------------------------
// Drawing
// ----------------------------------------------------------------------

// The preview hole is known before the board is drawn, so the first frame
// doesn't paint over the 3D view
function DrawFrame(GC gc, float a)
{
	if (VPlus())
	{
		S = height / 1080.0;
		OX = FMax(0, (width - 1920 * S) * 0.5);
		HoleX = OX + 397 * S;
		HoleY = 176 * S;
		HoleW = 583 * S;
		HoleH = 638 * S;
	}
	else
		HoleW = 0;
	Super.DrawFrame(gc, a);
}

// Vanilla+: Outfit sits on the Inventory board with Items, Ammo and Keys
function int VPBoard()
{
	return 1;
}

function DrawPage(GC gc, float a)
{
	PVX = OX + 650 * S;
	PVY = 236 * S;
	PVW = 540 * S;
	PVH = 704 * S;
	if (VPlus())
	{
		// the 3D preview fills the left frame
		PVX = OX + 397 * S;
		PVY = 176 * S;
		PVW = 583 * S;
		PVH = 638 * S;
		HoleX = PVX;
		HoleY = PVY;
		HoleW = PVW;
		HoleH = PVH;
	}
	else
		HoleW = 0;
	if (!bFound)
	{
		Heading(gc, OX + 140 * S, 170 * S, 1000 * S, OutfitsTitle, a);
		Class'RIText'.static.Draw(gc, Class'RIFontBody', OX + 140 * S, 240 * S, NoAugmentiqueLabel, ALbl(a), 0.8);
		return;
	}
	DrawList(gc, a);
	DrawPreviewFrame(gc, a);
	if (VPlus())
		DrawVPBeltItems(gc, a);
	DrawDetail(gc, a);
	if (!VPlus())
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', OX + 140 * S, FY + FH + 22 * S, HintText, ALbl(a * 0.8), 0.7);
}

function DrawList(GC gc, float a)
{
	local float x, y, w, rh, sh, kh;
	local int i, st, rowId, n;
	local bool bSel, bHot, bOn;
	local string T;

	x = OX + 140 * S;
	w = 470 * S;
	ListTop = 236 * S;
	ListBottom = 940 * S;
	rh = 60 * S;
	if (VPlus())
	{
		// top of the right frame's body
		x = OX + 1068 * S;
		w = 456 * S;
		ListTop = 220 * S;
		ListBottom = 420 * S;
		rh = 40 * S;
	}
	else
		Heading(gc, x, 170 * S, w, OutfitsTitle, a);
	ListRight = x + w + 20 * S;
	n = OutList.GetNumRows();
	st = gc.PushGC();
	gc.Intersect(x - 4 * S, ListTop, w + 8 * S, ListBottom - ListTop);
	y = ListTop - ListScroll;
	for (i = 0; i < n; i++)
	{
		rowId = OutList.IndexToRowId(i);
		bSel = OutList.IsRowSelected(rowId);
		bHot = (HoverId == HOT_ROW + i);
		bOn = (OutList.GetField(rowId, 1) != "");
		T = OutList.GetField(rowId, 0);
		if (VPlus())
		{
			// one line, like the Skills list: name, and the worn tag on the right
			if (bSel)
				SelRow(gc, x, y, w, rh, a);
			else
			{
				if (bHot)
					Glow(gc, x, y, w, rh, C3(36, 30, 12, a));
				Class'RIText'.static.HLine(gc, x + 8 * S, y + rh, w - 16 * S, C3(60, 50, 24, a));
			}
			if (bOn)
				Fill(gc, x + 2 * S, y + 8 * S, 3 * S, rh - 16 * S, AHi(a));
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x + 14 * S, y, w - 140 * S, rh,
				Caps(Class'RIText'.static.Fit(Class'RIFontHead', T, w - 140 * S, 0.46)),
				Class'RIUtil'.static.Mix(C3(236, 214, 160, a), C3(255, 255, 255, a), int(bSel)), 0, 0.46);
			if (bOn)
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x + w - 130 * S, y, 118 * S, rh, Caps(WearingLabel), AGood(a), 2, 0.54);
		}
		else
		{
		if (bSel)
			SelRow(gc, x, y, w, rh, a);
		else if (bHot)
			Class'RIText'.static.Box(gc, x, y, w, rh, AEdge(a));
		else
			Class'RIText'.static.HLine(gc, x + 8 * S, y + rh, w - 16 * S, C3(60, 50, 24, a));
		// Worn marker
		if (bOn)
		{
			CGlow(gc, x + 6 * S, y + rh * 0.5 - 14 * S, 28 * S, 28 * S, C3(60, 50, 22, a));
			Fill(gc, x + 14 * S, y + rh * 0.5 - 6 * S, 12 * S, 12 * S, AHi(a));
		}
		else
			Class'RIText'.static.Box(gc, x + 14 * S, y + rh * 0.5 - 6 * S, 12 * S, 12 * S, C3(110, 92, 44, a));
		Class'RIText'.static.DrawIn(gc, Class'RIFontBody', x + 42 * S, y + 6 * S, w - 60 * S, 28 * S,
			Class'RIText'.static.Fit(Class'RIFontBody', T, w - 60 * S, 0.8),
			Class'RIUtil'.static.Mix(ATxt(a), C3(255, 255, 255, a), int(bSel)), 0, 0.8);
		if (bOn)
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x + 42 * S, y + 34 * S, w - 60 * S, 20 * S, Caps(WearingLabel), AAcc(a), 0, 0.56);
		}
		if ((y + rh > ListTop) && (y < ListBottom))
			AddHot(HOT_ROW + i, x, FMax(y, ListTop), w, FMin(y + rh, ListBottom) - FMax(y, ListTop));
		if (VPlus())
			y += rh + 2 * S;
		else
			y += rh + 6 * S;
	}
	gc.PopGC(st);
	ListMax = FMax(0, (y + ListScroll - ListTop) - (ListBottom - ListTop));
	if (ListMax > 1)
	{
		sh = ListBottom - ListTop;
		kh = FMax(30 * S, sh * sh / (sh + ListMax));
		Fill(gc, x + w + 8 * S, ListTop, 2 * S, sh, C3(50, 42, 20, a));
		Fill(gc, x + w + 8 * S, ListTop + (sh - kh) * (ListScroll / ListMax), 2 * S, kh, AAcc(a));
	}
	if (n == 0)
		Class'RIText'.static.Draw(gc, Class'RIFontBody', x, ListTop, NoneLabel, ALbl(a), 0.8);
}

// The live preview is Augmentique's viewport, placed in this rectangle
function DrawPreviewFrame(GC gc, float a)
{
	if (VPlus())
		return;     // the board's inset frames it; nothing may tint the preview
	Class'RISkin'.static.Box2(gc, PVX - 2 * S, PVY - 2 * S, PVW + 4 * S, PVH + 4 * S, AEdge(a));
}

function DrawDetail(GC gc, float a)
{
	local float x, y, w, bw, th, by;
	local int i, sel, st;
	local string T;
	local bool bEdit;

	x = OX + 1220 * S;
	w = 560 * S;
	y = 170 * S;
	if (VPlus())
	{
		x = OX + 1072 * S;
		w = 446 * S;
	}

	// Name: the selected row's
	sel = SelIndex();
	if (sel >= 0)
		T = OutList.GetField(OutList.IndexToRowId(sel), 0);
	else if (TxtName != None)
		T = TxtName.GetText();
	if (VPlus())
	{
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 177 * S, w, 28 * S, Caps(Class'RIText'.static.Fit(Class'RIFontHead', T, w, 0.5)), ATxt(a), 0, 0.5);
		y = 432 * S;
		Class'RIText'.static.HLine(gc, x, 426 * S, w, ADim(a));
		st = gc.PushGC();
		gc.Intersect(x - 2 * S, 430 * S, w + 4 * S, 224 * S);
	}
	else
	{
		Class'RIText'.static.Draw(gc, Class'RIFontTitle', x, y, Caps(Class'RIText'.static.Fit(Class'RIFontTitle', T, w, 0.42)), ATxt(a), 0.42);
		y += 60 * S;
	}

	// Description (Augmentique's, when its setting shows them)
	if ((TxtDesc != None) && (TxtDesc.GetText() != ""))
	{
		th = Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x, y, w, TxtDesc.GetText(), C3(230, 210, 165, a), 0.76, 1.4);
		y += th + 18 * S;
	}

	// Parts (customise mode): model variant first, then each body slot
	NumRows = 0;
	if ((TxtVariant != None) && TxtVariant.IsVisible(False))
		AddPartRow(VarPrev, VarNext);
	for (i = 0; i < NumSlots; i++)
		if ((SlotTxt[i] != None) && SlotTxt[i].IsVisible(False))
			AddPartRow(SlotPrev[i], SlotNext[i]);
	bEdit = NumRows > 0;
	if (bEdit)
	{
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, Caps(PartsTitle), AAcc(a), 0.7);
		y += 30 * S;
		i = 0;
		if ((TxtVariant != None) && TxtVariant.IsVisible(False))
		{
			DrawPartRow(gc, x, y, w, i, TxtVariant.GetText(), a);
			y += 46 * S;
			i++;
		}
		for (sel = 0; sel < NumSlots; sel++)
			if ((SlotTxt[sel] != None) && SlotTxt[sel].IsVisible(False) && (i < NumRows))
			{
				DrawPartRow(gc, x, y, w, i, SlotTxt[sel].GetText(), a);
				y += 46 * S;
				i++;
			}
	}

	if (VPlus())
	{
		gc.PopGC(st);
		DrawVPOutfitActions(gc, x, w, a);
		return;
	}

	// Checkboxes
	by = 940 * S - 50 * S * 2 - 12 * S;
	if ((ChkAcc != None) && ChkAcc.IsVisible(False))
	{
		DrawCheck(gc, x, by - 44 * S, AccLabel, ChkAcc.GetToggle(), HOT_ACC, a);
	}
	if ((ChkDesc != None) && ChkDesc.IsVisible(False))
		DrawCheck(gc, x + w * 0.5, by - 44 * S, DescLabel, ChkDesc.GetToggle(), HOT_DESC, a);

	// Buttons: Equip / Customize, Change View / Settings
	bw = (w - 12 * S) / 2;
	DrawBtn(gc, x, by, bw, 50 * S, BtnLabel(BtnEquip, "Equip"), Live(BtnEquip), HoverId == HOT_EQUIP, Live(BtnEquip), a);
	AddHot(HOT_EQUIP, x, by, bw, 50 * S);
	DrawBtn(gc, x + bw + 12 * S, by, bw, 50 * S, BtnLabel(BtnEdit, "Customize"), Live(BtnEdit), HoverId == HOT_EDIT, False, a);
	AddHot(HOT_EDIT, x + bw + 12 * S, by, bw, 50 * S);
	by += 62 * S;
	DrawBtn(gc, x, by, bw, 50 * S, BtnLabel(BtnCamera, "Change view"), Live(BtnCamera), HoverId == HOT_CAMERA, False, a);
	AddHot(HOT_CAMERA, x, by, bw, 50 * S);
	if ((BtnSettings != None) && BtnSettings.IsVisible(False))
	{
		DrawBtn(gc, x + bw + 12 * S, by, bw, 50 * S, BtnLabel(BtnSettings, "Settings"), Live(BtnSettings), HoverId == HOT_SETTINGS, False, a);
		AddHot(HOT_SETTINGS, x + bw + 12 * S, by, bw, 50 * S);
	}
}

// Vanilla+: checkboxes in the footer bar, the four buttons in the lower box
function DrawVPOutfitActions(GC gc, float x, float w, float a)
{
	local float bw;

	if ((ChkAcc != None) && ChkAcc.IsVisible(False))
		DrawCheck(gc, x, 670 * S, AccLabel, ChkAcc.GetToggle(), HOT_ACC, a);
	if ((ChkDesc != None) && ChkDesc.IsVisible(False))
		DrawCheck(gc, x + w * 0.5, 670 * S, DescLabel, ChkDesc.GetToggle(), HOT_DESC, a);
	bw = 170 * S;
	DrawBtn(gc, OX + 1180 * S, 758 * S, bw, 38 * S, BtnLabel(BtnEquip, "Equip"), Live(BtnEquip), HoverId == HOT_EQUIP, Live(BtnEquip), a);
	AddHot(HOT_EQUIP, OX + 1180 * S, 758 * S, bw, 38 * S);
	DrawBtn(gc, OX + 1358 * S, 758 * S, bw, 38 * S, BtnLabel(BtnEdit, "Customize"), Live(BtnEdit), HoverId == HOT_EDIT, False, a);
	AddHot(HOT_EDIT, OX + 1358 * S, 758 * S, bw, 38 * S);
	DrawBtn(gc, OX + 1180 * S, 806 * S, bw, 38 * S, BtnLabel(BtnCamera, "Change view"), Live(BtnCamera), HoverId == HOT_CAMERA, False, a);
	AddHot(HOT_CAMERA, OX + 1180 * S, 806 * S, bw, 38 * S);
	if ((BtnSettings != None) && BtnSettings.IsVisible(False))
	{
		DrawBtn(gc, OX + 1358 * S, 806 * S, bw, 38 * S, BtnLabel(BtnSettings, "Settings"), Live(BtnSettings), HoverId == HOT_SETTINGS, False, a);
		AddHot(HOT_SETTINGS, OX + 1358 * S, 806 * S, bw, 38 * S);
	}
}

function AddPartRow(Window P, Window N)
{
	if (NumRows >= 25)
		return;
	RowPrev[NumRows] = P;
	RowNext[NumRows] = N;
	NumRows++;
}

function DrawPartRow(GC gc, float X, float Y, float W, int i, string T, float a)
{
	local float bs;

	bs = 38 * S;
	Fill(gc, X, Y, W, 40 * S, C3(30, 25, 11, 0.5 * a));
	Class'RIText'.static.Box(gc, X, Y, W, 40 * S, C3(74, 62, 28, a));
	DrawBtn(gc, X + 2 * S, Y + 1 * S, bs, bs, "<", Live(RowPrev[i]), HoverId == HOT_PREV + i, False, a);
	AddHot(HOT_PREV + i, X + 2 * S, Y + 1 * S, bs, bs);
	DrawBtn(gc, X + W - bs - 2 * S, Y + 1 * S, bs, bs, ">", Live(RowNext[i]), HoverId == HOT_NEXT + i, False, a);
	AddHot(HOT_NEXT + i, X + W - bs - 2 * S, Y + 1 * S, bs, bs);
	Class'RIText'.static.DrawIn(gc, Class'RIFontBody', X + bs + 12 * S, Y, W - 2 * bs - 24 * S, 40 * S,
		Class'RIText'.static.Fit(Class'RIFontBody', T, W - 2 * bs - 24 * S, 0.74), ATxt(a), 1, 0.74);
}

function DrawCheck(GC gc, float X, float Y, string L, bool bOn, int Id, float a)
{
	local float tw;

	Class'RISkin'.static.Box2(gc, X, Y + 6 * S, 18 * S, 18 * S, AEdge(a));
	if (bOn)
		Fill(gc, X + 4 * S, Y + 10 * S, 10 * S, 10 * S, AAcc(a));
	tw = Class'RIText'.static.Width(Class'RIFontBody', L, 0.72);
	Class'RIText'.static.DrawIn(gc, Class'RIFontBody', X + 28 * S, Y, tw, 30 * S, L,
		Class'RIUtil'.static.Mix(C3(220, 200, 155, a), C3(255, 255, 255, a), int(HoverId == Id)), 0, 0.72);
	AddHot(Id, X, Y, tw + 30 * S, 30 * S);
}

defaultproperties
{
     OutfitsTitle="Outfits"
     PartsTitle="Parts"
     AccLabel="Show accessories"
     DescLabel="Show descriptions"
     NoneLabel="No outfits yet."
     WearingLabel="Wearing"
     NoAugmentiqueLabel="The outfit screen didn't load as expected. Use Classic view."
     HintText="CLICK select     DOUBLE-CLICK or ENTER wear     UP / DOWN move     WHEEL scroll     ESC close"
}
