//=============================================================================
// RISaveView
// Full-screen Load Game / Save Game, drawn natively over AE's screens.
// AE's MenuScreenLoadGame / MenuScreenSaveGame stay in charge of everything
// that matters: the save list (still their hidden list window), snapshots,
// the save name editor, overwrite / delete / low-space prompts, loading and
// the save sequence itself. This view only reads their state, draws it and
// turns input into the same calls AE's buttons make.
//=============================================================================
class RISaveView extends Window;

const MAXROWS = 512;

// Hot-region ids
const HOT_ROW     = 1000;   // + row index
const HOT_BTN     = 10;     // + button
const HOT_CONFIRM = 20;

const BTN_BACK   = 0;
const BTN_DELETE = 1;
const BTN_GO     = 2;       // Load / Save

var MenuScreenLoadGame Screen;
var MenuScreenSaveGame SaveScreen;   // None on the load screen
var bool  bSave;
var bool  bReady;
var float Age, DescAge;
var float S;

// Rows (rebuilt every tick from AE's list, in its order)
var int    NumRows;
var int    RowId[512];
var string RowName[512];
var string RowDate[512];
var int    RowDir[512];     // save directory index: -1 quick save, -2 new / missing
var int    Sel;
var int    ShownRow;        // AE row id the details below belong to
var float  ScrollY, ScrollTarget, HiY;
var bool   bHiPlaced;
var bool   bLoadPending;    // Enter pressed: load once it is released

// Details of the selected save (copied, so nothing native is kept)
var string InfoLocation, InfoPlayTime, InfoCount, InfoId;
var bool   bInfoCheats, bInfoValid;

// Layout
var float FrameX, FrameY, FrameW, FrameH;
var float CX, CW, TopY, ListX, ListY, ListW, ListH, RowH;
var float PX, PW;
var float BtnY, BtnH;
var float BX[3], BW[3];

// Hit regions from the last frame
var float HotX[64], HotY[64], HotW[64], HotH[64];
var int   HotId[64];
var int   NumHot;
var int   HoverId;

var localized string LoadTitle, SaveTitle;
var localized string LoadSub, SaveSub;
var localized string CountLabel;
var localized string NewSaveTag, QuickSaveTag;
var localized string LocationLabel, PlayTimeLabel, SaveCountLabel, SaveIdLabel, DateLabel;
var localized string CheatsLabel, NoPreviewLabel, EmptyLabel;
var localized string FreeSpaceLabel, LowSpaceLabel;
var localized string ConfirmLabel;
var localized string BackLabel, DeleteLabel, LoadLabel, SaveLabel, OverwriteLabel;
var localized string LoadHint, SaveHint;

// ----------------------------------------------------------------------
// Setup
// ----------------------------------------------------------------------

event InitWindow()
{
	Super.InitWindow();
	SetSelectability(True);
	bTickEnabled = True;
	HoverId = -1;
	ShownRow = -99;
}

function AttachTo(MenuScreenLoadGame NewScreen)
{
	Screen = NewScreen;
	SaveScreen = MenuScreenSaveGame(NewScreen);
	bSave = (SaveScreen != None);
	SetConfiguration(0, 0, Screen.width, Screen.height);
	HideScreenParts();
	RebuildRows();
	Sel = FindSelected();
}

event WindowReady()
{
	Super.WindowReady();
	bReady = True;      // only flag here: see RIPanel.WindowReady
}

function HideScreenParts()
{
	local Window C;

	for (C = Screen.GetTopChild(); C != None; C = C.GetLowerSibling())
		if ((C != Self) && C.IsVisible(False))
			C.Hide();
}

// ----------------------------------------------------------------------
// Reading AE's state
// ----------------------------------------------------------------------

function MenuUIListWindow List()
{
	return Screen.lstGames;
}

function int EditRow()
{
	if (bSave)
		return SaveScreen.editRowId;
	return -1;
}

function RebuildRows()
{
	local int i, n, r;
	local MenuUIListWindow L;

	L = List();
	NumRows = 0;
	if (L == None)
		return;
	n = Min(L.GetNumRows(), MAXROWS);
	for (i = 0; i < n; i++)
	{
		r = L.IndexToRowId(i);
		RowId[i] = r;
		RowDir[i] = int(L.GetField(r, 4));
		RowDate[i] = L.GetField(r, 1);
		// On the save screen AE blanks the edited row's name and keeps it in its editor
		if (bSave && (r == EditRow()) && (SaveScreen.editName != None))
			RowName[i] = SaveScreen.editName.GetText();
		else
			RowName[i] = L.GetField(r, 0);
	}
	NumRows = n;
}

