//=============================================================================
// RIInventoryView
// Inventory, in the original gold. Left: the item grid (your real grid
// size, items at their real positions). Click an item to select it; with an
// item selected, click an empty cell to move it there. Right: the selected
// item (icon, description) and its actions. The action buttons mirror AE's
// own (hidden) ones, so Equip / Unequip, Use, Drop and Change Ammo are
// enabled and labelled exactly as AE decides, and run AE's own code.
// Drag an item onto a belt slot to assign it (AE's own belt code does it),
// drag between slots to swap, drag one off the belt to clear it, and drag
// items around the grid to move them. Rotating and the keyring list are on
// AE's page: "Classic view".
//=============================================================================
class RIInventoryView extends RIPersonaView;

const HOT_CELL    = 1000;   // + row * 32 + col
const HOT_EQUIP   = 50;
const HOT_USE     = 51;
const HOT_DROP    = 52;
const HOT_AMMO    = 53;
const HOT_CLASSIC = 54;
const HOT_ROTATE  = 55;
const HOT_BELT    = 900;    // + belt slot (0..11)
const HOT_LIST    = 700;    // + row in the ammo / nano key lists
const HOT_INFO    = 600;    // + AE info control (ammo choice, decline, mods)

var Inventory SelItem;
var float GX, GY, Cell;
var int   Cols, Rows;
var float DescAge;
var string Msg;
var float MsgAge;

// Sections: 0 items (grid), 1 ammo, 2 nano keys
var int   InvMode;
var int   NumList, ListSel;
var Inventory ListItems[64];
var NanoKeyInfo KeyInfos[64];
var float ListScroll, ListScrollTarget, ListMax, ListTop, ListBottom;

// Drag and drop
var Inventory DragItem;
var bool  bDragging, bDragFromBelt;
var float PressX, PressY;
var int   GrabCol, GrabRow;

// Item details as AE writes them (stats, ammo choices, decline and mod
// buttons), read from AE's hidden info panel and drawn here
var Window InfoWins[48];
var int    NumInfoWins;
var float  InfoScroll, InfoScrollTarget, InfoMax, InfoTop, InfoBottom;
var float  AmmoRowX, BtnRowX;
var string PendHead;      // section heading waiting for its first row with a value
var Window DeferBtn[8];   // AE's buttons (Decline...), drawn as one row after the details
var int    NumDefer;
var string InfoDesc;      // Sleek: the description, drawn at the top (AE's copy is skipped)
var bool   bStatsHead;    // Sleek: the STATS heading is drawn
var int    StatCol;       // Sleek spec sheet: stats fill two columns (0 left, 1 right)
var float  HdrBtnX, HdrBtnY, HdrBtnW;   // where the header button row goes (Sleek)

var localized string AmmoTitle, KeysTitle, NoAmmoLabel, NoKeysLabel, ListHint, RoundsLabel, PickListLabel;
var localized string RotateLabel, NoTurnLabel, NoTurnRoomLabel;
var localized string KindWeapon, KindAmmo, KindItem, SlotWord, EquippedWord;
var localized string StatsLabel, ClickLoadLabel;
var localized string InvTitle, CreditsLabel, KeysLabel, BeltLabel, ClassicLabel, PickLabel, NoRoomLabel, HintText;

// Vanilla+: the item page sits on the Inventory board (grid, belt, buttons)
function int VPBoard()
{
	return 1;    // items, ammo and keys all sit on the Inventory board
}

function bool VPFooterBar()
{
	return False;
}

function string VPDetailTitle()
{
	if ((InvMode == 0) && (SelItem != None))
		return KindLine(SelItem);
	return DetailLabel;
}

function bool VPItemDividers()
{
	return InvMode == 0;
}

function PersonaScreenInventory Inv()
{
	return PersonaScreenInventory(Screen);
}

function ScreenAttached()
{
	ActiveTab = TAB_INV;
	InvMode = Class'RIPersonaView'.default.PendingInvMode;
	Class'RIPersonaView'.default.PendingInvMode = 0;
	ListSel = -1;
}

function int CurrentSub()
{
	if (InvMode == 1)
		return TAB_AMMO;
	if (InvMode == 2)
		return TAB_KEYS;
	return TAB_INV;
}

// Items, ammo and keys are all this page
function bool LocalSub(int Id)
{
	if (Id == TAB_INV)
		InvMode = 0;
	else if (Id == TAB_AMMO)
		InvMode = 1;
	else if (Id == TAB_KEYS)
		InvMode = 2;
	else
		return False;
	ListSel = -1;
	ListScroll = 0;
	ListScrollTarget = 0;
	DragItem = None;
	bDragging = False;
	return True;
}

function Select(Inventory I)
{
	if (I == SelItem)
		return;
	SelItem = I;
	DescAge = 0;
	InfoScroll = 0;
	InfoScrollTarget = 0;
	if (I != None)
	{
		Inv().SelectInventoryItem(I);
		if ((Inv().winInfo != None) && ((Inv().selectedItem == None) || (Inv().selectedItem.GetClientObject() != I)))
			I.UpdateInfo(Inv().winInfo);
	}
	PlaySound(Sound'Menu_Press', 0.2);
}

function Inventory ItemAt(int col, int row)
{
	local Inventory I;

	for (I = Player.Inventory; I != None; I = I.Inventory)
		if ((I.invPosX >= 0) && (col >= I.invPosX) && (col < I.invPosX + I.invSlotsX)
			&& (row >= I.invPosY) && (row < I.invPosY + I.invSlotsY))
			return I;
	return None;
}

function bool Owned(Inventory I)
{
	local Inventory J;

	for (J = Player.Inventory; J != None; J = J.Inventory)
		if (J == I)
			return True;
	return False;
}

// ----------------------------------------------------------------------
// Belt (AE keeps it in the HUD belt; its persona copy does the assigning)
// ----------------------------------------------------------------------

function HUDObjectBelt HudBelt()
{
	if ((DeusExRootWindow(GetRootWindow()) == None) || (DeusExRootWindow(GetRootWindow()).hud == None))
		return None;
	return DeusExRootWindow(GetRootWindow()).hud.belt;
}

function int BeltCount()
{
	if (Class'RIUtil'.static.PBool(Player, "bBiggerBelt"))
		return 12;
	return 10;
}

function Inventory BeltItem(int i)
{
	if (HudBelt() == None)
		return None;
	return HudBelt().GetObjectFromBelt(i);
}

// False for the key ring's slot
function bool BeltSlotOpen(int i)
{
	if ((Inv().invBelt == None) || (Inv().invBelt.objBelt == None) || (Inv().invBelt.objBelt.objects[i] == None))
		return False;
	return Inv().invBelt.objBelt.objects[i].bAllowDragging;
}

function AssignBelt(Inventory I, int slot)
{
	if ((I == None) || (NanoKeyRing(I) != None) || !BeltSlotOpen(slot))
	{
		PlaySound(Sound'Menu_Cancel', 0.25);
		return;
	}
	Inv().invBelt.AddObject(I, slot);
	PlaySound(Sound'Menu_Press', 0.25);
}

function UnBelt(Inventory I)
{
	if ((I == None) || !I.bInObjectBelt || (NanoKeyRing(I) != None) || (Inv().invBelt == None))
		return;
	Inv().invBelt.RemoveObject(I);
	PlaySound(Sound'Menu_Press', 0.25);
}

function StartDrag(Inventory I, bool bFromBelt, int gc0, int gr0)
{
	DragItem = I;
	bDragging = False;
	bDragFromBelt = bFromBelt;
	PressX = LastMouseX;
	PressY = LastMouseY;
	GrabCol = gc0;
	GrabRow = gr0;
}

function PageRelease(float pointX, float pointY, EInputKey button)
{
	local int Id, row, col;
	local Inventory I;
	local bool bWas;

	if (button != IK_LeftMouse)
		return;
	I = DragItem;
	// A release away from the press counts as a drop even if no movement
	// was reported while the button was held
	bWas = bDragging || ((I != None) && (Abs(pointX - PressX) + Abs(pointY - PressY) > 8 * S));
	DragItem = None;
	bDragging = False;
	if (!bWas || (I == None) || !Owned(I))
		return;
	Id = HotAt(pointX, pointY);
	if ((Id >= HOT_BELT) && (Id < HOT_BELT + 12))
		AssignBelt(I, Id - HOT_BELT);
	else if (bDragFromBelt)
		UnBelt(I);          // dragged off the belt: clear the slot
	else if (Id >= HOT_CELL)
	{
		row = (Id - HOT_CELL) / 32;
		col = (Id - HOT_CELL) - row * 32;
		// dropped on another item: mods, ammo, cells and same-size swaps
		if (DropOnto(I, ItemAt(col, row)))
			return;
		SelItem = I;
		MoveTo(col - GrabCol, row - GrabRow);
	}
}

// ----------------------------------------------------------------------
// Dropping one item on another (AE's rules): a weapon mod on a weapon it
// fits, ammo on a weapon that takes it, a bioelectric cell on a charged
// item or the nanosword, or two items of the same size swapping places.
// ----------------------------------------------------------------------

// Whether dropping D on T does something (drawn green while dragging)
function bool CanDropOn(Inventory D, Inventory T)
{
	if ((D == None) || (T == None) || (D == T))
		return False;
	if ((WeaponMod(D) != None) && (DeusExWeapon(T) != None))
		return WeaponMod(D).CanUpgradeWeapon(DeusExWeapon(T));
	if ((DeusExAmmo(D) != None) && (DeusExWeapon(T) != None))
		return DeusExWeapon(T).CanLoadAmmoType(DeusExAmmo(D));
	// Recharging with a bioelectric cell (base feature: GMDX AE's)
	if (BioelectricCell(D) != None)
		return Class'RIBase'.static.CanCharge(Player, T);
	return False;
}

