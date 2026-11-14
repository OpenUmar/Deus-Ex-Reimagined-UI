//=============================================================================
// RIPanel
// Native, concept-style replacement for the inside of an AE settings screen.
// The AE screen stays alive underneath and keeps doing all the real work
// (reading and writing settings, GMDX side effects); its own widgets are
// hidden and this panel draws every row, value, slider, description and
// button itself with the Reimagined fonts, and handles mouse and keyboard.
//
// Three kinds of AE screen are understood:
//   CHOICES  classic option screens built from MenuUIChoice rows
//            (Game Options, Display, Sound, Controls, the GMDX hub)
//   LIST     GMDX scrolling option lists (Gameplay, Quality of Life,
//            Advanced, HDTP, tips)
//   KEYS     Keyboard / Mouse bindings (RIMenuScreenCustomizeKeys)
//
// There is no OK / Cancel: changes are kept by Apply. Leaving a screen with
// unapplied changes asks Apply / Discard / Stay (see RIMenuSettings).
//=============================================================================
class RIPanel extends Window;

const KIND_CHOICES = 1;
const KIND_LIST    = 2;
const KIND_KEYS    = 3;

const ROW_VALUE  = 0;
const ROW_SLIDER = 1;
const ROW_ACTION = 2;

const MAXROWS = 256;

var MenuUIScreenWindow Screen;
var RIMenuSettings     Shell;
var int   Kind;
var float Age;
var float UIS;              // layout scale (1.0 = 1080p screen pixels)

// Rows, re-read from the live AE screen every frame
var int          NumRows;
var string       RowLabel[256];
var string       RowValue[256];
var byte         RowType[256];
var float        RowFrac[256];
var byte         RowOn[256];      // 1 = enabled (bool arrays aren't allowed)
var MenuUIChoice RowChoice[256];
var int          RowRef[256];       // AE list row id (LIST / KEYS)

// Values when the screen opened or was last applied
var int    NumSnap;
var string SnapLabel[256];
var string SnapValue[256];
var bool   bDirty;
var bool   bReady;          // WindowReady has run (safe to hide AE's widgets)

// Selection, scrolling, highlight
var int   Sel, HoverRow, LastDescSel;
var float ScrollY, ScrollTarget;
var float HiY, HiA;
var bool  bHiPlaced;
var bool  bDragSlider;
var float ArrowLX[256], ArrowRX[256];   // where each value row's < and > are drawn
var int   DragRow;

var string DescTitle, DescText;
var float  DescAge;

// Bottom buttons
var int    NumBtn;
var string BtnLabel[8];
var string BtnKey[8];
var float  BtnX[8], BtnY[8], BtnW[8], BtnH[8];
var float  BtnHot[8];
var int    HoverBtn;
var float  AppliedFlash;
var bool   bHasValues;

// Outside the settings layout (e.g. Playthrough Modifiers) the panel frames
// itself and closes with Done / Cancel instead of Apply / Back
var bool   bStandalone;
var Window CloseBox;

// Layout (panel coordinates); OX/OY/IW/IH is the inner area
var float OX, OY, IW, IH;
var float ListX, ListY, ListW, ListH, RowH;
var float DescX, DescW, BarY, BarH;

var localized string ApplyLabel;
var localized string AppliedLabel;
var localized string BackLabel;
var localized string DefaultsLabel;
var localized string RevertLabel;
var localized string WaitingLabel;
var localized string HintValues;
var localized string HintKeys;
var localized string CurrentLabel;
var localized string OptionLabel;
var localized string UnsavedLabel;
var localized string DoneLabel;
var localized string CancelLabel;
var localized string CloseTitle;
var localized string CloseText;
var localized string ApplyChoice;
var localized string DiscardChoice;
var localized string StayChoice;

// ----------------------------------------------------------------------
// Which AE screens can be drawn natively
// ----------------------------------------------------------------------

static function bool Supports(Window W)
{
	local MenuUIScreenWindow Scr;
	local Window C;

	Scr = MenuUIScreenWindow(W);
	if (Scr == None)
		return False;

	// Screens whose point is a visual preview keep AE's layout (restyled)
	if (Scr.IsA('MenuScreenRGB') || Scr.IsA('MenuScreenThemesLoad')
		|| Scr.IsA('MenuScreenThemesSave'))
		return False;

	if (RIMenuScreenCustomizeKeys(Scr) != None)
		return True;
	if (Class'RIBase'.static.IsListScreen(Scr))
		return Class'RIBase'.static.ScreenList(Scr) != None;
	if (Scr.winClient == None)
		return False;
	for (C = Scr.winClient.GetTopChild(); C != None; C = C.GetLowerSibling())
		if (MenuUIChoice(C) != None)
			return True;
	return False;
}

static function RIPanel FindIn(Window W)
{
	local Window C;

	if (W == None)
		return None;
	for (C = W.GetTopChild(); C != None; C = C.GetLowerSibling())
		if (RIPanel(C) != None)
			return RIPanel(C);
	return None;
}

// ----------------------------------------------------------------------
// Setup
// ----------------------------------------------------------------------

event InitWindow()
{
	Super.InitWindow();
	bTickEnabled = True;
	HoverRow = -1;
	HoverBtn = -1;
	LastDescSel = -2;
	SetSelectability(True);
}

