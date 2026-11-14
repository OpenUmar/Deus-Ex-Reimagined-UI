//=============================================================================
// RIMenuScreenNewGame
// Character creation in the settings layout style. Every rule of AE's
// screen is inherited unchanged: local skill copies, point costs, the
// portrait list (including LDDP's female JC), playthrough modifiers, the
// blank-name check and the start sequence. AE's widgets still exist (hidden)
// and hold the state; this class only draws and takes input.
//
//   Agent column    code name, real name (just type), portrait, LDDP options
//   Skills column   level pips, cost, - / + per row
//   Detail column   the selected skill, with the current level highlighted
//=============================================================================
class RIMenuScreenNewGame extends MenuScreenNewGame;

const MAXSKILLS = 32;
const MAXHOT    = 64;

// Hot-region ids (rebuilt every frame while drawing)
const HOT_NAME     = 20;
const HOT_PREV     = 10;
const HOT_NEXT     = 11;
const HOT_PORTRAIT = 12;
const HOT_MORPHEUS = 30;
const HOT_MALEINT  = 31;
const HOT_BTN      = 40;    // + button index
const HOT_ROW      = 100;   // + skill index
const HOT_MINUS    = 200;
const HOT_PLUS     = 300;
const HOT_UP       = 50;
const HOT_DOWN     = 51;

const BTN_BACK  = 0;
const BTN_RESET = 1;
const BTN_MODS  = 2;
const BTN_HELP  = 3;
const BTN_START = 4;

var float S;
var float AnimTime, DescAge, PointsFlash;
var bool  bReady;

// Skills in display order (indices into localSkills)
var int   Order[32];
var int   NumSkills;
var int   SkillSel;
var float SelY;           // eased highlight position
var int   LastShown;

// 0 = skills, 1 = appearance (Left / Right act on the focused one)
var int   Zone;

// Layout (design pixels of the 1920x1080 mockup times S)
var float OX;                     // left edge of the 1920-wide design area
var float FrameX, FrameY, FrameW, FrameH;
var float KX, KY, KW, KH;         // skills panel
var float DX, DY, DW, DH;         // description box
var float AX, AY, AW;             // agent column
var float RowH, RowStep, ListY;
var float BtnY, BtnH;

// Hit regions from the last frame
var float HotX[64], HotY[64], HotW[64], HotH[64];
var int   HotId[64];
var int   NumHot;
var int   HoverId;
var float MouseX, MouseY;

var localized string HeaderText;
var localized string SubHeaderText;
var localized string PointsLabel;
var localized string AgentLabel;
var localized string CodeNameLabel;
var localized string RealNameLabel;
var localized string AppearanceLabel;
var localized string SkillsLabel;
var localized string LevelLabel;
var localized string CostLabel;
var localized string MaleLabel;
var localized string FemaleLabel;
var localized string NextCostLabel;
var localized string MasteredLabel;
var localized string NoPointsLabel;
var localized string LevelNames[4];
var localized string BtnLabels[5];
var localized string StartLabel;
var localized string HintText;
var localized string NameHint;

// ----------------------------------------------------------------------
// Setup
// ----------------------------------------------------------------------

event InitWindow()
{
	Super.InitWindow();
	SetWindowAlignments(HALIGN_Full, VALIGN_Full);
	SetSelectability(True);       // without this the screen can never hold keyboard focus
	bTickEnabled = True;
	SkillSel = 0;
	LastShown = -1;
	Zone = 0;
	HoverId = -1;
	RefreshSkills();
	SelectSkill(0);
}

// AE's widgets stay alive (they hold the state) but are never shown
function HideParts()
{
	local Window C;

	for (C = GetTopChild(); C != None; C = C.GetLowerSibling())
		if (C.IsVisible(False))
			C.Hide();
}

event WindowReady()
{
	bReady = True;
}

event ParentRequestedPreferredSize(bool bWidthSpecified, out float preferredWidth,
                                   bool bHeightSpecified, out float preferredHeight)
{
	preferredWidth  = root.width;
	preferredHeight = root.height;
}

function ConfigurationChanged()
{
	S  = height / 1080.0;
	OX = FMax(0, (width - 1920 * S) * 0.5);

	FrameX = OX + 60 * S;
	FrameY = 60 * S;
	FrameW = 1800 * S;
	FrameH = 960 * S;

	// Agent on the left (who you are first), skills on the right
	KX = OX + 640 * S;
	KY = 186 * S;
	KW = 1180 * S;
	KH = 600 * S;
	RowH = 40 * S;
	RowStep = 43 * S;
	ListY = KY + 58 * S;

	DX = KX;
	DY = 806 * S;
	DW = KW;
	DH = 118 * S;

	AX = OX + 100 * S;
	AY = 186 * S;
	AW = 500 * S;

	BtnY = 948 * S;
	BtnH = 48 * S;
}