function bool DropOnto(Inventory D, Inventory T)
{
	local DeusExWeapon W;
	local int Charged;
	local string RMsg;
	local int tx, ty;

	if ((D == None) || (T == None) || (D == T))
		return False;

	W = DeusExWeapon(T);
	if ((WeaponMod(D) != None) && (W != None))
	{
		if (!WeaponMod(D).CanUpgradeWeapon(W))
			return DropRefused();
		WeaponMod(D).ApplyMod(W);
		Class'RIBase'.static.RemoveFromBelt(Player, D);
		Say(Sprintf(Class'PersonaScreenInventory'.default.WeaponUpgradedLabel, W.itemName));
		SelItem = None;
		WeaponMod(D).DestroyMod();
		Select(W);
		PlaySound(Sound'Menu_Press', 0.25);
		return True;
	}
	if ((DeusExAmmo(D) != None) && (W != None))
	{
		if (!W.CanLoadAmmoType(DeusExAmmo(D)))
			return DropRefused();
		W.LoadAmmoType(DeusExAmmo(D));
		Say(Sprintf(Class'PersonaScreenInventory'.default.AmmoLoadedLabel, D.itemName));
		Select(W);
		PlaySound(Sound'Menu_Press', 0.25);
		return True;
	}
	if (BioelectricCell(D) != None)
	{
		Charged = Class'RIBase'.static.Charge(Player, T, RMsg);
		if (Charged == 1)
			return DropRefused();
		if (Charged == 2)
		{
			Say(RMsg);
			Player.PlaySound(Sound'BioElectricHiss', SLOT_None,,, 256);
			BioelectricCell(D).UseOnce();
			RecreateBelts();
			Select(T);
			return True;
		}
	}

	// Same footprint: trade places
	if ((D.invSlotsX == T.invSlotsX) && (D.invSlotsY == T.invSlotsY) && (D.invPosX >= 0) && (T.invPosX >= 0))
	{
		tx = T.invPosX;
		ty = T.invPosY;
		Player.SetInvSlots(D, 0);
		Player.SetInvSlots(T, 0);
		Player.PlaceItemInSlot(T, D.invPosX, D.invPosY);
		Player.PlaceItemInSlot(D, tx, ty);
		SelItem = D;
		PlaySound(Sound'Menu_Press', 0.25);
		return True;
	}
	return False;
}

function bool DropRefused()
{
	PlaySound(Sound'Menu_Cancel', 0.25);
	return True;
}

function Say(string T)
{
	if (T == "")
		return;
	Msg = T;
	MsgAge = 0;
}

function RecreateBelts()
{
	if (Inv().invBelt == None)
		return;
	Class'RIBase'.static.RecreateBelt(Inv().invBelt.objBelt);
	Class'RIBase'.static.RecreateBelt(Inv().invBelt.hudBelt);
}

// Room for I at col, row, counting every other item where it actually is.
// (AE's IsEmptyItemSlot re-marks every item, the moving one included,
// unless AE's own screen is dragging, so it can't be used here.)
function bool FreeAt(Inventory I, int col, int row)
{
	local Inventory J;

	if ((I == None) || (col < 0) || (row < 0) || (col + I.invSlotsX > Cols) || (row + I.invSlotsY > Rows))
		return False;
	for (J = Player.Inventory; J != None; J = J.Inventory)
	{
		if ((J == I) || (J.invPosX < 0) || (J.invPosY < 0))
			continue;
		if ((col < J.invPosX + J.invSlotsX) && (J.invPosX < col + I.invSlotsX)
			&& (row < J.invPosY + J.invSlotsY) && (J.invPosY < row + I.invSlotsY))
			return False;
	}
	return True;
}

function MoveTo(int col, int row)
{
	if ((SelItem == None) || !FreeAt(SelItem, col, row))
	{
		NoRoom();
		return;
	}
	Player.SetInvSlots(SelItem, 0);
	Player.PlaceItemInSlot(SelItem, col, row);
	PlaySound(Sound'Menu_Press', 0.25);
}

// ----------------------------------------------------------------------
// Rotation (AE turns weapons only: they have the turned icons)
// ----------------------------------------------------------------------

function bool Rotatable(Inventory I)
{
	return Class'RIBase'.static.Has("Rotation") && (DeusExWeapon(I) != None) && (I.invSlotsX != I.invSlotsY) && (I.invPosX >= 0);
}

// Turn the item's shape and icon, the way AE's drag rotation does
function TurnShape(DeusExWeapon W)
{
	local int t;

	t = W.invSlotsX;
	W.invSlotsX = W.invSlotsY;
	W.invSlotsY = t;
	Class'RIBase'.static.TurnIcon(W);
	t = W.largeIconWidth;
	W.largeIconWidth = W.largeIconHeight;
	W.largeIconHeight = t;
}

function bool FitsAt(Inventory I, int col, int row)
{
	return FreeAt(I, col, row);
}

// Turn in place if it fits there, otherwise in the nearest place that fits
function RotateItem(Inventory I)
{
	local DeusExWeapon W;
	local int col, row, bc, br, d, bd;

	if (!Rotatable(I))
	{
		Msg = NoTurnLabel;
		MsgAge = 0;
		PlaySound(Sound'Menu_Cancel', 0.25);
		return;
	}
	W = DeusExWeapon(I);
	Player.SetInvSlots(W, 0);
	TurnShape(W);
	bc = -1;
	if (FitsAt(W, W.invPosX, W.invPosY))
	{
		bc = W.invPosX;
		br = W.invPosY;
	}
	else
	{
		bd = 99999;
		for (row = 0; row < Rows; row++)
			for (col = 0; col < Cols; col++)
			{
				if (!FitsAt(W, col, row))
					continue;
				d = Abs(col - W.invPosX) + Abs(row - W.invPosY);
				if (d < bd)
				{
					bd = d;
					bc = col;
					br = row;
				}
			}
	}
	if (bc < 0)
	{
		TurnShape(W);
		Player.SetInvSlots(W, 1);
		Msg = NoTurnRoomLabel;
		MsgAge = 0;
		PlaySound(Sound'Menu_Cancel', 0.25);
		return;
	}
	Player.PlaceItemInSlot(W, bc, br);
	GrabCol = 0;
	GrabRow = 0;
	PlaySound(Sound'Menu_Press', 0.25);
}

function NoRoom()
{
	Msg = NoRoomLabel;
	MsgAge = 0;
	PlaySound(Sound'Menu_Cancel', 0.25);
}

// AE's hidden buttons decide what is allowed and what it is called
function bool Live(Window B)
{
	return (B != None) && B.IsSensitive() && B.IsVisible(False);
}

function string LabelOf(PersonaActionButtonWindow B, string Fallback)
{
	local string T;

	if (B == None)
		return Fallback;
	T = Class'RIText'.static.Clean(B.buttonText);
	if (T == "")
		T = Fallback;
	return T;
}

function DoAction(int Id)
{
	if (SelItem == None)
		return;
	Inv().SelectInventoryItem(SelItem);
	if ((Id == HOT_EQUIP) && Live(Inv().btnEquip))
		Inv().ButtonActivated(Inv().btnEquip);
	else if ((Id == HOT_USE) && Live(Inv().btnUse))
		Inv().ButtonActivated(Inv().btnUse);
	else if ((Id == HOT_DROP) && Live(Inv().btnDrop))
		Inv().ButtonActivated(Inv().btnDrop);
	else if ((Id == HOT_AMMO) && Live(Inv().btnChangeAmmo))
		Inv().ButtonActivated(Inv().btnChangeAmmo);
	else
		return;
	PlaySound(Sound'Menu_Press', 0.25);
	if (!Owned(SelItem))
		SelItem = None;
}

function PageClick(int Id, EInputKey button, int numClicks)
{
	local Inventory I;
	local int col, row;

	if (InvMode != 0)
	{
		if ((button == IK_LeftMouse) && (Id >= HOT_LIST) && (Id < HOT_LIST + 64))
		{
			ListSel = Id - HOT_LIST;
			DescAge = 0;
			PlaySound(Sound'Menu_Press', 0.2);
		}
		else if ((button == IK_LeftMouse) && (Id == HOT_CLASSIC))
			SwitchView(True);
		return;
	}

	if (Id >= HOT_CELL)
	{
		row = (Id - HOT_CELL) / 32;
		col = (Id - HOT_CELL) - row * 32;
		I = ItemAt(col, row);
		if (button == IK_RightMouse)
		{
			// Right click: AE's equip / use shortcut
			if (I != None)
			{
				Select(I);
				if (Live(Inv().btnEquip))
					DoAction(HOT_EQUIP);
				else
					DoAction(HOT_USE);
			}
			return;
		}
		if (button != IK_LeftMouse)
			return;
		if (I != None)
		{
			if ((numClicks >= 2) && (I == SelItem))
			{
				if (Live(Inv().btnUse))
					DoAction(HOT_USE);
				else
					DoAction(HOT_EQUIP);
			}
			else
			{
				Select(I);
				StartDrag(I, False, col - I.invPosX, row - I.invPosY);
			}
		}
		else if (SelItem != None)
			MoveTo(col, row);
		return;
	}
	if ((Id >= HOT_BELT) && (Id < HOT_BELT + 12))
	{
		I = BeltItem(Id - HOT_BELT);
		if ((I == None) || (NanoKeyRing(I) != None) || !Owned(I))
			return;
		if (button == IK_RightMouse)
		{
			Select(I);
			if (Live(Inv().btnEquip))
				DoAction(HOT_EQUIP);
			else
				DoAction(HOT_USE);
			return;
		}
		if (button != IK_LeftMouse)
			return;
		if ((numClicks >= 2) && (I == SelItem))
		{
			if (Live(Inv().btnUse))
				DoAction(HOT_USE);
			else
				DoAction(HOT_EQUIP);
			return;
		}
		Select(I);
		StartDrag(I, True, 0, 0);
		return;
	}
	if (button != IK_LeftMouse)
		return;
	if (Id == HOT_ROTATE)
	{
		if (SelItem != None)
			RotateItem(SelItem);
		return;
	}
	if ((Id >= HOT_INFO) && (Id < HOT_INFO + 48))
	{
		InfoClick(Id - HOT_INFO);
		return;
	}
	if ((Id >= HOT_EQUIP) && (Id <= HOT_AMMO))
		DoAction(Id);
	else if (Id == HOT_CLASSIC)
		SwitchView(True);
}