function AttachTo(MenuUIScreenWindow NewScreen, RIMenuSettings NewShell)
{
	Screen = NewScreen;
	Shell  = NewShell;
	bStandalone = (Shell == None);

	if (RIMenuScreenCustomizeKeys(Screen) != None)
	{
		Kind = KIND_KEYS;
		RIMenuScreenCustomizeKeys(Screen).FocusPanel = Self;
	}
	else if (Class'RIBase'.static.IsListScreen(Screen))
		Kind = KIND_LIST;
	else
		Kind = KIND_CHOICES;

	SetConfiguration(0, 0, Screen.width, Screen.height);
	HideScreenParts();          // before the first frame: no flash of the old layout
	RebuildRows();
	TakeSnapshot();
	BuildButtons();
	Sel = 0;
	UpdateDesc(True);
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

// Hides AE's own widgets. Safe at any time except inside the engine's ready
// pass (WindowReady): the engine subtracts hidden, not-yet-ready windows from
// its count, and these widgets don't need WindowReady. Doing it as soon as the
// screen opens means the old layout is never drawn, not even for one frame.
function HideScreenParts()
{
	local Window C;

	for (C = Screen.GetTopChild(); C != None; C = C.GetLowerSibling())
		if ((C != Self) && C.IsVisible(False))
			C.Hide();
}

function string TitleText()
{
	if ((Screen.winTitle != None) && (Screen.winTitle.titleText != ""))
		return Screen.winTitle.titleText;
	return Screen.title;
}

// ----------------------------------------------------------------------
// Rows
// ----------------------------------------------------------------------

function RebuildRows()
{
	local int i;

	if (Kind == KIND_KEYS)
		RowsFromList(RIMenuScreenCustomizeKeys(Screen).lstKeys);
	else if (Kind == KIND_LIST)
		RowsFromList(Class'RIBase'.static.ScreenList(Screen));
	else
		RowsFromChoices();

	bHasValues = False;
	for (i = 0; i < NumRows; i++)
		if (RowType[i] != ROW_ACTION)
			bHasValues = True;

	if (Sel >= NumRows)
		Sel = NumRows - 1;
	if ((Sel < 0) && (NumRows > 0))
		Sel = 0;
}

function RowsFromList(MenuUIListWindow L)
{
	local int i, id, n;

	NumRows = 0;
	if (L == None)
		return;

	n = L.GetNumRows();
	for (i = 0; (i < n) && (NumRows < MAXROWS); i++)
	{
		id = L.IndexToRowId(i);
		RowLabel[NumRows]  = Class'RIText'.static.Clean(L.GetField(id, 0));
		RowValue[NumRows]  = L.GetField(id, 1);
		RowType[NumRows]   = ROW_VALUE;
		RowFrac[NumRows]   = 0;
		RowOn[NumRows]     = 1;
		RowChoice[NumRows] = None;
		RowRef[NumRows]    = id;
		NumRows++;
	}
}

function RowsFromChoices()
{
	local Window C;
	local MenuUIChoice Ch;
	local int i, j;

	NumRows = 0;
	if (Screen.winClient == None)
		return;

	// Collect the option rows in on-screen order
	for (C = Screen.winClient.GetTopChild(); (C != None) && (NumRows < MAXROWS); C = C.GetLowerSibling())
	{
		Ch = MenuUIChoice(C);
		if (Ch == None)
			continue;
		j = NumRows;
		while ((j > 0) && (RowChoice[j - 1].y > Ch.y))
		{
			RowChoice[j] = RowChoice[j - 1];
			j--;
		}
		RowChoice[j] = Ch;
		NumRows++;
	}

	for (i = 0; i < NumRows; i++)
		FillChoiceRow(i);
}

function FillChoiceRow(int i)
{
	local MenuUIChoice Ch;
	local ScaleWindow Sl;
	local int n;

	Ch = RowChoice[i];
	RowRef[i]  = -1;
	RowFrac[i] = 0;
	RowOn[i]   = 0;
	if (Ch.IsSensitive())
		RowOn[i] = 1;
	RowValue[i] = "";
	RowType[i] = ROW_VALUE;

	// AE's menu buttons keep their caption in buttonText (not the TextWindow text)
	if ((Ch.btnAction != None) && (Ch.btnAction.buttonText != ""))
		RowLabel[i] = Class'RIText'.static.Clean(Ch.btnAction.buttonText);
	else
		RowLabel[i] = Class'RIText'.static.Clean(Ch.actionText);

	if (MenuUIChoiceSlider(Ch) != None)
	{
		RowType[i] = ROW_SLIDER;
		if ((MenuUIChoiceSlider(Ch).btnSlider != None) && (MenuUIChoiceSlider(Ch).btnSlider.winSlider != None))
		{
			Sl = MenuUIChoiceSlider(Ch).btnSlider.winSlider;
			n = Sl.GetNumTicks();
			if (n > 1)
				RowFrac[i] = FClamp(float(Sl.GetTickPosition()) / float(n - 1), 0, 1);
			RowValue[i] = Sl.GetValueString();
			if (RowValue[i] == "")
				RowValue[i] = string(int(RowFrac[i] * 100.0 + 0.5)) $ "%";
		}
	}
	else if (MenuUIChoiceEnum(Ch) != None)
	{
		if (MenuUIChoiceEnum(Ch).btnInfo != None)
			RowValue[i] = Class'RIText'.static.Clean(MenuUIChoiceEnum(Ch).btnInfo.buttonText);
		// Some enums (resolution) never fill btnInfo: read the list directly
		if ((RowValue[i] == "") && (MenuUIChoiceEnum(Ch).currentValue >= 0) && (MenuUIChoiceEnum(Ch).currentValue < 50))
			RowValue[i] = Class'RIText'.static.Clean(MenuUIChoiceEnum(Ch).enumText[MenuUIChoiceEnum(Ch).currentValue]);
		if ((RowValue[i] == "") && (MenuChoice_Resolution(Ch) != None))
			RowValue[i] = MenuChoice_Resolution(Ch).CurrentRes;
	}
	else if (MenuUIChoiceAction(Ch) != None)
		RowType[i] = ROW_ACTION;

	// Toggling full screen from the menu crashes the DX12 renderer, so the row is disabled
	if (IsFullScreenRow(Ch))
	{
		RowOn[i] = 0;
		RowValue[i] = "Off here";
	}
}

function bool IsFullScreenRow(MenuUIChoice Ch)
{
	return (MenuChoice_FullScreen(Ch) != None);
}

// ----------------------------------------------------------------------
// Changes: snapshot, dirty check, apply, discard
// ----------------------------------------------------------------------

function TakeSnapshot()
{
	local int i;

	NumSnap = NumRows;
	for (i = 0; i < NumRows; i++)
	{
		SnapLabel[i] = RowLabel[i];
		SnapValue[i] = RowValue[i];
	}
	bDirty = False;
}

function int FindSnap(int i)
{
	local int j;

	if ((i < NumSnap) && (SnapLabel[i] == RowLabel[i]))
		return i;
	for (j = 0; j < NumSnap; j++)
		if (SnapLabel[j] == RowLabel[i])
			return j;
	return -1;
}

function bool ComputeDirty()
{
	local int i, j;

	if (Kind == KIND_KEYS)
		return RIMenuScreenCustomizeKeys(Screen).HasChanges();

	for (i = 0; i < NumRows; i++)
	{
		if (RowType[i] == ROW_ACTION)
			continue;
		j = FindSnap(i);
		if ((j >= 0) && (SnapValue[j] != RowValue[i]))
			return True;
	}
	return False;
}

// Used by the settings layout before it closes this screen
function bool HasUnapplied()
{
	RebuildRows();
	bDirty = ComputeDirty();
	return bDirty;
}

function Apply()
{
	Screen.SaveSettings();
	RebuildRows();
	TakeSnapshot();
	AppliedFlash = 1.8;
	UpdateDesc(True);
}

function Discard()
{
	local int i, j, n;
	local Window C;
	local MenuUIListWindow L;

	if (Kind == KIND_KEYS)
	{
		RIMenuScreenCustomizeKeys(Screen).RevertNoPop();
	}
	else if (Kind == KIND_LIST)
	{
		// GMDX lists write values as they change: step each back to its old value
		L = Class'RIBase'.static.ScreenList(Screen);
		RebuildRows();
		for (i = 0; i < NumRows; i++)
		{
			j = FindSnap(i);
			if (j < 0)
				continue;
			n = 0;
			while ((L.GetField(RowRef[i], 1) != SnapValue[j]) && (n < 8))
			{
				Screen.ListRowActivated(L, RowRef[i]);
				n++;
			}
		}
	}
	else if (Screen.winClient != None)
	{
		for (C = Screen.winClient.GetTopChild(); C != None; C = C.GetLowerSibling())
			if (MenuUIChoice(C) != None)
				MenuUIChoice(C).CancelSetting();
	}
	RebuildRows();
	TakeSnapshot();
}

// ----------------------------------------------------------------------
// Row actions
// ----------------------------------------------------------------------

function CycleRow(int i, int Dir)
{
	local MenuUIListWindow L;
	local MenuUIChoice Ch;
	local string Start;
	local int n, k;

	if ((i < 0) || (i >= NumRows) || (RowOn[i] == 0))
		return;

	if (Kind == KIND_KEYS)
	{
		BeginRemap(i);
		return;
	}

	if (Kind == KIND_LIST)
	{
		L = Class'RIBase'.static.ScreenList(Screen);
		if (Dir > 0)
			Screen.ListRowActivated(L, RowRef[i]);
		else
		{
			// GMDX lists only step forward: go round once to count, then stop one short
			Start = L.GetField(RowRef[i], 1);
			n = 0;
			do
			{
				Screen.ListRowActivated(L, RowRef[i]);
				n++;
			} until ((L.GetField(RowRef[i], 1) == Start) || (n >= 8));
			for (k = 0; k < n - 1; k++)
				Screen.ListRowActivated(L, RowRef[i]);
		}
	}
	else
	{
		Ch = RowChoice[i];
		if (Ch == None)
			return;
		if (RowType[i] == ROW_ACTION)
		{
			PlaySound(Sound'DeusExSounds.UserInterface.Menu_Press', 0.25);
			Ch.ButtonActivated(Ch.btnAction);
			return;
		}
		if (Dir > 0)
			Ch.CycleNextValue();
		else
			Ch.CyclePreviousValue();
		if (RIChoiceScale(Ch) != None)
			Ch.SaveSetting();
	}

	PlaySound(Sound'DeusExSounds.UserInterface.Menu_Press', 0.25);
	RebuildRows();
	UpdateDesc(True);
}

function Activate(int i, optional bool bFromMouse)
{
	if ((i < 0) || (i >= NumRows))
		return;
	if (Kind == KIND_KEYS)
		BeginRemap(i, bFromMouse);
	else
		CycleRow(i, 1);
}

function BeginRemap(int i, optional bool bFromMouse)
{
	if ((i < 0) || (i >= NumRows))
		return;
	PlaySound(Sound'DeusExSounds.UserInterface.Menu_Press', 0.25);
	RIMenuScreenCustomizeKeys(Screen).BeginRemap(RowRef[i], bFromMouse);
}

function ClearKeyRow(int i)
{
	if ((Kind != KIND_KEYS) || (i < 0) || (i >= NumRows))
		return;
	PlaySound(Sound'DeusExSounds.UserInterface.Menu_Press', 0.25);
	RIMenuScreenCustomizeKeys(Screen).ClearRow(RowRef[i]);
	RebuildRows();
}

function SetSliderAt(int i, float PointX)
{
	local ScaleWindow Sl;
	local float f;
	local int n;

	if ((i < 0) || (i >= NumRows) || (RowType[i] != ROW_SLIDER) || (RowOn[i] == 0))
		return;
	if ((MenuUIChoiceSlider(RowChoice[i]) == None) || (MenuUIChoiceSlider(RowChoice[i]).btnSlider == None))
		return;
	Sl = MenuUIChoiceSlider(RowChoice[i]).btnSlider.winSlider;
	if (Sl == None)
		return;

	n = Sl.GetNumTicks();
	if (n < 2)
		return;
	f = FClamp((PointX - SliderX()) / SliderW(), 0, 1);
	if (int(f * (n - 1) + 0.5) != Sl.GetTickPosition())
	{
		Sl.SetTickPosition(int(f * (n - 1) + 0.5));
		// the interface sizes apply as you drag
		if (RIChoiceScale(RowChoice[i]) != None)
			RowChoice[i].SaveSetting();
	}
	RebuildRows();
}

function float SliderX() { return ListX + ListW * 0.48; }
function float SliderW() { return ListW * 0.28; }

// ----------------------------------------------------------------------
// Description panel
// ----------------------------------------------------------------------

function UpdateDesc(bool bForce)
{
	local int idx;

	if (!bForce && (Sel == LastDescSel))
		return;
	if (Sel != LastDescSel)
		DescAge = 0;
	LastDescSel = Sel;

	DescTitle = "";
	DescText  = "";
	if ((Sel < 0) || (Sel >= NumRows))
		return;

	DescTitle = RowLabel[Sel];

	if (Kind == KIND_LIST)
	{
		idx = int(Class'RIBase'.static.ScreenList(Screen).GetFieldValue(RowRef[Sel], 2));
		DescText = Class'RIBase'.static.ListHelp(Screen, idx);
	}
	else if ((Kind == KIND_CHOICES) && (RowChoice[Sel] != None))
	{
		DescText = RowChoice[Sel].helpText;
		if (IsFullScreenRow(RowChoice[Sel]))
			DescText = "Switching between full screen and a window from this menu crashes the current renderer, so the option is turned off here. To change it, set StartupFullscreen=True or False under [WinDrv.WindowsClient] in DeusEx.ini and restart the game.";
	}
}

// Keys: the screen's own help line changes as you rebind, so read it live
function string KeysHelp()
{
	if (Screen.winHelp != None)
		return Screen.winHelp.GetText();
	return "";
}

// ----------------------------------------------------------------------
// Buttons
// ----------------------------------------------------------------------

function AddBtn(string Label, string Key)
{
	if (NumBtn >= arrayCount(BtnLabel))
		return;
	BtnLabel[NumBtn] = Label;
	BtnKey[NumBtn]   = Key;
	NumBtn++;
}

function BuildButtons()
{
	local int i, act;

	NumBtn = 0;

	for (i = 0; i < 5; i++)
	{
		act = int(Screen.actionButtons[i].action);
		// 3 = AB_Reset, 5 = AB_Other (MenuUIWindow.EActionButtonEvents)
		if ((act == 3) && bHasValues)
		{
			if (Kind == KIND_KEYS)
				AddBtn(RevertLabel, "RI_RESET");
			else
				AddBtn(DefaultsLabel, "RI_RESET");
		}
		else if ((act == 5) && (Screen.actionButtons[i].text != ""))
			AddBtn(Screen.actionButtons[i].text, Screen.actionButtons[i].key);
	}

	if (bStandalone)
	{
		AddBtn(CancelLabel, "RI_CANCEL");
		AddBtn(DoneLabel, "RI_DONE");
		return;
	}
	if (RIRootWindow(GetRootWindow()).IsSubScreen(Screen))
		AddBtn(BackLabel, "RI_BACK");
	if (bHasValues)
		AddBtn(ApplyLabel, "RI_APPLY");
}

function bool IsRightBtn(int b)
{
	return (BtnKey[b] == "RI_APPLY") || (BtnKey[b] == "RI_BACK") || (BtnKey[b] == "RI_DONE") || (BtnKey[b] == "RI_CANCEL");
}

function PressBtn(int b)
{
	if ((b < 0) || (b >= NumBtn))
		return;

	PlaySound(Sound'DeusExSounds.UserInterface.Menu_Press', 0.25);

	switch (BtnKey[b])
	{
		case "RI_APPLY":
			Apply();
			break;
		case "RI_BACK":
			GoBack();
			break;
		case "RI_DONE":
			Screen.SaveSettings();
			DeusExRootWindow(GetRootWindow()).PopWindow();
			break;
		case "RI_CANCEL":
			Discard();
			DeusExRootWindow(GetRootWindow()).PopWindow();
			break;
		case "RI_RESET":
			if (Kind == KIND_KEYS)
				RIMenuScreenCustomizeKeys(Screen).RevertNoPop();
			else
				Screen.ResetToDefaults();     // GMDX lists confirm first
			RebuildRows();
			UpdateDesc(True);
			break;
		default:
			Screen.ProcessAction(BtnKey[b]);
			RebuildRows();
			UpdateDesc(True);
			break;
	}
}

function GoBack()
{
	if (Shell != None)
		Shell.RequestLeave(-3);     // RIMenuSettings.LEAVE_BACK
	else
		RequestClose();
}

// Standalone: close, asking first if there are unapplied changes
function RequestClose()
{
	if (HasUnapplied())
	{
		CloseBox = DeusExRootWindow(GetRootWindow()).MessageBox(CloseTitle, CloseText, 0, False, Self);
		if (RIMessageBox(CloseBox) != None)
			RIMessageBox(CloseBox).SetCustomButtons(ApplyChoice, DiscardChoice, StayChoice);
		return;
	}
	DeusExRootWindow(GetRootWindow()).PopWindow();
}

event bool BoxOptionSelected(Window box, int buttonNumber)
{
	if ((CloseBox == None) || (box != CloseBox))
		return False;

	DeusExRootWindow(GetRootWindow()).PopWindow();      // the prompt
	CloseBox = None;

	if (buttonNumber == 2)
		return True;                                    // Stay
	if (buttonNumber == 0)
		Screen.SaveSettings();
	else
		Discard();
	DeusExRootWindow(GetRootWindow()).PopWindow();      // this screen
	return True;
}

// ----------------------------------------------------------------------
// Frame update
// ----------------------------------------------------------------------

function Layout()
{
	local float x, rx, w;
	local int b;

	UIS = GetRootWindow().height / 1080.0;

	if (Shell != None)
	{
		// Inside settings the screen covers the whole window (so clicks on the
		// category list can be passed back); content goes in the layout's panel
		OX = Shell.ContentX;
		OY = Shell.ContentY;
		IW = Shell.ContentW;
		IH = Shell.ContentH;
	}
	else
	{
		OX = 0;
		OY = 0;
		if (bStandalone)
		{
			OX = 44 * UIS;
			OY = 36 * UIS;
		}
		IW = width - OX * 2;
		IH = height - OY * 2;
	}

	RowH  = 46 * UIS;
	ListX = OX;
	ListY = OY + 66 * UIS;
	ListW = FMax(300 * UIS, IW * 0.58);
	BarH  = 44 * UIS;
	BarY  = OY + IH - BarH;
	ListH = BarY - 48 * UIS - ListY;
	ListH = FMax(RowH, float(int(ListH / RowH)) * RowH);
	DescX = ListX + ListW + 44 * UIS;
	DescW = FMax(100 * UIS, OX + IW - DescX);

	// Left group from the left edge, Back / Apply from the right
	x  = OX;
	rx = OX + IW;
	for (b = NumBtn - 1; b >= 0; b--)
	{
		if (!IsRightBtn(b))
			continue;
		w = BtnWidth(b);
		rx -= w;
		BtnX[b] = rx;
		rx -= 12 * UIS;
	}
	for (b = 0; b < NumBtn; b++)
	{
		BtnY[b] = BarY;
		BtnH[b] = BarH;
		BtnW[b] = BtnWidth(b);
		if (IsRightBtn(b))
			continue;
		BtnX[b] = x;
		x += BtnW[b] + 12 * UIS;
	}
}

function float BtnWidth(int b)
{
	local float w;

	w = Class'RIText'.static.Width(Class'RIFontHead', Caps(BtnLabel[b]), 0.56);
	if (BtnKey[b] == "RI_APPLY")
		w = FMax(w, Class'RIText'.static.Width(Class'RIFontHead', Caps(AppliedLabel), 0.56));
	return FMax(150 * UIS, w + 64 * UIS);
}

event Tick(float deltaSeconds)
{
	local float k, maxScroll, target;
	local int b;

	Age += deltaSeconds;
	DescAge += deltaSeconds;
	AppliedFlash = FMax(0, AppliedFlash - deltaSeconds);

	if (Screen == None)
		return;

	if ((width != Screen.width) || (height != Screen.height))
		SetConfiguration(0, 0, Screen.width, Screen.height);

	Layout();
	HideScreenParts();          // AE re-shows some (e.g. its help line); keep them hidden
	if (RIRootWindow(GetRootWindow()) != None)
		RIRootWindow(GetRootWindow()).GuardInitCount("Panel");
	RebuildRows();
	bDirty = ComputeDirty();
	UpdateDesc(False);

	// Smooth scrolling
	maxScroll = FMax(0, NumRows * RowH - ListH);
	ScrollTarget = FClamp(ScrollTarget, 0, maxScroll);
	k = FMin(1.0, deltaSeconds * 14.0);
	ScrollY += (ScrollTarget - ScrollY) * k;
	if (Abs(ScrollTarget - ScrollY) < 0.25)
		ScrollY = ScrollTarget;

	// Sliding selection highlight
	if ((Sel >= 0) && (Sel < NumRows))
	{
		target = Sel * RowH;
		if (!bHiPlaced)
		{
			HiY = target;
			bHiPlaced = True;
		}
		HiY += (target - HiY) * FMin(1.0, deltaSeconds * 18.0);
		HiA = FMin(1.0, HiA + deltaSeconds * 6.0);
	}
	else
		HiA = FMax(0, HiA - deltaSeconds * 6.0);

	for (b = 0; b < NumBtn; b++)
	{
		if (b == HoverBtn)
			BtnHot[b] = FMin(1.0, BtnHot[b] + deltaSeconds * 10.0);
		else
			BtnHot[b] = FMax(0.0, BtnHot[b] - deltaSeconds * 6.0);
	}

	KeepFocus();
}

// Take keyboard focus back when it lands on one of AE's hidden widgets
function KeepFocus()
{
	local Window F, W;

	if (!bReady)
		return;

	if (DeusExRootWindow(GetRootWindow()).GetTopWindow() != Screen)
		return;
	if ((Kind == KIND_KEYS) && RIMenuScreenCustomizeKeys(Screen).bWaitingForInput)
		return;

	F = GetRootWindow().GetFocusWindow();
	if (F == Self)
		return;
	if (F != None)
	{
		W = F;
		while ((W != None) && (W != Screen))
			W = W.GetParent();
		if (W == None)
			return;       // focus is outside this screen (e.g. the category list)
	}
	SetFocusWindow(Self);
}

// ----------------------------------------------------------------------
// Selection helpers
// ----------------------------------------------------------------------

function SetSel(int NewSel)
{
	if (NumRows <= 0)
		return;
	NewSel = Clamp(NewSel, 0, NumRows - 1);
	if (NewSel != Sel)
		PlaySound(Sound'DeusExSounds.UserInterface.Menu_Focus', 0.15);
	Sel = NewSel;
	EnsureVisible();
	UpdateDesc(False);
}

function EnsureVisible()
{
	if (Sel * RowH < ScrollTarget)
		ScrollTarget = Sel * RowH;
	else if ((Sel + 1) * RowH > ScrollTarget + ListH)
		ScrollTarget = (Sel + 1) * RowH - ListH;
}

function int PageRows()
{
	return Max(1, int(ListH / RowH) - 1);
}

function int RowAt(float PX, float PY)
{
	local int r;

	if ((PX < ListX) || (PX > ListX + ListW) || (PY < ListY) || (PY > ListY + ListH))
		return -1;
	r = int((PY - ListY + ScrollY) / RowH);
	if ((r < 0) || (r >= NumRows))
		return -1;
	return r;
}

function int BtnAt(float PX, float PY)
{
	local int b;

	for (b = 0; b < NumBtn; b++)
		if ((PX >= BtnX[b]) && (PX <= BtnX[b] + BtnW[b]) && (PY >= BtnY[b]) && (PY <= BtnY[b] + BtnH[b]))
			return b;
	return -1;
}

// ----------------------------------------------------------------------
// Input
// ----------------------------------------------------------------------

event MouseMoved(float newX, float newY)
{
	if (Shell != None)
		Shell.NavHoverAt(newX, newY);
	if (bDragSlider)
	{
		SetSliderAt(DragRow, newX);
		return;
	}
	HoverRow = RowAt(newX, newY);
	HoverBtn = BtnAt(newX, newY);
}

event MouseLeftWindow()
{
	HoverRow = -1;
	HoverBtn = -1;
	if (Shell != None)
		Shell.NavHoverAt(-1, -1);
}

event bool MouseButtonPressed(float pointX, float pointY, EInputKey button, int numClicks)
{
	local int r, b;

	if (button == IK_MouseWheelUp)
	{
		ScrollTarget -= RowH * 3;
		return True;
	}
	if (button == IK_MouseWheelDown)
	{
		ScrollTarget += RowH * 3;
		return True;
	}

	// A click on the category list: hand it to the settings layout. This may
	// close this screen, so nothing of ours is touched afterwards.
	if ((Shell != None) && (button == IK_LeftMouse) && Shell.NavClickAt(pointX, pointY))
		return True;

	SetFocusWindow(Self);

	b = BtnAt(pointX, pointY);
	if ((b >= 0) && (button == IK_LeftMouse))
	{
		PressBtn(b);
		return True;
	}

	r = RowAt(pointX, pointY);
	if (r >= 0)
	{
		Sel = r;
		EnsureVisible();
		UpdateDesc(False);

		if (button == IK_LeftMouse)
		{
			if ((RowType[r] == ROW_SLIDER) && (pointX >= SliderX() - 8 * UIS) && (pointX <= SliderX() + SliderW() + 8 * UIS))
			{
				bDragSlider = True;
				DragRow = r;
				GrabMouse();
				SetSliderAt(r, pointX);
			}
			// a value row: the < side goes back, the rest goes forward
			else if ((RowType[r] == ROW_VALUE) && (Kind != KIND_KEYS) && (pointX < ArrowLX[r] + 26 * UIS) && (pointX > ArrowLX[r] - 60 * UIS))
				CycleRow(r, -1);
			else
				Activate(r, True);
		}
		else if (button == IK_RightMouse)
		{
			if (Kind == KIND_KEYS)
				ClearKeyRow(r);
			else
				CycleRow(r, -1);
		}
	}
	return True;
}

event bool MouseButtonReleased(float pointX, float pointY, EInputKey button, int numClicks)
{
	if (bDragSlider)
	{
		bDragSlider = False;
		UngrabMouse();
		PlaySound(Sound'DeusExSounds.UserInterface.Menu_Press', 0.25);
	}
	return True;
}

event bool VirtualKeyPressed(EInputKey key, bool bRepeat)
{
	if ((Kind == KIND_KEYS) && RIMenuScreenCustomizeKeys(Screen).bWaitingForInput)
		return False;

	switch (key)
	{
		case IK_Up:            SetSel(Sel - 1); return True;
		case IK_Down:          SetSel(Sel + 1); return True;
		case IK_PageUp:        SetSel(Sel - PageRows()); return True;
		case IK_PageDown:      SetSel(Sel + PageRows()); return True;
		case IK_Home:          SetSel(0); return True;
		case IK_End:           SetSel(NumRows - 1); return True;
		case IK_MouseWheelUp:  ScrollTarget -= RowH * 3; return True;
		case IK_MouseWheelDown: ScrollTarget += RowH * 3; return True;

		case IK_Left:
			if (Kind != KIND_KEYS)
				CycleRow(Sel, -1);
			return True;
		case IK_Right:
			if (Kind != KIND_KEYS)
				CycleRow(Sel, 1);
			return True;
		case IK_Enter:
		case IK_Space:
			Activate(Sel);
			return True;
		case IK_Delete:
		case IK_Backspace:
			ClearKeyRow(Sel);
			return True;
		case IK_Escape:
			GoBack();
			return True;
	}
	return False;
}

// ----------------------------------------------------------------------
// Drawing
// ----------------------------------------------------------------------

event DrawWindow(GC gc)
{
	local float a, y, sh, th, ty, total;
	local int i, first, last, st;
	local string Count;

	if (Screen == None)
		return;

	a = Class'RIUtil'.static.Phase(Age, 0.0, 0.3);
	gc.EnableSmoothing(True);

	// Augmentique's Outfit Settings opens from the in-game Outfit page: the
	// menus' blue palette is mapped to the persona gold while it draws
	if (Screen.IsA('OutfitSettingsMenu'))
	{
		Class'RITheme'.static.SetMode(1);
		Class'RITheme'.default.bGoldMenus = True;
	}

	if (bStandalone)
		DrawOwnFrame(gc, a);

	// Header: screen title, option count, hairline with a bright accent
	Class'RIText'.static.Draw(gc, Class'RIFontHead', ListX, OY + 6 * UIS, Caps(TitleText()),
		Class'RIUtil'.static.Col(236 * a, 238 * a, 255 * a), 0.82);
	if (bHasValues)
	{
		Count = NumRows @ "OPTIONS";
		if (bDirty)
			Count = UnsavedLabel;
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', ListX, OY + 6 * UIS, ListW, 24 * UIS, Count,
			Class'RIUtil'.static.Col(95 * a, 200 * a, 255 * a), 2);
	}
	Class'RIText'.static.HLine(gc, ListX, OY + 44 * UIS, ListW, Class'RIUtil'.static.Col(44 * a, 48 * a, 128 * a));
	Class'RIText'.static.HLine(gc, ListX, OY + 44 * UIS, 40 * UIS, Class'RIUtil'.static.Col(170 * a, 176 * a, 255 * a));

	// Rows, clipped to the list area
	st = gc.PushGC();
	gc.Intersect(ListX - 4 * UIS, ListY, ListW + 8 * UIS, ListH);

	if ((HiA > 0.01) && (NumRows > 0))
		DrawHighlight(gc, ListY + HiY - ScrollY, a * HiA);

	first = Max(0, int(ScrollY / RowH));
	last  = Min(NumRows - 1, int((ScrollY + ListH) / RowH));
	for (i = first; i <= last; i++)
		DrawRow(gc, i, ListY + i * RowH - ScrollY, a);

	gc.PopGC(st);

	if (Screen.IsA('MenuScreenBrightness'))
		DrawBrightnessBars(gc, a);

	// Thin scrollbar when the list overflows
	total = NumRows * RowH;
	if (total > ListH + 1)
	{
		sh = FMax(24 * UIS, ListH * ListH / total);
		th = ListY + (ListH - sh) * (ScrollY / (total - ListH));
		Class'RIText'.static.VLine(gc, ListX + ListW + 14 * UIS, ListY, ListH, Class'RIUtil'.static.Col(30 * a, 32 * a, 84 * a));
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(Class'RIUtil'.static.Col(150 * a, 156 * a, 250 * a));
		Class'RIText'.static.Fill(gc, Class'RIText'.static.Snap(ListX + ListW + 13.5 * UIS), Class'RIText'.static.Snap(th),
			1.5, Class'RIText'.static.Snap(sh));
	}

	// Control hints under the list
	ty = ListY + ListH + 14 * UIS;
	if (Kind == KIND_KEYS)
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', ListX, ty, HintKeys, Class'RIUtil'.static.Col(88 * a, 94 * a, 160 * a));
	else if (bHasValues)
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', ListX, ty, HintValues, Class'RIUtil'.static.Col(88 * a, 94 * a, 160 * a));

	DrawDescription(gc, a);
	DrawButtons(gc, a);
}

