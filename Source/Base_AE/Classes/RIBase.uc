//=============================================================================
// RIBase (GMDX: Augmented Edition)
// Everything ReimaginedUI needs from its base mod, answered for GMDX AE.
// Each base folder (Source\Base_*) has its own RIBase with the same static
// functions; the build copies one of them next to the shared screens, so the
// screens compile against whichever DeusEx.u the base ships.
//
// The bodies here are the code the screens used before the split, moved
// unchanged, so AE behaves exactly as it did.
//=============================================================================
class RIBase extends Object
	abstract;

var localized string BaseName;

// ----------------------------------------------------------------------
// Features the base has. The screens hide whatever the base lacks.
// ----------------------------------------------------------------------

static function bool Has(string Feature)
{
	switch (Caps(Feature))
	{
		case "NOTEEXTRAS":      // note filters, pins, map markers, editing game notes
		case "GOALSONSCREEN":   // goals shown on the HUD
		case "TRAUMAS":
		case "PERKS":
		case "ROTATION":        // turning items in the inventory grid
			return True;
	}
	return False;
}

// ----------------------------------------------------------------------
// Journal
// ----------------------------------------------------------------------

static function MakeMarker(DeusExPlayer P, DeusExNote N)
{
	N.bMarkerNote = True;
	P.AddMarker(N);
	P.bShowMarkers = True;
	P.UpdateMarkerDisplay();
}

static function PinNote(DeusExPlayer P, DeusExNote N)
{
	P.PinNote(N);
}

static function SetShowMarkers(DeusExPlayer P, bool B)
{
	P.bShowMarkers = B;
	P.UpdateMarkerDisplay();
}

static function SetGoalsOnScreen(PersonaScreenGoals G, DeusExPlayer P, bool B)
{
	P.bShowGoalsOnScreen = B;
	if (G == None)
		return;
	G.bShowOnScreen = B;
	if (G.chkShowOnScreen != None)
		G.chkShowOnScreen.SetToggle(B);
}

// ----------------------------------------------------------------------
// Player state
// ----------------------------------------------------------------------

static function float MaxEnergy(DeusExPlayer P, bool bTrueMax)
{
	return P.GetMaxEnergy(bTrueMax);
}

static function float EnergyReserve(DeusExPlayer P)
{
	if (P.AugmentationSystem == None)
		return 0;
	return P.AugmentationSystem.CalcEnergyReserve();
}

// GMDX's stamina system shares the breath timer
static function bool StaminaShown(DeusExPlayer P)
{
	return (P.iStaminaSystem > 0) || P.bHardCoreMode;
}

static function bool IsCrouching(DeusExPlayer P)
{
	return P.IsCrouching();
}

static function ResetAim(DeusExPlayer P)
{
	P.ResetAim();
}

// ----------------------------------------------------------------------
// Augmentations
// ----------------------------------------------------------------------

static function bool AugCanActivate(Augmentation Aug)
{
	return Aug.CanBeActivated();
}

static function Color AugColor(Augmentation Aug, bool bAlternate)
{
	return Aug.GetAugColor(bAlternate);
}

// 0 passive, 1 active, 2 automatic, 3 toggle
static function int AugType(Augmentation Aug)
{
	return Clamp(int(Aug.AugmentationType), 0, 3);
}

static function bool AugCanRespec(HUDMedBotAugItemButton B)
{
	return (B != None) && B.bCanRespec;
}

// ----------------------------------------------------------------------
// Inventory, belt, weapons
// ----------------------------------------------------------------------

static function Texture BeltPlaceholder(DeusExPlayer P, int n)
{
	if (P.IsPlaceholder(n))
		return P.GetPlaceholderIcon(n);
	return None;
}

static function int ReserveRounds(DeusExWeapon W)
{
	return W.NumRounds();
}

static function int MaxAmmo(DeusExPlayer P, Ammo Am)
{
	return P.GetAdjustedMaxAmmo(Am);
}

static function Texture ItemIcon(Inventory I)
{
	if (DeusExAmmo(I) != None)
		return DeusExAmmo(I).GetHDTPIcon();
	return I.icon;
}

static function RemoveFromBelt(DeusExPlayer P, Inventory I)
{
	P.RemoveObjectFromBelt(I, True);
}

static function RecreateBelt(HUDObjectBelt B)
{
	if (B != None)
		B.RecreateBelt();
}

// The item's large icon and travelling slot size after a turn (the grid
// size itself is swapped by the screen)
static function TurnIcon(DeusExWeapon W)
{
	W.invSlotsXtravel = W.invSlotsX;
	W.invSlotsYtravel = W.invSlotsY;
	W.bRotated = !W.bRotated;
	W.UpdateLargeIcon();
}

