//=============================================================================
// RIChoiceScreenScale: Screen size (Settings > Interface), a slider in 5% steps
//=============================================================================
class RIChoiceScreenScale extends RIChoiceScale;

defaultproperties
{
     Which=0
     numTicks=6
     startValue=75.000000
     endValue=100.000000
     defaultValue=100.000000
     HelpText="How large the Vanilla+ in-game screens (Inventory, Health, Augs, Skills, Journal) are drawn; smaller leaves the game visible round them. Ctrl - and Ctrl = change it inside the screens too."
     actionText="Screen size"
}
