//=============================================================================
// RISkillsView
// Skills / Perks, drawn to the Skills artboard in amber. Left: every skill
// with level pips and the cost of the next level, plus a "General perks"
// row. Right: the selected skill's description, its perks (owned /
// available / locked, with cost and requirement) and the actions.
// Upgrades go through AE's own PersonaScreenSkills (UpgradeSkill), perks
// through GMDX's PerkSystem (PurchasePerk), so all rules and sounds are theirs.
//=============================================================================
class RISkillsView extends RIPersonaView;

const HOT_ROW     = 100;    // + row
const HOT_PERK    = 200;    // + perk
const HOT_UPGRADE = 50;
const HOT_BUY     = 51;

var int   NumRows;          // skills + 1 (general perks)
var int   Sel;
var int   PerkSel;
var float SelY;
var float DescAge;
var float PointsFlash;

// Perks of the current row
var Object Perks[32];      // GMDX AE perks (base feature), read through RIBase
var int   NumPerks;
var float PerkScroll, PerkScrollTarget, PerkMax;
var float PerkTop, PerkBottom, PerkLeft, PerkRight;
var float PerkCardY[32], PerkCardH[32];
var float LScroll, LScrollTarget, LTop, LPitch;
var int   LastSkill;        // the skill row to return to from General perks   // the skill list scrolls to show general perks under their row

var localized string SkillsTitle, PointsLabel, SkillCol, LevelCol, CostCol;
var localized string PerksLabel, GeneralLabel, GeneralDesc, PerkCol, StatusCol;
var localized string OwnedLabel, AvailableLabel, LockedLabel, NeedsLabel;
var localized string UpgradeLabel, BuyLabel, MasteredLabel;
var localized string LevelNames[4];
var localized string HintText;

function PersonaScreenSkills Skills()
{
	return PersonaScreenSkills(Screen);
}

function ScreenAttached()
{
	ActiveTab = TAB_SKILLS;
	NumRows = CountSkills();
	if (Class'RIBase'.static.Has("Perks"))
		NumRows++;          // the General Perks row
	Sel = 0;
	PerkSel = -1;
	SelectRow(0);
}

function int CountSkills()
{
	local int n;

	n = 0;
	while ((n < 15) && (Skills().skillButtons[n] != None))
		n++;
	return n;
}

function bool IsGeneralRow(int i)
{
	return Class'RIBase'.static.Has("Perks") && (i == NumRows - 1);
}

function Skill SkillAt(int i)
{
	if ((i < 0) || (i >= NumRows - 1) || (Skills().skillButtons[i] == None))
		return None;
	return Skills().skillButtons[i].GetSkill();
}

function SelectRow(int i)
{
	i = Clamp(i, 0, NumRows - 1);
	if (i != Sel)
	{
		PlaySound(Sound'Menu_Focus', 0.2);
		DescAge = 0;
		PerkSel = -1;
		PerkScroll = 0;
		PerkScrollTarget = 0;
	}
	Sel = i;
	// Keep AE's selection in step, so its Upgrade acts on the same skill
	if (!IsGeneralRow(i) && (Skills().skillButtons[i] != None))
		Skills().SelectSkillButton(Skills().skillButtons[i]);
	GatherPerks();
}

function GatherPerks()
{
	local Object P;
	local int n;
	local class<Skill> SC;

	NumPerks = 0;
	if ((Player == None) || !Class'RIBase'.static.Has("Perks"))
		return;
	if (IsGeneralRow(Sel))
		SC = None;
	else if (SkillAt(Sel) != None)
		SC = SkillAt(Sel).Class;
	else
		return;
	for (n = 0; n < 32; n++)
	{
		P = Class'RIBase'.static.PerkFor(Player, SC, n);
		if (P == None)
			break;
		if (Class'RIBase'.static.PerkVisible(P))
			Perks[NumPerks++] = P;
	}
	if (PerkSel >= NumPerks)
		PerkSel = NumPerks - 1;
}

// Sections: Skills, and General perks as its own page (A / D or the header)
function int CurrentSub()
{
	if (IsGeneralRow(Sel))
		return TAB_PERKS;
	return TAB_SKILLS;
}

