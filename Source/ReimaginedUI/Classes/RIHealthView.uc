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
var Object TraumaSel;      // a trauma (base feature), read through RIBase

var localized string MedTitle, MedHealLabel, MedReadyLabel, MedChargingLabel, MedHealedLabel;
var localized string HealthTitle, StatusTitle, OverallLabel, MedkitsLabel, HealLabel, HealAllLabel;
var localized string StepsLabel, DistanceLabel, TimeLabel, LocationLabel, ClassicLabel, HealedLabel;
var localized string PartNames[6];
var localized string InjuredLabel, CriticalLabel, NumbLabel;
// Each part's place on the figure (RI_HealthBody / RI_HealthHi pixels): its
// glow, and where hovering or clicking the figure picks it
var float HX0[6], HY0[6], HX1[6], HY1[6];
var localized string HintText, TraumasLabel, TraumasOffLabel, AfflictedLabel, CureLabel, CuredLabel, KitsLabel;

function HUDMedBotHealthScreen MedBot()
{
	return HUDMedBotHealthScreen(Screen);
}

// The med bot can heal now (charged, and there's damage to heal)
function bool MedReady()
{
	return (MedBot() != None) && (MedBot().medBot != None) && MedBot().medBot.CanHeal() && MedBot().IsPlayerDamaged();
}

// Heal All button: medkits, or the bot on a med bot page
function string HealAllText()
{
	if (MedBot() != None)
		return MedHealLabel;
	return HealAllLabel;
}

function bool HealAllLive()
{
	if (MedBot() != None)
		return MedReady();
	return MedkitCount() > 0;
}

// The bot's state, under the title on a med bot page
function string MedLine()
{
	if ((MedBot() == None) || (MedBot().medBot == None))
		return "";
	if (MedBot().medBot.CanHeal())
		return Sprintf(MedReadyLabel, MedBot().medBot.healAmount);
	return MedChargingLabel;
}

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
	Class'RIBase'.static.ResetAim(Player);
	Health().EnableButtons();
	Flash[i] = 1.0;
	StatusMsg = Sprintf(HealedLabel, pts);
	StatusAge = 0;
}

function HealAll()
{
	local int i, pts;

	if (MedBot() != None)
	{
		if (!MedReady())
		{
			PlaySound(Sound'Menu_Cancel', 0.25);
			return;
		}
		MedBot().MedBotHealPlayer();
		for (i = 0; i < 6; i++)
			Flash[i] = 1.0;
		StatusMsg = MedHealedLabel;
		StatusAge = 0;
		return;
	}
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
	return Class'RIBase'.static.TraumaCount(Player);
}

function Object TraumaAt(int i)
{
	if ((i < 0) || (i >= TraumaCount()))
		return None;
	return Class'RIBase'.static.TraumaAt(Player, i);
}

function bool CanCure(Object W)
{
	return (W != None) && Class'RIBase'.static.TraumaActive(W) && (MedkitCount() > 0) && (MedkitCount() >= Class'RIBase'.static.TraumaKits(W));
}

