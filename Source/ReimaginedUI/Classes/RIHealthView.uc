//=============================================================================
// RIHealthView
// Health, in the original gold. The body figure sits in the middle (AE's
// art, scaled up with smoothing until the redrawn version replaces it);
// each body part has a card with its bar, points and a Heal button, joined
// to the body by a thin line. The right panel has the overall status, the
// medkit count, Heal All and the pedometer. Healing calls AE's own
// HealPart / HealAllParts, so medkit use, Medicine skill and perks apply.
// Traumas are listed in the status panel (progress toward each, which are
// afflicting you) and cured with medkits through AE's own code.
//=============================================================================
class RIHealthView extends RIPersonaView;

const HOT_HEAL    = 100;   // + part
const HOT_PART    = 120;   // + part
const HOT_HEALALL = 50;
const HOT_CLASSIC = 51;
const HOT_CURE    = 52;
const HOT_TRAUMA  = 130;   // + trauma index

var int   PartSel;
var float Flash[6];
var string StatusMsg;
var float AnchorX[6], AnchorY[6], CardX[6], CardY[6];
var float StatusAge;
var Wound TraumaSel;

var localized string HealthTitle, StatusTitle, OverallLabel, MedkitsLabel, HealLabel, HealAllLabel;
var localized string StepsLabel, DistanceLabel, TimeLabel, LocationLabel, ClassicLabel, HealedLabel;
var localized string PartNames[6];
var localized string HintText, TraumasLabel, TraumasOffLabel, AfflictedLabel, CureLabel, CuredLabel, KitsLabel;

function PersonaScreenHealth Health()
{
	return PersonaScreenHealth(Screen);
}

function ScreenAttached()
{
	ActiveTab = TAB_HEALTH;
	PartSel = -1;
}

function float PartHealth(int i)
{
	if (i == 0) return Player.HealthHead;
	if (i == 1) return Player.HealthTorso;
	if (i == 2) return Player.HealthArmRight;
	if (i == 3) return Player.HealthArmLeft;
	if (i == 4) return Player.HealthLegRight;
	return Player.HealthLegLeft;
}

function float PartMax(int i)
{
	if ((Health().regionWindows[i] != None) && (Health().regionWindows[i].maxHealth > 0))
		return Health().regionWindows[i].maxHealth;
	return 100;
}

function int MedkitCount()
{
	local MedKit M;

	M = MedKit(Player.FindInventoryType(Class'MedKit'));
	if (M == None)
		return 0;
	return M.NumCopies;
}

function bool CanHeal(int i)
{
	return (MedkitCount() > 0) && (PartHealth(i) < PartMax(i));
}

function HealOne(int i)
{
	local int pts;

	if (!CanHeal(i))
	{
		PlaySound(Sound'Menu_Cancel', 0.25);
		return;
	}
	// The same steps AE's per-part Heal button takes
	Health().PushHealth();
	pts = Health().HealPart(Health().regionWindows[i]);
	Player.PopHealth(Health().playerHealth[0], Health().playerHealth[1], Health().playerHealth[2],
		Health().playerHealth[3], Health().playerHealth[4], Health().playerHealth[5]);
	Player.ResetAim();
	Health().EnableButtons();
	Flash[i] = 1.0;
	StatusMsg = Sprintf(HealedLabel, pts);
	StatusAge = 0;
}

function HealAll()
{
	local int i, pts;

	if (MedkitCount() <= 0)
	{
		PlaySound(Sound'Menu_Cancel', 0.25);
		return;
	}
	pts = Health().HealAllParts();
	for (i = 0; i < 6; i++)
		Flash[i] = 1.0;
	StatusMsg = Sprintf(HealedLabel, pts);
	StatusAge = 0;
}

