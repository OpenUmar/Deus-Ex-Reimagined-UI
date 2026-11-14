//=============================================================================
// RIMenuMain
// Full-screen animated main menu. Extends AE's MenuMain, so every button
// action, sensitivity rule and GMDX behaviour is inherited unchanged; only
// the layout and drawing are replaced.
//
// Intro timeline (seconds):
//   0.00 - 0.90  fade up from black, key art eases in from a slight zoom
//   0.10 - 0.65  left panel slides in
//   0.30 - 0.90  logo drops in
//   0.35 - ...   buttons cascade in (see RIMenuButton)
//   always       light beam breathes
//=============================================================================
class RIMenuMain extends MenuMain;

var float AnimTime;
var int   DisplayOrder[10];

// "Main Menu": only while a game is running (not on the title map)
var RIMenuButton btnMainMenu;
var bool  bHasGame;
var bool  bAskMainMenu;
var localized string MainMenuLabel;

// Title card ("press any key"), once per launch on the title map
var RITitleCard TitleCard;
var bool  bTitleChecked;
var localized string MainMenuTitle;
var localized string MainMenuPrompt;

// Pause menu (in game): sits on the paused game instead of the key art,
// arrives quickly, and animates out before returning to the game
var bool  bInGame;
var bool  bClosing, bCloseDone;
var float CloseT;
const CloseTime = 0.2;     // button indices top to bottom; -1 = unused

// Layout, recomputed in ConfigurationChanged (scaled from a 1080p design)
var float S;                    // scale = height / 1080
var float PanelW;
var float MenuX, MenuY, MenuW, ButtonH, ButtonGap;

const KeyArtSrcW = 1920.0;     // true aspect of the key art (names must not clash with locals:
const KeyArtSrcH = 1080.0;     // UnrealScript is case-insensitive)

// ----------------------------------------------------------------------

event InitWindow()
{
	local int i;

	Super.InitWindow();

	SetWindowAlignments(HALIGN_Full, VALIGN_Full);
	AnimTime = 0;
	bTickEnabled = True;

	bInGame = (RIRootWindow(root) != None) && RIRootWindow(root).InGameMenus();
	if (bInGame)
		for (i = 0; i < arrayCount(winButtons); i++)
			if (RIMenuButton(winButtons[i]) != None)
			{
				RIMenuButton(winButtons[i]).IntroDelay = 0.06;
				RIMenuButton(winButtons[i]).IntroStep  = 0.025;
				RIMenuButton(winButtons[i]).IntroDur   = 0.26;
			}
	if (bInGame && (btnMainMenu != None))
	{
		btnMainMenu.IntroDelay = 0.06;
		btnMainMenu.IntroStep  = 0.025;
		btnMainMenu.IntroDur   = 0.26;
	}
}

// ----------------------------------------------------------------------
// Pause menu: "Back to Game" and Escape play the exit animation first
// ----------------------------------------------------------------------

// The title card has gone: play the menu's own intro from the start
function TitleCardDone()
{
	local int i;

	AnimTime = 0;
	for (i = 0; i < arrayCount(winButtons); i++)
		if (RIMenuButton(winButtons[i]) != None)
			RIMenuButton(winButtons[i]).Age = 0;
	if (btnMainMenu != None)
		btnMainMenu.Age = 0;
	if (winButtons[0] != None)
		SetFocusWindow(winButtons[0]);
}

function StartClose()
{
	if (bClosing)
		return;
	bClosing = True;
	CloseT = 0;
	if (RIRootWindow(root) != None)
		RIRootWindow(root).BeginResume();
}

function float CloseK()
{
	if (!bClosing)
		return 1.0;
	return 1.0 - Class'RIUtil'.static.Phase(CloseT, 0.0, CloseTime);
}

function bool ButtonActivated(Window buttonPressed)
{
	if (bClosing)
		return True;
	if (bInGame && (buttonPressed == winButtons[7]))
	{
		StartClose();
		return True;
	}
	if ((btnMainMenu != None) && (buttonPressed == btnMainMenu))
	{
		bAskMainMenu = True;
		root.MessageBox(MainMenuTitle, MainMenuPrompt, 0, False, Self);
		return True;
	}
	return Super.ButtonActivated(buttonPressed);
}

