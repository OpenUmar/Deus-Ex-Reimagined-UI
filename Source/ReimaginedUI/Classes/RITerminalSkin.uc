//=============================================================================
// RITerminalSkin
// Added (lowest) inside every computer / ATM terminal in the Sleek style.
// AE's screens keep all their logic; this window re-skins whichever screen
// the terminal shows (login, menus, email, bulletins, security, ATM, special
// options) and the Ice Breaker / account windows in the persona gold, and
// draws the gold panels and titles behind them in place of AE's frames.
// Vanilla+ (bVP): the game's own screens, frames and fonts are kept; their
// menu widgets are repainted from the HUD colour theme (as the rest of the
// in-game Vanilla+ UI is). No extra border: the computer frame is an
// irregular shape (title tab, offset left edge, shadowed right edge) with
// its own edges, so a rectangle round it would float off it.
//=============================================================================
class RITerminalSkin extends Window;

var NetworkTerminal Term;
var float Age, NextSkin;
var bool  bReady;
var ComputerUIWindow LastScreen;
var bool  bVP;                // Vanilla+: recolour only, original frames kept
var float ScreenAge;          // fades each new screen's panel in

var localized string HackTitle, AccountsTitle;

event InitWindow()
{
	Super.InitWindow();
	bTickEnabled = True;
}

event WindowReady()
{
	Super.WindowReady();
	bReady = True;            // hiding waits for the engine's ready pass (see RISkin.SafeHide)
}

event Tick(float deltaSeconds)
{
	local Window P;

	Age += deltaSeconds;
	ScreenAge += deltaSeconds;
	P = GetParent();
	if ((P != None) && ((width != P.width) || (height != P.height)))
		SetConfiguration(0, 0, P.width, P.height);
	if (Term == None)
		return;
	if (Term.winComputer != LastScreen)
	{
		LastScreen = Term.winComputer;
		ScreenAge = 0;
		NextSkin = 0;
	}
	if (!bVP)
		PlaceNotes();
	if (bReady && (Age >= NextSkin))
	{
		Reskin();
		NextSkin = Age + 0.25;
	}
}

function Reskin()
{
	if (bVP)
	{
		VPReskin();
		return;
	}
	Class'RITheme'.static.SetMode(2);
	if (Term.winComputer != None)
		Class'RISkin'.static.SkinComputer(Term.winComputer);
	if (Term.winHack != None)
	{
		Term.winHack.texBackground = Texture'ReimaginedUI.UI.RI_Clear';
		Term.winHack.texBorder = Texture'ReimaginedUI.UI.RI_Clear';
		if (Term.winHack.winHackMessage != None)
		{
			Term.winHack.winHackMessage.SetBackground(Texture'ReimaginedUI.UI.RI_Clear');
			Term.winHack.winHackMessage.SetTextColor(Class'RIUtil'.static.Col(255, 241, 194));
		}
		if (Term.winHack.winDigits != None)
			Term.winHack.winDigits.SetTextColor(Class'RIUtil'.static.Col(150, 126, 62));
		Class'RISkin'.static.SkinDeviceTree(Term.winHack);
	}
	if (Term.winHackAccounts != None)
	{
		Term.winHackAccounts.texBackground = Texture'ReimaginedUI.UI.RI_Clear';
		Term.winHackAccounts.texBorder = Texture'ReimaginedUI.UI.RI_Clear';
		if (Term.winHackAccounts.lstAccounts != None)
		{
			Term.winHackAccounts.lstAccounts.SetTextColor(Class'RIUtil'.static.Col(230, 195, 117));
			Term.winHackAccounts.lstAccounts.SetHighlightTextColor(Class'RIUtil'.static.Col(255, 241, 194));
		}
		Class'RISkin'.static.SkinDeviceTree(Term.winHackAccounts);
	}
	Class'RISkin'.static.SafeHide(Term.winHackShadow);
	Class'RISkin'.static.SafeHide(Term.winHackAccountsShadow);
	Class'RITheme'.static.SetMode(0);
	if (RIRootWindow(GetRootWindow()) != None)
		RIRootWindow(GetRootWindow()).GuardInitCount("Terminal");
}

// Bounds of W in this window's coordinates
function Bounds(Window W, out float rx, out float ry, out float rw, out float rh)
{
	ConvertCoordinates(W, 0, 0, Self, rx, ry);
	rw = W.width;
	rh = W.height;
}

