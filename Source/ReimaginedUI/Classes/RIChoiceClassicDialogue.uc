//=============================================================================
// RIChoiceClassicDialogue
// Settings > Interface: conversations in the Reimagined look, or the
// original letterboxed conversation window.
//=============================================================================
class RIChoiceClassicDialogue extends MenuUIChoiceEnum;

function LoadSetting()
{
	SetValue(int(Class'RIRootWindow'.default.bClassicDialogue));
}

function SaveSetting()
{
	local RIRootWindow R;

	Class'RIRootWindow'.default.bClassicDialogue = bool(GetValue());
	R = RIRootWindow(GetRootWindow());
	if (R != None)
	{
		R.bClassicDialogue = bool(GetValue());
		R.SaveConfig();
	}
}

function ResetToDefault()
{
	SetValue(0);
}

defaultproperties
{
     enumText(0)="Reimagined"
     enumText(1)="Classic"
     HelpText="Conversations in the Reimagined look, or the original conversation window. Takes effect from the next conversation."
     actionText="|&Dialogue"
}
