//=============================================================================
// RIPersonaView
// Base for the in-game (persona) screens: Inventory, Health, Augs, Skills,
// Goals / Notes and so on. Sits over AE's PersonaScreen*, which stays in
// charge of the game logic; this draws the shared frame and the tab bar in
// the original game's amber, and subclasses draw the page itself.
//
// Tabs switch screens through AE's own (hidden) nav bar, so saving and the
// pause rules are AE's. Escape / Exit close like AE's Escape does.
//=============================================================================
class RIPersonaView extends Window;

const MAXHOT  = 96;
const MAXTABS = 10;

// Tab ids (also hot-region ids 1..MAXTABS)
const TAB_INV    = 1;
const TAB_HEALTH = 2;
const TAB_AUGS   = 3;
const TAB_SKILLS = 4;
const TAB_GOALS  = 5;
const TAB_OUTFIT = 6;
const TAB_CONS   = 7;
const TAB_IMAGES = 8;
const TAB_LOGS   = 9;
const TAB_EXIT   = 10;
const TAB_AMMO   = 12;      // Inventory sections drawn by RIInventoryView
const TAB_KEYS   = 13;
const TAB_PERKS  = 14;      // Skills section: general perks (RISkillsView)
const HOT_SUB    = 20;      // + tab id: the section row under the main tabs

var PersonaScreenBaseWindow Screen;
var DeusExPlayer Player;
var int   ActiveTab;
var float Age;
var float S, OX;
var localized string PersonaTitle;   // Modern: the big frame's tab
var bool  bReady;
var bool  bLoggedStyle;
var float HoleX, HoleY, HoleW, HoleH;   // Vanilla+: a part of the screen left unpainted (Outfit's 3D preview)
var bool  bHideScreen;
var float ScaleAge;
var int   SubShown;          // section the fade below belongs to
var float SubShownAt;        // when it was chosen (Age)          // since the scale last changed (shows the percentage)
var bool  bClassic;           // default.bClassic: show AE's own pages (with the new tab row)        // subclasses that draw everything hide AE's widgets

// Tab bar from the last frame
var int   NumTabs;
var int   TabId[16];
var string TabLabel[16];

// Section row (Inventory: items / outfit / ammo / keys; Journal: goals,
// conversations, images, logs)
var int   NumSubs;
var int   SubId[8];

var int   JournalLast;        // default.JournalLast: the Journal reopens where it was left
var int   PendingInvMode;     // default.PendingInvMode: section for the next Inventory page

// Hit regions from the last frame
var float HotX[96], HotY[96], HotW[96], HotH[96];
var int   HotId[96];
var int   NumHot;
var int   HoverId;
var float LastMouseX, LastMouseY;   // cursor, from MouseMoved

// Content frame (design pixels * S)
var float FX, FY, FW, FH;

var localized string TabNames[16];
var localized string CloseHint;
var localized string DetailLabel;
var localized string SubNames[16];

// ----------------------------------------------------------------------
// Setup
// ----------------------------------------------------------------------

event InitWindow()
{
	Super.InitWindow();
	SetSelectability(True);
	bTickEnabled = True;
	HoverId = -1;
}

function AttachTo(PersonaScreenBaseWindow NewScreen)
{
	Screen = NewScreen;
	Player = DeusExPlayer(Screen.GetPlayerPawn());
	ScaleAge = 99;
	Place();
	if (bHideScreen)
		HideScreenParts();
	ScreenAttached();
}

// Vanilla+ board size (Settings: Ctrl - / Ctrl = in the screens): the view
// is a centred window that much smaller; everything inside scales with it
function float Scale()
{
	local float k;

	k = Class'RIRootWindow'.default.PersonaScale;
	if ((k < 0.7) || (k > 1.0))
		k = 1.0;
	// Modern: a touch smaller than the screen, so the frame has breathing room
	if (Class'RIModern'.static.On())
		return k * 0.9;
	if (!VPlus())
		return 1.0;
	return k;
}

function Place()
{
	local float k, w, h;

	k = Scale();
	w = Screen.width * k;
	h = Screen.height * k;
	SetConfiguration((Screen.width - w) * 0.5, (Screen.height - h) * 0.5, w, h);
}

function StepScale(int Dir)
{
	local float k;

	k = Class'RIRootWindow'.default.PersonaScale;
	if ((k < 0.7) || (k > 1.0))
		k = 1.0;
	k = FClamp(k + Dir * 0.05, 0.75, 1.0);
	Class'RIRootWindow'.default.PersonaScale = k;
	Class'RIRootWindow'.static.StaticSaveConfig();
	ScaleAge = 0;
	PlaySound(Sound'Menu_Press', 0.25);
	Place();
}

// Subclass hook: read whatever the page needs from AE's screen
function ScreenAttached()
{
}

event WindowReady()
{
	Super.WindowReady();
	bReady = True;      // focus is taken in Tick, outside the engine's ready pass
}

function HideScreenParts()
{
	local Window C;

	for (C = Screen.GetTopChild(); C != None; C = C.GetLowerSibling())
		if ((C != Self) && C.IsVisible(False))
			C.Hide();
}

// ----------------------------------------------------------------------
// Palette: the original game's gold (sampled from AE's own screens:
// text 230,195,117 / edges 126,105,50 / panels 61,50,23)
// ----------------------------------------------------------------------

function Color C3(float R, float G, float B, float a)
{
	return Class'RIUtil'.static.Col(R * a, G * a, B * a);
}

function Color AEdge(float a)    { return C3(150, 126, 62, a); }   // panel edges
function Color ADim(float a)     { return C3(79, 65, 31, a); }     // quiet edges, rules
function Color AHi(float a)      { return C3(255, 232, 150, a); }  // highlight
function Color ATxt(float a)     { return C3(240, 222, 178, a); }  // body text
function Color ALbl(float a)     { return C3(170, 145, 90, a); }   // labels
function Color AAcc(float a)     { return C3(230, 195, 117, a); }  // accent / values
function Color AGood(float a)    { return C3(120, 230, 150, a); }  // owned
function Color ABad(float a)     { return C3(255, 96, 80, a); }    // can't afford

function Fill(GC gc, float X, float Y, float W, float H, Color C)
{
	Class'RISkin'.static.FillC(gc, X, Y, W, H, C);
}

function Glow(GC gc, float X, float Y, float W, float H, Color C)
{
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C);
	Class'RIText'.static.Tex(gc, X, Y, W, H, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');
}

// Centred glow: bright in the middle, fading out on every side
function CGlow(GC gc, float X, float Y, float W, float H, Color C)
{
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C);
	// inset UVs: smoothing at the texture's edge would leave a faint box
	Class'RIText'.static.Tex(gc, X, Y, W, H, 3, 3, 250, 58, Texture'ReimaginedUI.UI.RI_GlowC');
}

// The selected tab's light: a low soft bloom rising off its underline,
// centred on the label and kept inside the tab row (no blob, no box)
function BarGlow(GC gc, float CX, float LY, float TW, float H, Color C, optional bool bNoSpill)
{
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C);
	// upper half of the radial glow, its bright edge sitting on the bar
	Class'RIText'.static.Tex(gc, CX - TW * 0.5 - 30 * S, LY - H, TW + 60 * S, H, 3, 3, 250, 29, Texture'ReimaginedUI.UI.RI_GlowC');
	// a short spill under the bar
	if (!bNoSpill)
		Class'RIText'.static.Tex(gc, CX - TW * 0.5 - 16 * S, LY, TW + 32 * S, H * 0.3, 3, 32, 250, 29, Texture'ReimaginedUI.UI.RI_GlowC');
}

