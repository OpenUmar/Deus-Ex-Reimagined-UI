//=============================================================================
// RIBase (vanilla Deus Ex 1.112fm)
// Everything ReimaginedUI needs from its base, answered for the original
// game. Same static functions as the other Source\Base_* folders; features
// the original doesn't have (perks, traumas, pins and markers, rotation,
// recharging, the bigger belt, GMDX's list menus) report as absent, and the
// screens leave them out.
//=============================================================================
class RIBase extends Object
	abstract;

var localized string BaseName;
var localized string DiffText[4];

// ----------------------------------------------------------------------
// Features the base has
// ----------------------------------------------------------------------

static function bool Has(string Feature)
{
	return False;
}

// ----------------------------------------------------------------------
// Journal (the original has plain notes only)
// ----------------------------------------------------------------------

static function MakeMarker(DeusExPlayer P, DeusExNote N)
{
}

static function PinNote(DeusExPlayer P, DeusExNote N)
{
}

static function SetShowMarkers(DeusExPlayer P, bool B)
{
}

static function SetGoalsOnScreen(PersonaScreenGoals G, DeusExPlayer P, bool B)
{
}

// ----------------------------------------------------------------------
// Player state
// ----------------------------------------------------------------------

static function float MaxEnergy(DeusExPlayer P, bool bTrueMax)
{
	return P.EnergyMax;
}

static function float EnergyReserve(DeusExPlayer P)
{
	return 0;
}

// The original has no stamina; the bar shows only for breath underwater
static function bool StaminaShown(DeusExPlayer P)
{
	return False;
}

static function bool IsCrouching(DeusExPlayer P)
{
	return P.bIsCrouching || P.bCrouchOn || P.bForceDuck;
}

static function ResetAim(DeusExPlayer P)
{
}

// ----------------------------------------------------------------------
// Augmentations: either always on (passive) or switched on and off
// ----------------------------------------------------------------------

static function bool AugCanActivate(Augmentation Aug)
{
	return Aug.bHasIt && !Aug.bAlwaysActive;
}

// The original HUD's icons: white when on, grey when off
static function Color AugColor(Augmentation Aug, bool bAlternate)
{
	local Color C;

	if (Aug.bIsActive)
	{
		C.R = 255;
		C.G = 255;
		C.B = 255;
	}
	else
	{
		C.R = 110;
		C.G = 110;
		C.B = 110;
	}
	return C;
}

// 0 passive, 1 active (the original has no automatic or toggle augs)
static function int AugType(Augmentation Aug)
{
	if (Aug.bAlwaysActive)
		return 0;
	return 1;
}

static function bool AugCanRespec(HUDMedBotAugItemButton B)
{
	return False;
}

// ----------------------------------------------------------------------
// Inventory, belt, weapons
// ----------------------------------------------------------------------

static function Texture BeltPlaceholder(DeusExPlayer P, int n)
{
	return None;
}

static function int ReserveRounds(DeusExWeapon W)
{
	if ((W.ReloadCount == 0) || (W.AmmoType == None))
		return 0;
	return W.AmmoType.AmmoAmount - W.AmmoLeftInClip();
}

static function int MaxAmmo(DeusExPlayer P, Ammo Am)
{
	return Am.MaxAmmo;
}

static function Texture ItemIcon(Inventory I)
{
	return I.Icon;
}

static function RemoveFromBelt(DeusExPlayer P, Inventory I)
{
	P.RemoveObjectFromBelt(I);
}

static function RecreateBelt(HUDObjectBelt B)
{
	if (B == None)
		return;
	B.ClearBelt();
	B.PopulateBelt();
}

static function TurnIcon(DeusExWeapon W)
{
}

static function bool CanCharge(DeusExPlayer P, Inventory T)
{
	return False;
}

static function int Charge(DeusExPlayer P, Inventory T, out string Msg)
{
	return 0;
}

// ----------------------------------------------------------------------
// Received / given items. The original keeps no list: each item is a child
// window of the box (an icon window and a "Name (count)" label).
// ----------------------------------------------------------------------

static function HUDReceivedDisplayItem ReceivedWindow(HUDReceivedDisplay R, int i)
{
	local Window W;
	local int n;

	if ((R == None) || (R.winTile == None))
		return None;
	for (W = R.winTile.GetTopChild(); W != None; W = W.GetLowerSibling())
	{
		if (HUDReceivedDisplayItem(W) == None)
			continue;
		if (n == i)
			return HUDReceivedDisplayItem(W);
		n++;
	}
	return None;
}

