//=============================================================================
// RIRootWindow
// Drop-in replacement for DeusExRootWindow (set Root= in the add-on's ini).
// Every AE screen is opened through PushWindow, so this is where:
//   - screens with a bespoke reimagined version are swapped in (RemapScreen)
//   - settings screens get a native RIPanel (inside the settings layout)
//   - every other AE menu screen is restyled in place (RISkin + RIScreenFrame)
// and DrawWindow paints the key-art backdrop behind menu screens.
// GMDX AE itself is never modified.
//=============================================================================
class RIRootWindow extends DeusExRootWindow;

var float BackdropTime;

// In-game menu fade (see DrawWindow)
var float MenuFade;         // 0 = game visible, 1 = menus fully faded in
var bool  bResuming;        // the pause menu is animating out
var bool  bIntroKnown, bIntroMap;
var bool  bGoMainMenu;
var globalconfig bool bAppliedGoldHUD;   // the HUD was switched to the original gold once      // the pause menu asked to return to the title map
// Speech held while paused: a playing sound runs on under a pause in this
// engine, so the current InfoLink / conversation line is stopped on pause
// and replayed from its start (with a fresh timer) on resume. 0 InfoLink, 1 conversation
var ConEventSpeech HeldSpeech[2];
// Settings > Interface: each part can use GMDX AE's own (classic) UI
var globalconfig bool bClassicMenus;
var globalconfig bool bClassicScreens;
var globalconfig bool bClassicDialogue;
var globalconfig bool bHudSway;          // the HUD trails the view a little and bobs with walking
var globalconfig int  HudTilt;           // 3D HUD: the side panels turned toward the eye. 0 flat, 1 tilted, 2 deep
var globalconfig bool bConBars;          // keep the black letterbox bars in conversations
var globalconfig int  SubColors;         // speaker colours in subtitles: 0 off, 1 names, 2 names and lines
var globalconfig bool bClassicHUD;
// Settings > Interface: original (not 4x HD) textures, and the in-game screen style (0 Sleek, 1 Vanilla+)
var globalconfig bool bNoHDTextures;
var globalconfig int  ScreenStyle;
// Checkpoints (the death screen's Last Checkpoint / Restart Mission): saved
// by the mod into two save slots of their own
var globalconfig int  CkptMission;      // mission whose start is in the mission-start slot
var globalconfig bool bHasCkpt, bHasMissionCkpt;
var globalconfig float PersonaScale;
var globalconfig float HudScale;       // the rebuilt HUD's size (0 = 1)
var globalconfig float SubScale;
var globalconfig float BeltScale;      // the hotbar's size, on top of the HUD size (0 = 1)       // subtitles' size (0 = 1)   // Vanilla+ in-game screens: board size (0.75 .. 1)
var RIHud   HudView;
var float  ThemeAge;
var float  DeathLoadT;       // a choice was made on the death screen
var RIDeathScreen DeathBox;  // the death screen's window, while it is up
var int    BeltCursor;      // the belt slot the wheel is on (an empty slot holds nothing to read it from)
var localized string DeathTitle, DeathLoadLast, DeathLoadGame, DeathMainMenu, DeathWaitLabel;
var localized string DeathCheckpoint, DeathRestart, CkptTitle, MissionStartTitle;
var LevelInfo CkptLevel;     // the level the last arrival was noticed in
var float CkptWait;          // time since arriving, toward the checkpoint save
var int   CkptStep;          // 0 nothing to save, 1 mission start then checkpoint, 2 checkpoint
const CKPT_SLOT = 998;       // save slots of their own (AE refuses 1000 and up)
const MISSION_SLOT = 997;
var float  DrawClock;        // advances per drawn frame (loading screens' wheel)         // re-read the colour themes a few times a second          // the rebuilt HUD, over AE's
var bool    bHudRestored;     // AE's own HUD pieces were brought back (classic)
var bool  bAEMask;          // AE asked for its darkening mask (UI screens over the game)

// Debug overlay (Ctrl+F10): drawn last, over everything, from PostDrawWindow.
// It creates no windows of its own, so it can't disturb the window tree.
var bool   bDebug;
var float  DebugFrameTime;  // smoothed seconds per frame
var Window DebugBox;        // test dialog opened from the overlay

// initCount guard (see GuardInitCount)
var int    InitFixes;       // corrections made this session
var Window ConHid[2];     // conversation windows hidden under the pause menu
var int    InitDumps;       // window-tree dumps written for them (capped)

event InitWindow()
{
	Super.InitWindow();
	bTickEnabled = True;
	ReplaceHud();

	// The scope / binocular view, restyled (AE's under the classic options)
	if (scopeView != None)
		scopeView.Destroy();
	scopeView = DeusExScopeView(NewChild(Class'RIScopeView', False));
	scopeView.SetWindowAlignments(HALIGN_Full, VALIGN_Full, 0, 0);

	ApplyCursor(Self);
}

// The rebuilt arrow cursor (tip at 32,32 of its 64 x 64 texture), tinted
// like AE's; set on the root and on every screen pushed (AE's screens set
// their own in StyleChanged)
function ApplyCursor(Window W)
{
	if (W == None)
		return;
	if (bClassicMenus && bClassicScreens)
		return;
	W.SetDefaultCursor(Texture'ReimaginedUI.UI.RI_Cursor', None, 32, 32, Class'RIUtil'.static.Raw(255, 241, 214));
}

// Swap AE's DeusExHUD (just made by Super.InitWindow) for RIDeusExHUD, which
// is the same HUD but never lets the pieces RIHud replaces show (no flicker)
// and moves its pop-ups (InfoLink, log...) clear of the new HUD
function ReplaceHud()
{
	local DeusExPlayer P;

	P = DeusExPlayer(parentPawn);
	if ((P == None) || (RIDeusExHUD(hud) != None))
		return;
	if (hud != None)
		hud.Destroy();
	hud = DeusExHUD(NewChild(Class'RIDeusExHUD'));
	RIDeusExHUD(hud).bRI = !bClassicHUD;
	hud.UpdateSettings(P);
	hud.SetWindowAlignments(HALIGN_Full, VALIGN_Full, 0, 0);
	hud.Lower();
	if (actorDisplay != None)
		actorDisplay.Lower();
}

// Conversations are created by AE's ConPlay with NewChild, not PushWindow:
// look for them here and give each its RIConView (drawn to the Dialogue mockup)
// The rebuilt HUD sits over AE's (which keeps running underneath). With
// Settings > Interface > HUD on Classic it is removed and AE's pieces return.
function AttachHud()
{
	if ((hud == None) || (DeusExPlayer(parentPawn) == None))
		return;
	if (RIDeusExHUD(hud) != None)
		RIDeusExHUD(hud).SetRI(!bClassicHUD);
	if (bClassicHUD)
	{
		if (HudView != None)
		{
			HudView.Destroy();
			HudView = None;
		}
		if (!bHudRestored)
		{
			hud.UpdateSettings(DeusExPlayer(parentPawn));
			bHudRestored = True;
		}
		return;
	}
	bHudRestored = False;
	if ((HudView == None) || (HudView.GetParent() != hud))
	{
		HudView = RIHud(hud.NewChild(Class'RIHud'));
		HudView.SetConfiguration(0, 0, hud.width, hud.height);
		HudView.Lower();      // under AE's pop-ups (InfoLink, log, received items)
	}
}

