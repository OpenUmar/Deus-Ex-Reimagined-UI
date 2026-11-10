//=============================================================================
// RIRechargeWindow
// AE's repair bot window (bioelectric recharge, equipment charging, the bot's
// own readiness) with all its logic, drawn as a Sleek gold panel in place of
// RSD's riveted art; its buttons and text take the persona gold.
//=============================================================================
class RIRechargeWindow extends HUDRechargeWindow;

var float Age, NextSkin;

event Tick(float deltaSeconds)
{
	Super.Tick(deltaSeconds);
	Age += deltaSeconds;
	if (Age >= NextSkin)
	{
		Class'RITheme'.static.SetMode(2);
		Class'RISkin'.static.SkinDeviceTree(Self);
		if (winTitle != None)
			winTitle.SetTextColor(Class'RIUtil'.static.Col(255, 241, 194));
		Class'RITheme'.static.SetMode(0);
		NextSkin = Age + 0.5;
	}
}

function DrawBackground(GC gc)
{
	local float a;

	Class'RITheme'.static.SetMode(2);
	a = 0.4 + 0.6 * Class'RIUtil'.static.EaseOut(FClamp(Age / 0.22, 0, 1));
	Class'RISkin'.static.GoldPanel(gc, 8, 8, width - 16, height - 14, 0.5, a);
	// a hairline under the title row
	Class'RIText'.static.HLine(gc, 20, 36, width - 40, Class'RIUtil'.static.Col(79 * a, 65 * a, 31 * a));
	Class'RITheme'.static.SetMode(0);
}

function DrawBorder(GC gc)
{
}

defaultproperties
{
}
