//=============================================================================
// RIAugsView
// Augmentations, in the original gold. Left: the skeleton figure with a
// card per body location (Cranial, Eyes, Torso, Arms, Legs, Subdermal,
// Default) listing what is installed there: icon, name, level pips, an
// "on" light for active ones. Right: the selected aug (description, level,
// type), bioelectric energy, upgrade canisters and cells, and the actions.
// Activate / Upgrade / Use Cell call AE's own functions on its (hidden)
// augmentations screen, so all GMDX rules apply.
//=============================================================================
class RIAugsView extends RIPersonaView;

const HOT_AUG      = 100;   // + aug button index
const HOT_ACTIVATE = 50;
const HOT_UPGRADE  = 51;
const HOT_CELL     = 52;
const HOT_CLASSIC  = 53;
const HOT_INSTALL  = 54;      // med bot: install the chosen aug
const HOT_CANAUG   = 60;      // + index: an aug offered by a canister (med bot)

var int   Sel;
var HUDMedBotAugItemButton CanBtn[24];     // med bot: the canisters' aug choices, in draw order
var int   NumCanBtn;
var float DescAge;
var float DescScroll, DescScrollTarget, DescMax, DescTop, DescBottom;

// Card placement per location (design px), filled in DrawPage
var float LocX[7], LocY[7];
// Where each location lights on the figure (RI_AugHi / RI_AugBody pixels)
var float HiX0[6], HiY0[6], HiX1[6], HiY1[6];
// Installed-location art: its place on the figure (RI_AugBody pixels) and
// the art's own size in its texture
var float LX0[6], LY0[6], LX1[6], LY1[6], LU[6], LV[6];

var localized string AugsTitle, EnergyLabel, CansLabel, CellsLabel, LevelLabel, TypeLabel;
var localized string ActivateLabel, DeactivateLabel, UpgradeLabel, MaxedLabel, CellLabel, ClassicLabel;
var localized string LocNames[7];
var localized string TypeNames[4];
var localized string MedTitle, MedPick, MedNoCans, InstallLabel, ReplaceLabel, HasItLabel, SlotFullLabel, CanLabel;
var localized string EmptyLabel, PickLabel, OnLabel, HintText, KeyLabel, NoKeyLabel, RebindLabel;

function HUDMedBotAddAugsScreen MBA()
{
	return HUDMedBotAddAugsScreen(Screen);
}

function PersonaScreenAugmentations Augs()
{
	return PersonaScreenAugmentations(Screen);
}

function ScreenAttached()
{
	local int i;

	ActiveTab = TAB_AUGS;
	Sel = -1;
	Class'RIAugKeys'.static.Refresh(Player);   // re-read the bindings
	for (i = 0; i < 13; i++)
		if (AugAt(i) != None)
		{
			SelectAug(i);
			break;
		}
}

// Small icon, or the full one for augs that ship without (AE's EUAS)
function Texture ListIcon(Augmentation Aug)
{
	if (Aug.smallIcon != None)
		return Aug.smallIcon;
	return Aug.icon;
}

function string AugKey(Augmentation Aug)
{
	if ((Aug == None) || (Player == None))
		return "";
	return Class'RIAugKeys'.static.KeyFor(Player, Aug.HotKeyNum);
}

function Augmentation AugAt(int i)
{
	if ((i < 0) || (i >= 13) || (Augs().augItems[i] == None))
		return None;
	return Augmentation(Augs().augItems[i].GetClientObject());
}

function SelectAug(int i)
{
	if ((AugAt(i) == None) || (i == Sel))
		return;
	Sel = i;
	DescAge = 0;
	DescScroll = 0;
	DescScrollTarget = 0;
	Augs().SelectAugmentation(Augs().augItems[i]);
}

function int Count(class<Inventory> C)
{
	local Inventory I;

	I = Player.FindInventoryType(C);
	if (Pickup(I) != None)
		return Pickup(I).NumCopies;
	return int(I != None);
}

function bool CanActivate()
{
	local Augmentation Aug;

	Aug = AugAt(Sel);
	return (Aug != None) && (Class'RIBase'.static.AugType(Aug) != 0);
}

function bool CanUpgrade()
{
	local Augmentation Aug;

	Aug = AugAt(Sel);
	return (Aug != None) && (Aug.CurrentLevel < Aug.MaxLevel) && (Count(Class'AugmentationUpgradeCannister') > 0);
}

function bool CanCell()
{
	return (Count(Class'BioelectricCell') > 0) && (Player.Energy < Player.EnergyMax);
}

function PageClick(int Id, EInputKey button, int numClicks)
{
	if (button != IK_LeftMouse)
		return;
	// Med bot: only the canister panel acts (the installed list is for viewing)
	if (MBA() != None)
	{
		if ((Id >= HOT_CANAUG) && (Id < HOT_CANAUG + NumCanBtn) && (CanBtn[Id - HOT_CANAUG] != None))
		{
			MBA().SelectAugmentation(CanBtn[Id - HOT_CANAUG]);
			PlaySound(Sound'Menu_Press', 0.2);
			if ((numClicks >= 2) && MBA().btnInstall.IsSensitive())
				MBA().InstallAugmentation();
		}
		else if ((Id == HOT_INSTALL) && MBA().btnInstall.IsSensitive())
			MBA().InstallAugmentation();
		else if ((Id >= HOT_AUG) && (Id < HOT_AUG + 13))
		{
			SelectAug(Id - HOT_AUG);
			PlaySound(Sound'Menu_Press', 0.2);
		}
		return;
	}
	if ((Id >= HOT_AUG) && (Id < HOT_AUG + 13))
	{
		SelectAug(Id - HOT_AUG);
		PlaySound(Sound'Menu_Press', 0.2);
		if ((numClicks >= 2) && CanActivate())
			Augs().ActivateAugmentation();
	}
	else if ((Id == HOT_ACTIVATE) && CanActivate())
		Augs().ActivateAugmentation();
	else if ((Id == HOT_UPGRADE) && CanUpgrade())
		Augs().UpgradeAugmentation();
	else if ((Id == HOT_CELL) && CanCell())
		Augs().UseCell();
	else if (Id == HOT_CLASSIC)
		SwitchView(True);
}

