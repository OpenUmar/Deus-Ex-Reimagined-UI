//=============================================================================
// RIChoiceSubColors
// Settings > Interface: colour subtitles by who is speaking, in conversations
// and overheard lines. Each person keeps one colour all game (picked from
// their name); the player has their own.
//=============================================================================
class RIChoiceSubColors extends MenuUIChoiceEnum;

function LoadSetting()
{
	SetValue(Class'RIRootWindow'.default.SubColors);
}

function SaveSetting()
{
	local RIRootWindow R;

	Class'RIRootWindow'.default.SubColors = int(GetValue());
	R = RIRootWindow(GetRootWindow());
	if (R != None)
	{
		R.SubColors = int(GetValue());
		R.SaveConfig();
	}
}

function ResetToDefault()
{
	SetValue(1);
}

defaultproperties
{
     enumText(0)="Off"
     enumText(1)="Names"
     enumText(2)="Names and lines"
     HelpText="Colour subtitles by who is speaking, in conversations and overheard lines. Names: each speaker's name in their own colour. Names and lines: their lines tinted to match too. Each person keeps one colour all game; you have your own."
     actionText="Speaker |&colours"
}
