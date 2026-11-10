//=============================================================================
// RIMenuSettingsClassic
// GMDX AE's own settings menu, used when Settings > Interface > Menus is
// Classic, with one extra entry so the Interface options stay reachable.
//=============================================================================
class RIMenuSettingsClassic extends MenuSettings;

defaultproperties
{
     NewButtonNames(7)="Interface"
     NewButtonNames(8)="Previous Menu"
     buttonDefaults(7)=(Y=265,Action=MA_MenuScreen,Invoke=Class'ReimaginedUI.RIMenuScreenInterface')
     buttonDefaults(8)=(Y=302,Action=MA_Previous)
}