// AE's ResetToDefaults rebuilds the local skills; pick them up again
function ResetToDefaults()
{
	Super.ResetToDefaults();
	RefreshSkills();
	SelectSkill(SkillSel);
}

// Alphabetical, like AE's list
function RefreshSkills()
{
	local int i, j, t;

	NumSkills = 0;
	while ((NumSkills < MAXSKILLS) && (localSkills[NumSkills] != None))
	{
		Order[NumSkills] = NumSkills;
		NumSkills++;
	}
	for (i = 1; i < NumSkills; i++)
	{
		t = Order[i];
		j = i;
		while ((j > 0) && (Caps(localSkills[Order[j - 1]].SkillName) > Caps(localSkills[t].SkillName)))
		{
			Order[j] = Order[j - 1];
			j--;
		}
		Order[j] = t;
	}
	if (SkillSel >= NumSkills)
		SkillSel = NumSkills - 1;
	if (SkillSel < 0)
		SkillSel = 0;
}

function Skill SkillAt(int k)
{
	if ((k < 0) || (k >= NumSkills))
		return None;
	return localSkills[Order[k]];
}

// Point AE's selection (and its list row) at skill k so Upgrade / Downgrade act on it
function SelectSkill(int k)
{
	local int i, r;

	if (NumSkills == 0)
		return;
	SkillSel = Clamp(k, 0, NumSkills - 1);
	selectedSkill = SkillAt(SkillSel);
	selectedRowId = -1;
	if (lstSkills != None)
		for (i = 0; i < lstSkills.GetNumRows(); i++)
		{
			r = lstSkills.IndexToRowId(i);
			if (lstSkills.GetRowClientObject(r) == selectedSkill)
				selectedRowId = r;
		}
	if ((winSkillInfo != None) && (selectedSkill != None))
		winSkillInfo.SetSkill(selectedSkill);
	EnableButtons();
	if (SkillSel != LastShown)
	{
		LastShown = SkillSel;
		DescAge = 0;
	}
}

function ChangeSkill(int k, int Dir)
{
	local int Before;

	SelectSkill(k);
	if (selectedSkill == None)
		return;
	Before = player.SkillPointsAvail;
	if (Dir > 0)
	{
		if (!selectedSkill.CanAffordToUpgrade(player.SkillPointsAvail))
		{
			PointsFlash = 1.0;
			PlaySound(Sound'Menu_Cancel', 0.25);
			return;
		}
		UpgradeSkill();
		player.PlaySound(Class'RIBase'.static.SkillUpSound(), SLOT_None, 0.85,, 0.8);
	}
	else if (selectedSkill.GetCurrentLevel() > 0)
	{
		DowngradeSkill();
		PlaySound(Sound'Menu_Press', 0.25);
	}
	if (player.SkillPointsAvail != Before)
		PointsFlash = 0.0;
}

// LDDP's female JC (in GMDX AE): portraits alternate male / female, and only
// the male half is used when it isn't loaded. The original has 5 portraits.
function bool FemaleOn()
{
	return Class'RIUtil'.static.PBool(Self, "bFemaleEnabled");
}

function int PortraitCount()
{
	if (!Class'RIUtil'.static.PHas(Self, "bFemaleEnabled"))
		return arrayCount(texPortraits);
	return arrayCount(texPortraits) / (1 + int(!FemaleOn()));
}

function bool IsFemalePortrait()
{
	return FemaleOn() && ((portraitIndex % 2) == 1);
}

// ----------------------------------------------------------------------
// Actions
// ----------------------------------------------------------------------

function bool ButtonLive(int b)
{
	if (b == BTN_HELP)
		return FemaleOn();
	if (b == BTN_START)
		return (editName != None) && (TrimSpaces(editName.GetText()) != "");
	return True;
}

function PressButton(int b)
{
	if (!ButtonLive(b))
		return;
	PlaySound(Sound'Menu_Press', 0.25);
	if (b == BTN_BACK)
		CancelScreen();
	else if (b == BTN_RESET)
		ResetToDefaults();
	else if ((b == BTN_MODS) && Class'RIBase'.static.Has("MODIFIERS"))
		ProcessAction("MODIFIERS");
	else if (b == BTN_HELP)
		ProcessAction("HELP");
	else if (b == BTN_START)
		ProcessAction("START");
}

function TypeChar(string C)
{
	local string T;

	if ((editName == None) || (InStr(filterString, C) < 0))
		return;
	T = editName.GetText();
	if (Len(T) >= 24)
		return;
	if ((T == "") && (C == " "))
		return;
	editName.SetText(T $ C);
	EnableButtons();
}