function bool PageKey(EInputKey key, bool bRepeat)
{
	local int i, d, n;

	// Wheel scrolls the description (long ones such as the EUAS tech list)
	if ((key == IK_MouseWheelUp) || (key == IK_MouseWheelDown))
	{
		if (key == IK_MouseWheelUp)
			DescScrollTarget -= 70 * S;
		else
			DescScrollTarget += 70 * S;
		return True;
	}
	if ((key == IK_Up) || (key == IK_Left))
		d = -1;
	else if ((key == IK_Down) || (key == IK_Right))
		d = 1;
	if (d != 0)
	{
		i = Max(Sel, 0);
		for (n = 0; n < 13; n++)
		{
			i = int((i + d + 13) % 13);
			if (AugAt(i) != None)
				break;
		}
		SelectAug(i);
		PlaySound(Sound'Menu_Focus', 0.2);
		return True;
	}
	if ((key == IK_Enter) && !bRepeat && CanActivate())
	{
		Augs().ActivateAugmentation();
		return True;
	}
	return False;
}

function PageTick(float deltaSeconds)
{
	DescAge += deltaSeconds;
	DescScrollTarget = FClamp(DescScrollTarget, 0, FMax(0, DescMax));
	DescScroll += (DescScrollTarget - DescScroll) * FMin(1.0, deltaSeconds * 14.0);
}

// ----------------------------------------------------------------------
// Drawing
// ----------------------------------------------------------------------

function DrawPage(GC gc, float a)
{
	local float bx, by, bw, bh, k;
	local int L;

	if (VPlus())
	{
		DrawVPPage(gc, a);
		return;
	}
	Heading(gc, OX + 140 * S, 170 * S, 1000 * S, AugsTitle, a);

	// Figure, centred, AE's 174 x 359 art scaled up
	bh = 690 * S;
	k = bh / 891.0;
	bw = 477.0 * k;
	bx = OX + 640 * S - bw * 0.5;
	by = 245 * S;
	// soft light behind the figure, fading out on every side
	CGlow(gc, bx - 200 * S, by - 60 * S, bw + 400 * S, bh + 120 * S, C3(30, 25, 11, a));
	gc.SetStyle(DSTY_Masked);
	gc.SetTileColor(C3(255, 255, 255, a));
	Class'RIText'.static.Tex(gc, bx, by, bw, bh, 0, 0, 477, 891, Texture'ReimaginedUI.UI.RI_AugBody');
	DrawAugHighlights(gc, bx, by, bw, bh, a);

	// Cards: left column Cranial, Arms, Subdermal, Default; right Eyes, Torso, Legs
	LocX[0] = OX + 140 * S;   LocY[0] = 245 * S;    // cranial
	LocX[1] = OX + 860 * S;   LocY[1] = 245 * S;    // eyes
	LocX[2] = OX + 860 * S;   LocY[2] = 450 * S;    // torso
	LocX[3] = OX + 140 * S;   LocY[3] = 400 * S;    // arms
	LocX[4] = OX + 860 * S;   LocY[4] = 720 * S;    // legs
	LocX[5] = OX + 140 * S;   LocY[5] = 560 * S;    // subdermal
	LocX[6] = OX + 140 * S;   LocY[6] = 760 * S;    // default
	for (L = 0; L < 7; L++)
	{
		DrawLocLeader(gc, L, bx, by, bw, bh, 280 * S, a);
		DrawLocCard(gc, L, LocX[L], LocY[L], 280 * S, a);
	}

	DrawDetail(gc, a);
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', OX + 140 * S, FY + FH + 22 * S, HintText, ALbl(a * 0.8), 0.7);
}