function AttachConViews()
{
	local Window C, D;
	local bool bHas;
	local RIConView V;

	if (bClassicDialogue)
		return;
	for (C = GetTopChild(); C != None; C = C.GetLowerSibling())
	{
		if (ConWindowActive(C) == None)
			continue;
		bHas = False;
		for (D = C.GetTopChild(); D != None; D = D.GetLowerSibling())
			if (RIConView(D) != None)
				bHas = True;
		if (!bHas)
		{
			V = RIConView(C.NewChild(Class'RIConView'));
			V.AttachTo(ConWindowActive(C));
		}
	}
}

// Once, on first run with this mod: switch the HUD to AE's "Amber" theme,
// the original game's gold. After that it's an ordinary setting
// (Settings > Colors) and is never changed again by this mod.
function ApplyGoldHUD()
{
	local DeusExPlayer P;

	if (bAppliedGoldHUD)
		return;
	P = DeusExPlayer(parentPawn);
	if ((P == None) || (P.ThemeManager == None))
		return;
	bAppliedGoldHUD = True;
	SaveConfig();
	// The base's gold theme (GMDX's Amber); a base without one keeps its own
	if (Class'RIBase'.static.ApplyGoldTheme(P))
		ChangeStyle();
}

// Called by the pause menu's "Main Menu" button (after its confirmation).
// Done here on the next tick, because closing the menus destroys the window
// that asked.
function UIPauseGame()
{
	local bool bWas;

	bWas = bUIPaused;
	Super.UIPauseGame();
	if (!bWas && bUIPaused)
	{
		HoldSpeech();
		HideConWins();
	}
}

// The conversation's windows sit above the root's dim and snapshot, so the
// menu over them looked see-through: hide them while paused, back on resume
function HideConWins()
{
	local DeusExPlayer P;

	ConHid[0] = None;
	ConHid[1] = None;
	P = DeusExPlayer(parentPawn);
	if ((P == None) || (P.conPlay == None))
		return;
	if ((P.conPlay.conWinThird != None) && P.conPlay.conWinThird.IsVisible())
	{
		ConHid[0] = P.conPlay.conWinThird;
		ConHid[0].Hide();
	}
	if ((P.conPlay.conWinFirst != None) && P.conPlay.conWinFirst.IsVisible())
	{
		ConHid[1] = P.conPlay.conWinFirst;
		ConHid[1].Hide();
	}
}

function ShowConWins()
{
	local DeusExPlayer P;
	local int i;

	P = DeusExPlayer(parentPawn);
	for (i = 0; i < 2; i++)
	{
		if ((ConHid[i] != None) && (P != None) && (P.conPlay != None) && !P.conPlay.bEndingConversation)
			ConHid[i].Show();
		ConHid[i] = None;
	}
}

// The game re-shows the whole HUD on unpause (and when a menu's background
// mask lifts) without checking for a conversation: the original couldn't be
// paused mid-conversation. A third-person conversation keeps it hidden
// (ConPlay shows it again itself when the conversation ends).
function ShowHud(bool bShow)
{
	if (bShow && InThirdPersonCon())
	{
		if (hud != None)
			hud.Hide();
		return;
	}
	Super.ShowHud(bShow);
}

function bool InThirdPersonCon()
{
	local DeusExPlayer P;

	P = DeusExPlayer(parentPawn);
	return (P != None) && (P.conPlay != None) && !P.conPlay.bEndingConversation
		&& (P.conPlay.GetDisplayMode() == DM_ThirdPerson);
}

function UnPauseGame()
{
	Super.UnPauseGame();
	ShowConWins();
	ResumeSpeech();
}

function HoldSpeech()
{
	local DeusExPlayer P;

	HeldSpeech[0] = None;
	HeldSpeech[1] = None;
	P = DeusExPlayer(parentPawn);
	if (P == None)
		return;
	if ((P.dataLinkPlay != None) && (ConEventSpeech(P.dataLinkPlay.currentEvent) != None) && (P.dataLinkPlay.playingSoundId != 0))
	{
		HeldSpeech[0] = ConEventSpeech(P.dataLinkPlay.currentEvent);
		P.StopSound(P.dataLinkPlay.playingSoundId);
	}
	if ((P.conPlay != None) && (ConEventSpeech(P.conPlay.currentEvent) != None) && (P.conPlay.playingSoundId != 0))
	{
		HeldSpeech[1] = ConEventSpeech(P.conPlay.currentEvent);
		P.StopSound(P.conPlay.playingSoundId);
	}
}

function ResumeSpeech()
{
	local DeusExPlayer P;
	local int Id;

	P = DeusExPlayer(parentPawn);
	if (P != None)
	{
		if ((HeldSpeech[0] != None) && (P.dataLinkPlay != None) && (P.dataLinkPlay.currentEvent == HeldSpeech[0]))
		{
			Id = HeldSpeech[0].conSpeech.soundID;
			if (Id != -1)
			{
				P.dataLinkPlay.PlaySpeech(Id);
				P.dataLinkPlay.SetTimer(P.dataLinkPlay.con.GetSpeechLength(Id), False);
			}
		}
		if ((HeldSpeech[1] != None) && (P.conPlay != None) && (P.conPlay.currentEvent == HeldSpeech[1]))
		{
			Id = HeldSpeech[1].conSpeech.soundID;
			if (Id != -1)
			{
				P.conPlay.PlaySpeech(Id, HeldSpeech[1].Speaker);
				P.conPlay.SetTimer(P.conPlay.con.GetSpeechLength(Id), False);
			}
		}
	}
	HeldSpeech[0] = None;
	HeldSpeech[1] = None;
}

function RequestMainMenu()
{
	bGoMainMenu = True;
}