function bool LocalSub(int Id)
{
	if ((Id == TAB_PERKS) && Class'RIBase'.static.Has("Perks"))
	{
		LastSkill = Sel;
		SelectRow(NumRows - 1);
		if (NumPerks > 0)
			PerkSel = 0;
		return True;
	}
	if (Id == TAB_SKILLS)
	{
		SelectRow(Clamp(LastSkill, 0, NumRows - 1 - int(Class'RIBase'.static.Has("Perks"))));
		return True;
	}
	return False;
}

function bool CanUpgrade()
{
	local Skill Sk;

	Sk = SkillAt(Sel);
	return (Sk != None) && (Sk.CurrentLevel < 3) && (Player.SkillPointsAvail >= Sk.GetCost());
}

function DoUpgrade()
{
	if (IsGeneralRow(Sel))
		return;
	if (!CanUpgrade())
	{
		PointsFlash = 1.0;
		PlaySound(Sound'Menu_Cancel', 0.25);
		return;
	}
	Skills().UpgradeSkill();
	GatherPerks();
}

function bool CanBuy(int k)
{
	return (k >= 0) && (k < NumPerks) && Class'RIBase'.static.PerkBuyable(Perks[k]);
}

function DoBuy(int k)
{
	if ((k < 0) || (k >= NumPerks) || Class'RIBase'.static.PerkOwned(Perks[k]))
		return;
	if (!CanBuy(k))
	{
		PointsFlash = 1.0;
		PlaySound(Sound'Menu_Cancel', 0.25);
		return;
	}
	Class'RIBase'.static.PerkBuy(Player, Perks[k]);
	GatherPerks();
}

// GMDX perk text: the value is printed into the description
function string PerkText(Object P)
{
	return Class'RIBase'.static.PerkText(P);
}

// ----------------------------------------------------------------------
// Input
// ----------------------------------------------------------------------

function bool MouseOverPerks()
{
	return (LastMouseX >= PerkLeft) && (LastMouseX < PerkRight + 20 * S) && (LastMouseY >= PerkTop) && (LastMouseY < PerkBottom);
}

// Keep the selected perk card in view
function ShowPerk(int k)
{
	if ((k < 0) || (k >= NumPerks))
		return;
	if (PerkCardY[k] < PerkScrollTarget)
		PerkScrollTarget = PerkCardY[k];
	else if (PerkCardY[k] + PerkCardH[k] > PerkScrollTarget + (PerkBottom - PerkTop))
		PerkScrollTarget = PerkCardY[k] + PerkCardH[k] - (PerkBottom - PerkTop);
}

function bool PageKey(EInputKey key, bool bRepeat)
{
	if (((key == IK_MouseWheelUp) || (key == IK_MouseWheelDown)) && MouseOverPerks())
	{
		if (key == IK_MouseWheelUp)
			PerkScrollTarget -= 80 * S;
		else
			PerkScrollTarget += 80 * S;
		return True;
	}
	if (IsGeneralRow(Sel) && ((key == IK_Up) || (key == IK_Down) || (key == IK_MouseWheelUp) || (key == IK_MouseWheelDown)))
	{
		if (NumPerks > 0)
		{
			if ((key == IK_Down) || (key == IK_MouseWheelDown))
				PerkSel = Min(NumPerks - 1, PerkSel + 1);
			else
				PerkSel = Max(0, PerkSel - 1);
			PlaySound(Sound'Menu_Focus', 0.2);
		}
		return True;
	}
	if ((key == IK_Up) || (key == IK_MouseWheelUp))
	{
		SelectRow(Max(0, Sel - 1));
		return True;
	}
	if ((key == IK_Down) || (key == IK_MouseWheelDown))
	{
		SelectRow(Min(NumRows - 2, Sel + 1));
		return True;
	}
	if ((key == IK_Enter) && !bRepeat)
	{
		if (PerkSel >= 0)
			DoBuy(PerkSel);
		else
			DoUpgrade();
		return True;
	}
	if ((key == IK_Right) && (NumPerks > 0))
	{
		PerkSel = Min(NumPerks - 1, PerkSel + 1);
		ShowPerk(PerkSel);
		PlaySound(Sound'Menu_Focus', 0.2);
		return True;
	}
	if (key == IK_Left)
	{
		PerkSel = Max(-1, PerkSel - 1);
		ShowPerk(PerkSel);
		PlaySound(Sound'Menu_Focus', 0.2);
		return True;
	}
	return False;
}