// Index of the row AE considers current
function int FindSelected()
{
	local int i, r;

	if (bSave)
		r = EditRow();
	else
		r = List().GetSelectedRow();
	for (i = 0; i < NumRows; i++)
		if (RowId[i] == r)
			return i;
	return 0;
}

function bool IsNewSaveRow(int i)
{
	return bSave && (RowId[i] == SaveScreen.newSaveRowId);
}

// Make row i current, the way clicking it in AE's list would
function SelectIndex(int i)
{
	local int r;

	if (NumRows == 0)
		return;
	i = Clamp(i, 0, NumRows - 1);
	if (i != Sel)
		PlaySound(Sound'Menu_Focus', 0.2);
	Sel = i;
	r = RowId[i];
	List().SetRow(r);
	// The list is hidden: deliver the change AE listens for ourselves (AE ignores repeats)
	Screen.ListSelectionChanged(List(), 1, r);
	EnsureVisible();
}

function UpdateInfo()
{
	local int r, dirIdx;
	local GameDirectory SDir;
	local DeusExSaveInfo Info;

	if ((Sel < 0) || (Sel >= NumRows))
	{
		bInfoValid = False;
		return;
	}
	r = RowId[Sel];
	if (r == ShownRow)
		return;
	ShownRow = r;
	DescAge = 0;
	bInfoValid = False;

	if (IsNewSaveRow(Sel))
	{
		InfoLocation = SaveScreen.missionLocation;
		InfoCount    = string(Screen.player.saveCount);
		InfoPlayTime = Screen.BuildElapsedTimeString(int(Screen.player.saveTime));
		InfoId       = "";
		bInfoCheats  = Screen.player.bCheatsEnabled;
		bInfoValid   = True;
		return;
	}

	dirIdx = RowDir[Sel];
	if (dirIdx == -2)
		return;
	SDir = Screen.GetSaveGameDirectory();
	if (SDir == None)
		return;
	Info = SDir.GetSaveInfo(dirIdx);
	if (Info != None)
	{
		InfoLocation = Info.MissionLocation;
		InfoCount    = string(Info.saveCount);
		InfoPlayTime = Screen.BuildElapsedTimeString(Info.saveTime);
		if (Info.directoryIndex != -1)
			InfoId = string(Info.directoryIndex);
		else
			InfoId = "";
		bInfoCheats = Info.bCheatsEnabled;
		bInfoValid  = True;
	}
	CriticalDelete(SDir);
}

function bool CanDelete()
{
	return (Sel >= 0) && (Sel < NumRows) && (RowDir[Sel] >= 0);
}

function bool CanGo()
{
	if ((Sel < 0) || (Sel >= NumRows))
		return False;
	if (bSave)
		return (SaveScreen.editName != None) && (Screen.TrimSpaces(SaveScreen.editName.GetText()) != "");
	return RowDir[Sel] != -2;
}

function bool CanEditName()
{
	return bSave && (SaveScreen.editName != None) && SaveScreen.editName.IsEditingEnabled();
}

function bool LowSpace()
{
	return (Screen.freeDiskSpace / 1024) < Screen.minFreeDiskSpace;
}

// ----------------------------------------------------------------------
// Actions (the same calls AE's buttons make)
// ----------------------------------------------------------------------

function DoGo()
{
	if (!CanGo())
		return;
	PlaySound(Sound'Menu_Press', 0.25);
	if (bSave)
		SaveScreen.ConfirmSaveGame();
	else
		Screen.LoadGame(RowId[Sel]);
}

function DoDelete()
{
	if (!CanDelete())
		return;
	PlaySound(Sound'Menu_Press', 0.25);
	if ((Screen.chkConfirmDelete == None) || Screen.chkConfirmDelete.GetToggle())
		Screen.ConfirmDeleteGame(RowId[Sel]);
	else
		Screen.DeleteGame(RowId[Sel]);
	ShownRow = -99;
}

function DoBack()
{
	PlaySound(Sound'Menu_Press', 0.25);
	Screen.CancelScreen();
}

