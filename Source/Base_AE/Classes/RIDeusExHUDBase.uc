//=============================================================================
// RIDeusExHUDBase (GMDX AE)
// Sits between the base's DeusExHUD and RIDeusExHUD, because the bases
// declare UpdateSettings differently (AE adds bNoBelt).
//=============================================================================
class RIDeusExHUDBase extends DeusExHUD;

function UpdateSettings(DeusExPlayer player, optional bool bNoBelt)
{
	Super.UpdateSettings(player, bNoBelt);
	SettingsUpdated();
}

function SettingsUpdated()
{
}

defaultproperties
{
}