function Backspace(bool bWord)
{
	local string T;

	if (editName == None)
		return;
	T = editName.GetText();
	if (T == "")
		return;
	if (bWord)
	{
		while ((T != "") && (Right(T, 1) == " "))
			T = Left(T, Len(T) - 1);
		while ((T != "") && (Right(T, 1) != " "))
			T = Left(T, Len(T) - 1);
	}
	else
		T = Left(T, Len(T) - 1);
	editName.SetText(T);
	EnableButtons();
}

function ToggleOption(int Id)
{
	if (Id == HOT_MORPHEUS)
		Class'RIBase'.static.NewGameFlip(Self, 0);
	else if (Id == HOT_MALEINT)
		Class'RIBase'.static.NewGameFlip(Self, 1);
	PlaySound(Sound'Menu_Press', 0.25);
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
		PressButton(BTN_BACK);
		return True;
	}
	if (key == IK_Enter)
	{
		if (!bRepeat)
			PressButton(BTN_START);
		return True;
	}
	if (key == IK_Backspace)
	{
		Backspace(IsKeyDown(IK_Ctrl));
		return True;
	}
	if (IsKeyDown(IK_Ctrl))
		return False;

	if (key == IK_Tab)
	{
		Zone = 1 - Zone;
		PlaySound(Sound'Menu_Focus', 0.2);
		return True;
	}
	if ((key == IK_Up) || (key == IK_MouseWheelUp))
	{
		if (SkillSel > 0)
		{
			SelectSkill(SkillSel - 1);
			PlaySound(Sound'Menu_Focus', 0.2);
		}
		Zone = 0;
		return True;
	}
	if ((key == IK_Down) || (key == IK_MouseWheelDown))
	{
		if (SkillSel < NumSkills - 1)
		{
			SelectSkill(SkillSel + 1);
			PlaySound(Sound'Menu_Focus', 0.2);
		}
		Zone = 0;
		return True;
	}
	if ((key == IK_Left) || (key == IK_Right) || (key == IK_GreyPlus) || (key == IK_GreyMinus)
		|| (key == IK_Equals) || (key == IK_Minus))
	{
		if ((Zone == 1) && ((key == IK_Left) || (key == IK_Right)))
		{
			if (key == IK_Left)
				PreviousPortrait();
			else
				NextPortrait();
			PlaySound(Sound'Menu_Focus', 0.2);
		}
		else if ((key == IK_Right) || (key == IK_GreyPlus) || (key == IK_Equals))
			ChangeSkill(SkillSel, 1);
		else
			ChangeSkill(SkillSel, -1);
		return True;
	}
	if ((key == IK_PageUp) || (key == IK_Home))
	{
		SelectSkill(0);
		return True;
	}
	if ((key == IK_PageDown) || (key == IK_End))
	{
		SelectSkill(NumSkills - 1);
		return True;
	}
	return False;
}

// Printable characters go to the name: there is only one text field
event bool KeyPressed(string key)
{
	if (IsKeyDown(IK_Ctrl) || IsKeyDown(IK_Alt))
		return False;
	if ((key == "") || (key == "-") || (key == "=") || (key == "+"))
		return (key != "");
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

	MouseX = newX;
	MouseY = newY;
	Id = HotAt(newX, newY);
	if ((Id != HoverId) && (Id != -1))
		PlaySound(Sound'Menu_Focus', 0.15);
	HoverId = Id;
}

event bool MouseButtonPressed(float pointX, float pointY, EInputKey button, int numClicks)
{
	local int Id;

	if (button != IK_LeftMouse)
		return True;
	Id = HotAt(pointX, pointY);
	if (Id < 0)
		return True;

	if ((Id == HOT_UP) || (Id == HOT_DOWN))
	{
		Zone = 0;
		if (Id == HOT_UP)
			ChangeSkill(SkillSel, 1);
		else
			ChangeSkill(SkillSel, -1);
	}
	else if (Id >= HOT_PLUS)
	{
		Zone = 0;
		ChangeSkill(Id - HOT_PLUS, 1);
	}
	else if (Id >= HOT_MINUS)
	{
		Zone = 0;
		ChangeSkill(Id - HOT_MINUS, -1);
	}
	else if (Id >= HOT_ROW)
	{
		Zone = 0;
		if ((numClicks >= 2) && (Id - HOT_ROW == SkillSel))
			ChangeSkill(SkillSel, 1);
		else
		{
			SelectSkill(Id - HOT_ROW);
			PlaySound(Sound'Menu_Press', 0.2);
		}
	}
	else if (Id >= HOT_BTN)
		PressButton(Id - HOT_BTN);
	else if ((Id == HOT_MORPHEUS) || (Id == HOT_MALEINT))
		ToggleOption(Id);
	else if ((Id == HOT_PREV) || (Id == HOT_NEXT) || (Id == HOT_PORTRAIT))
	{
		Zone = 1;
		if (Id == HOT_PREV)
			PreviousPortrait();
		else
			NextPortrait();
		PlaySound(Sound'Menu_Press', 0.2);
	}
	return True;
}

