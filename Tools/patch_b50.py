import os
os.chdir(os.path.expanduser("~/mnt/Deus Ex/Mods/ReimaginedUI/Source/ReimaginedUI/Classes"))

def rd(p): return open(p, encoding='latin-1').read()
def wr(p, s): open(p, 'w', encoding='latin-1').write(s)
def rep(s, a, b):
    assert a in s, a[:90]
    return s.replace(a, b, 1)

s = rd('RIPersonaView.uc')

# ---- section row: a box round the chosen section that fades in (no glow)
s = rep(s, "var float ScaleAge;", "var float ScaleAge;\nvar int   SubShown;          // section the fade below belongs to\nvar float SubShownAt;        // when it was chosen (Age)")
s = rep(s, """			// a soft glow centred on the label, brightest in the middle and
			// fading out on every side, with a short bar centred under it
			CGlow(gc, x + tw * 0.5 - (tw + 56 * S) * 0.5, y + 1 * S, tw + 56 * S, h - 2 * S, C3(88, 73, 33, a));
			CGlow(gc, x + tw * 0.5 - (tw + 20 * S) * 0.5, y + 7 * S, tw + 20 * S, h - 14 * S, C3(52, 43, 19, a));
			Fill(gc, x + tw * 0.5 - tw * 0.3, y + h - 7 * S, tw * 0.6, 2 * S, AHi(a));
			C = AHi(a);""", """			// a box round the section, fading in once it's chosen
			if (SubShown != cur)
			{
				SubShown = cur;
				SubShownAt = Age;
			}
			k = Class'RIUtil'.static.EaseOut(FClamp((Age - SubShownAt) / 0.3, 0, 1));
			Fill(gc, sx + 3 * S, y + 5 * S, ex - sx - 6 * S, h - 10 * S, C3(52, 43, 19, a * k));
			Class'RIText'.static.Box(gc, sx + 3 * S, y + 5 * S, ex - sx - 6 * S, h - 10 * S, C3(242, 211, 107, a * k));
			C = AHi(a);""")
s = rep(s, """function DrawVPSubRow(GC gc, float x, float y, float h, float sc, float gap, int cur, float a)
{
	local int i;
	local float tw, sx, ex;""", """function DrawVPSubRow(GC gc, float x, float y, float h, float sc, float gap, int cur, float a)
{
	local int i;
	local float tw, sx, ex, k;""")

# ---- selection highlight: a clean lit box (the original's double frame read as a white block)
i = s.index("function VSelRow(GC gc, float X, float Y, float W, float H, float a)")
j = s.index("\n}\n", i) + 3
s = s[:i] + """function VSelRow(GC gc, float X, float Y, float W, float H, float a)
{
	Fill(gc, X, Y, W, H, C3(56, 46, 20, 0.85 * a));
	Glow(gc, X, Y, W, H * 0.6, C3(30, 25, 11, a));
	Class'RIText'.static.Box(gc, X, Y, W, H, C3(242, 211, 107, a));
}
""" + s[j:]

# ---- belt: end to end with the boxes above (380 .. 1562), ten even slots
s = rep(s, "// Opaque black (RI_Clear drawn solid)", """// The Inventory board's belt slots (design px): 10 across 403 .. 1539
static function float BeltSlotX(int i) { return 403 + i * 114.8; }
static function float BeltSlotW() { return 102.8; }

// Opaque black (RI_Clear drawn solid)""")
s = rep(s, "		VPFrame(gc, 518, 900, 1054, 118, a);", "		VPFrame(gc, 380, 900, 1182, 118, a);")
s = rep(s, """			VPInset(gc, 541 + i * 102, 912, 90, 94, a);
			Class'RIText'.static.HLine(gc, OX + (541 + i * 102) * S, (912 + 72) * S, 90 * S, ADim(a));""",
"""			VPInset(gc, BeltSlotX(i), 912, BeltSlotW(), 94, a);
			Class'RIText'.static.HLine(gc, OX + BeltSlotX(i) * S, (912 + 72) * S, BeltSlotW() * S, ADim(a));""")
s = rep(s, "	w = 90 * S;\n	ih = 94 * S;\n	y = 912 * S;", "	w = BeltSlotW() * S;\n	ih = 94 * S;\n	y = 912 * S;")
s = rep(s, "OX + (541 + n * 102 + 6) * S, y + 4 * S, Mid(\"1234567890\", n, 1)", "OX + (BeltSlotX(n) + 6) * S, y + 4 * S, Mid(\"1234567890\", n, 1)")
s = rep(s, "		sx = OX + (541 + I.beltPos * 102) * S;", "		sx = OX + BeltSlotX(I.beltPos) * S;")
wr('RIPersonaView.uc', s)

s = rd('RIInventoryView.uc')
s = rep(s, """		pitch = 102 * S;
		w = 94 * S;
		bx0 = OX + 539 * S;""", """		pitch = 114.8 * S;
		w = (BeltSlotW() + 4) * S;
		bx0 = OX + (BeltSlotX(0) - 2) * S;""")
# belt selection: the lit box fades in when chosen; hover is a faint box
s = rep(s, """		else if ((I != None) && (I == SelItem))
			SelRow(gc, sx + 2, y, w - 4, ih, a);
		else if (bHot && (I != None))
			Class'RIText'.static.Box(gc, sx + 2, y, w - 4, ih, AHi(a));""", """		else if ((I != None) && (I == SelItem))
			SelRow(gc, sx + 2, y, w - 4, ih, a * Class'RIUtil'.static.EaseOut(FClamp(DescAge / 0.25, 0, 1)));
		else if (bHot && (I != None))
			Class'RIText'.static.Box(gc, sx + 2, y, w - 4, ih, C3(150, 126, 62, a));""")
wr('RIInventoryView.uc', s)
print("ok")
