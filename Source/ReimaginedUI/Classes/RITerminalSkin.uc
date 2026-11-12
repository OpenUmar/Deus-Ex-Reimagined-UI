//=============================================================================
// RITerminalSkin
// Added (lowest) inside every computer / ATM terminal in the Sleek style.
// AE's screens keep all their logic; this window re-skins whichever screen
// the terminal shows (login, menus, email, bulletins, security, ATM, special
// options) and the Ice Breaker / account windows in the persona gold, and
// draws the gold panels and titles behind them in place of AE's frames.
//=============================================================================
class RITerminalSkin extends Window;

var NetworkTerminal Term;
var float Age, NextSkin;
var bool  bReady;
var ComputerUIWindow LastScreen;
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
	PlaceNotes();
	if (bReady && (Age >= NextSkin))
	{
		Reskin();
		NextSkin = Age + 0.25;
	}
}

function Reskin()
{
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

defaultproperties
{
     HackTitle="Ice Breaker"
     AccountsTitle="Accounts"
}