event bool BoxOptionSelected(Window button, int buttonNumber)
{
	if (!bAskMainMenu)
		return Super.BoxOptionSelected(button, buttonNumber);

	bAskMainMenu = False;
	root.PopWindow();
	if ((buttonNumber == 0) && (RIRootWindow(root) != None))
		RIRootWindow(root).RequestMainMenu();
	return True;
}

event bool VirtualKeyPressed(EInputKey key, bool bRepeat)
{
	if (bClosing)
		return True;

	// The title card is up: any key dismisses it
	if ((TitleCard != None) && !TitleCard.bDone)
	{
		if (!IsKeyDown(IK_Alt) && !IsKeyDown(IK_Ctrl))
			TitleCard.Dismiss();
		return True;
	}

	// Title screen: there's no game to go back to, so Escape stays here
	// (AE would close the menu and leave the bare 3D logo scene)
	if ((key == IK_Escape) && (RIRootWindow(root) != None) && RIRootWindow(root).IsIntroMap())
		return True;
	if (bInGame && (key == IK_Escape))
	{
		StartClose();
		return True;
	}
	return Super.VirtualKeyPressed(key, bRepeat);
}

// No title bar, frame, shadow or button bar: DrawWindow paints everything.
function CreateControls()
{
}

// The version string is drawn in DrawWindow instead of a TextWindow.
function ShowVersionInfo()
{
}

function CreateMenuButtons()
{
	local int i;

	for (i = 0; i < arrayCount(buttonDefaults); i++)
	{
		if (ButtonNames[i] == "")
			break;

		winButtons[i] = MenuUIMenuButtonWindow(NewChild(Class'RIMenuButton'));
		winButtons[i].SetButtonText(ButtonNames[i]);
		RIMenuButton(winButtons[i]).TextScale = 1.25;
	}

	btnMainMenu = RIMenuButton(NewChild(Class'RIMenuButton'));
	btnMainMenu.SetButtonText(MainMenuLabel);
	btnMainMenu.TextScale = 1.25;
}

// Buttons that only make sense on the title screen: New Game, Training,
// Play Intro, Credits
function bool OnlyOnTitle(int idx)
{
	return (idx == 0) || (idx == 4) || (idx == 5) || (idx == 6);
}

// Buttons that only make sense during a game: Save Game, Back to Game
function bool OnlyInGame(int idx)
{
	return (idx == 1) || (idx == 7);
}

// A game is running unless this is the title map (mission number below 0)
function bool GameRunning()
{
	local DeusExLevelInfo info;

	if (player == None)
		return False;
	info = player.GetLevelInfo();
	return (info == None) || (info.MissionNumber >= 0);
}

event ParentRequestedPreferredSize(bool bWidthSpecified, out float preferredWidth,
                                   bool bHeightSpecified, out float preferredHeight)
{
	preferredWidth  = root.width;
	preferredHeight = root.height;
}

function ConfigurationChanged()
{
	local int i, idx, slot;
	local RIMenuButton btn;

	S         = height / 1080.0;
	PanelW    = 640 * S;
	MenuX     = 96 * S;
	MenuY     = 400 * S;
	MenuW     = 430 * S;
	ButtonH   = 50 * S;
	ButtonGap = 6 * S;

	bHasGame = GameRunning();
	slot = 0;
	for (i = 0; i < arrayCount(DisplayOrder); i++)
	{
		idx = DisplayOrder[i];
		if ((idx < 0) || (winButtons[idx] == None))
			continue;

		// During a game: no New Game / Training / Play Intro (Main Menu leads there)
		if ((bHasGame && OnlyOnTitle(idx)) || (!bHasGame && OnlyInGame(idx)))
		{
			Class'RISkin'.static.SafeHide(winButtons[idx]);
			continue;
		}

		btn = RIMenuButton(winButtons[idx]);

		// Exit sits alone in the bottom-right corner
		if (idx == 9)
		{
			btn.bAlignRight = True;
			btn.Slot = 9;
			btn.ConfigureChild(width - 96 * S - 300 * S, height - 48 * S - ButtonH, 300 * S, ButtonH);
			continue;
		}

		btn.Slot = slot;
		btn.ConfigureChild(MenuX, MenuY + slot * (ButtonH + ButtonGap), MenuW, ButtonH);
		slot++;
	}

	// Main Menu goes last in the list, only while a game is running
	if (btnMainMenu != None)
	{
		if (bHasGame)
		{
			btnMainMenu.Slot = slot;
			btnMainMenu.ConfigureChild(MenuX, MenuY + slot * (ButtonH + ButtonGap), MenuW, ButtonH);
		}
		else
			Class'RISkin'.static.SafeHide(btnMainMenu);
	}

	// GMDX has no multiplayer; hide the button instead of showing it greyed out
	if (winButtons[8] != None)
		Class'RISkin'.static.SafeHide(winButtons[8]);
}

