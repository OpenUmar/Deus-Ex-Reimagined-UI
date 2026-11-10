//=============================================================================
// RIDeusExHUD
// AE's DeusExHUD with two changes while the rebuilt HUD (RIHud) is on:
//  - The pieces RIHud replaces (hit display, compass, ammo, belt, active
//    augs, received items) can never be shown. AE re-shows them from
//    UpdateSettings (after picking things up, opening and closing screens...),
//    which used to flash them for a frame before RIHud hid them again. Here
//    the request is refused before anything is drawn.
//  - After AE lays out its windows, the ones that would land on the new HUD
//    (InfoLink, message log, damage icons, goals, timer) are moved clear of it.
// With the HUD set to Classic, it behaves exactly like AE's.
//=============================================================================
class RIDeusExHUD extends DeusExHUD;

var bool bRI;          // the rebuilt HUD is on

// ----------------------------------------------------------------------
// Restyled versions of AE's highlight frame and reader (same logic; they
// draw as AE's when the HUD is on Classic)
// ----------------------------------------------------------------------

event InitWindow()
{
	Super.InitWindow();

	if (frobDisplay != None)
		frobDisplay.Destroy();
	frobDisplay = FrobDisplayWindow(NewChild(Class'RIFrobDisplay'));
	frobDisplay.SetWindowAlignments(HALIGN_Full, VALIGN_Full);
	frobDisplay.Lower();

	if (damageDisplay != None)
		damageDisplay.Destroy();
	damageDisplay = DamageHUDDisplay(NewChild(Class'RIDamageDisplay'));

	if (info != None)
		info.Destroy();
	info = HUDInformationDisplay(NewChild(Class'RIInfoDisplay', False));

	// The message log, in the new style
	if (msgLog != None)
		msgLog.Destroy();
	msgLog = HUDLogDisplay(NewChild(Class'RILogDisplay', False));
	if (DeusExPlayer(GetRootWindow().parentPawn) != None)
		msgLog.SetLogTimeout(DeusExPlayer(GetRootWindow().parentPawn).GetLogTimeout());

	// Barks, as subtitles
	if (barkDisplay != None)
		barkDisplay.Destroy();
	barkDisplay = HUDBarkDisplay(NewChild(Class'RIBarkDisplay', False));

	if (startDisplay != None)
		startDisplay.Destroy();
	startDisplay = HUDMissionStartTextDisplay(NewChild(Class'RIMissionStart', False));
}

// AE's, with the restyled InfoLink window
function HUDInfoLinkDisplay CreateInfoLinkWindow()
{
	if (infolink != None)
		return None;

	infolink = HUDInfoLinkDisplay(NewChild(Class'RIInfoLinkDisplay'));

	if ((msgLog != None) && !class'DeusExPlayer'.default.bShowSmallLog)
		msgLog.HideLogWindow();

	infolink.AskParentForReconfigure();

	return infolink;
}

// AE's, with the restyled first-person conversation window (subtitles)
function HUDConWindowFirst CreateConWindowFirst()
{
	conWindow = HUDConWindowFirst(NewChild(Class'RIConFirst', False));
	conWindow.AskParentForReconfigure();
	return conWindow;
}

// ----------------------------------------------------------------------
// Which of AE's windows RIHud replaces
// ----------------------------------------------------------------------

function bool Replaced(Window W)
{
	if (W == None)
		return False;
	if ((W == hit) || (W == compass) || (W == ammo) || (W == ammo2))
		return True;
	if ((W == belt) || (W == activeItems) || (W == receivedItems))
		return True;
	return False;
}

function bool HideOne(Window W)
{
	if ((W != None) && W.IsVisible(False))
	{
		W.SetChildVisibility(False);
		return True;
	}
	return False;
}

function HideReplaced()
{
	local bool bAny;

	if (HideOne(hit))
		bAny = True;
	if (HideOne(compass))
		bAny = True;
	if (HideOne(ammo))
		bAny = True;
	if (HideOne(ammo2))
		bAny = True;
	if (HideOne(belt))
		bAny = True;
	if (HideOne(activeItems))
		bAny = True;
	if (HideOne(receivedItems))
		bAny = True;
	if (bAny)
		ConfigurationChanged();
}

