import os, re
base = os.path.expanduser("~/mnt/Deus Ex/Mods/ReimaginedUI/Source/ReimaginedUI/Classes")
os.chdir(base)

def rd(p): return open(p, encoding='latin-1').read()
def wr(p, s): open(p, 'w', encoding='latin-1').write(s)
def rep(s, a, b):
    assert a in s, a[:90]
    return s.replace(a, b, 1)

# ---------------- root: settings + helpers
s = rd('RIRootWindow.uc')
s = rep(s, "var globalconfig float PersonaScale;",
        "var globalconfig float PersonaScale;\n"
        "var globalconfig float HudScale;       // the rebuilt HUD's size (0 = 1)\n"
        "var globalconfig float SubScale;       // subtitles' size (0 = 1)")
s = rep(s, "// A Vanilla+ screen board scaled below full size",
"""// Interface sizes from Settings (unset reads as 100%)
static function float HudK()
{
	if ((default.HudScale < 0.5) || (default.HudScale > 1.5))
		return 1.0;
	return default.HudScale;
}

static function float SubK()
{
	if ((default.SubScale < 0.5) || (default.SubScale > 1.6))
		return 1.0;
	return default.SubScale;
}

// A Vanilla+ screen board scaled below full size""")
wr('RIRootWindow.uc', s)

# ---------------- the setting rows
open('RIChoiceScale.uc', 'w', encoding='latin-1').write(r'''//=============================================================================
// RIChoiceScale
// Settings > Interface: a size, in steps (Which: 0 in-game screens, 1 HUD,
// 2 subtitles). Saved the moment it changes, and shown live.
//=============================================================================
class RIChoiceScale extends MenuUIChoiceEnum;

var int   Which;
var float Steps[8];
var int   NumSteps;

function float Get()
{
	switch (Which)
	{
		case 0: return Class'RIRootWindow'.default.PersonaScale;
		case 1: return Class'RIRootWindow'.default.HudScale;
	}
	return Class'RIRootWindow'.default.SubScale;
}

function Put(float V)
{
	local RIRootWindow R;

	R = RIRootWindow(GetRootWindow());
	if (Which == 0)
	{
		Class'RIRootWindow'.default.PersonaScale = V;
		if (R != None)
			R.PersonaScale = V;
	}
	else if (Which == 1)
	{
		Class'RIRootWindow'.default.HudScale = V;
		if (R != None)
			R.HudScale = V;
	}
	else
	{
		Class'RIRootWindow'.default.SubScale = V;
		if (R != None)
			R.SubScale = V;
	}
	if (R != None)
	{
		R.SaveConfig();
		if (R.hud != None)
			R.hud.ConfigurationChanged();
	}
}

function int IndexOf(float V)
{
	local int i, best;
	local float d, bd;

	if (V <= 0)
		V = 1.0;
	best = 0;
	bd = 99;
	for (i = 0; i < NumSteps; i++)
	{
		d = Abs(Steps[i] - V);
		if (d < bd)
		{
			bd = d;
			best = i;
		}
	}
	return best;
}

function LoadSetting()
{
	SetValue(IndexOf(Get()));
}

function SaveSetting()
{
	Put(Steps[Clamp(GetValue(), 0, NumSteps - 1)]);
}

function CycleNextValue()
{
	Super.CycleNextValue();
	SaveSetting();
}

function CyclePreviousValue()
{
	Super.CyclePreviousValue();
	SaveSetting();
}

function ResetToDefault()
{
	SetValue(IndexOf(1.0));
	SaveSetting();
}

defaultproperties
{
}
''')

open('RIChoiceScreenScale.uc', 'w', encoding='latin-1').write('''//=============================================================================
// RIChoiceScreenScale: size of the Vanilla+ in-game screens (Ctrl - / = too)
//=============================================================================
class RIChoiceScreenScale extends RIChoiceScale;

defaultproperties
{
     Which=0
     NumSteps=6
     Steps(0)=0.75
     Steps(1)=0.8
     Steps(2)=0.85
     Steps(3)=0.9
     Steps(4)=0.95
     Steps(5)=1.0
     enumText(0)="75%"
     enumText(1)="80%"
     enumText(2)="85%"
     enumText(3)="90%"
     enumText(4)="95%"
     enumText(5)="100%"
     HelpText="How large the Vanilla+ in-game screens (Inventory, Health, Augs, Skills, Journal) are drawn. Smaller leaves the game visible round them. Ctrl - and Ctrl = change it inside the screens too."
     actionText="Screen size"
}
''')

