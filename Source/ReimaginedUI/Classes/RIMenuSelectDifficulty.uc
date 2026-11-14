//=============================================================================
// RIMenuSelectDifficulty
// Full-screen difficulty selection in the settings layout style. AE's
// "GMDX Difficulty Information" pop-up is gone: that text now sits on the
// screen itself, with a description of whichever difficulty you hover or
// focus. Every selection rule (Realistic / Hardcore unlocks and their
// confirmations) is inherited from AE unchanged.
//=============================================================================
class RIMenuSelectDifficulty extends MenuSelectDifficulty;

var float AnimTime;
var int   ShownIndex;           // difficulty being described
var float DescAge;

// Layout (scaled from a 1080p design)
var float S;
var float FrameX, FrameY, FrameW, FrameH;
var float NavX, NavY, NavW, NavButtonH, NavGap;
var float InfoX, InfoY, InfoW, InfoH;

var localized string HeaderText;
var localized string InfoHeader;
var localized string DiffLabel;
var localized string DiffNames[5];
var localized string DiffTags[5];
var localized string DiffText[5];

event InitWindow()
{
	Super.InitWindow();
	SetWindowAlignments(HALIGN_Full, VALIGN_Full);
	bTickEnabled = True;
	ShownIndex = 1;
}

function CreateControls()
{
}

function CreateMenuButtons()
{
	local int i;
	local RIMenuButton btn;

	for (i = 0; i < arrayCount(buttonDefaults); i++)
	{
		if (ButtonNames[i] == "")
			break;

		btn = RIMenuButton(NewChild(Class'RIMenuButton'));
		btn.SetButtonText(ButtonNames[i]);
		btn.TextScale = 0.95;
		btn.Slot = i;
		winButtons[i] = btn;
	}
}

// AE showed its information box here; the text is on screen instead
event WindowReady()
{
	if (winButtons[1] != None)
		SetFocusWindow(winButtons[1]);
}

event ParentRequestedPreferredSize(bool bWidthSpecified, out float preferredWidth,
                                   bool bHeightSpecified, out float preferredHeight)
{
	preferredWidth  = root.width;
	preferredHeight = root.height;
}

function ConfigurationChanged()
{
	local int i;

	S = height / 1080.0;

	FrameX = 30 * S;
	FrameY = 30 * S;
	FrameW = width - 60 * S;
	FrameH = height - 60 * S;

	NavX = 70 * S;
	NavY = 160 * S;
	NavW = 360 * S;
	NavButtonH = 56 * S;
	NavGap = 10 * S;

	InfoX = NavX + NavW + 76 * S;
	InfoY = 160 * S;
	InfoW = FMin(900 * S, (width - 90 * S) - InfoX);
	InfoH = (height - 90 * S) - InfoY;

	for (i = 0; i < arrayCount(winButtons); i++)
	{
		if (winButtons[i] == None)
			continue;
		if (buttonDefaults[i].action == MA_Previous)
			winButtons[i].ConfigureChild(NavX, FrameY + FrameH - 40 * S - NavButtonH, NavW, NavButtonH);
		else
			winButtons[i].ConfigureChild(NavX, NavY + i * (NavButtonH + NavGap), NavW, NavButtonH);
	}
}

event Tick(float deltaSeconds)
{
	local int i, Hot;
	local float best;
	local Window F;

	AnimTime += deltaSeconds;
	DescAge += deltaSeconds;

	// Describe the hovered button, else the focused one; keep the last otherwise
	Hot = -1;
	best = 0.5;
	for (i = 0; i < 5; i++)
		if ((RIMenuButton(winButtons[i]) != None) && (RIMenuButton(winButtons[i]).HoverT > best))
		{
			best = RIMenuButton(winButtons[i]).HoverT;
			Hot = i;
		}
	if (Hot == -1)
	{
		F = root.GetFocusWindow();
		for (i = 0; i < 5; i++)
			if ((winButtons[i] != None) && (F == winButtons[i]))
				Hot = i;
	}
	if ((Hot != -1) && (Hot != ShownIndex))
	{
		ShownIndex = Hot;
		DescAge = 0;
	}

	for (i = 0; i < 5; i++)
		if (RIMenuButton(winButtons[i]) != None)
			RIMenuButton(winButtons[i]).bActive = (i == ShownIndex);
}

// ----------------------------------------------------------------------
// Drawing
// ----------------------------------------------------------------------