function PageClick(int Id, EInputKey button, int numClicks)
{
	if (button != IK_LeftMouse)
		return;
	if (Id >= HOT_PERK)
	{
		if ((numClicks >= 2) && (PerkSel == Id - HOT_PERK))
			DoBuy(PerkSel);
		else
		{
			PerkSel = Id - HOT_PERK;
			PlaySound(Sound'Menu_Press', 0.2);
		}
	}
	else if (Id >= HOT_ROW)
	{
		if ((numClicks >= 2) && (Id - HOT_ROW == Sel))
			DoUpgrade();
		else
			SelectRow(Id - HOT_ROW);
	}
	else if (Id == HOT_UPGRADE)
		DoUpgrade();
	else if (Id == HOT_BUY)
		DoBuy(PerkSel);
}

function PageTick(float deltaSeconds)
{
	local float T;

	DescAge += deltaSeconds;
	PerkScrollTarget = FClamp(PerkScrollTarget, 0, FMax(0, PerkMax));
	PerkScroll += (PerkScrollTarget - PerkScroll) * FMin(1.0, deltaSeconds * 14.0);
	PointsFlash = FMax(0, PointsFlash - deltaSeconds * 1.6);
	LScroll += (LScrollTarget - LScroll) * FMin(1.0, deltaSeconds * 14.0);
	if (LPitch > 0)
		T = LTop + Sel * LPitch - LScroll;
	else if (VPlus())
		T = (180 * S) + 30 * S + Sel * 42 * S;
	else
		T = (240 * S) + 46 * S + Sel * 48 * S;
	if (SelY == 0)
		SelY = T;
	SelY += (T - SelY) * FMin(1.0, deltaSeconds * 16.0);
}

// ----------------------------------------------------------------------
// Drawing
// ----------------------------------------------------------------------

function DrawPage(GC gc, float a)
{
	local float x, y, w, tw;
	local string P;
	local Color PC;

	if (VPlus())
	{
		DrawList(gc, a);
		DrawDetail(gc, a * Class'RIUtil'.static.Phase(DescAge, 0.0, 0.2));
		return;
	}
	x = OX + 140 * S;
	y = 170 * S;
	Heading(gc, x, y, 0, SkillsTitle, a);

	// Skill points, right
	P = string(Player.SkillPointsAvail);
	w = FMax(120 * S, Class'RIText'.static.Width(Class'RIFontTitle', P, 0.42) + 30 * S);
	PC = Class'RIUtil'.static.Mix(AHi(a), ABad(a), PointsFlash);
	CGlow(gc, OX + 1780 * S - w - 16 * S, 166 * S - 10 * S, w + 32 * S, 38 * S + 20 * S, C3(40, 33, 14, a));
	Class'RISkin'.static.Box2(gc, OX + 1780 * S - w, 166 * S, w, 38 * S, PC);
	Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', OX + 1780 * S - w + Sin(PointsFlash * 30) * PointsFlash * 5 * S, 166 * S, w, 38 * S, P,
		Class'RIUtil'.static.Mix(C3(255, 255, 255, a), ABad(a), PointsFlash), 1, 0.42);
	tw = Class'RIText'.static.Width(Class'RIFontSmall', Caps(PointsLabel), 0.72);
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 1780 * S - w - 16 * S - tw, 166 * S, tw, 38 * S, Caps(PointsLabel), ALbl(a), 0, 0.72);

	Class'RIText'.static.HLine(gc, OX + 140 * S, 220 * S, 1640 * S, ADim(a));

	DrawList(gc, a);
	DrawDetail(gc, a * Class'RIUtil'.static.Phase(DescAge, 0.0, 0.2));

	Class'RIText'.static.Draw(gc, Class'RIFontSmall', OX + 140 * S, FY + FH + 22 * S, HintText, ALbl(a * 0.8), 0.7);
}