// The figure changes with what's installed, as on the original screen: each
// location with an aug shows its art over the figure, in a thin frame: the
// game's own six pieces, upscaled 4x with PBRify and fitted to the new
// figure (arm and leg warped row by row to its limbs; the head pieces
// placed by the head's outline, torso and subdermal by the body's). The
// selected aug's location also glows, breathing slowly.
function DrawAugHighlights(GC gc, float bx, float by, float bw, float bh, float a)
{
	local int i, L;
	local Augmentation Aug;
	local float Lit[6], k, x, y, w, h;
	local Texture T;

	for (i = 0; i < 13; i++)
	{
		Aug = AugAt(i);
		if (Aug == None)
			continue;
		L = int(Aug.AugmentationLocation);
		if ((L < 0) || (L > 5))
			continue;
		if (i == Sel)
			Lit[L] = 1.0;
		else
			Lit[L] = FMax(Lit[L], 0.5);
	}
	for (L = 0; L < 6; L++)
	{
		x = bx + bw * LX0[L] / 477.0;
		y = by + bh * LY0[L] / 891.0;
		w = bw * (LX1[L] - LX0[L]) / 477.0;
		h = bh * (LY1[L] - LY0[L]) / 891.0;
		// every location keeps its frame on the figure, empty until an aug
		// goes in, so the wires always have somewhere to land
		if (Lit[L] <= 0)
		{
			LocBox(gc, x, y, w, h, AEdge(0.35 * a), AEdge(0.6 * a));
			continue;
		}
		y = by + bh * LY0[L] / 891.0;
		w = bw * (LX1[L] - LX0[L]) / 477.0;
		h = bh * (LY1[L] - LY0[L]) / 891.0;
		T = LocTex(L);
		if (T != None)
		{
			gc.SetStyle(DSTY_Masked);
			gc.SetTileColor(C3(255, 255, 255, a));
			Class'RIText'.static.Tex(gc, x, y, w, h, 0, 0, LU[L], LV[L], T);
		}
		if (Lit[L] >= 1.0)
		{
			k = a * (0.8 + 0.2 * Sin(Age * 3.0));
			gc.SetStyle(DSTY_Translucent);
			gc.SetTileColor(C3(255, 232, 150, k * 0.7));
			Class'RIText'.static.Tex(gc, bx + bw * HiX0[L] / 477.0, by + bh * HiY0[L] / 891.0,
				bw * (HiX1[L] - HiX0[L]) / 477.0, bh * (HiY1[L] - HiY0[L]) / 891.0,
				HiX0[L], HiY0[L], HiX1[L] - HiX0[L], HiY1[L] - HiY0[L], Texture'ReimaginedUI.UI.RI_AugHi');
			LocBox(gc, x, y, w, h, AHi(a), AHi(0.9 * a));
		}
		else
			LocBox(gc, x, y, w, h, AEdge(0.9 * a), AHi(0.9 * a));
	}
}

// The box round an installed piece, after the original screen's: a 1 px
// frame standing 2 px off the art, with short heavier ticks on its corners
function LocBox(GC gc, float X, float Y, float W, float H, Color Col, Color BC)
{
	X -= 2 * S;
	Y -= 2 * S;
	W += 4 * S;
	H += 4 * S;
	Class'RIText'.static.Box(gc, X, Y, W, H, Col);
	Class'RIModern'.static.Brackets(gc, X - 1 * S, Y - 1 * S, W + 2 * S, H + 2 * S, 6 * S, BC);
}

function Texture LocTex(int L)
{
	switch (L)
	{
		case 0: return Texture'ReimaginedUI.UI.RI_AugLocCerebral';
		case 1: return Texture'ReimaginedUI.UI.RI_AugLocEyes';
		case 2: return Texture'ReimaginedUI.UI.RI_AugLocTorso';
		case 3: return Texture'ReimaginedUI.UI.RI_AugLocArm';
		case 4: return Texture'ReimaginedUI.UI.RI_AugLocLeg';
		case 5: return Texture'ReimaginedUI.UI.RI_AugLocSubdermal';
	}
	return None;
}

// Callout from a slot group's heading to its place on the body
function DrawLocLeader(GC gc, int L, float bx, float by, float bw, float bh, float W, float a)
{
	local float fx, fy, px, py, ax, ay, rx, ry, rw, rh, tx, ty;

	// points on the new figure, kept apart (cranial high on the skull, eyes
	// at the eye socket)
	switch (L)
	{
		case 0: fx = 0.44;  fy = 0.025; break;    // cranial
		case 1: fx = 0.585; fy = 0.075; break;    // eyes
		case 2: fx = 0.60;  fy = 0.24;  break;    // torso
		case 3: fx = 0.17;  fy = 0.28;  break;    // arms
		case 4: fx = 0.60;  fy = 0.62;  break;    // legs
		case 5: fx = 0.07;  fy = 0.39;  break;    // subdermal (the forearm)
		default: return;                          // default augs: no place on the body
	}
	ax = bx + bw * fx;
	ay = by + bh * fy;
	// level with the card's heading rule, so the wire carries the rule on
	py = LocY[L] + 24 * S;
	if (LocX[L] < bx)
		px = LocX[L] + W;
	else
		px = LocX[L];
	// an aug installed here: the wire runs to its box, as on the original
	// screen (out level, a right angle, then into the box's near side), with
	// a connector tab at each end
	// every card wires to its location's frame on the figure, as on the
	// original screen: out level, down (or up) a column just off the frame,
	// then into the frame's near side, a connector tab at each end; dim
	// while the location is empty
	LocRect(L, bx, by, bw, bh, rx, ry, rw, rh);
	// right up to the frame (LocBox stands 2 px off the art)
	if (px < rx)
		tx = rx - 2 * S;
	else
		tx = rx + rw + 2 * S;
	ty = Class'RIModern'.static.P(ry + rh * 0.5);
	py = Class'RIModern'.static.P(py);
	if (LocInstalled(L))
	{
		Wire(gc, px, py, tx, ty, AEdge(a));
		WireTab(gc, px, py, px < tx, AHi(a));
		WireTab(gc, tx, ty, tx < px, AHi(a));
	}
	else
	{
		Wire(gc, px, py, tx, ty, AEdge(0.45 * a));
		WireTab(gc, tx, ty, tx < px, AEdge(0.6 * a));
	}
}

