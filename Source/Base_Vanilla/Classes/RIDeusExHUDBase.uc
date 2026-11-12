//=============================================================================
// RIDeusExHUDBase (vanilla)
// Sits between the base's DeusExHUD and RIDeusExHUD, because the bases
// declare UpdateSettings differently.
//=============================================================================
class RIDeusExHUDBase extends DeusExHUD;

function UpdateSettings(DeusExPlayer player)
{
	Super.UpdateSettings(player);
	SettingsUpdated();
}

function SettingsUpdated()
{
}

defaultproperties
{
}