function PageClick(int Id, EInputKey button, int numClicks)
{
	if (button != IK_LeftMouse)
		return;
	if ((Id >= HOT_PART) && (Id < HOT_PART + 6))
	{
		PartSel = Id - HOT_PART;
		PlaySound(Sound'Menu_Press', 0.2);
		if (numClicks >= 2)
			HealOne(PartSel);
	}
	else if ((Id >= HOT_HEAL) && (Id < HOT_HEAL + 6))
		HealOne(Id - HOT_HEAL);
	else if (Id == HOT_HEALALL)
		HealAll();
	else if (Id == HOT_CLASSIC)
		SwitchView(True);
	else if ((Id >= HOT_TRAUMA) && (Id < HOT_TRAUMA + 16))
	{
		TraumaSel = TraumaAt(Id - HOT_TRAUMA);
		PlaySound(Sound'Menu_Press', 0.2);
	}
	else if (Id == HOT_CURE)
		Cure();
}

// ----------------------------------------------------------------------
// Traumas (AE's wound system)
// ----------------------------------------------------------------------

function int TraumaCount()
{
	if ((Player.WoundManager == None) || !Player.bWoundSystem)
		return 0;
	return Player.WoundManager.GetWoundNumber();
}

function Wound TraumaAt(int i)
{
	if ((i < 0) || (i >= TraumaCount()))
		return None;
	return Player.WoundManager.GetWoundByIndex(i);
}

function bool CanCure(Wound W)
{
	return (W != None) && W.HasWound() && (MedkitCount() > 0) && (MedkitCount() >= W.GetRequiredMedkits());
}

// The same steps AE's Cure Trauma button takes
function Cure()
{
	if (!CanCure(TraumaSel))
	{
		PlaySound(Sound'Menu_Cancel', 0.25);
		return;
	}
	Health().RemoveTraumaMedkits(TraumaSel);
	TraumaSel.RemoveWound();
	Health().UpdateMedKits();
	Health().EnableButtons();
	StatusMsg = Sprintf(CuredLabel, TraumaSel.WoundName);
	StatusAge = 0;
}

function bool PageKey(EInputKey key, bool bRepeat)
{
	if ((key == IK_Up) || (key == IK_Left))
	{
		PartSel = int((PartSel + 5) % 6);
		PlaySound(Sound'Menu_Focus', 0.2);
		return True;
	}
	if ((key == IK_Down) || (key == IK_Right))
	{
		PartSel = int((PartSel + 1) % 6);
		PlaySound(Sound'Menu_Focus', 0.2);
		return True;
	}
	if ((key == IK_Enter) && !bRepeat)
	{
		if (PartSel >= 0)
			HealOne(PartSel);
		else
			HealAll();
		return True;
	}
	return False;
}

function PageTick(float deltaSeconds)
{
	local int i;

	StatusAge += deltaSeconds;
	for (i = 0; i < 6; i++)
		Flash[i] = FMax(0, Flash[i] - deltaSeconds * 1.5);
}

// ----------------------------------------------------------------------
// Drawing
// ----------------------------------------------------------------------