// Recharging with a bioelectric cell dropped on the item
static function bool CanCharge(DeusExPlayer P, Inventory T)
{
	if (WeaponNanoSword(T) != None)
		return !WeaponNanoSword(T).chargeManager.IsFull();
	if (ChargedPickup(T) != None)
		return !ChargedPickup(T).IsDisposable() && (ChargedPickup(T).Charge < ChargedPickup(T).default.Charge);
	return False;
}

// 0 not chargeable, 1 refused (already full), 2 charged (Msg says by how much)
static function int Charge(DeusExPlayer P, Inventory T, out string Msg)
{
	local ChargedPickup ChT;
	local float Mult;

	if (WeaponNanoSword(T) != None)
	{
		if (WeaponNanoSword(T).chargeManager.IsFull())
			return 1;
		WeaponNanoSword(T).chargeManager.Recharge(Msg);
		return 2;
	}
	ChT = ChargedPickup(T);
	if ((ChT == None) || ChT.IsDisposable())
		return 0;
	if (ChT.Charge >= ChT.default.Charge)
		return 1;
	Mult = ChT.default.ChargeMult;
	if (P.PerkManager.GetPerkWithClass(Class'DeusEx.PerkFieldRepair').bPerkObtained)
		Mult *= 1.5;
	ChT.Charge += Mult * ChT.default.Charge;
	if (ChT.Charge >= ChT.default.Charge)
	{
		ChT.Charge = ChT.default.Charge;
		Msg = Class'ChargeManager'.default.msgFullyCharged;
	}
	else
		Msg = P.Sprintf(Class'ChargeManager'.default.msgRecharged, int(100 * Mult));   // (Sprintf is an instance function in AE's Core)
	ChT.bDrained = False;
	ChT.bActivatable = True;
	return 2;
}

// ----------------------------------------------------------------------
// Received / given items
// ----------------------------------------------------------------------

static function int ReceivedCount(HUDReceivedDisplay R)
{
	if (R == None)
		return 0;
	return Clamp(R.displayItemNum, 0, 60);
}

static function bool ReceivedItem(HUDReceivedDisplay R, int i, out Texture Icon, out string Label, out int Qty, out byte bDeclined)
{
	local HUDReceivedDisplayItem It;

	if ((R == None) || (i < 0) || (i >= 60))
		return False;
	It = R.displayItems[i];
	if (It == None)
		return False;
	Icon = It.itemIcon;
	Label = It.itemLabel;
	Qty = It.itemQuantity;
	bDeclined = byte(It.bItemDeclined);
	return True;
}

static function Receive(DeusExPlayer P, HUDReceivedDisplay R, Inventory I, int Count)
{
	P.AddReceivedItem("", I, Count);
}

// ----------------------------------------------------------------------
// HUD and conversation windows the base adds
// ----------------------------------------------------------------------

static function Window HudAmmo2(DeusExHUD H)
{
	return H.ammo2;
}

static function Window HudGoals(DeusExHUD H)
{
	return H.goalsWindow;
}

static function HideHudExtras(DeusExHUD H)
{
	if ((H.ammo2 != None) && H.ammo2.IsVisible(False))
		H.ammo2.Hide();
}

static function SetupLog(HUDLogDisplay L)
{
	if ((L != None) && !Class'DeusExPlayer'.default.bShowSmallLog)
		L.HideLogWindow();
}

static function HUDReceivedDisplay ConTaken(ConWindowActive C)
{
	return C.winTaken;
}

static function HideConExtras(ConWindowActive C)
{
	if (C.upperConWindow == None)
		return;
	if ((C.upperConWindow.txtLabel != None) && C.upperConWindow.txtLabel.IsVisible(False))
		C.upperConWindow.txtLabel.Hide();
	if ((C.upperConWindow.txtCredits != None) && C.upperConWindow.txtCredits.IsVisible(False))
		C.upperConWindow.txtCredits.Hide();
}

// ----------------------------------------------------------------------
// Traumas (AE's wound system). Passed around as Object so the shared
// screens don't name AE's Wound class.
// ----------------------------------------------------------------------

static function int TraumaCount(DeusExPlayer P)
{
	if ((P.WoundManager == None) || !P.bWoundSystem)
		return 0;
	return P.WoundManager.GetWoundNumber();
}

static function Object TraumaAt(DeusExPlayer P, int i)
{
	if (P.WoundManager == None)
		return None;
	return P.WoundManager.GetWoundByIndex(i);
}