// Vanilla+ (Settings > Interface > Style): the original persona textures,
// 4x HD when available, tinted in the game's gold
function bool VPlus()
{
	return Class'RIRootWindow'.default.ScreenStyle == 1;
}

// Nine-slice from original textures; K scales the original texels
function Slice(GC gc, float X, float Y, float W, float H, float K, Texture TL, Texture T, Texture TR, Texture L, Texture C, Texture R, Texture BL, Texture B, Texture BR)
{
	local float lw, rw, th, bh;

	lw = TL.USize * K;
	rw = TR.USize * K;
	th = TL.VSize * K;
	bh = BL.VSize * K;
	if (lw + rw > W)
	{
		lw = W * 0.5;
		rw = W * 0.5;
	}
	if (th + bh > H)
	{
		th = H * 0.5;
		bh = H * 0.5;
	}
	Class'RIHD'.static.DrawExact(gc, X, Y, lw, th, 0, 0, TL.USize, TL.VSize, TL);
	Class'RIHD'.static.DrawExact(gc, X + lw, Y, W - lw - rw, th, 0, 0, T.USize, T.VSize, T);
	Class'RIHD'.static.DrawExact(gc, X + W - rw, Y, rw, th, 0, 0, TR.USize, TR.VSize, TR);
	Class'RIHD'.static.DrawExact(gc, X, Y + th, lw, H - th - bh, 0, 0, L.USize, L.VSize, L);
	Class'RIHD'.static.DrawExact(gc, X + lw, Y + th, W - lw - rw, H - th - bh, 0, 0, C.USize, C.VSize, C);
	Class'RIHD'.static.DrawExact(gc, X + W - rw, Y + th, rw, H - th - bh, 0, 0, R.USize, R.VSize, R);
	Class'RIHD'.static.DrawExact(gc, X, Y + H - bh, lw, bh, 0, 0, BL.USize, BL.VSize, BL);
	Class'RIHD'.static.DrawExact(gc, X + lw, Y + H - bh, W - lw - rw, bh, 0, 0, B.USize, B.VSize, B);
	Class'RIHD'.static.DrawExact(gc, X + W - rw, Y + H - bh, rw, bh, 0, 0, BR.USize, BR.VSize, BR);
}

function VPanel(GC gc, float X, float Y, float W, float H, float a)
{
	// The original note/panel frame (PersonaNoteNormal), HD, in the game's gold
	Fill(gc, X, Y, W, H, C3(14, 11, 5, 0.9 * a));
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C3(230, 195, 117, a));
	Slice(gc, X, Y, W, H, 4 * S,
		Texture'DeusExUI.UserInterface.PersonaNoteNormal_TL', Texture'DeusExUI.UserInterface.PersonaNoteNormal_Top', Texture'DeusExUI.UserInterface.PersonaNoteNormal_TR',
		Texture'DeusExUI.UserInterface.PersonaNoteNormal_Left', Texture'DeusExUI.UserInterface.PersonaNoteNormal_Center', Texture'DeusExUI.UserInterface.PersonaNoteNormal_Right',
		Texture'DeusExUI.UserInterface.PersonaNoteNormal_BL', Texture'DeusExUI.UserInterface.PersonaNoteNormal_Bottom', Texture'DeusExUI.UserInterface.PersonaNoteNormal_BR');
}

function VSelRow(GC gc, float X, float Y, float W, float H, float a)
{
	Fill(gc, X, Y, W, H, C3(56, 46, 20, 0.85 * a));
	Glow(gc, X, Y, W, H * 0.6, C3(30, 25, 11, a));
	Class'RIText'.static.Box(gc, X, Y, W, H, C3(242, 211, 107, a));
}

// The original action button: left cap, stretched centre, angled right end
function VBtn(GC gc, float X, float Y, float W, float H, string L, bool bLive, bool bHot, bool bPrimary, float a)
{
	local Texture TL, TC, TR;
	local float k, lw, rw, sc, tw;
	local Color Tint, TextC;

	if (bLive && (bPrimary || bHot))
	{
		TL = Texture'DeusExUI.UserInterface.PersonaActionButtonPressed_Left';
		TC = Texture'DeusExUI.UserInterface.PersonaActionButtonPressed_Center';
		TR = Texture'DeusExUI.UserInterface.PersonaActionButtonPressed_Right';
		Tint = C3(255, 225, 140, a);
		TextC = C3(255, 241, 194, a);
	}
	else
	{
		TL = Texture'DeusExUI.UserInterface.PersonaActionButtonNormal_Left';
		TC = Texture'DeusExUI.UserInterface.PersonaActionButtonNormal_Center';
		TR = Texture'DeusExUI.UserInterface.PersonaActionButtonNormal_Right';
		if (bLive)
		{
			Tint = C3(200, 170, 95, a);
			TextC = AAcc(a);
		}
		else
		{
			Tint = C3(80, 68, 34, a);
			TextC = C3(90, 76, 38, a);
		}
	}
	k = H / 16.0;
	lw = 4 * k;
	rw = 8 * k;
	Fill(gc, X, Y, W, H, C3(12, 10, 5, 0.85 * a));
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Tint);
	Class'RIHD'.static.DrawExact(gc, X, Y, lw, H, 0, 0, 4, 16, TL);
	Class'RIHD'.static.DrawExact(gc, X + lw, Y, W - lw - rw, H, 0, 0, 2, 16, TC);
	Class'RIHD'.static.DrawExact(gc, X + W - rw, Y, rw, H, 0, 0, 8, 16, TR);
	// shrink long labels to fit the button
	sc = 0.52;
	tw = Class'RIText'.static.Width(Class'RIFontHead', Caps(L), sc);
	if (tw > W - rw - 12 * S)
		sc = FMax(0.3, sc * (W - rw - 12 * S) / FMax(1, tw));
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', X, Y, W - rw * 0.5, H, Caps(L), TextC, 1, sc);
}

// Refined panel: a deep fill, lighter at the top, and one hairline edge
function Panel(GC gc, float X, float Y, float W, float H, float a)
{
	if (VPlus())
	{
		VPanel(gc, X, Y, W, H, a);
		return;
	}
	if (Class'RIModern'.static.On())
	{
		Class'RIModern'.static.Frame(gc, X, Y, W, H, S, a);
		return;
	}
	Fill(gc, X, Y, W, H, C3(16, 13, 6, 0.85 * a));
	Glow(gc, X, Y, W, H * 0.5, C3(14, 11, 5, a));
	Class'RIText'.static.Box(gc, X, Y, W, H, C3(58, 48, 22, a));
}

function SelRow(GC gc, float X, float Y, float W, float H, float a)
{
	if (VPlus())
	{
		VSelRow(gc, X, Y, W, H, a);
		return;
	}
	if (Class'RIModern'.static.On())
	{
		Class'RIModern'.static.Cell(gc, X, Y, W, H, S, True, a);
		return;
	}
	Fill(gc, X, Y, W, H, C3(46, 38, 17, 0.8 * a));
	Glow(gc, X, Y, W, H, C3(40, 33, 15, a));
	Class'RIText'.static.Box(gc, X, Y, W, H, C3(242, 211, 107, a));
}