function DrawList(GC gc, float a)
{
	local int i, lv, pip;
	local float x, y, w, rh, nx, lx, cx, pw, ra;
	local Skill Sk;
	local bool bSel, bHot;
	local string Cost, LvName;
	local float pitch, ns, hs, lw, cw, bot, ph;
	local int st, k;

	x = OX + 140 * S;
	y = 240 * S;
	w = 1000 * S;
	rh = 46 * S;
	pitch = 48 * S;
	ns = 0.58;
	hs = 0.68;
	lw = 170 * S;
	cw = 200 * S;
	if (VPlus())
	{
		// inside the left frame
		x = OX + 402 * S;
		y = 180 * S;
		w = 574 * S;
		rh = 40 * S;
		pitch = 42 * S;
		ns = 0.46;
		hs = 0.54;
		lw = 100 * S;
		cw = 80 * S;
	}
	nx = x + 12 * S;
	lx = x + w * 0.5;
	cx = x + w - 12 * S;
	pw = 34 * S;
	if (VPlus())
		pw = 22 * S;

	if (IsGeneralRow(Sel))
	{
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', nx, y, Caps(PerkCol), ALbl(a), hs);
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', cx - 300 * S, y, 300 * S, 20 * S, Caps(StatusCol), ALbl(a), 2, hs);
	}
	else
	{
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', nx, y, Caps(SkillCol), ALbl(a), hs);
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', lx, y, Caps(LevelCol), ALbl(a), hs);
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', cx - 300 * S, y, 300 * S, 20 * S, Caps(CostCol), ALbl(a), 2, hs);
	}
	if (VPlus())
		Class'RIText'.static.HLine(gc, x, y + 24 * S, w, C3(126, 105, 50, a));

	if (VPlus())
		y += 30 * S;
	else
		y += 46 * S;
	LTop = y;
	LPitch = pitch;
	if (VPlus())
		bot = 936 * S;
	else
		bot = 975 * S;
	LScrollTarget = 0;
	st = gc.PushGC();
	gc.Intersect(x - 4 * S, LTop - 2 * S, w + 8 * S, bot - LTop + 4 * S);
	if (!IsGeneralRow(Sel))
		SelRow(gc, x, SelY, w, rh, a);
	y = LTop - LScroll;
	for (i = 0; i < NumRows - 1; i++)
	{
		if (IsGeneralRow(Sel))
			break;
		ra = a * Class'RIUtil'.static.Phase(Age, 0.08 + i * 0.02, 0.25);
		bSel = (i == Sel);
		bHot = (HoverId == HOT_ROW + i);
		if (bHot && !bSel)
			Glow(gc, x, y, w, rh, C3(36, 30, 12, ra));
		if (!bSel)
			Class'RIText'.static.HLine(gc, x + 8 * S, y + rh, w - 16 * S, C3(60, 50, 24, ra));

		if (IsGeneralRow(i))
		{
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', nx + (1 - ra) * 10 * S, y, lx - nx, rh, Caps(GeneralLabel),
				Class'RIUtil'.static.Mix(AAcc(ra), C3(255, 255, 255, ra), int(bSel)), 0, ns);
		}
		else
		{
			Sk = SkillAt(i);
			if (Sk == None)
				continue;
			lv = Sk.CurrentLevel;
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', nx + (1 - ra) * 10 * S, y, lx - nx - 10 * S, rh,
				Caps(Class'RIText'.static.Fit(Class'RIFontHead', Sk.SkillName, lx - nx - 10 * S, ns)),
				Class'RIUtil'.static.Mix(C3(236, 214, 160, ra), C3(255, 255, 255, ra), int(bSel)), 0, ns);
			for (pip = 0; pip < 3; pip++)
			{
				if (pip < lv)
				{
					CGlow(gc, lx + pip * (pw + 6 * S) - 6 * S, y + rh * 0.5 - 10 * S, pw + 12 * S, 20 * S, C3(56, 46, 20, ra));
					Fill(gc, lx + pip * (pw + 6 * S), y + rh * 0.5 - 5 * S, pw, 10 * S, AAcc(ra));
				}
				else
					Class'RIText'.static.Box(gc, lx + pip * (pw + 6 * S), y + rh * 0.5 - 5 * S, pw, 10 * S, C3(126, 105, 50, ra));
			}
			LvName = LevelNames[Clamp(lv, 0, 3)];
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', lx + 3 * (pw + 6 * S) + 8 * S, y, lw, rh, Caps(LvName), ALbl(ra), 0, hs);
			if (lv >= 3)
				Cost = "-";
			else
				Cost = string(Sk.GetCost());
			if ((lv < 3) && (Player.SkillPointsAvail < Sk.GetCost()))
				Class'RIText'.static.DrawIn(gc, Class'RIFontHead', cx - cw, y, cw, rh, Cost, ABad(ra), 2, ns);
			else
				Class'RIText'.static.DrawIn(gc, Class'RIFontHead', cx - cw, y, cw, rh, Cost, AAcc(ra), 2, ns);
		}
		if ((y + rh > LTop) && (y < bot))
			AddHot(HOT_ROW + i, x, FMax(y, LTop), w, FMin(y + rh, bot) - FMax(y, LTop));
		y += pitch;
	}

	// General perks page: the perks as rows, like the skills
	if (IsGeneralRow(Sel))
	{
		for (k = 0; k < NumPerks; k++)
		{
			bSel = (k == PerkSel);
			bHot = (HoverId == HOT_PERK + k);
			if (bSel)
				SelRow(gc, x, y, w, rh, a);
			else
			{
				if (bHot)
					Glow(gc, x, y, w, rh, C3(36, 30, 12, a));
				Class'RIText'.static.HLine(gc, x + 8 * S, y + rh, w - 16 * S, C3(60, 50, 24, a));
			}
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', nx, y, w * 0.58, rh,
				Caps(Class'RIText'.static.Fit(Class'RIFontHead', Class'RIBase'.static.PerkName(Perks[k]), w * 0.58, ns)),
				Class'RIUtil'.static.Mix(C3(236, 214, 160, a), C3(255, 255, 255, a), int(bSel)), 0, ns);
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x + w * 0.58, y, cx - x - w * 0.58, rh,
				Caps(PerkStateText(k)), PerkStateColor(k, a), 2, hs);
			if ((y + rh > LTop) && (y < bot))
				AddHot(HOT_PERK + k, x, FMax(y, LTop), w, FMin(y + rh, bot) - FMax(y, LTop));
			y += pitch;
		}
		if (NumPerks == 0)
			Class'RIText'.static.DrawIn(gc, Class'RIFontBody', nx, y, w, rh, "-", ALbl(a), 0, 0.8);
	}
	gc.PopGC(st);
}