function ToggleConfirm()
{
	local bool b;

	if (Screen.chkConfirmDelete == None)
		return;
	b = !Screen.chkConfirmDelete.GetToggle();
	Screen.chkConfirmDelete.SetToggle(b);
	Screen.player.bConfirmSaveDeletes = b;
	PlaySound(Sound'Menu_Press', 0.25);
}

function TypeChar(string C)
{
	local string T;

	if (!CanEditName() || (C == ";") || (Asc(C) < 32))
		return;
	T = SaveScreen.editName.GetText();
	if (Len(T) >= 60)
		return;
	SaveScreen.editName.SetText(T $ C);
}

function Backspace(bool bWord)
{
	local string T;

	if (!CanEditName())
		return;
	T = SaveScreen.editName.GetText();
	if (bWord)
	{
		while ((T != "") && (Right(T, 1) == " "))
			T = Left(T, Len(T) - 1);
		while ((T != "") && (Right(T, 1) != " "))
			T = Left(T, Len(T) - 1);
	}
	else if (T != "")
		T = Left(T, Len(T) - 1);
	SaveScreen.editName.SetText(T);
}

// ----------------------------------------------------------------------
// Input
// ----------------------------------------------------------------------

event bool VirtualKeyPressed(EInputKey key, bool bRepeat)
{
	if (IsKeyDown(IK_Alt))
		return False;

	if (key == IK_Escape)
	{
		DoBack();
		return True;
	}
	if (key == IK_Enter)
	{
		if (!bRepeat)
		{
			// Like AE: load on release, so the key doesn't carry into the game
			if (bSave)
				DoGo();
			else if (CanGo())
				bLoadPending = True;
		}
		return True;
	}
	if (key == IK_Delete)
	{
		DoDelete();
		return True;
	}
	if (key == IK_Backspace)
	{
		Backspace(IsKeyDown(IK_Ctrl));
		return True;
	}
	if (IsKeyDown(IK_Ctrl))
		return False;

	if ((key == IK_Up) || (key == IK_MouseWheelUp))
	{
		if (key == IK_MouseWheelUp)
			ScrollTarget -= RowH * 3;
		else
			SelectIndex(Sel - 1);
		return True;
	}
	if ((key == IK_Down) || (key == IK_MouseWheelDown))
	{
		if (key == IK_MouseWheelDown)
			ScrollTarget += RowH * 3;
		else
			SelectIndex(Sel + 1);
		return True;
	}
	if (key == IK_PageUp)
	{
		SelectIndex(Sel - PageRows());
		return True;
	}
	if (key == IK_PageDown)
	{
		SelectIndex(Sel + PageRows());
		return True;
	}
	if ((key == IK_Home) && !bSave)
	{
		SelectIndex(0);
		return True;
	}
	if ((key == IK_End) && !bSave)
	{
		SelectIndex(NumRows - 1);
		return True;
	}
	// Everything else is text for the save name (or ignored)
	return bSave;
}

event bool KeyPressed(string key)
{
	if (IsKeyDown(IK_Ctrl) || IsKeyDown(IK_Alt))
		return False;
	if (bSave)
		TypeChar(key);
	return True;
}

function int HotAt(float X, float Y)
{
	local int i;

	for (i = NumHot - 1; i >= 0; i--)
		if ((X >= HotX[i]) && (X < HotX[i] + HotW[i]) && (Y >= HotY[i]) && (Y < HotY[i] + HotH[i]))
			return HotId[i];
	return -1;
}

event MouseMoved(float newX, float newY)
{
	local int Id;

	Id = HotAt(newX, newY);
	if ((Id != HoverId) && (Id != -1) && (Id < HOT_ROW))
		PlaySound(Sound'Menu_Focus', 0.15);
	HoverId = Id;
}

event bool MouseButtonPressed(float pointX, float pointY, EInputKey button, int numClicks)
{
	local int Id;

	if (button != IK_LeftMouse)
		return True;
	Id = HotAt(pointX, pointY);
	if (Id >= HOT_ROW)
	{
		if ((numClicks >= 2) && (Id - HOT_ROW == Sel))
			DoGo();
		else
			SelectIndex(Id - HOT_ROW);
	}
	else if (Id == HOT_BTN + BTN_BACK)
		DoBack();
	else if (Id == HOT_BTN + BTN_DELETE)
		DoDelete();
	else if (Id == HOT_BTN + BTN_GO)
		DoGo();
	else if (Id == HOT_CONFIRM)
		ToggleConfirm();
	return True;
}