function DrawBtn(GC gc, float X, float Y, float W, float H, string L, bool bLive, bool bHot, bool bPrimary, float a)
{
	if (VPlus())
	{
		VBtn(gc, X, Y, W, H, L, bLive, bHot, bPrimary, a);
		return;
	}
	if (Class'RIModern'.static.On())
	{
		Class'RIModern'.static.Btn(gc, X, Y, W, H, S, L, bLive, bHot, bPrimary, a);
		return;
	}
	// Refined: hairline buttons; the main action lit, disabled ones faint
	if (!bLive)
	{
		Class'RIText'.static.Box(gc, X, Y, W, H, C3(46, 38, 18, a));
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', X, Y, W, H, Caps(L), C3(90, 76, 38, a), 1, 0.52);
		return;
	}
	if (bPrimary || bHot)
	{
		Fill(gc, X, Y, W, H, C3(50, 41, 19, 0.9 * a));
		CGlow(gc, X - 12 * S, Y - 8 * S, W + 24 * S, H + 16 * S, C3(36, 30, 12, a));
		Class'RIText'.static.Box(gc, X, Y, W, H, C3(242, 211, 107, a));
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', X, Y, W, H, Caps(L), C3(255, 241, 194, a), 1, 0.52);
	}
	else
	{
		Class'RIText'.static.Box(gc, X, Y, W, H, C3(110, 94, 46, a));
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', X, Y, W, H, Caps(L), AAcc(a), 1, 0.52);
	}
}

// A callout line from a card (px, py) to a point on a figure (ax, ay): out
// level from the card, then into the point at 45 degrees (or, short of
// room, a stub, 45 degrees, then straight up or down), 1 px throughout
function LeaderLine(GC gc, float px, float py, float ax, float ay, Color Col)
{
	local float dx, dy, adx, ady, sgn, ex, stub, h, ye;

	dx = ax - px;
	dy = ay - py;
	adx = Abs(dx);
	ady = Abs(dy);
	if (dx >= 0)
		sgn = 1;
	else
		sgn = -1;
	stub = FMin(18 * S, adx);
	if (ady <= adx - stub)
	{
		ex = ax - sgn * ady;
		Class'RIText'.static.HLine(gc, FMin(px, ex), py, Abs(ex - px), Col);
		DiagSeg(gc, ex, py, ax, ay, Col);
	}
	else
	{
		ex = px + sgn * stub;
		Class'RIText'.static.HLine(gc, FMin(px, ex), py, stub, Col);
		h = adx - stub;
		if (dy > 0)
			ye = py + h;
		else
			ye = py - h;
		DiagSeg(gc, ex, py, ax, ye, Col);
		Class'RIText'.static.VLine(gc, ax, FMin(ye, ay), Abs(ay - ye), Col);
	}
}

// A 45 degree segment between two points (drawn from its left end)
function DiagSeg(GC gc, float x0, float y0, float x1, float y1, Color Col)
{
	local float L;

	L = Abs(x1 - x0);
	if (L <= 0)
		return;
	if (x1 >= x0)
	{
		if (y1 >= y0)
			Class'RIModern'.static.Diag(gc, x0, y0, L, 0.5, 1, Col);
		else
			Class'RIModern'.static.Diag(gc, x0, y0, L, 0.5, -1, Col);
	}
	else
	{
		if (y0 >= y1)
			Class'RIModern'.static.Diag(gc, x1, y1, L, 0.5, 1, Col);
		else
			Class'RIModern'.static.Diag(gc, x1, y1, L, 0.5, -1, Col);
	}
}

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

function int HotAt(float X, float Y)
{
	local int i;

	for (i = NumHot - 1; i >= 0; i--)
		if ((X >= HotX[i]) && (X < HotX[i] + HotW[i]) && (Y >= HotY[i]) && (Y < HotY[i] + HotH[i]))
			return HotId[i];
	return -1;
}

// ----------------------------------------------------------------------
// Tabs
// ----------------------------------------------------------------------

function PersonaNavBarWindow Nav()
{
	return PersonaNavBarWindow(Screen.winNavBar);
}

// The med bot's own nav (Health / Augmentations), when this is a med bot page
function HUDMedBotNavBarWindow MedNav()
{
	return HUDMedBotNavBarWindow(Screen.winNavBar);
}

function BuildTabs()
{
	NumTabs = 0;
	if (MedNav() != None)
	{
		AddTab(TAB_HEALTH);
		AddTab(TAB_AUGS);
		AddTab(TAB_EXIT);
		NumSubs = 0;
		return;
	}
	AddTab(TAB_INV);
	AddTab(TAB_HEALTH);
	AddTab(TAB_AUGS);
	AddTab(TAB_SKILLS);
	AddTab(TAB_GOALS);      // the Journal
	AddTab(TAB_EXIT);
	BuildSubs();
}

// Which main tab a page belongs to
static function int MainOf(int Id)
{
	if ((Id == TAB_OUTFIT) || (Id == TAB_AMMO) || (Id == TAB_KEYS))
		return TAB_INV;
	if ((Id == TAB_CONS) || (Id == TAB_IMAGES) || (Id == TAB_LOGS))
		return TAB_GOALS;
	if (Id == TAB_PERKS)
		return TAB_SKILLS;
	return Id;
}

// The section shown right now (RIInventoryView answers with its own section)
function int CurrentSub()
{
	return ActiveTab;
}

function BuildSubs()
{
	NumSubs = 0;
	if (MainOf(ActiveTab) == TAB_INV)
	{
		SubId[NumSubs++] = TAB_INV;
		if (Class'RIBase'.static.HasOutfits(Nav()))
			SubId[NumSubs++] = TAB_OUTFIT;
		// ammo and nano keys are listed in the item panel, as in the original
	}
	else if (MainOf(ActiveTab) == TAB_GOALS)
	{
		SubId[NumSubs++] = TAB_GOALS;
		SubId[NumSubs++] = TAB_CONS;
		SubId[NumSubs++] = TAB_IMAGES;
		SubId[NumSubs++] = TAB_LOGS;
	}
	else if (MainOf(ActiveTab) == TAB_SKILLS)
	{
		SubId[NumSubs++] = TAB_SKILLS;
		if (Class'RIBase'.static.Has("Perks"))
			SubId[NumSubs++] = TAB_PERKS;
	}
}

// Subclass hook: a section the page can show itself (Inventory's ammo / keys)
function bool LocalSub(int Id)
{
	return False;
}

function GoSub(int Id)
{
	if (Id == CurrentSub())
		return;
	if (LocalSub(Id))
	{
		PlaySound(Sound'Menu_Press', 0.25);
		return;
	}
	if ((Id == TAB_AMMO) || (Id == TAB_KEYS) || (Id == TAB_INV))
	{
		if (Id == TAB_AMMO)
			Class'RIPersonaView'.default.PendingInvMode = 1;
		else if (Id == TAB_KEYS)
			Class'RIPersonaView'.default.PendingInvMode = 2;
		else
			Class'RIPersonaView'.default.PendingInvMode = 0;
		GoScreen(TAB_INV);
		return;
	}
	GoScreen(Id);
}

function AddTab(int Id)
{
	TabId[NumTabs] = Id;
	TabLabel[NumTabs] = TabNames[Id];
	NumTabs++;
}

function GoTab(int Id)
{
	if (Id == TAB_EXIT)
	{
		Close();
		return;
	}
	if (Id == MainOf(ActiveTab))
		return;
	if (Id == TAB_GOALS)
	{
		// The Journal reopens on the section used last
		if (Class'RIPersonaView'.default.JournalLast != 0)
			Id = Class'RIPersonaView'.default.JournalLast;
	}
	if (Id == TAB_INV)
		Class'RIPersonaView'.default.PendingInvMode = 0;
	GoScreen(Id);
}