// Standalone: the dark framed panel the settings layout would otherwise provide
// Brightness: AE's four calibration bars (red, green, blue, white), each a
// gradient to black. Gamma is applied to the whole screen, so they show the
// slider's effect live.
function DrawBrightnessBars(GC gc, float a)
{
	local float x, y, w, h, bw, gap;
	local int i;
	local Color C;
	local Texture T;

	T = Texture'DeusExUI.UserInterface.MenuBrightnessGradient';
	x = ListX;
	y = ListY + NumRows * RowH + 40 * UIS;
	w = ListW;
	h = FMin(ListY + ListH - y, 420 * UIS);
	if (h < 80 * UIS)
		return;
	gap = 14 * UIS;
	bw = (w - gap * 3) / 4;

	for (i = 0; i < 4; i++)
	{
		C.R = 0; C.G = 0; C.B = 0;
		if ((i == 0) || (i == 3)) C.R = 255 * a;
		if ((i == 1) || (i == 3)) C.G = 255 * a;
		if ((i == 2) || (i == 3)) C.B = 255 * a;
		gc.SetStyle(DSTY_Normal);
		gc.SetTileColor(C);
		Class'RIText'.static.Tex(gc, x + i * (bw + gap), y, bw, h, 0, 0, T.USize, T.VSize, T);
		Class'RIText'.static.Box(gc, x + i * (bw + gap), y, bw, h, Class'RIUtil'.static.Col(40 * a, 42 * a, 100 * a));
	}
}