event Tick(float deltaSeconds)
{
	local int i;

	AnimTime += deltaSeconds;

	if (!bTitleChecked && (player != None))
	{
		bTitleChecked = True;
		if (!bInGame && !GameRunning() && !Class'RITitleCard'.default.bShown)
		{
			TitleCard = RITitleCard(NewChild(Class'RITitleCard'));
			TitleCard.Menu = Self;
			TitleCard.SetConfiguration(0, 0, width, height);
		}
	}

	// GMDX has no multiplayer: hidden once the engine has readied the button
	if ((winButtons[8] != None) && winButtons[8].IsVisible(False))
		Class'RISkin'.static.SafeHide(winButtons[8]);
	if (!bHasGame && (btnMainMenu != None) && btnMainMenu.IsVisible(False))
		Class'RISkin'.static.SafeHide(btnMainMenu);
	for (i = 0; i < arrayCount(winButtons); i++)
		if (((bHasGame && OnlyOnTitle(i)) || (!bHasGame && OnlyInGame(i))) && (winButtons[i] != None) && winButtons[i].IsVisible(False))
			Class'RISkin'.static.SafeHide(winButtons[i]);

	if (bClosing)
	{
		CloseT += deltaSeconds;
		for (i = 0; i < arrayCount(winButtons); i++)
			if (RIMenuButton(winButtons[i]) != None)
				RIMenuButton(winButtons[i]).ParentFade = CloseK();
		if (btnMainMenu != None)
			btnMainMenu.ParentFade = CloseK();

		// Animation done: now actually return to the game (AE's Back to Game)
		if ((CloseT >= CloseTime) && !bCloseDone)
		{
			bCloseDone = True;
			Super.ButtonActivated(winButtons[7]);
		}
	}
}

// ----------------------------------------------------------------------
// DrawLogo: two-pass composite (knock out the shape, then add the colour).
// The knockout appears first and the colour fades in over it, so the logo
// "powers on" during the intro.
// ----------------------------------------------------------------------

function DrawLogo(GC gc, float X, float Y, float W, float H, float Bright)
{
	gc.SetStyle(DSTY_Modulated);
	Class'RIText'.static.Tex(gc, X, Y, W, H, 0, 0, 1024, 813, Texture'ReimaginedUI.UI.RI_LogoMask');

	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(255 * Bright, 255 * Bright, 255 * Bright));
	Class'RIText'.static.Tex(gc, X, Y, W, H, 0, 0, 1024, 813, Texture'ReimaginedUI.UI.RI_LogoAdd');
}

// ----------------------------------------------------------------------
// DrawPauseMenu: the in-game version. The root draws the faded game behind;
// here only the panel and logo, quicker, and reversing when closing.
// ----------------------------------------------------------------------