event bool MouseButtonReleased(float pointX, float pointY, EInputKey button, int numClicks)
{
	return True;
}

function KeepFocus()
{
	local DeusExRootWindow R;

	if (!bReady)
		return;
	R = DeusExRootWindow(GetRootWindow());
	if ((R == None) || (R.GetTopWindow() != Screen))
		return;
	if (R.GetFocusWindow() != Self)
		SetFocusWindow(Self);
}

function int PageRows()
{
	return Max(1, int(ListH / FMax(1, RowH)) - 1);
}

function EnsureVisible()
{
	local float top;

	top = Sel * RowH;
	if (top < ScrollTarget)
		ScrollTarget = top;
	else if (top + RowH > ScrollTarget + ListH)
		ScrollTarget = top + RowH - ListH;
}

// ----------------------------------------------------------------------
// Tick / layout
// ----------------------------------------------------------------------

function Layout()
{
	S = height / 1080.0;

	FrameX = 30 * S;
	FrameY = 30 * S;
	FrameW = width - 60 * S;
	FrameH = height - 60 * S;

	CW = FMin(width - 140 * S, 1780 * S);
	CX = (width - CW) * 0.5;
	TopY = 166 * S;

	BtnH = 52 * S;
	BtnY = FrameY + FrameH - 40 * S - BtnH;

	ListX = CX;
	ListW = CW * 0.54;
	ListY = TopY + 40 * S;
	RowH  = 66 * S;
	ListH = BtnY - 40 * S - ListY;
	ListH = FMax(RowH, float(int(ListH / RowH)) * RowH);

	PX = ListX + ListW + 60 * S;
	PW = CX + CW - PX;
}

event Tick(float deltaSeconds)
{
	local float k, target, maxScroll;
	local int Cur;

	Age += deltaSeconds;
	DescAge += deltaSeconds;
	if (Screen == None)
		return;

	if ((width != Screen.width) || (height != Screen.height))
		SetConfiguration(0, 0, Screen.width, Screen.height);
	Layout();
	HideScreenParts();
	if (RIRootWindow(GetRootWindow()) != None)
		RIRootWindow(GetRootWindow()).GuardInitCount("SaveView");
	KeepFocus();

	RebuildRows();
	// Follow AE when it moves the selection itself (after a delete, a new save row)
	Cur = FindSelected();
	if ((Cur != Sel) && (Cur >= 0) && (Cur < NumRows))
	{
		Sel = Cur;
		EnsureVisible();
	}
	Sel = Clamp(Sel, 0, Max(0, NumRows - 1));
	UpdateInfo();

	if (bLoadPending && !IsKeyDown(IK_Enter))
	{
		bLoadPending = False;
		DoGo();
	}

	maxScroll = FMax(0, NumRows * RowH - ListH);
	ScrollTarget = FClamp(ScrollTarget, 0, maxScroll);
	k = FMin(1.0, deltaSeconds * 14.0);
	ScrollY += (ScrollTarget - ScrollY) * k;
	if (Abs(ScrollTarget - ScrollY) < 0.25)
		ScrollY = ScrollTarget;

	target = Sel * RowH;
	if (!bHiPlaced)
	{
		HiY = target;
		bHiPlaced = True;
	}
	HiY += (target - HiY) * FMin(1.0, deltaSeconds * 18.0);
}

// ----------------------------------------------------------------------
// Drawing helpers
// ----------------------------------------------------------------------

function AddHot(int Id, float X, float Y, float W, float H)
{
	if (NumHot >= 64)
		return;
	HotId[NumHot] = Id;
	HotX[NumHot] = X;
	HotY[NumHot] = Y;
	HotW[NumHot] = W;
	HotH[NumHot] = H;
	NumHot++;
}

function Color C3(float R, float G, float B, float a)
{
	return Class'RIUtil'.static.Col(R * a, G * a, B * a);
}

function Fill(GC gc, float X, float Y, float W, float H, Color C)
{
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C);
	Class'RIText'.static.Fill(gc, X, Y, W, H);
}

