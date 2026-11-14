//=============================================================================
// RIMenuSettingsClassic
// The base's own settings menu, used when Settings > Interface > Menus is
// Classic, with one extra entry so the Interface options stay reachable
// (RIBase adds it to the base's list).
//=============================================================================
class RIMenuSettingsClassic extends MenuSettings;

function CreateMenuButtons()
{
	local int i;
	local string N;

	for (i = 0; i < arrayCount(buttonDefaults); i++)
		if (!Class'RIMenuSettings'.static.SetupSettingsButton(Self, i, N))
			break;
	Super.CreateMenuButtons();
}

defaultproperties
{
}
