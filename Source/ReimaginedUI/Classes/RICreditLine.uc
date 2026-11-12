//=============================================================================
// RICreditLine
// One line (or wrapped paragraph) of the ending credits, drawn natively:
// headers in Michroma, names in Exo 2. Sized up front so the credits' tile
// window stacks it like AE's text windows.
//=============================================================================
class RICreditLine extends Window;

var string Txt;
var int    Kind;      // 0 header, 1 text, 2 text left-aligned
var float  Sc;

function Class<RIFont> Font()
{
	if (Kind == 0)
		return Class'RIFontHead';
	return Class'RIFontBody';
}

function Setup(string S, int NewKind, float W)
{
	Txt = S;
	Kind = NewKind;
	if (Kind == 0)
		Sc = 0.85;
	else
		Sc = 0.95;
	SetSize(W, Class'RIText'.static.DrawWrapped(None, Font(), 0, 0, W, Txt, Class'RIUtil'.static.Raw(0, 0, 0), Sc, 1.3) + 2);
}

// One wrapped line centred: DrawWrapped draws left-aligned, so short lines
// (nearly all of the credits) are centred by hand
event DrawWindow(GC gc)
{
	local Color C;
	local float tw;

	Class'RITheme'.static.SetMode(1);
	if (Kind == 0)
		C = Class'RISkin'.static.TextHeader();
	else
		C = Class'RISkin'.static.TextIdle();
	tw = Class'RIText'.static.Width(Font(), Txt, Sc);
	if ((Kind == 2) || (tw > width))
		Class'RIText'.static.DrawWrapped(gc, Font(), 0, 0, width, Txt, C, Sc, 1.3);
	else
		Class'RIText'.static.Draw(gc, Font(), (width - tw) * 0.5, 0, Txt, C, Sc);
	Class'RITheme'.static.SetMode(0);
}

defaultproperties
{
}
