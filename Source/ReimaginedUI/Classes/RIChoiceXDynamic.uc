//=============================================================================
// RIChoiceXDynamic: Dynamic spread (Settings > Interface > Crosshair)
//=============================================================================
class RIChoiceXDynamic extends RIChoiceXBool;

function ResetToDefault()
{
	SetValue(1);
	SaveSetting();
}

defaultproperties
{
     XWhich=3
     HelpText="The crosshair opens to the real spread of the weapon in your hands: where its shots can actually land, from the game's own accuracy rules, at your current zoom. Off: the crosshair stays the same size."
     actionText="Dynamic spread"
}