// Open one of AE's pages through its own (hidden) nav bar
function GoScreen(int Id)
{
	local Window B;

	if (Id == ActiveTab)
		return;
	if (MedNav() != None)
	{
		if (Id == TAB_HEALTH)
			B = MedNav().btnHealth;
		else if (Id == TAB_AUGS)
			B = MedNav().btnAugs;
		if (B != None)
		{
			PlaySound(Sound'Menu_Press', 0.25);
			MedNav().ButtonActivated(B);
		}
		return;
	}
	if (Nav() == None)
		return;
	if (Id == TAB_INV)         B = Nav().btnInventory;
	else if (Id == TAB_HEALTH) B = Nav().btnHealth;
	else if (Id == TAB_AUGS)   B = Nav().btnAugs;
	else if (Id == TAB_SKILLS) B = Nav().btnSkills;
	else if (Id == TAB_GOALS)  B = Nav().btnGoals;
	else if (Id == TAB_OUTFIT) B = Class'RIBase'.static.OutfitsButton(Nav());
	else if (Id == TAB_CONS)   B = Nav().btnCons;
	else if (Id == TAB_IMAGES) B = Nav().btnImages;
	else if (Id == TAB_LOGS)   B = Nav().btnLogs;
	if (B != None)
	{
		PlaySound(Sound'Menu_Press', 0.25);
		Nav().ButtonActivated(B);
	}
}

// Swap between the rebuilt page and AE's original one (for what isn't
// rebuilt yet: traumas, addictions...). Reopens the same screen.
function SwitchView(bool bToClassic)
{
	Class'RIPersonaView'.default.bClassic = bToClassic;
	PlaySound(Sound'Menu_Press', 0.25);
	Screen.SaveSettings();
	DeusExRootWindow(GetRootWindow()).InvokeUIScreen(Screen.Class);
}

function Close()
{
	PlaySound(Sound'Menu_Press', 0.25);
	Screen.SaveSettings();
	DeusExRootWindow(GetRootWindow()).PopWindow();
}

// Text-only tab row (no boxes): labels spread across the width, the
// current one bright with a soft glow and a short bar on the rule below
function DrawTabs(GC gc, float a)
{
	local int i;
	local float x, w, y, h, tw, ly, KeyX;
	local bool bOn, bHot;
	local string L;

	BuildTabs();
	if (VPlus())
	{
		DrawVPTabs(gc, a);
		return;
	}
	x = OX + 120 * S;
	KeyX = x;
	y = 30 * S;
	if (Class'RIModern'.static.On())
		y = 46 * S;       // clear of the frame's top edge
	h = 46 * S;
	ly = y + h + 6 * S;

	// Rule along the whole bar, fading at both ends
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C3(126, 105, 50, a));
	Class'RIText'.static.Tex(gc, x - 40 * S, ly, 1720 * S + 80 * S, 1.5, 0, 28, 256, 8, Texture'ReimaginedUI.UI.RI_GlowC');

	for (i = 0; i < NumTabs; i++)
	{
		bOn = (TabId[i] == MainOf(ActiveTab));
		bHot = (HoverId == TabId[i]);
		L = Caps(TabLabel[i]);
		tw = Class'RIText'.static.Width(Class'RIFontHead', L, 0.6);
		w = tw + 56 * S;
		if (bOn)
		{
			BarGlow(gc, x + w * 0.5, ly, tw, 30 * S, C3(70, 59, 26, a));
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, y, w, h, L, C3(255, 240, 190, a), 1, 0.6);
			Fill(gc, x + (w - tw) * 0.5, ly - 1.5, tw, 3 * S, AHi(a));
		}
		else if (bHot)
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, y, w, h, L, AAcc(a), 1, 0.6);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, y, w, h, L, ALbl(a), 1, 0.6);
		AddHot(TabId[i], x, y, w, h);
		x += w;
	}
	// Key hints: Q / E cycle the screens
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', KeyX - 44 * S, y, 32 * S, h, "Q", ALbl(a * 0.6), 1, 0.56);
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x + 4 * S, y, 32 * S, h, "E", ALbl(a * 0.6), 1, 0.56);
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 100 * S, y, 1720 * S, h, Caps(CloseHint), ALbl(a * 0.7), 2, 0.56);
	DrawSubs(gc, ly, a);
}

// Section row: smaller labels from the left edge, the current one lit
function DrawSubs(GC gc, float ly, float a)
{
	local int i, cur;
	local float x, y, h, tw;
	local string L;
	local bool bOn, bHot;
	local float sc, gap;

	if (NumSubs == 0)
		return;
	sc = 0.5;
	gap = 52 * S;
	if (VPlus())
	{
		sc = 0.42;
		gap = 36 * S;
	}
	cur = CurrentSub();
	if (VPlus())
		x = OX + 415 * S;
	else
		x = OX + 140 * S;
	// Vanilla+: inside the header tab, no A / D hints
	if (VPlus())
	{
		y = 139 * S;
		h = 32 * S;
		DrawVPSubRow(gc, x, y, h, sc, gap, cur, a);
		return;
	}
	y = ly + 6 * S;
	h = 40 * S;
	// Key hint: A / D cycle the sections
	if (NumSubs > 1)
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x - 50 * S, y, 28 * S, h, "A", ALbl(a * 0.6), 1, 0.5);
	y = ly + 6 * S;
	h = 40 * S;
	for (i = 0; i < NumSubs; i++)
	{
		L = Caps(SubNames[SubId[i]]);
		tw = Class'RIText'.static.Width(Class'RIFontHead', L, sc);
		// the only section: nothing to switch to, so no label either
		if (NumSubs == 1)
			continue;
		bOn = (SubId[i] == cur);
		bHot = (HoverId == HOT_SUB + SubId[i]);
		if (bOn)
		{
			if (!VPlus())
				BarGlow(gc, x + tw * 0.5, y + h - 2 * S, tw, 20 * S, C3(50, 42, 18, a));
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, y, tw, h, L, C3(255, 240, 190, a), 0, sc);
			Fill(gc, x, y + h - 3 * S, tw, 2 * S, AHi(a));
		}
		else if (bHot)
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, y, tw, h, L, AAcc(a), 0, sc);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, y, tw, h, L, ALbl(a), 0, sc);
		AddHot(HOT_SUB + SubId[i], x - 12 * S, y, tw + 24 * S, h);
		x += tw + gap;
	}
	if (NumSubs > 1)
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x - 30 * S, y, 28 * S, h, "D", ALbl(a * 0.6), 1, 0.5);
}

function DrawFrame(GC gc, float a)
{
	FX = OX + 100 * S;
	FY = 140 * S;
	FW = 1720 * S;
	FH = 860 * S;
	if (VPlus())
	{
		DrawVPBackdrop(gc, a);
		return;
	}
	// Refined: no outer frame; the page darkens behind the content
	Fill(gc, 0, 0, width, height, C3(6, 5, 3, 0.55 * a));
	// Modern: one big digitized frame round the whole page, its tab above the screen row
	if (Class'RIModern'.static.On())
		Class'RIModern'.static.Frame(gc, OX + 48 * S, 4 * S, 1824 * S, 1066 * S, S, a, PersonaTitle, True);
}

// ----------------------------------------------------------------------
// Vanilla+ (mechanical frames): the board art, drawn 1:1 at 1080p and
// tinted by the HUD colour theme (C3 follows the theme)
// ----------------------------------------------------------------------

// 1 = the Inventory board (grid, belt, buttons); 0 = the shared frame
function int VPBoard()
{
	return 0;
}

// The right frame's footer bar (skill points, outfit options...); pages
// without one get the taller body instead
function bool VPFooterBar()
{
	return True;
}