// The same steps AE's Cure Trauma button takes
function Cure()
{
	if (!CanCure(TraumaSel))
	{
		PlaySound(Sound'Menu_Cancel', 0.25);
		return;
	}
	Class'RIBase'.static.TraumaCure(Health(), TraumaSel);
	Health().UpdateMedKits();
	Health().EnableButtons();
	StatusMsg = Sprintf(CuredLabel, Class'RIBase'.static.TraumaName(TraumaSel));
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
	if (MedBot() != None)
	{
		Heading(gc, OX + 140 * S, 170 * S, 1000 * S, MedTitle, a);
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', OX + 140 * S, 214 * S, Caps(MedLine()), AAcc(a), 0.8);
	}
	else
		Heading(gc, OX + 140 * S, 170 * S, 1000 * S, HealthTitle, a);

	// Body: AE's 219 x 357 figure, scaled up and centred in the left area
	bh = 700 * S;
	k = bh / 888.0;
	bw = 465.0 * k;
	bx = OX + 640 * S - bw * 0.5;
	by = 245 * S;
	T0 = Texture'DeusExUI.UserInterface.HealthBody_1';
	T1 = Texture'DeusExUI.UserInterface.HealthBody_2';
	// soft light behind the figure, fading out on every side
	CGlow(gc, bx - 200 * S, by - 60 * S, bw + 400 * S, bh + 120 * S, C3(30, 25, 11, a));
	gc.SetStyle(DSTY_Masked);
	gc.SetTileColor(C3(255, 255, 255, a));
	gc.DrawStretchedTexture(bx, by, bw, bh, 0, 0, 465, 888, Texture'ReimaginedUI.UI.RI_HealthBody');

	// Where each part's line meets the body (fractions of the figure, AE's layout)
	DrawPartGlow(gc, bx, by, bw, bh, a);
	SetAnchors(bx, by, bw, bh);

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

// Where each part's line meets the body (fractions of the new figure)
function SetAnchors(float bx, float by, float bw, float bh)
{
	AnchorX[0] = bx + bw * 0.50;  AnchorY[0] = by + bh * 0.065;   // head
	AnchorX[1] = bx + bw * 0.50;  AnchorY[1] = by + bh * 0.25;    // torso
	AnchorX[2] = bx + bw * 0.15;  AnchorY[2] = by + bh * 0.33;    // right arm (screen left)
	AnchorX[3] = bx + bw * 0.85;  AnchorY[3] = by + bh * 0.33;    // left arm
	AnchorX[4] = bx + bw * 0.40;  AnchorY[4] = by + bh * 0.58;    // right leg
	AnchorX[5] = bx + bw * 0.60;  AnchorY[5] = by + bh * 0.58;    // left leg
}

// Callout from the card to its part: the shared 1 px line, no marker on the
// body (the part itself lights when picked or hurt)
function Leader(GC gc, float px, float py, float ax, float ay, float a)
{
	LeaderLine(gc, px, py, ax, ay, AEdge(a));
}

// The figure shows each part's state: hurt parts glow round their outline,
// orange through red with the damage; a part at zero (numb) pulses red. The
// hovered part lights softly, the chosen one more. Each part's area of the
// figure can be hovered and clicked like its card.
function DrawPartGlow(GC gc, float bx, float by, float bw, float bh, float a)
{
	local int i;
	local float f, k;

	gc.SetStyle(DSTY_Translucent);
	for (i = 0; i < 6; i++)
	{
		f = FClamp(PartHealth(i) / FMax(1, PartMax(i)), 0, 1);
		if (f <= 0.001)
			PartTex(gc, i, bx, by, bw, bh, C3(255, 40, 30, a * (0.65 + 0.35 * Sin(Age * 5.0))));
		else if (f < 0.999)
		{
			k = 1.0 - f;
			if (f > 0.5)
				PartTex(gc, i, bx, by, bw, bh, C3(255, 170, 50, a * (0.35 + 0.9 * k)));
			else
				PartTex(gc, i, bx, by, bw, bh, C3(255, 70, 40, a * (0.55 + 0.6 * k)));
		}
		if (i == PartSel)
			PartTex(gc, i, bx, by, bw, bh, C3(255, 232, 150, a * 0.6));
		else if (HoverId == HOT_PART + i)
			PartTex(gc, i, bx, by, bw, bh, C3(255, 232, 150, a * 0.4));
		if (Flash[i] > 0)
			PartTex(gc, i, bx, by, bw, bh, C3(120, 255, 140, a * Flash[i]));
		AddHot(HOT_PART + i, bx + bw * HX0[i] / 465.0, by + bh * FMax(0, HY0[i]) / 888.0,
			bw * (HX1[i] - HX0[i]) / 465.0, bh * (HY1[i] - FMax(0, HY0[i])) / 888.0);
	}
}

function PartTex(GC gc, int i, float bx, float by, float bw, float bh, Color Col)
{
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Col);
	gc.DrawStretchedTexture(bx + bw * HX0[i] / 465.0, by + bh * HY0[i] / 888.0,
		bw * (HX1[i] - HX0[i]) / 465.0, bh * (HY1[i] - HY0[i]) / 888.0,
		HX0[i], HY0[i] + 32, HX1[i] - HX0[i], HY1[i] - HY0[i], Texture'ReimaginedUI.UI.RI_HealthHi');
}

// A part's state for its card: "" when whole
function string PartState(int i, out Color Col, float a)
{
	local float f;

	f = FClamp(PartHealth(i) / FMax(1, PartMax(i)), 0, 1);
	if (f <= 0.001)
	{
		Col = C3(255, 70, 55, a);
		return NumbLabel;
	}
	if (f < 0.34)
	{
		Col = C3(255, 95, 60, a);
		return CriticalLabel;
	}
	if (f < 0.999)
	{
		Col = C3(255, 175, 70, a);
		return InjuredLabel;
	}
	return "";
}

