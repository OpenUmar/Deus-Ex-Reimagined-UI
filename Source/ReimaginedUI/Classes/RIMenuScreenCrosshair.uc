//=============================================================================
// RIMenuScreenCrosshair
// Settings > Interface > Crosshair: presets, shape and every part of the crosshair,
// CS:GO style. RIPanel draws a live preview beside the rows.
//=============================================================================
class RIMenuScreenCrosshair extends MenuUIScreenWindow;

defaultproperties
{
     choices(0)=Class'ReimaginedUI.RIChoiceXPreset'
     choices(1)=Class'ReimaginedUI.RIChoiceXShape'
     choices(2)=Class'ReimaginedUI.RIChoiceXInner'
     choices(3)=Class'ReimaginedUI.RIChoiceXInnerSize'
     choices(4)=Class'ReimaginedUI.RIChoiceXColor'
     choices(5)=Class'ReimaginedUI.RIChoiceXLen'
     choices(6)=Class'ReimaginedUI.RIChoiceXGap'
     choices(7)=Class'ReimaginedUI.RIChoiceXThick'
     choices(8)=Class'ReimaginedUI.RIChoiceXOutline'
     choices(9)=Class'ReimaginedUI.RIChoiceXTShape'
     choices(10)=Class'ReimaginedUI.RIChoiceXDynamic'
     choices(11)=Class'ReimaginedUI.RIChoiceXScope'
     actionButtons(0)=(Align=HALIGN_Right,Action=AB_Cancel)
     actionButtons(1)=(Align=HALIGN_Right,Action=AB_OK)
     actionButtons(2)=(Action=AB_Reset)
     Title="Crosshair"
     ClientWidth=537
     ClientHeight=450
     clientTextures(0)=Texture'DeusExUI.UserInterface.MenuControlsBackground_1'
     clientTextures(1)=Texture'DeusExUI.UserInterface.MenuControlsBackground_2'
     clientTextures(2)=Texture'DeusExUI.UserInterface.MenuControlsBackground_3'
     textureRows=1
     helpPosY=396
}