// The right frame's header tab
function string VPDetailTitle()
{
	return DetailLabel;
}

// The item page's extra lower-box dividers (keys, ammo columns)
function bool VPItemDividers()
{
	return False;
}

static function int VPSlot(int Id)
{
	switch (Id)
	{
		case TAB_INV:    return 0;
		case TAB_HEALTH: return 1;
		case TAB_AUGS:   return 2;
		case TAB_SKILLS: return 3;
		case TAB_GOALS:  return 4;
	}
	return -1;
}

// The Inventory board's belt slots (design px): 10 across 403 .. 1539
static function float BeltSlotX(int i) { return 403 + i * 114.8; }
static function float BeltSlotW() { return 102.8; }

// Opaque black (RI_Clear drawn solid)
function Black(GC gc, float X, float Y, float W, float H)
{
	gc.SetStyle(DSTY_Normal);
	gc.SetTileColor(Class'RIUtil'.static.Col(255, 255, 255));
	Class'RIText'.static.Tex(gc, X, Y, W, H, 0, 0, 1, 1, Texture'ReimaginedUI.UI.RI_Clear');
}

function DrawVPBackdrop(GC gc, float a)
{
	local int i, slot;
	local float tw;

	// The game shows through, dimmed, behind the whole screen (what's behind
	// is the game's own UI Background setting: live 3D or a snapshot)
	// the veil over the game is drawn by the root, over the whole screen
	// (DrawVeil), so it doesn't stop at the board's edge when it's scaled
	if (ScaleAge < 1.6)
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', 0, 4 * S, width, 30 * S,
			"SCALE " $ string(int(Scale() * 100 + 0.5)) $ "%   (CTRL - / CTRL =)", AHi(FClamp((1.6 - ScaleAge) / 0.4, 0, 1)), 1, 0.46);

	// Tab bar: five equal tabs centred in their frame, Exit in its own
	VPFrame(gc, 352, 40, 1098, 58, a);
	tw = (1070.0 - 32.0) / 5.0;
	slot = VPSlot(MainOf(ActiveTab));
	for (i = 0; i < 5; i++)
		VPBtnK(gc, 366 + i * (tw + 8), 51, tw, 36, i == slot, a);
	VPFrame(gc, 1460, 40, 112, 58, a);
	VPBtnK(gc, 1474, 51, 84, 36, False, a);

	if (VPBoard() == 1)
	{
		// Inventory: grid frame (cells, buttons and credits are drawn by the page)
		VPFrame(gc, 380, 126, 620, 746, a);
		VPHdr(gc, 395, 139, VPHdrW(480), 32, a);
		VPWell(gc, 886, 141, 96, 28, a);
		VPInset(gc, 395, 174, 587, 642, a);
		if (Player != None)
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', OX + 886 * S, 139 * S, 88 * S, 32 * S, string(Player.Credits), ATxt(a), 2, 0.46);
		// Belt: ten even slots, each with a name strip
		VPFrame(gc, 380, 900, 1182, 118, a);
		for (i = 0; i < 10; i++)
		{
			VPWell(gc, BeltSlotX(i), 912, BeltSlotW(), 94, a);
			Class'RIText'.static.HLine(gc, OX + BeltSlotX(i) * S, (912 + 72) * S, BeltSlotW() * S, ADim(a));
		}
	}
	else
	{
		VPFrame(gc, 380, 126, 620, 866, a);
		VPHdr(gc, 395, 139, VPHdrW(565), 32, a);
		VPInset(gc, 395, 174, 587, 770, a);
	}

	// Right: name bar, body, footer; below it the lower box
	VPFrame(gc, 1042, 126, 520, 590, a);
	VPHdr(gc, 1061, 139, 340, 32, a);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', OX + 1079 * S, 139 * S, 280 * S, 32 * S, Caps(Class'RIText'.static.Fit(Class'RIFontHead', VPDetailTitle(), 280 * S, 0.42)), ALbl(a), 0, 0.42);
	VPStrip(gc, 1061, 176, 481, 30, a);
	if (VPFooterBar())
	{
		VPInset(gc, 1061, 216, 481, 443, a);
		VPStrip(gc, 1061, 670, 481, 30, a);
	}
	else
		VPInset(gc, 1061, 216, 481, 484, a);
	VPFrame(gc, 1046, 738, 516, 136, a);
	VPInset(gc, 1061, 750, 481, 107, a);
	Class'RIText'.static.VLine(gc, OX + 1168 * S, 750 * S, 107 * S, AEdge(a));
	if (VPItemDividers())
	{
		Class'RIText'.static.VLine(gc, OX + 1300 * S, 750 * S, 107 * S, AEdge(a));
		Class'RIText'.static.VLine(gc, OX + 1407 * S, 750 * S, 107 * S, AEdge(a));
	}
}

// --- Vanilla+ kit, in 1920 x 1080 design pixels ---

// Rounded frame (9-slice, corners 16) over the panel fill
function VPFrame(GC gc, float X, float Y, float W, float H, float a)
{
	local float x0, y0, w0, h0, c;
	local Texture T;

	x0 = OX + X * S;
	y0 = Y * S;
	w0 = W * S;
	h0 = H * S;
	c = 16 * S;
	FillAroundHole(gc, x0 + 3 * S, y0 + 3 * S, w0 - 6 * S, h0 - 6 * S, C3(46, 39, 20, a));
	T = Texture'ReimaginedUI.VPlus.VPK_Frame';
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C3(230, 195, 117, a));
	Class'RIVP'.static.TileR(gc, x0, y0, c, c, 0.5, 0.5, 15.5, 15.5, T);
	Class'RIVP'.static.TileR(gc, x0 + c, y0, w0 - 2 * c, c, 16, 0.5, 32, 15.5, T);
	Class'RIVP'.static.TileR(gc, x0 + w0 - c, y0, c, c, 48, 0.5, 15.5, 15.5, T);
	Class'RIVP'.static.TileR(gc, x0, y0 + c, c, h0 - 2 * c, 0.5, 16, 15.5, 32, T);
	Class'RIVP'.static.TileR(gc, x0 + w0 - c, y0 + c, c, h0 - 2 * c, 48, 16, 15.5, 32, T);
	Class'RIVP'.static.TileR(gc, x0, y0 + h0 - c, c, c, 0.5, 48, 15.5, 15.5, T);
	Class'RIVP'.static.TileR(gc, x0 + c, y0 + h0 - c, w0 - 2 * c, c, 16, 48, 32, 15.5, T);
	Class'RIVP'.static.TileR(gc, x0 + w0 - c, y0 + h0 - c, c, c, 48, 48, 15.5, 15.5, T);
	Class'RIVP'.static.DXAround(gc, x0, y0, w0, h0, S, a);
}

