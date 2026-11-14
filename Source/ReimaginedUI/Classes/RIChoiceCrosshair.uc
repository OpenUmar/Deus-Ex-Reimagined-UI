//=============================================================================
// RIChoiceCrosshair: Settings > Interface, opens the Crosshair page
//=============================================================================
class RIChoiceCrosshair extends MenuUIChoiceAction;

defaultproperties
{
     Action=MA_MenuScreen
     Invoke=Class'ReimaginedUI.RIMenuScreenCrosshair'
     HelpText="Make your own crosshair or pick a preset: colour, length, gap, thickness, centre dot, outline, T-shape, dynamic spread and rifle scopes, with a live preview."
     actionText="Crosshair..."
}