function DrawPage(GC gc, float a)
{
	local float bx, by, bw, bh, k, cx, cy, cw, ch, px, py;
	local int i;
	local Texture T0, T1;

	if (VPlus())
	{
		DrawVPPage(gc, a);
		return;
	}
	Heading(gc, OX + 140 * S, 170 * S, 1000 * S, HealthTitle, a);

	// Body: AE's 219 x 357 figure, scaled up and centred in the left area
	bh = 700 * S;
	k = bh / 888.0;
	bw = 443.0 * k;
	bx = OX + 640 * S - bw * 0.5;
	by = 245 * S;
	T0 = Texture'DeusExUI.UserInterface.HealthBody_1';
	T1 = Texture'DeusExUI.UserInterface.HealthBody_2';
	// soft light behind the figure, fading out on every side
	CGlow(gc, bx - 200 * S, by - 60 * S, bw + 400 * S, bh + 120 * S, C3(30, 25, 11, a));
	gc.SetStyle(DSTY_Masked);
	gc.SetTileColor(C3(255, 255, 255, a));
	gc.DrawStretchedTexture(bx, by, bw, bh, 0, 0, 443, 888, Texture'ReimaginedUI.UI.RI_HealthBody');

	// Where each part's line meets the body (fractions of the figure, AE's layout)
	AnchorX[0] = bx + bw * 0.50;  AnchorY[0] = by + bh * 0.06;    // head
	AnchorX[1] = bx + bw * 0.50;  AnchorY[1] = by + bh * 0.25;    // torso
	AnchorX[2] = bx + bw * 0.14;  AnchorY[2] = by + bh * 0.38;    // right arm (screen left)
	AnchorX[3] = bx + bw * 0.86;  AnchorY[3] = by + bh * 0.38;    // left arm
	AnchorX[4] = bx + bw * 0.38;  AnchorY[4] = by + bh * 0.75;    // right leg
	AnchorX[5] = bx + bw * 0.62;  AnchorY[5] = by + bh * 0.75;    // left leg

	cw = 280 * S;
	ch = 118 * S;
	CardX[0] = OX + 1140 * S - cw;  CardY[0] = 245 * S;
	CardX[1] = OX + 140 * S;        CardY[1] = 245 * S;
	CardX[2] = OX + 140 * S;        CardY[2] = 480 * S;
	CardX[3] = OX + 1140 * S - cw;  CardY[3] = 480 * S;
	CardX[4] = OX + 140 * S;        CardY[4] = 760 * S;
	CardX[5] = OX + 1140 * S - cw;  CardY[5] = 760 * S;

	for (i = 0; i < 6; i++)
	{
		// Connector: card edge -> elbow -> body point
		if (CardX[i] < bx)
			px = CardX[i] + cw;
		else
			px = CardX[i];
		py = CardY[i] + 22 * S;
		Leader(gc, px, py, AnchorX[i], AnchorY[i], a);

		DrawPartCard(gc, i, CardX[i], CardY[i], cw, ch, a);
	}

	DrawStatus(gc, a);
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', OX + 140 * S, FY + FH + 22 * S, HintText, ALbl(a * 0.8), 0.7);
}

// Callout: a short stub off the card, then a straight dotted line to the
// part's point on the body, and the point itself
function Leader(GC gc, float px, float py, float ax, float ay, float a)
{
	local float sx, dx, dy, L, t, stp;
	local int k, n;

	if (ax > px)
		sx = px + 18 * S;
	else
		sx = px - 18 * S;
	Class'RIText'.static.HLine(gc, FMin(px, sx), py, 18 * S, AEdge(a));
	dx = ax - sx;
	dy = ay - py;
	L = Sqrt(dx * dx + dy * dy);
	stp = 5 * S;
	n = int(L / stp);
	for (k = 0; k <= n; k++)
	{
		t = float(k) / FMax(1, n);
		Fill(gc, sx + dx * t - 1 * S, py + dy * t - 1 * S, 2 * S, 2 * S, AEdge(a));
	}
	Fill(gc, ax - 3 * S, ay - 3 * S, 6 * S, 6 * S, AHi(a));
	Class'RIText'.static.Box(gc, ax - 6 * S, ay - 6 * S, 12 * S, 12 * S, AEdge(a));
}

