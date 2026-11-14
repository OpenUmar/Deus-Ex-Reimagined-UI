//=============================================================================
// RIChoiceXBool: an on / off row of Settings > Interface > Crosshair.
// XWhich: 0 centre dot, 1 outline, 2 T-shape, 3 dynamic spread, 4 rifle
// scopes. Saved as it changes; a change (except scopes) makes the preset Custom.
//=============================================================================
class RIChoiceXBool extends MenuUIChoiceEnum;

var int XWhich;

function bool XGet()
{
	switch (XWhich)
	{
		case 0: return Class'RICrosshair'.default.XDot;
		case 1: return Class'RICrosshair'.default.XOutline;
		case 2: return Class'RICrosshair'.default.XTShape;
		case 3: return Class'RICrosshair'.default.XDynamic;
	}
	return Class'RICrosshair'.default.XInScope;
}

function LoadSetting()
{
	SetValue(int(XGet()));
}

function SaveSetting()
{
	local bool B;

	B = (int(GetValue()) != 0);
	if (B == XGet())
		return;
	if (XWhich == 0)
		Class'RICrosshair'.default.XDot = B;
	else if (XWhich == 1)
		Class'RICrosshair'.default.XOutline = B;
	else if (XWhich == 2)
		Class'RICrosshair'.default.XTShape = B;
	else if (XWhich == 3)
		Class'RICrosshair'.default.XDynamic = B;
	else
		Class'RICrosshair'.default.XInScope = B;
	if (XWhich == 4)
		Class'RICrosshair'.static.StaticSaveConfig();
	else
	{
		Class'RICrosshair'.static.Changed();
		Class'RICrosshair'.static.RefreshPage(Self);
	}
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

defaultproperties
{
     enumText(0)="Off"
     enumText(1)="On"
}
