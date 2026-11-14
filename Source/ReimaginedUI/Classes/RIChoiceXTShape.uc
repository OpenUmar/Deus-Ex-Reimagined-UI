//=============================================================================
// RIChoiceXTShape: T-shape (Settings > Interface > Crosshair)
//=============================================================================
class RIChoiceXTShape extends RIChoiceXBool;

function ResetToDefault()
{
	SetValue(0);
	SaveSetting();
}

defaultproperties
{
     XWhich=2
     HelpText="Leaves out the top arm."
     actionText="T-shape"
}