function DrawPartCard(GC gc, int i, float X, float Y, float W, float H, float a)
{
	local float cur, mx, f, bw2;
	local bool bSel, bHot;
	local Color BarC, StC;
	local string St;

	cur = PartHealth(i);
	mx = PartMax(i);
	f = FClamp(cur / FMax(1, mx), 0, 1);
	bSel = (i == PartSel);
	bHot = (HoverId == HOT_PART + i);
	St = PartState(i, StC, a);

	Fill(gc, X, Y, W, H, C3(30, 25, 11, 0.65 * a));
	if (bSel)
		SelRow(gc, X, Y, W, H, a);
	else if (bHot)
		Class'RIText'.static.Box(gc, X, Y, W, H, AEdge(a));
	else if (St != "")
		Class'RIText'.static.Box(gc, X, Y, W, H, StC);
	else
		Class'RIText'.static.Box(gc, X, Y, W, H, C3(90, 75, 36, a));
	// a hurt part's card carries a warm wash along its left edge
	if (St != "")
		Fill(gc, X, Y, 3 * S, H, StC);
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
		if (St != "")
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X + 10 * S, Y + 28 * S, W - 20 * S, 18 * S, Caps(St), StC, 2, 0.46);
		Fill(gc, X + 10 * S, Y + 52 * S, W - 20 * S, 6 * S, C3(40, 33, 15, a));
		Fill(gc, X + 10 * S, Y + 52 * S, (W - 20 * S) * f, 6 * S, BarC);
		DrawBtn(gc, X + 10 * S, Y + H - 40 * S, W - 20 * S, 30 * S, HealLabel, CanHeal(i), HoverId == HOT_HEAL + i, False, a);
		AddHot(HOT_HEAL + i, X + 10 * S, Y + H - 40 * S, W - 20 * S, 30 * S);
		return;
	}

	Class'RIText'.static.Draw(gc, Class'RIFontSmall', X + 14 * S, Y + 12 * S, Caps(PartNames[i]), AAcc(a), 0.7);
	if (St != "")
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', X + 24 * S + Class'RIText'.static.Width(Class'RIFontSmall', Caps(PartNames[i]), 0.7), Y + 14 * S, Caps(St), StC, 0.56);
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
	if (Class'RIUtil'.static.PHas(Player, "stepCount"))
	{
		StatLine(gc, x, y, w, StepsLabel, string(Class'RIUtil'.static.PInt(Player, "stepCount")), a);
		y += 34 * S;
		StatLine(gc, x, y, w, DistanceLabel, string(int(Class'RIUtil'.static.PInt(Player, "stepCount") * 0.0005)) $ " mi", a);
		y += 34 * S;
	}
	StatLine(gc, x, y, w, TimeLabel, Class'RIUtil'.static.ClockTime(int(Player.saveTime)), a);
	y += 48 * S;

	DrawTraumas(gc, x, y, w, 240 * S + h - 120 * S, a);

	if ((StatusMsg != "") && (StatusAge < 3.0))
		Class'RIText'.static.Draw(gc, Class'RIFontBody', x, 240 * S + h - 112 * S, StatusMsg, C3(150, 230, 140, a * FClamp((3.0 - StatusAge) / 0.5, 0, 1)), 0.74);

	// Actions: Heal all, Cure (the selected trauma)
	y = 240 * S + h - 74 * S;
	if (Class'RIBase'.static.Has("Traumas"))
		bw = (w - 12 * S) / 2;
	else
		bw = w;
	DrawBtn(gc, x, y, bw, 50 * S, HealAllText(), HealAllLive(), HoverId == HOT_HEALALL, HealAllLive(), a);
	AddHot(HOT_HEALALL, x, y, bw, 50 * S);
	if (Class'RIBase'.static.Has("Traumas"))
	{
		DrawBtn(gc, x + bw + 12 * S, y, bw, 50 * S, CureLabel, CanCure(TraumaSel), HoverId == HOT_CURE, False, a);
		AddHot(HOT_CURE, x + bw + 12 * S, y, bw, 50 * S);
	}
}