function Glow(GC gc, float X, float Y, float W, float H, Color C)
{
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C);
	Class'RIText'.static.Tex(gc, X, Y, W, H, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');
}

function float Pill(GC gc, float X, float Y, string L, Color C)
{
	local float w;

	w = Class'RIText'.static.Width(Class'RIFontSmall', L, 0.8) + 16 * S;
	Class'RIText'.static.Box(gc, X, Y, w, 20 * S, C);
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, Y, w, 20 * S, L, C, 1, 0.8);
	return w;
}

// ----------------------------------------------------------------------
// Drawing
// ----------------------------------------------------------------------

event DrawWindow(GC gc)
{
	local float a, pulse;

	if (Screen == None)
		return;
	NumHot = 0;
	a = Class'RIUtil'.static.Phase(Age, 0.0, 0.3);
	pulse = 0.85 + 0.15 * Sin(Age * 2.0);
	gc.EnableSmoothing(True);

	Class'RISkin'.static.DrawDim(gc, 0, 0, width, height, 0.55 * a);
	Class'RISkin'.static.DrawDim(gc, FrameX, FrameY, FrameW, FrameH, 0.85 * a);
	Fill(gc, FrameX, FrameY, FrameW, FrameH, C3(4, 5, 22, a));
	Class'RIText'.static.Box(gc, FrameX, FrameY, FrameW, FrameH, C3(80 * pulse, 84 * pulse, 190 * pulse, a));
	Class'RIText'.static.Box(gc, FrameX - 3 * S, FrameY - 3 * S, FrameW + 6 * S, FrameH + 6 * S, C3(24, 26, 80, a));

	DrawHeader(gc, a);
	DrawList(gc, a * Class'RIUtil'.static.Phase(Age, 0.05, 0.3));
	DrawPreview(gc, a * Class'RIUtil'.static.Phase(Age, 0.10, 0.3));
	DrawFooter(gc, a * Class'RIUtil'.static.Phase(Age, 0.15, 0.3));
}

function DrawHeader(GC gc, float a)
{
	local float y, tw;
	local string T, Sub, N;

	y = 66 * S;
	if (bSave)
	{
		T = SaveTitle;
		Sub = SaveSub;
	}
	else
	{
		T = LoadTitle;
		Sub = LoadSub;
	}
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', CX, y - 22 * S, Caps(Sub), C3(95, 200, 255, a));
	Class'RIText'.static.Draw(gc, Class'RIFontTitle', CX, y + 6 * S, T, C3(236, 238, 255, a), 0.62);
	Class'RIText'.static.HLine(gc, CX, y + 62 * S, CW, C3(44, 48, 128, a));
	Class'RIText'.static.HLine(gc, CX, y + 62 * S, 48 * S, C3(170, 176, 255, a));

	N = string(NumRows - int(bSave));
	tw = Class'RIText'.static.Width(Class'RIFontTitle', N, 0.62);
	Class'RIText'.static.Draw(gc, Class'RIFontTitle', CX + CW - tw, y + 6 * S, N, C3(244, 246, 255, a), 0.62);
	tw = Class'RIText'.static.Width(Class'RIFontSmall', Caps(CountLabel));
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', CX + CW - tw, y - 22 * S, Caps(CountLabel), C3(95, 200, 255, a));
}