// A right-angled wire: level out of (px, py), down or up at the halfway
// column, then level into (tx, ty); 1 px
function Wire(GC gc, float px, float py, float tx, float ty, Color Col)
{
	local float mx;

	// the column a short way off the frame, so the wire never cuts across
	// the figure; one straight run when card and frame line up
	if (Abs(ty - py) < 1)
	{
		Class'RIText'.static.HLine(gc, FMin(px, tx), py, Abs(tx - px), Col);
		return;
	}
	if (tx > px)
		mx = Class'RIModern'.static.P(tx - FMin(20 * S, (tx - px) * 0.5));
	else
		mx = Class'RIModern'.static.P(tx + FMin(20 * S, (px - tx) * 0.5));
	// each run overlaps the corner by the line's own width, so the joins
	// close on either side (left-hand cards run right to left)
	Class'RIText'.static.HLine(gc, FMin(px, mx), py, Abs(mx - px) + 0.5, Col);
	Class'RIText'.static.VLine(gc, mx, FMin(py, ty), Abs(ty - py) + 0.5, Col);
	Class'RIText'.static.HLine(gc, FMin(mx, tx), ty, Abs(tx - mx) + 0.5, Col);
}

// A connector tab at a wire's end: a small solid block on the line,
// standing off the side the wire leaves from
function WireTab(GC gc, float X, float Y, bool bRight, Color Col)
{
	if (bRight)
		Class'RIModern'.static.Blk(gc, X, Y - 2 * S, 6 * S, 4 * S, Col);
	else
		Class'RIModern'.static.Blk(gc, X - 6 * S, Y - 2 * S, 6 * S, 4 * S, Col);
}

function bool LocInstalled(int L)
{
	local int i;
	local Augmentation Aug;

	for (i = 0; i < 13; i++)
	{
		Aug = AugAt(i);
		if ((Aug != None) && (int(Aug.AugmentationLocation) == L))
			return True;
	}
	return False;
}

// The location's art box on screen
function LocRect(int L, float bx, float by, float bw, float bh, out float X, out float Y, out float W, out float H)
{
	X = bx + bw * LX0[L] / 477.0;
	Y = by + bh * LY0[L] / 891.0;
	W = bw * (LX1[L] - LX0[L]) / 477.0;
	H = bh * (LY1[L] - LY0[L]) / 891.0;
}

function DrawLocCard(GC gc, int L, float X, float Y, float W, float a)
{
	local int i, n, p, e, slots;
	local float y2, rh, ix, ex;
	local Augmentation Aug;
	local bool bSel, bHot;
	local Texture Ic;
	local string K;
	local float nw, ns, isz;

	rh = 44 * S;
	nw = W - 156 * S;
	ns = 0.66;
	isz = 36 * S;
	if (VPlus())
	{
		// narrower cards beside the figure: no key frame (shown in the details)
		rh = 38 * S;
		nw = W - 116 * S;
		ns = 0.56;
		isz = 30 * S;
	}
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', X, Y, Caps(LocNames[L]), AAcc(a), 0.7);
	Class'RIText'.static.HLine(gc, X, Y + 24 * S, W, ADim(a));
	y2 = Y + 30 * S;
	n = 0;
	for (i = 0; i < 13; i++)
	{
		Aug = AugAt(i);
		if ((Aug == None) || (int(Aug.AugmentationLocation) != L))
			continue;
		n++;
		bSel = (i == Sel);
		bHot = (HoverId == HOT_AUG + i);
		Fill(gc, X, y2, W, rh, C3(30, 25, 11, 0.6 * a));
		if (bSel)
			SelRow(gc, X, y2, W, rh, a);
		else if (bHot)
			Class'RIText'.static.Box(gc, X, y2, W, rh, AEdge(a));

		// Icon
		Ic = ListIcon(Aug);
		if (Ic != None)
		{
			// AE's colour for the aug's type and state
			gc.SetStyle(DSTY_Translucent);      // aug icons: black drops out (masked left blotches, IFF worst)
			gc.SetTileColor(Class'RIUtil'.static.Mix(C3(0, 0, 0, a), Class'RIBase'.static.AugColor(Aug, False), a));
			Class'RIHD'.static.DrawAugIcon(gc, X + 6 * S, y2 + (rh - isz) * 0.5, isz, isz, Ic);
		}
		ix = X + isz + 14 * S;
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', ix, y2, nw, rh,
			Caps(Class'RIText'.static.Fit(Class'RIFontSmall', Aug.AugmentationName, nw, ns)),
			Class'RIUtil'.static.Mix(ATxt(a), C3(255, 255, 255, a), int(bSel)), 0, ns);

		// Key that toggles it, in a small frame
		K = AugKey(Aug);
		if ((K != "") && !VPlus())
		{
			Class'RIText'.static.Box(gc, X + W - 100 * S, y2 + rh * 0.5 - 10 * S, 38 * S, 20 * S, ADim(a));
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X + W - 100 * S, y2 + rh * 0.5 - 10 * S, 38 * S, 20 * S, K, AAcc(a), 1, 0.56);
		}

		// Level pips
		for (p = 0; p < Aug.MaxLevel + 1; p++)
		{
			if (p <= Aug.CurrentLevel)
				Fill(gc, X + W - 56 * S + p * 11 * S, y2 + rh - 12 * S, 8 * S, 5 * S, AAcc(a));
			else
				Class'RIText'.static.Box(gc, X + W - 56 * S + p * 11 * S, y2 + rh - 12 * S, 8 * S, 5 * S, ADim(a));
		}
		// Active light
		if (Aug.bIsActive)
		{
			CGlow(gc, X + W - 28 * S, y2 + 2 * S, 24 * S, 24 * S, C3(60, 110, 50, a));
			Fill(gc, X + W - 19 * S, y2 + 11 * S, 6 * S, 6 * S, AGood(a));
		}
		AddHot(HOT_AUG + i, X, y2, W, rh);
		y2 += rh + 6 * S;
	}

	// Free slots at this location: an empty box with a plus in it
	slots = n;
	if (Player.AugmentationSystem != None)
		slots = Max(n, Player.AugmentationSystem.AugLocs[L].NumSlots);
	ex = X;
	for (e = n; e < slots; e++)
	{
		Fill(gc, ex, y2, rh, rh, C3(20, 16, 7, 0.55 * a));
		Class'RIText'.static.Box(gc, ex, y2, rh, rh, C3(106, 90, 44, a));
		Fill(gc, ex + rh * 0.5 - 8 * S, y2 + rh * 0.5 - 0.75 * S, 16 * S, 1.5 * S, C3(160, 135, 68, a));
		Fill(gc, ex + rh * 0.5 - 0.75 * S, y2 + rh * 0.5 - 8 * S, 1.5 * S, 16 * S, C3(160, 135, 68, a));
		ex += rh + 8 * S;
	}
}

