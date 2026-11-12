//=============================================================================
// RIBarkDisplay
// Barks (what people say as you pass) for the rebuilt HUD: centred
// subtitles with the speaker's name, each fading as AE's timer runs out, in
// place of the riveted box. AE's bark items still run (and time out) as
// before; their text is read from them and drawn here. With the HUD on
// Classic it draws exactly as AE's.
//=============================================================================
class RIBarkDisplay extends HUDBarkDisplay;

function bool RIOn()
{
	return (RIDeusExHUD(GetParent()) != None) && RIDeusExHUD(GetParent()).bRI;
}

function AddBark(string text, float newDisplayTime, Actor speakingActor)
{
	Super.AddBark(text, newDisplayTime, speakingActor);
	AskParentForReconfigure();
}

function float K()
{
	if ((GetParent() != None) && (GetParent().height > 0))
		return GetParent().height / 1080.0;
	return 1.0;
}

function string SpeakerOf(HUDBarkDisplayItem It)
{
	local string N;

	N = It.winName.GetText();
	if (Right(N, 2) == ": ")
		N = Left(N, Len(N) - 2);
	else if (Right(N, 1) == ":")
		N = Left(N, Len(N) - 1);
	return N;
}

event ParentRequestedPreferredSize(bool bWidthSpecified, out float preferredWidth,
								   bool bHeightSpecified, out float preferredHeight)
{
	local Window C;
	local HUDBarkDisplayItem It;
	local float h;

	if (!RIOn())
	{
		Super.ParentRequestedPreferredSize(bWidthSpecified, preferredWidth, bHeightSpecified, preferredHeight);
		return;
	}
	if (!bWidthSpecified)
		preferredWidth = 800 * K();
	h = 0;
	for (C = winBarks.GetBottomChild(); C != None; C = C.GetHigherSibling())
	{
		It = HUDBarkDisplayItem(C);
		if (It != None)
			h += Class'RISubs'.static.SubHeight(preferredWidth, K(), SpeakerOf(It), It.winBark.GetText()) + 10 * K();
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
	local Window C;
	local HUDBarkDisplayItem It;
	local float y, a;

	if (!RIOn())
	{
		Super.DrawBorder(gc);
		return;
	}
	Class'RITheme'.static.SetMode(2);
	y = 0;
	for (C = winBarks.GetBottomChild(); C != None; C = C.GetHigherSibling())
	{
		It = HUDBarkDisplayItem(C);
		if (It == None)
			continue;
		// AE's text windows stay alive (they time the bark) but out of sight
		if (It.winName.IsVisible(False))
			It.winName.Hide();
		if (It.winBark.IsVisible(False))
			It.winBark.Hide();
		a = 1.0;
		if (It.timeToDisplay > 0)
			a = FClamp((It.timeToDisplay - It.timeDisplayed) / 0.5, 0, 1) * FClamp(It.timeDisplayed / 0.15, 0.3, 1);
		y += Class'RISubs'.static.DrawSub(gc, 0, y, width, K(), SpeakerOf(It), It.winBark.GetText(), False, a) + 10 * K();
	}
}

defaultproperties
{
}