function DrawList(GC gc, float a)
{
	local int i, first, last, st;
	local float y, ra, tx, tw, blink, total, th, ty;
	local bool bSel, bHot, bEdit;
	local string Name;
	local Color NC;

	Class'RIText'.static.Draw(gc, Class'RIFontSmall', ListX, TopY, "SAVES", C3(95, 200, 255, a));
	Class'RIText'.static.HLine(gc, ListX, TopY + 24 * S, ListW, C3(34, 36, 96, a));

	if (NumRows == 0)
	{
		Class'RIText'.static.Draw(gc, Class'RIFontBody', ListX + 20 * S, ListY + 20 * S, EmptyLabel, C3(120, 126, 196, a));
		return;
	}

	st = gc.PushGC();
	gc.Intersect(ListX - 4 * S, ListY, ListW + 8 * S, ListH);

	// Sliding highlight
	y = ListY + HiY - ScrollY;
	Glow(gc, ListX, y, ListW, RowH, C3(34, 36, 106, a));
	Class'RIText'.static.Box(gc, ListX, y, ListW, RowH, C3(104, 108, 200, a));
	Fill(gc, ListX, y, 1.5, RowH, C3(205, 210, 255, a));

	first = Max(0, int(ScrollY / RowH));
	last  = Min(NumRows - 1, int((ScrollY + ListH) / RowH));
	for (i = first; i <= last; i++)
	{
		y = ListY + i * RowH - ScrollY;
		ra = a * Class'RIUtil'.static.Phase(Age, 0.05 + FMin(i - first, 12) * 0.022, 0.3);
		bSel = (i == Sel);
		bHot = (HoverId == HOT_ROW + i);
		bEdit = bSel && CanEditName();

		if (bHot && !bSel)
			Glow(gc, ListX, y, ListW, RowH, C3(14, 15, 44, ra));

		tx = ListX + 22 * S + (1.0 - ra) * 14 * S;

		// Tags: the new save slot, the quick save
		if (IsNewSaveRow(i))
			tx += Pill(gc, tx, y + 10 * S, Caps(NewSaveTag), C3(95, 200, 255, ra)) + 10 * S;
		else if (RowDir[i] == -1)
			tx += Pill(gc, tx, y + 10 * S, Caps(QuickSaveTag), C3(150, 156, 214, ra)) + 10 * S;

		Name = RowName[i];
		if (bSel)
			NC = C3(255, 255, 255, ra);
		else
			NC = C3(186, 190, 236, ra);
		Name = Class'RIText'.static.Fit(Class'RIFontBody', Name, ListX + ListW - 30 * S - tx);
		Class'RIText'.static.Draw(gc, Class'RIFontBody', tx, y + 8 * S, Name, NC);

		// Caret while the name is being edited
		if (bEdit)
		{
			tw = Class'RIText'.static.Width(Class'RIFontBody', Name);
			blink = 0.5 + 0.5 * Sin(Age * 6.0);
			Fill(gc, tx + tw + 2 * S, y + 10 * S, 1.5, 26 * S, C3(150 * blink, 228 * blink, 255 * blink, ra));
		}

		Class'RIText'.static.Draw(gc, Class'RIFontSmall', ListX + 22 * S + (1.0 - ra) * 14 * S, y + 40 * S, RowDate[i],
			C3(95 * (0.7 + 0.3 * int(bSel)), 200 * (0.7 + 0.3 * int(bSel)), 255 * (0.7 + 0.3 * int(bSel)), ra), 0.9);

		Class'RIText'.static.HLine(gc, ListX + 12 * S, y + RowH - 0.5, ListW - 24 * S, C3(28, 30, 80, ra));
		if ((y + RowH > ListY) && (y < ListY + ListH))
			AddHot(HOT_ROW + i, ListX, FMax(y, ListY), ListW, FMin(y + RowH, ListY + ListH) - FMax(y, ListY));
	}
	gc.PopGC(st);

	// Scrollbar
	total = NumRows * RowH;
	if (total > ListH + 1)
	{
		th = FMax(30 * S, ListH * ListH / total);
		ty = ListY + (ListH - th) * (ScrollY / (total - ListH));
		Fill(gc, ListX + ListW + 10 * S, ListY, 2 * S, ListH, C3(24, 26, 70, a));
		Fill(gc, ListX + ListW + 10 * S, ty, 2 * S, th, C3(120, 126, 220, a));
	}
}