// Med bot: the canisters in the player's inventory, each offering two augs.
// Picking one and installing goes through AE's own SelectAugmentation /
// InstallAugmentation, so slot, respec and duplicate rules are unchanged.
function DrawMedBot(GC gc, float a)
{
	local float x, y, w, h, rh, bottom;
	local Window C;
	local HUDMedBotAugCanWindow Can;
	local HUDMedBotAugItemButton B;
	local Augmentation Aug;
	local int k;
	local bool bSel, bHot, bLive;
	local string Tag, L;

	x = OX + 1180 * S;
	y = 240 * S;
	w = 600 * S;
	h = 700 * S;
	Panel(gc, x, y, w, h, a);
	x += 26 * S;
	w -= 52 * S;
	y += 24 * S;
	bottom = 240 * S + h - 90 * S;
	Class'RIText'.static.Draw(gc, Class'RIFontHead', x, y, Caps(MedTitle), ATxt(a), 0.62);
	y += 36 * S;
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, MedPick, ALbl(a), 0.72);
	y += 34 * S;

	NumCanBtn = 0;
	rh = 52 * S;
	if (MBA().winAugsTile != None)
	{
		for (C = MBA().winAugsTile.GetBottomChild(); C != None; C = C.GetHigherSibling())
		{
			Can = HUDMedBotAugCanWindow(C);
			if ((Can == None) || (y + 26 * S + rh * 2 > bottom))
				continue;
			L = CanLabel;
			if (Can.augCan != None)
				L = Can.augCan.ItemName;
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, Caps(L), ALbl(a), 0.68);
			Fill(gc, x, y + 22 * S, w, 1 * S, ADim(a));
			y += 30 * S;
			for (k = 0; k < 2; k++)
			{
				if (k == 0)
					B = Can.btnAug1;
				else
					B = Can.btnAug2;
				if ((B == None) || (NumCanBtn >= 24))
					continue;
				Aug = B.GetAugmentation();
				if (Aug == None)
					continue;
				CanBtn[NumCanBtn] = B;
				bSel = (MBA().selectedAugButton == B);
				bHot = (HoverId == HOT_CANAUG + NumCanBtn);
				bLive = !((B.bHasIt || B.bSlotFull) && !Class'RIBase'.static.AugCanRespec(B));
				if (bSel)
					SelRow(gc, x, y, w, rh - 6 * S, a);
				else if (bHot)
					Fill(gc, x, y, w, rh - 6 * S, C3(30, 25, 11, a));
				if (Aug.icon != None)
				{
					gc.SetStyle(DSTY_Masked);
					if (bLive)
						gc.SetTileColor(C3(255, 255, 255, a));
					else
						gc.SetTileColor(C3(110, 110, 110, a));
					Class'RIHD'.static.DrawAugIcon(gc, x + 6 * S, y + 4 * S, 38 * S, 38 * S, Aug.icon);
				}
				if (bLive)
					Class'RIText'.static.Draw(gc, Class'RIFontBody', x + 56 * S, y + 6 * S, Class'RIText'.static.Fit(Class'RIFontBody', Aug.AugmentationName, w - 220 * S, 0.8), ATxt(a), 0.8);
				else
					Class'RIText'.static.Draw(gc, Class'RIFontBody', x + 56 * S, y + 6 * S, Class'RIText'.static.Fit(Class'RIFontBody', Aug.AugmentationName, w - 220 * S, 0.8), ALbl(a * 0.7), 0.8);
				Tag = "";
				if (Class'RIBase'.static.AugCanRespec(B))
					Tag = ReplaceLabel;
				else if (B.bHasIt)
					Tag = HasItLabel;
				else if (B.bSlotFull)
					Tag = SlotFullLabel;
				else
					Tag = LocNames[Clamp(int(Aug.AugmentationLocation), 0, 6)];
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, y, w - 12 * S, rh - 6 * S, Caps(Tag), AAcc(a * 0.85), 2, 0.64);
				AddHot(HOT_CANAUG + NumCanBtn, x, y, w, rh - 6 * S);
				NumCanBtn++;
				y += rh;
			}
			y += 10 * S;
		}
	}
	if (NumCanBtn == 0)
		Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x, y, w, MedNoCans, ALbl(a), 0.8);

	// Install (or Replace, for a respec) along the bottom
	L = InstallLabel;
	if ((HUDMedBotAugItemButton(MBA().selectedAugButton) != None) && Class'RIBase'.static.AugCanRespec(HUDMedBotAugItemButton(MBA().selectedAugButton)))
		L = ReplaceLabel;
	bLive = MBA().btnInstall.IsSensitive();
	DrawBtn(gc, x, bottom + 20 * S, w, 50 * S, L, bLive, HoverId == HOT_INSTALL, bLive, a);
	AddHot(HOT_INSTALL, x, bottom + 20 * S, w, 50 * S);
}

