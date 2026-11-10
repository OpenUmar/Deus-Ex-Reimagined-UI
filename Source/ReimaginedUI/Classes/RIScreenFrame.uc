//=============================================================================
// RIScreenFrame
// Added behind every restyled AE screen. Draws the panel, glowing border and
// title in place of AE's frame, fades it in, and re-skins the screen's
// widgets every half second so anything AE creates later is restyled too.
//=============================================================================
class RIScreenFrame extends Window;

var MenuUIWindow Screen;
var float Age;
var float NextSkin;
var bool  bEmbedded;        // shown inside the settings layout
var bool  bReady;
var bool  bSkinned;

// Sliding highlight that follows the focused option row
var float HX, HY, HW, HH;   // current rectangle (frame coordinates)
var float HA;               // opacity 0..1
var bool  bHasHighlight;

event InitWindow()
{
	Super.InitWindow();
	bTickEnabled = True;
}

event WindowReady()
{
	Super.WindowReady();
	// Only flag readiness here. WindowReady runs INSIDE the engine's ready pass
	// (XRootWindow::InitializeWindows, called from PostRender), which walks the
	// visible tree once. Hiding or focusing here fires AE events that can SHOW
	// a window behind the walk; it is then counted but never readied, and the
	// engine stops with "initCount == 0". All hiding happens later, outside it.
	bReady = True;
}

event Tick(float deltaSeconds)
{
	local Window P;

	Age += deltaSeconds;

	// Hiding waits for WindowReady: the engine readies new windows by walking
	// only VISIBLE ones, so hiding a window before it is ready leaves it
	// uncounted and trips "initCount == 0" (ExtRoot.cpp, InitializeWindows).
	if (bReady && !bSkinned && (Screen != None))
	{
		Class'RISkin'.static.SkinScreen(Screen);
		bSkinned = True;
		if (RIRootWindow(GetRootWindow()) != None)
			RIRootWindow(GetRootWindow()).GuardInitCount("Frame");
	}

	// AE screens lay out their own children, so size ourselves to the screen
	P = GetParent();
	if ((P != None) && ((width != P.width) || (height != P.height)))
		SetConfiguration(0, 0, P.width, P.height);

	UpdateHighlight(deltaSeconds);

	if (Age >= NextSkin)
	{
		Class'RISkin'.static.SkinScreen(Screen);     // re-hides AE's frame pieces too, once they're ready
		NextSkin = Age + 0.5;
	}
}

// The option row containing the focused control, if it belongs to our screen
function Window FocusedRow()
{
	local Window F, W;

	F = GetRootWindow().GetFocusWindow();
	if (F == None)
		return None;

	if (MenuUIChoice(F) != None)
		W = F;
	else if ((F.GetParent() != None) && (MenuUIChoice(F.GetParent()) != None))
		W = F.GetParent();
	else
		return None;

	// Make sure it is inside this screen
	for (F = W; F != None; F = F.GetParent())
		if (F == Screen)
			return W;
	return None;
}

function UpdateHighlight(float dt)
{
	local Window Row;
	local float tx, ty, k;

	Row = FocusedRow();
	if (Row == None)
	{
		HA = FMax(0, HA - dt * 6.0);
		return;
	}

	ConvertCoordinates(Row, 0, 0, Self, tx, ty);
	tx -= 4;
	if (!bHasHighlight || (HA <= 0.01))
	{
		// Appear in place rather than flying in from the last spot
		HX = tx;  HY = ty;  HW = Row.width + 8;  HH = Row.height;
		bHasHighlight = True;
	}
	else
	{
		k = FMin(1.0, dt * 16.0);
		HX += (tx - HX) * k;
		HY += (ty - HY) * k;
		HW += (Row.width + 8 - HW) * k;
		HH += (Row.height - HH) * k;
	}
	HA = FMin(1.0, HA + dt * 6.0);
}