function bool PageKey(EInputKey key, bool bRepeat)
{
	if (InvMode != 0)
	{
		if (key == IK_MouseWheelUp)
		{
			ListScrollTarget -= 90 * S;
			return True;
		}
		if (key == IK_MouseWheelDown)
		{
			ListScrollTarget += 90 * S;
			return True;
		}
		if ((key == IK_Up) && (NumList > 0))
		{
			ListSel = Max(0, ListSel - 1);
			DescAge = 0;
			return True;
		}
		if ((key == IK_Down) && (NumList > 0))
		{
			ListSel = Min(NumList - 1, ListSel + 1);
			DescAge = 0;
			return True;
		}
		return False;
	}
	if ((key == IK_MouseWheelUp) || (key == IK_MouseWheelDown))
	{
		if (key == IK_MouseWheelUp)
			InfoScrollTarget -= 70 * S;
		else
			InfoScrollTarget += 70 * S;
		return True;
	}
	if (((key == IK_Space) || (key == IK_R)) && !bRepeat)
	{
		if ((DragItem != None) && bDragging)
			RotateItem(DragItem);
		else if (SelItem != None)
			RotateItem(SelItem);
		return True;
	}
	if ((key == IK_Delete) && (SelItem != None))
	{
		DoAction(HOT_DROP);
		return True;
	}
	if ((key == IK_Enter) && !bRepeat && (SelItem != None))
	{
		if (Live(Inv().btnUse))
			DoAction(HOT_USE);
		else
			DoAction(HOT_EQUIP);
		return True;
	}
	return False;
}

function PageTick(float deltaSeconds)
{
	DescAge += deltaSeconds;
	MsgAge += deltaSeconds;
	ListScrollTarget = FClamp(ListScrollTarget, 0, FMax(0, ListMax));
	ListScroll += (ListScrollTarget - ListScroll) * FMin(1.0, deltaSeconds * 14.0);
	InfoScrollTarget = FClamp(InfoScrollTarget, 0, FMax(0, InfoMax));
	InfoScroll += (InfoScrollTarget - InfoScroll) * FMin(1.0, deltaSeconds * 14.0);
	if ((SelItem != None) && !Owned(SelItem))
		SelItem = None;
	if ((DragItem != None) && !Owned(DragItem))
	{
		DragItem = None;
		bDragging = False;
	}
	if ((DragItem != None) && !bDragging && (Abs(LastMouseX - PressX) + Abs(LastMouseY - PressY) > 8 * S))
		bDragging = True;
}

// ----------------------------------------------------------------------
// Drawing
// ----------------------------------------------------------------------

function DrawPage(GC gc, float a)
{
	local int c, r;
	local float x, y, cw, ch, iw, ih, k;
	local Inventory I;
	local bool bSel, bHot;
	local string N;
	local DeusExPickup P;

	if (InvMode != 0)
	{
		DrawListPage(gc, a);
		return;
	}
	// Grid
	Cols = Max(1, Player.maxInvCols);
	Rows = Max(1, Player.maxInvRows);
	if (VPlus())
	{
		// The board: the grid as large as fits the inset (395,174 587x642)
		// with an even margin, centred both ways
		Cell = float(int(FMin((587.0 - 28.0) / Cols, (642.0 - 28.0) / Rows))) * S;
		GX = OX + 395 * S + (587 * S - Cols * Cell) * 0.5;
		GY = 174 * S + (642 * S - Rows * Cell) * 0.5;
	}
	else
	{
		Heading(gc, OX + 140 * S, 170 * S, 680 * S, InvTitle, a);
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 140 * S, 170 * S, 680 * S, 40 * S,
			Caps(CreditsLabel) @ string(Player.Credits), AAcc(a), 2, 0.72);
		Cell = FMin(680 * S / Cols, 590 * S / Rows);
		GX = OX + 140 * S;
		GY = 240 * S;
	}
	for (r = 0; r < Rows; r++)
		for (c = 0; c < Cols; c++)
		{
			x = GX + c * Cell;
			y = GY + r * Cell;
			AddHot(HOT_CELL + r * 32 + c, x, y, Cell, Cell);
			// cells under an item aren't drawn: the item fills its whole area
			if (ItemAt(c, r) != None)
				continue;
			bHot = (HoverId == HOT_CELL + r * 32 + c);
			if (VPlus())
			{
				Class'RIText'.static.Box(gc, x, y, Cell + 1, Cell + 1, ADim(a));
				if (bHot && (SelItem != None))
					Class'RIText'.static.Box(gc, x + 2, y + 2, Cell - 4, Cell - 4, AHi(a));
				continue;
			}
			Fill(gc, x + 2, y + 2, Cell - 4, Cell - 4, C3(30, 25, 11, 0.55 * a));
			if (bHot && (SelItem != None) && (ItemAt(c, r) == None))
				Class'RIText'.static.Box(gc, x + 2, y + 2, Cell - 4, Cell - 4, AHi(a));
			else
				Class'RIText'.static.Box(gc, x + 2, y + 2, Cell - 4, Cell - 4, C3(70, 58, 28, a));
		}

	// Items
	for (I = Player.Inventory; I != None; I = I.Inventory)
	{
		if ((I.invPosX < 0) || (I.invPosY < 0))
			continue;
		x = GX + I.invPosX * Cell + 2;
		y = GY + I.invPosY * Cell + 2;
		cw = I.invSlotsX * Cell - 4;
		ch = I.invSlotsY * Cell - 4;
		bSel = (I == SelItem);
		if (VPlus())
		{
			// the lattice runs round the item's footprint; the item is one
			// tile set evenly inside it, over darkened glass
			Class'RIText'.static.Box(gc, GX + I.invPosX * Cell, GY + I.invPosY * Cell, I.invSlotsX * Cell + 1, I.invSlotsY * Cell + 1, ADim(a));
			x = GX + I.invPosX * Cell + 5 * S;
			y = GY + I.invPosY * Cell + 5 * S;
			cw = I.invSlotsX * Cell - 10 * S;
			ch = I.invSlotsY * Cell - 10 * S;
			Piece(gc, x, y, cw, ch, 2, C3(0, 0, 0, 0));
			Fill(gc, x, y, cw, ch, C3(45, 38, 23, a));
		}
		else
			Fill(gc, x, y, cw, ch, C3(61, 50, 23, 0.6 * a));
		if (bSel)
			SelRow(gc, x, y, cw, ch, a);
		else
			Class'RIText'.static.Box(gc, x, y, cw, ch, AEdge(a));
		// while dragging, what the dragged item can be dropped on shows green
		if (bDragging && CanDropOn(DragItem, I))
			Class'RISkin'.static.Box2(gc, x, y, cw, ch, AGood(a));
		if (I.largeIcon != None)
		{
			iw = FMax(1, I.largeIconWidth);
			ih = FMax(1, I.largeIconHeight);
			k = FMin((cw - 12 * S) / iw, (ch - 30 * S) / ih);
			if (k >= 1)
				k = float(int(k));      // whole-number scale: even pixels
			gc.SetStyle(DSTY_Masked);
			gc.SetTileColor(C3(255, 255, 255, a));
			Class'RIHD'.static.DrawStretched(gc, x + (cw - iw * k) * 0.5, y + 6 * S + (ch - 30 * S - ih * k) * 0.5, iw * k, ih * k,
				0, 0, iw, ih, I.largeIcon);
		}
		N = I.beltDescription;
		if (N == "")
			N = I.ItemName;
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x + 6 * S, y + ch - 24 * S, cw - 12 * S, 22 * S,
			Caps(Class'RIText'.static.Fit(Class'RIFontSmall', N, cw - 12 * S, 0.6)), ATxt(a), 0, 0.6);
		P = DeusExPickup(I);
		if ((P != None) && (P.NumCopies > 1))
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, y + 4 * S, cw - 8 * S, 20 * S, string(P.NumCopies), AHi(a), 2, 0.66);
	}

	// Belt (read-only here: arrange it on the classic page)
	DrawBelt(gc, a);


	if (VPlus())
		DrawVPDetail(gc, a);
	else
	{
		DrawDetail(gc, a);
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', OX + 140 * S, FY + FH + 22 * S, HintText, ALbl(a * 0.8), 0.7);
	}

	// The item being dragged: its real footprint, snapped to the cells under
	// the cursor (gold where it fits, red where it doesn't); off the grid it
	// follows the cursor
	if (bDragging && (DragItem != None))
		DrawDragGhost(gc, a);
}

function DrawDragGhost(GC gc, float a)
{
	local float ghx, ghy, gw, gh, iw, ih, k;
	local int tc, tr;
	local bool bSnap, bOk;

	gw = DragItem.invSlotsX * Cell - 4;
	gh = DragItem.invSlotsY * Cell - 4;
	bSnap = (LastMouseX >= GX) && (LastMouseY >= GY) && (LastMouseX < GX + Cols * Cell) && (LastMouseY < GY + Rows * Cell);
	if (bSnap)
	{
		tc = int((LastMouseX - GX) / Cell) - GrabCol;
		tr = int((LastMouseY - GY) / Cell) - GrabRow;
		bOk = FreeAt(DragItem, tc, tr);
		ghx = GX + tc * Cell + 2;
		ghy = GY + tr * Cell + 2;
	}
	else
	{
		ghx = LastMouseX - (GrabCol + 0.5) * Cell;
		ghy = LastMouseY - (GrabRow + 0.5) * Cell;
	}
	Class'RISkin'.static.DrawDim(gc, ghx, ghy, gw, gh, 0.6);
	Fill(gc, ghx, ghy, gw, gh, C3(61, 50, 23, 0.5 * a));
	if (!bSnap)
		Class'RIText'.static.Box(gc, ghx, ghy, gw, gh, AEdge(a));
	else if (bOk)
		Class'RISkin'.static.Box2(gc, ghx, ghy, gw, gh, AHi(a));
	else
		Class'RISkin'.static.Box2(gc, ghx, ghy, gw, gh, ABad(a));
	if (DragItem.largeIcon != None)
	{
		iw = FMax(1, DragItem.largeIconWidth);
		ih = FMax(1, DragItem.largeIconHeight);
		k = FMin((gw - 12 * S) / iw, (gh - 12 * S) / ih);
		if (k >= 1)
			k = float(int(k));
		gc.SetStyle(DSTY_Masked);
		gc.SetTileColor(C3(255, 255, 255, a));
		Class'RIHD'.static.DrawStretched(gc, ghx + (gw - iw * k) * 0.5, ghy + (gh - ih * k) * 0.5, iw * k, ih * k, 0, 0, iw, ih, DragItem.largeIcon);
	}
}

