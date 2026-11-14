//=============================================================================
// RIChoiceHudLayout
// Settings > Interface: HUD Layout. Where the rebuilt HUD's pieces sit, in
// any UI style:
//   Reimagined  compass top centre, belt bottom centre, weapon bottom right,
//               messages on the left
//   Vanilla     the original game's places: compass under the body monitor,
//               messages and transmissions along the top beside it, weapon
//               bottom left, belt bottom right, aug bar down the right edge
// Only the arrangement changes; every new HUD feature works in both.
//=============================================================================
class RIChoiceHudLayout extends MenuUIChoiceEnum;

function LoadSetting()
{
	SetValue(Class'RIRootWindow'.default.HudLayout);
}

function SaveSetting()
{
	local RIRootWindow R;
	local bool bChanged;

	bChanged = (Class'RIRootWindow'.default.HudLayout != GetValue());
	Class'RIRootWindow'.default.HudLayout = GetValue();
	// Switching layout sets HUD Depth to suit it: the Vanilla layout's
	// corner pieces stay flat (Motion only), the Reimagined layout gets its
	// 3D Tilt + Motion back. Only on a change, so a Depth picked afterwards
	// is kept when the screen's rows are saved.
	// (Vanilla+ stays flat whatever the layout)
	if (bChanged && (Class'RIRootWindow'.default.ScreenStyle != 1))
	{
		Class'RIRootWindow'.default.bHudSway = True;
		if (GetValue() == 1)
			Class'RIRootWindow'.default.HudTilt = 0;
		else
			Class'RIRootWindow'.default.HudTilt = 1;
		RefreshRow('RIChoiceHudSway');
	}
	R = RIRootWindow(GetRootWindow());
	if (R != None)
	{
		R.HudLayout = GetValue();
		R.bHudSway = Class'RIRootWindow'.default.bHudSway;
		R.HudTilt = Class'RIRootWindow'.default.HudTilt;
		R.SaveConfig();
		if (R.hud != None)
			R.hud.ConfigurationChanged();
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

// Saved the moment it changes, so the HUD behind the menu moves at once
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
}

defaultproperties
{
     enumText(0)="Reimagined"
     enumText(1)="Vanilla"
     HelpText="Where the HUD's pieces sit. Reimagined: compass at the top centre, belt bottom centre, weapon bottom right. Vanilla: the original game's layout, with the compass under the body monitor, messages along the top, weapon bottom left and belt bottom right. Every new HUD feature works in both. Switching sets HUD Depth to suit the layout: Motion for Vanilla, 3D Tilt + Motion for Reimagined."
     actionText="HUD |&Layout"
}