// Owned / available (cost) / locked or what it needs
function string PerkStateText(int k)
{
	if (Class'RIBase'.static.PerkOwned(Perks[k]))
		return OwnedLabel;
	if (Class'RIBase'.static.PerkBuyable(Perks[k]))
		return AvailableLabel @ "-" @ string(Class'RIBase'.static.PerkCost(Perks[k]));
	if (Class'RIBase'.static.PerkNeedsSkill(Player, Perks[k]))
		return NeedsLabel @ LevelNames[Clamp(Class'RIBase'.static.PerkLevel(Perks[k]), 0, 3)];
	return LockedLabel @ "-" @ string(Class'RIBase'.static.PerkCost(Perks[k]));
}

function Color PerkStateColor(int k, float a)
{
	if (Class'RIBase'.static.PerkOwned(Perks[k]))
		return AGood(a);
	if (Class'RIBase'.static.PerkBuyable(Perks[k]))
		return AAcc(a);
	return C3(150, 132, 92, a);
}

function DrawDetail(GC gc, float a)
{
	local float x, y, w, h, top, bottom, cardH, st;
	local int k, p;
	local Skill Sk;
	local string T, D, StateTxt;
	local Color SC;
	local bool bSel, bHot;

	if (VPlus())
	{
		// the right frame's body; perks stop at its bottom (650)
		x = OX + 1072 * S;
		w = 446 * S;
		y = 222 * S;
		bottom = 740 * S;
	}
	else
	{
		x = OX + 1180 * S;
		y = 240 * S;
		w = 600 * S;
		h = 700 * S;
		Panel(gc, x, y, w, h, a);
		bottom = y + h;
		x += 26 * S;
		w -= 52 * S;
		y += 24 * S;
	}

	// Title and description
	if (IsGeneralRow(Sel))
	{
		T = GeneralLabel;
		D = GeneralDesc;
		if ((PerkSel >= 0) && (PerkSel < NumPerks))
		{
			T = Class'RIBase'.static.PerkName(Perks[PerkSel]);
			D = PerkText(Perks[PerkSel]);
		}
	}
	else
	{
		Sk = SkillAt(Sel);
		if (Sk == None)
			return;
		T = Sk.SkillName;
		D = Class'RIBase'.static.SkillDesc(Sk, Class'RIUtil'.static.PBool(Player, "bHardCoreMode"), Player.CombatDifficulty);
		p = InStr(D, "|n");
		if (p >= 0)
			D = Left(D, p);
	}
	if (VPlus())
	{
		// name in the title bar, a shorter description in the body
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x, 177 * S, w, 28 * S, Caps(Class'RIText'.static.Fit(Class'RIFontHead', T, w, 0.5)), ATxt(a), 0, 0.5);
		y += Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x, y, w, D, C3(230, 210, 165, a), 0.68, 1.34) + 10 * S;
	}
	else
	{
		Class'RIText'.static.Draw(gc, Class'RIFontTitle', x + (1 - a) * 8 * S, y, Caps(Class'RIText'.static.Fit(Class'RIFontTitle', T, w, 0.44)), ATxt(a), 0.44);
		y += 46 * S;
		y += Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x, y, w, D, C3(230, 210, 165, a), 0.8, 1.4) + 14 * S;
	}

	// General perks: the list is on the left; here the chosen perk's status
	if (IsGeneralRow(Sel))
	{
		if ((PerkSel >= 0) && (PerkSel < NumPerks))
			Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y + 6 * S, Caps(PerkStateText(PerkSel)), PerkStateColor(PerkSel, a), 0.64);
		else
			Class'RIText'.static.Draw(gc, Class'RIFontBody', x, y + 6 * S, "Pick a perk in the list on the left.", ALbl(a), 0.72);
		if (VPlus())
		{
			DrawVPActions(gc, a);
			return;
		}
		if ((PerkSel >= 0) && (PerkSel < NumPerks))
		{
			DrawBtn(gc, x + w - 220 * S, bottom - 74 * S, 220 * S, 50 * S, BuyLabel, CanBuy(PerkSel), HoverId == HOT_BUY, CanBuy(PerkSel), a);
			AddHot(HOT_BUY, x + w - 220 * S, bottom - 74 * S, 220 * S, 50 * S);
		}
		return;
	}

	// Perks (base feature)
	if (Class'RIBase'.static.Has("Perks"))
	{
	// Perks
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, Caps(PerksLabel), AAcc(a), 0.72);
		y += 30 * S;
		top = y;
		PerkTop = top;
		PerkBottom = bottom - 90 * S;
		PerkLeft = x;
		PerkRight = x + w;
		st = gc.PushGC();
		gc.Intersect(x - 4 * S, top, w + 8 * S, PerkBottom - top);
		y = top - PerkScroll;
		for (k = 0; k < NumPerks; k++)
		{
			bSel = (k == PerkSel);
			bHot = (HoverId == HOT_PERK + k);
			D = PerkText(Perks[k]);
			cardH = 46 * S + Class'RIText'.static.DrawWrapped(None, Class'RIFontBody', 0, 0, w - 28 * S, D, C3(0, 0, 0, 0), 0.72, 1.35);
	
			if (Class'RIBase'.static.PerkOwned(Perks[k]))
			{
				StateTxt = OwnedLabel;
				SC = AGood(a);
			}
			else if (Class'RIBase'.static.PerkBuyable(Perks[k]))
			{
				StateTxt = AvailableLabel @ "-" @ string(Class'RIBase'.static.PerkCost(Perks[k]));
				SC = AAcc(a);
			}
			else
			{
				StateTxt = LockedLabel;
				SC = C3(150, 132, 92, a);
				if (Class'RIBase'.static.PerkNeedsSkill(Player, Perks[k]))
					StateTxt = NeedsLabel @ LevelNames[Clamp(Class'RIBase'.static.PerkLevel(Perks[k]), 0, 3)];
				else
					StateTxt = LockedLabel @ "-" @ string(Class'RIBase'.static.PerkCost(Perks[k]));
			}
	
			Fill(gc, x, y, w, cardH, C3(30, 25, 11, 0.6 * a));
			if (bSel)
				SelRow(gc, x, y, w, cardH, a);
			else if (bHot)
				Class'RIText'.static.Box(gc, x, y, w, cardH, AEdge(a));
			else
				Class'RIText'.static.Box(gc, x, y, w, cardH, C3(90, 75, 36, a));
			Class'RIText'.static.Draw(gc, Class'RIFontHead', x + 14 * S, y + 10 * S,
				Caps(Class'RIText'.static.Fit(Class'RIFontHead', Class'RIBase'.static.PerkName(Perks[k]), w * 0.58, 0.5)), ATxt(a), 0.5);
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x + w * 0.5, y + 8 * S, w * 0.5 - 14 * S, 24 * S, Caps(StateTxt), SC, 2, 0.62);
			Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x + 14 * S, y + 38 * S, w - 28 * S, D, C3(220, 200, 155, a), 0.72, 1.35);
			PerkCardY[k] = y + PerkScroll - top;
			PerkCardH[k] = cardH;
			if ((y + cardH > top) && (y < PerkBottom))
				AddHot(HOT_PERK + k, x, FMax(y, top), w, FMin(y + cardH, PerkBottom) - FMax(y, top));
			y += cardH + 10 * S;
		}
		PerkMax = (y + PerkScroll - top) - (PerkBottom - top);
		if (NumPerks == 0)
			Class'RIText'.static.Draw(gc, Class'RIFontBody', x, top, "-", ALbl(a), 0.8);
		gc.PopGC(st);
	
		// Scroll bar when the perks overflow
		if (PerkMax > 1)
		{
			h = PerkBottom - top;
			Fill(gc, x + w + 10 * S, top, 2 * S, h, C3(50, 42, 20, a));
			Fill(gc, x + w + 10 * S, top + (h - FMax(30 * S, h * h / (h + PerkMax))) * (PerkScroll / PerkMax), 2 * S,
				FMax(30 * S, h * h / (h + PerkMax)), AAcc(a));
		}
	
	}

	if (VPlus())
	{
		DrawVPActions(gc, a);
		return;
	}

	// Actions
	y = bottom - 74 * S;
	if ((PerkSel >= 0) && (PerkSel < NumPerks))
	{
		DrawBtn(gc, x + w - 220 * S, y, 220 * S, 50 * S, BuyLabel, CanBuy(PerkSel), HoverId == HOT_BUY, CanBuy(PerkSel), a);
		AddHot(HOT_BUY, x + w - 220 * S, y, 220 * S, 50 * S);
	}
	if (!IsGeneralRow(Sel))
	{
		if ((SkillAt(Sel) != None) && (SkillAt(Sel).CurrentLevel >= 3))
			DrawBtn(gc, x, y, 240 * S, 50 * S, MasteredLabel, False, False, False, a);
		else
		{
			DrawBtn(gc, x, y, 240 * S, 50 * S, UpgradeLabel, CanUpgrade(), HoverId == HOT_UPGRADE, CanUpgrade() && (PerkSel < 0), a);
			AddHot(HOT_UPGRADE, x, y, 240 * S, 50 * S);
		}
	}
}