// ----------------------------------------------------------------------
// Ammo and nano key sections
// ----------------------------------------------------------------------

function GatherList()
{
	local Inventory I;
	local NanoKeyInfo K;

	NumList = 0;
	if (InvMode == 1)
	{
		for (I = Player.Inventory; I != None; I = I.Inventory)
			if ((DeusExAmmo(I) != None) && !I.IsA('AmmoNone') && (NumList < 64))
				ListItems[NumList++] = I;
	}
	else
	{
		for (K = Player.KeyList; K != None; K = K.NextKey)
			if (NumList < 64)
				KeyInfos[NumList++] = K;
	}
	if (ListSel >= NumList)
		ListSel = NumList - 1;
}

function DrawListPage(GC gc, float a)
{
	local float x, y, w, rh, f, sh, kh;
	local int n, mx, st;
	local bool bSel, bHot;
	local DeusExAmmo Am;
	local string T;

	GatherList();
	if (VPlus())
		DrawVPBeltItems(gc, a);
	if (!VPlus())
	{
		if (InvMode == 1)
			Heading(gc, OX + 140 * S, 170 * S, 1000 * S, AmmoTitle, a);
		else
			Heading(gc, OX + 140 * S, 170 * S, 1000 * S, KeysTitle, a);
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 140 * S, 170 * S, 1000 * S, 40 * S,
			Caps(CreditsLabel) @ string(Player.Credits), AAcc(a), 2, 0.72);
	}

	x = OX + 140 * S;
	w = 1000 * S;
	if (InvMode == 1)
		rh = 66 * S;
	else
		rh = 52 * S;
	ListTop = 240 * S;
	ListBottom = 940 * S;
	if (VPlus())
	{
		// inside the left frame (the section row is in its header)
		x = OX + 402 * S;
		w = 560 * S;
		ListTop = 182 * S;
		ListBottom = 808 * S;
	}
	st = gc.PushGC();
	gc.Intersect(x - 4 * S, ListTop, w + 8 * S, ListBottom - ListTop);
	y = ListTop - ListScroll;
	for (n = 0; n < NumList; n++)
	{
		bSel = (n == ListSel);
		bHot = (HoverId == HOT_LIST + n);
		Fill(gc, x, y, w, rh, C3(30, 25, 11, 0.5 * a));
		if (bSel)
			SelRow(gc, x, y, w, rh, a);
		else if (bHot)
			Class'RIText'.static.Box(gc, x, y, w, rh, AEdge(a));
		else
			Class'RIText'.static.HLine(gc, x + 8 * S, y + rh, w - 16 * S, C3(60, 50, 24, a));

		if (InvMode == 1)
		{
			Am = DeusExAmmo(ListItems[n]);
			if (Am.icon != None)
			{
				gc.SetStyle(DSTY_Masked);
				gc.SetTileColor(C3(255, 255, 255, a));
				Class'RIHD'.static.DrawStretched(gc, x + 14 * S, y + (rh - 46 * S) * 0.5, 52 * S, 46 * S, 0, 0, 42, 37, Am.icon);
			}
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x + 84 * S, y + 6 * S, w - 304 * S, 32 * S,
				Caps(Class'RIText'.static.Fit(Class'RIFontHead', Am.ItemName, w - 304 * S, 0.56)),
				Class'RIUtil'.static.Mix(ATxt(a), C3(255, 255, 255, a), int(bSel)), 0, 0.56);
			mx = Max(1, Class'RIBase'.static.MaxAmmo(Player, Am));
			f = FClamp(float(Am.AmmoAmount) / float(mx), 0, 1);
			Fill(gc, x + 84 * S, y + rh - 18 * S, w - 304 * S, 5 * S, C3(40, 33, 15, a));
			Fill(gc, x + 84 * S, y + rh - 18 * S, (w - 304 * S) * f, 5 * S, AAcc(a));
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x + w - 260 * S, y, 240 * S, rh,
				string(Am.AmmoAmount) $ " / " $ string(mx), AHi(a), 2, 0.6);
		}
		else
		{
			T = KeyInfos[n].Description;
			if (T == "")
				T = string(KeyInfos[n].KeyID);
			Class'RIText'.static.DrawIn(gc, Class'RIFontBody', x + 20 * S, y, w - 40 * S, rh,
				Class'RIText'.static.Fit(Class'RIFontBody', T, w - 40 * S, 0.8),
				Class'RIUtil'.static.Mix(ATxt(a), C3(255, 255, 255, a), int(bSel)), 0, 0.8);
		}
		if ((y + rh > ListTop) && (y < ListBottom))
			AddHot(HOT_LIST + n, x, FMax(y, ListTop), w, FMin(y + rh, ListBottom) - FMax(y, ListTop));
		y += rh + 6 * S;
	}
	gc.PopGC(st);
	ListMax = FMax(0, (y + ListScroll - ListTop) - (ListBottom - ListTop));
	if (ListMax > 1)
	{
		sh = ListBottom - ListTop;
		kh = FMax(30 * S, sh * sh / (sh + ListMax));
		Fill(gc, x + w + 10 * S, ListTop, 2 * S, sh, C3(50, 42, 20, a));
		Fill(gc, x + w + 10 * S, ListTop + (sh - kh) * (ListScroll / ListMax), 2 * S, kh, AAcc(a));
	}
	if (NumList == 0)
	{
		if (InvMode == 1)
			Class'RIText'.static.Draw(gc, Class'RIFontBody', x, ListTop, NoAmmoLabel, ALbl(a), 0.8);
		else
			Class'RIText'.static.Draw(gc, Class'RIFontBody', x, ListTop, NoKeysLabel, ALbl(a), 0.8);
	}

	DrawListDetail(gc, a);
	if (!VPlus())
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', OX + 140 * S, FY + FH + 22 * S, ListHint, ALbl(a * 0.8), 0.7);
}

function DrawListDetail(GC gc, float a)
{
	local float x, y, w, h, da, iw, ih, k;
	local DeusExAmmo Am;
	local string T, D;
	local int st;

	da = a * Class'RIUtil'.static.Phase(DescAge, 0.0, 0.2);
	if (VPlus())
	{
		DrawVPListDetail(gc, a, da);
		return;
	}
	x = OX + 1180 * S;
	y = 240 * S;
	w = 600 * S;
	h = 700 * S;
	Panel(gc, x, y, w, h, a);
	x += 26 * S;
	w -= 52 * S;
	y += 24 * S;

	if ((ListSel < 0) || (ListSel >= NumList))
		Class'RIText'.static.Draw(gc, Class'RIFontBody', x, y, PickListLabel, ALbl(a), 0.8);
	else if (InvMode == 1)
	{
		Am = DeusExAmmo(ListItems[ListSel]);
		Class'RIText'.static.Draw(gc, Class'RIFontTitle', x + (1 - da) * 8 * S, y, Caps(Class'RIText'.static.Fit(Class'RIFontTitle', Am.ItemName, w, 0.42)), ATxt(da), 0.42);
		y += 56 * S;
		CGlow(gc, x + w * 0.1, y, w * 0.8, 200 * S, C3(36, 30, 13, da));
		if (Am.largeIcon != None)
		{
			iw = FMax(1, Am.largeIconWidth);
			ih = FMax(1, Am.largeIconHeight);
			k = FMin((w - 40 * S) / iw, 180 * S / ih);
			if (k >= 1)
				k = float(int(k));
			gc.SetStyle(DSTY_Masked);
			gc.SetTileColor(C3(255, 255, 255, da));
			Class'RIHD'.static.DrawStretched(gc, x + (w - iw * k) * 0.5, y + 10 * S + (180 * S - ih * k) * 0.5, iw * k, ih * k, 0, 0, iw, ih, Am.largeIcon);
		}
		y += 210 * S;
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, Caps(RoundsLabel) @ string(Am.AmmoAmount) $ " / " $ string(Class'RIBase'.static.MaxAmmo(Player, Am)), AAcc(da), 0.72);
		y += 34 * S;
		D = Am.GetPropertyText("Description");
		Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x, y, w, Class'RIConView'.static.Lines(D), C3(230, 210, 165, da), 0.74, 1.38);
	}
	else
	{
		T = KeyInfos[ListSel].Description;
		if (T == "")
			T = string(KeyInfos[ListSel].KeyID);
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, Caps(KeysTitle), AAcc(da), 0.72);
		y += 34 * S;
		Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x + (1 - da) * 8 * S, y, w, T, ATxt(da), 0.86, 1.38);
	}

}