// The belt's contents on the Inventory board, read-only (pages other than
// Items: Ammo, Nano keys, Outfit)
function DrawVPBeltItems(GC gc, float a)
{
	local Inventory I;
	local int n;
	local float sx, y, w, ih, k;
	local string BName;

	if (Player == None)
		return;
	w = BeltSlotW() * S;
	ih = 94 * S;
	y = 912 * S;
	for (n = 0; n < 10; n++)
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', OX + (BeltSlotX(Class'RIUtil'.static.BeltPos(n)) + 6) * S, y + 4 * S, Mid("0123456789", n, 1), AAcc(a), 0.6);
	for (I = Player.Inventory; I != None; I = I.Inventory)
	{
		if (!I.bInObjectBelt || (I.beltPos < 0) || (I.beltPos >= 10) || (I.icon == None))
			continue;
		sx = OX + BeltSlotX(Class'RIUtil'.static.BeltPos(I.beltPos)) * S;
		// sized to sit well inside the slot (clear of its number, frame and
		// the name strip), as on the HUD belt
		k = FMin((w - 40 * S) / 42.0, (72 * S - 26 * S) / 37.0);
		gc.SetStyle(DSTY_Masked);
		gc.SetTileColor(C3(255, 255, 255, a));
		Class'RIHD'.static.DrawStretched(gc, sx + (w - 42 * k) * 0.5, y + 8 * S + (72 * S - 10 * S - 37 * k) * 0.5, 42 * k, 37 * k, 0, 0, 42, 37, I.icon);
		BName = I.beltDescription;
		if (BName == "")
			BName = I.ItemName;
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', sx + 4 * S, y + 72 * S, w - 8 * S, 22 * S,
			Caps(Class'RIText'.static.Fit(Class'RIFontSmall', BName, w - 8 * S, 0.52)), ATxt(a), 1, 0.52);
	}
}

// The panel fill, leaving the screen hole (Outfit's 3D preview) untouched
function FillAroundHole(GC gc, float X, float Y, float W, float H, Color C)
{
	// panels: the dimmed game darkened once more (smoked glass), then the tint
	AroundHole(gc, X, Y, W, H, 2, C);
	AroundHole(gc, X, Y, W, H, 0, C);
}

// Mode 0: additive fill in C; 1: veil (darken the game behind); 2: a lighter
// veil for the panels on top of it
function AroundHole(GC gc, float X, float Y, float W, float H, int Mode, Color C)
{
	local float hx0, hy0, hx1, hy1;

	if ((HoleW <= 0) || (HoleX >= X + W) || (HoleX + HoleW <= X) || (HoleY >= Y + H) || (HoleY + HoleH <= Y))
	{
		Piece(gc, X, Y, W, H, Mode, C);
		return;
	}
	hx0 = FMax(X, HoleX);
	hy0 = FMax(Y, HoleY);
	hx1 = FMin(X + W, HoleX + HoleW);
	hy1 = FMin(Y + H, HoleY + HoleH);
	if (hy0 > Y)
		Piece(gc, X, Y, W, hy0 - Y, Mode, C);
	if (hy1 < Y + H)
		Piece(gc, X, hy1, W, Y + H - hy1, Mode, C);
	if (hx0 > X)
		Piece(gc, X, hy0, hx0 - X, hy1 - hy0, Mode, C);
	if (hx1 < X + W)
		Piece(gc, hx1, hy0, X + W - hx1, hy1 - hy0, Mode, C);
}

