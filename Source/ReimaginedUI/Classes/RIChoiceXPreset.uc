//=============================================================================
// RIChoiceXPreset: Settings > Interface > Crosshair, the preset. Choosing one
// sets every other row; changing any other row turns it to Custom.
//=============================================================================
class RIChoiceXPreset extends MenuUIChoiceEnum;

function LoadSetting()
{
	SetValue(Class'RICrosshair'.default.XPreset);
}

function SaveSetting()
{
	if (int(GetValue()) != Class'RICrosshair'.default.XPreset)
	{
		Class'RICrosshair'.static.ApplyPreset(int(GetValue()));
		Class'RICrosshair'.static.RefreshPage(Self);
	}
}

// Custom isn't chosen by hand: stepping skips it
function CycleNextValue()
{
	Super.CycleNextValue();
	if (int(GetValue()) == 0)
		Super.CycleNextValue();
	SaveSetting();
}

function CyclePreviousValue()
{
	Super.CyclePreviousValue();
	if (int(GetValue()) == 0)
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
     enumText(0)="Custom"
     enumText(1)="Default"
     enumText(2)="Classic"
     enumText(3)="Tight"
     enumText(4)="Dot"
     enumText(5)="T-shape"
     enumText(6)="Large"
     enumText(7)="Circle"
     enumText(8)="Brackets"
     enumText(9)="Chevron"
     enumText(10)="Micro"
     enumText(11)="Plus"
     enumText(12)="Ring"
     HelpText="A ready-made crosshair. Default: the original game's bracket reticle round a centre dot, opening with your real spread. Classic: the same reticle round the original cross. Tight, Micro: small crosses. Dot: a single dot. T-shape: no top arm. Large: wide open. Circle, Brackets, Chevron: other shapes. Plus, Ring: a fixed centre mark only. Change any row below to make your own (Custom)."
     actionText="Preset"
}