function DrawBelt(GC gc, float a)
{
	local Inventory I;
	local int n, cnt;
	local float y, w, sx, k, ih;
	local bool bHot;
	local Texture T;
	local string BName;
	local float bx0, pitch, pad;

	cnt = BeltCount();
	if (VPlus())
	{
		// The board's ten slots
		cnt = Min(cnt, 10);
		pitch = 114.8 * S;
		w = BeltSlotW() * S;
		bx0 = OX + BeltSlotX(0) * S;
		pad = 0;
		y = 912 * S;
		ih = 94 * S;
	}
	else
	{
		w = 720 * S / cnt;
		pitch = w;
		bx0 = OX + 140 * S;
		y = 860 * S;
		ih = 70 * S;
		pad = 2;
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', OX + 140 * S, y - 26 * S, Caps(BeltLabel), ALbl(a), 0.66);
	}
	for (n = 0; n < cnt; n++)
	{
		sx = bx0 + n * pitch;
		I = BeltItem(n);
		bHot = (HoverId == HOT_BELT + n);
		if (!VPlus())
			Fill(gc, sx + pad, y, w - 2 * pad, ih, C3(30, 25, 11, 0.55 * a));
		if (bDragging && bHot)
		{
			if (BeltSlotOpen(n))
			{
				CGlow(gc, sx - 6 * S, y - 6 * S, w + 12 * S, ih + 12 * S, C3(60, 50, 22, a));
				Class'RISkin'.static.Box2(gc, sx + pad, y, w - 2 * pad, ih, AHi(a));
			}
			else
				Class'RISkin'.static.Box2(gc, sx + pad, y, w - 2 * pad, ih, ABad(a));
		}
		else if ((I != None) && (I == SelItem))
			SelRow(gc, sx + pad, y, w - 2 * pad, ih, a * Class'RIUtil'.static.EaseOut(FClamp(DescAge / 0.25, 0, 1)));
		else if (bHot && (I != None))
			Class'RIText'.static.Box(gc, sx + pad, y, w - 2 * pad, ih, C3(150, 126, 62, a));
		else if (VPlus())
		{
			// the board draws the slot
		}
		else if (I != None)
			Class'RIText'.static.Box(gc, sx + pad, y, w - 2 * pad, ih, AEdge(a));
		else
			Class'RIText'.static.Box(gc, sx + pad, y, w - 2 * pad, ih, C3(70, 58, 28, a));
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', sx + 8 * S, y + 4 * S, Mid("0123456789-=", n, 1), AAcc(a), 0.6);

		// Icon (AE's belt icons are 42 x 37 in the corner of the texture);
		// an empty slot that remembers an item shows it dimmed
		T = None;
		if (I != None)
			T = I.icon;
		else
			T = Class'RIBase'.static.BeltPlaceholder(Player, n);
		if (T != None)
		{
			k = FMin((w - 16 * S) / 42.0, (ih - 24 * S) / 37.0);
			if (k >= 1)
				k = float(int(k));
			gc.SetStyle(DSTY_Masked);
			if (I != None)
				gc.SetTileColor(C3(255, 255, 255, a));
			else
				gc.SetTileColor(C3(90, 90, 90, a));
			Class'RIHD'.static.DrawStretched(gc, sx + (w - 42 * k) * 0.5, y + 6 * S + (ih - 24 * S - 37 * k) * 0.5, 42 * k, 37 * k, 0, 0, 42, 37, T);
		}
		if (I != None)
		{
			BName = I.beltDescription;
			if (BName == "")
				BName = I.ItemName;
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', sx + 6 * S, y + ih - 20 * S, w - 12 * S, 18 * S,
				Caps(Class'RIText'.static.Fit(Class'RIFontSmall', BName, w - 12 * S, 0.52)), ATxt(a), 1, 0.52);
		}
		AddHot(HOT_BELT + n, sx, y, w, ih);
	}
}

// ----------------------------------------------------------------------
// Item details: AE's own info panel (filled by the item's UpdateInfo) read
// in order and drawn in this style. Stat rows become label / value lines,
// ammo choices become tiles (click to load), and AE's buttons (Decline,
// Decline Global, weapon mods...) become small buttons that run AE's code.
// Scrolls with the wheel.
// ----------------------------------------------------------------------

function DrawInfo(GC gc, float X, float Top, float W, float Bottom, float da)
{
	local int st;
	local float y, th;
	local string D;

	NumInfoWins = 0;
	PendHead = "";
	NumDefer = 0;
	StatCol = 0;
	InfoTop = Top;
	InfoBottom = Bottom;
	st = gc.PushGC();
	gc.Intersect(X - 2 * S, Top, W + 4 * S, Bottom - Top);
	y = Top - InfoScroll;
	AmmoRowX = -1;
	BtnRowX = -1;
	bStatsHead = False;
	InfoDesc = "";
	if (!VPlus())
	{
		InfoDesc = Class'RIConView'.static.Lines(SelItem.GetPropertyText("Description"));
		if ((InfoDesc != "") && (InStr(InfoDesc, "<END NOTE>") < 0))
			y += Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', X, y, W - 14 * S, InfoDesc, C3(217, 196, 150, da), 0.72, 1.45) + 4 * S;
		else
			InfoDesc = "";
	}
	if ((Inv().winInfo != None) && (Inv().winInfo.winTile != None))
		y = InfoTree(gc, Inv().winInfo.winTile, X, y, W, da);
	y = EndRows(y);
	y = CloseStat(y);
	if (VPlus())
		y = DrawDeferredBtns(gc, X, y, W, da, False);
	if ((y <= Top - InfoScroll + 1) && (InfoDesc == ""))
	{
		// AE wrote nothing: fall back to the description
		D = SelItem.GetPropertyText("Description");
		th = Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', X, Top - InfoScroll, W - 14 * S,
			Class'RIConView'.static.Lines(D), C3(230, 210, 165, da), 0.74, 1.38);
		y = Top - InfoScroll + th;
	}
	gc.PopGC(st);
	InfoMax = FMax(0, (y + InfoScroll) - Bottom + 10 * S);
	if (InfoMax > 1)
	{
		th = FMax(30 * S, (Bottom - Top) * (Bottom - Top) / (Bottom - Top + InfoMax));
		Fill(gc, X + W - 2 * S, Top, 1 * S, Bottom - Top, C3(30, 25, 11, da));
		Fill(gc, X + W - 3 * S, Top + (Bottom - Top - th) * (InfoScroll / InfoMax), 3 * S, th, C3(126, 105, 50, da));
	}
}

// Close an open row of ammo tiles or buttons
function float EndRows(float y)
{
	if (AmmoRowX >= 0)
		y += 62 * S;
	if (BtnRowX >= 0)
		y += 36 * S;
	AmmoRowX = -1;
	BtnRowX = -1;
	return y;
}

// AE's item buttons (Decline, Decline Global, mods...) as one row at the end
function float DrawDeferredBtns(GC gc, float X, float y, float W, float da, bool bFree)
{
	local int i;
	local float bx, bw;
	local string T;
	local bool bOn;

	if (NumDefer == 0)
		return y;
	y += 10 * S;
	bx = X;
	for (i = 0; i < NumDefer; i++)
	{
		T = LabelOf(PersonaActionButtonWindow(DeferBtn[i]), "");
		bw = Class'RIText'.static.Width(Class'RIFontSmall', Caps(T), 0.54) + 26 * S;
		if ((bx > X) && (bx + bw > X + W))
		{
			bx = X;
			y += 34 * S;
		}
		bOn = DeferBtn[i].IsSensitive();
		Class'RIText'.static.Box(gc, bx, y, bw, 26 * S, ADim(da));
		if (bOn)
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', bx, y, bw, 26 * S, Caps(T),
				Class'RIUtil'.static.Mix(ATxt(da), AHi(da), int(HoverId == HOT_INFO + NumInfoWins)), 1, 0.54);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', bx, y, bw, 26 * S, Caps(T), ALbl(da * 0.6), 1, 0.54);
		if (bOn && (NumInfoWins < 48) && bFree)
		{
			InfoWins[NumInfoWins] = DeferBtn[i];
			AddHot(HOT_INFO + NumInfoWins, bx, y, bw, 26 * S);
			NumInfoWins++;
		}
		else if (bOn && (NumInfoWins < 48) && InView(y, 26 * S))
		{
			InfoWins[NumInfoWins] = DeferBtn[i];
			AddHot(HOT_INFO + NumInfoWins, bx, FMax(y, InfoTop), bw, FMin(y + 26 * S, InfoBottom) - FMax(y, InfoTop));
			NumInfoWins++;
		}
		bx += bw + 8 * S;
	}
	return y + 34 * S;
}

// Finish a half-filled row of two-column stats
function float CloseStat(float y)
{
	if (StatCol == 1)
	{
		StatCol = 0;
		return y + 34 * S;
	}
	return y;
}

// Cut "|n" and spaces from both ends
static function string TrimBreaks(string T)
{
	while ((Left(T, 2) == "|n") || (Left(T, 1) == " "))
	{
		if (Left(T, 2) == "|n")
			T = Mid(T, 2);
		else
			T = Mid(T, 1);
	}
	while ((Right(T, 2) == "|n") || (Right(T, 1) == " "))
	{
		if (Right(T, 2) == "|n")
			T = Left(T, Len(T) - 2);
		else
			T = Left(T, Len(T) - 1);
	}
	return T;
}

// "Intro <UNATCO OPS FILE NOTE X> body -- Author <END NOTE> rest": the intro
// as a paragraph, the note as a card (label, body, author), then the rest
function float DrawNoteText(GC gc, float X, float y, float W, string T, float da)
{
	local int p, q, e, d;
	local string Pre, Lbl, Body, Auth, Post;
	local float bh, ah;

	p = InStr(T, "<");
	Pre = TrimBreaks(Left(T, p));
	T = Mid(T, p + 1);
	q = InStr(T, ">");
	Lbl = Left(T, q);
	T = Mid(T, q + 1);
	e = InStr(T, "<END NOTE>");
	Body = Left(T, e);
	Post = TrimBreaks(Mid(T, e + 10));
	Auth = "";
	d = InStr(Body, "--");
	if (d >= 0)
	{
		Auth = TrimBreaks(Mid(Body, d + 2));
		Body = Left(Body, d);
	}
	Body = TrimBreaks(Body);

	if (Pre != "")
		y += Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', X, y, W, Pre, C3(230, 210, 165, da), 0.72, 1.36) + 10 * S;
	bh = Class'RIText'.static.DrawWrapped(None, Class'RIFontBody', 0, 0, W - 32 * S, Body, C3(0, 0, 0, 0), 0.68, 1.4);
	ah = 0;
	if (Auth != "")
		ah = 26 * S;
	Fill(gc, X, y, W, bh + ah + 52 * S, C3(20, 16, 7, 0.6 * da));
	Class'RIText'.static.Box(gc, X, y, W, bh + ah + 52 * S, C3(70, 58, 28, da));
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', X + 16 * S, y + 12 * S, Caps(Lbl), ALbl(da), 0.5);
	Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', X + 16 * S, y + 36 * S, W - 32 * S, Body, C3(222, 202, 158, da), 0.68, 1.4);
	if (Auth != "")
		Class'RIText'.static.Draw(gc, Class'RIFontBody', X + 16 * S, y + 40 * S + bh, Auth, ALbl(da), 0.62);
	y += bh + ah + 62 * S;
	if (Post != "")
		y += Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', X, y, W, Post, C3(230, 210, 165, da), 0.72, 1.36) + 8 * S;
	return y;
}

// Draw the pending section heading (small gold label with a rule)
function float FlushHead(GC gc, float X, float y, float W, float da)
{
	if (PendHead == "")
		return y;
	y = CloseStat(y);
	y += 14 * S;
	SectionHead(gc, X, y, W, PendHead, "", da);
	PendHead = "";
	return y + 30 * S;
}