open('RIChoiceHudScale.uc', 'w', encoding='latin-1').write('''//=============================================================================
// RIChoiceHudScale: size of the rebuilt HUD (kept in its corners)
//=============================================================================
class RIChoiceHudScale extends RIChoiceScale;

defaultproperties
{
     Which=1
     NumSteps=6
     Steps(0)=0.7
     Steps(1)=0.8
     Steps(2)=0.9
     Steps(3)=1.0
     Steps(4)=1.1
     Steps(5)=1.2
     enumText(0)="70%"
     enumText(1)="80%"
     enumText(2)="90%"
     enumText(3)="100%"
     enumText(4)="110%"
     enumText(5)="120%"
     HelpText="How large the HUD is drawn: body monitor, compass, augs, belt and weapon. Each part stays in its corner of the screen."
     actionText="HUD size"
}
''')

open('RIChoiceSubScale.uc', 'w', encoding='latin-1').write('''//=============================================================================
// RIChoiceSubScale: size of the subtitles (barks and first-person talk)
//=============================================================================
class RIChoiceSubScale extends RIChoiceScale;

defaultproperties
{
     Which=2
     NumSteps=5
     Steps(0)=0.8
     Steps(1)=0.9
     Steps(2)=1.0
     Steps(3)=1.15
     Steps(4)=1.3
     enumText(0)="80%"
     enumText(1)="90%"
     enumText(2)="100%"
     enumText(3)="115%"
     enumText(4)="130%"
     HelpText="How large subtitles are drawn: what people say as you pass, and first-person conversations and InfoLink lines."
     actionText="Subtitle size"
}
''')

s = rd('RIMenuScreenInterface.uc')
s = rep(s, "     choices(5)=Class'ReimaginedUI.RIChoiceHDTextures'\n",
        "     choices(5)=Class'ReimaginedUI.RIChoiceHDTextures'\n"
        "     choices(6)=Class'ReimaginedUI.RIChoiceScreenScale'\n"
        "     choices(7)=Class'ReimaginedUI.RIChoiceHudScale'\n"
        "     choices(8)=Class'ReimaginedUI.RIChoiceSubScale'\n")
s = rep(s, "     ClientHeight=300", "     ClientHeight=410")
s = rep(s, "     helpPosY=246", "     helpPosY=356")
wr('RIMenuScreenInterface.uc', s)

# ---------------- HUD: scale, with the bottom parts kept at the bottom
s = rd('RIHud.uc')
s = rep(s, "event DrawWindow(GC gc)\n{\n	Class'RITheme'.static.SetMode(2);   // the HUD follows the HUD theme",
        "// Text and layout both follow Settings > Interface > HUD size\n"
        "event DrawWindow(GC gc)\n{\n	Class'RIText'.default.TextMul = Class'RIRootWindow'.static.HudK();\n	DrawHud(gc);\n	Class'RIText'.default.TextMul = 1.0;\n}\n\n"
        "function DrawHud(GC gc)\n{\n	Class'RITheme'.static.SetMode(2);   // the HUD follows the HUD theme")
s = rep(s, "	S = height / 1080.0;\n	gc.EnableSmoothing(True);\n	if (Class'RIVP'.static.On())",
        "	S = height / 1080.0 * Class'RIRootWindow'.static.HudK();\n	gc.EnableSmoothing(True);\n	if (Class'RIVP'.static.On())")
s = rep(s, "function float CX(float X) {",
        "function float BY(float Y) { return height - (1080 - Y) * S; }      // kept at the bottom\n"
        "function float MY(float Y) { return height * 0.5 + (Y - 540) * S; }  // kept at mid-height\n"
        "function float CX(float X) {")
# Vanilla+ belt / weapon / rail
lines = s.split('\n')
def conv(i, vals, fn='BY'):
    for v in vals:
        pat = re.compile(r'(?<![\w.])' + re.escape(v) + r' \* S')
        lines[i] = pat.sub(fn + '(' + v + ')', lines[i])