static function int ReceivedCount(HUDReceivedDisplay R)
{
	local Window W;
	local int n;

	if ((R == None) || (R.winTile == None))
		return 0;
	for (W = R.winTile.GetTopChild(); W != None; W = W.GetLowerSibling())
		if (HUDReceivedDisplayItem(W) != None)
			n++;
	return n;
}

static function bool ReceivedItem(HUDReceivedDisplay R, int i, out Texture Icon, out string Label, out int Qty, out byte bDeclined)
{
	local HUDReceivedDisplayItem It;
	local int p;

	It = ReceivedWindow(R, i);
	if (It == None)
		return False;
	Icon = None;
	if (It.winIcon != None)
		Icon = It.winIcon.background;
	Label = "";
	if (It.winLabel != None)
		Label = It.winLabel.GetText();
	Qty = 1;
	bDeclined = 0;
	// "Name (3)"
	if (Right(Label, 1) == ")")
	{
		p = InStr(Label, " (");
		if (p >= 0)
		{
			Qty = Max(1, int(Mid(Label, p + 2, Len(Label) - p - 3)));
			Label = Left(Label, p);
		}
	}
	// The original also adds rows with neither icon nor name (an empty search);
	// they'd show as a bare "x1"
	if ((Icon == None) && (Label == ""))
		return False;
	return True;
}

static function Receive(DeusExPlayer P, HUDReceivedDisplay R, Inventory I, int Count)
{
	if (R != None)
		R.AddItem(I, Count);
}

// ----------------------------------------------------------------------
// HUD and conversation windows (none extra in the original)
// ----------------------------------------------------------------------

static function Window HudAmmo2(DeusExHUD H)
{
	return None;
}

static function Window HudGoals(DeusExHUD H)
{
	return None;
}

static function HideHudExtras(DeusExHUD H)
{
}

static function SetupLog(HUDLogDisplay L)
{
}

static function HUDReceivedDisplay ConTaken(ConWindowActive C)
{
	return None;
}

static function HideConExtras(ConWindowActive C)
{
}

// ----------------------------------------------------------------------
// Traumas (none in the original)
// ----------------------------------------------------------------------

static function int TraumaCount(DeusExPlayer P)
{
	return 0;
}

static function Object TraumaAt(DeusExPlayer P, int i)
{
	return None;
}

static function bool TraumaActive(Object O)
{
	return False;
}

static function bool TraumaHidden(Object O)
{
	return True;
}

static function int TraumaKits(Object O)
{
	return 0;
}

static function string TraumaName(Object O)
{
	return "";
}

static function Texture TraumaIcon(Object O)
{
	return None;
}

static function int TraumaDamage(Object O)
{
	return 0;
}

static function int TraumaThreshold(Object O)
{
	return 1;
}

static function TraumaCure(PersonaScreenHealth H, Object O)
{
}

// ----------------------------------------------------------------------
// Perks (none in the original)
// ----------------------------------------------------------------------

static function Object PerkFor(DeusExPlayer P, class<Skill> SC, int n)
{
	return None;
}

static function bool PerkVisible(Object O)
{
	return False;
}

static function bool PerkOwned(Object O)
{
	return False;
}

static function bool PerkBuyable(Object O)
{
	return False;
}

static function PerkBuy(DeusExPlayer P, Object O)
{
}

static function string PerkName(Object O)
{
	return "";
}

static function int PerkCost(Object O)
{
	return 0;
}

static function int PerkLevel(Object O)
{
	return 0;
}

static function bool PerkNeedsSkill(DeusExPlayer P, Object O)
{
	return False;
}

static function string PerkText(Object O)
{
	return "";
}

static function string SkillDesc(Skill Sk, bool bHardcore, float Difficulty)
{
	return Sk.Description;
}

// ----------------------------------------------------------------------
// Persona tabs (no Outfits button in the original)
// ----------------------------------------------------------------------

static function PersonaNavButtonWindow OutfitsButton(PersonaNavBarWindow Nav)
{
	return None;
}

static function bool HasOutfits(PersonaNavBarWindow Nav)
{
	return False;
}

// ----------------------------------------------------------------------
// Keypad and terminals: the original opens the keypad on its own, with no
// notes beside it
// ----------------------------------------------------------------------

