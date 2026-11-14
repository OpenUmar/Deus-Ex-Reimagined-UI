//=============================================================================
// RIChoiceScreenStyle
// Settings > Interface: the rebuilt in-game screens drawn Sleek (hairlines) or
// Vanilla+ (the original persona textures, 4x HD).
//=============================================================================
class RIChoiceScreenStyle extends MenuUIChoiceEnum;

function LoadSetting()
{
	SetValue(Class'RIRootWindow'.default.ScreenStyle);
}

function SaveSetting()
{
	local RIRootWindow R;
	local bool bChanged;

	bChanged = (Class'RIRootWindow'.default.ScreenStyle != GetValue());
	Class'RIRootWindow'.default.ScreenStyle = GetValue();
	// Conversation bars follow the style when it changes: on for Vanilla+
	// (as the original game played), off for the others. Conversation Bars
	// can still override it afterwards.
	if (bChanged)
	{
		Class'RIRootWindow'.default.bConBars = (GetValue() == 1);
		RefreshRow('RIChoiceConBars');
		// HUD Depth follows too: Vanilla+ is flat (no tilt, no motion);
		// the others get the layout's own (Motion for the Vanilla layout,
		// 3D Tilt + Motion for Reimagined)
		if (GetValue() == 1)
		{
			Class'RIRootWindow'.default.bHudSway = False;
			Class'RIRootWindow'.default.HudTilt = 0;
		}
		else
		{
			Class'RIRootWindow'.default.bHudSway = True;
			if (Class'RIRootWindow'.default.HudLayout == 1)
				Class'RIRootWindow'.default.HudTilt = 0;
			else
				Class'RIRootWindow'.default.HudTilt = 1;
		}
		RefreshRow('RIChoiceHudSway');
	}
	Log("RI: screen style saved as " $ GetValue());
	R = RIRootWindow(GetRootWindow());
	if (R != None)
	{
		R.ScreenStyle = GetValue();
		R.bConBars = Class'RIRootWindow'.default.bConBars;
		R.bHudSway = Class'RIRootWindow'.default.bHudSway;
		R.HudTilt = Class'RIRootWindow'.default.HudTilt;
		R.SaveConfig();
	}
}

// Another row on this screen shows its setting again (after this one changed it)
function RefreshRow(name RowClass)
{
	local Window W;

	if (GetParent() == None)
		return;
	for (W = GetParent().GetTopChild(); W != None; W = W.GetLowerSibling())
		if (W.IsA(RowClass) && (MenuUIChoice(W) != None))
			MenuUIChoice(W).LoadSetting();
}

// Saved the moment it changes, so leaving Settings any way keeps it
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
	SetValue(2);
}

defaultproperties
{
     enumText(0)="Sleek"
     enumText(1)="Vanilla+"
     enumText(2)="Modern"
     HelpText="Modern (default): the Sleek layouts in digitized chamfered frames, with a Human Revolution style belt. Sleek: hairline panels. Vanilla+: the same updated screens drawn with the original game's panel frames, highlights and buttons in HD. Menus and Settings are the same in all three."
     actionText="|&UI style"
}