start = next(i for i, l in enumerate(lines) if l.startswith('function DrawVPBelt'))
end = len(lines)
for i in range(start, end):
    if lines[i].startswith('defaultproperties'):
        break
    conv(i, ['884', '856', '888', '965', '837', '796', '808', '848', '850', '898', '865'])
s = '\n'.join(lines)
s = rep(s, "Art(gc, RX(1760), 232 * S, 160 * S, 528 * S,", "Art(gc, RX(1760), MY(232), 160 * S, 528 * S,")
s = rep(s, "	y = 325 * S;", "	y = MY(325);")
wr('RIHud.uc', s)

# ---------------- HUD layout: same size; barks / talk end above the (scaled) belt
s = rd('RIDeusExHUD.uc')
s = rep(s, "	K = height / 1080.0;\n	if (K <= 0)", "	K = height / 1080.0 * Class'RIRootWindow'.static.HudK();\n	if (K <= 0)")
s = s.replace("barkDisplay.ConfigureChild((width - QW) * 0.5, 838 * K - QH, QW, QH);",
              "barkDisplay.ConfigureChild((width - QW) * 0.5, height - 242 * K - QH, QW, QH);")
s = s.replace("conWindow.ConfigureChild((width - QW) * 0.5, 838 * K - QH, QW, QH);",
              "conWindow.ConfigureChild((width - QW) * 0.5, height - 242 * K - QH, QW, QH);")
s = s.replace("timer.ConfigureChild(width - 36 * K - QW, height - (30 + 176 + 16) * K - QH, QW, QH);",
              "timer.ConfigureChild(width - 36 * K - QW, height - (30 + 176 + 16) * K - QH, QW, QH);")
wr('RIDeusExHUD.uc', s)

# ---------------- subtitles: wrappers set the size for text and spacing
s = rd('RISubs.uc')
s = rep(s, "static function float DrawSub(GC gc,", """// Settings > Interface > Subtitle size: text and spacing together
static function float DrawSub(GC gc, float X, float Y, float W, float K, string Speaker, string T,
	bool bPlayer, float a)
{
	local float q, r;

	q = Class'RIRootWindow'.static.SubK();
	Class'RIText'.default.TextMul = q;
	r = DrawSubIn(gc, X, Y, W, K * q, Speaker, T, bPlayer, a);
	Class'RIText'.default.TextMul = 1.0;
	return r;
}

static function float SubHeight(float W, float K, string Speaker, string T)
{
	local float q, r;

	q = Class'RIRootWindow'.static.SubK();
	Class'RIText'.default.TextMul = q;
	r = SubHeightIn(W, K * q, Speaker, T);
	Class'RIText'.default.TextMul = 1.0;
	return r;
}

static function float DrawSubIn(GC gc,""")
s = rep(s, "static function float SubHeight(float W, float K, string Speaker, string T)\n{\n	local", "static function float SubHeightIn(float W, float K, string Speaker, string T)\n{\n	local")
wr('RISubs.uc', s)

# ---------------- RIText: a size multiplier for whole parts of the UI
s = rd('RIText.uc')
s = rep(s, "var bool bAtlasText;", "var bool bAtlasText;\nvar float TextMul;     // set round a whole part of the UI (HUD size, subtitle size); 0 = 1\n\nstatic final function float M()\n{\n	if (default.TextMul <= 0)\n		return 1.0;\n	return default.TextMul;\n}")
s = rep(s, "		return Class'RINative'.static.RINativeTextWidth(Id, Size * Scale, Spacing * Scale, S);", "		return Class'RINative'.static.RINativeTextWidth(Id, Size * Scale * M(), Spacing * Scale * M(), S);")
s = rep(s, "		return Class'RINative'.static.RINativeAscent(Id, Size * Scale) + Class'RINative'.static.RINativeDescent(Id, Size * Scale);", "		return Class'RINative'.static.RINativeAscent(Id, Size * Scale * M()) + Class'RINative'.static.RINativeDescent(Id, Size * Scale * M());")
s = rep(s, "		Class'RINative'.static.RINativeDrawText(gc, Id, X, Y, S, C, Size * Scale, Spacing * Scale);", "		Class'RINative'.static.RINativeDrawText(gc, Id, X, Y, S, C, Size * Scale * M(), Spacing * Scale * M());")
wr('RIText.uc', s)
print("ok")