function DrawDetail(GC gc, float a)
{
	local float x, y, w, h, da, f, bw, th, sh, kh;
	local Augmentation Aug;
	local string T;
	local int cans, cells, st;

	if (MBA() != None)
	{
		DrawMedBot(gc, a);
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
	da = a * Class'RIUtil'.static.Phase(DescAge, 0.0, 0.2);

	Aug = AugAt(Sel);
	if (Aug == None)
		Class'RIText'.static.Draw(gc, Class'RIFontBody', x, y, PickLabel, ALbl(a), 0.8);
	else
	{
		if (Aug.icon != None)
		{
			gc.SetStyle(DSTY_Translucent);      // aug icons: black drops out (masked left blotches, IFF worst)
			gc.SetTileColor(C3(255, 255, 255, da));
			Class'RIHD'.static.DrawAugIcon(gc, x, y, 64 * S, 64 * S, Aug.icon);
		}
		Class'RIText'.static.Draw(gc, Class'RIFontTitle', x + 80 * S + (1 - da) * 8 * S, y + 4 * S,
			Caps(Class'RIText'.static.Fit(Class'RIFontTitle', Aug.AugmentationName, w - 80 * S, 0.4)), ATxt(da), 0.4);
		T = TypeNames[Class'RIBase'.static.AugType(Aug)];
		if (Aug.bIsActive)
			T = T $ "  -  " $ OnLabel;
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x + 80 * S, y + 42 * S,
			Caps(LevelLabel) @ string(Aug.CurrentLevel + 1) $ " / " $ string(Aug.MaxLevel + 1) $ "    " $ Caps(T), AAcc(da), 0.68);
		y += 84 * S;
		// How to toggle it in play: a strip with the key in a badge
		if ((AugKey(Aug) != "") || Class'RIBase'.static.AugCanActivate(Aug))
		{
			Fill(gc, x, y, w, 40 * S, C3(126, 105, 50, 0.12 * da));
			Class'RIText'.static.Box(gc, x, y, w, 40 * S, ADim(da));
			if (AugKey(Aug) != "")
			{
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x + 14 * S, y, 200 * S, 40 * S, Caps(KeyLabel), ALbl(da), 0, 0.6);
				T = AugKey(Aug);
				Class'RIText'.static.Box(gc, x + 170 * S, y + 8 * S, FMax(34 * S, Class'RIText'.static.Width(Class'RIFontHead', T, 0.5) + 18 * S), 24 * S, AHi(da));
				Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x + 170 * S, y + 8 * S, FMax(34 * S, Class'RIText'.static.Width(Class'RIFontHead', T, 0.5) + 18 * S), 24 * S, T, AHi(da), 1, 0.5);
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, y, w - 14 * S, 40 * S, Caps(RebindLabel), ALbl(da * 0.8), 2, 0.52);
			}
			else
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x + 14 * S, y, w - 28 * S, 40 * S, Caps(NoKeyLabel), ALbl(da), 0, 0.6);
			y += 54 * S;
		}

		// Description, clipped to its own box above the energy readout and
		// scrolled with the wheel, so long text never runs under the buttons
		DescTop = y;
		DescBottom = 240 * S + h - 222 * S;
		sh = DescBottom - DescTop;
		st = gc.PushGC();
		gc.Intersect(x - 2 * S, DescTop, w + 4 * S, sh);
		th = Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x, DescTop - DescScroll, w - 18 * S,
			Class'RIConView'.static.Lines(Aug.Description), C3(230, 210, 165, da), 0.74, 1.38);
		gc.PopGC(st);
		DescMax = FMax(0, th - sh);
		if (DescMax > 1)
		{
			kh = FMax(30 * S, sh * sh / (sh + DescMax));
			Fill(gc, x + w - 3 * S, DescTop, 2 * S, sh, C3(50, 42, 20, a));
			Fill(gc, x + w - 3 * S, DescTop + (sh - kh) * (DescScroll / DescMax), 2 * S, kh, AAcc(a));
		}
		Class'RIText'.static.HLine(gc, x, DescBottom + 8 * S, w, ADim(a));
	}

	// Energy and supplies, pinned to the bottom of the panel
	y = 240 * S + h - 200 * S;
	f = FClamp(Player.Energy / FMax(1, Player.EnergyMax), 0, 1);
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, Caps(EnergyLabel), ALbl(a), 0.68);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, y - 4 * S, w, 26 * S,
		string(int(Player.Energy)) $ " / " $ string(int(Player.EnergyMax)), ATxt(a), 2, 0.5);
	y += 28 * S;
	Fill(gc, x, y, w, 12 * S, C3(40, 33, 15, a));
	Fill(gc, x, y, w * f, 12 * S, Class'RIUtil'.static.Raw(110 * a, 180 * a, 240 * a));
	Class'RIText'.static.Box(gc, x, y, w, 12 * S, C3(110, 92, 44, a));
	y += 26 * S;
	cans = Count(Class'AugmentationUpgradeCannister');
	cells = Count(Class'BioelectricCell');
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, Caps(CansLabel) @ string(cans) $ "      " $ Caps(CellsLabel) @ string(cells), ALbl(a), 0.68);

	// Actions
	y = 240 * S + h - 74 * S;
	bw = (w - 24 * S) / 3;
	if ((Aug != None) && Aug.bIsActive)
		DrawBtn(gc, x, y, bw, 50 * S, DeactivateLabel, CanActivate(), HoverId == HOT_ACTIVATE, False, a);
	else
		DrawBtn(gc, x, y, bw, 50 * S, ActivateLabel, CanActivate(), HoverId == HOT_ACTIVATE, CanActivate(), a);
	AddHot(HOT_ACTIVATE, x, y, bw, 50 * S);
	if ((Aug != None) && (Aug.CurrentLevel >= Aug.MaxLevel))
		DrawBtn(gc, x + bw + 12 * S, y, bw, 50 * S, MaxedLabel, False, False, False, a);
	else
	{
		DrawBtn(gc, x + bw + 12 * S, y, bw, 50 * S, UpgradeLabel, CanUpgrade(), HoverId == HOT_UPGRADE, False, a);
		AddHot(HOT_UPGRADE, x + bw + 12 * S, y, bw, 50 * S);
	}
	DrawBtn(gc, x + (bw + 12 * S) * 2, y, bw, 50 * S, CellLabel, CanCell(), HoverId == HOT_CELL, False, a);
	AddHot(HOT_CELL, x + (bw + 12 * S) * 2, y, bw, 50 * S);

	// Classic page (aug wheel options etc.)
}