event Tick(float deltaSeconds)
{
	local DeusExPlayer DP;

	// GMDX's "menu after death" sends the player to the title map with an
	// OPEN from inside the player's own tick, the same immediate trip that
	// crashed in UnObj.cpp from the pause menu. Take it a second early,
	// queued the safe way.
	DP = DeusExPlayer(parentPawn);
	if (!bGoMainMenu && (DeathLoadT <= 0) && (DP != None) && DP.IsInState('Dying') && Class'RIUtil'.static.PBool(DP, "bRemoveVanillaDeath") && Class'RIUtil'.static.PBool(DP, "bMenuAfterDeath")
		&& (DP.Level.TimeSeconds - DP.FrobTime > 63.0) && (MenuUIWindow(GetTopWindow()) == None) && (ToolWindow(GetTopWindow()) == None))
	{
		Log("RI: death - to the main menu (queued)");
		RequestMainMenu();
	}

	if (bGoMainMenu)
	{
		bGoMainMenu = False;
		bIntroKnown = False;
		Log("RI: returning to the main menu");
		ClearWindowStack();
		Class'RIHD'.static.Reset();
		// Queue the trip the way AE does (credits, quotes, splash): the engine
		// changes maps between frames. An immediate OPEN from inside this
		// tick tore the old level down mid-update and crashed in UnObj.cpp
		// An absolute trip with nothing carried over, the way a saved game
		// is loaded (SendPlayer carried the player's inventory into the
		// title map, which it can't hold)
		if (parentPawn != None)
			parentPawn.ClientTravel("DXOnly", TRAVEL_Absolute, False);
		return;
	}

	GuardInitCount("Tick");
	DeathTick();
	CheckpointTick(deltaSeconds);
	ApplyGoldHUD();
	Class'RITheme'.static.SetMode(0);   // colours made outside drawing stay unthemed
	ThemeAge += deltaSeconds;
	if (ThemeAge > 0.25)
	{
		ThemeAge = 0;
		Class'RITheme'.static.Refresh(DeusExPlayer(parentPawn));
	}
	ConsoleText();
	AttachConViews();
	AttachHud();
	BackdropTime += deltaSeconds;
	DebugFrameTime += (deltaSeconds - DebugFrameTime) * 0.05;

	if (winCount <= 0)
	{
		MenuFade = 0;
		bResuming = False;
		bAEMask = False;
	}
	else if (bResuming)
		MenuFade = FMax(0.0, MenuFade - deltaSeconds / 0.18);
	else
		MenuFade = FMin(1.0, MenuFade + deltaSeconds / 0.28);
}

// The engine console's own LOADING / SAVING / PRECACHING / PAUSED text is
// replaced by RILoading's screens; with the HUD on Classic it comes back
function ConsoleText()
{
	local PlayerPawn P;
	local Console Con;

	P = parentPawn;
	if ((P == None) || (P.Player == None) || (P.Player.Console == None))
		return;
	Con = P.Player.Console;
	if (bClassicHUD)
	{
		Con.LoadingMessage = Con.default.LoadingMessage;
		Con.SavingMessage = Con.default.SavingMessage;
		Con.PrecachingMessage = Con.default.PrecachingMessage;
		Con.PausedMessage = Con.default.PausedMessage;
	}
	else
	{
		Con.LoadingMessage = "";
		Con.SavingMessage = "";
		Con.PrecachingMessage = "";
		Con.PausedMessage = "";
	}
}

// Title map (cached: AtIntroMap searches the level's actors)
function bool IsIntroMap()
{
	if (!bIntroKnown)
	{
		if (parentPawn == None)
			return False;           // too early to tell; ask again later
		bIntroMap = AtIntroMap();
		bIntroKnown = True;
	}
	return bIntroMap;
}

// Menus shown over the paused game, rather than over the key-art backdrop.
// AE's "UI/Menu Background": 0 Render 3D, 1 Snapshot (both keep the game
// behind the menus), 2 Black (no game to show: use the key art).
function bool InGameMenus()
{
	if (IsIntroMap())
		return False;
	if ((DeusExPlayer(parentPawn) != None) && (DeusExPlayer(parentPawn).UIBackground == 2))
		return False;
	return True;
}

function float MenuFadeEased()
{
	return Class'RIUtil'.static.EaseOut(MenuFade);
}

function BeginResume()
{
	bResuming = True;
}

// AE darkens the game behind menus instantly with a mask; the fade in
// DrawWindow replaces it in game (the title map keeps AE's behaviour).
function MaskBackground(bool bMask)
{
	Super.MaskBackground(bMask);
	bAEMask = bMask;
	if (bMask && !IsIntroMap())
		SetBackground(None);
}

// In-game devices (keypads, computers, ATMs, bots) get the rebuilt look in
// the Sleek and Modern styles; Vanilla+ has its own, Classic keeps AE's
function bool IsDeviceStyle()
{
	return !bClassicScreens && !Class'RIPersonaView'.default.bClassic && (ScreenStyle != 1);
}

// Vanilla+ devices: the game's own computer screens, recoloured (RITerminalSkin.bVP)
function bool IsVPDeviceStyle()
{
	return !bClassicScreens && !Class'RIPersonaView'.default.bClassic && (ScreenStyle == 1);
}

// A device window at the top of the stack: dimmed plainly, no menu glow
function bool IsDeviceWindow(Window W)
{
	return Class'RIBase'.static.IsKeypadWindow(W) || (RIRechargeWindow(W) != None) || ((NetworkTerminal(W) != None) && IsDeviceStyle());
}

function Class<DeusExBaseWindow> RemapScreen(Class<DeusExBaseWindow> Requested)
{
	// In-game devices rebuilt natively, Sleek style only for now (Vanilla+
	// and Classic screens keep AE's own until they get their own design)
	// The rebuilt keypad has a Vanilla+ look too (framed, same fonts)
	if (!bClassicScreens && !Class'RIPersonaView'.default.bClassic && (ScreenStyle == 1))
	{
		if (Class'RIBase'.static.KeypadClass(Requested) != None)
			return Class'RIBase'.static.KeypadClass(Requested);
	}
	if (IsDeviceStyle())
	{
		if (Class'RIBase'.static.KeypadClass(Requested) != None)
			return Class'RIBase'.static.KeypadClass(Requested);
		if (Requested == Class'DeusEx.NetworkTerminalPersonal')
			return Class'RITermPersonal';
		if (Requested == Class'DeusEx.NetworkTerminalPublic')
			return Class'RITermPublic';
		if (Requested == Class'DeusEx.NetworkTerminalSecurity')
			return Class'RITermSecurity';
		if (Requested == Class'DeusEx.ATMWindow')
			return Class'RITermATM';
		if (Requested == Class'DeusEx.HUDRechargeWindow')
			return Class'RIRechargeWindow';
	}

	// Classic menus: AE's own, plus the Interface entry in its settings list
	if (bClassicMenus)
	{
		if (Requested == Class'DeusEx.MenuSettings')
			return Class'RIMenuSettingsClassic';
		return Requested;
	}
	if (Requested == Class'DeusEx.MenuMain')
		return Class'RIMenuMain';
	if (Requested == Class'DeusEx.MenuSettings')
		return Class'RIMenuSettings';
	if (Requested == Class'DeusEx.MenuScreenCustomizeKeys')
		return Class'RIMenuScreenCustomizeKeys';
	if (Requested == Class'DeusEx.MenuUIMessageBoxWindow')
		return Class'RIMessageBox';
	if (Requested == Class'DeusEx.MenuSelectDifficulty')
		return Class'RIMenuSelectDifficulty';
	if (Requested == Class'DeusEx.MenuScreenNewGame')
		return Class'RIMenuScreenNewGame';
	if (Requested == Class'DeusEx.CreditsWindow')
		return Class'RICreditsWindow';

	return Requested;
}

// The settings layout, if it is open anywhere in the window stack
function RIMenuSettings FindSettingsShell()
{
	local int i;

	for (i = 0; i < winCount; i++)
		if (RIMenuSettings(winStack[i]) != None)
			return RIMenuSettings(winStack[i]);
	return None;
}

// True when W was opened from another option screen (so it gets a Back button)
function bool IsSubScreen(Window W)
{
	local int i;

	for (i = 1; i < winCount; i++)
		if (winStack[i] == W)
			return MenuUIScreenWindow(winStack[i - 1]) != None;
	return False;
}