function Piece(GC gc, float X, float Y, float W, float H, int Mode, Color C)
{
	if (Mode == 0)
	{
		Fill(gc, X, Y, W, H, C);
		return;
	}
	gc.SetStyle(DSTY_Modulated);
	if (Mode == 1)
		Class'RIText'.static.Tex(gc, X, Y, W, H, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dark');
	else
		Class'RIText'.static.Tex(gc, X, Y, W, H, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dim4');
}

// The root draws this round a scaled-down board (screen coordinates)
// Drawn by the root under the board: the game dimmed a little over the whole
// screen (no tint), leaving Outfit's 3D preview untouched. Root coordinates.
function DrawVeil(GC gc, float RW, float RH)
{
	local float hx0, hy0, hx1, hy1;

	gc.SetStyle(DSTY_Modulated);
	if (HoleW <= 0)
	{
		Class'RIText'.static.Tex(gc, 0, 0, RW, RH, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dim4');
		return;
	}
	hx0 = x + HoleX;
	hy0 = y + HoleY;
	hx1 = hx0 + HoleW;
	hy1 = hy0 + HoleH;
	Class'RIText'.static.Tex(gc, 0, 0, RW, hy0, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dim4');
	Class'RIText'.static.Tex(gc, 0, hy1, RW, RH - hy1, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dim4');
	Class'RIText'.static.Tex(gc, 0, hy0, hx0, HoleH, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dim4');
	Class'RIText'.static.Tex(gc, hx1, hy0, RW - hx1, HoleH, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dim4');
}

// Chamfered button (left cap, stretched middle, chamfered right end)
function VPBtnK(GC gc, float X, float Y, float W, float H, bool bLit, float a)
{
	local float x0, y0, w0, h0, lw, rw;
	local Texture T;

	x0 = OX + X * S;
	y0 = Y * S;
	w0 = W * S;
	h0 = H * S;
	lw = 8 * h0 / 32;
	rw = 24 * h0 / 32;
	if (bLit)
		T = Texture'ReimaginedUI.VPlus.VPK_BtnLit';
	else
		T = Texture'ReimaginedUI.VPlus.VPK_Btn';
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C3(230, 195, 117, a));
	Class'RIVP'.static.TileR(gc, x0, y0, lw, h0, 0.5, 0.5, 7.5, 31, T);
	Class'RIVP'.static.TileR(gc, x0 + lw, y0, w0 - lw - rw, h0, 8, 0.5, 32, 31, T);
	Class'RIVP'.static.TileR(gc, x0 + w0 - rw, y0, rw, h0, 40, 0.5, 23.5, 31, T);
}

// Header tab across the top of the left frame (diagonal right end)
function VPHdr(GC gc, float X, float Y, float W, float H, float a)
{
	local float x0, y0, w0, h0, lw, rw;
	local Texture T;

	x0 = OX + X * S;
	y0 = Y * S;
	w0 = W * S;
	h0 = H * S;
	lw = 16 * h0 / 32;
	rw = 48 * h0 / 32;
	T = Texture'ReimaginedUI.VPlus.VPK_Hdr';
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C3(230, 195, 117, a));
	Class'RIVP'.static.TileR(gc, x0, y0, lw, h0, 0.5, 0.5, 15.5, 31, T);
	Class'RIVP'.static.TileR(gc, x0 + lw, y0, w0 - lw - rw, h0, 16, 0.5, 64, 31, T);
	Class'RIVP'.static.TileR(gc, x0 + w0 - rw, y0, rw, h0, 80, 0.5, 47.5, 31, T);
}

// Thin inset box
function VPInset(GC gc, float X, float Y, float W, float H, float a)
{
	Class'RIText'.static.Box(gc, OX + X * S, Y * S, W * S, H * S, C3(170, 143, 70, a));
}

// Screen title in the left frame's header strip
function VPTitle(GC gc, string T, float a)
{
	// centred in the header tab (y 137..170 on the shared frame)
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', OX + 415 * S, 140 * S, 520 * S, 30 * S, Caps(T), ATxt(a), 0, 0.46);
}

// Vanilla+: the header tab's width, in design pixels. With sections it ends
// just past the last one (its chamfer follows the labels: three sections on
// the original game make a shorter tab); with none (a title) it's full width.
function float VPHdrW(float Full)
{
	local int i;
	local float tw;

	if (NumSubs <= 1)
		return Full;
	for (i = 0; i < NumSubs; i++)
		tw += Class'RIText'.static.Width(Class'RIFontHead', Caps(SubNames[SubId[i]]), 0.42) / S;
	// labels from 415, 36 apart, half a gap after the last, then the chamfer
	return FClamp(20 + tw + 36 * (NumSubs - 1) + 18 + 56, 200, Full);
}

// The section row inside the header tab (Vanilla+): labels centred in the
// tab's height, hairline dividers between them, the current one lit from
// behind with a short bar under it, clear of the tab's bottom edge
function DrawVPSubRow(GC gc, float x, float y, float h, float sc, float gap, int cur, float a)
{
	local int i;
	local float tw, sx, ex, k;
	local string L;
	local Color C;

	for (i = 0; i < NumSubs; i++)
	{
		L = Caps(SubNames[SubId[i]]);
		tw = Class'RIText'.static.Width(Class'RIFontHead', L, sc);
		// the only section: a plain title, no box (nothing to switch to)
		if (NumSubs == 1)
		{
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, y - 1 * S, tw, h, L, ATxt(a), 0, sc);
			continue;
		}
		if (i == 0)
			sx = x - 14 * S;
		else
			sx = x - gap * 0.5;
		ex = x + tw + gap * 0.5;
		if (SubId[i] == cur)
		{
			// a box round the section, fading in once it's chosen
			if (SubShown != cur)
			{
				SubShown = cur;
				SubShownAt = Age;
			}
			k = Class'RIUtil'.static.EaseOut(FClamp((Age - SubShownAt) / 0.3, 0, 1));
			Fill(gc, sx + 3 * S, y + 4 * S, ex - sx - 6 * S, h - 8 * S, C3(52, 43, 19, a * k));
			Class'RIText'.static.Box(gc, sx + 3 * S, y + 4 * S, ex - sx - 6 * S, h - 8 * S, C3(242, 211, 107, a * k));
			C = AHi(a);
		}
		else if (HoverId == HOT_SUB + SubId[i])
		{
			Fill(gc, sx + 3 * S, y + 4 * S, ex - sx - 6 * S, h - 8 * S, C3(30, 25, 11, a));
			C = ATxt(a);
		}
		else
			C = ALbl(a);
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, y - 1 * S, tw, h, L, C, 0, sc);
		AddHot(HOT_SUB + SubId[i], sx, y, ex - sx, h);
		x += tw + gap;
		if (i < NumSubs - 1)
			Class'RIText'.static.VLine(gc, x - gap * 0.5, y + 7 * S, h - 14 * S, C3(126, 105, 50, a));
	}
}

// A title strip (name bar, footer bar): a toned band in a thin box
function VPStrip(GC gc, float X, float Y, float W, float H, float a)
{
	VPWell(gc, X, Y, W, H, a);
	Fill(gc, OX + X * S, Y * S, 2 * S, H * S, C3(200, 170, 98, a));
}

// An inset box with a dark backing (the game behind darkened twice, close
// to solid, then the panel tone; once wasn't enough: edges in the level
// still showed through as lines): belt slots, the credits box, title strips
function VPWell(GC gc, float X, float Y, float W, float H, float a)
{
	AroundHole(gc, OX + X * S, Y * S, W * S, H * S, 1, C3(0, 0, 0, a));
	AroundHole(gc, OX + X * S, Y * S, W * S, H * S, 1, C3(0, 0, 0, a));
	Fill(gc, OX + X * S, Y * S, W * S, H * S, C3(24, 20, 9, a));
	VPInset(gc, X, Y, W, H, a);
}

// The board's tab slots: five screens and Exit
function DrawVPTabs(GC gc, float a)
{
	local int i, id;
	local float x, w;
	local string L;
	local Color C;

	for (i = 0; i < 6; i++)
	{
		id = TAB_EXIT;
		switch (i)
		{
			case 0: id = TAB_INV; break;
			case 1: id = TAB_HEALTH; break;
			case 2: id = TAB_AUGS; break;
			case 3: id = TAB_SKILLS; break;
			case 4: id = TAB_GOALS; break;
		}
		if (i < 5)
		{
			x = OX + (366 + i * 215.6) * S;
			w = 207.6 * S;
		}
		else
		{
			x = OX + 1474 * S;
			w = 84 * S;
		}
		L = Caps(Class'RIText'.static.Fit(Class'RIFontHead', TabNames[id], w - 16 * S, 0.46));
		if (id == MainOf(ActiveTab))
			C = AHi(a);
		else if (HoverId == id)
			C = ATxt(a);
		else
			C = ALbl(a);
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 50 * S, w - 10 * S, 38 * S, L, C, 1, 0.46);
		AddHot(id, x, 50 * S, w, 38 * S);
	}
	DrawSubs(gc, 138 * S, a);
}

// Vanilla+: the AE screen's own background and border art (its 640x480
// layout, doubled and centred), drawn behind the rebuilt content
function DrawOriginalScreen(GC gc, float a)
{
	local float k, X0, Y0;

	if (Screen == None)
		return;
	k = 2 * S;
	X0 = (width - 640 * k) * 0.5;
	Y0 = (height - 480 * k) * 0.5;
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(C3(255, 215, 120, a));
	TileSet(gc, X0 + (Screen.clientBorderOffsetX + Screen.clientOffsetX) * k, Y0 + (Screen.clientBorderOffsetY + Screen.clientOffsetY) * k,
		Screen.clientWidth, Screen.clientHeight, Screen.clientTextureCols, Screen.clientTextureRows, k, true);
	gc.SetStyle(DSTY_Masked);
	gc.SetTileColor(C3(255, 225, 140, a));
	TileSet(gc, X0 + Screen.clientBorderOffsetX * k, Y0 + Screen.clientBorderOffsetY * k,
		Screen.clientBorderWidth, Screen.clientBorderHeight, Screen.clientBorderTextureCols, Screen.clientBorderTextureRows, k, false);
	// Style tag, so it is plain which style is live
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', OX + 100 * S, 1036 * S, "VANILLA+", AAcc(a), 0.72);
}

// One of the screen's 256-texel tile grids, cropped to W x H original pixels
function TileSet(GC gc, float X, float Y, int W, int H, int Cols, int Rows, float k, bool bClient)
{
	local int c, r, i, tw, th;
	local Texture T;

	for (r = 0; r < Rows; r++)
	{
		for (c = 0; c < Cols; c++)
		{
			i = r * Cols + c;
			if (i > 5)
				continue;
			if (bClient)
				T = Screen.clientTextures[i];
			else
				T = Screen.clientBorderTextures[i];
			if (T == None)
				continue;
			tw = Min(256, W - c * 256);
			th = Min(256, H - r * 256);
			if ((tw <= 0) || (th <= 0))
				continue;
			Class'RIHD'.static.DrawStretched(gc, X + c * 256 * k, Y + r * 256 * k, tw * k, th * k, 0, 0, tw, th, T);
		}
	}
}

// Section title with a rule under it
function Heading(GC gc, float X, float Y, float W, string T, float a)
{
	Class'RIText'.static.Draw(gc, Class'RIFontTitle', X, Y, Caps(T), ATxt(a), 0.5);
	if (W > 0)
		Class'RIText'.static.HLine(gc, X, Y + 46 * S, W, ADim(a));
}

// ----------------------------------------------------------------------
// Input
// ----------------------------------------------------------------------

event bool VirtualKeyPressed(EInputKey key, bool bRepeat)
{
	if (IsKeyDown(IK_Ctrl) && !bRepeat && VPlus() && ((key == IK_Minus) || (key == IK_Equals)))
	{
		if (key == IK_Minus)
			StepScale(-1);
		else
			StepScale(1);
		return True;
	}
	if (IsKeyDown(IK_Alt) || IsKeyDown(IK_Ctrl))
		return False;
	if (key == IK_Escape)
	{
		Close();
		return True;
	}
	// Q / E: previous / next screen; A / D: previous / next section of it
	if (!bRepeat && !IsTyping())
	{
		if (key == IK_Q)
		{
			CycleMain(-1);
			return True;
		}
		if (key == IK_E)
		{
			CycleMain(1);
			return True;
		}
		if (key == IK_A)
		{
			CycleSub(-1);
			return True;
		}
		if (key == IK_D)
		{
			CycleSub(1);
			return True;
		}
	}
	if (PageKey(key, bRepeat))
		return True;
	// Everything else (F-keys that switch screens, etc.) goes to AE
	return Screen.VirtualKeyPressed(key, bRepeat);
}

// Subclass hook: True while the page takes typed text (Q/E/A/D then type)
function bool IsTyping()
{
	return False;
}

// The main screens in tab order, for Q / E
function int MainAt(int Pos)
{
	if (Pos == 0)
		return TAB_INV;
	if (Pos == 1)
		return TAB_HEALTH;
	if (Pos == 2)
		return TAB_AUGS;
	if (Pos == 3)
		return TAB_SKILLS;
	return TAB_GOALS;
}

function CycleMain(int Dir)
{
	local int i, Here, Cur;

	Cur = MainOf(ActiveTab);
	if (MedNav() != None)
	{
		if (Cur == TAB_HEALTH)
			GoTab(TAB_AUGS);
		else
			GoTab(TAB_HEALTH);
		return;
	}
	Here = 0;
	for (i = 0; i < 5; i++)
		if (MainAt(i) == Cur)
			Here = i;
	Here = (Here + Dir + 5) % 5;
	GoTab(MainAt(Here));
}

// A / D: the section row of this screen (Inventory, Journal)
function CycleSub(int Dir)
{
	local int i, Here, Cur;

	BuildSubs();
	if (NumSubs < 2)
		return;
	Cur = CurrentSub();
	Here = 0;
	for (i = 0; i < NumSubs; i++)
		if (SubId[i] == Cur)
			Here = i;
	Here = (Here + Dir + NumSubs) % NumSubs;
	GoSub(SubId[Here]);
}

// Subclass hook
function bool PageKey(EInputKey key, bool bRepeat)
{
	return False;
}

event MouseMoved(float newX, float newY)
{
	local int Id;

	LastMouseX = newX;
	LastMouseY = newY;
	Id = HotAt(newX, newY);
	if ((Id != HoverId) && (Id != -1) && ((Id <= TAB_EXIT) || ((Id > HOT_SUB) && (Id < HOT_SUB + 16))))
		PlaySound(Sound'Menu_Focus', 0.15);
	HoverId = Id;
}

event bool MouseButtonPressed(float pointX, float pointY, EInputKey button, int numClicks)
{
	local int Id;

	// The wheel arrives here as a "button": hand it to the page like a key
	if ((button == IK_MouseWheelUp) || (button == IK_MouseWheelDown))
	{
		LastMouseX = pointX;
		LastMouseY = pointY;
		PageKey(button, False);
		return True;
	}
	LastMouseX = pointX;
	LastMouseY = pointY;
	Id = HotAt(pointX, pointY);
	if ((button == IK_LeftMouse) && (Id >= 1) && (Id <= TAB_EXIT))
	{
		GoTab(Id);
		return True;
	}
	if ((button == IK_LeftMouse) && (Id > HOT_SUB) && (Id < HOT_SUB + 16))
	{
		GoSub(Id - HOT_SUB);
		return True;
	}
	PageClick(Id, button, numClicks);
	return True;
}

event bool MouseButtonReleased(float pointX, float pointY, EInputKey button, int numClicks)
{
	LastMouseX = pointX;
	LastMouseY = pointY;
	PageRelease(pointX, pointY, button);
	return True;
}

// Subclass hook (drag and drop)
function PageRelease(float pointX, float pointY, EInputKey button)
{
}

// Subclass hook
function PageClick(int Id, EInputKey button, int numClicks)
{
}

// ----------------------------------------------------------------------
// Tick / draw
// ----------------------------------------------------------------------

event Tick(float deltaSeconds)
{
	Age += deltaSeconds;
	if (Screen == None)
		return;
	ScaleAge += deltaSeconds;
	if ((Abs(width - Screen.width * Scale()) > 0.5) || (Abs(height - Screen.height * Scale()) > 0.5))
		Place();
	if (bHideScreen)
		HideScreenParts();
	if (RIRootWindow(GetRootWindow()) != None)
		RIRootWindow(GetRootWindow()).GuardInitCount("Persona");
	if (bReady && (DeusExRootWindow(GetRootWindow()).GetTopWindow() == Screen) && (GetRootWindow().GetFocusWindow() != Self))
		SetFocusWindow(Self);
	PageTick(deltaSeconds);
}

// Subclass hook
function PageTick(float deltaSeconds)
{
}

event DrawWindow(GC gc)
{
	local float a;

	if (Screen == None)
		return;
	if (!bLoggedStyle)
	{
		bLoggedStyle = True;
		Log("RI: " $ Class $ " style=" $ Class'RIRootWindow'.default.ScreenStyle $ " noHD=" $ Class'RIRootWindow'.default.bNoHDTextures
			$ " bg=" $ Screen.clientTextures[0] $ " hd=" $ Class'RIHD'.static.HD(Screen.clientTextures[0]) $ " border=" $ Screen.clientBorderTextures[0]);
	}
	Class'RITheme'.static.SetMode(2);   // persona palette follows the HUD theme
	NumHot = 0;
	S = height / 1080.0;
	OX = FMax(0, (width - 1920 * S) * 0.5);
	a = Class'RIUtil'.static.Phase(Age, 0.0, 0.25);
	gc.EnableSmoothing(True);

	if (VPlus())
	{
		// No fade in Vanilla+: the chrome is the same on every screen, so
		// switching tabs must not flash it through black
		a = 1.0;
		DrawFrame(gc, a);
		DrawTabs(gc, a);
	}
	else if (Class'RIModern'.static.On())
	{
		// the frame darkens what's under it, so it goes down first
		DrawFrame(gc, a);
		DrawTabs(gc, a);
	}
	else
	{
		DrawTabs(gc, a);
		DrawFrame(gc, a);
	}
	DrawPage(gc, a * Class'RIUtil'.static.Phase(Age, 0.05, 0.25));
	if (VPlus() && (VPBoard() == 0))
		DrawVPFooter(gc, a);
}

// Vanilla+: the shared frame's label slot (bottom left) and the strip beside
// it carry the screen keys and this page's own hints
function DrawVPFooter(GC gc, float a)
{
	local string H;

	H = GetPropertyText("HintText");
	if (H == "")
		H = CloseHint;
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 412 * S, 948 * S, 560 * S, 32 * S,
		Caps(Class'RIText'.static.Fit(Class'RIFontSmall', H, 560 * S, 0.44)), ALbl(a * 0.85), 0, 0.44);
}

// Subclass hook
function DrawPage(GC gc, float a)
{
}

defaultproperties
{
     CloseHint="Esc close"
     PersonaTitle="Persona"
     DetailLabel="Details"
     TabNames(1)="Inventory"
     TabNames(2)="Health"
     TabNames(3)="Augs"
     TabNames(4)="Skills"
     TabNames(5)="Journal"
     TabNames(6)="Outfit"
     TabNames(7)="Conversations"
     TabNames(8)="Images"
     TabNames(9)="Logs"
     TabNames(10)="Exit"
     SubNames(1)="Items"
     SubNames(5)="Goals / Notes"
     SubNames(6)="Outfit"
     SubNames(7)="Conversations"
     SubNames(8)="Images"
     SubNames(9)="Logs"
     SubNames(12)="Ammo"
     SubNames(13)="Nano keys"
     SubNames(4)="Skills"
     SubNames(14)="General perks"
}