function DrawPartCard(GC gc, int i, float X, float Y, float W, float H, float a)
{
	local float cur, mx, f, bw2;
	local bool bSel, bHot;
	local Color BarC;

	cur = PartHealth(i);
	mx = PartMax(i);
	f = FClamp(cur / FMax(1, mx), 0, 1);
	bSel = (i == PartSel);
	bHot = (HoverId == HOT_PART + i);

	Fill(gc, X, Y, W, H, C3(30, 25, 11, 0.65 * a));
	if (bSel)
		SelRow(gc, X, Y, W, H, a);
	else if (bHot)
		Class'RIText'.static.Box(gc, X, Y, W, H, AEdge(a));
	else
		Class'RIText'.static.Box(gc, X, Y, W, H, C3(90, 75, 36, a));
	if (Flash[i] > 0)
		Glow(gc, X, Y, W, H, C3(60 * Flash[i], 90 * Flash[i], 40 * Flash[i], a));
	AddHot(HOT_PART + i, X, Y, W, H);

	// Vanilla+: a narrower card (name, value, bar, Heal) to fit beside the figure
	if (VPlus())
	{
		if (f > 0.66)
			BarC = AAcc(a);
		else if (f > 0.33)
			BarC = C3(240, 150, 50, a);
		else
			BarC = C3(230, 70, 50, a);
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', X + 10 * S, Y + 8 * S, Caps(PartNames[i]), AAcc(a), 0.6);
		Class'RIText'.static.Draw(gc, Class'RIFontHead', X + 10 * S, Y + 28 * S, string(int(cur)) $ " / " $ string(int(mx)), ATxt(a), 0.42);
		Fill(gc, X + 10 * S, Y + 52 * S, W - 20 * S, 6 * S, C3(40, 33, 15, a));
		Fill(gc, X + 10 * S, Y + 52 * S, (W - 20 * S) * f, 6 * S, BarC);
		DrawBtn(gc, X + 10 * S, Y + H - 40 * S, W - 20 * S, 30 * S, HealLabel, CanHeal(i), HoverId == HOT_HEAL + i, False, a);
		AddHot(HOT_HEAL + i, X + 10 * S, Y + H - 40 * S, W - 20 * S, 30 * S);
		return;
	}

	Class'RIText'.static.Draw(gc, Class'RIFontSmall', X + 14 * S, Y + 12 * S, Caps(PartNames[i]), AAcc(a), 0.7);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', X + W * 0.5, Y + 8 * S, W * 0.5 - 14 * S, 24 * S,
		string(int(cur)) $ " / " $ string(int(mx)), ATxt(a), 2, 0.5);

	// Bar: gold when healthy, through orange to red
	if (f > 0.66)
		BarC = AAcc(a);
	else if (f > 0.33)
		BarC = C3(240, 150, 50, a);
	else
		BarC = C3(230, 70, 50, a);
	bw2 = W - 28 * S;
	Fill(gc, X + 14 * S, Y + 42 * S, bw2, 10 * S, C3(40, 33, 15, a));
	Fill(gc, X + 14 * S, Y + 42 * S, bw2 * f, 10 * S, BarC);
	Class'RIText'.static.Box(gc, X + 14 * S, Y + 42 * S, bw2, 10 * S, C3(110, 92, 44, a));

	DrawBtn(gc, X + 14 * S, Y + H - 50 * S, W - 28 * S, 38 * S, HealLabel, CanHeal(i), HoverId == HOT_HEAL + i, False, a);
	AddHot(HOT_HEAL + i, X + 14 * S, Y + H - 50 * S, W - 28 * S, 38 * S);
}

function DrawStatus(GC gc, float a)
{
	local float x, y, w, h, tot, mx, f, bw;
	local int i;
	local DeusExLevelInfo Info;
	local string Loc;

	x = OX + 1180 * S;
	y = 240 * S;
	w = 600 * S;
	h = 700 * S;
	Panel(gc, x, y, w, h, a);
	x += 26 * S;
	w -= 52 * S;
	y += 24 * S;
	Class'RIText'.static.Draw(gc, Class'RIFontTitle', x, y, Caps(StatusTitle), ATxt(a), 0.44);
	y += 60 * S;

	// Overall
	tot = 0;
	mx = 0;
	for (i = 0; i < 6; i++)
	{
		tot += PartHealth(i);
		mx += PartMax(i);
	}
	f = FClamp(tot / FMax(1, mx), 0, 1);
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, Caps(OverallLabel), ALbl(a), 0.7);
	Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', x, y - 6 * S, w, 40 * S, string(int(f * 100)) $ "%", AHi(a), 2, 0.5);
	y += 40 * S;
	Fill(gc, x, y, w, 12 * S, C3(40, 33, 15, a));
	Fill(gc, x, y, w * f, 12 * S, AAcc(a));
	Class'RIText'.static.Box(gc, x, y, w, 12 * S, C3(110, 92, 44, a));
	y += 40 * S;

	StatLine(gc, x, y, w, MedkitsLabel, string(MedkitCount()), a);
	y += 34 * S;
	Info = Player.GetLevelInfo();
	Loc = "";
	if (Info != None)
		Loc = Info.MissionLocation;
	StatLine(gc, x, y, w, LocationLabel, Loc, a);
	y += 34 * S;
	StatLine(gc, x, y, w, StepsLabel, string(Player.stepCount), a);
	y += 34 * S;
	StatLine(gc, x, y, w, DistanceLabel, string(int(Player.stepCount * 0.0005)) $ " mi", a);
	y += 34 * S;
	StatLine(gc, x, y, w, TimeLabel, Health().BuildElapsedPlayTimeString(int(Player.saveTime)), a);
	y += 48 * S;

	DrawTraumas(gc, x, y, w, 240 * S + h - 120 * S, a);

	if ((StatusMsg != "") && (StatusAge < 3.0))
		Class'RIText'.static.Draw(gc, Class'RIFontBody', x, 240 * S + h - 112 * S, StatusMsg, C3(150, 230, 140, a * FClamp((3.0 - StatusAge) / 0.5, 0, 1)), 0.74);

	// Actions: Heal all, Cure (the selected trauma)
	y = 240 * S + h - 74 * S;
	bw = (w - 12 * S) / 2;
	DrawBtn(gc, x, y, bw, 50 * S, HealAllLabel, MedkitCount() > 0, HoverId == HOT_HEALALL, MedkitCount() > 0, a);
	AddHot(HOT_HEALALL, x, y, bw, 50 * S);
	DrawBtn(gc, x + bw + 12 * S, y, bw, 50 * S, CureLabel, CanCure(TraumaSel), HoverId == HOT_CURE, False, a);
	AddHot(HOT_CURE, x + bw + 12 * S, y, bw, 50 * S);
}