// Vanilla+: skill points in the footer bar; the skill's icon and the
// actions in the lower box
function DrawVPActions(GC gc, float a)
{
	local Skill Sk;
	local Color PC;

	PC = Class'RIUtil'.static.Mix(ATxt(a), ABad(a), PointsFlash);
	Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 1072 * S, 670 * S, 200 * S, 30 * S, Caps(PointsLabel), ALbl(a), 0, 0.54);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', OX + 1072 * S, 670 * S, 458 * S, 30 * S, string(Player.SkillPointsAvail), PC, 2, 0.5);

	Sk = None;
	if (!IsGeneralRow(Sel))
		Sk = SkillAt(Sel);
	if ((Sk != None) && (Sk.SkillIcon != None))
	{
		gc.SetStyle(DSTY_Masked);
		gc.SetTileColor(C3(255, 255, 255, a));
		Class'RIHD'.static.DrawStretched(gc, OX + 1080 * S, 768 * S, 72 * S, 72 * S, 0, 0, Sk.SkillIcon.USize, Sk.SkillIcon.VSize, Sk.SkillIcon);
	}
	// right of the icon: the skill and what the next level costs, then the
	// board's own button across the box (Buy beside it for a chosen perk)
	if (Sk != None)
	{
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 1180 * S, 760 * S, 346 * S, 26 * S,
			Caps(Class'RIText'.static.Fit(Class'RIFontSmall', Sk.SkillName, 220 * S, 0.54)), ATxt(a), 0, 0.54);
		if (Sk.CurrentLevel >= 3)
		{
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 1180 * S, 760 * S, 346 * S, 26 * S, Caps(MasteredLabel), AHi(a), 2, 0.54);
			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', OX + 1180 * S, 800 * S, 346 * S, 36 * S, Caps(MasteredLabel), ALbl(a), 1, 0.42);
		}
		else
		{
			if (Player.SkillPointsAvail >= Sk.GetCost())
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 1180 * S, 760 * S, 346 * S, 26 * S, string(Sk.GetCost()), AHi(a), 2, 0.54);
			else
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', OX + 1180 * S, 760 * S, 346 * S, 26 * S, string(Sk.GetCost()), ABad(a), 2, 0.54);
			if ((PerkSel >= 0) && (PerkSel < NumPerks))
				SkBtn(gc, 1178, 800, 170, UpgradeLabel, CanUpgrade(), HOT_UPGRADE, a);
			else
				SkBtn(gc, 1178, 800, 350, UpgradeLabel, CanUpgrade(), HOT_UPGRADE, a);
		}
	}
	if ((PerkSel >= 0) && (PerkSel < NumPerks))
		SkBtn(gc, 1358, 800, 170, BuyLabel, CanBuy(PerkSel), HOT_BUY, a);
}

