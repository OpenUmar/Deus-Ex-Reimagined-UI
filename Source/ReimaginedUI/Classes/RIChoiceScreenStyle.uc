//=============================================================================
// RIChoiceScreenStyle
// Settings > Interface: the rebuilt in-game screens drawn Sleek (hairlines) or
// Vanilla+ (the original persona textures, 4x HD).
//=============================================================================
class RIChoiceScreenStyle extends MenuUIChoiceEnum;

function LoadSetting()
{
	SetValue(Class'RIRootWindow'.default.ScreenStyle);
}

function SaveSetting()
{
	local RIRootWindow R;

	Class'RIRootWindow'.default.ScreenStyle = GetValue();
	Log("RI: screen style saved as " $ GetValue());
	R = RIRootWindow(GetRootWindow());
	if (R != None)
	{
		R.ScreenStyle = GetValue();
		R.SaveConfig();
	}
}

// Saved the moment it changes, so leaving Settings any way keeps it
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
	SetValue(2);
}

defaultproperties
{
     enumText(0)="Sleek"
     enumText(1)="Vanilla+"
     enumText(2)="Modern"
     HelpText="Modern (default): the Sleek layouts in digitized chamfered frames, with a Human Revolution style belt. Sleek: hairline panels. Vanilla+: the same updated screens drawn with the original game's panel frames, highlights and buttons in HD. Menus and Settings are the same in all three."
     actionText="|&UI style"
}
