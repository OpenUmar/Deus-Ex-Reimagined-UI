//=============================================================================
// RIKeypadButton
// A key on the rebuilt keypad: AE's button (same press logic, same number
// mapping), drawn natively. Sleek: dark cell with a hairline gold edge that
// warms on hover and floods on press (Sleek style).
//=============================================================================
class RIKeypadButton extends HUDKeypadButton;

var bool  bHover;
var float Flash;        // 1 on press, fades out (keyboard presses light the key too)
var float LastClock;

event MouseEnteredWindow()
{
	Super.MouseEnteredWindow();
	bHover = True;
}

event MouseLeftWindow()
{
	Super.MouseLeftWindow();
	bHover = False;
}

event DrawWindow(GC gc)
{
	local RIKeypadWindow kp;
	local float s, ts, now, dt, lit;
	local string L;
	local Color edge, txt;
	local Texture KT;

	kp = RIKeypadWindow(GetParent());
	if (kp == None)
	{
		Super.DrawWindow(gc);
		return;
	}
	Class'RITheme'.static.SetMode(2);
	s  = kp.UIS;
	ts = s * 2.0;

	now = kp.Age;
	dt = FClamp(now - LastClock, 0, 0.1);
	LastClock = now;
	if (bButtonPressed)
		Flash = 1.0;
	else
		Flash = FMax(0, Flash - dt * 4.0);

	lit = Flash;
	if (bHover && (lit < 0.35))
		lit = 0.35;
	L = kp.IndexToString(num);

	Class'RIVP'.static.Dim(gc, 0, 0, width, height);
	Class'RIVP'.static.Dim(gc, 0, 0, width, height);
	Class'RISkin'.static.FillC(gc, 0, 0, width, height, Class'RIUtil'.static.Col(18 + 40 * lit, 14 + 33 * lit, 6 + 15 * lit));
	if (Flash > 0)
		Class'RISkin'.static.GlowC(gc, 0, 0, width, height, 10 * s, Class'RIVP'.static.Acc(0.25 * Flash));
	edge = Class'RIUtil'.static.Mix(Class'RIUtil'.static.Col(92, 77, 37), Class'RIUtil'.static.Col(230, 195, 117), lit);
	if (Class'RIVP'.static.On())
	{
		// Vanilla+: the original key (HUDKeypadButton_*, its art in the top
		// 25 x 27 of the texture), pressed art while held, lit on hover
		if (bButtonPressed)
			KT = Texture'DeusExUI.UserInterface.HUDKeypadButton_Pressed';
		else
			KT = Texture'DeusExUI.UserInterface.HUDKeypadButton_Normal';
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(Class'RIUtil'.static.Mix(Class'RIUtil'.static.Col(150, 150, 150), Class'RIUtil'.static.Col(255, 255, 255), lit));
		Class'RIHD'.static.DrawStretched(gc, 0, 0, width, height, 0, 0, KT.USize * 100.0 / 128.0, KT.VSize * 108.0 / 128.0, KT);
	}
	else
	{
		Class'RIText'.static.Box(gc, 0, 0, width, height, edge);
		// a short accent tick in the top-left corner, as on the persona cells
		Class'RISkin'.static.FillC(gc, 0, 0, 14 * s, 2 * s, edge);
	}

	if (bIsSensitive)
		txt = Class'RIUtil'.static.Mix(Class'RIUtil'.static.Col(230, 195, 117), Class'RIUtil'.static.Col(255, 246, 214), lit);
	else
		txt = Class'RIUtil'.static.Col(90, 75, 36);
	// symbol keys (< C > * #) read smaller than the digits
	if ((num == 9) || (num == 11))
		Class'RIText'.static.DrawIn(gc, Class'RIFontHead', 0, Flash * 2 * s, width, height, L, txt, 1, 1.0 * ts);
	else
		Class'RIText'.static.DrawIn(gc, Class'RIFontTitle', 0, Flash * 2 * s, width, height, L, txt, 1, 0.85 * ts);
}

defaultproperties
{
}