event DrawWindow(GC gc)
{
	local float a, pulse, x0, y0, x1, y1, pad;
	local Window bar;

	Class'RITheme'.static.SetMode(1);

	if ((Screen == None) || (Screen.winClient == None))
		return;

	a = Class'RIUtil'.static.Phase(Age, 0.0, 0.3);
	pulse = 0.85 + 0.15 * Sin(Age * 2.0);

	// Panel bounds: client area plus the action button bar
	x0 = Screen.winClient.x;
	y0 = Screen.winClient.y;
	x1 = x0 + Screen.winClient.width;
	y1 = y0 + Screen.winClient.height;

	bar = Screen.winButtonBar;
	if ((bar != None) && bar.IsVisible())
	{
		x0 = FMin(x0, bar.x);
		x1 = FMax(x1, bar.x + bar.width);
		y1 = FMax(y1, bar.y + bar.height);
	}

	pad = 6;
	x0 -= pad;  y0 -= pad;
	x1 += pad;  y1 += pad;

	gc.EnableSmoothing(True);

	// Inside settings the layout already provides the panel: skip ours
	if (!bEmbedded)
		DrawPanel(gc, a, pulse, x0, y0, x1, y1);

	DrawHighlightAndTitle(gc, a, x0, y0, x1);
}

function DrawPanel(GC gc, float a, float pulse, float x0, float y0, float x1, float y1)
{
	if (Class'RIVP'.static.InMenus())
	{
		Class'RIVP'.static.Black(gc, x0 + 3, y0 + 3, x1 - x0 - 6, y1 - y0 - 6);
		Class'RIVP'.static.Frame(gc, x0 - 6, y0 - 6, x1 - x0 + 12, y1 - y0 + 12, 14, a);
		return;
	}
	// Darken, then a faint navy wash
	gc.SetStyle(DSTY_Modulated);
	gc.DrawStretchedTexture(x0, y0, x1 - x0, y1 - y0, 0, 0, 16, 16, Texture'ReimaginedUI.UI.RI_Dark');
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(8 * a, 10 * a, 38 * a));
	Class'RIText'.static.Fill(gc, x0, y0, x1 - x0, y1 - y0);

	// Hairline border with a faint outer echo
	Class'RIText'.static.Box(gc, x0, y0, x1 - x0, y1 - y0, Class'RIUtil'.static.Col(80 * a * pulse, 84 * a * pulse, 190 * a * pulse));
	Class'RIText'.static.Box(gc, x0 - 2, y0 - 2, x1 - x0 + 4, y1 - y0 + 4, Class'RIUtil'.static.Col(24 * a, 26 * a, 80 * a));

}

function DrawHighlightAndTitle(GC gc, float a, float x0, float y0, float x1)
{
	// Sliding highlight under the focused row (snapped to whole pixels)
	if ((HA > 0.01) && Class'RIVP'.static.InMenus())
	{
		HX = Class'RIText'.static.Snap(HX);
		HY = Class'RIText'.static.Snap(HY);
		Class'RIVP'.static.Btn(gc, HX, HY, HW, HH, True, HA * a);
	}
	else if (HA > 0.01)
	{
		HX = Class'RIText'.static.Snap(HX);
		HY = Class'RIText'.static.Snap(HY);
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(Class'RIUtil'.static.Col(34 * HA * a, 36 * HA * a, 104 * HA * a));
		gc.DrawStretchedTexture(HX, HY, HW, HH, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_Glow');
		Class'RIText'.static.Box(gc, HX, HY, HW, HH, Class'RIUtil'.static.Col(120 * HA * a, 124 * HA * a, 210 * HA * a));
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(Class'RIUtil'.static.Col(200 * HA * a, 204 * HA * a, 255 * HA * a));
		Class'RIText'.static.Fill(gc, HX, HY, 1.5, HH);
	}

	// Title, in the space AE's title bar used to occupy
	if (bEmbedded)
		Class'RIText'.static.Draw(gc, Class'RIFontSmall', x0 + 2, y0 - 16, Caps(TitleText()),
			Class'RIUtil'.static.Col(95 * a, 200 * a, 255 * a));
	else
		Class'RIText'.static.Draw(gc, Class'RIFontHead', x0 + 2, y0 - 22, Caps(TitleText()),
			Class'RIUtil'.static.Col(232 * a, 234 * a, 255 * a));

	Class'RIText'.static.HLine(gc, x0, y0 - 3, 36, Class'RIUtil'.static.Col(166 * a, 170 * a, 255 * a));
}

// The text AE gave its (now hidden) title bar; message boxes set it at runtime
function string TitleText()
{
	if ((Screen.winTitle != None) && (Screen.winTitle.titleText != ""))
		return Screen.winTitle.titleText;
	if (Screen.title != "")
		return Screen.title;
	return "Confirm";
}

defaultproperties
{
}
