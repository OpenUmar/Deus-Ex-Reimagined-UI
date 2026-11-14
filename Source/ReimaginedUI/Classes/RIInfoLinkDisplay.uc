//=============================================================================
// RIInfoLinkDisplay
// AE's InfoLink window (all its logic: speaker, portrait, static, typed text,
// "message waiting") restyled for the rebuilt HUD: wider, a soft dark backing
// in place of the riveted box, a hairline-framed portrait and the original
// gold. With the HUD on Classic it draws exactly as AE's.
//=============================================================================
class RIInfoLinkDisplay extends HUDInfoLinkDisplay;

var bool bDLIcon;      // the DataLink icon is up (drawn here, centred and scaled)
var int   ColStyle;     // UI style and HUD theme the text colours were last made for
var bool  bColHud;
var float ColHue;

function bool RIOn()
{
	return (RIDeusExHUD(GetParent()) != None) && RIDeusExHUD(GetParent()).bRI;
}

function Color Col(int R, int G, int B)
{
	return Class'RIUtil'.static.Col(R, G, B);
}

event InitWindow()
{
	Super.InitWindow();
	if (RIOn())
		Relayout();
}

function Relayout()
{
	// Everything kept inside the box art's frame with a margin: its line runs
	// round the window's edge, so content starts 20+ in from every side.
	// Five rows of text; portrait centred down the left.
	SetSize(520, 114);
	winPortrait.SetPos(22, 25);
	winStatic.SetPos(22, 25);
	winName.SetSize(260, 15);
	winName.SetPos(104, 15);
	winQueued.SetSize(200, 15);
	winQueued.SetPos(298, 15);
	winLine.SetSize(394, 1);
	winLine.SetPos(104, 32);
	winText.SetPos(104, 38);
	winText.SetTextSize(52, 5);
	Recolour();
}

// The text colours are set once on the child windows, outside any draw, so
// the HUD theme is applied here explicitly (mode 2): Vanilla+ turns the gold
// to the original game's grey, and a chosen HUD theme recolours it as it
// does the rest of the HUD.
function Recolour()
{
	local int OldMode;

	if (winName == None)
		return;
	OldMode = Class'RITheme'.default.Mode;
	Class'RITheme'.static.SetMode(2);
	winName.SetTextColor(Col(255, 241, 194));
	winQueued.SetTextColor(Col(143, 208, 224));
	winLine.SetTileColor(Col(126, 105, 50));
	winText.SetFontColor(Col(230, 195, 117));
	winText.SetCursorColor(Col(242, 211, 107));
	Class'RITheme'.static.SetMode(OldMode);
	ColStyle = Class'RIRootWindow'.default.ScreenStyle;
	bColHud = Class'RITheme'.default.bHudOn;
	ColHue = Class'RITheme'.default.HudHue;
}

// Re-make the text colours when the UI style or HUD theme has changed
function CheckColours()
{
	if ((ColStyle != Class'RIRootWindow'.default.ScreenStyle)
		|| (bColHud != Class'RITheme'.default.bHudOn)
		|| (ColHue != Class'RITheme'.default.HudHue))
		Recolour();
}

event StyleChanged()
{
	Super.StyleChanged();
	if (RIOn())
		Recolour();
}

// Soft dark backing: darkest in the middle, no hard edges
// While a transmission is incoming the original blinks the DataLink icon on
// and off (DataLinkPlay), which leaves the box empty half the time. Keep it on.
// The icon itself is drawn in DrawBorder, scaled into the portrait box:
// the window's own background draws the texture at its native size in the
// corner (with the HD set that looked broken)
function ShowDatalinkIcon(bool bShow)
{
	if (!RIOn())
	{
		bDLIcon = False;
		Super.ShowDatalinkIcon(bShow);
		return;
	}
	Super.ShowDatalinkIcon(True);
	winPortrait.SetBackground(None);
	bDLIcon = True;
}

function ShowPortrait()
{
	bDLIcon = False;
	Super.ShowPortrait();
}

function DrawBackground(GC gc)
{
	local int i;
	local float inX, inY;

	if (!RIOn())
	{
		Super.DrawBackground(gc);
		return;
	}
	CheckColours();
	if (Class'RIVP'.static.On())
	{
		// the HUD corners board's InfoLink box, stretched so its frame runs
		// round this window (the box sits at 20,23 - 868,238 in the art)
		Class'RITheme'.static.SetMode(2);
		// a soft shade with no edges (a rectangle showed as a box inside the frame)
		gc.SetStyle(DSTY_Modulated);
		Class'RIText'.static.Tex(gc, -width * 0.08, -height * 0.25, width * 1.16, height * 1.5, 0, 0, 256, 64, Texture'ReimaginedUI.UI.RI_ShadeC');
		gc.SetStyle(DSTY_Translucent);
		gc.SetTileColor(Class'RIVP'.static.Acc(1));
		Class'RIText'.static.Tex(gc, -20 * width / 848.0, -23 * height / 215.0, 896 * width / 848.0, 256 * height / 215.0,
			0, 0, 896, 256, Texture'ReimaginedUI.VPlus.VPH_Info');
		return;
	}
	for (i = 0; i < 7; i++)
	{
		inX = i * width * 0.05;
		inY = i * 7;
		if (height - inY * 2 <= 2)
			break;
		Class'RISkin'.static.DrawDim(gc, inX, inY, width - inX * 2, height - inY * 2, 0.12);
	}
}

// Hairline frame round the portrait, a short gold rule along the top
function DrawBorder(GC gc)
{
	if (!RIOn())
	{
		Super.DrawBorder(gc);
		return;
	}
	if (bDLIcon)
		DrawDLIcon(gc);
	if (Class'RIVP'.static.On())
	{
		Class'RIVP'.static.Inset(gc, 20, 23, 68, 68, 1);
		return;
	}
	Class'RIText'.static.Box(gc, 20, 23, 68, 68, Col(126, 105, 50));
	Class'RIText'.static.HLine(gc, 22, 4, 140, Col(126, 105, 50));
}

function DrawDLIcon(GC gc)
{
	local Texture T;

	// the icon only fills the top-middle quarter of its texture (x 1/4..3/4,
	// y 0..1/2): crop to it so it sits centred and fills the portrait frame
	// (frame 20..88 x 23..91, centre 54, 57)
	T = Texture'DeusExUI.UserInterface.DataLinkIcon';
	gc.SetStyle(DSTY_Masked);
	gc.SetTileColor(Col(255, 255, 255));
	Class'RIHD'.static.DrawStretched(gc, 54 - 29, 57 - 29, 58, 58, T.USize * 0.25, 0, T.USize * 0.5, T.VSize * 0.5, T);
}

defaultproperties
{
}