function DrawOwnFrame(GC gc, float a)
{
	local float pulse;

	if (Class'RIVP'.static.InMenus())
	{
		Class'RIVP'.static.Black(gc, 4 * UIS, 4 * UIS, width - 8 * UIS, height - 8 * UIS);
		Class'RIVP'.static.Frame(gc, 0, 0, width, height, 16 * UIS, a);
		return;
	}
	pulse = 0.85 + 0.15 * Sin(Age * 2.0);
	gc.SetStyle(DSTY_Modulated);
	Class'RIText'.static.Tex(gc, 0, 0, width, height, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dark');
	Class'RIText'.static.Tex(gc, 0, 0, width, height, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dark');
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(6 * a, 7 * a, 26 * a));
	Class'RIText'.static.Fill(gc, 0, 0, width, height);
	Class'RIText'.static.Box(gc, 0, 0, width, height, Class'RIUtil'.static.Col(80 * a * pulse, 84 * a * pulse, 190 * a * pulse));
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(205 * a, 210 * a, 255 * a));
	Class'RIText'.static.Fill(gc, 0, 0, 80 * UIS * a, 1.5);
}

function DrawHighlight(GC gc, float y, float a)
{
	y = Class'RIText'.static.Snap(y);
	if (Class'RIVP'.static.InMenus())
	{
		Class'RIVP'.static.Btn(gc, ListX, y, ListW, RowH, True, 0.85 * a);
		return;
	}
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(34 * a, 36 * a, 106 * a));
	Class'RIText'.static.Tex(gc, ListX, y, ListW, RowH, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');
	Class'RIText'.static.Box(gc, ListX, y, ListW, RowH, Class'RIUtil'.static.Col(104 * a, 108 * a, 200 * a));
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(205 * a, 210 * a, 255 * a));
	Class'RIText'.static.Fill(gc, ListX, y, 1.5, RowH);
}