event bool MouseButtonReleased(float pointX, float pointY, EInputKey button, int numClicks)
{
	return True;
}

// The blank-name message box returns focus to AE's edit window; take it back
event bool BoxOptionSelected(Window msgBoxWindow, int buttonNumber)
{
	root.PopWindow();
	return True;
}

function KeepFocus()
{
	if (!bReady || (root.GetTopWindow() != Self))
		return;
	if (GetRootWindow().GetFocusWindow() != Self)
		SetFocusWindow(Self);
}

event Tick(float deltaSeconds)
{
	local float TargetY;

	AnimTime += deltaSeconds;
	DescAge += deltaSeconds;
	PointsFlash = FMax(0, PointsFlash - deltaSeconds * 1.6);

	HideParts();
	KeepFocus();

	if (NumSkills == 0)
	{
		RefreshSkills();
		SelectSkill(0);
	}

	TargetY = ListY + SkillSel * RowStep;
	if (SelY == 0)
		SelY = TargetY;
	SelY += (TargetY - SelY) * FMin(1.0, deltaSeconds * 16.0);
}

// ----------------------------------------------------------------------
// Drawing helpers
// ----------------------------------------------------------------------

function AddHot(int Id, float X, float Y, float W, float H)
{
	if (NumHot >= MAXHOT)
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
	Class'RISkin'.static.FillC(gc, X, Y, W, H, C);
}

// ----------------------------------------------------------------------
// Drawing (layout follows the NewGame artboard of the design canvas)
// ----------------------------------------------------------------------

event DrawWindow(GC gc)
{
	local float a;

	NumHot = 0;
	a = Class'RIUtil'.static.Phase(AnimTime, 0.0, 0.35);
	gc.EnableSmoothing(True);

	Class'RISkin'.static.DrawDim(gc, 0, 0, width, height, 0.55 * a);
	Class'RISkin'.static.MockFrame(gc, FrameX, FrameY, FrameW, FrameH, S, a);
	Class'RISkin'.static.MockTitle(gc, OX + 100 * S, 96 * S, HeaderText, 0, S, a);
	DrawPoints(gc, a);

	DrawSkills(gc, a * Class'RIUtil'.static.Phase(AnimTime, 0.05, 0.35));
	DrawDetail(gc, a * Class'RIUtil'.static.Phase(AnimTime, 0.10, 0.35));
	DrawAgent(gc, a * Class'RIUtil'.static.Phase(AnimTime, 0.10, 0.35));
	DrawBottom(gc, a * Class'RIUtil'.static.Phase(AnimTime, 0.15, 0.35));
}