function DrawPauseMenu(GC gc)
{
	local float k, panelT, panelX, logoT;

	k = CloseK();
	panelT = Class'RIUtil'.static.Phase(AnimTime, 0.0, 0.24) * k;
	panelX = -PanelW * (1.0 - panelT);

	// Solid dark panel (as the mockup): the game shows only faintly through,
	// a gentle lighter shade inside on the left, a crisp blue edge and a
	// soft glow beyond it
	if (panelT > 0.02)
	{
		Class'RISkin'.static.DrawDim(gc, panelX, 0, PanelW, height, panelT);
		Class'RISkin'.static.DrawDim(gc, panelX, 0, PanelW, height, 0.6 * panelT);
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(Class'RIUtil'.static.Col(3 * panelT, 4 * panelT, 14 * panelT));
		Class'RIText'.static.Fill(gc, panelX, 0, PanelW, height);
		gc.SetTileColor(Class'RIUtil'.static.Col(4 * panelT, 5 * panelT, 16 * panelT));
		Class'RIText'.static.Tex(gc, panelX, 0, PanelW, height, 0, 0, 256, 8, Texture'ReimaginedUI.UI.RI_EdgeGlow');

		Class'RIText'.static.VLine(gc, panelX + PanelW - 1.0, 0, height, Class'RIUtil'.static.Col(59 * panelT, 63 * panelT, 196 * panelT));
		Class'RIText'.static.VLine(gc, panelX + PanelW - 2.0, 0, height, Class'RIUtil'.static.Col(40 * panelT, 43 * panelT, 140 * panelT));
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(Class'RIUtil'.static.Col(9 * panelT, 10 * panelT, 36 * panelT));
		Class'RIText'.static.Tex(gc, panelX + PanelW, 0, 30 * S, height, 0, 0, 256, 8, Texture'ReimaginedUI.UI.RI_EdgeGlow');
	}

	logoT = Class'RIUtil'.static.Phase(AnimTime, 0.04, 0.3) * k;
	if (logoT > 0.02)
		DrawLogo(gc, 80 * S + panelX, (40 - 14 * (1.0 - logoT)) * S, 400 * S, 318 * S, logoT);

	Class'RIText'.static.Draw(gc, Class'RIFontSmall', 96 * S + panelX, height - 70 * S,
		Caps(Class'RIBase'.static.VersionText(Self, player)), Class'RIUtil'.static.Col(120 * panelT, 126 * panelT, 196 * panelT));

	DrawNativeStatus(gc, panelT);
}

// ----------------------------------------------------------------------
// DrawWindow: painted behind the button children
// ----------------------------------------------------------------------

