//=============================================================================
// RIChoiceHudSway
// Settings > Interface: HUD motion. The HUD trails the view slightly as you
// look around, springs back, and bobs gently as you walk, so it reads as a
// layer in front of the eyes. Off keeps it still.
//=============================================================================
class RIChoiceHudSway extends MenuUIChoiceEnum;

function LoadSetting()
{
	SetValue(int(Class'RIRootWindow'.default.bHudSway));
}

function SaveSetting()
{
	local RIRootWindow R;

	Class'RIRootWindow'.default.bHudSway = bool(GetValue());
	R = RIRootWindow(GetRootWindow());
	if (R != None)
	{
		R.bHudSway = bool(GetValue());
		R.SaveConfig();
	}
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
	SetValue(1);
}

defaultproperties
{
     enumText(0)="Off"
     enumText(1)="On"
     HelpText="The HUD trails your view slightly when you look around, and glides back, for a sense of depth. The crosshair never moves."
     actionText="HUD |&Motion"
}