function Grow(Window W, out float x0, out float y0, out float x1, out float y1)
{
	local float rx, ry, rw, rh;

	if ((W == None) || !W.IsVisible())
		return;
	Bounds(W, rx, ry, rw, rh);
	x0 = FMin(x0, rx);
	y0 = FMin(y0, ry);
	x1 = FMax(x1, rx + rw);
	y1 = FMax(y1, ry + rh);
}

// The computer screen's panel: client, button bar and status line, padded
function bool ScreenPanel(ComputerUIWindow S, out float x0, out float y0, out float x1, out float y1)
{
	if ((S == None) || !S.IsVisible() || (S.winClient == None))
		return False;
	Bounds(S.winClient, x0, y0, x1, y1);
	x1 += x0;
	y1 += y0;
	Grow(S.winButtonBar, x0, y0, x1, y1);
	Grow(S.winStatus, x0, y0, x1, y1);
	x0 -= 8;
	y0 -= 8;
	x1 += 8;
	y1 += 8;
	return True;
}

// The notes panel beside the computer panel, as tall as it
function PlaceNotes()
{
	local float x0, y0, x1, y1;
	local Window N;

	N = Class'RIBase'.static.TerminalNotes(Term);
	if ((N == None) || !N.IsVisible())
		return;
	if (!ScreenPanel(Term.winComputer, x0, y0, x1, y1))
		return;
	Class'RIBase'.static.PlaceTerminalNotes(Term, x1 + 14, y0, 300, y1 - y0);
}

event DrawWindow(GC gc)
{
	local ComputerUIWindow S;
	local float x0, y0, x1, y1, k, a;
	local string T;

	if (Term == None)
		return;
	if (bVP)
		return;
	Class'RITheme'.static.SetMode(2);
	k = 0.5;                     // these are root-scale UI units: half a unit per 1080p pixel

	S = Term.winComputer;
	if (ScreenPanel(S, x0, y0, x1, y1))
	{
		a = 0.4 + 0.6 * Class'RIUtil'.static.EaseOut(FClamp(ScreenAge / 0.22, 0, 1));
		T = "";
		if (S.winTitle != None)
			T = S.winTitle.titleText;
		Class'RISkin'.static.GoldPanel(gc, x0, y0, x1 - x0, y1 - y0, k, a, T);
	}

	if ((Term.winHack != None) && Term.winHack.IsVisible())
	{
		Bounds(Term.winHack, x0, y0, x1, y1);
		Class'RISkin'.static.GoldPanel(gc, x0 + 6, y0 + 6, x1 - 18, y1 - 14, k, 1, HackTitle);
	}
	if ((Term.winHackAccounts != None) && Term.winHackAccounts.IsVisible())
	{
		Bounds(Term.winHackAccounts, x0, y0, x1, y1);
		Class'RISkin'.static.GoldPanel(gc, x0 + 6, y0 + 6, x1 - 18, y1 - 14, k, 1, AccountsTitle);
	}
	Class'RITheme'.static.SetMode(0);
}

// ----------------------------------------------------------------------
// Vanilla+: the computer screen's menu widgets take the HUD theme's colours
// (each widget's own StyleChanged reads the Menu theme; this repeats it with
// the matching HUD names). Ice Breaker and the account list already follow
// the HUD theme, so they're left as they are.
// ----------------------------------------------------------------------

function VPReskin()
{
	local DeusExPlayer P;
	local ColorTheme T;

	P = DeusExPlayer(GetRootWindow().parentPawn);
	if ((P == None) || (P.ThemeManager == None) || (Term.winComputer == None))
		return;
	T = P.ThemeManager.GetCurrentHUDColorTheme();
	if (T == None)
		return;
	Class'RITheme'.static.SetMode(2);
	HudTree(Term.winComputer, T);
	Class'RITheme'.static.SetMode(0);
	if (RIRootWindow(GetRootWindow()) != None)
		RIRootWindow(GetRootWindow()).GuardInitCount("Terminal");
}

// A HUD theme colour, through the Vanilla+ palette (Amber turns to grey)
function Color HC(ColorTheme T, Name N)
{
	local Color C;

	C = T.GetColorFromName(N);
	return Class'RIUtil'.static.Col(C.R, C.G, C.B);
}

