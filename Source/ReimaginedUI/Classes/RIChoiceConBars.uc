//=============================================================================
// RIChoiceConBars
// Settings > Interface: the black cinematic bars in conversations, as in the
// original game, or none (the scene stays full screen).
//=============================================================================
class RIChoiceConBars extends MenuUIChoiceEnum;

function LoadSetting()
{
	SetValue(int(Class'RIRootWindow'.default.bConBars));
}

function SaveSetting()
{
	local RIRootWindow R;

	Class'RIRootWindow'.default.bConBars = bool(GetValue());
	R = RIRootWindow(GetRootWindow());
	if (R != None)
	{
		R.bConBars = bool(GetValue());
		R.SaveConfig();
	}
}

function ResetToDefault()
{
	SetValue(0);
}

defaultproperties
{
     enumText(0)="Off"
     enumText(1)="On"
     HelpText="Black cinematic bars above and below the scene during conversations, as in the original game. Takes effect from the next conversation."
     actionText="Conversation |&Bars"
}
