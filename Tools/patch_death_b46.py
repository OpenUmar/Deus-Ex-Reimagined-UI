import os
os.chdir(os.path.expanduser("~/mnt/Deus Ex/Mods/ReimaginedUI/Source/ReimaginedUI/Classes"))

def rd(p): return open(p, encoding='latin-1').read()
def wr(p, s): open(p, 'w', encoding='latin-1').write(s)
def rep(s, a, b):
    assert a in s, a[:80]
    return s.replace(a, b, 1)

# ---- loading screens: truly opaque (FillC is additive, so the last frame,
#      e.g. the Eidos logo, showed through)
s = rd('RILoading.uc')
s = rep(s, "\tClass'RISkin'.static.FillC(gc, 0, 0, W, H, C(6, 5, 4));\n\tcy = H * 0.5;",
        "\tClass'RIVP'.static.Black(gc, 0, 0, W, H);\n\tClass'RISkin'.static.FillC(gc, 0, 0, W, H, C(6, 5, 4));\n\tcy = H * 0.5;")
s = rep(s, "\tClass'RISkin'.static.FillC(gc, 0, 0, W, H, C(8, 7, 5));\n\tcy = H * 0.5;",
        "\tClass'RIVP'.static.Black(gc, 0, 0, W, H);\n\tClass'RISkin'.static.FillC(gc, 0, 0, W, H, C(8, 7, 5));\n\tcy = H * 0.5;")
s = rep(s, "\tDarken(gc, W, H, 0.35, 0.6);\n\tx = 120 * S;",
        "\t// opaque: the engine doesn't redraw while loading, so the last frame\n"
        "\t// (whatever it was) would otherwise show through\n"
        "\tClass'RIVP'.static.Black(gc, 0, 0, W, H);\n"
        "\tClass'RISkin'.static.FillC(gc, 0, 0, W, H, C(8, 7, 5));\n\tx = 120 * S;")
wr('RILoading.uc', s)

# ---- death screen
s = rd('RIRootWindow.uc')
s = rep(s, "var float  DrawClock;",
        "var float  DeathLoadT;       // a choice was made on the death screen\n"
        "var localized string DeathTitle, DeathLoadLast, DeathLoadGame, DeathMainMenu, DeathWaitLabel;\n"
        "var float  DrawClock;")
s = rep(s, "\t\tClass'RILoading'.static.Draw(gc, DeusExPlayer(parentPawn), width, height, winCount, MapName(), DrawClock);\n\t}",
        "\t\tif (!Class'RILoading'.static.Draw(gc, DeusExPlayer(parentPawn), width, height, winCount, MapName(), DrawClock))\n"
        "\t\t\tDrawDeath(gc);\n\t}")

