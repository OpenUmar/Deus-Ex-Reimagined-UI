//=============================================================================
// RIChoiceXShape: Settings > Interface > Crosshair, the shape
//=============================================================================
class RIChoiceXShape extends MenuUIChoiceEnum;

function LoadSetting()
{
	SetValue(Class'RICrosshair'.default.XShape);
}

function SaveSetting()
{
	if (int(GetValue()) == Class'RICrosshair'.default.XShape)
		return;
	Class'RICrosshair'.default.XShape = int(GetValue());
	Class'RICrosshair'.static.Changed();
	Class'RICrosshair'.static.RefreshPage(Self);
}

function CycleNextValue()
{
	Super.CycleNextValue();
	SaveSetting();
}

function CyclePreviousValue()
{
	Super.CyclePreviousValue();
	SaveSetting();
}

function ResetToDefault()
{
	SetValue(0);
	SaveSetting();
}

defaultproperties
{
     enumText(0)="Cross"
     enumText(1)="Original"
     enumText(2)="Circle"
     enumText(3)="Brackets"
     enumText(4)="Chevron"
     enumText(5)="None"
     HelpText="The outer shape, which opens with the spread: Cross (four arms; T-shape leaves out the top one), Original (the game's own bracket accuracy reticle), Circle, Brackets (four corners), Chevron (a small V under the aim), or None (only the inner mark)."
     actionText="Outer shape"
}