// One row per trauma: icon, name, "afflicted" (and the medkits a cure
// takes) or progress toward it, with a thin bar
function DrawTraumas(GC gc, float X, float Y, float W, float Bottom, float a)
{
	local int i, n, kits;
	local float rh, f;
	local Wound Wd;
	local bool bSel;
	local string R;
	local Color BC;

	Class'RIText'.static.Draw(gc, Class'RIFontSmall', X, Y, Caps(TraumasLabel), AAcc(a), 0.7);
	Class'RIText'.static.HLine(gc, X, Y + 22 * S, W, ADim(a));
	Y += 30 * S;
	if (TraumaCount() == 0)
	{
		Class'RIText'.static.Draw(gc, Class'RIFontBody', X, Y, TraumasOffLabel, ALbl(a), 0.72);
		return;
	}
	rh = 32 * S;
	for (i = 0; (i < TraumaCount()) && (i < 16); i++)
	{
		Wd = TraumaAt(i);
		if ((Wd == None) || Wd.bNoDisplay)
			continue;
		if (Y + rh > Bottom)
			break;
		if ((TraumaSel == None) && Wd.HasWound())
			TraumaSel = Wd;
		bSel = (Wd == TraumaSel);
		if (bSel)
			SelRow(gc, X, Y, W, rh - 3 * S, a);
		else if (HoverId == HOT_TRAUMA + i)
			Class'RIText'.static.Box(gc, X, Y, W, rh - 3 * S, AEdge(a));
		AddHot(HOT_TRAUMA + i, X, Y, W, rh - 3 * S);

		if (Wd.WoundIcon != None)
		{
			gc.SetStyle(DSTY_Masked);
			gc.SetTileColor(C3(255, 255, 255, a));
			Class'RIHD'.static.DrawStretched(gc, X + 4 * S, Y + 2 * S, 25 * S, 25 * S, 0, 0, Wd.WoundIcon.USize, Wd.WoundIcon.VSize, Wd.WoundIcon);
		}
		Class'RIText'.static.DrawIn(gc, Class'RIFontBody', X + 38 * S, Y, W * 0.5, rh - 6 * S, Wd.WoundName, ATxt(a), 0, 0.7);

		f = FClamp(float(Wd.GetDamage()) / FMax(1, Wd.DamageThreshold), 0, 1);
		if (Wd.HasWound())
		{
			kits = Wd.GetRequiredMedkits();
			R = Caps(AfflictedLabel) $ "  -  " $ string(kits) @ Caps(KitsLabel);
			BC = C3(230, 70, 50, a);
			f = 1;
		}
		else
		{
			R = string(Wd.GetDamage()) $ " / " $ string(Wd.DamageThreshold);
			if (f > 0.66)
				BC = C3(240, 150, 50, a);
			else
				BC = AAcc(a);
		}
		if (Wd.HasWound())
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X + W * 0.5, Y, W * 0.5 - 8 * S, rh - 8 * S, R, C3(255, 120, 90, a), 2, 0.56);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X + W * 0.5, Y, W * 0.5 - 8 * S, rh - 8 * S, R, ALbl(a), 2, 0.56);
		Fill(gc, X + 38 * S, Y + rh - 7 * S, W - 46 * S, 2 * S, C3(40, 33, 15, a));
		Fill(gc, X + 38 * S, Y + rh - 7 * S, (W - 46 * S) * f, 2 * S, BC);
		Y += rh;
		n++;
	}
}

