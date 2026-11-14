//=============================================================================
// RIChoiceXDot: Centre dot (Settings > Interface > Crosshair)
//=============================================================================
class RIChoiceXDot extends RIChoiceXBool;

function ResetToDefault()
{
	SetValue(1);
	SaveSetting();
}

defaultproperties
{
     XWhich=0
     HelpText="A dot in the very centre, as thick as the arms."
     actionText="Centre dot"
}