// AMMO ---------------------- CLICK TO LOAD
function SectionHead(GC gc, float X, float y, float W, string T, string Hint, float da)
{
	local float tw, hw;

	T = Caps(T);
	tw = Class'RIText'.static.Width(Class'RIFontSmall', T, 0.54);
	hw = 0;
	if (Hint != "")
	{
		hw = Class'RIText'.static.Width(Class'RIFontSmall', Caps(Hint), 0.46);
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X + W - 12 * S - hw, y, hw, 20 * S, Caps(Hint), C3(110, 94, 50, da), 0, 0.46);
		hw += 14 * S;
	}
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, y, tw, 20 * S, T, AAcc(da), 0, 0.54);
	Class'RIText'.static.HLine(gc, X + tw + 14 * S, y + 10 * S, W - 12 * S - tw - 14 * S - hw, C3(46, 38, 18, da));
}

// "60% (+4%) = 64%": the result, and the bonus on its own
function bool SplitBonus(string V, out string Res, out string Bonus)
{
	local int p, q, e;

	e = InStr(V, " = ");
	p = InStr(V, "(");
	q = InStr(V, ")");
	if ((e < 0) || (p < 0) || (q < p))
		return False;
	Res = Mid(V, e + 3);
	Bonus = Mid(V, p + 1, q - p - 1);
	return True;
}

function bool InView(float y, float h)
{
	return (y + h > InfoTop) && (y < InfoBottom);
}

function float InfoTree(GC gc, Window Parent, float X, float y, float W, float da)
{
	local Window C;
	local PersonaInfoItemWindow Row;
	local PersonaAmmoDetailButton AB;
	local string L, V, T;
	local float lw, th, bw, ax;
	local string Bn;
	local Texture Ic;
	local bool bOn;

	for (C = Parent.GetBottomChild(); C != None; C = C.GetHigherSibling())
	{
		if (!C.IsVisible(False))
			continue;

		// Ammo choice: a tile with the ammo's icon and rounds
		if (C.IsA('PersonaAmmoDetailButton'))
		{
			AB = PersonaAmmoDetailButton(C);
			if (BtnRowX >= 0)
				y = EndRows(y);
			y = CloseStat(y);
			if ((AmmoRowX < 0) && !VPlus() && (PendHead != ""))
			{
				y += 14 * S;
				SectionHead(gc, X, y, W, PendHead, ClickLoadLabel, da);
				PendHead = "";
				y += 30 * S;
			}
			else if (AmmoRowX < 0)
				y = FlushHead(gc, X, y, W, da);
			if ((AmmoRowX < 0) || (AmmoRowX + 152 * S > X + W))
			{
				if (AmmoRowX >= 0)
					y += 62 * S;
				AmmoRowX = X;
			}
			ax = AmmoRowX;
			bOn = AB.bSelected || AB.bLoaded;
			if (bOn)
			{
				Fill(gc, ax, y, 142 * S, 52 * S, C3(40, 33, 15, da));
				Class'RIText'.static.Box(gc, ax, y, 142 * S, 52 * S, C3(242, 211, 107, da));
			}
			else
			{
				Fill(gc, ax, y, 142 * S, 52 * S, C3(14, 11, 5, 0.7 * da));
				Class'RIText'.static.Box(gc, ax, y, 142 * S, 52 * S, C3(46, 38, 18, da));
			}
			if (AB.ammo != None)
			{
				Ic = AB.ammo.default.Icon;
				if (Ic != None)
				{
					gc.SetStyle(DSTY_Masked);
					if (AB.bHasIt)
						gc.SetTileColor(C3(255, 255, 255, da));
					else
						gc.SetTileColor(C3(90, 90, 90, da));
					Class'RIHD'.static.DrawStretched(gc, ax + 8 * S, y + 7 * S, 43 * S, 38 * S, 0, 0, FMin(42, Ic.USize), FMin(37, Ic.VSize), Ic);
				}
				T = Class<DeusExAmmo>(AB.ammo).default.beltDescription;
				if (T == "")
					T = AB.ammo.default.ItemName;
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', ax + 60 * S, y + 8 * S, 76 * S, 16 * S, Caps(Class'RIText'.static.Fit(Class'RIFontSmall', T, 76 * S, 0.44)), AAcc(da), 0, 0.44);
				Class'RIText'.static.DrawIn(gc, Class'RIFontBody', ax + 60 * S, y + 24 * S, 76 * S, 22 * S, string(AB.rounds), C3(255, 241, 194, da), 0, 0.66);
			}
			if ((NumInfoWins < 48) && InView(y, 52 * S))
			{
				InfoWins[NumInfoWins] = C;
				AddHot(HOT_INFO + NumInfoWins, ax, FMax(y, InfoTop), 142 * S, FMin(y + 52 * S, InfoBottom) - FMax(y, InfoTop));
				NumInfoWins++;
			}
			AmmoRowX = ax + 152 * S;
			continue;
		}

		// AE's buttons in the panel (Decline, Decline Global, mods, perks)
		if (C.IsA('PersonaActionButtonWindow'))
		{
			T = LabelOf(PersonaActionButtonWindow(C), "");
			if (T == "")
				continue;
			// held for one tidy row after the details
			if (NumDefer < 8)
			{
				DeferBtn[NumDefer++] = C;
				continue;
			}
			if (AmmoRowX >= 0)
				y = EndRows(y);
			if (BtnRowX < 0)
				y = FlushHead(gc, X, y, W, da);
			bw = Class'RIText'.static.Width(Class'RIFontSmall', Caps(T), 0.56) + 28 * S;
			if ((BtnRowX < 0) || (BtnRowX + bw > X + W))
			{
				if (BtnRowX >= 0)
					y += 36 * S;
				BtnRowX = X;
			}
			bOn = C.IsSensitive();
			Class'RIText'.static.Box(gc, BtnRowX, y, bw, 28 * S, ADim(da));
			if (bOn)
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', BtnRowX, y, bw, 28 * S, Caps(T),
					Class'RIUtil'.static.Mix(ATxt(da), AHi(da), int(HoverId == HOT_INFO + NumInfoWins)), 1, 0.56);
			else
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', BtnRowX, y, bw, 28 * S, Caps(T), ALbl(da * 0.6), 1, 0.56);
			if (bOn && (NumInfoWins < 48) && InView(y, 28 * S))
			{
				InfoWins[NumInfoWins] = C;
				AddHot(HOT_INFO + NumInfoWins, BtnRowX, FMax(y, InfoTop), bw, FMin(y + 28 * S, InfoBottom) - FMax(y, InfoTop));
				NumInfoWins++;
			}
			BtnRowX += bw + 8 * S;
			continue;
		}

		// Stat row: label, then value (values can run to several lines)
		if (C.IsA('PersonaInfoItemWindow'))
		{
			y = EndRows(y);
			Row = PersonaInfoItemWindow(C);
			L = "";
			V = "";
			if (Row.winLabel != None)
				L = Row.winLabel.GetText();
			if (Row.winText != None)
				V = Row.winText.GetText();
			if (Right(L, 1) == ":")
				L = Left(L, Len(L) - 1);
			V = OneLine(V);
			while (Left(V, 1) == " ")
				V = Mid(V, 1);
			// AE lists every mod slot; only the ones with a value are shown
			if (V == "")
				continue;
			y = FlushHead(gc, X, y, W, da);
			// Sleek spec sheet: two columns, small label left, value right
			if (!VPlus())
			{
				// the ammo tiles already show what's loaded and what fits
				if ((DeusExWeapon(SelItem) != None) && (Left(Caps(L), 4) == "AMMO"))
					continue;
				if (!bStatsHead && (StatCol == 0))
				{
					bStatsHead = True;
					y += 14 * S;
					SectionHead(gc, X, y, W, StatsLabel, "", da);
					y += 26 * S;
				}
				lw = (W - 52 * S) / 2;
				ax = X + StatCol * (lw + 40 * S);
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', ax, y, lw * 0.55, 30 * S,
					Caps(Class'RIText'.static.Fit(Class'RIFontSmall', L, lw * 0.55, 0.48)), C3(140, 119, 64, da), 0, 0.48);
				if (SplitBonus(V, T, Bn))
				{
					bw = Class'RIText'.static.Width(Class'RIFontSmall', Bn, 0.48);
					Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', ax + lw - bw, y, bw, 30 * S, Bn, C3(159, 212, 138, da), 0, 0.48);
					Class'RIText'.static.DrawIn(gc, Class'RIFontBody', ax + lw * 0.55, y, lw * 0.45 - bw - 8 * S, 30 * S,
						Class'RIText'.static.Fit(Class'RIFontBody', T, lw * 0.45 - bw - 8 * S, 0.66), C3(255, 231, 154, da), 2, 0.66);
				}
				else if (Row.bHighlight)
					Class'RIText'.static.DrawIn(gc, Class'RIFontBody', ax + lw * 0.55, y, lw * 0.45, 30 * S, Class'RIText'.static.Fit(Class'RIFontBody', V, lw * 0.45, 0.66), C3(255, 231, 154, da), 2, 0.66);
				else
					Class'RIText'.static.DrawIn(gc, Class'RIFontBody', ax + lw * 0.55, y, lw * 0.45, 30 * S, Class'RIText'.static.Fit(Class'RIFontBody', V, lw * 0.45, 0.66), C3(230, 210, 165, da), 2, 0.66);
				Class'RIText'.static.HLine(gc, ax, y + 31 * S, lw, C3(30, 25, 11, da));
				if (StatCol == 0)
					StatCol = 1;
				else
				{
					StatCol = 0;
					y += 34 * S;
				}
				continue;
			}
			lw = W * 0.38;
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', X, y + 3 * S, Caps(L), ALbl(da), 0.5);
			if (Row.bHighlight)
				th = Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', X + lw, y, W - lw - 12 * S, V, AHi(da), 0.6, 1.2);
			else
				th = Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', X + lw, y, W - lw - 12 * S, V, C3(230, 210, 165, da), 0.6, 1.2);
			y += FMax(19 * S, th) + 3 * S;
			Class'RIText'.static.HLine(gc, X, y - 2 * S, W - 12 * S, C3(50, 42, 20, da));
			continue;
		}

		// Title (shown above already), plain text (headings, description)
		if (C.IsA('PersonaHeaderTextWindow'))
			continue;
		if (C.IsA('TextWindow') && !C.IsA('ButtonWindow'))
		{
			T = TextWindow(C).GetText();
			if (T == "")
				continue;
			y = EndRows(y);
			// Short "Something:" lines are section headings: held until the
			// section has a row to show (empty mod sections disappear)
			if ((Right(T, 1) == ":") && (Len(T) < 40))
			{
				y = CloseStat(y);
				PendHead = Left(T, Len(T) - 1);
				continue;
			}
			y = CloseStat(y);
			if (!VPlus() && (InfoDesc != "") && (Class'RIConView'.static.Lines(T) == InfoDesc))
				continue;
			PendHead = "";
			y += 6 * S;
			// UNATCO / agency file notes get their own card
			if ((InStr(T, "<END NOTE>") >= 0) && (InStr(T, "<") < InStr(T, "<END NOTE>")))
			{
				y = DrawNoteText(gc, X, y, W - 14 * S, Class'RIConView'.static.Lines(T), da);
				continue;
			}
			th = Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', X, y, W - 14 * S,
				Class'RIConView'.static.Lines(T), C3(230, 210, 165, da), 0.72, 1.36);
			y += th + 8 * S;
			continue;
		}

		// Anything else (tiles, button bars): look inside
		y = InfoTree(gc, C, X, y, W, da);
	}
	return y;
}

