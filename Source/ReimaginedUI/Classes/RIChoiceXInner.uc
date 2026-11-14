//=============================================================================
// RIChoiceXInner: the inner mark at the centre (Settings > Interface >
// Crosshair), drawn inside whatever outer shape shows the spread
//=============================================================================
class RIChoiceXInner extends MenuUIChoiceEnum;

function LoadSetting()
{
	SetValue(Class'RICrosshair'.default.XInner);
}

function SaveSetting()
{
	if (int(GetValue()) == Class'RICrosshair'.default.XInner)
		return;
	Class'RICrosshair'.default.XInner = int(GetValue());
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
	SetValue(1);
	SaveSetting();
}

defaultproperties
{
     enumText(0)="None"
     enumText(1)="Dot"
     enumText(2)="Plus"
     enumText(3)="Original cross"
     enumText(4)="Ring"
     HelpText="The mark at the very centre, inside the outer shape: none, a dot, a small plus, the original game's cross, or a small ring. Its size is set by Inner size; its lines by Thickness."
     actionText="Inner mark"
}