event DrawWindow(GC gc)
{
	local float a, da, pulse, hx, hy, hw, hh, x, y, w, h, tw;
	local int i;
	local Color Tag;
	local string Note;

	a = Class'RIUtil'.static.Phase(AnimTime, 0.0, 0.35);
	da = a * Class'RIUtil'.static.Phase(DescAge, 0.0, 0.25);
	pulse = 0.85 + 0.15 * Sin(AnimTime * 2.0);

	gc.EnableSmoothing(True);

	// Same frame as the settings layout
	// Darkening fades in (stepped: modulated drawing can't take a colour fade)
	Class'RISkin'.static.DrawDim(gc, 0, 0, width, height, 0.55 * a);
	Class'RISkin'.static.DrawDim(gc, FrameX, FrameY, FrameW, FrameH, 0.85 * a);
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(4 * a, 5 * a, 22 * a));
	Class'RIText'.static.Fill(gc, FrameX, FrameY, FrameW, FrameH);
	Class'RIText'.static.Box(gc, FrameX, FrameY, FrameW, FrameH, Class'RIUtil'.static.Col(80 * a * pulse, 84 * a * pulse, 190 * a * pulse));
	Class'RIText'.static.Box(gc, FrameX - 3 * S, FrameY - 3 * S, FrameW + 6 * S, FrameH + 6 * S, Class'RIUtil'.static.Col(24 * a, 26 * a, 80 * a));

	// Header
	hx = NavX;
	hy = 66 * S;
	hw = NavW + 76 * S + InfoW;
	hh = 54 * S;
	Class'RIText'.static.Draw(gc, Class'RIFontTitle', hx, hy + 6 * S, HeaderText, Class'RIUtil'.static.Col(236 * a, 238 * a, 255 * a), 0.62);
	Class'RIText'.static.HLine(gc, hx, hy + hh + 8 * S, hw, Class'RIUtil'.static.Col(44 * a, 48 * a, 128 * a));
	Class'RIText'.static.HLine(gc, hx, hy + hh + 8 * S, 48 * S, Class'RIUtil'.static.Col(170 * a, 176 * a, 255 * a));

	// Divider between the choices and the description
	Class'RIText'.static.VLine(gc, InfoX - 38 * S, InfoY, InfoH, Class'RIUtil'.static.Col(34 * a, 36 * a, 96 * a));

	// Selected difficulty: name, tag, description
	x = InfoX;
	y = InfoY;
	w = InfoW;
	i = Clamp(ShownIndex, 0, 4);

	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x, y, DiffLabel, Class'RIUtil'.static.Col(95 * da, 200 * da, 255 * da));
	y += 28 * S;
	Class'RIText'.static.Draw(gc, Class'RIFontTitle', x + (1.0 - da) * 10 * S, y, Caps(DiffNames[i]),
		Class'RIUtil'.static.Col(244 * da, 246 * da, 255 * da), 0.9);
	y += Class'RIText'.static.LineHeight(Class'RIFontTitle', 0.9) + 10 * S;

	// Tag pill (e.g. RECOMMENDED / LOCKED)
	if (DiffTags[i] != "")
	{
		if (i >= 3)
			Tag = Class'RIUtil'.static.Col(255 * da, 120 * da, 96 * da);
		else
			Tag = Class'RIUtil'.static.Col(95 * da, 200 * da, 255 * da);
		tw = Class'RIText'.static.Width(Class'RIFontSmall', DiffTags[i]) + 24 * S;
		Class'RIText'.static.Box(gc, x, y, tw, 26 * S, Tag);
		Class'RIText'.static.DrawIn(gc, Class'RIFontSmall', x, y, tw, 26 * S, DiffTags[i], Tag, 1);
		y += 26 * S + 22 * S;
	}

	h = Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x, y, w, Class'RIBase'.static.DifficultyText(i, DiffText[i]),
		Class'RIUtil'.static.Col(196 * da, 202 * da, 244 * da), 1.05, 1.45);
	y += h + 30 * S;

	// The base's general note (GMDX's), always visible at the bottom of the panel
	Note = Class'RIUtil'.static.PStr(Self, "InfoDescription");
	if (Note == "")
		return;
	h = Class'RIText'.static.DrawWrapped(None, Class'RIFontBody', 0, 0, w - 48 * S, Note,
		Class'RIUtil'.static.Col(0, 0, 0), 0.92, 1.4);
	y = FMax(y, InfoY + InfoH - h - 80 * S);
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(12 * a, 13 * a, 40 * a));
	Class'RIText'.static.Fill(gc, x, y, w, h + 76 * S);
	Class'RIText'.static.Box(gc, x, y, w, h + 76 * S, Class'RIUtil'.static.Col(44 * a, 48 * a, 128 * a));
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Col(205 * a, 210 * a, 255 * a));
	Class'RIText'.static.Fill(gc, x, y, 1.5, h + 76 * S);
	Class'RIText'.static.Draw(gc, Class'RIFontSmall', x + 24 * S, y + 20 * S, InfoHeader, Class'RIUtil'.static.Col(95 * a, 200 * a, 255 * a));
	Class'RIText'.static.DrawWrapped(gc, Class'RIFontBody', x + 24 * S, y + 48 * S, w - 48 * S, Note,
		Class'RIUtil'.static.Col(176 * a, 182 * a, 232 * a), 0.92, 1.4);
}

defaultproperties
{
     HeaderText="SELECT DIFFICULTY"
     InfoHeader="GMDX DIFFICULTY INFORMATION"
     DiffLabel="DIFFICULTY"
     DiffNames(0)="Easy"
     DiffNames(1)="Medium"
     DiffNames(2)="Hard"
     DiffNames(3)="Realistic"
     DiffNames(4)="Hardcore"
     DiffTags(1)="RECOMMENDED"
     DiffTags(3)="FOR VETERANS"
     DiffTags(4)="FOR VETERANS"
     DiffText(0)="For players who are here mainly for the story. Combat and detection are at their most forgiving, so mistakes are rarely fatal."
     DiffText(1)="The intended first playthrough of GMDX. Stealth, combat and exploration are balanced so that every approach is viable and none is free."
     DiffText(2)="For players who already know GMDX. Enemies are more dangerous and more perceptive, and careless play is punished quickly."
     DiffText(3)="A testing challenge where a few shots can end you. Not recommended for those new to GMDX. You will be asked to confirm."
     DiffText(4)="Realistic damage with save points instead of manual saving. Additional rules include no console access, real-time inventory use, greater stamina drain, no weapon auto-reload and less ammo. You will be asked to confirm."
}
