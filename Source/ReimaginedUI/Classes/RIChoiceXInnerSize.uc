//=============================================================================
// RIChoiceXInnerSize: the inner mark's size (Settings > Interface > Crosshair)
//=============================================================================
class RIChoiceXInnerSize extends RIChoiceXNum;

defaultproperties
{
     XWhich=3
     numTicks=8
     startValue=2.000000
     endValue=16.000000
     defaultValue=2.000000
     HelpText="How big the inner mark is, in pixels at 1080p: the dot's width, the plus's arm span, the ring's radius. For the original cross, 8 is the game's own size. Even sizes only, so it sits exactly on the centre."
     actionText="Inner size"
}