function DrawRow(GC gc, int i, float y, float a)
{
	local float ra, dx, vr, tw, lw, sx, sw, f, kx, pulse, ArrowK;
	local Color LabelC, ValueC, Dim;
	local string V;
	local bool bHot, bWait;
	local RIMenuScreenCustomizeKeys Keys;

	ra = a * Class'RIUtil'.static.Phase(Age, 0.05 + FMin(i - int(ScrollY / RowH), 14) * 0.022, 0.32);
	if (ra <= 0.01)
		return;
	dx = (1.0 - ra) * 16 * UIS;
	bHot = (i == Sel) || (i == HoverRow);

	// Hover wash (selection has its own sliding highlight)
	if ((i == HoverRow) && (i != Sel))
	{
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(Class'RIUtil'.static.Col(14 * ra, 15 * ra, 44 * ra));
		Class'RIText'.static.Tex(gc, ListX, Class'RIText'.static.Snap(y), ListW, RowH, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');
	}

	if (RowOn[i] == 0)
		LabelC = Class'RIUtil'.static.Col(80 * ra, 84 * ra, 130 * ra);
	else if (i == Sel)
		LabelC = Class'RIUtil'.static.Col(255 * ra, 255 * ra, 255 * ra);
	else
		LabelC = Class'RIUtil'.static.Col(186 * ra, 190 * ra, 236 * ra);

	if (RowOn[i] == 0)
		ValueC = Class'RIUtil'.static.Col(60 * ra, 96 * ra, 130 * ra);
	else if (i == Sel)
		ValueC = Class'RIUtil'.static.Col(150 * ra, 228 * ra, 255 * ra);
	else
		ValueC = Class'RIUtil'.static.Col(95 * ra, 200 * ra, 255 * ra);
	Dim = Class'RIUtil'.static.Col(90 * ra, 140 * ra, 200 * ra);

	vr = ListX + ListW - 36 * UIS;

	// Label (truncated to its column)
	if (RowType[i] == ROW_SLIDER)
		lw = SliderX() - (ListX + 20 * UIS) - 16 * UIS;
	else
		lw = ListW * 0.56;
	Class'RIText'.static.DrawIn(gc, Class'RIFontBody', ListX + 20 * UIS + dx, y, lw, RowH,
		Class'RIText'.static.Fit(Class'RIFontBody', RowLabel[i], lw), LabelC, 0);

	V = RowValue[i];

	if (Kind == KIND_KEYS)
	{
		Keys = RIMenuScreenCustomizeKeys(Screen);
		bWait = Keys.bWaitingForInput && (Keys.WaitingRowId() == RowRef[i]);
		if (bWait)
		{
			pulse = 0.55 + 0.45 * Sin(Age * 7.0);
			V = WaitingLabel;
			ValueC = Class'RIUtil'.static.Col(255 * ra * pulse, 255 * ra * pulse, 255 * ra * pulse);
		}
		else if ((V == "") || (V == Keys.NoneText))
		{
			V = "-";
			ValueC = Class'RIUtil'.static.Col(70 * ra, 74 * ra, 120 * ra);
		}
	}

	if (RowType[i] == ROW_SLIDER)
	{
		sx = SliderX();
		sw = SliderW();
		f  = RowFrac[i];
		Class'RIText'.static.HLine(gc, sx, y + RowH * 0.5, sw, Class'RIUtil'.static.Col(44 * ra, 48 * ra, 120 * ra));
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(ValueC);
		Class'RIText'.static.Fill(gc, Class'RIText'.static.Snap(sx), Class'RIText'.static.Snap(y + RowH * 0.5 - 0.5),
			Class'RIText'.static.Snap(sw * f), 1.0);
		kx = Class'RIText'.static.Snap(sx + sw * f - 1.0);
		gc.SetTileColor(LabelC);
		Class'RIText'.static.Tex(gc, kx, Class'RIText'.static.Snap(y + RowH * 0.5 - 6 * UIS), 2.0, Class'RIText'.static.Snap(12 * UIS),
			0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_White');
		Class'RIText'.static.DrawIn(gc, Class'RIFontBody', vr - 90 * UIS, y, 90 * UIS, RowH, V, ValueC, 2, 0.95);
	}
	else if (RowType[i] == ROW_ACTION)
	{
		ArrowK = 0.6;
		if (bHot)
			ArrowK = 1.0;
		Class'RIText'.static.DrawIn(gc, Class'RIFontBody', vr + 6 * UIS, y, 20 * UIS, RowH, ">",
			Class'RIUtil'.static.Scale(ValueC, ArrowK), 0);
	}
	else
	{
		V = Class'RIText'.static.Fit(Class'RIFontBody', V, ListW * 0.36, 0.95);
		tw = Class'RIText'.static.Width(Class'RIFontBody', V, 0.95);
		Class'RIText'.static.DrawIn(gc, Class'RIFontBody', vr - tw, y, tw, RowH, V, ValueC, 0, 0.95);

		// Cycle arrows: on every changeable row (faint), bright on the active
		// one; each side is its own click target (< back, > forward)
		ArrowLX[i] = vr - tw - 30 * UIS;
		ArrowRX[i] = vr + 6 * UIS;
		if ((RowOn[i] != 0) && (Kind != KIND_KEYS))
		{
			if (bHot)
				ArrowK = 1.0;
			else
				ArrowK = 0.45;
			Class'RIText'.static.DrawIn(gc, Class'RIFontBody', ArrowLX[i], y, 22 * UIS, RowH, "<", Class'RIUtil'.static.Scale(ValueC, ArrowK), 1, 0.9);
			Class'RIText'.static.DrawIn(gc, Class'RIFontBody', ArrowRX[i], y, 22 * UIS, RowH, ">", Class'RIUtil'.static.Scale(ValueC, ArrowK), 1, 0.9);
		}
	}

	// Row separator
	Class'RIText'.static.HLine(gc, ListX + 12 * UIS, y + RowH - 0.5, ListW - 24 * UIS,
		Class'RIUtil'.static.Col(28 * ra, 30 * ra, 80 * ra));
}

function DrawDescription(GC gc, float a)
{
	local float x, y, w, da, h;
	local string T, Cur;

	if (DescW < 60 * UIS)
		return;

	da = a * Class'RIUtil'.static.Phase(DescAge, 0.0, 0.22);

	// Panel outline with a top accent
	Class'RIText'.static.Box(gc, DescX, ListY, DescW, ListH, Class'RIUtil'.static.Col(40 * a, 44 * a, 116 * a));
	Class'RIText'.static.HLine(gc, DescX, ListY, 48 * UIS, Class'RIUtil'.static.Col(170 * a, 176 * a, 255 * a));
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(10 * a, 11 * a, 34 * a));
	Class'RIText'.static.Fill(gc, DescX, ListY, DescW, ListH);

	x = DescX + 24 * UIS;
	w = DescW - 48 * UIS;
	y = ListY + 22 * UIS;

	if (Screen.IsA('RIMenuScreenCrosshair'))
		DrawCrossPreview(gc, a);

	if ((Sel < 0) || (Sel >= NumRows))
		return;

	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, OptionLabel, Class'RIUtil'.static.Col(95 * da, 200 * da, 255 * da));
	y += 26 * UIS;
	h = Class'RIText'.static.DrawWrapped(gc, Class'RIFontHead', x, y + (1.0 - da) * 6 * UIS, w, Caps(DescTitle),
		Class'RIUtil'.static.Col(240 * da, 242 * da, 255 * da), 0.62, 1.25);
	y += h + 12 * UIS;
	Class'RIText'.static.HLine(gc, x, y, w, Class'RIUtil'.static.Col(44 * da, 48 * da, 128 * da));
	y += 18 * UIS;

	if (Kind == KIND_KEYS)
		T = KeysHelp();
	else
		T = DescText;
	if (T != "")
		Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x, y, w, T,
			Class'RIUtil'.static.Col(176 * da, 182 * da, 232 * da), 0.9, 1.35);

	// Current value, pinned to the bottom of the panel
	if (RowType[Sel] != ROW_ACTION)
	{
		Cur = RowValue[Sel];
		if (Cur == "")
			Cur = "-";
		y = ListY + ListH - 58 * UIS;
		Class'RIText'.static.HLine(gc, x, y, w, Class'RIUtil'.static.Col(30 * da, 32 * da, 86 * da));
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y + 12 * UIS, CurrentLabel, Class'RIUtil'.static.Col(95 * da, 200 * da, 255 * da));
		Class'RIText'.static.DrawIn(gc, Class'RIFontBody', x, y + 6 * UIS, w, 30 * UIS,
			Class'RIText'.static.Fit(Class'RIFontBody', Cur, w * 0.7), Class'RIUtil'.static.Col(240 * da, 242 * da, 255 * da), 2);
	}
}