static function Class<DeusExBaseWindow> KeypadClass(Class<DeusExBaseWindow> Requested)
{
	if (Requested == Class'DeusEx.HUDKeypadWindow')
		return Class'RIKeypadWindow';
	return None;
}

static function bool IsKeypadWindow(Window W)
{
	return RIKeypadWindow(W) != None;
}

static function AddTerminalNotes(NetworkTerminal T)
{
}

static function Window TerminalNotes(NetworkTerminal T)
{
	return None;
}

// ----------------------------------------------------------------------
// Menus
// ----------------------------------------------------------------------

static function bool IsListScreen(MenuUIScreenWindow S)
{
	return False;
}

static function MenuUIListWindow ScreenList(MenuUIScreenWindow S)
{
	return None;
}

static function string ListHelp(MenuUIScreenWindow S, int Id)
{
	return "";
}

// Settings categories (the original's names, from DeusEx.int)
static function string SettingsName(int i)
{
	return Class'MenuSettings'.default.ButtonNames[i];
}

static function SetSettingsName(MenuSettings M, int i, string N)
{
	M.ButtonNames[i] = N;
}

static function int NewGameOption(MenuScreenNewGame M, int Which, out string Label)
{
	return -1;
}

static function NewGameFlip(MenuScreenNewGame M, int Which)
{
}

static function string VersionText(MenuMain M, DeusExPlayer P)
{
	if (P == None)
		return "";
	return P.GetDeusExVersion();
}

static function string DifficultyText(int i, string Def)
{
	if ((i >= 0) && (i < 4) && (default.DiffText[i] != ""))
		return default.DiffText[i];
	return Def;
}

// The original's HUD has no gold theme; keep what the player has
static function bool ApplyGoldTheme(DeusExPlayer P)
{
	return False;
}

// ----------------------------------------------------------------------
// Health and keys
// ----------------------------------------------------------------------

static function int HeadBonus(DeusExPlayer P)
{
	return 0;
}

static function int TorsoBonus(DeusExPlayer P)
{
	return 0;
}

static function float TotalMaxHealth(DeusExPlayer P)
{
	return P.default.Health;
}

static function KeysChanged(DeusExPlayer P)
{
}

static function PlaceTerminalNotes(NetworkTerminal T, float X, float Y, float W, float H)
{
}

// What the ammo readout is about: the weapon in hand, as the original's
// ammo display does
static function Inventory HudWeapon(HUDAmmoDisplay A)
{
	if ((A == None) || (A.player == None))
		return None;
	return A.player.Weapon;
}

// Played when a skill is raised on the New Game screen
static function Sound SkillUpSound()
{
	return Sound'DeusExSounds.UserInterface.Menu_OK';
}

// Vision aug (light amp / thermal): the original vision aug is redrawn in Vanilla+ (RIAugDisplay)
static function bool OwnVision()
{
	return True;
}

// ----------------------------------------------------------------------
// Crosshair spread: how far a shot can stray off the aim, as the tangent of
// that angle (RICrosshair turns it into pixels with the view's FOV).
// The original game: instant-hit shots land up to +-500 x accuracy across at
// max(1024, range) (TraceFire); a scope adds 0.2 unless zoomed; zoomed or
// lasing shots are dead on. Projectiles turn their aim by up to +-512 x
// accuracy rotation units (ProjectileFire).
// ----------------------------------------------------------------------

static function float ShotSpread(DeusExWeapon W)
{
	local float acc;

	if ((W == None) || W.bHandToHand)
		return 0;
	acc = FMax(0, W.currentAccuracy);
	if (!W.bInstantHit)
		return Tan(acc * 512.0 * Pi / 32768.0);
	if (W.bHasScope && !W.bZoomed)
		acc += 0.2;
	else if (W.bLasing || W.bZoomed)
		acc = 0;
	return acc * 500.0 / FMax(1024.0, W.MaxRange);
}

defaultproperties
{
     BaseName="Deus Ex"
     DiffText(0)="For players who are here mainly for the story. Enemies do less damage and are slower to notice you, so mistakes are rarely fatal."
     DiffText(1)="The intended experience. Stealth, combat and exploration are balanced so that every approach is viable."
     DiffText(2)="Enemies hit harder and notice you sooner. For players who already know the game."
     DiffText(3)="Enemies are deadly, and a few shots can end you. For veterans."
}
