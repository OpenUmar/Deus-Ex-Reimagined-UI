//=============================================================================
// RIMenuScreenInterface
// Settings > Interface: switch each part of the UI between the Reimagined
// look and GMDX AE's own (classic) one.
//=============================================================================
class RIMenuScreenInterface extends MenuUIScreenWindow;

// The base class holds 13 rows; HUD Motion is added as a 14th, placed the same way
function CreateChoices()
{
	local MenuUIChoice newChoice;

	Super.CreateChoices();
	newChoice = MenuUIChoice(winClient.NewChild(Class'ReimaginedUI.RIChoiceHudSway'));
	newChoice.SetPos(choiceStartX, choiceStartY + (choiceCount * choiceVerticalGap) - newChoice.buttonVerticalOffset);
	choiceCount++;
	newChoice.SetSensitivity(True);
}

defaultproperties
{
     choices(0)=Class'ReimaginedUI.RIChoiceClassicMenus'
     choices(1)=Class'ReimaginedUI.RIChoiceClassicScreens'
     choices(2)=Class'ReimaginedUI.RIChoiceClassicDialogue'
     choices(3)=Class'ReimaginedUI.RIChoiceClassicHUD'
     choices(4)=Class'ReimaginedUI.RIChoiceScreenStyle'
     choices(5)=Class'ReimaginedUI.RIChoiceHDTextures'
     choices(6)=Class'ReimaginedUI.RIChoiceScreenScale'
     choices(7)=Class'ReimaginedUI.RIChoiceHudScale'
     choices(8)=Class'ReimaginedUI.RIChoiceBeltScale'
     choices(9)=Class'ReimaginedUI.RIChoiceSubScale'
     choices(10)=Class'ReimaginedUI.RIChoiceConBars'
     choices(11)=Class'ReimaginedUI.RIChoiceCrosshair'
     choices(12)=Class'ReimaginedUI.RIChoiceSubColors'
     actionButtons(0)=(Align=HALIGN_Right,Action=AB_Cancel)
     actionButtons(1)=(Align=HALIGN_Right,Action=AB_OK)
     actionButtons(2)=(Action=AB_Reset)
     Title="Interface"
     ClientWidth=537
     ClientHeight=450
     clientTextures(0)=Texture'DeusExUI.UserInterface.MenuControlsBackground_1'
     clientTextures(1)=Texture'DeusExUI.UserInterface.MenuControlsBackground_2'
     clientTextures(2)=Texture'DeusExUI.UserInterface.MenuControlsBackground_3'
     textureRows=1
     helpPosY=396
}