function DrawSkills(GC gc, float a)
{
	local int k, lv, pip;
	local float y, ra, nx, lx, cx2, pw;
	local Skill Sk;
	local bool bSel, bHot, bCanUp;
	local string Cost;
	local Color NC;

	Class'RISkin'.static.MockPanel(gc, KX, KY, KW, KH, S, a);

	// Header row
	nx = KX + 32 * S;
	lx = KX + 14 * S + (KW - 28 * S) * 0.52;
	cx2 = KX + KW - 32 * S;
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', nx, KY + 18 * S, Caps(SkillsLabel), C3(139, 144, 212, a), 0.72);
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', lx, KY + 18 * S, Caps(LevelLabel), C3(139, 144, 212, a), 0.72);
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', cx2 - 300 * S, KY + 18 * S, 300 * S, 20 * S, Caps(CostLabel), C3(139, 144, 212, a), 2, 0.72);
	Class'RIText'.static.HLine(gc, KX + 14 * S, KY + 48 * S, KW - 28 * S, C3(46, 50, 144, a));

	if (NumSkills > 0)
		Class'RISkin'.static.MockSelRow(gc, KX + 14 * S, SelY, KW - 28 * S, RowH, S, a * (1.0 - 0.4 * Zone));

	pw = 30 * S;
	for (k = 0; k < NumSkills; k++)
	{
		Sk = SkillAt(k);
		if (Sk == None)
			continue;
		ra = a * Class'RIUtil'.static.Phase(AnimTime, 0.12 + k * 0.025, 0.3);
		y = ListY + k * RowStep;
		bSel = (k == SkillSel);
		bHot = (HoverId == HOT_ROW + k);
		lv = Sk.GetCurrentLevel();
		bCanUp = (lv < 3) && Sk.CanAffordToUpgrade(player.SkillPointsAvail);

		if (bHot && !bSel)
			Class'RISkin'.static.GlowC(gc, KX + 14 * S, y, KW - 28 * S, RowH, 0, C3(18, 19, 60, ra));
		if (!bSel)
			Class'RIText'.static.HLine(gc, KX + 14 * S, y + RowH, KW - 28 * S, C3(30, 34, 102, ra));

		if (bSel)
			NC = C3(255, 255, 255, ra);
		else
			NC = C3(218, 220, 255, ra);
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', nx + (1.0 - ra) * 12 * S, y, lx - nx - 20 * S, RowH,
			Caps(Class'RIText'.static.Fit(Class'RIFontHead', Sk.SkillName, lx - nx - 20 * S, 0.6)), NC, 0, 0.6);

		// Level: three pips, then the name
		for (pip = 0; pip < 3; pip++)
		{
			if (pip < lv)
			{
				Class'RISkin'.static.GlowC(gc, lx + pip * (pw + 6 * S), y + RowH * 0.5 - 5 * S, pw, 10 * S, 3 * S, C3(30, 80, 110, ra));
				Fill(gc, lx + pip * (pw + 6 * S), y + RowH * 0.5 - 5 * S, pw, 10 * S, C3(95, 200, 255, ra));
			}
			else
				Class'RIText'.static.Box(gc, lx + pip * (pw + 6 * S), y + RowH * 0.5 - 5 * S, pw, 10 * S, C3(90, 94, 230, ra));
		}
		if (lv == 0)
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', lx + 3 * (pw + 6 * S) + 8 * S, y, 160 * S, RowH, Caps(LevelNames[0]), C3(139, 144, 212, ra), 0, 0.7);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', lx + 3 * (pw + 6 * S) + 8 * S, y, 160 * S, RowH, Caps(LevelNames[Clamp(lv, 0, 3)]), C3(255, 255, 255, ra), 0, 0.7);

		if (lv >= 3)
			Cost = "-";
		else
			Cost = string(Sk.GetCost());
		if ((lv < 3) && !bCanUp)
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', cx2 - 200 * S, y, 200 * S, RowH, Cost, C3(255, 107, 142, ra), 2, 0.6);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', cx2 - 200 * S, y, 200 * S, RowH, Cost, C3(95, 200, 255, ra), 2, 0.6);

		AddHot(HOT_ROW + k, KX + 14 * S, y, KW - 28 * S, RowH);
	}
}

function DrawDetail(GC gc, float a)
{
	local float da, x, y, isz, st;
	local Skill Sk;
	local string D, Para;
	local int p;

	Class'RISkin'.static.FillC(gc, DX, DY, DW, DH, C3(10, 12, 48, 0.55 * a));
	Class'RISkin'.static.Box2(gc, DX, DY, DW, DH, C3(46, 50, 144, a));

	Sk = SkillAt(SkillSel);
	if (Sk == None)
		return;
	da = a * Class'RIUtil'.static.Phase(DescAge, 0.0, 0.22);

	isz = 56 * S;
	x = DX + 22 * S;
	if (Sk.SkillIcon != None)
	{
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(C3(95, 200, 255, da));
		Class'RIHD'.static.DrawStretched(gc, x, DY + (DH - isz) * 0.5, isz, isz, 0, 0, Sk.SkillIcon.USize, Sk.SkillIcon.VSize, Sk.SkillIcon);
	}
	x += isz + 22 * S;

	Class'RIText'.static.Draw(gc, Class'RIFontHead', x + (1.0 - da) * 8 * S, DY + 16 * S, Caps(Sk.SkillName), C3(230, 232, 255, da), 0.62);

	// The skill's general description (its first paragraph)
	D = Class'RIBase'.static.SkillDesc(Sk, Class'RIUtil'.static.PBool(Self, "bHardCoreMode"), combatDifficulty);
	p = InStr(D, "|n");
	if (p >= 0)
		Para = Left(D, p);
	else
		Para = D;
	st = gc.PushGC();
	gc.Intersect(x, DY + 40 * S, DX + DW - 190 * S - x, DH - 48 * S);
	Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x, DY + 44 * S, DX + DW - 190 * S - x, Para, C3(185, 189, 235, da), 0.8, 1.35);
	gc.PopGC(st);

	// lower / raise the selected skill, right of its description
	x = DX + DW - 22 * S - BtnH * 2 - 12 * S;
	y = DY + (DH - BtnH) * 0.5;
	DrawRound(gc, x, y, "-", Sk.GetCurrentLevel() > 0, HoverId == HOT_DOWN, a);
	AddHot(HOT_DOWN, x, y, BtnH, BtnH);
	x += BtnH + 12 * S;
	DrawRound(gc, x, y, "+", (Sk.GetCurrentLevel() < 3) && Sk.CanAffordToUpgrade(player.SkillPointsAvail), HoverId == HOT_UP, a);
	AddHot(HOT_UP, x, y, BtnH, BtnH);
}