// ----------------------------------------------------------------------
// Vanilla+: figure and part cards in the left frame, status in the right
// frame (name bar, body, footer), medkits and actions in the lower box
// ----------------------------------------------------------------------

function DrawVPPage(GC gc, float a)
{
	local float bx, by, bw, bh, k, cx, cw, ch, px, py;
	local int i;

	VPTitle(gc, HealthTitle, a);
	bh = 560 * S;
	k = bh / 888.0;
	bw = 443.0 * k;
	bx = OX + 688 * S - bw * 0.5;
	by = 250 * S;
	gc.SetStyle(DSTY_Masked);
	gc.SetTileColor(C3(255, 255, 255, a));
	gc.DrawStretchedTexture(bx, by, bw, bh, 0, 0, 443, 888, Texture'ReimaginedUI.UI.RI_HealthBody');

	AnchorX[0] = bx + bw * 0.50;  AnchorY[0] = by + bh * 0.06;
	AnchorX[1] = bx + bw * 0.50;  AnchorY[1] = by + bh * 0.25;
	AnchorX[2] = bx + bw * 0.14;  AnchorY[2] = by + bh * 0.38;
	AnchorX[3] = bx + bw * 0.86;  AnchorY[3] = by + bh * 0.38;
	AnchorX[4] = bx + bw * 0.38;  AnchorY[4] = by + bh * 0.75;
	AnchorX[5] = bx + bw * 0.62;  AnchorY[5] = by + bh * 0.75;

	cw = 160 * S;
	ch = 104 * S;
	CardX[0] = OX + 807 * S;  CardY[0] = 200 * S;    // head
	CardX[1] = OX + 410 * S;  CardY[1] = 200 * S;    // torso
	CardX[2] = OX + 410 * S;  CardY[2] = 470 * S;    // right arm
	CardX[3] = OX + 807 * S;  CardY[3] = 470 * S;    // left arm
	CardX[4] = OX + 410 * S;  CardY[4] = 790 * S;    // right leg
	CardX[5] = OX + 807 * S;  CardY[5] = 790 * S;    // left leg
	for (i = 0; i < 6; i++)
	{
		if (CardX[i] < bx)
			px = CardX[i] + cw;
		else
			px = CardX[i];
		py = CardY[i] + 22 * S;
		Leader(gc, px, py, AnchorX[i], AnchorY[i], a);
		DrawPartCard(gc, i, CardX[i], CardY[i], cw, ch, a);
	}
	DrawVPStatus(gc, a);
}