function DrawPreview(GC gc, float a)
{
	local float da, x, y, w, ih, iw, sw, sh, lx, vx;
	local Texture T;
	local string Loc;

	x = PX;
	y = TopY;
	w = PW;
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, "PREVIEW", C3(95, 200, 255, a));
	Class'RIText'.static.HLine(gc, x, y + 24 * S, w, C3(34, 36, 96, a));
	y = ListY;

	da = a * Class'RIUtil'.static.Phase(DescAge, 0.0, 0.22);

	// Snapshot: whatever AE is showing (it loads it and owns it), 4:3
	iw = w;
	ih = iw * 0.75;
	if (ih > ListH * 0.58)
	{
		ih = ListH * 0.58;
		iw = ih / 0.75;
	}
	Fill(gc, x, y, iw, ih, C3(10, 11, 34, a));
	T = None;
	if (Screen.winSnapshot != None)
		T = Screen.winSnapshot.background;
	if ((T != None) && (T != Texture'Extension.Solid') && (T.USize > 8))
	{
		sw = FMin(T.USize, 160);
		sh = FMin(T.VSize, 120);
		gc.SetStyle(DSTY_Normal);
		gc.SetTileColor(Class'RIUtil'.static.Col(255, 255, 255));
		Class'RIText'.static.Tex(gc, x, y, iw, ih, 0, 0, sw, sh, T);
		if (da < 0.99)
			Class'RISkin'.static.DrawDim(gc, x, y, iw, ih, 1.0 - da);
	}
	else
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, y, iw, ih, NoPreviewLabel, C3(70, 74, 130, a), 1);
	Class'RIText'.static.Box(gc, x, y, iw, ih, C3(44, 48, 128, a));
	if (bInfoValid && bInfoCheats)
		Pill(gc, x + 12 * S, y + 12 * S, Caps(CheatsLabel), C3(255, 120, 96, da));
	y += ih + 26 * S;

	if (!bInfoValid)
		return;

	// Location as the heading, then a small grid of details
	Loc = InfoLocation;
	if (Loc == "")
		Loc = RowName[Sel];
	Class'RIText'.static.Draw(gc, Class'RIFontTitle', x + (1.0 - da) * 10 * S, y,
		Caps(Class'RIText'.static.Fit(Class'RIFontTitle', Loc, w, 0.46)), C3(244, 246, 255, da), 0.46);
	y += Class'RIText'.static.LineHeight(Class'RIFontTitle', 0.46) + 18 * S;

	lx = x;
	vx = x + 200 * S;
	DetailRow(gc, lx, vx, y, w, DateLabel, RowDate[Sel], da);
	y += 34 * S;
	DetailRow(gc, lx, vx, y, w, PlayTimeLabel, InfoPlayTime, da);
	y += 34 * S;
	DetailRow(gc, lx, vx, y, w, SaveCountLabel, InfoCount, da);
	y += 34 * S;
	if (InfoId != "")
		DetailRow(gc, lx, vx, y, w, SaveIdLabel, InfoId, da);
}

function DetailRow(GC gc, float LX, float VX, float Y, float W, string L, string V, float a)
{
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', LX, Y + 4 * S, Caps(L), C3(120, 126, 196, a));
	Class'RIText'.static.Draw(gc, Class'RIFontBody', VX, Y, Class'RIText'.static.Fit(Class'RIFontBody', V, LX + W - VX), C3(220, 224, 255, a), 0.95);
	Class'RIText'.static.HLine(gc, LX, Y + 30 * S, W, C3(24, 26, 70, a));
}

