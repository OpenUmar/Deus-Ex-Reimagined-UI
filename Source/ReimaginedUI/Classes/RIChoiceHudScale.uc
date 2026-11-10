//=============================================================================
// RIChoiceHudScale: HUD size (Settings > Interface), a slider in 5% steps
//=============================================================================
class RIChoiceHudScale extends RIChoiceScale;

defaultproperties
{
     Which=1
     numTicks=13
     startValue=70.000000
     endValue=130.000000
     defaultValue=100.000000
     HelpText="How large the HUD is drawn: body monitor, compass, augs, belt and weapon. Each part stays in its corner of the screen."
     actionText="HUD size"
}
