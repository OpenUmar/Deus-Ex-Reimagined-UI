import os
os.chdir(os.path.expanduser("~/mnt/Deus Ex/Mods/ReimaginedUI/Source/ReimaginedUI/Classes"))

def rd(p): return open(p, encoding='latin-1').read()
def wr(p, s): open(p, 'w', encoding='latin-1').write(s)
def rep(s, a, b):
    assert a in s, a[:90]
    return s.replace(a, b, 1)

s = rd('RIInventoryView.uc')

# ---- vars
s = rep(s, "var int    StatCol;", "var string InfoDesc;      // Sleek: the description, drawn at the top (AE's copy is skipped)\nvar bool   bStatsHead;    // Sleek: the STATS heading is drawn\nvar int    StatCol;")

# ---- stats really fill two columns: a heading closes the row, a plain row doesn't
s = rep(s, """function float FlushHead(GC gc, float X, float y, float W, float da)
{
	y = CloseStat(y);
	if (PendHead == "")
		return y;""", """function float FlushHead(GC gc, float X, float y, float W, float da)
{
	if (PendHead == "")
		return y;
	y = CloseStat(y);""")

# section heading in the mockup's style: label, rule to the right, a hint at the end
s = rep(s, """	y += 6 * S;
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', X, y, Caps(PendHead), AAcc(da), 0.56);
	Class'RIText'.static.HLine(gc, X, y + 20 * S, W - 12 * S, ADim(da));
	PendHead = "";
	return y + 26 * S;""", """	y += 14 * S;
	SectionHead(gc, X, y, W, PendHead, "", da);
	PendHead = "";
	return y + 30 * S;""")

s = rep(s, "function bool InView(float y, float h)", """// AMMO ---------------------- CLICK TO LOAD
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

function bool InView(float y, float h)""")

# ---- ammo tiles: the mockup's 142 x 52 chips (icon, name, rounds) under an AMMO heading with the hint
s = rep(s, """			if (AmmoRowX < 0)
				y = FlushHead(gc, X, y, W, da);
			if ((AmmoRowX < 0) || (AmmoRowX + 120 * S > X + W))
			{
				if (AmmoRowX >= 0)
					y += 66 * S;
				AmmoRowX = X;
			}
			ax = AmmoRowX;
			bOn = AB.bSelected || AB.bLoaded;
			Fill(gc, ax, y, 112 * S, 58 * S, C3(20, 16, 7, 0.7 * da));
			if (bOn)
				Class'RIText'.static.Box(gc, ax, y, 112 * S, 58 * S, AAcc(da));
			else
				Class'RIText'.static.Box(gc, ax, y, 112 * S, 58 * S, ADim(da));""", """			if ((AmmoRowX < 0) && !VPlus() && (PendHead != ""))
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
			}""")
s = rep(s, """					Class'RIHD'.static.DrawStretched(gc, ax + 6 * S, y + 4 * S, 42 * S, 37 * S, 0, 0, Ic.USize, Ic.VSize, Ic);
				}
				T = Class<DeusExAmmo>(AB.ammo).default.beltDescription;
				if (T == "")
					T = AB.ammo.default.ItemName;
				Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', ax + 50 * S, y + 4 * S, 58 * S, 18 * S, Caps(Class'RIText'.static.Fit(Class'RIFontSmall', T, 58 * S, 0.44)), ATxt(da), 0, 0.44);
				Class'RIText'.static.DrawIn(gc, Class'RIFontHead', ax + 50 * S, y + 22 * S, 58 * S, 30 * S, string(AB.rounds), AAcc(da), 0, 0.5);
			}
			if ((NumInfoWins < 48) && InView(y, 58 * S))
			{
				InfoWins[NumInfoWins] = C;
				AddHot(HOT_INFO + NumInfoWins, ax, FMax(y, InfoTop), 112 * S, FMin(y + 58 * S, InfoBottom) - FMax(y, InfoTop));
				NumInfoWins++;
			}
			AmmoRowX = ax + 120 * S;""", """					Class'RIHD'.static.DrawStretched(gc, ax + 8 * S, y + 7 * S, 43 * S, 38 * S, 0, 0, FMin(42, Ic.USize), FMin(37, Ic.VSize), Ic);
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
			AmmoRowX = ax + 152 * S;""")
s = rep(s, """function float EndRows(float y)
{
	if (AmmoRowX >= 0)
		y += 66 * S;""", """function float EndRows(float y)
{
	if (AmmoRowX >= 0)
		y += 62 * S;""")