function DrawField(GC gc, float X, float Y, float W, string Label, string Value, bool bEdit, int Id, float a)
{
	local float h, tw, blink;
	local bool bHot;
	local string V;

	h = 48 * S;
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', X, Y, Caps(Label), C3(139, 144, 212, a), 0.7);
	Y += 24 * S;
	bHot = (HoverId == Id);

	Fill(gc, X, Y, W, h, C3(10, 12, 48, 0.8 * a));
	if (bEdit)
		Class'RISkin'.static.Box2(gc, X, Y, W, h, C3(90 + 76 * int(bHot), 94 + 76 * int(bHot), 230 + 25 * int(bHot), a));
	else
		Class'RISkin'.static.Box2(gc, X, Y, W, h, C3(59, 63, 196, a));

	V = Value;
	if (bEdit && (V == ""))
	{
		Class'RIText'.static.DrawIn(gc, Class'RIFontBody', X + 16 * S, Y, W - 32 * S, h, NameHint, C3(90, 94, 150, a), 0, 0.8);
		tw = 0;
	}
	else
	{
		V = Class'RIText'.static.Fit(Class'RIFontBody', V, W - 40 * S, 0.8);
		if (bEdit)
			Class'RIText'.static.DrawIn(gc, Class'RIFontBody', X + 16 * S, Y, W - 32 * S, h, V, C3(230, 232, 255, a), 0, 0.8);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontBody', X + 16 * S, Y, W - 32 * S, h, V, C3(170, 174, 220, a), 0, 0.8);
		tw = Class'RIText'.static.Width(Class'RIFontBody', V, 0.8);
	}
	if (bEdit)
	{
		blink = 0.5 + 0.5 * Sin(AnimTime * 6.0);
		Fill(gc, X + 16 * S + tw + 2 * S, Y + 12 * S, 1.5, h - 24 * S, C3(150 * blink, 228 * blink, 255 * blink, a));
		AddHot(Id, X, Y, W, h);
	}
}

function DrawToggle(GC gc, float X, float Y, float W, string Label, bool bOn, int Id, float a)
{
	local float h, kx2;
	local bool bHot;

	h = 34 * S;
	bHot = (HoverId == Id);
	kx2 = X + W - 44 * S;
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, Y, W - 60 * S, h,
		Caps(Class'RIText'.static.Fit(Class'RIFontSmall', Label, W - 64 * S, 0.7)), C3(170 + 60 * int(bHot), 174 + 60 * int(bHot), 230, a), 0, 0.7);
	Class'RISkin'.static.Box2(gc, kx2, Y + 8 * S, 40 * S, 18 * S, C3(90, 94, 230, a));
	if (bOn)
	{
		Fill(gc, kx2, Y + 8 * S, 40 * S, 18 * S, C3(40, 44, 140, a));
		Fill(gc, kx2 + 24 * S, Y + 11 * S, 13 * S, 12 * S, C3(95, 200, 255, a));
	}
	else
		Fill(gc, kx2 + 3 * S, Y + 11 * S, 13 * S, 12 * S, C3(110, 114, 170, a));
	AddHot(Id, X, Y, W, h);
}

function string DifficultyName()
{
	if (Class'RIUtil'.static.PBool(Self, "bHardCoreMode"))
		return "Hardcore";
	if (combatDifficulty <= 0.75)
		return "Easy";
	if (combatDifficulty <= 1.75)
		return "Medium";
	if (combatDifficulty <= 2.5)
		return "Hard";
	return "Realistic";
}

