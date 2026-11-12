//=============================================================================
// RIChoiceHDTextures
// Settings > Interface: draw the 4x Real-ESRGAN remasters from RIVanillaHD.u,
// or the original textures (also a quick test when the HD package misbehaves).
//=============================================================================
class RIChoiceHDTextures extends MenuUIChoiceEnum;

function LoadSetting()
{
	SetValue(int(Class'RIRootWindow'.default.bNoHDTextures));
}

function SaveSetting()
{
	local RIRootWindow R;

	Class'RIRootWindow'.default.bNoHDTextures = bool(GetValue());
	R = RIRootWindow(GetRootWindow());
	if (R != None)
	{
		R.bNoHDTextures = bool(GetValue());
		R.SaveConfig();
	}
}

function ResetToDefault()
{
	SetValue(0);
}

defaultproperties
{
     enumText(0)="HD (4x)"
     enumText(1)="Original"
     HelpText="Icons, portraits and Vanilla+ panels drawn from the 4x HD remasters, or from the game's original textures."
     actionText="|&Textures"
}
