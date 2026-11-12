import os
os.chdir(os.path.expanduser("~/mnt/Deus Ex/Mods/ReimaginedUI/Source/ReimaginedUI/Classes"))

def rd(p): return open(p, encoding='latin-1').read()
def wr(p, s): open(p, 'w', encoding='latin-1').write(s)
def rep(s, a, b):
    assert a in s, a[:90]
    return s.replace(a, b, 1)

s = rd('RIHud.uc')
i = s.index("function DrawVPAugs(GC gc)")
j = s.index("// Belt in the board's ten slots")
s = s[:i] + '''function DrawVPAugs(GC gc)
{
	local Augmentation Aug;
	local Inventory I;
	local ChargedPickup CP;
	local int n, k;
	local float step, x, y, c, top;

	n = 0;
	if (Player.AugmentationSystem != None)
		for (Aug = Player.AugmentationSystem.FirstAug; Aug != None; Aug = Aug.next)
			if (Aug.CanBeActivated() && (Player.bHUDShowAllAugs || Aug.bIsActive))
				n++;
	for (I = Player.Inventory; I != None; I = I.Inventory)
		if ((ChargedPickup(I) != None) && ChargedPickup(I).bIsActive)
			n++;
	if (n == 0)
		return;

	// lower left: a column rising from the bottom, on a thin spine
	c = 44 * S;
	step = FMin(58, 560.0 / n) * S;
	x = LX(52);
	y = BY(1030) - c;
	top = y - (n - 1) * step;
	Class'RIText'.static.VLine(gc, x - 14 * S, top + c * 0.5, y - top, C3(110, 92, 44));
	Fill(gc, x - 17 * S, top + c * 0.5 - 0.5 * S, 7 * S, 1.5 * S, C3(160, 135, 70));
	Fill(gc, x - 17 * S, y + c * 0.5 - 0.5 * S, 7 * S, 1.5 * S, C3(160, 135, 70));

	k = 0;
	if (Player.AugmentationSystem != None)
		for (Aug = Player.AugmentationSystem.FirstAug; Aug != None; Aug = Aug.next)
		{
			if (!Aug.CanBeActivated() || (!Player.bHUDShowAllAugs && !Aug.bIsActive))
				continue;
			VPAugCell(gc, x, y - k * step, c, AugIcon(Aug), Aug.bIsActive, HotKey(Aug.HotKeyNum), -1, Aug.GetAugColor(True));
			k++;
		}
	for (I = Player.Inventory; I != None; I = I.Inventory)
	{
		CP = ChargedPickup(I);
		if ((CP == None) || !CP.bIsActive)
			continue;
		VPAugCell(gc, x, y - k * step, c, CP.ChargedIcon, True, "", FClamp(CP.GetCurrentCharge() / 100.0, 0, 1), C3(255, 255, 255));
		k++;
	}
}

// One aug: no box. Active: a soft glow behind the icon, a notch lit on the
// spine and a short bar under it; idle: the icon dimmed. Key to the right.
function VPAugCell(GC gc, float X, float Y, float C, Texture Icon, bool bOn, string Key, float Charge, Color Tint)
{
	if (bOn)
	{
		CGlow(gc, X - C * 0.45, Y - C * 0.3, C * 1.9, C * 1.6, C3(70, 58, 26));
		Fill(gc, X - 14 * S, Y + C * 0.5 - 4 * S, 3 * S, 8 * S, C3(242, 211, 107));
		Fill(gc, X + C * 0.2, Y + C + 2 * S, C * 0.6, 1.5 * S, C3(242, 211, 107));
	}
	else
		Fill(gc, X - 15 * S, Y + C * 0.5 - 0.5 * S, 5 * S, 1 * S, C3(110, 92, 44));
	if (Icon != None)
	{
		gc.SetStyle(DSTY_Masked);
		if (bOn)
			gc.SetTileColor(Tint);
		else
			gc.SetTileColor(Class'RIUtil'.static.Mix(C3(0, 0, 0), Tint, 0.45));
		Class'RIHD'.static.DrawStretched(gc, X + 4 * S, Y + 4 * S, C - 8 * S, C - 8 * S, 0, 0, Icon.USize, Icon.VSize, Icon);
	}
	if (Charge >= 0)
	{
		Fill(gc, X + 4 * S, Y + C + 2 * S, C - 8 * S, 2 * S, C3(40, 33, 15));
		Fill(gc, X + 4 * S, Y + C + 2 * S, (C - 8 * S) * Charge, 2 * S, C3(242, 211, 107));
	}
	if (Key != "")
	{
		if (bOn)
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X + C + 10 * S, Y + (C - 16 * S) * 0.5, 40 * S, 16 * S, Key, C3(255, 241, 194), 0, 0.5);
		else
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', X + C + 10 * S, Y + (C - 16 * S) * 0.5, 40 * S, 16 * S, Key, C3(140, 118, 66), 0, 0.5);
	}
}

''' + s[j:]
# Received toast no longer has a rail to dodge on the right
s = rep(s, """	if (Class'RIVP'.static.On() && Player.bAugDisplayVisible)
		RX = width - 184 * S;     // clear of the aug rail (160 wide at the right edge)
""", "")
wr('RIHud.uc', s)
print("ok")
