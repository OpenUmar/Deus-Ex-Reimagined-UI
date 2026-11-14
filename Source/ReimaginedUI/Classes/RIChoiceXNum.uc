//=============================================================================
// RIChoiceXNum: Settings > Interface > Crosshair, a size in screen pixels
// (at 1080p). XWhich: 0 length, 1 gap, 2 thickness, 3 inner size. Built on RIChoiceScale,
// so it saves as you drag or step it; a change turns the preset to Custom.
//=============================================================================
class RIChoiceXNum extends RIChoiceScale;

var int XWhich;

function float XGet()
{
	switch (XWhich)
	{
		case 0: return Class'RICrosshair'.default.XLen;
		case 1: return Class'RICrosshair'.default.XGap;
		case 3: return Class'RICrosshair'.default.XInnerSize;
	}
	return Class'RICrosshair'.default.XThick;
}

function SetEnumerators()
{
	local int i;

	for (i = 0; i < numTicks; i++)
		SetEnumeration(i, string(int(startValue + i * (endValue - startValue) / FMax(1, numTicks - 1) + 0.5)) $ " px");
}

function LoadSetting()
{
	SetValue(XGet());
}

function SaveSetting()
{
	local float V;

	V = float(int(GetValue() + 0.5));
	if (V == XGet())
		return;
	if (XWhich == 0)
		Class'RICrosshair'.default.XLen = V;
	else if (XWhich == 1)
		Class'RICrosshair'.default.XGap = V;
	else if (XWhich == 3)
		Class'RICrosshair'.default.XInnerSize = V;
	else
		Class'RICrosshair'.default.XThick = V;
	Class'RICrosshair'.static.Changed();
	Class'RICrosshair'.static.RefreshPage(Self);
}

function ResetToDefault()
{
	SetValue(defaultValue);
	SaveSetting();
}

defaultproperties
{
}