function DeusExBaseWindow PushWindow(
	Class<DeusExBaseWindow> newWindowClass,
	optional Bool hideCurrentWin,
	optional Bool bNoPause)
{
	local DeusExBaseWindow NewWin;
	local RIScreenFrame Frame;
	local RIMenuSettings Shell;
	local RIPanel Panel;
	local RISaveView SaveView;
	local RIPersonaView Persona;
	local Class<RIPersonaView> PersonaClass;
	local Class<DeusExBaseWindow> Cls;
	local RITerminalSkin TermSkin;

	Cls   = RemapScreen(newWindowClass);
	Shell = FindSettingsShell();

	// Inside settings, a screen opened from another screen replaces it in
	// the content panel instead of stacking on top of it
	if ((Shell != None) && (GetTopWindow() != Shell) && (MenuUIScreenWindow(GetTopWindow()) != None)
		&& ClassIsChildOf(Cls, Class'MenuUIScreenWindow'))
		hideCurrentWin = True;

	NewWin = Super.PushWindow(Cls, hideCurrentWin, bNoPause);
	if (NewWin == None)
	{
		GuardInitCount("Push");
		return None;
	}
	ApplyCursor(NewWin);

	// Computers and ATMs (Sleek): AE's screens, re-skinned in gold from inside
	if ((NetworkTerminal(NewWin) != None) && IsDeviceStyle())
	{
		TermSkin = RITerminalSkin(NewWin.NewChild(Class'RITerminalSkin'));
		TermSkin.Term = NetworkTerminal(NewWin);
		TermSkin.SetConfiguration(0, 0, NewWin.width, NewWin.height);
		TermSkin.Lower();
		GuardInitCount("Push " $ ClassOf(NewWin));
		return NewWin;
	}

	// Computers and ATMs (Vanilla+): the game's own screens, recoloured to
	// the HUD theme
	if ((NetworkTerminal(NewWin) != None) && IsVPDeviceStyle())
	{
		TermSkin = RITerminalSkin(NewWin.NewChild(Class'RITerminalSkin'));
		TermSkin.bVP = True;
		TermSkin.Term = NetworkTerminal(NewWin);
		TermSkin.SetConfiguration(0, 0, NewWin.width, NewWin.height);
		TermSkin.Lower();
		GuardInitCount("Push " $ ClassOf(NewWin));
		return NewWin;
	}

	// Classic in-game screens: AE's own pages, untouched
	if (bClassicScreens && (PersonaScreenBaseWindow(NewWin) != None))
	{
		GuardInitCount("Push " $ ClassOf(NewWin));
		return NewWin;
	}

	// Classic menus: AE's own, untouched (in-game screens are handled below)
	if (bClassicMenus && (PersonaScreenBaseWindow(NewWin) == None))
	{
		GuardInitCount("Push " $ ClassOf(NewWin));
		return NewWin;
	}

	// In-game screens rebuilt natively (more join this list as they're done)
	PersonaClass = None;
	if (Class'RIPersonaView'.default.bClassic)
		PersonaClass = None;       // the player asked for AE's own pages
	else if (PersonaScreenSkills(NewWin) != None)
		PersonaClass = Class'RISkillsView';
	else if (PersonaScreenGoals(NewWin) != None)
		PersonaClass = Class'RIGoalsView';
	else if (PersonaScreenHealth(NewWin) != None)
		PersonaClass = Class'RIHealthView';
	else if (PersonaScreenAugmentations(NewWin) != None)
		PersonaClass = Class'RIAugsView';
	else if (PersonaScreenInventory(NewWin) != None)
		PersonaClass = Class'RIInventoryView';
	else if (PersonaScreenConversations(NewWin) != None)
		PersonaClass = Class'RIConsView';
	else if (PersonaScreenImages(NewWin) != None)
		PersonaClass = Class'RIImagesView';
	else if (PersonaScreenLogs(NewWin) != None)
		PersonaClass = Class'RILogsView';
	else if (NewWin.IsA('PersonaScreenOutfits'))
		PersonaClass = Class'RIOutfitView';
	if (PersonaClass != None)
	{
		NewWin.SetWindowAlignments(HALIGN_Full, VALIGN_Full);
		Persona = RIPersonaView(NewWin.NewChild(PersonaClass));
		Persona.AttachTo(PersonaScreenBaseWindow(NewWin));
		GuardInitCount("Push " $ ClassOf(NewWin));
		return NewWin;
	}

	// The other in-game screens keep AE's page for now, with the new tab row
	// (Vanilla+: every in-game screen, with its art in HD)
	if (PersonaScreenBaseWindow(NewWin) != None)
	{
		Persona = RIPersonaView(NewWin.NewChild(Class'RIPersonaTabs'));
		Persona.AttachTo(PersonaScreenBaseWindow(NewWin));
		GuardInitCount("Push " $ ClassOf(NewWin));
		return NewWin;
	}

	// Load / Save: full screen, drawn by RISaveView over AE's (hidden) screen
	if (MenuScreenLoadGame(NewWin) != None)
	{
		NewWin.SetWindowAlignments(HALIGN_Full, VALIGN_Full);
		SaveView = RISaveView(NewWin.NewChild(Class'RISaveView'));
		SaveView.AttachTo(MenuScreenLoadGame(NewWin));
		GuardInitCount("Push " $ ClassOf(NewWin));
		return NewWin;
	}

	// Character creation draws itself; AE's widgets only hold its state
	if (RIMenuScreenNewGame(NewWin) != None)
	{
		RIMenuScreenNewGame(NewWin).HideParts();
		GuardInitCount("Push NewGame");
		return NewWin;
	}

	// Message boxes draw themselves
	if (RIMessageBox(NewWin) != None)
	{
		GuardInitCount("Push");
		return NewWin;
	}

	if ((MenuUIWindow(NewWin) != None) && (RIMenuMain(NewWin) == None) && (RIMenuSettings(NewWin) == None)
		&& (RIMenuSelectDifficulty(NewWin) == None))
	{
		// Option screens: drawn natively, inside the settings layout or
		// framed on their own (e.g. Playthrough Modifiers)
		if (Class'RIPanel'.static.Supports(NewWin))
		{
			if (Shell != None)
				Shell.PlaceEmbedded(NewWin, True);
			else
				NewWin.SetWindowAlignments(HALIGN_Full, VALIGN_Full,
					height / 1080.0 * 200, height / 1080.0 * 80, height / 1080.0 * 200, height / 1080.0 * 80);
			Panel = RIPanel(NewWin.NewChild(Class'RIPanel'));
			Panel.AttachTo(MenuUIScreenWindow(NewWin), Shell);
			GuardInitCount("Push " $ ClassOf(NewWin));
			return NewWin;
		}

		// Everything else: AE's layout, restyled (RIScreenFrame skins it once
		// the engine has readied the screen's widgets)

		Frame = RIScreenFrame(NewWin.NewChild(Class'RIScreenFrame'));
		Frame.Screen = MenuUIWindow(NewWin);
		Frame.SetConfiguration(0, 0, NewWin.width, NewWin.height);
		Frame.Lower();

		if ((Shell != None) && (MenuUIScreenWindow(NewWin) != None))
		{
			Frame.bEmbedded = True;
			Shell.PlaceEmbedded(NewWin, False);
		}
	}

	GuardInitCount("Push " $ ClassOf(NewWin));
	return NewWin;
}