// One row per trauma: icon, name, "afflicted" (and the medkits a cure
// takes) or progress toward it, with a thin bar
function DrawTraumas(GC gc, float X, float Y, float W, float Bottom, float a)
{
	local int i, n, kits;
	local float rh, f;
	local Object Wd;
	local bool bSel;
	local string R;
	local Color BC;
	local Texture WIc;

	if (!Class'RIBase'.static.Has("Traumas"))
		return;
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
		if ((Wd == None) || Class'RIBase'.static.TraumaHidden(Wd))
			continue;
		if (Y + rh > Bottom)
			break;
		if ((TraumaSel == None) && Class'RIBase'.static.TraumaActive(Wd))
			TraumaSel = Wd;
		bSel = (Wd == TraumaSel);
		if (bSel)
			SelRow(gc, X, Y, W, rh - 3 * S, a);
		else if (HoverId == HOT_TRAUMA + i)
			Class'RIText'.static.Box(gc, X, Y, W, rh - 3 * S, AEdge(a));
		AddHot(HOT_TRAUMA + i, X, Y, W, rh - 3 * S);

		WIc = Class'RIBase'.static.TraumaIcon(Wd);
		if (WIc != None)
		{
			gc.SetStyle(DSTY_Masked);
			gc.SetTileColor(C3(255, 255, 255, a));
			Class'RIHD'.static.DrawStretched(gc, X + 4 * S, Y + 2 * S, 25 * S, 25 * S, 0, 0, WIc.USize, WIc.VSize, WIc);
		}
		Class'RIText'.static.DrawIn(gc, Class'RIFontBody', X + 38 * S, Y, W * 0.5, rh - 6 * S, Class'RIBase'.static.TraumaName(Wd), ATxt(a), 0, 0.7);

		f = FClamp(float(Class'RIBase'.static.TraumaDamage(Wd)) / FMax(1, Class'RIBase'.static.TraumaThreshold(Wd)), 0, 1);
		if (Class'RIBase'.static.TraumaActive(Wd))
		{
			kits = Class'RIBase'.static.TraumaKits(Wd);
			R = Caps(AfflictedLabel) $ "  -  " $ string(kits) @ Caps(KitsLabel);
			BC = C3(230, 70, 50, a);
			f = 1;
		}
		else
		{
			R = string(Class'RIBase'.static.TraumaDamage(Wd)) $ " / " $ string(Class'RIBase'.static.TraumaThreshold(Wd));
			if (f > 0.66)
				BC = C3(240, 150, 50, a);
			else
				BC = AAcc(a);
		}
		if (Class'RIBase'.static.TraumaActive(Wd))
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
	bw = 465.0 * k;
	bx = OX + 688 * S - bw * 0.5;
	by = 250 * S;
	gc.SetStyle(DSTY_Masked);
	gc.SetTileColor(C3(255, 255, 255, a));
	gc.DrawStretchedTexture(bx, by, bw, bh, 0, 0, 465, 888, Texture'ReimaginedUI.UI.RI_HealthBody');

	DrawPartGlow(gc, bx, by, bw, bh, a);
	SetAnchors(bx, by, bw, bh);

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
	if (Class'RIUtil'.static.PHas(Player, "stepCount"))
	{
		StatLine(gc, x, y, w, StepsLabel, string(Class'RIUtil'.static.PInt(Player, "stepCount")), a);
		y += 36 * S;
		StatLine(gc, x, y, w, DistanceLabel, string(int(Class'RIUtil'.static.PInt(Player, "stepCount") * 0.0005)) $ " mi", a);
		y += 36 * S;
	}
	StatLine(gc, x, y, w, TimeLabel, Class'RIUtil'.static.ClockTime(int(Player.saveTime)), a);
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
	DrawBtn(gc, OX + 1182 * S, 800 * S, 168 * S, 40 * S, HealAllText(), HealAllLive(), HoverId == HOT_HEALALL, HealAllLive(), a);
	AddHot(HOT_HEALALL, OX + 1182 * S, 800 * S, 168 * S, 40 * S);
	if (Class'RIBase'.static.Has("Traumas"))
	{
		DrawBtn(gc, OX + 1362 * S, 800 * S, 168 * S, 40 * S, CureLabel, CanCure(TraumaSel), HoverId == HOT_CURE, False, a);
		AddHot(HOT_CURE, OX + 1362 * S, 800 * S, 168 * S, 40 * S);
	}
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
     InjuredLabel="Injured"
     CriticalLabel="Critical"
     NumbLabel="Numb"
     HX0(0)=170
     HY0(0)=-32
     HX1(0)=295
     HY1(0)=118
     HX0(1)=135
     HY0(1)=118
     HX1(1)=330
     HY1(1)=440
     HX0(2)=0
     HY0(2)=118
     HX1(2)=135
     HY1(2)=470
     HX0(3)=330
     HY0(3)=118
     HX1(3)=465
     HY1(3)=470
     HX0(4)=90
     HY0(4)=440
     HX1(4)=232
     HY1(4)=888
     HX0(5)=232
     HY0(5)=440
     HX1(5)=375
     HY1(5)=888
     HealthTitle="Health"
     StatusTitle="Status"
     OverallLabel="Overall"
     MedkitsLabel="Medkits"
     HealLabel="Heal"
     HealAllLabel="Heal all"
     MedTitle="Medical Bot"
     MedHealLabel="Med bot heal"
     MedReadyLabel="Med bot ready: restores %d points"
     MedChargingLabel="Med bot recharging"
     MedHealedLabel="The med bot patched you up"
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