# ---- Sleek stat rows: the mockup's spec sheet
old_start = "			// Sleek spec sheet: two columns, label left, value right-aligned\n			if (!VPlus())\n			{"
i = s.index(old_start)
j = s.index("				continue;\n			}\n			lw = W * 0.38;", i)
s = s[:i] + """			// Sleek spec sheet: two columns, small label left, value right
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
""" + s[j:]
s = rep(s, "function float CloseStat(float y)\n{\n	if (StatCol == 1)\n	{\n		StatCol = 0;\n		return y + 30 * S;",
        "function float CloseStat(float y)\n{\n	if (StatCol == 1)\n	{\n		StatCol = 0;\n		return y + 34 * S;")
s = rep(s, "	local float lw, th, bw, ax;\n	local Texture Ic;", "	local float lw, th, bw, ax;\n	local string Bn;\n	local Texture Ic;")

# AE's own copy of the description is skipped in Sleek (it's drawn at the top)
s = rep(s, """			y = CloseStat(y);
			PendHead = "";
			y += 6 * S;
			// UNATCO / agency file notes get their own card""", """			y = CloseStat(y);
			if (!VPlus() && (InfoDesc != "") && (Class'RIConView'.static.Lines(T) == InfoDesc))
				continue;
			PendHead = "";
			y += 6 * S;
			// UNATCO / agency file notes get their own card""")

# DrawInfo: description first (Sleek), then AE's details
s = rep(s, """	AmmoRowX = -1;
	BtnRowX = -1;
	if ((Inv().winInfo != None) && (Inv().winInfo.winTile != None))""", """	AmmoRowX = -1;
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
	if ((Inv().winInfo != None) && (Inv().winInfo.winTile != None))""")
s = rep(s, """	if (y <= Top - InfoScroll + 1)
	{""", """	if ((y <= Top - InfoScroll + 1) && (InfoDesc == ""))
	{""")
# a quieter scroll bar
s = rep(s, """		Fill(gc, X + W - 3 * S, Top, 2 * S, Bottom - Top, C3(50, 42, 20, da));
		Fill(gc, X + W - 3 * S, Top + (Bottom - Top - th) * (InfoScroll / InfoMax), 2 * S, th, AAcc(da));""",
"""		Fill(gc, X + W - 2 * S, Top, 1 * S, Bottom - Top, C3(30, 25, 11, da));
		Fill(gc, X + W - 3 * S, Top + (Bottom - Top - th) * (InfoScroll / InfoMax), 3 * S, th, C3(126, 105, 50, da));""")

# header: Rotate and Decline chips on one line (Decline had dropped 10 px)
s = rep(s, "		DrawDeferredBtns(gc, HdrBtnX, HdrBtnY, HdrBtnW, da, True);", "		DrawDeferredBtns(gc, HdrBtnX, HdrBtnY - 10 * S, HdrBtnW, da, True);")

# ---- ammo / keys list: icon scaled with the screen so it never runs into the name
s = rep(s, "				Class'RIHD'.static.DrawStretched(gc, x + 14 * S, y + (rh - 37) * 0.5, 42, 37, 0, 0, 42, 37, Am.icon);",
        "				Class'RIHD'.static.DrawStretched(gc, x + 14 * S, y + (rh - 46 * S) * 0.5, 52 * S, 46 * S, 0, 0, 42, 37, Am.icon);")
s = rep(s, """			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x + 80 * S, y + 6 * S, w - 300 * S, 32 * S,
				Caps(Class'RIText'.static.Fit(Class'RIFontHead', Am.ItemName, w - 300 * S, 0.56)),""", """			Class'RIText'.static.DrawIn(gc, Class'RIFontHead', x + 84 * S, y + 6 * S, w - 304 * S, 32 * S,
				Caps(Class'RIText'.static.Fit(Class'RIFontHead', Am.ItemName, w - 304 * S, 0.56)),""")
s = rep(s, """			Fill(gc, x + 80 * S, y + rh - 18 * S, w - 300 * S, 5 * S, C3(40, 33, 15, a));
			Fill(gc, x + 80 * S, y + rh - 18 * S, (w - 300 * S) * f, 5 * S, AAcc(a));""", """			Fill(gc, x + 84 * S, y + rh - 18 * S, w - 304 * S, 5 * S, C3(40, 33, 15, a));
			Fill(gc, x + 84 * S, y + rh - 18 * S, (w - 304 * S) * f, 5 * S, AAcc(a));""")

s = rep(s, '     KindWeapon="Weapon"', '     StatsLabel="Stats"\n     ClickLoadLabel="Click to load"\n     KindWeapon="Weapon"')
s = rep(s, "var localized string InvTitle,", "var localized string StatsLabel, ClickLoadLabel;\nvar localized string InvTitle,")
wr('RIInventoryView.uc', s)

# ---- Outfit (Sleek): nothing tints the live preview
s = rd('RIOutfitView.uc')
s = rep(s, "	CGlow(gc, PVX - 60 * S, PVY - 30 * S, PVW + 120 * S, PVH + 60 * S, C3(26, 22, 10, a));\n", "")
wr('RIOutfitView.uc', s)
print("ok")