// ----------------------------------------------------------------------
// Vanilla+: figure and slot groups in the left frame; the selected aug in
// the right frame (name bar, body, footer); its icon and the actions in
// the lower box
// ----------------------------------------------------------------------

function DrawVPPage(GC gc, float a)
{
	local float bx, by, bw, bh, k;
	local int L;

	VPTitle(gc, AugsTitle, a);
	bh = 560 * S;
	k = bh / 891.0;
	bw = 477.0 * k;
	bx = OX + 688 * S - bw * 0.5;
	by = 250 * S;
	gc.SetStyle(DSTY_Masked);
	gc.SetTileColor(C3(255, 255, 255, a));
	Class'RIText'.static.Tex(gc, bx, by, bw, bh, 0, 0, 477, 891, Texture'ReimaginedUI.UI.RI_AugBody');
	DrawAugHighlights(gc, bx, by, bw, bh, a);

	LocX[0] = OX + 405 * S;   LocY[0] = 196 * S;    // cranial
	LocX[1] = OX + 782 * S;   LocY[1] = 196 * S;    // eyes
	LocX[2] = OX + 782 * S;   LocY[2] = 400 * S;    // torso
	LocX[3] = OX + 405 * S;   LocY[3] = 370 * S;    // arms
	LocX[4] = OX + 782 * S;   LocY[4] = 700 * S;    // legs
	LocX[5] = OX + 405 * S;   LocY[5] = 540 * S;    // subdermal
	LocX[6] = OX + 405 * S;   LocY[6] = 715 * S;    // default
	for (L = 0; L < 7; L++)
	{
		DrawLocLeader(gc, L, bx, by, bw, bh, 190 * S, a);
		DrawLocCard(gc, L, LocX[L], LocY[L], 190 * S, a);
	}
	DrawVPDetail(gc, a);
}

function DrawVPDetail(GC gc, float a)
{
	local float x, y, w, da, f, bw, th, sh, kh;
	local Augmentation Aug;
	local string T;
	local int cans, cells, st;

	x = OX + 1072 * S;
	w = 458 * S;
	da = a * Class'RIUtil'.static.Phase(DescAge, 0.0, 0.2);
	Aug = AugAt(Sel);

	// Name bar
	if (Aug == None)
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 177 * S, w, 28 * S, Caps(PickLabel), ALbl(a), 0, 0.46);
	else
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 177 * S, w, 28 * S,
			Caps(Class'RIText'.static.Fit(Class'RIFontHead', Aug.AugmentationName, w, 0.5)), ATxt(da), 0, 0.5);

	// Body: level, type and key, then the description (scrolls), then energy
	y = 226 * S;
	if (Aug != None)
	{
		T = TypeNames[Class'RIBase'.static.AugType(Aug)];
		if (Aug.bIsActive)
			T = T $ "  -  " $ OnLabel;
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y,
			Caps(LevelLabel) @ string(Aug.CurrentLevel + 1) $ " / " $ string(Aug.MaxLevel + 1) $ "    " $ Caps(T), AAcc(da), 0.62);
		y += 26 * S;
		if (AugKey(Aug) != "")
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, Caps(KeyLabel) @ AugKey(Aug), ALbl(da), 0.58);
		else if (Class'RIBase'.static.AugCanActivate(Aug))
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, Caps(NoKeyLabel), ALbl(da), 0.58);
		y += 32 * S;
		DescTop = y;
		DescBottom = 586 * S;
		sh = DescBottom - DescTop;
		st = gc.PushGC();
		gc.Intersect(x - 2 * S, DescTop, w + 4 * S, sh);
		th = Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x, DescTop - DescScroll, w - 18 * S,
			Class'RIConView'.static.Lines(Aug.Description), C3(230, 210, 165, da), 0.68, 1.34);
		gc.PopGC(st);
		DescMax = FMax(0, th - sh);
		if (DescMax > 1)
		{
			kh = FMax(30 * S, sh * sh / (sh + DescMax));
			Fill(gc, x + w - 3 * S, DescTop, 2 * S, sh, C3(50, 42, 20, a));
			Fill(gc, x + w - 3 * S, DescTop + (sh - kh) * (DescScroll / DescMax), 2 * S, kh, AAcc(a));
		}
	}
	y = 600 * S;
	f = FClamp(Player.Energy / FMax(1, Player.EnergyMax), 0, 1);
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, Caps(EnergyLabel), ALbl(a), 0.6);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, y - 4 * S, w, 24 * S,
		string(int(Player.Energy)) $ " / " $ string(int(Player.EnergyMax)), ATxt(a), 2, 0.46);
	Fill(gc, x, y + 26 * S, w, 10 * S, C3(40, 33, 15, a));
	Fill(gc, x, y + 26 * S, w * f, 10 * S, Class'RIUtil'.static.Raw(110 * a, 180 * a, 240 * a));

	// Footer bar: supplies
	cans = Count(Class'AugmentationUpgradeCannister');
	cells = Count(Class'BioelectricCell');
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, 670 * S, w, 30 * S,
		Caps(CansLabel) @ string(cans) $ "      " $ Caps(CellsLabel) @ string(cells), ALbl(a), 0, 0.52);

	// Lower box: the aug's icon, then the actions
	if ((Aug != None) && (Aug.icon != None))
	{
		gc.SetStyle(DSTY_Translucent);      // aug icons: black drops out (masked left blotches, IFF worst)
		gc.SetTileColor(C3(255, 255, 255, da));
		Class'RIHD'.static.DrawAugIcon(gc, OX + 1074 * S, 762 * S, 82 * S, 82 * S, Aug.icon);
	}
	y = 784 * S;
	bw = 112 * S;
	if ((Aug != None) && Aug.bIsActive)
		DrawBtn(gc, OX + 1180 * S, y, bw, 40 * S, DeactivateLabel, CanActivate(), HoverId == HOT_ACTIVATE, False, a);
	else
		DrawBtn(gc, OX + 1180 * S, y, bw, 40 * S, ActivateLabel, CanActivate(), HoverId == HOT_ACTIVATE, CanActivate(), a);
	AddHot(HOT_ACTIVATE, OX + 1180 * S, y, bw, 40 * S);
	if ((Aug != None) && (Aug.CurrentLevel >= Aug.MaxLevel))
		DrawBtn(gc, OX + 1300 * S, y, bw, 40 * S, MaxedLabel, False, False, False, a);
	else
	{
		DrawBtn(gc, OX + 1300 * S, y, bw, 40 * S, UpgradeLabel, CanUpgrade(), HoverId == HOT_UPGRADE, False, a);
		AddHot(HOT_UPGRADE, OX + 1300 * S, y, bw, 40 * S);
	}
	DrawBtn(gc, OX + 1420 * S, y, bw, 40 * S, CellLabel, CanCell(), HoverId == HOT_CELL, False, a);
	AddHot(HOT_CELL, OX + 1420 * S, y, bw, 40 * S);
}