static function bool TraumaActive(Object O)
{
	return (Wound(O) != None) && Wound(O).HasWound();
}

static function bool TraumaHidden(Object O)
{
	return (Wound(O) == None) || Wound(O).bNoDisplay;
}

static function int TraumaKits(Object O)
{
	if (Wound(O) == None)
		return 0;
	return Wound(O).GetRequiredMedkits();
}

static function string TraumaName(Object O)
{
	if (Wound(O) == None)
		return "";
	return Wound(O).WoundName;
}

static function Texture TraumaIcon(Object O)
{
	if (Wound(O) == None)
		return None;
	return Wound(O).WoundIcon;
}

static function int TraumaDamage(Object O)
{
	if (Wound(O) == None)
		return 0;
	return Wound(O).GetDamage();
}

static function int TraumaThreshold(Object O)
{
	if (Wound(O) == None)
		return 1;
	return Wound(O).DamageThreshold;
}

// The same steps AE's Cure Trauma button takes
static function TraumaCure(PersonaScreenHealth H, Object O)
{
	if (Wound(O) == None)
		return;
	H.RemoveTraumaMedkits(Wound(O));
	Wound(O).RemoveWound();
}

// ----------------------------------------------------------------------
// Perks (passed around as Object, like traumas)
// ----------------------------------------------------------------------

static function Object PerkFor(DeusExPlayer P, class<Skill> SC, int n)
{
	if (P.PerkManager == None)
		return None;
	return P.PerkManager.GetPerkForSkill(SC, n);
}

static function bool PerkVisible(Object O)
{
	return (Perk(O) != None) && Perk(O).IsVisible();
}

static function bool PerkOwned(Object O)
{
	return (Perk(O) != None) && Perk(O).bPerkObtained;
}

static function bool PerkBuyable(Object O)
{
	return (Perk(O) != None) && Perk(O).IsPurchasable();
}

static function PerkBuy(DeusExPlayer P, Object O)
{
	if ((Perk(O) != None) && (P.PerkManager != None))
		P.PerkManager.PurchasePerk(Perk(O).Class);
}

static function string PerkName(Object O)
{
	if (Perk(O) == None)
		return "";
	return Perk(O).PerkName;
}

static function int PerkCost(Object O)
{
	if (Perk(O) == None)
		return 0;
	return Perk(O).PerkCost;
}

static function int PerkLevel(Object O)
{
	if (Perk(O) == None)
		return 0;
	return Perk(O).PerkLevelRequirement;
}

// True when the perk is locked behind its skill's level
static function bool PerkNeedsSkill(DeusExPlayer P, Object O)
{
	local Perk K;

	K = Perk(O);
	return (K != None) && (K.PerkSkill != None) && (P.SkillSystem.GetSkillLevel(K.PerkSkill) < K.PerkLevelRequirement);
}

// GMDX perk text: the value is printed into the description
static function string PerkText(Object O)
{
	local Perk P;
	local string V;

	P = Perk(O);
	if (P == None)
		return "";
	if (P.PerkValueDisplay == Delta_Percentage)
		return P.Sprintf(P.PerkDescription, int(P.PerkValue * 100 - 100));
	if (P.PerkValueDisplay == Percentage)
		return P.Sprintf(P.PerkDescription, int(P.PerkValue * 100));
	V = string(P.PerkValue);
	while ((InStr(V, ".") >= 0) && ((Right(V, 1) == "0") || (Right(V, 1) == ".")))
		V = Left(V, Len(V) - 1);
	return P.Sprintf(P.PerkDescription, V);
}

static function string SkillDesc(Skill Sk, bool bHardcore, float Difficulty)
{
	return Sk.GetDescriptionText(bHardcore, Difficulty);
}

// ----------------------------------------------------------------------
// Persona tabs: Augmentique's Outfits button
// ----------------------------------------------------------------------

static function PersonaNavButtonWindow OutfitsButton(PersonaNavBarWindow Nav)
{
	if (Nav == None)
		return None;
	return Nav.btnOutfits;
}

static function bool HasOutfits(PersonaNavBarWindow Nav)
{
	return OutfitsButton(Nav) != None;
}

// ----------------------------------------------------------------------
// Keypad and terminals: AE wraps the keypad in a container with the code
// notes beside it, and adds notes to terminals
// ----------------------------------------------------------------------

static function Class<DeusExBaseWindow> KeypadClass(Class<DeusExBaseWindow> Requested)
{
	if (Requested == Class'DeusEx.HUDKeypadContainerWindow')
		return Class'RIKeypadContainer';
	return None;
}