function DrawVPStatus(GC gc, float a)
{
	local float x, y, w, tot, mx, f;
	local int i;
	local DeusExLevelInfo Info;
	local string Loc, T;

	x = OX + 1072 * S;
	w = 458 * S;
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 177 * S, w, 28 * S, Caps(StatusTitle), ATxt(a), 0, 0.5);

	// Body: overall, the monitor readouts, traumas
	y = 228 * S;
	tot = 0;
	mx = 0;
	for (i = 0; i < 6; i++)
	{
		tot += PartHealth(i);
		mx += PartMax(i);
	}
	f = FClamp(tot / FMax(1, mx), 0, 1);
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y + 8 * S, Caps(OverallLabel), ALbl(a), 0.62);
	Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', x, y, w, 34 * S, string(int(f * 100)) $ "%", AHi(a), 2, 0.42);
	y += 40 * S;
	Fill(gc, x, y, w, 10 * S, C3(40, 33, 15, a));
	Fill(gc, x, y, w * f, 10 * S, AAcc(a));
	y += 22 * S;
	Info = Player.GetLevelInfo();
	Loc = "";
	if (Info != None)
		Loc = Info.MissionLocation;
	StatLine(gc, x, y, w, LocationLabel, Loc, a);
	y += 36 * S;
	StatLine(gc, x, y, w, StepsLabel, string(Player.stepCount), a);
	y += 36 * S;
	StatLine(gc, x, y, w, DistanceLabel, string(int(Player.stepCount * 0.0005)) $ " mi", a);
	y += 36 * S;
	StatLine(gc, x, y, w, TimeLabel, Health().BuildElapsedPlayTimeString(int(Player.saveTime)), a);
	y += 50 * S;
	DrawTraumas(gc, x, y, w, 650 * S, a);

	// Footer bar: what just happened, or how to heal
	if ((StatusMsg != "") && (StatusAge < 3.0))
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, 670 * S, w, 30 * S, StatusMsg, C3(150, 230, 140, a * FClamp((3.0 - StatusAge) / 0.5, 0, 1)), 0, 0.56);
	else
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, 670 * S, w, 30 * S, "CLICK A BODY PART TO HEAL IT", ALbl(a), 0, 0.52);

	// Lower box: medkit and count on the left, actions on the right
	if (Class'MedKit'.default.Icon != None)
	{
		gc.SetStyle(DSTY_Masked);
		gc.SetTileColor(C3(255, 255, 255, a));
		Class'RIHD'.static.DrawStretched(gc, OX + 1072 * S, 766 * S, 84 * S, 74 * S, 0, 0, 42, 37, Class'MedKit'.default.Icon);
	}
	T = Caps(MedkitsLabel) @ string(MedkitCount());
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 1182 * S, 756 * S, 350 * S, 30 * S, T, ATxt(a), 0, 0.6);
	DrawBtn(gc, OX + 1182 * S, 800 * S, 168 * S, 40 * S, HealAllLabel, MedkitCount() > 0, HoverId == HOT_HEALALL, MedkitCount() > 0, a);
	AddHot(HOT_HEALALL, OX + 1182 * S, 800 * S, 168 * S, 40 * S);
	DrawBtn(gc, OX + 1362 * S, 800 * S, 168 * S, 40 * S, CureLabel, CanCure(TraumaSel), HoverId == HOT_CURE, False, a);
	AddHot(HOT_CURE, OX + 1362 * S, 800 * S, 168 * S, 40 * S);
}

function StatLine(GC gc, float X, float Y, float W, string L, string V, float a)
{
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', X, Y + 6 * S, Caps(L), ALbl(a), 0.7);
	Class'RIText'.static.DrawIn(gc, Class'RIFontBody', X + W * 0.4, Y, W * 0.6, 30 * S,
		Class'RIText'.static.Fit(Class'RIFontBody', V, W * 0.6, 0.82), ATxt(a), 2, 0.82);
	Class'RIText'.static.HLine(gc, X, Y + 34 * S, W, C3(60, 50, 24, a));
}

defaultproperties
{
     HealthTitle="Health"
     StatusTitle="Status"
     OverallLabel="Overall"
     MedkitsLabel="Medkits"
     HealLabel="Heal"
     HealAllLabel="Heal all"
     StepsLabel="Steps taken"
     DistanceLabel="Distance"
     TimeLabel="Time monitored"
     LocationLabel="Location"
     ClassicLabel="Classic view"
     TraumasLabel="Traumas"
     TraumasOffLabel="Traumas are off for this game."
     AfflictedLabel="Afflicted"
     CureLabel="Cure trauma"
     CuredLabel="Cured: %s"
     KitsLabel="Medkits"
     HealedLabel="Healed %d points"
     PartNames(0)="Head"
     PartNames(1)="Torso"
     PartNames(2)="Right arm"
     PartNames(3)="Left arm"
     PartNames(4)="Right leg"
     PartNames(5)="Left leg"
     HintText="CLICK a part to select     ENTER or double-click heal     HEAL ALL uses medkits across the body     ESC close"
     bHideScreen=True
}
