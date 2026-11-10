//=============================================================================
// RICreditsWindow
// AE's ending credits (same text, music, scrolling and speed keys) with the
// lines drawn natively in the menus' palette, and a faint key-art backdrop.
//=============================================================================
class RICreditsWindow extends CreditsWindow;

function PrintHeader(String headerText)
{
	local RICreditLine L;

	L = RICreditLine(winScroll.NewChild(Class'RICreditLine'));
	L.Setup(Caps(headerText), 0, maxTextWidth);
}

function PrintText(String itemText, optional bool bLeftJustify)
{
	local RICreditLine L;

	L = RICreditLine(winScroll.NewChild(Class'RICreditLine'));
	if (bLeftJustify)
		L.Setup(itemText, 2, maxTextWidth);
	else
		L.Setup(itemText, 1, maxTextWidth);
}

function PrintAlignText(String itemLabel, String itemText)
{
	local RICreditLine L;

	L = RICreditLine(winScroll.NewChild(Class'RICreditLine'));
	L.Setup(itemLabel $ "   " $ itemText, 2, maxTextWidth);
}

event DrawWindow(GC gc)
{
	Super.DrawWindow(gc);
	// the key art, barely there, behind the scroll
	gc.SetStyle(DSTY_Translucent);
	gc.SetTileColor(Class'RIUtil'.static.Raw(26, 26, 34));
	Class'RISkin'.static.DrawKeyArt(gc, 0, 0, width, height);
}

defaultproperties
{
}