// Settings > Interface > Crosshair: the crosshair as set, at twice its
// size, over a patch half dark and half light (so the outline can be judged).
// In a game it shows the in-game crosshair's own spread right now (the held
// weapon's real spread), so it matches what's on screen; on the main menu
// the spread breathes in and out when dynamic spread is on. Sits above the
// current value at the foot of the description panel.
function DrawCrossPreview(GC gc, float a)
{
	local float px, py, pw, ph, sp;
	local Color W;
	local DeusExRootWindow R;
	local RICrosshair X;

	pw = DescW - 48 * UIS;
	px = DescX + 24 * UIS;
	ph = 160 * UIS;
	py = ListY + ListH - 80 * UIS - ph;
	if (py < ListY + 200 * UIS)
		return;
	gc.SetStyle(DSTY_Normal);
	gc.SetTileColor(Class'RIUtil'.static.Raw(34 * a, 36 * a, 42 * a));
	Class'RIText'.static.Fill(gc, px, py, pw * 0.5, ph);
	gc.SetTileColor(Class'RIUtil'.static.Raw(150 * a, 152 * a, 160 * a));
	Class'RIText'.static.Fill(gc, px + pw * 0.5, py, pw * 0.5, ph);
	Class'RIText'.static.Box(gc, px, py, pw, ph, Class'RIUtil'.static.Col(40 * a, 44 * a, 116 * a));
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', px + 10 * UIS, py + 8 * UIS, "PREVIEW  2X",
		Class'RIUtil'.static.Col(95 * a, 200 * a, 255 * a), 0.8);
	sp = 0;
	R = DeusExRootWindow(GetRootWindow());
	if ((R != None) && (R.hud != None))
		X = RICrosshair(R.hud.cross);
	if ((X != None) && (DeusExPlayer(R.parentPawn) != None) && (DeusExPlayer(R.parentPawn).Weapon != None))
		sp = X.Spread;
	else if (Class'RICrosshair'.default.XDynamic)
		sp = (0.5 + 0.5 * Sin(Age * 2.2)) * 6.0;
	W = Class'RIUtil'.static.Raw(255, 255, 255);
	Class'RICrosshair'.static.DrawCross(gc, px + pw * 0.5, py + ph * 0.5, 2.0, W, sp);
}