// Every screen change goes through PushWindow / PopWindow: re-check the
// engine's window count right after each one (see GuardInitCount)
function DeusExBaseWindow PopWindow(optional Bool bNoUnpause)
{
	local DeusExBaseWindow W;

	W = Super.PopWindow(bNoUnpause);
	GuardInitCount("Pop");
	return W;
}

// Screens opened from the settings layout must not hide it
function DeusExBaseWindow InvokeMenuScreen(Class<DeusExBaseWindow> newScreen, optional bool bNoPause)
{
	local DeusExBaseWindow NewWin;

	if (RIMenuSettings(GetTopWindow()) != None)
	{
		NewWin = PushWindow(newScreen, False, bNoPause);
		if (!bNoPause)
			UIPauseGame();
		return NewWin;
	}

	return Super.InvokeMenuScreen(newScreen, bNoPause);
}

// Key-art backdrop behind menu screens (the main menu draws its own).
// Message boxes don't count: in game they sit over the live view.
event DrawWindow(GC gc)
{
	local Window Top;
	local int i;

	Class'RITheme'.static.SetMode(0);


	Top = None;
	for (i = winCount - 1; i >= 0; i--)
	{
		if (RIMessageBox(winStack[i]) == None)
		{
			Top = winStack[i];
			break;
		}
	}

	// Classic menus: the original title scene; over the game, just the dim
	if (bClassicMenus && ((Top == None) || (MenuUIWindow(Top) != None)))
	{
		if ((Top != None) && InGameMenus())
			Class'RISkin'.static.DrawGameDim(gc, width, height, MenuFadeEased(), BackdropTime);
		return;
	}

	// Title map with no menu up yet (start-up): the original intro plays here
	// (the Eidos and Ion Storm logos, then the spinning Deus Ex logo), so
	// nothing is drawn over it. A click or key brings up the main menu.
	if (Top == None)
		return;

	// Inventory, augmentations and other AE UI screens: AE darkened the game
	// behind them with its mask, which MaskBackground now replaces with this fade
	if (MenuUIWindow(Top) == None)
	{
		// Vanilla+ screens draw their own plain veil; the menus' navy tint
		// and key-art ghost don't belong behind them
		if (DrawPersonaMargins(gc, Top))
			return;
		// The outfit screen renders its own 3D preview: leave it alone
		if (Top.IsA('PersonaScreenOutfits') && (bClassicScreens || Class'RIPersonaView'.default.bClassic))
			return;
		// In-game devices (keypad): a plain dim, without the menus' cool glow
		if (IsDeviceWindow(Top))
		{
			if (bAEMask && !IsIntroMap())
				Class'RISkin'.static.DrawDim(gc, 0, 0, width, height, 0.55 * MenuFadeEased());
			return;
		}
		if (bAEMask && !IsIntroMap())
			Class'RISkin'.static.DrawGameDim(gc, width, height, MenuFadeEased(), BackdropTime);
		return;
	}

	// Augmentique's Outfit Settings belongs to the in-game screens: plain dim
	if (Top.IsA('OutfitSettingsMenu') && InGameMenus())
	{
		Class'RISkin'.static.DrawDim(gc, 0, 0, width, height, 0.55 * MenuFadeEased());
		return;
	}
	if (InGameMenus())
		Class'RISkin'.static.DrawGameDim(gc, width, height, MenuFadeEased(), BackdropTime);
	else if (RIMenuMain(Top) == None)
		Class'RISkin'.static.DrawBackdrop(gc, width, height, BackdropTime);
}

// Interface sizes from Settings (unset reads as 100%)
static function float HudK()
{
	if ((default.HudScale < 0.5) || (default.HudScale > 1.5))
		return 1.0;
	return default.HudScale;
}

// The 3D HUD's tilt in degrees (Settings > Interface > HUD Depth)
static function float HudTiltDeg()
{
	if (default.HudTilt == 1)
		return 12.0;
	if (default.HudTilt >= 2)
		return 20.0;
	return 0.0;
}

static function float BeltK()
{
	if ((default.BeltScale < 0.5) || (default.BeltScale > 1.3))
		return 1.0;
	return default.BeltScale;
}

static function float SubK()
{
	if ((default.SubScale < 0.5) || (default.SubScale > 1.6))
		return 1.0;
	return default.SubScale;
}

// A Vanilla+ screen board scaled below full size: dim the margin round it
function bool DrawPersonaMargins(GC gc, Window Top)
{
	local Window C;

	if (PersonaScreenBaseWindow(Top) == None)
		return False;
	for (C = Top.GetTopChild(); C != None; C = C.GetLowerSibling())
		if (RIPersonaView(C) != None)
		{
			if (!RIPersonaView(C).VPlus() && !Class'RIModern'.static.On())
				return False;
			RIPersonaView(C).DrawVeil(gc, width, height);
			return True;
		}
	return False;
}

// ----------------------------------------------------------------------
// Debug overlay
//   Ctrl+F10  show / hide
//   Ctrl+F11  open a test dialog
//   Ctrl+F12  write the full window tree to the log (ReimaginedUI.log)
// The root sees keys before the game does (AE's Ctrl+F9 screenshot works
// the same way), so these work in game and in menus.
// ----------------------------------------------------------------------

event bool VirtualKeyPressed(EInputKey key, bool bRepeat)
{
	if (!bRepeat && DeathUp())
	{
		DeathKey(key);
		return True;
	}
	if (((key == IK_MouseWheelUp) || (key == IK_MouseWheelDown)) && WheelBelt(key))
		return True;
	if (!bRepeat && BeltToggle(key))
		return True;
	if (IsKeyDown(IK_Ctrl) && !bRepeat)
	{
		if (key == IK_F10)
		{
			bDebug = !bDebug;
			return True;
		}
		if (bDebug && (key == IK_F8))
		{
			Class'RIText'.default.bAtlasText = !Class'RIText'.default.bAtlasText;
			return True;
		}
		if (bDebug && (key == IK_F11))
		{
			DebugBox = MessageBox("Debug dialog", "Test of the Reimagined UI dialog box.|nYes and No both close it.", 0, False, Self);
			return True;
		}
		if (bDebug && (key == IK_F12))
		{
			DumpWindowTree();
			ClientMessageSafe("Window tree written to ReimaginedUI.log");
			return True;
		}
	}
	return Super.VirtualKeyPressed(key, bRepeat);
}

// ----------------------------------------------------------------------
// Mouse wheel on the belt, the way modern shooters do it: the wheel steps
// through every slot in order, and landing on an empty one puts away what's
// in hand (the original skipped empty slots). Only when the wheel is bound
// to NextBeltItem / PrevBeltItem, nothing is open, and no scope or
// binoculars want the wheel for zoom; otherwise the game handles it.
// ----------------------------------------------------------------------

