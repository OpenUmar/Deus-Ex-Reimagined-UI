import os
os.chdir(os.path.expanduser("~/mnt/Deus Ex/Mods/ReimaginedUI/Source/ReimaginedUI/Classes"))

def rd(p): return open(p, encoding='latin-1').read()
def wr(p, s): open(p, 'w', encoding='latin-1').write(s)
def rep(s, a, b, n=1):
    assert a in s, a[:90]
    return s.replace(a, b, n)

# ---------- Vanilla+ leaves the menus (Settings, Load/Save, boxes) as they are
s = rd('RIVP.uc')
s = rep(s, """static final function bool InMenus()
{
	return On() && (Class'RITheme'.default.Mode != 3);
}""", """static final function bool InMenus()
{
	return False;      // Vanilla+ is for the HUD, dialogue and in-game screens only
}""")
wr('RIVP.uc', s)

s = rd('RITheme.uc')
s = rep(s, "		if ((default.Mode == 1) && (Class'RIRootWindow'.default.ScreenStyle == 1))",
        "		if ((default.Mode == 1) && Class'RIVP'.static.InMenus())")
wr('RITheme.uc', s)

for f in ['RIPanel.uc', 'RIMenuSettings.uc', 'RIScreenFrame.uc']:
    s = rd(f)
    s = s.replace("Class'RIVP'.static.On()", "Class'RIVP'.static.InMenus()")
    wr(f, s)

# ---------- sizes as sliders
s = rd('RIChoiceScale.uc')
i = s.index("class RIChoiceScale extends MenuUIChoiceEnum;")
j = s.index("defaultproperties")
s = s[:i] + '''class RIChoiceScale extends MenuUIChoiceSlider;

var int Which;

function float Get()
{
	local float V;

	switch (Which)
	{
		case 0: V = Class'RIRootWindow'.default.PersonaScale; break;
		case 1: V = Class'RIRootWindow'.default.HudScale; break;
		default: V = Class'RIRootWindow'.default.SubScale;
	}
	if (V <= 0)
		V = 1.0;
	return V;
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

// one tick per 5%, labelled as a percentage
function SetEnumerators()
{
	local int i;

	for (i = 0; i < numTicks; i++)
		SetEnumeration(i, string(int(startValue + i * (endValue - startValue) / FMax(1, numTicks - 1) + 0.5)) $ "%");
}

function LoadSetting()
{
	SetValue(Get() * 100.0);
}

function SaveSetting()
{
	Put(GetValue() / 100.0);
}

// arrows and keys step and stop at the ends (no wrapping round)
function CycleNextValue()
{
	if ((btnSlider != None) && (btnSlider.winSlider.GetTickPosition() < btnSlider.winSlider.GetNumTicks() - 1))
		btnSlider.winSlider.SetTickPosition(btnSlider.winSlider.GetTickPosition() + 1);
	SaveSetting();
}

function CyclePreviousValue()
{
	if ((btnSlider != None) && (btnSlider.winSlider.GetTickPosition() > 0))
		btnSlider.winSlider.SetTickPosition(btnSlider.winSlider.GetTickPosition() - 1);
	SaveSetting();
}

function ResetToDefault()
{
	SetValue(100.0);
	SaveSetting();
}

''' + s[j:]
wr('RIChoiceScale.uc', s)

def slider(name, which, lo, hi, text, label):
    n = int((hi - lo) / 5) + 1
    wr(name + '.uc', f'''//=============================================================================
// {name}: {label} (Settings > Interface), a slider in 5% steps
//=============================================================================
class {name} extends RIChoiceScale;

defaultproperties
{{
     Which={which}
     numTicks={n}
     startValue={lo:.6f}
     endValue={hi:.6f}
     defaultValue=100.000000
     HelpText="{text}"
     actionText="{label}"
}}
''')

slider('RIChoiceScreenScale', 0, 75, 100,
       "How large the Vanilla+ in-game screens (Inventory, Health, Augs, Skills, Journal) are drawn; smaller leaves the game visible round them. Ctrl - and Ctrl = change it inside the screens too.",
       "Screen size")
