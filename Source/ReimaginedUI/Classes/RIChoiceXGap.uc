//=============================================================================
// RIChoiceXGap: Gap (Settings > Interface > Crosshair)
//=============================================================================
class RIChoiceXGap extends RIChoiceXNum;

defaultproperties
{
     XWhich=1
     numTicks=17
     startValue=0.000000
     endValue=16.000000
     defaultValue=4.000000
     HelpText="The space between the centre and each arm, in pixels at 1080p, when your aim is steady. Dynamic spread opens it further as your accuracy drops."
     actionText="Gap"
}