// AE separates list values with line breaks ("10mm Ammo" / "10mm AP Ammo"),
// which the native text draws as "?": join them with commas instead
function string OneLine(string V)
{
	local int p;

	while (True)
	{
		p = InStr(V, Chr(13) $ Chr(10));
		if (p < 0)
			break;
		V = Left(V, p) $ ", " $ Mid(V, p + 2);
	}
	while (True)
	{
		p = InStr(V, Chr(10));
		if (p < 0)
			p = InStr(V, Chr(13));
		if (p < 0)
			p = InStr(V, "|n");
		if (p < 0)
			break;
		if (Mid(V, p, 2) == "|n")
			V = Left(V, p) $ ", " $ Mid(V, p + 2);
		else
			V = Left(V, p) $ ", " $ Mid(V, p + 1);
	}
	return V;
}

// A click on one of AE's controls in the details: AE's own handlers run it
function InfoClick(int i)
{
	local Window C;

	if ((i < 0) || (i >= NumInfoWins) || (SelItem == None))
		return;
	C = InfoWins[i];
	if ((C == None) || !C.IsSensitive())
		return;
	// Re-selecting rebuilds AE's panel (and the button just clicked), so
	// only do it when AE has a different item selected
	if ((Inv().selectedItem == None) || (Inv().selectedItem.GetClientObject() != SelItem))
	{
		Inv().SelectInventoryItem(SelItem);
		return;
	}
	if (C.IsA('PersonaAmmoDetailButton'))
		Inv().ButtonActivated(C);
	else if (!Inv().winInfo.ButtonActivated(C))
		Inv().ButtonActivated(C);
	PlaySound(Sound'Menu_Press', 0.25);
	if (!Owned(SelItem))
		SelItem = None;
}

function DrawDetail(GC gc, float a)
{
	local float x, y, w, h, da, iw, ih, k, bw, px, pw;
	local string N, T;

	x = OX + 900 * S;
	y = 170 * S;
	w = 820 * S;
	h = 790 * S;
	Panel(gc, x, y, w, h, a);
	x += 32 * S;
	w -= 64 * S;
	y += 28 * S;
	da = a * Class'RIUtil'.static.Phase(DescAge, 0.0, 0.2);

	if (SelItem == None)
		Class'RIText'.static.Draw(gc, Class'RIFontBody', x, y, PickLabel, ALbl(a), 0.8);
	else
	{
		// Picture on the left, name and kind on the right
		pw = 260 * S;
		Glow(gc, x, y, pw, 150 * S, C3(36, 30, 13, da));
		Class'RIText'.static.Box(gc, x, y, pw, 150 * S, C3(40, 33, 15, da));
		if (SelItem.largeIcon != None)
		{
			iw = FMax(1, SelItem.largeIconWidth);
			ih = FMax(1, SelItem.largeIconHeight);
			k = FMin((pw - 30 * S) / iw, 130 * S / ih);
			if (k >= 1)
				k = float(int(k));
			gc.SetStyle(DSTY_Masked);
			gc.SetTileColor(C3(255, 255, 255, da));
			Class'RIHD'.static.DrawStretched(gc, x + (pw - iw * k) * 0.5, y + (150 * S - ih * k) * 0.5, iw * k, ih * k, 0, 0, iw, ih, SelItem.largeIcon);
		}
		px = x + pw + 30 * S;
		N = SelItem.ItemName;
		Class'RIText'.static.Draw(gc, Class'RIFontTitle', px + (1 - da) * 8 * S, y + 4 * S,
			Caps(Class'RIText'.static.Fit(Class'RIFontTitle', N, w - pw - 30 * S, 0.42)), ATxt(da), 0.42);
		DrawTags(gc, px, y + 54 * S, KindLine(SelItem), da);
		// Turn it (weapons with a long shape), then AE's item buttons
		bw = 0;
		if (Rotatable(SelItem))
		{
			T = Caps(RotateLabel) $ "   [SPACE]";
			bw = Class'RIText'.static.Width(Class'RIFontSmall', T, 0.54) + 26 * S;
			Class'RIText'.static.Box(gc, px, y + 112 * S, bw, 26 * S, Class'RIUtil'.static.Mix(ADim(da), AHi(da), int(HoverId == HOT_ROTATE)));
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', px, y + 112 * S, bw, 26 * S, T,
				Class'RIUtil'.static.Mix(AAcc(da), AHi(da), int(HoverId == HOT_ROTATE)), 1, 0.54);
			AddHot(HOT_ROTATE, px, y + 112 * S, bw, 26 * S);
			bw += 8 * S;
		}
		HdrBtnX = px + bw;
		HdrBtnY = y + 112 * S;
		HdrBtnW = w - pw - 30 * S - bw;
		y += 170 * S;
		DrawInfo(gc, x, y, w, 170 * S + h - 132 * S, da);
		DrawDeferredBtns(gc, HdrBtnX, HdrBtnY - 10 * S, HdrBtnW, da, True);
	}

	// Short notices (no room, can't be turned): just above the actions
	if ((Msg != "") && (MsgAge < 2.5))
		Class'RIText'.static.Draw(gc, Class'RIFontBody', x, 170 * S + h - 120 * S, Msg,
			C3(255, 120, 90, a * FClamp((2.5 - MsgAge) / 0.5, 0, 1)), 0.72);

	// Actions, as AE allows them for this item: one row of four
	y = 170 * S + h - 84 * S;
	bw = (w - 36 * S) / 4;
	DrawBtn(gc, x, y, bw, 50 * S, LabelOf(Inv().btnEquip, "Equip"), (SelItem != None) && Live(Inv().btnEquip), HoverId == HOT_EQUIP, (SelItem != None) && Live(Inv().btnEquip), a);
	AddHot(HOT_EQUIP, x, y, bw, 50 * S);
	DrawBtn(gc, x + (bw + 12 * S), y, bw, 50 * S, LabelOf(Inv().btnUse, "Use"), (SelItem != None) && Live(Inv().btnUse), HoverId == HOT_USE, False, a);
	AddHot(HOT_USE, x + (bw + 12 * S), y, bw, 50 * S);
	DrawBtn(gc, x + (bw + 12 * S) * 2, y, bw, 50 * S, LabelOf(Inv().btnDrop, "Drop"), (SelItem != None) && Live(Inv().btnDrop), HoverId == HOT_DROP, False, a);
	AddHot(HOT_DROP, x + (bw + 12 * S) * 2, y, bw, 50 * S);
	DrawBtn(gc, x + (bw + 12 * S) * 3, y, bw, 50 * S, LabelOf(Inv().btnChangeAmmo, "Change ammo"), (SelItem != None) && Live(Inv().btnChangeAmmo), HoverId == HOT_AMMO, False, a);
	AddHot(HOT_AMMO, x + (bw + 12 * S) * 3, y, bw, 50 * S);

	// Keys
	if (Player.KeyRing != None)
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, 170 * S + h + 10 * S, Caps(KeysLabel) @ string(Player.KeyRing.GetKeyCount()), ALbl(a), 0.66);
}

// ----------------------------------------------------------------------
// Vanilla+: item name in the board's title bar, AE's details in its body,
// actions on its four buttons under the grid, keys and ammo in its boxes
// ----------------------------------------------------------------------

// The selected item's large icon, centred in a soft glow under a hairline
function DrawVPPicture(GC gc, float X, float Y, float W, float H, float da)
{
	local float iw, ih, k;

	CGlow(gc, X + W * 0.15, Y, W * 0.7, H, C3(46, 38, 17, da));
	Class'RIText'.static.HLine(gc, X, Y + H + 3 * S, W, C3(70, 58, 28, da));
	if ((SelItem == None) || (SelItem.largeIcon == None))
		return;
	iw = FMax(1, SelItem.largeIconWidth);
	ih = FMax(1, SelItem.largeIconHeight);
	k = FMin((W - 20 * S) / iw, (H - 12 * S) / ih);
	if (k >= 1)
		k = float(int(k));
	gc.SetStyle(DSTY_Masked);
	gc.SetTileColor(C3(255, 255, 255, da));
	Class'RIHD'.static.DrawStretched(gc, X + (W - iw * k) * 0.5, Y + (H - ih * k) * 0.5, iw * k, ih * k, 0, 0, iw, ih, SelItem.largeIcon);
}