function DrawAgent(GC gc, float a)
{
	local float y, ph, pw, bx, tw;
	local string L, Code;
	local Texture T;
	local bool bZone;

	bZone = (Zone == 1);

	// Portrait box with the appearance arrows in its bottom corners
	ph = 430 * S;
	if (FemaleOn())
		ph -= 84 * S;
	y = AY;
	Class'RISkin'.static.FillC(gc, AX, y, AW, ph, C3(14, 16, 56, 0.6 * a));
	T = texPortraits[portraitIndex];
	if (T != None)
	{
		// Smaller card, centred, sampled 3 texels inside the texture's edge:
		// its border is magenta padding, and smoothing (more so on the 4x HD
		// copy) bled it in as purple specks on the edge
		pw = (ph * 0.72) * 108.0 / 154.0;
		gc.SetStyle(DSTY_Normal);
		gc.SetTileColor(Class'RIUtil'.static.Col(255, 255, 255));
		Class'RIHD'.static.DrawStretched(gc, AX + (AW - pw) * 0.5, y + ph * 0.13, pw, ph * 0.72, 3, 3, 108, 154, T);
		Class'RIText'.static.Box(gc, AX + (AW - pw) * 0.5, y + ph * 0.13, pw, ph * 0.72, C3(59, 63, 196, a));
		if (a < 0.99)
			Class'RISkin'.static.DrawDim(gc, AX + (AW - pw) * 0.5, y + ph * 0.13, pw, ph * 0.72, 1.0 - a);
	}
	if (bZone || (HoverId == HOT_PORTRAIT))
		Class'RISkin'.static.Box2(gc, AX, y, AW, ph, C3(166, 170, 255, a));
	else
		Class'RISkin'.static.Box2(gc, AX, y, AW, ph, C3(59, 63, 196, a));
	AddHot(HOT_PORTRAIT, AX, y, AW, ph);

	// Appearance count, top left; arrows, bottom corners
	if (FemaleOn())
	{
		if (IsFemalePortrait())
			L = FemaleLabel;
		else
			L = MaleLabel;
		L = Caps(AppearanceLabel) @ string(portraitIndex / 2 + 1) @ "OF" @ string(PortraitCount() / 2) $ "  /  " $ Caps(L);
	}
	else
		L = Caps(AppearanceLabel) @ string(portraitIndex + 1) @ "OF" @ string(PortraitCount());
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', AX + 18 * S, y + 16 * S, L, C3(166, 170, 255, a), 0.7);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', AX + 8 * S, y + ph - 56 * S, 48 * S, 48 * S, "<",
		C3(166 + 89 * int(HoverId == HOT_PREV), 170 + 85 * int(HoverId == HOT_PREV), 255, a), 1, 0.9);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', AX + AW - 56 * S, y + ph - 56 * S, 48 * S, 48 * S, ">",
		C3(166 + 89 * int(HoverId == HOT_NEXT), 170 + 85 * int(HoverId == HOT_NEXT), 255, a), 1, 0.9);
	AddHot(HOT_PREV, AX, y + ph - 64 * S, 72 * S, 64 * S);
	AddHot(HOT_NEXT, AX + AW - 72 * S, y + ph - 64 * S, 72 * S, 64 * S);
	y += ph + 16 * S;

	// Name fields
	Code = "";
	if (editCodeName != None)
		Code = editCodeName.GetText();
	DrawField(gc, AX, y, AW, CodeNameLabel, Code, False, -1, a);
	y += 24 * S + 48 * S + 14 * S;
	if (editName != None)
		DrawField(gc, AX, y, AW, RealNameLabel, editName.GetText(), True, HOT_NAME, a);
	y += 24 * S + 48 * S + 14 * S;

	// LDDP options
	if (FemaleOn() && (Class'RIBase'.static.NewGameOption(Self, 0, L) >= 0))
	{
		DrawToggle(gc, AX, y, AW, L, Class'RIBase'.static.NewGameOption(Self, 0, L) == 1, HOT_MORPHEUS, a);
		y += 38 * S;
		if (IsFemalePortrait() && (Class'RIBase'.static.NewGameOption(Self, 1, L) >= 0))
			DrawToggle(gc, AX, y, AW, L, Class'RIBase'.static.NewGameOption(Self, 1, L) == 1, HOT_MALEINT, a);
		y += 42 * S;
	}

	// Difficulty, and the modifiers / LDDP buttons
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', AX, y, "DIFFICULTY", C3(139, 144, 212, a), 0.7);
	tw = Class'RIText'.static.Width(Class'RIFontSmall', "DIFFICULTY  ", 0.7);
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', AX + tw, y, Caps(DifficultyName()), C3(230, 232, 255, a), 0.7);

	bx = AX + AW;
	if (FemaleOn())
	{
		bx -= 170 * S;
		Class'RISkin'.static.MockButton(gc, bx, y - 10 * S, 170 * S, 36 * S, BtnLabels[BTN_HELP], S, a, HoverId == HOT_BTN + BTN_HELP, True);
		AddHot(HOT_BTN + BTN_HELP, bx, y - 10 * S, 170 * S, 36 * S);
		bx -= 12 * S;
	}
	// gameplay modifiers are GMDX AE's; vanilla has none
	if (Class'RIBase'.static.Has("MODIFIERS"))
	{
		bx -= 190 * S;
		Class'RISkin'.static.MockButton(gc, bx, y - 10 * S, 190 * S, 36 * S, BtnLabels[BTN_MODS], S, a, HoverId == HOT_BTN + BTN_MODS, True);
		AddHot(HOT_BTN + BTN_MODS, bx, y - 10 * S, 190 * S, 36 * S);
	}
}

