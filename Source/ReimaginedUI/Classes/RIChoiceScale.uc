//=============================================================================
// RIChoiceScale
// Settings > Interface: a size, in steps (Which: 0 in-game screens, 1 HUD,
// 2 subtitles). Saved the moment it changes, and shown live.
//=============================================================================
class RIChoiceScale extends MenuUIChoiceSlider;

var int Which;

function float Get()
{
	local float V;

	switch (Which)
	{
		case 0: V = Class'RIRootWindow'.default.PersonaScale; break;
		case 1: V = Class'RIRootWindow'.default.HudScale; break;
		case 3: V = Class'RIRootWindow'.default.BeltScale; break;
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
	else if (Which == 3)
	{
		Class'RIRootWindow'.default.BeltScale = V;
		if (R != None)
			R.BeltScale = V;
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

defaultproperties
{
}