function DrawVPDetail(GC gc, float a)
{
	local float x, w, da;
	local string N, T;
	local bool bHot;

	x = OX + 1068 * S;
	w = 460 * S;
	da = a * Class'RIUtil'.static.Phase(DescAge, 0.0, 0.2);
	if (SelItem == None)
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 177 * S, w, 28 * S, Caps(PickLabel), ALbl(a), 0, 0.46);
	else
	{
		N = SelItem.ItemName;
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 177 * S, w, 28 * S,
			Caps(Class'RIText'.static.Fit(Class'RIFontHead', N, w, 0.5)), ATxt(da), 0, 0.5);
		DrawVPPicture(gc, OX + 1068 * S, 222 * S, 466 * S, 112 * S, da);
		DrawInfo(gc, x, 342 * S, w, 652 * S, da);
		if (Rotatable(SelItem))
		{
			T = Caps(RotateLabel) $ "   [SPACE]";
			bHot = (HoverId == HOT_ROTATE);
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, 670 * S, w, 30 * S, T,
				Class'RIUtil'.static.Mix(ALbl(da), AHi(da), int(bHot)), 0, 0.56);
			AddHot(HOT_ROTATE, x, 670 * S, w, 30 * S);
		}
	}
	if ((Msg != "") && (MsgAge < 2.5))
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, 670 * S, w, 30 * S, Msg,
			C3(255, 120, 90, a * FClamp((2.5 - MsgAge) / 0.5, 0, 1)), 2, 0.56);

	// four buttons spanning the grid box under them (395 .. 982, 8 apart)
	VPBtn(gc, 395, 135.7, LabelOf(Inv().btnEquip, "Equip"), (SelItem != None) && Live(Inv().btnEquip), HOT_EQUIP, a);
	VPBtn(gc, 538.7, 111.3, LabelOf(Inv().btnUse, "Use"), (SelItem != None) && Live(Inv().btnUse), HOT_USE, a);
	VPBtn(gc, 658, 124.6, LabelOf(Inv().btnDrop, "Drop"), (SelItem != None) && Live(Inv().btnDrop), HOT_DROP, a);
	VPBtn(gc, 790.6, 191.4, LabelOf(Inv().btnChangeAmmo, "Change ammo"), (SelItem != None) && Live(Inv().btnChangeAmmo), HOT_AMMO, a);

	// Keys and ammo boxes: click to list
	if ((Player.KeyRing != None) && (Player.KeyRing.icon != None))
	{
		gc.SetStyle(DSTY_Masked);
		gc.SetTileColor(C3(255, 255, 255, a));
		Class'RIHD'.static.DrawStretched(gc, OX + 1072 * S, 766 * S, 84 * S, 74 * S, 0, 0, 42, 37, Player.KeyRing.icon);
	}
	T = Caps(KeysLabel);
	if (Player.KeyRing != None)
		T = T @ string(Player.KeyRing.GetKeyCount());
	bHot = (HoverId == HOT_SUB + TAB_KEYS);
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 1170 * S, 756 * S, 128 * S, 50 * S, T, Class'RIUtil'.static.Mix(ATxt(a), AHi(a), int(bHot)), 1, 0.56);
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 1170 * S, 802 * S, 128 * S, 40 * S, "CLICK TO LIST", ALbl(a), 1, 0.46);
	AddHot(HOT_SUB + TAB_KEYS, OX + 1061 * S, 750 * S, 239 * S, 107 * S);
	bHot = (HoverId == HOT_SUB + TAB_AMMO);
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 1409 * S, 756 * S, 131 * S, 50 * S, Caps(AmmoTitle), Class'RIUtil'.static.Mix(ATxt(a), AHi(a), int(bHot)), 1, 0.56);
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 1409 * S, 802 * S, 131 * S, 40 * S, "CLICK TO LIST", ALbl(a), 1, 0.46);
	AddHot(HOT_SUB + TAB_AMMO, OX + 1300 * S, 750 * S, 242 * S, 107 * S);
}

// Vanilla+ ammo / key details: name in the title bar, picture, rounds and
// description in the body (clipped to it), credits in the footer bar,
// the belt icon in the lower box
function DrawVPListDetail(GC gc, float a, float da)
{
	local float x, y, w, iw, ih, k;
	local DeusExAmmo Am;
	local string T, D;
	local int st;

	x = OX + 1072 * S;
	w = 446 * S;
	y = 226 * S;
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, 670 * S, w, 30 * S, Caps(CreditsLabel) @ string(Player.Credits), ALbl(a), 0, 0.54);
	if ((ListSel < 0) || (ListSel >= NumList))
	{
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 177 * S, w, 28 * S, Caps(PickListLabel), ALbl(a), 0, 0.46);
		return;
	}
	st = gc.PushGC();
	gc.Intersect(x - 2 * S, 216 * S, w + 4 * S, 440 * S);
	if (InvMode == 1)
	{
		Am = DeusExAmmo(ListItems[ListSel]);
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 177 * S, w, 28 * S, Caps(Class'RIText'.static.Fit(Class'RIFontHead', Am.ItemName, w, 0.5)), ATxt(da), 0, 0.5);
		if (Am.largeIcon != None)
		{
			iw = FMax(1, Am.largeIconWidth);
			ih = FMax(1, Am.largeIconHeight);
			k = FMin((w - 40 * S) / iw, 150 * S / ih);
			if (k >= 1)
				k = float(int(k));
			gc.SetStyle(DSTY_Masked);
			gc.SetTileColor(C3(255, 255, 255, da));
			Class'RIHD'.static.DrawStretched(gc, x + (w - iw * k) * 0.5, y + (150 * S - ih * k) * 0.5, iw * k, ih * k, 0, 0, iw, ih, Am.largeIcon);
		}
		y += 164 * S;
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, Caps(RoundsLabel) @ string(Am.AmmoAmount) $ " / " $ string(Class'RIBase'.static.MaxAmmo(Player, Am)), AAcc(da), 0.62);
		y += 30 * S;
		D = Am.GetPropertyText("Description");
		Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x, y, w, Class'RIConView'.static.Lines(D), C3(230, 210, 165, da), 0.68, 1.34);
		gc.PopGC(st);
		if (Am.icon != None)
		{
			gc.SetStyle(DSTY_Masked);
			gc.SetTileColor(C3(255, 255, 255, da));
			Class'RIHD'.static.DrawStretched(gc, OX + 1072 * S, 766 * S, 84 * S, 74 * S, 0, 0, 42, 37, Am.icon);
		}
	}
	else
	{
		T = KeyInfos[ListSel].Description;
		if (T == "")
			T = string(KeyInfos[ListSel].KeyID);
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 177 * S, w, 28 * S, Caps(KeysTitle), ATxt(da), 0, 0.5);
		Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x, y, w, T, ATxt(da), 0.8, 1.36);
		gc.PopGC(st);
	}
}

// Text on one of the board's buttons (the frame is part of the board)
function VPBtn(GC gc, float X, float W, string L, bool bLive, int Id, float a)
{
	local Color C;
	local bool bHot;

	bHot = bLive && (HoverId == Id);
	if (!bLive)
		C = C3(110, 95, 60, a);
	else if (bHot)
		C = AHi(a);
	else
		C = ATxt(a);
	VPBtnK(gc, X, 824, W, 36, bHot, a);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', OX + X * S, 824 * S, W * S - 10 * S, 36 * S,
		Caps(Class'RIText'.static.Fit(Class'RIFontHead', L, W * S - 20 * S, 0.42)), C, 1, 0.42);
	AddHot(Id, OX + X * S, 824 * S, W * S, 36 * S);
}

// The kind line as small boxed tags; the last one (Equipped) lit
function DrawTags(GC gc, float X, float Y, string T, float da)
{
	local int p;
	local string P1;
	local float tw;
	local bool bLast;

	while (T != "")
	{
		p = InStr(T, "  -  ");
		if (p >= 0)
		{
			P1 = Left(T, p);
			T = Mid(T, p + 5);
			bLast = False;
		}
		else
		{
			P1 = T;
			T = "";
			bLast = True;
		}
		tw = Class'RIText'.static.Width(Class'RIFontSmall', P1, 0.5) + 20 * S;
		if (bLast && (P1 == Caps(EquippedWord)))
		{
			Fill(gc, X, Y, tw, 24 * S, C3(60, 50, 23, da));
			Class'RIText'.static.Box(gc, X, Y, tw, 24 * S, AHi(da));
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, Y, tw, 24 * S, P1, AHi(da), 1, 0.5);
		}
		else
		{
			Class'RIText'.static.Box(gc, X, Y, tw, 24 * S, ADim(da));
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X, Y, tw, 24 * S, P1, AAcc(da), 1, 0.5);
		}
		X += tw + 6 * S;
	}
}

// "WEAPON  -  SLOT 2  -  EQUIPPED" and the like
function string KindLine(Inventory I)
{
	local string T;

	if (DeusExWeapon(I) != None)
		T = KindWeapon;
	else if (DeusExAmmo(I) != None)
		T = KindAmmo;
	else
		T = KindItem;
	T = Caps(T);
	if (I.bInObjectBelt && (I.beltPos >= 0) && (I.beltPos < 12))
		T = T $ "  -  " $ Caps(SlotWord) @ Mid("0123456789-=", I.beltPos, 1);
	if (Player.inHand == I)
		T = T $ "  -  " $ Caps(EquippedWord);
	return T;
}

defaultproperties
{
     InvTitle="Inventory"
     StatsLabel="Stats"
     ClickLoadLabel="Click to load"
     KindWeapon="Weapon"
     KindAmmo="Ammunition"
     KindItem="Item"
     SlotWord="Slot"
     EquippedWord="Equipped"
     AmmoTitle="Ammo"
     KeysTitle="Nano keys"
     NoAmmoLabel="No ammo."
     NoKeysLabel="No nano keys yet."
     PickListLabel="Select an entry."
     RoundsLabel="Rounds"
     ListHint="CLICK select     UP / DOWN move     WHEEL scroll     ESC close"
     CreditsLabel="Credits"
     KeysLabel="Keys"
     BeltLabel="Belt"
     ClassicLabel="Classic view (rotate, keys, ammo)"
     PickLabel="Select an item."
     NoRoomLabel="No room there."
     HintText="CLICK select     DRAG to move or onto the belt     SPACE rotate     DOUBLE-CLICK or ENTER use     RIGHT-CLICK equip / use     DEL drop     ESC close"
     RotateLabel="Rotate"
     NoTurnLabel="Only long weapons can be turned."
     NoTurnRoomLabel="No room to turn it."
     bHideScreen=True
}