DEATH = r'''// ----------------------------------------------------------------------
// Death screen: comes up by itself a moment after dying (no key needed) and
// replaces AE's trip through the main menu, which crashed from here.
//   Enter  load the last save (GMDX's own quick load, which waits for the
//          death animation)    L  load game    Esc  main menu
// ----------------------------------------------------------------------

function float DeathTime()
{
	local DeusExPlayer P;

	P = DeusExPlayer(parentPawn);
	if ((P == None) || !P.IsInState('Dying') || bGoMainMenu || IsIntroMap())
		return -1;
	return P.Level.TimeSeconds - P.FrobTime;
}

function bool DeathUp()
{
	return (DeathTime() > 2.0) && (winCount <= 0);
}

function DeathKey(EInputKey key)
{
	local DeusExPlayer P;

	P = DeusExPlayer(parentPawn);
	if (DeathLoadT > 0)
		return;
	if ((key == IK_Enter) || (key == IK_Space))
	{
		DeathLoadT = 1;
		Log("RI: death screen - load last save");
		P.QuickLoad();
	}
	else if (key == IK_L)
	{
		Log("RI: death screen - load game");
		InvokeMenuScreen(Class'DeusEx.MenuScreenLoadGame');
	}
	else if (key == IK_Escape)
	{
		DeathLoadT = 1;
		Log("RI: death screen - main menu");
		RequestMainMenu();
	}
}

function DrawDeath(GC gc)
{
	local float t, a, S, cy, y, w, kw;
	local DeusExLevelInfo Info;
	local string Loc, K, L;
	local int i;

	t = DeathTime();
	if (t < 0)
		DeathLoadT = 0;
	if ((t < 2.0) || (winCount > 0))
		return;
	a = FClamp((t - 2.0) / 0.8, 0, 1);
	S = height / 1080.0;
	cy = height * 0.42;
	Class'RITheme'.static.SetMode(2);
	Class'RISkin'.static.DrawDim(gc, 0, 0, width, height, 0.55 * a);
	Class'RISkin'.static.DrawDim(gc, 0, cy - 140 * S, width, 340 * S, 0.35 * a);

	Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', 0, cy - 110 * S, width, 60 * S, DeathTitle, Class'RIUtil'.static.Col(255 * a, 241 * a, 194 * a), 1, 0.95);
	Info = DeusExPlayer(parentPawn).GetLevelInfo();
	if (Info != None)
		Loc = Info.MissionLocation;
	if (Loc != "")
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', 0, cy - 46 * S, width, 20 * S, Caps(Loc), Class'RIUtil'.static.Col(168 * a, 143 * a, 78 * a), 1, 0.62);
	Class'RISkin'.static.FillC(gc, width * 0.5 - 220 * S, cy - 16 * S, 440 * S, 1.5 * S, Class'RIUtil'.static.Col(126 * a, 105 * a, 50 * a));

	if (DeathLoadT > 0)
	{
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', 0, cy + 10 * S, width, 30 * S, Caps(DeathWaitLabel), Class'RIUtil'.static.Col(242 * a, 211 * a, 107 * a), 1, 0.56);
		return;
	}
	w = 360 * S;
	kw = 74 * S;
	y = cy + 8 * S;
	for (i = 0; i < 3; i++)
	{
		if (i == 0)
		{
			K = "ENTER";
			L = DeathLoadLast;
		}
		else if (i == 1)
		{
			K = "L";
			L = DeathLoadGame;
		}
		else
		{
			K = "ESC";
			L = DeathMainMenu;
		}
		Class'RIText'.static.Box(gc, width * 0.5 - w * 0.5, y + 6 * S, kw, 28 * S, Class'RIUtil'.static.Col(150 * a, 126 * a, 62 * a));
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', width * 0.5 - w * 0.5, y + 6 * S, kw, 28 * S, K, Class'RIUtil'.static.Col(242 * a, 211 * a, 107 * a), 1, 0.56);
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', width * 0.5 - w * 0.5 + kw + 20 * S, y + 6 * S, w - kw - 20 * S, 28 * S, Caps(L),
			Class'RIUtil'.static.Col(240 * a, 222 * a, 178 * a), 0, 0.52);
		y += 42 * S;
	}
}

// While dying, AE's main menu (any key, F, Escape) is replaced by the death screen
function InvokeMenu(Class<DeusExBaseWindow> newMenu)
{
	if ((DeathTime() >= 0) && ClassIsChildOf(newMenu, Class'DeusEx.MenuMain'))
		return;
	Super.InvokeMenu(newMenu);
}

event PostDrawWindow(GC gc)'''
s = rep(s, "event PostDrawWindow(GC gc)", DEATH)
s = rep(s, "event bool VirtualKeyPressed(EInputKey key, bool bRepeat)\n{",
        "event bool VirtualKeyPressed(EInputKey key, bool bRepeat)\n{\n"
        "\tif (!bRepeat && DeathUp())\n\t{\n\t\tDeathKey(key);\n\t\treturn True;\n\t}")
s = rep(s, "\tif (!bGoMainMenu && (DP != None) && DP.IsInState('Dying')",
        "\tif (!bGoMainMenu && (DeathLoadT <= 0) && (DP != None) && DP.IsInState('Dying')")
s = rep(s, "defaultproperties\n{",
        'defaultproperties\n{\n     DeathTitle="AGENT DOWN"\n     DeathLoadLast="Load last save"\n'
        '     DeathLoadGame="Load game"\n     DeathMainMenu="Main menu"\n     DeathWaitLabel="Loading..."')
wr('RIRootWindow.uc', s)
print("ok")
