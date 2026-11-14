//=============================================================================
// RIChoiceHudSway
// Settings > Interface: HUD Depth. Two effects that make the HUD read as a
// layer in front of the eyes, chosen together on one row:
//   motion  the HUD trails the view slightly as you look around and glides
//           back (RIRootWindow.bHudSway)
//   3D tilt the side panels (vitals and messages on the left, weapon on the
//           right) are turned toward the eye in perspective, as in Human
//           Revolution / Mankind Divided (RIRootWindow.HudTilt; drawn by
//           RINative.dll)
// Flat keeps the HUD still and square.
//=============================================================================
class RIChoiceHudSway extends MenuUIChoiceEnum;

// Row value <-> settings: 0 Flat, 1 Motion, 2 3D tilt, 3 3D tilt + motion, 4 deep tilt + motion
function LoadSetting()
{
	local int T;
	local bool bSway;

	T = Class'RIRootWindow'.default.HudTilt;
	bSway = Class'RIRootWindow'.default.bHudSway;
	if (T >= 2)
		SetValue(4);
	else if (T == 1)
		SetValue(2 + int(bSway));
	else
		SetValue(int(bSway));
}

function SaveSetting()
{
	local RIRootWindow R;
	local int V, T;
	local bool bSway;

	V = GetValue();
	bSway = (V == 1) || (V >= 3);
	T = 0;
	if (V == 2 || V == 3)
		T = 1;
	else if (V >= 4)
		T = 2;
	Class'RIRootWindow'.default.bHudSway = bSway;
	Class'RIRootWindow'.default.HudTilt = T;
	R = RIRootWindow(GetRootWindow());
	if (R != None)
	{
		R.bHudSway = bSway;
		R.HudTilt = T;
		R.SaveConfig();
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

function ResetToDefault()
{
	SetValue(3);
}

defaultproperties
{
     enumText(0)="Flat"
     enumText(1)="Motion"
     enumText(2)="3D Tilt"
     enumText(3)="3D Tilt + Motion"
     enumText(4)="Deep Tilt + Motion"
     HelpText="Depth for the HUD. Motion: the HUD trails your view slightly and glides back. 3D Tilt: the side panels turn toward you in perspective. The crosshair never moves."
     actionText="HUD |&Depth"
}