slider('RIChoiceHudScale', 1, 70, 130,
       "How large the HUD is drawn: body monitor, compass, augs, belt and weapon. Each part stays in its corner of the screen.",
       "HUD size")
slider('RIChoiceSubScale', 2, 80, 140,
       "How large subtitles are drawn: what people say as you pass, and first-person conversations.",
       "Subtitle size")

# ---------- the panel: sliders apply at once; arrows match the side clicked
s = rd('RIPanel.uc')
s = rep(s, """	f = FClamp((PointX - SliderX()) / SliderW(), 0, 1);
	if (int(f * (n - 1) + 0.5) != Sl.GetTickPosition())
		Sl.SetTickPosition(int(f * (n - 1) + 0.5));
	RebuildRows();""", """	f = FClamp((PointX - SliderX()) / SliderW(), 0, 1);
	if (int(f * (n - 1) + 0.5) != Sl.GetTickPosition())
	{
		Sl.SetTickPosition(int(f * (n - 1) + 0.5));
		// the interface sizes apply as you drag
		if (RIChoiceScale(RowChoice[i]) != None)
			RowChoice[i].SaveSetting();
	}
	RebuildRows();""")

# a value row: remember where its arrows are drawn, and always draw them
s = rep(s, "var bool  bDragSlider;", "var bool  bDragSlider;\nvar float ArrowLX[256], ArrowRX[256];   // where each value row's < and > are drawn")
s = rep(s, """		// Cycle arrows on the active row
		if (bHot && (RowOn[i] != 0) && (Kind != KIND_KEYS))
		{
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', vr - tw - 22 * UIS, y, 14 * UIS, RowH, "<", Dim, 1);
			Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', vr + 8 * UIS, y, 14 * UIS, RowH, ">", Dim, 1);
		}""", """		// Cycle arrows: on every changeable row (faint), bright on the active
		// one; each side is its own click target (< back, > forward)
		ArrowLX[i] = vr - tw - 30 * UIS;
		ArrowRX[i] = vr + 6 * UIS;
		if ((RowOn[i] != 0) && (Kind != KIND_KEYS))
		{
			if (bHot)
				ArrowK = 1.0;
			else
				ArrowK = 0.45;
			Class'RIText'.static.DrawIn(gc, Class'RIFontBody', ArrowLX[i], y, 22 * UIS, RowH, "<", Class'RIUtil'.static.Scale(ValueC, ArrowK), 1, 0.9);
			Class'RIText'.static.DrawIn(gc, Class'RIFontBody', ArrowRX[i], y, 22 * UIS, RowH, ">", Class'RIUtil'.static.Scale(ValueC, ArrowK), 1, 0.9);
		}""")
s = rep(s, """			if ((RowType[r] == ROW_SLIDER) && (pointX >= SliderX() - 8 * UIS) && (pointX <= SliderX() + SliderW() + 8 * UIS))
			{
				bDragSlider = True;
				DragRow = r;
				GrabMouse();
				SetSliderAt(r, pointX);
			}
			else
				Activate(r, True);""", """			if ((RowType[r] == ROW_SLIDER) && (pointX >= SliderX() - 8 * UIS) && (pointX <= SliderX() + SliderW() + 8 * UIS))
			{
				bDragSlider = True;
				DragRow = r;
				GrabMouse();
				SetSliderAt(r, pointX);
			}
			// a value row: the < side goes back, the rest goes forward
			else if ((RowType[r] == ROW_VALUE) && (Kind != KIND_KEYS) && (pointX < ArrowLX[r] + 26 * UIS) && (pointX > ArrowLX[r] - 60 * UIS))
				CycleRow(r, -1);
			else
				Activate(r, True);""")
# sliders and value rows saved straight after a keyboard / arrow change too (interface sizes)
s = rep(s, """		if (Dir > 0)
			Ch.CycleNextValue();
		else
			Ch.CyclePreviousValue();
	}""", """		if (Dir > 0)
			Ch.CycleNextValue();
		else
			Ch.CyclePreviousValue();
		if (RIChoiceScale(Ch) != None)
			Ch.SaveSetting();
	}""")
wr('RIPanel.uc', s)
print("ok")
