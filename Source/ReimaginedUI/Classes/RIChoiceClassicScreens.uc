//=============================================================================
// RIChoiceClassicScreens
// Settings > Interface: the in-game screens (inventory, health, augs,
// skills, goals...) in the Reimagined look, or GMDX AE's own pages.
//=============================================================================
class RIChoiceClassicScreens extends MenuUIChoiceEnum;

function LoadSetting()
{
	SetValue(int(Class'RIRootWindow'.default.bClassicScreens));
}

function SaveSetting()
{
	local RIRootWindow R;

	Class'RIRootWindow'.default.bClassicScreens = bool(GetValue());
	R = RIRootWindow(GetRootWindow());
	if (R != None)
	{
		R.bClassicScreens = bool(GetValue());
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
     HelpText="In-game screens (inventory, health, augmentations, skills, goals and the rest) in the Reimagined look, or GMDX's original pages."
     actionText="|&In-game screens"
}
