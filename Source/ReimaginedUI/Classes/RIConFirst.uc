//=============================================================================
// RIConFirst
// First-person conversations (someone talks to you without the camera
// cutting away) for the rebuilt HUD: centred subtitles with the speaker's
// name above, the player's own lines a shade brighter, in place of the
// riveted box. AE's conversation logic fills this as before (name, text,
// appended text, clears); the text is recorded here and drawn in the new
// style. With the HUD on Classic it draws exactly as AE's.
//=============================================================================
class RIConFirst extends HUDConWindowFirst;

var string Speaker;
var string Lines[6];
var byte   LinePlayer[6];
var int    NumLines;

function bool RIOn()
{
	return (RIDeusExHUD(GetParent()) != None) && RIDeusExHUD(GetParent()).bRI;
}

function float K()
{
	if ((GetParent() != None) && (GetParent().height > 0))
		return GetParent().height / 1080.0;
	return 1.0;
}

function DisplayName(string text)
{
	Super.DisplayName(text);
	Speaker = text;
	AskParentForReconfigure();
}

function DisplayText(string text, Actor speakingActor)
{
	local int i;

	Super.DisplayText(text, speakingActor);
	if (lowerConWindow == None)      // subtitles are off
		return;
	if (NumLines >= 6)
	{
		for (i = 1; i < 6; i++)
		{
			Lines[i - 1] = Lines[i];
			LinePlayer[i - 1] = LinePlayer[i];
		}
		NumLines = 5;
	}
	Lines[NumLines] = text;
	LinePlayer[NumLines] = byte(DeusExPlayer(speakingActor) != None);
	NumLines++;
	// AE sized the window before the line was recorded here: size it again
	AskParentForReconfigure();
}

function AppendText(string text)
{
	Super.AppendText(text);
	if (NumLines > 0)
		Lines[NumLines - 1] = Lines[NumLines - 1] $ text;
	AskParentForReconfigure();
}

function DestroyChildren()
{
	Super.DestroyChildren();
	NumLines = 0;
}

event ParentRequestedPreferredSize(bool bWidthSpecified, out float preferredWidth,
                                   bool bHeightSpecified, out float preferredHeight)
{
	local int i;
	local float h;

	if (!RIOn())
	{
		Super.ParentRequestedPreferredSize(bWidthSpecified, preferredWidth, bHeightSpecified, preferredHeight);
		return;
	}
	if (!bWidthSpecified)
		preferredWidth = 800 * K();
	h = 0;
	for (i = 0; i < NumLines; i++)
	{
		if (i == 0)
			h += Class'RISubs'.static.SubHeight(preferredWidth, K(), Speaker, Lines[i]);
		else
			h += Class'RISubs'.static.SubHeight(preferredWidth, K(), "", Lines[i]) + 6 * K();
	}
	preferredHeight = FMax(h, 30 * K());
}

function DrawBackground(GC gc)
{
	if (!RIOn())
		Super.DrawBackground(gc);
}

function DrawBorder(GC gc)
{
	local int i;
	local float y;

	if (!RIOn())
	{
		Super.DrawBorder(gc);
		return;
	}
	if ((lowerConWindow != None) && lowerConWindow.IsVisible(False))
		lowerConWindow.Hide();
	Class'RITheme'.static.SetMode(2);
	y = 0;
	for (i = 0; i < NumLines; i++)
	{
		if (i == 0)
			y += Class'RISubs'.static.DrawSub(gc, 0, y, width, K(), Speaker, Lines[i], LinePlayer[i] != 0, 1.0);
		else
			y += Class'RISubs'.static.DrawSub(gc, 0, y, width, K(), "", Lines[i], LinePlayer[i] != 0, 1.0) + 6 * K();
	}
}

defaultproperties
{
}
