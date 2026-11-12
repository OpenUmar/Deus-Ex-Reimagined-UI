//=============================================================================
// RIVPlusArt
// Vanilla+ in-game screens: AE's own page (original layout, as on the VPlus
// artboards) with its background and border art drawn from the 4x HD
// remasters. Sits behind AE's widgets; AE's own low-res copies are switched
// off (texture count 0), and the same colours and draw styles AE would use
// are applied, so only the resolution changes.
//=============================================================================
class RIVPlusArt extends Window;

var PersonaScreenBaseWindow Screen;

function AttachTo(PersonaScreenBaseWindow NewScreen)
{
	Screen = NewScreen;
	SetSensitivity(False);
	SetConfiguration(0, 0, Screen.width, Screen.height);
	Lower();
	TakeOver();
}

// Stop AE drawing its own copies (re-applied each tick; AE resets them on resize)
function TakeOver()
{
	if (Screen.winClient != None)
		Screen.winClient.textureCount = 0;
	if (Screen.winClientBorder != None)
		Screen.winClientBorder.textureCount = 0;
}

event Tick(float deltaSeconds)
{
	if (Screen == None)
		return;
	if ((width != Screen.width) || (height != Screen.height))
		SetConfiguration(0, 0, Screen.width, Screen.height);
	TakeOver();
}

function DrawSet(GC gc, Window W, Texture T0, Texture T1, Texture T2, Texture T3, Texture T4, Texture T5, int Cols)
{
	local int i, c, r;
	local Texture T;

	for (i = 0; i < 6; i++)
	{
		switch (i)
		{
			case 0: T = T0; break;
			case 1: T = T1; break;
			case 2: T = T2; break;
			case 3: T = T3; break;
			case 4: T = T4; break;
			case 5: T = T5; break;
		}
		if ((T == None) || (Cols <= 0))
			continue;
		c = i % Cols;
		r = i / Cols;
		Class'RIHD'.static.DrawStretched(gc, W.x + c * 256, W.y + r * 256, T.USize, T.VSize, 0, 0, T.USize, T.VSize, T);
	}
}

event DrawWindow(GC gc)
{
	local PersonaClientWindow C;
	local PersonaClientBorderWindow B;

	if (Screen == None)
		return;
	gc.EnableSmoothing(True);

	C = Screen.winClient;
	if (C != None)
	{
		gc.SetStyle(C.backgroundDrawStyle);
		gc.SetTileColor(C.colBackground);
		DrawSet(gc, C, Screen.clientTextures[0], Screen.clientTextures[1], Screen.clientTextures[2],
			Screen.clientTextures[3], Screen.clientTextures[4], Screen.clientTextures[5], Screen.clientTextureCols);
	}

	B = Screen.winClientBorder;
	if ((B != None) && B.bDrawBorder)
	{
		gc.SetStyle(B.borderDrawStyle);
		gc.SetTileColor(B.colBorder);
		DrawSet(gc, B, Screen.clientBorderTextures[0], Screen.clientBorderTextures[1], Screen.clientBorderTextures[2],
			Screen.clientBorderTextures[3], Screen.clientBorderTextures[4], Screen.clientBorderTextures[5], Screen.clientBorderTextureCols);
	}
}

defaultproperties
{
}