defaultproperties
{
     LX0(0)=189
     LY0(0)=-2
     LX1(0)=230
     LY1(0)=47
     LU(0)=64
     LV(0)=76
     LX0(1)=238
     LY0(1)=44
     LX1(1)=286
     LY1(1)=75
     LU(1)=76
     LV(1)=48
     LX0(2)=227
     LY0(2)=162
     LX1(2)=326
     LY1(2)=287
     LU(2)=136
     LV(2)=192
     LX0(3)=74
     LY0(3)=167
     LX1(3)=142
     LY1(3)=280
     LU(3)=68
     LV(3)=113
     LX0(4)=254
     LY0(4)=460
     LX1(4)=336
     LY1(4)=706
     LU(4)=82
     LV(4)=246
     LX0(5)=15
     LY0(5)=298
     LX1(5)=55
     LY1(5)=392
     LU(5)=56
     LV(5)=144
     HiX0(0)=181
     HiY0(0)=0
     HiX1(0)=296
     HiY1(0)=58
     HiX0(1)=181
     HiY0(1)=58
     HiX1(1)=296
     HiY1(1)=100
     HiX0(2)=119
     HiY0(2)=125
     HiX1(2)=329
     HiY1(2)=356
     HiX0(3)=0
     HiY0(3)=134
     HiX1(3)=119
     HiY1(3)=356
     HiX0(4)=124
     HiY0(4)=463
     HiX1(4)=391
     HiY1(4)=891
     HiX0(5)=0
     HiY0(5)=356
     HiX1(5)=95
     HiY1(5)=490
     AugsTitle="Augmentations"
     MedTitle="Medical Bot"
     MedPick="Choose an augmentation from a canister, then install it."
     MedNoCans="No augmentation canisters in your inventory."
     InstallLabel="Install"
     ReplaceLabel="Replace"
     HasItLabel="Installed"
     SlotFullLabel="Slot full"
     CanLabel="Augmentation canister"
     EnergyLabel="Bioelectric energy"
     CansLabel="Upgrade canisters"
     CellsLabel="Bioelectric cells"
     LevelLabel="Level"
     ActivateLabel="Activate"
     DeactivateLabel="Deactivate"
     UpgradeLabel="Upgrade"
     MaxedLabel="Max level"
     CellLabel="Use cell"
     ClassicLabel="Classic view"
     LocNames(0)="Cranial"
     LocNames(1)="Eyes"
     LocNames(2)="Torso"
     LocNames(3)="Arms"
     LocNames(4)="Legs"
     LocNames(5)="Subdermal"
     LocNames(6)="Default"
     TypeNames(0)="Passive"
     TypeNames(1)="Active"
     TypeNames(2)="Automatic"
     TypeNames(3)="Toggle"
     EmptyLabel="Empty"
     PickLabel="Select an augmentation."
     OnLabel="On"
     KeyLabel="Toggle key"
     RebindLabel="Rebind under Controls"
     NoKeyLabel="No key: use the aug wheel"
     HintText="ARROWS select     ENTER or double-click activate     ESC close"
     bHideScreen=True
}