event DrawWindow(GC gc)
{
	local float fade, zoom, baseW, artW, artH, artX, artY;
	local float panelT, panelX, logoT, beam;

	Class'RITheme'.static.SetMode(3);   // menu theme; the main menu keeps its own look in every UI style

	fade = Class'RIUtil'.static.Phase(AnimTime, 0.0, 0.9);

	gc.EnableSmoothing(True);

	if (bInGame)
	{
		DrawPauseMenu(gc);
		return;
	}

	// Base
	gc.SetStyle(DSTY_Normal);
	gc.SetTileColor(Class'RIUtil'.static.Col(255 * fade, 255 * fade, 255 * fade));
	Class'RIText'.static.Tex(gc, 0, 0, width, height, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Navy');

	// Key art: fills the height, right-aligned, eases in from 6% zoom
	zoom = 1.0 + 0.06 * (1.0 - Class'RIUtil'.static.Phase(AnimTime, 0.0, 1.6));
	baseW = height * (KeyArtSrcW / KeyArtSrcH);
	artW = baseW * zoom;
	artH = height * zoom;
	artX = width - baseW - (artW - baseW) * 0.5;   // zoom around the art's centre
	artY = -(artH - height) * 0.2;                 // keep JC's head near the top
	Class'RISkin'.static.DrawKeyArt(gc, artX, artY, artW, artH);

	// Breathing light beam over JC's head
	beam = (0.55 + 0.25 * Sin(AnimTime * 1.4)) * fade;
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(70 * beam, 74 * beam, 170 * beam));
	Class'RIText'.static.Tex(gc, artX + artW * 0.42, artY, artW * 0.16, height * 0.5, 0, 0, 64, 256, Texture'ReimaginedUI.UI.RI_Beam');

	// Fade the art's left edge and bottom into the dark
	gc.SetStyle(DSTY_Modulated);
	Class'RIText'.static.Tex(gc, artX, 0, artW * 0.28, height, 2, 0, 252, 8, Texture'ReimaginedUI.UI.RI_FadeH');
	Class'RIText'.static.Tex(gc, 0, height * 0.62, width, height * 0.38, 0, 2, 8, 252, Texture'ReimaginedUI.UI.RI_FadeV');

	// Left panel slides in: solid navy so the art behind can't show through
	// unevenly, with a soft gradient and a glowing edge
	panelT = Class'RIUtil'.static.Phase(AnimTime, 0.1, 0.55);
	panelX = -PanelW * (1.0 - panelT);
	gc.SetStyle(DSTY_Normal);
	gc.SetTileColor(Class'RIUtil'.static.Col(150 * fade, 150 * fade, 150 * fade));
	Class'RIText'.static.Tex(gc, panelX, 0, PanelW, height, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Navy');
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(10 * panelT, 11 * panelT, 40 * panelT));
	Class'RIText'.static.Tex(gc, panelX, 0, PanelW, height, 0, 0, 256, 8, Texture'ReimaginedUI.UI.RI_EdgeGlow');

	Class'RIText'.static.VLine(gc, panelX + PanelW - 0.5, 0, height, Class'RIUtil'.static.Col(90 * panelT, 94 * panelT, 200 * panelT));
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(16 * panelT, 17 * panelT, 60 * panelT));
	Class'RIText'.static.Tex(gc, panelX + PanelW, 0, 34 * S, height, 0, 0, 256, 8, Texture'ReimaginedUI.UI.RI_EdgeGlow');

	// Logo drops in
	logoT = Class'RIUtil'.static.Phase(AnimTime, 0.3, 0.6);
	if (logoT > 0)
		DrawLogo(gc, 80 * S, (40 - 24 * (1.0 - logoT)) * S, 400 * S, 318 * S, logoT);

	// Faint scanlines
	gc.SetStyle(DSTY_Modulated);
	Class'RIText'.static.Pat(gc, 0, 0, width, height, 0, 0, Texture'ReimaginedUI.UI.RI_Scan');


	// Version string, bottom-left
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', 96 * S, height - 70 * S,
		Caps(Class'RIBase'.static.VersionText(Self, player)), Class'RIUtil'.static.Col(120 * panelT, 126 * panelT, 196 * panelT));

	DrawNativeStatus(gc, panelT);
}

// Plugin proof of life: calls into RINative.dll. If this line shows
// "RINATIVE 0.1  PING 41", the native library loaded and script <-> C++ works.
function DrawNativeStatus(GC gc, float a)
{
	local string BuildLine;
	local float sc, w;

	BuildLine = "REIMAGINED UI BUILD " $ Class'RIBuildInfo'.default.BuildNumber;
	if (Class'RIBuildInfo'.default.BuildTime != "")
		BuildLine = BuildLine $ "  |  " $ Class'RIBuildInfo'.default.BuildTime;
	BuildLine = BuildLine $ "  |  " $ Caps(Class'RINative'.static.RINativeVersion()) $ "  PING " $ Class'RINative'.static.RINativePing(20);

	// Shrinks to stay inside the panel (the vanilla version line is longer)
	sc = 1.0;
	w = Class'RIText'.static.Width(Class'RIFontSmall', BuildLine);
	if (w > PanelW - 120 * S)
		sc = (PanelW - 120 * S) / w;
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', 96 * S, height - 46 * S, BuildLine,
		Class'RIUtil'.static.Col(95 * a, 200 * a, 255 * a), sc);
}

defaultproperties
{
     DisplayOrder(0)=7
     DisplayOrder(1)=0
     DisplayOrder(2)=1
     DisplayOrder(3)=2
     DisplayOrder(4)=3
     DisplayOrder(5)=4
     DisplayOrder(6)=5
     DisplayOrder(7)=6
     DisplayOrder(8)=9
     DisplayOrder(9)=-1
     MainMenuLabel="Main Menu"
     MainMenuTitle="Return to Main Menu"
     MainMenuPrompt="Leave this game and return to the main menu? Anything since your last save will be lost."
}