function HudTree(Window W, ColorTheme T)
{
	local Window Child;

	if (W == None)
		return;
	HudWidget(W, T);
	Child = W.GetTopChild();
	while (Child != None)
	{
		HudTree(Child, T);
		Child = Child.GetLowerSibling();
	}
}

function HudWidget(Window W, ColorTheme T)
{
	local MenuUIBorderButtonWindow Btn;
	local MenuUIListWindow Lst;
	local MenuUIScrollAreaWindow Scr;
	local Color F;
	local int i;

	if (MenuUITitleWindow(W) != None)
	{
		MenuUITitleWindow(W).colTitle     = HC(T, 'HUDColor_ButtonFace');
		MenuUITitleWindow(W).colTitleText = HC(T, 'HUDColor_TitleText');
		MenuUITitleWindow(W).colBubble    = HC(T, 'HUDColor_Background');
		return;
	}
	if (MenuUILeftEdgeWindow(W) != None)
	{
		MenuUILeftEdgeWindow(W).colBackground = HC(T, 'HUDColor_ButtonFace');
		return;
	}
	if (MenuUIRightEdgeWindow(W) != None)
	{
		MenuUIRightEdgeWindow(W).colBackground = HC(T, 'HUDColor_ButtonFace');
		return;
	}
	if (MenuUIClientWindow(W) != None)
	{
		MenuUIClientWindow(W).colBackground = HC(T, 'HUDColor_Background');
		return;
	}
	Btn = MenuUIBorderButtonWindow(W);
	if (Btn != None)
	{
		Btn.colButtonFace = HC(T, 'HUDColor_ButtonFace');
		Btn.colText[0] = HC(T, 'HUDColor_ButtonTextNormal');
		Btn.colText[1] = HC(T, 'HUDColor_ButtonTextFocus');
		Btn.colText[2] = Btn.colText[1];
		Btn.colText[3] = HC(T, 'HUDColor_ButtonTextDisabled');
		return;
	}
	Lst = MenuUIListWindow(W);
	if (Lst != None)
	{
		Lst.SetTextColor(HC(T, 'HUDColor_ListText'));
		// the HUD theme's highlight text is often no brighter than its list
		// text (Default: both 200 over a 128 bar); the focus colour reads
		Lst.SetHighlightTextColor(HC(T, 'HUDColor_ButtonTextFocus'));
		Lst.SetHighlightColor(HC(T, 'HUDColor_ListHighlight'));
		Lst.SetFocusColor(HC(T, 'HUDColor_ListFocus'));
		for (i = 0; i < Lst.GetNumColumns(); i++)
			Lst.SetColumnColor(i, HC(T, 'HUDColor_ListText'));
		return;
	}
	if (MenuUIHeaderWindow(W) != None)
	{
		MenuUIHeaderWindow(W).SetTextColor(HC(T, 'HUDColor_HeaderText'));
		return;
	}
	if (MenuUILabelWindow(W) != None)
	{
		MenuUILabelWindow(W).SetTextColor(HC(T, 'HUDColor_ListText'));
		return;
	}
	if (MenuUINormalLargeTextWindow(W) != None)
	{
		MenuUINormalLargeTextWindow(W).SetTextColor(HC(T, 'HUDColor_NormalText'));
		return;
	}
	if (MenuUIHelpWindow(W) != None)
	{
		MenuUIHelpWindow(W).colText = HC(T, 'HUDColor_NormalText');
		MenuUIHelpWindow(W).SetTextColor(MenuUIHelpWindow(W).colText);
		return;
	}
	if (MenuUIEditWindow(W) != None)
	{
		MenuUIEditWindow(W).SetTextColor(HC(T, 'HUDColor_ListText'));
		MenuUIEditWindow(W).SetTileColor(HC(T, 'HUDColor_ListHighlight'));
		return;
	}
	Scr = MenuUIScrollAreaWindow(W);
	if (Scr != None)
	{
		F = HC(T, 'HUDColor_ButtonFace');
		Scr.upButton.SetButtonColors(F, F, F, F, F, F);
		Scr.downButton.SetButtonColors(F, F, F, F, F, F);
		Scr.vScale.SetThumbColor(F);
		return;
	}
}

defaultproperties
{
     HackTitle="Ice Breaker"
     AccountsTitle="Accounts"
}