// A belt slot's key while that slot's item is already in hand (or on its
// way) puts it away, as modern shooters do: 1 draws the pistol, 1 again
// holsters it. Only for keys bound to ActivateBelt, with nothing open.
function bool BeltToggle(EInputKey key)
{
	local DeusExPlayer P;
	local Inventory Cur, Item;
	local string B, KName;
	local int i, slot;

	P = DeusExPlayer(parentPawn);
	if ((P == None) || (winCount > 0) || (hud == None) || (hud.belt == None) || (P.Health <= 0))
		return False;
	KName = string(GetEnum(enum'EInputKey', key));
	if (Left(KName, 3) != "IK_")
		return False;
	B = Caps(P.ConsoleCommand("KEYBINDING " $ Mid(KName, 3)));
	i = InStr(B, "ACTIVATEBELT");
	if (i < 0)
		return False;
	B = Mid(B, i + 12);
	while (Left(B, 1) == " ")
		B = Mid(B, 1);
	if ((Left(B, 1) < "0") || (Left(B, 1) > "9"))
		return False;
	slot = int(B);
	if (P.RestrictInput() || (P.CarriedDecoration != None))
		return False;
	Cur = P.inHandPending;
	if (Cur == None)
		Cur = P.inHand;
	if (Cur == None)
		return False;
	Item = hud.belt.GetObjectFromBelt(slot);
	if ((Item == None) || (Item != Cur))
		return False;
	P.PutInHand(None);
	return True;
}

function bool WheelBelt(EInputKey key)
{
	local DeusExPlayer P;
	local Inventory Cur, Item;
	local string B, KName;
	local int dir, cnt, slot;

	P = DeusExPlayer(parentPawn);
	if ((P == None) || (winCount > 0) || (hud == None) || (hud.belt == None) || (P.Health <= 0))
		return False;
	if (key == IK_MouseWheelUp)
		KName = "MouseWheelUp";
	else
		KName = "MouseWheelDown";
	B = Caps(P.ConsoleCommand("KEYBINDING " $ KName));
	if (InStr(B, "NEXTBELTITEM") >= 0)
		dir = 1;
	else if (InStr(B, "PREVBELTITEM") >= 0)
		dir = -1;
	else
		return False;

	if (P.RestrictInput() || (P.CarriedDecoration != None))
		return True;
	Cur = P.inHandPending;
	if (Cur == None)
		Cur = P.inHand;
	if ((DeusExWeapon(Cur) != None) && DeusExWeapon(Cur).bZoomed)
		return False;
	if ((Binoculars(Cur) != None) && Binoculars(Cur).bActive)
		return False;

	if (Class'RIUtil'.static.PBool(P, "bBiggerBelt"))
		cnt = 12;
	else
		cnt = 10;
	if ((Cur != None) && Cur.bInObjectBelt && (Cur.beltPos >= 0) && (Cur.beltPos < cnt))
		slot = Cur.beltPos;
	else
		slot = Clamp(BeltCursor, 0, cnt - 1);
	slot = (slot + dir + cnt) % cnt;
	BeltCursor = slot;

	Item = hud.belt.GetObjectFromBelt(slot);
	if (Item != None)
		ActivateObjectInBelt(slot);
	else if (Cur != None)
		P.PutInHand(None);
	return True;
}

event bool BoxOptionSelected(Window box, int buttonNumber)
{
	if ((DeathBox != None) && (box == DeathBox))
	{
		DeathChoice(buttonNumber);
		return True;
	}
	if ((DebugBox != None) && (box == DebugBox))
	{
		PopWindow();
		DebugBox = None;
		return True;
	}
	return Super.BoxOptionSelected(box, buttonNumber);
}

// ----------------------------------------------------------------------
// Death screen: comes up by itself a moment after dying (no key needed) and
// replaces AE's trip through the main menu, which crashed from here.
//   Enter  load the last save (GMDX's own quick load, which waits for the
//          death animation)    L  load game    Esc  main menu
// ----------------------------------------------------------------------

function float DeathTime()
{
	local DeusExPlayer P;

	P = DeusExPlayer(parentPawn);
	if ((P == None) || !P.IsInState('Dying') || bGoMainMenu || IsIntroMap())
		return -1;
	return P.Level.TimeSeconds - P.FrobTime;
}

function bool DeathUp()
{
	return (DeathTime() > 2.0) && (winCount <= 0);
}

// Opens the death screen once the player has been down a moment, and again
// if a screen opened from it (Load Game) is closed without loading
function DeathTick()
{
	local DeusExPlayer P;
	local DeusExLevelInfo Info;
	local string Loc;

	if (DeathTime() < 0)
	{
		DeathLoadT = 0;
		DeathBox = None;
		return;
	}
	if ((DeathBox != None) && (GetTopWindow() != DeathBox))
		DeathBox = None;
	if ((DeathBox != None) || (DeathLoadT > 0) || (DeathTime() < 2.0) || (winCount > 0))
		return;
	P = DeusExPlayer(parentPawn);
	Info = P.GetLevelInfo();
	if (Info != None)
		Loc = Info.MissionLocation;
	DeathBox = RIDeathScreen(PushWindow(Class'RIDeathScreen', False, True));
	if (DeathBox == None)
		return;
	DeathBox.SetDeath(DeathTitle, Loc, DeathCheckpoint, DeathRestart, DeathLoadGame, DeathMainMenu);
	DeathBox.SetNotifyWindow(Self);
	DeathBox.SetFocusWindow(DeathBox);
	ShowCursor(True);
	Log("RI: death screen up");
}

function DeathChoice(int n)
{
	PopWindow(True);
	DeathBox = None;
	if (n == 0)
		LoadCheckpoint();
	else if (n == 1)
		RestartMission();
	else if (n == 2)
	{
		Log("RI: death screen - load game");
		InvokeMenuScreen(Class'DeusEx.MenuScreenLoadGame', True);
	}
	else
	{
		DeathLoadT = 1;
		Log("RI: death screen - main menu");
		RequestMainMenu();
	}
}

// ----------------------------------------------------------------------
// Checkpoints. The original game makes none (only the quick save), so the
// mod saves one into a slot of its own each time the player arrives in a
// map, once things are calm (alive, no conversation, transmission or menu,
// a couple of seconds in). The first arrival in a new mission also saves
// the mission's start into a second slot. Both show in Load Game as
// "Checkpoint" / "Mission Start". Not made under AE's hardcore or
// restricted saving.
// ----------------------------------------------------------------------