// Called by the root every tick with the Classic HUD setting
function SetRI(bool bOn)
{
	local DeusExPlayer P;

	if (bOn == bRI)
		return;
	bRI = bOn;
	if (bRI)
		HideReplaced();
	else
	{
		P = DeusExPlayer(GetRootWindow().parentPawn);
		if (P != None)
			UpdateSettings(P);
	}
	ConfigurationChanged();
}

// ----------------------------------------------------------------------
// AE hooks
// ----------------------------------------------------------------------

function ChildRequestedVisibilityChange(window child, bool bNewVisibility)
{
	if (bRI && bNewVisibility && Replaced(child))
		bNewVisibility = False;
	Super.ChildRequestedVisibilityChange(child, bNewVisibility);
}

function UpdateSettings(DeusExPlayer player, optional bool bNoBelt)
{
	Super.UpdateSettings(player, bNoBelt);
	if (bRI)
		HideReplaced();
}

function ConfigurationChanged()
{
	Super.ConfigurationChanged();
	if (bRI)
		Relayout();
}

// ----------------------------------------------------------------------
// Layout around the rebuilt HUD (design units: 1920 x 1080)
//   top left:   body monitor and bars, about 480 wide, 250 tall
//   top centre: compass, down to about 76
//   bottom right: weapon card, 176 tall, 30 up from the bottom
// ----------------------------------------------------------------------

function Relayout()
{
	local float K, SideL, TopY, NextY, QW, QH, LogW;

	K = height / 1080.0 * Class'RIRootWindow'.static.HudK();
	if (K <= 0)
		return;
	SideL = 480 * K;
	TopY = 84 * K;
	NextY = TopY;

	// InfoLink: centred under the compass
	if (infolink != None)
	{
		infolink.QueryPreferredSize(QW, QH);
		infolink.ConfigureChild((width - QW) * 0.5, TopY, QW, QH);
		if (infolink.IsVisible())
			NextY = TopY + QH + 12 * K;
	}

	// Message log: under the compass (or under the InfoLink), clear of
	// the body monitor on the left and kept symmetric
	if (msgLog != None)
	{
		LogW = FMax(400, width - 2 * SideL);
		QH = msgLog.QueryPreferredHeight(LogW);
		msgLog.ConfigureChild((width - LogW) * 0.5, NextY, LogW, QH);
	}

	// Damage halo: the whole screen (RIDamageDisplay; its icons sit under
	// the body monitor); goals under the body monitor, below those icons
	NextY = 300 * K;
	if (damageDisplay != None)
		damageDisplay.ConfigureChild(0, 0, width, height);
	if ((goalsWindow != None) && goalsWindow.IsVisible())
	{
		goalsWindow.QueryPreferredSize(QW, QH);
		goalsWindow.ConfigureChild(36 * K, NextY, QW, QH);
	}

	// Mission start text: drawn by RIMissionStart anywhere on the screen
	if (startDisplay != None)
		startDisplay.ConfigureChild(0, 0, width, height);

	// Barks and first-person conversations: centred, ending above the belt
	// (its art starts at 856), never over it
	QW = FMin(1100 * K, width - 2 * SideL + 200 * K);
	if ((barkDisplay != None) && barkDisplay.IsVisible())
	{
		QH = barkDisplay.QueryPreferredHeight(QW);
		barkDisplay.ConfigureChild((width - QW) * 0.5, height - (224 * Class'RIRootWindow'.static.BeltK() + 18) * K - QH, QW, QH);
	}
	if ((conWindow != None) && conWindow.IsVisible())
	{
		QH = conWindow.QueryPreferredHeight(QW);
		conWindow.ConfigureChild((width - QW) * 0.5, height - (224 * Class'RIRootWindow'.static.BeltK() + 18) * K - QH, QW, QH);
	}

	// Timer: above the weapon card
	if (timer != None)
	{
		timer.QueryPreferredSize(QW, QH);
		timer.ConfigureChild(width - 36 * K - QW, height - (30 + 176 + 16) * K - QH, QW, QH);
	}
}

defaultproperties
{
}
