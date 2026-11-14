//=============================================================================
// RIChoiceXScope: In rifle scopes (Settings > Interface > Crosshair)
//=============================================================================
class RIChoiceXScope extends RIChoiceXBool;

function ResetToDefault()
{
	SetValue(1);
	SaveSetting();
}

defaultproperties
{
     XWhich=4
     HelpText="Show the crosshair over a rifle scope as well (never through binoculars)."
     actionText="In rifle scopes"
}
