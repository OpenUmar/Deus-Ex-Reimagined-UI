//=============================================================================
// RIChoiceXThick: Thickness (Settings > Interface > Crosshair)
//=============================================================================
class RIChoiceXThick extends RIChoiceXNum;

defaultproperties
{
     XWhich=2
     numTicks=3
     startValue=2.000000
     endValue=6.000000
     defaultValue=2.000000
     HelpText="How thick the lines are, in pixels at 1080p. Always an even number, so every line sits exactly on the centre of the screen."
     actionText="Thickness"
}