function CheckpointTick(float DT)
{
	local DeusExPlayer P;
	local DeusExLevelInfo Info;

	P = DeusExPlayer(parentPawn);
	if ((P == None) || (P.Level == None))
		return;
	if (P.Level != CkptLevel)
	{
		CkptLevel = P.Level;
		CkptWait = 0;
		CkptStep = 2;
		Info = P.GetLevelInfo();
		if ((Info != None) && (Info.MissionNumber != CkptMission))
			CkptStep = 1;
		return;
	}
	if (CkptStep == 0)
		return;
	CkptWait += DT;
	if ((CkptWait < 2.0) || !CanCheckpoint(P))
		return;
	Info = P.GetLevelInfo();
	if (CkptStep == 1)
	{
		Log("RI: mission start save, mission" @ Info.MissionNumber);
		P.SaveGame(MISSION_SLOT, MissionStartTitle $ " - " $ Info.MissionLocation);
		CkptMission = Info.MissionNumber;
		bHasMissionCkpt = True;
		SaveConfig();
		CkptStep = 2;
		CkptWait = 1.5;          // the checkpoint half a second later
		return;
	}
	Log("RI: checkpoint save");
	P.SaveGame(CKPT_SLOT, CkptTitle $ " - " $ Info.MissionLocation);
	bHasCkpt = True;
	SaveConfig();
	CkptStep = 0;
}

// The quick save's own rules, plus: no conversation, menu or loading
function bool CanCheckpoint(DeusExPlayer P)
{
	local DeusExLevelInfo Info;

	Info = P.GetLevelInfo();
	if ((Info == None) || (Info.MissionNumber < 0) || IsIntroMap() || bGoMainMenu)
		return False;
	if (P.IsInState('Dying') || P.IsInState('Paralyzed') || P.IsInState('Interpolating') || (P.Health <= 0))
		return False;
	if ((P.dataLinkPlay != None) || (P.conPlay != None) || (P.Level.NetMode != NM_Standalone) || (winCount > 0))
		return False;
	if (Class'RIUtil'.static.PBool(P, "bHardCoreMode") || Class'RIUtil'.static.PBool(P, "bRestrictedSaving"))
		return False;
	return True;
}

// Death screen: the last checkpoint (the quick save if there's none yet)
function LoadCheckpoint()
{
	local DeusExPlayer P;

	P = DeusExPlayer(parentPawn);
	DeathLoadT = 1;
	if (bHasCkpt)
	{
		Log("RI: death screen - last checkpoint");
		P.LoadGame(CKPT_SLOT);
	}
	else
	{
		Log("RI: death screen - no checkpoint yet, quick save");
		P.QuickLoadConfirmed();
	}
}

// Death screen: this mission's start (the last checkpoint if it's from
// another mission or there's none)
function RestartMission()
{
	local DeusExPlayer P;
	local DeusExLevelInfo Info;

	P = DeusExPlayer(parentPawn);
	Info = P.GetLevelInfo();
	if (bHasMissionCkpt && (Info != None) && (Info.MissionNumber == CkptMission))
	{
		DeathLoadT = 1;
		Log("RI: death screen - restart mission");
		P.LoadGame(MISSION_SLOT);
	}
	else
		LoadCheckpoint();
}

function DeathKey(EInputKey key)
{
	local DeusExPlayer P;

	P = DeusExPlayer(parentPawn);
	if (DeathLoadT > 0)
		return;
	if ((key == IK_Enter) || (key == IK_Space))
		LoadCheckpoint();
	else if (key == IK_R)
		RestartMission();
	else if (key == IK_L)
	{
		Log("RI: death screen - load game");
		InvokeMenuScreen(Class'DeusEx.MenuScreenLoadGame');
	}
	else if (key == IK_Escape)
	{
		DeathLoadT = 1;
		Log("RI: death screen - main menu");
		RequestMainMenu();
	}
}

function DrawDeath(GC gc)
{
	local float t, a, S, cy;
	local DeusExLevelInfo Info;
	local string Loc;

	t = DeathTime();
	if (t < 0)
		DeathLoadT = 0;
	if ((t < 2.0) || (winCount > 0))
		return;
	a = FClamp((t - 2.0) / 0.8, 0, 1);
	S = height / 1080.0;
	cy = height * 0.42;
	Class'RITheme'.static.SetMode(2);
	Class'RISkin'.static.DrawDim(gc, 0, 0, width, height, 0.55 * a);
	Class'RISkin'.static.DrawDim(gc, 0, cy - 140 * S, width, 340 * S, 0.35 * a);

	Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', 0, cy - 110 * S, width, 60 * S, DeathTitle, Class'RIUtil'.static.Col(255 * a, 241 * a, 194 * a), 1, 0.95);
	Info = DeusExPlayer(parentPawn).GetLevelInfo();
	if (Info != None)
		Loc = Info.MissionLocation;
	if (Loc != "")
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', 0, cy - 46 * S, width, 20 * S, Caps(Loc), Class'RIUtil'.static.Col(168 * a, 143 * a, 78 * a), 1, 0.62);
	Class'RISkin'.static.FillC(gc, width * 0.5 - 220 * S, cy - 16 * S, 440 * S, 1.5 * S, Class'RIUtil'.static.Col(126 * a, 105 * a, 50 * a));

	if (DeathLoadT > 0)
	{
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', 0, cy + 10 * S, width, 30 * S, Caps(DeathWaitLabel), Class'RIUtil'.static.Col(242 * a, 211 * a, 107 * a), 1, 0.56);
		return;
	}
	// the buttons are RIDeathScreen's (a window, so they take the mouse)
}

// While dying, AE's main menu (any key, F, Escape) is replaced by the death screen
function InvokeMenu(Class<DeusExBaseWindow> newMenu)
{
	if ((DeathTime() >= 0) && ClassIsChildOf(newMenu, Class'DeusEx.MenuMain'))
		return;
	Super.InvokeMenu(newMenu);
}

event PostDrawWindow(GC gc)
{
	GuardInitCount("PostDraw");
	// Loading, saving, preparing and paused screens (see RILoading)
	if (!bClassicHUD)
	{
		// a clock that runs per drawn frame, since the level (and Tick) can
		// be stopped while these screens draw
		DrawClock += 1.0 / 60.0;
		if (!Class'RILoading'.static.Draw(gc, DeusExPlayer(parentPawn), width, height, winCount, MapName(), DrawClock))
			DrawDeath(gc);
	}
	Class'RITheme'.static.SetMode(0);
	if (bDebug)
		DrawDebug(gc);
}

// ----------------------------------------------------------------------
// initCount guard
// After each frame is drawn, the engine (XRootWindow::InitializeWindows)
// walks the VISIBLE window tree once, sends WindowReady to every window not
// yet set up, and subtracts one from initCount for each. It then requires
// initCount == 0 and stops the game otherwise (above or below zero).
// Here the same walk is done in script: count the not-yet-ready windows the
// engine will actually reach. If initCount disagrees, something left it out
// of step; correct it so the check passes, and log what was on screen.
// Windows that were counted but can't be reached stay not-ready and are
// counted again, correctly, when they become visible.
// ----------------------------------------------------------------------

function int CountUnready(Window W, int Depth)
{
	local Window C;
	local int n;

	if ((W == None) || (Depth > 32))
		return 0;
	if (!W.bIsInitialized)
		n = 1;
	for (C = W.GetBottomChild(True); C != None; C = C.GetHigherSibling(True))
		n += CountUnready(C, Depth + 1);
	return n;
}

