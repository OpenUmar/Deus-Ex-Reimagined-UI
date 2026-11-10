import os
os.chdir(os.path.expanduser("~/mnt/Deus Ex/Mods/ReimaginedUI/Source/ReimaginedUI/Classes"))

def rd(p): return open(p, encoding='latin-1').read()
def wr(p, s): open(p, 'w', encoding='latin-1').write(s)
def rep(s, a, b):
    assert a in s, a[:90]
    return s.replace(a, b, 1)

# config + helper
s = rd('RIRootWindow.uc')
s = rep(s, "var globalconfig float SubScale;", "var globalconfig float SubScale;\nvar globalconfig float BeltScale;      // the hotbar's size, on top of the HUD size (0 = 1)")
s = rep(s, "static function float SubK()", """static function float BeltK()
{
	if ((default.BeltScale < 0.5) || (default.BeltScale > 1.3))
		return 1.0;
	return default.BeltScale;
}

static function float SubK()""")
wr('RIRootWindow.uc', s)

# slider
s = rd('RIChoiceScale.uc')
s = rep(s, """		case 1: V = Class'RIRootWindow'.default.HudScale; break;
		default: V = Class'RIRootWindow'.default.SubScale;""", """		case 1: V = Class'RIRootWindow'.default.HudScale; break;
		case 3: V = Class'RIRootWindow'.default.BeltScale; break;
		default: V = Class'RIRootWindow'.default.SubScale;""")
s = rep(s, """	else
	{
		Class'RIRootWindow'.default.SubScale = V;""", """	else if (Which == 3)
	{
		Class'RIRootWindow'.default.BeltScale = V;
		if (R != None)
			R.BeltScale = V;
	}
	else
	{
		Class'RIRootWindow'.default.SubScale = V;""")
wr('RIChoiceScale.uc', s)

wr('RIChoiceBeltScale.uc', '''//=============================================================================
// RIChoiceBeltScale: Hotbar size (Settings > Interface), a slider in 5% steps
//=============================================================================
class RIChoiceBeltScale extends RIChoiceScale;

defaultproperties
{
     Which=3
     numTicks=13
     startValue=60.000000
     endValue=120.000000
     defaultValue=100.000000
     HelpText="How large the hotbar (belt) is drawn, on top of the HUD size. It stays centred at the bottom of the screen."
     actionText="Hotbar size"
}
''')

s = rd('RIMenuScreenInterface.uc')
s = rep(s, "     choices(8)=Class'ReimaginedUI.RIChoiceSubScale'\n",
        "     choices(8)=Class'ReimaginedUI.RIChoiceBeltScale'\n     choices(9)=Class'ReimaginedUI.RIChoiceSubScale'\n")
s = rep(s, "     ClientHeight=410", "     ClientHeight=450")
s = rep(s, "     helpPosY=356", "     helpPosY=396")
wr('RIMenuScreenInterface.uc', s)

# the belt drawn at its own size, centred at the bottom
s = rd('RIHud.uc')
s = rep(s, "// Belt in the board's ten slots\nfunction DrawVPBelt(GC gc)\n{", """// Belt in the board's ten slots, at Settings > Interface > Hotbar size
// (S scaled for the belt alone: CX keeps it centred, BY at the bottom)
function DrawVPBelt(GC gc)
{
	local float S0, M0;

	S0 = S;
	M0 = Class'RIText'.default.TextMul;
	S = S * Class'RIRootWindow'.static.BeltK();
	Class'RIText'.default.TextMul = M0 * Class'RIRootWindow'.static.BeltK();
	DrawVPBeltIn(gc);
	S = S0;
	Class'RIText'.default.TextMul = M0;
}

function DrawVPBeltIn(GC gc)
{""")
wr('RIHud.uc', s)

# barks / first-person talk end above the belt at its size
s = rd('RIDeusExHUD.uc')
s = s.replace("barkDisplay.ConfigureChild((width - QW) * 0.5, height - 242 * K - QH, QW, QH);",
              "barkDisplay.ConfigureChild((width - QW) * 0.5, height - (224 * Class'RIRootWindow'.static.BeltK() + 18) * K - QH, QW, QH);")
s = s.replace("conWindow.ConfigureChild((width - QW) * 0.5, height - 242 * K - QH, QW, QH);",
              "conWindow.ConfigureChild((width - QW) * 0.5, height - (224 * Class'RIRootWindow'.static.BeltK() + 18) * K - QH, QW, QH);")
wr('RIDeusExHUD.uc', s)
print("ok")