// Skill points, over the skills panel at the title's height (flashes red
// when an upgrade can't be afforded)
function DrawPoints(GC gc, float a)
{
	local float x, w, tw, y, h;
	local string P;
	local Color PC;

	y = 96 * S;
	h = 58 * S;
	P = string(player.SkillPointsAvail);
	w = FMax(140 * S, Class'RIText'.static.Width(Class'RIFontTitle', P, 0.55) + 36 * S);
	x = KX + KW - w;
	PC = Class'RIUtil'.static.Mix(C3(143, 147, 255, a), C3(255, 107, 142, a), PointsFlash);
	Class'RISkin'.static.GlowC(gc, x, y, w, h, 6 * S, C3(30, 32, 100, a));
	Class'RISkin'.static.Box2(gc, x, y, w, h, PC);
	Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', x + Sin(PointsFlash * 30) * PointsFlash * 6 * S, y, w, h, P,
		Class'RIUtil'.static.Mix(C3(255, 255, 255, a), C3(255, 107, 142, a), PointsFlash), 1, 0.55);
	tw = Class'RIText'.static.Width(Class'RIFontHead', Caps(PointsLabel), 0.62);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x - tw - 20 * S, y, tw, h, Caps(PointsLabel), C3(201, 204, 245, a), 0, 0.62);
}

function DrawBottom(GC gc, float a)
{
	local float x, w;

	// Reset, under the skills it resets
	x = KX;
	w = 260 * S;
	Class'RISkin'.static.MockButton(gc, x, BtnY, w, BtnH, BtnLabels[BTN_RESET], S, a, HoverId == HOT_BTN + BTN_RESET, True);
	AddHot(HOT_BTN + BTN_RESET, x, BtnY, w, BtnH);

	// Key hints, bottom right: ENTER START, ESC BACK
	x = OX + 1820 * S - Class'RISkin'.static.MockKeyHintWidth(BtnLabels[BTN_BACK], S);
	Class'RISkin'.static.MockKeyHint(gc, x, BtnY + 3 * S, "ESC", BtnLabels[BTN_BACK], S, a, HoverId == HOT_BTN + BTN_BACK);
	AddHot(HOT_BTN + BTN_BACK, x, BtnY, Class'RISkin'.static.MockKeyHintWidth(BtnLabels[BTN_BACK], S), BtnH);
	x -= 34 * S + Class'RISkin'.static.MockKeyHintWidth(StartLabel, S);
	if (ButtonLive(BTN_START))
		Class'RISkin'.static.MockKeyHint(gc, x, BtnY + 3 * S, "ENTER", StartLabel, S, a, HoverId == HOT_BTN + BTN_START);
	else
		Class'RISkin'.static.MockKeyHint(gc, x, BtnY + 3 * S, "ENTER", StartLabel, S, a * 0.45, False);
	AddHot(HOT_BTN + BTN_START, x, BtnY, Class'RISkin'.static.MockKeyHintWidth(StartLabel, S), BtnH);
}

function DrawRound(GC gc, float X, float Y, string L, bool bLive, bool bHot, float a)
{
	local Color E;
	local float t, gl, cx, cy;

	if (!bLive)
		E = C3(46, 50, 144, a);
	else if (bHot)
		E = C3(255, 255, 255, a);
	else
		E = C3(166, 170, 255, a);
	if (bLive)
		Class'RISkin'.static.GlowC(gc, X, Y, BtnH, BtnH, 6 * S, C3(30, 32, 100, a));
	Class'RISkin'.static.Box2(gc, X, Y, BtnH, BtnH, E);
	// the glyph drawn as bars, dead centre (the font's + and - sat off it)
	t = Class'RIModern'.static.P(FMax(1.0, BtnH * 0.07));
	gl = Class'RIModern'.static.P(BtnH * 0.38);
	cx = Class'RIModern'.static.P(X + (BtnH - gl) * 0.5);
	cy = Class'RIModern'.static.P(Y + (BtnH - t) * 0.5);
	Fill(gc, cx, cy, gl, t, E);
	if (L == "+")
		Fill(gc, Class'RIModern'.static.P(X + (BtnH - t) * 0.5), Class'RIModern'.static.P(Y + (BtnH - gl) * 0.5), t, gl, E);
}

defaultproperties
{
     HeaderText="NEW GAME"
     PointsLabel="Skill points"
     CodeNameLabel="Code name"
     RealNameLabel="Real name"
     AppearanceLabel="Appearance"
     SkillsLabel="Skill"
     LevelLabel="Skill level"
     CostLabel="Points needed"
     MaleLabel="Male"
     FemaleLabel="Female"
     LevelNames(0)="Untrained"
     LevelNames(1)="Trained"
     LevelNames(2)="Advanced"
     LevelNames(3)="Master"
     BtnLabels(0)="Back"
     BtnLabels(1)="Reset"
     BtnLabels(2)="Modifiers"
     BtnLabels(3)="LDDP Help"
     BtnLabels(4)="Start Game"
     StartLabel="Start"
     NameHint="Type a name"
}
