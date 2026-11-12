//=============================================================================
// RIChoiceClassicMenus
// Settings > Interface: main menu, pause menu, settings, load / save in the
// Reimagined look, or GMDX AE's own (classic) menus.
//=============================================================================
class RIChoiceClassicMenus extends MenuUIChoiceEnum;

function LoadSetting()
{
	SetValue(int(Class'RIRootWindow'.default.bClassicMenus));
}

function SaveSetting()
{
	local RIRootWindow R;

	Class'RIRootWindow'.default.bClassicMenus = bool(GetValue());
	R = RIRootWindow(GetRootWindow());
	if (R != None)
	{
		R.bClassicMenus = bool(GetValue());
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
     HelpText="Menus (main, pause, settings, load and save) in the Reimagined look, or GMDX's original menus. Takes effect the next time a menu opens."
     actionText="|&Menus"
}