function GuardInitCount(string Where)
{
	local int Reach;

	Reach = CountUnready(Self, 0);
	if (Reach == initCount)
		return;

	InitFixes++;
	Log("Reimagined UI: initCount " $ initCount $ " but " $ Reach $ " reachable at " $ Where
		$ " (top " $ ClassOf(GetTopWindow()) $ ", focus " $ ClassOf(GetFocusWindow()) $ ") - corrected");
	if (InitDumps < 3)
	{
		InitDumps++;
		DumpWindowTree();
	}
	initCount = Reach;
}

function string ClassOf(Object O)
{
	if (O == None)
		return "None";
	return string(O.Class.Name);
}

function string MapName()
{
	local string M;
	local int p;

	if ((parentPawn == None) || (parentPawn.Level == None))
		return "?";
	M = string(parentPawn.Level);
	p = InStr(M, ".");
	if (p > 0)
		M = Left(M, p);
	return M;
}

function DrawDebug(GC gc)
{
	local float S, x, y, w, lh, fps;
	local int i, n;
	local string L;
	local Window F;
	local Color Head, Txt, Dim, Warn;
	local RIPanel P;

	S  = height / 1080.0;
	w  = 640 * S;
	x  = width - w - 24 * S;
	y  = 24 * S;
	lh = Class'RIText'.static.LineHeight(Class'RIFontSmall') + 4 * S;

	Head = Class'RIUtil'.static.Col(95, 200, 255);
	Txt  = Class'RIUtil'.static.Col(214, 218, 250);
	Dim  = Class'RIUtil'.static.Col(120, 126, 186);
	Warn = Class'RIUtil'.static.Col(255, 150, 110);

	n = 15 + winCount;
	P = Class'RIPanel'.static.FindIn(GetTopWindow());
	if (P != None)
		n += 2;

	// Panel
	Class'RISkin'.static.DrawDim(gc, x, y, w, n * lh + 28 * S, 0.9);
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(8, 10, 34));
	Class'RIText'.static.Fill(gc, x, y, w, n * lh + 28 * S);
	Class'RIText'.static.Box(gc, x, y, w, n * lh + 28 * S, Class'RIUtil'.static.Col(90, 96, 210));

	x += 14 * S;
	y += 12 * S;

	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, "REIMAGINED UI DEBUG  |  BUILD " $ Class'RIBuildInfo'.default.BuildNumber $ "  " $ Class'RIBuildInfo'.default.BuildTime, Head);
	y += lh;
	L = Caps(Class'RINative'.static.RINativeVersion()) $ "  ping(20)=" $ Class'RINative'.static.RINativePing(20);
	if (Class'RIText'.default.bAtlasText)
		L = L $ "   TEXT: ATLAS (Ctrl+F8)";
	else
		L = L $ "   TEXT: NATIVE (Ctrl+F8)";
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, L, Dim);
	y += lh * 1.4;

	fps = 0;
	if (DebugFrameTime > 0)
		fps = 1.0 / DebugFrameTime;
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, "FPS " $ int(fps) $ "   frame " $ int(DebugFrameTime * 1000.0 + 0.5) $ " ms   UI scale " $ int(S * 1000) / 1000.0, Txt);
	y += lh;
	L = "MAP " $ MapName();
	if (IsIntroMap())
		L = L $ " (title)";
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, L, Txt);
	y += lh;
	if (DeusExPlayer(parentPawn) != None)
		L = "UI BACKGROUND " $ DeusExPlayer(parentPawn).UIBackground $ " (0 render 3D, 1 snapshot, 2 black)";
	else
		L = "UI BACKGROUND ?";
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, L, Txt);
	y += lh;
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, "PAUSED " $ bUIPaused $ "   in-game menus " $ InGameMenus() $ "   AE mask " $ bAEMask, Txt);
	y += lh;
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, "MENU FADE " $ int(MenuFade * 100) $ "%   resuming " $ bResuming, Txt);
	y += lh * 1.4;

	// Engine window state: initCount must return to 0 every frame
	L = "INITCOUNT " $ initCount $ "   corrections " $ InitFixes;
	if (InitFixes > 0)
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, L $ "  (see ReimaginedUI.log)", Warn);
	else
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, L, Txt);
	y += lh;
	F = GetFocusWindow();
	L = "FOCUS " $ ClassOf(F);
	if ((F != None) && (F.GetParent() != None))
		L = L $ "  in " $ ClassOf(F.GetParent());
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, L, Txt);
	y += lh * 1.4;

	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, "WINDOW STACK (" $ winCount $ ")", Head);
	y += lh;
	for (i = winCount - 1; i >= 0; i--)
	{
		L = "  " $ i $ "  " $ ClassOf(winStack[i]);
		if ((winStack[i] != None) && !winStack[i].IsVisible(False))
			L = L $ "  (hidden)";
		if (Class'RIPanel'.static.FindIn(winStack[i]) != None)
			L = L $ "  [panel]";
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, L, Txt);
		y += lh;
	}

	if (P != None)
	{
		y += lh * 0.4;
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y,
			"PANEL kind " $ P.Kind $ "  rows " $ P.NumRows $ "  sel " $ P.Sel $ "  dirty " $ P.bDirty $ "  ready " $ P.bReady, Txt);
		y += lh;
	}

	y += lh * 0.4;
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, "CTRL+F10 HIDE   CTRL+F11 TEST DIALOG   CTRL+F12 DUMP TO LOG", Dim);
}

// Writes the whole window tree to the log, with each window's visibility
// and readiness, and marks the focus window.
function DumpWindowTree()
{
	Log("==== Reimagined UI window tree (build " $ Class'RIBuildInfo'.default.BuildNumber $ ") ====");
	Log("initCount=" $ initCount $ " winCount=" $ winCount $ " focus=" $ ClassOf(GetFocusWindow()) $ " top=" $ ClassOf(GetTopWindow()));
	DumpWindow(Self, 0);
	Log("==== end of window tree ====");
}

function DumpWindow(Window W, int Depth)
{
	local Window C;
	local string Pad, L;
	local int i;

	if ((W == None) || (Depth > 24))
		return;
	for (i = 0; i < Depth; i++)
		Pad = Pad $ "  ";
	L = Pad $ ClassOf(W);
	if (!W.IsVisible(False))
		L = L $ " [hidden]";
	if (!W.bIsInitialized)
		L = L $ " [NOT READY]";
	if (W == GetFocusWindow())
		L = L $ " [FOCUS]";
	Log(L);
	for (C = W.GetBottomChild(); C != None; C = C.GetHigherSibling())
		DumpWindow(C, Depth + 1);
}

function ClientMessageSafe(string M)
{
	if (parentPawn != None)
		parentPawn.ClientMessage(M);
}

defaultproperties
{
     ScreenStyle=2
     bHudSway=True
     HudTilt=1
     SubColors=1
     DeathTitle="AGENT DOWN"
     DeathLoadLast="Load last save"
     DeathLoadGame="Load game"
     DeathMainMenu="Main menu"
     DeathWaitLabel="Loading..."
     DeathCheckpoint="Last checkpoint"
     DeathRestart="Restart mission"
     CkptTitle="Checkpoint"
     MissionStartTitle="Mission Start"
     CkptMission=-99
}
