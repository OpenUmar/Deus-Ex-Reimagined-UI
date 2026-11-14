//=============================================================================
// RITitleCard
// "Press any key" title card, shown once per launch over the main menu on
// the title map. Covers the menu completely (and takes its input) until a
// key or click, then fades away and restarts the menu's intro animation.
//=============================================================================
class RITitleCard extends Window;

var RIMenuMain Menu;
var float Age, LeaveT;
var bool  bLeaving, bReady, bDone;
var float S;

var bool bShown;        // default.bShown: once per launch

var localized string PressText;
var localized string CreditText;

const LeaveTime = 0.45;

event InitWindow()
{
	Super.InitWindow();
	SetSelectability(True);
	bTickEnabled = True;
	Class'RITitleCard'.default.bShown = True;
}

event WindowReady()
{
	Super.WindowReady();
	bReady = True;      // focus is taken in Tick, outside the engine's ready pass
}

function Dismiss()
{
	if (bLeaving)
		return;
	bLeaving = True;
	LeaveT = 0;
	PlaySound(Sound'Menu_OK', 0.35);
}

event bool VirtualKeyPressed(EInputKey key, bool bRepeat)
{
	if (bRepeat || (key == IK_Alt) || (key == IK_Shift) || (key == IK_Ctrl))
		return True;
	// Alt+Enter, Ctrl+F10 and the like stay with the engine / debug overlay
	if (IsKeyDown(IK_Alt) || IsKeyDown(IK_Ctrl))
		return False;
	Dismiss();
	return True;
}

event bool KeyPressed(string key)
{
	return True;
}

event bool MouseButtonPressed(float pointX, float pointY, EInputKey button, int numClicks)
{
	Dismiss();
	return True;
}

event bool MouseButtonReleased(float pointX, float pointY, EInputKey button, int numClicks)
{
	return True;
}

event Tick(float deltaSeconds)
{
	Age += deltaSeconds;

	if (Menu != None)
		SetConfiguration(0, 0, Menu.width, Menu.height);

	if (bReady && !bLeaving && (GetRootWindow().GetFocusWindow() != Self))
		SetFocusWindow(Self);

	if (bLeaving && !bDone)
	{
		LeaveT += deltaSeconds;
		if (LeaveT >= LeaveTime)
		{
			bDone = True;
			bTickEnabled = False;
			if (Menu != None)
				Menu.TitleCardDone();
			Hide();
		}
	}
}

event DrawWindow(GC gc)
{
	local float a, inT, aspect, artW, artH, artX, artY, pulse, y, tw, k;
	local string L;

	S = height / 1080.0;
	inT = Class'RIUtil'.static.Phase(Age, 0.0, 1.2);
	k = 1.0;
	if (bLeaving)
		k = 1.0 - Class'RIUtil'.static.Phase(LeaveT, 0.0, LeaveTime);
	a = inT * k;

	gc.EnableSmoothing(True);

	// Solid base so the menu underneath never shows through
	gc.SetStyle(DSTY_Normal);
	gc.SetTileColor(Class'RIUtil'.static.Col(255 * k, 255 * k, 255 * k));
	gc.DrawStretchedTexture(0, 0, width, height, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Navy');
	if (k < 0.999)
		Class'RISkin'.static.DrawDim(gc, 0, 0, width, height, 1.0 - k);

	// Key art covering the screen, anchored to the top, slow push-in
	aspect = Class'RISkin'.static.KeyArtAspect();
	if (width / height > aspect)
	{
		artW = width;
		artH = width / aspect;
	}
	else
	{
		artH = height;
		artW = height * aspect;
	}
	artW *= 1.0 + 0.04 * (1.0 - inT);
	artH *= 1.0 + 0.04 * (1.0 - inT);
	artX = (width - artW) * 0.5;
	artY = 0;
	Class'RISkin'.static.DrawKeyArt(gc, artX, artY, artW, artH);
	if (a < 0.999)
		Class'RISkin'.static.DrawDim(gc, 0, 0, width, height, 1.0 - a);

	// Darken the bottom (text) and the left edge (logo)
	gc.SetStyle(DSTY_Modulated);
	gc.DrawStretchedTexture(0, height * 0.45, width, height * 0.55, 0, 2, 8, 252, Texture'ReimaginedUI.UI.RI_FadeV');
	gc.DrawStretchedTexture(0, height * 0.62, width, height * 0.38, 0, 2, 8, 252, Texture'ReimaginedUI.UI.RI_FadeV');
	gc.DrawStretchedTexture(0, 0, width * 0.25, height, 2, 0, 252, 8, Texture'ReimaginedUI.UI.RI_FadeH');

	// Scanlines
	gc.SetStyle(DSTY_Modulated);
	gc.DrawPattern(0, 0, width, height, 0, 0, Texture'ReimaginedUI.UI.RI_Scan');

	// Logo, top left
	if (Menu != None)
		Menu.DrawLogo(gc, 96 * S, (72 - 16 * (1.0 - inT)) * S, 340 * S, 270 * S, a);

	// PRESS ANY KEY, breathing; brightens and widens as you press
	pulse = 0.55 + 0.45 * (0.5 + 0.5 * Sin(Age * 2.6));
	if (bLeaving)
		pulse = 1.0;
	pulse *= Class'RIUtil'.static.Phase(Age, 0.6, 0.6) * k;
	L = PressText;
	y = height - 150 * S - 40 * S;
	tw = Class'RIText'.static.Width(Class'RIFontTitle', L, 0.8);
	Class'RIText'.static.Draw(gc, Class'RIFontTitle', (width - tw) * 0.5, y, L,
		Class'RIUtil'.static.Col(255 * pulse, 255 * pulse, 255 * pulse), 0.8);

	// Fading rule under it
	y += Class'RIText'.static.LineHeight(Class'RIFontTitle', 0.8) + 16 * S;
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(166 * pulse, 170 * pulse, 255 * pulse));
	gc.DrawStretchedTexture((width - 340 * S) * 0.5, y, 340 * S, 1.5, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');

	// Footer
	if (Menu != None)
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', 96 * S, height - 64 * S, Caps(Class'RIBase'.static.VersionText(Menu, Menu.player)),
			Class'RIUtil'.static.Col(139 * a, 144 * a, 212 * a));
	tw = Class'RIText'.static.Width(Class'RIFontSmall', Caps(CreditText));
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', width - 96 * S - tw, height - 64 * S, Caps(CreditText),
		Class'RIUtil'.static.Col(139 * a, 144 * a, 212 * a));
}

defaultproperties
{
     PressText="PRESS ANY KEY"
     CreditText="UI concept after Tanit Mesa"
}