static function bool IsKeypadWindow(Window W)
{
	return RIKeypadContainer(W) != None;
}

static function AddTerminalNotes(NetworkTerminal T)
{
	Class'RINotesPanel'.static.AddTerminalNotes(T);
}

static function Window TerminalNotes(NetworkTerminal T)
{
	return T.winNotes;
}

// ----------------------------------------------------------------------
// Menus
// ----------------------------------------------------------------------

// GMDX's list-style option screens (MenuScreenListWindow)
static function bool IsListScreen(MenuUIScreenWindow S)
{
	return MenuScreenListWindow(S) != None;
}

static function MenuUIListWindow ScreenList(MenuUIScreenWindow S)
{
	if (MenuScreenListWindow(S) == None)
		return None;
	return MenuScreenListWindow(S).lstItems;
}

static function string ListHelp(MenuUIScreenWindow S, int Id)
{
	local MenuScreenListWindow LW;

	LW = MenuScreenListWindow(S);
	if (LW == None)
		return "";
	LW.ShowHelpString(Id);
	if (LW.winDesc == None)
		return "";
	return LW.winDesc.GetText();
}

// Settings categories (AE renames them in NewButtonNames)
static function string SettingsName(int i)
{
	return Class'MenuSettings'.default.NewButtonNames[i];
}

static function SetSettingsName(MenuSettings M, int i, string N)
{
	M.NewButtonNames[i] = N;
}

// LDDP's New Game options: 0 Morpheus line, 1 male interactions.
// -1 when the option isn't there, else 0 / 1 for its state.
static function int NewGameOption(MenuScreenNewGame M, int Which, out string Label)
{
	if ((Which == 0) && (M.MorpheusCheckbox != None))
	{
		Label = M.MorpheusCheckboxLabel;
		return int(M.MorpheusCheckbox.GetToggle());
	}
	if ((Which == 1) && (M.MaleInteractionsCheckbox != None))
	{
		Label = M.MaleInteractionsCheckboxLabel;
		return int(M.MaleInteractionsCheckbox.GetToggle());
	}
	return -1;
}

static function NewGameFlip(MenuScreenNewGame M, int Which)
{
	if ((Which == 0) && (M.MorpheusCheckbox != None))
		M.MorpheusCheckbox.SetToggle(!M.MorpheusCheckbox.GetToggle());
	else if ((Which == 1) && (M.MaleInteractionsCheckbox != None))
		M.MaleInteractionsCheckbox.SetToggle(!M.MaleInteractionsCheckbox.GetToggle());
}

static function string VersionText(MenuMain M, DeusExPlayer P)
{
	if (M == None)
		return "";
	return M.GMDXText;
}

static function string DifficultyText(int i, string Def)
{
	return Def;
}

// First run: the HUD switches to GMDX's Amber theme (the gold the screens
// are designed around). True if a theme was applied.
static function bool ApplyGoldTheme(DeusExPlayer P)
{
	P.HUDThemeNameGMDX = "Amber";
	P.ThemeManager.SetHUDThemeByName("Amber");
	P.SaveConfig();
	return True;
}

// ----------------------------------------------------------------------
// Health and keys
// ----------------------------------------------------------------------

static function int HeadBonus(DeusExPlayer P)
{
	return P.GetHeadHealthAdjustment();
}

static function int TorsoBonus(DeusExPlayer P)
{
	return P.GetTorsoHealthAdjustment();
}

static function float TotalMaxHealth(DeusExPlayer P)
{
	return P.GenerateTotalMaxHealth();
}

// AE keeps its own copy of the bindings; refresh it after a change
static function KeysChanged(DeusExPlayer P)
{
	P.KeybindManager.Setup(P);
}

static function PlaceTerminalNotes(NetworkTerminal T, float X, float Y, float W, float H)
{
	if (T.winNotes == None)
		return;
	T.winNotes.SetPos(X, Y);
	T.winNotes.Resize(W, H);
}

// What the ammo readout is about (AE hides it for tools and empty hands)
static function Inventory HudWeapon(HUDAmmoDisplay A)
{
	return A.GetWeapon();
}

// Played when a skill is raised on the New Game screen (GMDX's)
static function Sound SkillUpSound()
{
	return Sound'GMDXSFX.Generic.Select';
}

// Vision aug (light amp / thermal): AE's vision aug has its own changes: keep it as AE draws it
static function bool OwnVision()
{
	return False;
}

defaultproperties
{
     BaseName="GMDX: Augmented Edition"
}