function DrawButtons(GC gc, float a)
{
	local int b;
	local float hot, pulse, ba;
	local bool bPrimary, bLive;
	local string L;
	local Color Edge, Fill, Txt;

	pulse = 0.8 + 0.2 * Sin(Age * 4.0);

	for (b = 0; b < NumBtn; b++)
	{
		ba = a * Class'RIUtil'.static.Phase(Age, 0.15 + b * 0.04, 0.3);
		hot = BtnHot[b];
		bPrimary = (BtnKey[b] == "RI_APPLY");
		bLive = !bPrimary || bDirty;
		L = Caps(BtnLabel[b]);

		if (bPrimary && !bDirty && (AppliedFlash > 0))
			L = Caps(AppliedLabel);

		if (bPrimary && bDirty)
		{
			Fill = Class'RIUtil'.static.Col((44 + 30 * hot) * ba * pulse, (48 + 30 * hot) * ba * pulse, (150 + 60 * hot) * ba * pulse);
			Edge = Class'RIUtil'.static.Col(190 * ba, 196 * ba, 255 * ba);
			Txt  = Class'RIUtil'.static.Col(255 * ba, 255 * ba, 255 * ba);
		}
		else if (bLive)
		{
			Fill = Class'RIUtil'.static.Col(30 * hot * ba, 32 * hot * ba, 96 * hot * ba);
			Edge = Class'RIUtil'.static.Col((70 + 100 * hot) * ba, (74 + 100 * hot) * ba, (170 + 80 * hot) * ba);
			Txt  = Class'RIUtil'.static.Col((186 + 69 * hot) * ba, (190 + 65 * hot) * ba, (236 + 19 * hot) * ba);
		}
		else
		{
			Fill = Class'RIUtil'.static.Col(10 * hot * ba, 11 * hot * ba, 30 * hot * ba);
			Edge = Class'RIUtil'.static.Col(40 * ba, 42 * ba, 100 * ba);
			if (AppliedFlash > 0)
				Txt = Class'RIUtil'.static.Col(95 * ba, 200 * ba, 255 * ba);
			else
				Txt = Class'RIUtil'.static.Col(80 * ba, 84 * ba, 136 * ba);
		}

		if (Class'RIVP'.static.InMenus())
		{
			if (bLive)
				Class'RIVP'.static.Btn(gc, BtnX[b], BtnY[b], BtnW[b], BtnH[b], (hot > 0.5) || (bPrimary && bDirty), ba);
			else
				Class'RIVP'.static.Btn(gc, BtnX[b], BtnY[b], BtnW[b], BtnH[b], False, 0.45 * ba);
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', BtnX[b], BtnY[b], BtnW[b] - 14 * UIS, BtnH[b], L, Txt, 1, 0.56);
			continue;
		}
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(Fill);
		Class'RIText'.static.Tex(gc, BtnX[b], BtnY[b], BtnW[b], BtnH[b], 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');
		Class'RIText'.static.Box(gc, BtnX[b], BtnY[b], BtnW[b], BtnH[b], Edge);
		if (bLive)
		{
			gc.SetStyle(DSTY_Translucent);
			gc.SetTileColor(Edge);
			Class'RIText'.static.Fill(gc, BtnX[b], BtnY[b], 1.5, BtnH[b]);
		}
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', BtnX[b], BtnY[b], BtnW[b], BtnH[b], L, Txt, 1, 0.56);
	}
}

defaultproperties
{
     ApplyLabel="Apply"
     AppliedLabel="Applied"
     BackLabel="Back"
     DefaultsLabel="Restore Defaults"
     RevertLabel="Revert"
     WaitingLabel="PRESS A KEY..."
     HintValues="ENTER / CLICK  CHANGE      LEFT / RIGHT  ADJUST      ESC  BACK"
     HintKeys="ENTER / CLICK  REBIND      DELETE / RIGHT CLICK  CLEAR      ESC  BACK"
     CurrentLabel="CURRENT"
     OptionLabel="OPTION"
     UnsavedLabel="UNSAVED CHANGES"
     DoneLabel="Done"
     CancelLabel="Cancel"
     CloseTitle="Unapplied changes"
     CloseText="You changed options on this screen. Keep them before closing?"
     ApplyChoice="Keep"
     DiscardChoice="Discard"
     StayChoice="Stay"
}
