//=============================================================================
// RIChoiceXOutline: Outline (Settings > Interface > Crosshair)
//=============================================================================
class RIChoiceXOutline extends RIChoiceXBool;

function ResetToDefault()
{
	SetValue(1);
	SaveSetting();
}

defaultproperties
{
     XWhich=1
     HelpText="A one-pixel dark outline round every stroke, so the crosshair reads on bright and dark scenes alike."
     actionText="Outline"
}