// One of the board's buttons (the Inventory's frame), in design pixels; the
// label lit on hover, faint when it can't be used. Always clickable, so a
// click without the points still flashes the points.
function SkBtn(GC gc, float X, float Y, float W, string L, bool bLive, int Id, float a)
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
	VPBtnK(gc, X, Y, W, 36, bHot, a);
	Class'RIText'.static.DrawIn(gc, Class'RIFontHead', OX + X * S, Y * S, W * S - 10 * S, 36 * S,
		Caps(Class'RIText'.static.Fit(Class'RIFontHead', L, W * S - 20 * S, 0.42)), C, 1, 0.42);
	AddHot(Id, OX + X * S, Y * S, W * S, 36 * S);
}

defaultproperties
{
     SkillsTitle="Skills"
     PointsLabel="Skill points"
     SkillCol="Skill"
     LevelCol="Level"
     CostCol="To upgrade"
     PerksLabel="Perks"
     GeneralLabel="General perks"
     PerkCol="Perk"
     StatusCol="Status"
     GeneralDesc="Perks that don't belong to any one skill."
     OwnedLabel="Owned"
     AvailableLabel="Available"
     LockedLabel="Locked"
     NeedsLabel="Needs"
     UpgradeLabel="Upgrade"
     BuyLabel="Buy perk"
     MasteredLabel="Mastered"
     LevelNames(0)="Untrained"
     LevelNames(1)="Trained"
     LevelNames(2)="Advanced"
     LevelNames(3)="Master"
     HintText="UP / DOWN select     LEFT / RIGHT perk     A / D skills or general perks     ENTER upgrade or buy     ESC close"
     bHideScreen=True
}
