//=============================================================================
// RIMenuButton
// Animated main-menu button. Keeps all of MenuUIMenuButtonWindow's input,
// focus, sound and sensitivity behaviour; replaces only the drawing.
//
//  - Cascades in: slides from the left and fades up, staggered by Slot
//  - Hover/focus: glow and outline ease in and out smoothly (no snapping)
//  - Press: brief flash
//=============================================================================
class RIMenuButton extends MenuUIMenuButtonWindow;

var int   Slot;            // position in the list, drives the stagger
var bool  bAlignRight;     // used for the Exit button
var float Age;             // seconds since creation
var float HoverT;          // 0 = idle, 1 = fully highlighted
var float PressT;          // flash on click, decays to 0
var bool  bActive;         // stays highlighted (current settings category)
var Class<RIFont> TextFont; // baked font for the label
var float TextScale;
var float IntroDelay;       // cascade timing (the pause menu uses a quicker one)
var float IntroStep;
var float IntroDur;
var float ParentFade;       // 1 = shown; the pause menu lowers it when closing
var bool  bHoverExternal;   // hovered, as reported by the screen on top (settings)

event InitWindow()
{
	Super.InitWindow();
	bTickEnabled = True;
}

event Tick(float deltaSeconds)
{
	local float target;

	Age += deltaSeconds;

	SetButtonMetrics();
	if (bActive || bHoverExternal || (textColorIndex == 1) || (textColorIndex == 2))
		target = 1.0;
	else
		target = 0.0;

	// Frame-rate independent ease toward the target
	HoverT += (target - HoverT) * FMin(1.0, deltaSeconds * 12.0);

	if (textColorIndex == 2)
		PressT = 1.0;
	else
		PressT = FMax(0.0, PressT - deltaSeconds * 4.0);
}

event DrawWindow(GC gc)
{
	local float s, appear, off, glowW, h, k, ts, avail, tw;
	local Color idleText, hotText, txt;

	SetButtonMetrics();

	s = height / 50.0;

	// Stagger: main list starts at 0.35 s, 55 ms apart; Exit arrives last
	appear = Class'RIUtil'.static.Phase(Age, IntroDelay + Slot * IntroStep, IntroDur) * ParentFade;
	if (appear <= 0.0)
		return;

	off = -40.0 * s * (1.0 - appear);
	if (bAlignRight)
		off = -off;
	h = height;

	gc.EnableSmoothing(True);

	// Highlight: soft gradient grows from the left, hairline outline, thin accent bar
	k = HoverT * appear;
	if ((k > 0.01) && Class'RIVP'.static.InMenus())
		Class'RIVP'.static.Btn(gc, off, 0, width, h, PressT > 0.3, k);
	else if (k > 0.01)
	{
		gc.SetStyle(DSTY_Translucent);
		glowW = width;
		gc.SetTileColor(Class'RIUtil'.static.Col(34 * k + 40 * PressT, 36 * k + 40 * PressT, 104 * k + 40 * PressT));
		if (bAlignRight)
			gc.DrawStretchedTexture(off + width - glowW, 0, glowW, h, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');
		else
			gc.DrawStretchedTexture(off, 0, glowW, h, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');

		Class'RIText'.static.Box(gc, off, 0, width, h, Class'RIUtil'.static.Col(120 * k, 124 * k, 210 * k));
		gc.SetTileColor(Class'RIUtil'.static.Col(200 * k, 204 * k, 255 * k));
		if (bAlignRight)
			Class'RIText'.static.Fill(gc, off + width - 1.5, 0, 1.5, h);
		else
			Class'RIText'.static.Fill(gc, off, 0, 1.5, h);
	}

	// Label: idle lavender -> white on hover, dim when unavailable
	idleText = Class'RIUtil'.static.Col(170, 176, 226);
	hotText  = Class'RIUtil'.static.Col(255, 255, 255);
	if (!bIsSensitive)
		txt = Class'RIUtil'.static.Col(70, 74, 120);
	else
		txt = Class'RIUtil'.static.Mix(idleText, hotText, HoverT);
	if (bActive)
		txt = Class'RIUtil'.static.Col(255, 255, 255);

	// Shrink long labels (e.g. KEYBOARD/MOUSE) to fit instead of clipping
	ts = TextScale;
	avail = width - 24 * s;
	tw = Class'RIText'.static.Width(TextFont, Caps(buttonText), ts);
	if ((tw > avail) && (tw > 0))
		ts = ts * avail / tw;

	if (bAlignRight)
		Class'RIText'.static.DrawIn(gc, TextFont, off, 0, width - 12 * s, h,
			Caps(buttonText), Class'RIUtil'.static.Scale(txt, appear), 2, ts);
	else
		Class'RIText'.static.DrawIn(gc, TextFont, off + 12 * s, 0, width, h,
			Caps(buttonText), Class'RIUtil'.static.Scale(txt, appear), 0, ts);
}

defaultproperties
{
     TextFont=Class'RIFontHead'
     TextScale=1.000000
     IntroDelay=0.350000
     IntroStep=0.055000
     IntroDur=0.450000
     ParentFade=1.000000
}