function DrawFooter(GC gc, float a)
{
	local int b;
	local float x, hot, pulse, fx, tw;
	local bool bLive, bPrimary, bOn;
	local string L, Free;
	local Color Edge, FillC, Txt, FC;

	pulse = 0.8 + 0.2 * Sin(Age * 4.0);
	Class'RIText'.static.HLine(gc, CX, BtnY - 18 * S, CW, C3(34, 36, 96, a));

	// Free space + delete confirmation, between Back and the action buttons
	Free = Sprintf(FreeSpaceLabel, Screen.freeDiskSpace / 1024);
	if (LowSpace())
	{
		Free = Free $ "   " $ LowSpaceLabel;
		FC = C3(255, 110, 96, a);
	}
	else
		FC = C3(120, 126, 196, a);
	fx = CX + 200 * S;
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', fx, BtnY, 400 * S, BtnH * 0.5, Caps(Free), FC, 0, 0.9);

	if (Screen.chkConfirmDelete != None)
	{
		bOn = Screen.chkConfirmDelete.GetToggle();
		L = Caps(ConfirmLabel);
		tw = Class'RIText'.static.Width(Class'RIFontSmall', L, 0.9);
		x = fx;
		Class'RIText'.static.Box(gc, x, BtnY + BtnH * 0.55, 32 * S, 15 * S, C3(70, 74, 170, a));
		if (bOn)
		{
			Fill(gc, x, BtnY + BtnH * 0.55, 32 * S, 15 * S, C3(44, 48, 150, a));
			Fill(gc, x + 19 * S, BtnY + BtnH * 0.55 + 3 * S, 10 * S, 9 * S, C3(150, 228, 255, a));
		}
		else
			Fill(gc, x + 3 * S, BtnY + BtnH * 0.55 + 3 * S, 10 * S, 9 * S, C3(90, 94, 150, a));
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x + 42 * S, BtnY + BtnH * 0.5, tw, BtnH * 0.5, L,
			C3(150 + 80 * int(HoverId == HOT_CONFIRM), 156 + 80 * int(HoverId == HOT_CONFIRM), 214, a), 0, 0.9);
		AddHot(HOT_CONFIRM, x, BtnY + BtnH * 0.5, tw + 46 * S, BtnH * 0.5);
	}

	// Hint line above the buttons
	if (bSave)
		L = SaveHint;
	else
		L = LoadHint;
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', ListX, BtnY - 44 * S, L, C3(70, 74, 130, a), 0.9);

	BW[BTN_BACK]   = 170 * S;
	BW[BTN_DELETE] = 170 * S;
	BW[BTN_GO]     = 250 * S;
	BX[BTN_BACK]   = CX;
	BX[BTN_GO]     = CX + CW - BW[BTN_GO];
	BX[BTN_DELETE] = BX[BTN_GO] - 14 * S - BW[BTN_DELETE];

	for (b = 0; b < 3; b++)
	{
		bPrimary = (b == BTN_GO);
		if (b == BTN_DELETE)
			bLive = CanDelete();
		else if (b == BTN_GO)
			bLive = CanGo();
		else
			bLive = True;
		hot = 0;
		if (HoverId == HOT_BTN + b)
			hot = 1;

		if (b == BTN_BACK)
			L = BackLabel;
		else if (b == BTN_DELETE)
			L = DeleteLabel;
		else if (!bSave)
			L = LoadLabel;
		else if (IsNewSaveRow(Sel))
			L = SaveLabel;
		else
			L = OverwriteLabel;

		if (bPrimary && bLive)
		{
			FillC = C3((44 + 30 * hot) * pulse, (48 + 30 * hot) * pulse, (150 + 60 * hot) * pulse, a);
			Edge  = C3(190, 196, 255, a);
			Txt   = C3(255, 255, 255, a);
		}
		else if (bLive)
		{
			FillC = C3(30 * hot, 32 * hot, 96 * hot, a);
			Edge  = C3(70 + 100 * hot, 74 + 100 * hot, 170 + 80 * hot, a);
			Txt   = C3(186 + 69 * hot, 190 + 65 * hot, 236 + 19 * hot, a);
		}
		else
		{
			FillC = C3(0, 0, 0, 0);
			Edge  = C3(40, 42, 100, a);
			Txt   = C3(80, 84, 136, a);
		}
		Glow(gc, BX[b], BtnY, BW[b], BtnH, FillC);
		Class'RIText'.static.Box(gc, BX[b], BtnY, BW[b], BtnH, Edge);
		if (bLive)
			Fill(gc, BX[b], BtnY, 1.5, BtnH, Edge);
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', BX[b], BtnY, BW[b], BtnH, Caps(L), Txt, 1, 0.56);
		AddHot(HOT_BTN + b, BX[b], BtnY, BW[b], BtnH);
	}
}

defaultproperties
{
     LoadTitle="LOAD GAME"
     SaveTitle="SAVE GAME"
     LoadSub="Resume an operation"
     SaveSub="Record your progress"
     CountLabel="Saves"
     NewSaveTag="New"
     QuickSaveTag="Quick"
     LocationLabel="Location"
     PlayTimeLabel="Play time"
     SaveCountLabel="Times saved"
     SaveIdLabel="Save ID"
     DateLabel="Saved"
     CheatsLabel="Cheats enabled"
     NoPreviewLabel="NO PREVIEW"
     EmptyLabel="No saved games yet."
     FreeSpaceLabel="Free space %dMB"
     LowSpaceLabel="Low: 100MB needed to save"
     ConfirmLabel="Confirm before deleting"
     BackLabel="Back"
     DeleteLabel="Delete"
     LoadLabel="Load Game"
     SaveLabel="Save Game"
     OverwriteLabel="Overwrite"
     LoadHint="UP / DOWN select     ENTER or double-click load     DEL delete     ESC back"
     SaveHint="Type to name the save     UP / DOWN pick a slot to overwrite     ENTER save     DEL delete     ESC back"
}
