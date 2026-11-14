//=============================================================================
// RIChoiceClassicHUD
// Settings > Interface: the HUD in the Reimagined look, or GMDX AE's own.
//=============================================================================
class RIChoiceClassicHUD extends MenuUIChoiceEnum;

function LoadSetting()
{
	SetValue(int(Class'RIRootWindow'.default.bClassicHUD));
}

function SaveSetting()
{
	local RIRootWindow R;

	Class'RIRootWindow'.default.bClassicHUD = bool(GetValue());
	R = RIRootWindow(GetRootWindow());
	if (R != None)
	{
		R.bClassicHUD = bool(GetValue());
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
     HelpText="The in-game HUD (body monitor, compass, augs, belt, weapon) in the Reimagined look, or the original game's HUD."
     actionText="|&HUD"
}
